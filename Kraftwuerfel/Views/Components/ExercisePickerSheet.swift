import SwiftUI

/*
  Übung auswählen — aus dem ganzen Katalog, mit Suche und Filtern.

  Gebraucht an zwei Stellen: beim Tauschen einer einzelnen Übung in einem
  fertigen Plan und beim Bauen eines eigenen Plans. Deshalb liegt sie hier und
  nicht in einer der beiden Ansichten.

  `highlightCategories` hebt die Muskelgruppen hervor, die an dieser Stelle
  gemeint sind — beim Tauschen also die des bisherigen Eintrags. Das ist eine
  Vorauswahl, keine Sperre: Wer die Kniebeuge gegen eine Klimmzugstange
  tauschen will, darf das.
*/
public struct ExercisePickerSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    public let title: String
    /// Vorausgewählter Filter, meist die Kategorien der zu ersetzenden Übung.
    public let highlightCategories: [MuscleCategory]
    /// Namen, die schon im Plan stehen — werden markiert, nicht ausgeblendet.
    public let alreadyUsed: Set<String>
    /// Nur diese Geräte zulassen. `nil` heißt: alles.
    public let allowedEquipment: Set<EquipmentType>?
    public let onPick: (Exercise) -> Void

    /*
      Mehrfachauswahl.

      Beim Tauschen einer Übung wird genau eine gewählt und das Blatt schließt.
      Beim Zusammenstellen eines eigenen Workouts wären das aber zehn Mal
      Öffnen und Schließen — dort bleibt das Blatt offen, die Auswahl wird
      abgehakt, und eine Obergrenze begrenzt sie.
    */
    public let isMultiSelect: Bool
    /// Namen der aktuell gewählten Übungen — abgehakt dargestellt.
    public let selectedNames: Set<String>
    /// Obergrenze der Mehrfachauswahl. `nil` heißt: keine.
    public let selectionLimit: Int?

    @State private var query: String = ""
    @State private var category: MuscleCategory?
    @State private var equipment: EquipmentType?

    public init(
        title: String,
        highlightCategories: [MuscleCategory] = [],
        alreadyUsed: Set<String> = [],
        allowedEquipment: Set<EquipmentType>? = nil,
        isMultiSelect: Bool = false,
        selectedNames: Set<String> = [],
        selectionLimit: Int? = nil,
        onPick: @escaping (Exercise) -> Void
    ) {
        self.title = title
        self.highlightCategories = highlightCategories
        self.alreadyUsed = alreadyUsed
        self.allowedEquipment = allowedEquipment
        self.isMultiSelect = isMultiSelect
        self.selectedNames = selectedNames
        self.selectionLimit = selectionLimit
        self.onPick = onPick
        _category = State(initialValue: highlightCategories.first)
    }

    /// Wahr, wenn die Obergrenze erreicht ist — dann lässt sich nur noch abwählen.
    private var isAtLimit: Bool {
        guard isMultiSelect, let selectionLimit else { return false }
        return selectedNames.count >= selectionLimit
    }

    private var pool: [Exercise] {
        var list = ExerciseDatabase.all

        if let allowedEquipment, !allowedEquipment.isEmpty {
            list = list.filter { allowedEquipment.contains($0.equipment) }
        }
        if let category {
            list = list.filter { $0.categories.contains(category) }
        }
        if let equipment {
            list = list.filter { $0.equipment == equipment }
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                $0.nameEn.localizedCaseInsensitiveContains(trimmed)
            }
        }

        /*
          Schon verwendete Übungen rutschen nach unten statt zu verschwinden.
          Ausblenden wäre bevormundend — dieselbe Übung an zwei Tagen ist eine
          legitime Entscheidung.
        */
        return list.sorted { a, b in
            let aUsed = alreadyUsed.contains(a.name)
            let bUsed = alreadyUsed.contains(b.name)
            if aUsed != bUsed { return !aUsed }
            return a.localizedName(language: i18n.lang) < b.localizedName(language: i18n.lang)
        }
    }

    private var availableEquipment: [EquipmentType] {
        guard let allowedEquipment, !allowedEquipment.isEmpty else { return ExerciseDatabase.equipment }
        return ExerciseDatabase.equipment.filter { allowedEquipment.contains($0) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            filters

            if isAtLimit { limitBanner }

            if pool.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KraftFont.bebas(20)).tracking(1)
                    .foregroundColor(Theme.text)

                if isMultiSelect, let selectionLimit {
                    Text("\(selectedNames.count) / \(selectionLimit) " + (i18n.lang == "en" ? "selected" : "gewählt"))
                        .font(KraftFont.mono(11, .bold))
                        .foregroundColor(isAtLimit ? Theme.orange : Theme.accent)
                } else {
                    Text(i18n.t("saved.exercises", ["n": "\(pool.count)"]))
                        .font(KraftFont.mono(11))
                        .foregroundColor(Theme.muted)
                }
            }
            Spacer()
            Button(action: { dismiss() }) {
                if isMultiSelect {
                    Text(i18n.lang == "en" ? "DONE" : "FERTIG")
                        .font(KraftFont.bebas(14)).tracking(1)
                        .foregroundColor(Theme.bg)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(i18n.t("saved.close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
                TextField(
                    "",
                    text: $query,
                    prompt: Text(i18n.lang == "en" ? "Search exercises" : "Übung suchen")
                        .foregroundColor(Theme.muted)
                )
                .font(KraftFont.inter(14))
                .foregroundColor(Theme.text)
                .autocorrectionDisabled()
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    KraftChip(i18n.lang == "en" ? "All" : "Alle", isActive: category == nil) {
                        category = nil
                    }
                    ForEach(ExerciseDatabase.categories) { c in
                        KraftChip(i18n.category(c), isActive: category == c) {
                            category = (category == c) ? nil : c
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    KraftChip(i18n.lang == "en" ? "Any gear" : "Alle Geräte", isActive: equipment == nil) {
                        equipment = nil
                    }
                    ForEach(availableEquipment, id: \.self) { e in
                        KraftChip(i18n.equipment(e), isActive: equipment == e) {
                            equipment = (equipment == e) ? nil : e
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var limitBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.orange)
            Text(i18n.lang == "en"
                 ? "Maximum reached. Remove one to pick another, or raise the exercise count."
                 : "Maximum erreicht. Wähle eine ab, um eine andere zu wählen — oder erhöhe die Anzahl.")
                .font(KraftFont.inter(11.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.orange.opacity(0.4), lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(pool) { exercise in
                    row(exercise)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let used = alreadyUsed.contains(exercise.name)
        let selected = isMultiSelect && selectedNames.contains(exercise.name)
        // Bei erreichter Grenze bleibt nur das Abwählen erlaubt.
        let blocked = isAtLimit && !selected

        return Button(action: {
            guard !blocked else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onPick(exercise)
            if !isMultiSelect { dismiss() }
        }) {
            HStack(spacing: 12) {
                if isMultiSelect {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19))
                        .foregroundColor(selected ? Theme.accent : (blocked ? Theme.border : Theme.muted))
                }

                ExerciseVisual(exercise: exercise, category: exercise.category, size: 38, tappable: false)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.localizedName(language: i18n.lang))
                        .font(KraftFont.inter(13.5, .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(exercise.categories.map { i18n.category($0) }.joined(separator: " · "))
                            .font(KraftFont.inter(10.5))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                        if exercise.isHeavy {
                            Text(i18n.lang == "en" ? "HEAVY" : "SCHWER")
                                .font(KraftFont.mono(8.5, .bold))
                                .foregroundColor(Theme.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Theme.orange.opacity(0.15)))
                        }
                    }
                }

                Spacer(minLength: 6)

                if used && !isMultiSelect {
                    Text(i18n.lang == "en" ? "IN PLAN" : "IM PLAN")
                        .font(KraftFont.mono(8.5, .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accentDim))
                }

                EquipmentTag(i18n.equipment(exercise.equipment))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.accentDim : Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selected ? Theme.accent : ((used && !isMultiSelect) ? Theme.accent.opacity(0.35) : Theme.border),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .opacity(blocked ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(Theme.muted)
            Text(i18n.lang == "en"
                 ? "No exercise matches these filters."
                 : "Keine Übung passt zu diesen Filtern.")
                .font(KraftFont.inter(13))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
            Button(action: {
                query = ""
                category = nil
                equipment = nil
            }) {
                Text(i18n.lang == "en" ? "Reset filters" : "Filter zurücksetzen")
                    .font(KraftFont.inter(12.5, .semibold))
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}
