import SwiftUI

/*
  Anmelden, Registrieren und Passwort vergessen.
  Entspricht der neuen kartengestützten Ansicht ohne Pro-Werbetexte.
*/
public struct AuthView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    public enum Mode { case signIn, signUp, forgotPassword }

    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @FocusState private var focus: Field?

    private enum Field { case name, email, password, passwordConfirm }

    /*
      Die Anmeldeschranke beim Start zeigt dieselbe Ansicht, aber ohne Ausgang:
      Ohne Konto gibt es nichts dahinter, und ein Abbrechen-Knopf, der auf
      einen leeren Bildschirm führt, ist kein Ausgang, sondern eine Sackgasse.
    */
    private let showsClose: Bool

    public init(initialMode: Mode = .signUp, showsClose: Bool = true) {
        self._mode = State(initialValue: initialMode)
        self.showsClose = showsClose
    }

    private var canSubmit: Bool {
        if auth.isBusy || !auth.isConfigured { return false }
        if mode == .forgotPassword {
            return email.contains("@")
        }
        if mode == .signUp {
            return email.contains("@") && password.count >= 6 && !passwordConfirm.isEmpty
        }
        return email.contains("@") && password.count >= 6
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    authCard

                    if let error = auth.lastError {
                        errorCard(error)
                    }

                    if auth.awaitingEmailConfirmation {
                        confirmationCard(i18n.t("auth.confirmEmail"))
                    }

                    if auth.resetEmailSent {
                        confirmationCard(i18n.t("auth.resetPasswordSent"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if !auth.userName.isEmpty {
                self.name = auth.userName
            }
        }
        .onChange(of: auth.isSignedIn) { signedIn in
            if signedIn && showsClose { dismiss() }
        }
    }

    // MARK: - Kopfzeile

    private var header: some View {
        HStack {
            if showsClose {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text(i18n.t("proScreen.back"))
                            .font(KraftFont.inter(13, .semibold))
                    }
                    .foregroundColor(Theme.muted)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if showsClose {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i18n.t("saved.close"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: - Authentifizierungs-Karte

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Modus-Umschalter oben in der Karte (nur zwischen Registrieren & Anmelden)
            if mode != .forgotPassword {
                modeSegmentControl
            }

            Text(cardTitle)
                .font(KraftFont.mono(11, .bold))
                .tracking(1.5)
                .foregroundColor(Theme.muted)
                .textCase(.uppercase)
                .padding(.top, 4)

            if mode == .forgotPassword {
                Text(i18n.t("auth.forgotPasswordHint"))
                    .font(KraftFont.inter(13, .regular))
                    .foregroundColor(Theme.muted)
                    .lineSpacing(2)
            }

            VStack(spacing: 14) {
                if mode == .signUp {
                    cardInputField(
                        label: i18n.t("auth.nameLabel"),
                        promptText: i18n.t("auth.namePlaceholder"),
                        text: $name,
                        focusedField: .name,
                        submitLabel: .next,
                        onSubmit: { focus = .email }
                    )
                }

                cardInputField(
                    label: i18n.t("auth.emailLabel"),
                    promptText: "name@example.com",
                    text: $email,
                    focusedField: .email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress,
                    submitLabel: mode == .forgotPassword ? .go : .next,
                    onSubmit: {
                        if mode == .forgotPassword {
                            submit()
                        } else {
                            focus = .password
                        }
                    }
                )

                if mode != .forgotPassword {
                    VStack(alignment: .trailing, spacing: 6) {
                        cardSecureField(
                            label: i18n.t("auth.passwordLabel"),
                            promptText: "••••••••",
                            text: $password,
                            focusedField: .password,
                            textContentType: mode == .signUp ? .newPassword : .password,
                            submitLabel: mode == .signUp ? .next : .go,
                            onSubmit: {
                                if mode == .signUp {
                                    focus = .passwordConfirm
                                } else {
                                    submit()
                                }
                            }
                        )

                        if mode == .signIn {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                auth.clearStatus()
                                passwordConfirm = ""
                                withAnimation(.easeOut(duration: 0.15)) {
                                    mode = .forgotPassword
                                }
                            }) {
                                Text(i18n.t("auth.forgotPassword"))
                                    .font(KraftFont.inter(11.5, .medium))
                                    .foregroundColor(Theme.accent)
                                    .padding(.top, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if mode == .signUp {
                        cardSecureField(
                            label: i18n.t("auth.passwordConfirmLabel"),
                            promptText: "••••••••",
                            text: $passwordConfirm,
                            focusedField: .passwordConfirm,
                            textContentType: .newPassword,
                            submitLabel: .go,
                            onSubmit: { submit() }
                        )
                    }
                }
            }

            submitButton

            bottomNavigationButton
        }
        .padding(20)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var cardTitle: String {
        switch mode {
        case .signUp:         return i18n.t("auth.createAccountHeader")
        case .signIn:         return i18n.t("auth.signInHeader")
        case .forgotPassword: return i18n.t("auth.forgotPasswordHeader")
        }
    }

    private var modeSegmentControl: some View {
        HStack(spacing: 0) {
            modeButton(.signUp, i18n.t("auth.signUp"))
            modeButton(.signIn, i18n.t("auth.signIn"))
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func modeButton(_ target: Mode, _ label: String) -> some View {
        let isActive = mode == target
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            auth.clearStatus()
            passwordConfirm = ""
            withAnimation(.easeOut(duration: 0.15)) { mode = target }
        }) {
            Text(label)
                .font(KraftFont.inter(12.5, isActive ? .bold : .semibold))
                .foregroundColor(isActive ? Theme.bg : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(isActive ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Eingabefelder im Kartendesign

    private func cardInputField(
        label: String,
        promptText: String,
        text: Binding<String>,
        focusedField: Field,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .next,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(KraftFont.mono(10.5, .bold))
                .tracking(1)
                .foregroundColor(Theme.muted)
                .textCase(.uppercase)

            TextField("", text: text, prompt: Text(promptText).foregroundColor(Theme.muted.opacity(0.6)))
                .font(KraftFont.inter(14, .medium))
                .foregroundColor(Theme.text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
                .focused($focus, equals: focusedField)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focus == focusedField ? Theme.accent.opacity(0.8) : Theme.border, lineWidth: 1)
                )
        }
    }

    private func cardSecureField(
        label: String,
        promptText: String,
        text: Binding<String>,
        focusedField: Field,
        textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .go,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(KraftFont.mono(10.5, .bold))
                .tracking(1)
                .foregroundColor(Theme.muted)
                .textCase(.uppercase)

            SecureField("", text: text, prompt: Text(promptText).foregroundColor(Theme.muted.opacity(0.6)))
                .font(KraftFont.inter(14, .medium))
                .foregroundColor(Theme.text)
                .textContentType(textContentType)
                .focused($focus, equals: focusedField)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focus == focusedField ? Theme.accent.opacity(0.8) : Theme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Aktionsschaltflächen

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if auth.isBusy {
                    ProgressView().tint(Theme.bg)
                }
                Text(submitButtonTitle)
                    .font(KraftFont.bebas(16)).tracking(1.5)
                    .textCase(.uppercase)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(canSubmit ? Theme.accent : Theme.accent.opacity(0.4)))
            .shadow(color: canSubmit ? Theme.accent.opacity(0.25) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.top, 6)
    }

    private var submitButtonTitle: String {
        switch mode {
        case .signUp:         return i18n.t("auth.signUp")
        case .signIn:         return i18n.t("auth.signIn")
        case .forgotPassword: return i18n.t("auth.resetPasswordSubmit")
        }
    }

    private var bottomNavigationButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            auth.clearStatus()
            passwordConfirm = ""
            withAnimation(.easeOut(duration: 0.15)) {
                switch mode {
                case .signUp:         mode = .signIn
                case .signIn:         mode = .signUp
                case .forgotPassword: mode = .signIn
                }
            }
        }) {
            Text(bottomNavigationTitle)
                .font(KraftFont.inter(13, .semibold))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .buttonStyle(.plain)
    }

    private var bottomNavigationTitle: String {
        switch mode {
        case .signUp:         return i18n.t("auth.toSignInPrompt")
        case .signIn:         return i18n.t("auth.toSignUpPrompt")
        case .forgotPassword: return i18n.t("auth.backToSignIn")
        }
    }

    // MARK: - Statuskarten

    private func errorCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.red)

            Text(text)
                .font(KraftFont.inter(12.5, .medium))
                .foregroundColor(Color(hex: "FF6B6B"))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "2B1416")))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.red.opacity(0.6), lineWidth: 1))
    }

    private func confirmationCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.accent)

            Text(message)
                .font(KraftFont.inter(12.5, .medium))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentDim))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Absenden

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if mode == .signUp && password != passwordConfirm {
            auth.lastError = i18n.t("auth.passwordsDoNotMatch")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        Task {
            switch mode {
            case .signIn:
                let ok = await auth.signIn(email: email, password: password)
                if ok {
                    password = ""
                    passwordConfirm = ""
                }
            case .signUp:
                let ok = await auth.signUp(name: name.isEmpty ? nil : name, email: email, password: password)
                if ok {
                    password = ""
                    passwordConfirm = ""
                }
            case .forgotPassword:
                await auth.resetPassword(email: email)
            }
        }
    }
}
