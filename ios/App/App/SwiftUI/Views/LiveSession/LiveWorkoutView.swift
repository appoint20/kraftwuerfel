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
    @State private var globalTimer: AnyCancellable?
    
    public init(slots: [ExerciseSlot], planTitle: String = "Live Workout", onFinish: (() -> Void)? = nil) {
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
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // TOP BAR: Elapsed Time & HealthKit BPM
                HStack {
                    Button(action: { finishWorkout() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(white: 0.18))
                            .clipShape(Circle())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(planTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(formatDuration(elapsedTime))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // Live BPM Indicator
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        Text("\(Int(healthKit.currentHeartRate > 0 ? healthKit.currentHeartRate : 128)) BPM")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if let slot = currentSlot {
                    
                    // EXERCISE HEADER
                    VStack(spacing: 6) {
                        Text("ÜBUNG \(currentExerciseIndex + 1) VON \(slots.count)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.orange)
                        
                        Text(slot.exercise.name)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 8) {
                            Text(slot.exercise.category.localized)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(white: 0.2))
                                .cornerRadius(6)
                                .foregroundColor(.gray)
                            
                            Text(slot.exercise.equipment.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    if isResting {
                        // REST TIMER RING ANIMATION
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color(white: 0.16), lineWidth: 12)
                                    .frame(width: 180, height: 180)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(restSecondsRemaining) / CGFloat(max(1, totalRestSeconds)))
                                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .frame(width: 180, height: 180)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear, value: restSecondsRemaining)
                                
                                VStack(spacing: 4) {
                                    Text("\(restSecondsRemaining)")
                                        .font(.system(size: 52, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("SEKUNDEN PAUSE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: { skipRest() }) {
                                Text("Pause überspringen")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(10)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // WEIGHT & REPS CONTROLS
                        VStack(spacing: 20) {
                            
                            // SET INDICATOR
                            Text("SATZ \(currentSetIndex) VON \(slot.sets)")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color(white: 0.15))
                                .cornerRadius(10)
                            
                            // WEIGHT STEPPER
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("GEWICHT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("\(String(format: "%.1f", currentWeight)) kg")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Button(action: { currentWeight = max(0, currentWeight - 2.5) }) {
                                        Text("-2.5")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color(white: 0.18))
                                            .cornerRadius(12)
                                    }
                                    Button(action: { currentWeight += 2.5 }) {
                                        Text("+2.5")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color(white: 0.18))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(white: 0.12))
                            .cornerRadius(18)
                            .padding(.horizontal)
                            
                            // REPS STEPPER
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("WIEDERHOLUNGEN")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("\(currentReps)")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Button(action: { currentReps = max(1, currentReps - 1) }) {
                                        Image(systemName: "minus")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color(white: 0.18))
                                            .cornerRadius(12)
                                    }
                                    Button(action: { currentReps += 1 }) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color(white: 0.18))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(white: 0.12))
                            .cornerRadius(18)
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    // BOTTOM ACTION BUTTON (COMPLETE SET / NEXT)
                    Button(action: { completeSet() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text(isResting ? "NÄCHSTER SATZ" : "SATZ ABSCHLIESSEN")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(18)
                        .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            startWorkout()
        }
        .onDisappear {
            endWorkout()
        }
    }
    
    private func startWorkout() {
        healthKit.startWorkoutSession()
        globalTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.elapsedTime += 1
            }
    }
    
    private func completeSet() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        guard let slot = currentSlot else { return }
        
        if currentSetIndex < slot.sets {
            // Start rest timer
            totalRestSeconds = slot.restSeconds
            restSecondsRemaining = slot.restSeconds
            isResting = true
            currentSetIndex += 1
            
            // Sync to Apple Watch
            watchSync.sendLiveWorkoutState(
                exerciseName: slot.exercise.name,
                setIndex: currentSetIndex,
                totalSets: slot.sets,
                restRemaining: restSecondsRemaining
            )
            
            timer = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    if self.restSecondsRemaining > 0 {
                        self.restSecondsRemaining -= 1
                    } else {
                        self.skipRest()
                    }
                }
        } else {
            // Next Exercise
            if currentExerciseIndex + 1 < slots.count {
                currentExerciseIndex += 1
                currentSetIndex = 1
                isResting = false
                timer?.cancel()
            } else {
                finishWorkout()
            }
        }
    }
    
    private func skipRest() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        timer?.cancel()
        timer = nil
        isResting = false
    }
    
    private func finishWorkout() {
        endWorkout()
        onFinish?()
    }
    
    private func endWorkout() {
        timer?.cancel()
        timer = nil
        globalTimer?.cancel()
        globalTimer = nil
        healthKit.endWorkoutSession()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
