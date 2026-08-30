import SwiftUI

/*
  ChallengeSettingsView — Konfiguration von 10, 20, 30+ Tage Challenges
  mit täglicher Erinnerung und Fortschritts-Visualisierung.
*/
public struct ChallengeSettingsView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var challenge = ChallengeStore.shared
    @ObservedObject private var notifications = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var reminderDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showResetConfirm = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    currentStatusCard
                    durationSelector
                    categorySelector
                    reminderSection
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            var comps = DateComponents()
            comps.hour = challenge.reminderHour
            comps.minute = challenge.reminderMinute
            reminderDate = Calendar.current.date(from: comps) ?? Date()
        }
        .kraftDialog(isPresented: $showResetConfirm) {
            KraftDialog(
                title: i18n.lang == "en" ? "Reset Challenge?" : "Challenge zurücksetzen?",
                message: i18n.lang == "en"
                    ? "Do you really want to reset your challenge progress? Your current streak will start from Day 1."
                    : "Möchtest du deinen Challenge-Fortschritt wirklich zurücksetzen? Dein Fortschritt beginnt wieder bei Tag 1.",
                isError: true,
                icon: "arrow.counterclockwise",
                dismissLabel: i18n.t("auth.deleteCancel"),
                confirmLabel: i18n.lang == "en" ? "Reset" : "Zurücksetzen",
                onConfirm: {
                    showResetConfirm = false
                    challenge.resetChallenge()
                },
                onDismiss: { showResetConfirm = false }
            )
        }
    }

    private var header: some View {
        HStack {
            Text(i18n.lang == "en" ? "CHALLENGE SETTINGS" : "CHALLENGE KONFIGURATION")
                .font(KraftFont.bebas(22)).tracking(1.2)
                .foregroundColor(Theme.text)

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
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: - Aktueller Status

    private var currentStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.accentDim)
                    Image(systemName: challenge.category.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.category.title(language: i18n.lang))
                        .font(KraftFont.bebas(17)).tracking(1)
                        .foregroundColor(Theme.text)
                    Text("\(challenge.durationDays)-Tage Challenge · Tag \(challenge.currentDayNumber)")
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.orange)
                        Text("\(challenge.streak)")
                            .font(KraftFont.mono(15, .bold))
                            .foregroundColor(Theme.orange)
                    }
                    Text("Streak")
                        .font(KraftFont.mono(9.5))
                        .foregroundColor(Theme.muted)
                }
            }

            // Fortschrittsbalken
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(challenge.completedDays.count) von \(challenge.durationDays) Tagen geschafft")
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                    Spacer()
                    Text("\(Int(challenge.progressPercent * 100))%")
                        .font(KraftFont.mono(11.5, .bold))
                        .foregroundColor(Theme.accent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surface2).frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.accent, Theme.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * CGFloat(challenge.progressPercent)), height: 7)
                    }
                }
                .frame(height: 7)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Dauer

    private var durationSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(i18n.lang == "en" ? "CHALLENGE DURATION (DAYS)" : "CHALLENGE DAUER (TAGE)")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ChallengeStore.availableDurations, id: \.self) { d in
                    let isSelected = challenge.durationDays == d
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { challenge.durationDays = d }
                    }) {
                        Text("\(d) TAGE")
                            .font(KraftFont.bebas(14)).tracking(1)
                            .foregroundColor(isSelected ? Theme.bg : Theme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Theme.accent : Theme.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Kategorie

    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(i18n.lang == "en" ? "CHALLENGE FOCUS" : "CHALLENGE FOKUS")

            VStack(spacing: 8) {
                ForEach(ChallengeCategory.allCases) { cat in
                    let isSelected = challenge.category == cat
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { challenge.category = cat }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(isSelected ? Theme.accent : Theme.muted)
                                .frame(width: 24)

                            Text(cat.title(language: i18n.lang))
                                .font(KraftFont.inter(13.5, isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? Theme.text : Theme.muted)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Theme.accentDim : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Erinnerungen

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(i18n.lang == "en" ? "DAILY REMINDER" : "TÄGLICHE ERINNERUNG")

            VStack(spacing: 12) {
                Toggle(isOn: $challenge.reminderEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(challenge.reminderEnabled ? Theme.accent : Theme.muted)
                        Text(i18n.lang == "en" ? "Remind me daily" : "Täglich erinnern")
                            .font(KraftFont.inter(13.5, .medium))
                            .foregroundColor(Theme.text)
                    }
                }
                .tint(Theme.accent)
                .onChange(of: challenge.reminderEnabled) { enabled in
                    if enabled {
                        notifications.requestAuthorization()
                    }
                }

                if challenge.reminderEnabled {
                    Rectangle().fill(Theme.border).frame(height: 1)

                    HStack {
                        Text(i18n.lang == "en" ? "Reminder Time" : "Uhrzeit")
                            .font(KraftFont.inter(13))
                            .foregroundColor(Theme.muted)

                        Spacer()

                        DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .onChange(of: reminderDate) { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                challenge.reminderHour = comps.hour ?? 9
                                challenge.reminderMinute = comps.minute ?? 0
                            }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
    }

    // MARK: - Aktionen

    private var actionSection: some View {
        VStack(spacing: 10) {
            KraftDashedButton(
                i18n.lang == "en" ? "Reset Challenge Progress" : "Challenge-Fortschritt zurücksetzen",
                systemImage: "arrow.counterclockwise"
            ) {
                showResetConfirm = true
            }
        }
        .padding(.top, 10)
    }
}
