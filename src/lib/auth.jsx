import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { supabase, isSupabaseConfigured } from "./supabase.js";
import { ENV } from "./env.js";

/*
  Freemium in zwei Stufen:
    frei — würfeln, so oft man will. Keine Anmeldung nötig, nichts wird gespeichert.
    pro  — KI-Coach, Speichern, Trainingspläne, Favoriten, Sync über Geräte.

  Wer nicht angemeldet ist, ist "frei". Die Rolle steht in public.profiles und
  ist für Nutzer nur lesbar — freigeschaltet wird serverseitig. is_admin gilt
  als Pro und ist für spätere Verwaltungsfunktionen reserviert.
*/

const FREE = { name: "", isPremium: false, isAdmin: false };

// Ohne Supabase-Zugangsdaten gibt es keine Konten. Für die lokale Entwicklung
// lässt sich die Rolle über VITE_LOCAL_ROLE=free|pro durchspielen.
const LOCAL_ROLE = ENV.localRole;
const LOCAL_PROFILE = {
  free: FREE,
  pro: { name: "Athlet", isPremium: true, isAdmin: false },
  premium: { name: "Athlet", isPremium: true, isAdmin: false },
  admin: { name: "Admin", isPremium: true, isAdmin: true },
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
      .select("is_premium, is_admin, name")
      .eq("id", nextUser.id)
      .maybeSingle();

    const userName =
      data?.name || nextUser.user_metadata?.name || nextUser.email?.split("@")[0] || "";
    setProfile({
      name: userName,
      isPremium: !!data?.is_premium,
      isAdmin: !!data?.is_admin,
    });
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

  const upgradeToPro = useCallback(async () => {
    if (!user || !supabase) return false;
    try {
      const { error: rpcError } = await supabase.rpc("upgrade_to_pro");
      if (!rpcError) {
        await loadProfile(user);
        return true;
      }
    } catch {
      // Fallback
    }
    const { error: updateError } = await supabase
      .from("profiles")
      .update({ is_premium: true })
      .eq("id", user.id);
    if (!updateError) {
      await loadProfile(user);
      return true;
    }
    return false;
  }, [user, loadProfile]);

  // Test-Helfer: Pro Version für Testuser umschalten (freischalten / sperren)
  const toggleTestPro = useCallback(async () => {
    if (!user || !supabase) return false;
    const nextState = !profile.isPremium;
    await supabase.from("profiles").update({ is_premium: nextState }).eq("id", user.id);
    await loadProfile(user);
    return nextState;
  }, [user, profile.isPremium, loadProfile]);

  const updateUserName = useCallback(
    async (newName) => {
      if (!user || !supabase || !newName) return;
      await supabase.from("profiles").update({ name: newName }).eq("id", user.id);
      await supabase.auth.updateUser({ data: { name: newName } });
      await loadProfile(user);
    },
    [user, loadProfile]
  );

  const value = {
    user,
    ready,
    userName: profile.name,
    isAuthenticated: !!user,
    isPremium: profile.isPremium,
    isAdmin: profile.isAdmin,
    canSignIn: isSupabaseConfigured,
    signOut: () => supabase?.auth.signOut(),
    upgradeToPro,
    toggleTestPro,
    updateUserName,
    refreshProfile: () => loadProfile(user),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth muss innerhalb von AuthProvider verwendet werden");
  return ctx;
}
