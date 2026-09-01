import SwiftUI

/*
  FortschrittView (Fortschritt-Tab) — Persönliches Trainingstagebuch, Körpergewicht-Tracking & Fortschrittsanalyse.

  Features:
  1. Körpergewicht & Zielgewicht-Tracker:
     - Zeigt aktuelles Gewicht, Zielgewicht, Delta (kg) und prozentualen Fortschritt / Abstand zum Ziel.
     - Interaktive Schnellanpassung für das tägliche Wiegen.
  2. Gesamtüberblick: Absolvierte Einheiten, Gesamtvolumen (kg/t), Trainingszeit.
  3. Interaktiver Übungs-Verlaufsgraph: Wähle eine Übung aus und sieh die
     Gewichts- & Volumensteigerung über die Zeit mit Trendindikator.
  4. Detailreiches Trainingstagebuch: Jedes beendete Workout mit allen Sätzen,
     Gewichten, Wiederholungen und KI-Abschlussnachrichten.
  5. UI-Garantie: Alle Chip- und Badge-Texte bleiben stets einzeilig ohne Zeilenumbruch.
*/

public struct FortschrittView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var history = WorkoutHistoryStore.shared
    @ObservedObject private var aiSession = AICoachSession.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var adManager = AdManager.shared

    @State private var selectedExercise: String = ""
    @State private var chartMetric: ChartMetric = .weight
    @State private var expandedSessionId: UUID?
    @State private var showWeightEditor: Bool = false
    @State private var showPro: Bool = false

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    private enum ChartMetric: String, CaseIterable {
        case weight, volume

        func title(lang: String) -> String {
            switch self {
            case .weight: return lang == "en" ? "Max Weight" : "Max. Gewicht"
            case .volume: return lang == "en" ? "Volume" : "Volumen"
            }
        }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                SectionLabel(i18n.lang == "en" ? "TRAINING PROGRESS & DIARY" : "TRAININGSFORTSCHRITT & TAGEBUCH")
                    .padding(.top, 4)

                // 1. Körpergewicht & Zielgewicht Fortschrittskarte
                bodyWeightProgressCard

                if history.logs.isEmpty {
                    emptyState
                } else {
                    // 2. Globale Statistiken
                    overviewCards

                    // 3. Übungs-Fortschrittsgraph
                    exerciseChartSection

                    // 4. Trainingstagebuch (Chronologische Liste)
                    workoutHistoryDiary
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
        .sheet(isPresented: $showWeightEditor) {
            WeightEditorSheet(aiSession: aiSession, i18n: i18n)
        }
        .sheet(isPresented: $showPro) {
            ProSubscriptionView()
        }
        .onAppear {
            if selectedExercise.isEmpty, let first = history.allLoggedExerciseNames.first {
                selectedExercise = first
            }
        }
    }

    // MARK: - 1. Körpergewicht & Zielgewicht Tracker

    private var bodyWeightProgressCard: some View {
        let currentWeight = aiSession.weightKg
        let goalWeight = aiSession.goalWeightKg
        let startWeight = aiSession.startWeightKg ?? currentWeight

        return VStack(alignment: .leading, spacing: 14) {
            // Kopfzeile mit Edit-Button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text(i18n.lang == "en" ? "BODY WEIGHT & GOAL" : "KÖRPERGEWICHT & ZIEL")
                        .font(KraftFont.inter(11, .bold))
                        .tracking(1)
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showWeightEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                        Text(i18n.lang == "en" ? "Update" : "Eintragen")
                            .font(KraftFont.inter(11, .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.accentDim)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // 3-Spalten Kennzahlen: Aktuell, Ziel, Delta / Prozent
            HStack(spacing: 10) {
                // Aktuelles Gewicht
                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.lang == "en" ? "Current" : "Aktuell")
                        .font(KraftFont.inter(10, .bold))
                        .foregroundColor(Theme.muted)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(formatWeight(currentWeight))
                        .font(KraftFont.mono(19, .bold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.surface2)
                .cornerRadius(10)

                // Zielgewicht
                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.lang == "en" ? "Goal" : "Ziel")
                        .font(KraftFont.inter(10, .bold))
                        .foregroundColor(Theme.muted)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(goalWeight != nil ? formatWeight(goalWeight!) : (i18n.lang == "en" ? "Not set" : "—"))
                        .font(KraftFont.mono(19, .bold))
                        .foregroundColor(goalWeight != nil ? Theme.text : Theme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.surface2)
                .cornerRadius(10)

                // Differenz / Prozentwert
                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.lang == "en" ? "To Goal" : "Zum Ziel")
                        .font(KraftFont.inter(10, .bold))
                        .foregroundColor(Theme.muted)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if let goal = goalWeight {
                        let delta = goal - currentWeight
                        let deltaSign = delta > 0 ? "+" : ""
                        let deltaText = String(format: "%@%.1f kg", deltaSign, delta)

                        Text(delta == 0 ? "🎯 " + (i18n.lang == "en" ? "Goal!" : "Erreicht!") : deltaText)
                            .font(KraftFont.mono(16, .bold))
                            .foregroundColor(delta == 0 ? Theme.accent : (delta < 0 ? Theme.accent : Theme.orange))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    } else {
                        Text("—")
                            .font(KraftFont.mono(19, .bold))
                            .foregroundColor(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Theme.surface2)
                .cornerRadius(10)
            }

            // Fortschrittsbalken & Prozentberechnung
            if let goal = goalWeight {
                let metrics = calculateWeightProgress(current: currentWeight, goal: goal, start: startWeight)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(metrics.statusText(lang: i18n.lang))
                            .font(KraftFont.inter(11, .medium))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer()

                        Text(metrics.percentageText)
                            .font(KraftFont.mono(12, .bold))
                            .foregroundColor(Theme.accent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.surface2)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.accent, Theme.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(metrics.fraction)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private struct WeightProgressResult {
        let fraction: Double
        let percentageText: String
        let deltaKg: Double
        let isGaining: Bool

        func statusText(lang: String) -> String {
            if abs(deltaKg) < 0.1 {
                return lang == "en" ? "🎉 Target weight achieved!" : "🎉 Zielgewicht erreicht!"
            } else if isGaining {
                return lang == "en"
                    ? String(format: "%.1f kg to gain", abs(deltaKg))
                    : String(format: "Noch %.1f kg zum Aufbau", abs(deltaKg))
            } else {
                return lang == "en"
                    ? String(format: "%.1f kg to lose", abs(deltaKg))
                    : String(format: "Noch %.1f kg zum Zielgewicht", abs(deltaKg))
            }
        }
    }

    private func calculateWeightProgress(current: Double, goal: Double, start: Double) -> WeightProgressResult {
        let delta = goal - current
        let isGaining = goal > start

        if abs(goal - start) < 0.1 {
            // Wenn Start gleich Ziel war, berechne direkte Ziel-Nähe
            let dist = abs(goal - current)
            let proximity = max(0.0, min(1.0, 1.0 - (dist / max(1.0, current))))
            let pct = proximity * 100.0
            return WeightProgressResult(
                fraction: proximity,
                percentageText: String(format: "%.1f%%", pct),
                deltaKg: delta,
                isGaining: isGaining
            )
        }

        let totalJourney = abs(goal - start)
        let progressMade = isGaining ? (current - start) : (start - current)
        let ratio = max(0.0, min(1.0, progressMade / totalJourney))
        let pct = ratio * 100.0

        return WeightProgressResult(
            fraction: ratio,
            percentageText: String(format: "%.1f%%", pct),
            deltaKg: delta,
            isGaining: isGaining
        )
    }

    // MARK: - Leerer Zustand

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.surface2)
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.accent)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text(i18n.lang == "en" ? "No Workouts Logged Yet" : "Noch keine Workouts absolviert")
                    .font(KraftFont.bebas(22)).tracking(1)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Text(i18n.lang == "en"
                     ? "Start a live session to track your weights, reps, and strength gains over time."
                     : "Starte ein Live-Workout, um deine tatsächlich gestemmten Gewichte und Steigerungen hier zu verfolgen.")
                    .font(KraftFont.inter(13.5))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Globale Statistiken

    private var overviewCards: some View {
        HStack(spacing: 10) {
            statMetricCard(
                icon: "flame.fill",
                title: i18n.lang == "en" ? "Workouts" : "Einheiten",
                value: "\(history.totalWorkoutsCount)"
            )

            statMetricCard(
                icon: "scalemass.fill",
                title: i18n.lang == "en" ? "Total Volume" : "Gesamtvolumen",
                value: formatTotalVolume(history.totalVolumeKg)
            )

            statMetricCard(
                icon: "clock.fill",
                title: i18n.lang == "en" ? "Time" : "Gesamtzeit",
                value: formatTotalTime(history.totalDurationMinutes)
            )
        }
    }

    private func statMetricCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(KraftFont.inter(10, .bold))
                    .foregroundColor(Theme.muted)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(value)
                .font(KraftFont.mono(17, .bold))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Übungs-Verlaufsgraph

    private var exerciseChartSection: some View {
        let availableExercises = history.allLoggedExerciseNames

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(i18n.lang == "en" ? "EXERCISE PROGRESSION" : "ÜBUNGS-ENTWICKLUNG")
                    .font(KraftFont.inter(11, .bold))
                    .tracking(1)
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                // Metrik-Umschalter
                HStack(spacing: 4) {
                    ForEach(ChartMetric.allCases, id: \.self) { metric in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            chartMetric = metric
                            adManager.triggerProgressAnalyticsAd()
                        }) {
                            Text(metric.title(lang: i18n.lang))
                                .font(KraftFont.inter(10.5, chartMetric == metric ? .bold : .medium))
                                .foregroundColor(chartMetric == metric ? Theme.bg : Theme.muted)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(chartMetric == metric ? Theme.accent : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
            }

            // Übungsauswahl (Horizontaler Pillen-Scroll)
            if !availableExercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableExercises, id: \.self) { name in
                            let isSelected = (selectedExercise.isEmpty && name == availableExercises.first) || selectedExercise == name
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedExercise = name
                                adManager.triggerProgressAnalyticsAd()
                            }) {
                                Text(name)
                                    .font(KraftFont.inter(12, isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Theme.accent : Theme.text)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Theme.accentDim : Theme.surface2)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            let currentEx = selectedExercise.isEmpty ? (availableExercises.first ?? "") : selectedExercise
            let dataPoints = history.exerciseProgression(for: currentEx)

            if dataPoints.isEmpty {
                Text(i18n.lang == "en" ? "No history for this exercise yet." : "Für diese Übung liegt noch kein Verlauf vor.")
                    .font(KraftFont.inter(12.5))
                    .foregroundColor(Theme.muted)
                    .padding(.vertical, 20)
            } else {
                // Graph & Kennzahlen
                progressionChartCard(exerciseName: currentEx, points: dataPoints)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func progressionChartCard(
        exerciseName: String,
        points: [(date: Date, maxWeight: Double, volume: Double, totalReps: Int)]
    ) -> some View {
        let values: [Double] = points.map { chartMetric == .weight ? $0.maxWeight : $0.volume }
        let firstVal = values.first ?? 0
        let lastVal = values.last ?? 0
        let diff = lastVal - firstVal
        let percent = firstVal > 0 ? (diff / firstVal) * 100.0 : 0

        return VStack(alignment: .leading, spacing: 14) {
            // Oberer Wert & Trend
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chartMetric == .weight ? formatWeight(lastVal) : formatVolume(lastVal))
                        .font(KraftFont.mono(26, .bold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text(i18n.lang == "en" ? "Latest Workout" : "Letztes Training")
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer()

                if points.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                        Text(String(format: "%@%.1f%% (%@%.1f kg)", diff >= 0 ? "+" : "", percent, diff >= 0 ? "+" : "", diff))
                            .font(KraftFont.mono(11.5, .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(diff >= 0 ? Theme.accent : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((diff >= 0 ? Theme.accent : Color.red).opacity(0.12))
                    .cornerRadius(6)
                }
            }

            // Zeichnung des Graphen
            ProgressionLineCanvas(values: values)
                .frame(height: 140)
                .padding(.vertical, 6)

            // Datumsangaben Anfang & Ende
            if let firstDate = points.first?.date, let lastDate = points.last?.date {
                HStack {
                    Text(formatDate(firstDate))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text(formatDate(lastDate))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .font(KraftFont.mono(10.5))
                .foregroundColor(Theme.muted)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Trainingstagebuch (Liste)

    private var workoutHistoryDiary: some View {
        /*
          Das Trainingsarchiv ist eine Pro-Funktion.

          Vorher waren die letzten drei Einheiten frei und der Rest gesperrt.
          Die Einheiten werden weiterhin für JEDEN mitgeschrieben — gesperrt
          ist das Ansehen, nicht das Aufzeichnen. Wer später abschließt,
          findet seine Vergangenheit vor, statt bei null anzufangen; und wer
          das Abo auslaufen lässt, verliert nichts.
        */
        let isFullArchiveUnlocked = storeKit.isProUnlocked
        let displayLogs = isFullArchiveUnlocked ? history.logs : []
        let lockedCount = isFullArchiveUnlocked ? 0 : history.logs.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(i18n.lang == "en" ? "WORKOUT DIARY" : "TRAININGSTAGEBUCH")
                    .font(KraftFont.inter(11, .bold))
                    .tracking(1)
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()

                if !history.logs.isEmpty {
                    Text(i18n.lang == "en" ? "\(history.logs.count) sessions" : "\(history.logs.count) Einheiten")
                        .font(KraftFont.mono(11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            VStack(spacing: 10) {
                ForEach(displayLogs) { log in
                    sessionDiaryCard(log)
                }

                if !isFullArchiveUnlocked && lockedCount > 0 {
                    archiveLockedCard(lockedCount: lockedCount)
                }
            }
        }
    }

    private func archiveLockedCard(lockedCount: Int) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.accent)
                Text(i18n.lang == "en" ? "FULL HISTORY ARCHIVE" : "VOLLSTÄNDIGES TAGEBUCH-ARCHIV")
                    .font(KraftFont.bebas(17)).tracking(1)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(i18n.lang == "en"
                 ? "+\(lockedCount) older workouts logged. Unlock your complete history archive."
                 : "+\(lockedCount) weitere Workouts im Archiv. Schalte dein gesamtes Trainingstagebuch frei.")
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            HStack(spacing: 10) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    adManager.watchRewardedVideoForHistoryArchive { _ in }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.rectangle.fill")
                        Text(i18n.lang == "en" ? "Watch Video (24h Free)" : "1 Video ansehen (24h)")
                            .font(KraftFont.bebas(14)).tracking(0.8)
                    }
                    .foregroundColor(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showPro = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("PRO")
                            .font(KraftFont.bebas(14)).tracking(0.8)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accentDim)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        .padding(.top, 4)
    }

    private func sessionDiaryCard(_ log: WorkoutSessionLog) -> some View {
        let isExpanded = expandedSessionId == log.id

        return VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSessionId = isExpanded ? nil : log.id
                }
            }) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.planTitle)
                                .font(KraftFont.bebas(19)).tracking(0.8)
                                .foregroundColor(Theme.text)
                                .lineLimit(1)

                            Text(formatDateTime(log.date))
                                .font(KraftFont.mono(11))
                                .foregroundColor(Theme.muted)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.muted)
                    }

                    // Kennzahlen-Leiste (stets einzeilig)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            diaryMetricBadge("clock", "\(max(1, log.durationSeconds / 60)) min")
                            diaryMetricBadge("scalemass", formatVolume(log.totalVolume))
                            diaryMetricBadge("dumbbell", "\(log.exercises.count) " + (i18n.lang == "en" ? "exercises" : "Übungen"))
                            if let cal = log.estimatedCalories, cal > 0 {
                                diaryMetricBadge("flame", "\(Int(cal)) kcal")
                            }
                        }
                    }

                    if !log.motivationalQuote.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.accent)
                            Text(log.motivationalQuote)
                                .font(KraftFont.inter(11.5, .medium))
                                .foregroundColor(Theme.text.opacity(0.9))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accentDim)
                        .cornerRadius(6)
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Ausklappbare Detail-Übungsliste
            if isExpanded {
                VStack(spacing: 10) {
                    Divider().background(Theme.border)

                    ForEach(log.exercises) { ex in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ex.exerciseName)
                                    .font(KraftFont.inter(13, .bold))
                                    .foregroundColor(Theme.accent)
                                    .lineLimit(1)
                                Spacer()
                                Text("Max: \(formatWeight(ex.maxWeight)) · Vol: \(formatVolume(ex.totalVolume))")
                                    .font(KraftFont.mono(11))
                                    .foregroundColor(Theme.muted)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            // Sätze
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(ex.sets) { s in
                                        HStack(spacing: 2) {
                                            Text("\(formatWeight(s.weight)) × \(s.reps)")
                                                .font(KraftFont.mono(10.5, .medium))
                                                .foregroundColor(s.done ? Theme.text : Theme.muted)
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(s.done ? Theme.surface2 : Color.clear)
                                        .cornerRadius(5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(s.done ? Theme.border : Theme.border.opacity(0.4), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }

                    // Löschen-Aktion
                    HStack {
                        Spacer()
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            history.delete(id: log.id)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text(i18n.lang == "en" ? "Delete Entry" : "Eintrag löschen")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(KraftFont.inter(11))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func diaryMetricBadge(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Theme.accent)
            Text(text)
                .font(KraftFont.mono(11, .medium))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.surface2)
        .cornerRadius(6)
    }

    // MARK: - Formatierungshelfer

    private func formatWeight(_ w: Double) -> String {
        w == w.rounded() ? "\(Int(w)) kg" : String(format: "%.1f kg", w)
    }

    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.1f t", v / 1000.0)
        } else {
            return "\(Int(v)) kg"
        }
    }

    private func formatTotalVolume(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.1f t", v / 1000.0)
        } else {
            return "\(Int(v)) kg"
        }
    }

    private func formatTotalTime(_ min: Int) -> String {
        if min >= 60 {
            let h = min / 60
            let m = min % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h) Std"
        } else {
            return "\(min) Min"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: i18n.lang)
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: i18n.lang)
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// MARK: - Schnellanpassung für Körpergewicht & Zielgewicht (Sheet)

