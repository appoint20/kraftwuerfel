import SwiftUI

public struct AICoachWizardView: View {
    @State private var currentStep: Int = 1
    @State private var goal: TrainingGoal = .muscle
    @State private var experience: ExperienceLevel = .intermediate
    @State private var sex: String = "male"
    @State private var age: Int = 28
    @State private var heightCm: Double = 180
    @State private var weightKg: Double = 80
    @State private var selectedDays: Set<String> = ["Mo", "Mi", "Fr"]
    @State private var durationMinutes: Int = 60
    @State private var weeks: Int = 4
    @State private var selectedEquipment: Set<EquipmentType> = []
    @State private var diet: DietType = .lactoVegetarian
    @State private var includeWarmup: Bool = true
    
    @State private var generatedPlan: TrainingPlan?
    @State private var selectedTab: String = "workout" // "workout" | "nutrition"
    @State private var isGenerating: Bool = false
    
    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    public var onSavePlan: ((TrainingPlan) -> Void)?
    
    private let allWeekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    public init(
        onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil,
        onSavePlan: ((TrainingPlan) -> Void)? = nil
    ) {
        self.onStartLiveWorkout = onStartLiveWorkout
        self.onSavePlan = onSavePlan
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // HEADER BRAND
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("KI-COACH")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("PRO")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.black)
                                .cornerRadius(6)
                        }
                        Text("Wissenschaftlich periodisierter Trainings- & Ernährungsplan")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                if let plan = generatedPlan {
                    // PLAN VIEW MODE (WORKOUT vs NUTRITION)
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            Button(action: { selectedTab = "workout" }) {
                                HStack {
                                    Image(systemName: "dumbbell.fill")
                                    Text("Trainingsplan")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTab == "workout" ? Color.orange : Color(white: 0.16))
                                .foregroundColor(selectedTab == "workout" ? .black : .white)
                                .cornerRadius(12)
                            }
                            
                            Button(action: { selectedTab = "nutrition" }) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                    Text("Meal Guide")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTab == "nutrition" ? Color.orange : Color(white: 0.16))
                                .foregroundColor(selectedTab == "nutrition" ? .black : .white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        if selectedTab == "workout" {
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 18) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(plan.title)
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                        Text(plan.summary)
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(white: 0.12))
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                    
                                    ForEach(plan.days) { day in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text(day.weekday)
                                                    .font(.system(size: 13, weight: .black))
                                                    .foregroundColor(.orange)
                                                    .frame(width: 32, height: 32)
                                                    .background(Color.orange.opacity(0.15))
                                                    .clipShape(Circle())
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(day.name)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                    Text(day.focus)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                                
                                                if let onStartLiveWorkout = onStartLiveWorkout {
                                                    Button(action: {
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        onStartLiveWorkout(day.slots, "\(day.name) · \(day.weekday)")
                                                    }) {
                                                        Image(systemName: "play.fill")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 6)
                                                            .background(Color.green)
                                                            .foregroundColor(.black)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                            }
                                            
                                            ForEach(day.slots) { slot in
                                                HStack {
                                                    Text(slot.exercise.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Text("\(slot.sets) × \(slot.reps)")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                        .foregroundColor(.orange)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                        .padding()
                                        .background(Color(white: 0.12))
                                        .cornerRadius(16)
                                        .padding(.horizontal)
                                    }
                                    
                                    Button(action: { generatedPlan = nil; currentStep = 1 }) {
                                        Text("Neuen Plan konfigurieren")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                    
                                    Spacer(minLength: 40)
                                }
                            }
                        } else if let nutrition = plan.nutrition {
                            MealGuideView(nutrition: nutrition)
                        }
                    }
                } else {
                    // 5-STEP WIZARD
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // STEP INDICATOR (1 to 5)
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { s in
                                    Rectangle()
                                        .fill(s <= currentStep ? Color.orange : Color(white: 0.2))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                }
                            }
                            .padding(.horizontal)
                            
                            // STEP 1: GOAL & EXPERIENCE
                            if currentStep == 1 {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("SCHRITT 1: ZIEL & ERFAHRUNG")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    
                                    ForEach(TrainingGoal.allCases) { g in
                                        Button(action: { goal = g }) {
                                            HStack {
                                                Text(g.titleDe)
                                                    .font(.system(size: 15, weight: .semibold))
                                                Spacer()
                                                if goal == g {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            .padding()
                                            .background(goal == g ? Color.orange.opacity(0.15) : Color(white: 0.12))
                                            .foregroundColor(goal == g ? .orange : .white)
                                            .cornerRadius(14)
                                        }
                                    }
                                    
                                    Text("Erfahrungslevel")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                    
                                    HStack(spacing: 8) {
                                        ForEach(ExperienceLevel.allCases) { exp in
                                            Button(action: { experience = exp }) {
                                                Text(exp.rawValue.capitalized)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(experience == exp ? Color.orange : Color(white: 0.16))
                                                    .foregroundColor(experience == exp ? .black : .white)
                                                    .cornerRadius(12)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // STEP 2: BIOMETRICS
                            if currentStep == 2 {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("SCHRITT 2: KÖRPERDATEN")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    
                                    HStack {
                                        Text("Geschlecht")
                                        Spacer()
                                        Picker("Geschlecht", selection: $sex) {
                                            Text("Männlich").tag("male")
                                            Text("Weiblich").tag("female")
                                            Text("Divers").tag("other")
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 220)
                                    }
                                    .padding()
                                    .background(Color(white: 0.12))
                                    .cornerRadius(14)
                                    
                                    HStack {
                                        Text("Gewicht")
                                        Spacer()
                                        Text("\(Int(weightKg)) kg")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.orange)
                                        Stepper("", value: $weightKg, in: 40...200, step: 1)
                                            .labelsHidden()
                                    }
                                    .padding()
                                    .background(Color(white: 0.12))
                                    .cornerRadius(14)
                                    
                                    HStack {
                                        Text("Körpergröße")
                                        Spacer()
                                        Text("\(Int(heightCm)) cm")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.orange)
                                        Stepper("", value: $heightCm, in: 130...230, step: 1)
                                            .labelsHidden()
                                    }
                                    .padding()
                                    .background(Color(white: 0.12))
                                    .cornerRadius(14)
                                }
                                .padding(.horizontal)
                            }
                            
                            // STEP 3: SCHEDULE (DAYS & WEEKS IN 1 ROW)
                            if currentStep == 3 {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("SCHRITT 3: ZEITPLAN")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    
                                    Text("Trainingstage pro Woche")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                    
                                    HStack(spacing: 6) {
                                        ForEach(allWeekdays, id: \.self) { day in
                                            let isSelected = selectedDays.contains(day)
                                            Button(action: {
                                                if isSelected {
                                                    if selectedDays.count > 1 { selectedDays.remove(day) }
                                                } else {
                                                    selectedDays.insert(day)
                                                }
                                            }) {
                                                Text(day)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(isSelected ? Color.orange : Color(white: 0.16))
                                                    .foregroundColor(isSelected ? .black : .white)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                    
                                    Text("Plan-Laufzeit")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                    
                                    HStack(spacing: 8) {
                                        ForEach([2, 4, 6], id: \.self) { w in
                                            Button(action: { weeks = w }) {
                                                Text("\(w) Wochen")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 10)
                                                    .background(weeks == w ? Color.orange : Color(white: 0.16))
                                                    .foregroundColor(weeks == w ? .black : .white)
                                                    .cornerRadius(12)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // STEP 4: EQUIPMENT (WITH ALL CHIP)
                            if currentStep == 4 {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("SCHRITT 4: VERFÜGBARES EQUIPMENT")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    
                                    VStack(spacing: 8) {
                                        Button(action: { selectedEquipment.removeAll() }) {
                                            HStack {
                                                Text("Alles (Komplettes Gym)")
                                                    .font(.system(size: 14, weight: .bold))
                                                Spacer()
                                                if selectedEquipment.isEmpty {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            .padding()
                                            .background(selectedEquipment.isEmpty ? Color.orange.opacity(0.15) : Color(white: 0.12))
                                            .foregroundColor(selectedEquipment.isEmpty ? .orange : .white)
                                            .cornerRadius(12)
                                        }
                                        
                                        ForEach(EquipmentType.allCases) { eq in
                                            let isSelected = selectedEquipment.contains(eq)
                                            Button(action: {
                                                if isSelected {
                                                    selectedEquipment.remove(eq)
                                                } else {
                                                    selectedEquipment.insert(eq)
                                                }
                                            }) {
                                                HStack {
                                                    Text(eq.rawValue)
                                                        .font(.system(size: 14, weight: .semibold))
                                                    Spacer()
                                                    if isSelected {
                                                        Image(systemName: "checkmark")
                                                            .foregroundColor(.orange)
                                                    }
                                                }
                                                .padding()
                                                .background(isSelected ? Color.orange.opacity(0.15) : Color(white: 0.12))
                                                .foregroundColor(isSelected ? .orange : .white)
                                                .cornerRadius(12)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // STEP 5: NUTRITION & GENERATE
                            if currentStep == 5 {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("SCHRITT 5: ERNÄHRUNGSFORM")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    
                                    ForEach(DietType.allCases) { d in
                                        Button(action: { diet = d }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(d.titleDe)
                                                        .font(.system(size: 15, weight: .bold))
                                                    Spacer()
                                                    if diet == d {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.orange)
                                                    }
                                                }
                                                Text(d.descriptionDe)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(diet == d ? Color.orange.opacity(0.15) : Color(white: 0.12))
                                            .foregroundColor(diet == d ? .orange : .white)
                                            .cornerRadius(14)
                                        }
                                    }
                                    
                                    Toggle("Aufwärmübungen integrieren", isOn: $includeWarmup)
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding()
                                        .background(Color(white: 0.12))
                                        .cornerRadius(14)
                                }
                                .padding(.horizontal)
                            }
                            
                            // NAVIGATION BUTTONS (NEXT / BACK)
                            HStack(spacing: 12) {
                                if currentStep > 1 {
                                    Button(action: { currentStep -= 1 }) {
                                        Text("Zurück")
                                            .font(.system(size: 15, weight: .bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color(white: 0.18))
                                            .foregroundColor(.white)
                                            .cornerRadius(16)
                                    }
                                }
                                
                                Button(action: {
                                    if currentStep < 5 {
                                        currentStep += 1
                                    } else {
                                        generatePlan()
                                    }
                                }) {
                                    HStack {
                                        if currentStep == 5 {
                                            Image(systemName: "sparkles")
                                            Text("PLAN JETZT GENERIEREN")
                                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        } else {
                                            Text("Weiter")
                                                .font(.system(size: 15, weight: .bold))
                                            Image(systemName: "arrow.right")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.orange)
                                    .foregroundColor(.black)
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private func generatePlan() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let input = AICoachInput(
            goal: goal,
            experience: experience,
            biometrics: UserBiometrics(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg),
            selectedDays: Array(selectedDays).sorted(),
            sessionDurationMinutes: durationMinutes,
            weeks: weeks,
            equipment: selectedEquipment,
            diet: diet,
            includeWarmup: includeWarmup
        )
        
        self.generatedPlan = AICoachService.shared.generatePlan(input: input)
        self.selectedTab = "workout"
    }
}
