import AVFoundation
import Foundation

/*
  Die Audiositzung der App — eine Stelle, an der sie eingestellt wird.

  Zwei Fehler hatte sie schon:

  1. Niemand stellte sie ein. Die App lief auf `.soloAmbient`, und jeder
     eigene Ton (Countdown-Ping, gesprochenes „Los!") riss die Sitzung an sich
     und stoppte die Musik des Nutzers.

  2. Danach stand sie dauerhaft auf `[.mixWithOthers, .duckOthers]` und wurde
     nie wieder deaktiviert. `.duckOthers` senkt fremde Wiedergabe aber nicht
     nur für die Dauer eines Tons, sondern so lange, wie die Sitzung aktiv ist.
     Die Sitzung wurde beim App-Start aktiviert — die Musik war damit während
     der ganzen Live-Session (und schon vorher) leiser. Genau das war die
     Beschwerde: „Live-Session gestartet, Musik wird leiser."

  Jetzt:

  - Grundzustand `.playback` mit nur `.mixWithOthers`: Die Musik läuft in
    voller Lautstärke weiter, der eigene Ton mischt sich dazu. Im Hintergrund
    spielt die App bewusst nichts — `UIBackgroundModes: audio` ist nicht
    deklariert (App Review, Richtlinie 2.5.4).
  - Nur für einen Ton (Countdown, Pausenende) wird kurz auf `.duckOthers`
    umgestellt: `beginCue`. Folgen Töne dicht aufeinander — der Countdown
    5…1 und danach das Pausenende —, bleibt die Musik so lange leiser und
    kommt etwa eine halbe Sekunde nach dem letzten Ton zurück.
  - Zurück auf volle Lautstärke geht es nur über Deaktivieren mit
    `.notifyOthersOnDeactivation`. Weil die Sitzung mischbar ist, unterbricht
    das die Musik nicht (anders als früher bei `.soloAmbient`) — es hebt nur
    das Absenken auf.
*/
public enum AudioSessionManager {

    private nonisolated(unsafe) static var isConfigured = false
    private nonisolated(unsafe) static var isDucking = false
    /// Jeder neue Ton bekommt eine Nummer; nur der letzte darf das Absenken beenden.
    private nonisolated(unsafe) static var cueGeneration = 0

    /// Grundzustand herstellen: mischen, nicht absenken. Einmal pro Programmlauf.
    public static func configureForWorkout() {
        guard !isConfigured else { return }
        apply(duck: false)
    }

    /// Erzwingt den Grundzustand erneut — nach einer Unterbrechung.
    public static func reapply() {
        isConfigured = false
        isDucking = false
        apply(duck: false)
    }

    /*
      Vor einem eigenen Ton aufrufen. Senkt fremde Musik für `duration`
      Sekunden (plus kurzen Nachlauf) ab; ein weiterer Ton in dieser Zeit
      verlängert das.
    */
    public static func beginCue(lasting duration: TimeInterval) {
        let work = {
            cueGeneration &+= 1
            let generation = cueGeneration
            if !isDucking {
                // Die Option greift erst beim Aktivieren — deshalb kurz ab- und wieder an.
                try? AVAudioSession.sharedInstance().setActive(false)
                apply(duck: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.45) {
                endDucking(generation: generation, attempt: 0)
            }
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private static func endDucking(generation: Int, attempt: Int) {
        guard generation == cueGeneration, isDucking else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ein Ton spielt noch („busy") — gleich noch einmal versuchen.
            guard attempt < 5 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                endDucking(generation: generation, attempt: attempt + 1)
            }
            return
        }
        apply(duck: false)
    }

    private static func apply(duck: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: duck ? [.mixWithOthers, .duckOthers] : [.mixWithOthers]
            )
            try session.setActive(true, options: [])
            isConfigured = true
            isDucking = duck
        } catch {
            /*
              Schlägt das fehl, bleibt es bei der Voreinstellung. Unschön, aber
              kein Grund, das Training abzubrechen — deshalb kein Weiterreichen.
            */
            isConfigured = false
            isDucking = false
        }
    }
}
