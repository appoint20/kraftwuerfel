import CoreBluetooth
import Combine
import Foundation

/*
  Puls von Bluetooth-Sensoren — Brustgurte, Armbänder und Uhren, die ihren
  Puls übertragen.

  Fast alle diese Geräte sprechen dasselbe offene Protokoll: den
  Heart-Rate-Dienst der Bluetooth SIG (0x180D) mit der Messung 0x2A37. Ein
  Stück Code deckt damit Polar H10 und Verity Sense, Wahoo TICKR, Garmin HRM
  und die vielen Gurte ohne Markennamen ab — und Uhren, die „Herzfrequenz
  übertragen“ können (Garmin, Polar, Suunto, Coros, Whoop).

  Nicht abgedeckt, weil sie den Dienst nicht anbieten: Ringe (Oura & Co.) und
  Uhren ohne Übertragungsmodus. Für die gibt es live nichts Echtes, und dann
  zeigt die App auch nichts.

  Zwei bewusste Grenzen:

  - Kein `UIBackgroundModes: bluetooth-central`. Im Hintergrund kommen keine
    Messungen an; beim Zurückkehren laufen sie weiter. Ein Hintergrundmodus,
    den App Review nicht nachvollziehen kann, war schon einmal ein
    Ablehnungsgrund (Richtlinie 2.5.4).
  - Der CBCentralManager entsteht erst, wenn der Nutzer einen Sensor sucht
    oder schon einmal einen gekoppelt hat. Sein Anlegen löst die
    Bluetooth-Abfrage aus — die soll nicht beim App-Start kommen, sondern
    dann, wenn jemand weiß, wofür.
*/
public final class HeartRateSensorManager: NSObject, ObservableObject {

    public static let shared = HeartRateSensorManager()

    static let heartRateService = CBUUID(string: "180D")
    static let measurementCharacteristic = CBUUID(string: "2A37")

    /// Ein Messwert gilt zehn Sekunden — wie bei Apple Health.
    public static let sampleValidity: TimeInterval = HealthKitManager.sampleValidity

    public enum Status: Equatable {
        /// Noch nichts angefragt.
        case idle
        case bluetoothOff
        case unauthorized
        case unsupported
        case scanning
        case connecting
        case connected
    }

    public struct DiscoveredSensor: Identifiable, Equatable {
        public let id: UUID
        public let name: String
        public let rssi: Int
    }

    @Published public private(set) var status: Status = .idle
    @Published public private(set) var discovered: [DiscoveredSensor] = []
    /// Name des verbundenen (oder gerade verbindenden) Sensors.
    @Published public private(set) var sensorName: String?
    @Published public private(set) var heartRate: Int?
    @Published public private(set) var heartRateDate: Date?
    /// `false`, wenn der Sensor meldet, dass er keinen Hautkontakt hat —
    /// typisch für einen trockenen oder locker sitzenden Gurt.
    @Published public private(set) var hasSkinContact = true

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var seen: [UUID: CBPeripheral] = [:]

    /// Was nach dem Einschalten von Bluetooth passieren soll.
    private var wantsScan = false
    private var wantsReconnect = false
    /// Während einer Trainingssitzung wird nach einem Abriss neu verbunden.
    private var sessionActive = false

    private let defaults = UserDefaults.standard
    private static let rememberedIdKey = "kw.hrSensor.id"
    private static let rememberedNameKey = "kw.hrSensor.name"

    private override init() { super.init() }

    // MARK: - Gemerkter Sensor

    public var rememberedSensorName: String? { defaults.string(forKey: Self.rememberedNameKey) }

    private var rememberedId: UUID? {
        defaults.string(forKey: Self.rememberedIdKey).flatMap(UUID.init(uuidString:))
    }

    /// Der beim Suchen beworbene Name ist oft genauer als `peripheral.name`
    /// („Polar H10 A1B2C3“ statt nichts) — deshalb wird der gemerkt.
    private func remember(_ peripheral: CBPeripheral, name: String) {
        defaults.set(peripheral.identifier.uuidString, forKey: Self.rememberedIdKey)
        defaults.set(name, forKey: Self.rememberedNameKey)
    }

    // MARK: - Messwert

    /// Der letzte Puls, sofern er frisch ist und der Sensor Hautkontakt hat.
    public var freshHeartRate: Int? {
        guard status == .connected, hasSkinContact,
              let heartRate, let heartRateDate,
              Date().timeIntervalSince(heartRateDate) < Self.sampleValidity
        else { return nil }
        return heartRate
    }

    // MARK: - Suchen & Verbinden

