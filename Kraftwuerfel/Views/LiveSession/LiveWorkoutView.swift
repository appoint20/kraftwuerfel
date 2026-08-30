import SwiftUI
import Combine

/*
  Portierung von src/components/LiveSession.jsx.

  Die bisherige native Fassung war eine eigene Erfindung: Satz-Pillen,
  zwei Stepper, eine Übungsliste. Das Web hat stattdessen

    - eine Kopfzeile mit Titel, Uhr und Schließen
    - eine Gesundheitskarte mit Puls, Zone, Verlaufskurve, Dauer/Kalorien/Volumen
    - eine Segmentleiste über alle Übungen
    - einen Umschalter zwischen "Fokus" und "Satz-Protokoll"

  Puls und Kalorien haben zwei Quellen, und die Ansicht sagt immer, welche
  gerade gilt:

    - Liegt eine Apple Watch bei, kommen echte Sensorwerte (WatchWorkoutManager
      misst, WatchSyncManager reicht sie durch). Dann steht „Apple Watch“ daran.
    - Sonst rechnet `estimateTick` weiter wie im Web, und daneben steht
      „geschätzt“ — plus der Hinweis, dass ein Sensor echte Werte liefert.

  Geschätzte Werte gehen weder nach Apple Health noch als Messwert auf den
  Sperrbildschirm. Das war der Ablehnungsgrund, nicht die Schätzung selbst.
*/

/// Ein protokollierter Satz — entspricht loggedSets[exercise][set] im Web.
private struct SetEntry: Equatable {
    var weight: Double
    var reps: Int
    var done: Bool
}

public struct LiveWorkoutView: View {
    @ObservedObject private var i18n = I18n.shared

    public let slots: [ExerciseSlot]
    public let planTitle: String
    public var onNavigateToProgress: (() -> Void)?
    public var onFinish: (() -> Void)?

    // MARK: - Zustand

    @State private var mode: String = "fokus"          // "fokus" | "protokoll"
    /*
      Die Reihenfolge, in der die Übungen abgearbeitet werden — als Liste von
      Plätzen in `slots`, nicht als fester Durchlauf von 0 bis n.

      „Überspringen" hieß vorher: der Zeiger springt eine Übung weiter, und
      die übersprungene ist für diese Sitzung verloren. Im Studio ist das
      aber der häufigste Fall überhaupt — die Bank ist besetzt, man macht
      etwas anderes und kommt später zurück. Genau das ging nicht.

      Jetzt wandert die übersprungene Übung ans Ende der Reihenfolge, und der
      Rest rückt auf. `position` zeigt in diese Liste, `exerciseIdx` bleibt
      der Platz in `slots` — so bleiben die Schlüssel in `logged` gültig.
    */
    @State private var order: [Int] = []
    @State private var position: Int = 0
    /// Übungen, die einmal weggeschoben wurden. Nur für die Anzeige — im
    /// Protokoll zählt allein, was wirklich abgehakt wurde.
    @State private var deferred: Set<Int> = []
    @State private var setIdx: Int = 0

    @State private var elapsed: Int = 0
    @State private var sessionStart = Date()
    @State private var isResting: Bool = false
    @State private var restDuration: Int = 60
    @State private var restRemaining: Int = 0
    /// Ende der Pause als Zeitpunkt. Uhr und Sperrbildschirm zählen daraus
    /// selbst herunter, statt auf Sekundentakt-Updates zu warten.
    @State private var restEndsAt: Date?

    @State private var heartRate: Double = 128
    @State private var peakHeartRate: Double = 128
    @State private var hrHistory: [Double] = [128]
    @State private var calories: Double = 0
    /// Woher der angezeigte Puls stammt. Steuert das Etikett an der Karte —
    /// und ob überhaupt etwas an den Sperrbildschirm geht.
    @State private var heartRateSource: HeartRateSource = .estimated
    /// ActivityKit drosselt Updates. Der Puls geht deshalb nicht im
    /// Sekundentakt raus, sondern alle paar Sekunden.
    @State private var lastActivityHeartRatePush = Date.distantPast

    @State private var logged: [Int: [Int: SetEntry]] = [:]
    @State private var currentWeight: Double = 20
    @State private var currentReps: Int = 8

    @State private var editingSet: EditingSetData?
    @State private var showWeightPrompt: Bool = false
    @State private var weightPromptInput: String = ""
    @State private var showRepsPrompt: Bool = false
    @State private var repsPromptInput: String = ""

    /// Pausiert die ganze Sitzung — anders als `isResting`, das nur die
    /// kurze Pause zwischen zwei Sätzen ist. Während dieser Zustand steht,
    /// überspringt `tick()` alles: Zeit, Kalorien, Pulsschätzung, Restzeit.
    @State private var isPaused: Bool = false

    @State private var ticker: AnyCancellable?
    @State private var showMusic = false
    @State private var completedLog: WorkoutSessionLog?
    @State private var showEndSessionDialog = false

    /*
      Sperrbildschirm, Uhr und Apple Health hängen an derselben Sitzung. Beim
      Umbau dieser Ansicht waren die Aufrufe verloren gegangen — hier laufen
      sie wieder mit, ohne dass die Manager die Ansicht neu zeichnen lassen
      (kein @ObservedObject: sonst baut der Sekundentakt die View neu auf).
    */
    private var watch: WatchSyncManager { .shared }
    private var health: HealthKitManager { .shared }
    private var liveActivity: ActivityKitManager { .shared }

