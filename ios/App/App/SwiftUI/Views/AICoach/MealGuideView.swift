import SwiftUI

public struct MealGuideView: View {
    public let nutrition: NutritionPlan
    public var onSaveMealPlan: (() -> Void)?
    
    @State private var showSavedAlert = false
    
    public init(nutrition: NutritionPlan, onSaveMealPlan: (() -> Void)? = nil) {
        self.nutrition = nutrition
        self.onSaveMealPlan = onSaveMealPlan
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                macrosGrid
                mealScheduleList
                if !nutrition.shakes.isEmpty {
                    shakesList
                }
                saveButton
                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(nutrition.diet.titleDe)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentDim)
                    .foregroundColor(Theme.accent)
                    .cornerRadius(10)
                
                Spacer()
                
                Text("\(nutrition.dailyCalories) kcal / Tag")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Theme.text)
            }
            
            Text(nutrition.diet.descriptionDe)
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }
    
    private var macrosGrid: some View {
        HStack(spacing: 12) {
            MacroCard(title: "Eiweiß", grams: nutrition.protein, color: Theme.accent, icon: "flame.fill")
            MacroCard(title: "Carbs", grams: nutrition.carbs, color: Color(hex: "3B82F6"), icon: "bolt.fill")
            MacroCard(title: "Fett", grams: nutrition.fat, color: Color(hex: "F59E0B"), icon: "drop.fill")
        }
        .padding(.horizontal, 20)
    }
    
    private var mealScheduleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAHLZEITEN-TIMING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
            
            ForEach(nutrition.meals) { meal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(meal.time)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Theme.accent)
                        Spacer()
                        Text("\(meal.calories) kcal")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.muted)
                    }
                    
                    Text(meal.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.text)
                    
                    if !meal.items.isEmpty {
                        Text(meal.items.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                    }
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var shakesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POWER-SHAKES & SUPPLEMENTE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
            
            ForEach(nutrition.shakes) { shake in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("SHAKE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.accent)
                        Spacer()
                        Text(shake.when)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                    }
                    
                    Text(shake.what)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.text)
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var saveButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showSavedAlert = true
            onSaveMealPlan?()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14))
                Text("MEAL GUIDE SPEICHERN")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accent)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .alert(isPresented: $showSavedAlert) {
            Alert(
                title: Text("Gespeichert!"),
                message: Text("Dein Ernährungsplan wurde erfolgreich gesichert."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

public struct MacroCard: View {
    public let title: String
    public let grams: Int
    public let color: Color
    public let icon: String
    
    public init(title: String, grams: Int, color: Color, icon: String) {
        self.title = title
        self.grams = grams
        self.color = color
        self.icon = icon
    }
    
    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text("\(grams)g")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(Theme.text)
            
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
