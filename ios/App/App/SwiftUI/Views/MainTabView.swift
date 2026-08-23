import SwiftUI

@available(iOS 15.0, *)
public struct MainTabView: View {
    @State private var selectedTab: KraftTab = .generator
    @State private var activeLiveWorkout: (slots: [ExerciseSlot], title: String)?
    
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var watchSync = WatchSyncManager.shared
    @StateObject private var storeKit = StoreKitManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // STICKY HEADER
                KraftHeaderView(selectedTab: $selectedTab)
                
                // TAB CONTENT
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
            }
        }
        .fullScreenCover(item: Binding(
            get: {
                if let w = activeLiveWorkout {
                    return LiveWorkoutWrapper(slots: w.slots, title: w.title)
                }
                return nil
            },
            set: { _ in activeLiveWorkout = nil }
        )) { wrapper in
            LiveWorkoutView(
                slots: wrapper.slots,
                planTitle: wrapper.title,
                onFinish: {
                    self.activeLiveWorkout = nil
                }
            )
            .preferredColorScheme(.dark)
        }
    }
}

public struct LiveWorkoutWrapper: Identifiable {
    public var id = UUID()
    public let slots: [ExerciseSlot]
    public let title: String
}
