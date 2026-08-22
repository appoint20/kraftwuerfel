/*
  Ein-Wort-Namen für Tagespläne.

  KI-Pläne bekommen ihren Namen vom Modell (es kennt den Inhalt). Gewürfelte
  Pläne haben kein Modell im Spiel und würden sonst namenlos bleiben — die
  holen sich hier einen. Beides ist bewusst ein einzelnes Wort: es soll ein
  Rufname sein ("Titan am Mittwoch"), keine Beschreibung.
*/

// Wörter, die in beiden Sprachen funktionieren und nach Kraft klingen.
const NAMES = [
  "Titan", "Granit", "Vulkan", "Anker", "Kobalt", "Falke", "Orkan", "Basalt",
  "Zenit", "Nova", "Atlas", "Krater", "Quarz", "Bison", "Komet", "Obsidian",
  "Kanon", "Wolf", "Magma", "Bastion", "Kobra", "Zunder", "Achat", "Delta",
  "Fenrir", "Gletscher", "Hammer", "Impuls", "Jaguar", "Kaskade",
];

/*
  Gleicher Plan -> gleicher Name, auch nach einem Reload. Deshalb wird aus dem
  Seed ein Hash gebildet statt zufällig zu ziehen; sonst hieße der Mittwoch bei
  jedem Rendern anders.
*/
export function planNameFor(seed) {
  const text = String(seed ?? "");
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = (hash * 31 + text.charCodeAt(i)) | 0;
  }
  return NAMES[Math.abs(hash) % NAMES.length];
}

/*
  Ein Name, der noch nicht vergeben ist.

  "Nicht wiederholen" muss über alles hinweg gelten, was der Nutzer sieht —
  gespeicherte Pläne UND Favoriten. Deshalb kommt die Liste der belegten Namen
  von außen, statt hier geraten zu werden. Sind alle Wörter verbraucht, wird
  durchnummeriert (Titan 2), damit nie ein Duplikat entsteht.
*/
export function uniquePlanName(taken = [], seed = "") {
  const used = new Set([...taken].filter(Boolean).map((n) => String(n).toLowerCase()));

  const start = Math.abs(hash(String(seed))) % NAMES.length;
  for (let i = 0; i < NAMES.length; i++) {
    const candidate = NAMES[(start + i) % NAMES.length];
    if (!used.has(candidate.toLowerCase())) return candidate;
  }

  for (let round = 2; round < 100; round++) {
    for (const base of NAMES) {
      const candidate = `${base} ${round}`;
      if (!used.has(candidate.toLowerCase())) return candidate;
    }
  }
  return `Plan ${used.size + 1}`;
}

function hash(text) {
  let h = 0;
  for (let i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) | 0;
  return h;
}

/* Ein Name pro Tag, ohne Dopplungen innerhalb desselben Plans. */
export function planNamesForDays(days, salt = "") {
  const taken = new Set();
  const out = {};
  days.forEach((day) => {
    let name = planNameFor(`${salt}:${day}`);
    let bump = 0;
    while (taken.has(name) && bump < NAMES.length) {
      bump++;
      name = planNameFor(`${salt}:${day}:${bump}`);
    }
    taken.add(name);
    out[day] = name;
  });
  return out;
}
