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
        return (activeWeek % 2 == 1) ? 1 : 2
    }
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                
                // TRAINING DAYS SELECTOR
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRAININGSTAGE (TAGE PRO ZYKLUS)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 20)
                    
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
                                    .background(isSelected ? Theme.accent : Theme.surface)
                                    .foregroundColor(isSelected ? Theme.bg : Theme.text)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // WEEKS ROW
                VStack(alignment: .leading, spacing: 8) {
                    Text("PLAN-LAUFZEIT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 8) {
                        ForEach([2, 4, 6, 8], id: \.self) { w in
                            let isSel = durationWeeks == w
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                durationWeeks = w
                                if activeWeek > w { activeWeek = 1 }
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
                
                // WEEKS PROGRESS SELECTOR (WITH CYCLE INDICATION)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AKTIVE WOCHE & ZYKLUS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(Theme.muted)
                        Spacer()
                        Text("Woche \(activeWeek) ➔ Zyklus \(activeCycleForWeek)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...durationWeeks, id: \.self) { weekNum in
                                let cycleForW = (weekNum % 2 == 1) ? 1 : 2
                                let isSel = activeWeek == weekNum
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
                                            .foregroundColor(isSel ? Theme.bg : Theme.accent)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSel ? Theme.accent : Theme.surface)
                                    .foregroundColor(isSel ? Theme.bg : Theme.text)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSel ? Theme.accent : Theme.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // CYCLE SWITCHER BANNER
                HStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewingCycle = 1
                    }) {
                        HStack {
                            Text("Zyklus 1")
                                .font(.system(size: 13, weight: .bold))
                            if activeCycleForWeek == 1 {
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
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewingCycle = 2
                    }) {
                        HStack {
                            Text("Zyklus 2")
                                .font(.system(size: 13, weight: .bold))
                            if activeCycleForWeek == 2 {
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
                                    
                                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Theme.muted)
                                }
                                .padding(16)
                            }
                            
                            if isOpen {
                                VStack(alignment: .leading, spacing: 10) {
                                    Divider().background(Theme.border)
                                    
                                    ForEach(currentSlots) { slot in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(slot.exercise.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Theme.text)
                                                Text("\(slot.exercise.category.localized) · \(slot.exercise.equipment.rawValue)")
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
                                            onStartLiveWorkout(
                                                currentSlots,
                                                "\(day.name) · \(day.weekday) (Zyklus \(viewingCycle))"
                                            )
                                        }) {
                                            HStack {
                                                Image(systemName: "play.fill")
                                                Text("TRAINING STARTEN (\(day.weekday) · ZYKLUS \(viewingCycle))")
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
                
                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if currentDayPlans.isEmpty {
                regeneratePlans()
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
