import Combine
import Foundation
import SwiftUI

/*
  Der eine Ort, an dem die Antworten des Nutzers liegen.

  Die beiden Sitzungen (AICoachSession, ChallengeSession) greifen hier zu,
  statt eigene Kopien zu halten. Wer im Coach sein Gewicht ändert, ändert es
  damit auch für die Challenge — vorher waren das zwei Zahlen, die sich
  gegenseitig nicht kannten.

  Geschrieben wird nach jeder Änderung, wie bei den Sitzungen zuvor. Das ist
  eine kleine Struktur; ein Umweg über eine Warteschlange wäre hier mehr
  Maschinerie als Nutzen.
*/
public final class UserProfileStore: ObservableObject {

    public static let shared = UserProfileStore()

    private static let storageKey = "kraftwuerfel:userProfile"

    @Published public private(set) var profile: UserProfile

    private init() {
        profile = Self.loadFromDefaults() ?? Self.migrateFromLegacySessions() ?? UserProfile()
    }

    // MARK: - Ändern

    /*
      Jede Änderung läuft hier durch. Der Block bekommt eine veränderbare
      Kopie; erst danach wird veröffentlicht und geschrieben. So löst eine
      Änderung an fünf Feldern auch nur einen Neuzeichnungslauf aus.
    */
    public func update(_ change: (inout UserProfile) -> Void) {
        var next = profile
        change(&next)
        guard next != profile else { return }
        profile = next
        persist()
    }