    public init(
        slots: [ExerciseSlot],
        planTitle: String,
        onNavigateToProgress: (() -> Void)? = nil,
        onFinish: (() -> Void)? = nil
    ) {
        self.slots = slots
        self.planTitle = planTitle
        self.onNavigateToProgress = onNavigateToProgress
        self.onFinish = onFinish
    }

    /// Der Platz in `slots`, auf dem wir gerade stehen.
    private var exerciseIdx: Int {
        order.indices.contains(position) ? order[position] : 0
    }

    private var slot: ExerciseSlot? {
        slots.indices.contains(exerciseIdx) ? slots[exerciseIdx] : nil
    }

    /// Wo eine Übung in der aktuellen Reihenfolge steht.
    private func orderPosition(of slotIndex: Int) -> Int {
        order.firstIndex(of: slotIndex) ?? slotIndex
    }

    /// Nur wegschieben, solange es überhaupt etwas gibt, wohin. Bei der
    /// letzten offenen Übung wäre „später" dieselbe Übung sofort wieder.
    private var canSkipExercise: Bool { LiveQueue.canDefer(order, at: position) }

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let log = completedLog {
                WorkoutCompletionModal(
                    log: log,
                    onNavigateToProgress: {
                        onNavigateToProgress?()
                    },
                    onDismissSession: {
                        onFinish?()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        healthCard
                        segmentBar
                        modeSwitch
                        if mode == "fokus" { fokusView } else { protokollView }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
            }

            AdOverlayModal()
        }
        .animation(.easeInOut(duration: 0.25), value: completedLog != nil)
        .onAppear(perform: start)
        .onDisappear {
            ticker?.cancel()
            liveActivity.end()
            health.stopObservingHeartRate()
            watch.onSetCompletedRemotely = nil
            watch.onPauseToggleRequestedRemotely = nil
            watch.endLiveSession()
        }
        .sheet(isPresented: $showMusic) { MusicPlayerSheet() }
        .confirmationDialog(
            i18n.lang == "en" ? "End Workout" : "Training beenden",
            isPresented: $showEndSessionDialog,
            titleVisibility: .visible
        ) {
            Button(i18n.lang == "en" ? "Finish & Save to Progress" : "Training abschließen & speichern") {
                finish()
            }
            Button(i18n.lang == "en" ? "Discard (Don't save)" : "Abbrechen (ohne Speichern)", role: .destructive) {
                discardWithoutSaving()
            }
            Button(i18n.lang == "en" ? "Continue Workout" : "Weitertrainieren", role: .cancel) {}
        }
        .sheet(item: $editingSet) { data in
            SetEditorSheet(data: data) { newWeight, newReps, isDone in
                if logged[data.exerciseIndex] == nil {
                    logged[data.exerciseIndex] = [:]
                }
                logged[data.exerciseIndex]?[data.setIndex] = SetEntry(weight: newWeight, reps: newReps, done: isDone)
                if data.exerciseIndex == exerciseIdx && data.setIndex == setIdx {
                    currentWeight = newWeight
                    currentReps = newReps
                }
                syncWatch()
            }
        }
        .alert(i18n.lang == "en" ? "Enter Weight (kg)" : "Satz-Gewicht (kg) eintragen", isPresented: $showWeightPrompt) {
            TextField(i18n.lang == "en" ? "e.g. 82.5" : "z. B. 82.5", text: $weightPromptInput)
                .keyboardType(.decimalPad)
            Button("OK") {
                let clean = weightPromptInput.replacingOccurrences(of: ",", with: ".")
                if let val = Double(clean) {
                    currentWeight = max(0, val)
                }
            }
            Button(i18n.t("common.cancel"), role: .cancel) {}
        }
        .alert(i18n.lang == "en" ? "Enter Repetitions" : "Wiederholungen eintragen", isPresented: $showRepsPrompt) {
            TextField(i18n.lang == "en" ? "e.g. 10" : "z. B. 10", text: $repsPromptInput)
                .keyboardType(.numberPad)
            Button("OK") {
                if let val = Int(repsPromptInput) {
                    currentReps = max(1, val)
                }
            }
            Button(i18n.t("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Kopfzeile (.live-header)

    private var header: some View {
        HStack(alignment: .top) {
            // Der Titel gibt nach, nicht die Knopfreihe rechts: ein langer
            // Planname darf die Steuerung nicht aus der Zeile drängen.
            VStack(alignment: .leading, spacing: 2) {
                Text(planTitle.uppercased())
                    .kwStyle(.liveTitle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                // Der Fortschritt zählt die Position in der Reihenfolge —
                // sonst spränge die Anzeige beim Überspringen zurück.
                Text(i18n.t("live.exerciseOf", ["current": "\(position + 1)", "total": "\(slots.count)"]))
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            .layoutPriority(-1)

            Spacer(minLength: 8)

            /*
              Vier Elemente in einer Reihe. Ohne `fixedSize` unten staucht
              SwiftUI die Zeitkapsel so weit zusammen, dass ihr Text
              buchstabenweise umbricht statt einfach breiter zu bleiben —
              genau das ist passiert, als der Pausenknopf dazukam.
            */
            HStack(spacing: 8) {
                headerButton("music.note") { showMusic = true }

                Button(action: togglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isPaused ? Theme.bg : Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(isPaused ? Theme.accent : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isPaused ? Theme.accent : Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i18n.t(isPaused ? "live.resumeSession" : "live.pauseSession"))

                elapsedBadge

                headerButton("xmark") { showEndSessionDialog = true }
            }
        }
    }

    /*
      .live-elapsed-badge — die Uhr läuft weiter sichtbar, auch pausiert.
      Ein ausgeschriebenes „PAUSIERT“ stand hier vorher an ihrer Stelle und
      war zu breit für die Zeile; dass die Sitzung steht, sagen jetzt Symbol
      und Farbe, ohne der Kapsel Platz wegzunehmen.
    */
    private var elapsedBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: isPaused ? "pause.fill" : "clock")
                .font(.system(size: 10, weight: .bold))
            Text(timeString(elapsed))
                .font(KraftFont.mono(12.5, .bold))
                .lineLimit(1)
                .monospacedDigit()
        }
        .fixedSize()
        .foregroundColor(isPaused ? Theme.orange : Theme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().stroke(isPaused ? Theme.orange : Theme.border, lineWidth: 1))
        .accessibilityLabel(isPaused ? i18n.t("live.paused") : i18n.t("live.duration"))
    }

    private func headerButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.muted)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gesundheitskarte

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.pink)
                        Text(i18n.t("live.heartRate"))
                            .font(KraftFont.bebas(13)).tracking(1.5)
                            .foregroundColor(Theme.text)
                        // Das Etikett wechselt mit der Quelle. Ein Messwert
                        // darf nicht als Schätzung durchgehen und umgekehrt
                        // erst recht nicht.
                        Text(i18n.t(isMeasured ? "live.sourceWatch" : "live.estimated"))
                            .font(KraftFont.inter(9.5, .bold))
                            .textCase(.uppercase)
                            .foregroundColor(isMeasured ? Theme.accent : Theme.muted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isMeasured ? Theme.accentDim : Theme.surface2)
                            )
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(Int(heartRate))").font(KraftFont.mono(38, .bold))
                            .foregroundColor(Theme.text)
                        Text("BPM").font(KraftFont.inter(11, .bold))
                            .foregroundColor(Theme.muted)
                    }

