import Combine
import Foundation

/*
  Was die App gerade vom Server hat — und was nicht.

  Bisher lief die Verbindung stumm: `refreshFromAPI()` holte den Katalog mit
  `try?` und kehrte bei jedem Fehler wortlos zurück. Ob die App mit 137
  eingebauten oder 137 frisch geladenen Übungen arbeitete, ob der Dienst
  überhaupt antwortet, ob der KI-Coach den Server erreicht oder heimlich lokal
  rechnet — nichts davon war irgendwo abzulesen, weder für den Nutzer noch beim
  Suchen eines Fehlers.

  Diese Klasse hält genau das fest. Sie entscheidet nichts, sie protokolliert.
*/
@MainActor
public final class BackendStatus: ObservableObject {

    public static let shared = BackendStatus()

    public enum Reachability: Equatable {
        case unknown
        case checking
        case online(exercises: Int)
        case offline(reason: String)
    }

    public enum CatalogSource: Equatable {
        /// Die eingebaute Liste — kein Netz, oder die Antwort war unbrauchbar.
        case bundled
        case server(count: Int)
    }

    @Published public private(set) var reachability: Reachability = .unknown
    @Published public private(set) var catalogSource: CatalogSource = .bundled
    @Published public private(set) var lastCheck: Date?

    private init() {}

    /// Woher die KI-Pläne kommen. Ohne Anmeldung gibt es kein Token, und
    /// `generatePlan` fällt auf den lokalen Generator zurück.
    public var usesServerForPlans: Bool {
        let token = KraftAPI.shared.accessToken
        return !(token?.isEmpty ?? true)
    }

    // MARK: - Prüfen

    public func check() async {
        reachability = .checking
        do {
            let count = try await KraftAPI.shared.health()
            reachability = .online(exercises: count)
        } catch {
            reachability = .offline(reason: error.localizedDescription)
        }
        lastCheck = Date()
    }

    // MARK: - Protokollieren

    func recordCatalog(_ source: CatalogSource) {
        catalogSource = source
        if case .server(let count) = source {
            reachability = .online(exercises: count)
            lastCheck = Date()
        }
    }

    func recordCatalogFailure(_ reason: String) {
        catalogSource = .bundled
        reachability = .offline(reason: reason)
        lastCheck = Date()
    }
}
