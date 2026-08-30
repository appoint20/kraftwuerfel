import Foundation

public struct ExerciseSlot: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let exercise: Exercise
    public var sets: Int
    public var reps: String
    public var restSeconds: Int
    public var note: String
    
    public init(exercise: Exercise, sets: Int = 3, reps: String = "4-8", restSeconds: Int = 60, note: String = "") {
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.note = note
    }
}

public struct WarmupExercise: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let name: String
    public let duration: String
    
    public init(name: String, duration: String) {
        self.name = name
        self.duration = duration
    }
}

public struct DayPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let weekday: String // "Mo", "Di", "Mi", etc.
    public let name: String    // "Titan", "Vulkan", etc.
    public let focus: String   // "Chest & Triceps", "Glutes & Legs"
    public let warmup: [WarmupExercise]
    public var cycle1Slots: [ExerciseSlot]
    public var cycle2Slots: [ExerciseSlot]
    
    public var slots: [ExerciseSlot] {
        get { cycle1Slots }
        set { cycle1Slots = newValue }
    }

    /*
      Ob dieser Tag überhaupt zwei unterschiedliche Zyklen hat.

      Hieß früher `hasTwoCycles` — derselbe Name wie die Eigenschaft am Plan,
      die inzwischen etwas anderes bedeutet (dort entscheidet zusätzlich der
      Schalter des Nutzers). Zwei Dinge gleich zu nennen, von denen eines das
      andere überstimmt, war die Sorte Verwechslung, die man erst im Debugger
      merkt.
    */
    public var hasDistinctCycles: Bool {
        guard !cycle2Slots.isEmpty else { return false }
        if cycle1Slots.map(\.id) == cycle2Slots.map(\.id) {
            return false
        }
        let c1Names = cycle1Slots.map { $0.exercise.name }
        let c2Names = cycle2Slots.map { $0.exercise.name }
        return c1Names != c2Names
    }

    @available(*, deprecated, renamed: "hasDistinctCycles")
    public var hasTwoCycles: Bool { hasDistinctCycles }

    /// Die Muskelgruppen, die dieser Tag tatsächlich trifft — Grundlage fürs
    /// Neumischen, weil `focus` ein Freitext des Modells ist und nicht zählbar.
    public func categories(forCycle cycle: Int = 1) -> [MuscleCategory] {
        var seen: [MuscleCategory] = []
        for slot in slots(forCycle: cycle) {
            for c in slot.exercise.categories where !seen.contains(c) {
                seen.append(c)
            }
        }
        return seen
    }
    
    public init(
        weekday: String,
        name: String,
        focus: String,
        warmup: [WarmupExercise] = [],
        cycle1Slots: [ExerciseSlot],
        cycle2Slots: [ExerciseSlot] = []
    ) {
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.warmup = warmup
        self.cycle1Slots = cycle1Slots
        self.cycle2Slots = cycle2Slots.isEmpty ? cycle1Slots : cycle2Slots
    }
    
    public init(weekday: String, name: String, focus: String, warmup: [WarmupExercise] = [], slots: [ExerciseSlot]) {
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.warmup = warmup
        self.cycle1Slots = slots
        self.cycle2Slots = slots
    }
    
    public func slots(forCycle cycle: Int) -> [ExerciseSlot] {
        return cycle == 2 ? cycle2Slots : cycle1Slots
    }
}

