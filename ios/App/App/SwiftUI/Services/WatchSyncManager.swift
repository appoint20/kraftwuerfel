import Foundation
import WatchConnectivity
import Combine

public final class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncManager()
    
    @Published public var isWatchPaired: Bool = false
    @Published public var isWatchAppInstalled: Bool = false
    @Published public var lastReceivedBpm: Double = 0.0
    
    // Live Workout Sync State
    @Published public var isLiveSessionActive: Bool = false
    @Published public var isResting: Bool = false
    @Published public var restSecondsRemaining: Int = 0
    @Published public var currentExercise: String = ""
    @Published public var currentSet: Int = 1
    @Published public var totalSets: Int = 3
    
    public var onSetCompletedOnWatch: (() -> Void)?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func sendWorkoutUpdate(
        exercise: String,
        set: Int,
        totalSets: Int,
        isRest: Bool,
        restSecondsRemaining: Int
    ) {
        self.currentExercise = exercise
        self.currentSet = set
        self.totalSets = totalSets
        self.isResting = isRest
        self.restSecondsRemaining = restSecondsRemaining
        self.isLiveSessionActive = true
        
        guard WCSession.isSupported() && WCSession.default.isReachable else { return }
        
        let payload: [String: Any] = [
            "type": "workout_update",
            "exercise": exercise,
            "set": set,
            "totalSets": totalSets,
            "isRest": isRest,
            "restSecondsRemaining": restSecondsRemaining,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    public func completeSetOnWatch() {
        if WCSession.isSupported() && WCSession.default.isReachable {
            WCSession.default.sendMessage(["type": "complete_set"], replyHandler: nil, errorHandler: nil)
        }
        DispatchQueue.main.async {
            self.onSetCompletedOnWatch?()
        }
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            #if os(iOS)
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                if type == "workout_update" {
                    self.isLiveSessionActive = true
                    if let ex = message["exercise"] as? String { self.currentExercise = ex }
                    if let s = message["set"] as? Int { self.currentSet = s }
                    if let ts = message["totalSets"] as? Int { self.totalSets = ts }
                    if let ir = message["isRest"] as? Bool { self.isResting = ir }
                    if let r = message["restSecondsRemaining"] as? Int { self.restSecondsRemaining = r }
                } else if type == "complete_set" {
                    self.onSetCompletedOnWatch?()
                }
            }
            if let bpm = message["bpm"] as? Double {
                self.lastReceivedBpm = bpm
            }
        }
    }
}
