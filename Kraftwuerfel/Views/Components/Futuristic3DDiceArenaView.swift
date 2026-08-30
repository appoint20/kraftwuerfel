import SwiftUI

/*
  Futuristic3DDiceArenaView — High-Fidelity 3D Würfel-Arena
  nach Vorlage der metallischen Kraftwürfel-Würfel mit leuchtenden Neon-Cyan Pips.
  Bietet eine dynamische 3D-Perspektiven-Wurf-Animation: Die Würfel fliegen
  aus der Nutzerperspektive in die Tiefe der App, rotieren im Raum und landen
  mit spürbarem Haptik-Bounce.

  Würfel 1: Sätze (Sets)
  Würfel 2: Wiederholungen (Reps)
*/

public struct Futuristic3DDiceArenaView: View {
    @ObservedObject private var i18n = I18n.shared

    public let dice1Sets: Int           // 1 bis 6 Sätze
    public let dice2Reps: Int           // z. B. 8, 10, 12, 15, 20, 25 Wdh
    public let dice1Pips: Int           // 1 bis 6
    public let dice2Pips: Int           // 1 bis 6
    public let isRolling: Bool
    public let onRoll: () -> Void

    // 3D Animationszustände
    @State private var throwScale: CGFloat = 1.0
    @State private var throwOffsetY: CGFloat = 0.0
    @State private var rotateX1: Double = 0.0
    @State private var rotateY1: Double = 0.0
    @State private var rotateZ1: Double = 0.0
    @State private var rotateX2: Double = 0.0
    @State private var rotateY2: Double = 0.0
    @State private var rotateZ2: Double = 0.0
    @State private var shadowBlur: CGFloat = 15.0

    public init(
        dice1Sets: Int,
        dice2Reps: Int,
        dice1Pips: Int,
        dice2Pips: Int,
        isRolling: Bool,
        onRoll: @escaping () -> Void
    ) {
        self.dice1Sets = dice1Sets
        self.dice2Reps = dice2Reps
        self.dice1Pips = dice1Pips
        self.dice2Pips = dice2Pips
        self.isRolling = isRolling
        self.onRoll = onRoll
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Würfel-Arena
            ZStack {
                // Arena Hintergrund mit subtilem Neon-Glühen
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.07, green: 0.08, blue: 0.10), Color(red: 0.04, green: 0.05, blue: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.accent.opacity(0.35), Theme.border, Theme.accent.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Theme.accent.opacity(0.12), radius: 20, y: 8)

                // Subtile Arena-Bodenbeleuchtung
                Circle()
                    .fill(Theme.accent.opacity(isRolling ? 0.25 : 0.10))
                    .frame(width: 220, height: 100)
                    .blur(radius: 35)
                    .scaleEffect(isRolling ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRolling)

                // Die 2 3D-Würfel
                HStack(spacing: 24) {
                    // Würfel 1: SÄTZE (Sets)
                    VStack(spacing: 8) {
                        Text(i18n.lang == "en" ? "DICE 1 · SETS" : "WÜRFEL 1 · SÄTZE")
                            .font(KraftFont.mono(10.5, .bold))
                            .tracking(1.0)
                            .foregroundColor(Theme.accent)

                        FuturisticSingleDieView(
                            pips: dice1Pips,
                            label: "\(dice1Sets) " + (i18n.lang == "en" ? "SETS" : "SÄTZE"),
                            sub: i18n.lang == "en" ? "Work Sets" : "Arbeitssätze",
                            accentColor: Theme.accent
                        )
                        .rotation3DEffect(.degrees(rotateX1), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(rotateY1), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(rotateZ1), axis: (x: 0, y: 0, z: 1))
                    }

                    // Würfel 2: WIEDERHOLUNGEN (Reps)
                    VStack(spacing: 8) {
                        Text(i18n.lang == "en" ? "DICE 2 · REPS" : "WÜRFEL 2 · WDH")
                            .font(KraftFont.mono(10.5, .bold))
                            .tracking(1.0)
                            .foregroundColor(Theme.orange)

                        FuturisticSingleDieView(
                            pips: dice2Pips,
                            label: "\(dice2Reps) " + (i18n.lang == "en" ? "REPS" : "WDH"),
                            sub: i18n.lang == "en" ? "Repetitions" : "Wiederholungen",
                            accentColor: Theme.orange
                        )
                        .rotation3DEffect(.degrees(rotateX2), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(rotateY2), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(rotateZ2), axis: (x: 0, y: 0, z: 1))
                    }
                }
                .padding(.vertical, 16)
                .scaleEffect(throwScale)
                .offset(y: throwOffsetY)
            }
            .frame(height: 200)
            .contentShape(Rectangle())
            .onTapGesture {
                onRoll()
            }
            .onChange(of: isRolling) { rolling in
                if rolling {
                    triggerPerspectiveThrowAnimation()
                }
            }

            // Info-Zeile unter der Arena
            HStack {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.muted)
                Text(i18n.lang == "en"
                     ? "Tap the dice or the roll button to throw in 3D perspective"
                     : "Tippe auf die Würfel für den 3D-Perspektiven-Wurf")
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - 3D Perspektiven-Wurf Animation

