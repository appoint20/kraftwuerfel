import SwiftUI

/*
  Einstellungen — erreichbar über das Zahnrad in der Kopfzeile.

  Hier landet, was vorher entweder im Weg stand oder gar nicht da war:

  - Der DE/EN-Schalter saß neben dem Markennamen und kostete dort Platz, den
    die Navigationsleiste braucht.
  - Anmelden und Registrieren gab es in der nativen App überhaupt nicht.
  - Impressum und Datenschutz fehlten. Beides muss aus der App heraus
    erreichbar sein, bevor sie in den Store geht.
*/
public struct SettingsView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var backend = BackendStatus.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showAuth = false
    @State private var legalPage: LegalPage?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    accountSection
                    backendSection
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
        .sheet(isPresented: $showAuth) { AuthView() }
        .sheet(item: $legalPage) { page in LegalView(page: page) }
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

    // MARK: - Konto

    private var accountSection: some View {
        SettingsSection(title: i18n.t("settings.account")) {
            if let account = auth.account {
                SettingsRow(
                    icon: "person.crop.circle.fill",
                    title: account.email,
                    subtitle: i18n.t("auth.signedIn")
                )
                SettingsButtonRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: i18n.t("auth.signOut"),
                    destructive: true
                ) { auth.signOut() }
            } else {
                SettingsButtonRow(
                    icon: "person.crop.circle.badge.plus",
                    title: i18n.t("auth.signInOrUp"),
                    subtitle: i18n.t("auth.whyAccount")
                ) { showAuth = true }
            }

            /*
              Ohne die beiden Supabase-Werte in der Info.plist kann sich niemand
              anmelden. Das gehört sichtbar gesagt, nicht in einen
              Netzwerkfehler versteckt.
            */
            if !auth.isConfigured {
                SettingsNote(text: i18n.t("auth.notConfigured"), warning: true)
            }
        }
    }

    // MARK: - Verbindung

    /*
      Der Zustand der Verbindung war nirgends abzulesen. Ob der KI-Coach den
      Server erreicht oder still lokal rechnet, entscheidet aber, was der Nutzer
      bekommt — das gehört sichtbar hin.
    */
    private var backendSection: some View {
        SettingsSection(title: i18n.t("settings.backend")) {
            SettingsRow(
                icon: reachabilityIcon,
                title: reachabilityTitle,
                subtitle: i18n.t("settings.backendHost")
            )
            SettingsRow(
                icon: "list.bullet",
                title: catalogTitle,
                subtitle: i18n.t("settings.catalogHint")
            )
            SettingsRow(
                icon: backend.usesServerForPlans ? "sparkles" : "iphone",
                title: i18n.t(backend.usesServerForPlans ? "settings.aiServer" : "settings.aiLocal"),
                subtitle: backend.usesServerForPlans ? nil : i18n.t("settings.aiLocalHint")
            )
            SettingsButtonRow(icon: "arrow.clockwise", title: i18n.t("settings.checkConnection")) {
                Task {
                    await backend.check()
                    await ExerciseDatabase.refreshFromAPI()
                }
            }
        }
    }

    private var reachabilityIcon: String {
        switch backend.reachability {
        case .online:   return "checkmark.circle.fill"
        case .offline:  return "exclamationmark.triangle.fill"
        case .checking: return "arrow.triangle.2.circlepath"
        case .unknown:  return "questionmark.circle"
        }
    }

    private var reachabilityTitle: String {
        switch backend.reachability {
        case .online(let count):   return i18n.t("settings.online", ["n": "\(count)"])
        case .offline(let reason): return i18n.t("settings.offline", ["reason": reason])
        case .checking:            return i18n.t("settings.checking")
        case .unknown:             return i18n.t("settings.unknown")
        }
    }

    private var catalogTitle: String {
        switch backend.catalogSource {
        case .server(let count): return i18n.t("settings.catalogServer", ["n": "\(count)"])
        case .bundled:           return i18n.t("settings.catalogBundled",
                                               ["n": "\(ExerciseDatabase.bundled.count)"])
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
            SettingsRow(
                icon: storeKit.isProUnlocked ? "checkmark.seal.fill" : "sparkles",
                title: storeKit.isProUnlocked
                    ? i18n.t("settings.proActive") : i18n.t("settings.proInactive"),
                subtitle: storeKit.isProUnlocked ? nil : i18n.t("settings.proHint")
            )
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
