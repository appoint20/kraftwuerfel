import SwiftUI

/*
  HomeChallengeDiceView — 2-Würfel-Arena für Home- & Calisthenics-Workouts.
  Würfel 1: Sätze (Sets: 2..6 Sätze)
  Würfel 2: Wiederholungen (Reps: 10..40 Wdh)
  Darunter: Dynamischer Slot-Reel für die Bodyweight-Übung mit 3D-Perspektiven-Wurf.
*/

public struct HomeChallengeDiceView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var challengeStore = ChallengeStore.shared

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    @State private var isRolling: Bool = false
    @State private var dice1Pips: Int = 3
    @State private var dice2Pips: Int = 4
    @State private var exerciseIndex: Int = 0
    @State private var hasRolled: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var reelScrambleName: String = ""
    @State private var rollTimer: Timer?

    // Übungen (Home & Calisthenics)
    private struct ChallengeExerciseItem: Identifiable {
        let id: Int
        let nameDe: String
        let nameEn: String
        let icon: String
        let categoryDe: String
        let categoryEn: String
        let exerciseCategory: MuscleCategory
        let tipDe: String
        let tipEn: String

        func name(lang: String) -> String { lang == "en" ? nameEn : nameDe }
        func cat(lang: String) -> String { lang == "en" ? categoryEn : categoryDe }
        func tip(lang: String) -> String { lang == "en" ? tipEn : tipDe }
    }

    private let exerciseOptions: [ChallengeExerciseItem] = [
        ChallengeExerciseItem(
            id: 0, nameDe: "Liegestütze", nameEn: "Push-Ups",
            icon: "figure.strengthtraining.traditional", categoryDe: "Brust & Trizeps", categoryEn: "Chest & Triceps",
            exerciseCategory: .chest, tipDe: "Körperspannung halten, Ellenbogen im 45°-Winkel.", tipEn: "Keep core tight, elbows at 45 degrees."
        ),
        ChallengeExerciseItem(
            id: 1, nameDe: "Kniebeugen (Air Squats)", nameEn: "Air Squats",
            icon: "figure.cross.training", categoryDe: "Beine & Po", categoryEn: "Quads & Glutes",
            exerciseCategory: .legs, tipDe: "Fersen am Boden, Rücken aufrecht, 90° Tiefe.", tipEn: "Heels flat, chest up, hit full 90° depth."
        ),
        ChallengeExerciseItem(
            id: 2, nameDe: "Wall-Sit (Wandsitz)", nameEn: "Wall-Sit Static Hold",
            icon: "timer", categoryDe: "Oberschenkel (Statisch)", categoryEn: "Quads (Isometric)",
            exerciseCategory: .legs, tipDe: "Oberschenkel parallel zum Boden, Rücken an Wand.", tipEn: "Thighs parallel to floor, back flat on wall."
        ),
        ChallengeExerciseItem(
            id: 3, nameDe: "Unterarmstütz (Plank)", nameEn: "Forearm Plank",
            icon: "figure.core.training", categoryDe: "Core & Stabilität", categoryEn: "Core & Stability",
            exerciseCategory: .core, tipDe: "Bauch fest anspannen, kein Hohlkreuz bilden.", tipEn: "Squeeze abs tight, avoid arching your back."
        ),
        ChallengeExerciseItem(
            id: 4, nameDe: "Ausfallschritte (Lunges)", nameEn: "Walking Lunges",
            icon: "figure.walk", categoryDe: "Beine & Gesäß", categoryEn: "Legs & Glutes",
            exerciseCategory: .legs, tipDe: "Knie berührt fast den Boden, vorderes Knie stabil.", tipEn: "Back knee kisses the floor, front knee stable."
        ),
        ChallengeExerciseItem(
            id: 5, nameDe: "Burpees (Ganzkörper)", nameEn: "Full Body Burpees",
            icon: "flame.fill", categoryDe: "Ganzkörper & Cardio", categoryEn: "Full Body & Cardio",
            exerciseCategory: .fullBody, tipDe: "Explosiv abfedern und nach oben springen.", tipEn: "Explode up and jump high with hands over head."
        ),
        ChallengeExerciseItem(
            id: 6, nameDe: "Dips an Stuhl / Bank", nameEn: "Chair / Bench Dips",
            icon: "chair.lounge.fill", categoryDe: "Trizeps & Schultern", categoryEn: "Triceps & Shoulders",
            exerciseCategory: .triceps, tipDe: "Ellenbogen nach hinten beugen, Schultern tief.", tipEn: "Bend elbows backward, keep shoulders down."
        ),
        ChallengeExerciseItem(
            id: 7, nameDe: "Mountain Climbers", nameEn: "Mountain Climbers",
            icon: "figure.run", categoryDe: "Bauch & Ausdauer", categoryEn: "Abs & Endurance",
            exerciseCategory: .core, tipDe: "Knie abwechselnd dynamisch zur Brust ziehen.", tipEn: "Drive knees dynamically toward your chest."
        ),
        ChallengeExerciseItem(
            id: 8, nameDe: "Hollow Body Static Hold", nameEn: "Hollow Body Static Hold",
            icon: "figure.gymnastics", categoryDe: "Tiefe Bauchmuskeln", categoryEn: "Deep Core",
            exerciseCategory: .core, tipDe: "Unterer Rücken bleibt fest auf der Matte gepresst.", tipEn: "Press lower back firmly into the floor."
        ),
        ChallengeExerciseItem(
            id: 9, nameDe: "Glute Bridges (Beckenheben)", nameEn: "Glute Bridges",
            icon: "figure.mind.and.body", categoryDe: "Gesäß & Beinbeuger", categoryEn: "Glutes & Hamstrings",
            exerciseCategory: .legs, tipDe: "Oben für 2 Sekunden fest das Gesäß anspannen.", tipEn: "Squeeze glutes hard at the top for 2 seconds."
        ),
        ChallengeExerciseItem(
            id: 10, nameDe: "Jumping Jacks (Hampelmann)", nameEn: "Jumping Jacks",
            icon: "figure.jumping", categoryDe: "Warm-Up & Ausdauer", categoryEn: "Conditioning",
            exerciseCategory: .fullBody, tipDe: "Gleichmäßiger Rhythmus, weich auf Ballen landen.", tipEn: "Keep a continuous rhythm, land softly."
        ),
        ChallengeExerciseItem(
            id: 11, nameDe: "High Knees Sprint", nameEn: "High Knees Sprint",
            icon: "figure.highintensity.intervaltraining", categoryDe: "Cardio & Hüftbeuger", categoryEn: "HIIT & Cardio",
            exerciseCategory: .legs, tipDe: "Knie mindestens auf Hüfthöhe anziehen.", tipEn: "Drive knees up to at least hip height."
        )
    ]

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    public var body: some View {
        VStack(spacing: 16) {
            streakBanner

            // 3D Perspektiven-Würfel-Arena
            diceArena

            // Scrollende Slot-Reel Anzeige
            exerciseSlotReel

            // Würfel-Button
            rollButton

            // Gewürfeltes Ergebnis
            if hasRolled {
                resultCard
            } else {
                initialHint
            }
        }
        .padding(.horizontal, 20)
        .onDisappear {
            rollTimer?.invalidate()
            rollTimer = nil
            isRolling = false
        }
        .sheet(isPresented: $showSettingsSheet) {
            ChallengeSettingsView()
        }
    }

    // MARK: - Streak & Status Banner

    private var streakBanner: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.orange.opacity(0.2)).frame(width: 32, height: 32)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(challengeStore.category.title(language: i18n.lang))
                        .font(KraftFont.bebas(14)).tracking(0.5)
                        .foregroundColor(Theme.text)
                    Text("Tag \(challengeStore.currentDayNumber) von \(challengeStore.durationDays) · \(challengeStore.streak) Tage Streak")
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                }
            }

            Spacer()

            Button(action: { showSettingsSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11))
                    Text(i18n.lang == "en" ? "Config" : "Anpassen")
                        .font(KraftFont.inter(11.5, .semibold))
                }
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentDim))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - 2 Würfel Arena (Perspektiven-Wurf & 3D Metallic Dice)

    private var diceArena: some View {
        Futuristic3DDiceArenaView(
            dice1Sets: currentSetsCount,
            dice2Reps: currentRepsCount,
            dice1Pips: dice1Pips,
            dice2Pips: dice2Pips,
            isRolling: isRolling,
            onRoll: {
                rollDice()
            }
        )
    }

    private var currentSetsCount: Int {
        switch dice1Pips {
        case 1: return 2
        case 2: return 3
        case 3: return 3
        case 4: return 4
        case 5: return 5
        default: return 6
        }
    }

    private var currentRepsCount: Int {
        switch dice2Pips {
        case 1: return 10
        case 2: return 15
        case 3: return 20
        case 4: return 25
        case 5: return 30
        default: return 40
        }
    }

    // MARK: - Dynamischer Slot-Reel für Übungen

    private var exerciseSlotReel: some View {
        let currentEx = exerciseOptions[exerciseIndex % exerciseOptions.count]
        let displayName = isRolling && !reelScrambleName.isEmpty
            ? reelScrambleName
            : currentEx.name(lang: i18n.lang)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: currentEx.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(i18n.lang == "en" ? "CHALLENGE EXERCISE SLOT" : "CHALLENGE ÜBUNGS-SLOT")
                        .font(KraftFont.mono(9.5, .bold))
                        .foregroundColor(Theme.accent)
                        .tracking(0.5)

                    if isRolling {
                        DiceLoaderView(size: 24, showGlow: false)
                    }
                }

                Text(displayName)
                    .font(KraftFont.bebas(20))
                    .tracking(0.8)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(currentSetsCount) × \(currentRepsCount)")
                    .font(KraftFont.mono(14, .bold))
                    .foregroundColor(Theme.orange)

                Text(i18n.lang == "en" ? "Sets × Reps" : "Sätze × Wdh")
                    .font(KraftFont.inter(10))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isRolling ? Theme.accent : Theme.border, lineWidth: isRolling ? 1.5 : 1)
        )
        .shadow(color: isRolling ? Theme.accent.opacity(0.2) : Color.clear, radius: 8)
        .animation(.easeInOut(duration: 0.2), value: isRolling)
    }

    // MARK: - Würfel-Button

    private var rollButton: some View {
        KraftGradientButton(
            i18n.lang == "en" ? "ROLL 3D PERSPECTIVE DICE" : "3D WÜRFEL WERFEN",
            systemImage: "dice.fill",
            isEnabled: !isRolling
        ) {
            rollDice()
        }
    }

    // MARK: - Ergebnis Karte

    private var resultCard: some View {
        let ex = exerciseOptions[exerciseIndex % exerciseOptions.count]
        let sets = currentSetsCount
        let reps = currentRepsCount
        let totalReps = sets * reps

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.orange)
                Text(i18n.lang == "en" ? "YOUR ROLLED CHALLENGE" : "DEINE GEWÜRFELTE CHALLENGE")
                    .font(KraftFont.bebas(16)).tracking(1)
                    .foregroundColor(Theme.text)
                Spacer()
                Text("HOME BODYWEIGHT")
                    .font(KraftFont.mono(9.5, .bold))
                    .foregroundColor(Theme.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("\(ex.name(lang: i18n.lang))")
                    .font(KraftFont.bebas(24)).tracking(1)
                    .foregroundColor(Theme.text)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill").font(.system(size: 11)).foregroundColor(Theme.accent)
                        Text("\(sets) " + (i18n.lang == "en" ? "Sets" : "Sätze"))
                            .font(KraftFont.inter(13.5, .bold))
                            .foregroundColor(Theme.accent)
                    }

                    Text("·")
                        .foregroundColor(Theme.muted)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 11)).foregroundColor(Theme.orange)
                        Text("\(reps) " + (i18n.lang == "en" ? "Reps per Set" : "Wdh pro Satz"))
                            .font(KraftFont.inter(13.5, .bold))
                            .foregroundColor(Theme.orange)
                    }

                    Text("·")
                        .foregroundColor(Theme.muted)

                    Text("∑ \(totalReps) " + (i18n.lang == "en" ? "Total" : "Gesamt"))
                        .font(KraftFont.mono(12, .semibold))
                        .foregroundColor(Theme.muted)
                }
            }

            Text("💡 Tipp: \(ex.tip(lang: i18n.lang))")
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            // Aktions-Knöpfe
            HStack(spacing: 10) {
                // Live Workout Starten
                if let onStartLiveWorkout {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        let dummyExercise = Exercise(
                            name: ex.nameDe,
                            nameEn: ex.nameEn,
                            category: ex.exerciseCategory,
                            equipment: .bodyweight
                        )
                        let slot = ExerciseSlot(
                            exercise: dummyExercise,
                            sets: sets,
                            reps: "\(reps)"
                        )
                        onStartLiveWorkout([slot], "Challenge: \(ex.name(lang: i18n.lang))")
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 12))
                            Text(i18n.lang == "en" ? "START LIVE" : "LIVE STARTEN")
                                .font(KraftFont.bebas(14)).tracking(1)
                        }
                        .foregroundColor(Theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }

                // Heute abhaken
                Button(action: {
                    challengeStore.markTodayCompleted()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: challengeStore.isCompletedToday ? "checkmark.circle.fill" : "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text(challengeStore.isCompletedToday
                             ? (i18n.lang == "en" ? "COMPLETED 🔥" : "ERLEDIGT 🔥")
                             : (i18n.lang == "en" ? "CHECK OFF" : "ABHAKEN (+1)"))
                            .font(KraftFont.bebas(14)).tracking(1)
                    }
                    .foregroundColor(challengeStore.isCompletedToday ? Theme.bg : Theme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(challengeStore.isCompletedToday ? Theme.orange : Theme.surface2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(challengeStore.isCompletedToday ? Theme.orange : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Theme.orange.opacity(0.6), Theme.accent.opacity(0.4), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Theme.orange.opacity(0.15), radius: 10, y: 4)
    }

    private var initialHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "house.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.muted)
            Text(i18n.lang == "en"
                 ? "No gym? No problem! Throw the 3D dice to roll your sets, reps, and exercise challenge."
                 : "Kein Fitnessstudio? Wirf die 3D-Würfel für Sätze, Wiederholungen und deine Home-Challenge.")
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Würfel- & Reel-Logik mit 3D Perspektive

    private func rollDice() {
        guard !isRolling else { return }
        isRolling = true
        hasRolled = false
        rollTimer?.invalidate()
        rollTimer = nil
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        var step = 0
        let totalSteps = 12

        // Schnelles Scrambling & Durchlaufen der Reel-Texte während des Flugs
        rollTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [self] timer in
            step += 1
            dice1Pips = Int.random(in: 1...6)
            dice2Pips = Int.random(in: 1...6)
            let randomEx = exerciseOptions.randomElement()!
            reelScrambleName = randomEx.name(lang: i18n.lang)

            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            if step >= totalSteps {
                timer.invalidate()
                rollTimer = nil
                exerciseIndex = Int.random(in: 0..<exerciseOptions.count)
                reelScrambleName = ""

                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isRolling = false
                    hasRolled = true
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
