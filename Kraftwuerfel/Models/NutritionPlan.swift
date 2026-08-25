import Foundation

public enum DietType: String, Codable, CaseIterable, Identifiable {
    case omnivore = "omnivore"
    case vegetarian = "vegetarian"
    case lactoVegetarian = "lacto_vegetarian"
    case vegan = "vegan"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .omnivore: return "Allesesser"
        case .vegetarian: return "Vegetarisch"
        case .lactoVegetarian: return "Lakto-Vegetarisch"
        case .vegan: return "Vegan"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .omnivore: return "Omnivore"
        case .vegetarian: return "Vegetarian"
        case .lactoVegetarian: return "Lacto-Vegetarian"
        case .vegan: return "Vegan"
        }
    }
    
    public var descriptionDe: String {
        switch self {
        case .omnivore: return "Fleisch, Fisch, Eier & Milchprodukte"
        case .vegetarian: return "Pflanzlich, Milchprodukte & Eier (kein Fleisch/Fisch)"
        case .lactoVegetarian: return "Milchprodukte (Quark, Käse, Whey), keine Eier, kein Fleisch/Fisch"
        case .vegan: return "100% rein pflanzliche Ernährung"
        }
    }

    /// Fehlte komplett — der Meal Guide zeigte die Beschreibung deshalb auch
    /// auf Englisch auf Deutsch an.
    public var descriptionEn: String {
        switch self {
        case .omnivore: return "Meat, fish, eggs & dairy"
        case .vegetarian: return "Plant-based, dairy & eggs (no meat or fish)"
        case .lactoVegetarian: return "Dairy (quark, cheese, whey), no eggs, no meat or fish"
        case .vegan: return "100% plant-based"
        }
    }

    public func localized(_ lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }

    public func localizedDescription(_ lang: String) -> String {
        lang == "en" ? descriptionEn : descriptionDe
    }
}

public struct MealItem: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let time: String
    public let name: String
    public let calories: Int
    public let items: [String]
    
    public init(time: String, name: String, calories: Int, items: [String]) {
        self.time = time
        self.name = name
        self.calories = calories
        self.items = items
    }
}

public struct ShakeItem: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let when: String
    public let what: String
    
    public init(when: String, what: String) {
        self.when = when
        self.what = what
    }
}

public struct NutritionPlan: Codable, Hashable {
    public let diet: DietType
    public let dailyCalories: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int
    public let meals: [MealItem]
    public let shakes: [ShakeItem]
    public let notes: [String]
    public let disclaimer: String
    
    public init(
        diet: DietType,
        dailyCalories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        meals: [MealItem],
        shakes: [ShakeItem],
        notes: [String],
        disclaimer: String
    ) {
        self.diet = diet
        self.dailyCalories = dailyCalories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.meals = meals
        self.shakes = shakes
        self.notes = notes
        self.disclaimer = disclaimer
    }

    /*
      Zwei Guides beschreiben dieselbe Ernährung, wenn Form, Kalorien, Makros
      und der Ablauf übereinstimmen. Die UUIDs der Mahlzeiten zählen bewusst
      nicht mit — sie sind bei jedem Erzeugen neu.
    */
    public func isSameGuide(as other: NutritionPlan) -> Bool {
        diet == other.diet
            && dailyCalories == other.dailyCalories
            && protein == other.protein
            && carbs == other.carbs
            && fat == other.fat
            && meals.map(\.time) == other.meals.map(\.time)
            && meals.map(\.calories) == other.meals.map(\.calories)
    }
}
