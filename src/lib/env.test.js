import { describe, it, expect } from "vitest";
import { resolveEnv } from "./env.js";

describe("resolveEnv", () => {
  it("bevorzugt die Laufzeit-Konfiguration aus dem Container", () => {
    const out = resolveEnv(
      { VITE_SUPABASE_URL: "https://runtime.supabase.co", VITE_SUPABASE_ANON_KEY: "runtime-key" },
      { VITE_SUPABASE_URL: "https://build.supabase.co", VITE_SUPABASE_ANON_KEY: "build-key" }
    );
    expect(out.supabaseUrl).toBe("https://runtime.supabase.co");
    expect(out.supabaseAnonKey).toBe("runtime-key");
  });

  it("fällt auf die Build-Werte zurück, wenn die Laufzeit leer ist", () => {
    const out = resolveEnv({}, { VITE_SUPABASE_URL: "https://build.supabase.co" });
    expect(out.supabaseUrl).toBe("https://build.supabase.co");
  });

  it("behandelt leere Container-Variablen wie nicht gesetzt", () => {
    // Der Entrypoint schreibt immer alle Schlüssel — auch die ohne Wert.
    const out = resolveEnv(
      { VITE_SUPABASE_URL: "", VITE_SUPABASE_ANON_KEY: "   " },
      { VITE_SUPABASE_URL: "https://build.supabase.co", VITE_SUPABASE_ANON_KEY: "build-key" }
    );
    expect(out.supabaseUrl).toBe("https://build.supabase.co");
    expect(out.supabaseAnonKey).toBe("build-key");
  });

  it("liefert leere Strings, wenn nirgends etwas gesetzt ist", () => {
    const out = resolveEnv({}, {});
    expect(out.supabaseUrl).toBe("");
    expect(out.supabaseAnonKey).toBe("");
  });

  it("schneidet Leerzeichen ab", () => {
    const out = resolveEnv({ VITE_SUPABASE_URL: "  https://x.supabase.co  " }, {});
    expect(out.supabaseUrl).toBe("https://x.supabase.co");
  });

  it("normalisiert die lokale Rolle und fällt auf free zurück", () => {
    expect(resolveEnv({ VITE_LOCAL_ROLE: "PRO" }, {}).localRole).toBe("pro");
    expect(resolveEnv({}, {}).localRole).toBe("free");
  });
});
