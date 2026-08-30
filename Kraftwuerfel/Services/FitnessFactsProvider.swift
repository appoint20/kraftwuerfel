import Foundation

/*
  Wissenschaftlich fundierte Fitness- & Hypertrophie-Facts.

  Wird im KI-Coach während der Ladezeit (Planerstellung) und als
  Micro-Learning-Tipps in der App eingesetzt.
*/
public struct FitnessFact: Identifiable, Equatable {
    public let id: Int
    public let category: String
    public let titleDe: String
    public let factDe: String
    public let titleEn: String
    public let factEn: String
    public let icon: String

    public func title(for lang: String) -> String {
        lang == "en" ? titleEn : titleDe
    }

    public func fact(for lang: String) -> String {
        lang == "en" ? factEn : factDe
    }
}

public enum FitnessFactsProvider {

    public static let facts: [FitnessFact] = [
        FitnessFact(
            id: 1,
            category: "Erholung & Wachstum",
            titleDe: "Wann Muskeln wachsen",
            factDe: "Muskeln wachsen in den Ruhephasen nach dem Training, nicht während der Belastung. Schlaf und Proteinzufuhr sind der Schlüssel zur Hypertrophie.",
            titleEn: "When Muscles Grow",
            factEn: "Muscles grow during recovery periods after workouts, not during lifting. Quality sleep and protein intake drive hypertrophy.",
            icon: "bed.double.fill"
        ),
        FitnessFact(
            id: 2,
            category: "Progression",
            titleDe: "Progressive Überladung",
            factDe: "Die stetige Steigerung von Gewicht oder Wiederholungen ist der wichtigste biologische Reiz für kontinuierlichen Muskelaufbau.",
            titleEn: "Progressive Overload",
            factEn: "Gradually increasing weight or reps over time provides the primary stimulus for sustainable muscle growth.",
            icon: "chart.line.uptrend.xyaxis"
        ),
        FitnessFact(
            id: 3,
            category: "Ernährung",
            titleDe: "Optimale Proteinzufuhr",
            factDe: "1,6 bis 2,2 Gramm Protein pro Kilogramm Körpergewicht täglich maximieren die Muskelproteinsynthese bei Kraftsportlern.",
            titleEn: "Optimal Protein Intake",
            factEn: "1.6 to 2.2 grams of protein per kg of bodyweight per day maximizes muscle protein synthesis in strength athletes.",
            icon: "fork.knife"
        ),
        FitnessFact(
            id: 4,
            category: "Leistung",
            titleDe: "Hydratation & Maximalkraft",
            factDe: "Bereits 2% Flüssigkeitsverlust im Körper können deine Kraftleistung um bis zu 10% bis 15% verringern. Trinke ausreichend vor und beim Training.",
            titleEn: "Hydration & Strength",
            factEn: "Just a 2% drop in hydration can decrease maximum strength output by 10% to 15%. Stay well-hydrated throughout the day.",
            icon: "drop.fill"
        ),
        FitnessFact(
            id: 5,
            category: "Hypertrophie",
            titleDe: "Wiederholungsbereiche",
            factDe: "Muskelaufbau gelingt effektiv zwischen 5 und 30 Wiederholungen – entscheidend ist, dass du jeden Satz nah ans Muskelversagen ausführst.",
            titleEn: "Repetition Ranges",
            factEn: "Hypertrophy occurs effectively across 5 to 30 reps, provided sets are taken close to muscular failure.",
            icon: "repeat"
        ),
        FitnessFact(
            id: 6,
            category: "Hormone",
            titleDe: "Schlaf als Superkraft",
            factDe: "Im Tiefschlaf schüttet der Körper das meiste Wachstumshormon (HGH) aus. 7 bis 9 Stunden Schlaf beschleunigen die Regeneration drastisch.",
            titleEn: "Sleep as a Superpower",
            factEn: "Deep sleep triggers the highest release of Human Growth Hormone (HGH). 7 to 9 hours accelerates muscle tissue repair.",
            icon: "moon.stars.fill"
        ),
        FitnessFact(
            id: 7,
            category: "Biomechanik",
            titleDe: "Mind-Muscle Connection",
            factDe: "Die bewusste Konzentration auf den arbeitenden Zielmuskel steigert die elektromyografische Aktivierung messbar um bis zu 20%.",
            titleEn: "Mind-Muscle Connection",
            factEn: "Consciously focusing on the target muscle during a lift increases muscle fiber recruitment by up to 20%.",
            icon: "brain.head.profile"
        ),
        FitnessFact(
            id: 8,
            category: "Stoffwechsel",
            titleDe: "Nachbrenneffekt (EPOC)",
            factDe: "Intensives Krafttraining erhöht deinen Energiegrundumsatz noch bis zu 24 bis 48 Stunden nach dem Workout (Excess Post-Exercise Oxygen Consumption).",
            titleEn: "Afterburn Effect (EPOC)",
            factEn: "Intense resistance training elevates your resting metabolic rate for 24 to 48 hours post-workout.",
            icon: "flame.fill"
        ),
        FitnessFact(
            id: 9,
            category: "Supplements",
            titleDe: "Kreatin-Monohydrat",
            factDe: "Kreatin ist das am besten erforschte Nahrungsergänzungsmittel: Es füllt die zellulären ATP-Speicher und steigert Schnellkraft und Muskelmasse.",
            titleEn: "Creatine Monohydrate",
            factEn: "Creatine is the most heavily researched supplement: it restores cellular ATP stores to boost strength and power output.",
            icon: "bolt.fill"
        ),
        FitnessFact(
            id: 10,
            category: "Prävention",
            titleDe: "Dynamisches Warm-up",
            factDe: "Aufwärmen erhöht die Muskeltemperatur und Nervenleitgeschwindigkeit, was Verletzungen vorbeugt und die Kraftübertragung verbessert.",
            titleEn: "Dynamic Warm-up",
            factEn: "Warming up increases core muscle temperature and nerve conduction velocity, preventing injury and boosting performance.",
            icon: "figure.walk"
        ),
        FitnessFact(
            id: 11,
            category: "Satzpausen",
            titleDe: "Längere Pausen bei Grundübungen",
            factDe: "2 bis 3 Minuten Pause bei schweren Grundübungen erlauben eine vollständigere Erholung des Nervensystems und ermöglichen mehr Gesamtvolumen.",
            titleEn: "Rest Periods for Compounds",
            factEn: "2 to 3 minutes of rest on heavy compound lifts enables complete ATP replenishment and higher quality training volume.",
            icon: "timer"
        ),
        FitnessFact(
            id: 12,
            category: "Gesundheit",
            titleDe: "Knochendichte & Kraft",
            factDe: "Widerstandstraining stimuliert die Osteoblasten-Aktivität und erhöht die Knochendichte signifikant zum Schutz vor Osteoporose.",
            titleEn: "Bone Mineral Density",
            factEn: "Resistance training stimulates osteoblast activity, strengthening bones and increasing density across all age groups.",
            icon: "cross.fill"
        ),
        FitnessFact(
            id: 13,
            category: "Stoffwechsel",
            titleDe: "Muskeln verbrennen rund um die Uhr",
            factDe: "Jedes zusätzliche Kilogramm Muskelmasse erhöht deinen täglichen Kalorienverbrauch in Ruhe – Muskelgewebe ist metabolisch aktiv.",
            titleEn: "Metabolic Muscle Engine",
            factEn: "Every kilogram of added muscle tissue increases your baseline resting metabolic rate around the clock.",
            icon: "speedometer"
        ),
        FitnessFact(
            id: 14,
            category: "Bewegungsqualität",
            titleDe: "Die exzentrische Phase",
            factDe: "Das kontrollierte 2-3-sekündige Absenken des Gewichts erzeugt starke Muskelspannung und stimuliert Hypertrophie besonders effektiv.",
            titleEn: "The Eccentric Phase",
            factEn: "Controlling the lowering (eccentric) portion of a lift for 2-3 seconds causes potent mechanical tension for hypertrophy.",
            icon: "arrow.down.circle.fill"
        ),
        FitnessFact(
            id: 15,
            category: "Stabilität",
            titleDe: "Rumpf-Stabilität (Core)",
            factDe: "Ein stabiler Core schützt die Wirbelsäule bei Kniebeugen und Kreuzheben und überträgt die Kraft ohne Energieverlust auf die Extremitäten.",
            titleEn: "Core Stability",
            factEn: "A rigid core protects your lumbar spine and efficiently transfers force without power leaks during compound lifts.",
            icon: "shield.lefthalf.filled"
        ),
        FitnessFact(
            id: 16,
            category: "Mobilität",
            titleDe: "Gelenkbeweglichkeit",
            factDe: "Gute Mobilität in Sprunggelenken und Hüfte ermöglicht tiefere Kniebeugen mit optimaler Rekrutierung von Quadrizeps und Gesäßmuskeln.",
            titleEn: "Joint Mobility",
            factEn: "Adequate ankle and hip mobility allows deeper squats with superior quadriceps and glute activation.",
            icon: "figure.flexibility"
        ),
        FitnessFact(
            id: 17,
            category: "Neuro-Muskulär",
            titleDe: "Zentralnervensystem (ZNS)",
            factDe: "Kraftgewinne in den ersten 4–6 Trainingswochen entstehen primär durch verbesserte neuronale Ansteuerung der Muskelfasern.",
            titleEn: "Central Nervous System (CNS)",
            factEn: "Early strength gains in the first 4-6 weeks stem primarily from improved neuromuscular coordination and firing frequency.",
            icon: "waveform.path.ecg"
        ),
        FitnessFact(
            id: 18,
            category: "Kontinuität",
            titleDe: "Konsistenz schlägt Intensität",
            factDe: "Ein solides Training, das du über Jahre hinweg beibehältst, schlägt jedes extreme Programm, das nach wenigen Wochen abgebrochen wird.",
            titleEn: "Consistency Beats Intensity",
            factEn: "A solid, sustainable training routine executed for years always beats extreme regimens abandoned after a few weeks.",
            icon: "calendar.badge.clock"
        ),
        FitnessFact(
            id: 19,
            category: "Herz-Kreislauf",
            titleDe: "Kardiovaskuläre Vorteile",
            factDe: "Krafttraining senkt den Ruheblutdruck, verbessert die Insulinsensitivität und stärkt das Gefäßsystem genauso effektiv wie Cardiotraining.",
            titleEn: "Cardiovascular Benefits",
            factEn: "Resistance training lowers resting blood pressure, improves insulin sensitivity, and enhances arterial elasticity.",
            icon: "heart.fill"
        ),
        FitnessFact(
            id: 20,
            category: "Mikronährstoffe",
            titleDe: "Magnesium & Muskelkontraktion",
            factDe: "Magnesium ist an über 300 Stoffwechselprozessen beteiligt und unverzichtbar für die neuromuskuläre Reizübertragung und Entspannung.",
            titleEn: "Magnesium & Contraction",
            factEn: "Magnesium participates in over 300 biochemical reactions, essential for muscle relaxation and preventing cramping.",
            icon: "sparkles"
        ),
        FitnessFact(
            id: 21,
            category: "Periodisierung",
            titleDe: "Strategische Deload-Wochen",
            factDe: "Eine Entlastungswoche mit reduziertem Volumen alle 6 bis 8 Wochen baut akkumulierte Ermüdung ab und beugt Übertraining vor.",
            titleEn: "Deload Weeks",
            factEn: "A planned deload week with reduced volume every 6 to 8 weeks dissipates fatigue and primes you for new personal records.",
            icon: "arrow.triangle.2.circlepath"
        ),
        FitnessFact(
            id: 22,
            category: "Aminosäuren",
            titleDe: "Leucin als Muskel-Trigger",
            factDe: "Die essentielle Aminosäure Leucin aktiviert den mTOR-Signalweg und schaltet die Muskelproteinsynthese nach einer Mahlzeit gezielt an.",
            titleEn: "Leucine as an mTOR Trigger",
            factEn: "The essential amino acid leucine acts as a molecular trigger, directly activating the mTOR pathway for protein synthesis.",
            icon: "atom"
        )
    ]

    public static func randomFact() -> FitnessFact {
        facts.randomElement() ?? facts[0]
    }
}
