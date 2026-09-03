import SwiftUI

/*
  Das zweite fehlende Ziel.

  WatchContentView.swift lag bisher im iPhone-Ziel und war hinter
  `#if os(watchOS) || canImport(WatchKit)` versteckt. Auf iOS lässt sich
  WatchKit importieren, die Bedingung war also wahr — die Ansicht wurde in die
  iPhone-App übersetzt, wo sie niemand je zu Gesicht bekam. Toter Code, der
  aussah wie eine fertige Uhren-App.

  Ab hier ist es eine echte watchOS-App mit eigenem Bundle, eigener
  WCSession-Gegenstelle und eigener HKWorkoutSession.
*/
@main
struct KraftwuerfelWatchApp: App {

    @StateObject private var sync = WatchSyncManager.shared
    @StateObject private var workout = WatchWorkoutManager.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Die Gegenstelle muss stehen, bevor das iPhone den ersten Zustand
        // schickt — sonst geht der Start der Sitzung verloren.
        _ = WatchSyncManager.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(sync)
                .environmentObject(workout)
                .task { await workout.requestAuthorization() }
        }
        /*
          Jedes Mal nachfragen, wenn die App wieder nach vorn kommt.

          Im Hintergrund kann die Uhr Nachrichten verpassen — und weil Zustand
          bisher nur bei Änderungen auf dem iPhone floss, blieb ein verpasster
          Wechsel für den Rest des Trainings verpasst. Genau das war die
          „verlorene Verbindung", die sich nur durch Schließen der App und einen
          abgehakten Satz am iPhone lösen ließ.
        */
        .onChange(of: scenePhase) { phase in
            if phase == .active { WatchSyncManager.shared.requestState() }
        }
    }
}
