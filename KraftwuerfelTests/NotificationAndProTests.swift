import XCTest
@testable import Kraftwuerfel

final class NotificationAndProTests: XCTestCase {

    func testNotificationManagerSingleton() {
        let manager = NotificationManager.shared
        XCTAssertNotNil(manager)
    }

    func testScheduleWorkoutDayRemindersRunsWithoutError() {
        let manager = NotificationManager.shared
        manager.scheduleWorkoutDayReminders(days: ["Mo", "Mi", "Fr"], language: "de")
        manager.scheduleWorkoutDayReminders(days: ["Mon", "Wed", "Fri"], language: "en")
    }

    func testRestTimerNotificationScheduling() {
        let manager = NotificationManager.shared
        manager.scheduleRestCompleteNotification(seconds: 60, nextSet: 2, exerciseName: "Bankdrücken", language: "de")
        manager.cancelRestTimerNotification()
    }

    func testCountdownAudioTicksAndRestFinishedCues() {
        let manager = NotificationManager.shared
        // Test countdown ticks for 5..1
        for s in 1...5 {
            manager.playCountdownTick(secondsRemaining: s)
        }
        // Test out of range bounds
        manager.playCountdownTick(secondsRemaining: 0)
        manager.playCountdownTick(secondsRemaining: 6)

        // Test rest completion voice and cues
        manager.playRestFinishedCues(language: "de")
        manager.playRestFinishedCues(language: "en")
    }

    func testUpdatedProPricingAndBenefitsStrings() {
        let deMonthly = I18n.shared.t("proScreen.monthlyPrice")
        let deYearly = I18n.shared.t("proScreen.yearlyPrice")
        let deAds = I18n.shared.t("proScreen.benefit.ads")
        let deWatch = I18n.shared.t("proScreen.benefit.watch")

        XCTAssertTrue(deMonthly.contains("9,99"))
        XCTAssertTrue(deYearly.contains("99,90"))
        XCTAssertTrue(deAds.contains("Werbefrei"))
        XCTAssertTrue(deWatch.contains("Apple Watch"))
    }

    /*
      Der Untertitel des Jahresabos ist eine Vorlage geworden.

      Vorher standen „4,16 €" und „48%" fest darin, direkt neben Preisen, die
      live aus StoreKit kommen — nach einer Preisänderung im App Store hätte die
      App weiter mit der alten Ersparnis geworben. Jetzt werden beide Werte
      eingesetzt; geprüft wird, dass keine Platzhalter stehen bleiben.
    */
    func testYearlySubtitleWirdVollstaendigGefuellt() {
        for lang in ["de", "en"] {
            let filled = Strings.t(
                "proScreen.yearlySub",
                lang: lang,
                ["price": "8,33 €", "percent": "17"]
            )
            XCTAssertTrue(filled.contains("8,33 €"), "[\(lang)] Preis fehlt: \(filled)")
            XCTAssertTrue(filled.contains("17"), "[\(lang)] Prozentwert fehlt: \(filled)")
            XCTAssertFalse(filled.contains("{"), "[\(lang)] Platzhalter blieb stehen: \(filled)")
        }
    }

    /// Der Steuerhinweis muss in beiden Sprachen dastehen — Apple zeigt
    /// Bruttopreise, und das soll auf dem Bildschirm auch so stehen.
    func testSteuerhinweisVorhanden() {
        XCTAssertTrue(Strings.t("proScreen.vatNote", lang: "de").contains("MwSt"))
        XCTAssertTrue(Strings.t("proScreen.vatNote", lang: "en").lowercased().contains("vat"))
    }

    func testStoreKitProductIdsAndPlanChoices() {
        XCTAssertEqual(StoreKitManager.allProductIds.count, 2)
        XCTAssertTrue(StoreKitManager.allProductIds.contains("app.kraftwuerfel.pro.monthly"))
        XCTAssertTrue(StoreKitManager.allProductIds.contains("app.kraftwuerfel.pro.yearly"))

        XCTAssertEqual(StoreKitManager.ProPlanChoice.allCases.count, 2)
        XCTAssertEqual(StoreKitManager.ProPlanChoice.yearly.productId, "app.kraftwuerfel.pro.yearly")
        XCTAssertEqual(StoreKitManager.ProPlanChoice.monthly.productId, "app.kraftwuerfel.pro.monthly")
    }

    func testSubscriptionTermsAndLegalLinksStrings() {
        let deTerms = I18n.shared.t("proScreen.subscriptionTerms")
        let deEula = I18n.shared.t("proScreen.terms")
        let dePrivacy = I18n.shared.t("proScreen.privacy")

        XCTAssertFalse(deTerms.isEmpty)
        XCTAssertFalse(deEula.isEmpty)
        XCTAssertFalse(dePrivacy.isEmpty)
        XCTAssertTrue(deTerms.contains("Apple-ID") || deTerms.contains("Abonnement"))
    }
}
