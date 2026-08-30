import SwiftUI

/*
  Wie der Plan gebaut wird: Split, Methode, Umfang, Pause, Zyklen.

  Diese Einstellungen standen nur im Generator-Tab. Wer im Trainingsplan
  merkte, dass er lieber Ganzkörper statt Push/Pull will oder jede Woche
  denselben Plan statt zwei wechselnder, musste den Reiter wechseln, dort
  etwas umstellen und wieder zurück — und hatte unterwegs vergessen, worauf
  er hinauswollte.

  Das Blatt hier ist an beiden Stellen dasselbe. Es gibt genau eine
  Definition dieser Auswahl, so wie es genau ein Profil gibt.
*/
public struct PlanSetupSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var settings = GeneratorSettings.shared
    @Environment(\.dismiss) private var dismiss

    /*
      Läuft ein Plan, wirkt eine Änderung nicht rückwirkend: Der laufende Plan
      steht in ActivePlanStore und behält seine Übungen. Deshalb der Hinweis —
      eine Einstellung, die sichtbar nichts tut, ist schlimmer als keine.
    */
    private let hasActivePlan: Bool

    public init(hasActivePlan: Bool = false) {
        self.hasActivePlan = hasActivePlan
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if hasActivePlan { activePlanNote }

                    SectionLabel(i18n.t("gen.split"))
                    ChipGrid(count: 2) {
                        ForEach(SplitType.allCases) { split in
                            WizardCardChip(split.localized(i18n.lang), isActive: settings.split == split) {
                                settings.split = split
                            }
                        }
                    }

                    SectionLabel(i18n.t("gen.method"))
                    ChipGrid(count: TrainingMethod.allCases.count) {
                        ForEach(TrainingMethod.allCases) { m in
                            WizardCardChip(i18n.method(m), isActive: settings.method == m) {
                                settings.method = m
                            }
                        }
                    }

                    SectionLabel(i18n.t("planSetup.cycles"))
                    ChipGrid(count: 3) {
                        ForEach(CycleMode.allCases) { mode in
                            WizardCardChip(
                                mode.localized(i18n.lang),
                                subtitle: mode.localizedSubtitle(i18n.lang),
                                isActive: settings.cycleMode == mode
                            ) {
                                settings.cycleMode = mode
                            }
                        }
                    }

                    SectionLabel(i18n.t("gen.count"))
                    ChipGrid(columns: 4) {
                        ForEach([4, 5, 6, 7, 8, 9, 10], id: \.self) { n in
                            WizardCardChip("\(n)", isActive: settings.count == n) {
                                settings.count = n
                            }
                        }
                    }

                    SectionLabel(i18n.t("gen.rest"))
                    ChipGrid(columns: 4) {
                        ForEach(PlanGenerator.restOptions + [120], id: \.self) { s in
                            WizardCardChip("\(s)s", isActive: settings.restTime == s) {
                                settings.restTime = s
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var activePlanNote: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.top, 1)
            Text(i18n.t("planSetup.activeNote"))
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("planSetup.title"))
                    .font(KraftFont.bebas(22)).tracking(1.2)
                    .foregroundColor(Theme.text)
                Text(i18n.t("planSetup.subtitle"))
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
            }
            Spacer()
            Button(action: { dismiss() }) {
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
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}