public struct TrainingPlan: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let title: String
    public let summary: String
    public let weeks: Int
    public var days: [DayPlan]
    public let nutrition: NutritionPlan?
    public let notes: [String]
    public let createdAt: Date

    /*
      Ob der Plan mit zwei Zyklen läuft.

      Vorher war das reine Ableitung: Sobald sich Zyklus 2 von Zyklus 1
      unterschied, gab es zwei — der Nutzer hatte keine Wahl. Wer mit drei
      Trainingstagen einfach dreimal dasselbe machen wollte, konnte das nicht
      einstellen.

      Jetzt entscheidet `twoCyclesEnabled`. `nil` heißt „nie etwas gesagt“ und
      verhält sich wie bisher, damit gespeicherte Pläne unverändert aussehen.
      Beim Ausschalten bleibt Zyklus 2 erhalten und wird nur nicht gezeigt —
      wer es sich anders überlegt, verliert nichts.
    */
    public var twoCyclesEnabled: Bool?

    public var hasTwoCycles: Bool {
        guard twoCyclesEnabled ?? true else { return false }
        return days.contains { $0.hasDistinctCycles }
    }

    /// Ob überhaupt ein zweiter Zyklus vorliegt — unabhängig vom Schalter.
    public var canOfferTwoCycles: Bool {
        days.contains { $0.hasDistinctCycles }
    }
    /*
      In welcher Sprache die Texte dieses Plans stehen. Titel, Fokus, Rufnamen
      und der Meal Guide entstehen beim Erzeugen — ohne diese Angabe wüsste
      niemand, dass sie nach einem Sprachwechsel nicht mehr passen.

      Optional, damit Pläne aus einer älteren Fassung weiter dekodieren.
    */
    public var language: String?

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        weeks: Int = 4,
        days: [DayPlan],
        nutrition: NutritionPlan? = nil,
        notes: [String] = [],
        createdAt: Date = Date(),
        language: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.weeks = weeks
        self.days = days
        self.nutrition = nutrition
        self.notes = notes
        self.createdAt = createdAt
        self.language = language
    }

    /*
      Sätze oder Wiederholungen einer einzelnen Übung ändern.

      Die einzige Stelle, an der ein fertiger Plan verändert wird — und sie ist
      absichtlich eng: Sie trifft genau einen Slot in genau einem Zyklus eines
      genau bezeichneten Tages. Alles andere bleibt unangetastet.

      Warum das wichtig ist: Ohne zweiten Zyklus spiegelt `DayPlan` den ersten,
      und beide Arrays tragen dann dieselben Slot-Kennungen. Wer nur nach der
      Kennung suchte, würde beim Ändern von Zyklus 1 stillschweigend auch
      Zyklus 2 verstellen.
    */
    // MARK: - Einzelnen Tag bearbeiten

    /*
      Genau einen Tag neu mischen — nicht den ganzen Plan.

      Vorher gab es nur „alles neu erzeugen“. Wer mit dem Montag unzufrieden
      war, verlor damit auch Mittwoch und Freitag, obwohl die passten.

      Gemischt wird innerhalb der Muskelgruppen, die dieser Tag ohnehin trifft
      (aus den vorhandenen Übungen abgeleitet, nicht aus dem Freitext `focus`).
      Der Tag behält damit seinen Charakter: Ein Brust-Tag bleibt ein
      Brust-Tag, er bekommt nur andere Übungen. Anzahl, Satzschema und Pause
      werden aus dem bisherigen Stand übernommen.

      `equipment` schränkt zusätzlich ein — ein Home-Plan darf beim Neumischen
      keine Maschine bekommen.
    */
    @discardableResult
    public mutating func reshuffleDay(
        dayID: UUID,
        cycle: Int,
        equipment: Set<EquipmentType>? = nil,
        method: TrainingMethod = .standard
    ) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        let day = days[dayIndex]
        let current = day.slots(forCycle: cycle)
        guard !current.isEmpty else { return false }

        let categories = day.categories(forCycle: cycle)
        guard !categories.isEmpty else { return false }

        /*
          Der andere Zyklus wird ausgeschlossen, damit die beiden nicht
          zusammenfallen — sonst wäre nach zweimal Mischen der Unterschied weg,
          auf dem die ganze Zyklus-Logik beruht.
        */
        let otherCycle = cycle == 2 ? 1 : 2
        let exclude = Set(day.slots(forCycle: otherCycle).map(\.exercise.name))

        let fresh = PlanGenerator.buildPlan(
            categories: categories,
            count: current.count,
            method: method,
            restTime: current.first?.restSeconds ?? 60,
            extraExclude: exclude,
            equipment: equipment
        )
        guard !fresh.isEmpty else { return false }

        // Sätze, Wiederholungen und Pause des bisherigen Stands übernehmen —
        // gemischt werden die Übungen, nicht die Vorgaben des Nutzers.
        let rebuilt: [ExerciseSlot] = fresh.enumerated().map { index, slot in
            guard index < current.count else { return slot }
            let old = current[index]
            return ExerciseSlot(
                exercise: slot.exercise,
                sets: old.sets,
                reps: old.reps,
                restSeconds: old.restSeconds
            )
        }

        write(rebuilt, to: dayIndex, cycle: cycle)
        return true
    }

    /*
      Eine einzelne Übung gegen eine bestimmte andere tauschen. Sätze,
      Wiederholungen und Pause bleiben stehen — getauscht wird die Übung, nicht
      die Vorgabe.
    */
    @discardableResult
    public mutating func replaceSlot(
        dayID: UUID,
        cycle: Int,
        slotID: UUID,
        with exercise: Exercise
    ) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        var slots = days[dayIndex].slots(forCycle: cycle)
        guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return false }

        let old = slots[slotIndex]
        slots[slotIndex] = ExerciseSlot(
            exercise: exercise,
            sets: old.sets,
            reps: old.reps,
            restSeconds: old.restSeconds,
            note: ""
        )

        write(slots, to: dayIndex, cycle: cycle)
        return true
    }

    /// Eine einzelne Übung zufällig neu würfeln, innerhalb ihrer Kategorie.
    @discardableResult
    public mutating func rerollSlot(
        dayID: UUID,
        cycle: Int,
        slotID: UUID,
        method: TrainingMethod = .standard
    ) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        let slots = days[dayIndex].slots(forCycle: cycle)
        guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }),
              let fresh = PlanGenerator.rerollSlot(plan: slots, at: slotIndex, method: method)
        else { return false }

        return replaceSlot(dayID: dayID, cycle: cycle, slotID: slotID, with: fresh.exercise)
    }

    /// Eine Übung aus einem Tag entfernen. Der letzte Eintrag bleibt stehen —
    /// ein Trainingstag ohne Übung wäre keiner.
    @discardableResult
    public mutating func removeSlot(dayID: UUID, cycle: Int, slotID: UUID) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        var slots = days[dayIndex].slots(forCycle: cycle)
        guard slots.count > 1, let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return false }

        slots.remove(at: slotIndex)
        write(slots, to: dayIndex, cycle: cycle)
        return true
    }

    /// Eine Übung an einen Tag anhängen.
    @discardableResult
    public mutating func addSlot(dayID: UUID, cycle: Int, exercise: Exercise) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        var slots = days[dayIndex].slots(forCycle: cycle)
        guard slots.count < 15 else { return false }

        slots.append(ExerciseSlot(
            exercise: exercise,
            sets: slots.last?.sets ?? 3,
            reps: slots.last?.reps ?? PlanGenerator.defaultReps,
            restSeconds: slots.last?.restSeconds ?? 60
        ))
        write(slots, to: dayIndex, cycle: cycle)
        return true
    }

    /// Reihenfolge innerhalb eines Tages ändern.
    @discardableResult
    public mutating func moveSlot(dayID: UUID, cycle: Int, from: Int, to: Int) -> Bool {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return false }

        var slots = days[dayIndex].slots(forCycle: cycle)
        guard slots.indices.contains(from), slots.indices.contains(to), from != to else { return false }

        let item = slots.remove(at: from)
        slots.insert(item, at: to)
        write(slots, to: dayIndex, cycle: cycle)
        return true
    }

    // MARK: - Zweiter Zyklus

    /*
      Den zweiten Zyklus ein- oder ausschalten.

      Beim Einschalten wird er erzeugt, falls es noch keinen gibt, der sich
      vom ersten unterscheidet. Beim Ausschalten bleibt er unangetastet
      liegen — nur `twoCyclesEnabled` fällt auf `false`, und die Ansicht zeigt
      Zyklus 1. Wer zurückschaltet, bekommt seinen alten zweiten Zyklus
      wieder, statt einen neu gewürfelten.
    */
    public mutating func setTwoCycles(
        _ enabled: Bool,
        equipment: Set<EquipmentType>? = nil,
        method: TrainingMethod = .standard
    ) {
        twoCyclesEnabled = enabled
        guard enabled, !canOfferTwoCycles else { return }

        for index in days.indices {
            let base = days[index].cycle1Slots
            guard !base.isEmpty else { continue }

            let categories = days[index].categories(forCycle: 1)
            guard !categories.isEmpty else { continue }

            let second = PlanGenerator.buildPlan(
                categories: categories,
                count: base.count,
                method: method,
                restTime: base.first?.restSeconds ?? 60,
                extraExclude: Set(base.map(\.exercise.name)),
                equipment: equipment
            )
            guard !second.isEmpty else { continue }

            days[index].cycle2Slots = second.enumerated().map { i, slot in
                let old = i < base.count ? base[i] : base[base.count - 1]
                return ExerciseSlot(
                    exercise: slot.exercise,
                    sets: old.sets,
                    reps: old.reps,
                    restSeconds: old.restSeconds
                )
            }
        }
    }

    /// Schreibt eine Slot-Liste in den richtigen Zyklus. Ohne zweiten Zyklus
    /// gehen Änderungen immer nach Zyklus 1 — sonst editiert der Nutzer etwas,
    /// das er gar nicht sieht.
    private mutating func write(_ slots: [ExerciseSlot], to dayIndex: Int, cycle: Int) {
        if cycle == 2 && hasTwoCycles {
            days[dayIndex].cycle2Slots = slots
        } else {
            days[dayIndex].cycle1Slots = slots
            if !canOfferTwoCycles {
                // Ohne echten zweiten Zyklus laufen beide Listen mit.
                days[dayIndex].cycle2Slots = slots
            }
        }
    }

    public mutating func updateSlot(
        dayID: UUID,
        cycle: Int,
        slotID: UUID,
        sets: Int? = nil,
        reps: String? = nil
    ) {
        guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else { return }

        var slots = days[dayIndex].slots(forCycle: cycle)
        guard let slotIndex = slots.firstIndex(where: { $0.id == slotID }) else { return }

        if let sets { slots[slotIndex].sets = max(1, min(20, sets)) }
        if let reps {
            let trimmed = reps.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { slots[slotIndex].reps = trimmed }
        }

        if cycle == 2 {
            days[dayIndex].cycle2Slots = slots
        } else {
            days[dayIndex].cycle1Slots = slots
        }
    }
}

