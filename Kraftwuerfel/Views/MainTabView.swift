import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: KraftTab = .generator
    /*
      Das präsentierte Objekt liegt direkt im State und behält damit seine
      Identität. Vorher baute der Binding-Getter bei JEDEM Lesen ein neues
      LiveWorkoutWrapper mit frischer UUID. Weil HealthKitManager während des
      Trainings jede Sekunde sendet, wurde diese View jede Sekunde neu
      ausgewertet — neue ID, also hat SwiftUI das Sheet geschlossen und sofort
      wieder geöffnet. Das war das ständige Auf und Ab.
    */
    @State private var activeLiveWorkout: LiveWorkoutWrapper?
    /// Das Zahnrad in der Kopfzeile öffnet die Einstellungen als Blatt —
    /// sie sind kein eigener Bereich in der Leiste.
    @State private var showSettings = false
    
    /*
      Diese drei Manager wurden hier beobachtet, ohne im Body vorzukommen.
      HealthKit sendet im Training jede Sekunde — die ganze Tab-Hülle wurde
      also im Sekundentakt neu gebaut, ohne dass sich etwas ändern konnte.
      Wer sie braucht (LiveWorkoutView, KraftHeaderView), greift selbst auf
      .shared zu; die Singletons leben unabhängig von dieser View.
    */

    public init() {}
    
    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // STICKY HEADER
                KraftHeaderView(selectedTab: $selectedTab) { showSettings = true }
                
                // TAB CONTENT
                Group {
                    switch selectedTab {
                    case .generator:
                        GeneratorView(onStartLiveWorkout: { slots, title in
                            self.activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
                        })
                    case .aiCoach:
                        AICoachWizardView(onStartLiveWorkout: { slots, title in
                            self.activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
                        })
                    case .trainingsplan:
                        TrainingsplanView(onStartLiveWorkout: { slots, title in
                            self.activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
                        })
                    case .saved:
                        SavedPlansView(onStartLiveWorkout: { slots, title in
                            self.activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
                        })
                    case .favorites:
                        FavoritenView(onStartLiveWorkout: { slots, title in
                            self.activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
                        })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            /*
              Der freie Render-Plan schläft ein — der erste Aufruf danach hat im
              Test knapp 14 Sekunden gebraucht. Deshalb hier gleich anstupsen und
              den Katalog auffrischen, damit der KI-Coach später nicht wartet.
            */
            KraftAPI.shared.warmUp()
            await ExerciseDatabase.refreshFromAPI()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .fullScreenCover(item: $activeLiveWorkout) { wrapper in
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
