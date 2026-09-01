import SwiftUI

public struct MainTabView: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    /*
      Landet nach der Anmeldung auf dem Trainingsplan, nicht auf dem
      Generator: Wer angemeldet ist, hat in der Regel einen laufenden Plan,
      und der ist die Antwort auf „was mache ich heute“. Der Generator ist
      der Schritt davor und einen Tipp entfernt.
    */
    @State private var selectedTab: KraftTab = .plans
    @State private var activeLiveWorkout: LiveWorkoutWrapper?
    @State private var showSettings = false
    @State private var showPro = false

    public init() {}

    /*
      Einziger Startpunkt für die Live-Session, egal ob der Vorschlag vom
      Generator, dem KI-Coach, dem Trainingsplan, Gespeichert oder Favoriten
      kommt. Vorher konnte jeder Aufrufer die Sitzung direkt öffnen — die
      Pro-Sperre stand nur beim KI-Coach und beim Speichern, nie beim Start
      selbst. Hier an einer Stelle geprüft, statt an fünf.
    */
    private func startLiveWorkout(_ slots: [ExerciseSlot], _ title: String) {
        activeLiveWorkout = LiveWorkoutWrapper(slots: slots, title: title)
    }

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // STICKY HEADER (Marke, Untertitel, Begrüßung & Aktionen)
                KraftHeaderView(
                    onOpenSettings: { showSettings = true },
                    onOpenPro: { showPro = true }
                )

                // TAB CONTENT
                Group {
                    switch selectedTab {
                    case .generator:
                        GeneratorView(onStartLiveWorkout: startLiveWorkout)
                    case .aiCoach:
                        AICoachWizardView(onStartLiveWorkout: startLiveWorkout)
                    case .plans:
                        PlansHubView(onStartLiveWorkout: startLiveWorkout)
                    case .progress:
                        FortschrittView(onStartLiveWorkout: startLiveWorkout)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // WERBEBANNER FÜR FREE-USER (wird bei Pro automatisch ausgeblendet)
                AdBannerView()

                // UNTERE REITERLEISTE (Bottom Tab Bar)
                KraftBottomTabBar(selectedTab: $selectedTab)
            }

            // VOLLBILD-WERBEMODAL (Rewarded Video / Interstitials)
            AdOverlayModal()
        }
        .task {
            /*
              Werbung erst nach der Anmeldung starten: Die Zustimmungs- und
              Tracking-Abfragen sollen nicht über der Anmeldeschranke liegen,
              wo der Nutzer noch gar nicht weiß, wofür die App da ist.
            */
            await GoogleAdsService.shared.startIfNeeded()
            KraftAPI.shared.warmUp()
            await ExerciseDatabase.refreshFromAPI()
            /*
              Die Frage nach Mitteilungen stand hier und lief damit beim
              allerersten Start los — vor der Anmeldung, neben der
              Willkommensseite. Ein Systemdialog, bevor der Nutzer die App
              überhaupt gesehen hat, wird weggetippt, und ein zweites Mal
              fragt iOS nicht. Gefragt wird jetzt am Ende des Fragebogens,
              wo Erinnerungen an Trainingstage auch einen Sinn ergeben.
            */
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPro) { ProSubscriptionView() }
        // Gesperrte Stellen tief in der Ansicht bitten hierüber um die Pro-Seite.
        .onReceive(NotificationCenter.default.publisher(for: .kraftShowPro)) { _ in
            showPro = true
        }
        .fullScreenCover(item: $activeLiveWorkout) { wrapper in
            LiveWorkoutView(
                slots: wrapper.slots,
                planTitle: wrapper.title,
                onNavigateToProgress: {
                    self.activeLiveWorkout = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selectedTab = .progress
                    }
                },
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
