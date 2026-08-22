import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
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
/*
  Ohne Backend gibt es weder Konto noch Kaufmöglichkeit — und damit auch nichts
  zu schützen: die Daten liegen ausschließlich auf diesem Gerät. Eine Sperre
  wäre hier eine Sackgasse, denn es gibt keinen Knopf, der sie aufheben könnte.
  Deshalb ist der lokale Modus vollständig freigeschaltet.

  Zum Prüfen der Sperren trotzdem: VITE_LOCAL_ROLE=free.
*/
const LOCAL_ROLE = ENV.localRole;
const LOCAL_PRO = { name: "Athlet", isPremium: true, isAdmin: false };
const LOCAL_PROFILE = {
  free: FREE,
  pro: LOCAL_PRO,
  premium: LOCAL_PRO,
  admin: { name: "Admin", isPremium: true, isAdmin: true },
}[LOCAL_ROLE] || LOCAL_PRO;

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

  /*
    Der Client kann Pro nicht vergeben — die Rollenspalten sind für ihn gesperrt.
    Hier wird nur nachgefragt, ob die Testliste im Backend dieses Konto kennt.
    Ein früherer Stand schrieb is_premium direkt aus dem Browser; damit war die
    Bezahlschranke eine Anzeigeeinstellung.
  */
  const syncEntitlement = useCallback(async () => {
    if (!user || !supabase) return false;
    try {
      const { data, error } = await supabase.functions.invoke("sync-entitlement", { body: {} });
      if (error || !data) return false;
      if (data.isPremium) await loadProfile(user);
      return !!data.isPremium;
    } catch {
      return false;
    }
  }, [user, loadProfile]);

  // Einmal pro Anmeldung nachfragen, nicht bei jedem Token-Refresh.
  const syncedFor = useRef(null);
  useEffect(() => {
    if (!user || !isSupabaseConfigured) return;
    if (syncedFor.current === user.id) return;
    syncedFor.current = user.id;
    syncEntitlement();
  }, [user, syncEntitlement]);

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
    syncEntitlement,
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
