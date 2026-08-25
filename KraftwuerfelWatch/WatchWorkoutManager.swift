import Combine
import Foundation
import HealthKit

/*
  Die laufende Trainingseinheit auf der Uhr.

  Das hier ist der Grund, warum es ein watchOS-Ziel braucht. `HKWorkoutSession`
  gibt es nur auf watchOS. Sie bewirkt drei Dinge, die vom iPhone aus
  unerreichbar sind:

    - Die Uhr misst durchgehend den Puls, statt nur gelegentlich.
    - Das Training erscheint in der Fitness-App als „Krafttraining“, solange es
      läuft — nicht erst hinterher.
    - Die Ringe füllen sich mit, weil aktive Energie laufend eingeht.

  Vom iPhone ließe sich allenfalls ein fertiges Workout nachträglich ablegen.
  Deshalb speichert die Uhr, und nur die Uhr — und was gespeichert wird, sind
  ausschließlich Sensorwerte. Geschätztes gehört nicht nach Apple Health.
*/
public final class WatchWorkoutManager: NSObject, ObservableObject {

    public static let shared = WatchWorkoutManager()

    @Published public private(set) var isRunning = false
    /// Echter Puls vom Sensor. `nil`, solange die erste Messung aussteht.
    @Published public private(set) var heartRate: Int?
    @Published public private(set) var activeCalories: Double = 0
    @Published public private(set) var startDate: Date?
    @Published public private(set) var lastError: String?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() { super.init() }

    // MARK: - Erlaubnis

    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            return false
        }
    }

    // MARK: - Start & Ende

    public func start() {
        guard session == nil, HKHealthStore.isHealthDataAvailable() else { return }

        let configuration = HKWorkoutConfiguration()
        // Genau das zeigt die Fitness-App später als „Krafttraining“ an.
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: store,
                workoutConfiguration: configuration
            )
            session.delegate = self
            builder.delegate = self

            let start = Date()
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] ok, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if ok {
                        self.isRunning = true
                        self.startDate = start
                    } else {
                        self.lastError = error?.localizedDescription
                        self.teardown()
                    }
                }
            }

            self.session = session
            self.builder = builder
        } catch {
            DispatchQueue.main.async { self.lastError = error.localizedDescription }
        }
    }

    /// Beendet die Einheit und legt sie in Apple Health ab. Der eigentliche
    /// Abschluss passiert in `workoutSession(_:didChangeTo:)`, sobald die
    /// Sitzung wirklich beendet ist.
    public func end() {
        guard let session else { return }
        session.end()
    }

    private func finishAndSave() {
        guard let builder else {
            DispatchQueue.main.async { self.teardown() }
            return
        }

        builder.endCollection(withEnd: Date()) { [weak self] _, _ in
            builder.finishWorkout { _, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let error { self.lastError = error.localizedDescription }
                    self.teardown()
                }
            }
        }
    }

    private func teardown() {
        session = nil
        builder = nil
        isRunning = false
        heartRate = nil
        activeCalories = 0
        startDate = nil
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {

    public func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        finishAndSave()
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.lastError = error.localizedDescription
            self.teardown()
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {

    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    public func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var newHeartRate: Int?
        var newCalories: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType)
            else { continue }

            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let unit = HKUnit.count().unitDivided(by: .minute())
                if let bpm = statistics.mostRecentQuantity()?.doubleValue(for: unit) {
                    newHeartRate = Int(bpm.rounded())
                }

            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                if let kcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    newCalories = kcal
                }

            default:
                break
            }
        }

        guard newHeartRate != nil || newCalories != nil else { return }

        DispatchQueue.main.async {
            if let newHeartRate { self.heartRate = newHeartRate }
            if let newCalories { self.activeCalories = newCalories }

            // Nur echte Messwerte gehen ans iPhone. Die Live-Ansicht dort
            // wechselt damit von „geschätzt“ auf „Apple Watch“.
            WatchSyncManager.shared.sendMeasurements(
                heartRate: self.heartRate,
                activeCalories: self.activeCalories
            )
        }
    }
}
