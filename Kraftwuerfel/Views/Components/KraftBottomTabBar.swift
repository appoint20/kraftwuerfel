import SwiftUI

/*
  Moderne untere Navigationsleiste (Bottom Tab Bar).
  Ersetzt die frühere obere Taskleiste und dockt die fünf Hauptbereiche
  am unteren Bildschirmrand an.
*/
public struct KraftBottomTabBar: View {
    @Binding public var selectedTab: KraftTab
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    public init(selectedTab: Binding<KraftTab>) {
        self._selectedTab = selectedTab
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Oberer feiner Trennstrich
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(KraftTab.allCases) { tab in
                    tabItem(tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 6)
        }
        .background(
            Theme.surface
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(_ tab: KraftTab) -> some View {
        let isActive = selectedTab == tab
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 3) {
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accentDim)
                            .frame(width: 44, height: 26)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: isActive ? .bold : .medium))
                        if tab == .aiCoach && !storeKit.isProUnlocked {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .foregroundColor(isActive ? Theme.accent : Theme.muted)
                }
                .frame(height: 26)

                Text(i18n.t(tab.titleKey))
                    .font(KraftFont.bebas(11))
                    .tracking(0.4)
                    .foregroundColor(isActive ? Theme.accent : Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityLabel(i18n.t(tab.titleKey))
    }
}
