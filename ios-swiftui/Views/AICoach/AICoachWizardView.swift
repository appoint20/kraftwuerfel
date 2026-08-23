import SwiftUI

public struct AICoachWizardView: View {
    @State private var step: Int = 1
    @State private var goal: String = "muscle"
    @State private var experience: String = "intermediate"
    
    // Biometrics
    @State private var sex: String = "male"
    @State private var age: Int = 28
    @State private var height: Int = 180
    @State private var weight: Int = 80
    
    // Schedule
    @State private var selectedDays: Set<String> = ["Mo", "Mi", "Fr"]
    @State private var sessionMinutes: Int = 60
    @State private var weeks: Int = 4
    
    // Options
    @State private var warmup: String = "auto"
    @State private var diet: String = "lacto_vegetarian"
    @State private var limitations: String = ""
    
    @State private var generatedPlan: TrainingPlan?
    @State private var isGenerating: Bool = false
    @State private var selectedTab: Int = 0 // 0: Workout Plan, 1: Meal Guide
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                
                if let plan = generatedPlan {
                    // Result Screen
                    VStack(spacing: 0) {
                        Picker("Ansicht", selection: $selectedTab) {
                            Text("🏋️ Trainingsplan").tag(0)
                            if plan.nutrition != nil {
                                Text("🥗 Meal Guide").tag(1)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        if selectedTab == 0 {
                            WorkoutPlanResultView(plan: plan)
                        } else if let nut = plan.nutrition {
                            MealGuideView(nutrition: nut)
                        }
                    }
                } else {
                    // Wizard Flow
                    VStack(spacing: 20) {
                        // 5-Step Progress Bar
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { s in
                                Rectangle()
                                    .fill(s <= step ? Color.accentEmerald : Color.surfaceElevated)
                                    .frame(height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                switch step {
                                case 1:
                                    step1GoalExperience
                                case 2:
                                    step2Biometrics
                                case 3:
                                    step3Schedule
                                case 4:
                                    step4WarmupAndDiet
                                case 5:
                                    step5Review
                                default:
                                    EmptyView()
                                }
                            }
                            .padding()
                        }
                        
                        // Navigation Buttons
                        HStack(spacing: 12) {
                            if step > 1 {
                                Button(action: { withAnimation { step -= 1 } }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Zurück")
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.surfaceElevated)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Button(action: handleNext) {
                                HStack {
                                    if isGenerating {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text(step == 5 ? "PLAN ERSTELLEN" : "WEITER")
                                        Image(systemName: "arrow.right")
                                    }
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentEmerald)
                                .cornerRadius(12)
                            }
                            .disabled(isGenerating)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(generatedPlan == nil ? "KI-Coach Wizard" : "Dein Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Step 1: Goal & Experience
    private var step1GoalExperience: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("WAS IST DEIN ZIEL?")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                GoalButton(title: "Muskelaufbau", id: "muscle", selected: $goal)
                GoalButton(title: "Maximalkraft", id: "strength", selected: $goal)
                GoalButton(title: "Definition", id: "definition", selected: $goal)
                GoalButton(title: "Abnehmen", id: "abnehmen", selected: $goal)
            }
            
            Text("TRAININGSERFAHRUNG")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
                .padding(.top, 10)
            
            // Single Row Experience Options
            HStack(spacing: 8) {
                OptionChip(title: "Anfänger", id: "beginner", selected: $experience)
                OptionChip(title: "Fortgeschritten", id: "intermediate", selected: $experience)
                OptionChip(title: "Profi", id: "advanced", selected: $experience)
            }
        }
    }
    
    // MARK: - Step 2: Biometrics
    private var step2Biometrics: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("BIOMETRISCHE DATEN")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            
            HStack(spacing: 8) {
                OptionChip(title: "Männlich", id: "male", selected: $sex)
                OptionChip(title: "Weiblich", id: "female", selected: $sex)
                OptionChip(title: "Divers", id: "other", selected: $sex)
            }
            
            HStack(spacing: 10) {
                StepperCard(title: "Alter", value: "\(age) J.", onMinus: { age = max(14, age - 1) }, onPlus: { age += 1 })
                StepperCard(title: "Größe", value: "\(height) cm", onMinus: { height = max(120, height - 1) }, onPlus: { height += 1 })
                StepperCard(title: "Gewicht", value: "\(weight) kg", onMinus: { weight = max(40, weight - 1) }, onPlus: { weight += 1 })
            }
        }
    }
    
    // MARK: - Step 3: Schedule & Duration (Single Row Options)
    private var step3Schedule: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("TRAININGSTAGE PRO WOCHE")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            
            HStack(spacing: 6) {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { d in
                    Button(action: {
                        if selectedDays.contains(d) { selectedDays.remove(d) } else { selectedDays.insert(d) }
                    }) {
                        Text(d)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedDays.contains(d) ? Color.accentEmerald : Color.surfaceDark)
                            .foregroundColor(selectedDays.contains(d) ? .black : .white)
                            .cornerRadius(10)
                    }
                }
            }
            
            Text("DAUER PRO EINHEIT (SINGLE ROW)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
                .padding(.top, 10)
            
            HStack(spacing: 8) {
                ForEach([30, 45, 60, 90], id: \.self) { m in
                    OptionChipInt(title: "\(m) Min", val: m, selected: $sessionMinutes)
                }
            }
            
            Text("PLANLÄNGE IN WOCHEN (SINGLE ROW)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
                .padding(.top, 10)
            
            HStack(spacing: 8) {
                ForEach([2, 4, 6], id: \.self) { w in
                    OptionChipInt(title: "\(w) Wochen", val: w, selected: $weeks)
                }
            }
        }
    }
    
    // MARK: - Step 4: Warmup & Diet (Includes Lacto-Vegetarian)
    private var step4WarmupAndDiet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("AUFWÄRMEN (SINGLE ROW)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            
            HStack(spacing: 8) {
                OptionChip(title: "Coach wählt", id: "auto", selected: $warmup)
                OptionChip(title: "Ja, immer", id: "yes", selected: $warmup)
                OptionChip(title: "Nein", id: "no", selected: $warmup)
            }
            
            Text("ERNÄHRUNGSFORM (INKL. LAKTO-VEGETARISCH)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
                .padding(.top, 10)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                OptionChip(title: "Allesesser", id: "omnivore", selected: $diet)
                OptionChip(title: "Vegetarisch", id: "vegetarian", selected: $diet)
                OptionChip(title: "Lakto-Vegetarisch", id: "lacto_vegetarian", selected: $diet)
                OptionChip(title: "Vegan", id: "vegan", selected: $diet)
            }
        }
    }
    