public struct LoggedSet: Identifiable, Codable, Hashable {
    public var id: String { "\(setIndex)_\(weight)_\(reps)_\(done)" }
    public var setIndex: Int
    public var weight: Double
    public var reps: Int
    public var done: Bool
    public var timestamp: Date?

    public init(setIndex: Int, weight: Double, reps: Int, done: Bool = true, timestamp: Date? = nil) {
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.done = done
        self.timestamp = timestamp
    }

    public var setNumber: Int { setIndex + 1 }
    public var weightKg: Double { weight }
    public var isCompleted: Bool { done }
}

public enum SplitType: String, CaseIterable, Identifiable, Codable {
    case fullBody = "Ganzkörper"
    case upperBody = "Oberkörper"
    case lowerBody = "Unterkörper"
    case push = "Push"
    case pull = "Pull"
    case legs = "Beine"
    case core = "Bauch"
    case custom = "Eigene"

    public var id: String { rawValue }

    /// Entspricht SPLITS in data/exercises.js. `custom` ist dort `null` —
    /// die Kategorien kommen dann aus der eigenen Auswahl des Nutzers.
    public var categories: [MuscleCategory]? {
        switch self {
        case .fullBody:  return ExerciseDatabase.categories
        case .upperBody: return [.chest, .back, .shoulders, .biceps, .triceps, .neck]
        case .lowerBody: return [.legs, .glutes, .calves]
        case .push:      return [.chest, .shoulders, .triceps]
        case .pull:      return [.back, .biceps, .neck]
        case .legs:      return [.legs, .glutes, .calves]
        case .core:      return [.core]
        case .custom:    return nil
        }
    }

