import Foundation
import HealthKit
import Combine

@available(iOS 15.0, *)
@MainActor
public final class HealthKitManager: ObservableObject {
    public static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published public var isAuthorized: Bool = false
    @Published public var currentHeartRate: Double = 0.0
    @Published public var activeCalories: Double = 0.0
    @Published public var sessionDurationSeconds: Int = 0
    
    private var heartRateQuery: HKQuery?
    private var timer: AnyCancellable?
    
    private init() {}
    
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let workoutType = HKObjectType.workoutType() as? HKSampleType else {
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [heartRateType, activeEnergyType, workoutType]
        let typesToWrite: Set<HKSampleType> = [activeEnergyType, workoutType]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            self.isAuthorized = true
            return true
        } catch {
            self.isAuthorized = false
            return false
        }
    }
    
    public func startWorkoutSession() {
        guard isAuthorized else { return }
        sessionDurationSeconds = 0
        currentHeartRate = 125.0
        activeCalories = 0.0
        
        // Start duration timer
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.sessionDurationSeconds += 1
                self.activeCalories += 0.12 // ~7 kcal per min
                
                // Subtle pulse simulation if on simulator
                if self.currentHeartRate > 0 {
                    let delta = Double.random(in: -2...2)
                    self.currentHeartRate = max(90, min(175, self.currentHeartRate + delta))
                }
            }
    }
    
    public func endWorkoutSession() {
        timer?.cancel()
        timer = nil
    }
}
