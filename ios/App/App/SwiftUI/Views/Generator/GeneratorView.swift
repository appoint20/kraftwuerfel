import SwiftUI

public struct GeneratorView: View {
    @State private var selectedSplit: SplitType = .fullBody
    @State private var exerciseCount: Int = 6
    @State private var selectedMethod: TrainingMethod = .standard
    @State private var restSeconds: Int = 90
    @State private var customMuscles: Set<MuscleCategory> = [.chest, .back, .legs]
    @State private var generatedSlots: [ExerciseSlot] = []
    @State private var isRolling: Bool = false
    @State private var planName: String = ""
    
    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    
    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // SPLIT CHIPS
                VStack(alignment: .leading, spacing: 8) {
                    Text("SPLIT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SplitType.allCases) { split in
                                let isSelected = selectedSplit == split
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedSplit = split
                                    rollDice()
                                }) {
                                    Text(split.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(isSelected ? Theme.accent : Theme.surface)
                                        .foregroundColor(isSelected ? Theme.bg : Theme.text)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // METHOD CHIPS
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRAININGSMETHODE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TrainingMethod.allCases) { method in
                                let isSelected = selectedMethod == method
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedMethod = method
                                    rollDice()
                                }) {
                                    Text(method.titleDe)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(isSelected ? Theme.accent : Theme.surface)
                                        .foregroundColor(isSelected ? Theme.bg : Theme.text)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // EXERCISE COUNT & REST
                HStack(spacing: 12) {
                    // Count
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ÜBUNGEN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Theme.muted)
                        
                        HStack {
                            Button(action: {
                                if exerciseCount > 3 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    exerciseCount -= 1
                                    rollDice()
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.surface2)
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            Text("\(exerciseCount)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(Theme.accent)
                            
                            Spacer()
                            
                            Button(action: {
                                if exerciseCount < 10 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    exerciseCount += 1
                                    rollDice()
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.text)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.surface2)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(8)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    
                    // Rest
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SATZPAUSE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Theme.muted)
                        
                        HStack {
                            ForEach([60, 90, 120], id: \.self) { sec in
                                let isSel = restSeconds == sec
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    restSeconds = sec
                                }) {
                                    Text("\(sec)s")
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isSel ? Theme.accent : Theme.surface2)
                                        .foregroundColor(isSel ? Theme.bg : Theme.text)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(4)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                
                // ROLL BUTTON
                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    rollDice()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 18, weight: .bold))
                            .rotationEffect(.degrees(isRolling ? 360 : 0))
                        
                        Text(isRolling ? "WÜRFELN..." : "NEUER WORKOUT WÜRFELN")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(1.0)
                    }
                    .foregroundColor(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.accent)
                    .cornerRadius(14)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 3)
                }
                .padding(.horizontal, 20)
                
                // GENERATED PLAN CARD
                if !generatedSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(planName.uppercased())
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.text)
                                Text("\(selectedSplit.rawValue) · \(selectedMethod.titleDe)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                            
                            if let onStart = onStartLiveWorkout {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onStart(generatedSlots, planName)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11))
                                        Text("START")
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                    }
                                    .foregroundColor(Theme.bg)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.accent)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        
                        Divider().background(Theme.border)
                        
                        VStack(spacing: 10) {
                            ForEach(Array(generatedSlots.enumerated()), id: \.offset) { index, slot in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundColor(Theme.accent)
                                        .frame(width: 24, height: 24)
                                        .background(Theme.accentDim)
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(slot.exercise.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Theme.text)
                                        Text("\(slot.exercise.category.localized) · \(slot.exercise.equipment.rawValue)")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.muted)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(slot.sets) × \(slot.reps)")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.accent)
                                }
                                .padding(10)
                                .background(Theme.surface2)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if generatedSlots.isEmpty {
                rollDice()
            }
        }
    }
    
    private func rollDice() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isRolling = true
        }
        
        let pool = ExerciseDatabase.all
        var targetMuscles: [MuscleCategory] = []
        
        switch selectedSplit {
        case .fullBody:
            targetMuscles = [.chest, .back, .legs, .shoulders, .biceps, .triceps, .core]
        case .pushPullLegs:
            targetMuscles = [.chest, .shoulders, .triceps]
        case .upperLower:
            targetMuscles = [.chest, .back, .shoulders, .biceps, .triceps]
        case .custom:
            targetMuscles = Array(customMuscles)
        }
        
        var slots: [ExerciseSlot] = []
        let shuffledMuscles = targetMuscles.shuffled()
        
        for i in 0..<exerciseCount {
            let m = shuffledMuscles[i % shuffledMuscles.count]
            let candidates = pool.filter { $0.category == m }
            if let ex = candidates.randomElement() {
                var sets = 3
                if selectedMethod == .fiveFourThree {
                    if i == 0 { sets = 5 }
                    else if i == 1 { sets = 4 }
                } else if selectedMethod == .fourFourThree {
                    if i == 0 || i == 1 { sets = 4 }
                }
                
                slots.append(ExerciseSlot(
                    exercise: ex,
                    sets: sets,
                    reps: "8-12",
                    restSeconds: restSeconds
                ))
            }
        }
        
        let names = ["Titan", "Vulkan", "Olymp", "Gipfel", "Atlas", "Komet", "Phönix"]
        self.planName = "\(names.randomElement() ?? "Titan") Workout"
        self.generatedSlots = slots
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isRolling = false
        }
    }
}