    public var localizedDe: String { rawValue }

    public var localizedEn: String {
        switch self {
        case .fullBody:  return "Full Body"
        case .upperBody: return "Upper Body"
        case .lowerBody: return "Lower Body"
        case .push:      return "Push"
        case .pull:      return "Pull"
        case .legs:      return "Legs"
        case .core:      return "Core"
        case .custom:    return "Custom"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? localizedEn : localizedDe
    }
}

public enum TrainingMethod: String, CaseIterable, Identifiable, Codable {
    case standard = "standard"
    case fiveFourThree = "543"
    case fourFourThree = "443"
    case chestFocus = "brust-fokus"
    case backFocus = "ruecken-fokus"
    case legsFocus = "beine-fokus"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .standard: return "3x3x3"
        case .fiveFourThree: return "5x4x3"
        case .fourFourThree: return "4x4x3"
        case .chestFocus: return "Brust-Fokus"
        case .backFocus: return "Rücken-Fokus"
        case .legsFocus: return "Beine-Fokus"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .standard: return "3×3×3"
        case .fiveFourThree: return "5×4×3"
        case .fourFourThree: return "4×4×3"
        case .chestFocus: return "Chest Focus"
        case .backFocus: return "Back Focus"
        case .legsFocus: return "Legs Focus"
        }
    }

    /*
      „3×3×3“ sagt niemandem etwas, der es nicht schon weiß.

      Die Zahlen sind Sätze je Übung, und bei den gemischten Schemata gilt
      die höhere Zahl für die schweren Grundübungen. Genau das steht jetzt
      als zweite Zeile unter jeder Auswahl — die Kurzform allein war eine
      Auswahl, die man nur raten konnte.
    */
    public var explainerDe: String {
        switch self {
        case .standard:       return "3 Sätze in jeder Übung"
        case .fiveFourThree:  return "5 Sätze in der schwersten Übung, 4 in der nächsten, 3 im Rest"
        case .fourFourThree:  return "4 Sätze in den zwei schwersten Übungen, 3 im Rest"
        case .chestFocus:     return "Mehr Brustübungen, mindestens drei je Einheit"
        case .backFocus:      return "Mehr Rückenübungen, mindestens drei je Einheit"
        case .legsFocus:      return "Mehr Beinübungen, mindestens drei je Einheit"
        }
    }

    public var explainerEn: String {
        switch self {
        case .standard:       return "3 sets on every exercise"
        case .fiveFourThree:  return "5 sets on the heaviest lift, 4 on the next, 3 on the rest"
        case .fourFourThree:  return "4 sets on the two heaviest lifts, 3 on the rest"
        case .chestFocus:     return "More chest work, at least three exercises per session"
        case .backFocus:      return "More back work, at least three exercises per session"
        case .legsFocus:      return "More leg work, at least three exercises per session"
        }
    }

    public func explainer(_ lang: String) -> String {
        lang == "en" ? explainerEn : explainerDe
    }
}

