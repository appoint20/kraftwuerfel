import SwiftUI

/*
  Die drei Körpertypen als Silhouette.

  Vorher stand dort nur „Ektomorph / Mesomorph / Endomorph“ mit einem Satz
  Erklärung. Wer die Begriffe nicht kennt — also fast jeder — musste raten,
  und geraten wurde in der Regel „Mesomorph“, weil es in der Mitte stand.
  Eine falsche Angabe hier verschiebt Kalorienziel und Satzempfehlung.

  Gezeichnet statt fotografiert: Ein Foto eines Körpers ist eine Aussage
  darüber, wie ein Körper auszusehen hat. Eine Silhouette zeigt den
  Unterschied, um den es geht — Schulterbreite, Taille, Gesamtmasse — ohne
  jemanden abzubilden.

  Der Unterschied steckt in drei Zahlen je Typ: Schulterbreite, Taillenbreite
  und Hüftbreite. Alles andere ist für alle drei gleich, damit man die
  Formen nebeneinander vergleichen kann.
*/
public struct SomatotypeFigure: View {

    private let type: Somatotype
    private let size: CGFloat
    private let isActive: Bool

    public init(_ type: Somatotype, size: CGFloat = 54, isActive: Bool = false) {
        self.type = type
        self.size = size
        self.isActive = isActive
    }

    /// Schulter, Taille, Hüfte — als Anteil der Figurenbreite.
    private var proportions: (shoulder: CGFloat, waist: CGFloat, hip: CGFloat) {
        switch type {
        case .ectomorph: return (0.52, 0.40, 0.46)  // schmal, gerade
        case .mesomorph: return (0.82, 0.48, 0.60)  // V-Form
        case .endomorph: return (0.74, 0.78, 0.80)  // kräftig, rund
        }
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let p = proportions
            let color = isActive ? Theme.accent : Theme.muted

            let midX = w / 2
            let headRadius = w * 0.12
            let headCenterY = headRadius + h * 0.04

            // Kopf
            context.fill(
                Path(ellipseIn: CGRect(
                    x: midX - headRadius, y: headCenterY - headRadius,
                    width: headRadius * 2, height: headRadius * 2
                )),
                with: .color(color)
            )

            // Rumpf: Schulter -> Taille -> Hüfte, mit weichen Kanten
            let torsoTop = headCenterY + headRadius * 1.25
            let waistY = torsoTop + (h - torsoTop) * 0.42
            let hipY = torsoTop + (h - torsoTop) * 0.72

            let shoulderHalf = w * p.shoulder / 2
            let waistHalf = w * p.waist / 2
            let hipHalf = w * p.hip / 2

            var torso = Path()
            torso.move(to: CGPoint(x: midX - shoulderHalf, y: torsoTop))
            torso.addLine(to: CGPoint(x: midX + shoulderHalf, y: torsoTop))
            torso.addQuadCurve(
                to: CGPoint(x: midX + hipHalf, y: hipY),
                control: CGPoint(x: midX + waistHalf, y: waistY)
            )
            torso.addLine(to: CGPoint(x: midX - hipHalf, y: hipY))
            torso.addQuadCurve(
                to: CGPoint(x: midX - shoulderHalf, y: torsoTop),
                control: CGPoint(x: midX - waistHalf, y: waistY)
            )
            torso.closeSubpath()
            context.fill(torso, with: .color(color))

            // Beine — für alle Typen gleich, sie tragen den Unterschied nicht.
            let legWidth = hipHalf * 0.62
            let legGap = hipHalf * 0.16
            for side in [-1.0, 1.0] {
                let x = midX + CGFloat(side) * (legGap + legWidth / 2) - legWidth / 2
                context.fill(
                    Path(roundedRect: CGRect(x: x, y: hipY - 2, width: legWidth, height: h - hipY),
                         cornerRadius: legWidth / 2.4),
                    with: .color(color)
                )
            }
        }
        .frame(width: size, height: size * 1.35)
        .accessibilityHidden(true)
    }
}

/*
  Eine Auswahlkarte je Körpertyp: Silhouette, Name, kurze Erklärung.

  Bewusst kein WizardCardChip: Die Erklärung ist hier keine Beigabe, sondern
  der Grund, warum die Auswahl überhaupt zu treffen ist.
*/
public struct SomatotypePicker: View {
    @ObservedObject private var i18n = I18n.shared
    @Binding private var selection: Somatotype

    public init(selection: Binding<Somatotype>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(Somatotype.allCases) { type in
                let isActive = selection == type
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.15)) { selection = type }
                }) {
                    VStack(spacing: 8) {
                        SomatotypeFigure(type, size: 42, isActive: isActive)

                        Text(type.localized(i18n.lang))
                            .font(KraftFont.inter(12.5, .semibold))
                            .foregroundColor(isActive ? Theme.accent : Theme.text)

                        Text(type.subtitle(i18n.lang))
                            .font(KraftFont.inter(10.5))
                            .foregroundColor(Theme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Theme.accentDim : Theme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Theme.accent : Theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
