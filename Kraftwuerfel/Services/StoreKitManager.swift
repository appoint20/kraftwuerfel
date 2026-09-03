import Foundation
import StoreKit
import Combine

/*
  Pro-Freischaltung über StoreKit 2.

  Die vorherige Fassung verschenkte Pro auf mehreren Wegen:
    - `isProUnlocked` stand fest auf `true`
    - `purchasePro()` schaltete frei und meldete Erfolg, wenn das Produkt nicht
      geladen werden konnte — ein Netzwerkfehler reichte also für Gratis-Pro
    - `checkSubscriptionStatus()` setzte nie auf `false` zurück, ein
      abgelaufenes oder erstattetes Abo blieb ewig gültig
    - Änderungen außerhalb der App (Kündigung, Erstattung, Familienfreigabe)
      kamen nie an, weil niemand `Transaction.updates` zuhörte

  Deshalb ist der Zustand jetzt immer aus den tatsächlichen Berechtigungen
  abgeleitet, nie gesetzt. Zum Ausprobieren gibt es eine Hintertür — aber nur
  im Debug-Build, damit sie unmöglich in den Store gelangt.
*/
@MainActor
public final class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()

    @Published public private(set) var isProUnlocked: Bool = false
    @Published public private(set) var availableProducts: [Product] = []
    @Published public var isPurchasing: Bool = false
    @Published public var lastError: String?

    nonisolated public static let monthlyProductId = "app.kraftwuerfel.pro.monthly"
    nonisolated public static let yearlyProductId = "app.kraftwuerfel.pro.yearly"
    nonisolated public static let allProductIds: [String] = [monthlyProductId, yearlyProductId]

    public var proProductId: String { Self.monthlyProductId }

    public enum ProPlanChoice: String, CaseIterable, Identifiable {
        case yearly, monthly
        public var id: String { rawValue }

        public var productId: String {
            switch self {
            case .yearly: return StoreKitManager.yearlyProductId
            case .monthly: return StoreKitManager.monthlyProductId
            }
        }
    }

    #if DEBUG
    /*
      Nur im Debug-Build: schaltet Pro zum Ausprobieren frei.

      Zwei Dinge waren an der vorherigen Fassung falsch, und beide zusammen
      ergaben den Eindruck, das Speichern sei kaputt.

      Erstens stand der Standard auf AN. Damit war `isProUnlocked` in jedem
      Entwicklungsbuild wahr, sobald jemand angemeldet war — jede Pro-Sperre
      sah offen aus, unabhängig davon, ob ein Abo lief. Gespeicherte Pläne
      blieben sichtbar, obwohl das Abo abgelaufen war. Es funktionierte
      alles; nur stand die Tür in der Entwicklung immer offen.

      Zweitens lag der Schalter in UserDefaults und überlebte damit jeden
      Neustart. Wer ihn einmal zum Prüfen anschaltete, hatte ihn Wochen
      später immer noch an und wusste es nicht.

      Er kommt deshalb jetzt aus einem Startargument und wird nirgends
      gespeichert: Er gilt für genau einen Programmlauf und ist im Schema
      sichtbar, statt unsichtbar in den Voreinstellungen zu liegen.

          Product → Scheme → Run → Arguments → "-KraftDebugPro"

      Im Release-Build existiert die Eigenschaft gar nicht; dort zählt
      allein die Berechtigung von Apple.
    */
    @Published public var debugProOverride: Bool = ProcessInfo.processInfo.arguments.contains("-KraftDebugPro") {
        didSet {
            /*
              Beim Einschalten sofort wirken, nicht erst nach dem Nachfragen.

              `refreshEntitlements()` läuft asynchron. Wurde der Schalter kurz
              zuvor ausgeschaltet, konnte dessen Nachfrage danach landen und
              `isProUnlocked` wieder auf false setzen — der Schalter stand auf
              an, die App zeigte trotzdem die kostenlose Fassung. Dass der
              Schalter gilt, ist eine rein lokale Entscheidung und braucht
              StoreKit nicht.
            */
            if debugProOverride { isProUnlocked = true }
            // Absichtlich ohne Speichern — siehe oben.
            Task { await refreshEntitlements() }
        }
    }
    #endif

    private var updatesTask: Task<Void, Never>?
    private var accountObserver: AnyCancellable?

    private init() {
        // Auf Änderungen hören, die außerhalb der App passieren.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }

        /*
          Pro hängt am Konto, nicht am Gerät: `syncEntitlementToServer` unten
          schreibt is_premium in genau das angemeldete Konto, und der Kauf
          wird über `appAccountToken` daran gebunden. Ohne Anmeldung gibt es
          folglich auch kein Pro — sonst blieben KI-Coach, Live-Session und
          Speichern nach dem Abmelden offen, weil `isProUnlocked` allein die
          Apple-ID kannte und vom Abmelden nie erfuhr.
        */
        accountObserver = AuthService.shared.$account
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.refreshEntitlements() }
            }

        Task {
            await fetchProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
        accountObserver?.cancel()
    }

    // MARK: - Produkte

    public func fetchProducts() async {
        do {
            availableProducts = try await Product.products(for: Self.allProductIds)
        } catch {
            // Kein Grund, irgendetwas freizuschalten — nur merken.
            lastError = error.localizedDescription
        }
    }

    public func product(for plan: ProPlanChoice) -> Product? {
        availableProducts.first(where: { $0.id == plan.productId })
    }

    // MARK: - Kaufen

    @discardableResult
    public func purchase(plan: ProPlanChoice) async -> Bool {
        if availableProducts.isEmpty { await fetchProducts() }

        guard let product = availableProducts.first(where: { $0.id == plan.productId }) else {
            // Fallback zum ersten verfügbaren Pro-Produkt
            if let fallback = availableProducts.first(where: { Self.allProductIds.contains($0.id) }) {
                return await executePurchase(product: fallback)
            }
            lastError = "product_unavailable"
            return false
        }

        return await executePurchase(product: product)
    }

    @discardableResult
    public func purchasePro() async -> Bool {
        await purchase(plan: .yearly)
    }

    private func executePurchase(product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        // Bindet den Kauf an das angemeldete Konto, damit der Server später
        // (in /subscriptions/verify) prüfen kann, dass niemand eine fremde,
        // echte Transaktion mit dem eigenen Account einreicht.
        var options: Set<Product.PurchaseOption> = []
        if let userId = AuthService.shared.account?.id, let accountToken = UUID(uuidString: userId) {
            options.insert(.appAccountToken(accountToken))
        }

        do {
            switch try await product.purchase(options: options) {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    // Signatur nicht prüfbar -> nicht freischalten.
                    lastError = "unverified_transaction"
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isProUnlocked

            case .userCancelled, .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Apple verlangt einen sichtbaren Weg, Käufe wiederherzustellen.
    public func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Berechtigung

    /*
      Einzige Stelle, die `isProUnlocked` setzt: was Apple sagt, gilt.
      Abgelaufene und erstattete Transaktionen zählen ausdrücklich nicht.
    */
    public func refreshEntitlements() async {
        /*
          Ohne Anmeldung kein Pro — auch nicht im Debug-Build. Die Hintertür
          darf beim Ausprobieren nicht genau den Fall verdecken, den sie
          testen soll: abmelden und sehen, dass die Pro-Funktionen zugehen.
        */
        guard AuthService.shared.isSignedIn else {
            isProUnlocked = false
            return
        }

        #if DEBUG
        if debugProOverride {
            isProUnlocked = true
            return
        }
        #endif

        var unlocked = false
        var winningJws: String?
        /*
          Ob wir überhaupt etwas über dieses Konto erfahren haben.

          `Transaction.currentEntitlements` liefert eine leere Folge in zwei
          völlig verschiedenen Fällen: „kein Abo" und „konnte gerade nicht
          nachsehen" (kein App-Store-Konto auf dem Gerät, Start noch nicht
          durch, Netzproblem). Diese beiden auseinanderzuhalten ist der Kern
          der Sache — siehe unten bei `syncEntitlementToServer`.
        */
        var sawAnyEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.allProductIds.contains(transaction.productID) else { continue }
            sawAnyEntitlement = true
            if transaction.revocationDate != nil { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            unlocked = true
            winningJws = result.jwsRepresentation
            break
        }

        /*
          Der Server ist der zweite, gleichwertige Nachweis.

          Er setzt `is_premium` nur nach geprüfter Apple-Signatur — die
          Angabe ist also nicht schlechter als die lokale Prüfung, nur an
          einer anderen Stelle. Ohne sie war ein zahlender Nutzer auf einem
          zweiten Gerät (oder direkt nach einer Neuinstallation, bevor
          StoreKit geantwortet hat) schlicht „kostenlos".
        */
        let serverSaysPremium = AuthService.shared.account?.isPremium == true
        isProUnlocked = unlocked || serverSaysPremium

        await syncEntitlementToServer(
            unlocked: unlocked,
            jws: winningJws,
            sawAnyEntitlement: sawAnyEntitlement
        )
    }

    /*
      Meldet den lokal geprüften Stand an den Server, damit is_premium in
      Supabase demselben Stand folgt wie StoreKit auf diesem Gerät — sonst
      wüsste kein zweites Gerät und keine spätere Web-Ansicht vom Kauf.

      `isProUnlocked` oben hängt NICHT von dieser Antwort ab: StoreKits
      eigene Signaturprüfung (`.verified`) hat schon stattgefunden, bevor
      diese Funktion aufgerufen wird. Das hier ist Abgleich, keine zweite
      Freischaltung.
    */
    private func syncEntitlementToServer(
        unlocked: Bool,
        jws: String?,
        sawAnyEntitlement: Bool
    ) async {
        guard let token = KraftAPI.shared.accessToken, !token.isEmpty else { return }

        do {
            if unlocked, let jws {
                _ = try await KraftAPI.shared.verifySubscription(accessToken: token, signedTransactionInfo: jws)
                return
            }

            /*
              Gelöscht wird nur mit Beleg.

              Hier stand `else { clearSubscription() }` — der Pro-Status im
              Konto wurde also gelöscht, sobald auf DIESEM Gerät gerade keine
              Berechtigung zu finden war. Eine leere Antwort von StoreKit
              heißt aber nicht „kein Abo": Sie kommt genauso, wenn kein
              App-Store-Konto angemeldet ist, wenn der Start noch nicht durch
              ist oder das Netz klemmt. Ein zahlender Nutzer verlor damit
              seinen Serverstatus, weil er sein Telefon zurückgesetzt hatte.

              Jetzt wird nur zurückgesetzt, wenn wir tatsächlich eine
              Berechtigung gesehen haben und sie abgelaufen oder widerrufen
              ist. Im Zweifel bleibt der Serverstand stehen — Apple bleibt
              ohnehin die letzte Instanz, und ein zu großzügiger Status ist
              der harmlosere Fehler.
            */
            guard sawAnyEntitlement else { return }
            _ = try await KraftAPI.shared.clearSubscription(accessToken: token)
        } catch {
            // Best-effort — der lokale Pro-Status bleibt davon unberührt.
        }
    }
}