public enum TrainingGoal: String, CaseIterable, Identifiable, Codable {
    case muscle = "muscle"
    case strength = "strength"
    case definition = "definition"
    case weightLoss = "weight_loss"
    case fitness = "fitness"

    public var id: String { rawValue }

    public var titleDe: String {
        switch self {
        case .muscle: return "Muskelaufbau"
        case .strength: return "Maximalkraft"
        case .definition: return "Definition"
        case .weightLoss: return "Abnehmen"
        case .fitness: return "Allgemeine Fitness"
        }
    }

    public var titleEn: String {
        switch self {
        case .muscle: return "Muscle Building"
        case .strength: return "Max Strength"
        case .definition: return "Definition"
        case .weightLoss: return "Weight Loss"
        case .fitness: return "General Fitness"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }
}

public enum ExperienceLevel: String, CaseIterable, Identifiable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    public var id: String { rawValue }

    public var titleDe: String {
        switch self {
        case .beginner: return "Anfänger (0–1 Jahr)"
        case .intermediate: return "Fortgeschritten (1–3 Jahre)"
        case .advanced: return "Experte (3+ Jahre)"
        }
    }

    public var titleEn: String {
        switch self {
        case .beginner: return "Beginner (0–1 yr)"
        case .intermediate: return "Intermediate (1–3 yrs)"
        case .advanced: return "Advanced (3+ yrs)"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }

    public func localizedShort(_ lang: String) -> String {
        switch self {
        case .beginner: return lang == "en" ? "Beginner" : "Anfänger"
        case .intermediate: return lang == "en" ? "Intermediate" : "Fortgeschritten"
        case .advanced: return lang == "en" ? "Advanced" : "Experte"
        }
    }
}

// MARK: - Somatotyp (Körpertyp)

public enum Somatotype: String, CaseIterable, Identifiable, Codable {
    case ectomorph = "ectomorph"
    case mesomorph = "mesomorph"
    case endomorph = "endomorph"

