/*
  Vite backt VITE_*-Variablen beim Build in das Bundle. In einem Container hieße
  das: die Supabase-URL steckt fest im Image, dasselbe Image kann nicht von
  Staging nach Produktion wandern, und ein neuer Schlüssel erzwingt einen neuen
  Build.

  Deshalb liest die App zuerst window.__KRAFTWUERFEL_ENV__. Diese Datei
  (public/env.js) ist im Dev-Betrieb leer; der Container schreibt sie beim Start
  aus seinen Umgebungsvariablen neu. Fällt beides aus, gilt der Build-Wert.
*/

export function resolveEnv(runtime = {}, buildTime = {}) {
  const pick = (key) => {
    const fromRuntime = runtime[key];
    if (typeof fromRuntime === "string" && fromRuntime.trim()) return fromRuntime.trim();
    const fromBuild = buildTime[key];
    if (typeof fromBuild === "string" && fromBuild.trim()) return fromBuild.trim();
    return "";
  };

  return {
    supabaseUrl: pick("VITE_SUPABASE_URL"),
    supabaseAnonKey: pick("VITE_SUPABASE_ANON_KEY") || pick("VITE_SUPABASE_PUBLISHABLE_KEY"),
    // Leer heißt "nicht gesetzt" — das ist etwas anderes als ausdrücklich
    // "free", und nur der Aufrufer weiß, was der richtige Standard ist.
    localRole: pick("VITE_LOCAL_ROLE").toLowerCase(),
  };
}

export const ENV = resolveEnv(
  (typeof window !== "undefined" && window.__KRAFTWUERFEL_ENV__) || {},
  import.meta.env
);