    public func startScan() {
        wantsScan = true
        guard let central = ensureCentral(), central.state == .poweredOn else { return }
        discovered = []

        // Sensoren, die schon mit dem iPhone verbunden sind (etwa über die App
        // des Herstellers), werben nicht mehr — sie stehen nur hier.
        for p in central.retrieveConnectedPeripherals(withServices: [Self.heartRateService]) {
            seen[p.identifier] = p
            upsert(DiscoveredSensor(id: p.identifier, name: displayName(p), rssi: -50))
        }

        central.scanForPeripherals(
            withServices: [Self.heartRateService],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        if peripheral == nil { status = .scanning }
    }

    public func stopScan() {
        wantsScan = false
        central?.stopScan()
        if status == .scanning { status = .idle }
    }

    public func connect(_ id: UUID) {
        guard let central, let target = seen[id] else { return }
        if let current = peripheral, current.identifier != id {
            central.cancelPeripheralConnection(current)
        }
        stopScan()
        peripheral = target
        target.delegate = self
        sensorName = discovered.first(where: { $0.id == id })?.name ?? displayName(target)
        status = .connecting
        central.connect(target)
    }

    /// Trennt die Verbindung. `forget` löscht auch den gemerkten Sensor.
    public func disconnect(forget: Bool) {
        wantsReconnect = false
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        clearReading()
        sensorName = nil
        status = .idle
        if forget {
            defaults.removeObject(forKey: Self.rememberedIdKey)
            defaults.removeObject(forKey: Self.rememberedNameKey)
        }
    }

    /// Außerhalb einer Sitzung braucht niemand die Verbindung — sie kostet
    /// nur Akku am Sensor.
    public func disconnectIfIdle() {
        guard !sessionActive else { return }
        disconnect(forget: false)
    }

    // MARK: - Trainingssitzung

    /// Zu Beginn einer Sitzung den gemerkten Sensor wieder verbinden.
    public func beginSession() {
        sessionActive = true
        guard rememberedId != nil, peripheral == nil else { return }
        wantsReconnect = true
        if let central = ensureCentral(), central.state == .poweredOn {
            reconnectRemembered()
        }
    }

    public func endSession() {
        sessionActive = false
        disconnect(forget: false)
    }

    private func reconnectRemembered() {
        guard let central, let id = rememberedId,
              let target = central.retrievePeripherals(withIdentifiers: [id]).first
        else { return }
        seen[id] = target
        peripheral = target
        target.delegate = self
        sensorName = rememberedSensorName ?? displayName(target)
        status = .connecting
        // CoreBluetooth wartet ohne Zeitlimit — kommt der Gurt erst später in
        // Reichweite, verbindet er sich dann von selbst.
        central.connect(target)
    }

    // MARK: - Hilfen

    private func ensureCentral() -> CBCentralManager? {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil)
        }
        return central
    }

    private func displayName(_ p: CBPeripheral) -> String {
        if let name = p.name, !name.isEmpty { return name }
        return "Bluetooth-Sensor"
    }

    private func upsert(_ sensor: DiscoveredSensor) {
        if let i = discovered.firstIndex(where: { $0.id == sensor.id }) {
            discovered[i] = sensor
        } else {
            discovered.append(sensor)
        }
    }

    private func clearReading() {
        heartRate = nil
        heartRateDate = nil
        hasSkinContact = true
    }

    // MARK: - Messung lesen

    public struct Measurement: Equatable {
        public let bpm: Int?
        /// `nil`, wenn der Sensor keinen Kontakt meldet (Funktion fehlt).
        public let skinContact: Bool?
    }

    /*
      Die Heart Rate Measurement (0x2A37) nach Bluetooth-SIG-Spezifikation.

      Byte 0 sind Flags:
        Bit 0    — Format: 0 = Puls als UInt8, 1 = als UInt16 (little endian)
        Bit 1–2  — Hautkontakt: Bit 2 = Funktion vorhanden, Bit 1 = Kontakt
      Danach folgt der Puls. Energie und RR-Intervalle dahinter braucht die
      App nicht.

      Ein Wert außerhalb von 25–250 ist kein Puls, sondern ein Gurt ohne
      Kontakt, der Nullen schickt — der wird verworfen.
    */
    public static func parseMeasurement(_ data: Data) -> Measurement? {
        let bytes = [UInt8](data)
        guard let flags = bytes.first else { return nil }

        let isUInt16 = flags & 0x01 != 0
        let contactSupported = flags & 0x04 != 0
        let contactDetected = flags & 0x02 != 0
        let skinContact: Bool? = contactSupported ? contactDetected : nil

        let value: Int
        if isUInt16 {
            guard bytes.count >= 3 else { return nil }
            value = Int(bytes[1]) | (Int(bytes[2]) << 8)
        } else {
            guard bytes.count >= 2 else { return nil }
            value = Int(bytes[1])
        }

        let bpm = (25...250).contains(value) ? value : nil
        return Measurement(bpm: bpm, skinContact: skinContact)
    }
}

// MARK: - CBCentralManagerDelegate

extension HeartRateSensorManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if status == .bluetoothOff || status == .unauthorized { status = .idle }
            if wantsReconnect, peripheral == nil { reconnectRemembered() }
            if wantsScan { startScan() }
        case .poweredOff:
            status = .bluetoothOff
            clearReading()
        case .unauthorized:
            status = .unauthorized
        case .unsupported:
            status = .unsupported
        default:
            break
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        seen[peripheral.identifier] = peripheral
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? displayName(peripheral)
        upsert(DiscoveredSensor(id: peripheral.identifier, name: name, rssi: RSSI.intValue))
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == self.peripheral?.identifier else { return }
        let name = sensorName ?? displayName(peripheral)
        remember(peripheral, name: name)
        sensorName = name
        status = .connected
        peripheral.discoverServices([Self.heartRateService])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral.identifier == self.peripheral?.identifier else { return }
        self.peripheral = nil
        sensorName = nil
        status = .idle
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral.identifier == self.peripheral?.identifier else { return }
        clearReading()
        if sessionActive {
            // Gurt kurz außer Reichweite oder abgelegt: weiter warten. Bis er
            // wieder sendet, zeigt die Sitzung keinen Puls.
            status = .connecting
            central.connect(peripheral)
        } else {
            self.peripheral = nil
            sensorName = nil
            status = .idle
        }
    }
}

// MARK: - CBPeripheralDelegate

extension HeartRateSensorManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.heartRateService })
        else { return }
        peripheral.discoverCharacteristics([Self.measurementCharacteristic], for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristic = service.characteristics?
            .first(where: { $0.uuid == Self.measurementCharacteristic })
        else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.measurementCharacteristic,
              let data = characteristic.value,
              let measurement = Self.parseMeasurement(data)
        else { return }

        hasSkinContact = measurement.skinContact ?? true
        if let bpm = measurement.bpm, hasSkinContact {
            heartRate = bpm
            heartRateDate = Date()
        }
    }
}