    public var id: String { rawValue }

    public var titleDe: String {
        switch self {
        case .ectomorph: return "Ektomorph"
        case .mesomorph: return "Mesomorph"
        case .endomorph: return "Endomorph"
        }
    }

    public var titleEn: String {
        switch self {
        case .ectomorph: return "Ectomorph"
        case .mesomorph: return "Mesomorph"
        case .endomorph: return "Endomorph"
        }
    }

    public var subtitleDe: String {
        switch self {
        case .ectomorph: return "Schmaler Knochenbau, schneller Stoffwechsel, schwerer Masseaufbau"
        case .mesomorph: return "Athletischer Körperbau, definierte Muskeln, schneller Aufbau"
        case .endomorph: return "Kräftiger Körperbau, langsamerer Stoffwechsel, speichert leicht"
        }
    }

    public var subtitleEn: String {
        switch self {
        case .ectomorph: return "Lean bone structure, fast metabolism, hardgainer"
        case .mesomorph: return "Athletic build, defined muscles, rapid hypertrophy"
        case .endomorph: return "Stocky build, slower metabolism, stores energy easily"
        }
    }

    public var icon: String {
        switch self {
        case .ectomorph: return "figure.walk"
        case .mesomorph: return "figure.strengthtraining.traditional"
        case .endomorph: return "figure.arms.open"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func subtitle(_ lang: String) -> String { lang == "en" ? subtitleEn : subtitleDe }
}

// MARK: - Aktivitätsniveau

public enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary = "sedentary"
    case lightlyActive = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive = "very_active"

    public var id: String { rawValue }

    public var titleDe: String {
        switch self {
        case .sedentary: return "Viel sitzend"
        case .lightlyActive: return "Leicht aktiv"
        case .moderatelyActive: return "Mäßig aktiv"
        case .veryActive: return "Sehr aktiv"
        }
    }

    public var titleEn: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        }
    }

    public var subtitleDe: String {
        switch self {
        case .sedentary: return "Büro / Home-Office, kaum Bewegung"
        case .lightlyActive: return "Leichte Bewegung, 1–2× Sport / Woche"
        case .moderatelyActive: return "Regelmäßig auf den Beinen, 3–5× Sport"
        case .veryActive: return "Körperlich anstrengende Arbeit, 6–7× Sport"
        }
    }

    public var subtitleEn: String {
        switch self {
        case .sedentary: return "Desk job, minimal daily movement"
        case .lightlyActive: return "Light daily activity, 1–2 workouts / week"
        case .moderatelyActive: return "On your feet regularly, 3–5 workouts"
        case .veryActive: return "Physically demanding job, 6–7 workouts"
        }
    }

