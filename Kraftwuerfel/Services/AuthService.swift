import Combine
import Foundation

/*
  Anmeldung und Registrierung.

  Die App spricht dafür nur mit der eigenen API (`KraftAPI.register/login/
  refresh/logout`), nie direkt mit Supabase. Vorher lag Supabase-Projekt-URL
  und anon key in der Info.plist, und diese Klasse rief GoTrue selbst auf —
  zwei Anmeldewege, die die App hätte kennen müssen (diese API für Pläne,
  Supabase für die Sitzung). Jetzt kennt sie nur noch einen.

  Der zweite Unterschied zur vorherigen Fassung: Refresh. Supabase-Access-
  Tokens laufen nach einer Stunde ab. Ohne Refresh wäre der KI-Coach nach der
  ersten Stunde wieder auf den lokalen Generator zurückgefallen — ein Fehler,
  der aussieht wie „die Anmeldung tut nichts", und der nur schwer auffällt,
  weil die App dabei nie abstürzt.
*/
public final class AuthService: ObservableObject {

    public static let shared = AuthService()

    public struct Account: Codable, Equatable {
        public let id: String
        public let email: String
        public var name: String?
        /*
          Was der Server über das Abo dieses Kontos weiß.

          Optional, weil ältere gespeicherte Konten das Feld nicht haben —
          `nil` heißt „unbekannt", nicht „kein Abo".
        */
        public var isPremium: Bool?
    }

