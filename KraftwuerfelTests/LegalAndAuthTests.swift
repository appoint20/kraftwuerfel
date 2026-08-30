import XCTest
@testable import Kraftwuerfel

final class LegalAndAuthTests: XCTestCase {

    func testLegalContentIsCompleteAndHasRealDetails() {
        XCTAssertTrue(LegalContent.isComplete, "LegalContent must be complete with no placeholder tags")
        XCTAssertEqual(LegalContent.companyName, "appoint")
        XCTAssertEqual(LegalContent.ownerName, "Shiv Mehra")
        XCTAssertEqual(LegalContent.operatorEmail, "appoint.20@gmail.com")
        XCTAssertEqual(LegalContent.operatorPhone, "+49 152 23024756")
    }

    func testImprintSectionsInGermanAndEnglish() {
        let deSections = LegalContent.sections(for: .imprint, language: "de")
        XCTAssertFalse(deSections.isEmpty)
        let deText = deSections.map { "\($0.heading)\n\($0.body)" }.joined(separator: "\n")
        XCTAssertTrue(deText.contains("appoint (Inhaber: Shiv Mehra)"))
        XCTAssertTrue(deText.contains("Max-Liebermann-Str. 82"))
        XCTAssertTrue(deText.contains("14612 Falkensee"))
        XCTAssertTrue(deText.contains("appoint.20@gmail.com"))
        XCTAssertTrue(deText.contains("015223024756") || deText.contains("+49 152 23024756"))
        XCTAssertTrue(deText.contains("§ 18 Abs. 2 MStV"))
        XCTAssertTrue(deText.contains("§ 19 UStG"))

        let enSections = LegalContent.sections(for: .imprint, language: "en")
        XCTAssertFalse(enSections.isEmpty)
        let enText = enSections.map { "\($0.heading)\n\($0.body)" }.joined(separator: "\n")
        XCTAssertTrue(enText.contains("appoint (Inhaber: Shiv Mehra)"))
        XCTAssertTrue(enText.contains("appoint.20@gmail.com"))
        XCTAssertTrue(enText.contains("14612 Falkensee"))
    }

    func testPrivacySectionsInGermanAndEnglish() {
        let dePrivacy = LegalContent.sections(for: .privacy, language: "de")
        XCTAssertFalse(dePrivacy.isEmpty)
        let deText = dePrivacy.map { "\($0.heading)\n\($0.body)" }.joined(separator: "\n")
        XCTAssertTrue(deText.contains("PostgreSQL"))
        XCTAssertTrue(deText.contains("Mailjet"))
        XCTAssertTrue(deText.contains("OpenRouter"))
        XCTAssertTrue(deText.contains("DSGVO"))
        XCTAssertTrue(deText.contains("Trainingsziel"))
        XCTAssertTrue(deText.contains("Körpergewicht"))

        let enPrivacy = LegalContent.sections(for: .privacy, language: "en")
        XCTAssertFalse(enPrivacy.isEmpty)
        let enText = enPrivacy.map { "\($0.heading)\n\($0.body)" }.joined(separator: "\n")
        XCTAssertTrue(enText.contains("PostgreSQL"))
        XCTAssertTrue(enText.contains("Mailjet"))
        XCTAssertTrue(enText.contains("OpenRouter"))
        XCTAssertTrue(enText.contains("GDPR"))
        XCTAssertTrue(enText.contains("Fitness goal"))
    }

    func testPasswordConfirmationStringsExist() {
        let deConfirmLabel = I18n.shared.t("auth.passwordConfirmLabel")
        let deMismatch = I18n.shared.t("auth.passwordsDoNotMatch")
        XCTAssertFalse(deConfirmLabel.isEmpty)
        XCTAssertFalse(deMismatch.isEmpty)
        XCTAssertNotEqual(deConfirmLabel, "auth.passwordConfirmLabel")
        XCTAssertNotEqual(deMismatch, "auth.passwordsDoNotMatch")
    }
}
