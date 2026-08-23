import SwiftUI

@Observable
public final class AuthViewModel {
    public var userName: String = "shiv.kumarm98"
    public var isPremium: Bool = true
    public var language: String = "de"
    
    public init() {}
}

public struct MainTabView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var selectedTab: Int = 1 // Defaults to KI-Coach
    @State private var activeLiveSession: DayPlan?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Custom Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentEmerald)
                        Text("KRAFTWÜRFEL")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    if auth.isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentEmerald)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.surfaceDark)
                
                // Tab Selection
                TabView(selection: $selectedTab) {
                    GeneratorPlaceholderView()
                        .tabItem {
                            Label("Generator", systemImage: "dice.fill")
                        }
                        .tag(0)
                    
                    AICoachWizardView()
                        .tabItem {
                            Label("KI-Coach", systemImage: "sparkles")
                        }
                        .tag(1)
                    
                    TrainingsplanPlaceholderView(onStart: { day in
                        activeLiveSession = day
                    })
                    .tabItem {
                        Label("Trainingsplan", systemImage: "calendar")
                    }
                    .tag(2)
                }
            }
        }
        .fullScreenCover(item: $activeLiveSession) { day in
            LiveWorkoutView(dayPlan: day) {
                activeLiveSession = nil
            }
        }
    }
}

private struct GeneratorPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dice.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentEmerald)
            Text("GENERATOR")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text("Würfle dir deinen spontanen Workout-Plan zusammen.")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark)
    }
}

private struct TrainingsplanPlaceholderView: View {
    let onStart: (DayPlan) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(.accentEmerald)
            Text("DEIN AKTIVER PLAN")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Button(action: {
                let sampleDay = DayPlan(
                    weekday: "Mo",
                    name: "Titan",
                    focus: "Chest & Shoulders",
                    slots: [
                        ExerciseSlot(exercise: Exercise(name: "Bankdrücken", nameEn: "Bench Press", category: .chest, equipment: .barbell, isHeavy: true), sets: 3, reps: "8-10"),
                        ExerciseSlot(exercise: Exercise(name: "Schrägbankdrücken (Kurzhantel)", nameEn: "Incline DB Press", category: .chest, equipment: .dumbbell), sets: 3, reps: "10-12")
                    ]
                )
                onStart(sampleDay)
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("LIVE TRAINING STARTEN")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.accentEmerald)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark)
    }
}
