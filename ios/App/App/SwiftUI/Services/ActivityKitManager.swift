import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

public final class ActivityKitManager {
    public static let shared = ActivityKitManager()
    
    private init() {}
    
    public func startLiveWorkoutActivity(workoutTitle: String, exerciseName: String, currentSet: Int, totalSets: Int) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            // Live Activity notification trigger
            print("Starting Live Activity for \(workoutTitle): \(exerciseName) (Set \(currentSet)/\(totalSets))")
        }
        #endif
    }
    
    public func endLiveWorkoutActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            print("Ending Live Activity")
        }
        #endif
    }
}
