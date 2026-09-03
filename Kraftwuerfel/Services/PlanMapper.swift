import Foundation

/*
  Wandelt die JSON-Antwort von POST /generate-plan in einen TrainingPlan um.

  Unterstützt sowohl das standardmäßige Root-Format als auch verschachtelte
  Strukturen (training.weeks für Zyklus 1 & 2 Wochenprogression sowie
  nutrition.weeklySchedule und nutrition.macros mit detaillierten
  Mahlzeit-Makros und Zubereitungsanleitungen).
*/
public enum PlanMapper {

    /*
      `exerciseRange` bestimmt, wie viele Übungen ein Tag haben muss.

      Der KI-Coach bleibt bei 6 bis 8 — so war es und so ist der Studio-Plan
      gedacht. Die Home-Challenge fordert dagegen mindestens 5 und ist nach
      oben offen: Eine 60-Minuten-Einheit zu Hause besteht aus vielen kurzen
      Übungen, und die auf acht zu kürzen hätte den Plan halbiert.
    */
    public static let coachExerciseRange = 6...8
    /// Der bisherige feste Bereich. Bleibt für Aufrufer stehen, die keine
    /// Einheitsdauer kennen — die Challenge benutzt jetzt `challengeExerciseRange(forMinutes:)`.
    public static let challengeExerciseRange = 5...12

    /*
      Wie viele Übungen ein Challenge-Tag haben darf, nach der Zeit gerechnet.

      Muss zur Rechnung des Servers passen (PlanValidator.ExerciseCountFor).
      Vorher standen hier fest 5 bis 12, unabhängig von der Einheitsdauer:
      Der Server kürzte eine 10-Minuten-Einheit auf seine Obergrenze, und
      diese Seite füllte danach wieder auf mindestens fünf auf. Das Ergebnis
      war ein Plan, den in zehn Minuten niemand schafft — drei Sätze mit
      Pause sind rund 3,5 Minuten je Übung.
    */
    public static func challengeExerciseRange(forMinutes minutes: Int) -> ClosedRange<Int> {
        switch minutes {
        case ...10: return 3...3
        case ...15: return 4...5
        case ...20: return 5...6
        case ...30: return 6...8
        case ...45: return 8...10
        default:    return 8...12
        }
    }

