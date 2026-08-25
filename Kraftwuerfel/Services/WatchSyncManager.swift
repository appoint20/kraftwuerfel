import Combine
import Foundation
import WatchConnectivity

/*
  Die Brücke zwischen iPhone und Apple Watch. Diese Datei wird in BEIDE Ziele
  übersetzt; die Richtung ergibt sich aus `#if os(...)`.

  Was vorher nicht funktionieren konnte:

  - Es gab kein watchOS-Ziel. `WCSession.isReachable` war damit nie wahr, und
    weil jedes Senden hinter `guard isReachable` stand, verschwand jede
    Nachricht wortlos.
  - Auch mit Uhr wäre die Hälfte verloren gegangen: `sendMessage` braucht eine
    laufende Gegenstelle. Steckt die Uhr am Ladegerät oder ist die App nur im
    Hintergrund, ist nichts erreichbar. Für einen Zustand, bei dem nur der
    letzte Stand zählt, ist `updateApplicationContext` das richtige Mittel —
    es wird zugestellt, sobald die Uhr wieder mitspielt.
  - Die Pause wurde als Restsekunden übertragen. Nachrichten gehen aber nur bei
    Zustandswechseln raus, also stand der Zähler auf der Uhr still. Jetzt
    kommt das Ende der Pause als Datum, und die Uhr zählt selbst herunter.
*/
public final class WatchSyncManager: NSObject, ObservableObject {

    public static let shared = WatchSyncManager()

    // MARK: - Gespiegelter Sitzungszustand

    @Published public private(set) var isLiveSessionActive: Bool = false
    @Published public private(set) var currentExercise: String = ""
    @Published public private(set) var currentSet: Int = 0
    @Published public private(set) var totalSets: Int = 0
    @Published public private(set) var isResting: Bool = false
    /// Ende der Pause als Zeitpunkt — die Uhr zählt daraus selbst herunter.
    @Published public private(set) var restEndsAt: Date?

    // MARK: - Gegenstelle

    @Published public private(set) var isCounterpartReachable: Bool = false
    #if os(iOS)
    @Published public private(set) var isWatchPaired: Bool = false
    @Published public private(set) var isWatchAppInstalled: Bool = false

    /*
      Echte Messwerte von der Uhr. `nil` heißt: es liegt nichts vor. Die
      Ansicht fällt dann sichtbar auf ihre Schätzung zurück, statt eine alte
      Zahl weiterzuzeigen.
    */
    @Published public private(set) var watchHeartRate: Int?
    @Published public private(set) var watchActiveCalories: Double?
    @Published public private(set) var watchSampleDate: Date?
    #endif

    /// Wird gerufen, wenn auf der Gegenstelle „Satz fertig“ gedrückt wurde.
    public var onSetCompletedRemotely: (() -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Ein Messwert gilt zehn Sekunden. Danach lieber nichts zeigen als eine
    /// Zahl, die längst nicht mehr stimmt.
    public static let sampleValidity: TimeInterval = 10

    // MARK: - Senden

    /*
      Zustand geht über den Anwendungskontext: Der wird auch dann zugestellt,
      wenn die Gegenstelle gerade nicht läuft, und ein neuer Stand ersetzt den
      alten. Ist die Gegenstelle erreichbar, geht zusätzlich eine Nachricht
      raus — die kommt sofort an, der Kontext braucht bis zu ein paar Sekunden.
    */
    private func push(_ payload: [String: Any], immediate: Bool) {
        guard let session, session.activationState == .activated else { return }

        if immediate, session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? session.updateApplicationContext(payload)
    }

    /// Einmalige Ereignisse. Ein nachgereichter „Satz fertig“ wäre falsch,
    /// deshalb hier ausdrücklich kein Anwendungskontext.
    private func fire(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    #if os(iOS)
    public func sendWorkoutUpdate(
        exercise: String,
        set: Int,
        totalSets: Int,
        isRest: Bool,
        restEndsAt: Date?
    ) {
        self.currentExercise = exercise
        self.currentSet = set
        self.totalSets = totalSets
        self.isResting = isRest
        self.restEndsAt = restEndsAt
        self.isLiveSessionActive = true

        var payload: [String: Any] = [
            "type": "workout_update",
            "exercise": exercise,
            "set": set,
            "totalSets": totalSets,
            "isRest": isRest,
            "timestamp": Date().timeIntervalSince1970
        ]
        if let restEndsAt {
            payload["restEndsAt"] = restEndsAt.timeIntervalSince1970
        }
        push(payload, immediate: true)
    }

    /// Sagt der Uhr, dass die Sitzung vorbei ist — sonst bleibt dort die
    /// letzte Übung stehen, bis die App neu startet.
    public func endLiveSession() {
        isLiveSessionActive = false
        currentExercise = ""
        currentSet = 0
        totalSets = 0
        isResting = false
        restEndsAt = nil
        watchHeartRate = nil
        watchActiveCalories = nil
        watchSampleDate = nil

        push(["type": "workout_end", "timestamp": Date().timeIntervalSince1970], immediate: true)
    }

    /// Der zuletzt gemeldete Puls, sofern er noch frisch genug ist.
    public var freshWatchHeartRate: Int? {
        guard let watchHeartRate, let watchSampleDate,
              Date().timeIntervalSince(watchSampleDate) < Self.sampleValidity
        else { return nil }
        return watchHeartRate
    }
    #endif

    #if os(watchOS)
    /// Echte Sensorwerte ans iPhone. Nur Messwerte gehen hier durch —
    /// geschätzte Zahlen haben auf diesem Weg nichts verloren.
    public func sendMeasurements(heartRate: Int?, activeCalories: Double?) {
        var payload: [String: Any] = [
            "type": "measurements",
            "timestamp": Date().timeIntervalSince1970
        ]
        if let heartRate { payload["bpm"] = heartRate }
        if let activeCalories { payload["kcal"] = activeCalories }
        guard payload.count > 2 else { return }
        fire(payload)
    }
    #endif

    /// Auf beiden Seiten dasselbe: „Satz fertig“ meldet sich bei der
    /// Gegenstelle und schaltet lokal weiter.
    public func completeSetRemotely() {
        fire(["type": "complete_set", "timestamp": Date().timeIntervalSince1970])
        DispatchQueue.main.async { self.onSetCompletedRemotely?() }
    }

    // MARK: - Empfangen

    private func apply(_ message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case "workout_update":
                self.isLiveSessionActive = true
                if let v = message["exercise"] as? String { self.currentExercise = v }
                if let v = message["set"] as? Int { self.currentSet = v }
                if let v = message["totalSets"] as? Int { self.totalSets = v }
                if let v = message["isRest"] as? Bool { self.isResting = v }
                self.restEndsAt = (message["restEndsAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))

            case "workout_end":
                self.isLiveSessionActive = false
                self.currentExercise = ""
                self.currentSet = 0
                self.totalSets = 0
                self.isResting = false
                self.restEndsAt = nil

            case "complete_set":
                self.onSetCompletedRemotely?()

            case "measurements":
                #if os(iOS)
                if let bpm = message["bpm"] as? Int {
                    self.watchHeartRate = bpm
                    self.watchSampleDate = Date()
                }
                if let kcal = message["kcal"] as? Double {
                    self.watchActiveCalories = kcal
                }
                #endif

            default:
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncManager: WCSessionDelegate {

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isCounterpartReachable = session.isReachable
            #if os(iOS)
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isCounterpartReachable = session.isReachable }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Nach einem Uhrenwechsel muss die Sitzung neu aktiviert werden, sonst
    /// erreicht die App die neue Uhr nie.
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    #endif
}
