import Foundation

/*
  Zugriff auf https://kraftwuerfel-api.onrender.com

  Der Dienst hat drei Endpunkte: /health, /exercises (offen) und
  /generate-plan (braucht ein Supabase-Token).

  Zwei Eigenheiten bestimmen den Aufbau:

  1. Der freie Render-Plan schläft ein. Der erste Aufruf danach hat im Test
     13,9 Sekunden gebraucht. Deshalb großzügige Zeitlimits und ein
     Aufwärm-Ping beim Start, statt den Nutzer warten zu lassen.

  2. Ohne Token gibt es keine KI-Pläne. Solange die App keine Anmeldung hat,
     liefert `generatePlan` deshalb `.unauthorized` zurück, und der Aufrufer
     fällt auf die lokale Erzeugung zurück — die App bleibt benutzbar.
*/
public final class KraftAPI: @unchecked Sendable {
    public static let shared = KraftAPI()

    public var baseURL = URL(string: "https://kraftwuerfel-api.onrender.com")!

    /*
      Supabase-Access-Token. Gesetzt wird es von AuthService, sobald sich
      jemand angemeldet hat; abgelegt ist es im Schlüsselbund, nicht hier.

      Vorher lag es als Klartext in UserDefaults — und wurde nie gesetzt, weil
      es keine Anmeldung gab. `generatePlan` warf deshalb immer `.unauthorized`.
    */
    public var accessToken: String?