    private func triggerPerspectiveThrowAnimation() {
        // Phase 1: Wurf aus der Benutzerperspektive (Start nah & groß vor der Kamera)
        throwScale = 1.6
        throwOffsetY = 70.0
        rotateX1 = -35.0
        rotateY1 = 45.0
        rotateZ1 = -20.0
        rotateX2 = 40.0
        rotateY2 = -50.0
        rotateZ2 = 25.0

        // Phase 2: Flug in die Tiefe & mehrachsige 3D-Rotation
        withAnimation(.easeInOut(duration: 0.5)) {
            throwScale = 0.88
            throwOffsetY = -15.0
            rotateX1 = 720.0 + Double.random(in: -30...30)
            rotateY1 = 540.0 + Double.random(in: -30...30)
            rotateZ1 = 360.0 + Double.random(in: -20...20)
            rotateX2 = -720.0 + Double.random(in: -30...30)
            rotateY2 = -540.0 + Double.random(in: -30...30)
            rotateZ2 = -360.0 + Double.random(in: -20...20)
        }

        // Phase 3: Landung auf dem Tisch mit Spring-Bounce & Haptik
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55, blendDuration: 0)) {
                throwScale = 1.0
                throwOffsetY = 0.0
                rotateX1 = 0.0
                rotateY1 = 0.0
                rotateZ1 = 0.0
                rotateX2 = 0.0
                rotateY2 = 0.0
                rotateZ2 = 0.0
            }
        }
    }
}

// MARK: - Einzelner Futuristischer Würfel mit Chamfer-Kanten & Neon Pips

public struct FuturisticSingleDieView: View {
    public let pips: Int
    public let label: String
    public let sub: String
    public let accentColor: Color

    public init(pips: Int, label: String, sub: String, accentColor: Color) {
        self.pips = min(6, max(1, pips))
        self.label = label
        self.sub = sub
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 3D Bevel Schatten
                ChamferedDieShape(chamfer: 14)
                    .fill(Color.black.opacity(0.6))
                    .offset(y: 6)
                    .blur(radius: 6)

                // Äußere abgeschrägte metallische Würfelhülle (Beveled Titanium)
                ChamferedDieShape(chamfer: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.26, blue: 0.30),
                                Color(red: 0.12, green: 0.14, blue: 0.16),
                                Color(red: 0.08, green: 0.09, blue: 0.11)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Metallische Kanten-Reflexion
                ChamferedDieShape(chamfer: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.65, blue: 0.75),
                                accentColor.opacity(0.8),
                                Color(red: 0.20, green: 0.24, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.0
                    )

                // Innere dunkle Würfelfläche (Matte Dark Inset)
                ChamferedDieShape(chamfer: 10)
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.11, green: 0.13, blue: 0.15), Color(red: 0.05, green: 0.06, blue: 0.07)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .padding(5)

                // Leuchtende Neon-Pips (Punkte 1 bis 6)
                DiePipsPatternView(count: pips, tint: accentColor)
                    .padding(14)
            }
            .frame(width: 105, height: 105)

            // Beschriftung unter dem Würfel
            VStack(spacing: 1) {
                Text(label)
                    .font(KraftFont.bebas(16))
                    .tracking(0.8)
                    .foregroundColor(Theme.text)

                Text(sub)
                    .font(KraftFont.inter(10.5))
                    .foregroundColor(Theme.muted)
            }
        }
    }
}

// MARK: - Chamfered Die Shape (Achteckige abgeschrägte Würfelform)

public struct ChamferedDieShape: Shape {
    public var chamfer: CGFloat = 12

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = min(chamfer, min(rect.width, rect.height) / 3)

        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.closeSubpath()

        return path
    }
}

// MARK: - Leuchtende Pips (Neon Cyan / Orange Dots)

public struct DiePipsPatternView: View {
    public let count: Int
    public let tint: Color

    public init(count: Int, tint: Color = Theme.accent) {
        self.count = min(6, max(1, count))
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                switch count {
                case 1:
                    pipDot.position(x: w * 0.5, y: h * 0.5)

                case 2:
                    pipDot.position(x: w * 0.28, y: h * 0.28)
                    pipDot.position(x: w * 0.72, y: h * 0.72)

                case 3:
                    pipDot.position(x: w * 0.25, y: h * 0.25)
                    pipDot.position(x: w * 0.50, y: h * 0.50)
                    pipDot.position(x: w * 0.75, y: h * 0.75)

                case 4:
                    pipDot.position(x: w * 0.28, y: h * 0.28)
                    pipDot.position(x: w * 0.72, y: h * 0.28)
                    pipDot.position(x: w * 0.28, y: h * 0.72)
                    pipDot.position(x: w * 0.72, y: h * 0.72)

                case 5:
                    pipDot.position(x: w * 0.26, y: h * 0.26)
                    pipDot.position(x: w * 0.74, y: h * 0.26)
                    pipDot.position(x: w * 0.50, y: h * 0.50)
                    pipDot.position(x: w * 0.26, y: h * 0.74)
                    pipDot.position(x: w * 0.74, y: h * 0.74)

                default: // 6
                    pipDot.position(x: w * 0.28, y: h * 0.24)
                    pipDot.position(x: w * 0.72, y: h * 0.24)
                    pipDot.position(x: w * 0.28, y: h * 0.50)
                    pipDot.position(x: w * 0.72, y: h * 0.50)
                    pipDot.position(x: w * 0.28, y: h * 0.76)
                    pipDot.position(x: w * 0.72, y: h * 0.76)
                }
            }
        }
    }

    private var pipDot: some View {
        ZStack {
            // Neon-Glüh-Aura
            Circle()
                .fill(tint.opacity(0.5))
                .frame(width: 17, height: 17)
                .blur(radius: 3.5)

            // Hell leuchtender Kern
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, tint, tint.opacity(0.8)],
                        center: .center,
                        startRadius: 1,
                        endRadius: 7
                    )
                )
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.5))
                .shadow(color: tint, radius: 5)
        }
    }
}
