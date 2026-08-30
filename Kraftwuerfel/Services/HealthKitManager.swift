import Combine
import Foundation
import HealthKit

/*
  Apple Health auf dem iPhone.

  Die allererste Fassung war ein Ablehnungsgrund: `startWorkoutSession()`
  setzte den Puls auf 125 und addierte jede Sekunde `Double.random(in: -2...2)`,
  die Kalorien liefen mit einer festen Rate mit. Das sah aus wie eine Messung,
  war aber eine Erfindung — und die Klasse forderte dazu Schreibrechte an,
  also genau die Rechte, mit denen man solche Zahlen in Health hinterlegt.

  Daraus folgt die Regel, die hier über allem steht und die auch beim
  Wiedereinführen der Schreibrechte gilt:

      Geschrieben wird ausschließlich, was gemessen oder vom Nutzer selbst
      eingetragen wurde. Nie ein Schätzwert.

  Konkret heißt das:

  - **Gewicht und Körperfettanteil** trägt der Nutzer im Profil ein. Das sind
    seine eigenen Angaben, und sie dürfen nach Health.
  - **Trainings und aktive Energie** schreibt die Uhr, weil sie misst
    (WatchWorkoutManager). Das iPhone schreibt eine Einheit nur mit echter
    Dauer, und Energie nur dann, wenn sie von der Uhr kam —
    `saveWorkout` nimmt gar keinen geschätzten Wert entgegen.
  - **Puls** wird nur gelesen. `liveHeartRate` ist entweder ein echter
    Messwert oder `nil`; die Schätzung der Live-Ansicht bleibt dort, wo sie
    hingehört: sichtbar als Schätzung, in der Ansicht.
*/
public final class HealthKitManager: ObservableObject {

    public static let shared = HealthKitManager()

    public enum Availability {
        /// Gerät ohne Health (z. B. iPad ohne Health-App).
        case unavailable
        /// Noch nicht gefragt.
        case notDetermined
        /// Gefragt — ob Lesen erlaubt wurde, verrät HealthKit absichtlich
        /// nicht. Ob wirklich Werte kommen, zeigt sich erst an den Daten.
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

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Typen

    private static var shareTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(t) }
        types.insert(HKObjectType.workoutType())
        return types
    }

    private static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyMass) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .height) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(t) }
        if let t = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(t) }
        if let t = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { types.insert(t) }
        types.insert(HKObjectType.workoutType())
        return types
    }

    // MARK: - Erlaubnis

    /*
      Der eine Aufruf, der Apples Berechtigungsblatt zeigt. Lesen und
      Schreiben stehen gemeinsam darin — Health fragt nur einmal, und ein
      zweiter Aufruf für die zweite Hälfte würde dem Nutzer dasselbe Blatt
      ein zweites Mal zeigen.
    */
    @discardableResult
    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            await MainActor.run { self.availability = .unavailable }
            return false
        }

        do {
            try await store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
            await MainActor.run { self.availability = .requested }
            return true
        } catch {
            return false
        }
    }

    /// Alter Name, damit bestehende Aufrufer (Live-Session) unverändert bleiben.
    @discardableResult
    public func requestReadAuthorization() async -> Bool {
        await requestAuthorization()
    }

    // MARK: - Körperdaten lesen

    /// Was Health über den Nutzer weiß, soweit er es freigegeben hat.
    /// Jedes Feld einzeln optional: Health gibt oft nur einen Teil frei, und
    /// eine fehlende Angabe ist kein Fehler.
    public struct BodyMetrics: Equatable {
        public var weightKg: Double?
        public var heightCm: Double?
        public var bodyFatPercent: Double?
        public var age: Int?
        public var sex: String?

        public var isEmpty: Bool {
            weightKg == nil && heightCm == nil && bodyFatPercent == nil && age == nil && sex == nil
        }
    }

    /*
      Füllt den Fragebogen vor, statt den Nutzer eintippen zu lassen, was sein
      Telefon längst weiß. Fehlt ein Wert oder ist er nicht freigegeben,
      bleibt das Feld auf seinem Standard — es wird nichts geraten.
    */
    public func readBodyMetrics() async -> BodyMetrics {
        guard HKHealthStore.isHealthDataAvailable() else { return BodyMetrics() }

        var result = BodyMetrics()

        if let kg = await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) {
            result.weightKg = (kg * 10).rounded() / 10
        }
        if let cm = await latestQuantity(.height, unit: .meterUnit(with: .centi)) {
            result.heightCm = cm.rounded()
        }
        if let fraction = await latestQuantity(.bodyFatPercentage, unit: .percent()) {
            result.bodyFatPercent = (fraction * 1000).rounded() / 10
        }

        // Merkmale sind synchron und werfen, wenn sie nicht freigegeben sind.
        if let dob = try? store.dateOfBirthComponents(),
           let date = Calendar.current.date(from: dob),
           let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year,
           years > 0, years < 120 {
            result.age = years
        }
        if let biological = try? store.biologicalSex().biologicalSex {
            switch biological {
            case .male:   result.sex = "male"
            case .female: result.sex = "female"
            case .other:  result.sex = "other"
            default:      break
            }
        }

        return result
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = (samples as? [HKQuantitySample])?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Körperdaten schreiben

    /*
      Nur eigene Angaben des Nutzers. Aufgerufen wird das aus dem Profil,
      wenn er sein Gewicht dort ändert — nicht aus einer Berechnung.
    */
    public func writeBodyMass(kilograms: Double, date: Date = Date()) async {
        guard HKHealthStore.isHealthDataAvailable(), kilograms > 0,
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)
        else { return }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }

    public func writeBodyFat(percent: Double, date: Date = Date()) async {
        guard HKHealthStore.isHealthDataAvailable(), percent > 0, percent < 100,
              let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        else { return }

        let quantity = HKQuantity(unit: .percent(), doubleValue: percent / 100)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try? await store.save(sample)
    }

    // MARK: - Training schreiben

    /*
      Eine abgeschlossene Einheit nach Health.

      `measuredActiveEnergyKcal` ist bewusst optional und heißt „gemessen“:
      Übergeben wird ausschließlich, was die Uhr gemessen hat. Die Schätzung
      der Live-Ansicht hat hier keinen Weg hinein — genau dafür wurde die
      alte Fassung abgelehnt.

      Läuft die Uhr mit, schreibt sie die Einheit selbst
      (WatchWorkoutManager). Dieser Weg ist für Sitzungen ohne Uhr da, und er
      trägt dann eben nur Dauer und Zeitraum, keine Energie.
    */
    public func saveWorkout(
        start: Date,
        end: Date,
        measuredActiveEnergyKcal: Double? = nil
    ) async {
        guard HKHealthStore.isHealthDataAvailable(), end > start else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)

            if let kcal = measuredActiveEnergyKcal, kcal > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
                let sample = HKCumulativeQuantitySample(
                    type: energyType,
                    quantity: quantity,
                    start: start,
                    end: end
                )
                try await builder.addSamples([sample])
            }

            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Health kann die Einheit ablehnen (keine Erlaubnis). Das Training
            // selbst ist dadurch nicht ungültig — es steht weiter im
            // Trainingsarchiv der App.
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
