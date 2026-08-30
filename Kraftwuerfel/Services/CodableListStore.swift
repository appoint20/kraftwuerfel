import Combine
import Foundation

/*
  Eine Liste, die als JSON in UserDefaults liegt.

  Bisher baute jeder Speicher dieselbe Kette von Hand: `JSONEncoder`, ein
  Schlüssel als Zeichenkette, `try?` beim Laden. Fünfmal derselbe Code, und
  jedes Mal die Möglichkeit, sich beim Schlüssel zu vertippen.

  Der wichtigere Punkt ist aber ein anderer: `persist()` gab nirgends zurück,
  ob das Schreiben geklappt hat. Der Meal Guide zeigte deshalb „Gespeichert!“,
  ohne dass irgendwo etwas gespeichert wurde. Hier meldet `add` ehrlich, ob
  der Eintrag wirklich in den Voreinstellungen gelandet ist — nur dann darf
  eine Erfolgsmeldung erscheinen.
*/
public class CodableListStore<Item: Codable & Identifiable>: ObservableObject
where Item.ID == UUID {

    @Published public private(set) var items: [Item] = []

    /// Letzter Fehler beim Schreiben. Die Ansicht kann ihn zeigen, statt
    /// Erfolg vorzutäuschen.
    @Published public private(set) var lastError: String?

    private let storageKey: String
    private let defaults: UserDefaults

    public init(storageKey: String, defaults: UserDefaults = .standard) {
        self.storageKey = storageKey
        self.defaults = defaults
        load()
    }

    // MARK: - Lesen

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([Item].self, from: data)
        } catch {
            /*
              Nicht löschen. Ein Formatwechsel darf die Daten des Nutzers nicht
              wegwerfen — die Liste bleibt in dieser Sitzung leer, die rohen
              Bytes bleiben liegen und lassen sich später migrieren.
            */
            lastError = error.localizedDescription
        }
    }

    // MARK: - Schreiben

    /// `true`, wenn der Eintrag tatsächlich geschrieben wurde. Schlägt das
    /// Kodieren fehl, bleibt die Liste unverändert.
    @discardableResult
    public func add(_ item: Item) -> Bool {
        var next = items
        next.insert(item, at: 0)
        guard persist(next) else { return false }
        items = next
        lastError = nil
        return true
    }

    @discardableResult
    public func delete(_ item: Item) -> Bool {
        let next = items.filter { $0.id != item.id }
        guard next.count != items.count else { return true }
        guard persist(next) else { return false }
        items = next
        return true
    }

    @discardableResult
    public func replace(_ item: Item) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return add(item) }
        var next = items
        next[idx] = item
        guard persist(next) else { return false }
        items = next
        return true
    }

    /// Schreibt die ganze Liste. Erst wenn das durch ist, wird `items` gesetzt —
    /// so kann der sichtbare Zustand nie behaupten, es sei gespeichert.
    private func persist(_ list: [Item]) -> Bool {
        do {
            let data = try JSONEncoder().encode(list)
            defaults.set(data, forKey: storageKey)
            // Gegenprobe: liegt wirklich etwas unter dem Schlüssel?
            guard defaults.data(forKey: storageKey) != nil else {
                lastError = "UserDefaults hat nichts übernommen"
                return false
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public func clearError() { lastError = nil }

    /*
      Alles weg — für die Kontolöschung (Art. 17 DSGVO).

      Anders als `delete` wird hier NICHT über `persist` gegangen: Der Schlüssel
      verschwindet ganz, statt eine leere Liste zu hinterlassen. Und anders als
      überall sonst wird die Liste auch dann geleert, wenn das Entfernen
      scheitern sollte — bei einer Löschung ist Wegwerfen immer richtig.
    */
    public func wipe() {
        defaults.removeObject(forKey: storageKey)
        items = []
        lastError = nil
    }
}
