import Foundation
import Security

/*
  Ein Zugriffstoken gehört nicht in UserDefaults.

  `KraftAPI.accessToken` lag bisher dort — als Klartext in einer Datei, die
  jedes iTunes-Backup mitnimmt und die auf einem gejailbreakten Gerät offen
  liest. Für einen Wert, mit dem sich fremde Pläne abrufen lassen, ist das zu
  wenig. Deshalb dieser kleine Wrapper um die Schlüsselbundverwaltung.

  Bewusst schmal: setzen, lesen, löschen. Mehr braucht die App nicht, und jede
  weitere Zeile hier wäre eine, die niemand prüft.
*/
public enum Keychain {

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "app.kraftwuerfel"
    }

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    @discardableResult
    public static func set(_ value: String?, for account: String) -> Bool {
        guard let value, !value.isEmpty else { return remove(account) }
        guard let data = value.data(using: .utf8) else { return false }

        var attributes = query(account)
        SecItemDelete(attributes as CFDictionary)

        attributes[kSecValueData as String] = data
        // Nur auf diesem Gerät und nur bei entsperrtem Bildschirm — das Token
        // wird ausschließlich im Vordergrund gebraucht.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    public static func get(_ account: String) -> String? {
        var attributes = query(account)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(attributes as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func remove(_ account: String) -> Bool {
        let status = SecItemDelete(query(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
