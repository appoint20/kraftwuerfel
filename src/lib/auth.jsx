import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { supabase, isSupabaseConfigured } from "./supabase.js";

/*
  Freemium in zwei Stufen:
    frei — würfeln, so oft man will. Keine Anmeldung nötig, nichts wird gespeichert.
    pro  — KI-Coach, Speichern, Trainingspläne, Favoriten, Sync über Geräte.

  Wer nicht angemeldet ist, ist "frei". Die Rolle steht in public.profiles und
  ist für Nutzer nur lesbar — freigeschaltet wird serverseitig. is_admin gilt
  als Pro und ist für spätere Verwaltungsfunktionen reserviert.
*/

const FREE = { isPremium: false, isAdmin: false };

// Ohne Supabase-Zugangsdaten gibt es keine Konten. Für die lokale Entwicklung
// lässt sich die Rolle über VITE_LOCAL_ROLE=free|pro durchspielen. Der KI-Coach
// bleibt lokal unerreichbar — er braucht die Edge Function.
const LOCAL_ROLE = (import.meta.env.VITE_LOCAL_ROLE || "free").toLowerCase();
const LOCAL_PROFILE = {
  free: FREE,
  pro: { isPremium: true, isAdmin: false },
  premium: { isPremium: true, isAdmin: false },
  admin: { isPremium: true, isAdmin: true },
}[LOCAL_ROLE] || FREE;

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(isSupabaseConfigured ? FREE : LOCAL_PROFILE);
  const [ready, setReady] = useState(!isSupabaseConfigured);

  const loadProfile = useCallback(async (nextUser) => {
    if (!nextUser) {
      setProfile(FREE);
      return;
    }
    const { data } = await supabase
      .from("profiles")
      .select("is_premium, is_admin")
      .eq("id", nextUser.id)
      .maybeSingle();
    setProfile({ isPremium: !!data?.is_premium, isAdmin: !!data?.is_admin });
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured) return;
    supabase.auth.getSession().then(async ({ data }) => {
      setUser(data.session?.user || null);
      await loadProfile(data.session?.user || null);
      setReady(true);
    });
    const { data: sub } = supabase.auth.onAuthStateChange(async (_event, session) => {
      setUser(session?.user || null);
      await loadProfile(session?.user || null);
    });
    return () => sub.subscription.unsubscribe();
  }, [loadProfile]);

  const value = {
    user,
    ready,
    isAuthenticated: !!user,
    isPremium: profile.isPremium,
    isAdmin: profile.isAdmin,
    canSignIn: isSupabaseConfigured,
    signOut: () => supabase?.auth.signOut(),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth muss innerhalb von AuthProvider verwendet werden");
  return ctx;
}
