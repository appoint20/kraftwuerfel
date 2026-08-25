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

    public let proProductId = "app.kraftwuerfel.pro.monthly"

    #if DEBUG
    /*
      Nur im Debug-Build: schaltet Pro zum Ausprobieren frei. Standard ist an,
      damit das Testen im Simulator wie bisher funktioniert — im Release-Build
      existiert die Eigenschaft gar nicht, dort zählt allein die Berechtigung.
    */
    private static let debugOverrideKey = "kraftwuerfel:debugPro"
    @Published public var debugProOverride: Bool = UserDefaults.standard.object(forKey: "kraftwuerfel:debugPro") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(debugProOverride, forKey: Self.debugOverrideKey)
            Task { await refreshEntitlements() }
        }
    }
    #endif

    private var updatesTask: Task<Void, Never>?

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

        Task {
            await fetchProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Produkte

    public func fetchProducts() async {
        do {
            availableProducts = try await Product.products(for: [proProductId])
        } catch {
            // Kein Grund, irgendetwas freizuschalten — nur merken.
            lastError = error.localizedDescription
        }
    }

    // MARK: - Kaufen

    @discardableResult
    public func purchasePro() async -> Bool {
        if availableProducts.isEmpty { await fetchProducts() }

        guard let product = availableProducts.first(where: { $0.id == proProductId }) else {
            // Früher wurde hier freigeschaltet. Ohne Produkt gibt es keinen Kauf.
            lastError = "product_unavailable"
            return false
        }

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
        #if DEBUG
        if debugProOverride {
            isProUnlocked = true
            return
        }
        #endif

        var unlocked = false
        var winningJws: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == proProductId else { continue }
            if transaction.revocationDate != nil { continue }
            if let expiry = transaction.expirationDate, expiry <= Date() { continue }
            unlocked = true
            winningJws = result.jwsRepresentation
            break
        }

        isProUnlocked = unlocked
        await syncEntitlementToServer(unlocked: unlocked, jws: winningJws)
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
    private func syncEntitlementToServer(unlocked: Bool, jws: String?) async {
        guard let token = KraftAPI.shared.accessToken, !token.isEmpty else { return }

        do {
            if unlocked, let jws {
                _ = try await KraftAPI.shared.verifySubscription(accessToken: token, signedTransactionInfo: jws)
            } else {
                _ = try await KraftAPI.shared.clearSubscription(accessToken: token)
            }
        } catch {
            // Best-effort — der lokale Pro-Status bleibt davon unberührt.
        }
    }
}
