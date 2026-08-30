import SwiftUI

/*
  Dedizierte Pro-Abonnement-Ansicht (Pro Subscription View).
  Zeigt die Pro-Vorteile, Tarifauswahl, StoreKit-In-App-Kauf und Wiederherstellung.
*/
public struct ProSubscriptionView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @ObservedObject private var auth = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: StoreKitManager.ProPlanChoice = .yearly
    @State private var activeLegalPage: LegalPage?
    @State private var showAuthSheet = false

    private let appleEulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    proCard
                    if !auth.isSignedIn && !storeKit.isProUnlocked {
                        authRequirementCard
                    }
                    planSelector
                    aiDisclaimerCard
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $activeLegalPage) { page in
            LegalView(page: page)
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
        }
        .task {
            await storeKit.fetchProducts()
        }
        .onChange(of: storeKit.isProUnlocked) { unlocked in
            if unlocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Kopfzeile

    private var header: some View {
        HStack {
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

            Spacer()

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
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: - Pro Vorteilskarte

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Titelzeile mit Logo
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.accent)
                    LogoIcon(size: 28)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(i18n.t("proScreen.headline"))
                            .font(KraftFont.bebas(22))
                            .tracking(1.2)
                            .foregroundColor(Theme.text)

                        Text(i18n.t("proScreen.badge"))
                            .font(KraftFont.bebas(11))
                            .tracking(1)
                            .foregroundColor(Theme.bg)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent))
                    }

                    Text(i18n.t("proScreen.pitch"))
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Vorteile-Checkliste
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(i18n.t("proScreen.benefit.ai"))
                benefitRow(i18n.t("proScreen.benefit.ads"))
                benefitRow(i18n.t("proScreen.benefit.save"))
                benefitRow(i18n.t("proScreen.benefit.plans"))
                benefitRow(i18n.t("proScreen.benefit.watch"))
            }
        }
        .padding(20)
        .background(Theme.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.6), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.top, 2)

            Text(text)
                .font(KraftFont.inter(13, .medium))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Anmelde-Pflicht vor Pro-Kauf

    private var authRequirementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)

                Text(i18n.lang == "en" ? "ACCOUNT REQUIRED FOR PRO" : "KONTO ERFORDERLICH FÜR PRO")
                    .font(KraftFont.bebas(16)).tracking(1)
                    .foregroundColor(Theme.text)

                Spacer()
            }

            Text(i18n.lang == "en"
                 ? "Please sign in or register a free account to securely link your Pro membership to your profile."
                 : "Bitte melde dich an oder registriere dich kostenlos, um deine Pro-Mitgliedschaft mit deinem Profil zu verknüpfen.")
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAuthSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.key.fill").font(.system(size: 13))
                    Text(i18n.lang == "en" ? "SIGN IN / REGISTER" : "JETZT ANMELDEN / REGISTRIEREN")
                        .font(KraftFont.bebas(14)).tracking(1)
                }
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Tarifauswahl

    private var planSelector: some View {
        let yearlyDisplayPrice = storeKit.product(for: .yearly)?.displayPrice ?? i18n.t("proScreen.yearlyPrice")
        let monthlyDisplayPrice = storeKit.product(for: .monthly)?.displayPrice ?? i18n.t("proScreen.monthlyPrice")

        return VStack(spacing: 10) {
            // Jahres-Abo (Highlight)
            planOptionCard(
                plan: .yearly,
                title: i18n.t("proScreen.yearlyPlan"),
                price: yearlyDisplayPrice,
                subtitle: i18n.t("proScreen.yearlySub"),
                badge: i18n.lang == "en" ? "SAVE 48%" : "SPARE 48%"
            )

            // Monats-Abo
            planOptionCard(
                plan: .monthly,
                title: i18n.t("proScreen.monthlyPlan"),
                price: monthlyDisplayPrice,
                subtitle: i18n.t("proScreen.monthlySub"),
                badge: nil
            )
        }
    }

    private func planOptionCard(
        plan: StoreKitManager.ProPlanChoice,
        title: String,
        price: String,
        subtitle: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = plan
            }
        }) {
            HStack(spacing: 14) {
                // Radio-Knopf
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(KraftFont.inter(14, .bold))
                            .foregroundColor(Theme.text)

                        if let badge {
                            Text(badge)
                                .font(KraftFont.mono(9.5, .bold))
                                .tracking(0.5)
                                .foregroundColor(Theme.bg)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.accent))
                        }
                    }

                    Text(subtitle)
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                }

                Spacer(minLength: 0)

                Text(price)
                    .font(KraftFont.inter(13.5, .bold))
                    .foregroundColor(isSelected ? Theme.accent : Theme.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Theme.accentDim : Theme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Aktionen

    private var actionSection: some View {
        VStack(spacing: 14) {
            if storeKit.isProUnlocked {
                successBanner
            } else {
                subscribeButton
            }

            // Rechtliche Links & Wiederherstellen gemäß Apple Richtlinie 3.1.2
            legalLinksSection

            // Gesetzliche Abo-Hinweise (Automatische Verlängerung, Kündigung, Abrechnung)
            Text(i18n.t("proScreen.subscriptionTerms"))
                .font(KraftFont.inter(10))
                .foregroundColor(Theme.muted.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 2)
        }
    }

    private var subscribeButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if !auth.isSignedIn {
                showAuthSheet = true
            } else {
                Task {
                    await storeKit.purchase(plan: selectedPlan)
                }
            }
        }) {
            HStack(spacing: 8) {
                if storeKit.isPurchasing {
                    ProgressView().tint(Theme.bg)
                } else {
                    Image(systemName: auth.isSignedIn ? "sparkles" : "person.badge.key.fill")
                        .font(.system(size: 14, weight: .bold))
                }

                Text(auth.isSignedIn
                     ? i18n.t("proScreen.subscribeNow")
                     : (i18n.lang == "en" ? "SIGN IN & UNLOCK PRO" : "ANMELDEN & PRO FREISCHALTEN"))
                    .font(KraftFont.bebas(17)).tracking(1.5)
                    .textCase(.uppercase)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
            .shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(storeKit.isPurchasing)
    }

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.accent)

            Text(i18n.t("proScreen.upgradeSuccess"))
                .font(KraftFont.inter(13.5, .bold))
                .foregroundColor(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accentDim))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent, lineWidth: 1))
    }

    private var legalLinksSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                openURL(appleEulaURL)
            }) {
                Text(i18n.t("proScreen.terms"))
                    .font(KraftFont.inter(11, .medium))
                    .foregroundColor(Theme.muted)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("·")
                .foregroundColor(Theme.border)

            Button(action: {
                activeLegalPage = .privacy
            }) {
                Text(i18n.t("proScreen.privacy"))
                    .font(KraftFont.inter(11, .medium))
                    .foregroundColor(Theme.muted)
                    .underline()
            }
            .buttonStyle(.plain)

            Text("·")
                .foregroundColor(Theme.border)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task {
                    await storeKit.restorePurchases()
                }
            }) {
                Text(i18n.t("proScreen.restorePurchases"))
                    .font(KraftFont.inter(11, .medium))
                    .foregroundColor(Theme.muted)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - KI- & Service-Hinweis

    private var aiDisclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.lang == "en" ? "AI Coach & Service Notice" : "Hinweis zum KI-Coach & Modell")
                    .font(KraftFont.inter(11.5, .bold))
                    .foregroundColor(Theme.text)

                Text(i18n.lang == "en"
                     ? "Workouts and meal guides are generated by artificial intelligence for general fitness guidance and do not replace medical consultation. If the AI service is temporarily offline, intelligent offline templates are provided automatically. Subscriptions and refund requests are processed exclusively through Apple App Store policies."
                     : "Trainings- und Ernährungspläne werden durch künstliche Intelligenz (KI) zur allgemeinen Orientierung generiert und ersetzen keine ärztliche oder orthopädische Beratung. Bei vorübergehender Unerreichbarkeit des KI-Dienstes greift die integrierte Offline-Vorlagenbibliothek. Abonnements und Rückerstattungsanfragen werden über die offiziellen Richtlinien des Apple App Store abgewickelt.")
                    .font(KraftFont.inter(10.5))
                    .foregroundColor(Theme.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}
