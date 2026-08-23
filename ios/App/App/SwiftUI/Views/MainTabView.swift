import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
    case generator = "Generator"
    case aiCoach = "KI-Coach"
    case trainingsplan = "Trainingsplan"
    case saved = "Gespeichert"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .generator: return "dice.fill"
        case .aiCoach: return "sparkles"
        case .trainingsplan: return "calendar.badge.clock"
        case .saved: return "bookmark.fill"
        }
    }
}

@available(iOS 15.0, *)
public struct MainTabView: View {
    @State private var selectedTab: AppTab = .generator
    @State private var activeLiveWorkout: (slots: [ExerciseSlot], title: String)?
    
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var watchSync = WatchSyncManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            
            // MAIN TAB CONTENT
            Group {
                switch selectedTab {
                case .generator:
                    GeneratorView(onStartLiveWorkout: { slots, title in
                        self.activeLiveWorkout = (slots, title)
                    })
                case .aiCoach:
                    AICoachWizardView(onStartLiveWorkout: { slots, title in
                        self.activeLiveWorkout = (slots, title)
                    })
                case .trainingsplan:
                    TrainingsplanView(onStartLiveWorkout: { slots, title in
                        self.activeLiveWorkout = (slots, title)
                    })
                case .saved:
                    SavedPlansView(onStartLiveWorkout: { slots, title in
                        self.activeLiveWorkout = (slots, title)
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // GLASSMORPHIC TAB BAR
            HStack {
                ForEach(AppTab.allCases) { tab in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .orange : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(
                Color(white: 0.1)
                    .opacity(0.92)
                    .background(.ultraThinMaterial)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: -4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .edgesIgnoringSafeArea(.bottom)
        .fullScreenCover(isPresented: Binding(
            get: { activeLiveWorkout != nil },
            set: { if !$0 { activeLiveWorkout = nil } }
        )) {
            if let workout = activeLiveWorkout {
                LiveWorkoutView(
                    slots: workout.slots,
                    planTitle: workout.title,
                    onFinish: {
                        activeLiveWorkout = nil
                    }
                )
            }
        }
        .onAppear {
            Task {
                _ = await healthKit.requestAuthorization()
            }
        }
    }
}
