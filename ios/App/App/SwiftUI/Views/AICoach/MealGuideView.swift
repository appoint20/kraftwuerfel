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
                
                // Diet Badge & Calories Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(nutrition.diet.titleDe)
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                        
                        Spacer()
                        
                        Text("\(nutrition.dailyCalories) kcal / Tag")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text(nutrition.diet.descriptionDe)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(18)
                .padding(.horizontal)
                
                // MACROS GRID (Donut Cards)
                HStack(spacing: 12) {
                    MacroCard(title: "Eiweiß", grams: nutrition.protein, color: .orange, icon: "flame.fill")
                    MacroCard(title: "Carbs", grams: nutrition.carbs, color: .blue, icon: "bolt.fill")
                    MacroCard(title: "Fett", grams: nutrition.fat, color: .yellow, icon: "drop.fill")
                }
                .padding(.horizontal)
                
                // MEALS LIST
                VStack(alignment: .leading, spacing: 12) {
                    Text("TAGESPLAN & MAHLZEITEN")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    ForEach(nutrition.meals) { meal in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(meal.time)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                                    .foregroundColor(.white)
                                
                                Text(meal.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(meal.calories) kcal")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(meal.items, id: \.self) { item in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 4, height: 4)
                                        Text(item)
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
                
                // SHAKES SECTION
                if !nutrition.shakes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SHAKES & TIMING")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ForEach(nutrition.shakes) { shake in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                                    .frame(width: 36, height: 36)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shake.when)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(shake.what)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.12))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // SAVE MEAL PLAN BUTTON
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSaveMealPlan?()
                    showSavedAlert = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                        Text("ERNÄHRUNGSPLAN SPEICHERN")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .alert("Gespeichert!", isPresented: $showSavedAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Dein Ernährungsplan wurde erfolgreich in den gespeicherten Plänen gesichert.")
                }
                
                // Disclaimer
                Text(nutrition.disclaimer)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct MacroCard: View {
    let title: String
    let grams: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text("\(grams) g")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.12))
        .cornerRadius(16)
    }
}