    /*
      Eine Bindung auf ein einzelnes Feld, damit Formulare wie gewohnt mit
      `$` arbeiten können, ohne dass das Profil dafür veränderbar
      herumgereicht werden muss. Geschrieben wird weiterhin nur über
      `update`, also an genau einer Stelle.
    */
    public func binding<Value>(_ keyPath: WritableKeyPath<UserProfile, Value>) -> Binding<Value> {
        Binding(
            get: { self.profile[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    /// Den Fragebogen als beantwortet markieren — Ende des Onboardings.
    public func markComplete() {
        update {
            $0.isComplete = true
            $0.hasSeenOnboarding = true
            // Ohne Startgewicht hat der Fortschrittsbalken keinen Nullpunkt.
            if $0.startWeightKg == nil { $0.startWeightKg = $0.weightKg }
        }
    }

    /// Der Nutzer hat den Fragebogen weggetippt. Nicht wieder von selbst
    /// aufmachen — gefragt wird erst dort, wo die Antworten gebraucht werden.
    public func markOnboardingSeen() {
        update { $0.hasSeenOnboarding = true }
    }

    /*
      Für die Kontolöschung. Alles zurück auf Werkseinstellung, und die Datei
      weg: Geschlecht, Alter, Größe und Gewicht sind Gesundheitsdaten und
      dürfen eine Löschung nicht überleben.
    */
    public func wipe() {
        profile = UserProfile()
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Speichern

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadFromDefaults() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        /*
          Nicht löschen bei einem Formatwechsel. Die Antworten bleiben in
          dieser Sitzung auf Standard, die rohen Bytes bleiben liegen — so wie
          CodableListStore es mit den Listen hält.
        */
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    // MARK: - Übernahme aus den alten Fragebögen

    /*
      Wer die App vor dieser Änderung benutzt hat, hat seine Antworten in den
      beiden Sitzungsständen liegen. Die einfach zu verwerfen hieße: einmal
      alles noch mal eintippen, obwohl es schon dasteht.

      Gelesen wird nur; die alten Schlüssel bleiben stehen. Die Sitzungen
      holen sich daraus weiterhin ihren erzeugten Plan, und ein Decoder
      überliest Felder, die er nicht kennt.
    */
    private static func migrateFromLegacySessions() -> UserProfile? {
        let coach = legacyCoach()
        let challenge = legacyChallenge()
        guard coach != nil || challenge != nil else { return nil }

        var p = UserProfile()

        if let c = coach {
            p.sex = c.sex ?? p.sex
            p.age = c.age ?? p.age
            p.heightCm = c.heightCm ?? p.heightCm
            p.weightKg = c.weightKg ?? p.weightKg
            p.startWeightKg = c.startWeightKg
            p.goalWeightKg = c.goalWeightKg
            p.somatotype = c.somatotype ?? p.somatotype
            p.activityLevel = c.activityLevel ?? p.activityLevel
            p.experience = c.experience ?? p.experience
            p.pushupLevel = c.pushupLevel ?? p.pushupLevel
            p.pullupLevel = c.pullupLevel ?? p.pullupLevel
            p.plankLevel = c.plankLevel ?? p.plankLevel
            p.goal = c.goal ?? p.goal
            p.trainingLocation = c.trainingLocation ?? p.trainingLocation
            p.equipment = Set(c.selectedEquipment ?? [])
            p.selectedDays = Set(c.selectedDays ?? Array(p.selectedDays))
            p.durationMinutes = c.durationMinutes ?? p.durationMinutes
            p.weeks = c.weeks ?? p.weeks
            p.method = c.method ?? p.method
            p.warmup = c.warmup ?? p.warmup
            p.diet = c.diet ?? p.diet
        }

        if let ch = challenge {
            p.challengeGoal = ch.goal ?? p.challengeGoal
            p.challengeDurationDays = ch.durationDays ?? p.challengeDurationDays
            p.challengeDaysPerWeek = ch.daysPerWeek ?? p.challengeDaysPerWeek
            p.challengeSessionMinutes = ch.sessionMinutes ?? p.challengeSessionMinutes
            let eq = Set(ch.equipment ?? [])
            p.challengeEquipment = eq.isEmpty ? [.bodyweight] : eq
            p.limitations = ch.limitations ?? p.limitations
            // Der Coach hat keine Körperdaten hinterlassen? Dann die der Challenge.
            if coach == nil {
                p.sex = ch.sex ?? p.sex
                p.age = ch.age ?? p.age
                p.heightCm = ch.heightCm ?? p.heightCm
                p.weightKg = ch.weightKg ?? p.weightKg
                p.goalWeightKg = ch.goalWeightKg
                p.experience = ch.experience ?? p.experience
                p.diet = ch.diet ?? p.diet
            }
        }

        /*
          Übernommen heißt nicht beantwortet. Der alte Stand kann aus einem
          abgebrochenen Formular stammen und nur Standardwerte enthalten —
          den Fragebogen deshalb trotzdem einmal anbieten.
        */
        p.isComplete = false
        return p
    }

    /// Nur die Felder, die für die Übernahme zählen — alles Weitere überliest der Decoder.
    private struct LegacyCoach: Decodable {
        var goal: TrainingGoal?
        var experience: ExperienceLevel?
        var sex: String?
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
        var somatotype: Somatotype?
        var activityLevel: ActivityLevel?
        var pushupLevel: PushupLevel?
        var pullupLevel: PullupLevel?
        var plankLevel: PlankLevel?
        var trainingLocation: TrainingLocation?
        var startWeightKg: Double?
        var goalWeightKg: Double?
        var method: TrainingMethod?
        var selectedDays: [String]?
        var durationMinutes: Int?
        var weeks: Int?
        var selectedEquipment: [EquipmentType]?
        var diet: DietType?
        var warmup: String?
    }

    private struct LegacyChallenge: Decodable {
        var goal: ChallengeGoal?
        var experience: ExperienceLevel?
        var sex: String?
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
        var goalWeightKg: Double?
        var durationDays: Int?
        var daysPerWeek: Int?
        var sessionMinutes: Int?
        var equipment: [EquipmentType]?
        var diet: DietType?
        var limitations: String?
    }

    private static func legacyCoach() -> LegacyCoach? {
        guard let data = UserDefaults.standard.data(forKey: "kraftwuerfel:aiCoachSession") else { return nil }
        return try? JSONDecoder().decode(LegacyCoach.self, from: data)
    }

    private static func legacyChallenge() -> LegacyChallenge? {
        guard let data = UserDefaults.standard.data(forKey: "kraftwuerfel:challengeSession") else { return nil }
        return try? JSONDecoder().decode(LegacyChallenge.self, from: data)
    }
}
