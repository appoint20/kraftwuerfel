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
    @State private var viewingCycle: Int = 1
    @State private var activeWeek: Int = 1
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
        VStack(spacing: 0) {
            
            if let plan = generatedPlan {
                // PLAN VIEW MODE (WORKOUT vs NUTRITION)
                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedTab = "workout"
                        }) {
                            HStack {
                                Image(systemName: "dumbbell.fill")
                                Text("Trainingsplan")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedTab == "workout" ? Theme.accent : Theme.surface)
                            .foregroundColor(selectedTab == "workout" ? Theme.bg : Theme.text)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedTab == "workout" ? Theme.accent : Theme.border, lineWidth: 1))
                        }
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedTab = "nutrition"
                        }) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                Text("Meal Guide")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedTab == "nutrition" ? Theme.accent : Theme.surface)
                            .foregroundColor(selectedTab == "nutrition" ? Theme.bg : Theme.text)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedTab == "nutrition" ? Theme.accent : Theme.border, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    if selectedTab == "workout" {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(plan.title)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.text)
                                    Text(plan.summary)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.muted)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                .padding(.horizontal, 20)
                                
                                // CYCLE SELECTOR BANNER
                                HStack {
                                    Button(action: { viewingCycle = 1 }) {
                                        HStack {
                                            Text("Zyklus 1")
                                                .font(.system(size: 13, weight: .bold))
                                            if (activeWeek % 2 == 1) {
                                                Text("AKTIV")
                                                    .font(.system(size: 9, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.accent)
                                                    .foregroundColor(Theme.bg)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(viewingCycle == 1 ? Theme.surface2 : Color.clear)
                                        .foregroundColor(Theme.text)
                                        .cornerRadius(10)
                                    }
                                    
                                    Button(action: { viewingCycle = 2 }) {
                                        HStack {
                                            Text("Zyklus 2")
                                                .font(.system(size: 13, weight: .bold))
                                            if (activeWeek % 2 == 0) {
                                                Text("AKTIV")
                                                    .font(.system(size: 9, weight: .black))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Theme.accent)
                                                    .foregroundColor(Theme.bg)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(viewingCycle == 2 ? Theme.surface2 : Color.clear)
                                        .foregroundColor(Theme.text)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(4)
                                .background(Theme.surface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                                .padding(.horizontal, 20)
                                
                                ForEach(plan.days) { day in
                                    let currentSlots = day.slots(forCycle: viewingCycle)
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(day.weekday)
                                                .font(.system(size: 13, weight: .black))
                                                .foregroundColor(Theme.accent)
                                                .frame(width: 32, height: 32)
                                                .background(Theme.accentDim)
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 6) {
                                                    Text(day.name)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(Theme.text)
                                                    Text("Zyklus \(viewingCycle)")
                                                        .font(.system(size: 11, weight: .heavy))
                                                        .foregroundColor(Theme.accent)
                                                }
                                                Text(day.focus)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.muted)
                                            }
                                            
                                            Spacer()
                                            
                                            if let onStartLiveWorkout = onStartLiveWorkout {
                                                Button(action: {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    onStartLiveWorkout(
                                                        currentSlots,
                                                        "\(day.name) · \(day.weekday) (Zyklus \(viewingCycle))"
                                                    )
                                                }) {
                                                    Image(systemName: "play.fill")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 6)
                                                        .background(Theme.accent)
                                                        .foregroundColor(Theme.bg)
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                        
                                        ForEach(currentSlots) { slot in
                                            HStack {
                                                Text(slot.exercise.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Theme.text)
                                                Spacer()
                                                Text("\(slot.sets) × \(slot.reps)")
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(Theme.accent)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .padding(16)
                                    .background(Theme.surface)
                                    .cornerRadius(16)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                    .padding(.horizontal, 20)
                                }
                                
                                Button(action: {
                                    generatedPlan = nil
                                    currentStep = 1
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("NEUEN PLAN KONFIGURIEREN")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                    }
                                    .foregroundColor(Theme.muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 10)
                        }
                    } else if let nut = plan.nutrition {
                        MealGuideView(nutrition: nut)
                    }
                }
            } else {
                // WIZARD STEPS
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // STEP PROGRESS BAR
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { s in
                                Rectangle()
                                    .fill(s <= currentStep ? Theme.accent : Theme.surface2)
                                    .frame(height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        if currentStep == 1 {
                            step1Goals
                        } else if currentStep == 2 {
                            step2Profile
                        } else if currentStep == 3 {
                            step3Schedule
                        } else if currentStep == 4 {
                            step4Equipment
                        } else if currentStep == 5 {
                            step5Diet
                        }
                        
                        // NAVIGATION BUTTONS
                        HStack(spacing: 12) {
                            if currentStep > 1 {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    currentStep -= 1
                                }) {
                                    Text("ZURÜCK")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                                }
                            }
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if currentStep < 5 {
                                    currentStep += 1
                                } else {
                                    generatePlan()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(currentStep == 5 ? (isGenerating ? "BERECHNE..." : "PLAN GENERIEREN") : "WEITER")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                    if currentStep < 5 {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .foregroundColor(Theme.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accent)
                                .cornerRadius(12)
                                .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }
    
    // STEP 1: GOAL & EXPERIENCE
    private var step1Goals: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SCHRITT 1: DEIN ZIEL")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(TrainingGoal.allCases, id: \.self) { g in
                    let isSel = goal == g
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        goal = g
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.titleDe)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.text)
                                Text(g.titleEn)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                            if isSel {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(14)
                        .background(isSel ? Theme.accentDim : Theme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSel ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // STEP 2: PROFILE
    private var step2Profile: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SCHRITT 2: KÖRPERDATEN")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Geschlecht")
                        .foregroundColor(Theme.text)
                    Spacer()
                    Picker("", selection: $sex) {
                        Text("Männlich").tag("male")
                        Text("Weiblich").tag("female")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                
                HStack {
                    Text("Gewicht")
                        .foregroundColor(Theme.text)
                    Spacer()
                    Stepper("\(Int(weightKg)) kg", value: $weightKg, in: 40...160, step: 1)
                        .foregroundColor(Theme.text)
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                
                HStack {
                    Text("Größe")
                        .foregroundColor(Theme.text)
                    Spacer()
                    Stepper("\(Int(heightCm)) cm", value: $heightCm, in: 130...220, step: 1)
                        .foregroundColor(Theme.text)
                }
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 20)
        }
    }
    
    // STEP 3: SCHEDULE (1-ROW DAYS & WEEKS)
    private var step3Schedule: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SCHRITT 3: TRAININGSTAGE (PRO ZYKLUS)")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            HStack(spacing: 6) {
                ForEach(allWeekdays, id: \.self) { day in
                    let isSel = selectedDays.contains(day)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isSel {
                            if selectedDays.count > 1 { selectedDays.remove(day) }
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text(day)
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSel ? Theme.accent : Theme.surface)
                            .foregroundColor(isSel ? Theme.bg : Theme.text)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Text("LAUFZEIT")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                ForEach([2, 4, 6, 8], id: \.self) { w in
                    let isSel = weeks == w
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        weeks = w
                    }) {
                        Text("\(w) Wochen")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSel ? Theme.accent : Theme.surface)
                            .foregroundColor(isSel ? Theme.bg : Theme.text)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSel ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // STEP 4: EQUIPMENT ("ALLES" CHIP)
    private var step4Equipment: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SCHRITT 4: VERFÜGBARES EQUIPMENT")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            let allEq = EquipmentType.allCases
            let isAllSelected = selectedEquipment.count == allEq.count || selectedEquipment.isEmpty
            
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isAllSelected {
                    selectedEquipment = [.bodyweight]
                } else {
                    selectedEquipment = Set(allEq)
                }
            }) {
                HStack {
                    Text("Alles / All Equipment (Gym)")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    if isAllSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.accent)
                    }
                }
                .padding(14)
                .background(isAllSelected ? Theme.accentDim : Theme.surface)
                .foregroundColor(Theme.text)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isAllSelected ? Theme.accent : Theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 20)
        }
    }
    
    // STEP 5: DIET (INCL. LAKTO-VEGETARISCH)
    private var step5Diet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SCHRITT 5: ERNÄHRUNGSFORM")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.muted)
                .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(DietType.allCases, id: \.self) { d in
                    let isSel = diet == d
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        diet = d
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.titleDe)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.text)
                                Text(d.descriptionDe)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                            if isSel {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(14)
                        .background(isSel ? Theme.accentDim : Theme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSel ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func generatePlan() {
        isGenerating = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        let input = AICoachInput(
            goal: goal,
            experience: experience,
            biometrics: UserBiometrics(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg),
            selectedDays: Array(selectedDays),
            sessionDurationMinutes: durationMinutes,
            weeks: weeks,
            equipment: selectedEquipment.isEmpty ? Set(EquipmentType.allCases) : selectedEquipment,
            diet: diet,
            includeWarmup: includeWarmup
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let plan = AICoachService.shared.generatePlan(input: input, language: "de")
            self.generatedPlan = plan
            self.isGenerating = false
            self.onSavePlan?(plan)
        }
    }
}
