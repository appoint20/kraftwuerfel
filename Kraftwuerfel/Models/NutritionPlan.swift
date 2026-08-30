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

/// Einzelnes, strukturiertes Lebensmittel / Zutat im Yazio-Style
public struct FoodItemEntry: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var amount: String
    public var calories: Int
    public var protein: Int
    public var carbs: Int
    public var fat: Int

    public init(
        id: UUID = UUID(),
        name: String,
        amount: String = "1 Portion",
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fat: Int = 0
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

public struct MealItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var time: String
    public var name: String
    public var calories: Int
    public var protein: Int?
    public var carbs: Int?
    public var fat: Int?
    public var items: [String]
    public var customEntries: [FoodItemEntry]
    public var instructions: String?
    
    public init(
        id: UUID = UUID(),
        time: String,
        name: String,
        calories: Int,
        protein: Int? = nil,
        carbs: Int? = nil,
        fat: Int? = nil,
        items: [String] = [],
        customEntries: [FoodItemEntry] = [],
        instructions: String? = nil
    ) {
        self.id = id
        self.time = time
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.items = items
        self.customEntries = customEntries
        self.instructions = instructions
    }

    /// Gesamtkalorien inklusive eventueller Custom-Zutaten
    public var effectiveCalories: Int {
        if !customEntries.isEmpty {
            return customEntries.reduce(0) { $0 + $1.calories }
        }
        return calories
    }

    /// Gesamtprotein inklusive eventueller Custom-Zutaten
    public var effectiveProtein: Int {
        if !customEntries.isEmpty {
            return customEntries.reduce(0) { $0 + $1.protein }
        }
        return protein ?? 0
    }

    /// Gesamtkohlenhydrate inklusive eventueller Custom-Zutaten
    public var effectiveCarbs: Int {
        if !customEntries.isEmpty {
            return customEntries.reduce(0) { $0 + $1.carbs }
        }
        return carbs ?? 0
    }

    /// Gesamtfett inklusive eventueller Custom-Zutaten
    public var effectiveFat: Int {
        if !customEntries.isEmpty {
            return customEntries.reduce(0) { $0 + $1.fat }
        }
        return fat ?? 0
    }
}

public struct ShakeItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var when: String
    public var what: String
    public var powderAmount: String?
    public var liquid: String?
    public var proteinGrams: Int?
    public var calories: Int?
    
    public init(
        id: UUID = UUID(),
        when: String,
        what: String,
        powderAmount: String? = nil,
        liquid: String? = nil,
        proteinGrams: Int? = nil,
        calories: Int? = nil
    ) {
        self.id = id
        self.when = when
        self.what = what
        self.powderAmount = powderAmount
        self.liquid = liquid
        self.proteinGrams = proteinGrams
        self.calories = calories
    }
}

/// Tagesplan für den 7-Tage-Ernährungsplan (Montag bis Sonntag)
public struct NutritionDaySchedule: Identifiable, Codable, Hashable {
    public var id: UUID
    public var dayNumber: Int
    public var dayName: String
    public var dailyCalories: Int
    public var protein: Int?
    public var carbs: Int?
    public var fat: Int?
    public var meals: [MealItem]
    
    public init(
        id: UUID = UUID(),
        dayNumber: Int,
        dayName: String,
        dailyCalories: Int,
        protein: Int? = nil,
        carbs: Int? = nil,
        fat: Int? = nil,
        meals: [MealItem]
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.dayName = dayName
        self.dailyCalories = dailyCalories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.meals = meals
    }

    /// Summe aller Mahlzeitenkalorien für diesen Tag
    public var calculatedCalories: Int {
        let sum = meals.reduce(0) { $0 + $1.effectiveCalories }
        return sum > 0 ? sum : dailyCalories
    }

    /// Summe aller Proteinangaben für diesen Tag
    public var calculatedProtein: Int {
        let sum = meals.reduce(0) { $0 + $1.effectiveProtein }
        return sum > 0 ? sum : (protein ?? 0)
    }

    /// Summe aller Kohlenhydrate für diesen Tag
    public var calculatedCarbs: Int {
        let sum = meals.reduce(0) { $0 + $1.effectiveCarbs }
        return sum > 0 ? sum : (carbs ?? 0)
    }

    /// Summe aller Fettangaben für diesen Tag
    public var calculatedFat: Int {
        let sum = meals.reduce(0) { $0 + $1.effectiveFat }
        return sum > 0 ? sum : (fat ?? 0)
    }
}

public struct NutritionPlan: Codable, Hashable {
    public var diet: DietType
    public var dailyCalories: Int
    public var protein: Int
    public var carbs: Int
    public var fat: Int
    public var weeklySchedule: [NutritionDaySchedule]
    public var meals: [MealItem]
    public var shakes: [ShakeItem]
    public var notes: [String]
    public var disclaimer: String
    
    public init(
        diet: DietType,
        dailyCalories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        weeklySchedule: [NutritionDaySchedule] = [],
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
        self.weeklySchedule = weeklySchedule
        self.meals = meals
        self.shakes = shakes
        self.notes = notes
        self.disclaimer = disclaimer
    }

    /// Liefert immer einen validen 7-Tage-Plan (Montag bis Sonntag), auch wenn legacy Daten vorliegen
    public var resolvedSchedule: [NutritionDaySchedule] {
        if !weeklySchedule.isEmpty {
            return weeklySchedule
        }
        let dayNamesDe = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
        return (1...7).map { index in
            NutritionDaySchedule(
                dayNumber: index,
                dayName: dayNamesDe[index - 1],
                dailyCalories: dailyCalories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                meals: meals
            )
        }
    }

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
