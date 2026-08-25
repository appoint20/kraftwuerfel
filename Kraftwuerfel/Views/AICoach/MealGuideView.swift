import SwiftUI

/*
  Der Ernährungsplan aus dem KI-Coach.

  Zwei Dinge waren hier kaputt:

  1. Gespeichert wurde nie. Der Knopf setzte `showSavedAlert = true` und rief
     danach `onSaveMealPlan?()` auf — einen Rückruf, den der Aufrufer nie
     gesetzt hat. Die Meldung „erfolgreich gesichert“ erschien also immer, und
     abgelegt wurde nichts.

  2. Die Ansicht war fest deutsch: `titleDe`, `descriptionDe` und ein Dutzend
     eingebauter Zeichenketten. Auf Englisch stand hier weiter „Eiweiß“ und
     „MAHLZEITEN-TIMING“.

  Jetzt spricht die Ansicht selbst mit dem Speicher und meldet erst dann
  Erfolg, wenn der Speicher Erfolg meldet.
*/
public struct MealGuideView: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var store = SavedMealGuidesStore.shared

    public let nutrition: NutritionPlan
    /// Vorschlag für den Namen — im KI-Coach der Titel des Plans.
    public var suggestedName: String
    /// Aus der gespeicherten Ansicht heraus gibt es nichts mehr zu speichern.
    public var showsSaveButton: Bool

    @State private var alert: SaveAlert?

    public init(
        nutrition: NutritionPlan,
        suggestedName: String = "",
        showsSaveButton: Bool = true
    ) {
        self.nutrition = nutrition
        self.suggestedName = suggestedName
        self.showsSaveButton = showsSaveButton
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                macrosGrid
                mealScheduleList
                if !nutrition.shakes.isEmpty { shakesList }
                if !nutrition.notes.isEmpty { notesCard }
                if showsSaveButton { saveButton }
                Spacer(minLength: 40)
            }
            .padding(.top, 10)
        }
        .background(Theme.bg.ignoresSafeArea())
        .alert(item: $alert) { $0.alert }
    }

    // MARK: - Kopf

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(nutrition.diet.localized(i18n.lang))
                    .font(KraftFont.inter(13, .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentDim)
                    .foregroundColor(Theme.accent)
                    .cornerRadius(10)

                Spacer()

                Text("\(nutrition.dailyCalories) \(i18n.t("meal.perDay"))")
                    .font(KraftFont.mono(18, .bold))
                    .foregroundColor(Theme.text)
            }

            Text(nutrition.diet.localizedDescription(i18n.lang))
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var macrosGrid: some View {
        HStack(spacing: 12) {
            MacroCard(title: i18n.t("meal.protein"), grams: nutrition.protein,
                      color: Theme.accent, icon: "flame.fill")
            MacroCard(title: i18n.t("meal.carbs"), grams: nutrition.carbs,
                      color: Color(hex: "3B82F6"), icon: "bolt.fill")
            MacroCard(title: i18n.t("meal.fat"), grams: nutrition.fat,
                      color: Color(hex: "F59E0B"), icon: "drop.fill")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Listen

    private var mealScheduleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(i18n.t("meal.timing"))

            ForEach(nutrition.meals) { meal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(meal.time)
                            .font(KraftFont.mono(11, .bold))
                            .foregroundColor(Theme.accent)
                        Spacer()
                        Text("\(meal.calories) kcal")
                            .font(KraftFont.mono(12, .bold))
                            .foregroundColor(Theme.muted)
                    }

                    Text(meal.name)
                        .font(KraftFont.inter(15, .semibold))
                        .foregroundColor(Theme.text)

                    if !meal.items.isEmpty {
                        Text(meal.items.joined(separator: " · "))
                            .font(KraftFont.inter(13))
                            .foregroundColor(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private var shakesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(i18n.t("meal.shakes"))

            ForEach(nutrition.shakes) { shake in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(i18n.t("meal.shakeTag"))
                            .font(KraftFont.mono(10, .bold))
                            .textCase(.uppercase)
                            .foregroundColor(Theme.accent)
                        Spacer()
                        Text(shake.when)
                            .font(KraftFont.inter(11, .semibold))
                            .foregroundColor(Theme.muted)
                    }

                    Text(shake.what)
                        .font(KraftFont.inter(14, .semibold))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.surface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(i18n.t("meal.notes"))
            ForEach(nutrition.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.accent).frame(width: 5, height: 5).padding(.top, 7)
                    Text(note)
                        .font(KraftFont.inter(13))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !nutrition.disclaimer.isEmpty {
                Text(nutrition.disclaimer)
                    .font(KraftFont.inter(11))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Speichern

    private var isSaved: Bool { store.contains(nutrition) }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isSaved ? "checkmark" : "bookmark.fill")
                    .font(.system(size: 14))
                Text(isSaved ? i18n.t("meal.alreadySaved") : i18n.t("meal.save"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .textCase(.uppercase)
            }
            .foregroundColor(isSaved ? Theme.muted : Theme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSaved ? Theme.surface : Theme.accent)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSaved ? Theme.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaved)
        .padding(.horizontal, 20)
    }

    /*
      Die Meldung hängt am Rückgabewert des Speichers, nicht am Tippen. Klappt
      das Schreiben nicht, sagt die Ansicht genau das — inklusive Grund.
    */
    private func save() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard !isSaved else {
            alert = .info(title: i18n.t("meal.alreadySaved"), message: i18n.t("meal.savedBody"))
            return
        }

        if store.save(nutrition: nutrition, name: suggestedName) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            alert = .info(title: i18n.t("meal.savedTitle"), message: i18n.t("meal.savedBody"))
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            alert = .info(
                title: i18n.t("meal.failedTitle"),
                message: i18n.t("meal.failedBody", ["reason": store.lastError ?? ""])
            )
        }
    }
}

/// Kleiner Träger, damit `.alert(item:)` Titel und Text mitbekommt.
public struct SaveAlert: Identifiable {
    public let id = UUID()
    public let title: String
    public let message: String

    public static func info(title: String, message: String) -> SaveAlert {
        SaveAlert(title: title, message: message)
    }

    var alert: Alert {
        Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("OK")))
    }
}

public struct MacroCard: View {
    public let title: String
    public let grams: Int
    public let color: Color
    public let icon: String

    public init(title: String, grams: Int, color: Color, icon: String) {
        self.title = title
        self.grams = grams
        self.color = color
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text("\(grams)g")
                .font(KraftFont.mono(18, .bold))
                .foregroundColor(Theme.text)

            Text(title)
                .font(KraftFont.inter(11, .semibold))
                .foregroundColor(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
