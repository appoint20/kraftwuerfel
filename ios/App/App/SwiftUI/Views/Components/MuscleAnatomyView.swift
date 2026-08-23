import SwiftUI

public struct MuscleAnatomyView: View {
    public let activeCategory: MuscleCategory
    public var isBackView: Bool = false
    
    public init(activeCategory: MuscleCategory, isBackView: Bool = false) {
        self.activeCategory = activeCategory
        self.isBackView = isBackView
    }
    
    private var isCategoryActive: Bool {
        if isBackView {
            return activeCategory == .back || activeCategory == .glutes || activeCategory == .calves || activeCategory == .neck
        } else {
            return activeCategory == .chest || activeCategory == .shoulders || activeCategory == .biceps || activeCategory == .legs || activeCategory == .core
        }
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack(spacing: 8) {
                // Vector silhouette illustration
                ZStack {
                    // Silhouette base
                    Image(systemName: isBackView ? "figure.walk" : "figure.stand")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundColor(Color.white.opacity(0.2))
                    
                    // Muscle highlight glow
                    if isCategoryActive {
                        Image(systemName: isBackView ? "figure.walk" : "figure.stand")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.8), radius: 12, x: 0, y: 0)
                            .opacity(0.9)
                    }
                }
                .padding(.top, 8)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text(activeCategory.localized)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 6)
            }
        }
        .frame(width: 140, height: 160)
    }
}
