import SwiftUI

public enum SplitType: String, CaseIterable, Identifiable {
    case fullBody = "Ganzkörper"
    case pushPullLegs = "Push/Pull/Beine"
    case upperLower = "Ober-/Unterkörper"
    case custom = "Eigene"
    
    public var id: String { rawValue }
    
    public var localizedEn: String {
        switch self {
        case .fullBody: return "Full Body"
        case .pushPullLegs: return "Push/Pull/Legs"
        case .upperLower: return "Upper/Lower"
        case .custom: return "Custom"
        }
    }
}

public enum TrainingMethod: String, CaseIterable, Identifiable {
    case standard = "standard"
    case fiveFourThree = "543"
    case fourFourThree = "443"
    case chestFocus = "brust-fokus"
    case backFocus = "ruecken-fokus"
    case legsFocus = "beine-fokus"
    
    public var id: String { rawValue }
    
    public var titleDe: String {
        switch self {
        case .standard: return "Standard"
        case .fiveFourThree: return "5x4x3"
        case .fourFourThree: return "4x4x3"
        case .chestFocus: return "Brust-Fokus"
        case .backFocus: return "Rücken-Fokus"
        case .legsFocus: return "Beine-Fokus"
        }
    }
    
    public var titleEn: String {
        switch self {
        case .standard: return "Standard"
        case .fiveFourThree: return "5×4×3"
        case .fourFourThree: return "4×4×3"
        case .chestFocus: return "Chest Focus"
        case .backFocus: return "Back Focus"
        case .legsFocus: return "Legs Focus"
        }
    }
}

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
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    
                    // Header Brand
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KRAFTWÜRFEL")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Trainingsplan Generator")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Image(systemName: "dice.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // SPLIT SELECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPLIT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(SplitType.allCases) { split in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedSplit = split
                                    }) {
                                        Text(split.rawValue)
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(selectedSplit == split ? Color.orange : Color(white: 0.16))
                                            .foregroundColor(selectedSplit == split ? .black : .white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // CUSTOM MUSCLES (if selected)
                    if selectedSplit == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ZIELMUSKELN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MuscleCategory.allCases) { muscle in
                                        let isSelected = customMuscles.contains(muscle)
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            if isSelected {
                                                customMuscles.remove(muscle)
                                            } else {
                                                customMuscles.insert(muscle)
                                            }
                                        }) {
                                            Text(muscle.localized)
                                                .font(.system(size: 13, weight: .semibold))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? Color.orange : Color(white: 0.16))
                                                .foregroundColor(isSelected ? .black : .white)
                                                .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // EXERCISE COUNT STEPPER
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ANZAHL ÜBUNGEN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        HStack {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                exerciseCount = max(2, exerciseCount - 1)
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color(white: 0.18))
                                    .cornerRadius(14)
                            }
                            
                            Spacer()
                            
                            Text("\(exerciseCount)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                exerciseCount = min(12, exerciseCount + 1)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Color(white: 0.18))
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.12))
                        .cornerRadius(18)
                        .padding(.horizontal)
                    }
                    
                    // TRAINING METHOD
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRAININGSMETHODE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TrainingMethod.allCases) { m in
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        selectedMethod = m
                                    }) {
                                        Text(m.titleDe)
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(selectedMethod == m ? Color.orange : Color(white: 0.16))
                                            .foregroundColor(selectedMethod == m ? .black : .white)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // REST TIME CHIPS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SATZPAUSE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        HStack(spacing: 10) {
                            ForEach([60, 90, 120, 180], id: \.self) { seconds in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    restSeconds = seconds
                                }) {
                                    Text("\(seconds) s")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(restSeconds == seconds ? Color.orange : Color(white: 0.16))
                                        .foregroundColor(restSeconds == seconds ? .black : .white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // ROLL BUTTON
                    Button(action: rollPlan) {
                        HStack(spacing: 12) {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("PLAN WÜRFELN")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(18)
                        .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    
                    // GENERATED PLAN LIST
                    if !generatedSlots.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("DEIN TRAININGSPLAN")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(generatedSlots.count) Übungen")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                            
                            ForEach(Array(generatedSlots.enumerated()), id: \.offset) { index, slot in
                                HStack(spacing: 14) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                                        .foregroundColor(.orange)
                                        .frame(width: 28, height: 28)
                                        .background(Color.orange.opacity(0.15))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(slot.exercise.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        HStack(spacing: 8) {
                                            Text(slot.exercise.category.localized)
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(white: 0.2))
                                                .cornerRadius(6)
                                                .foregroundColor(.gray)
                                            
                                            Text(slot.exercise.equipment.rawValue)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(slot.sets) × \(slot.reps)")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.orange)
                                        Text("\(slot.restSeconds)s Pause")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.12))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                            
                            // START LIVE WORKOUT BUTTON
                            if let onStartLiveWorkout = onStartLiveWorkout {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    onStartLiveWorkout(generatedSlots, "Gewürfelter Plan")
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("LIVE WORKOUT STARTEN")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.green)
                                    .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private func rollPlan() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        let pool = ExerciseDatabase.all
        var targetMuscles: [MuscleCategory] = []
        
        switch selectedSplit {
        case .fullBody:
            targetMuscles = [.chest, .back, .legs, .shoulders, .biceps, .triceps, .core]
        case .pushPullLegs:
            targetMuscles = [.chest, .shoulders, .triceps, .chest]
        case .upperLower:
            targetMuscles = [.chest, .back, .shoulders, .biceps, .triceps]
        case .custom:
            targetMuscles = Array(customMuscles)
            if targetMuscles.isEmpty { targetMuscles = [.chest, .back, .legs] }
        }
        
        var newSlots: [ExerciseSlot] = []
        for i in 0..<exerciseCount {
            let cat = targetMuscles[i % targetMuscles.count]
            let candidates = pool.filter { $0.category == cat }
            if let ex = candidates.randomElement() {
                newSlots.append(ExerciseSlot(
                    exercise: ex,
                    sets: 3,
                    reps: "8-12",
                    restSeconds: restSeconds
                ))
            }
        }
        
        self.generatedSlots = newSlots
    }
}
