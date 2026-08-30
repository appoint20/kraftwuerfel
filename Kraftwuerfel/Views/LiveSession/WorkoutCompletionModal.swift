import SwiftUI

/*
  WorkoutCompletionModal — Feierliche Abschlussansicht nach Beenden eines
  Trainingstags mit dynamischer KI-Motivationsmeldung und Einheiten-Zusammenfassung.
*/
public struct WorkoutCompletionModal: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    let log: WorkoutSessionLog
    let onNavigateToProgress: () -> Void
    let onDismissSession: () -> Void

    public init(
        log: WorkoutSessionLog,
        onNavigateToProgress: @escaping () -> Void,
        onDismissSession: @escaping () -> Void
    ) {
        self.log = log
        self.onNavigateToProgress = onNavigateToProgress
        self.onDismissSession = onDismissSession
    }

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Trophäen-Kopfbereich
                    trophyHeader

                    // KI-Motivationsmeldung
                    quoteCard

                    // Trainingsstatistiken im Überblick
                    statsGrid

                    // Übungszusammenfassung
                    exercisesSummaryList

                    Spacer(minLength: 20)

                    // Aktions-Buttons
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Header

    private var trophyHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.0)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 65
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            VStack(spacing: 4) {
                Text(i18n.lang == "en" ? "WORKOUT COMPLETED!" : "TRAINING GESCHAFFT!")
                    .font(KraftFont.bebas(34)).tracking(1.5)
                    .foregroundColor(Theme.text)

                Text(log.planTitle)
                    .font(KraftFont.inter(14, .semibold))
                    .foregroundColor(Theme.muted)
            }
        }
    }

    // MARK: - Motivationsmeldung

    private var quoteCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.accent)

            Text(log.motivationalQuote)
                .font(KraftFont.inter(15, .semibold))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accent.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Statistik-Raster

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            statBox(
                icon: "clock.fill",
                title: i18n.lang == "en" ? "Duration" : "Dauer",
                value: "\(max(1, log.durationSeconds / 60)) Min"
            )

            statBox(
                icon: "scalemass.fill",
                title: i18n.lang == "en" ? "Total Volume" : "Gesamtvolumen",
                value: formatVolume(log.totalVolume)
            )

            statBox(
                icon: "checkmark.circle.fill",
                title: i18n.lang == "en" ? "Sets & Exercises" : "Sätze & Übungen",
                value: "\(log.completedSetsCount) / \(log.exercises.count)"
            )

            statBox(
                icon: "flame.fill",
                title: i18n.lang == "en" ? "Calories" : "Kalorien",
                value: "\(Int(log.estimatedCalories ?? Double(log.durationSeconds / 60 * 7))) kcal"
            )
        }
    }

    private func statBox(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.accent)
                Text(title)
                    .font(KraftFont.inter(10.5, .semibold))
                    .foregroundColor(Theme.muted)
                    .textCase(.uppercase)
            }

            Text(value)
                .font(KraftFont.mono(16, .bold))
                .foregroundColor(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Übungsliste

    private var exercisesSummaryList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(i18n.lang == "en" ? "COMPLETED EXERCISES" : "ABSOLVIERTE ÜBUNGEN")
                .font(KraftFont.inter(11, .bold))
                .tracking(1)
                .foregroundColor(Theme.muted)

            VStack(spacing: 6) {
                ForEach(log.exercises) { ex in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.exerciseName)
                                .font(KraftFont.inter(13.5, .semibold))
                                .foregroundColor(Theme.text)
                            Text("\(ex.completedSetsCount) \(i18n.lang == "en" ? "sets completed" : "Sätze abgeschlossen")")
                                .font(KraftFont.inter(11))
                                .foregroundColor(Theme.muted)
                        }

                        Spacer()

                        if ex.maxWeight > 0 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Max. \(formatWeight(ex.maxWeight))")
                                    .font(KraftFont.mono(13.5, .bold))
                                    .foregroundColor(Theme.accent)
                                Text("Vol: \(formatVolume(ex.totalVolume))")
                                    .font(KraftFont.mono(10.5))
                                    .foregroundColor(Theme.muted)
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            KraftPrimaryButton(
                i18n.lang == "en" ? "VIEW PROGRESS & DIARY" : "ZUM FORTSCHRITT & TAGEBUCH",
                systemImage: "chart.line.uptrend.xyaxis"
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onNavigateToProgress()
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismissSession()
            }) {
                Text(i18n.lang == "en" ? "Done" : "Fertig")
                    .font(KraftFont.inter(13.5, .semibold))
                    .foregroundColor(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

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
}
