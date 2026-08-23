import SwiftUI

public struct SavedWorkoutPlan: Identifiable, Codable {
    public var id = UUID()
    public let name: String
    public let slots: [ExerciseSlot]
    public let savedAt: Date
    
    public init(name: String, slots: [ExerciseSlot], savedAt: Date = Date()) {
        self.name = name
        self.slots = slots
        self.savedAt = savedAt
    }
}

public struct SavedPlansView: View {
    @State private var subTab: String = "workouts" // "workouts" | "nutrition"
    @State private var savedWorkouts: [SavedWorkoutPlan] = [
        SavedWorkoutPlan(
            name: "Hypertrophie Push Express",
            slots: [
                ExerciseSlot(exercise: ExerciseDatabase.all[0], sets: 4, reps: "6-8", restSeconds: 120),
                ExerciseSlot(exercise: ExerciseDatabase.all[1], sets: 3, reps: "8-10", restSeconds: 90),
                ExerciseSlot(exercise: ExerciseDatabase.all[12], sets: 3, reps: "10-12", restSeconds: 60)
            ]
        )
    ]
    @State private var savedMealPlans: [NutritionPlan] = []
    @State private var openPlanId: UUID?
    
    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    
    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                
                // SUB-TAB SWITCHER
                HStack(spacing: 8) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        subTab = "workouts"
                    }) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                            Text("Workouts (\(savedWorkouts.count))")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(subTab == "workouts" ? Theme.accent : Theme.surface)
                        .foregroundColor(subTab == "workouts" ? Theme.bg : Theme.text)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(subTab == "workouts" ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        subTab = "nutrition"
                    }) {
                        HStack {
                            Image(systemName: "leaf.fill")
                            Text("Meal Guides (\(savedMealPlans.count))")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(subTab == "nutrition" ? Theme.accent : Theme.surface)
                        .foregroundColor(subTab == "nutrition" ? Theme.bg : Theme.text)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(subTab == "nutrition" ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // WORKOUTS LIST
                if subTab == "workouts" {
                    if savedWorkouts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.muted)
                            Text("Noch keine Workouts gespeichert")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(savedWorkouts) { plan in
                                let isOpen = openPlanId == plan.id
                                VStack(alignment: .leading, spacing: 0) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        openPlanId = isOpen ? nil : plan.id
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(plan.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Theme.text)
                                                Text("\(plan.slots.count) Übungen")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.muted)
                                            }
                                            Spacer()
                                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Theme.muted)
                                        }
                                        .padding(16)
                                    }
                                    
                                    if isOpen {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Divider().background(Theme.border)
                                            
                                            ForEach(plan.slots) { slot in
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(slot.exercise.name)
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundColor(Theme.text)
                                                        Text("\(slot.exercise.category.localized)")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Theme.muted)
                                                    }
                                                    Spacer()
                                                    Text("\(slot.sets) × \(slot.reps)")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                        .foregroundColor(Theme.accent)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                            
                                            if let onStartLiveWorkout = onStartLiveWorkout {
                                                Button(action: {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    onStartLiveWorkout(plan.slots, plan.name)
                                                }) {
                                                    HStack {
                                                        Image(systemName: "play.fill")
                                                        Text("WORKOUT STARTEN")
                                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                                    }
                                                    .foregroundColor(Theme.bg)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Theme.accent)
                                                    .cornerRadius(12)
                                                    .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 2)
                                                }
                                                .padding(.top, 6)
                                            }
                                        }
                                        .padding([.horizontal, .bottom], 16)
                                    }
                                }
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                } else {
                    // MEAL GUIDES LIST
                    if savedMealPlans.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "leaf.circle")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.muted)
                            Text("Noch keine Meal Guides gespeichert")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}
