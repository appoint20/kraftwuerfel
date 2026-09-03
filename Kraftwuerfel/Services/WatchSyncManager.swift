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
    @Published public var currentWeight: Double = 20.0
    @Published public var currentReps: Int = 10
    @Published public private(set) var targetReps: String = "8-12"
    @Published public private(set) var restDurationSeconds: Int = 60
    @Published public private(set) var isResting: Bool = false
    /// Ende der Pause als Zeitpunkt — die Uhr zählt daraus selbst herunter.
    @Published public private(set) var restEndsAt: Date?
    /// Das Training selbst pausiert — anders als `isResting`, das nur die
    /// Pause zwischen zwei Sätzen ist. Wie bei `restEndsAt` zählt die Uhr die
    /// Gesamtzeit über `sessionStartedAt` selbst weiter; angezeigt wird der
    /// pausierte Zustand separat, statt den Zähler künstlich anzuhalten.
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var sessionStartedAt: Date?

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
    /// Wird gerufen, wenn auf der Watch Gewicht und Wiederholungen eingetragen & abgehakt wurden.
    public var onSetCompletedWithDataRemotely: ((Double, Int) -> Void)?
    /// Wird gerufen, wenn auf der Gegenstelle Pause/Fortsetzen gedrückt wurde.
    public var onPauseToggleRequestedRemotely: (() -> Void)?
    /// Wird gerufen, wenn die Pause vorzeitig auf der Watch übersprungen wurde.
    public var onSkipRestRequestedRemotely: (() -> Void)?
    /// Wird gerufen, wenn auf der Watch „Training beenden" gedrückt wurde.
    public var onEndWorkoutRequestedRemotely: (() -> Void)?
    /*
      Wird gerufen, wenn die Gegenstelle nach dem aktuellen Stand fragt.

      Das ist der Ausweg aus der verlorenen Verbindung: Zustand floss bisher
      ausschließlich dann, wenn sich auf dem iPhone etwas änderte. Startete die
      Uhr neu oder verpasste sie den Kontext, wartete sie endlos — bis man am
      iPhone einen Satz abhakte und damit zufällig eine neue Nachricht auslöste.
      Fragen konnte sie nicht. Jetzt schon.
    */
    public var onStateRequestedRemotely: (() -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /*
      Den zuletzt hinterlegten Anwendungskontext übernehmen.

      `didReceiveApplicationContext` feuert nur bei NEUEN Kontexten. Eine
      gerade gestartete App bekommt also nichts, obwohl WatchConnectivity den
      letzten Stand längst vorrätig hält — er steht in `receivedApplicationContext`
      und wurde bisher nie gelesen. Genau deshalb stand die Uhr nach einem
      Neustart leer da, während auf dem iPhone ein Training lief.
    */
    private func applyStoredContext() {
        guard let session, session.activationState == .activated else { return }
        let stored = session.receivedApplicationContext
        guard !stored.isEmpty else { return }
        apply(stored)
    }

    /// Ein Messwert gilt dreißig Sekunden, um Messpausen des optischen Sensors abzufedern.
    public static let sampleValidity: TimeInterval = 30

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
        weight: Double = 20.0,
        reps: Int = 10,
        targetReps: String = "8-12",
        isRest: Bool,
        restEndsAt: Date?,
        restDurationSeconds: Int = 60,
        isPaused: Bool,
        sessionStartedAt: Date
    ) {
        self.currentExercise = exercise
        self.currentSet = set
        self.totalSets = totalSets
        self.currentWeight = weight
        self.currentReps = reps
        self.targetReps = targetReps
        self.isResting = isRest
        self.restEndsAt = restEndsAt
        self.restDurationSeconds = restDurationSeconds
        self.isPaused = isPaused
        self.sessionStartedAt = sessionStartedAt
        self.isLiveSessionActive = true

        var payload: [String: Any] = [
            "type": "workout_update",
            "exercise": exercise,
            "set": set,
            "totalSets": totalSets,
            "weight": weight,
            "reps": reps,
            "targetReps": targetReps,
            "isRest": isRest,
            "restDurationSeconds": restDurationSeconds,
            "isPaused": isPaused,
            "sessionStartedAt": sessionStartedAt.timeIntervalSince1970,
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
        isPaused = false
        sessionStartedAt = nil
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

    /// Die zuletzt gemeldeten Aktivkalorien von der Watch.
    public var freshWatchActiveCalories: Double? {
        guard let watchActiveCalories, let watchSampleDate,
              Date().timeIntervalSince(watchSampleDate) < Self.sampleValidity
        else { return nil }
        return watchActiveCalories
    }
    #endif

    #if os(watchOS)
    /// Echte Sensorwerte ans iPhone. Werden via sendMessage, applicationContext
    /// und transferUserInfo übertragen, damit kein Messwert verloren geht.
    public func sendMeasurements(heartRate: Int?, activeCalories: Double?) {
        var payload: [String: Any] = [
            "type": "measurements",
            "timestamp": Date().timeIntervalSince1970
        ]
        if let heartRate { payload["bpm"] = heartRate }
        if let activeCalories { payload["kcal"] = activeCalories }
        guard payload.count > 2 else { return }

        guard let session, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        try? session.updateApplicationContext(payload)
        session.transferUserInfo(payload)
    }

    /// Satz auf der Watch mit angepasstem Gewicht und Wiederholungen abhaken.
    public func completeSetWithData(weight: Double, reps: Int) {
        self.currentWeight = weight
        self.currentReps = reps
        fire([
            "type": "complete_set_with_data",
            "weight": weight,
            "reps": reps,
            "set": currentSet,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    /// Pausenzeit auf der Watch vorzeitig beenden.
    public func skipRestPause() {
        fire([
            "type": "skip_rest",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    /// Das ganze Training von der Uhr aus beenden.
    public func requestEndWorkout() {
        fire([
            "type": "end_workout",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    /*
      Das iPhone nach dem aktuellen Stand fragen.

      Zwei Wege, weil beide für sich lückenhaft sind: `sendMessage` weckt die
      iOS-App auch aus dem Hintergrund, kommt aber nur an, wenn die Gegenstelle
      gerade erreichbar ist. Ist sie das nicht, hilft der zuletzt hinterlegte
      Kontext — der liegt lokal und braucht die Gegenstelle gar nicht.
    */
    public func requestState() {
        applyStoredContext()
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(
            ["type": "request_state", "timestamp": Date().timeIntervalSince1970],
            replyHandler: nil,
            errorHandler: nil
        )
    }
    #endif

    public func completeSetRemotely() {
        fire(["type": "complete_set", "timestamp": Date().timeIntervalSince1970])
    }

    /// Bittet die Gegenstelle, Pause/Fortsetzen umzuschalten. Autorität über
    /// `isPaused` bleibt beim iPhone, genau wie bei Übung, Satz und der Pause
    /// zwischen Sätzen — die Uhr fragt nur an, sie setzt den Zustand nie
    /// selbst.
    public func requestPauseToggle() {
        fire(["type": "toggle_pause", "timestamp": Date().timeIntervalSince1970])
    }

    // MARK: - Empfangen

    func apply(_ message: [String: Any]) {
        let block = {
            switch message["type"] as? String {
            case "workout_update":
                self.isLiveSessionActive = true
                if let v = message["exercise"] as? String { self.currentExercise = v }
                if let v = message["set"] as? Int { self.currentSet = v }
                if let v = message["totalSets"] as? Int { self.totalSets = v }
                if let v = message["weight"] as? Double { self.currentWeight = v }
                if let v = message["reps"] as? Int { self.currentReps = v }
                if let v = message["targetReps"] as? String { self.targetReps = v }
                if let v = message["restDurationSeconds"] as? Int { self.restDurationSeconds = v }
                if let v = message["isRest"] as? Bool { self.isResting = v }
                if let v = message["isPaused"] as? Bool { self.isPaused = v }
                if let v = message["sessionStartedAt"] as? TimeInterval {
                    self.sessionStartedAt = Date(timeIntervalSince1970: v)
                }
                self.restEndsAt = (message["restEndsAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))

            case "workout_end":
                self.isLiveSessionActive = false
                self.currentExercise = ""
                self.currentSet = 0
                self.totalSets = 0
                self.isResting = false
                self.restEndsAt = nil
                self.isPaused = false
                self.sessionStartedAt = nil

            case "complete_set_with_data":
                let w = message["weight"] as? Double ?? self.currentWeight
                let r = message["reps"] as? Int ?? self.currentReps
                self.currentWeight = w
                self.currentReps = r
                if let handler = self.onSetCompletedWithDataRemotely {
                    handler(w, r)
                } else {
                    self.onSetCompletedRemotely?()
                }

            case "skip_rest":
                self.onSkipRestRequestedRemotely?()

            case "end_workout":
                self.onEndWorkoutRequestedRemotely?()

            case "request_state":
                /*
                  Die Uhr fragt. Läuft gerade ein Training, schickt die
                  Live-Ansicht ihren vollen Stand; läuft keins, muss die Uhr das
                  ausdrücklich erfahren — sonst zeigt sie den letzten Stand
                  eines längst beendeten Trainings weiter an.
                */
                #if os(iOS)
                if let handler = self.onStateRequestedRemotely {
                    handler()
                } else {
                    self.endLiveSession()
                }
                #endif

            case "complete_set":
                self.onSetCompletedRemotely?()

            case "toggle_pause":
                self.onPauseToggleRequestedRemotely?()

            case "measurements":
                #if os(iOS)
                if let bpm = message["bpm"] as? Int {
                    self.watchHeartRate = bpm
                    self.watchSampleDate = Date()
                }
                if let kcal = message["kcal"] as? Double {
                    self.watchActiveCalories = kcal
                    self.watchSampleDate = Date()
                }
                #endif

            default:
                break
            }
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
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
            #else
            // Frisch gestartete Uhr: erst den hinterlegten Stand, dann fragen.
            self.applyStoredContext()
            self.requestState()
            #endif
        }
    }

    /*
      Erreichbarkeit hat gewechselt.

      Der Moment, in dem die Verbindung zurückkommt, ist genau der, in dem
      beide Seiten auseinanderliegen können. Bisher wurde hier nur ein Flag
      gesetzt und sonst nichts — der Stand blieb so lange falsch, bis auf dem
      iPhone zufällig etwas passierte. Jetzt gleicht jede Seite von sich aus ab:
      das iPhone schiebt seinen Stand nach, die Uhr fragt danach.
    */
    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isCounterpartReachable = session.isReachable
            guard session.isReachable else { return }
            #if os(iOS)
            if self.isLiveSessionActive { self.onStateRequestedRemotely?() }
            #else
            self.requestState()
            #endif
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
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
