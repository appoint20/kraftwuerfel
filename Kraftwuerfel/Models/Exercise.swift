import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum MuscleCategory: String, Codable, CaseIterable, Identifiable {
    case chest = "Brust"
    case back = "Rücken"
    case neck = "Nacken"
    case shoulders = "Schultern"
    case biceps = "Bizeps"
    case triceps = "Trizeps"
    case legs = "Beine"
    case glutes = "Gesäß"
    case calves = "Waden"
    case core = "Bauch"
    case fullBody = "Ganzkörper"

    public var id: String { rawValue }

    /// Deutsch ist der rawValue — genau die Schreibweise aus data/exercises.js.
    public var localizedDe: String { rawValue }

    public var localizedEn: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .neck: return "Neck"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? localizedEn : localizedDe
    }
}

public enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case barbell = "Langhantel"
    case dumbbell = "Kurzhantel"
    case machine = "Maschine"
    case cable = "Kabelzug"
    case bodyweight = "Körpergewicht"
    case smithMachine = "Multipresse"
    case weightPlate = "Gewichtsscheibe"
    case kettlebell = "Kettlebell"

    public var id: String { rawValue }

    public var localizedDe: String { rawValue }

    public var localizedEn: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .smithMachine: return "Smith Machine"
        case .weightPlate: return "Weight Plate"
        case .kettlebell: return "Kettlebell"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? localizedEn : localizedDe
    }
}

public struct Exercise: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let nameEn: String
    /// Anzeige-Kategorie (die erste) — entspricht `category` im Web.
    public let category: MuscleCategory
    /*
      Für die Auswahl zählt `categories`, nicht `category`: Hip Thrust gehört
      zu Gesäß, Beinen und Rücken und muss deshalb in allen drei Splits
      auftauchen können. Im Web macht das die MULTI_CATEGORY-Tabelle.
    */
    public let categories: [MuscleCategory]
    public let equipment: EquipmentType
    public let isHeavy: Bool

    public init(
        name: String,
        nameEn: String,
        category: MuscleCategory,
        equipment: EquipmentType,
        isHeavy: Bool = false,
        categories: [MuscleCategory]? = nil
    ) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        self.name = name
        self.nameEn = nameEn
        self.category = category
        self.categories = categories ?? [category]
        self.equipment = equipment
        self.isHeavy = isHeavy
    }

    public func localizedName(language: String) -> String {
        language == "en" ? nameEn : name
    }

    /*
      Der Name des Bildes im Asset-Katalog, aus `nameEn` abgeleitet.

      Die Regel: englischer Name, klein geschrieben, `/` und `-` werden zu
      Leerzeichen, Klammern fallen weg, Leerzeichen werden zu `_`, davor `ex_`.
      „Pull-Ups" wird so zu `ex_pull_ups`, „Low-to-High Cable Flyes" zu
      `ex_low_to_high_cable_flyes`.

      Damit braucht eine neue Übungsabbildung keine Codeänderung: Ein Bildsatz
      mit dem passenden Namen im Katalog genügt, `hasCustomImage` findet ihn von
      selbst. Fehlt er, zeichnet ExerciseVisual die anatomische Figur.
    */
    public var imageAssetKey: String {
        /*
          Apostrophe fallen weg, jedes andere Sonderzeichen trennt.

          Die Liste einzelner `replacingOccurrences` lief der Wirklichkeit
          hinterher: `/`, `-`, Klammern, dann `°`, dann `'` — und „Angel & Devil
          Floor Raises" ergab weiterhin `ex_angel_&_devil_floor_raises`. So
          heißt kein Bildsatz im Asset-Katalog, das Bild wurde also nie
          gefunden. Auffallen konnte das niemandem: Fehlt das Bild, zeichnet
          ExerciseVisual stillschweigend die anatomische Figur.

          Der Apostroph ist die Ausnahme und muss verschwinden statt zu trennen
          — „Farmer's Walk" soll `ex_farmers_walk` ergeben, nicht
          `ex_farmer_s_walk`.
        */
        let withoutApostrophes = nameEn.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")

        let separated = withoutApostrophes.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }

        let clean = String(separated)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return "ex_" + clean
    }

    public var hasCustomImage: Bool {
        #if canImport(UIKit)
        return UIImage(named: imageAssetKey) != nil
        #else
        return false
        #endif
    }
}

