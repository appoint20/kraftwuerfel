import Foundation
import WatchConnectivity
import Combine

public final class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSyncManager()
    
    @Published public var isWatchPaired: Bool = false
    @Published public var isWatchAppInstalled: Bool = false
    @Published public var lastReceivedBpm: Double = 0.0
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func sendLiveWorkoutState(exerciseName: String, setIndex: Int, totalSets: Int, restRemaining: Int) {
        guard WCSession.isSupported() && WCSession.default.isReachable else { return }
        
        let payload: [String: Any] = [
            "type": "workout_update",
            "exercise": exerciseName,
            "setIndex": setIndex,
            "totalSets": totalSets,
            "restRemaining": restRemaining,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let bpm = message["bpm"] as? Double {
            DispatchQueue.main.async {
                self.lastReceivedBpm = bpm
            }
        }
    }
}
