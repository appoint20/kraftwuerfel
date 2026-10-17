import XCTest
@testable import Kraftwuerfel

/*
  Die Ersparnis auf dem Pro-Bildschirm.

  Die Ersparnis wird aus den StoreKit-Preisen gerechnet. Die Rückfallwerte
  müssen zu den aktuellen Preisen von 7,99 € monatlich und 49,99 € jährlich
  passen; andere Preise prüfen, dass die Berechnung dynamisch bleibt.
*/
final class SubscriptionPricingTests: XCTestCase {

    private typealias Pro = ProSubscriptionView

    /// Die Preise, mit denen die App ausgeliefert wird.
    func testAktuellePreiseErgeben48Prozent() {
        let percent = Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 49.99)
        XCTAssertEqual(percent, 48, "12 × 7,99 € = 95,88 €; 49,99 € sind 47,9% weniger")
    }

    /*
      Der Rückfallwert gilt, solange StoreKit noch nichts geliefert hat — ohne
      Netz ist das der einzige Wert, den der Nutzer je zu sehen bekommt. Er muss
      deshalb dasselbe sagen wie die Rechnung mit den echten Preisen.
    */
    func testRueckfallwertPasstZuDenAusgelieferten() {
        XCTAssertEqual(
            Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 49.99),
            Pro.fallbackSavingsPercent,
            "Rückfallwert und gerechnete Ersparnis sind auseinandergelaufen"
        )
    }

    /// Auch der Monatspreis im Rückfall muss zum Jahrespreis passen.
    func testRueckfallMonatspreisPasstZumJahrespreis() {
        let perMonth = (Decimal(49.99) / 12 as NSDecimalNumber).doubleValue
        XCTAssertEqual(perMonth, 4.17, accuracy: 0.005)
        XCTAssertTrue(
            Pro.fallbackPerMonth.hasPrefix("4,17"),
            "fallbackPerMonth ist \(Pro.fallbackPerMonth), gerechnet sind es 4,17 €"
        )
    }

    /// Abweichende StoreKit-Preise dürfen nicht die feste Ersparnis übernehmen.
    func testAnderePreiseErgebenPassendeErsparnis() {
        XCTAssertEqual(Pro.savingsPercent(monthlyPrice: 10, yearlyPrice: 90), 25)
    }

    /*
      Kein Abzeichen, wenn es nichts zu sparen gibt. „SPARE 0%" oder gar ein
      negativer Wert wäre schlimmer als gar kein Hinweis.
    */
    func testKeineErsparnisWennJahresaboNichtGuenstiger() {
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 95.88), "exakt gleich teuer")
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 110.00), "teurer als monatlich")
    }

    /// Unbrauchbare Preise dürfen keine Zahl erfinden.
    func testUngueltigePreiseErgebenNichts() {
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 0, yearlyPrice: 49.99))
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 0))
    }
}
