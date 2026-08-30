import SwiftUI

/*
  BiometricsBreakdownView — Visuelle Körpertyp-, Aktivitäts- & Stoffwechsel-Auswertung
  (BetterMe-inspiriertes Biometrie-Dashboard).
  Berechnet Grundumsatz (BMR), Gesamtenergiebedarf (TDEE), Ziel-Kalorien und Makros
  basierend auf der Mifflin-St Jeor Formel und den Nutzereingaben.
*/

public struct BiometricsBreakdownView: View {
    @ObservedObject private var i18n = I18n.shared
    @State private var showSomatotypeGuide = false

    @Binding public var somatotype: Somatotype
    @Binding public var activityLevel: ActivityLevel

    public let biometrics: UserBiometrics
    public let goal: TrainingGoal
    public let goalWeightKg: Double?

    public init(
        somatotype: Binding<Somatotype>,
        activityLevel: Binding<ActivityLevel>,
        biometrics: UserBiometrics,
        goal: TrainingGoal,
        goalWeightKg: Double? = nil
    ) {
        self._somatotype = somatotype
        self._activityLevel = activityLevel
        self.biometrics = biometrics
        self.goal = goal
        self.goalWeightKg = goalWeightKg
    }

    private var targetCals: Int {
        biometrics.targetCalories(for: goal, goalWeightKg: goalWeightKg)
    }

    private var proteinGrams: Int {
        let perKg = (goal == .muscle || goal == .definition) ? 2.0 : 1.6
        return Int((biometrics.weightKg * perKg).rounded())
    }

    private var fatGrams: Int {
        Int((biometrics.weightKg * 0.9).rounded())
    }

    private var carbGrams: Int {
        let calsFromProteinAndFat = (proteinGrams * 4) + (fatGrams * 9)
        return max(50, (targetCals - calsFromProteinAndFat) / 4)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            somatotypeSection
            activitySection
            metabolismCard
        }
        .sheet(isPresented: $showSomatotypeGuide) {
            SomatotypeGuideSheet(selectedSomatotype: $somatotype)
        }
    }

    // MARK: - Körpertyp (Somatotyp)

    private var somatotypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(i18n.lang == "en" ? "BODY TYPE (SOMATOTYPE)" : "KÖRPERTYP (SOMATOTYP)")
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSomatotypeGuide = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                        Text(i18n.lang == "en" ? "Finder & Test" : "Typ-Finder & Test")
                            .font(KraftFont.inter(11.5, .bold))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accentDim))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(Somatotype.allCases) { type in
                    let isSelected = somatotype == type
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { somatotype = type }
                    }) {
                        HStack(spacing: 12) {
                            /*
                              Die Silhouette statt eines SF-Symbols:
                              „figure.walk“ und „figure.strengthtraining“
                              zeigen Tätigkeiten, nicht Körperformen — der
                              Unterschied zwischen den drei Typen war daran
                              nicht zu erkennen.
                            */
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Theme.accentDim : Theme.surface2)
                                    .frame(width: 38, height: 38)
                                SomatotypeFigure(type, size: 17, isActive: isSelected)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.localized(i18n.lang))
                                    .font(KraftFont.inter(13.5, isSelected ? .bold : .semibold))
                                    .foregroundColor(isSelected ? Theme.text : Theme.text.opacity(0.85))

                                Text(type.subtitle(i18n.lang))
                                    .font(KraftFont.inter(11))
                                    .foregroundColor(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 4)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Theme.accentDim.opacity(0.6) : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Alltags-Aktivität

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(i18n.lang == "en" ? "DAILY ACTIVITY & LIFESTYLE" : "LEBENSSTIL & AKTIVITÄTSNIVEAU")

            VStack(spacing: 8) {
                ForEach(ActivityLevel.allCases) { level in
                    let isSelected = activityLevel == level
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { activityLevel = level }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Theme.orange.opacity(0.15) : Theme.surface2)
                                    .frame(width: 38, height: 38)
                                Image(systemName: level.icon)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(isSelected ? Theme.orange : Theme.muted)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.localized(i18n.lang))
                                    .font(KraftFont.inter(13.5, isSelected ? .bold : .semibold))
                                    .foregroundColor(isSelected ? Theme.text : Theme.text.opacity(0.85))

                                Text(level.subtitle(i18n.lang))
                                    .font(KraftFont.inter(11))
                                    .foregroundColor(Theme.muted)
                            }

                            Spacer(minLength: 4)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.orange)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Theme.orange.opacity(0.1) : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.orange : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stoffwechsel & Kalorien/Makro Dashboard

    private var metabolismCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Theme.orange)
                Text(i18n.lang == "en" ? "METABOLISM & DAILY ENERGY METRICS" : "STOFFWECHSEL & TÄGLICHE ENERGIE-METRIKEN")
                    .font(KraftFont.bebas(16)).tracking(1)
                    .foregroundColor(Theme.text)
                Spacer()
            }

            // 3-Spalten Metriken: BMR, TDEE, ZIEL
            HStack(spacing: 8) {
                metricBox(
                    title: i18n.lang == "en" ? "BMR (BASE)" : "GRUNDUMSATZ",
                    value: "\(biometrics.bmr)",
                    unit: "kcal",
                    sub: i18n.lang == "en" ? "In complete rest" : "In Ruhe",
                    color: Theme.muted
                )

                metricBox(
                    title: i18n.lang == "en" ? "TDEE (TOTAL)" : "GESAMTUMSATZ",
                    value: "\(biometrics.tdee)",
                    unit: "kcal",
                    sub: i18n.lang == "en" ? "With daily movement" : "Mit Aktivität",
                    color: Theme.accent
                )

                metricBox(
                    title: i18n.lang == "en" ? "TARGET" : "ZIEL-KALORIEN",
                    value: "\(targetCals)",
                    unit: "kcal",
                    sub: goal.localized(i18n.lang),
                    color: Theme.orange
                )
            }

            // Makronährstoff-Vorschau
            VStack(alignment: .leading, spacing: 6) {
                Text(i18n.lang == "en" ? "Recommended Daily Macros:" : "Empfohlene tägliche Makroverteilung:")
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)

                HStack(spacing: 12) {
                    macroTag(name: "Protein", grams: proteinGrams, color: Theme.accent)
                    macroTag(name: i18n.lang == "en" ? "Fats" : "Fette", grams: fatGrams, color: Theme.orange)
                    macroTag(name: "Carbs", grams: carbGrams, color: Color(red: 0.3, green: 0.8, blue: 0.5))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Theme.orange.opacity(0.4), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func metricBox(title: String, value: String, unit: String, sub: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(KraftFont.mono(9, .bold))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(KraftFont.bebas(20))
                    .foregroundColor(color)
                Text(unit)
                    .font(KraftFont.mono(9.5))
                    .foregroundColor(color.opacity(0.8))
            }

            Text(sub)
                .font(KraftFont.inter(9.5))
                .foregroundColor(Theme.muted.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func macroTag(name: String, grams: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(name):")
                .font(KraftFont.inter(11))
                .foregroundColor(Theme.muted)
            Text("\(grams)g")
                .font(KraftFont.mono(11, .bold))
                .foregroundColor(Theme.text)
        }
    }
}
