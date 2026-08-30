import SwiftUI

/*
  Einstellungen — erreichbar über das Zahnrad in der Kopfzeile.
*/
public struct SettingsView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var challengeStore = ChallengeStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAuth = false
    @State private var showProfile = false
    @State private var showPro = false
    @State private var showGuide = false
    @State private var showChallengeSettings = false
    @State private var legalPage: LegalPage?
    @State private var showDeleteConfirm = false
    @State private var deleteResult: SaveAlert?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    profileSection
                    guideSection
                    challengeSection
                    accountSection
                    languageSection
                    proSection
                    legalSection
                    versionLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showGuide) { AppGuideView() }
        .sheet(isPresented: $showChallengeSettings) { ChallengeSettingsView() }
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(isPresented: $showProfile) { ProfileSettingsView() }
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        .sheet(item: $legalPage) { page in LegalView(page: page) }
        .kraftDialog(isPresented: $showDeleteConfirm) {
            KraftDialog(
                title: i18n.t("auth.deleteConfirmTitle"),
                message: i18n.t("auth.deleteConfirmBody"),
                isError: true,
                icon: "trash.fill",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.t("auth.deleteConfirmAction"),
                onConfirm: {
                    showDeleteConfirm = false
                    deleteAccount()
                },
                onDismiss: { showDeleteConfirm = false }
            )
        }
        .kraftDialog(item: $deleteResult) { entry in
            KraftDialog(title: entry.title, message: entry.message, isError: entry.isError) {
                deleteResult = nil
                // Nach der Löschung gibt es in den Einstellungen nichts mehr
                // zu sehen, was zu diesem Konto gehört.
                if !entry.isError { dismiss() }
            }
        }
    }

    /*
      Erfolg meldet nur, was der Server bestätigt hat. Schlägt es fehl, bleibt
      der Nutzer angemeldet und bekommt die Kontaktadresse aus dem
      Datenschutztext — dann kann er die Löschung dort verlangen, statt im
      Glauben zu bleiben, sie sei erledigt.
    */
    private func deleteAccount() {
        Task {
            if await auth.deleteAccount() {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                deleteResult = .info(
                    title: i18n.t("auth.deleteDoneTitle"),
                    message: i18n.t("auth.deleteDoneBody")
                )
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                deleteResult = .error(
                    title: i18n.t("auth.deleteFailedTitle"),
                    message: i18n.t("auth.deleteFailedBody", ["reason": auth.lastError ?? ""])
                )
            }
        }
    }

    private var header: some View {
        HStack {
            Text(i18n.t("settings.title"))
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

    /*
      Der Fragebogen, aber jederzeit erreichbar.

      Gefragt wird nur einmal, nach der Registrierung — geändert werden darf
      trotzdem alles. Ohne diesen Weg wäre eine falsch eingetippte Größe für
      immer falsch, und der einzige Ausweg wäre gewesen, das Konto zu löschen.
    */
    private var profileSection: some View {
        SettingsSection(title: i18n.t("settings.profile")) {
            SettingsButtonRow(
                icon: "person.text.rectangle",
                title: i18n.t("profile.title"),
                subtitle: profileSummary
            ) {
                showProfile = true
            }
        }
    }

    private var profileSummary: String {
        let p = UserProfileStore.shared.profile
        guard p.isComplete else { return i18n.t("profile.incompleteTitle") }
        return "\(p.age) · \(Int(p.heightCm)) cm · \(Int(p.weightKg)) kg · \(p.goal.localized(i18n.lang))"
    }

    // MARK: - Handbuch & Anleitung

    private var guideSection: some View {
        SettingsSection(title: i18n.lang == "en" ? "Help & Documentation" : "Hilfe & Dokumentation") {
            SettingsButtonRow(
                icon: "book.fill",
                title: i18n.lang == "en" ? "360° App Guide & How-To" : "360° App-Handbuch & Anleitung",
                subtitle: i18n.lang == "en" ? "Interactive guide to generator, live tracking, diary, and AI coach" : "Ausführliche Erklärung zu Generator, Live-Tracking, Tagebuch und KI-Coach"
            ) {
                showGuide = true
            }
        }
    }

    // MARK: - Challenge Konfiguration

    private var challengeSection: some View {
        SettingsSection(title: i18n.lang == "en" ? "CHALLENGES & HOME WORKOUT" : "CHALLENGES & HOME-WORKOUT") {
            SettingsButtonRow(
                icon: "flame.fill",
                title: challengeStore.category.title(language: i18n.lang),
                subtitle: "\(challengeStore.durationDays)-Tage Challenge · Tag \(challengeStore.currentDayNumber) (\(challengeStore.completedDays.count) geschafft)"
            ) {
                showChallengeSettings = true
            }
        }
    }

    // MARK: - Konto

    private var accountSection: some View {
        SettingsSection(title: i18n.t("settings.account")) {
            if let account = auth.account {
                SettingsRow(
                    icon: "person.crop.circle.fill",
                    title: auth.displayName.isEmpty ? account.email : "\(auth.displayName) (\(account.email))",
                    subtitle: i18n.t("auth.signedIn")
                )
                SettingsButtonRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: i18n.t("auth.signOut"),
                    destructive: true
                ) { auth.signOut() }

                // Art. 17 DSGVO — der Weg zur Löschung muss in der App
                // selbst liegen, nicht nur als E-Mail-Adresse im
                // Datenschutztext.
                SettingsButtonRow(
                    icon: "trash",
                    title: i18n.t("auth.deleteAccount"),
                    subtitle: i18n.t("auth.deleteAccountHint"),
                    destructive: true
                ) { showDeleteConfirm = true }
            } else {
                SettingsButtonRow(
                    icon: "person.crop.circle.badge.plus",
                    title: i18n.t("auth.signInOrUp"),
                    subtitle: i18n.t("auth.whyAccount")
                ) { showAuth = true }
            }

            if !auth.isConfigured {
                SettingsNote(text: i18n.t("auth.notConfigured"), warning: true)
            }
        }
    }

    // MARK: - Sprache

    private var languageSection: some View {
        SettingsSection(title: i18n.t("settings.language")) {
            HStack(spacing: 8) {
                languageButton("de", "Deutsch")
                languageButton("en", "English")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func languageButton(_ code: String, _ label: String) -> some View {
        let isActive = i18n.lang == code
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            i18n.lang = code
        }) {
            HStack(spacing: 6) {
                Text(code.uppercased())
                    .font(KraftFont.mono(10.5, .bold))
                Text(label)
                    .font(KraftFont.inter(13, .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? Theme.accent : Theme.surface2)
            .foregroundColor(isActive ? Theme.bg : Theme.text)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro

    private var proSection: some View {
        SettingsSection(title: i18n.t("settings.pro")) {
            if storeKit.isProUnlocked {
                SettingsRow(
                    icon: "checkmark.seal.fill",
                    title: i18n.t("settings.proActive"),
                    subtitle: nil
                )
            } else {
                SettingsButtonRow(
                    icon: "sparkles",
                    title: i18n.t("nav.getPro"),
                    subtitle: i18n.t("settings.proHint")
                ) {
                    showPro = true
                }
            }

            SettingsButtonRow(
                icon: "arrow.clockwise",
                title: i18n.t("settings.restorePurchases")
            ) {
                Task { await storeKit.restorePurchases() }
            }
        }
    }

    // MARK: - Rechtliches

    private var legalSection: some View {
        SettingsSection(title: i18n.t("settings.legal")) {
            ForEach(LegalPage.allCases) { page in
                SettingsButtonRow(icon: page.icon, title: i18n.t(page.titleKey)) {
                    legalPage = page
                }
            }
        }
    }

    private var versionLine: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return Text("KRAFTWÜRFEL \(version) (\(build))")
            .font(KraftFont.mono(10.5, .medium))
            .foregroundColor(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
    }
}

// MARK: - Bausteine

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
            VStack(spacing: 0) { content }
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KraftFont.inter(14, .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(destructive ? Theme.red : Theme.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(KraftFont.inter(14, .semibold))
                        .foregroundColor(destructive ? Theme.red : Theme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(KraftFont.inter(11.5))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
    }
}

struct SettingsNote: View {
    let text: String
    var warning: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: warning ? "exclamationmark.triangle.fill" : "info.circle")
                .font(.system(size: 12))
                .foregroundColor(warning ? Theme.orange : Theme.muted)
            Text(text)
                .font(KraftFont.inter(11.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface2)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}
