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
    }

    @Published public private(set) var account: Account?
    @Published public private(set) var isBusy = false
    @Published public var lastError: String?
    /// Nach der Registrierung will Supabase je nach Projekt eine Bestätigung
    /// per E-Mail. Dann gibt es noch keine Sitzung, und das ist kein Fehler.
    @Published public private(set) var awaitingEmailConfirmation = false

    private static let accountKey = "kraftwuerfel:account"
    private static let accessTokenAccount = "supabase.accessToken"
    private static let refreshTokenAccount = "supabase.refreshToken"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.accountKey),
           let stored = try? JSONDecoder().decode(Account.self, from: data) {
            account = stored
        }
        // Das Token liegt im Schlüsselbund, nicht in den Voreinstellungen.
        KraftAPI.shared.accessToken = Keychain.get(Self.accessTokenAccount)
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
    public func signUp(email: String, password: String) async -> Bool {
        guard let trimmedEmail = await validate(email: email, password: password) else { return false }

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

    public func signOut() {
        let token = Keychain.get(Self.accessTokenAccount)
        Keychain.remove(Self.accessTokenAccount)
        Keychain.remove(Self.refreshTokenAccount)
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        KraftAPI.shared.accessToken = nil
        account = nil
        awaitingEmailConfirmation = false
        lastError = nil

        // Best-effort — die Tokens sind lokal so oder so schon weg.
        if let token { Task { await KraftAPI.shared.logout(accessToken: token) } }
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
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), password.count >= 6 else {
            await set { self.lastError = I18n.shared.t("auth.invalidInput") }
            return nil
        }
        return trimmedEmail
    }

    private func store(_ tokens: KraftAPI.AuthTokens) async {
        Keychain.set(tokens.accessToken, for: Self.accessTokenAccount)
        Keychain.set(tokens.refreshToken, for: Self.refreshTokenAccount)
        KraftAPI.shared.accessToken = tokens.accessToken

        let stored = Account(id: tokens.user.id, email: tokens.user.email ?? "")
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
        default: return I18n.shared.t("auth.serverError", ["reason": authError.code])
        }
    }

    @MainActor
    private func set(_ change: () -> Void) { change() }
}
