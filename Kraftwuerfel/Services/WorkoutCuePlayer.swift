import AVFoundation
import Foundation

/*
  Die Töne der Live-Session: Countdown-Ticks und das Signal am Pausenende.

  Warum das nicht mehr über AudioServicesPlaySystemSound läuft:

  Systemtöne gehen an der Audiositzung der App vorbei. Sie werden von der
  Systemsitzung ausgegeben, und deshalb greift `.duckOthers` bei ihnen nicht —
  die Musik des Nutzers lief unverändert laut weiter, während der Ton darin
  unterging. Genau das war die Beschwerde: Das Pausenende war nicht zu hören.

  Ein AVAudioPlayer spielt dagegen auf der Sitzung der App. Weil die auf
  `.playback` mit `[.mixWithOthers, .duckOthers]` steht (AudioSessionManager),
  senkt iOS die Lautstärke der Musik für die Dauer der Wiedergabe von selbst ab
  und hebt sie danach wieder an. Ohne Eingriff in fremde Wiedergabe, ohne die
  Sitzung zu deaktivieren — und Deaktivieren war der Grund, aus dem die Musik
  früher ganz ausging.

  Die Töne stehen nicht als Dateien im Bündel, sondern werden einmalig gerechnet.
  Ein Sinus mit weicher Hüllkurve ist ein paar Zeilen Code; als Datei wären es
  drei Dateien mehr im Ziel, die jemand pflegen müsste.
*/
public final class WorkoutCuePlayer {

    public static let shared = WorkoutCuePlayer()

    /// Fertige Spieler, nach Kennung abgelegt. Ein Spieler muss die Wiedergabe
    /// überleben — eine lokale Variable wäre vor dem letzten Ton freigegeben.
    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "kraftwuerfel.cues")

    private init() {}

    // MARK: - Öffentliche Signale

    /// Ein Schritt des Countdowns. Die letzte Sekunde klingt heller, damit man
    /// das Ende auch ohne Mitzählen hört.
    public func playTick(isFinal: Bool) {
        play(id: isFinal ? "tick_final" : "tick",
             frequency: isFinal ? 1_046.5 : 880,
             duration: 0.09,
             volume: isFinal ? 1.0 : 0.85)
    }

    /*
      Das Pausenende: drei aufsteigende Töne.

      Aufsteigend und nicht dreimal derselbe Ton, weil ein Dreiklang auch dann
      als „jetzt" gelesen wird, wenn man die ersten beiden Töne verpasst hat.
    */
    public func playRestFinished() {
        play(id: "go1", frequency: 659.3, duration: 0.13, volume: 1.0)
        queue.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            self?.play(id: "go2", frequency: 880, duration: 0.13, volume: 1.0)
        }
        queue.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            self?.play(id: "go3", frequency: 1_174.7, duration: 0.24, volume: 1.0)
        }
    }

    /// Vorbereiten, solange nichts drängt. Der erste Ton eines frisch gebauten
    /// Spielers setzt sonst mit hörbarer Verzögerung ein — mitten im Countdown
    /// wäre das genau der Fehler, der behoben werden soll.
    public func prepare() {
        AudioSessionManager.configureForWorkout()
        queue.async { [weak self] in
            guard let self else { return }
            _ = self.player(id: "tick", frequency: 880, duration: 0.09)
            _ = self.player(id: "tick_final", frequency: 1_046.5, duration: 0.09)
            _ = self.player(id: "go1", frequency: 659.3, duration: 0.13)
            _ = self.player(id: "go2", frequency: 880, duration: 0.13)
            _ = self.player(id: "go3", frequency: 1_174.7, duration: 0.24)
        }
    }

    // MARK: - Wiedergabe

    private func play(id: String, frequency: Double, duration: Double, volume: Float) {
        AudioSessionManager.configureForWorkout()
        queue.async { [weak self] in
            guard let self,
                  let player = self.player(id: id, frequency: frequency, duration: duration)
            else { return }
            player.volume = volume
            player.currentTime = 0
            player.play()
        }
    }

    private func player(id: String, frequency: Double, duration: Double) -> AVAudioPlayer? {
        if let existing = players[id] { return existing }
        guard let data = Self.toneWAV(frequency: frequency, duration: duration),
              let player = try? AVAudioPlayer(data: data)
        else { return nil }
        player.prepareToPlay()
        players[id] = player
        return player
    }

    // MARK: - Tonerzeugung

    private static let sampleRate = 44_100.0

    /*
      Ein Sinuston als WAV im Speicher.

      Die Hüllkurve ist der Grund, warum hier überhaupt gerechnet wird: Ein hart
      ein- und ausgeschalteter Sinus knackt an beiden Enden, und ein Knacken
      klingt nach Fehler, nicht nach Signal. Fünf Millisekunden Anstieg und ein
      Ausklang über den Rest nehmen das weg.
    */
    private static func toneWAV(frequency: Double, duration: Double) -> Data? {
        let frameCount = Int(sampleRate * duration)
        guard frameCount > 0 else { return nil }

        let attack = Int(sampleRate * 0.005)
        var samples = [Int16]()
        samples.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope: Double
            if i < attack {
                envelope = Double(i) / Double(attack)
            } else {
                let rest = Double(frameCount - i) / Double(max(1, frameCount - attack))
                envelope = rest * rest
            }
            let value = sin(2 * .pi * frequency * t) * envelope * 0.9
            samples.append(Int16(max(-1, min(1, value)) * Double(Int16.max)))
        }

        return wavContainer(for: samples)
    }

    /// 16-Bit-Mono-WAV — der kleinste Kopf, den AVAudioPlayer akzeptiert.
    private static func wavContainer(for samples: [Int16]) -> Data {
        let bytesPerSample = 2
        let dataBytes = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataBytes)

        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataBytes))
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                                   // Länge des Formatblocks
        append(UInt16(1))                                    // PCM, unkomprimiert
        append(UInt16(1))                                    // Mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * UInt32(bytesPerSample))   // Bytes pro Sekunde
        append(UInt16(bytesPerSample))                       // Blockausrichtung
        append(UInt16(16))                                   // Bits je Wert

        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataBytes))
        for sample in samples { append(sample) }

        return data
    }
}
