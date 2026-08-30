import SwiftUI

/*
  BMIEvaluationCard — Interaktive BMI-Skala & Live-Bewertung
  nach dem Vorbild moderner Fitness-Assessment-Systeme (wie BetterMe).
  Berechnet in Echtzeit den BMI aus Größe & Gewicht und visualisiert
  die Position des Nutzers auf einer segmentierten Farbskala.
*/

public struct BMIEvaluationCard: View {
    @ObservedObject private var i18n = I18n.shared

    public let heightCm: Double
    public let weightKg: Double

    public init(heightCm: Double, weightKg: Double) {
        self.heightCm = heightCm
        self.weightKg = weightKg
    }

    private var bmi: Double {
        let heightM = max(0.5, heightCm / 100.0)
        return weightKg / (heightM * heightM)
    }

    private var bmiCategory: BMICategory {
        let b = bmi
        if b < 18.5 { return .underweight }
        if b < 25.0 { return .normal }
        if b < 30.0 { return .overweight }
        return .obese
    }

    // Prozentuale Position auf der Skala (15 bis 40 BMI)
    private var gaugePosition: CGFloat {
        let clamped = min(40.0, max(15.0, bmi))
        return CGFloat((clamped - 15.0) / (40.0 - 15.0))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerLine

            // Visuelle BMI-Skala mit Schieberegler / Nadel
            gaugeView

            // Feedback- und Empfehlungs-Box
            assessmentBox
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.4), Theme.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Kopfzeile

    private var headerLine: some View {
        HStack {
            Text("Body-Mass-Index (BMI)")
                .font(KraftFont.bebas(17)).tracking(1)
                .foregroundColor(Theme.text)

            Spacer()

            Text(String(format: "%.1f", bmi))
                .font(KraftFont.mono(16, .bold))
                .foregroundColor(categoryColor)
        }
    }

    // MARK: - Skala mit Nadel

    private var gaugeView: some View {
        VStack(spacing: 8) {
            // Nadel-Indikator ("Du - 19.49")
            GeometryReader { geo in
                let xPos = max(24, min(geo.size.width - 24, geo.size.width * gaugePosition))

                VStack(spacing: 2) {
                    Text("Du – \(String(format: "%.1f", bmi))")
                        .font(KraftFont.mono(10.5, .bold))
                        .foregroundColor(Theme.bg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.text))
                        .shadow(color: Theme.bg.opacity(0.5), radius: 4, y: 2)

                    Image(systemName: "triangle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Theme.text)
                        .rotationEffect(.degrees(180))
                }
                .position(x: xPos, y: 14)
            }
            .frame(height: 28)

            // Farbverlaufs-Balken mit Skalenpunkten
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Segmentierter Gradient: Blau -> Grün -> Orange -> Rot
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.2, green: 0.6, blue: 0.9), location: 0.0),   // Untergewichtig
                                    .init(color: Color(red: 0.2, green: 0.6, blue: 0.9), location: 0.14),
                                    .init(color: Theme.accent, location: 0.15),                            // Normal (18.5 - 25)
                                    .init(color: Theme.accent, location: 0.40),
                                    .init(color: Theme.orange, location: 0.41),                            // Übergewichtig (25 - 30)
                                    .init(color: Theme.orange, location: 0.60),
                                    .init(color: Color(red: 0.9, green: 0.2, blue: 0.3), location: 0.61), // Fettleibig (30+)
                                    .init(color: Color(red: 0.9, green: 0.2, blue: 0.3), location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)

                    // Skalen-Markierungen (15, 18.5, 25, 30, 40)
                    let p18_5 = geo.size.width * CGFloat((18.5 - 15.0) / 25.0)
                    let p25_0 = geo.size.width * CGFloat((25.0 - 15.0) / 25.0)
                    let p30_0 = geo.size.width * CGFloat((30.0 - 15.0) / 25.0)

