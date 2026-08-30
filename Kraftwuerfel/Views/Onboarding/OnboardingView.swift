import SwiftUI

/*
  Der Fragebogen nach der Registrierung.

  Vorher standen dieselben Fragen in zwei Formularen, und beide wurden bei
  JEDEM Aufruf gestellt — wer sich zum dritten Mal einen Plan bauen ließ,
  tippte zum dritten Mal Größe und Gewicht ein. Hier wird einmal gefragt;
  danach erzeugen Coach und Challenge mit einem Tipp.

  Abbrechen ist erlaubt. Ein Nutzer, der nach der Registrierung erst einmal
  sehen will, was die App kann, soll nicht gegen eine Wand aus Formularen
  laufen — gefragt wird dann erst dort, wo die Antworten gebraucht werden
  (ProfileGateView im Coach und in der Challenge).

  Apple Health steht bewusst VOR den Körperdaten: Was Health schon weiß, muss
  der Nutzer im nächsten Schritt nicht mehr eintippen.
*/
public struct OnboardingView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = UserProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 0

    /// Die Schritte mit Fragen — Begrüßung und Abschluss zählen nicht mit,
    /// sonst stünde über der ersten Frage „Schritt 2 von 8“.
    private static let firstQuestion = 1
    private static let lastQuestion = 6
    private var questionCount: Int { Self.lastQuestion - Self.firstQuestion + 1 }

    public init() {}

    public var body: some View {
        Group {
            /*
              Die Begrüßung ist keine Formularseite und sieht deshalb auch
              nicht so aus: kein Schrittzähler, kein Fortschrittsbalken, keine
              Fußzeile — nur die Würfel, die Frage und die zwei Antworten,
              mittig übereinander.
            */
            if step == 0 {
                welcomeScreen
            } else {
                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            content
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    footer
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .dismissKeyboardOnTap()
    }

    // MARK: - Begrüßung

    /*
      Zwei echte Wege statt eines kleinen „Später" oben rechts.

      Vorher war die Wahl zwischen Fragebogen und Überspringen nicht
      gleichwertig dargestellt: unten ein großer Knopf „Los geht's", oben
      rechts ein grauer Text. Wer nicht antworten wollte, musste erst suchen
      — und wer nur schnell weiterwollte, tippte den großen Knopf und stand
      mitten im Formular.

      Jetzt stehen beide Antworten untereinander: die empfohlene zuerst und
      betont, die andere sichtbar daneben.
    */
    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                DiceLoaderView(size: 150)

                Text(i18n.t("onboarding.welcomeTitle"))
                    .font(KraftFont.bebas(32))
                    .tracking(1.4)
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("onboarding.welcomeText"))
                    .font(KraftFont.inter(14.5))
                    .foregroundColor(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)

                VStack(spacing: 10) {
                    KraftPrimaryButton(i18n.t("onboarding.setupProfile"), systemImage: "person.text.rectangle") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) { step = Self.firstQuestion }
                    }

                    Button(action: skip) {
                        Text(i18n.t("onboarding.jumpIn"))
                            .font(KraftFont.bebas(17))
                            .tracking(1.4)
                            .foregroundColor(Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Text(i18n.t("onboarding.laterHint"))
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                if step > 0 && step <= Self.lastQuestion {
                    Text(i18n.t("onboarding.step", [
                        "current": "\(step)",
                        "total": "\(questionCount)"
                    ]))
                    .font(KraftFont.mono(11, .bold))
                    .tracking(0.8)
                    .foregroundColor(Theme.muted)
                }
                Spacer()
                if !store.profile.isComplete {
                    Button(action: skip) {
                        Text(i18n.t("onboarding.later"))
                            .font(KraftFont.inter(12.5, .semibold))
                            .foregroundColor(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }

            if step > 0 && step <= Self.lastQuestion {
                HStack(spacing: 5) {
                    ForEach(Self.firstQuestion...Self.lastQuestion, id: \.self) { s in
                        Capsule()
                            .fill(s <= step ? Theme.accent : Theme.surface2)
                            .frame(height: 4)
                    }
                }
            }

            if let title = stepTitle {
                Text(title)
                    .font(KraftFont.bebas(28))
                    .tracking(1.2)
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var stepTitle: String? {
        switch step {
        case 1: return i18n.t("onboarding.titleHealth")
        case 2: return i18n.t("onboarding.titleBody")
        case 3: return i18n.t("onboarding.titleGoal")
        case 4: return i18n.t("onboarding.titleTraining")
        case 5: return i18n.t("onboarding.titleChallenge")
        case 6: return i18n.t("onboarding.titleNutrition")
        default: return nil
        }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        switch step {
        case 1: HealthConnectCard()
        case 2: ProfileBodySection()
        case 3: ProfileGoalSection()
        case 4: ProfileTrainingSection()
        case 5: ProfileChallengeSection()
        case 6: ProfileNutritionSection()
        default: done
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(Theme.accent)
                .padding(.top, 20)

            Text(i18n.t("onboarding.doneTitle"))
                .font(KraftFont.bebas(34))
                .tracking(1.5)
                .foregroundColor(Theme.text)

            Text(i18n.t("onboarding.doneText"))
                .font(KraftFont.inter(15))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            summaryCard
        }
    }

    private var summaryCard: some View {
        let p = store.profile
        return VStack(spacing: 10) {
            ReviewRow(i18n.t("ai.goal"), p.goal.localized(i18n.lang), highlight: true)
            ReviewRow(i18n.t("ai.experience"), p.experience.localizedShort(i18n.lang))
            ReviewRow(
                i18n.t("ai.biometricsTitle"),
                "\(p.age) · \(Int(p.heightCm)) cm · \(Int(p.weightKg)) kg"
            )
            ReviewRow(i18n.t("ai.days"), Weekdays.sorted(p.selectedDays).joined(separator: " "))
            ReviewRow(i18n.t("ai.dietTitle"), p.diet.localized(i18n.lang), isLast: true)
        }
        .padding(16)
        .kraftCard()
        .padding(.top, 6)
    }

    // MARK: - Fuß

    private var footer: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button(action: { move(-1) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                        Text(i18n.t("onboarding.back")).font(KraftFont.inter(13.5, .semibold))
                    }
                    .foregroundColor(Theme.muted)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
            }

            KraftPrimaryButton(primaryTitle, systemImage: primaryIcon) {
                if step > Self.lastQuestion {
                    finish()
                } else {
                    move(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Theme.bg)
    }

    private var primaryTitle: String {
        // Schritt 0 hat eine eigene Ansicht mit eigenen Knöpfen.
        step > Self.lastQuestion ? i18n.t("onboarding.finish") : i18n.t("onboarding.next")
    }

    private var primaryIcon: String {
        step > Self.lastQuestion ? "checkmark" : "arrow.right"
    }

    // MARK: - Ablauf

    private func move(_ delta: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            step = max(0, min(Self.lastQuestion + 1, step + delta))
        }
    }

    private func skip() {
        store.markOnboardingSeen()
        dismiss()
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        store.markComplete()
        /*
          Erst hier nach Mitteilungen fragen. Jetzt stehen die Trainingstage
          fest, also gibt es etwas, woran erinnert werden kann — und der
          Nutzer weiß, wofür er gefragt wird.
        */
        NotificationManager.shared.requestAuthorization()
        dismiss()
    }
}

// MARK: - Apple Health

/*
  Der Health-Schritt.

  Zwei Dinge stehen hier ausdrücklich dabei, weil sie in der App-Prüfung und
  gegenüber dem Nutzer zählen: was gelesen wird, und was geschrieben wird.
  Der Hinweis, dass Schätzwerte NIE nach Health gehen, ist keine Beruhigung
  fürs Auge — genau das war der Grund, warum eine frühere Fassung dieser App
  abgelehnt wurde.
*/
public struct HealthConnectCard: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var health = HealthKitManager.shared
    @ObservedObject private var store = UserProfileStore.shared

    @State private var isRequesting = false
    @State private var importedCount: Int?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.pink)
                Text(i18n.t("health.title"))
                    .font(KraftFont.inter(17, .bold))
                    .foregroundColor(Theme.text)
            }

            Text(i18n.t("health.text"))
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    icon: "arrow.down.circle.fill",
                    title: i18n.t("health.readTitle"),
                    items: i18n.t("health.readItems")
                )
                permissionRow(
                    icon: "arrow.up.circle.fill",
                    title: i18n.t("health.writeTitle"),
                    items: i18n.t("health.writeItems")
                )
            }
            .padding(14)
            .kraftCard()

            Text(i18n.t("health.estimateNote"))
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !health.isAvailable {
                statusLine(icon: "xmark.circle", text: i18n.t("health.unavailable"), color: Theme.muted)
            } else if let importedCount {
                statusLine(
                    icon: "checkmark.circle.fill",
                    text: importedCount > 0
                        ? i18n.t("health.prefilled", ["count": "\(importedCount)"])
                        : i18n.t("health.nothingRead"),
                    color: Theme.green
                )
            } else if health.availability == .requested {
                statusLine(icon: "checkmark.circle.fill", text: i18n.t("health.connected"), color: Theme.green)
            } else {
                KraftPrimaryButton(
                    i18n.t("health.connect"),
                    systemImage: "heart.fill",
                    isEnabled: !isRequesting
                ) {
                    connect()
                }
            }
        }
    }

    private func permissionRow(icon: String, title: String, items: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(KraftFont.mono(10.5, .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.muted)
                Text(items)
                    .font(KraftFont.inter(13))
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusLine(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(text).font(KraftFont.inter(13, .semibold))
        }
        .foregroundColor(color)
    }

    /*
      Erlaubnis holen und, wenn sie da ist, gleich übernehmen was Health weiß.
      Ohne diesen zweiten Teil wäre die Verbindung eine Erlaubnis ohne Nutzen:
      Der Nutzer hätte zugestimmt und müsste sein Gewicht trotzdem eintippen.
    */
    private func connect() {
        isRequesting = true
        Task {
            await health.requestAuthorization()
            let metrics = await health.readBodyMetrics()

            await MainActor.run {
                var taken = 0
                store.update { profile in
                    if let kg = metrics.weightKg, kg > 30, kg < 300 {
                        profile.weightKg = kg
                        if profile.startWeightKg == nil { profile.startWeightKg = kg }
                        taken += 1
                    }
                    if let cm = metrics.heightCm, cm > 100, cm < 250 {
                        profile.heightCm = cm
                        taken += 1
                    }
                    if let age = metrics.age, age >= 14, age <= 99 {
                        profile.age = age
                        taken += 1
                    }
                    if let sex = metrics.sex {
                        profile.sex = sex
                        taken += 1
                    }
                }
                importedCount = taken
                isRequesting = false
            }
        }
    }
}
