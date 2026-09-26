import SwiftUI

/*
  Quellen für alles, was der Coach über Körper und Ernährung sagt.

  App Review (Richtlinie 1.4.1) verlangt, dass jede Gesundheitsangabe ihre
  Quelle nennt — und zwar dort, wo die Zahl steht, nicht irgendwo versteckt.
  Deshalb hängt unter jeder Karte mit BMI, Grundumsatz, Kalorien, Makros oder
  Körpertyp ein Verweis auf genau die Quellen, aus denen diese Karte rechnet.
  Die Gesamtliste ist zusätzlich über die Einstellungen erreichbar.

  Jede Quelle hier entspricht einer Formel oder Schwelle im Code. Wer eine
  Formel ändert (TrainingPlan.swift: UserBiometrics, ActivityLevel.factor;
  BiometricsBreakdownView: Makros), muss die Quelle hier mitziehen.
*/

public enum HealthTopic: CaseIterable, Identifiable {
    case bmi, metabolism, nutrition, training, bodyType

    public var id: Self { self }

    func title(_ lang: String) -> String {
        let en = lang == "en"
        switch self {
        case .bmi: return en ? "BMI categories" : "BMI-Kategorien"
        case .metabolism: return en ? "Metabolic rate & calorie targets" : "Grundumsatz & Ziel-Kalorien"
        case .nutrition: return en ? "Protein, fat & carbohydrates" : "Protein, Fett & Kohlenhydrate"
        case .training: return en ? "Training volume & progression" : "Trainingsumfang & Progression"
        case .bodyType: return en ? "Body type (somatotype)" : "Körpertyp (Somatotyp)"
        }
    }
}

public struct HealthSource: Identifiable {
    public let id: String
    /// Kurzname für die Zeile unter einer Karte.
    let shortName: String
    let citation: String
    let usedForDe: String
    let usedForEn: String
    let url: URL
    let topic: HealthTopic

    func usedFor(_ lang: String) -> String { lang == "en" ? usedForEn : usedForDe }

