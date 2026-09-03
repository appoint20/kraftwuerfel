import SwiftUI
import WatchKit

/*
  Die Apple Watch als direkte Trainingssteuerung.

  Ermöglicht das komplette Workout ohne Blick aufs iPhone:
  - Aktuellen Satz und Übung sehen
  - Gewicht anpassen (+/- 2.5 kg)
  - Wiederholungen anpassen (+/- 1)
  - Satz direkt auf der Watch abhaken & speichern
  - Automatischer Pausen-Timer mit sicht- und hörbarem Countdown:
    5 → 4 → 3 → 2 → 1 → LOS!
  - Pausieren/Fortsetzen und Pause überspringen
  - Herzfrequenz und verbrannte Kalorien in Echtzeit
*/
struct WatchContentView: View {

    @ObservedObject private var sync = WatchSyncManager.shared
    @ObservedObject private var workout = WatchWorkoutManager.shared

    @State private var localWeight: Double = 20.0
    @State private var localReps: Int = 10
    @State private var lastHapticSecond: Int = -1
    /// Rückfrage vor dem Beenden — ein Fehlgriff am Handgelenk ist schnell
    /// passiert, und ein versehentlich beendetes Training lässt sich nicht
    /// zurückholen.
    @State private var showsEndConfirmation = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if sync.isLiveSessionActive {
                activeSession
            } else {
                idle
            }
        }
        .onAppear {
            localWeight = sync.currentWeight
            localReps = sync.currentReps
            /*
              Beim Erscheinen nach dem Stand fragen.

              Die Uhr bekam Zustand bisher nur geschickt, wenn sich auf dem
              iPhone etwas änderte. Wer die App hier öffnete, während drüben ein
              Training lief, sah deshalb „Workout auf dem iPhone starten" — bis
              zufällig ein Satz abgehakt wurde.
            */
            sync.requestState()
        }
        .onChange(of: sync.currentExercise) { _ in
            localWeight = sync.currentWeight
            localReps = sync.currentReps
        }
        .onChange(of: sync.currentSet) { _ in
            localWeight = sync.currentWeight
            localReps = sync.currentReps
        }
        // Die Uhr folgt dem iPhone: Sitzung an -> messen, Sitzung aus ->
        // Training abschließen und in Apple Health ablegen.
        .onChange(of: sync.isLiveSessionActive) { isActive in
            if isActive {
                workout.start()
            } else {
                workout.end()
            }
        }
    }

    // MARK: - Laufende Sitzung

    private var activeSession: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                if sync.isPaused {
                    pausedView
                } else if sync.isResting, let endsAt = sync.restEndsAt {
                    restCountdownView(endsAt: endsAt)
                } else {
                    activeSetView
                }

                measurementsBar

                if let startedAt = sync.sessionStartedAt {
                    elapsedRow(startedAt)
                }

                endWorkoutButton
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .onChange(of: sync.isPaused) { paused in
            paused ? workout.pause() : workout.resume()
        }
    }

    // MARK: - Aktiver Satz

    private var activeSetView: some View {
        VStack(spacing: 6) {
            // Satz & Übungskopf
            HStack {
                Text("SATZ \(sync.currentSet)/\(sync.totalSets)")
                    .font(KraftFont.mono(10.5, .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accentDim)
                    .foregroundColor(Theme.accent)
                    .cornerRadius(6)

                Spacer()

                Button(action: { sync.requestPauseToggle() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 24, height: 20)
                        .background(Theme.surface2)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            Text(sync.currentExercise)
                .font(KraftFont.bebas(16)).tracking(0.6)
                .foregroundColor(Theme.text)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Gewicht Stepper
            HStack(spacing: 4) {
                stepperButton(systemName: "minus", delta: -2.5) {
                    localWeight = max(0, localWeight - 2.5)
                }

                VStack(spacing: 0) {
                    Text(localWeight == localWeight.rounded() ? "\(Int(localWeight)) kg" : String(format: "%.1f kg", localWeight))
                        .font(KraftFont.mono(13.5, .bold))
                        .foregroundColor(Theme.text)
                    Text("GEWICHT")
                        .font(KraftFont.inter(7.5, .bold))
                        .foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Theme.surface)
                .cornerRadius(7)

                stepperButton(systemName: "plus", delta: 2.5) {
                    localWeight += 2.5
                }
            }

            // Wiederholungen Stepper
            HStack(spacing: 4) {
                stepperButton(systemName: "minus", delta: -1) {
                    localReps = max(1, localReps - 1)
                }

                VStack(spacing: 0) {
                    Text("\(localReps) Wdh")
                        .font(KraftFont.mono(13.5, .bold))
                        .foregroundColor(Theme.text)
                    Text(sync.targetReps.isEmpty ? "REPS" : "ZIEL: \(sync.targetReps)")
                        .font(KraftFont.inter(7.5, .bold))
                        .foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Theme.surface)
                .cornerRadius(7)

                stepperButton(systemName: "plus", delta: 1) {
                    localReps += 1
                }
            }

            // Hauptaktion: Satz abhaken & weiter
            Button(action: completeSetOnWatch) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("SATZ ABHAKEN")
                        .font(KraftFont.bebas(15)).tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Theme.accent)
                .foregroundColor(Theme.bg)
                .cornerRadius(9)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func stepperButton(systemName: String, delta: Double, action: @escaping () -> Void) -> some View {
        Button(action: {
            WKInterfaceDevice.current().play(.click)
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 32, height: 28)
                .background(Theme.surface2)
                .cornerRadius(7)
        }
        .buttonStyle(.plain)
    }

    private func completeSetOnWatch() {
        WKInterfaceDevice.current().play(.click)
        sync.completeSetWithData(weight: localWeight, reps: localReps)
    }

    // MARK: - Pausen-Timer mit Countdown (5..1 LOS!)

    private func restCountdownView(endsAt: Date) -> some View {
        TimelineView(.animation(minimumInterval: 0.25, paused: sync.isPaused)) { timeline in
            let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(timeline.date))))

            VStack(spacing: 4) {
                HStack {
                    Text("PAUSE")
                        .font(KraftFont.bebas(12)).tracking(1.5)
                        .foregroundColor(Theme.accent)
                    Spacer()
                    Text("NÄCHSTER SATZ")
                        .font(KraftFont.inter(8.5, .semibold))
                        .foregroundColor(Theme.muted)
                }

                if remaining > 5 {
                    // Normaler Pausenzähler
                    Text(formatTimer(remaining))
                        .font(KraftFont.mono(32, .bold))
                        .foregroundColor(Theme.text)
                        .monospacedDigit()
                        .padding(.vertical, 2)
                } else if remaining >= 1 {
                    // Akustischer & visueller 5..1 Countdown
                    VStack(spacing: 1) {
                        Text("\(remaining)")
                            .font(KraftFont.mono(36, .bold))
                            .foregroundColor(Theme.orange)
                            .scaleEffect(1.1)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: remaining)
                        Text("BEREIT MACHEN")
                            .font(KraftFont.bebas(10)).tracking(1.2)
                            .foregroundColor(Theme.orange)
                    }
                    .onAppear { triggerCountdownHaptic(remaining) }
                    .onChange(of: remaining) { sec in
                        triggerCountdownHaptic(sec)
                    }
                } else {
                    // LOS!
                    VStack(spacing: 1) {
                        Text("LOS!")
                            .font(KraftFont.bebas(36)).tracking(2)
                            .foregroundColor(Theme.accent)
                        Text("SATZ STARTET")
                            .font(KraftFont.inter(9, .bold))
                            .foregroundColor(Theme.accent)
                    }
                    .onAppear {
                        triggerFinishedHaptic()
                    }
                }

                // Pause vorzeitig überspringen
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    sync.skipRestPause()
                }) {
                    Text("WEITER")
                        .font(KraftFont.bebas(14)).tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.surface2)
                        .foregroundColor(Theme.text)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(8)
            .background(Theme.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(remaining <= 5 ? Theme.orange.opacity(0.8) : Theme.border, lineWidth: 1))
        }
    }

    private func triggerCountdownHaptic(_ sec: Int) {
        guard sec >= 1, sec <= 5, sec != lastHapticSecond else { return }
        lastHapticSecond = sec
        WKInterfaceDevice.current().play(.directionUp)
    }

    private func triggerFinishedHaptic() {
        guard lastHapticSecond != 0 else { return }
        lastHapticSecond = 0
        WKInterfaceDevice.current().play(.success)
    }

    private func formatTimer(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Pausiert-Ansicht

    private var pausedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "pause.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.orange)

            Text("TRAINING PAUSIERT")
                .font(KraftFont.bebas(15)).tracking(1.2)
                .foregroundColor(Theme.orange)

            Button(action: { sync.requestPauseToggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("FORTSETZEN")
                }
                .font(KraftFont.bebas(14)).tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Theme.accent)
                .foregroundColor(Theme.bg)
                .cornerRadius(9)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Theme.surface)
        .cornerRadius(10)
    }

    // MARK: - Messwerte & Fußzeile

    private var measurementsBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.pink)
                Text(workout.heartRate.map(String.init) ?? "–")
                    .font(KraftFont.mono(11.5, .bold))
                    .foregroundColor(Theme.text)
            }

            Spacer()

            HStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Theme.orange)
                Text("\(Int(workout.activeCalories)) kcal")
                    .font(KraftFont.mono(11.5, .bold))
                    .foregroundColor(Theme.text)
            }
        }
        .padding(.horizontal, 6)
        .opacity(workout.isRunning ? 1 : 0.4)
    }

    private func elapsedRow(_ startedAt: Date) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "stopwatch")
                .font(.system(size: 8))
                .foregroundColor(Theme.muted)
            if startedAt <= Date.distantFuture {
                Text(timerInterval: min(Date(), startedAt)...Date.distantFuture, countsDown: false)
                    .font(KraftFont.mono(10.5, .semibold))
                    .foregroundColor(Theme.muted)
                    .monospacedDigit()
            } else {
                Text("0:00")
                    .font(KraftFont.mono(10.5, .semibold))
                    .foregroundColor(Theme.muted)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Training beenden

    /*
      Beenden von der Uhr aus.

      Bisher ging das nur am iPhone: Wer das Training am Handgelenk führte,
      musste es zum Abschließen wieder hervorholen. Der Knopf steht bewusst
      ganz unten hinter allem anderen — er ist das Seltenste, was man hier tut,
      und das Einzige, was sich nicht rückgängig machen lässt.

      Beendet wird auch hier nicht auf der Uhr: Sie fragt an, das iPhone
      schließt die Einheit ab und schreibt sie ins Archiv. Andernfalls gäbe es
      zwei Stellen, an denen ein Training endet, und zwei Fassungen davon, was
      dabei protokolliert wurde.
    */
    private var endWorkoutButton: some View {
        Button(role: .destructive) {
            WKInterfaceDevice.current().play(.click)
            showsEndConfirmation = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("TRAINING BEENDEN")
                    .font(KraftFont.bebas(12)).tracking(0.8)
            }
            .foregroundColor(Theme.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Theme.surface2)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .confirmationDialog(
            "Training beenden?",
            isPresented: $showsEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("Beenden", role: .destructive) {
                WKInterfaceDevice.current().play(.success)
                sync.requestEndWorkout()
            }
            Button("Weiter trainieren", role: .cancel) {}
        }
    }

    // MARK: - Idle

    private var idle: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.accent)

            Text("KRAFTWÜRFEL")
                .font(KraftFont.bebas(16)).tracking(1.2)
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
