import SwiftUI

/*
  Die Uhr während des Trainings.

  Drei Dinge sind gegenüber der alten Fassung anders:

  1. Kein `#if os(watchOS) || canImport(WatchKit)` mehr. Die Datei liegt jetzt
     im watchOS-Ziel; die Bedingung war ohnehin auch auf iOS wahr und hat die
     Ansicht in die iPhone-App gezogen.

  2. Die Pause zählt hier herunter, nicht auf dem iPhone. Übertragen wird das
     Ende als Zeitpunkt. Vorher kamen Restsekunden, die nur bei Zustands-
     wechseln erneuert wurden — der Zähler auf der Uhr stand still.

  3. Sobald das iPhone eine Sitzung meldet, startet die HKWorkoutSession. Erst
     dadurch misst die Uhr durchgehend, erscheint das Training in der
     Fitness-App und füllen sich die Ringe.
*/
struct WatchContentView: View {

    @EnvironmentObject private var sync: WatchSyncManager
    @EnvironmentObject private var workout: WatchWorkoutManager

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if sync.isLiveSessionActive {
                activeSession
            } else {
                idle
            }
        }
        // Die Uhr folgt dem iPhone: Sitzung an -> messen, Sitzung aus ->
        // Training abschließen und in Apple Health ablegen.
        .onChange(of: sync.isLiveSessionActive) { _, isActive in
            if isActive {
                workout.start()
            } else {
                workout.end()
            }
        }
    }

    // MARK: - Laufende Sitzung

    private var activeSession: some View {
        VStack(spacing: 6) {
            if sync.isResting, let endsAt = sync.restEndsAt {
                VStack(spacing: 2) {
                    Text("PAUSE")
                        .font(KraftFont.bebas(13)).tracking(1.5)
                        .foregroundColor(Theme.accent)

                    Text(timerInterval: Date()...endsAt, countsDown: true)
                        .font(KraftFont.mono(30, .bold))
                        .foregroundColor(Theme.text)
                        .monospacedDigit()
                }
            } else {
                VStack(spacing: 2) {
                    Text("SATZ \(sync.currentSet) / \(sync.totalSets)")
                        .font(KraftFont.inter(11, .bold)).tracking(0.8)
                        .foregroundColor(Theme.accent)

                    Text(sync.currentExercise)
                        .font(KraftFont.bebas(18)).tracking(0.7)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
            }

            measurements

            Spacer(minLength: 2)

            Button(action: { sync.completeSetRemotely() }) {
                Text(sync.isResting ? "WEITER" : "FERTIG")
                    .font(KraftFont.bebas(15)).tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .foregroundColor(Theme.bg)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    /// Nur echte Werte. Vor der ersten Messung steht hier ein Strich — keine
    /// Platzhalterzahl, die nach Puls aussieht.
    private var measurements: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.pink)
                Text(workout.heartRate.map(String.init) ?? "–")
                    .font(KraftFont.mono(13, .bold))
                    .foregroundColor(Theme.text)
            }

            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.orange)
                Text("\(Int(workout.activeCalories))")
                    .font(KraftFont.mono(13, .bold))
                    .foregroundColor(Theme.text)
            }
        }
        .opacity(workout.isRunning ? 1 : 0.35)
    }

    // MARK: - Ohne Sitzung

    private var idle: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 26))
                .foregroundColor(Theme.accent)

            Text("KRAFTWÜRFEL")
                .font(KraftFont.bebas(15)).tracking(1)
                .foregroundColor(Theme.text)

            Text(hint)
                .font(KraftFont.inter(10))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var hint: String {
        sync.isCounterpartReachable
            ? "Workout auf dem iPhone starten"
            : "iPhone nicht erreichbar"
    }
}
