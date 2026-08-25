import SwiftUI

/*
  Impressum und Datenschutzerklärung.

  WICHTIG — bitte vor der Einreichung lesen:

  Der Inhalt unten ist ein Gerüst, kein fertiger Text. Die Stellen in
  spitzen Klammern sind Platzhalter und müssen mit den echten Angaben des
  Betreibers gefüllt werden. Solange auch nur einer davon steht, blendet die
  Ansicht oben einen sichtbaren Hinweis ein — und `LegalContent.isComplete`
  meldet `false`, damit es nicht versehentlich mitgeht.

  Ein Impressum mit falschen Angaben ist in Deutschland abmahnfähig, und eine
  Datenschutzerklärung, die nicht beschreibt, was die App tatsächlich tut, ist
  schlimmer als keine. Deshalb steht hier nichts Erfundenes.
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
                VStack(alignment: .leading, spacing: 20) {
                    if !LegalContent.isComplete {
                        placeholderWarning
                    }
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.heading)
                                .font(KraftFont.bebas(16)).tracking(1)
                                .foregroundColor(Theme.accent)
                            Text(section.body)
                                .font(KraftFont.inter(13))
                                .foregroundColor(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
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

    private var placeholderWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.orange)
            Text(i18n.t("legal.placeholderWarning"))
                .font(KraftFont.inter(12.5, .semibold))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.5), lineWidth: 1))
    }
}

/*
  Der Text selbst. Eine Datei, zwei Sprachen, klar markierte Lücken — damit
  niemand suchen muss, was noch fehlt.
*/
public enum LegalContent {

    public struct Section: Identifiable {
        public let id = UUID()
        public let heading: String
        public let body: String
    }

    // MARK: - Auszufüllen

    static let operatorName    = "<Betreiber / Firma>"
    static let operatorAddress = "<Straße Hausnummer>\n<PLZ Ort>\n<Land>"
    static let operatorEmail   = "<kontakt@example.com>"
    static let responsible     = "<Name der verantwortlichen Person>"
    static let vatID           = "<USt-IdNr., falls vorhanden>"

