/*
  KRAFTWÜRFEL — KI-Plangenerator

  Läuft als Supabase Edge Function. Warum überhaupt ein Backend: der
  OpenRouter-Schlüssel darf nicht ins Frontend, und ob jemand Pro hat, muss
  serverseitig entschieden werden — sonst reicht ein Klick in den DevTools.

  Ablauf: JWT prüfen -> Pro prüfen -> Tageslimit prüfen -> Eingaben prüfen ->
  OpenRouter -> Antwort gegen den Übungskatalog validieren -> zurückgeben.
  Die reine Logik der letzten Schritte liegt in ../_shared/planPrompt.ts und
  ist von dort aus getestet.

  Alles Modellbezogene kommt aus der Umgebung, damit die Deployment-Pipeline
  Schlüssel und Modell setzen kann, ohne dass Code angefasst wird:

    supabase secrets set OPENROUTER_API_KEY=sk-or-...
    supabase secrets set OPENROUTER_MODEL=anthropic/claude-sonnet-4.5
    supabase functions deploy generate-plan
*/
import { OpenRouter } from "npm:@openrouter/sdk@1.2.54";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { sanitize, buildPrompt, validatePlan, extractJson } from "../_shared/planPrompt.ts";

const env = (name: string, fallback = "") => Deno.env.get(name)?.trim() || fallback;

const MODEL = env("OPENROUTER_MODEL", "anthropic/claude-sonnet-4.5");
const TEMPERATURE = Number(env("OPENROUTER_TEMPERATURE", "0.7"));
const MAX_TOKENS = Number(env("OPENROUTER_MAX_TOKENS", "4000"));
const APP_URL = env("ALLOWED_ORIGIN", "https://kraftwuerfel.app");
const DAILY_LIMIT = Number(env("AI_DAILY_LIMIT", "20"));

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

/* Der Antwortinhalt kann laut Typ auch eine Liste von Content-Blöcken sein. */
function readContent(content: unknown): string | undefined {
  if (typeof content === "string") return content || undefined;
  if (Array.isArray(content)) {
    const text = content
      .map((part) => (part && typeof part === "object" && "text" in part ? String(part.text ?? "") : ""))
      .join("");
    return text || undefined;
  }
  return undefined;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const apiKey = env("OPENROUTER_API_KEY");
  if (!apiKey) return json({ error: "OPENROUTER_API_KEY is not configured" }, 500);

  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData } = await supabase.auth.getUser();
  const user = userData?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  // Pro-Prüfung gehört hierher, nicht ins Frontend.
  const { data: profile } = await supabase
    .from("profiles")
    .select("is_premium, is_admin")
    .eq("id", user.id)
    .maybeSingle();

  if (!profile?.is_premium && !profile?.is_admin) return json({ error: "premium required" }, 403);

  // Jeder Aufruf kostet Geld — deshalb ein Limit pro Tag und Konto.
  const since = new Date();
  since.setUTCHours(0, 0, 0, 0);
  const { count } = await supabase
    .from("ai_generations")
    .select("id", { count: "exact", head: true })
    .gte("created_at", since.toISOString());

  if ((count ?? 0) >= DAILY_LIMIT) return json({ error: "daily limit reached" }, 429);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }

  const answers = sanitize(body);
  if ("error" in answers) return json(answers, 400);

  const { system, user: userPrompt } = buildPrompt(answers);

  // Bewusst ohne Streaming: der Plan wird erst gegen den Übungskatalog validiert
  // und umgebaut, bevor er den Client erreicht — halbfertige Chunks nützen dort
  // nichts. Der Ladezustand im Frontend deckt die Wartezeit ab.
  const openrouter = new OpenRouter({ apiKey });

  let content: string | undefined;
  let usage: { promptTokens?: number; completionTokens?: number } | undefined;

  try {
    const result = await openrouter.chat.send({
      httpReferer: APP_URL,
      appTitle: "Kraftwürfel",
      chatRequest: {
        model: MODEL,
        temperature: TEMPERATURE,
        maxTokens: MAX_TOKENS,
        responseFormat: { type: "json_object" },
        stream: false,
        messages: [
          { role: "system", content: system },
          { role: "user", content: userPrompt },
        ],
      },
    });

    // send() ist überladen und liefert typseitig immer "Ergebnis oder Stream".
    // Bei stream:false kommt das Ergebnis — hier wird das auch tatsächlich geprüft.
    if (!("choices" in result)) {
      console.error("unexpected streaming response", MODEL);
      return json({ error: "model request failed" }, 502);
    }

    content = readContent(result.choices?.[0]?.message?.content);
    usage = result.usage;
  } catch (err) {
    // Modellfehler und Netzprobleme landen beide hier. Details nur ins Log —
    // der Client bekommt keine Schlüssel oder Anbieter-Interna zu sehen.
    console.error("openrouter request failed", MODEL, (err as Error).message);
    return json({ error: "model request failed" }, 502);
  }

  if (!content) return json({ error: "empty model response" }, 502);

  let plan;
  try {
    plan = validatePlan(extractJson(content), answers);
  } catch (err) {
    console.error("parse error", (err as Error).message, content.slice(0, 500));
    return json({ error: "could not read the model response" }, 502);
  }

  if (!plan) return json({ error: "model returned no usable exercises" }, 502);

  console.log("plan generated", MODEL, "tokens", usage?.promptTokens, usage?.completionTokens);

  await supabase.from("ai_generations").insert({
    user_id: user.id,
    model: MODEL,
    goal: answers.goal,
    days: answers.days.length,
  });

  return json({ plan, model: MODEL });
});