    public static func trainingPlan(
        from raw: [String: Any],
        language: String,
        input: AICoachInput? = nil,
        exerciseRange: ClosedRange<Int> = coachExerciseRange
    ) -> TrainingPlan? {
        let byName = Dictionary(
            ExerciseDatabase.all.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // 1. Tage extrahieren (entweder direkt aus raw["days"] oder aus raw["training"]["weeks"])
        var rawDays = raw["days"] as? [[String: Any]] ?? []
        var rawWeek2Days: [[String: Any]] = []

        if let training = raw["training"] as? [String: Any], let weeks = training["weeks"] as? [[String: Any]], !weeks.isEmpty {
            if let w1 = weeks.first, let w1Days = w1["days"] as? [[String: Any]], !w1Days.isEmpty {
                if rawDays.isEmpty {
                    rawDays = w1Days
                }
            }
            if weeks.count > 1, let w2Days = weeks[1]["days"] as? [[String: Any]], !w2Days.isEmpty {
                rawWeek2Days = w2Days
            }
        }

        guard !rawDays.isEmpty else { return nil }

        func parseSlots(from dayObj: [String: Any], keys: [String]) -> [ExerciseSlot] {
            for key in keys {
                if let rawList = dayObj[key] as? [[String: Any]], !rawList.isEmpty {
                    let slots: [ExerciseSlot] = rawList.compactMap { ex in
                        guard let name = ex["name"] as? String else { return nil }
                        let exercise = byName[name.lowercased()] ?? ExerciseDatabase.all.first {
                            $0.name.localizedCaseInsensitiveContains(name) || name.localizedCaseInsensitiveContains($0.name)
                        }
                        guard let exercise else { return nil }
                        /*
                          Die Satzpause wird gekappt, nicht übernommen.

                          Der Server begrenzt sie inzwischen selbst, aber ein
                          Plan kann aus dem Cache stammen, der noch vor dieser
                          Änderung entstanden ist — dort stehen weiterhin bis
                          zu 180 Sekunden. Und ein gespeicherter Plan lebt
                          länger als ein Serverstand.
                        */
                        let maxRest = input?.restSeconds ?? 180
                        let rawRest = ex["rest"] as? Int ?? 60
                        return ExerciseSlot(
                            exercise: exercise,
                            sets: ex["sets"] as? Int ?? 3,
                            reps: ex["reps"] as? String ?? PlanGenerator.defaultReps,
                            restSeconds: min(rawRest, maxRest),
                            note: ex["note"] as? String ?? ""
                        )
                    }
                    if !slots.isEmpty {
                        return (input != nil) ? ensureExerciseCount(slots, in: exerciseRange) : slots
                    }
                }
            }
            return []
        }

        let days: [DayPlan] = rawDays.compactMap { (rawDay: [String: Any]) -> DayPlan? in
            guard let weekday = rawDay["weekday"] as? String else { return nil }

            let cycle1Slots = parseSlots(from: rawDay, keys: ["cycle1", "cycle1Exercises", "exercises"])
            guard !cycle1Slots.isEmpty else { return nil }

            var cycle2Slots = parseSlots(from: rawDay, keys: ["cycle2", "cycle2Exercises"])

            // Falls Woche 2 im `training.weeks` Array vorliegt, diese für Zyklus 2 nutzen
            if cycle2Slots.isEmpty, !rawWeek2Days.isEmpty {
                if let w2Day = rawWeek2Days.first(where: { ($0["weekday"] as? String) == weekday }) {
                    let w2Slots = parseSlots(from: w2Day, keys: ["exercises", "cycle2", "cycle1"])
                    if !w2Slots.isEmpty {
                        cycle2Slots = w2Slots
                    }
                }
            }

            let warmup: [WarmupExercise] = (rawDay["warmup"] as? [[String: Any]] ?? []).compactMap { w in
                let name = (w["exercise"] as? String) ?? (w["name"] as? String)
                guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
                let duration = w["duration"] as? String ?? ""
                return WarmupExercise(name: name, duration: duration)
            }

            return DayPlan(
                weekday: weekday,
                name: (rawDay["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? PlanNames.planName(for: weekday),
                focus: rawDay["focus"] as? String ?? "",
                warmup: warmup,
                cycle1Slots: cycle1Slots,
                cycle2Slots: cycle2Slots
            )
        }

        guard !days.isEmpty else { return nil }

        // Ernährungsplan parsen oder mit den Eingabedaten vollständig generieren
        let nutrition: NutritionPlan? = parseNutrition(from: raw["nutrition"] as? [String: Any], language: language, input: input)
            ?? (input.map { AICoachService.shared.generateNutrition(input: $0, language: language) })

        let durationWeeks = (raw["training"] as? [String: Any])?["duration_weeks"] as? Int
            ?? raw["weeks"] as? Int
            ?? input?.weeks
            ?? 4

        return TrainingPlan(
            title: raw["title"] as? String ?? "KI Hypertrophie & Performance Plan",
            summary: raw["summary"] as? String ?? "",
            weeks: durationWeeks,
            days: days,
            nutrition: nutrition,
            notes: raw["notes"] as? [String] ?? [],
            language: language
        )
    }

    // MARK: - Übungsanzahl auffüllen & deckeln

    /*
      Der Server füllt schon auf, aber nicht jeder Name aus seiner Antwort
      lässt sich hier auf eine bekannte Übung abbilden — dabei fallen wieder
      welche weg. Deshalb steht die Untergrenze auch auf dieser Seite.

      Aufgefüllt wird aus derselben Equipment-Klasse wie der Rest des Tages:
      Ein Home-Plan darf nicht plötzlich eine Beinpresse bekommen, bloß weil
      eine Übung nicht zugeordnet werden konnte.
    */
    public static func ensureExerciseCount(
        _ slots: [ExerciseSlot],
        in range: ClosedRange<Int>
    ) -> [ExerciseSlot] {
        var result = slots

        if result.count < range.lowerBound {
            let existingIds = Set(result.map(\.exercise.id))
            let usedEquipment = Set(result.map(\.exercise.equipment))
            let sameEquipment = ExerciseDatabase.all.filter {
                !existingIds.contains($0.id) && usedEquipment.contains($0.equipment)
            }
            let rest = ExerciseDatabase.all.filter {
                !existingIds.contains($0.id) && !usedEquipment.contains($0.equipment)
            }
            for ex in sameEquipment + rest {
                if result.count >= range.lowerBound { break }
                result.append(ExerciseSlot(exercise: ex, sets: 3, reps: PlanGenerator.defaultReps, restSeconds: 60))
            }
        } else if result.count > range.upperBound {
            result = Array(result.prefix(range.upperBound))
        }

        return result
    }

    @available(*, deprecated, renamed: "ensureExerciseCount(_:in:)")
    public static func ensureExerciseCountBetween6And8(_ slots: [ExerciseSlot]) -> [ExerciseSlot] {
        ensureExerciseCount(slots, in: coachExerciseRange)
    }

    // MARK: - Uhrzeit-Parsing in Minuten für chronologische Sortierung

    public static func parseTimeMinutes(_ time: String) -> Int {
        let clean = time.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = clean.components(separatedBy: ":")
        if parts.count >= 2,
           let h = Int(parts[0].filter { $0.isNumber }),
           let m = Int(parts[1].filter { $0.isNumber }) {
            return h * 60 + m
        }
        if let h = Int(clean.filter { $0.isNumber }) {
            return h * 60
        }
        return 720
    }

    private static func parseMealList(
        from rawMealList: [[String: Any]],
        dailyCalories: Int,
        language: String
    ) -> [MealItem] {
        let parsed: [MealItem] = rawMealList.enumerated().compactMap { index, m in
            let time = m["time"] as? String ?? "12:00"
            let cal = m["calories"] as? Int ?? (dailyCalories / max(1, rawMealList.count))
            let mealProtein = m["protein"] as? Int
            let mealCarbs = m["carbs"] as? Int
            let mealFat = m["fat"] as? Int
            let instructions = m["instructions"] as? String

            let items: [String]
            if let rawItems = m["items"] as? [String] {
                items = rawItems.compactMap {
                    let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }
            } else if let rawItemStr = m["items"] as? String {
                let trimmed = rawItemStr.trimmingCharacters(in: .whitespacesAndNewlines)
                items = trimmed.isEmpty ? [] : [trimmed]
            } else {
                items = []
            }

            var customEntries: [FoodItemEntry] = []
            if let rawEntries = m["customEntries"] as? [[String: Any]] {
                customEntries = rawEntries.compactMap { entry in
                    guard let name = entry["name"] as? String else { return nil }
                    let amount = entry["amount"] as? String ?? "1 Portion"
                    let c = entry["calories"] as? Int ?? 0
                    let p = entry["protein"] as? Int ?? 0
                    let cb = entry["carbs"] as? Int ?? 0
                    let f = entry["fat"] as? Int ?? 0
                    return FoodItemEntry(name: name, amount: amount, calories: c, protein: p, carbs: cb, fat: f)
                }
            }

            let explicitName = m["name"] as? String ?? m["title"] as? String
            let name: String
            if let explicitName = explicitName?.trimmingCharacters(in: .whitespacesAndNewlines), !explicitName.isEmpty {
                name = explicitName
            } else {
                let lowerTime = time.lowercased()
                if lowerTime.contains("pre") {
                    name = language == "en" ? "Pre-Workout Meal" : "Pre-Workout Mahlzeit"
                } else if lowerTime.contains("post") {
                    name = language == "en" ? "Post-Workout Meal" : "Post-Workout Mahlzeit"
                } else if lowerTime.contains("snack") {
                    name = language == "en" ? "Snack" : "Snack / Zwischenmahlzeit"
                } else {
                    switch index {
                    case 0: name = language == "en" ? "Breakfast" : "Frühstück"
                    case 1: name = language == "en" ? "Lunch" : "Mittagessen"
                    case 2: name = language == "en" ? "Snack / Pre-Workout" : "Snack / Pre-Workout"
                    case 3: name = language == "en" ? "Dinner" : "Abendessen"
                    case 4: name = language == "en" ? "Evening Snack" : "Spätmahlzeit"
                    default: name = language == "en" ? "Meal \(index + 1)" : "Mahlzeit \(index + 1)"
                    }
                }
            }

            return MealItem(
                time: time,
                name: name,
                calories: cal,
                protein: mealProtein,
                carbs: mealCarbs,
                fat: mealFat,
                items: items,
                customEntries: customEntries,
                instructions: instructions
            )
        }

        // Chronologische Sortierung anhand der Uhrzeit
        return parsed.sorted { parseTimeMinutes($0.time) < parseTimeMinutes($1.time) }
    }

    private static func parseNutrition(
        from raw: [String: Any]?,
        language: String,
        input: AICoachInput?
    ) -> NutritionPlan? {
        guard let raw else { return nil }

        let dietRaw = raw["diet"] as? String ?? input?.diet.rawValue ?? "omnivore"
        let diet = DietType(rawValue: dietRaw) ?? .omnivore

        let dailyCalories = raw["dailyCalories"] as? Int ?? raw["calories"] as? Int ?? (
            input.map { AICoachService.shared.generateNutrition(input: $0, language: language).dailyCalories } ?? 2400
        )

        let macrosObj = raw["macros"] as? [String: Any]

        let protein = raw["protein"] as? Int
            ?? macrosObj?["proteinGrams"] as? Int
            ?? macrosObj?["protein"] as? Int
            ?? (input.map { Int(round($0.biometrics.weightKg * 2.0)) } ?? Int(round(Double(dailyCalories) * 0.28 / 4.0)))

        let fat = raw["fat"] as? Int
            ?? macrosObj?["fatGrams"] as? Int
            ?? macrosObj?["fat"] as? Int
            ?? (input.map { Int(round($0.biometrics.weightKg * 0.9)) } ?? Int(round(Double(dailyCalories) * 0.25 / 9.0)))

        let carbs = raw["carbs"] as? Int
            ?? macrosObj?["carbsGrams"] as? Int
            ?? macrosObj?["carbsGrams"] as? Int
            ?? max(50, Int(round(Double(dailyCalories - (protein * 4) - (fat * 9)) / 4.0)))

        // 1. Weekly Schedule parsen (alle 7 Tage)
        var weeklySchedule: [NutritionDaySchedule] = []
        let dayNamesDe = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
        let dayNamesEn = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

        if let rawWeekly = raw["weeklySchedule"] as? [[String: Any]], !rawWeekly.isEmpty {
            var seenMealNames = Set<String>()
            weeklySchedule = rawWeekly.enumerated().compactMap { idx, dayObj in
                let dayNum = dayObj["dayNumber"] as? Int ?? (idx + 1)
                let defaultName = language == "en"
                    ? dayNamesEn[min(max(0, dayNum - 1), 6)]
                    : dayNamesDe[min(max(0, dayNum - 1), 6)]
                let dayName = dayObj["dayName"] as? String ?? defaultName
                let dayCal = dayObj["dailyCalories"] as? Int ?? dailyCalories
                let dayProtein = dayObj["protein"] as? Int ?? protein
                let dayCarbs = dayObj["carbs"] as? Int ?? carbs
                let dayFat = dayObj["fat"] as? Int ?? fat

                let dayMealsRaw = dayObj["meals"] as? [[String: Any]] ?? []
                let dayMeals = parseMealList(from: dayMealsRaw, dailyCalories: dayCal, language: language)

                // Deduplizierung: Falls dieselbe Mahlzeit bereits in einem früheren Wochentag vorkam
                var uniqueDayMeals: [MealItem] = []
                for m in dayMeals {
                    let normalized = m.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if seenMealNames.contains(normalized) {
                        // Bei Namensdopplung Wochentag-Zusatz anfügen oder durch unique Variante ersetzen
                        var mod = m
                        mod.name = "\(m.name) (\(dayName))"
                        uniqueDayMeals.append(mod)
                        seenMealNames.insert(mod.name.lowercased())
                    } else {
                        uniqueDayMeals.append(m)
                        seenMealNames.insert(normalized)
                    }
                }

                return NutritionDaySchedule(
                    dayNumber: dayNum,
                    dayName: dayName,
                    dailyCalories: dayCal,
                    protein: dayProtein,
                    carbs: dayCarbs,
                    fat: dayFat,
                    meals: uniqueDayMeals
                )
            }
        }

        // Falls weeklySchedule weniger als 7 Tage umfasst, über AICoachService auffüllen
        if weeklySchedule.count < 7, let input {
            let fullGen = AICoachService.shared.generateNutrition(input: input, language: language)
            weeklySchedule = fullGen.weeklySchedule
        }

        // 2. Mahlzeiten für Tag 1 oder direkt aus `meals`
        var meals: [MealItem] = []
        let rawMealList: [[String: Any]] = raw["meals"] as? [[String: Any]] ?? []
        if rawMealList.isEmpty, let firstDay = weeklySchedule.first {
            meals = firstDay.meals
        } else if !rawMealList.isEmpty {
            meals = parseMealList(from: rawMealList, dailyCalories: dailyCalories, language: language)
        }

        var shakes: [ShakeItem] = []
        let defaultWhen = language == "en" ? "Post-Workout (within 30-60 min)" : "Nach dem Training (innerhalb 30-60 Min.)"
        let defaultPowder = diet == .vegan
            ? (language == "en" ? "30g Pea & Rice Protein" : "30g Veganes Erbsen-/Reisprotein")
            : (language == "en" ? "35g Whey Protein Isolate" : "35g Whey Protein Isolat")
        let defaultLiquid = language == "en" ? "250-300 ml cold water or almond milk" : "250–300 ml kaltes Wasser oder ungesüßte Mandelmilch"

        if let rawShakes = raw["shakes"] as? [[String: Any]] {
            shakes = rawShakes.compactMap { s in
                guard let what = (s["what"] as? String) ?? (s["text"] as? String) ?? (s["name"] as? String) else { return nil }
                let when = s["when"] as? String ?? defaultWhen
                let powder = s["powderAmount"] as? String ?? defaultPowder
                let liquid = s["liquid"] as? String ?? defaultLiquid
                let protein = s["proteinGrams"] as? Int ?? 26
                let calories = s["calories"] as? Int ?? 130
                return ShakeItem(when: when, what: what, powderAmount: powder, liquid: liquid, proteinGrams: protein, calories: calories)
            }
        } else if let rawShakeStr = raw["shakes"] as? String, !rawShakeStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shakes = [ShakeItem(
                when: defaultWhen,
                what: rawShakeStr.trimmingCharacters(in: .whitespacesAndNewlines),
                powderAmount: defaultPowder,
                liquid: defaultLiquid,
                proteinGrams: 26,
                calories: 130
            )]
        } else if let rawShakeList = raw["shakes"] as? [String] {
            shakes = rawShakeList.compactMap { s in
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : ShakeItem(
                    when: defaultWhen,
                    what: trimmed,
                    powderAmount: defaultPowder,
                    liquid: defaultLiquid,
                    proteinGrams: 26,
                    calories: 130
                )
            }
        }

        if shakes.isEmpty {
            let shakeText = language == "en"
                ? "1x Post-Workout Protein Shake (\(defaultPowder) + \(defaultLiquid))"
                : "1x Post-Workout Protein Shake (\(defaultPowder) + \(defaultLiquid))"
            shakes = [ShakeItem(
                when: defaultWhen,
                what: shakeText,
                powderAmount: defaultPowder,
                liquid: defaultLiquid,
                proteinGrams: 26,
                calories: 130
            )]
        }

        let notes = (raw["notes"] as? [String]) ?? [
            language == "en" ? "Drink at least 3-4 liters of water daily" : "Trinke täglich mindestens 3–4 Liter Wasser",
            language == "en" ? "Distribute ~30g protein evenly every 3-4 hours" : "Verteile dein Eiweiß gleichmäßig alle 3–4 Stunden"
        ]

        let disclaimer = raw["disclaimer"] as? String ?? (
            language == "en"
                ? "Nutritional values are scientifically estimated reference values for healthy adults."
                : "Nährwertangaben sind wissenschaftlich berechnete Richtwerte für gesunde Erwachsene."
        )

        // Falls trotz allem gar keine Mahlzeiten erfasst wurden, Fallback
        if meals.isEmpty, let input {
            let generated = AICoachService.shared.generateNutrition(input: input, language: language)
            return generated
        }

        return NutritionPlan(
            diet: diet,
            dailyCalories: dailyCalories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            weeklySchedule: weeklySchedule,
            meals: meals,
            shakes: shakes,
            notes: notes,
            disclaimer: disclaimer
        )
    }
}