    static let all: [HealthSource] = [
        HealthSource(
            id: "who-bmi",
            shortName: "WHO",
            citation: "World Health Organization. A healthy lifestyle – WHO recommendations.",
            usedForDe: "BMI-Grenzwerte: < 18,5 Untergewicht, 18,5–24,9 Normalgewicht, 25–29,9 Übergewicht, ≥ 30 Adipositas.",
            usedForEn: "BMI cut-offs: < 18.5 underweight, 18.5–24.9 normal, 25–29.9 overweight, ≥ 30 obese.",
            url: URL(string: "https://www.who.int/europe/news-room/fact-sheets/item/a-healthy-lifestyle---who-recommendations")!,
            topic: .bmi
        ),
        HealthSource(
            id: "mifflin",
            shortName: "Mifflin-St Jeor 1990",
            citation: "Mifflin MD, St Jeor ST, et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241–247.",
            usedForDe: "Formel für den Grundumsatz (BMR).",
            usedForEn: "Equation for basal metabolic rate (BMR).",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!,
            topic: .metabolism
        ),
        HealthSource(
            id: "frankenfield",
            shortName: "Frankenfield 2005",
            citation: "Frankenfield D, Roth-Yousey L, Compher C. Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults: a systematic review. J Am Diet Assoc. 2005;105(5):775–789.",
            usedForDe: "Begründung, warum Mifflin-St Jeor die genaueste der gängigen Formeln ist.",
            usedForEn: "Why Mifflin-St Jeor is the most accurate of the common equations.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/15883556/")!,
            topic: .metabolism
        ),
        HealthSource(
            id: "fao-energy",
            shortName: "FAO/WHO/UNU 2001",
            citation: "FAO/WHO/UNU. Human energy requirements. Report of a Joint FAO/WHO/UNU Expert Consultation. Rome, 2001.",
            usedForDe: "Aktivitätsfaktoren (1,2–1,725), mit denen der Grundumsatz zum Gesamtumsatz (TDEE) wird.",
            usedForEn: "Activity factors (1.2–1.725) that turn BMR into total daily energy expenditure (TDEE).",
            url: URL(string: "https://www.fao.org/4/y5686e/y5686e00.htm")!,
            topic: .metabolism
        ),
        HealthSource(
            id: "hall-energy",
            shortName: "Hall 2011",
            citation: "Hall KD, Sacks G, et al. Quantification of the effect of energy imbalance on bodyweight. Lancet. 2011;378(9793):826–837.",
            usedForDe: "Größe des Kalorienüberschusses bzw. -defizits (±200–500 kcal) für das Ziel-Kalorien-Feld.",
            usedForEn: "Size of the calorie surplus or deficit (±200–500 kcal) behind the target calories.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/21872751/")!,
            topic: .metabolism
        ),
        HealthSource(
            id: "niddk-bwp",
            shortName: "NIH Body Weight Planner",
            citation: "National Institute of Diabetes and Digestive and Kidney Diseases (NIH). Body Weight Planner.",
            usedForDe: "Untergrenze von 1.200 kcal pro Tag und langsames, nachhaltiges Abnehmen.",
            usedForEn: "Lower limit of 1,200 kcal per day and slow, sustainable weight change.",
            url: URL(string: "https://www.niddk.nih.gov/bwp")!,
            topic: .metabolism
        ),
        HealthSource(
            id: "issn-protein",
            shortName: "ISSN 2017",
            citation: "Jäger R, Kerksick CM, et al. International Society of Sports Nutrition Position Stand: protein and exercise. J Int Soc Sports Nutr. 2017;14:20.",
            usedForDe: "Proteinbedarf von 1,6–2,0 g pro kg Körpergewicht bei Krafttraining.",
            usedForEn: "Protein intake of 1.6–2.0 g per kg body weight for resistance training.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/28642676/")!,
            topic: .nutrition
        ),
        HealthSource(
            id: "morton-protein",
            shortName: "Morton 2018",
            citation: "Morton RW, Murphy KT, et al. A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength. Br J Sports Med. 2018;52(6):376–384.",
            usedForDe: "1,6 g/kg als Schwelle, ab der mehr Protein kaum zusätzlichen Muskelaufbau bringt.",
            usedForEn: "1.6 g/kg as the point beyond which more protein adds little muscle gain.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/28698222/")!,
            topic: .nutrition
        ),
        HealthSource(
            id: "efsa-fat",
            shortName: "EFSA 2010 (Fette)",
            citation: "EFSA Panel on Dietetic Products, Nutrition and Allergies. Scientific Opinion on Dietary Reference Values for fats. EFSA Journal. 2010;8(3):1461.",
            usedForDe: "Fettanteil von 20–35 % der Energie (in der App ca. 0,9 g pro kg Körpergewicht).",
            usedForEn: "Fat at 20–35 % of energy (about 0.9 g per kg body weight in the app).",
            url: URL(string: "https://doi.org/10.2903/j.efsa.2010.1461")!,
            topic: .nutrition
        ),
        HealthSource(
            id: "efsa-carbs",
            shortName: "EFSA 2010 (Kohlenhydrate)",
            citation: "EFSA Panel on Dietetic Products, Nutrition and Allergies. Scientific Opinion on Dietary Reference Values for carbohydrates and dietary fibre. EFSA Journal. 2010;8(3):1462.",
            usedForDe: "Kohlenhydrate füllen die restliche Energie auf (Referenz: 45–60 % der Energie).",
            usedForEn: "Carbohydrates fill the remaining energy (reference: 45–60 % of energy).",
            url: URL(string: "https://doi.org/10.2903/j.efsa.2010.1462")!,
            topic: .nutrition
        ),
        HealthSource(
            id: "who-activity",
            shortName: "WHO 2020",
            citation: "World Health Organization. WHO guidelines on physical activity and sedentary behaviour. Geneva, 2020.",
            usedForDe: "Mindestens zwei Krafteinheiten pro Woche und wöchentlicher Bewegungsumfang.",
            usedForEn: "At least two strength sessions per week and weekly activity volume.",
            url: URL(string: "https://www.who.int/publications/i/item/9789240015128")!,
            topic: .training
        ),
        HealthSource(
            id: "acsm-resistance",
            shortName: "ACSM 2009",
            citation: "American College of Sports Medicine. Position stand: Progression models in resistance training for healthy adults. Med Sci Sports Exerc. 2009;41(3):687–708.",
            usedForDe: "Sätze, Wiederholungen, Pausen und Steigerung je nach Ziel und Erfahrung.",
            usedForEn: "Sets, reps, rest periods and progression by goal and experience.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/19204579/")!,
            topic: .training
        ),
        HealthSource(
            id: "heath-carter",
            shortName: "Heath & Carter 1967",
            citation: "Heath BH, Carter JE. A modified somatotype method. Am J Phys Anthropol. 1967;27(1):57–74.",
            usedForDe: "Einteilung in Ekto-, Meso- und Endomorph. Der Körpertyp ist ein beschreibendes Modell, keine Diagnose.",
            usedForEn: "Ecto-, meso- and endomorph classification. Body type is a descriptive model, not a diagnosis.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/6049820/")!,
            topic: .bodyType
        ),
    ]

    static func sources(for topics: [HealthTopic]) -> [HealthSource] {
        all.filter { topics.contains($0.topic) }
    }
}