    public var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        }
    }

    public var icon: String {
        switch self {
        case .sedentary: return "chair.fill"
        case .lightlyActive: return "figure.walk"
        case .moderatelyActive: return "figure.run"
        case .veryActive: return "flame.fill"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }
    public func subtitle(_ lang: String) -> String { lang == "en" ? subtitleEn : subtitleDe }
}

// MARK: - BMI Kategorien

public enum BMICategory: String, Codable {
    case underweight = "underweight"
    case normal = "normal"
    case overweight = "overweight"
    case obese = "obese"

    public var titleDe: String {
        switch self {
        case .underweight: return "Untergewichtig"
        case .normal: return "Normal"
        case .overweight: return "Übergewichtig"
        case .obese: return "Fettleibig"
        }
    }

    public var titleEn: String {
        switch self {
        case .underweight: return "Underweight"
        case .normal: return "Normal"
        case .overweight: return "Overweight"
        case .obese: return "Obese"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }

}

// MARK: - Calisthenics Leistungs-Level

public enum PushupLevel: String, CaseIterable, Identifiable, Codable {
    case beginner = "0-5"
    case intermediate = "6-15"
    case advanced = "16-30"
    case elite = "30+"

    public var id: String { rawValue }
    public var labelDe: String { "\(rawValue) Wdh" }
    public var labelEn: String { "\(rawValue) Reps" }
}

public enum PullupLevel: String, CaseIterable, Identifiable, Codable {
    case none = "0"
    case beginner = "1-5"
    case advanced = "6-12"
    case elite = "12+"

    public var id: String { rawValue }
    public var labelDe: String { rawValue == "0" ? "0 (Noch keinen)" : "\(rawValue) Wdh" }
    public var labelEn: String { rawValue == "0" ? "0 (None yet)" : "\(rawValue) Reps" }
}

public enum PlankLevel: String, CaseIterable, Identifiable, Codable {
    case under30s = "<30s"
    case under60s = "30-60s"
    case under120s = "1-2min"
    case over2min = "2min+"

    public var id: String { rawValue }
    public var labelDe: String {
        switch self {
        case .under30s: return "< 30 Sek"
        case .under60s: return "30–60 Sek"
        case .under120s: return "1–2 Min"
        case .over2min: return "2+ Min"
        }
    }
    public var labelEn: String {
        switch self {
        case .under30s: return "< 30s"
        case .under60s: return "30–60s"
        case .under120s: return "1–2 min"
        case .over2min: return "2+ min"
        }
    }
}

// MARK: - Trainingsort

public enum TrainingLocation: String, CaseIterable, Identifiable, Codable {
    case gym = "gym"
    case homeBodyweight = "home_bodyweight"
    case outdoorPark = "outdoor_park"
    case hybrid = "hybrid"

    public var id: String { rawValue }

    public var titleDe: String {
        switch self {
        case .gym: return "Fitnessstudio (Gym)"
        case .homeBodyweight: return "Zuhause (Bodyweight)"
        case .outdoorPark: return "Outdoor / Calisthenics-Park"
        case .hybrid: return "Hybrid (Studio & Zuhause)"
        }
    }

    public var titleEn: String {
        switch self {
        case .gym: return "Gym / Fitness Studio"
        case .homeBodyweight: return "Home (Bodyweight)"
        case .outdoorPark: return "Outdoor Calisthenics Park"
        case .hybrid: return "Hybrid (Gym & Home)"
        }
    }

    public var icon: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .homeBodyweight: return "house.fill"
        case .outdoorPark: return "tree.fill"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }

    public func localized(_ lang: String) -> String { lang == "en" ? titleEn : titleDe }

    public var allowedEquipment: [EquipmentType] {
        switch self {
        case .gym, .hybrid:
            return EquipmentType.allCases
        case .homeBodyweight:
            return [.bodyweight, .dumbbell, .kettlebell, .weightPlate]
        case .outdoorPark:
            return [.bodyweight, .kettlebell]
        }
    }
}

public struct UserBiometrics: Codable, Hashable {
    public var sex: String
    public var age: Int
    public var heightCm: Double
    public var weightKg: Double
    public var somatotype: Somatotype
    public var activityLevel: ActivityLevel