    /// `false`, solange irgendwo noch ein Platzhalter steht.
    public static var isComplete: Bool {
        ![operatorName, operatorAddress, operatorEmail, responsible, vatID]
            .contains { $0.contains("<") }
    }

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
            Section(heading: "Angaben gemäß § 5 DDG",
                    body: "\(operatorName)\n\(operatorAddress)"),
            Section(heading: "Kontakt",
                    body: "E-Mail: \(operatorEmail)"),
            Section(heading: "Verantwortlich für den Inhalt",
                    body: responsible),
            Section(heading: "Umsatzsteuer-Identifikationsnummer",
                    body: vatID),
            Section(heading: "Haftung für Inhalte",
                    body: """
                    Die Trainings- und Ernährungspläne dieser App sind allgemeine \
                    Vorschläge und ersetzen keine ärztliche oder therapeutische \
                    Beratung. Wer Vorerkrankungen hat, Beschwerden bemerkt oder \
                    Medikamente nimmt, spricht vor dem Training mit einer Ärztin \
                    oder einem Arzt.
                    """),
        ]
    }

    private static var imprintEn: [Section] {
        [
            Section(heading: "Provider", body: "\(operatorName)\n\(operatorAddress)"),
            Section(heading: "Contact", body: "Email: \(operatorEmail)"),
            Section(heading: "Responsible for content", body: responsible),
            Section(heading: "VAT identification number", body: vatID),
            Section(heading: "Liability for content",
                    body: """
                    The training and nutrition plans in this app are general \
                    suggestions and do not replace medical or therapeutic advice. \
                    If you have a pre-existing condition, notice symptoms, or take \
                    medication, talk to a doctor before training.
                    """),
        ]
    }

    /*
      Der Datenschutzteil beschreibt, was die App heute tatsächlich tut. Wer
      etwas daran ändert — Anmeldung anbinden, Analysewerkzeug einbauen —, muss
      diesen Text UND das Datenschutzmanifest (PrivacyInfo.xcprivacy) UND die
      Angaben in App Store Connect nachziehen.
    */
    private static var privacyDe: [Section] {
        [
            Section(heading: "Verantwortlicher",
                    body: "\(operatorName)\n\(operatorAddress)\nE-Mail: \(operatorEmail)"),
            Section(heading: "Was auf dem Gerät bleibt",
                    body: """
                    Gewürfelte Pläne, gespeicherte Trainings- und Ernährungspläne, \
                    Favoriten, der Stand des KI-Assistenten und die Sprachwahl \
                    liegen ausschließlich auf deinem Gerät. Sie werden nicht \
                    übertragen und beim Löschen der App mitentfernt.
                    """),
            Section(heading: "Gesundheitsdaten",
                    body: """
                    Die App liest deine Herzfrequenz aus Apple Health, um sie \
                    während der Live-Session anzuzeigen. Diese Werte verlassen das \
                    Gerät nicht. Vom iPhone aus schreibt die App nichts nach Apple \
                    Health. Läuft die Apple-Watch-App mit, speichert diese die \
                    absolvierte Trainingseinheit mit den gemessenen Werten in \
                    Apple Health. Ohne Uhr zeigt die App einen gerechneten \
                    Schätzwert, klar als solcher gekennzeichnet.
                    """),
            Section(heading: "Verbindungen zum Server",
                    body: """
                    Die App lädt den Übungskatalog von kraftwuerfel-api.onrender.com. \
                    Dabei werden keine personenbezogenen Daten übertragen; der \
                    Server verarbeitet technisch bedingt deine IP-Adresse.
                    """),
            Section(heading: "Konto und KI-Coach",
                    body: """
                    Wenn du dich anmeldest, werden E-Mail-Adresse und Passwort an \
                    unseren Authentifizierungsdienst übertragen. Für einen \
                    KI-Trainingsplan gehen zusätzlich Geschlecht, Alter, Größe, \
                    Gewicht, Trainingstage und Ziel an den Server. Ohne Anmeldung \
                    erzeugt die App den Plan lokal, und es wird nichts übertragen.
                    """),
            Section(heading: "Käufe",
                    body: """
                    Zahlungen wickelt Apple ab. Die App erfährt nur, ob eine \
                    gültige Berechtigung vorliegt — keine Zahlungsdaten.
                    """),
            Section(heading: "Deine Rechte",
                    body: """
                    Du kannst Auskunft, Berichtigung, Löschung und Widerspruch \
                    verlangen. Schreib dafür an \(operatorEmail). Gerätedaten \
                    löschst du, indem du die App entfernst.
                    """),
        ]
    }

    private static var privacyEn: [Section] {
        [
            Section(heading: "Controller",
                    body: "\(operatorName)\n\(operatorAddress)\nEmail: \(operatorEmail)"),
            Section(heading: "What stays on your device",
                    body: """
                    Rolled plans, saved workout and nutrition plans, favourites, \
                    the AI assistant's state and your language choice live only on \
                    your device. They are not transmitted and are removed when you \
                    delete the app.
                    """),
            Section(heading: "Health data",
                    body: """
                    The app reads your heart rate from Apple Health to show it \
                    during a live session. These values do not leave the device. \
                    The iPhone app never writes to Apple Health. If the Apple Watch \
                    app is running, it stores the completed workout with the \
                    measured values in Apple Health. Without a watch the app shows \
                    a calculated estimate, clearly labelled as such.
                    """),
            Section(heading: "Server connections",
                    body: """
                    The app loads the exercise catalogue from \
                    kraftwuerfel-api.onrender.com. No personal data is transmitted; \
                    the server necessarily processes your IP address.
                    """),
            Section(heading: "Account and AI coach",
                    body: """
                    When you sign in, your email address and password are sent to \
                    our authentication service. Generating an AI plan additionally \
                    sends sex, age, height, weight, training days and goal to the \
                    server. Without an account the plan is generated locally and \
                    nothing is transmitted.
                    """),
            Section(heading: "Purchases",
                    body: """
                    Payments are handled by Apple. The app only learns whether a \
                    valid entitlement exists — never payment details.
                    """),
            Section(heading: "Your rights",
                    body: """
                    You may request access, correction, deletion and object to \
                    processing. Write to \(operatorEmail). Device data is deleted \
                    by removing the app.
                    """),
        ]
    }
}
