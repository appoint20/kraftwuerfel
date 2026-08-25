import SwiftUI

/*
  Anmelden und Registrieren.

  Beides gab es in der nativen App bisher nicht — und das war mehr als eine
  fehlende Ansicht: Ohne Anmeldung blieb `KraftAPI.accessToken` leer,
  `generatePlan` warf immer `.unauthorized`, und der als Pro verkaufte
  KI-Coach lief in Wahrheit immer lokal.

  Ein Formular, zwei Modi. Der Knopf bleibt gesperrt, solange die Eingaben
  offensichtlich nicht reichen — eine Fehlermeldung nach dem Absenden für etwas,
  das man vorher sieht, ist nur Warterei.
*/
public struct AuthView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    private enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    public init() {}

    private var canSubmit: Bool {
        !auth.isBusy
            && auth.isConfigured
            && email.contains("@")
            && password.count >= 6
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    modeSwitch
                    if !auth.isConfigured { notConfiguredNote }
                    fields
                    if let error = auth.lastError { errorNote(error) }
                    if auth.awaitingEmailConfirmation { confirmationNote }
                    submitButton
                    hint
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // Nach erfolgreicher Anmeldung ist hier nichts mehr zu tun.
        .onChange(of: auth.isSignedIn) { signedIn in
            if signedIn { dismiss() }
        }
    }

    private var header: some View {
        HStack {
            Text(i18n.t("auth.title"))
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

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeButton(.signIn, i18n.t("auth.signIn"))
            modeButton(.signUp, i18n.t("auth.signUp"))
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func modeButton(_ target: Mode, _ label: String) -> some View {
        let isActive = mode == target
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            auth.lastError = nil
            withAnimation(.easeOut(duration: 0.15)) { mode = target }
        }) {
            Text(label)
                .font(KraftFont.inter(13, isActive ? .bold : .semibold))
                .foregroundColor(isActive ? Theme.bg : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(isActive ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var fields: some View {
        VStack(spacing: 10) {
            labelledField(i18n.t("auth.email")) {
                TextField("", text: $email, prompt: prompt("name@example.com"))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }

            labelledField(i18n.t("auth.password")) {
                SecureField("", text: $password, prompt: prompt("••••••••"))
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
            }
        }
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundColor(Theme.muted)
    }

    private func labelledField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).kwStyle(.controlLabel)
            content()
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if auth.isBusy {
                    ProgressView().tint(Theme.bg)
                } else {
                    Image(systemName: mode == .signIn
                          ? "arrow.right.to.line" : "person.crop.circle.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(mode == .signIn ? i18n.t("auth.signIn") : i18n.t("auth.signUp"))
                    .font(KraftFont.bebas(16)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(canSubmit ? Theme.accent : Theme.surface2))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.top, 4)
    }

    private var hint: some View {
        Text(i18n.t(mode == .signIn ? "auth.hintSignIn" : "auth.hintSignUp"))
            .font(KraftFont.inter(11.5))
            .foregroundColor(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var notConfiguredNote: some View {
        note(i18n.t("auth.notConfigured"), color: Theme.orange, icon: "exclamationmark.triangle.fill")
    }

    private func errorNote(_ text: String) -> some View {
        note(text, color: Theme.red, icon: "xmark.octagon.fill")
    }

    private var confirmationNote: some View {
        note(i18n.t("auth.confirmEmail"), color: Theme.accent, icon: "envelope.fill")
    }

    private func note(_ text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            Text(text)
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.45), lineWidth: 1))
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let ok = mode == .signIn
                ? await auth.signIn(email: email, password: password)
                : await auth.signUp(email: email, password: password)
            if ok {
                // Das Passwort hat nach dem Absenden nichts mehr im Speicher
                // der Ansicht verloren.
                password = ""
            }
        }
    }
}