    public init(
        sex: String = "male",
        age: Int = 28,
        heightCm: Double = 180,
        weightKg: Double = 80,
        somatotype: Somatotype = .mesomorph,
        activityLevel: ActivityLevel = .moderatelyActive
    ) {
        self.sex = sex
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.somatotype = somatotype
        self.activityLevel = activityLevel
    }

    public var bmi: Double {
        let heightM = max(0.5, heightCm / 100.0)
        return (weightKg / (heightM * heightM))
    }

    public var bmiCategory: BMICategory {
        let b = bmi
        if b < 18.5 { return .underweight }
        if b < 25.0 { return .normal }
        if b < 30.0 { return .overweight }
        return .obese
    }

    /// BMR nach Mifflin-St Jeor Formel
    public var bmr: Int {
        var base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * Double(age))
        if sex == "male" {
            base += 5.0
        } else {
            base -= 161.0
        }
        return max(800, Int(base.rounded()))
    }

    /// TDEE Gesamtenergieumsatz (BMR * Aktivitätsfaktor)
    public var tdee: Int {
        Int((Double(bmr) * activityLevel.factor).rounded())
    }

    /// Ziel-Kalorien basierend auf Trainingsziel & Gewichtsziel
    public func targetCalories(for goal: TrainingGoal, goalWeightKg: Double? = nil) -> Int {
        var target = tdee
        if let goalWeight = goalWeightKg {
            let delta = goalWeight - weightKg
            if abs(delta) >= 1 {
                let magnitude = abs(delta) >= 5 ? 500 : 300
                target += delta > 0 ? magnitude : -magnitude
                return max(1200, target)
            }
        }

        switch goal {
        case .muscle: target += 350
        case .strength: target += 200
        case .definition: target -= 350
        case .weightLoss: target -= 500
        case .fitness: break
        }
        return max(1200, target)
    }
}

public struct AICoachInput: Codable, Hashable {
    public var goal: TrainingGoal
    public var experience: ExperienceLevel
    public var biometrics: UserBiometrics
    public var selectedDays: [String]
    public var sessionDurationMinutes: Int
    public var weeks: Int
    public var equipment: Set<EquipmentType>
    public var diet: DietType
    public var includeWarmup: Bool
    public var goalWeightKg: Double?
    public var method: TrainingMethod
    public var pushupLevel: PushupLevel
    public var pullupLevel: PullupLevel
    public var plankLevel: PlankLevel
    public var trainingLocation: TrainingLocation

    public var weightDelta: Double? {
        guard let goalWeightKg else { return nil }
        return goalWeightKg - biometrics.weightKg
    }

    public init(
        goal: TrainingGoal = .muscle,
        experience: ExperienceLevel = .intermediate,
        biometrics: UserBiometrics = UserBiometrics(),
        selectedDays: [String] = ["Mo", "Mi", "Fr"],
        sessionDurationMinutes: Int = 60,
        weeks: Int = 4,
        equipment: Set<EquipmentType> = Set(EquipmentType.allCases),
        diet: DietType = .omnivore,
        includeWarmup: Bool = true,
        goalWeightKg: Double? = nil,
        method: TrainingMethod = .standard,
        pushupLevel: PushupLevel = .intermediate,
        pullupLevel: PullupLevel = .beginner,
        plankLevel: PlankLevel = .under60s,
        trainingLocation: TrainingLocation = .gym
    ) {
        self.goal = goal
        self.experience = experience
        self.biometrics = biometrics
        self.selectedDays = selectedDays
        self.sessionDurationMinutes = sessionDurationMinutes
        self.weeks = weeks
        self.equipment = equipment
        self.diet = diet
        self.includeWarmup = includeWarmup
        self.goalWeightKg = goalWeightKg
        self.method = method
        self.pushupLevel = pushupLevel
        self.pullupLevel = pullupLevel
        self.plankLevel = plankLevel
        self.trainingLocation = trainingLocation
    }
}


