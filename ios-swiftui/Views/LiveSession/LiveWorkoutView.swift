import SwiftUI
import HealthKit

public struct LiveWorkoutView: View {
    public let dayPlan: DayPlan
    public let onDismiss: () -> Void
    
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(WatchSyncManager.self) private var watchSync
    
    @State private var exerciseIndex: Int = 0
    @State private var setIndex: Int = 0
    @State private var currentWeight: Double = 20.0
    @State private var currentReps: Int = 8
    
    // Timer
    @State private var elapsedSeconds: Int = 0
    @State private var restSecondsRemaining: Int = 0
    @State private var isResting: Bool = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    public init(dayPlan: DayPlan, onDismiss: @escaping () -> Void) {
        self.dayPlan = dayPlan
        self.onDismiss = onDismiss
    }
    
    private var currentSlot: ExerciseSlot {
        guard exerciseIndex < dayPlan.slots.count else { return dayPlan.slots[0] }
        return dayPlan.slots[exerciseIndex]
    }
    
    public var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayPlan.name.uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.accentEmerald)
                        Text("Übung \(exerciseIndex + 1) von \(dayPlan.slots.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    
                    // Live HR & Stopwatch
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill").foregroundColor(.pink).font(.system(size: 12))
                            Text("\(Int(healthKit.currentHeartRate))")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.surfaceDark)
                        .cornerRadius(8)
                        
                        Text(formatTime(elapsedSeconds))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.surfaceDark)
                            .cornerRadius(8)
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.surfaceElevated)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                
                // Rest Ring / Exercise Visual Area
                ZStack {
                    Circle()
                        .stroke(Color.surfaceElevated, lineWidth: 10)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: isResting ? CGFloat(restSecondsRemaining) / CGFloat(currentSlot.restSeconds) : 1.0)
                        .stroke(Color.accentEmerald, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: restSecondsRemaining)
                    
                    VStack(spacing: 6) {
                        if isResting {
                            Text(formatTime(restSecondsRemaining))
                                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                                .foregroundColor(.accentEmerald)
                            Text("PAUSE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.textSecondary)
                        } else {
                            MuscleAnatomyView(category: currentSlot.exercise.category, size: 64)
                            Text(currentSlot.exercise.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                // Steppers (Weight & Reps)
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("GEWICHT (KG)").font(.system(size: 11, weight: .bold)).foregroundColor(.textSecondary)
                        HStack {
                            Button(action: { currentWeight = max(0, currentWeight - 2.5) }) {
                                Text("−").font(.system(size: 20, weight: .bold)).foregroundColor(.white).frame(width: 36, height: 36)
                            }
                            Spacer()
                            Text(String(format: "%.1f", currentWeight))
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { currentWeight += 2.5 }) {
                                Text("+").font(.system(size: 20, weight: .bold)).foregroundColor(.white).frame(width: 36, height: 36)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.surfaceDark)
                        .cornerRadius(12)
                    }
                    
                    VStack(spacing: 8) {
                        Text("WIEDERHOLUNGEN").font(.system(size: 11, weight: .bold)).foregroundColor(.textSecondary)
                        HStack {
                            Button(action: { currentReps = max(1, currentReps - 1) }) {
                                Text("−").font(.system(size: 20, weight: .bold)).foregroundColor(.white).frame(width: 36, height: 36)
                            }
                            Spacer()
                            Text("\(currentReps)")
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { currentReps += 1 }) {
                                Text("+").font(.system(size: 20, weight: .bold)).foregroundColor(.white).frame(width: 36, height: 36)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.surfaceDark)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Complete Set Button
                Button(action: completeSet) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(isResting ? "PAUSE BEENDEN" : "SATZ \(setIndex + 1) ABHAKEN")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentEmerald)
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            healthKit.startWorkoutSession()
            syncWatch()
        }
        .onReceive(timer) { _ in
            elapsedSeconds += 1
            if isResting && restSecondsRemaining > 0 {
                restSecondsRemaining -= 1
            } else if isResting && restSecondsRemaining == 0 {
                isResting = false
            }
            syncWatch()
        }
    }
    
    private func completeSet() {
        if isResting {
            isResting = false
            return
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if setIndex + 1 < currentSlot.sets {
            setIndex += 1
            restSecondsRemaining = currentSlot.restSeconds
            isResting = true
        } else if exerciseIndex + 1 < dayPlan.slots.count {
            exerciseIndex += 1
            setIndex = 0
            restSecondsRemaining = currentSlot.restSeconds
            isResting = true
        } else {
            // Workout Complete
            Task {
                await healthKit.endWorkoutSession(totalVolumeKg: 1200)
                onDismiss()
            }
        }
        syncWatch()
    }
    
    private func syncWatch() {
        watchSync.sendLiveWorkoutState(
            exerciseName: currentSlot.exercise.name,
            setNumber: setIndex + 1,
            totalSets: currentSlot.sets,
            weightKg: currentWeight,
            reps: currentReps,
            isResting: isResting,
            restSecondsRemaining: restSecondsRemaining,
            calories: Int(healthKit.activeCaloriesBurned),
            heartRate: Int(healthKit.currentHeartRate)
        )
    }
    
    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}
