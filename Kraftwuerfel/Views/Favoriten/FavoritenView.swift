import SwiftUI

/*
  Portierung von src/components/FavoritenTab.jsx — dieser Tab fehlte nativ
  komplett.

  Der Plan von heute steht oben: das ist der, den man im Gym aufschlägt.
  Danach geht es in Wochentagsreihenfolge weiter, beginnend beim heutigen Tag.
*/
public struct FavoritenView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var storeKit = StoreKitManager.shared

    @State private var openId: UUID?

    public var onStartLiveWorkout: (([ExerciseSlot], String) -> Void)?

    public init(onStartLiveWorkout: (([ExerciseSlot], String) -> Void)? = nil) {
        self.onStartLiveWorkout = onStartLiveWorkout
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(i18n.t("fav.title"))
                    .padding(.bottom, 10)

                if !storeKit.isProUnlocked && favorites.favorites.isEmpty {
                    premiumGate
                } else if favorites.favorites.isEmpty {
                    EmptyStateBox(i18n.t("fav.empty"), hint: i18n.t("fav.emptyHint"))
                } else {
                    VStack(spacing: 10) {
                        ForEach(favorites.sortedForDisplay) { fav in
                            favoriteCard(fav)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }

    private func favoriteCard(_ fav: FavoriteDayPlan) -> some View {
        let isToday = fav.day == Weekdays.today()
        let planName = PlanNames.planName(for: "\(fav.day):\(fav.split)")
        let title = "\(planName) · \(i18n.weekday(fav.day))"

        var badges = [PlanCardBadge(planName)]
        if isToday { badges.append(PlanCardBadge(i18n.t("fav.today"), filled: true)) }

        var actions: [PlanCardAction] = []
        if let onStartLiveWorkout, let first = fav.cycles.first, !first.isEmpty {
            actions.append(PlanCardAction(i18n.t("live.startTraining"),
                                          systemImage: "play.fill", style: .primary) {
                onStartLiveWorkout(first, title)
            })
        }
        actions.append(PlanCardAction(i18n.t("fav.remove"),
                                      systemImage: "xmark", style: .destructive) {
            favorites.remove(id: fav.id)
        })

        // Dieselbe Karte wie unter „Gespeichert“ — nur mit Zyklen im Inhalt.
        return PlanListCard(
            title: i18n.weekday(fav.day),
            badges: badges,
            meta: metaLine(fav),
            isOpen: openId == fav.id,
            isHighlighted: isToday,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openId = openId == fav.id ? nil : fav.id
                }
            },
            actions: actions
        ) {
            VStack(spacing: 10) {
                ForEach(Array(fav.cycles.enumerated()), id: \.offset) { idx, slots in
                    CycleBlockView(
                        label: i18n.t("tp.cycleLabel", ["n": "\(idx + 1)"]),
                        slots: slots,
                        onStart: slots.isEmpty ? nil : { onStartLiveWorkout?(slots, title) }
                    )
                }
            }
        }
    }

    private func metaLine(_ fav: FavoriteDayPlan) -> String {
        let n = fav.cycles.count
        let plans = i18n.t(n == 1 ? "tp.planCount" : "tp.plansCount", ["n": "\(n)"])
        let df = DateFormatter()
        df.locale = i18n.locale
        df.dateStyle = .short
        return "\(plans) · \(i18n.method(fav.method)) · \(df.string(from: fav.favoritedAt))"
    }


    private var premiumGate: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                Text(i18n.t("pro.badge")).font(KraftFont.bebas(15)).tracking(1.5)
            }
            .foregroundColor(Theme.accent)

            Text(i18n.t("pro.gateText", ["feature": i18n.t("pro.feature.favorites")]))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Theme.accent)
        )
    }
}
