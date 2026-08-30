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
        let deYearlySub = I18n.shared.t("proScreen.yearlySub")
        let deAds = I18n.shared.t("proScreen.benefit.ads")
        let deWatch = I18n.shared.t("proScreen.benefit.watch")

        XCTAssertTrue(deMonthly.contains("7,99"))
        XCTAssertTrue(deYearly.contains("49,99"))
        XCTAssertTrue(deYearlySub.contains("4,16") && deYearlySub.contains("48%"))
        XCTAssertTrue(deAds.contains("Werbefrei"))
        XCTAssertTrue(deWatch.contains("Apple Watch"))
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
