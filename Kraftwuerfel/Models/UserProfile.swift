import Foundation

/*
  Die Antworten des Nutzers — einmal beantwortet, überall verwendet.

  Vorher lagen dieselben Fragen zweimal im Formular: einmal im KI-Coach
  (AICoachSession) und einmal in der Home-Challenge (ChallengeSession).
  Geschlecht, Alter, Größe, Gewicht, Erfahrung, Ernährungsform und Equipment
  wurden bei jedem Aufruf erneut abgefragt, und die beiden Stände konnten
  auseinanderlaufen: Wer im Coach 82 kg eintrug, stand in der Challenge
  weiter mit 75 kg da.

  Jetzt gibt es genau einen Satz Antworten. Die beiden Sitzungen halten nur
  noch das Ergebnis — den erzeugten Plan — und lesen ihre Eingaben hier.

  Gesundheitsdaten (Art. 9 DSGVO): Geschlecht, Alter, Größe, Gewicht und
  Zielgewicht stehen hier drin. Das Profil muss deshalb bei einer
  Kontolöschung mit weg — siehe AuthService.wipeAllLocalData().
*/
public struct UserProfile: Codable, Equatable {

    // MARK: - Körper

    public var sex: String = "male"
    public var age: Int = 28
    public var heightCm: Double = 180
    public var weightKg: Double = 80
    /// Das Gewicht beim Anlegen des Ziels — der Fortschrittsbalken misst dagegen.
    public var startWeightKg: Double?
    /// `nil` heißt: kein Zielgewicht gesetzt. Die Ansicht zeigt dann das
    /// aktuelle Gewicht, ohne dass daraus schon ein Ziel wird.
    public var goalWeightKg: Double?
    public var somatotype: Somatotype = .mesomorph
    public var activityLevel: ActivityLevel = .moderatelyActive
    public var experience: ExperienceLevel = .intermediate

    // MARK: - Selbsteinschätzung

    public var pushupLevel: PushupLevel = .intermediate
    public var pullupLevel: PullupLevel = .beginner
    public var plankLevel: PlankLevel = .under60s

    // MARK: - Training (KI-Coach)

    public var goal: TrainingGoal = .muscle
    public var trainingLocation: TrainingLocation = .gym
    public var equipment: Set<EquipmentType> = []
    public var selectedDays: Set<String> = ["Mo", "Mi", "Fr"]
    public var durationMinutes: Int = 60
    public var restSeconds: Int = 60
    public var weeks: Int = 4
    public var method: TrainingMethod = .standard
    public var warmup: String = "auto"

    // MARK: - Home-Challenge

    /*
      Ob überhaupt eine Home-Challenge gewünscht ist.

      Vorher lief jeder durch die Challenge-Fragen, auch wer nur einen
      Studio-Plan wollte — vier Fragen zu einer Funktion, die er nie öffnet.
      Steht das hier auf `false`, entfallen sie im Fragebogen.
    */
    public var wantsChallenge: Bool = true

    /*
      Eigene Werte, keine geteilten: Eine Challenge ist kurz und zu Hause, ein
      Studio-Plan lang und mit Gerät. Dieselbe Einheitsdauer für beide wäre
      für eine der zwei Seiten immer falsch.
    */
    public var challengeGoal: ChallengeGoal = .getFit
    public var challengeDurationDays: Int = 30
    public var challengeDaysPerWeek: Int = 5
    public var challengeSessionMinutes: Int = 15
    public var challengeEquipment: Set<EquipmentType> = [.bodyweight]

    // MARK: - Ernährung & Einschränkungen

    public var diet: DietType = .omnivore
    /*
      Ob überhaupt Shakes getrunken werden.

      Steuert allein die Erinnerung nach dem Training. Wer keine Shakes nimmt,
      bekam bisher trotzdem eine halbe Stunde nach jeder Einheit die Meldung
      „Zeit für deinen Shake“ — eine Erinnerung an etwas, das gar nicht
      vorkommt, und der schnellste Weg, Mitteilungen ganz abzuschalten.

      Standard ist `false`: Lieber keine Erinnerung als eine unpassende.
    */
    public var usesProteinShakes: Bool = false
    /// Freitext, geht als `limitations` in den Prompt. Der Server kürzt bei 500.
    public var limitations: String = ""

    // MARK: - Stand des Fragebogens

    /// Wurde der Fragebogen einmal bis zum Ende durchlaufen?
    public var isComplete: Bool = false
    /// Wurde er dem Nutzer schon einmal gezeigt? Wer abbricht, soll nicht bei
    /// jedem Start erneut damit begrüßt werden — gefragt wird dann erst
    /// wieder dort, wo die Antworten wirklich gebraucht werden.
    public var hasSeenOnboarding: Bool = false

    public init() {}

    // MARK: - Abgeleitetes

    public var biometrics: UserBiometrics {
        UserBiometrics(
            sex: sex,
            age: age,
            heightCm: heightCm,
            weightKg: weightKg,
            somatotype: somatotype,
            activityLevel: activityLevel
        )
    }

    /// Das Equipment, das an diesem Ort überhaupt zur Verfügung steht.
    public static func allowedEquipment(for location: TrainingLocation) -> Set<EquipmentType> {
        switch location {
        case .gym, .hybrid:
            return Set(EquipmentType.allCases)
        case .homeBodyweight:
            return [.bodyweight, .dumbbell, .kettlebell, .weightPlate]
        case .outdoorPark:
            return [.bodyweight]
        }
    }

    /*
      Nach einem Ortswechsel kann Equipment stehen bleiben, das es dort nicht
      gibt — eine Multipresse im Park. Leer heißt „alles Erlaubte“, nicht
      „nichts“: Ein leerer Filter lässt den Server auf den vollen Katalog
      zurückfallen, und das ist für einen Home-Plan die falsche Antwort.
    */
    public mutating func normalizeEquipmentForLocation() {
        let allowed = Self.allowedEquipment(for: trainingLocation)
        if equipment.isEmpty {
            equipment = allowed
        } else {
            equipment = equipment.intersection(allowed)
            if equipment.isEmpty { equipment = [.bodyweight] }
        }
    }

    /// Die Wochentage der Challenge — gleiche Verteilung wie im Server.
    public var challengeDays: [String] {
        switch challengeDaysPerWeek {
        case ...2: return ["Mo", "Do"]
        case 3:    return ["Mo", "Mi", "Fr"]
        case 4:    return ["Mo", "Di", "Do", "Fr"]
        case 5:    return ["Mo", "Di", "Mi", "Do", "Fr"]
        case 6:    return ["Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        default:   return Weekdays.all
        }
    }

    /*
      Die Challenge fragt den Aktivitätsgrad nicht ab — er ergibt sich aus der
      Trainingsfrequenz. Für den Ernährungsteil der Challenge zählt der, nicht
      der im Profil hinterlegte Studio-Wert.
    */
    public var challengeActivityLevel: ActivityLevel {
        switch challengeDaysPerWeek {
        case ...3: return .lightlyActive
        case 4, 5: return .moderatelyActive
        default:   return .veryActive
        }
    }

    public var goalWeightDeltaText: String? {
        guard let target = goalWeightKg else { return nil }
        let delta = target - weightKg
        guard abs(delta) >= 1 else { return nil }
        return String(format: "%+.0f kg", delta)
    }
}
