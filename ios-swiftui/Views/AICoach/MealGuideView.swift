import SwiftUI

public struct MealGuideView: View {
    public let nutrition: NutritionPlan
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card with Diet Tag
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ERNÄHRUNGSPLAN")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(nutrition.diet.descriptionDe)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Text(nutrition.diet.titleDe.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentEmeraldDim)
                        .foregroundColor(.accentEmerald)
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.surfaceDark)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1))
                
                // Macros Grid
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("\(nutrition.dailyCalories)")
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundColor(.accentEmerald)
                        Text("kcal / Tag")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.surfaceDark)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
                    
                    MacroChip(title: "Eiweiß", value: "\(nutrition.protein) g", color: .blue)
                    MacroChip(title: "Carbs", value: "\(nutrition.carbs) g", color: .orange)
                    MacroChip(title: "Fett", value: "\(nutrition.fat) g", color: .purple)
                }
                
                // Meals List
                VStack(alignment: .leading, spacing: 12) {
                    Text("TAGESPLAN & MAHLZEITEN")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.textSecondary)
                        .tracking(1)
                    
                    ForEach(nutrition.meals) { meal in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.time)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.accentEmerald)
                                Text(meal.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 90, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.items.joined(separator: " · "))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.9))
                                if meal.calories > 0 {
                                    Text("\(meal.calories) kcal")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.surfaceDark)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
                    }
                }
                
                // Protein Shakes
                if !nutrition.shakes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PROTEIN-SHAKES")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.textSecondary)
                            .tracking(1)
                        
                        ForEach(nutrition.shakes) { shake in
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .foregroundColor(.accentEmerald)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shake.when)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(shake.what)
                                        .font(.system(size: 12))
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.surfaceDark)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
                        }
                    }
                }
                
                // Disclaimer
                Text(nutrition.disclaimer)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary.opacity(0.8))
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color.bgDark.ignoresSafeArea())
    }
}

private struct MacroChip: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.surfaceDark)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
    }
}