// MARK: - Verweis unter einer Karte

/*
  Die Zeile unter einer Karte. Sie nennt die Quellen schon beim Namen, damit
  man sie sieht, ohne zu tippen — ein Tippen öffnet die Liste mit Links.
*/
public struct HealthSourcesLink: View {
    @ObservedObject private var i18n = I18n.shared
    @State private var showSheet = false

    private let topics: [HealthTopic]

    public init(_ topics: [HealthTopic]) {
        self.topics = topics
    }

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSheet = true
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.lang == "en" ? "Sources & method" : "Quellen & Methodik")
                        .font(KraftFont.inter(11.5, .bold))
                        .foregroundColor(Theme.accent)
                    Text(HealthSource.sources(for: topics).map(\.shortName).joined(separator: " · "))
                        .font(KraftFont.inter(10.5))
                        .foregroundColor(Theme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            HealthSourcesSheet(topics: topics)
        }
    }
}

// MARK: - Quellenliste

public struct HealthSourcesSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    private let topics: [HealthTopic]

    public init(topics: [HealthTopic] = HealthTopic.allCases) {
        self.topics = topics
    }

    private var isEn: Bool { i18n.lang == "en" }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    disclaimer

                    ForEach(topics) { topic in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(topic.title(i18n.lang).uppercased())
                            ForEach(HealthSource.sources(for: [topic])) { source in
                                sourceRow(source)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(isEn ? "Sources" : "Quellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEn ? "Done" : "Fertig") { dismiss() }
                        .font(KraftFont.inter(14, .bold))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.orange)
            Text(isEn
                 ? "All values are estimates for healthy adults, calculated from the published sources below. They are not medical advice. If you are pregnant, have a medical condition or take medication, talk to a doctor before changing your diet or training."
                 : "Alle Werte sind Schätzungen für gesunde Erwachsene, berechnet nach den unten genannten veröffentlichten Quellen. Sie ersetzen keine ärztliche Beratung. Bei Schwangerschaft, Vorerkrankungen oder Medikamenten sprich vor einer Umstellung von Ernährung oder Training mit einer Ärztin oder einem Arzt.")
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.35), lineWidth: 1))
    }

    private func sourceRow(_ source: HealthSource) -> some View {
        Link(destination: source.url) {
            VStack(alignment: .leading, spacing: 6) {
                Text(source.usedFor(i18n.lang))
                    .font(KraftFont.inter(13, .semibold))
                    .foregroundColor(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source.citation)
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10, weight: .semibold))
                    Text(source.url.host ?? source.url.absoluteString)
                        .font(KraftFont.mono(10.5, .bold))
                }
                .foregroundColor(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
    }
}
