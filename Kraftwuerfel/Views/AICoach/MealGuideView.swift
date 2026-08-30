import SwiftUI

/*
  Der Ernährungsplan aus dem KI-Coach.
  
  Unterstützt:
  - Vollständigen 7-Tage-Ernährungsplan (Montag bis Sonntag) mit interaktiver Tagesauswahl
  - Detaillierte Protein-Shake & Supplement-Ansicht (welcher Shake, wie viel Pulver, wie viel Flüssigkeit, wann trinken)
  - Yazio-Style Lebensmittel-/Zutaten-Editor: Nutzer können eigene Zutaten mit Kalorien & Makros hinzufügen oder anpassen
  - Dynamische Echtzeit-Neuberechnung von Kalorien und Makros
  - Persistentes Speichern & Aktualisieren in SavedMealGuidesStore
*/
public struct MealGuideView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = SavedMealGuidesStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    public let initialNutrition: NutritionPlan
    public var suggestedName: String
    public var showsSaveButton: Bool
    public var onUpdate: ((NutritionPlan) -> Void)?

    @State private var currentPlan: NutritionPlan
    @State private var selectedDayIndex: Int = 0
    /*
      Welche Mahlzeit gerade eine Zutat bekommt — direkt auf dem Planbildschirm.

      Vorher öffnete „+ Zutat hinzufügen" ein eigenes Blatt (NavigationStack
      mit Form). Das riss den Nutzer aus dem Plan heraus, um ein Feld
      auszufüllen, und sah als einziger Bildschirm der App nach Standard-iOS
      aus statt nach Kraftwürfel. Die Eingabe steht jetzt dort, wo sie
      hingehört: unter der Mahlzeit, die sie ergänzt.

      `nil` heißt: gerade wird nichts ergänzt.
    */
    @State private var addingToMealIndex: Int?
    @State private var alert: SaveAlert?
    @State private var showPro = false
    @State private var proNotice: SaveAlert?

    public init(
        nutrition: NutritionPlan,
        suggestedName: String = "",
        showsSaveButton: Bool = true,
        onUpdate: ((NutritionPlan) -> Void)? = nil
    ) {
        self.initialNutrition = nutrition
        self.suggestedName = suggestedName
        self.showsSaveButton = showsSaveButton
        self.onUpdate = onUpdate
        _currentPlan = State(initialValue: nutrition)
    }

    private var schedule: [NutritionDaySchedule] {
        currentPlan.resolvedSchedule
    }

    private var activeDay: NutritionDaySchedule {
        guard !schedule.isEmpty else {
            return NutritionDaySchedule(dayNumber: 1, dayName: "Tag 1", dailyCalories: currentPlan.dailyCalories, meals: currentPlan.meals)
        }
        let safeIndex = min(max(0, selectedDayIndex), schedule.count - 1)
        return schedule[safeIndex]
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                daySelectorBar
                headerCard
                macrosGrid
                mealScheduleList
                shakesList
                if !currentPlan.notes.isEmpty { notesCard }
                
                if showsSaveButton {
                    saveButton
                } else if onUpdate != nil {
                    saveChangesButton
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .kraftDialog(item: $alert) { entry in
            KraftDialog(title: entry.title, message: entry.message, isError: entry.isError) {
                alert = nil
            }
        }
        .kraftDialog(item: $proNotice) { entry in
            KraftDialog(
                title: entry.title,
                message: entry.message,
                icon: "sparkles",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("pro.cta"),
                onConfirm: {
                    proNotice = nil
                    showPro = true
                },
                onDismiss: { proNotice = nil }
            )
        }
        .sheet(isPresented: $showPro) {
            ProSubscriptionView()
        }
    }

    // MARK: - 7-Tage-Auswahlleiste

    private var daySelectorBar: some View {
        HStack(spacing: 4) {
            ForEach(schedule.indices, id: \.self) { idx in
                let day = schedule[idx]
                let isSelected = selectedDayIndex == idx
                let shortName = dayShortName(day.dayName, index: idx)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDayIndex = idx
                } label: {
                    VStack(spacing: 2) {
                        Text("\(day.dayNumber)")
                            .font(KraftFont.inter(9.5, .semibold))
                            .foregroundColor(isSelected ? Theme.bg : Theme.muted)
                        Text(shortName)
                            .font(KraftFont.mono(12.5, .bold))
                            .foregroundColor(isSelected ? Theme.bg : Theme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Theme.accent : Theme.surface)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func dayShortName(_ fullName: String, index: Int) -> String {
        let deShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let enShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let list = i18n.lang == "en" ? enShort : deShort
        if list.indices.contains(index) { return list[index] }
        return String(fullName.prefix(2))
    }

    // MARK: - Kopf

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(currentPlan.diet.localized(i18n.lang))
                    .font(KraftFont.inter(13, .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentDim)
                    .foregroundColor(Theme.accent)
                    .cornerRadius(10)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(activeDay.calculatedCalories) \(i18n.t("meal.perDay"))")
                        .font(KraftFont.mono(18, .bold))
                        .foregroundColor(Theme.text)
                    Text("\(activeDay.dayName)")
                        .font(KraftFont.inter(12, .medium))
                        .foregroundColor(Theme.accent)
                }
            }

            Text(currentPlan.diet.localizedDescription(i18n.lang))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var macrosGrid: some View {
        HStack(spacing: 12) {
            MacroCard(
                title: i18n.t("meal.protein"),
                grams: activeDay.calculatedProtein,
                color: Theme.accent,
                icon: "flame.fill"
            )
            MacroCard(
                title: i18n.t("meal.carbs"),
                grams: activeDay.calculatedCarbs,
                color: Color(hex: "3B82F6"),
                icon: "bolt.fill"
            )
            MacroCard(
                title: i18n.t("meal.fat"),
                grams: activeDay.calculatedFat,
                color: Color(hex: "F59E0B"),
                icon: "drop.fill"
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Mahlzeitenplan & Yazio-Style Editor

    private var mealScheduleList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("\(activeDay.dayName) — \(i18n.t("meal.timing"))")
                Spacer()
            }

            ForEach(activeDay.meals.indices, id: \.self) { mealIdx in
                let meal = activeDay.meals[mealIdx]
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(meal.time)
                            .font(KraftFont.mono(12, .bold))
                            .foregroundColor(Theme.accent)
                        Spacer()
                        Text("\(meal.effectiveCalories) kcal")
                            .font(KraftFont.mono(13.5, .bold))
                            .foregroundColor(Theme.text)
                    }

                    if !meal.name.isEmpty {
                        Text(meal.name)
                            .font(KraftFont.inter(15.5, .semibold))
                            .foregroundColor(Theme.text)
                    }

                    // Makro-Verteilung der einzelnen Mahlzeit
                    HStack(spacing: 6) {
                        mealMacroTag("P", "\(meal.effectiveProtein)g", Theme.accent)
                        mealMacroTag("K", "\(meal.effectiveCarbs)g", Theme.text)
                        mealMacroTag("F", "\(meal.effectiveFat)g", Theme.orange)
                    }
                    .padding(.vertical, 2)

                    // Standard-Zutatenliste
                    if !meal.items.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(meal.items, id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.accent.opacity(0.8))
                                    Text(item)
                                        .font(KraftFont.inter(13))
                                        .foregroundColor(Theme.text.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    // Benutzerdefinierte Zutaten (Yazio-Style)
                    if !meal.customEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(i18n.lang == "en" ? "CUSTOM INGREDIENTS" : "EIGENE ZUTATEN")
                                .font(KraftFont.inter(10, .bold))
                                .foregroundColor(Theme.accent)
                                .textCase(.uppercase)

                            ForEach(meal.customEntries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(KraftFont.inter(13, .semibold))
                                            .foregroundColor(Theme.text)
                                        Text("\(entry.amount) · \(entry.calories) kcal · P: \(entry.protein)g · K: \(entry.carbs)g · F: \(entry.fat)g")
                                            .font(KraftFont.inter(11))
                                            .foregroundColor(Theme.muted)
                                    }
                                    Spacer()
                                    Button {
                                        removeCustomFoodEntry(entry.id, fromMealAt: mealIdx)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.red.opacity(0.8))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Theme.surface2)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Aufklappen statt Blatt öffnen — der Plan bleibt sichtbar.
                    if addingToMealIndex == mealIdx {
                        InlineFoodComposer(
                            onAdd: { entry in
                                addCustomFoodEntry(entry, toMealAt: mealIdx)
                                withAnimation(.easeOut(duration: 0.18)) { addingToMealIndex = nil }
                            },
                            onCancel: {
                                withAnimation(.easeOut(duration: 0.18)) { addingToMealIndex = nil }
                            }
                        )
                        .padding(.top, 6)
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.18)) { addingToMealIndex = mealIdx }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13))
                                Text(i18n.t("meal.addFood"))
                                    .font(KraftFont.inter(12.5, .semibold))
                            }
                            .foregroundColor(Theme.accent)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Theme.accentDim)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    // Zubereitung / Anleitung
                    if let instr = meal.instructions, !instr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(i18n.lang == "en" ? "PREPARATION" : "ZUBEREITUNG")
                                .font(KraftFont.inter(10, .bold))
                                .foregroundColor(Theme.muted)
                                .textCase(.uppercase)
                            Text(instr)
                                .font(KraftFont.inter(12.5))
                                .foregroundColor(Theme.text.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(Theme.surface2)
                        .cornerRadius(8)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private func mealMacroTag(_ letter: String, _ val: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .font(KraftFont.mono(9.5, .bold))
                .foregroundColor(color)
            Text(val)
                .font(KraftFont.mono(10.5, .medium))
                .foregroundColor(Theme.muted)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Theme.surface2)
        .cornerRadius(5)
    }

    // MARK: - Detaillierte Protein-Shake & Supplement Karte

    private var shakesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(i18n.t("meal.shakeTitle"))

            ForEach(currentPlan.shakes) { shake in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.accent)
                            Text(i18n.t("meal.shakeTag"))
                                .font(KraftFont.mono(11, .bold))
                                .textCase(.uppercase)
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accentDim)
                        .cornerRadius(6)

                        Spacer()

                        Text(shake.when)
                            .font(KraftFont.inter(11.5, .semibold))
                            .foregroundColor(Theme.muted)
                    }

                    Text(shake.what)
                        .font(KraftFont.inter(14.5, .semibold))
                        .foregroundColor(Theme.text)

                    // Detaillierte Zubereitung & Pulvermenge
                    VStack(alignment: .leading, spacing: 6) {
                        if let powder = shake.powderAmount {
                            HStack(spacing: 6) {
                                Image(systemName: "scalemass.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.accent)
                                Text("\(i18n.t("meal.shakePowder")): \(powder)")
                                    .font(KraftFont.inter(12))
                                    .foregroundColor(Theme.text.opacity(0.9))
                            }
                        }

                        if let liquid = shake.liquid {
                            HStack(spacing: 6) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "3B82F6"))
                                Text("\(i18n.t("meal.shakeLiquid")): \(liquid)")
                                    .font(KraftFont.inter(12))
                                    .foregroundColor(Theme.text.opacity(0.9))
                            }
                        }

                        if let protein = shake.proteinGrams, let cal = shake.calories {
                            HStack(spacing: 6) {
                                mealMacroTag("P", "\(protein)g Protein", Theme.accent)
                                mealMacroTag("KCAL", "\(cal) kcal", Theme.text)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .background(Theme.surface2)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(i18n.t("meal.notes"))
            ForEach(currentPlan.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 7)
                    Text(note)
                        .font(KraftFont.inter(13))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !currentPlan.disclaimer.isEmpty {
                Text(currentPlan.disclaimer)
                    .font(KraftFont.inter(11))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Speichern & Aktualisieren

    private var isSaved: Bool { store.contains(currentPlan) }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isSaved ? "checkmark" : "bookmark.fill")
                    .font(.system(size: 14))
                Text(isSaved ? i18n.t("meal.alreadySaved") : i18n.t("meal.save"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(isSaved ? Theme.muted : Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSaved ? Theme.surface : Theme.accent)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSaved ? Theme.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaved)
        .padding(.horizontal, 20)
    }

    private var saveChangesButton: some View {
        Button(action: saveCustomChanges) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                Text(i18n.t("meal.saveChanges"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    private func saveCustomChanges() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onUpdate?(currentPlan)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        alert = .info(title: i18n.t("meal.savedTitle"), message: i18n.t("meal.changesSaved"))
    }

    private func save() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard storeKit.isProUnlocked else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            proNotice = SaveAlert.info(
                title: i18n.t("pro.badge"),
                message: i18n.t("ai.savingMealIsProFeature")
            )
            return
        }

        guard !isSaved else {
            alert = .info(title: i18n.t("meal.alreadySaved"), message: i18n.t("meal.savedBody"))
            return
        }

        if store.save(nutrition: currentPlan, name: suggestedName) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            alert = .info(title: i18n.t("meal.savedTitle"), message: i18n.t("meal.savedBody"))
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            alert = .error(
                title: i18n.t("meal.failedTitle"),
                message: i18n.t("meal.failedBody", ["reason": store.lastError ?? ""])
            )
        }
    }

    // MARK: - Zutat hinzufügen & entfernen

    private func addCustomFoodEntry(_ entry: FoodItemEntry, toMealAt mealIdx: Int) {
        var updatedSchedule = schedule
        guard updatedSchedule.indices.contains(selectedDayIndex) else { return }
        var day = updatedSchedule[selectedDayIndex]
        guard day.meals.indices.contains(mealIdx) else { return }

        var meal = day.meals[mealIdx]
        meal.customEntries.append(entry)
        day.meals[mealIdx] = meal
        updatedSchedule[selectedDayIndex] = day

        currentPlan.weeklySchedule = updatedSchedule
        if selectedDayIndex == 0 {
            currentPlan.meals = day.meals
        }
        onUpdate?(currentPlan)
    }

    private func removeCustomFoodEntry(_ entryId: UUID, fromMealAt mealIdx: Int) {
        var updatedSchedule = schedule
        guard updatedSchedule.indices.contains(selectedDayIndex) else { return }
        var day = updatedSchedule[selectedDayIndex]
        guard day.meals.indices.contains(mealIdx) else { return }

        var meal = day.meals[mealIdx]
        meal.customEntries.removeAll { $0.id == entryId }
        day.meals[mealIdx] = meal
        updatedSchedule[selectedDayIndex] = day

        currentPlan.weeklySchedule = updatedSchedule
        if selectedDayIndex == 0 {
            currentPlan.meals = day.meals
        }
        onUpdate?(currentPlan)
    }
}

