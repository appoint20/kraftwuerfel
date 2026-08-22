/*
  Offline-Musikbibliothek.

  Die Audiodateien liegen als Blob in IndexedDB — nicht als Link, nicht im
  localStorage (das kann nur Text und wäre nach zwei Songs voll). Damit läuft
  die Musik im Keller ohne Empfang genauso wie zu Hause.

  Was hier bewusst NICHT passiert: irgendetwas von YouTube oder Spotify laden.
  Das verstößt gegen deren Nutzungsbedingungen und bräuchte ohnehin einen
  Server. Hier kommen ausschließlich Dateien rein, die der Nutzer selbst
  auswählt.
*/

const DB_NAME = "kraftwuerfel-music";
const DB_VERSION = 1;
const STORE = "tracks";

let dbPromise = null;

function openDb() {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    if (typeof indexedDB === "undefined") {
      reject(new Error("indexeddb-unavailable"));
      return;
    }
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: "id" });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error || new Error("indexeddb-open-failed"));
  });
  return dbPromise;
}

function tx(mode, run) {
  return openDb().then(
    (db) =>
      new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE, mode);
        const store = transaction.objectStore(STORE);
        let result;
        try {
          result = run(store);
        } catch (err) {
          reject(err);
          return;
        }
        transaction.oncomplete = () => resolve(result);
        transaction.onerror = () => reject(transaction.error);
        transaction.onabort = () => reject(transaction.error);
      })
  );
}

const newId = () => `trk-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

/* Dateiname ohne Endung als Titel — reicht als Anzeige und ist ehrlich. */
function titleFrom(file) {
  return file.name.replace(/\.[^.]+$/, "").replace(/[_-]+/g, " ").trim() || file.name;
}

export const musicLibrary = {
  available: typeof indexedDB !== "undefined",

  async list() {
    const rows = await tx("readonly", (store) => {
      const out = [];
      store.openCursor().onsuccess = (e) => {
        const cursor = e.target.result;
        if (!cursor) return;
        const { blob, ...meta } = cursor.value;
        out.push(meta);
        cursor.continue();
      };
      return out;
    });
    return rows.sort((a, b) => (a.addedAt || "").localeCompare(b.addedAt || ""));
  },

  async add(files) {
    const added = [];
    for (const file of files) {
      if (!file.type.startsWith("audio/")) continue;
      const record = {
        id: newId(),
        title: titleFrom(file),
        size: file.size,
        type: file.type,
        addedAt: new Date().toISOString(),
        blob: file,
      };
      await tx("readwrite", (store) => store.put(record));
      const { blob, ...meta } = record;
      added.push(meta);
    }
    return added;
  },

  async blobFor(id) {
    // Der Request ist fertig, bevor die Transaktion "complete" meldet — deshalb
    // reicht es, das Ergebnis in einem Objekt festzuhalten.
    const holder = {};
    await tx("readonly", (store) => {
      const req = store.get(id);
      req.onsuccess = () => {
        holder.value = req.result;
      };
    });
    return holder.value?.blob || null;
  },

  async remove(id) {
    await tx("readwrite", (store) => store.delete(id));
  },

  async usage() {
    const rows = await this.list();
    return rows.reduce((sum, r) => sum + (r.size || 0), 0);
  },
};

export function formatBytes(bytes) {
  if (!bytes) return "0 MB";
  const mb = bytes / (1024 * 1024);
  return mb < 1 ? `${Math.round(bytes / 1024)} KB` : `${mb.toFixed(1)} MB`;
}
