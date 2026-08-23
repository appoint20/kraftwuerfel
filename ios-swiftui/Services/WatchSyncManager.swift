import Foundation
import WatchConnectivity
import SwiftUI

@Observable
public final class WatchSyncManager: NSObject, WCSessionDelegate {
    public static let shared = WatchSyncManager()
    
    public var isWatchPaired: Bool = false
    public var isWatchAppInstalled: Bool = false
    public var lastReceivedMessage: [String: Any] = [:]
    
    public override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    public func sendLiveWorkoutState(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        weightKg: Double,
        reps: Int,
        isResting: Bool,
        restSecondsRemaining: Int,
        calories: Int,
        heartRate: Int
    ) {
        guard WCSession.default.isReachable else { return }
        
        let payload: [String: Any] = [
            "type": "WORKOUT_STATE",
            "exercise": exerciseName,
            "set": setNumber,
            "totalSets": totalSets,
            "weight": weightKg,
            "reps": reps,
            "isResting": isResting,
            "restRemaining": restSecondsRemaining,
            "calories": calories,
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("WatchSync Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
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
    
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.lastReceivedMessage = message
        }
    }
}
