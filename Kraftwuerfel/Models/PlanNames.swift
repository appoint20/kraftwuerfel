import Foundation

/*
  Portierung von src/lib/planNames.js.

  Gleicher Plan -> gleicher Name, auch nach einem Neustart: der Name kommt aus
  einem Hash des Seeds, nicht aus dem Zufall. Der Hash rechnet wie in JavaScript
  mit 32-Bit-Überlauf (`| 0`) und über UTF-16-Einheiten, sonst vergäbe die App
  andere Namen als das Web für denselben Plan.
*/
public enum PlanNames {

    public static let names = [
        "Titan", "Granit", "Vulkan", "Anker", "Kobalt", "Falke", "Orkan", "Basalt",
        "Zenit", "Nova", "Atlas", "Krater", "Quarz", "Bison", "Komet", "Obsidian",
        "Kanon", "Wolf", "Magma", "Bastion", "Kobra", "Zunder", "Achat", "Delta",
        "Fenrir", "Gletscher", "Hammer", "Impuls", "Jaguar", "Kaskade",
    ]

    static func hash(_ text: String) -> Int32 {
        var h: Int32 = 0
        for unit in text.utf16 {
            h = h &* 31 &+ Int32(unit)
        }
        return h
    }

    private static func index(_ seed: String) -> Int {
        let h = hash(seed)
        return Int(h.magnitude % UInt32(names.count))
    }

    public static func planName(for seed: String) -> String {
        names[index(seed)]
    }

    /// Ein Name, der weder unter den gespeicherten Plänen noch unter den
    /// Favoriten schon vergeben ist. Sind alle Wörter belegt, wird nummeriert.
    public static func uniquePlanName(taken: [String] = [], seed: String = "") -> String {
        let used = Set(taken.filter { !$0.isEmpty }.map { $0.lowercased() })

        let start = index(seed)
        for i in 0..<names.count {
            let candidate = names[(start + i) % names.count]
            if !used.contains(candidate.lowercased()) { return candidate }
        }

        for round in 2..<100 {
            for base in names {
                let candidate = "\(base) \(round)"
                if !used.contains(candidate.lowercased()) { return candidate }
            }
        }
        return "Plan \(used.count + 1)"
    }

    /// Ein Name pro Tag, ohne Dopplungen innerhalb desselben Plans.
    public static func planNamesForDays(_ days: [String], salt: String = "") -> [String: String] {
        var taken = Set<String>()
        var out: [String: String] = [:]
        for day in days {
            var name = planName(for: "\(salt):\(day)")
            var bump = 0
            while taken.contains(name) && bump < names.count {
                bump += 1
                name = planName(for: "\(salt):\(day):\(bump)")
            }
            taken.insert(name)
            out[day] = name
        }
        return out
    }
}
