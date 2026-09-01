import SwiftUI

/*
  Die Bewertung eines Plans, als Karte.

  Zugeklappt zeigt sie die Gesamtnote und einen Ring; aufgeklappt die sechs
  Einzelwerte, die konkreten Hinweise und die Wochensätze je Muskelgruppe.

  Die Farbe allein trägt die Aussage nicht — jede Note steht zusätzlich als
  Zahl und als Wort daneben. Wer Rot und Grün nicht unterscheidet, liest
  „Volumen 42 · Schwach“ statt eines roten Balkens.
*/
public struct PlanScoreCard: View {
    @ObservedObject private var i18n = I18n.shared
    /*
      Die Sperre sitzt in der Karte, nicht bei den Aufrufern.

      Die Bewertung wird an drei Stellen gezeigt (KI-Plan, Plan-Baukasten,
      laufender Trainingsplan). Läge die Pro-Prüfung dort, wäre sie dreimal
      geschrieben — und die vierte Stelle, die später dazukommt, hätte sie
      vergessen. So kann die Karte gar nicht ungesperrt erscheinen.
    */
    @ObservedObject private var storeKit = StoreKitManager.shared

    public let score: PlanQualityScore
    /// Zugeklappt in Listen, aufgeklappt in der Detailansicht.
    public let startsExpanded: Bool

    @State private var expanded: Bool

    public init(score: PlanQualityScore, startsExpanded: Bool = false) {
        self.score = score
        self.startsExpanded = startsExpanded
        _expanded = State(initialValue: startsExpanded)
    }

    public var body: some View {
        if storeKit.isProUnlocked {
            unlockedCard
        } else {
            lockedCard
        }
    }