private struct WeightEditorSheet: View {
    @ObservedObject var aiSession: AICoachSession
    @ObservedObject var i18n: I18n
    @Environment(\.dismiss) private var dismiss

    @State private var currentWeight: Double = 80.0
    @State private var goalWeight: Double = 75.0
    @State private var hasGoal: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                Text(i18n.lang == "en" ? "UPDATE BODY WEIGHT" : "GEWICHT AKTUALISIEREN")
                    .font(KraftFont.bebas(22)).tracking(1.2)
                    .foregroundColor(Theme.text)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // 1. Aktuelles Gewicht Stepper
                    VStack(alignment: .leading, spacing: 10) {
                        Text(i18n.lang == "en" ? "CURRENT WEIGHT" : "AKTUELLES KÖRPERGEWICHT")
                            .font(KraftFont.inter(11, .bold))
                            .tracking(1)
                            .foregroundColor(Theme.muted)

                        HStack {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                currentWeight = max(30, currentWeight - 0.5)
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.surface2)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(String(format: "%.1f kg", currentWeight))
                                .font(KraftFont.mono(26, .bold))
                                .foregroundColor(Theme.accent)

                            Spacer()

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                currentWeight = min(250, currentWeight + 0.5)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.surface2)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Theme.surface)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    }

                    // 2. Zielgewicht Stepper
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(i18n.lang == "en" ? "GOAL WEIGHT" : "ZIELGEWICHT")
                                .font(KraftFont.inter(11, .bold))
                                .tracking(1)
                                .foregroundColor(Theme.muted)

                            Spacer()

                            Toggle("", isOn: $hasGoal)
                                .labelsHidden()
                                .tint(Theme.accent)
                        }

                        if hasGoal {
                            HStack {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    goalWeight = max(30, goalWeight - 0.5)
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.text)
                                        .frame(width: 44, height: 44)
                                        .background(Theme.surface2)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Text(String(format: "%.1f kg", goalWeight))
                                    .font(KraftFont.mono(26, .bold))
                                    .foregroundColor(Theme.text)

                                Spacer()

                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    goalWeight = min(250, goalWeight + 0.5)
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.text)
                                        .frame(width: 44, height: 44)
                                        .background(Theme.surface2)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Theme.surface)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                        }
                    }

                    // Speichern Button
                    Button(action: {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        aiSession.weightKg = currentWeight
                        if aiSession.startWeightKg == nil {
                            aiSession.startWeightKg = currentWeight
                        }
                        aiSession.goalWeightKg = hasGoal ? goalWeight : nil
                        dismiss()
                    }) {
                        Text(i18n.lang == "en" ? "SAVE CHANGES" : "SPEICHERN")
                            .font(KraftFont.bebas(17)).tracking(1.5)
                            .foregroundColor(Theme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accent)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
                .padding(20)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            currentWeight = aiSession.weightKg
            if let gw = aiSession.goalWeightKg {
                goalWeight = gw
                hasGoal = true
            } else {
                goalWeight = aiSession.weightKg
                hasGoal = false
            }
        }
    }
}

