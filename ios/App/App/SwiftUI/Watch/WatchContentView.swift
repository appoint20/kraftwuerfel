import SwiftUI
import Combine

#if os(watchOS) || canImport(WatchKit)
public struct WatchContentView: View {
    @StateObject private var watchSync = WatchSyncManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if watchSync.isLiveSessionActive {
                VStack(spacing: 8) {
                    if watchSync.isResting {
                        VStack(spacing: 4) {
                            Text("PAUSE")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Color(hex: "26E1BE"))
                            
                            Text("\(watchSync.restSecondsRemaining)s")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Text("SATZ \(watchSync.currentSet) / \(watchSync.totalSets)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "26E1BE"))
                            
                            Text(watchSync.currentExercise)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        watchSync.completeSetOnWatch()
                    }) {
                        Text(watchSync.isResting ? "WEITER" : "FERTIG")
                            .font(.system(size: 13, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(hex: "26E1BE"))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "26E1BE"))
                    
                    Text("KRAFTWÜRFEL")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("Workout auf iPhone starten")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }
}
#endif
