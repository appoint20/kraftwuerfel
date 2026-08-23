import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var setNumber: Int
        public var totalSets: Int
        public var isResting: Bool
        public var restTargetDate: Date?
        public var heartRate: Double
        
        public init(
            exerciseName: String,
            setNumber: Int,
            totalSets: Int,
            isResting: Bool = false,
            restTargetDate: Date? = nil,
            heartRate: Double = 0.0
        ) {
            self.exerciseName = exerciseName
            self.setNumber = setNumber
            self.totalSets = totalSets
            self.isResting = isResting
            self.restTargetDate = restTargetDate
            self.heartRate = heartRate
        }
    }
    
    public var planTitle: String
    
    public init(planTitle: String) {
        self.planTitle = planTitle
    }
}
#endif

public final class ActivityKitManager {
    public static let shared = ActivityKitManager()
    
    #if canImport(ActivityKit)
    private var currentActivity: Any? // Activity<WorkoutActivityAttributes>?
    #endif
    
    private init() {}
    
    public func startWorkoutActivity(exerciseName: String, setNumber: Int, totalSets: Int, planTitle: String) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            
            let attributes = WorkoutActivityAttributes(planTitle: planTitle)
            let initialState = WorkoutActivityAttributes.ContentState(
                exerciseName: exerciseName,
                setNumber: setNumber,
                totalSets: totalSets,
                isResting: false
            )
            
            do {
                let activity = try Activity<WorkoutActivityAttributes>.request(
                    attributes: attributes,
                    contentState: initialState,
                    pushType: nil
                )
                self.currentActivity = activity
            } catch {
                print("Failed to start Live Activity: \(error)")
            }
        }
        #endif
    }
    
    public func updateActiveSet(exerciseName: String, setNumber: Int, totalSets: Int) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else { return }
            let state = WorkoutActivityAttributes.ContentState(
                exerciseName: exerciseName,
                setNumber: setNumber,
                totalSets: totalSets,
                isResting: false
            )
            Task {
                await activity.update(using: state)
            }
        }
        #endif
    }
    
    public func updateRestTimer(exerciseName: String, setNumber: Int, restTargetDate: Date) {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else { return }
            let state = WorkoutActivityAttributes.ContentState(
                exerciseName: exerciseName,
                setNumber: setNumber,
                totalSets: activity.contentState.totalSets,
                isResting: true,
                restTargetDate: restTargetDate
            )
            Task {
                await activity.update(using: state)
            }
        }
        #endif
    }
    
    public func endWorkoutActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            guard let activity = currentActivity as? Activity<WorkoutActivityAttributes> else { return }
            Task {
                await activity.end(using: nil, dismissalPolicy: .immediate)
                self.currentActivity = nil
            }
        }
        #endif
    }
}