    @Published public private(set) var account: Account?
    @Published public var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: Self.userNameKey)
        }
    }
    @Published public private(set) var isBusy = false
    @Published public var lastError: String?
    /// Nach der Registrierung will Supabase je nach Projekt eine Bestätigung
    /// per E-Mail. Dann gibt es noch keine Sitzung, und das ist kein Fehler.
    @Published public private(set) var awaitingEmailConfirmation = false
    @Published public private(set) var resetEmailSent = false

    private static let accountKey = "kraftwuerfel:account"
    private static let userNameKey = "kraftwuerfel:userName"
    private static let accessTokenAccount = "supabase.accessToken"
    private static let refreshTokenAccount = "supabase.refreshToken"

    private init() {
        self.userName = UserDefaults.standard.string(forKey: Self.userNameKey) ?? ""
        if let data = UserDefaults.standard.data(forKey: Self.accountKey),
           let stored = try? JSONDecoder().decode(Account.self, from: data) {
            account = stored
            if self.userName.isEmpty, let accName = stored.name, !accName.isEmpty {
                self.userName = accName
            }
        }
        // Das Token liegt im Schlüsselbund, nicht in den Voreinstellungen.
        KraftAPI.shared.accessToken = Keychain.get(Self.accessTokenAccount)
    }

    public var displayName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let accName = account?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !accName.isEmpty {
            return accName
        }
        if let email = account?.email, let firstPart = email.split(separator: "@").first {
            let clean = firstPart
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
            let firstWord = clean.components(separatedBy: .whitespaces).first ?? clean
            if !firstWord.isEmpty { return firstWord }
        }
        return ""
    }

    public var isSignedIn: Bool { account != nil }

    /*
      Es gibt clientseitig nichts mehr zu konfigurieren — Projekt-URL und
      anon key kennt nur noch der Server. Fehlen sie DORT, meldet sich das
      über `lastError` (Code "auth_not_configured"), nicht mehr über dieses
      Flag. Es bleibt aus Kompatibilität zur bestehenden Ansicht stehen.
    */
    public var isConfigured: Bool { true }

    // MARK: - Anmelden & Registrieren

    @discardableResult
    public func signIn(email: String, password: String) async -> Bool {
        guard let trimmedEmail = await validate(email: email, password: password) else { return false }

        await set { self.isBusy = true; self.lastError = nil; self.awaitingEmailConfirmation = false }
        defer { Task { await self.set { self.isBusy = false } } }

        do {
            let tokens = try await KraftAPI.shared.login(email: trimmedEmail, password: password)
            await store(tokens)
            return true
        } catch {
            await set { self.lastError = Self.message(for: error) }
            return false
        }
    }

    @discardableResult
    public func signUp(name: String? = nil, email: String, password: String) async -> Bool {
        guard let trimmedEmail = await validate(email: email, password: password) else { return false }

        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await set { self.userName = name.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        await set { self.isBusy = true; self.lastError = nil; self.awaitingEmailConfirmation = false }
        defer { Task { await self.set { self.isBusy = false } } }

        do {
            switch try await KraftAPI.shared.register(email: trimmedEmail, password: password) {
            case .tokens(let tokens):
                await store(tokens)
            case .needsEmailConfirmation:
                await set { self.awaitingEmailConfirmation = true }
            }
            return true
        } catch {
            await set { self.lastError = Self.message(for: error) }
            return false
        }
    }

    @discardableResult
    public func resetPassword(email: String) async -> Bool {
        guard let trimmedEmail = await validateEmailOnly(email: email) else { return false }

        await set { self.isBusy = true; self.lastError = nil; self.resetEmailSent = false }
        defer { Task { await self.set { self.isBusy = false } } }

        do {
            try await KraftAPI.shared.recoverPassword(email: trimmedEmail)
            await set { self.resetEmailSent = true }
            return true
        } catch {
            // Datenschutz-konforme Bestätigung: Dem Nutzer wird bestätigt, dass eine E-Mail gesendet wurde
            await set { self.resetEmailSent = true }
            return true
        }
    }

    public func clearStatus() {
        lastError = nil
        resetEmailSent = false
    }

    public func signOut() {
        let token = Keychain.get(Self.accessTokenAccount)
        Keychain.remove(Self.accessTokenAccount)
        Keychain.remove(Self.refreshTokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        KraftAPI.shared.accessToken = nil
        account = nil
        /*
          Der Name muss mit weg. `displayName` liest ihn ZUERST — ohne diese
          Zeile stand nach dem Abmelden weiter „Hallo, Shivm!“ in der
          Kopfzeile, obwohl niemand mehr angemeldet war. Das Konto zu
          verwerfen reichte dafür nicht, weil der Name in eigenen
          Voreinstellungen liegt und nicht im Konto.
        */
        userName = ""
        awaitingEmailConfirmation = false
        resetEmailSent = false
        lastError = nil

        SavedAIPlansStore.shared.wipe()
        SavedMealGuidesStore.shared.wipe()

        // Best-effort — die Tokens sind lokal so oder so schon weg.
        if let token { Task { await KraftAPI.shared.logout(accessToken: token) } }
    }

    // MARK: - Konto löschen (Art. 17 DSGVO)

    /*
      Löscht das Konto auf dem Server UND alles, was lokal auf dem Gerät liegt.

      Die Reihenfolge ist Absicht: erst der Server, dann das Gerät. Andersherum
      wäre der Token weg, bevor die Löschung abgeschickt ist — und ohne Token
      kann der Server nicht mehr wissen, welches Konto gemeint war. Der Nutzer
      bliebe mit einem Konto zurück, das er nicht mehr erreichen kann.

      Gibt `false` zurück, wenn der Server nicht bestätigt hat. Dann bleibt
      auch lokal alles stehen: Eine halbe Löschung, die sich wie eine ganze
      anfühlt, ist schlimmer als eine, die ehrlich fehlschlägt.
    */
    @discardableResult
    public func deleteAccount() async -> Bool {
        guard let token = Keychain.get(Self.accessTokenAccount) else {
            await set { self.lastError = I18n.shared.t("auth.deleteNoSession") }
            return false
        }

        await set { self.isBusy = true; self.lastError = nil }
        defer { Task { await self.set { self.isBusy = false } } }

        do {
            try await KraftAPI.shared.deleteAccount(accessToken: token)
        } catch {
            await set { self.lastError = Self.message(for: error) }
            return false
        }

        await MainActor.run { self.wipeAllLocalData() }
        return true
    }

    /*
      Jeder Speicher, den die App führt. Abmelden allein reicht hier nicht:
      Trainingspläne, Favoriten und vor allem die Körperdaten im
      KI-Assistenten liegen in eigenen Voreinstellungen und hätten eine
      Kontolöschung sonst überlebt.

      Die Sprache bleibt bewusst stehen — sie ist eine Bedienvorliebe, kein
      personenbezogenes Datum, und die App auf Deutsch zurückzusetzen wäre für
      einen englischen Nutzer nur verwirrend.
    */
    @MainActor
    private func wipeAllLocalData() {
        SavedPlansStore.shared.wipe()
        SavedAIPlansStore.shared.wipe()
        SavedMealGuidesStore.shared.wipe()
        FavoritesStore.shared.wipe()
        ActivePlanStore.shared.wipe()
        WorkoutHistoryStore.shared.wipe()
        GeneratorSettings.shared.wipe()
        AICoachSession.shared.wipe()
        /*
          Der Fragebogen der Home-Challenge enthält dieselben Gesundheitsdaten
          wie der des KI-Coaches (Geschlecht, Alter, Größe, Gewicht,
          Zielgewicht) — Art. 9 DSGVO. Er darf eine Kontolöschung so wenig
          überleben wie der Coach. ChallengeStore kommt mit, weil dort steht,
          an welchen Tagen trainiert wurde.
        */
        ChallengeSession.shared.wipe()
        ChallengeStore.shared.wipe()
        /*
          Seit die Antworten nur noch einmal existieren, liegen Geschlecht,
          Alter, Größe, Gewicht und Zielgewicht hier — nicht mehr in den
          beiden Sitzungen. Ohne diese Zeile hätte das Profil als einziger
          Speicher die Kontolöschung überlebt, und zwar genau der mit den
          Gesundheitsdaten darin.
        */
        UserProfileStore.shared.wipe()

        Keychain.remove(Self.accessTokenAccount)
        Keychain.remove(Self.refreshTokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        UserDefaults.standard.removeObject(forKey: Self.userNameKey)
        KraftAPI.shared.accessToken = nil

        userName = ""
        account = nil
        awaitingEmailConfirmation = false
        resetEmailSent = false
        lastError = nil
    }

    // MARK: - Refresh

    /*
      Für KraftAPI.tokenRefresher: läuft der Access-Token ab, holt sich die
      App hier einen neuen, ohne den Nutzer erneut zu fragen.

      Mehrere gleichzeitige Aufrufe (z. B. zwei Anfragen, die beide auf ein
      401 laufen) teilen sich einen einzigen Refresh-Versuch — der
      Refresh-Token gilt nur einmal, ein zweiter, paralleler Aufruf würde den
      ersten ungültig machen und die Sitzung beenden, statt sie zu verlängern.
      Das Anlegen/Auslesen von `refreshTask` läuft deshalb über denselben
      MainActor-Sprung wie jede andere Zustandsänderung hier.
    */
    private var refreshTask: Task<String?, Never>?

    /*
      Den Kontostand vom Server nachziehen.

      Das Konto liegt in den Voreinstellungen und wird beim Anmelden
      geschrieben — danach nie wieder. Der Pro-Status darin war damit auf dem
      Stand des letzten Anmeldens eingefroren: Wer sein Abo auf einem anderen
      Gerät abschloss (oder wem es hier von Hand gesetzt wurde), sah davon
      nichts, bis er sich ab- und wieder anmeldete.

      `/auth/refresh` liefert den aktuellen Nutzer gleich mit, also kostet das
      nichts extra. Fehler sind egal: Dann bleibt der bisherige Stand stehen.
    */
    public func refreshAccountFromServer() async {
        guard isSignedIn, let refreshToken = Keychain.get(Self.refreshTokenAccount) else { return }
        guard let tokens = try? await KraftAPI.shared.refresh(refreshToken: refreshToken) else { return }
        await store(tokens)
        await StoreKitManager.shared.refreshEntitlements()
    }

    public func refreshAccessToken() async -> String? {
        let task = await currentOrNewRefreshTask()
        let token = await task.value
        await set { self.refreshTask = nil }
        return token
    }

    @MainActor
    private func currentOrNewRefreshTask() -> Task<String?, Never> {
        if let existing = refreshTask { return existing }
        let task = Task { [weak self] () -> String? in
            await self?.performRefresh()
        }
        refreshTask = task
        return task
    }

    private func performRefresh() async -> String? {
        guard let refreshToken = Keychain.get(Self.refreshTokenAccount) else { return nil }

        do {
            let tokens = try await KraftAPI.shared.refresh(refreshToken: refreshToken)
            await store(tokens)
            return tokens.accessToken
        } catch let error as KraftAPI.AuthError where error.code == "invalid_refresh_token" {
            // Der Refresh-Token wurde abgelehnt (abgelaufen, schon verbraucht, …) —
            // die Sitzung ist wirklich vorbei, nicht nur kurz gestört.
            await set { self.signOut() }
            return nil
        } catch {
            // Netzwerkfehler oder ein vorübergehendes Server-Problem: der alte
            // Token bleibt liegen, der nächste Aufruf versucht es erneut.
            return nil
        }
    }

    // MARK: - Intern

    private func validate(email: String, password: String) async -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@"), password.count >= 6 else {
            await set { self.lastError = I18n.shared.t("auth.invalidInput") }
            return nil
        }
        return normalizedEmail
    }

    private func validateEmailOnly(email: String) async -> String? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@") else {
            await set { self.lastError = I18n.shared.t("auth.invalidInput") }
            return nil
        }
        return normalizedEmail
    }

    private func store(_ tokens: KraftAPI.AuthTokens) async {
        Keychain.set(tokens.accessToken, for: Self.accessTokenAccount)
        Keychain.set(tokens.refreshToken, for: Self.refreshTokenAccount)
        KraftAPI.shared.accessToken = tokens.accessToken

        let stored = Account(
            id: tokens.user.id,
            email: tokens.user.email ?? "",
            name: userName.isEmpty ? nil : userName,
            isPremium: tokens.user.isPremium
        )
        if let encoded = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(encoded, forKey: Self.accountKey)
        }
        await set { self.account = stored }
    }

    /// Die API antwortet mit einem stabilen, sprachneutralen Code (siehe
    /// Backend-README) — hier wird er einmal zentral in Anzeigetext übersetzt.
    private static func message(for error: Error) -> String {
        guard let authError = error as? KraftAPI.AuthError else {
            return I18n.shared.t("auth.serverError", ["reason": error.localizedDescription])
        }
        switch authError.code {
        case "invalid_credentials": return I18n.shared.t("auth.invalidCredentials")
        case "email_not_confirmed": return I18n.shared.t("auth.confirmEmail")
        case "invalid_email", "password_too_short", "weak_password": return I18n.shared.t("auth.invalidInput")
        case "rate_limited": return I18n.shared.t("auth.tooManyAttempts")
        case "auth_not_configured": return I18n.shared.t("auth.notConfigured")
        case "delete_not_supported": return I18n.shared.t("auth.deleteNotSupported")
        default: return I18n.shared.t("auth.serverError", ["reason": authError.code])
        }
    }

    @MainActor
    private func set(_ change: () -> Void) { change() }
}
