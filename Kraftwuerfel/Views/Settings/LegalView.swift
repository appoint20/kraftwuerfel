import SwiftUI

/*
  Impressum und Datenschutzerklärung.
  Rechtssichere Angaben gemäß § 5 DDG, § 18 Abs. 2 MStV und EU-DSGVO.
  Maßgeschneidert auf das PostgreSQL-Backend, Mailjet, OpenRouter und die 13 Fitnessparameter.
*/

public enum LegalPage: String, CaseIterable, Identifiable {
    case imprint, privacy

    public var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .imprint: return "legal.imprint"
        case .privacy: return "legal.privacy"
        }
    }

    var icon: String {
        switch self {
        case .imprint: return "building.2.fill"
        case .privacy: return "lock.shield.fill"
        }
    }
}

public struct LegalView: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    public let page: LegalPage

    public init(page: LegalPage) { self.page = page }

    private var sections: [LegalContent.Section] {
        LegalContent.sections(for: page, language: i18n.lang)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t(page.titleKey))
                    .font(KraftFont.bebas(22)).tracking(1.1)
                    .foregroundColor(Theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i18n.t("saved.close"))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(KraftFont.bebas(16)).tracking(1)
                                .foregroundColor(Theme.accent)
                            Text(section.body)
                                .font(KraftFont.inter(13))
                                .foregroundColor(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)

                            if !section.rows.isEmpty {
                                dataTable(section.rows)
                                    .padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /*
      Zwei Spalten statt einer echten Tabelle: Auf einem Telefon in
      Hochkantlage bleibt für eine dritte Spalte kein lesbarer Platz, und ein
      seitlich scrollender Datenschutztext wäre schlimmer als keiner.
    */
    private func dataTable(_ rows: [LegalContent.DataRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: 10) {
                    Text(row.field)
                        .font(KraftFont.mono(11, .bold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 118, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(row.purpose)
                        .font(KraftFont.inter(12))
                        .foregroundColor(Theme.text.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(index % 2 == 0 ? Theme.surface : Color.clear)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/*
  Rechtssichere Inhalte für Impressum (§ 5 DDG, § 18 MStV) und Datenschutzerklärung (DSGVO).
*/
public enum LegalContent {

    /// Eine Zeile in einer Datentabelle: Was, wozu, wie lange.
    public struct DataRow: Identifiable {
        public let id = UUID()
        public let field: String
        public let purpose: String

        public init(_ field: String, _ purpose: String) {
            self.field = field
            self.purpose = purpose
        }
    }

    public struct Section: Identifiable {
        public let id = UUID()
        public let heading: String
        public let body: String
        /*
          Optionale Tabelle unter dem Fließtext.

          „Wir verarbeiten Gesundheitsdaten" ist als Satz richtig und als
          Auskunft wertlos — der Nutzer will wissen, WELCHE Angabe wofür
          gebraucht wird und wo sie landet. Als Aufzählung im Fließtext liest
          das niemand; als Tabelle schon.
        */
        public let rows: [DataRow]

        public init(heading: String, body: String, rows: [DataRow] = []) {
            self.heading = heading
            self.body = body
            self.rows = rows
        }
    }

    // MARK: - Stammdaten Betreiber

    public static let companyName     = "appoint"
    public static let ownerName       = "Shiv Mehra"
    public static let operatorName    = "appoint (Inhaber: Shiv Mehra)"
    public static let operatorAddress = "Max-Liebermann-Str. 82\n14612 Falkensee\nDeutschland"
    public static let operatorEmail   = "appoint.20@gmail.com"
    public static let operatorPhone   = "+49 152 23024756"
    public static let responsible     = "Shiv Mehra\nMax-Liebermann-Str. 82\n14612 Falkensee\nDeutschland"
    public static let vatID           = "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet und nicht ausgewiesen (Kleinunternehmerregelung)."

    public static var isComplete: Bool { true }

    // MARK: - Inhalt

    static func sections(for page: LegalPage, language: String) -> [Section] {
        let en = language == "en"
        switch page {
        case .imprint:  return en ? imprintEn : imprintDe
        case .privacy:  return en ? privacyEn : privacyDe
        }
    }

    private static var imprintDe: [Section] {
        [
            Section(
                heading: "Angaben gemäß § 5 DDG (Digitale-Dienste-Gesetz)",
                body: "\(operatorName)\n\(operatorAddress)"
            ),
            Section(
                heading: "Kontakt",
                body: "E-Mail: \(operatorEmail)\nTelefon: \(operatorPhone)"
            ),
            Section(
                heading: "Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV",
                body: responsible
            ),
            Section(
                heading: "Umsatzsteuer",
                body: vatID
            ),
            Section(
                heading: "EU-Streitschlichtung & Verbraucherstreitbeilegung",
                body: """
                Die Plattform der Europäischen Kommission zur Online-Streitbeilegung (OS-Plattform) \
                wurde zum 20. Juli 2025 eingestellt und steht nicht mehr zur Verfügung.

                Wir sind nicht bereit und nicht verpflichtet, an Streitbeilegungsverfahren vor einer \
                Verbraucherschlichtungsstelle teilzunehmen. Bei Beschwerden wende Dich bitte direkt an \
                \(operatorEmail) — wir antworten in der Regel innerhalb weniger Werktage.
                """
            ),
            Section(
                heading: "Haftungsausschluss & Gesundheitshinweis",
                body: """
                Die von Kraftwuerfel und dem KI-Coach bereitgestellten Trainings- und Ernährungspläne \
                sind allgemeine sportwissenschaftliche Empfehlungen und stellen keine medizinische, \
                therapeutische oder ernährungsmedizinische Beratung dar. Die Durchführung der Übungen \
                erfolgt auf eigene Verantwortung. Bei Vorerkrankungen, akuten Beschwerden oder \
                körperlichen Einschränkungen sollte vor Beginn des Trainings ein Arzt konsultiert werden.
                """
            ),
        ]
    }

    private static var imprintEn: [Section] {
        [
            Section(
                heading: "Provider according to § 5 DDG (Digital Services Act)",
                body: "\(operatorName)\n\(operatorAddress)"
            ),
            Section(
                heading: "Contact",
                body: "Email: \(operatorEmail)\nPhone: \(operatorPhone)"
            ),
            Section(
                heading: "Responsible for content (§ 18 (2) MStV)",
                body: responsible
            ),
            Section(
                heading: "VAT & Small Business Regulation",
                body: "Pursuant to § 19 UStG (German Small Business Regulation), no VAT is charged or stated."
            ),
            Section(
                heading: "Online Dispute Resolution",
                body: """
                The European Commission's Online Dispute Resolution (ODR) platform was shut down on \
                20 July 2025 and is no longer available.

                We are neither willing nor obliged to participate in dispute resolution proceedings before a \
                consumer arbitration board. For complaints, please contact \(operatorEmail) directly — \
                we usually reply within a few business days.
                """
            ),
            Section(
                heading: "Disclaimer & Health Notice",
                body: """
                The training and nutrition plans generated by Kraftwuerfel and the AI Coach are \
                general recommendations and do not replace professional medical or nutritional advice. \
                Workouts are performed at your own risk. If you have pre-existing conditions or symptoms, \
                consult a physician before starting any training.
                """
            ),
        ]
    }

    private static var privacyDe: [Section] {
        [
            Section(
                heading: "1. Verantwortlicher & Grundsätze",
                body: """
                Verantwortlicher für die Datenverarbeitung ist:
                \(operatorName)
                \(operatorAddress)
                E-Mail: \(operatorEmail) | Telefon: \(operatorPhone)

                Kraftwuerfel folgt dem Prinzip der Datensparsamkeit und Zweckbindung (Art. 5 DSGVO). \
                Wir erheben und verarbeiten ausschließlich Daten, die für die Bereitstellung des \
                Benutzerkontos, die Synchronisation des Pro-Status und die Generierung von individuellen \
                Trainings- und Ernährungsplänen erforderlich sind.

                Werbung: Für Nutzerinnen und Nutzer ohne Pro-Abo bindet die App Google AdMob ein \
                (Google Ireland Limited). Dabei können Gerätekennungen und Nutzungsdaten an Google \
                übertragen und dort auch außerhalb der EU verarbeitet werden. Vor dem ersten Laden \
                fragen wir Deine Einwilligung über Googles User Messaging Platform ab (Art. 6 Abs. 1 \
                lit. a DSGVO) sowie zusätzlich Apples Tracking-Erlaubnis. Lehnst Du ab, siehst Du \
                weiterhin Werbung, aber keine personalisierte. Mit einem Pro-Abo entfällt die \
                Werbung vollständig — dann wird das Werbe-SDK gar nicht erst geladen. \
                Analyse-Cookies und geräteübergreifendes Tracking durch uns selbst gibt es nicht.
                """
            ),
            Section(
                heading: "2. Personenbezogene Daten & Anonyme Nutzung",
                body: """
                Der Begriff der personenbezogenen Daten ist im Bundesdatenschutzgesetz (BDSG) und in der \
                EU-DSGVO definiert. Danach sind dies Einzelangaben über persönliche oder sachliche \
                Verhältnisse einer bestimmten oder bestimmbaren natürlichen Person (z. B. Name, E-Mail-Adresse, \
                biometrische Trainings- und Ernährungsdaten).

                Für die Nutzung der App ist ein Konto erforderlich (E-Mail-Adresse und Passwort). \
                Ohne Anmeldung lässt sich die App nicht verwenden — Trainingspläne, Fortschritt und \
                ein etwaiges Pro-Abo hängen am Konto und nicht am Gerät. Der Fragebogen zu Deinem \
                Profil ist davon unabhängig und bleibt freiwillig; Du kannst ihn überspringen und \
                später ausfüllen.

                Beim Aufruf der App und der Kommunikation mit unserer Backend-API (Render Services, Inc., \
                Rechenzentrum Frankfurt am Main / EU) werden technisch notwendige Zugriffsdaten \
                (iOS-Betriebssystemversion, IP-Adresse, Datum und Uhrzeit des Aufrufs sowie Gerätemodell) \
                in flüchtigen Server-Logfiles verarbeitet. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO \
                (berechtigtes Interesse an der Gewährleistung von Systemsicherheit und Stabilität).
                """
            ),
            Section(
                heading: "3. Benutzerkonto & Authentifizierung (PostgreSQL & Mailjet)",
                body: """
                Bei der Registrierung eines Benutzerkontos speichern wir folgende Daten in unserer \
                abgesicherten PostgreSQL-Datenbank:

                • E-Mail-Adresse (Benutzeridentifikation und Login)
                • Passwort-Hash (gespeichert als irreversibler kryptografischer Hash mit BCrypt, Work Factor 12; niemals im Klartext)
                • Optionaler Anzeigename / Vorname
                • Pro-Status (is_premium zur Freischaltung erworbener Funktionen)
                • Refresh-Token (gespeichert als SHA-256 Hash zur sicheren Sitzungsverwaltung)
                • Bestätigungs- und Reset-Tokens (zeitlich befristet für maximal 24 Stunden)

                Für den transaktionalen E-Mail-Versand (E-Mail-Bestätigung und Passwort-Reset) nutzen \
                wir Mailjet (Sinch SAS, Frankreich / Deutschland) auf Basis eines AV-Vertrags nach Art. 28 DSGVO.

                Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung) sowie Art. 6 Abs. 1 lit. f DSGVO (Sicherheit).
                """
            ),
            Section(
                heading: "4. Datenerhebung für den KI-Coach (Die 13 Fitnessparameter)",
                body: """
                Zur sportwissenschaftlichen Erstellung Deines Trainings- und Ernährungsplans erfassen \
                wir im KI-Assistenten folgende 13 Parameter:

                1. Trainingsziel (z. B. Muskelaufbau, Kraftaufbau, Fettabbau, Definition)
                2. Trainingserfahrung (Anfänger, Fortgeschritten, Profi)
                3. Biologisches Geschlecht (zur Grundumsatz- & Physiologieberechnung)
                4. Alter (zur Bestimmung von Regenerationszeiten & Pausen)
                5. Körpergewicht in kg (zur Kalorien- & Proteinbedarfsberechnung)
                6. Körpergröße in cm (zur BMI- & Energieumsatzermittlung)
                7. Zielgewicht in kg (zur Steuerung von Kaloriendefizit/-überschuss)
                8. Trainingstage (Wochentage zur Split-Periodisierung)
                9. Dauer pro Einheit in Minuten (zur Volumen- & Übungsbegrenzung)
                10. Planlänge in Wochen (zur Periodisierungsplanung)
                11. Trainingsmethode (z. B. Standard, 5x5, Pyramidentraining, Drop-Sets)
                12. Verfügbares Equipment (zur Filterung kompatibler Übungen)
                13. Ernährungsform (Omnivor, Vegetarisch, Lakto-Vegetarisch, Vegan)

                Dieselben Angaben werden auch im Fragebogen der Home-Challenge erhoben, dort ergänzt um \
                die Länge der Challenge in Tagen und die Trainingstage pro Woche.

                Speicherung — was tatsächlich passiert: Die Angaben selbst werden nicht als Profil zu \
                Deinem Konto gespeichert. Sie werden für die Berechnung im Arbeitsspeicher verarbeitet \
                und an das Sprachmodell weitergereicht.

                Zwischenspeicher (Plan-Cache): Der FERTIGE Plan wird für 14 Tage in unserer \
                PostgreSQL-Datenbank zwischengespeichert, damit eine identische Anfrage nicht erneut \
                berechnet werden muss. Adressiert wird dieser Eintrag über einen nicht umkehrbaren \
                SHA-256-Prüfwert, der aus Deinen Antworten gebildet wird. Der Eintrag enthält weder Deine \
                E-Mail-Adresse noch Deine Konto-ID; er lässt sich Dir also nicht direkt zuordnen. Der \
                zwischengespeicherte Plan ist jedoch aus Gesundheitsangaben abgeleitet — wir behandeln ihn \
                deshalb wie Gesundheitsdaten. Nach 14 Tagen läuft der Eintrag ab.

                Besondere Datenkategorie (Art. 9 DSGVO): Diese Angaben stellen Gesundheitsdaten dar. \
                Rechtsgrundlage ist Deine ausdrückliche Einwilligung nach Art. 9 Abs. 2 lit. a DSGVO. \
                Du erteilst sie, indem Du den Fragebogen absendest; Du kannst sie jederzeit mit Wirkung \
                für die Zukunft widerrufen (Art. 7 Abs. 3 DSGVO), indem Du die Funktion nicht weiter \
                nutzt oder Dein Konto löschst.

                KI-Inferenz (OpenRouter): Die Parameter werden in anonymisierter Form (ohne Namen, \
                ohne E-Mail-Adresse) an OpenRouter Inc. (USA) übermittelt. Die Übermittlung erfolgt \
                TLS-verschlüsselt auf Basis von EU-Standardvertragsklauseln (Art. 46 DSGVO). \
                Deine Prompt-Daten werden gemäß den geltenden Richtlinien nicht zum Trainieren öffentlicher \
                KI-Modelle verwendet.
                """
            ),
            Section(
                heading: "5a. Dein Profil — nur auf diesem Gerät",
                body: """
                Diese Angaben machst Du im Fragebogen nach der Registrierung. Sie liegen \
                ausschließlich auf Deinem Gerät (UserDefaults) und werden von uns NICHT in einer \
                Datenbank gespeichert. Wir können sie nicht einsehen.

                Warum wir sie brauchen: Ein Trainingsplan, der nicht weiß, wie schwer Du bist, wie \
                oft Du trainieren kannst und welche Geräte Du hast, ist geraten. Alle Angaben sind \
                freiwillig — ohne sie erstellt der Coach keinen Plan, die übrige App funktioniert.

                Zum Erzeugen eines KI-Plans werden sie einmalig an unseren Dienst gesendet (siehe \
                Abschnitt 4); dort werden sie verarbeitet, aber nicht mit Deinem Konto verknüpft \
                abgelegt. Beim Löschen Deines Kontos werden sie auf dem Gerät vollständig entfernt.
                """,
                rows: [
                    DataRow("Geschlecht", "Grundumsatz (Mifflin-St Jeor) und Belastungsregeln — Art. 9 DSGVO"),
                    DataRow("Alter", "Grundumsatz, Aufwärmumfang und Regenerationsbedarf — Art. 9 DSGVO"),
                    DataRow("Größe · Gewicht", "BMI, Grundumsatz, Kalorien- und Makroberechnung — Art. 9 DSGVO"),
                    DataRow("Zielgewicht", "Kalorienüber- oder -defizit im Ernährungsplan — Art. 9 DSGVO"),
                    DataRow("Körpertyp", "Feinjustierung der Makronährstoffe"),
                    DataRow("Aktivitätsgrad", "Gesamtumsatz (TDEE) neben dem Training"),
                    DataRow("Trainingsziel", "Sätze, Wiederholungen und Kalorienziel"),
                    DataRow("Erfahrung", "Übungsauswahl und Belastung; Anfänger bekommen keine Maximallasten"),
                    DataRow("Selbsteinschätzung", "Liegestütze, Klimmzüge, Plank — Startniveau der Körperübungen"),
                    DataRow("Trainingsort", "Bestimmt, welche Geräte überhaupt in Frage kommen"),
                    DataRow("Equipment", "Es werden nur Übungen geplant, die Du ausführen kannst"),
                    DataRow("Trainingstage", "Verteilung des Plans über die Woche"),
                    DataRow("Einheitsdauer", "Anzahl der Übungen pro Trainingstag"),
                    DataRow("Satzpause", "Obergrenze der Pause zwischen zwei Sätzen"),
                    DataRow("Planlänge · Methode", "Progression über die Wochen und Satzschema"),
                    DataRow("Ernährungsform", "Rezeptauswahl und Makroverteilung — Art. 9 DSGVO"),
                    DataRow("Einschränkungen", "Freitext zu Verletzungen und Wünschen — Art. 9 DSGVO"),
                ]
            ),
            Section(
                heading: "5b. Was in unserer Datenbank liegt",
                body: """
                Nur das Folgende wird auf unserem Server (PostgreSQL bei Render, Frankfurt am Main) \
                gespeichert. Alles andere — Profil, Pläne, Trainingsarchiv, Favoriten, Einstellungen — \
                bleibt auf Deinem Gerät.
                """,
                rows: [
                    DataRow("E-Mail-Adresse", "Anmeldung, Bestätigungs- und Passwort-Reset-Mails — bis zur Kontolöschung"),
                    DataRow("Passwort-Hash", "BCrypt, nicht umkehrbar — wir kennen Dein Passwort nicht"),
                    DataRow("is_premium", "Ob ein geprüftes Pro-Abo vorliegt — bis zur Kontolöschung"),
                    DataRow("E-Mail bestätigt", "Ob die Adresse bestätigt wurde"),
                    DataRow("Bestätigungs- und Reset-Token", "Einmalig, mit Ablaufdatum; danach wertlos"),
                    DataRow("Refresh-Token (Hash)", "Angemeldet bleiben; nur der Hash, max. 30 Tage"),
                    DataRow("Plan-Zwischenspeicher", "Erzeugter Plan als JSON, 14 Tage, adressiert über einen SHA-256-Schlüssel aus den Antworten — ohne Konto-ID und ohne E-Mail"),
                    DataRow("Tageszähler", "Anzahl der KI-Anfragen pro Tag gegen Missbrauch; Konto-ID und Tag, sonst nichts"),
                    DataRow("Zeitstempel", "Erstellt/geändert am — technische Nachvollziehbarkeit"),
                ]
            ),
            Section(
                heading: "5. Apple Health & Lokale Speicherung",
                body: """
                • Apple Health (HealthKit) — Lesen: Mit Deiner Erlaubnis liest die App Deine Herzfrequenz \
                (Anzeige während der Live-Session) sowie Gewicht, Größe, Körperfettanteil, Geburtsdatum \
                und Geschlecht. Letztere werden ausschließlich dazu verwendet, den Fragebogen nach der \
                Registrierung vorauszufüllen, damit Du sie nicht abtippen musst.
                • Apple Health (HealthKit) — Schreiben: Mit Deiner Erlaubnis schreibt die App Dein Gewicht \
                und Deinen Körperfettanteil (Deine eigenen Eingaben aus dem Profil) sowie abgeschlossene \
                Trainings nach Apple Health. Aktive Energie wird nur geschrieben, wenn sie von einer Apple \
                Watch gemessen wurde. Geschätzte oder gerechnete Werte — etwa die Puls- und Kalorien\u{00AD}schätzung \
                der Live-Session ohne Uhr — werden ausdrücklich NIE nach Apple Health geschrieben.
                • Health-Daten verbleiben zu 100 % lokal auf Deinem Endgerät und werden zu keinem \
                Zeitpunkt an unsere Server übertragen. Du kannst jede einzelne Berechtigung jederzeit in \
                der Health-App unter „Datenzugriff & Geräte" widerrufen.
                • Lokale Speicherung: Dein Profil (Körperdaten, Ziel, Ausrüstung, Ernährungsform), \
                gespeicherte Pläne, das Trainingsarchiv, Einstellungen und Würfelergebnisse werden \
                lokal in UserDefaults bzw. im iOS-Schlüsselbund (Keychain für Sitzungs-Tokens) abgelegt. \
                Das Profil enthält Gesundheitsdaten im Sinne von Art. 9 DSGVO und wird beim Löschen \
                Deines Kontos vollständig mit entfernt.
                • Mitteilungen: Auf Wunsch erinnert Dich die App an Deinen Trainingstagen um 09:00 Uhr \
                und 30 Minuten nach einer beendeten Einheit an Deinen Protein-Shake. Diese Erinnerungen \
                werden ausschließlich lokal auf Deinem Gerät geplant; es findet kein Versand über \
                Push-Server statt und wir erfahren nicht, ob oder wann sie erscheinen.
                """
            ),
            Section(
                heading: "6. Pro-Abonnements & Zahlungen (Apple StoreKit 2)",
                body: """
                Käufe von Pro-Abonnements werden direkt über Apple Distribution International Ltd. (Irland) \
                abgewickelt. Unsere API verifiziert lediglich die kryptografische JWS-Transaktionsquittung \
                von Apple (StoreKit 2) und schaltet den Pro-Status frei. Wir verarbeiten oder speichern \
                zu keinem Zeitpunkt Kreditkarten- oder Bankdaten (Art. 6 Abs. 1 lit. b DSGVO).
                """
            ),
            Section(
                heading: "6a. Empfänger & Auftragsverarbeiter (Art. 13 Abs. 1 lit. e DSGVO)",
                body: """
                Wir geben Deine Daten nicht zu Werbezwecken weiter und verkaufen sie nicht. \
                Eingebunden sind ausschließlich folgende Dienstleister:

                • Render Services, Inc. (USA) — Hosting von API und PostgreSQL-Datenbank, Region \
                Frankfurt am Main (EU). Auftragsverarbeitung nach Art. 28 DSGVO, EU-Standard\u{00AD}vertrags\u{00AD}klauseln.
                • Sinch/Mailjet SAS (Frankreich) — Versand der Bestätigungs- und Passwort-Reset-Mails. \
                Empfängt ausschließlich Deine E-Mail-Adresse und den jeweiligen Token.
                • OpenRouter, Inc. (USA) — KI-Inferenz für Trainings- und Ernährungspläne. Empfängt die \
                Fragebogenangaben ohne Namen, ohne E-Mail-Adresse und ohne Konto-ID. Übermittlung \
                TLS-verschlüsselt auf Basis von EU-Standardvertragsklauseln (Art. 46 DSGVO).
                • Apple Distribution International Ltd. (Irland) — Abwicklung der Abonnements. Wir erhalten \
                von Apple nur die signierte Kaufquittung, keine Zahlungsdaten.

                Keine Werbenetzwerke, keine Analyse-SDKs, kein Tracking über App- oder Websitegrenzen \
                hinweg. Die App fragt deshalb auch nicht nach einer Tracking-Erlaubnis (ATT).
                """
            ),
            Section(
                heading: "6b. Automatisierte Entscheidungen & KI",
                body: """
                Trainings- und Ernährungspläne werden automatisiert durch ein Sprachmodell erzeugt. Es \
                handelt sich dabei um eine Empfehlung ohne rechtliche Wirkung und ohne vergleichbare \
                erhebliche Beeinträchtigung im Sinne von Art. 22 DSGVO. Die Pläne ersetzen keine \
                medizinische, therapeutische oder ernährungsmedizinische Beratung. Du entscheidest \
                selbst, ob und wie Du sie umsetzt, und kannst jeden Plan in der App anpassen.

                Deine Eingaben werden nach den Richtlinien des Anbieters nicht zum Training öffentlicher \
                KI-Modelle verwendet.
                """
            ),
            Section(
                heading: "7. Technische Sicherheitsmaßnahmen (TOMs)",
                body: """
                • Durchgehende Transportverschlüsselung via TLS 1.3 / HTTPS mit Perfect Forward Secrecy.
                • Passwörter werden vor der Speicherung mit BCrypt (Work Factor 12) gesalzen und gehasht.
                • Token-Sicherheit: Zeitlich begrenzte JSON Web Tokens (JWT) und 64-Byte Refresh-Tokens, \
                die in der Datenbank ausschließlich als SHA-256-Hash hinterlegt sind.
                """
            ),
            Section(
                heading: "8. Speicherdauer & Löschung",
                body: """
                Wir speichern personenbezogene Daten nur so lange, wie es für die Bereitstellung der Dienste \
                notwendig ist:

                • Kontodaten (E-Mail, Passwort-Hash, Pro-Status): bis zur Löschung des Kontos.
                • Sitzungs- und Refresh-Tokens: bis zum Ablauf, zur Abmeldung oder zur Kontolöschung.
                • Bestätigungs- und Reset-Tokens: maximal 24 Stunden.
                • Plan-Zwischenspeicher: 14 Tage ab Erstellung, danach läuft der Eintrag ab.
                • Server-Logs: flüchtig, nur zur Störungssuche und Missbrauchsabwehr.

                Bei Löschung Deines Kontos werden alle Kontodaten und Sitzungs-Tokens unverzüglich und \
                vollständig aus der PostgreSQL-Datenbank gelöscht (ON DELETE CASCADE). Du löschst Dein Konto \
                direkt in der App unter Einstellungen. Einträge im Plan-Zwischenspeicher enthalten keine \
                Kontokennung und laufen unabhängig davon nach spätestens 14 Tagen ab.

                Lokal auf Deinem Gerät gespeicherte Daten (gespeicherte Pläne, Favoriten, Trainingstagebuch, \
                Einstellungen, Fragebogen-Antworten) werden beim Löschen des Kontos ebenfalls entfernt und \
                verschwinden in jedem Fall mit dem Deinstallieren der App.
                """
            ),
            Section(
                heading: "9. Deine Betroffenenrechte (Art. 15–22 DSGVO)",
                body: """
                Dir stehen nach der EU-DSGVO folgende Rechte zu:
                • Auskunftsrecht (Art. 15 DSGVO)
                • Berichtigungsrecht (Art. 16 DSGVO)
                • Löschungsrecht / Recht auf Vergessenwerden (Art. 17 DSGVO)
                • Einschränkung der Verarbeitung (Art. 18 DSGVO)
                • Datenübertragbarkeit (Art. 20 DSGVO)
                • Widerspruchsrecht (Art. 21 DSGVO)
                • Widerruf erteilter Einwilligungen mit Wirkung für die Zukunft (Art. 7 Abs. 3 DSGVO)
                • Beschwerderecht bei einer Datenschutz-Aufsichtsbehörde (Art. 77 DSGVO)

                Kontakt für Datenschutzfragen und Auskunft: \(operatorEmail).
                """
            ),
        ]
    }

    private static var privacyEn: [Section] {
        [
            Section(
                heading: "1. Data Controller & Principles",
                body: """
                The data controller is:
                \(operatorName)
                \(operatorAddress)
                Email: \(operatorEmail) | Phone: \(operatorPhone)

                Kraftwuerfel complies strictly with the principles of data minimization and purpose limitation \
                (Art. 5 GDPR). We only process data required to provide your account, sync your Pro status, \
                and generate customized workout and nutrition plans.

                Advertising: for users without a Pro subscription the app embeds Google AdMob \
                (Google Ireland Limited). This can transmit device identifiers and usage data to \
                Google, including processing outside the EU. Before anything is loaded we ask for \
                your consent via Google's User Messaging Platform (Art. 6(1)(a) GDPR) and \
                additionally for Apple's tracking permission. If you decline you still see ads, but \
                not personalised ones. With a Pro subscription ads disappear entirely — the ad SDK \
                is then never loaded at all. We use no analytics cookies and do no cross-device \
                tracking of our own.
                """
            ),
            Section(
                heading: "2. Personal Data & Anonymous Usage",
                body: """
                Personal data refers to any information relating to an identified or identifiable natural \
                person (e.g. name, email, workout preferences, and biometric metrics).

                Using the app requires an account (email address and password). Without signing in the \
                app cannot be used — training plans, progress and any Pro subscription belong to the \
                account, not to the device. The profile questionnaire is separate and stays optional; \
                you can skip it and fill it in later.

                When accessing the app or our backend API (Render Services, Inc., Frankfurt am Main / EU), \
                technical log data (iOS version, IP address, timestamp, device model) is temporarily processed \
                in server logs for security and stability purposes (Art. 6 (1) (f) GDPR).
                """
            ),
            Section(
                heading: "3. User Account & Authentication (PostgreSQL & Mailjet)",
                body: """
                When you create an account, we securely store the following data in our PostgreSQL database:

                • Email address (login and account identification)
                • Password hash (irreversible cryptographic hash using BCrypt with Work Factor 12; never plaintext)
                • Optional display name / first name
                • Subscription status (is_premium entitlement)
                • Refresh tokens (stored as SHA-256 hashes for secure session rotation)
                • Activation and password reset tokens (temporary, valid for 24 hours maximum)

                For transactional emails (email confirmation and password reset), we use Mailjet (Sinch SAS, \
                France / Germany) under a Data Processing Agreement (Art. 28 GDPR).

                Legal basis: Art. 6 (1) (b) GDPR (contract performance) and Art. 6 (1) (f) GDPR (security).
                """
            ),
            Section(
                heading: "4. Data Collection for AI Coach (The 13 Fitness Parameters)",
                body: """
                To calculate customized workout and meal plans, we process the following 13 parameters in the AI wizard:

                1. Fitness goal (e.g. muscle hypertrophy, strength, fat loss, definition)
                2. Experience level (beginner, intermediate, advanced)
                3. Biological sex (for metabolic & physiological calculations)
                4. Age (for recovery times and rest periods)
                5. Body weight in kg (for calorie and protein targets)
                6. Height in cm (for BMI and energy expenditure)
                7. Goal weight in kg (for calorie deficit/surplus calibration)
                8. Training days (weekdays for split periodization)
                9. Session duration in minutes (for volume & exercise limits)
                10. Plan length in weeks (for progressive overload structure)
                11. Training method (e.g. standard, 5x5, pyramid, drop sets)
                12. Available equipment (to filter compatible exercises)
                13. Dietary preference (omnivore, vegetarian, lacto-vegetarian, vegan)

                The same parameters are collected in the Home Challenge questionnaire, extended by the \
                challenge length in days and the number of training days per week.

                What is actually stored: The parameters themselves are not kept as a profile attached to \
                your account. They are processed in memory for the calculation and passed to the language model.

                Plan cache: The RESULTING plan is cached in our PostgreSQL database for 14 days so that an \
                identical request does not have to be recomputed. The entry is addressed by a non-reversible \
                SHA-256 digest derived from your answers. It contains neither your email address nor your \
                account ID, so it cannot be directly attributed to you. The cached plan is nevertheless \
                derived from health information, and we treat it as health data. Entries expire after 14 days.

                Special Category (Art. 9 GDPR): These represent health data. Legal basis: explicit consent \
                pursuant to Art. 9 (2) (a) GDPR, given by submitting the questionnaire. You may withdraw it \
                at any time with future effect (Art. 7 (3) GDPR) by discontinuing use or deleting your account.

                AI Inference (OpenRouter): Anonymized parameters (without name or email) are sent to \
                OpenRouter Inc. (USA) via TLS encryption under EU Standard Contractual Clauses (Art. 46 GDPR). \
                Your data is never used to train public AI models.
                """
            ),
            Section(
                heading: "5a. Your profile — on this device only",
                body: """
                You provide these answers in the questionnaire after registration. They live \
                exclusively on your device (UserDefaults) and are NOT stored in a database by us. \
                We cannot see them.

                Why we need them: a training plan that does not know your weight, how often you can \
                train and what equipment you have is guesswork. All answers are optional — without \
                them the coach cannot build a plan, but the rest of the app works.

                To generate an AI plan they are sent once to our service (see section 4); they are \
                processed there but not stored linked to your account. Deleting your account removes \
                them from the device entirely.
                """,
                rows: [
                    DataRow("Sex", "Basal metabolic rate (Mifflin-St Jeor) and loading rules — Art. 9 GDPR"),
                    DataRow("Age", "Metabolic rate, warm-up volume and recovery need — Art. 9 GDPR"),
                    DataRow("Height · weight", "BMI, metabolic rate, calorie and macro calculation — Art. 9 GDPR"),
                    DataRow("Target weight", "Calorie surplus or deficit in the nutrition plan — Art. 9 GDPR"),
                    DataRow("Body type", "Fine-tuning of the macronutrient split"),
                    DataRow("Activity level", "Total daily expenditure (TDEE) beside training"),
                    DataRow("Training goal", "Sets, reps and calorie target"),
                    DataRow("Experience", "Exercise selection and load; beginners get no maximal loads"),
                    DataRow("Self-assessment", "Push-ups, pull-ups, plank — starting level for bodyweight work"),
                    DataRow("Training location", "Determines which equipment is possible at all"),
                    DataRow("Equipment", "Only exercises you can actually perform are planned"),
                    DataRow("Training days", "Distribution of the plan across the week"),
                    DataRow("Session length", "Number of exercises per training day"),
                    DataRow("Rest time", "Upper limit for the pause between two sets"),
                    DataRow("Plan length · method", "Progression across weeks and the set scheme"),
                    DataRow("Diet", "Recipe selection and macro split — Art. 9 GDPR"),
                    DataRow("Limitations", "Free text on injuries and preferences — Art. 9 GDPR"),
                ]
            ),
            Section(
                heading: "5b. What we store in our database",
                body: """
                Only the following is stored on our server (PostgreSQL at Render, Frankfurt am Main). \
                Everything else — profile, plans, training archive, favourites, settings — stays on \
                your device.
                """,
                rows: [
                    DataRow("Email address", "Sign-in, confirmation and password reset mails — until account deletion"),
                    DataRow("Password hash", "BCrypt, not reversible — we do not know your password"),
                    DataRow("is_premium", "Whether a verified Pro subscription exists — until account deletion"),
                    DataRow("Email confirmed", "Whether the address has been confirmed"),
                    DataRow("Confirm / reset token", "Single use, with an expiry date; worthless afterwards"),
                    DataRow("Refresh token (hash)", "Staying signed in; hash only, max. 30 days"),
                    DataRow("Plan cache", "Generated plan as JSON, 14 days, addressed by a SHA-256 key derived from your answers — no account ID, no email"),
                    DataRow("Daily counter", "Number of AI requests per day to prevent abuse; account ID and day, nothing else"),
                    DataRow("Timestamps", "Created/updated at — technical traceability"),
                ]
            ),
            Section(
                heading: "5. Apple Health & Local Storage",
                body: """
                • Apple Health (HealthKit) — reading: With your permission the app reads your heart rate \
                (shown during the live session) as well as weight, height, body fat, date of birth and \
                sex. The latter are used solely to pre-fill the questionnaire after registration so you \
                do not have to type them.
                • Apple Health (HealthKit) — writing: With your permission the app writes your weight and \
                body fat (your own entries from your profile) and finished workouts to Apple Health. \
                Active energy is only written when it was measured by an Apple Watch. Estimated or \
                calculated values — such as the heart rate and calorie estimate shown during a live \
                session without a watch — are explicitly NEVER written to Apple Health.
                • Health data stays 100% on your local device and is never sent to our servers. You can \
                revoke each individual permission at any time in the Health app under "Data Access & Devices".
                • Local storage: your profile (body data, goal, equipment, diet), saved plans, the training \
                archive, settings and dice results are stored locally in UserDefaults and the iOS Keychain \
                (session tokens). Your profile contains health data within the meaning of Art. 9 GDPR and \
                is removed in full when you delete your account.
                • Notifications: if you allow it, the app reminds you at 09:00 on your training days and \
                30 minutes after a finished session to have your protein shake. These reminders are \
                scheduled locally on your device only; nothing is sent through push servers and we do not \
                learn whether or when they appear.
                """
            ),
            Section(
                heading: "6. Pro Subscriptions & Payments (Apple StoreKit 2)",
                body: """
                In-app purchases are processed directly by Apple Distribution International Ltd. (Ireland). \
                Our backend only verifies Apple's cryptographic JWS transaction receipt (StoreKit 2) to \
                activate Pro access. We never receive or store payment or credit card details (Art. 6 (1) (b) GDPR).
                """
            ),
            Section(
                heading: "6a. Recipients & Processors (Art. 13 (1) (e) GDPR)",
                body: """
                We do not share your data for advertising purposes and we do not sell it. Only the \
                following processors are involved:

                • Render Services, Inc. (USA) — hosting of the API and PostgreSQL database, Frankfurt am \
                Main (EU) region. Processing under Art. 28 GDPR with EU Standard Contractual Clauses.
                • Sinch/Mailjet SAS (France) — delivery of confirmation and password reset emails. Receives \
                only your email address and the respective token.
                • OpenRouter, Inc. (USA) — AI inference for workout and nutrition plans. Receives the \
                questionnaire values without your name, email address or account ID. Transmitted over TLS \
                under EU Standard Contractual Clauses (Art. 46 GDPR).
                • Apple Distribution International Ltd. (Ireland) — subscription processing. We receive only \
                the signed purchase receipt from Apple, never payment details.

                No ad networks, no analytics SDKs, no cross-app or cross-site tracking. The app therefore \
                never asks for tracking permission (ATT).
                """
            ),
            Section(
                heading: "6b. Automated Decisions & AI",
                body: """
                Workout and nutrition plans are generated automatically by a language model. They are \
                recommendations with no legal effect and no similarly significant impact within the meaning \
                of Art. 22 GDPR. They do not replace medical, therapeutic or dietary advice. You decide \
                whether and how to follow them, and every plan can be edited in the app.

                Your inputs are not used to train public AI models, in line with the provider's policies.
                """
            ),
            Section(
                heading: "7. Technical Security Measures (TOMs)",
                body: """
                • End-to-end TLS 1.3 / HTTPS encryption with Perfect Forward Secrecy.
                • BCrypt salted password hashing (Work Factor 12).
                • Signed short-lived JSON Web Tokens (JWT) and cryptographically secure SHA-256 hashed refresh tokens.
                """
            ),
            Section(
                heading: "8. Retention & Account Deletion",
                body: """
                We retain personal data only as long as necessary:

                • Account data (email, password hash, Pro status): until you delete your account.
                • Session and refresh tokens: until expiry, sign-out, or account deletion.
                • Activation and reset tokens: 24 hours maximum.
                • Plan cache: 14 days from creation, then the entry expires.
                • Server logs: transient, for troubleshooting and abuse prevention only.

                When you delete your account, your data and all associated tokens are immediately and \
                completely purged from the PostgreSQL database (ON DELETE CASCADE). You can delete your \
                account directly in the app under Settings. Plan cache entries carry no account identifier \
                and expire after 14 days regardless.

                Data stored locally on your device (saved plans, favorites, workout diary, settings, \
                questionnaire answers) is also removed when you delete your account, and is removed in any \
                case when you uninstall the app.
                """
            ),
            Section(
                heading: "9. Your Rights (Articles 15–22 GDPR)",
                body: """
                Under the EU GDPR, you have the right to:
                • Access your data (Art. 15 GDPR)
                • Rectification (Art. 16 GDPR)
                • Erasure / Right to be forgotten (Art. 17 GDPR)
                • Restriction of processing (Art. 18 GDPR)
                • Data portability (Art. 20 GDPR)
                • Object to processing (Art. 21 GDPR)
                • Withdraw consent at any time (Art. 7 (3) GDPR)
                • Lodge a complaint with a data protection authority (Art. 77 GDPR)

                Contact: \(operatorEmail).
                """
            ),
        ]
    }
}
