import Foundation
import SwiftUI

/*
  In App.jsx liegen Split, Anzahl, Methode und Pause auf oberster Ebene und
  werden BEIDEN Tabs übergeben — dem Generator und dem Trainingsplan. Wer im
  Generator "Push" wählt, bekommt im Trainingsplan Push-Tage.

  Zwei Dinge sind gegenüber der ersten Fassung anders:

  1. Der gewürfelte Plan liegt jetzt hier, nicht als @State in GeneratorView.
     SwiftUI wirft @State weg, sobald die View aus der Hierarchie fällt — beim
     Tabwechsel also. Wer gewürfelt hat, in den Trainingsplan schaute und
     zurückkam, stand wieder vor „Noch kein Plan gewürfelt“. Denselben Fehler
     hatte der KI-Assistent, dort wurde er mit AICoachSession behoben.

  2. Alles wird gespeichert. Im Web hängen diese Werte an usePersistentState
     und überleben das Schließen des Browsers; nativ waren sie nach jedem
     Neustart wieder auf den Vorgabewerten.
*/
public final class GeneratorSettings: ObservableObject {
    public static let shared = GeneratorSettings()

    private static let storageKey = "kraftwuerfel:generator"

    // Startwerte wie in App.jsx
    @Published public var split: SplitType = .fullBody          { didSet { save() } }
    @Published public var customCats: Set<MuscleCategory> = [.chest, .back] { didSet { save() } }
    @Published public var count: Int = 6                        { didSet { save() } }
    @Published public var method: TrainingMethod = .standard    { didSet { save() } }
    @Published public var restTime: Int = 60                    { didSet { save() } }

    /// Der zuletzt gewürfelte Plan und der Name im Speichern-Feld.
    @Published public var plan: [ExerciseSlot] = []             { didSet { save() } }
    @Published public var planName: String = ""                 { didSet { save() } }

    private var loading = false

    private init() { load() }

    /// `activeCategories` aus App.jsx: bei "Eigene" die angehakten Gruppen,
    /// sonst die Liste des Splits.
    public var activeCategories: [MuscleCategory] {
        split == .custom
            ? ExerciseDatabase.categories.filter { customCats.contains($0) }
            : (split.categories ?? [])
    }

    public func toggleCustomCat(_ c: MuscleCategory) {
        if customCats.contains(c) { customCats.remove(c) } else { customCats.insert(c) }
    }

    // MARK: - Speichern

    private struct Snapshot: Codable {
        var split: SplitType
        var customCats: [MuscleCategory]
        var count: Int
        var method: TrainingMethod
        var restTime: Int
        var plan: [ExerciseSlot]
        var planName: String
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(
            split: split, customCats: Array(customCats), count: count,
            method: method, restTime: restTime, plan: plan, planName: planName
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        // Während des Ladens nicht bei jedem Feld zurückschreiben.
        loading = true
        split = s.split
        customCats = Set(s.customCats)
        count = s.count
        method = s.method
        restTime = s.restTime
        plan = s.plan
        planName = s.planName
        loading = false
    }
}