// MARK: - Yazio-Style Zutat-Hinzufügen Sheet

/*
  Eine neue Zutat eintragen — direkt unter der Mahlzeit.

  Hier stand ein `AddFoodItemSheet`: ein NavigationStack mit einem
  Standard-`Form`. Zwei Dinge waren daran falsch.

  Erstens der Bildschirmwechsel. Wer im Plan eine Zutat ergänzen will,
  verliert dabei den Plan aus den Augen — und genau der ist der Grund, warum
  er die Zutat einträgt.

  Zweitens sah es als einziger Bildschirm der App nach Standard-iOS aus:
  helles `Form`, eigene Navigationsleiste, nichts von den Farben und
  Schriften ringsherum.

  Ergänzen heißt hier ausdrücklich NEU anlegen. Eine bestehende Zutat wird
  nicht bearbeitet — sie wird gelöscht und neu eingetragen. Das ist bei
  sechs Feldern der kürzere Weg als eine zweite Maske, die dasselbe noch
  einmal in „ändern" kann.
*/
struct InlineFoodComposer: View {
    @ObservedObject private var i18n = I18n.shared

    let onAdd: (FoodItemEntry) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""

    @FocusState private var nameFocused: Bool

    /// Ohne Namen wäre es eine Zeile ohne Aussage — alles andere darf leer
    /// bleiben und zählt dann als 0.
    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field(i18n.t("meal.foodName"), text: $name, wide: true)
                .focused($nameFocused)

