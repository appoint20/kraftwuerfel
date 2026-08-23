import SwiftUI
import Combine

@available(iOS 15.0, *)
public struct LiveWorkoutView: View {
    public let slots: [ExerciseSlot]
    public let planTitle: String
    public var onFinish: (() -> Void)?
    
    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var watchSync = WatchSyncManager.shared
    
    @State private var currentExerciseIndex: Int = 0
    @State private var currentSetIndex: Int = 1
    @State private var currentWeight: Double = 60.0
    @State private var currentReps: Int = 10
    @State private var isResting: Bool = false
    @State private var restSecondsRemaining: Int = 90
    @State private var totalRestSeconds: Int = 90
    @State private var timer: AnyCancellable?
    @State private var elapsedTime: Int = 0
    
    public init(slots: [ExerciseSlot], planTitle: String, onFinish: (() -> Void)? = nil) {
        self.slots = slots
        self.planTitle = planTitle
        self.onFinish = onFinish
    }
    
    private var currentSlot: ExerciseSlot? {
        guard currentExerciseIndex < slots.count else { return nil }
        return slots[currentExerciseIndex]
    }
    
    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP BAR
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        stopTimer()
                        onFinish?()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)
                            .padding(10)
                            .background(Theme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(planTitle.uppercased())
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundColor(Theme.text)
                        
                        Text("LIVE WORKOUT SESSION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.accent)
                    }
                    
                    Spacer()
                    
                    // Live BPM Badge
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.red)
                        Text(healthKit.currentHeartRate > 0 ? "\(Int(healthKit.currentHeartRate))" : "--")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(Theme.text)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // REST TIMER RING OR ACTIVE SET CARD
                        if isResting {
                            VStack(spacing: 16) {
                                Text("SATZPAUSE")
                                    .font(.system(size: 12, weight: .black))
                                    .tracking(1.5)
                                    .foregroundColor(Theme.accent)
                                
                                ZStack {
                                    Circle()
                                        .stroke(Theme.surface2, lineWidth: 12)
                                        .frame(width: 170, height: 170)
                                    
                                    Circle()
                                        .trim(from: 0, to: Double(restSecondsRemaining) / Double(max(1, totalRestSeconds)))
                                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                        .frame(width: 170, height: 170)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 1.0), value: restSecondsRemaining)
                                    
                                    VStack(spacing: 4) {
                                        Text("\(restSecondsRemaining)")
                                            .font(.system(size: 48, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.text)
                                        Text("SEKUNDEN")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.muted)
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Button(action: { restSecondsRemaining += 15 }) {
                                        Text("+15s")
                                            .font(.system(size: 12, weight: .bold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Theme.surface2)
                                            .foregroundColor(Theme.text)
                                            .cornerRadius(10)
                                    }
                                    
                                    Button(action: { endRest() }) {
                                        Text("PAUSE BEENDEN")
                                            .font(.system(size: 12, weight: .black))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Theme.accent)
                                            .foregroundColor(Theme.bg)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Theme.surface)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
                            .padding(.horizontal, 20)
                        } else if let slot = currentSlot {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ÜBUNG \(currentExerciseIndex + 1) VON \(slots.count)")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundColor(Theme.accent)
                                            .tracking(1.0)
                                        
                                        Text(slot.exercise.name)
                                            .font(.system(size: 22, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.text)
                                    }
                                    Spacer()
                                    
                                    Text("\(slot.exercise.category.localized)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.text)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Theme.surface2)
                                        .cornerRadius(8)
                                }
                                
                                Divider().background(Theme.border)
                                
                                // SET INDICATOR PILLS
                                HStack(spacing: 8) {
                                    ForEach(1...slot.sets, id: \.self) { s in
                                        let isDone = s < currentSetIndex
                                        let isCurrent = s == currentSetIndex
                                        
                                        HStack {
                                            Text("Satz \(s)")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(isCurrent ? Theme.accent : (isDone ? Theme.accentDim : Theme.surface2))
                                        .foregroundColor(isCurrent ? Theme.bg : (isDone ? Theme.accent : Theme.muted))
                                        .cornerRadius(10)
                                    }
                                }
                                
                                // WEIGHT & REPS STEPPERS
                                HStack(spacing: 12) {
                                    // Weight
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("GEWICHT (KG)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.muted)
                                        
                                        HStack {
                                            Button(action: {
                                                if currentWeight > 2.5 { currentWeight -= 2.5 }
                                            }) {
                                                Image(systemName: "minus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Theme.text)
                                                    .frame(width: 28, height: 28)
                                                    .background(Theme.surface2)
                                                    .cornerRadius(6)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(String(format: "%.1f", currentWeight))
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundColor(Theme.text)
                                            
                                            Spacer()
                                            
                                            Button(action: { currentWeight += 2.5 }) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Theme.text)
                                                    .frame(width: 28, height: 28)
                                                    .background(Theme.surface2)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding(6)
                                        .background(Theme.surface2)
                                        .cornerRadius(10)
                                    }
                                    
                                    // Reps
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("WIEDERHOLUNGEN")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.muted)
                                        
                                        HStack {
                                            Button(action: {
                                                if currentReps > 1 { currentReps -= 1 }
                                            }) {
                                                Image(systemName: "minus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Theme.text)
                                                    .frame(width: 28, height: 28)
                                                    .background(Theme.surface2)
                                                    .cornerRadius(6)
                                            }
                                            
                                            Spacer()
                                            
                                            Text("\(currentReps)")
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundColor(Theme.text)
                                            
                                            Spacer()
                                            
                                            Button(action: { currentReps += 1 }) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Theme.text)
                                                    .frame(width: 28, height: 28)
                                                    .background(Theme.surface2)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        .padding(6)
                                        .background(Theme.surface2)
                                        .cornerRadius(10)
                                    }
                                }
                                
                                // COMPLETE SET BUTTON
                                Button(action: {
                                    completeSet()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("SATZ ABSCHLIESSEN")
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .tracking(0.5)
                                    }
                                    .foregroundColor(Theme.bg)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.accent)
                                    .cornerRadius(12)
                                    .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 2)
                                }
                                .padding(.top, 4)
                            }
                            .padding(20)
                            .background(Theme.surface)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
                            .padding(.horizontal, 20)
                        }
                        
                        // WORKOUT PROGRESS LIST
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ÜBUNGSÜBERSICHT")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(Theme.muted)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 8) {
                                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                                    let isCurrent = index == currentExerciseIndex
                                    let isDone = index < currentExerciseIndex
                                    
                                    HStack(spacing: 12) {
                                        Image(systemName: isDone ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                                            .font(.system(size: 16))
                                            .foregroundColor(isDone ? Theme.green : (isCurrent ? Theme.accent : Theme.muted))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(slot.exercise.name)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(isCurrent ? Theme.text : Theme.muted)
                                            Text("\(slot.sets) Sätze · \(slot.reps) Wdh.")
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.muted)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(isCurrent ? Theme.surface2 : Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isCurrent ? Theme.accent : Theme.border, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            startLiveWorkout()
        }
    }
    
    private func startLiveWorkout() {
        Task {
            _ = await healthKit.requestAuthorization()
            healthKit.startWorkoutSession()
        }
        
        startTimer()
        syncWithWatch()
        
        // Start Lock Screen Live Activity
        if let slot = currentSlot {
            ActivityKitManager.shared.startWorkoutActivity(
                exerciseName: slot.exercise.name,
                setNumber: currentSetIndex,
                totalSets: slot.sets,
                planTitle: planTitle
            )
        }
    }
    
    private func completeSet() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        guard let slot = currentSlot else { return }
        
        if currentSetIndex < slot.sets {
            // Next set in same exercise -> start rest timer
            currentSetIndex += 1
            startRest(seconds: slot.restSeconds)
        } else {
            // Exercise finished -> move to next exercise
            if currentExerciseIndex < slots.count - 1 {
                currentExerciseIndex += 1
                currentSetIndex = 1
                startRest(seconds: slot.restSeconds)
            } else {
                // Whole workout completed!
                finishWorkout()
            }
        }
        
        syncWithWatch()
    }
    
    private func startRest(seconds: Int) {
        isResting = true
        totalRestSeconds = seconds
        restSecondsRemaining = seconds
        
        if let slot = currentSlot {
            ActivityKitManager.shared.updateRestTimer(
                exerciseName: slot.exercise.name,
                setNumber: currentSetIndex,
                restTargetDate: Date().addingTimeInterval(TimeInterval(seconds))
            )
        }
    }
    
    private func endRest() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isResting = false
        
        if let slot = currentSlot {
            ActivityKitManager.shared.updateActiveSet(
                exerciseName: slot.exercise.name,
                setNumber: currentSetIndex,
                totalSets: slot.sets
            )
        }
    }
    
    private func finishWorkout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        stopTimer()
        ActivityKitManager.shared.endWorkoutActivity()
        healthKit.endWorkoutSession()
        onFinish?()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                elapsedTime += 1
                if isResting {
                    if restSecondsRemaining > 1 {
                        restSecondsRemaining -= 1
                    } else {
                        // Rest ended
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        endRest()
                    }
                }
            }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func syncWithWatch() {
        guard let slot = currentSlot else { return }
        watchSync.sendWorkoutUpdate(
            exercise: slot.exercise.name,
            set: currentSetIndex,
            totalSets: slot.sets,
            isRest: isResting,
            restSecondsRemaining: restSecondsRemaining
        )
    }
}
