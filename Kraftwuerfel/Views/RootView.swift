import SwiftUI

/*
  Die Weiche beim Start: Anmeldung oder App.

  Vorher startete die App direkt in MainTabView, und die Anmeldung lag als
  Blatt in den Einstellungen — benutzbar war ohne Konto trotzdem fast alles.
  Das führte zu einem Zustand, den niemand wollte: Pläne, Fortschritt und
  Favoriten lagen auf dem Gerät, ohne dass sie zu jemandem gehörten. Wer das
  Telefon wechselte, fing bei null an, und das Pro-Abo hing an einer Apple-ID,
  während die Daten am Gerät hingen.

  Jetzt gilt: erst anmelden, dann die App. Was danach kommt, entscheidet der
  Zustand des Profils — nicht mehr jeder Bildschirm für sich.
*/
public struct RootView: View {
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var profileStore = UserProfileStore.shared

    @State private var showOnboarding = false

    public init() {}

    public var body: some View {
        Group {
            if auth.isSignedIn {
                MainTabView()
                    .transition(.opacity)
            } else {
                AuthGateView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isSignedIn)
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
        /*
          Der Fragebogen kommt einmal, direkt nach der ersten Anmeldung. Wer
          ihn wegtippt, wird nicht bei jedem Start erneut damit begrüßt —
          gefragt wird dann dort, wo die Antworten gebraucht werden
          (ProfileGateView im Coach und in der Challenge).
        */
        .onChange(of: auth.isSignedIn) { signedIn in
            if signedIn { presentOnboardingIfNeeded() }
        }
        .onAppear {
            if auth.isSignedIn { presentOnboardingIfNeeded() }
        }
    }

    private func presentOnboardingIfNeeded() {
        guard !profileStore.profile.hasSeenOnboarding else { return }
        // Kurz warten, sonst kollidiert das Blatt mit dem Wechsel von der
        // Anmeldeschranke auf die Tableiste und wird gar nicht gezeigt.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard !profileStore.profile.hasSeenOnboarding else { return }
            showOnboarding = true
        }
    }
}

/*
  Die Anmeldeschranke.

  Bewusst keine reine Formularseite: Der erste Bildschirm sagt, wofür das
  Konto da ist. „Melde dich an“ ohne Grund ist die Stelle, an der Leute die
  App wieder löschen.
*/
public struct AuthGateView: View {
    @ObservedObject private var i18n = I18n.shared

    @State private var authMode: AuthView.Mode?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                /*
                  LogoIcon zeichnet in Theme.bg — es ist für eine mintfarbene
                  Kachel gemacht, nicht für den dunklen Hintergrund. Ohne die
                  Kachel darunter war es schwarz auf schwarz und schlicht
                  nicht da. Die Größe steht am Symbol selbst: Ein .frame von
                  außen vergrößert nur das leere Feld drumherum.
                */
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.accent)
                        .frame(width: 84, height: 84)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 14, y: 4)
                    LogoIcon(size: 60)
                }

                VStack(spacing: 8) {
                    Text(i18n.t("gate.title"))
                        .font(KraftFont.bebas(38))
                        .tracking(2)
                        .foregroundColor(Theme.text)

                    Text(i18n.t("app.subtitle"))
                        .font(KraftFont.inter(12))
                        .tracking(0.5)
                        .foregroundColor(Theme.accent)
                }

                Text(i18n.t("gate.subtitle"))
                    .font(KraftFont.inter(14.5))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                KraftPrimaryButton(i18n.t("gate.signUp"), systemImage: "person.badge.plus") {
                    authMode = .signUp
                }

                Button(action: { authMode = .signIn }) {
                    Text(i18n.t("gate.signIn"))
                        .font(KraftFont.bebas(18))
                        .tracking(1.6)
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 5) {
                    Text(i18n.t("gate.why"))
                        .font(KraftFont.inter(12.5, .semibold))
                        .foregroundColor(Theme.text)
                    Text(i18n.t("gate.whyText"))
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .kraftCard()
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $authMode) { mode in
            AuthView(initialMode: mode, showsClose: true)
        }
    }
}

/// Damit `fullScreenCover(item:)` den Modus tragen kann.
extension AuthView.Mode: Identifiable {
    public var id: String {
        switch self {
        case .signIn:         return "signIn"
        case .signUp:         return "signUp"
        case .forgotPassword: return "forgotPassword"
        }
    }
}
