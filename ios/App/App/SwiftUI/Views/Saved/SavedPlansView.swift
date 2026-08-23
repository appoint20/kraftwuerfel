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
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GESPEICHERT")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Deine persönlichen Workouts & Ernährungspläne")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // SUB-TAB SWITCHER
                    HStack(spacing: 8) {
                        Button(action: { subTab = "workouts"; openPlanId = nil }) {
                            HStack {
                                Image(systemName: "dumbbell.fill")
                                Text("Trainingspläne (\(savedWorkouts.count))")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(subTab == "workouts" ? Color.orange : Color(white: 0.16))
                            .foregroundColor(subTab == "workouts" ? .black : .white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: { subTab = "nutrition"; openPlanId = nil }) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                Text("Meal Guides (\(savedMealPlans.count))")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(subTab == "nutrition" ? Color.orange : Color(white: 0.16))
                            .foregroundColor(subTab == "nutrition" ? .black : .white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // CONTENT
                    if subTab == "workouts" {
                        if savedWorkouts.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray)
                                Text("Noch keine Trainingspläne gespeichert.")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(savedWorkouts) { plan in
                                let isOpen = openPlanId == plan.id
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        openPlanId = isOpen ? nil : plan.id
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(plan.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text("\(plan.slots.count) Übungen · \(plan.savedAt.formatted(date: .abbreviated, time: .omitted))")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                    }
                                    
                                    if isOpen {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Divider().background(Color(white: 0.2))
                                            
                                            ForEach(plan.slots) { slot in
                                                HStack {
                                                    Text(slot.exercise.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Text("\(slot.sets) × \(slot.reps)")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                        .foregroundColor(.orange)
                                                }
                                                .padding(.vertical, 2)
                                            }
                                            
                                            HStack(spacing: 10) {
                                                if let onStartLiveWorkout = onStartLiveWorkout {
                                                    Button(action: {
                                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                        onStartLiveWorkout(plan.slots, plan.name)
                                                    }) {
                                                        HStack {
                                                            Image(systemName: "play.fill")
                                                            Text("Starten")
                                                                .font(.system(size: 14, weight: .bold))
                                                        }
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 10)
                                                        .background(Color.green)
                                                        .foregroundColor(.black)
                                                        .cornerRadius(10)
                                                    }
                                                }
                                                
                                                Button(action: {
                                                    savedWorkouts.removeAll { $0.id == plan.id }
                                                }) {
                                                    Image(systemName: "trash")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.red)
                                                        .padding(10)
                                                        .background(Color.red.opacity(0.15))
                                                        .cornerRadius(10)
                                                }
                                            }
                                            .padding(.top, 6)
                                        }
                                        .padding([.horizontal, .bottom])
                                    }
                                }
                                .background(Color(white: 0.12))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        if savedMealPlans.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "leaf")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray)
                                Text("Noch keine Ernährungspläne gespeichert.")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(savedMealPlans.enumerated()), id: \.offset) { index, mealPlan in
                                MealGuideView(nutrition: mealPlan)
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
}
