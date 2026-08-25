import ActivityKit
import SwiftUI
import WidgetKit

/*
  Die Sperrbildschirm-Karte und die Dynamic Island.

  Zwei Regeln bestimmen den Aufbau:

  1. Die Pause zählt die Karte selbst herunter — `Text(timerInterval:)` läuft
     ohne Update weiter. ActivityKit drosselt Aktualisierungen; ein
     Sekundentakt aus der App käme nicht durch.

  2. Der Puls steht nur da, wenn er von einem Sensor kommt. Ein Schätzwert
     bekommt das Wort "geschätzt" daneben, genau wie in der App. Auf einer
     Karte, die neben Apples eigenen Trainingsdaten liegt, darf eine gerechnete
     Zahl nicht wie ein Messwert aussehen.
*/
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenCard(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Theme.bg)
            .activitySystemActionForegroundColor(Theme.accent)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Strings.t(context.state.isResting ? "live.rest" : "live.set",
                                    lang: context.state.language))
                            .textCase(.uppercase)
                            .font(KraftFont.bebas(13)).tracking(1.4)
                            .foregroundColor(Theme.accent)
                        Text("\(context.state.setNumber)/\(context.state.totalSets)")
                            .font(KraftFont.mono(19, .bold))
                            .foregroundColor(Theme.text)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let endsAt = context.state.restEndsAt, context.state.isResting {
                        Text(timerInterval: Date()...endsAt, countsDown: true)
                            .font(KraftFont.mono(19, .bold))
                            .foregroundColor(Theme.accent)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 68)
                    } else {
                        HeartRateBadge(state: context.state, compact: true)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.exerciseName)
                            .font(KraftFont.bebas(19)).tracking(0.7)
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        ExerciseProgressBar(state: context.state)
                    }
                }

            } compactLeading: {
                Image(systemName: context.state.isResting ? "pause.fill" : "dumbbell.fill")
                    .foregroundColor(Theme.accent)

            } compactTrailing: {
                if let endsAt = context.state.restEndsAt, context.state.isResting {
                    Text(timerInterval: Date()...endsAt, countsDown: true)
                        .font(KraftFont.mono(13, .bold))
                        .foregroundColor(Theme.accent)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                } else {
                    Text("\(context.state.setNumber)/\(context.state.totalSets)")
                        .font(KraftFont.mono(13, .bold))
                        .foregroundColor(Theme.accent)
                }

            } minimal: {
                Image(systemName: context.state.isResting ? "pause.fill" : "dumbbell.fill")
                    .foregroundColor(Theme.accent)
            }
            .keylineTint(Theme.accent)
        }
    }
}

// MARK: - Sperrbildschirm

private struct LockScreenCard: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.planTitle.uppercased())
                        .font(KraftFont.bebas(18)).tracking(1.1)
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text(Strings.t("live.exerciseOf", lang: state.language, [
                        "current": "\(state.exerciseIndex + 1)",
                        "total": "\(state.totalExercises)",
                    ]))
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                }

                Spacer(minLength: 8)

                // Gesamtdauer läuft ohne Update weiter.
                Text(timerInterval: attributes.startedAt...Date.distantFuture, countsDown: false)
                    .font(KraftFont.mono(13, .bold))
                    .foregroundColor(Theme.accent)
                    .monospacedDigit()
                    .frame(maxWidth: 62, alignment: .trailing)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.exerciseName)
                        .font(KraftFont.bebas(24)).tracking(0.9)
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(Strings.t("live.setOf", lang: state.language, [
                        "current": "\(state.setNumber)",
                        "total": "\(state.totalSets)",
                    ]))
                        .font(KraftFont.inter(12, .medium))
                        .foregroundColor(Theme.muted)
                }

                Spacer(minLength: 8)

                if state.isResting, let endsAt = state.restEndsAt {
                    VStack(spacing: 1) {
                        Text(timerInterval: Date()...endsAt, countsDown: true)
                            .font(KraftFont.mono(26, .bold))
                            .foregroundColor(Theme.accent)
                            .monospacedDigit()
                            .frame(maxWidth: 88)
                        Text(Strings.t("live.rest", lang: state.language))
                            .textCase(.uppercase)
                            .font(KraftFont.bebas(11)).tracking(2)
                            .foregroundColor(Theme.accent)
                    }
                } else {
                    HeartRateBadge(state: state, compact: false)
                }
            }

            ExerciseProgressBar(state: state)
        }
        .padding(16)
    }
}

// MARK: - Bausteine

private struct ExerciseProgressBar: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        GeometryReader { geo in
            let total = max(1, state.totalExercises)
            let gap: CGFloat = 3
            let width = max(2, (geo.size.width - gap * CGFloat(total - 1)) / CGFloat(total))

            HStack(spacing: gap) {
                ForEach(0..<total, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= state.exerciseIndex ? Theme.accent : Theme.surface2)
                        .frame(width: width, height: 4)
                }
            }
        }
        .frame(height: 4)
    }
}

/// Zeigt den Puls — oder gar nichts, wenn keiner vorliegt. Ein Schätzwert
/// bekommt sein Etikett; ein Messwert nennt die Quelle.
private struct HeartRateBadge: View {
    let state: WorkoutActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        if let bpm = state.heartRate {
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: compact ? 10 : 12))
                        .foregroundColor(Theme.pink)
                    Text("\(bpm)")
                        .font(KraftFont.mono(compact ? 17 : 22, .bold))
                        .foregroundColor(Theme.text)
                }
                Text(Strings.t(state.heartRateSource == .appleWatch
                            ? "live.sourceWatch" : "live.estimated",
                            lang: state.language))
                    .textCase(.uppercase)
                    .font(KraftFont.inter(compact ? 7.5 : 8.5, .bold))
                    .tracking(0.6)
                    .foregroundColor(Theme.muted)
            }
        }
    }
}
