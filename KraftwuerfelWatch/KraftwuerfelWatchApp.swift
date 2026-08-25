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
    }
}