            HStack(spacing: 8) {
                field(i18n.t("meal.foodAmount"), text: $amount)
                field("kcal", text: $calories, numeric: true)
            }

            HStack(spacing: 8) {
                field(i18n.t("meal.protein"), text: $protein, numeric: true, tint: Theme.accent)
                field(i18n.t("meal.carbs"), text: $carbs, numeric: true, tint: Color(hex: "3B82F6"))
                field(i18n.t("meal.fat"), text: $fat, numeric: true, tint: Theme.orange)
            }

            HStack(spacing: 8) {
                Button(action: onCancel) {
                    Text(i18n.t("auth.deleteCancel"))
                        .font(KraftFont.inter(12.5, .semibold))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface2))
                }
                .buttonStyle(.plain)

                Button(action: submit) {
                    Text(i18n.t("meal.addFood"))
                        .font(KraftFont.bebas(14)).tracking(0.8)
                        .foregroundColor(canAdd ? Theme.bg : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(canAdd ? Theme.accent : Theme.surface2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
        .onAppear { nameFocused = true }
    }

    private func field(
        _ placeholder: String,
        text: Binding<String>,
        numeric: Bool = false,
        wide: Bool = false,
        tint: Color = Theme.text
    ) -> some View {
        TextField(placeholder, text: text)
            .font(numeric ? KraftFont.mono(13, .medium) : KraftFont.inter(13))
            .foregroundColor(tint)
            .keyboardType(numeric ? .numberPad : .default)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
    }

    private func submit() {
        guard canAdd else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let cleanAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(
            FoodItemEntry(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                // Leer heißt „eine Portion" — eine erfundene Grammzahl wäre schlechter.
                amount: cleanAmount.isEmpty ? (i18n.lang == "en" ? "1 serving" : "1 Portion") : cleanAmount,
                calories: Int(calories) ?? 0,
                protein: Int(protein) ?? 0,
                carbs: Int(carbs) ?? 0,
                fat: Int(fat) ?? 0
            )
        )
    }
}

public struct SaveAlert: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let isError: Bool

    public static func info(title: String, message: String) -> SaveAlert {
        SaveAlert(title: title, message: message, isError: false)
    }

    public static func error(title: String, message: String) -> SaveAlert {
        SaveAlert(title: title, message: message, isError: true)
    }
}

public struct MacroCard: View {
    public let title: String
    public let grams: Int
    public let color: Color
    public let icon: String

    public init(title: String, grams: Int, color: Color, icon: String) {
        self.title = title
        self.grams = grams
        self.color = color
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text("\(grams)g")
                .font(KraftFont.mono(18, .bold))
                .foregroundColor(Theme.text)

            Text(title)
                .font(KraftFont.inter(11, .semibold))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
