import XCTest
@testable import Kraftwuerfel

/*
  Die Ersparnis auf dem Pro-Bildschirm.

  Vorher stand „SPARE 48%" fest im Code, während die Preise daneben live aus
  StoreKit kamen. Solange 7,99 € und 49,99 € galten, stimmte das zufällig.
  Nach einer Preisänderung in App Store Connect hätte die App weiter mit 48%
  geworben, obwohl es 17% sind — eine falsche Preisauszeichnung, die niemandem
  auffällt, weil die Zahl ja irgendwann einmal richtig war.

  Deshalb wird gerechnet statt geschrieben, und deshalb wird die Rechnung hier
  geprüft.
*/
final class SubscriptionPricingTests: XCTestCase {

    private typealias Pro = ProSubscriptionView

    /// Die Preise, mit denen die App ausgeliefert wird.
    func testAktuellePreiseErgeben17Prozent() {
        let percent = Pro.savingsPercent(monthlyPrice: 9.99, yearlyPrice: 99.90)
        XCTAssertEqual(percent, 17, "12 × 9,99 € = 119,88 €; 99,90 € sind 16,7% weniger")
    }

    /*
      Der Rückfallwert gilt, solange StoreKit noch nichts geliefert hat — ohne
      Netz ist das der einzige Wert, den der Nutzer je zu sehen bekommt. Er muss
      deshalb dasselbe sagen wie die Rechnung mit den echten Preisen.
    */
    func testRueckfallwertPasstZuDenAusgelieferten() {
        XCTAssertEqual(
            Pro.savingsPercent(monthlyPrice: 9.99, yearlyPrice: 99.90),
            Pro.fallbackSavingsPercent,
            "Rückfallwert und gerechnete Ersparnis sind auseinandergelaufen"
        )
    }

    /// Auch der Monatspreis im Rückfall muss zum Jahrespreis passen.
    func testRueckfallMonatspreisPasstZumJahrespreis() {
        let perMonth = (Decimal(99.90) / 12 as NSDecimalNumber).doubleValue
        XCTAssertEqual(perMonth, 8.325, accuracy: 0.005)
        XCTAssertTrue(
            Pro.fallbackPerMonth.hasPrefix("8,3"),
            "fallbackPerMonth ist \(Pro.fallbackPerMonth), gerechnet sind es 8,33 €"
        )
    }

    /// Die alten Preise ergaben tatsächlich 48% — der Beleg, dass die Formel
    /// stimmt und die frühere Zahl nur veraltet war, nicht falsch gerechnet.
    func testAltePreiseErgaeben48Prozent() {
        XCTAssertEqual(Pro.savingsPercent(monthlyPrice: 7.99, yearlyPrice: 49.99), 48)
    }

    /*
      Kein Abzeichen, wenn es nichts zu sparen gibt. „SPARE 0%" oder gar ein
      negativer Wert wäre schlimmer als gar kein Hinweis.
    */
    func testKeineErsparnisWennJahresaboNichtGuenstiger() {
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 9.99, yearlyPrice: 119.88), "exakt gleich teuer")
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 9.99, yearlyPrice: 130.00), "teurer als monatlich")
    }

    /// Unbrauchbare Preise dürfen keine Zahl erfinden.
    func testUngueltigePreiseErgebenNichts() {
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 0, yearlyPrice: 99.90))
        XCTAssertNil(Pro.savingsPercent(monthlyPrice: 9.99, yearlyPrice: 0))
    }
}
