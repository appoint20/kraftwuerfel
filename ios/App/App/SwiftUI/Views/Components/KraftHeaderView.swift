import SwiftUI

public enum KraftTab: String, CaseIterable, Identifiable {
    case generator = "GENERATOR"
    case aiCoach = "KI-COACH"
    case trainingsplan = "TRAININGSPLAN"
    case saved = "GESPEICHERT"
    
    public var id: String { rawValue }
}

public struct KraftHeaderView: View {
    @Binding public var selectedTab: KraftTab
    
    public init(selectedTab: Binding<KraftTab>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // BRAND ROW
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.accent)
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "dice.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.bg)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("KRAFTWÜRFEL")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(Theme.text)
                    
                    Text("Hypertrophie & Trainings-Generator")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.muted)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // TABS ROW
            HStack(spacing: 4) {
                ForEach(KraftTab.allCases) { tab in
                    let isActive = selectedTab == tab
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(isActive ? Theme.accent : Theme.muted)
                                .frame(maxWidth: .infinity)
                            
                            Rectangle()
                                .fill(isActive ? Theme.accent : Color.clear)
                                .frame(height: 2.5)
                                .cornerRadius(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Divider()
                .background(Theme.border)
        }
        .background(Theme.bg)
    }
}
