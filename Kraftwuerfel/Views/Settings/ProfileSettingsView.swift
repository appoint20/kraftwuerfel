import SwiftUI

/*
  Das Profil ändern.

  Dieselben Felder wie im Fragebogen nach der Registrierung — nicht
  nachgebaut, sondern dieselben Ansichten (ProfileFormSections). Ein zweites
  Formular hätte beim nächsten neuen Feld genau eine Seite bekommen und die
  andere nicht.
*/
public struct ProfileSettingsView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared
    @ObservedObject private var health = HealthKitManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    Text(i18n.t("profile.subtitle"))
                        .font(KraftFont.inter(13.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    group(i18n.t("profile.sectionBody")) {
                        // Ohne die große Auswertung: in einer Liste zum
                        // Nachbessern ist sie zwischen den Feldern nur im Weg.
                        ProfileBodySection(showsEvaluation: false)
                    }
                    group(i18n.t("profile.sectionGoal")) { ProfileGoalSection() }
                    group(i18n.t("profile.sectionTraining")) { ProfileTrainingSection() }
                    group(i18n.t("profile.sectionChallenge")) { ProfileChallengeSection() }
                    group(i18n.t("profile.sectionNutrition")) { ProfileNutritionSection() }
                    group(i18n.t("profile.sectionHealth")) { HealthConnectCard() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 44)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .dismissKeyboardOnTap()
        .onDisappear {
            /*
              Wer hier war, hat seine Angaben gesehen und angepasst — das
              zählt als beantwortet. Sonst stünde die Aufforderung, den
              Fragebogen auszufüllen, weiter im Coach, obwohl der Nutzer
              gerade jedes Feld durchgegangen ist.
            */
            store.markComplete()
        }
    }

    private var header: some View {
        HStack {
            Text(i18n.t("profile.title"))
                .font(KraftFont.bebas(24)).tracking(1.2)
                .foregroundColor(Theme.text)
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

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(KraftFont.bebas(15))
                .tracking(1.5)
                .foregroundColor(Theme.accent)
            content()
        }
    }
}

/*
  Was im KI-Coach und in der Home-Challenge steht, solange der Fragebogen
  nicht ausgefüllt ist.

  Der Fragebogen ist überspringbar — dann muss aber an der Stelle, an der die
  Antworten wirklich gebraucht werden, ein Weg dorthin stehen. Eine
  Fehlermeldung „Profil unvollständig“ ohne Knopf wäre eine Sackgasse.
*/
public struct ProfileGateView: View {
    @ObservedObject private var i18n = I18n.shared
    @State private var showOnboarding = false

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.text.rectangle")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text(i18n.t("profile.incompleteTitle"))
                .font(KraftFont.inter(16, .bold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)

            Text(i18n.t("profile.incompleteText"))
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            KraftPrimaryButton(i18n.t("profile.incompleteCta"), systemImage: "arrow.right", compact: true) {
                showOnboarding = true
            }
            .frame(maxWidth: 260)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
    }
}
