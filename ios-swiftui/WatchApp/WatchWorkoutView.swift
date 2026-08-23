import SwiftUI
import WatchKit

public struct WatchWorkoutView: View {
    @State private var exerciseName: String = "Bankdrücken"
    @State private var setNumber: Int = 1
    @State private var totalSets: Int = 3
    @State private var weightKg: Double = 60.0
    @State private var reps: Int = 10
    @State private var isResting: Bool = false
    @State private var restRemaining: Int = 60
    @State private var calories: Int = 85
    @State private var heartRate: Int = 132
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 6) {
                // Top HR & Elapsed Time
                HStack {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill").foregroundColor(.pink).font(.system(size: 10))
                        Text("\(heartRate)").font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill").foregroundColor(.orange).font(.system(size: 10))
                        Text("\(calories)").font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                
                // Exercise Name
                Text(exerciseName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Set info
                Text("SATZ \(setNumber)/\(totalSets) · \(Int(weightKg))kg × \(reps)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentEmerald)
                
                // Main Ring / Counter
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: isResting ? CGFloat(restRemaining) / 60.0 : 1.0)
                        .stroke(Color.accentEmerald, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Text(isResting ? "\(restRemaining)s" : "\(Int(weightKg)) kg")
                            .font(.system(size: 18, weight: .heavy, design: .monospaced))
                            .foregroundColor(isResting ? .accentEmerald : .white)
                        Text(isResting ? "PAUSE" : "\(reps) WDH")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 75, height: 75)
                .padding(.vertical, 2)
                
                // Action Button with Apple Watch Haptic feedback
                Button(action: handleTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isResting ? "forward.fill" : "checkmark")
                        Text(isResting ? "WEITER" : "FERTIG")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.accentEmerald)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(4)
        }
    }
    
    private func handleTap() {
        WKInterfaceDevice.current().play(.success)
        if isResting {
            isResting = false
        } else {
            isResting = true
            restRemaining = 60
            if setNumber < totalSets {
                setNumber += 1
            }
        }
    }
}