                    Rectangle().fill(Theme.bg).frame(width: 1.5, height: 8).position(x: p18_5, y: 4)
                    Rectangle().fill(Theme.bg).frame(width: 1.5, height: 8).position(x: p25_0, y: 4)
                    Rectangle().fill(Theme.bg).frame(width: 1.5, height: 8).position(x: p30_0, y: 4)
                }
            }
            .frame(height: 8)

            // Skalen-Zahlen
            HStack {
                Text("15").font(KraftFont.mono(9)).foregroundColor(Theme.muted)
                Spacer()
                Text("18.5").font(KraftFont.mono(9)).foregroundColor(Theme.muted)
                Spacer()
                Text("25").font(KraftFont.mono(9)).foregroundColor(Theme.muted)
                Spacer()
                Text("30").font(KraftFont.mono(9)).foregroundColor(Theme.muted)
                Spacer()
                Text("40").font(KraftFont.mono(9)).foregroundColor(Theme.muted)
            }

            // Kategorienamen
            HStack {
                Text(i18n.lang == "en" ? "Underweight" : "Untergewicht")
                    .font(KraftFont.inter(9.5, bmiCategory == .underweight ? .bold : .regular))
                    .foregroundColor(bmiCategory == .underweight ? Color(red: 0.2, green: 0.6, blue: 0.9) : Theme.muted.opacity(0.8))
                Spacer()
                Text(i18n.lang == "en" ? "Normal" : "Normal")
                    .font(KraftFont.inter(9.5, bmiCategory == .normal ? .bold : .regular))
                    .foregroundColor(bmiCategory == .normal ? Theme.accent : Theme.muted.opacity(0.8))
                Spacer()
                Text(i18n.lang == "en" ? "Overweight" : "Übergewicht")
                    .font(KraftFont.inter(9.5, bmiCategory == .overweight ? .bold : .regular))
                    .foregroundColor(bmiCategory == .overweight ? Theme.orange : Theme.muted.opacity(0.8))
                Spacer()
                Text(i18n.lang == "en" ? "Obese" : "Fettleibig")
                    .font(KraftFont.inter(9.5, bmiCategory == .obese ? .bold : .regular))
                    .foregroundColor(bmiCategory == .obese ? Color(red: 0.9, green: 0.2, blue: 0.3) : Theme.muted.opacity(0.8))
            }
        }
    }

    // MARK: - Bewertungs-Box

    private var assessmentBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(categoryColor)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(assessmentTitle)
                    .font(KraftFont.inter(13, .bold))
                    .foregroundColor(Theme.text)

                Text(assessmentBody)
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(categoryColor.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(categoryColor.opacity(0.35), lineWidth: 1))
    }

    private var categoryColor: Color {
        switch bmiCategory {
        case .underweight: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .normal: return Theme.accent
        case .overweight: return Theme.orange
        case .obese: return Color(red: 0.9, green: 0.2, blue: 0.3)
        }
    }

    private var assessmentTitle: String {
        let isEn = i18n.lang == "en"
        switch bmiCategory {
        case .underweight:
            return isEn ? "Underweight Range:" : "Leichtes Untergewicht:"
        case .normal:
            return isEn ? "Healthy BMI:" : "Gesunder BMI:"
        case .overweight:
            return isEn ? "Overweight Range:" : "Erhöhter BMI-Bereich:"
        case .obese:
            return isEn ? "High BMI Range:" : "Stark erhöhter BMI:"
        }
    }

    private var assessmentBody: String {
        let isEn = i18n.lang == "en"
        switch bmiCategory {
        case .underweight:
            return isEn
                ? "Ideal starting point to focus on clean mass gain and strength building. We will adjust your calorie surplus accordingly."
                : "Optimaler Ausgangspunkt für gezielten Muskelaufbau und kontrollierten Kalorienüberschuss."
        case .normal:
            return isEn
                ? "Great baseline to get in peak shape and build lean muscle. We will use your BMI to tailor your exact training & nutrition volume."
                : "Hervorragender Ausgangswert, um in Topform zu kommen. Wir nutzen deinen BMI-Wert für dein maßgeschneidertes Programm."
        case .overweight:
            return isEn
                ? "Solid base for body recomposition — shedding fat while preserving and toning muscle with a slight calorie deficit."
                : "Sehr gute Ausgangslage für Body-Recomposition: Fettverbrennung bei gleichzeitigem Muskelerhalt im moderaten Defizit."
        case .obese:
            return isEn
                ? "Focus on joint-friendly exercises, high-energy burn, and structured nutrition to steadily decrease body fat."
                : "Fokus auf gelenkschonende Bewegung, effektive Fettverbrennung und nachhaltige Ernährungssteuerung."
        }
    }
}
