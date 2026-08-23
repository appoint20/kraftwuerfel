import Foundation
import HealthKit
import SwiftUI

@Observable
public final class HealthKitManager {
    public static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    
    public var currentHeartRate: Double = 124.0
    public var peakHeartRate: Double = 124.0
    public var activeCaloriesBurned: Double = 0.0
    public var isAuthorized: Bool = false
    public var isStreaming: Bool = false
    
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    public init() {}
    
    public func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            await MainActor.run { self.isAuthorized = true }
            return true
        } catch {
            print("HealthKit Auth Error: \(error.localizedDescription)")
            return false
        }
    }
    
    public func startWorkoutSession() {
        guard isAvailable && isAuthorized else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if success {
                    Task { @MainActor in
                        self.isStreaming = true
                    }
                }
            }
        } catch {
            print("Failed to start HK workout: \(error)")
        }
    }
    
    public func endWorkoutSession(totalVolumeKg: Double) async {
        guard let session = workoutSession, let b = builder else { return }
        
        session.end()
        do {
            try await b.endCollection(withEnd: Date())
            _ = try await b.finishWorkout()
            await MainActor.run {
                self.isStreaming = false
            }
        } catch {
            print("Error ending workout: \(error)")
        }
    }
}