    /*
      Gesperrt wird die Note gezeigt, nicht versteckt: Wer sieht, dass es
      eine Bewertung gibt und wofür sie steht, versteht wenigstens, was ihm
      fehlt. Eine leere Fläche verkauft nichts und erklärt nichts.
    */
    private var lockedCard: some View {
        Button(action: { NotificationCenter.default.post(name: .kraftShowPro, object: nil) }) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ProFeature.planScore.localized(i18n.lang))
                        .font(KraftFont.bebas(16)).tracking(0.8)
                        .foregroundColor(Theme.text)
                    Text(ProFeature.planScore.localizedSubtitle(i18n.lang))
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Text(i18n.t("pro.badge"))
                    .font(KraftFont.mono(9.5, .bold))
                    .foregroundColor(Theme.bg)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var unlockedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            if expanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle().fill(Theme.border).frame(height: 1)
                    dimensionList
                    if !score.findings.isEmpty { findingList }
                    if !score.weeklySets.isEmpty { volumeBars }
                    disclaimer
                }
                .padding(.top, 14)
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color(for: score.overall).opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Kopf

    private var headerRow: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        }) {
            HStack(spacing: 14) {
                scoreRing

                VStack(alignment: .leading, spacing: 3) {
                    Text(i18n.lang == "en" ? "PLAN SCORE" : "PLAN-BEWERTUNG")
                        .font(KraftFont.mono(9.5, .bold)).tracking(0.8)
                        .foregroundColor(Theme.muted)

                    Text(score.gradeLabel(i18n.lang))
                        .font(KraftFont.bebas(20)).tracking(0.8)
                        .foregroundColor(Theme.text)

                    Text(summaryLine)
                        .font(KraftFont.inter(11.5))
                        .foregroundColor(Theme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var summaryLine: String {
        let en = i18n.lang == "en"
        let weak = score.dimensions.filter { $0.band == .weak }
        if let first = weak.first {
            return en
                ? "Weakest area: \(first.title("en")) (\(first.score)/100)"
                : "Schwächster Punkt: \(first.title("de")) (\(first.score)/100)"
        }
        return en
            ? "~\(score.estimatedMinutes) min per session, no weak areas."
            : "~\(score.estimatedMinutes) Min pro Einheit, keine Schwachstelle."
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.surface2, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(score.overall) / 100.0)
                .stroke(
                    color(for: score.overall),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -2) {
                Text("\(score.overall)")
                    .font(KraftFont.mono(19, .bold))
                    .foregroundColor(Theme.text)
                Text("/100")
                    .font(KraftFont.mono(8))
                    .foregroundColor(Theme.muted)
            }
        }
        .frame(width: 58, height: 58)
    }

    // MARK: - Einzelwerte

    private var dimensionList: some View {
        VStack(spacing: 10) {
            ForEach(score.dimensions) { dimension in
                HStack(spacing: 10) {
                    Image(systemName: dimension.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color(for: dimension.score))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(dimension.title(i18n.lang))
                                .font(KraftFont.inter(12.5, .semibold))
                                .foregroundColor(Theme.text)
                            Spacer(minLength: 4)
                            Text("\(dimension.score)")
                                .font(KraftFont.mono(12, .bold))
                                .foregroundColor(color(for: dimension.score))
                            Text("· \(dimension.band.label(i18n.lang))")
                                .font(KraftFont.inter(10.5))
                                .foregroundColor(Theme.muted)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surface2).frame(height: 4)
                                Capsule()
                                    .fill(color(for: dimension.score))
                                    .frame(width: max(4, geo.size.width * CGFloat(dimension.score) / 100), height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text(dimension.detail(i18n.lang))
                            .font(KraftFont.inter(10.5))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Hinweise

    private var findingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.lang == "en" ? "WHAT STANDS OUT" : "WAS AUFFÄLLT")
                .font(KraftFont.mono(9.5, .bold)).tracking(0.8)
                .foregroundColor(Theme.muted)

            ForEach(score.findings) { finding in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: finding.isPositive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(finding.isPositive ? Theme.green : Theme.orange)
                        .padding(.top, 2)
                    Text(finding.text(i18n.lang))
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
    }

    // MARK: - Wochenvolumen

    private var volumeBars: some View {
        let sorted = score.weeklySets
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        let maxValue = max(PlanQualityScore.volumeCeiling, sorted.first?.value ?? 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(i18n.lang == "en" ? "WEEKLY SETS PER MUSCLE" : "WOCHENSÄTZE JE MUSKELGRUPPE")
                    .font(KraftFont.mono(9.5, .bold)).tracking(0.8)
                    .foregroundColor(Theme.muted)
                Spacer()
                Text("\(PlanQualityScore.volumeFloor)–\(PlanQualityScore.volumeCeiling)")
                    .font(KraftFont.mono(9.5, .bold))
                    .foregroundColor(Theme.accent)
            }

            ForEach(sorted, id: \.key) { entry in
                HStack(spacing: 8) {
                    Text(i18n.category(entry.key))
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                        .frame(width: 74, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2).frame(height: 7)

                            // Der Zielkorridor als heller Streifen dahinter.
                            let lo = CGFloat(PlanQualityScore.volumeFloor) / CGFloat(maxValue)
                            let hi = CGFloat(PlanQualityScore.volumeCeiling) / CGFloat(maxValue)
                            Rectangle()
                                .fill(Theme.accent.opacity(0.12))
                                .frame(width: geo.size.width * (hi - lo), height: 7)
                                .offset(x: geo.size.width * lo)

                            Capsule()
                                .fill(volumeColor(entry.value))
                                .frame(width: max(5, geo.size.width * CGFloat(entry.value) / CGFloat(maxValue)), height: 7)
                        }
                    }
                    .frame(height: 7)

                    Text("\(entry.value)")
                        .font(KraftFont.mono(11, .bold))
                        .foregroundColor(volumeColor(entry.value))
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
    }

    private var disclaimer: some View {
        Text(i18n.lang == "en"
             ? "Guide values from common training literature. Orientation, not medical advice."
             : "Richtwerte aus der gängigen Trainingsliteratur. Orientierung, keine medizinische Beratung.")
            .font(KraftFont.inter(10))
            .foregroundColor(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Farben

    private func color(for score: Int) -> Color {
        switch score {
        case 80...: return Theme.green
        case 55..<80: return Theme.accent
        default: return Theme.orange
        }
    }

    private func volumeColor(_ sets: Int) -> Color {
        if sets < PlanQualityScore.volumeFloor { return Theme.orange }
        if sets > PlanQualityScore.volumeCeiling { return Theme.orange }
        return Theme.accent
    }
}
