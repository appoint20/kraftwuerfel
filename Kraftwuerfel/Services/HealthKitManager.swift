import Combine
import Foundation
import HealthKit

/*
  Apple Health auf dem iPhone — ausschließlich lesend.

  Die vorherige Fassung war der Ablehnungsgrund: `startWorkoutSession()` setzte
  den Puls auf 125 und addierte jede Sekunde `Double.random(in: -2...2)`, die
  Kalorien liefen mit einer festen Rate mit. Das sah aus wie eine Messung, war
  aber eine Erfindung — und die Klasse forderte dazu Schreibrechte für aktive
  Energie und Workouts an, also genau die Rechte, mit denen man solche Zahlen
  in Apple Health hinterlegt.

  Zwei Dinge sind deshalb anders:

  1. Hier wird nichts mehr erfunden. `liveHeartRate` ist entweder ein echter
     Messwert oder `nil`. Die Schätzung, die die Live-Ansicht anzeigt, bleibt
     dort, wo sie hingehört: sichtbar als Schätzung, in der Ansicht.

  2. Hier wird nichts mehr geschrieben. Das iPhone kann keine
     `HKWorkoutSession` führen — nur watchOS kann das. Also speichert die Uhr
     das Training (mit echten Sensorwerten), und das iPhone liest höchstens
     mit. Siehe WatchWorkoutManager im watchOS-Ziel.
*/
public final class HealthKitManager: ObservableObject {

    public static let shared = HealthKitManager()

    public enum Availability {
        /// Gerät ohne Health (z. B. iPad ohne Health-App).
        case unavailable
        /// Noch nicht gefragt.
        case notDetermined
        /// Gefragt — ob Lesen erlaubt wurde, verrät HealthKit absichtlich
        /// nicht. Ob wirklich Werte kommen, zeigt sich erst an `liveHeartRate`.
        case requested
    }

    @Published public private(set) var availability: Availability =
        HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable

    /// Echter Puls aus Apple Health — in der Praxis das, was die gekoppelte
    /// Apple Watch während des Trainings schreibt. `nil` heißt: nichts da.
    @Published public private(set) var liveHeartRate: Int?
    @Published public private(set) var liveHeartRateDate: Date?

    private let store = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    /// Ein Messwert gilt zehn Sekunden — danach lieber nichts zeigen.
    public static let sampleValidity: TimeInterval = 10

    private init() {}

    /// Der zuletzt gelesene Puls, sofern er noch frisch genug ist.
    public var freshHeartRate: Int? {
        guard let liveHeartRate, let liveHeartRateDate,
              Date().timeIntervalSince(liveHeartRateDate) < Self.sampleValidity
        else { return nil }
        return liveHeartRate
    }

    // MARK: - Erlaubnis

    /*
      Nur Lesen, und nur Herzfrequenz. Aktive Energie und Workouts standen
      früher als Schreibrechte in der Anfrage, ohne dass je etwas geschrieben
      wurde — ungenutzte Rechte fallen in der Prüfung auf und sind
      gegenüber dem Nutzer nicht zu rechtfertigen.
    */
    @discardableResult
    public func requestReadAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else {
            availability = .unavailable
            return false
        }

        do {
            try await store.requestAuthorization(toShare: [], read: [heartRate])
            await MainActor.run { self.availability = .requested }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Mitlesen

    /// Beobachtet die Herzfrequenz ab `start`. Kommt keine Uhr mit, bleibt
    /// `liveHeartRate` schlicht `nil` — und der Aufrufer weiß, dass er nichts
    /// Echtes anzuzeigen hat.
    public func startObservingHeartRate(from start: Date) {
        guard availability == .requested,
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate)
        else { return }

        stopObservingHeartRate()

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: nil,
            options: [.strictStartDate]
        )

        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            [weak self] _, samples, _, _, _ in
            guard let self,
                  let latest = (samples as? [HKQuantitySample])?
                      .max(by: { $0.startDate < $1.startDate })
            else { return }

            let bpm = latest.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            DispatchQueue.main.async {
                self.liveHeartRate = Int(bpm.rounded())
                self.liveHeartRateDate = latest.startDate
            }
        }

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler

        heartRateQuery = query
        store.execute(query)
    }

    public func stopObservingHeartRate() {
        if let heartRateQuery {
            store.stop(heartRateQuery)
        }
        heartRateQuery = nil
        liveHeartRate = nil
        liveHeartRateDate = nil
    }
}
