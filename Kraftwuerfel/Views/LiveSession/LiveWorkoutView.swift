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
    public var onFinish: (() -> Void)?

    // MARK: - Zustand

    @State private var mode: String = "fokus"          // "fokus" | "protokoll"
    @State private var exerciseIdx: Int = 0
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

    @State private var ticker: AnyCancellable?
    @State private var showMusic = false

    /*
      Sperrbildschirm, Uhr und Apple Health hängen an derselben Sitzung. Beim
      Umbau dieser Ansicht waren die Aufrufe verloren gegangen — hier laufen
      sie wieder mit, ohne dass die Manager die Ansicht neu zeichnen lassen
      (kein @ObservedObject: sonst baut der Sekundentakt die View neu auf).
    */
    private var watch: WatchSyncManager { .shared }
    private var health: HealthKitManager { .shared }
    private var liveActivity: ActivityKitManager { .shared }

    public init(slots: [ExerciseSlot], planTitle: String, onFinish: (() -> Void)? = nil) {
        self.slots = slots
        self.planTitle = planTitle
        self.onFinish = onFinish
    }

    private var slot: ExerciseSlot? {
        slots.indices.contains(exerciseIdx) ? slots[exerciseIdx] : nil
    }

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

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
        .onAppear(perform: start)
        .onDisappear { ticker?.cancel() }
        .sheet(isPresented: $showMusic) { MusicPlayerSheet() }
    }

    // MARK: - Kopfzeile (.live-header)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(planTitle.uppercased()).kwStyle(.liveTitle)
                Text(i18n.t("live.exerciseOf", ["current": "\(exerciseIdx + 1)", "total": "\(slots.count)"]))
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)
            }
            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button(action: { showMusic = true }) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                // .live-elapsed-badge
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 11, weight: .bold))
                    Text(timeString(elapsed)).font(KraftFont.mono(12.5, .bold))
                }
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))

                Button(action: finish) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
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
            ForEach(slots.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < exerciseIdx ? Theme.accent.opacity(0.85)
                          : (i == exerciseIdx ? Theme.accent : Theme.surface2))
                    .frame(height: 4)
                    .shadow(color: i == exerciseIdx ? Theme.accent.opacity(0.6) : .clear, radius: 4)
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
                    inputCard(i18n.t("live.weight")) {
                        stepperRow(value: currentWeight, unit: "",
                                   dec: { currentWeight = max(0, currentWeight - 2.5) },
                                   inc: { currentWeight += 2.5 })
                    }
                    inputCard(i18n.t("live.reps")) {
                        stepperRow(value: Double(currentReps), unit: "",
                                   dec: { currentReps = max(1, currentReps - 1) },
                                   inc: { currentReps += 1 })
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
                    quickAction(i18n.t("live.skipExercise")) { nextExercise() }
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

    private func stepperRow(value: Double, unit: String,
                            dec: @escaping () -> Void, inc: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            miniBtn("minus", dec)
            Text(value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value))
                .font(KraftFont.mono(15, .bold))
                .foregroundColor(Theme.text)
                .frame(maxWidth: .infinity)
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
                HStack {
                    Text("\(s + 1)")
                        .font(KraftFont.inter(13.5, .semibold))
                        .foregroundColor(isActive ? Theme.accent : Theme.muted)
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
                }
                .font(KraftFont.inter(13.5))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(isActive ? Theme.accentDim : Color.clear)
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
        let rest = Array(slots.enumerated()).filter { $0.offset > exerciseIdx }
        if !rest.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(i18n.t("live.upNext"))
                VStack(spacing: 6) {
                    ForEach(rest, id: \.offset) { idx, s in
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(KraftFont.inter(11))
                                .foregroundColor(Theme.muted)
                                .frame(width: 18, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(i18n.exerciseName(s.exercise))
                                    .font(KraftFont.inter(13.5, .semibold))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(1)
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
        guard let prev = logged[exerciseIdx]?[max(0, setIdx - 1)], prev.done else { return "–" }
        return "\(Int(prev.weight)) kg"
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Ablauf

    private func start() {
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
        syncWatch()
    }

    /// Uhr auf den aktuellen Stand bringen — bei jedem Satz- und Pausenwechsel.
    /// Die Pause geht als Zeitpunkt raus, nicht als Restsekunden: Nachrichten
    /// fließen nur bei Wechseln, ein mitgeschickter Zähler stünde dort still.
    private func syncWatch() {
        guard let slot else { return }
        watch.sendWorkoutUpdate(
            exercise: i18n.exerciseName(slot.exercise),
            set: setIdx + 1,
            totalSets: slot.sets,
            isRest: isResting,
            restEndsAt: isResting ? restEndsAt : nil
        )
    }

    /*
      Ein Takt pro Sekunde. Erst wird nach echten Messwerten gesehen; nur wenn
      keine vorliegen, rechnet das Modell aus dem Web weiter — und die Karte
      sagt dann auch „geschätzt“.
    */
    private func tick() {
        elapsed += 1

        if let measured = watch.freshWatchHeartRate ?? health.freshHeartRate {
            heartRateSource = .appleWatch
            heartRate = Double(measured)
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
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                isResting = false
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

    private func completeSet() {
        guard let slot else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        logged[exerciseIdx, default: [:]][setIdx] =
            SetEntry(weight: currentWeight, reps: currentReps, done: true)

        watch.completeSetRemotely()

        if setIdx < slot.sets - 1 {
            setIdx += 1
            startRest(seconds: slot.restSeconds)
        } else {
            nextExercise()
        }
    }

    private func nextExercise() {
        guard let slot else { return }
        if exerciseIdx < slots.count - 1 {
            exerciseIdx += 1
            setIdx = 0
            startRest(seconds: slot.restSeconds)
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

        // Sperrbildschirm und Uhr zählen selbst herunter; dafür brauchen sie
        // das Zieldatum, nicht die Restsekunden.
        if let slot {
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

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        ticker?.cancel()
        liveActivity.end()
        health.stopObservingHeartRate()
        watch.endLiveSession()
        onFinish?()
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
