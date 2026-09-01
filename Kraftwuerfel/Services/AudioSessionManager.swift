import AVFoundation
import Foundation

/*
  Die Audiositzung der App — eine Stelle, an der sie eingestellt wird.

  Bisher stellte sie niemand ein. Damit lief die App auf der Voreinstellung
  `.soloAmbient`, und die heißt wörtlich: allein. Jedes Mal, wenn die App
  Ton ausgab — der Countdown-Ping in den letzten fünf Sekunden, vor allem
  aber das gesprochene „Los!" am Pausenende — riss sie die Sitzung an sich
  und legte danach wieder auf. Die Musik, die der Nutzer sich für sein
  Training angemacht hatte, war damit gestoppt. Ausgerechnet in dem Moment,
  in dem er wieder loslegen sollte.

  Zwei Einstellungen beheben das:

  - `.playback` statt `.soloAmbient`: Ton auch bei stummgeschaltetem
    Klingelton und im Hintergrund. Die App hat `UIBackgroundModes: audio`
    deklariert, konnte das mangels passender Kategorie aber nie einlösen.
  - `.duckOthers` zusammen mit `.mixWithOthers`: Der eigene Ton mischt sich
    dazu, statt zu verdrängen. Die Musik wird für den Ping und das „Los!"
    kurz leiser und läuft danach weiter.

  Und: Die Sitzung wird nie wieder deaktiviert. Genau das Deaktivieren nach
  dem Sprechen war der Moment, in dem die Musik ausging.
*/
public enum AudioSessionManager {

    /// Einmal pro Programmlauf. Ein zweiter Aufruf schadet nicht, kostet aber
    /// einen Systemaufruf — deshalb der Merker.
    private nonisolated(unsafe) static var isConfigured = false

    /*
      Wird beim Start gesetzt und vor jeder Tonausgabe noch einmal
      sichergestellt: Andere Teile des Systems (ein Anruf, eine andere App)
      können die Sitzung zwischendurch verändert haben.
    */
    public static func configureForWorkout() {
        guard !isConfigured else { return }
        apply()
    }

    /// Erzwingt die Einstellung erneut — nach einer Unterbrechung.
    public static func reapply() {
        isConfigured = false
        apply()
    }

    private static func apply() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try session.setActive(true, options: [])
            isConfigured = true
        } catch {
            /*
              Schlägt das fehl, bleibt es bei der Voreinstellung: Der
              Countdown klingt, die Musik stoppt. Unschön, aber kein Grund,
              das Training abzubrechen — deshalb kein Weiterreichen des
              Fehlers.
            */
            isConfigured = false
        }
    }
}
