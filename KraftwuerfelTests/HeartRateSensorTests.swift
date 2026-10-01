import XCTest
@testable import Kraftwuerfel

/// Die Heart Rate Measurement (0x2A37) so, wie echte Gurte sie schicken.
final class HeartRateSensorTests: XCTestCase {

    private func parse(_ bytes: [UInt8]) -> HeartRateSensorManager.Measurement? {
        HeartRateSensorManager.parseMeasurement(Data(bytes))
    }

    func testUInt8HeartRateWithoutContactFeature() {
        // Flags 0x00: UInt8, keine Kontakt-Funktion.
        XCTAssertEqual(parse([0x00, 72]), .init(bpm: 72, skinContact: nil))
    }

    func testUInt16HeartRate() {
        // Flags 0x01: UInt16 little endian — 0x00B4 = 180.
        XCTAssertEqual(parse([0x01, 0xB4, 0x00])?.bpm, 180)
    }

    func testContactDetected() {
        // Flags 0x06: Funktion vorhanden (Bit 2) und Kontakt (Bit 1).
        XCTAssertEqual(parse([0x06, 130]), .init(bpm: 130, skinContact: true))
    }

    func testNoSkinContactIsReported() {
        // Flags 0x04: Funktion vorhanden, aber kein Kontakt — trockener Gurt.
        XCTAssertEqual(parse([0x04, 0])?.skinContact, false)
    }

    func testTrailingRRIntervalsAreIgnored() {
        // Flags 0x10: RR-Intervalle folgen dem Puls und stören nicht.
        XCTAssertEqual(parse([0x10, 95, 0x00, 0x04, 0x10, 0x04])?.bpm, 95)
    }

    func testImplausibleValuesAreDropped() {
        XCTAssertNil(parse([0x00, 0])?.bpm)
        XCTAssertNil(parse([0x00, 12])?.bpm)
        XCTAssertNil(parse([0x01, 0x2C, 0x01])?.bpm) // 300
    }

    func testTruncatedPacketsAreRejected() {
        XCTAssertNil(parse([]))
        XCTAssertNil(parse([0x00]))
        XCTAssertNil(parse([0x01, 0x50]))
    }

    func testOnlyEstimatedCountsAsUnmeasured() {
        XCTAssertFalse(HeartRateSource.estimated.isMeasured)
        XCTAssertTrue(HeartRateSource.appleWatch.isMeasured)
        XCTAssertTrue(HeartRateSource.bluetoothSensor.isMeasured)
        XCTAssertTrue(HeartRateSource.appleHealth.isMeasured)
    }

    func testEverySourceLabelIsTranslated() {
        for source in [HeartRateSource.estimated, .appleWatch, .bluetoothSensor, .appleHealth] {
            for lang in ["de", "en"] {
                XCTAssertNotEqual(Strings.t(source.labelKey, lang: lang), source.labelKey)
            }
        }
    }
}