// MARK: - Zeichnung des Graphen mit Bezier-Kurve & Datenpunkten

private struct ProgressionLineCanvas: View {
    let values: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard !values.isEmpty else { return }

            if values.count == 1 {
                // Ein einzelner Punkt
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let dot = Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
                ctx.fill(dot, with: .color(Theme.accent))
                return
            }

            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(1, hi - lo)
            let padding: CGFloat = 16
            let usableH = size.height - (padding * 2)

            var points: [CGPoint] = []
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) / CGFloat(values.count - 1) * (size.width - 24) + 12
                let norm = CGFloat((v - lo) / span)
                let y = (size.height - padding) - (norm * usableH)
                points.append(CGPoint(x: x, y: y))
            }

            // 1. Flächenfüllung unter der Kurve (Gradient)
            var area = Path()
            area.move(to: CGPoint(x: points[0].x, y: size.height))
            area.addLine(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                area.addQuadCurve(to: mid, control: prev)
                area.addQuadCurve(to: curr, control: mid)
            }
            area.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            area.closeSubpath()

            let fillGrad = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [Theme.accent.opacity(0.3), Theme.accent.opacity(0.0)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
            ctx.fill(area, with: fillGrad)

            // 2. Kurvenlinie
            var line = Path()
            line.move(to: points[0])
            for i in 1..<points.count {
                let prev = points[i - 1]
                let curr = points[i]
                let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                line.addQuadCurve(to: mid, control: prev)
                line.addQuadCurve(to: curr, control: mid)
            }
            ctx.stroke(line, with: .color(Theme.accent), lineWidth: 2.5)

            // 3. Datenpunkte
            for p in points {
                let dotBg = Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
                ctx.fill(dotBg, with: .color(Theme.surface))
                ctx.stroke(dotBg, with: .color(Theme.accent), lineWidth: 2)
            }

            // Letzten Punkt betonen
            if let last = points.last {
                let halo = Path(ellipseIn: CGRect(x: last.x - 7, y: last.y - 7, width: 14, height: 14))
                ctx.stroke(halo, with: .color(Theme.accent.opacity(0.4)), lineWidth: 2)
            }
        }
    }
}
