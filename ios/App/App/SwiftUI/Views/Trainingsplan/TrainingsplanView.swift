import SwiftUI

public struct TrainingsplanView: View {
    @State private var selectedDays: Set<String> = ["Mo", "Mi", "Fr"]
    @State private var durationWeeks: Int = 4
    @State private var activeWeek: Int = 1
    @State private var expandedDay: String? = "Mo"
    @State private var viewingCycle: Int = 1 // 1 or 2
    @State private var currentDayPlans: [DayPlan] = []
    
    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?
    
    private let allWeekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    
    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }
    
    private var activeCycleForWeek: Int {
        // Zyklus 1 -> Zyklus 2 -> Zyklus 1 -> Zyklus 2 ...
        return (activeWeek % 2 == 1) ? 1 : 2
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // HEADER
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TRAININGSPLAN")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("Zyklus 1 ➔ Zyklus 2 Periodisierung")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 26))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // TRAINING DAYS SELECTOR
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRAININGSTAGE (TAGE PRO ZYKLUS)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        HStack(spacing: 6) {
                            ForEach(allWeekdays, id: \.self) { day in
                                let isSelected = selectedDays.contains(day)
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if isSelected {
                                        if selectedDays.count > 1 { selectedDays.remove(day) }
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                    regeneratePlans()
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
                        .padding(.horizontal)
                    }
                    
                    // WEEKS ROW
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAN-LAUFZEIT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            ForEach([2, 4, 6, 8], id: \.self) { w in
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    durationWeeks = w
                                    if activeWeek > w { activeWeek = 1 }
                                }) {
                                    Text("\(w) Wochen")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(durationWeeks == w ? Color.orange : Color(white: 0.16))
                                        .foregroundColor(durationWeeks == w ? .black : .white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // WEEKS PROGRESS SELECTOR (WITH CYCLE INDICATION)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("AKTIVE WOCHE & ZYKLUS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text("Woche \(activeWeek) ➔ Zyklus \(activeCycleForWeek)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(1...durationWeeks, id: \.self) { weekNum in
                                    let cycleForW = (weekNum % 2 == 1) ? 1 : 2
                                    Button(action: {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        activeWeek = weekNum
                                        viewingCycle = cycleForW
                                    }) {
                                        VStack(spacing: 2) {
                                            Text("Woche \(weekNum)")
                                                .font(.system(size: 13, weight: .bold))
                                            Text("Zyklus \(cycleForW)")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundColor(activeWeek == weekNum ? .black : .orange)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(activeWeek == weekNum ? Color.orange : Color(white: 0.14))
                                        .foregroundColor(activeWeek == weekNum ? .black : .white)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // CYCLE SWITCHER BANNER
                    HStack {
                        Button(action: { viewingCycle = 1 }) {
                            HStack {
                                Text("Zyklus 1")
                                    .font(.system(size: 13, weight: .bold))
                                if activeCycleForWeek == 1 {
                                    Text("AKTIV")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(viewingCycle == 1 ? Color(white: 0.22) : Color.clear)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: { viewingCycle = 2 }) {
                            HStack {
                                Text("Zyklus 2")
                                    .font(.system(size: 13, weight: .bold))
                                if activeCycleForWeek == 2 {
                                    Text("AKTIV")
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(viewingCycle == 2 ? Color(white: 0.22) : Color.clear)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(4)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // DAY PLANS ACCORDION
                    VStack(spacing: 12) {
                        ForEach(currentDayPlans) { day in
                            let isOpen = expandedDay == day.weekday
                            let currentSlots = day.slots(forCycle: viewingCycle)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Button(action: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    expandedDay = isOpen ? nil : day.weekday
                                }) {
                                    HStack {
                                        Text(day.weekday)
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.orange)
                                            .frame(width: 34, height: 34)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(day.name)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text("Zyklus \(viewingCycle)")
                                                    .font(.system(size: 11, weight: .heavy))
                                                    .foregroundColor(.orange)
                                            }
                                            Text(day.focus)
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
                                        
                                        ForEach(currentSlots) { slot in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(slot.exercise.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                    Text("\(slot.exercise.category.localized) · \(slot.exercise.equipment.rawValue)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.gray)
                                                }
                                                Spacer()
                                                Text("\(slot.sets) × \(slot.reps)")
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(.orange)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        
                                        if let onStartLiveWorkout = onStartLiveWorkout {
                                            Button(action: {
                                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                onStartLiveWorkout(
                                                    currentSlots,
                                                    "\(day.name) · \(day.weekday) (Zyklus \(viewingCycle))"
                                                )
                                            }) {
                                                HStack {
                                                    Image(systemName: "play.fill")
                                                    Text("TRAINING STARTEN (\(day.weekday) · ZYKLUS \(viewingCycle))")
                                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                                }
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(Color.green)
                                                .cornerRadius(12)
                                            }
                                            .padding(.top, 6)
                                        }
                                    }
                                    .padding([.horizontal, .bottom])
                                }
                            }
                            .background(Color(white: 0.12))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                if currentDayPlans.isEmpty {
                    regeneratePlans()
                }
            }
        }
    }
    
    private func regeneratePlans() {
        let pool = ExerciseDatabase.all
        var plans: [DayPlan] = []
        let dayNames = ["Titan", "Vulkan", "Olymp", "Gipfel", "Atlas", "Komet", "Phönix"]
        
        let sortedDays = Array(selectedDays).sorted()
        for (i, day) in sortedDays.enumerated() {
            let name = dayNames[i % dayNames.count]
            var c1Slots: [ExerciseSlot] = []
            var c2Slots: [ExerciseSlot] = []
            
            let targetMuscles: [MuscleCategory] = i % 2 == 0 ? [.chest, .shoulders, .triceps] : [.back, .legs, .biceps]
            for m in targetMuscles {
                let candidates = pool.filter { $0.category == m }.shuffled()
                if let ex1 = candidates.first {
                    c1Slots.append(ExerciseSlot(exercise: ex1, sets: 3, reps: "6-10", restSeconds: 90))
                }
                if candidates.count > 1 {
                    c2Slots.append(ExerciseSlot(exercise: candidates[1], sets: 3, reps: "10-14", restSeconds: 90))
                } else if let ex1 = candidates.first {
                    c2Slots.append(ExerciseSlot(exercise: ex1, sets: 3, reps: "10-14", restSeconds: 90))
                }
            }
            
            plans.append(DayPlan(
                weekday: day,
                name: name,
                focus: targetMuscles.map { $0.localized }.joined(separator: " & "),
                cycle1Slots: c1Slots,
                cycle2Slots: c2Slots
            ))
        }
        
        self.currentDayPlans = plans
        self.expandedDay = sortedDays.first
    }
}
