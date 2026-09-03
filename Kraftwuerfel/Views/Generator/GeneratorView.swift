import SwiftUI

/*
  Der Workout-Tab: Home-Challenge und eigener Plan.

  Hier stand bis zuletzt auch der Studio-Generator — Split wählen, würfeln,
  Planliste. Der war doppelt: Genau dieselbe Würfelstrecke steht im
  Trainingsplan, wo sie auch hingehört, weil dort der Plan über Wochen
  verfolgt wird. Wer im Studio-Tab würfelte, bekam einen Plan, der nirgends
  weiterlief; wer im Trainingsplan würfelte, bekam denselben Plan mit
  Fortschritt. Zwei Wege zum selben Ergebnis, von denen einer in einer
  Sackgasse endete.

  Übrig bleiben die beiden Wege, die es sonst nirgends gibt: die
  Home-Challenge und der selbst zusammengestellte Plan. Deshalb ist diese
  Ansicht nur noch ein Rahmen um die beiden — die Würfel-Maschinerie
  (ReelController, Split-Auswahl, Planliste) ist mit dem Studio-Tab
  verschwunden.
*/
public struct GeneratorView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var settings = GeneratorSettings.shared

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    /*
      Der gewählte Tab liegt in GeneratorSettings, nicht als @State: SwiftUI
      wirft @State beim Tabwechsel weg, und wer in der Home-Challenge stand,
      kam beim eigenen Plan zurück.
    */
    private var selectedMode: GeneratorMode { settings.mode }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                modeSegmentedControl
                    .padding(.horizontal, selectedMode == .challenge ? 20 : 0)
                    .padding(.bottom, 18)

                switch selectedMode {
                case .challenge:
                    HomeChallengeView(onStartLiveWorkout: onStartLiveWorkout)
                case .builder:
                    PlanBuilderView(onStartLiveWorkout: onStartLiveWorkout)
                }
            }
            .padding(.horizontal, selectedMode == .challenge ? 0 : 20)
            .padding(.vertical, 20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }

    // MARK: - Umschalter

    private var modeSegmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(GeneratorMode.allCases) { mode in
                modeTabButton(mode: mode, title: mode.title(i18n.lang), icon: mode.icon)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func modeTabButton(mode: GeneratorMode, title: String, icon: String) -> some View {
        let isSelected = selectedMode == mode
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                settings.mode = mode
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(KraftFont.bebas(13.5)).tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? Theme.bg : Theme.muted)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