                    HStack(spacing: 6) {
                        Circle().fill(zone.color).frame(width: 7, height: 7)
                        Text(zone.name).font(KraftFont.inter(12, .semibold))
                            .foregroundColor(zone.color)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    HeartRateChart(values: hrHistory)
                        .frame(width: 140, height: 46)
                    HStack(spacing: 10) {
                        metricInline("Ø", "\(Int(averageHeartRate))")
                        metricInline("Max", "\(Int(peakHeartRate))")
                    }
                }
            }

            HStack(spacing: 8) {
                statTile("stopwatch", timeString(elapsed), i18n.t("live.duration"), tint: Theme.text)
                statTile("flame.fill", "\(Int(displayCalories))", i18n.t("live.calories"), tint: Color(hex: "FF7849"))
                statTile("dumbbell.fill", "\(totalVolume)", i18n.t("live.volume"), tint: Theme.text)
            }

            // Der Hinweis steht nur da, solange gerechnet statt gemessen wird.
            if !isMeasured {
                Text(i18n.t("live.estimatedNote"))
                    .font(KraftFont.inter(11))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func metricInline(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(KraftFont.inter(10)).foregroundColor(Theme.muted)
            Text(value).font(KraftFont.mono(12, .bold)).foregroundColor(Theme.text)
        }
    }

    private func statTile(_ symbol: String, _ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 12)).foregroundColor(tint)
            Text(value).font(KraftFont.mono(15, .bold)).foregroundColor(Theme.text)
            Text(label).kwStyle(.controlLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Segmentleiste & Umschalter

    private var segmentBar: some View {
        HStack(spacing: 4) {
            /*
              Ein Balken je Übung, in der Reihenfolge, in der sie drankommen —
              nicht in der des Plans. Wer eine Übung wegschiebt, sieht sie
              nach hinten wandern, statt einen Balken zu behalten, der
              plötzlich nicht mehr zu seiner Stelle passt.
            */
            ForEach(order.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < position ? Theme.accent.opacity(0.85)
                          : (i == position ? Theme.accent : Theme.surface2))
                    .frame(height: 4)
                    .shadow(color: i == position ? Theme.accent.opacity(0.6) : .clear, radius: 4)
            }
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeButton("fokus", i18n.t("live.modeFocus"))
            modeButton("protokoll", i18n.t("live.modeLog"))
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func modeButton(_ id: String, _ label: String) -> some View {
        let active = mode == id
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.15)) { mode = id }
        }) {
            Text(label)
                .font(KraftFont.inter(12.5, active ? .bold : .semibold))
                .foregroundColor(active ? Theme.bg : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9).fill(active ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fokus

    @ViewBuilder
    private var fokusView: some View {
        if let slot {
            VStack(spacing: 20) {
                ring

                ExerciseVisual(category: slot.exercise.category, size: 90, compact: false)

                Text("\(i18n.category(slot.exercise.category)) · \(i18n.equipment(slot.exercise.equipment))")
                    .kwStyle(.kwTag)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentDim))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.3), lineWidth: 1))

                VStack(spacing: 6) {
                    Text(i18n.exerciseName(slot.exercise))
                        .font(KraftFont.bebas(36)).tracking(1.44)
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                    Text(i18n.t("live.setOf", ["current": "\(setIdx + 1)", "total": "\(slot.sets)"])
                         + " · " + i18n.t("live.repsTarget", ["reps": slot.reps]))
                        .font(KraftFont.inter(13.5, .medium))
                        .foregroundColor(Theme.muted)
                }

                HStack(spacing: 8) {
                    inputCard(i18n.t("live.weight") + " (kg)") {
                        stepperRow(
                            value: currentWeight,
                            unit: "kg",
                            dec: { currentWeight = max(0, currentWeight - 2.5) },
                            inc: { currentWeight += 2.5 },
                            onTapValue: {
                                weightPromptInput = currentWeight == currentWeight.rounded()
                                    ? "\(Int(currentWeight))"
                                    : String(format: "%.1f", currentWeight)
                                showWeightPrompt = true
                            }
                        )
                    }
                    inputCard(i18n.t("live.reps")) {
                        stepperRow(
                            value: Double(currentReps),
                            unit: "",
                            dec: { currentReps = max(1, currentReps - 1) },
                            inc: { currentReps += 1 },
                            onTapValue: {
                                repsPromptInput = "\(currentReps)"
                                showRepsPrompt = true
                            }
                        )
                    }
                    inputCard(i18n.t("live.last")) {
                        Text(lastSetLabel)
                            .font(KraftFont.mono(14, .bold))
                            .foregroundColor(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                KraftPrimaryButton(i18n.t("live.completeSet"), systemImage: "checkmark") {
                    completeSet()
                }

                HStack(spacing: 9) {
                    quickAction(i18n.t("live.addRest")) { startRest(seconds: restDuration + 30) }
                    if canSkipExercise {
                        quickAction(i18n.t("live.skipExercise")) { deferExercise() }
                    }
                }
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.surface2, lineWidth: 10).frame(width: 220, height: 220)

            if isResting {
                Circle()
                    .trim(from: 0, to: Double(restRemaining) / Double(max(1, restDuration)))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: restRemaining)
            }

            VStack(spacing: 4) {
                Text(isResting ? "\(restRemaining)s" : "\(slot?.restSeconds ?? 60)s")
                    .font(KraftFont.mono(46, .bold))
                    .foregroundColor(isResting ? Theme.accent : Theme.text)
                Text(isResting ? i18n.t("live.rest") : i18n.t("live.target"))
                    .font(KraftFont.bebas(14)).tracking(2.8)
                    .foregroundColor(isResting ? Theme.accent : Theme.muted)
            }
        }
    }

    private func inputCard<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            Text(label).kwStyle(.controlLabel)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func stepperRow(
        value: Double,
        unit: String,
        dec: @escaping () -> Void,
        inc: @escaping () -> Void,
        onTapValue: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 4) {
            miniBtn("minus", dec)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTapValue?()
            }) {
                HStack(spacing: 2) {
                    Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value))
                        .font(KraftFont.mono(15, .bold))
                        .foregroundColor(Theme.text)
                    Image(systemName: "pencil")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.accent.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)

            miniBtn("plus", inc)
        }
    }

    private func miniBtn(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.text)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func quickAction(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(label)
                .font(KraftFont.inter(12.5, .semibold))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Satz-Protokoll

    @ViewBuilder
    private var protokollView: some View {
        if let slot {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i18n.t("live.target"))
                            .font(KraftFont.inter(11, .semibold))
                            .textCase(.uppercase)
                            .foregroundColor(Theme.accent)
                        Text(i18n.exerciseName(slot.exercise))
                            .font(KraftFont.bebas(24)).tracking(0.96)
                            .foregroundColor(Theme.text)
                    }
                    Spacer(minLength: 8)
                    Text(timeString(elapsed))
                        .font(KraftFont.mono(14, .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accentDim))
                        .overlay(Capsule().stroke(Theme.accent, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                setsTable(slot)

                KraftPrimaryButton(i18n.t("live.saveSet", ["n": "\(setIdx + 1)"])) { completeSet() }

                upNext

                quickAction(i18n.t("live.endSession")) { finish() }
            }
        }
    }

    private func setsTable(_ slot: ExerciseSlot) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t("live.set")).frame(width: 44, alignment: .leading)
                Text(i18n.t("live.weight")).frame(maxWidth: .infinity, alignment: .leading)
                Text(i18n.t("live.reps")).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(KraftFont.inter(10, .bold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(Theme.muted)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }

            ForEach(0..<slot.sets, id: \.self) { s in
                let entry = logged[exerciseIdx]?[s]
                let isActive = s == setIdx

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let currentSetWeight = entry?.weight ?? (isActive ? currentWeight : 20.0)
                    let currentSetReps = entry?.reps ?? (isActive ? currentReps : 8)
                    let isSetDone = entry?.done ?? (s < setIdx)

                    editingSet = EditingSetData(
                        exerciseIndex: exerciseIdx,
                        setIndex: s,
                        exerciseName: i18n.exerciseName(slot.exercise),
                        weight: currentSetWeight,
                        reps: currentSetReps,
                        done: isSetDone
                    )
                }) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("\(s + 1)")
                                .font(KraftFont.inter(13.5, .semibold))
                                .foregroundColor(isActive ? Theme.accent : (entry?.done == true ? Theme.accent : Theme.muted))
                            if entry?.done == true {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .frame(width: 44, alignment: .leading)

                        if isActive {
                            boxedValue(currentWeight == currentWeight.rounded()
                                       ? "\(Int(currentWeight))" : String(format: "%.1f", currentWeight))
                            boxedValue("\(currentReps)")
                        } else if let entry, entry.done {
                            Text(entry.weight == entry.weight.rounded()
                                 ? "\(Int(entry.weight))" : String(format: "%.1f", entry.weight))
                                .font(KraftFont.mono(13.5, .bold))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(entry.reps)")
                                .font(KraftFont.mono(13.5, .bold))
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("–").foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                            Text("–").foregroundColor(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.muted.opacity(0.6))
                    }
                    .font(KraftFont.inter(13.5))
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(isActive ? Theme.accentDim : Color.clear)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) {
                    if s < slot.sets - 1 { Rectangle().fill(Theme.surface2).frame(height: 1) }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func boxedValue(_ text: String) -> some View {
        Text(text)
            .font(KraftFont.mono(13.5, .bold))
            .foregroundColor(Theme.text)
            .frame(width: 64)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surface2))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.accent, lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var upNext: some View {
        /*
          Was noch kommt, in der Reihenfolge der Warteschlange. Vorher stand
          hier „alle Plätze nach dem aktuellen" — eine weggeschobene Übung
          wäre damit aus der Liste verschwunden, obwohl sie noch aussteht.
        */
        let rest = LiveQueue.upcoming(order, after: position).compactMap { idx -> (offset: Int, element: ExerciseSlot)? in
            guard slots.indices.contains(idx) else { return nil }
            return (offset: idx, element: slots[idx])
        }
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(i18n.t("live.upNext"))
                VStack(spacing: 6) {
                    ForEach(Array(rest.enumerated()), id: \.element.offset) { queueIdx, entry in
                        let idx = entry.offset
                        let s = entry.element
                        HStack(spacing: 12) {
                            /*
                              Die Nummer zählt die Warteschlange, nicht den
                              Platz im Plan: Nach einem Übersprung stünde
                              sonst „3" über der Übung, die als Nächstes
                              drankommt.
                            */
                            Text("\(position + queueIdx + 2)")
                                .font(KraftFont.inter(11))
                                .foregroundColor(Theme.muted)
                                .frame(width: 18, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 5) {
                                    Text(i18n.exerciseName(s.exercise))
                                        .font(KraftFont.inter(13.5, .semibold))
                                        .foregroundColor(Theme.text)
                                        .lineLimit(1)
                                    // Sichtbar machen, dass sie nicht weg ist,
                                    // sondern wartet.
                                    if deferred.contains(idx) {
                                        Text(i18n.t("live.deferred"))
                                            .font(KraftFont.mono(9, .bold))
                                            .foregroundColor(Theme.orange)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Theme.orange.opacity(0.15)))
                                    }
                                }
                                Text(i18n.category(s.exercise.category))
                                    .font(KraftFont.inter(10.5))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer(minLength: 0)
                            Text("\(s.sets)×\(s.reps)")
                                .font(KraftFont.mono(11.5, .bold))
                                .foregroundColor(Theme.accent)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Werte

    private var zone: (name: String, color: Color) {
        switch heartRate {
        case ..<115:  return (i18n.t("live.zone1"), Theme.muted)
        case ..<135:  return (i18n.t("live.zone2"), Theme.accent)
        case ..<155:  return (i18n.t("live.zone3"), Color(hex: "68D391"))
        case ..<175:  return (i18n.t("live.zone4"), Color(hex: "F6AD55"))
        default:      return (i18n.t("live.zone5"), Color(hex: "FC8181"))
        }
    }

    /// Ob der angezeigte Puls von einem Sensor stammt.
    private var isMeasured: Bool { heartRateSource == .appleWatch }

    /// Gemessen, wenn die Uhr mitläuft — sonst der gerechnete Wert.
    private var displayCalories: Double {
        isMeasured ? (watch.watchActiveCalories ?? calories) : calories
    }

    private var averageHeartRate: Double {
        guard !hrHistory.isEmpty else { return 125 }
        return (hrHistory.reduce(0, +) / Double(hrHistory.count)).rounded()
    }

    private var totalVolume: Int {
        var vol = 0.0
        for (_, sets) in logged {
            for (_, e) in sets where e.done { vol += e.weight * Double(e.reps) }
        }
        return Int(vol.rounded())
    }

    private var lastSetLabel: String {
        if setIdx > 0, let prev = logged[exerciseIdx]?[setIdx - 1], prev.done {
            return prev.weight == prev.weight.rounded() ? "\(Int(prev.weight)) kg" : String(format: "%.1f kg", prev.weight)
        }
        // Letztes Mal aus WorkoutHistoryStore!
        if let slot = slot {
            let exName = i18n.exerciseName(slot.exercise)
            if let past = WorkoutHistoryStore.shared.mostRecentLog(for: exName) {
                let wStr = past.weight == past.weight.rounded() ? "\(Int(past.weight))" : String(format: "%.1f", past.weight)
                return "\(wStr) kg × \(past.reps)"
            }
        }
        return "–"
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Ablauf

    private func start() {
        // Anfangs die Reihenfolge des Plans; Überspringen schiebt darin um.
        if order.isEmpty { order = Array(slots.indices) }
        if let s = slot { restDuration = s.restSeconds }
        sessionStart = Date()

        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in tick() }

        /*
          Nur lesen, und nur die Herzfrequenz. Liegt eine Apple Watch bei,
          schreibt die während des Trainings echte Werte nach Apple Health und
          diese Ansicht liest sie mit. Geschrieben wird von hier aus nichts —
          das übernimmt die Uhr, die auch wirklich misst.
        */
        Task {
            if await health.requestReadAuthorization() {
                await MainActor.run { health.startObservingHeartRate(from: sessionStart) }
            }
        }

        if let slot {
            liveActivity.start(
                planTitle: planTitle,
                exerciseName: i18n.exerciseName(slot.exercise),
                setNumber: setIdx + 1,
                totalSets: slot.sets,
                exerciseIndex: exerciseIdx,
                totalExercises: slots.count,
                language: i18n.lang
            )
        }

        // Die Uhr kann „Satz fertig“ und Pause/Fortsetzen nur ANFRAGEN — das
        // iPhone bleibt die einzige Quelle für beide Zustände und reagiert
        // hier auf die Anfrage genauso, als hätte man selbst gedrückt.
        watch.onSetCompletedRemotely = { completeSet() }
        watch.onSetCompletedWithDataRemotely = { [self] weight, reps in
            completeSet(weight: weight, reps: reps)
        }
        watch.onPauseToggleRequestedRemotely = { togglePause() }
        watch.onSkipRestRequestedRemotely = { skipRest() }

        syncWatch()
    }

    /// Uhr auf den aktuellen Stand bringen — bei jedem Satz-, Pausen- und
    /// Trainingspausen-Wechsel. Pause und Gesamtstart gehen als Zeitpunkt
    /// raus, nicht als Restsekunden oder laufender Zähler: Nachrichten
    /// fließen nur bei Wechseln, ein mitgeschickter Zähler stünde dort still.
    private func syncWatch() {
        guard let slot else { return }
        watch.sendWorkoutUpdate(
            exercise: i18n.exerciseName(slot.exercise),
            set: setIdx + 1,
            totalSets: slot.sets,
            weight: currentWeight,
            reps: currentReps,
            targetReps: slot.reps,
            isRest: isResting,
            restEndsAt: isResting ? restEndsAt : nil,
            restDurationSeconds: slot.restSeconds,
            isPaused: isPaused,
            sessionStartedAt: sessionStart
        )
    }

    /// Pausiert oder setzt die Sitzung fort — vom eigenen Knopf oder auf
    /// Anfrage der Uhr. `tick()` überspringt bei aktivem Zustand jede
    /// Fortschreibung, die Uhr zeigt „PAUSIERT“ statt der laufenden Werte.
    private func togglePause() {
        isPaused.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        syncWatch()
    }

    private func skipRest() {
        guard isResting else { return }
        NotificationManager.shared.cancelRestTimerNotification()
        isResting = false
        restRemaining = 0
        restEndsAt = nil
        liveActivity.endRest()
        syncWatch()
    }

    /*
      Ein Takt pro Sekunde. Erst wird nach echten Messwerten gesehen; nur wenn
      keine vorliegen, rechnet das Modell aus dem Web weiter — und die Karte
      sagt dann auch „geschätzt“.
    */
    private func tick() {
        // Pausiert heißt: nichts läuft weiter — weder Zeit noch Kalorien,
        // Puls oder die Pause zwischen Sätzen.
        guard !isPaused else { return }

        elapsed += 1

        if let measured = watch.freshWatchHeartRate ?? health.freshHeartRate {
            heartRateSource = .appleWatch
            heartRate = Double(measured)
            if let watchCalories = watch.freshWatchActiveCalories {
                calories = watchCalories
            }
        } else {
            heartRateSource = .estimated
            estimateTick()
        }

        peakHeartRate = max(peakHeartRate, heartRate)
        hrHistory.append(heartRate)
        if hrHistory.count > 300 { hrHistory.removeFirst() }

        pushHeartRateToLockScreen()

        if isResting {
            if restRemaining > 1 {
                restRemaining -= 1
                if restRemaining <= 5 {
                    NotificationManager.shared.playCountdownTick(secondsRemaining: restRemaining)
                }
            } else {
                NotificationManager.shared.playRestFinishedCues(language: i18n.lang)
                NotificationManager.shared.cancelRestTimerNotification()
                isResting = false
                restRemaining = 0
                restEndsAt = nil
                liveActivity.endRest()
                syncWatch()
            }
        }
    }

    /// Das Belastungsmodell aus dem Web: der Puls nähert sich einem Zielwert,
    /// die Kalorien laufen je nach Belastung schneller. Ausdrücklich eine
    /// Schätzung — sie wird nirgends gespeichert und nirgends als Messwert
    /// ausgegeben.
    private func estimateTick() {
        let target: Double = isResting ? 105 : 138
        let variation = (sin(Date().timeIntervalSince1970 / 5) * 4).rounded(.down)
        heartRate = (heartRate + (target - heartRate) * 0.08 + variation).rounded()

        let burnPerSec = isResting ? 0.06 : 0.13
        let hrMultiplier = heartRate > 120 ? heartRate / 115 : 1.0
        calories += burnPerSec * hrMultiplier
    }

    /// ActivityKit nimmt keine sekündlichen Updates entgegen. Alle fünf
    /// Sekunden reicht für eine Zahl, die sich langsam bewegt.
    private func pushHeartRateToLockScreen() {
        guard Date().timeIntervalSince(lastActivityHeartRatePush) >= 5 else { return }
        lastActivityHeartRatePush = Date()
        liveActivity.setHeartRate(Int(heartRate), source: heartRateSource)
    }

    private func completeSet(weight: Double? = nil, reps: Int? = nil) {
        guard let slot else { return }
        if let weight { currentWeight = weight }
        if let reps { currentReps = reps }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        logged[exerciseIdx, default: [:]][setIdx] =
            SetEntry(weight: currentWeight, reps: currentReps, done: true)

        if setIdx < slot.sets - 1 {
            setIdx += 1
            startRest(seconds: slot.restSeconds)
        } else {
            nextExercise()
        }
        syncWatch()
    }

    /*
      Die aktuelle Übung ans Ende schieben.

      Der Zeiger bleibt stehen, wo er ist — dadurch rückt die nächste Übung
      auf diesen Platz und die weggeschobene wartet am Ende. Angefangene
      Sätze bleiben in `logged` stehen; wer zurückkommt, macht dort weiter,
      wo er aufgehört hat, statt von vorn anzufangen.

      Ohne Pause danach: Die Bank ist besetzt, der Nutzer will sofort
      weitermachen, nicht erst 60 Sekunden warten.
    */
    private func deferExercise() {
        guard canSkipExercise else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let moved = order[position]
        order = LiveQueue.deferring(order, at: position)
        deferred.insert(moved)

        // `setIdx` gehört zur Übung, nicht zum Platz: Die neue Übung an
        // dieser Stelle fängt bei ihrem ersten offenen Satz an.
        setIdx = firstOpenSet(for: exerciseIdx)
        skipRest()
        syncWatch()
    }

    /// Der erste Satz, der für diese Übung noch nicht abgehakt ist.
    private func firstOpenSet(for slotIndex: Int) -> Int {
        guard slots.indices.contains(slotIndex) else { return 0 }
        let done = logged[slotIndex] ?? [:]
        return LiveQueue.firstOpenSet(totalSets: slots[slotIndex].sets) { done[$0]?.done == true }
    }

    private func nextExercise() {
        guard let slot else { return }
        if position < order.count - 1 {
            position += 1
            setIdx = firstOpenSet(for: exerciseIdx)
            startRest(seconds: slot.restSeconds)

            // Übergangs-Werbung für Free-User bei Plänen mit >= 6 Übungen
            AdManager.shared.triggerLiveSessionExerciseTransitionAd(exerciseCount: slots.count)
        } else {
            finish()
        }
    }

    private func startRest(seconds: Int) {
        let endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        restDuration = seconds
        restRemaining = seconds
        restEndsAt = endsAt
        isResting = true

        if let slot {
            NotificationManager.shared.scheduleRestCompleteNotification(
                seconds: seconds,
                nextSet: setIdx + 1,
                exerciseName: i18n.exerciseName(slot.exercise),
                language: i18n.lang
            )

            // Sperrbildschirm und Uhr zählen selbst herunter; dafür brauchen sie
            // das Zieldatum, nicht die Restsekunden.
            liveActivity.setActiveSet(
                exerciseName: i18n.exerciseName(slot.exercise),
                setNumber: setIdx + 1,
                totalSets: slot.sets,
                exerciseIndex: exerciseIdx,
                totalExercises: slots.count,
                language: i18n.lang
            )
        }
        liveActivity.startRest(until: endsAt)
        syncWatch()
    }

    private func discardWithoutSaving() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        NotificationManager.shared.cancelRestTimerNotification()
        ticker?.cancel()
        liveActivity.end()
        health.stopObservingHeartRate()
        watch.onSetCompletedRemotely = nil
        watch.onPauseToggleRequestedRemotely = nil
        watch.endLiveSession()
        onFinish?()
    }

    private func finish() {
        NotificationManager.shared.cancelRestTimerNotification()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ticker?.cancel()
        liveActivity.end()
        health.stopObservingHeartRate()
        watch.onSetCompletedRemotely = nil
        watch.onPauseToggleRequestedRemotely = nil
        watch.endLiveSession()

        // 1. Alle absolvierten Sätze & Übungen für das Tagebuch zusammenstellen
        var loggedExercises: [LoggedExercise] = []
        for (idx, s) in slots.enumerated() {
            var sets: [LoggedSet] = []
            for setI in 0..<s.sets {
                if let entry = logged[idx]?[setI] {
                    sets.append(LoggedSet(setIndex: setI, weight: entry.weight, reps: entry.reps, done: entry.done))
                /*
                  Nur Sätze, die der Nutzer wirklich hinter sich hat.

                  Vorher galt „alles vor dem Zeiger ist erledigt". Mit dem
                  Wegschieben stimmt das nicht mehr: Eine übersprungene Übung
                  steht am Ende der Reihenfolge, und wenn die Sitzung endet,
                  bevor sie drankam, wurde sie eben nicht gemacht. Sie als
                  erledigt zu protokollieren wäre eine erfundene Zahl im
                  Trainingsarchiv.
                */
                } else if orderPosition(of: idx) < position || (idx == exerciseIdx && setI < setIdx) {
                    sets.append(LoggedSet(setIndex: setI, weight: currentWeight, reps: currentReps, done: true))
                }
            }
            if !sets.isEmpty {
                loggedExercises.append(LoggedExercise(
                    exerciseId: s.exercise.id,
                    exerciseName: i18n.exerciseName(s.exercise),
                    category: s.exercise.category,
                    sets: sets
                ))
            }
        }

        // Falls noch keine Sätze eingetragen waren, den aktuellen Satz sichern
        if loggedExercises.isEmpty, let slot = slot {
            loggedExercises.append(LoggedExercise(
                exerciseId: slot.exercise.id,
                exerciseName: i18n.exerciseName(slot.exercise),
                category: slot.exercise.category,
                sets: [LoggedSet(setIndex: 0, weight: currentWeight, reps: currentReps, done: true)]
            ))
        }

        let quote = MotivationalQuotes.randomQuote(language: i18n.lang)
        let log = WorkoutHistoryStore.shared.logSession(
            planTitle: planTitle,
            durationSeconds: elapsed,
            peakHeartRate: peakHeartRate > 0 ? peakHeartRate : nil,
            estimatedCalories: calories > 0 ? calories : nil,
            exercises: loggedExercises,
            motivationalQuote: quote
        )

        /*
          Das Training ist durch — beide Erinnerungen hängen genau hier dran:

          - Der Shake in einer halben Stunde. Das ist der Zeitpunkt, an dem
            die Erinnerung Sinn ergibt, nicht ein fester Uhrzeit-Termin.
          - Die Erinnerung für HEUTE fällt weg. Ohne das käme sie am nächsten
            gleichen Wochentag wieder, obwohl das Training längst im Archiv
            steht — und eine Erinnerung an etwas Erledigtes ist der Grund,
            aus dem Leute Benachrichtigungen ganz abschalten.
        */
        NotificationManager.shared.scheduleProteinShakeReminder(language: i18n.lang)
        NotificationManager.shared.cancelWorkoutReminder(on: Date())

        withAnimation(.easeInOut(duration: 0.25)) {
            completedLog = log
        }
    }
}

