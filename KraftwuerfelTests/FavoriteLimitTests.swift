import XCTest
@testable import Kraftwuerfel

/*
  Die Gratis-Grenze für Favoriten.

  Sie ist eine Geldregel, keine Anzeigefrage: Wer sie umgeht, bekommt eine
  Pro-Funktion geschenkt. Deshalb liegt sie im Store und nicht in der View —
  und deshalb steht sie hier unter Test.

  Der Store ist ein Singleton auf UserDefaults.standard und lässt sich nicht
  mit einer eigenen Suite unterschieben. Jeder Test räumt darum vorher und
  nachher mit `wipe()` auf.
*/
final class FavoriteLimitTests: XCTestCase {

    private var store: FavoritesStore { .shared }

    override func setUp() {
        super.setUp()
        store.wipe()
    }

    override func tearDown() {
        store.wipe()
        super.tearDown()
    }

    private func slots(_ n: Int) -> [[ExerciseSlot]] {
        [ExerciseDatabase.bundled.prefix(n).map { ExerciseSlot(exercise: $0) }]
    }

    @discardableResult
    private func favorite(_ day: String, isPro: Bool) -> FavoritesStore.ToggleOutcome {
        store.toggle(day: day, cycles: slots(3), split: "push", method: .standard, isPro: isPro)
    }

    // MARK: - Gratis

    func testGratisDarfGenauEinenFavoritenSetzen() {
        XCTAssertEqual(favorite("Mo", isPro: false), .added)
        XCTAssertEqual(store.favorites.count, FavoritesStore.freeLimit)
    }

    func testZweiterFavoritOhneProWirdAbgelehnt() {
        favorite("Mo", isPro: false)
        XCTAssertEqual(favorite("Mi", isPro: false), .blockedByLimit)
        // Abgelehnt heißt abgelehnt: Der zweite Tag darf nicht doch im
        // Speicher landen.
        XCTAssertEqual(store.favorites.count, 1)
        XCTAssertFalse(store.isFavorited(day: "Mi"))
    }

    /*
      Der wichtigste Fall: Ohne diese Ausnahme säße ein Gratis-Nutzer für immer
      auf seinem ersten Favoriten fest, weil das Entfernen an derselben Grenze
      scheitern würde wie das Hinzufügen.
    */
    func testEigenerFavoritLaesstSichOhneProWiederEntfernen() {
        favorite("Mo", isPro: false)
        XCTAssertEqual(favorite("Mo", isPro: false), .removed)
        XCTAssertTrue(store.favorites.isEmpty)

        // Und danach ist wieder Platz für einen anderen Tag.
        XCTAssertEqual(favorite("Fr", isPro: false), .added)
    }

    func testCanFavoriteMeldetDieGrenzeVorDemAntippen() {
        XCTAssertTrue(store.canFavorite(day: "Mo", isPro: false))
        favorite("Mo", isPro: false)

        XCTAssertFalse(store.canFavorite(day: "Mi", isPro: false))
        // Der belegte Tag bleibt erlaubt — sonst kein Weg zurück.
        XCTAssertTrue(store.canFavorite(day: "Mo", isPro: false))
    }

    // MARK: - Pro

    func testProDarfBeliebigVieleFavoritenSetzen() {
        for day in Weekdays.all {
            XCTAssertEqual(favorite(day, isPro: true), .added, "Tag \(day) wurde abgelehnt")
        }
        XCTAssertEqual(store.favorites.count, Weekdays.all.count)
    }

    /*
      Ein abgelaufenes Abo darf bestehende Favoriten nicht löschen — die Daten
      des Nutzers gehören ihm. Neue kommen nur keine mehr dazu.
    */
    func testNachProVerlustBleibenBestehendeFavoritenErhalten() {
        for day in ["Mo", "Mi", "Fr"] { favorite(day, isPro: true) }
        XCTAssertEqual(store.favorites.count, 3)

        XCTAssertEqual(favorite("Sa", isPro: false), .blockedByLimit)
        XCTAssertEqual(store.favorites.count, 3)
        // Entfernen geht weiter, auch über der Grenze.
        XCTAssertEqual(favorite("Mo", isPro: false), .removed)
    }
}