public enum ExerciseDatabase {
    /*
      Der gebündelte Katalog: 1:1 aus src/data/exercises.js erzeugt.

      Er ist die Rückfallebene. Beim Start holt `refreshFromAPI()` die Liste von
      /exercises — so kommen neue Übungen ohne App-Update an. Schlägt das fehl
      (kein Netz, Dienst schläft), bleibt genau diese Liste stehen und die App
      funktioniert unverändert weiter.
    */
    public static let bundled: [Exercise] = [
        Exercise(name: "Bankdrücken", nameEn: "Barbell Bench Press", category: .chest, equipment: .barbell, isHeavy: true),
        Exercise(name: "Schrägbankdrücken", nameEn: "Incline Barbell Bench Press", category: .chest, equipment: .barbell, isHeavy: true),
        Exercise(name: "Negativbankdrücken", nameEn: "Decline Barbell Bench Press", category: .chest, equipment: .barbell),
        Exercise(name: "Kurzhantel-Bankdrücken", nameEn: "Dumbbell Bench Press", category: .chest, equipment: .dumbbell),
        Exercise(name: "Kurzhantel-Schrägbankdrücken", nameEn: "Incline Dumbbell Press", category: .chest, equipment: .dumbbell),
        Exercise(name: "Fliegende Kurzhantel (Schrägbank)", nameEn: "Incline Dumbbell Flyes", category: .chest, equipment: .dumbbell),
        Exercise(name: "Butterfly", nameEn: "Pec Deck Machine Fly", category: .chest, equipment: .machine),
        Exercise(name: "Cable Crossover", nameEn: "Cable Crossover", category: .chest, equipment: .cable),
        Exercise(name: "Dips (Brustfokus)", nameEn: "Chest Dips", category: .chest, equipment: .bodyweight),
        Exercise(name: "Liegestütze", nameEn: "Push-Ups", category: .chest, equipment: .bodyweight),
        Exercise(name: "Pec-Deck", nameEn: "Pec Deck Machine", category: .chest, equipment: .machine),
        Exercise(name: "Negativbankdrücken (Kurzhantel)", nameEn: "Decline Dumbbell Press", category: .chest, equipment: .dumbbell),
        Exercise(name: "Kabel-Butterfly liegend (Bank)", nameEn: "Lying Cable Flyes", category: .chest, equipment: .cable),
        Exercise(name: "Kabel-Butterfly stehend", nameEn: "Standing Cable Flyes", category: .chest, equipment: .cable),
        Exercise(name: "Kabel-Low-Fly stehend", nameEn: "Low-to-High Cable Flyes", category: .chest, equipment: .cable),
        Exercise(name: "Brustpresse (Maschine)", nameEn: "Chest Press Machine", category: .chest, equipment: .machine),
        Exercise(name: "Schrägbankdrücken (Maschine)", nameEn: "Incline Chest Press Machine", category: .chest, equipment: .machine),
        Exercise(name: "Kurzhantel-Bankdrücken (Neutralgriff)", nameEn: "Neutral-Grip Dumbbell Press", category: .chest, equipment: .dumbbell),
        Exercise(name: "Kurzhantel-Bankdrücken (Untergriff)", nameEn: "Underhand Dumbbell Press", category: .chest, equipment: .dumbbell),
        Exercise(name: "Schrägbankdrücken (Multipresse)", nameEn: "Smith Machine Incline Press", category: .chest, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Bankdrücken (Multipresse)", nameEn: "Smith Machine Bench Press", category: .chest, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Klimmzüge", nameEn: "Pull-Ups", category: .back, equipment: .bodyweight, isHeavy: true),
        Exercise(name: "Latzug breit", nameEn: "Wide-Grip Lat Pulldown", category: .back, equipment: .cable, isHeavy: true),
        Exercise(name: "Latzug eng (Untergriff)", nameEn: "Close-Grip Underhand Pulldown", category: .back, equipment: .cable),
        Exercise(name: "Langhantelrudern vorgebeugt", nameEn: "Bent-Over Barbell Row", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Kurzhantelrudern einarmig", nameEn: "One-Arm Dumbbell Row", category: .back, equipment: .dumbbell),
        Exercise(name: "T-Bar Rudern", nameEn: "T-Bar Row", category: .back, equipment: .barbell),
        Exercise(name: "Kabelrudern sitzend", nameEn: "Seated Cable Row", category: .back, equipment: .cable),
        Exercise(name: "Kreuzheben", nameEn: "Barbell Deadlift", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Rumänisches Kreuzheben", nameEn: "Romanian Deadlift", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Good Mornings", nameEn: "Good Mornings", category: .back, equipment: .barbell),
        Exercise(name: "Hyperextensions", nameEn: "Back Hyperextensions", category: .back, equipment: .bodyweight),
        Exercise(name: "Pull-Over", nameEn: "Dumbbell Pullover", category: .back, equipment: .dumbbell),
        Exercise(name: "Nackenheben (Shrugs, Langhantel)", nameEn: "Barbell Shrugs", category: .back, equipment: .barbell),
        Exercise(name: "Shrugs (Kurzhantel)", nameEn: "Dumbbell Shrugs", category: .back, equipment: .dumbbell),
        Exercise(name: "Langhantelrudern vorgebeugt (Untergriff)", nameEn: "Reverse-Grip Barbell Row", category: .back, equipment: .barbell),
        Exercise(name: "Einarmiges Rudern (Maschine, sitzend)", nameEn: "Single-Arm Machine Row", category: .back, equipment: .machine),
        Exercise(name: "Kreuzheben (Maschine)", nameEn: "Deadlift Machine", category: .back, equipment: .machine, isHeavy: true),
        Exercise(name: "Kreuzheben (Multipresse)", nameEn: "Smith Machine Deadlift", category: .back, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Trapezmaschine", nameEn: "Trap / Shrug Machine", category: .back, equipment: .machine),
        Exercise(name: "Überzüge (Maschine)", nameEn: "Pullover Machine", category: .back, equipment: .machine),
        Exercise(name: "Einarmiges Ziehen (Maschine)", nameEn: "Single-Arm Machine Pulldown", category: .back, equipment: .machine),
        Exercise(name: "Angel & Devil", nameEn: "Angel & Devil Floor Raises", category: .back, equipment: .bodyweight),
        Exercise(name: "T-Bar Rudern (Maschine)", nameEn: "Chest-Supported T-Bar Row", category: .back, equipment: .machine),
        Exercise(name: "Kreuzheben (Hexbar)", nameEn: "Hex Bar / Trap Bar Deadlift", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Vorgebeugtes Rudern (Langhantel, Obergriff)", nameEn: "Overhand Barbell Row", category: .back, equipment: .barbell, isHeavy: true),
        Exercise(name: "Nackenheben / Shrugs (Multipresse)", nameEn: "Smith Machine Shrugs", category: .neck, equipment: .smithMachine),
        Exercise(name: "Nackenheben / Shrugs (Maschine)", nameEn: "Machine Shrugs", category: .neck, equipment: .machine),
        Exercise(name: "Nackenheben / Shrugs (Kabelzug)", nameEn: "Cable Shrugs", category: .neck, equipment: .cable),
        Exercise(name: "Nackenheben / Shrugs (Kurzhantel)", nameEn: "Dumbbell Shrugs", category: .neck, equipment: .dumbbell),
        Exercise(name: "Frontheben mit Gewichtsscheibe", nameEn: "Weight Plate Front Raise", category: .neck, equipment: .weightPlate),
        Exercise(name: "Schulterdrücken (Langhantel)", nameEn: "Overhead Barbell Press", category: .shoulders, equipment: .barbell, isHeavy: true),
        Exercise(name: "Schulterdrücken (Kurzhantel, sitzend)", nameEn: "Seated Dumbbell Shoulder Press", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Seitheben (Kurzhantel)", nameEn: "Dumbbell Lateral Raises", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Frontheben", nameEn: "Dumbbell Front Raises", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Reverse Butterfly", nameEn: "Reverse Pec Deck Fly", category: .shoulders, equipment: .machine),
        Exercise(name: "Face Pulls", nameEn: "Rope Face Pulls", category: .shoulders, equipment: .cable),
        Exercise(name: "Arnold Press", nameEn: "Arnold Press", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Aufrechtes Rudern", nameEn: "Upright Barbell Row", category: .shoulders, equipment: .barbell),
        Exercise(name: "Schulterdrücken (Maschine)", nameEn: "Shoulder Press Machine", category: .shoulders, equipment: .machine),
        Exercise(name: "Kabel-Seitheben", nameEn: "Cable Lateral Raises", category: .shoulders, equipment: .cable),
        Exercise(name: "Seitheben angelehnt an Bank (Kurzhantel)", nameEn: "Incline Bench Lateral Raise", category: .shoulders, equipment: .dumbbell),
        Exercise(name: "Schulterdrücken (Multipresse)", nameEn: "Smith Machine Shoulder Press", category: .shoulders, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Kabelzug hintere Schulter", nameEn: "Rear Delt Cable Cross", category: .shoulders, equipment: .cable),
        Exercise(name: "Seitheben (Maschine)", nameEn: "Lateral Raise Machine", category: .shoulders, equipment: .machine),
        Exercise(name: "Langhantel-Bizepscurls", nameEn: "Barbell Bicep Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "SZ-Stangen-Curls", nameEn: "EZ-Bar Bicep Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "Kurzhantel-Curls", nameEn: "Dumbbell Bicep Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Hammer-Curls", nameEn: "Hammer Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Konzentrationscurls", nameEn: "Concentration Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Scott-Curls (Predigerbank)", nameEn: "Preacher Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "Kabel-Bizepscurls", nameEn: "Cable Bicep Curls", category: .biceps, equipment: .cable),
        Exercise(name: "21er Curls", nameEn: "21s Bicep Curls", category: .biceps, equipment: .barbell),
        Exercise(name: "Über-Kreuz-Hammercurls", nameEn: "Cross-Body Hammer Curls", category: .biceps, equipment: .dumbbell),
        Exercise(name: "Bizepscurls (Multipresse)", nameEn: "Smith Machine Curls", category: .biceps, equipment: .smithMachine),
        Exercise(name: "Einarmige Bizepscurls (Kabel)", nameEn: "Single-Arm Cable Curls", category: .biceps, equipment: .cable),
        Exercise(name: "Bizeps-Maschine", nameEn: "Bicep Curl Machine", category: .biceps, equipment: .machine),
        Exercise(name: "Trizepsdrücken am Kabel (Seil)", nameEn: "Tricep Rope Pushdown", category: .triceps, equipment: .cable),
        Exercise(name: "Trizepsdrücken am Kabel (Stange)", nameEn: "Straight-Bar Tricep Pushdown", category: .triceps, equipment: .cable),
        Exercise(name: "Enges Bankdrücken", nameEn: "Close-Grip Bench Press", category: .triceps, equipment: .barbell),
        Exercise(name: "Dips (Trizepsfokus)", nameEn: "Tricep Dips", category: .triceps, equipment: .bodyweight),
        Exercise(name: "French Press", nameEn: "Skull Crushers / French Press", category: .triceps, equipment: .barbell),
        Exercise(name: "Kickbacks", nameEn: "Dumbbell Tricep Kickbacks", category: .triceps, equipment: .dumbbell),
        Exercise(name: "Overhead-Trizepsdrücken", nameEn: "Overhead Tricep Extension", category: .triceps, equipment: .dumbbell),
        Exercise(name: "Trizeps-Maschine", nameEn: "Tricep Extension Machine", category: .triceps, equipment: .machine),
        Exercise(name: "Enges Bankdrücken (Multipresse, V-Griff)", nameEn: "Smith Machine Close-Grip Press", category: .triceps, equipment: .smithMachine),
        Exercise(name: "Kniebeugen", nameEn: "Barbell Back Squats", category: .legs, equipment: .barbell, isHeavy: true),
        Exercise(name: "Frontkniebeugen", nameEn: "Barbell Front Squats", category: .legs, equipment: .barbell, isHeavy: true),
        Exercise(name: "Beinpresse", nameEn: "45° Leg Press", category: .legs, equipment: .machine, isHeavy: true),
        Exercise(name: "Ausfallschritte", nameEn: "Walking Dumbbell Lunges", category: .legs, equipment: .dumbbell),
        Exercise(name: "Bulgarian Split Squats", nameEn: "Bulgarian Split Squats", category: .legs, equipment: .dumbbell),
        Exercise(name: "Beinstrecker", nameEn: "Leg Extension Machine", category: .legs, equipment: .machine),
        Exercise(name: "Beinbeuger liegend", nameEn: "Lying Leg Curl", category: .legs, equipment: .machine),
        Exercise(name: "Beinbeuger sitzend", nameEn: "Seated Leg Curl", category: .legs, equipment: .machine),
        Exercise(name: "Hack Squat", nameEn: "Hack Squat Machine", category: .legs, equipment: .machine, isHeavy: true),
        Exercise(name: "Goblet Squats", nameEn: "Goblet Squats", category: .legs, equipment: .dumbbell),
        Exercise(name: "Step-Ups", nameEn: "Dumbbell Step-Ups", category: .legs, equipment: .dumbbell),
        Exercise(name: "Sumo-Kniebeugen", nameEn: "Sumo Squats", category: .legs, equipment: .barbell, isHeavy: true),
        Exercise(name: "Innenschenkel-Maschine (Adduktion)", nameEn: "Adductor Machine", category: .legs, equipment: .machine),
        Exercise(name: "Außenschenkel-Maschine (Abduktion)", nameEn: "Abductor Machine", category: .legs, equipment: .machine),
        Exercise(name: "Kniebeugen (Multipresse)", nameEn: "Smith Machine Squats", category: .legs, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Frontkniebeugen (Multipresse)", nameEn: "Smith Machine Front Squats", category: .legs, equipment: .smithMachine, isHeavy: true),
        Exercise(name: "Ausfallschritte vorwärts (Multipresse)", nameEn: "Smith Machine Forward Lunges", category: .legs, equipment: .smithMachine),
        Exercise(name: "Ausfallschritte rückwärts (Multipresse)", nameEn: "Smith Machine Reverse Lunges", category: .legs, equipment: .smithMachine),
        Exercise(name: "Beinpresse frontal (Maschine)", nameEn: "Horizontal Leg Press", category: .legs, equipment: .machine, isHeavy: true),
        Exercise(name: "Hip Thrust", nameEn: "Barbell Hip Thrust", category: .glutes, equipment: .barbell, isHeavy: true, categories: [.glutes, .legs, .back]),
        Exercise(name: "Hip Thrust (Maschine)", nameEn: "Machine Hip Thrust", category: .glutes, equipment: .machine, isHeavy: true, categories: [.glutes, .legs, .back]),
        Exercise(name: "Kabelzug Kickback", nameEn: "Cable Glute Kickbacks", category: .glutes, equipment: .cable),
        Exercise(name: "Hüftabduktion (Maschine)", nameEn: "Seated Hip Abduction", category: .glutes, equipment: .machine),
        Exercise(name: "Beckenheben (Glute Bridge)", nameEn: "Glute Bridge", category: .glutes, equipment: .bodyweight),
        Exercise(name: "Cable Pull-Through", nameEn: "Cable Pull-Through", category: .glutes, equipment: .cable),
        Exercise(name: "Wadenheben stehend", nameEn: "Standing Calf Raise", category: .calves, equipment: .machine),
        Exercise(name: "Wadenheben sitzend", nameEn: "Seated Calf Raise", category: .calves, equipment: .machine),
        Exercise(name: "Wadenheben stehend (Multipresse)", nameEn: "Smith Machine Calf Raise", category: .calves, equipment: .smithMachine),
        Exercise(name: "Wadenheben an der Beinpresse", nameEn: "Leg Press Calf Raise", category: .calves, equipment: .machine),
        Exercise(name: "Eselwadenheben", nameEn: "Donkey Calf Raise", category: .calves, equipment: .machine),
        Exercise(name: "Crunches", nameEn: "Floor Crunches", category: .core, equipment: .bodyweight),
        Exercise(name: "Plank (Unterarmstütz)", nameEn: "Forearm Plank", category: .core, equipment: .bodyweight),
        Exercise(name: "Beinheben hängend", nameEn: "Hanging Leg Raises", category: .core, equipment: .bodyweight),
        Exercise(name: "Russian Twists", nameEn: "Russian Twists", category: .core, equipment: .bodyweight),
        Exercise(name: "Cable Crunches", nameEn: "Kneeling Cable Crunches", category: .core, equipment: .cable),
        Exercise(name: "Sit-Ups", nameEn: "Sit-Ups", category: .core, equipment: .bodyweight),
        Exercise(name: "Ab Wheel Rollout", nameEn: "Ab Wheel Rollouts", category: .core, equipment: .bodyweight),
        Exercise(name: "Mountain Climbers", nameEn: "Mountain Climbers", category: .core, equipment: .bodyweight),
        Exercise(name: "Seitliche Crunches", nameEn: "Side Crunches", category: .core, equipment: .bodyweight),
        Exercise(name: "Fahrradfahren (Bicycle Crunches)", nameEn: "Bicycle Crunches", category: .core, equipment: .bodyweight),
        Exercise(name: "Kerze mit Beinheben", nameEn: "Candle Leg Raises", category: .core, equipment: .bodyweight),
        Exercise(name: "Beine hochhalten (Static Hold)", nameEn: "Hollow Body Static Hold", category: .core, equipment: .bodyweight),
        Exercise(name: "Knietucks / Beine ziehen (liegend)", nameEn: "Lying Knee Tucks", category: .core, equipment: .bodyweight),
        Exercise(name: "Beine heben und senken (sitzend)", nameEn: "Seated In-and-Outs", category: .core, equipment: .bodyweight),
        Exercise(name: "Kettlebell Swings", nameEn: "Kettlebell Swings", category: .fullBody, equipment: .kettlebell),
        Exercise(name: "Burpees", nameEn: "Burpees", category: .fullBody, equipment: .bodyweight),
        Exercise(name: "Clean and Press", nameEn: "Barbell Clean and Press", category: .fullBody, equipment: .barbell, isHeavy: true),
        Exercise(name: "Farmer's Walk", nameEn: "Farmer's Walk", category: .fullBody, equipment: .dumbbell),
        Exercise(name: "Turkish Get-Up", nameEn: "Turkish Get-Up", category: .fullBody, equipment: .kettlebell),
        Exercise(name: "Thruster", nameEn: "Barbell Thrusters", category: .fullBody, equipment: .barbell, isHeavy: true),
        Exercise(name: "Box Jump (Box-Springen)", nameEn: "Plyo Box Jumps", category: .fullBody, equipment: .bodyweight),
        // Echte Home-Übungen — ohne Stange, Bank oder Box (Stand API-Katalog).
        Exercise(name: "Kniebeugen ohne Gewicht", nameEn: "Bodyweight Squats", category: .legs, equipment: .bodyweight, categories: [.legs, .glutes]),
        Exercise(name: "Ausfallschritte ohne Gewicht", nameEn: "Bodyweight Lunges", category: .legs, equipment: .bodyweight, categories: [.legs, .glutes]),
        Exercise(name: "Rückwärts-Ausfallschritte", nameEn: "Reverse Lunges", category: .legs, equipment: .bodyweight, categories: [.legs, .glutes]),
        Exercise(name: "Sprungkniebeugen", nameEn: "Jump Squats", category: .legs, equipment: .bodyweight, categories: [.legs, .fullBody]),
        Exercise(name: "Wandsitzen (Wall Sit)", nameEn: "Wall Sit", category: .legs, equipment: .bodyweight),
        Exercise(name: "Wadenheben stehend (Körpergewicht)", nameEn: "Bodyweight Calf Raises", category: .calves, equipment: .bodyweight),
        Exercise(name: "Einbeiniges Beckenheben", nameEn: "Single-Leg Glute Bridge", category: .glutes, equipment: .bodyweight, categories: [.glutes, .legs]),
        Exercise(name: "Knie-Liegestütze", nameEn: "Knee Push-Ups", category: .chest, equipment: .bodyweight, categories: [.chest, .triceps]),
        Exercise(name: "Diamant-Liegestütze", nameEn: "Diamond Push-Ups", category: .triceps, equipment: .bodyweight, categories: [.triceps, .chest]),
        Exercise(name: "Pike-Liegestütze", nameEn: "Pike Push-Ups", category: .shoulders, equipment: .bodyweight, categories: [.shoulders, .triceps]),
        Exercise(name: "Superman", nameEn: "Superman Raises", category: .back, equipment: .bodyweight),
        Exercise(name: "Bird Dog (Vierfüßlerstand)", nameEn: "Bird Dog", category: .back, equipment: .bodyweight, categories: [.back, .core]),
        Exercise(name: "Seitstütz (Side Plank)", nameEn: "Side Plank", category: .core, equipment: .bodyweight),
        Exercise(name: "Hampelmann (Jumping Jacks)", nameEn: "Jumping Jacks", category: .fullBody, equipment: .bodyweight),
        Exercise(name: "Kniehebelauf (High Knees)", nameEn: "High Knees", category: .fullBody, equipment: .bodyweight, categories: [.fullBody, .legs]),
    ]

    public private(set) static var all: [Exercise] = bundled

    /// Reihenfolge wie CATEGORIES im Web: erstes Auftreten in der Liste.
    public private(set) static var categories: [MuscleCategory] = Self.derivedCategories(from: bundled)
    public private(set) static var equipment: [EquipmentType] = Self.derivedEquipment(from: bundled)

    private static func derivedCategories(from list: [Exercise]) -> [MuscleCategory] {
        var seen: [MuscleCategory] = []
        for ex in list {
            for c in ex.categories where !seen.contains(c) { seen.append(c) }
        }
        return seen
    }

    private static func derivedEquipment(from list: [Exercise]) -> [EquipmentType] {
        var seen: [EquipmentType] = []
        for ex in list where !seen.contains(ex.equipment) { seen.append(ex.equipment) }
        return seen
    }

    /*
      Ersetzt den Katalog durch die Liste vom Server — aber nur, wenn sie
      plausibel ist. Eine leere oder halbe Antwort darf die App nicht ärmer
      machen als sie ohne Netz wäre.
    */
    @MainActor
    public static func refreshFromAPI() async {
        let remote: [KraftAPI.RemoteExercise]
        do {
            remote = try await KraftAPI.shared.exercises()
        } catch {
            // Vorher stand hier `try?` und ein wortloses `return`. Ein Ausfall
            // des Dienstes war damit von einem leeren Katalog nicht zu
            // unterscheiden — auch nicht beim Suchen eines Fehlers.
            BackendStatus.shared.recordCatalogFailure(error.localizedDescription)
            return
        }

        let mapped: [Exercise] = remote.compactMap { r in
            guard let category = MuscleCategory(rawValue: r.category),
                  let equipment = EquipmentType(rawValue: r.equipment)
            else { return nil }   // unbekannte Werte lieber auslassen als raten
            let cats = r.categories.compactMap(MuscleCategory.init(rawValue:))
            return Exercise(
                name: r.name, nameEn: r.nameEn,
                category: category, equipment: equipment,
                isHeavy: r.heavy,
                categories: cats.isEmpty ? [category] : cats
            )
        }

        guard mapped.count >= bundled.count else {
            BackendStatus.shared.recordCatalogFailure(
                "nur \(mapped.count) von \(bundled.count) Übungen verwertbar"
            )
            return
        }

        all = mapped
        categories = derivedCategories(from: mapped)
        equipment = derivedEquipment(from: mapped)
        BackendStatus.shared.recordCatalog(.server(count: mapped.count))
    }
}

// MARK: - Zu Hause machbar

/*
  Einige Übungen stehen als „Körpergewicht" im Katalog, brauchen aber trotzdem
  ein Gerät: eine Klimmzugstange, einen Barren, eine Bank, eine Box oder ein
  Ab-Wheel. Für das Studio ist das egal. Zu Hause schlug die App sie trotzdem
  vor — beim Neu-Würfeln und Tauschen sogar Maschinen, weil dort nur die
  Muskelgruppe zählte.

  Dieselbe Liste steht im Server (TrainingConstraints.NeedsApparatus).
*/
public extension Exercise {
    static let apparatusNames: Set<String> = [
        "Dips (Brustfokus)", "Dips (Trizepsfokus)", "Klimmzüge", "Hyperextensions",
        "Beinheben hängend", "Ab Wheel Rollout", "Box Jump (Box-Springen)",
        "Kurzhantel-Bankdrücken", "Kurzhantel-Schrägbankdrücken", "Fliegende Kurzhantel (Schrägbank)",
        "Negativbankdrücken (Kurzhantel)", "Kurzhantel-Bankdrücken (Neutralgriff)",
        "Kurzhantel-Bankdrücken (Untergriff)", "Seitheben angelehnt an Bank (Kurzhantel)", "Pull-Over",
    ]

    /// Braucht ein Gerät, das zu Hause in der Regel fehlt.
    var needsApparatus: Bool { Self.apparatusNames.contains(name) }
}

public enum HomeTraining {
    /// Was zu Hause realistisch herumsteht.
    public static let equipment: Set<EquipmentType> = [.bodyweight, .dumbbell, .kettlebell, .weightPlate]

    /// Ein Gerätesatz, der nur aus Home-Equipment besteht.
    public static func isHome(_ allowed: Set<EquipmentType>?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return false }
        return allowed.isSubset(of: equipment)
    }

    /*
      Welche Geräte ein Tausch oder Neu-Würfeln nehmen darf, wenn niemand es
      ausdrücklich sagt: abgeleitet aus dem, was im Plan schon steht.

      Besteht der Plan nur aus Home-Übungen, ist es ein Home-Plan — dann bleibt
      es bei genau diesen Geräten plus Körpergewicht. Sonst (Studio) gibt es
      keine Einschränkung.
    */
    public static func inferredEquipment(for exercises: [Exercise]) -> Set<EquipmentType>? {
        guard !exercises.isEmpty,
              exercises.allSatisfy({ equipment.contains($0.equipment) && !$0.needsApparatus })
        else { return nil }
        return Set(exercises.map(\.equipment)).union([.bodyweight])
    }

    /// Darf diese Übung bei diesen Geräten vorgeschlagen werden?
    public static func allows(_ exercise: Exercise, equipment allowed: Set<EquipmentType>?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        guard allowed.contains(exercise.equipment) else { return false }
        return !(isHome(allowed) && exercise.needsApparatus)
    }
}