    public enum APIError: Error, LocalizedError {
        case unauthorized
        case rateLimited
        case badRequest(String)
        case upstream(String)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .unauthorized:        return "unauthorized"
            case .rateLimited:         return "daily limit reached"
            case .badRequest(let m):   return m
            case .upstream(let m):     return m
            case .transport(let m):    return m
            }
        }
    }

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        // Kaltstart auf dem freien Plan darf nicht in ein Timeout laufen.
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    // MARK: - Aufwärmen

    /// Weckt den Dienst, damit der erste echte Aufruf nicht 14 Sekunden hängt.
    /// Fehler sind hier egal — es ist nur ein Anstupser.
    public func warmUp() {
        Task { _ = try? await health() }
    }

    @discardableResult
    public func health() async throws -> Int {
        let (data, _) = try await session.data(from: baseURL.appending(path: "health"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (json?["exercises"] as? Int) ?? 0
    }

    // MARK: - Übungen

    public struct RemoteExercise: Decodable {
        public let name: String
        public let nameEn: String
        public let category: String
        public let categories: [String]
        public let equipment: String
        public let heavy: Bool
    }

    public func exercises(
        category: String? = nil,
        equipment: String? = nil,
        heavy: Bool? = nil
    ) async throws -> [RemoteExercise] {
        var components = URLComponents(
            url: baseURL.appending(path: "exercises"),
            resolvingAgainstBaseURL: false
        )!
        var query: [URLQueryItem] = []
        if let category { query.append(.init(name: "category", value: category)) }
        if let equipment { query.append(.init(name: "equipment", value: equipment)) }
        if let heavy { query.append(.init(name: "heavy", value: heavy ? "true" : "false")) }
        if !query.isEmpty { components.queryItems = query }

        do {
            let (data, response) = try await session.data(from: components.url!)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw APIError.upstream("exercises \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            return try JSONDecoder().decode([RemoteExercise].self, from: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    // MARK: - Plan erzeugen

    /// Rumpf exakt wie in der API-Beschreibung.
    public struct PlanRequest: Encodable {
        public var goal: String
        public var experience: String
        public var sex: String
        public var age: Int
        public var height: Int
        public var weight: Int
        /*
          Zielgewicht und Satzschema.

          Der Dienst kannte beides zum Zeitpunkt dieser Änderung noch nicht —
          seine Eingabeprüfung übernimmt nur bekannte Felder und verwirft den
          Rest. Sie gehen trotzdem mit: Sobald der Server sie auswertet, ist
          die App schon soweit, und lokal wirken sie ohnehin.
        */
        public var goalWeight: Int?
        public var method: String
        public var days: [String]
        public var sessionMinutes: Int
        public var weeks: Int
        public var equipment: [String]
        public var focus: [String]
        public var limitations: String
        public var warmup: String
        public var diet: String
        public var excludedFoods: [String]
        public var allergies: [String]
        public var intolerances: [String]
        public var dietPreferences: String
        public var language: String
        public var somatotype: String
        public var activityLevel: String
        public var pushupLevel: String
        public var pullupLevel: String
        public var plankLevel: String
        public var trainingLocation: String
        public var bmi: Double?
        public var bmr: Int?
        public var tdee: Int?

        public init(
            goal: String,
            experience: String,
            sex: String,
            age: Int,
            height: Int,
            weight: Int,
            goalWeight: Int? = nil,
            method: String = "standard",
            days: [String],
            sessionMinutes: Int = 60,
            weeks: Int = 4,
            equipment: [String] = [],
            focus: [String] = [],
            limitations: String = "",
            warmup: String = "auto",
            diet: String = "omnivore",
            excludedFoods: [String] = [],
            allergies: [String] = [],
            intolerances: [String] = [],
            dietPreferences: String = "",
            language: String = "de",
            somatotype: String = "mesomorph",
            activityLevel: String = "moderately_active",
            pushupLevel: String = "6-15",
            pullupLevel: String = "1-5",
            plankLevel: String = "30-60s",
            trainingLocation: String = "gym",
            bmi: Double? = nil,
            bmr: Int? = nil,
            tdee: Int? = nil
        ) {
            self.goal = goal
            self.experience = experience
            self.sex = sex
            self.age = age
            self.height = height
            self.weight = weight
            self.goalWeight = goalWeight
            self.method = method
            self.days = days
            self.sessionMinutes = sessionMinutes
            self.weeks = weeks
            self.equipment = equipment
            self.focus = focus
            self.limitations = limitations
            self.warmup = warmup
            self.diet = diet
            self.excludedFoods = excludedFoods
            self.allergies = allergies
            self.intolerances = intolerances
            self.dietPreferences = dietPreferences
            self.language = language
            self.somatotype = somatotype
            self.activityLevel = activityLevel
            self.pushupLevel = pushupLevel
            self.pullupLevel = pullupLevel
            self.plankLevel = plankLevel
            self.trainingLocation = trainingLocation
            self.bmi = bmi
            self.bmr = bmr
            self.tdee = tdee
        }
    }

    // MARK: - Home-Challenge

    /*
      Rumpf für POST /challenge-plan.

      Getrennt von PlanRequest, weil der Fragebogen der Challenge ein anderer
      ist: kein Split, keine Trainingsmethode, kein Studio-Equipment — dafür
      eine Challenge-Länge in Tagen und Einheiten ab 10 Minuten.
    */
    public struct ChallengeRequest: Encodable {
        public var sex: String
        public var age: Int
        public var height: Int
        public var weight: Int
        public var goalWeight: Int?
        public var goal: String
        public var experience: String
        public var durationDays: Int
        public var daysPerWeek: Int
        public var days: [String]
        public var sessionMinutes: Int
        public var equipment: [String]
        public var diet: String
        public var limitations: String
        public var language: String

        public init(
            sex: String,
            age: Int,
            height: Int,
            weight: Int,
            goalWeight: Int? = nil,
            goal: String,
            experience: String,
            durationDays: Int,
            daysPerWeek: Int,
            days: [String],
            sessionMinutes: Int,
            equipment: [String],
            diet: String,
            limitations: String = "",
            language: String = "de"
        ) {
            self.sex = sex
            self.age = age
            self.height = height
            self.weight = weight
            self.goalWeight = goalWeight
            self.goal = goal
            self.experience = experience
            self.durationDays = durationDays
            self.daysPerWeek = daysPerWeek
            self.days = days
            self.sessionMinutes = sessionMinutes
            self.equipment = equipment
            self.diet = diet
            self.limitations = limitations
            self.language = language
        }
    }

    /// Gibt das rohe `plan`-Objekt zurück — die Umwandlung macht PlanMapper.
    public func generateChallenge(_ request: ChallengeRequest) async throws -> [String: Any] {
        guard let token = accessToken, !token.isEmpty else {
            throw APIError.unauthorized
        }

        let body = try JSONEncoder().encode(request)

        do {
            return try await sendPlanRequest(path: "challenge-plan", body: body, token: token)
        } catch APIError.unauthorized {
            guard let fresh = await tokenRefresher?(), !fresh.isEmpty else {
                throw APIError.unauthorized
            }
            return try await sendPlanRequest(path: "challenge-plan", body: body, token: fresh)
        }
    }

    /*
      Läuft der Access-Token unterwegs ab, reicht ein zweiter Versuch mit einem
      frischen Token — die App muss den Nutzer nicht jede Stunde neu anmelden.
      KraftwuerfelApp verdrahtet das auf AuthService.refreshAccessToken(); diese
      Klasse selbst weiß nichts von Supabase oder Keychain.
    */
    public var tokenRefresher: (@Sendable () async -> String?)?

    /// Gibt das rohe `plan`-Objekt zurück — die Umwandlung in TrainingPlan
    /// macht der Aufrufer, weil nur er die Sprache und die Rufnamen kennt.
    public func generatePlan(_ request: PlanRequest) async throws -> [String: Any] {
        guard let token = accessToken, !token.isEmpty else {
            throw APIError.unauthorized
        }

        let body = try JSONEncoder().encode(request)

        do {
            return try await sendPlanRequest(path: "generate-plan", body: body, token: token)
        } catch APIError.unauthorized {
            guard let fresh = await tokenRefresher?(), !fresh.isEmpty else {
                throw APIError.unauthorized
            }
            return try await sendPlanRequest(path: "generate-plan", body: body, token: fresh)
        }
    }

    private func sendPlanRequest(path: String, body: Data, token: String) async throws -> [String: Any] {
        var urlRequest = URLRequest(url: baseURL.appending(path: path))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        switch status {
        case 200:
            guard let plan = json?["plan"] as? [String: Any] else {
                throw APIError.upstream("Antwort ohne Plan")
            }
            return plan
        case 401: throw APIError.unauthorized
        case 429: throw APIError.rateLimited
        case 400: throw APIError.badRequest(json?["error"] as? String ?? "invalid input")
        default:  throw APIError.upstream(json?["error"] as? String ?? "HTTP \(status)")
        }
    }

    // MARK: - Anmeldung

    /*
      Registrierung, Anmeldung, Refresh, Abmelden — als Aufrufe gegen die
      eigene API, nicht gegen Supabase. Der Server hält Projekt-URL und
      anon key; die App kennt nur diese drei Routen.
    */

    public struct AuthUser: Decodable, Sendable {
        public let id: String
        public let email: String?
    }

    public struct AuthTokens: Decodable, Sendable {
        public let accessToken: String
        public let refreshToken: String
        public let expiresIn: Int
        public let user: AuthUser
    }

    public enum AuthOutcome: Sendable {
        case tokens(AuthTokens)
        case needsEmailConfirmation
    }

    /// Stabiler, sprachneutraler Code aus dem `error`-Feld der API — siehe
    /// README des Backends. Die Übersetzung übernimmt der Aufrufer.
    public struct AuthError: Error, Sendable {
        public let code: String
    }

    public func register(email: String, password: String) async throws -> AuthOutcome {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (status, json) = try await authRequest(path: "auth/register", body: ["email": cleanEmail, "password": password])
        if status == 200, json?["needsEmailConfirmation"] as? Bool == true {
            return .needsEmailConfirmation
        }
        return .tokens(try decodeAuthTokens(status: status, json: json))
    }

    public func login(email: String, password: String) async throws -> AuthTokens {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let (status, json) = try await authRequest(path: "auth/login", body: ["email": cleanEmail, "password": password])
        return try decodeAuthTokens(status: status, json: json)
    }

    public func refresh(refreshToken: String) async throws -> AuthTokens {
        let (status, json) = try await authRequest(path: "auth/refresh", body: ["refreshToken": refreshToken])
        return try decodeAuthTokens(status: status, json: json)
    }

    public func recoverPassword(email: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        _ = try await authRequest(path: "auth/recover", body: ["email": cleanEmail])
    }

    /// Best-effort — die App verwirft ihre Tokens so oder so, ein Fehler hier ändert daran nichts.
    public func logout(accessToken: String) async {
        var request = URLRequest(url: baseURL.appending(path: "auth/logout"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    /*
      Konto und alle Serverdaten löschen (Art. 17 DSGVO).

      Anders als `logout` ist das ausdrücklich NICHT best-effort: Wenn der
      Server nicht bestätigt, darf die App dem Nutzer keine Löschung melden.
      Ein stilles Fehlschlagen wäre hier die schlimmste Variante — der Nutzer
      hielte seine Daten für gelöscht, während sie liegen bleiben.

      Betrifft immer nur das eigene Konto: Welches gemeint ist, steht im
      Token, nicht im Rumpf.
    */
    public func deleteAccount(accessToken: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "auth/delete"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        /*
          Nur 200/204 zählen als gelöscht.

          Insbesondere 404 NICHT: Diese API antwortet auf jede unbekannte
          Route mit 404, und solange `POST /auth/delete` dort noch nicht
          existiert, käme genau das zurück. Als Erfolg gewertet, hätte die App
          alle lokalen Daten weggeworfen und „Konto gelöscht“ gemeldet,
          während auf dem Server alles liegen bleibt — die eine Zusage, die
          eine Löschfunktion niemals brechen darf.
        */
        guard status == 200 || status == 204 else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let serverCode = json?["error"] as? String { throw AuthError(code: serverCode) }
            throw AuthError(code: status == 404 ? "delete_not_supported" : "upstream_error")
        }
    }

    private func authRequest(path: String, body: [String: String]) async throws -> (Int, [String: Any]?) {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if status >= 400 {
            if let serverCode = json?["error"] as? String {
                throw AuthError(code: serverCode)
            }
        }
        
        return (status, json)
    }

    private func decodeAuthTokens(status: Int, json: [String: Any]?) throws -> AuthTokens {
        guard status == 200 else {
            throw AuthError(code: (json?["error"] as? String) ?? "upstream_error")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json ?? [:]),
              let tokens = try? JSONDecoder().decode(AuthTokens.self, from: data)
        else {
            throw AuthError(code: "upstream_error")
        }
        return tokens
    }

    // MARK: - Abonnement

    public struct SubscriptionStatus: Decodable, Sendable {
        public let isPremium: Bool
        public let productId: String?
    }

    /// `signedTransactionInfo`: `VerificationResult.jwsRepresentation` von StoreKit 2.
    public func verifySubscription(accessToken: String, signedTransactionInfo: String) async throws -> SubscriptionStatus {
        try await subscriptionRequest(
            path: "subscriptions/verify",
            accessToken: accessToken,
            body: ["signedTransactionInfo": signedTransactionInfo])
    }

    /// Die App ruft das auf, sobald sie lokal kein aktives Abo mehr findet — sicher,
    /// weil es ausschließlich das eigene Konto betreffen kann.
    public func clearSubscription(accessToken: String) async throws -> SubscriptionStatus {
        try await subscriptionRequest(path: "subscriptions/clear", accessToken: accessToken, body: [:])
    }

    private func subscriptionRequest(
        path: String, accessToken: String, body: [String: String]
    ) async throws -> SubscriptionStatus {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw AuthError(code: (json?["error"] as? String) ?? "upstream_error")
        }
        return try JSONDecoder().decode(SubscriptionStatus.self, from: data)
    }
}
