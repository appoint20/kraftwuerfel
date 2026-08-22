import { useCallback, useEffect, useRef, useState } from "react";

/*
  useState, das seinen Wert behält, wenn die Komponente ausgehängt wird.

  Der KI-Assistent wird beim Tabwechsel komplett abgebaut — vorher war damit
  jede Antwort weg und man stand wieder bei Frage eins. Der Zustand liegt jetzt
  im sessionStorage: er überlebt Tabwechsel und Reload, verschwindet aber, wenn
  der Tab geschlossen wird. Das ist die richtige Lebensdauer für einen halb
  ausgefüllten Assistenten — beim nächsten Öffnen der App soll er leer sein.

  Sets werden mitgeführt, weil die Auswahlfelder (Tage, Equipment) Sets sind und
  JSON.stringify daraus sonst {} macht.
*/

const KEY_PREFIX = "kraftwuerfel:state:";

function encode(value) {
  if (value instanceof Set) return { __set: [...value] };
  return value;
}

function decode(value) {
  if (value && typeof value === "object" && Array.isArray(value.__set)) return new Set(value.__set);
  return value;
}

function read(key, fallback) {
  try {
    const raw = sessionStorage.getItem(KEY_PREFIX + key);
    if (raw === null) return fallback;
    return decode(JSON.parse(raw));
  } catch {
    return fallback;
  }
}

export default function usePersistentState(key, initialValue) {
  const [value, setValue] = useState(() => read(key, initialValue));
  const keyRef = useRef(key);
  keyRef.current = key;

  useEffect(() => {
    try {
      sessionStorage.setItem(KEY_PREFIX + keyRef.current, JSON.stringify(encode(value)));
    } catch {
      // Speicher voll oder gesperrt — dann eben nur für diese Ansicht.
    }
  }, [value]);

  return [value, setValue];
}

/* Alles vergessen, was zu einem Assistenten gehört (z. B. nach "neuer Plan"). */
export function clearPersistentState(prefix) {
  try {
    const doomed = [];
    for (let i = 0; i < sessionStorage.length; i++) {
      const k = sessionStorage.key(i);
      if (k && k.startsWith(KEY_PREFIX + prefix)) doomed.push(k);
    }
    doomed.forEach((k) => sessionStorage.removeItem(k));
  } catch {
    // ignorieren
  }
}
