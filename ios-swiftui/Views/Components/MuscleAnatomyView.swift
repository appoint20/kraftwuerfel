import SwiftUI

public struct MuscleAnatomyView: View {
    public let category: MuscleCategory
    public let size: CGFloat
    
    public init(category: MuscleCategory, size: CGFloat = 40) {
        self.category = category
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )
            
            // Simplified anatomical silhouette with target muscle glow
            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height
                
                // Base silhouette body
                let bodyPath = Path { p in
                    p.addEllipse(in: CGRect(x: w * 0.4, y: h * 0.08, width: w * 0.2, height: h * 0.16)) // Head
                    p.move(to: CGPoint(x: w * 0.3, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.7, y: h * 0.28))
                    p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.58))
                    p.closeSubpath()
                    
                    // Legs
                    p.addRect(CGRect(x: w * 0.36, y: h * 0.6, width: w * 0.11, height: h * 0.32))
                    p.addRect(CGRect(x: w * 0.53, y: h * 0.6, width: w * 0.11, height: h * 0.32))
                }
                context.fill(bodyPath, with: .color(Color.gray.opacity(0.3)))
                
                // Highlight target muscle group
                let highlightColor = Color.accentEmerald
                var targetPath = Path()
                
                switch category {
                case .chest:
                    targetPath.addRect(CGRect(x: w * 0.34, y: h * 0.30, width: w * 0.32, height: h * 0.12))
                case .back:
                    targetPath.addRect(CGRect(x: w * 0.32, y: h * 0.28, width: w * 0.36, height: h * 0.20))
                case .shoulders:
                    targetPath.addEllipse(in: CGRect(x: w * 0.24, y: h * 0.27, width: w * 0.12, height: h * 0.12))
                    targetPath.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.27, width: w * 0.12, height: h * 0.12))
                case .legs:
                    targetPath.addRect(CGRect(x: w * 0.36, y: h * 0.60, width: w * 0.11, height: h * 0.18))
                    targetPath.addRect(CGRect(x: w * 0.53, y: h * 0.60, width: w * 0.11, height: h * 0.18))
                case .glutes:
                    targetPath.addRect(CGRect(x: w * 0.34, y: h * 0.54, width: w * 0.32, height: h * 0.12))
                case .biceps, .triceps:
                    targetPath.addRect(CGRect(x: w * 0.22, y: h * 0.34, width: w * 0.09, height: h * 0.15))
                    targetPath.addRect(CGRect(x: w * 0.69, y: h * 0.34, width: w * 0.09, height: h * 0.15))
                case .core:
                    targetPath.addRect(CGRect(x: w * 0.38, y: h * 0.44, width: w * 0.24, height: h * 0.14))
                case .calves:
                    targetPath.addRect(CGRect(x: w * 0.36, y: h * 0.78, width: w * 0.11, height: h * 0.14))
                    targetPath.addRect(CGRect(x: w * 0.53, y: h * 0.78, width: w * 0.11, height: h * 0.14))
                case .neck, .fullBody:
                    targetPath = bodyPath
                }
                
                context.fill(targetPath, with: .color(highlightColor))
            }
            .padding(size * 0.12)
        }
        .frame(width: size, height: size)
    }
}