/// Der Pulsverlauf als schlichte Linie (.live-hr-chart im Web).
private struct HeartRateChart: View {
    let values: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1 else { return }
            let recent = Array(values.suffix(60))
            let lo = recent.min() ?? 0
            let hi = recent.max() ?? 1
            let span = max(1, hi - lo)

            var path = Path()
            for (i, v) in recent.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(max(1, recent.count - 1))
                let y = size.height - (CGFloat((v - lo) / span) * size.height)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(Theme.accent), lineWidth: 2)

            if let last = recent.last {
                let y = size.height - (CGFloat((last - lo) / span) * size.height)
                let dot = Path(ellipseIn: CGRect(x: size.width - 3, y: y - 3, width: 6, height: 6))
                ctx.fill(dot, with: .color(Theme.accent))
            }
        }
    }
}

public struct EditingSetData: Identifiable {
    public var id: Int { setIndex }
    public let exerciseIndex: Int
    public let setIndex: Int
    public let exerciseName: String
    public var weight: Double
    public var reps: Int
    public var done: Bool
}

private struct SetEditorSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    let data: EditingSetData
    let onSave: (Double, Int, Bool) -> Void

    @State private var weight: Double
    @State private var reps: Int
    @State private var done: Bool
    @State private var weightText: String
    @State private var repsText: String

    init(data: EditingSetData, onSave: @escaping (Double, Int, Bool) -> Void) {
        self.data = data
        self.onSave = onSave
        _weight = State(initialValue: data.weight)
        _reps = State(initialValue: data.reps)
        _done = State(initialValue: data.done)
        _weightText = State(initialValue: data.weight == data.weight.rounded() ? "\(Int(data.weight))" : String(format: "%.1f", data.weight))
        _repsText = State(initialValue: "\(data.reps)")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(i18n.lang == "en" ? "Set \(data.setIndex + 1)" : "Satz \(data.setIndex + 1)")
                        .font(KraftFont.bebas(28)).tracking(1.2)
                        .foregroundColor(Theme.text)
                    Text(data.exerciseName)
                        .font(KraftFont.inter(14, .semibold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.top, 10)

                // Gewicht-Sektion mit Direkteingabe & ±2.5 kg Steppern
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("live.weight") + " (kg)")
                        .font(KraftFont.inter(11, .bold))
                        .textCase(.uppercase)
                        .foregroundColor(Theme.muted)

                    HStack(spacing: 8) {
                        Button(action: {
                            weight = max(0, weight - 2.5)
                            weightText = weight == weight.rounded() ? "\(Int(weight))" : String(format: "%.1f", weight)
                        }) {
                            Text("-2.5")
                                .font(KraftFont.inter(13, .bold))
                                .foregroundColor(Theme.text)
                                .frame(width: 54, height: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }

                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(KraftFont.mono(20, .bold))
                            .foregroundColor(Theme.text)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1))
                            .onChange(of: weightText) { newVal in
                                let clean = newVal.replacingOccurrences(of: ",", with: ".")
                                if let val = Double(clean) { weight = max(0, val) }
                            }

                        Button(action: {
                            weight += 2.5
                            weightText = weight == weight.rounded() ? "\(Int(weight))" : String(format: "%.1f", weight)
                        }) {
                            Text("+2.5")
                                .font(KraftFont.inter(13, .bold))
                                .foregroundColor(Theme.text)
                                .frame(width: 54, height: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                // Wdh-Sektion mit Direkteingabe & ±1 Steppern
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("live.reps"))
                        .font(KraftFont.inter(11, .bold))
                        .textCase(.uppercase)
                        .foregroundColor(Theme.muted)

                    HStack(spacing: 8) {
                        Button(action: {
                            reps = max(1, reps - 1)
                            repsText = "\(reps)"
                        }) {
                            Text("-1")
                                .font(KraftFont.inter(13, .bold))
                                .foregroundColor(Theme.text)
                                .frame(width: 54, height: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }

                        TextField("1", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(KraftFont.mono(20, .bold))
                            .foregroundColor(Theme.text)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1))
                            .onChange(of: repsText) { newVal in
                                if let val = Int(newVal) { reps = max(1, val) }
                            }

                        Button(action: {
                            reps += 1
                            repsText = "\(reps)"
                        }) {
                            Text("+1")
                                .font(KraftFont.inter(13, .bold))
                                .foregroundColor(Theme.text)
                                .frame(width: 54, height: 44)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface2))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                // Erledigt Toggle
                Toggle(isOn: $done) {
                    Text(i18n.lang == "en" ? "Mark set as completed" : "Satz als abgeschlossen markieren")
                        .font(KraftFont.inter(13.5, .medium))
                        .foregroundColor(Theme.text)
                }
                .tint(Theme.accent)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

                Spacer()

                KraftPrimaryButton(i18n.lang == "en" ? "SAVE CHANGES" : "ÄNDERUNGEN SPEICHERN", systemImage: "checkmark") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let cleanWeight = weightText.replacingOccurrences(of: ",", with: ".")
                    let finalWeight = Double(cleanWeight) ?? weight
                    let finalReps = Int(repsText) ?? reps
                    onSave(finalWeight, finalReps, done)
                    dismiss()
                }
            }
            .padding(18)
            .background(Theme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(i18n.t("common.cancel")) { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
