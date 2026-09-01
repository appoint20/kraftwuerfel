import SwiftUI

/*
  GESPEICHERT — drei Sektionen.

  Vorher gab es zwei Reiter, und der zweite war eine Attrappe:
  `@State private var savedMealPlans: [NutritionPlan] = []` wurde nie befüllt,
  und da es `@State` war, hätte es einen Tabwechsel ohnehin nicht überlebt. Die
  Liste konnte gar nichts anderes zeigen als „noch nichts gespeichert“.

  Jetzt kommen alle drei Listen aus echten Speichern, und jede lässt sich
  wieder öffnen:

    Workouts    — gewürfelte Pläne aus dem Generator
    KI-Pläne    — komplette Trainingspläne aus dem KI-Coach   (neu)
    Meal Guides — Ernährungspläne aus dem KI-Coach            (neu)
*/
public struct SavedPlansView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var saved = SavedPlansStore.shared
    @ObservedObject private var aiPlans = SavedAIPlansStore.shared
    @ObservedObject private var mealGuides = SavedMealGuidesStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    private enum Section: String, CaseIterable {
        case workouts, aiPlans, mealGuides

        var titleKey: String {
            switch self {
            case .workouts:   return "saved.tabWorkouts"
            case .aiPlans:    return "saved.tabAIPlans"
            case .mealGuides: return "saved.tabMealGuides"
            }
        }

        var icon: String {
            switch self {
            case .workouts:   return "dumbbell.fill"
            case .aiPlans:    return "sparkles"
            case .mealGuides: return "leaf.fill"
            }
        }
    }

    @State private var section: Section = .workouts
    @State private var openPlanId: UUID?
    @State private var openedAIPlan: SavedAIPlan?
    @State private var openedMealGuide: SavedMealGuide?
    @State private var showPro: Bool = false

    /*
      Einen Plan aktiv zu setzen ersetzt den laufenden — samt Fortschritt.
      Das ist nicht rückgängig zu machen, deshalb wird gefragt, statt es
      einfach zu tun.
    */
    @State private var pendingActivation: PendingActivation?

    enum PendingActivation: Identifiable {
        case workout(SavedWorkoutPlan)
        case aiPlan(SavedAIPlan)

        var id: UUID {
            switch self {
            case .workout(let p): return p.id
            case .aiPlan(let p):  return p.id
            }
        }

        var name: String {
            switch self {
            case .workout(let p): return p.name
            case .aiPlan(let p):  return p.name
            }
        }
    }

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                sectionSwitcher

                switch section {
                case .workouts:   workoutsList
                case .aiPlans:    aiPlansList
                case .mealGuides: mealGuidesList
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(item: $openedAIPlan) { entry in
            SavedAIPlanSheet(entry: entry, onStartLiveWorkout: onStartLiveWorkout)
        }
        .sheet(item: $openedMealGuide) { entry in
            SavedMealGuideSheet(entry: entry)
        }
        .sheet(isPresented: $showPro) {
            ProSubscriptionView()
        }
        .kraftDialog(item: $pendingActivation) { target in
            KraftDialog(
                title: i18n.t("saved.setActiveTitle"),
                message: i18n.t(
                    ActivePlanStore.shared.plan == nil ? "saved.setActiveBody" : "saved.setActiveReplace",
                    ["name": target.name]
                ),
                icon: "calendar.badge.plus",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("saved.setActive"),
                onConfirm: {
                    activate(target)
                    pendingActivation = nil
                },
                onDismiss: { pendingActivation = nil }
            )
        }
    }

    /*
      Ein gespeichertes Workout ist EINE Einheit, ein KI-Plan ein ganzer
      Wochenplan — deshalb zwei Wege in denselben Speicher.

      Das einzelne Workout landet auf den Trainingstagen aus dem Profil: Das
      ist die Angabe, die der Nutzer ohnehin schon gemacht hat, und ohne sie
      müsste hier ein weiteres Formular stehen.
    */
    private func activate(_ target: PendingActivation) {
        switch target {
        case .workout(let plan):
            ActivePlanStore.shared.activate(
                slots: plan.slots,
                name: plan.name,
                days: Weekdays.sorted(UserProfileStore.shared.profile.selectedDays),
                durationWeeks: UserProfileStore.shared.profile.weeks
            )
        case .aiPlan(let entry):
            ActivePlanStore.shared.activate(trainingPlan: entry.plan, title: entry.name)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Umschalter

    private var sectionSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases, id: \.self) { s in
                sectionButton(s, count: count(for: s))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func count(for s: Section) -> Int {
        switch s {
        case .workouts:   return saved.plans.count
        case .aiPlans:    return aiPlans.items.count
        case .mealGuides: return mealGuides.items.count
        }
    }

    private func sectionButton(_ s: Section, count: Int) -> some View {
        let isActive = section == s
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) { section = s }
        }) {
            VStack(spacing: 3) {
                Image(systemName: s.icon).font(.system(size: 12, weight: .semibold))
                Text(i18n.t(s.titleKey))
                    .font(KraftFont.inter(11, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(count)")
                    .font(KraftFont.mono(10, .bold))
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isActive ? Theme.accent : Theme.surface)
            .foregroundColor(isActive ? Theme.bg : Theme.text)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workouts

    private func workoutActions(for plan: SavedWorkoutPlan) -> [PlanCardAction] {
        var actions: [PlanCardAction] = []
        if let onStartLiveWorkout {
            actions.append(PlanCardAction(i18n.t("live.startTraining"),
                                          systemImage: "play.fill", style: .primary) {
                onStartLiveWorkout(plan.slots, plan.name)
            })
        }
        actions.append(PlanCardAction(i18n.t("saved.setActive"), systemImage: "calendar.badge.plus") {
            pendingActivation = .workout(plan)
        })
        actions.append(PlanCardAction(i18n.t("saved.delete"),
                                      systemImage: "trash", style: .destructive) {
            saved.delete(plan)
        })
        return actions
    }

    @ViewBuilder
    private var workoutsList: some View {
        /*
          Gespeicherte Workouts sind eine Pro-Funktion — genau wie KI-Pläne
          und Meal Guides daneben. Dieser Abschnitt war als einziger offen:
          Wer Pro hatte, speicherte Pläne, und nach Ablauf des Abos standen
          sie weiter da. Genau das war zu sehen.

          Die Daten bleiben liegen und werden NICHT gelöscht. Ein abgelaufenes
          Abo ist kein Grund, die Arbeit des Nutzers wegzuwerfen — wer wieder
          abschließt, findet seine Pläne vor.
        */
        if !storeKit.isProUnlocked {
            proSavedGate(
                title: i18n.t("saved.tabWorkouts"),
                desc: ProFeature.savedPlans.localizedSubtitle(i18n.lang)
            )
        } else if saved.plans.isEmpty {
            EmptySavedState(icon: "bookmark.slash", text: i18n.t("saved.emptyWorkouts"))
        } else {
            VStack(spacing: 10) {
                ForEach(saved.plans) { plan in
                    PlanListCard(
                        title: plan.name,
                        meta: i18n.t("saved.exercises", ["n": "\(plan.slots.count)"]),
                        isOpen: openPlanId == plan.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                openPlanId = openPlanId == plan.id ? nil : plan.id
                            }
                        },
                        actions: workoutActions(for: plan)
                    ) {
                        PlanSlotRows(slots: plan.slots)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - KI-Pläne

    @ViewBuilder
    private var aiPlansList: some View {
        if !storeKit.isProUnlocked {
            proSavedGate(
                title: i18n.t("saved.tabAIPlans"),
                desc: i18n.lang == "en"
                    ? "Saving and managing AI workout plans is a Pro feature."
                    : "KI-Trainingspläne dauerhaft speichern und verwalten ist ein Pro-Feature."
            )
        } else if aiPlans.items.isEmpty {
            EmptySavedState(
                icon: "sparkles",
                text: i18n.t("saved.emptyAIPlans"),
                hint: i18n.t("saved.emptyAIPlansHint")
            )
        } else {
            VStack(spacing: 10) {
                ForEach(aiPlans.items) { entry in
                    SavedEntryCard(
                        title: entry.name,
                        meta: i18n.t("saved.days", ["n": "\(entry.plan.days.count)"])
                            + " · " + i18n.t("saved.weeks", ["n": "\(entry.plan.weeks)"])
                            + " · " + i18n.t("saved.exercises", ["n": "\(entry.exerciseCount)"]),
                        savedAt: entry.savedAt,
                        onOpen: { openedAIPlan = entry },
                        onDelete: { aiPlans.delete(entry) },
                        onActivate: { pendingActivation = .aiPlan(entry) }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Meal Guides

    @ViewBuilder
    private var mealGuidesList: some View {
        if !storeKit.isProUnlocked {
            proSavedGate(
                title: i18n.t("saved.tabMealGuides"),
                desc: i18n.lang == "en"
                    ? "Saving and managing AI nutrition guides is a Pro feature."
                    : "Ernährungspläne & Meal Guides dauerhaft speichern ist ein Pro-Feature."
            )
        } else if mealGuides.items.isEmpty {
            EmptySavedState(
                icon: "leaf.circle",
                text: i18n.t("saved.emptyMealGuides"),
                hint: i18n.t("saved.emptyMealGuidesHint")
            )
        } else {
            VStack(spacing: 10) {
                ForEach(mealGuides.items) { entry in
                    SavedEntryCard(
                        title: entry.name,
                        meta: entry.nutrition.diet.localized(i18n.lang)
                            + " · \(entry.nutrition.dailyCalories) " + i18n.t("meal.perDay"),
                        savedAt: entry.savedAt,
                        onOpen: { openedMealGuide = entry },
                        onDelete: { mealGuides.delete(entry) }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func proSavedGate(title: String, desc: String) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPro = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.accent)

                Text(title)
                    .font(KraftFont.bebas(20)).tracking(1.2)
                    .foregroundColor(Theme.text)

                Text(desc)
                    .font(KraftFont.inter(13))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(i18n.t("pro.cta"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .foregroundColor(Theme.accent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .padding(.horizontal, 20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(Theme.accent.opacity(0.6))
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bausteine

/// Eine Karte, die sich nicht aufklappt, sondern öffnet — für Inhalte, die zu
/// groß für eine Vorschauzeile sind.
struct SavedEntryCard: View {
    @ObservedObject private var i18n = I18n.shared

    let title: String
    let meta: String
    let savedAt: Date
    let onOpen: () -> Void
    let onDelete: () -> Void
    /// `nil`, wenn sich der Eintrag nicht als laufender Plan setzen lässt —
    /// ein Meal Guide ist kein Trainingsplan.
    var onActivate: (() -> Void)? = nil

    private var dateLabel: String {
        let df = DateFormatter()
        df.locale = i18n.locale
        df.setLocalizedDateFormatFromTemplate("ddMMyyyy")
        return df.string(from: savedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(KraftFont.bebas(18)).tracking(0.5)
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                Text(meta)
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
                    .lineLimit(2)
                Text(dateLabel)
                    .font(KraftFont.mono(10.5, .medium))
                    .foregroundColor(Theme.muted)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onOpen()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square").font(.system(size: 12, weight: .bold))
                        Text(i18n.t("saved.open"))
                            .font(KraftFont.bebas(14)).tracking(0.8)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.accent)
                    .foregroundColor(Theme.bg)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.red)
                        .frame(width: 40, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            /*
              „Als Plan starten" steht bewusst unter und nicht neben „Öffnen":
              Es ist die folgenreichere der beiden Aktionen — sie ersetzt den
              laufenden Plan — und soll nicht versehentlich getroffen werden,
              wenn jemand nur nachsehen wollte.
            */
            if let onActivate {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onActivate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus").font(.system(size: 12, weight: .bold))
                        Text(i18n.t("saved.setActive"))
                            .font(KraftFont.bebas(14)).tracking(0.8)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundColor(Theme.accent)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

struct EmptySavedState: View {
    let icon: String
    let text: String
    var hint: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(Theme.muted)
            Text(text)
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.muted)
            if let hint {
                Text(hint)
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
                    .opacity(0.75)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
    }
}

// MARK: - Blätter

/// Ein gespeicherter KI-Plan, geöffnet. Dieselbe Ansicht wie im Assistenten —
/// nur ohne Speichern-Knopf, denn hier ist er schon gespeichert.
struct SavedAIPlanSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = SavedAIPlansStore.shared
    @Environment(\.dismiss) private var dismiss

    let entry: SavedAIPlan
    var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    @State private var plan: TrainingPlan?
    @State private var viewingCycle = 1

    var body: some View {
        SheetFrame(title: entry.name) { dismiss() } content: {
            if plan != nil {
                AIPlanView(
                    plan: Binding(
                        get: { plan ?? entry.plan },
                        set: { persist($0) }
                    ),
                    viewingCycle: $viewingCycle,
                    input: entry.input,
                    onStartLiveWorkout: onStartLiveWorkout.map { start in
                        { slots, title in
                            dismiss()
                            start(slots, title)
                        }
                    },
                    showsSaveButton: false
                )
            }
        }
        // Der Plan folgt der Sprache, in der die App gerade läuft.
        .onAppear { plan = entry.localizedPlan(in: i18n.lang) }
        .onChange(of: i18n.lang) { lang in plan = entry.localizedPlan(in: lang) }
    }

    /*
      Ein bereits gespeicherter Plan hat keinen Speichern-Knopf mehr — eine
      Änderung an Sätzen oder Wiederholungen wandert deshalb sofort in den
      Speicher. Sonst wäre sie beim Schließen des Blatts weg.
    */
    private func persist(_ updated: TrainingPlan) {
        plan = updated
        store.replace(SavedAIPlan(
            id: entry.id,
            name: entry.name,
            plan: updated,
            input: entry.input,
            savedAt: entry.savedAt
        ))
    }
}

struct SavedMealGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: SavedMealGuide

    var body: some View {
        SheetFrame(title: entry.name) { dismiss() } content: {
            MealGuideView(
                nutrition: entry.nutrition,
                showsSaveButton: false,
                onUpdate: { updatedNutrition in
                    SavedMealGuidesStore.shared.replace(SavedMealGuide(
                        id: entry.id,
                        name: entry.name,
                        nutrition: updatedNutrition,
                        savedAt: entry.savedAt
                    ))
                }
            )
        }
    }
}

/// Kopfzeile mit Titel und Schließen — beide Blätter benutzen sie.
struct SheetFrame<Content: View>: View {
    @ObservedObject private var i18n = I18n.shared

    let title: String
    let onClose: () -> Void
    let content: Content

    init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(KraftFont.bebas(20)).tracking(1)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i18n.t("saved.close"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            content
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
