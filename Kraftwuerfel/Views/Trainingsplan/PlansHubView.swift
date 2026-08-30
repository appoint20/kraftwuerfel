import SwiftUI

/*
  Pläne — alle drei Sichten unter einem Reiter.

  Vorher waren Trainingsplan, Gespeichert und Favoriten drei eigene Reiter.
  Das war die Hälfte der unteren Leiste für Ansichten, die dasselbe zeigen:
  Pläne. Wer von seinem laufenden Plan zu einem gespeicherten wollte, musste
  den Reiter wechseln und verlor dabei, wo er gerade war.

  Der Trainingsplan steht in der Mitte und ist der Startpunkt — das ist die
  Antwort auf „was mache ich heute“. Links liegt, was aufgehoben wurde,
  rechts, was zu den Lieblingen zählt.
*/
public struct PlansHubView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    public enum Section: String, CaseIterable, Identifiable {
        case saved, plan, favorites
        public var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .saved:     return "tabs.saved"
            case .plan:      return "tabs.trainingsplan"
            case .favorites: return "tabs.favorites"
            }
        }

        var icon: String {
            switch self {
            case .saved:     return "bookmark.fill"
            case .plan:      return "calendar"
            case .favorites: return "heart.fill"
            }
        }
    }

    /*
      Die Auswahl überlebt den Reiterwechsel nicht absichtlich: Wer auf
      „Pläne“ tippt, will in aller Regel seinen laufenden Plan sehen. Wäre
      der letzte Stand gespeichert, landete man nach einem Ausflug in die
      Favoriten dort immer wieder.
    */
    @State private var section: Section = .plan

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    public var body: some View {
        VStack(spacing: 0) {
            segmentBar

            Group {
                switch section {
                case .saved:     SavedPlansView(onStartLiveWorkout: onStartLiveWorkout)
                case .plan:      TrainingsplanView(onStartLiveWorkout: onStartLiveWorkout)
                case .favorites: FavoritenView(onStartLiveWorkout: onStartLiveWorkout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var segmentBar: some View {
        HStack(spacing: 6) {
            ForEach(Section.allCases) { s in
                segmentButton(s)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private func segmentButton(_ s: Section) -> some View {
        let isActive = section == s
        // Der Zähler steht nur dort, wo er etwas sagt — eine „0“ neben den
        // Favoriten wäre eine Zahl ohne Aussage.
        let badge: Int? = (s == .favorites && !favorites.favorites.isEmpty)
            ? favorites.favorites.count
            : nil

        return Button(action: {
            guard !isActive else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.18)) { section = s }
        }) {
            HStack(spacing: 5) {
                Image(systemName: s.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(i18n.t(s.titleKey))
                    .font(KraftFont.bebas(13))
                    .tracking(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let badge {
                    Text("\(badge)")
                        .font(KraftFont.mono(9.5, .bold))
                        .foregroundColor(isActive ? Theme.bg : Theme.muted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(isActive ? Theme.bg.opacity(0.22) : Theme.surface2)
                        )
                }
            }
            .foregroundColor(isActive ? Theme.bg : Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isActive ? Theme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(i18n.t(s.titleKey))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