    // MARK: - Step 5: Review
    private var step5Review: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ÜBERSICHT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textSecondary)
                .tracking(1)
            
            VStack(spacing: 12) {
                ReviewRow(label: "Ziel", value: goal.capitalized)
                ReviewRow(label: "Biometrie", value: "\(sex.capitalized) · \(age) J · \(height)cm · \(weight)kg")
                ReviewRow(label: "Tage & Dauer", value: "\(selectedDays.joined(separator: ", ")) · \(sessionMinutes)m")
                ReviewRow(label: "Planlänge", value: "\(weeks) Wochen")
                ReviewRow(label: "Ernährung", value: DietType(rawValue: diet)?.titleDe ?? diet)
            }
            .padding()
            .background(Color.surfaceDark)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.borderSubtle, lineWidth: 1))
        }
    }
    
    private func handleNext() {
        if step < 5 {
            withAnimation { step += 1 }
        } else {
            generatePlan()
        }
    }
    
    private func generatePlan() {
        isGenerating = true
        Task {
            let req = AICoachRequest(
                sex: sex,
                age: age,
                height: height,
                weight: weight,
                goal: goal,
                experience: experience,
                days: Array(selectedDays),
                sessionMinutes: sessionMinutes,
                equipment: [],
                focus: [],
                limitations: limitations,
                weeks: weeks,
                language: "de",
                warmup: warmup,
                diet: diet
            )
            do {
                let plan = try await AICoachService.shared.generatePlan(from: req)
                await MainActor.run {
                    self.generatedPlan = plan
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run { self.isGenerating = false }
            }
        }
    }
}

// MARK: - Supporting Components
private struct GoalButton: View {
    let title: String
    let id: String
    @Binding var selected: String
    
    var body: some View {
        Button(action: { selected = id }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected == id ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selected == id ? Color.accentEmerald : Color.surfaceDark)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected == id ? Color.accentEmerald : Color.borderSubtle, lineWidth: 1))
        }
    }
}

private struct OptionChip: View {
    let title: String
    let id: String
    @Binding var selected: String
    
    var body: some View {
        Button(action: { selected = id }) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(selected == id ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected == id ? Color.accentEmerald : Color.surfaceDark)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == id ? Color.accentEmerald : Color.borderSubtle, lineWidth: 1))
        }
    }
}

private struct OptionChipInt: View {
    let title: String
    let val: Int
    @Binding var selected: Int
    
    var body: some View {
        Button(action: { selected = val }) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected == val ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected == val ? Color.accentEmerald : Color.surfaceDark)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == val ? Color.accentEmerald : Color.borderSubtle, lineWidth: 1))
        }
    }
}

private struct StepperCard: View {
    let title: String
    let value: String
    let onMinus: () -> Void
    let onPlus: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Text("−").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
                Button(action: onPlus) {
                    Text("+").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.surfaceDark)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderSubtle, lineWidth: 1))
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.textSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        }
    }
}

private struct WorkoutPlanResultView: View {
    let plan: TrainingPlan
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(plan.days) { day in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(day.weekday)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentEmeraldDim)
                                .foregroundColor(.accentEmerald)
                                .cornerRadius(6)
                            Text(day.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(day.focus)
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        
                        ForEach(day.slots) { slot in
                            HStack(spacing: 12) {
                                MuscleAnatomyView(category: slot.exercise.category, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.exercise.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(slot.exercise.category.localized)
                                        .font(.system(size: 11))
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                Text("\(slot.sets) × \(slot.reps)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.accentEmerald)
                            }
                            .padding(10)
                            .background(Color.surfaceElevated)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color.surfaceDark)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.borderSubtle, lineWidth: 1))
                }
            }
            .padding()
        }
    }
}
