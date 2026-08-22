/*
  KRAFTWÜRFEL — Entitlement-Abgleich

  Die einzige Stelle, an der ein Konto Pro bekommen kann, ohne dass jemand von
  Hand SQL ausführt. Der Client kann das nicht selbst: die Rollenspalten sind
  für ihn gesperrt (Spalten-Grant + Trigger in schema.sql).

  Testkonten stehen in einem Secret, nicht im Code und nicht in der Datenbank:

    supabase secrets set PRO_TEST_EMAILS="du@example.com,tester@example.com"
    supabase functions deploy sync-entitlement

  Ohne gesetztes Secret tut die Funktion nichts — sie meldet nur den aktuellen
  Stand zurück. Echte Käufe gehören später hierher: ein Webhook des
  Zahlungsanbieters setzt is_premium, niemals der Browser.
*/
import { createClient } from "jsr:@supabase/supabase-js@2";

const env = (name: string, fallback = "") => Deno.env.get(name)?.trim() || fallback;

const CORS = {
  "Access-Control-Allow-Origin": env("ALLOWED_ORIGIN", "*"),
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

const allowlist = () =>
  env("PRO_TEST_EMAILS")
    .split(",")
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";

  // Mit dem Token des Nutzers: nur um zu prüfen, WER fragt.
  const asUser = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData } = await asUser.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  const email = (user.email || "").toLowerCase();
  const isTester = email.length > 0 && allowlist().includes(email);

  const { data: profile } = await asUser
    .from("profiles")
    .select("is_premium, is_admin")
    .eq("id", user.id)
    .maybeSingle();

  const alreadyPro = !!profile?.is_premium || !!profile?.is_admin;

  // Nichts zu tun: entweder kein Tester, oder längst freigeschaltet.
  if (!isTester || alreadyPro) {
    return json({ isPremium: alreadyPro, isAdmin: !!profile?.is_admin, source: alreadyPro ? "profile" : "none" });
  }

  // Nur für die Rollenspalte die Service-Role verwenden — der Trigger in
  // schema.sql lässt ausschließlich diese Rolle daran.
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!serviceKey) {
    console.error("SUPABASE_SERVICE_ROLE_KEY fehlt — Testfreischaltung nicht möglich");
    return json({ isPremium: false, isAdmin: false, source: "none" });
  }

  const asService = createClient(env("SUPABASE_URL"), serviceKey);
  const { error } = await asService.from("profiles").update({ is_premium: true }).eq("id", user.id);

  if (error) {
    console.error("entitlement update failed", error.message);
    return json({ isPremium: false, isAdmin: false, source: "none" });
  }

  console.log("test entitlement granted", email);
  return json({ isPremium: true, isAdmin: !!profile?.is_admin, source: "tester" });
});
