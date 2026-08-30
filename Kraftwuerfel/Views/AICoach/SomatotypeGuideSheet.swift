import SwiftUI

/*
  Körpertyp-Finder & Auswertungshilfe (Somatotyp Guide).

  Hilft dem Nutzer, seinen Körpertyp (Ektomorph, Mesomorph, Endomorph)
  intuitiv zu ermitteln:
  1. Handgelenk-Test (Knochenbau & Gelenkumfang mit Daumen + Mittelfinger)
  2. Physische Merkmale & Stoffwechselgeschwindigkeit
  3. Tendenz bei Muskelaufbau vs. Fettansatz
*/
public struct SomatotypeGuideSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @Binding public var selectedSomatotype: Somatotype
    @Environment(\.dismiss) private var dismiss

    public init(selectedSomatotype: Binding<Somatotype>) {
        self._selectedSomatotype = selectedSomatotype
    }

    private var isEn: Bool { i18n.lang == "en" }

    public var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerCard

                        wristTestCard

                        sectionHeadline(isEn ? "THE 3 BODY TYPES" : "DIE 3 KÖRPERTYPEN")

                        somatotypeDetailCard(
                            type: .ectomorph,
                            title: isEn ? "ECTOMORPH (Lean / Hardgainer)" : "EKTOMORPH (Schlank / Hardgainer)",
                            badge: isEn ? "Fast Metabolism" : "Schneller Stoffwechsel",
                            icon: "figure.walk",
                            color: Theme.accent,
                            wristResult: isEn ? "Fingers overlap clearly" : "Finger überlappen sich deutlich",
                            traits: isEn ? [
                                "Naturally lean, narrow shoulders and hips",
                                "Fast metabolism, burns calories rapidly",
                                "Difficulty gaining weight and muscle mass",
                                "Best with: Higher calorie intake & progressive overload"
                            ] : [
                                "Schmaler Knochenbau, schlanke Gelenke & Gliedmaßen",
                                "Sehr schneller Stoffwechsel, verbrennt Kalorien rasch",
                                "Schwerer Aufbau von Körpergewicht & Muskelmasse",
                                "Empfehlung: Kalorienüberschuss & schweres Grundlagentraining"
                            ]
                        )

                        somatotypeDetailCard(
                            type: .mesomorph,
                            title: isEn ? "MESOMORPH (Athletic / V-Shape)" : "MESOMORPH (Athletisch / V-Form)",
                            badge: isEn ? "Optimal Muscle Growth" : "Optimaler Muskelaufbau",
                            icon: "figure.strengthtraining.traditional",
                            color: Color(hex: "50E3C2"),
                            wristResult: isEn ? "Fingers touch each other" : "Finger berühren sich gerade so",
                            traits: isEn ? [
                                "Athletic build, wide shoulders, narrow waist",
                                "Efficient metabolism, responds quickly to training",
                                "Builds muscle easily, burns fat moderately fast",
                                "Best with: Balanced split training & periodization"
                            ] : [
                                "Breite Schultern, schmale Taille, natürliche V-Form",
                                "Effizienter Stoffwechsel, reagiert schnell auf Kraftreize",
                                "Schneller Muskelaufbau bei gleichzeitig guter Fettverbrennung",
                                "Empfehlung: Ausgewogenes Volumentraining & progressive Steigerung"
                            ]
                        )

                        somatotypeDetailCard(
                            type: .endomorph,
                            title: isEn ? "ENDOMORPH (Solid / Softgainer)" : "ENDOMORPH (Kräftig / Softgainer)",
                            badge: isEn ? "High Strength Potential" : "Hohe Kraftbasis",
                            icon: "shield.fill",
                            color: Color(hex: "F5A623"),
                            wristResult: isEn ? "Fingers do not touch" : "Finger berühren sich nicht",
                            traits: isEn ? [
                                "Solid, wide bone structure, strong foundation",
                                "Slower metabolism, stores energy efficiently",
                                "High strength potential, gains muscle and fat easily",
                                "Best with: High protein, moderate carbs & consistent activity"
                            ] : [
                                "Stämmiger, breiter Knochenbau, starke Kraftbasis",
                                "Langsamerer Stoffwechsel, speichert Energie sehr effizient",
                                "Baut sehr leicht Kraft & Masse auf, neigt zu Fetteinlagerung",
                                "Empfehlung: Proteinreiche Ernährung & moderate Cardio-Einheiten"
                            ]
                        )

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(isEn ? "Body Type Guide" : "Körpertyp-Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEn ? "Done" : "Fertig") {
                        dismiss()
                    }
                    .font(KraftFont.inter(14, .bold))
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accentDim)
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill.viewfinder")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isEn ? "FIND YOUR SOMATOTYPE" : "DEINEN KÖRPERTYP BESTIMMEN")
                    .font(KraftFont.bebas(16))
                    .tracking(1)
                    .foregroundColor(Theme.accent)

                Text(isEn
                     ? "Your bone structure and metabolism determine how your body builds muscle and burns energy."
                     : "Dein Knochenbau und Stoffwechsel bestimmen, wie dein Körper auf Training und Ernährung reagiert.")
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        )
    }

    // MARK: - Handgelenk-Test Card

    private var wristTestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)

                Text(isEn ? "THE WRIST TEST (BONE FRAME)" : "DER HANDGELENK-TEST (KNOCHENBAU)")
                    .font(KraftFont.bebas(15))
                    .tracking(1)
                    .foregroundColor(Theme.text)
            }

            Text(isEn
                 ? "Wrap your thumb and middle finger around your opposite wrist where you wear a watch:"
                 : "Umfasse dein Handgelenk an der schmalsten Stelle mit Daumen und Mittelfinger der anderen Hand:")
                .font(KraftFont.inter(12.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                wristTestRow(
                    label: isEn ? "Fingers overlap clearly" : "Finger überlappen deutlich",
                    type: "→ Ektomorph (Schlank)",
                    color: Theme.accent
                )
                wristTestRow(
                    label: isEn ? "Fingers just touch each other" : "Finger berühren sich gerade",
                    type: "→ Mesomorph (Athletisch)",
                    color: Color(hex: "50E3C2")
                )
                wristTestRow(
                    label: isEn ? "Fingers do not touch" : "Finger berühren sich nicht",
                    type: "→ Endomorph (Kräftig)",
                    color: Color(hex: "F5A623")
                )
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
        )
    }

    private func wristTestRow(label: String, type: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(KraftFont.inter(12, .medium))
                .foregroundColor(Theme.text)
            Spacer()
            Text(type)
                .font(KraftFont.mono(11.5, .bold))
                .foregroundColor(color)
        }
    }

    // MARK: - Somatotype Detail Card

    private func somatotypeDetailCard(
        type: Somatotype,
        title: String,
        badge: String,
        icon: String,
        color: Color,
        wristResult: String,
        traits: [String]
    ) -> some View {
        let isSelected = selectedSomatotype == type

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)

                    Text(title)
                        .font(KraftFont.bebas(16))
                        .tracking(1)
                        .foregroundColor(Theme.text)
                }

                Spacer()

                if isSelected {
                    Text(isEn ? "SELECTED" : "GEWÄHLT")
                        .font(KraftFont.mono(10.5, .bold))
                        .foregroundColor(Theme.bg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color))
                }
            }

            HStack {
                Text(badge)
                    .font(KraftFont.inter(11, .semibold))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.12)))

                Spacer()

                Text("🖐 \(wristResult)")
                    .font(KraftFont.inter(11, .medium))
                    .foregroundColor(Theme.muted)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(traits, id: \.self) { trait in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                        Text(trait)
                            .font(KraftFont.inter(12))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                selectedSomatotype = type
                dismiss()
            } label: {
                HStack {
                    Text(isSelected ? (isEn ? "Currently Selected" : "Bereits ausgewählt") : (isEn ? "Select this body type" : "Diesen Körpertyp wählen"))
                        .font(KraftFont.inter(13, .bold))
                    if !isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.surface2 : color)
                .foregroundColor(isSelected ? Theme.muted : Theme.bg)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Theme.border, lineWidth: isSelected ? 1.5 : 1)
                )
        )
    }

    private func sectionHeadline(_ text: String) -> some View {
        Text(text)
            .font(KraftFont.bebas(15))
            .tracking(1.2)
            .foregroundColor(Theme.muted)
            .padding(.top, 6)
    }
}
