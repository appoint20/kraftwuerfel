import SwiftUI

/*
  Der Start der Home-Challenge.

  Hier stand ein Fragebogen über fünf Schritte — und derselbe Fragebogen
  stand ein zweites Mal im KI-Coach. Geschlecht, Alter, Größe, Gewicht,
  Erfahrung und Ernährungsform wurden an beiden Stellen erhoben und konnten
  auseinanderlaufen: Wer im Coach 82 kg eintrug, startete die Challenge
  weiter mit 75 kg.

  Beide lesen die Antworten jetzt aus dem Profil (UserProfile), das einmal
  nach der Registrierung ausgefüllt wird. Übrig bleibt: zeigen, womit
  gerechnet wird, und ein Knopf.

  Der Startknopf trägt jetzt dasselbe Mint wie überall sonst. Der Verlauf
  (Mint nach Orange) gehört zur Würfel-Arena; auf dieser Seite stand er
  allein und ließ denselben Knopf je nach Tab anders aussehen.
*/
public struct HomeChallengeWizardView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var session = ChallengeSession.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var profileStore = UserProfileStore.shared

    public var onSubmit: () -> Void

    @State private var showAuth = false
    @State private var showProfile = false

    public init(onSubmit: @escaping () -> Void) {
        self.onSubmit = onSubmit
    }

    public var body: some View {
        Group {
            if !profileStore.profile.isComplete {
                ProfileGateView()
            } else if !profileStore.profile.wantsChallenge {
                // Abgewählt heißt abgewählt — aber mit einem Weg zurück.
                challengeOffCard
            } else {
                ready
            }
        }
        /*
          Der Einzug sitzt hier, nicht im GeneratorView: Der Ergebnis-Zweig
          der Challenge zeigt AIPlanView und MealGuideView, und die bringen
          ihre eigenen 20 Punkte schon mit. Ein Einzug außen herum würde
          dort doppelt zählen.
        */
        .padding(.horizontal, 20)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showProfile) { ProfileSettingsView() }
    }

    private var challengeOffCard: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "flame")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(Theme.muted)
            Text(i18n.t("challenge.disabledTitle"))
                .font(KraftFont.inter(16, .bold))
                .foregroundColor(Theme.text)
            Text(i18n.t("challenge.disabledText"))
                .font(KraftFont.inter(13.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            KraftPrimaryButton(i18n.t("profile.title"), systemImage: "slider.horizontal.3", compact: true) {
                showProfile = true
            }
            .frame(maxWidth: 240)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 16) {
            AiIntroBox(i18n.t("ready.challengeText"))

            profileCard

            if let error = session.errorMessage {
                errorCard(error)
            }

            /*
              Mint wie überall sonst. Der Verlauf (Mint nach Orange) stammt
              aus der Würfel-Arena und stand hier allein auf weiter Flur —
              derselbe Knopf in zwei Farben, je nachdem in welchem Tab man
              gerade steht.
            */
            KraftPrimaryButton(i18n.t("ready.generateChallenge"), systemImage: "flame.fill") {
                onSubmit()
            }
        }
    }

    // MARK: - Womit gerechnet wird

    private var profileCard: some View {
        let p = profileStore.profile
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(i18n.t("ready.profileTitle"))
                    .font(KraftFont.bebas(15)).tracking(1.5)
                    .foregroundColor(Theme.accent)
                Spacer()
                Button(action: { showProfile = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 11, weight: .bold))
                        Text(i18n.t("ready.edit")).font(KraftFont.inter(12.5, .semibold))
                    }
                    .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                ReviewRow(i18n.t("ai.goal"), p.challengeGoal.localized(i18n.lang), highlight: true)
                ReviewRow(
                    i18n.lang == "en" ? "Length" : "Länge",
                    i18n.lang == "en" ? "\(p.challengeDurationDays) days" : "\(p.challengeDurationDays) Tage"
                )
                ReviewRow(
                    i18n.lang == "en" ? "Days per week" : "Tage pro Woche",
                    "\(p.challengeDaysPerWeek) · \(p.challengeDays.joined(separator: " "))"
                )
                ReviewRow(
                    i18n.t("ai.duration"),
                    i18n.t("ai.minutes", ["n": "\(p.challengeSessionMinutes)"])
                )
                ReviewRow(
                    i18n.t("ai.biometricsTitle"),
                    "\(p.age) · \(Int(p.heightCm)) cm · \(Int(p.weightKg)) kg"
                )
                ReviewRow(
                    i18n.t("ai.equipment"),
                    p.challengeEquipment
                        .sorted { $0.rawValue < $1.rawValue }
                        .map { $0.localized(i18n.lang) }
                        .joined(separator: ", ")
                )
                ReviewRow(i18n.t("ai.dietTitle"), p.diet.localized(i18n.lang), isLast: true)
            }
        }
        .padding(16)
        .kraftCard()
    }

    // MARK: - Fehler

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.t("ai.errorTitle"))
                        .font(KraftFont.bebas(15)).tracking(1)
                        .foregroundColor(Theme.text)
                    Text(message)
                        .font(KraftFont.inter(12.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !auth.isSignedIn {
                Button { showAuth = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.key.fill").font(.system(size: 13))
                        Text(i18n.t("auth.signIn")).font(KraftFont.inter(12.5, .semibold))
                    }
                    .foregroundColor(Theme.bg)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Theme.accent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.5), lineWidth: 1))
    }
}
