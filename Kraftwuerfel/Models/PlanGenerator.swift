import Foundation

/*
  Portierung von src/lib/planLogic.js. Die Reihenfolge der Schritte ist absichtlich
  identisch zum Web — inklusive der Eigenheiten, die dort Absicht sind:

  - Der Nachschlag-Durchlauf (`fill`) schließt nur das bereits Gewählte aus, nicht
    `extraExclude`. So darf ein Zyklus eine Übung aus dem Vorzyklus wiederholen,
    wenn die Kategorie sonst leer läuft — besser als ein zu kurzer Plan.
  - Bei einer Fokus-Methode läuft das Satzschema als "standard", weil 5x4x3 und
    Fokus sich sonst gegenseitig die schweren Übungen wegnehmen.
*/
public enum PlanGenerator {

    // MARK: - Konstanten (data/exercises.js)

    public static let restOptions = [45, 60, 90]
    public static let defaultReps = "4-8"
    public static let focusMinCount = 3

    public static func focusCategory(for method: TrainingMethod) -> MuscleCategory? {
        switch method {
        case .chestFocus: return .chest
        case .backFocus:  return .back
        case .legsFocus:  return .legs
        default:          return nil
        }
    }

    // MARK: - Zufall

    public static func shuffle<T>(_ arr: [T]) -> [T] {
        var a = arr
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = Int.random(in: 0...i)
            a.swapAt(i, j)
        }
        return a
    }

    public static func randOf<T>(_ arr: [T]) -> T? { arr.randomElement() }

    // MARK: - Satzschema

    public static func applySetScheme(
        _ exercises: [Exercise],
        method: TrainingMethod,
        restTime: Int
    ) -> [ExerciseSlot] {
        var sets = [Int](repeating: 3, count: exercises.count)

        if method == .fiveFourThree || method == .fourFourThree {
            let heavyIdx = exercises.indices.filter { exercises[$0].isHeavy }
            let pool = shuffle(heavyIdx.isEmpty ? Array(exercises.indices) : heavyIdx)

            if method == .fiveFourThree {
                let fiveIdx = pool.first
                if let f = fiveIdx { sets[f] = 5 }

                var fourIdx = pool.count > 1 ? pool[1] : nil
                if fourIdx == nil {
                    let rest = shuffle(exercises.indices.filter { $0 != fiveIdx })
                    fourIdx = rest.first
                }
                if let f = fourIdx { sets[f] = 4 }
            } else {
                var chosen = Array(pool.prefix(2))
                if chosen.count < 2 {
                    var rest = shuffle(exercises.indices.filter { !chosen.contains($0) })
                    while chosen.count < 2 && !rest.isEmpty {
                        chosen.append(rest.removeFirst())
                    }
                }
                chosen.forEach { sets[$0] = 4 }
            }
        }

        return exercises.enumerated().map { i, e in
            ExerciseSlot(exercise: e, sets: sets[i], reps: defaultReps, restSeconds: restTime)
        }
    }

    // MARK: - Plan bauen

    public static func buildPlan(
        categories categoriesIn: [MuscleCategory],
        count countIn: Int,
        method: TrainingMethod = .standard,
        restTime: Int = 60,
        extraExclude: Set<String> = [],
        equipment: Set<EquipmentType>? = nil
    ) -> [ExerciseSlot] {
        // Normalisierung: Bei reinem Beine-Split ist Beine-Fokus redundant & ungültig
        let effectiveMethod: TrainingMethod = (categoriesIn == [.legs, .glutes, .calves] && method == .legsFocus)
            ? .standard
            : method

        let focusCat = focusCategory(for: effectiveMethod)
        let categories: [MuscleCategory] = {
            guard let f = focusCat, !categoriesIn.contains(f) else { return categoriesIn }
            return [f] + categoriesIn
        }()
        let count = focusCat != nil ? max(countIn, focusMinCount) : countIn

        guard !categories.isEmpty else { return [] }

        /*
          Der KI-Coach schränkt auf vorhandene Geräte ein. Bleibt dabei zu wenig
          übrig, fällt der Filter weg — ein kurzer Plan wäre schlechter als
          einer mit einer Maschine, die vielleicht doch dasteht.
        */
        let pool: [Exercise] = {
            guard let equipment, !equipment.isEmpty else { return ExerciseDatabase.all }
            let filtered = ExerciseDatabase.all.filter { equipment.contains($0.equipment) }
            return filtered.count >= count ? filtered : ExerciseDatabase.all
        }()

        func attempt(_ excludeSet: Set<String>) -> [Exercise] {
            var byCat: [MuscleCategory: [Exercise]] = [:]
            for c in categories {
                byCat[c] = shuffle(pool.filter { $0.categories.contains(c) })
            }
            var usedNames = excludeSet
            var result: [Exercise] = []
            var ci = 0
            var safety = 0

            // Verbrauchte Einträge vorne abräumen, damit `isEmpty` die Wahrheit sagt.
            func trim(_ c: MuscleCategory) {
                while let first = byCat[c]?.first, usedNames.contains(first.name) {
                    byCat[c]?.removeFirst()
                }
            }
            func stillHasUnused() -> Bool {
                categories.contains { c in
                    trim(c)
                    return !(byCat[c]?.isEmpty ?? true)
                }
            }

            while result.count < count && safety < count * 40 {
                let cat = categories[ci % categories.count]
                trim(cat)
                if let ex = byCat[cat]?.first {
                    byCat[cat]?.removeFirst()
                    usedNames.insert(ex.name)
                    result.append(ex)
                }
                ci += 1
                safety += 1
                if !stillHasUnused() { break }
            }
            return result
        }

        var result = attempt(extraExclude)

        if result.count < count {
            // Nicht genug Übungen ohne Überschneidung übrig -> mit bereits Gewähltem auffüllen
            var already = Set(result.map(\.name))
            for e in attempt(already) where result.count < count && !already.contains(e.name) {
                result.append(e)
                already.insert(e.name)
            }
        }

        // Fokus-Methode: garantiert mind. focusMinCount Übungen aus der Fokus-Kategorie
        if let focusCat {
            let focusInResult = result.filter { $0.categories.contains(focusCat) }.count
            if focusInResult < focusMinCount {
                let usedNames = Set(result.map(\.name))
                var moreFocus = shuffle(
                    pool.filter {
                        $0.categories.contains(focusCat) && !usedNames.contains($0.name)
                    }
                )
                var needed = focusMinCount - focusInResult
                while needed > 0 && !moreFocus.isEmpty {
                    if result.count >= count {
                        guard let removeIdx = result.lastIndex(where: { !$0.categories.contains(focusCat) })
                        else { break } // alles bereits Fokus-Übungen
                        result.remove(at: removeIdx)
                    }
                    result.append(moreFocus.removeFirst())
                    needed -= 1
                }
            }
        }

        let setSchemeMethod: TrainingMethod = focusCat != nil ? .standard : method
        return applySetScheme(result, method: setSchemeMethod, restTime: restTime)
    }

    // MARK: - Einzelne Übung neu würfeln

    public static func rerollSlot(
        plan: [ExerciseSlot],
        at idx: Int,
        method: TrainingMethod
    ) -> ExerciseSlot? {
        guard plan.indices.contains(idx) else { return nil }
        let currentSlot = plan[idx]
        let cat = currentSlot.exercise.category
        let usedNames = Set(plan.map(\.exercise.name))
        let needsHeavy = method != .standard && currentSlot.sets >= 4

        func buildPool(allowSameName: Bool) -> [Exercise] {
            var pool = ExerciseDatabase.all.filter {
                $0.categories.contains(cat) && (allowSameName || !usedNames.contains($0.name))
            }
            if allowSameName {
                pool = pool.filter { $0.name != currentSlot.exercise.name }
            }
            if needsHeavy {
                let heavyPool = pool.filter(\.isHeavy)
                if !heavyPool.isEmpty { pool = heavyPool }
            }
            return pool
        }

        var pool = buildPool(allowSameName: false)
        if pool.isEmpty { pool = buildPool(allowSameName: true) }
        guard let picked = randOf(pool) else { return nil }

        return ExerciseSlot(
            exercise: picked,
            sets: currentSlot.sets,
            reps: currentSlot.reps,
            restSeconds: currentSlot.restSeconds
        )
    }

    // MARK: - Trainingsplan über mehrere Wochen

    public static func cyclesForDuration(_ duration: Int) -> Int {
        max(1, Int((Double(duration) / 2.0).rounded()))
    }

    public static func buildDayPlans(
        days: [String],
        cycles: Int,
        categories: [MuscleCategory],
        count: Int,
        method: TrainingMethod,
        restTime: Int,
        equipment: Set<EquipmentType>? = nil
    ) -> [String: [[ExerciseSlot]]] {
        var result: [String: [[ExerciseSlot]]] = [:]
        for day in days {
            var usedSoFar = Set<String>()
            var cyclePlans: [[ExerciseSlot]] = []
            for _ in 0..<cycles {
                let p = buildPlan(
                    categories: categories,
                    count: count,
                    method: method,
                    restTime: restTime,
                    extraExclude: usedSoFar,
                    equipment: equipment
                )
                p.forEach { usedSoFar.insert($0.exercise.name) }
                cyclePlans.append(p)
            }
            result[day] = cyclePlans
        }
        return result
    }
}
