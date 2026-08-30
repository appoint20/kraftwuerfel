import SwiftUI

/*
  AppGuideView — 360° App-Handbuch & How-To Anleitung für KRAFTWÜRFEL.
  Umfassende, interaktive Schritt-für-Schritt Erklärung aller Kernfunktionen:
  1. Generator & Split-System (Würfeln, Zyklen A/B)
  2. Live-Workout (2.5 kg Schritte, Direkteingabe, Pause, Apple Watch & Dynamic Island)
  3. Fortschritt & Trainingstagebuch (Bezier-Graphen, Historie)
  4. KI-Coach & Ernährungs-Guides (13 Biometrie-Parameter)
  5. Musik-Player & Mediathek-Shuffle
  6. Mitgliedschaft (Free vs. Pro)
*/

public struct AppGuideView: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var expandedSection: String? = "generator"

    public init() {}

    private struct GuideTopic: Identifiable {
        let id: String
        let icon: String
        let titleDe: String
        let titleEn: String
        let subtitleDe: String
        let subtitleEn: String
        let pointsDe: [String]
        let pointsEn: [String]
        let tipDe: String
        let tipEn: String
    }

    private let topics: [GuideTopic] = [
        GuideTopic(
            id: "generator",
            icon: "dice.fill",
            titleDe: "1. Generator & Split-System",
            titleEn: "1. Generator & Split System",
            subtitleDe: "Intelligente Trainingsplan-Erstellung auf Knopfdruck",
            subtitleEn: "Smart workout creation at the touch of a button",
            pointsDe: [
                "**Split-Auswahl:** Wähle zwischen Ganzkörper, 2er-Split (Push/Pull, OK/UK) oder 3er/4er-Splits.",
                "**2-Zyklen-System (A/B):** Jeder Trainingstag bietet zwei wechselnde Übungs-Zyklen für optimale Muskelreize.",
                "**Schwere Grundübungen zuerst:** Der Algorithmus setzt Verbundübungen (wie Bankdrücken, Kniebeugen) stets an den Anfang.",
                "**Übungstausch:** Tippe auf eine beliebige Übung oder den Würfel-Button, um eine Alternative aus derselben Muskelgruppe zu ziehen.",
                "**Reihenfolge anpassen:** Halte eine Übung oder einen Trainingstag gedrückt oder nutze die Pfeile (▲ / ▼), um die Reihenfolge beliebig anzupassen."
            ],
            pointsEn: [
                "**Split Selection:** Choose between Full Body, 2-Day Splits (Push/Pull, Upper/Lower) or 3/4-Day Splits.",
                "**2-Cycle System (A/B):** Every workout day features two alternating exercise cycles for balanced muscular stimuli.",
                "**Heavy Compounds First:** The generator always prioritizes compound lifts (like Bench Press, Squats) at the beginning of each session.",
                "**Exercise Swapping:** Tap any exercise or the reroll dice to pick an alternative from the same muscle category.",
                "**Reorder Exercises & Days:** Long-press any exercise or workout day or use the arrow buttons (▲ / ▼) to freely rearrange the workout order."
            ],
            tipDe: "Tipp: Halte einen Tag oder eine Übung gedrückt oder nutze die Pfeile, um die Trainingsabfolge nach deinen Wünschen zu sortieren.",
            tipEn: "Tip: Long-press any day or exercise, or use the arrow buttons, to sort your workout sequence exactly as you like."
        ),
        GuideTopic(
            id: "live",
            icon: "bolt.fill",
            titleDe: "2. Live-Workout & Session-Tracking",
            titleEn: "2. Live Workout & Session Tracking",
            subtitleDe: "Präzises Tracking mit Apple Watch & Dynamic Island",
            subtitleEn: "Precise tracking with Apple Watch & Dynamic Island",
            pointsDe: [
                "**2,5 kg Steigerung:** Passe Gewichte in 2,5 kg Schritten über die Stepper an.",
                "**Direkteingabe:** Tippe direkt auf das Gewicht oder die Wiederholungen, um eigene Zahlen per Tastatur einzutragen.",
                "**Satz-Korrektur:** Tippe im Satz-Protokoll auf jeden absolvierten Satz, um falsche Angaben nachträglich anzupassen.",
                "**Vergangenheitswerte:** In der Karte „LETZTES MAL“ siehst du sofort deine gestemmten Gewichte aus dem vorherigen Training.",
                "**Satzpause:** Automatischer Pausentimer mit Countdown-Benachrichtigung und Live Activity auf dem Sperrbildschirm.",
                "**Apple Watch:** Live-Puls-Messung und „Satz fertig“-Steuerung direkt am Handgelenk."
            ],
            pointsEn: [
                "**2.5 kg Increments:** Step weights up or down easily in standard 2.5 kg plates.",
                "**Direct Typing:** Tap directly on the weight or rep numbers to type exact values with the keypad.",
                "**Set History Correction:** Tap any row in the set log to quickly correct mistaken weights or reps.",
                "**Past Performance:** The 'LAST TIME' card automatically displays your exact weight and reps from the last workout.",
                "**Rest Timer:** Automatic rest countdown with Lock Screen Live Activity notifications.",
                "**Apple Watch:** Real-time heart rate syncing and set completion controls directly on your wrist."
            ],
            tipDe: "Tipp: Der Fokus-Modus zeigt die aktuelle Übung groß an, der Protokoll-Modus die Gesamtübersicht.",
            tipEn: "Tip: Focus mode highlights the active set, while Log mode gives you a full session overview."
        ),
        GuideTopic(
            id: "progress",
            icon: "chart.line.uptrend.xyaxis",
            titleDe: "3. Fortschritt & Trainingstagebuch",
            titleEn: "3. Progress & Workout Diary",
            subtitleDe: "Deine Kraftkurven und Erfolge über die Zeit",
            subtitleEn: "Your strength curves and performance diary over time",
            pointsDe: [
                "**Automatisches Tagebuch:** Jedes beendete Workout wird dauerhaft mit allen Sätzen, Gewichten und Wdh gespeichert.",
                "**Übungs-Entwicklungsgraph:** Wähle eine Übung aus und analysiere deine Steigerungskurve mit Trend-Prozenten.",
                "**Metrik-Umschaltung:** Wechsle zwischen Maximalgewicht (kg) und Trainingsvolumen (kg).",
                "**KI-Motivationsmeldungen:** Nach jedem Trainingstag erhältst du eine individuelle Abschlussbotschaft."
            ],
            pointsEn: [
                "**Automatic Diary:** Every finished session is permanently logged with all sets, weights, and repetitions.",
                "**Progression Graphs:** Select any exercise to view your Bezier strength curve and percentage progress.",
                "**Metric Toggle:** Switch between Maximum Weight (kg) and total Volume (kg).",
                "**AI Motivation:** Receive an inspiring congratulatory message at the end of every completed session."
            ],
            tipDe: "Tipp: Im Fortschritts-Tab kannst du vergangene Trainingstage aufklappen und einzelne Einträge verwalten.",
            tipEn: "Tip: In the Progress tab, expand any diary entry to inspect completed exercise sets."
        ),
        GuideTopic(
            id: "aicoach",
            icon: "sparkles",
            titleDe: "4. KI-Coach & Ernährungs-Guides",
            titleEn: "4. AI Coach & Nutrition Guides",
            subtitleDe: "Maßgeschneiderte Hypertrophie- & Ernährungspläne",
            subtitleEn: "Tailored hypertrophy & nutrition blueprints",
            pointsDe: [
                "**13 Biometrie-Parameter:** Alter, Größe, Gewicht, Zielgewicht, Geschlecht, Erfahrung, Tage, Dauer, Methode, Equipment, Einschränkungen, Aufwärmen und Ernährungsform.",
                "**Wissenschaftliche Makros:** Berechnet deine optimale Kalorien-, Protein-, Kohlenhydrat- und Fett-Verteilung.",
                "**Mahlzeiten-Leitfaden:** Konkrete Empfehlungen für Pre-Workout, Post-Workout und Hauptmahlzeiten passend zu deiner Diätform (Omnivor, Vegetarisch, Vegan, Keto, etc.)."
            ],
            pointsEn: [
                "**13 Biometric Parameters:** Age, height, weight, target weight, sex, experience, training days, duration, method, equipment, restrictions, warmup, and diet.",
                "**Evidence-Based Macros:** Calculates optimal calorie, protein, carbohydrate, and fat targets.",
                "**Meal Guide:** Concrete recommendations for Pre-Workout, Post-Workout, and main meals tailored to your diet (Omnivore, Vegetarian, Vegan, Keto, etc.)."
            ],
            tipDe: "Tipp: Bei kurzen Netzwerkausfällen schaltet die App nahtlos auf die intelligente Offline-Vorlagenbibliothek um.",
            tipEn: "Tip: If the network is offline, the app seamlessly falls back to our intelligent built-in template engine."
        ),
        GuideTopic(
            id: "music",
            icon: "music.note.list",
            titleDe: "5. Musik-Player & Mediathek",
            titleEn: "5. Music Player & Library",
            subtitleDe: "Deine Workout-Tracks ohne Unterbrechung",
            subtitleEn: "Your workout tracks with zero interruptions",
            pointsDe: [
                "**Eigene Mediathek:** Spiele heruntergeladene Titel aus deiner Apple Music Mediathek auch offline ohne Empfang.",
                "**Zufallswiedergabe (Shuffle):** Mische deine Titel über den neuen 🔀-Button in der Steuerleiste.",
                "**Spotify-Anbindung:** Starte verknüpfte Workout-Playlists direkt aus der Live-Session."
            ],
            pointsEn: [
                "**Apple Music Library:** Play downloaded tracks from your media library even offline without signal.",
                "**Shuffle Mode:** Shuffle your playlist with the 🔀 button in the player control bar.",
                "**Spotify Integration:** Launch your favorite workout playlists directly from the live session."
            ],
            tipDe: "Tipp: Der Mini-Player in der Live-Session blendet sich dezent ein, ohne die Trainingsanzeige zu stören.",
            tipEn: "Tip: The live session mini-player stays accessible without obscuring your workout weights."
        ),
        GuideTopic(
            id: "pro",
            icon: "crown.fill",
            titleDe: "6. Mitgliedschaft (Free vs. Pro)",
            titleEn: "6. Membership (Free vs. Pro)",
            subtitleDe: "Faire Grundfunktionen & unbegrenzte Pro-Vorteile",
            subtitleEn: "Fair free features & unlimited Pro benefits",
            pointsDe: [
                "**Free-Version:** Unbegrenztes Würfeln & Generator-Nutzung, 1 dauerhafter Favoriten-Plan, vollständige Live-Session mit Apple Watch & Musik, 1 KI-Plan nach 3 Video-Clips einsehbar.",
                "**Pro-Version:** 100% Werbefreiheit (keine Banner/Unterbrechungen), unbegrenzte KI-Trainings- & Ernährungspläne sofort ohne Videos, unbegrenztes Speichern & Exportieren in die Bibliothek.",
                "**Tarife:** Flexibles Monats-Abo (7,99 €/Monat) oder Jahres-Abo (49,99 €/Jahr · Spare 48%)."
            ],
            pointsEn: [
                "**Free Tier:** Unlimited workout generator, 1 permanent favorite plan, full live session with Apple Watch & music, and AI Coach generation unlocked after 3 sponsor videos.",
                "**Pro Tier:** 100% ad-free experience, unlimited instant AI Coach plans without videos, and unlimited library saving & exporting.",
                "**Plans:** Flexible Monthly Plan ($7.99/mo) or Yearly Plan ($49.99/yr · Save 48%)."
            ],
            tipDe: "Tipp: Abonnements können jederzeit flexibel in deinen Apple-ID-Account-Einstellungen verwaltet oder gekündigt werden.",
            tipEn: "Tip: Subscriptions can be managed or cancelled anytime in your Apple ID Account Settings."
        ),
        GuideTopic(
            id: "homechallenge",
            icon: "die.face.5.fill",
            titleDe: "7. 3D Titan-Würfel & Home-Challenge",
            titleEn: "7. 3D Titanium Dice & Home Challenge",
            subtitleDe: "Bodyweight-Arena mit Perspektivenwurf & Satz/Wdh-Würfeln",
            subtitleEn: "Bodyweight arena with perspective toss & sets/reps dice",
            pointsDe: [
                "**Futuristische 3D Titan-Würfel:** Optisch designte Metallwürfel mit leuchtenden Neon-Cyan Pips und echter 3D-Flugphysik.",
                "**Sätze & Wiederholungen:** Würfel 1 bestimmt die Sätze (2 bis 6), Würfel 2 die Wiederholungen (10 bis 40).",
                "**Reel-Scrolling:** Beim Wurf scrollt der Übungs-Slot synchron durch alle Bodyweight-Übungen.",
                "**Konfigurierbare Challenges:** Wähle 10, 20, 30, 45, 60 oder 100 Tage mit täglicher Push-Erinnerung für Calisthenics, Squats, Wall-Sits und Planks."
            ],
            pointsEn: [
                "**Futuristic 3D Titanium Dice:** Custom chamfered metal dice with glowing neon-cyan pips and 3D physics flight.",
                "**Sets & Reps:** Die 1 rolls the sets (2 to 6), Die 2 rolls the repetitions (10 to 40).",
                "**Synchronized Reel Scrolling:** The bodyweight exercise slot scrolls smoothly and locks in upon impact.",
                "**Customizable Challenges:** Configure 10, 20, 30, 45, 60 or 100 days with daily push notifications."
            ],
            tipDe: "Tipp: Schalte im Generator-Tab oben einfach zwischen 'Generator' und 'Challenge' um!",
            tipEn: "Tip: Toggle between 'Generator' and 'Challenge' directly in the Generator tab!"
        ),
        GuideTopic(
            id: "privacy",
            icon: "lock.shield.fill",
            titleDe: "8. Datenschutz & 100% On-Device Speicherung",
            titleEn: "8. Privacy & 100% On-Device Storage",
            subtitleDe: "Deine Trainings- & Gesundheitsdaten bleiben privat bei dir",
            subtitleEn: "Your workout & health data remains strictly private on device",
            pointsDe: [
                "**100% Lokale Daten:** Alle Trainingspläne, generierten Einheiten, Workouts, Fortschritts-Logs, Ernährungspläne und Biometriedaten werden ausschließlich lokal auf deinem Endgerät (UserDefaults/Keychain) gespeichert.",
                "**Minimale Cloud-Daten:** In unserer sicheren Datenbank speichern wir ausschließlich deine E-Mail, deinen Namen und das gehashte Passwort zur Verwaltung deines Accounts und der Pro-Mitgliedschaft.",
                "**Kein Tracking:** Kein Verkauf deiner Gesundheitsdaten, keine Werbetracker und kein externer Zugriff."
            ],
            pointsEn: [
                "**100% Local Data:** All workout plans, generated routines, diary logs, nutrition guides, and biometric data are stored strictly on your local device.",
                "**Minimal Cloud Account:** Our secure database only holds your email, name, and hashed password for account and Pro subscription management.",
                "**No Health Tracking:** Zero sale of personal health data, no advertising trackers, and total privacy."
            ],
            tipDe: "Tipp: Unter Einstellungen → 'Daten löschen' kannst du alle lokalen Daten mit einem Klick vollständig bereinigen.",
            tipEn: "Tip: Under Settings → 'Delete Data' you can completely wipe all local data with a single tap."
        ),
        GuideTopic(
            id: "applewatch",
            icon: "applewatch",
            titleDe: "9. Apple Watch Sensorik & Live-Werte",
            titleEn: "9. Apple Watch Sensors & Live Metrics",
            subtitleDe: "Echte optische Herzfrequenzmessung vs. physiologisches Modell",
            subtitleEn: "Real optical heart rate tracking vs. physiological model",
            pointsDe: [
                "**Echte optische Messung:** Sobald du deine Apple Watch trägst und die Sitzung startest, erfassen die PPG-Sensoren deinen Puls und Aktivkalorien in Echtzeit (grüner 'Apple Watch' Indikator).",
                "**Physiologisches Modell-Fallback:** Da iPhones am Gehäuse keine optischen Kontaktsensoren haben, schaltet die App ohne gekoppelte Watch auf ein wissenschaftliches Belastungsmodell um und kennzeichnet dies transparent als 'geschätzt'.",
                "**Volle Handgelenks-Steuerung:** Sätze abhaken, Gewicht anpassen und Pausen-Countdown direkt auf der Apple Watch nutzen."
            ],
            pointsEn: [
                "**Real Optical Tracking:** When wearing your Apple Watch, PPG optical diodes track your real-time heart rate and active calories (green 'Apple Watch' indicator).",
                "**Physiological Model Fallback:** Because iPhones lack optical contact diodes on the chassis, the app uses a scientific load model when no watch is worn and transparently labels it 'estimated'.",
                "**Wrist Controls:** Complete sets, adjust weights, and view rest countdowns directly from your Apple Watch."
            ],
            tipDe: "Tipp: Öffne die Kraftwürfel-Watch-App vor Trainingsbeginn, um die optische Messung sofort scharfzuschalten.",
            tipEn: "Tip: Launch the Kraftwürfel Watch app before starting your session to activate optical sensing immediately."
        )
    ]

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    introCard

                    SectionLabel(i18n.lang == "en" ? "APP MODULES & FEATURES" : "MODULE & FUNKTIONEN IM ÜBERBLICK")
                        .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(topics) { topic in
                            topicCard(topic)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.lang == "en" ? "360° APP GUIDE" : "360° APP-HANDBUCH")
                    .font(KraftFont.bebas(22)).tracking(1.2)
                    .foregroundColor(Theme.text)
                Text(i18n.lang == "en" ? "How Kraftwuerfel works" : "So funktioniert Kraftwürfel")
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(i18n.t("saved.close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var introCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.accent)
                LogoIcon(size: 30)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("KRAFTWÜRFEL PRO")
                    .font(KraftFont.bebas(18)).tracking(1)
                    .foregroundColor(Theme.text)
                Text(i18n.lang == "en"
                     ? "Your comprehensive workout generator, live tracker, AI coach, and progression diary."
                     : "Dein intelligenter Trainingsplan-Generator, Live-Session-Tracker, KI-Coach und Fortschrittstagebuch.")
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func topicCard(_ topic: GuideTopic) -> some View {
        let isExpanded = expandedSection == topic.id
        let title = i18n.lang == "en" ? topic.titleEn : topic.titleDe
        let subtitle = i18n.lang == "en" ? topic.subtitleEn : topic.subtitleDe
        let points = i18n.lang == "en" ? topic.pointsEn : topic.pointsDe
        let tip = i18n.lang == "en" ? topic.tipEn : topic.tipDe

        return VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSection = isExpanded ? nil : topic.id
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(KraftFont.inter(14, .bold))
                            .foregroundColor(Theme.text)
                        Text(subtitle)
                            .font(KraftFont.inter(11.5))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.muted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().background(Theme.border)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(points, id: \.self) { pt in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Theme.accent)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                Text(LocalizedStringKey(pt))
                                    .font(KraftFont.inter(12.5))
                                    .foregroundColor(Theme.text.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // Tipp-Box
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accent)
                            .padding(.top, 1)

                        Text(tip)
                            .font(KraftFont.inter(11.5, .medium))
                            .foregroundColor(Theme.accent)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Theme.accentDim)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isExpanded ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
    }
}
