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
    @Published public var split: SplitType = .fullBody {
        didSet {
            if split == .legs && method == .legsFocus {
                method = .standard
            }
            save()
        }
    }
    @Published public var customCats: Set<MuscleCategory> = [.chest, .back] { didSet { save() } }

    /*
      Die selbst gewählten Übungen für den Split „Eigene".

      Vorher hieß „Eigene" nur: eigene Muskelgruppen ankreuzen und dann
      würfeln lassen. Welche Übungen dabei herauskamen, entschied weiter der
      Zufall. Wer genau wusste, was er machen will, hatte keinen Weg dorthin.

      Die Reihenfolge zählt — sie ist die Reihenfolge im Trainingsplan.
      Deshalb ein Array und kein Set.
    */
    @Published public var customExercises: [Exercise] = [] {
        didSet {
            syncCustomCategoriesFromExercises()
            save()
        }
    }
    @Published public var count: Int = 6 {
        didSet {
            trimCustomExercisesToLimit()
            save()
        }
    }
    @Published public var method: TrainingMethod = .standard {
        didSet {
            if split == .legs && method == .legsFocus {
                method = .standard
            }
            save()
        }
    }
    @Published public var restTime: Int = 60                    { didSet { save() } }

    /*
      Wie viele Zyklen ein Plan bekommt.

      Vorher rechnete das allein `PlanGenerator.cyclesForDuration` aus der
      Planlänge aus — 4 Wochen ergaben 2 Zyklen, 12 Wochen 6, ohne dass der
      Nutzer etwas dazu sagen durfte. Wer bewusst jede Woche dasselbe
      trainieren wollte (oder umgekehrt strikt zwei abwechselnde Wochen),
      hatte keinen Weg dorthin.
    */
    @Published public var cycleMode: CycleMode = .auto          { didSet { save() } }

    /// Der zuletzt gewürfelte Plan und der Name im Speichern-Feld.
    @Published public var plan: [ExerciseSlot] = []             { didSet { save() } }
    @Published public var planName: String = ""                 { didSet { save() } }

    /*
      Studio-Generator oder Home-Challenge — aus demselben Grund hier wie der
      Plan darüber: Als @State in GeneratorView war die Wahl beim nächsten
      Tabwechsel weg. Wer mitten in der Challenge steckt, landete beim
      Zurückkommen wieder im Studio-Generator.
    */
    @Published public var mode: GeneratorMode = .challenge      { didSet { save() } }

    /*
      Der Entwurf des selbstgebauten Plans.

      Aus demselben Grund hier wie der gewürfelte Plan darüber: Wer zehn
      Übungen zusammengesucht hat und kurz in den Trainingsplan schaut, darf
      sie beim Zurückkommen nicht verloren haben.
    */
    @Published public var builderSlots: [ExerciseSlot] = []     { didSet { save() } }
    @Published public var builderName: String = ""              { didSet { save() } }

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

    // MARK: - Eigene Übungen

    /// Wie viele Übungen unter „Eigene" höchstens gewählt werden dürfen —
    /// genau die Zahl aus „Anzahl Übungen".
    public var customExerciseLimit: Int { count }

    public var customExerciseNames: Set<String> {
        Set(customExercises.map(\.name))
    }

    public var isCustomSelectionFull: Bool {
        customExercises.count >= customExerciseLimit
    }

    /*
      An- und abwählen. Über der Obergrenze passiert nichts — die Grenze wird
      hier durchgesetzt und nicht nur in der Ansicht, damit sie auch gilt,
      wenn später ein zweiter Aufrufer dazukommt.

      Rückgabe sagt, ob die Auswahl sich geändert hat; die Ansicht kann daran
      eine Rückmeldung hängen.
    */
    @discardableResult
    public func toggleCustomExercise(_ exercise: Exercise) -> Bool {
        if let index = customExercises.firstIndex(where: { $0.name == exercise.name }) {
            customExercises.remove(at: index)
            return true
        }
        guard !isCustomSelectionFull else { return false }
        customExercises.append(exercise)
        return true
    }

    public func removeCustomExercise(at index: Int) {
        guard customExercises.indices.contains(index) else { return }
        customExercises.remove(at: index)
    }

    public func moveCustomExercise(from: Int, to: Int) {
        guard customExercises.indices.contains(from),
              customExercises.indices.contains(to), from != to else { return }
        let item = customExercises.remove(at: from)
        customExercises.insert(item, at: to)
    }

    /*
      Beim Verkleinern von „Anzahl Übungen" fallen die überzähligen hinten weg.

      Die Alternative wäre, eine Auswahl stehen zu lassen, die größer ist als
      das erlaubte Maximum — dann stimmte die Anzeige „7 / 5" nicht mehr, und
      beim Würfeln käme ein Plan heraus, der länger ist als bestellt.
    */
    public func trimCustomExercisesToLimit() {
        guard customExercises.count > customExerciseLimit else { return }
        customExercises = Array(customExercises.prefix(customExerciseLimit))
    }

    /*
      `customCats` bleibt die Wahrheit für alles andere im Programm — der
      Trainingsplan-Tab würfelt darüber seine Tage. Damit beide dasselbe
      meinen, folgen die Kategorien der Übungsauswahl, statt daneben ein
      zweites, widersprüchliches Bild zu führen.

      Ohne Auswahl bleibt die letzte Kategorienwahl stehen: Wer alle Übungen
      abwählt, soll nicht zusätzlich seine Kategorien verlieren.
    */
    private func syncCustomCategoriesFromExercises() {
        guard !customExercises.isEmpty else { return }
        var seen: Set<MuscleCategory> = []
        for exercise in customExercises {
            for category in exercise.categories where category != .fullBody {
                seen.insert(category)
            }
        }
        if !seen.isEmpty && seen != customCats {
            customCats = seen
        }
    }

    /*
      Zurück auf Werkseinstellung — für die Kontolöschung.

      `loading` steht dabei auf `true`, damit nicht jedes einzelne Feld über
      sein `didSet` eine Zwischenfassung zurückschreibt; erst am Ende fällt
      der Schlüssel als Ganzes weg.
    */
    public func wipe() {
        loading = true
        split = .fullBody
        customCats = [.chest, .back]
        customExercises = []
        count = 6
        method = .standard
        restTime = 60
        plan = []
        planName = ""
        mode = .challenge
        builderSlots = []
        builderName = ""
        loading = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Speichern

    private struct Snapshot: Codable {
        var split: SplitType
        var customCats: [MuscleCategory]
        var customExercises: [Exercise]?
        var count: Int
        var method: TrainingMethod
        var restTime: Int
        var plan: [ExerciseSlot]
        var planName: String
        /*
          Als Zeichenkette, nicht als GeneratorMode.

          Der Studio-Modus ist entfallen. Stünde hier der Aufzählungstyp,
          würfe der Decoder bei einem alten Stand mit dem Rohwert
          „generator" — und weil `load()` den ganzen Schnappschuss mit `try?`
          liest, wären damit ALLE Generator-Einstellungen weg: eigene
          Übungen, der Baukasten-Plan, die Zyklus-Wahl. Ein entfernter Tab
          darf nicht die Daten des Nutzers mitnehmen.
        */
        var mode: String?
        // Ältere Stände kennen die Zyklus-Wahl noch nicht.
        var cycleMode: CycleMode?
        var builderSlots: [ExerciseSlot]?
        var builderName: String?
    }

    private func save() {
        guard !loading else { return }
        let snapshot = Snapshot(
            split: split, customCats: Array(customCats), customExercises: customExercises, count: count,
            method: method, restTime: restTime, plan: plan, planName: planName,
            mode: mode.rawValue, cycleMode: cycleMode, builderSlots: builderSlots, builderName: builderName
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
        customExercises = s.customExercises ?? []
        count = s.count
        method = s.method
        restTime = s.restTime
        plan = s.plan
        planName = s.planName
        // Ein alter Stand kann „generator" tragen — den Tab gibt es nicht
        // mehr, also landet er auf der Home-Challenge statt im Nichts.
        mode = s.mode.flatMap(GeneratorMode.init(rawValue:)) ?? .challenge
        cycleMode = s.cycleMode ?? .auto
        builderSlots = s.builderSlots ?? []
        builderName = s.builderName ?? ""
        loading = false
    }
}

/*
  Ein Zyklus, zwei Zyklen, oder die App entscheidet.

  „Automatisch" ist das bisherige Verhalten und bleibt die Voreinstellung:
  aus der Planlänge gerechnet. Die beiden anderen sind die Antwort auf zwei
  Wünsche, die vorher nicht ausdrückbar waren — „jede Woche dasselbe" und
  „genau zwei Wochen im Wechsel".
*/
public enum CycleMode: String, CaseIterable, Identifiable, Codable {
    case auto
    case single
    case dual

    public var id: String { rawValue }

    /// Wie viele Zyklen daraus für eine Planlänge folgen.
    public func cycles(forDuration duration: Int) -> Int {
        switch self {
        case .auto:   return PlanGenerator.cyclesForDuration(duration)
        case .single: return 1
        case .dual:   return 2
        }
    }

    public var titleDe: String {
        switch self {
        case .auto:   return "Automatisch"
        case .single: return "Ein Zyklus"
        case .dual:   return "Zwei Zyklen"
        }
    }

    public var titleEn: String {
        switch self {
        case .auto:   return "Automatic"
        case .single: return "One cycle"
        case .dual:   return "Two cycles"
        }
    }

    public var subtitleDe: String {
        switch self {
        case .auto:   return "Aus der Planlänge gerechnet"
        case .single: return "Jede Woche derselbe Plan"
        case .dual:   return "Zwei Wochen im Wechsel"
        }
    }

    public var subtitleEn: String {
        switch self {
        case .auto:   return "Derived from plan length"
        case .single: return "Same plan every week"
        case .dual:   return "Two weeks alternating"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func localizedSubtitle(_ lang: String) -> String { lang == "en" ? subtitleEn : subtitleDe }
}

/// Die beiden Tabs über dem Würfel: Studio-Generator und Home-Challenge.
public enum GeneratorMode: String, CaseIterable, Identifiable, Codable {
    /*
      „generator" (der Studio-Würfel) ist entfallen — dieselbe Würfelstrecke
      steht im Trainingsplan, wo der Plan danach auch über Wochen weiterläuft.
      Der Rohwert bleibt in alten gespeicherten Ständen stehen; `load()` bildet
      ihn auf `.challenge` ab, damit niemand nach dem Update auf einem Tab
      landet, den es nicht mehr gibt.
    */
    case challenge = "challenge"
    /// Selbst zusammengestellt — Übung für Übung aus dem Katalog.
    case builder = "builder"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .challenge: return "flame.fill"
        case .builder:   return "square.and.pencil"
        }
    }

    public func title(_ lang: String) -> String {
        let en = lang == "en"
        switch self {
        case .challenge: return en ? "HOME" : "HOME"
        case .builder:   return en ? "CUSTOM" : "EIGENER"
        }
    }
}
