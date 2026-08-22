# KRAFTWÜRFEL

Freemium-Trainings-App, zweisprachig (Deutsch/Englisch).

**Kostenlos, ohne Konto:** Split wählen, Plan würfeln, Sätze/Wiederholungen/Pausen anpassen,
einzelne Übungen neu würfeln, Mehrwochen-Pläne würfeln.

**Pro:** der KI-Coach (Plan nach Ziel, Erfahrung, Equipment und Einschränkungen), Pläne speichern
und laden, Trainingspläne starten und verfolgen, Favoriten, Sync über alle Geräte.

## Stack

| Ebene | Wahl |
|---|---|
| Frontend | React 19 + Vite 8, reines CSS |
| Icons | `lucide-react` + Inline-SVG-Logo |
| Auth | Supabase Auth (E-Mail + Passwort) |
| Datenbank | Supabase Postgres, pro Nutzer via Row Level Security getrennt |
| KI | Supabase Edge Function → OpenRouter (`anthropic/claude-sonnet-4.5`) |
| Tests | Vitest |

## Schnellstart

```bash
npm install && npm run dev
```

Läuft sofort im **lokalen Modus**: Pläne landen in `localStorage`, es gibt keine Anmeldung und der
KI-Coach ist nicht erreichbar (der braucht die Edge Function). Zum Durchspielen der Rollen ohne
Supabase: `VITE_LOCAL_ROLE=free` oder `pro` in `.env`.

## Supabase einrichten

1. Projekt auf [supabase.com](https://supabase.com) anlegen.
2. `supabase/schema.sql` im SQL-Editor ausführen. Das legt an:
   - `profiles` (Rollen, wird bei der Registrierung automatisch befüllt)
   - `plans`, `active_plans`, `favorites` (die Nutzerdaten)
   - `ai_generations` (Protokoll für das Tageslimit)
   - alle RLS-Policies
3. `.env.example` nach `.env` kopieren und die beiden Werte aus *Project Settings → API* eintragen.
4. `npm run dev` neu starten.

### Jemanden auf Pro setzen

Es gibt bewusst keinen Weg, sich selbst freizuschalten — die `profiles`-Policy erlaubt nur Lesen.
Freischalten passiert im SQL-Editor:

```sql
update public.profiles set is_premium = true where email = 'name@example.com';
```

## KI-Coach einrichten

Der OpenRouter-Schlüssel darf nicht ins Frontend, und ob jemand Pro hat, muss serverseitig
entschieden werden. Beides erledigt die Edge Function — sie nutzt das offizielle
[`@openrouter/sdk`](https://www.npmjs.com/package/@openrouter/sdk).

```bash
supabase link --project-ref <dein-project-ref>
supabase secrets set OPENROUTER_API_KEY=sk-or-...
supabase functions deploy generate-plan
```

Nichts davon steht im Code — die Deployment-Pipeline setzt alle Werte als Secrets:

| Secret | Standard | Zweck |
|---|---|---|
| `OPENROUTER_API_KEY` | — | **Pflicht.** Ohne Schlüssel antwortet die Function mit 500. |
| `OPENROUTER_MODEL` | `anthropic/claude-sonnet-4.5` | Modell wechseln ohne Code-Änderung |
| `OPENROUTER_TEMPERATURE` | `0.7` | Wie frei das Modell variieren darf |
| `OPENROUTER_MAX_TOKENS` | `4000` | Obergrenze pro Plan |
| `AI_DAILY_LIMIT` | `20` | Generierungen pro Konto und Tag |
| `ALLOWED_ORIGIN` | `*` | CORS und `HTTP-Referer` auf die eigene Domain |

Modell wechseln, ohne neu zu deployen:

```bash
supabase secrets set OPENROUTER_MODEL=openai/gpt-5.1
```

Der Aufruf läuft bewusst **ohne Streaming**: der Plan wird erst gegen den Übungskatalog validiert
und umgebaut, bevor er den Client erreicht — halbfertige Chunks nützen dort nichts, und der
Ladezustand im Frontend deckt die Wartezeit ab.

Die Function prüft in dieser Reihenfolge: gültiges JWT → Pro-Rolle → Tageslimit → Eingaben. Erst
danach geht ein Request an OpenRouter. Die Antwort des Modells wird gegen die Übungsliste
validiert: Übungen, die es nicht gibt, fliegen raus, Sätze und Pausen werden in gültige Bereiche
gezwungen.

### Warum die Übungen vorgegeben sind

Das Modell bekommt die 137 Übungen als Katalog und darf nur daraus wählen. Ein Modell könnte
Übungen auch frei erfinden — dann passen aber Namen, Kategorien und Equipment nicht mehr zu dem,
was die App speichert, filtert und anzeigt, und kuratierte Entscheidungen (der Frauen-Split lässt
Brust bewusst weg) gehen verloren. Wer das lockern will, ändert `validatePlan` in der Function.

Nach jeder Änderung an `src/data/exercises.js`:

```bash
npm run sync:exercises
```

Das schreibt die Kopie für die Edge Function nach `supabase/functions/_shared/exercises.ts`.

## Skripte

```bash
npm run dev
npm run build
npm run preview
npm test
npm run sync:exercises
```

## Aufbau

```
src/
  data/exercises.js       137 Übungen, Splits, Methoden, Kategorien
  lib/planLogic.js        Würfel-Logik: buildPlan, Satzschemata, Reroll, (De-)Serialisierung
  lib/dateUtils.js        Wochentage, Wochen-/Zyklus-Berechnung
  lib/progress.js         Fortschritt aus Startdatum + heute
  lib/repository.js       Datenzugriff — Supabase oder localStorage, gleiche Schnittstelle
  lib/auth.jsx            Rollen: frei / pro
  lib/i18n.jsx            Wörterbuch DE/EN
  lib/aiClient.js         Aufruf der Edge Function, Mapping KI-Plan -> App-Format
  hooks/                  useReel, useSavedPlans, useActivePlan, useFavorites
  components/             fünf Tabs, ProScreen, PremiumGate, DayBlock, CycleBlock, ErrorBoundary
  styles/app.css          komplettes Design
supabase/
  schema.sql              Tabellen, Rollen, RLS
  functions/generate-plan Edge Function (Deno)
  functions/_shared       generierte Übungsliste
```

### Wo die Grenzen gezogen sind

Die Oberfläche versteckt gesperrte Funktionen, aber das ist nur Kosmetik. Durchgesetzt wird alles
in Postgres und in der Edge Function:

- `plans`, `active_plans`, `favorites`: Lesen und Löschen darf jeder für die eigenen Zeilen,
  Anlegen und Ändern nur mit Pro. Wer Pro verliert, kommt weiterhin an seine Daten und kann
  aufräumen.
- Der KI-Coach prüft die Rolle serverseitig, bevor ein einziger Token an OpenRouter geht.

### Sprachen

Deutsch ist Standard, umgeschaltet wird im Header, die Wahl bleibt gespeichert. Übersetzt sind
Oberfläche, Kategorien und Equipment. **Übungsnamen bleiben deutsch** — sie sind Daten, keine
Oberfläche, und werden so gespeichert. Wenn englische Übungsnamen gewünscht sind, braucht
`src/data/exercises.js` ein zweites Namensfeld.

## Deployment

Statischer Build, kein eigener Server:

```bash
npm run build   # -> dist/
```

Auf Vercel, Netlify oder Cloudflare Pages ablegen, die beiden `VITE_`-Variablen dort als
Build-Environment setzen und die Deploy-URL in den Supabase-Auth-Einstellungen als *Site URL*
eintragen. `ALLOWED_ORIGIN` in den Function-Secrets auf dieselbe Domain setzen.

## Offen

- **Bezahlung**: `is_premium` wird derzeit von Hand gesetzt. Für echten Verkauf fehlt eine
  Anbindung (Stripe Checkout + Webhook, der das Flag setzt).
- **KI-Pläne speichern**: ein KI-Plan lässt sich als Trainingsplan starten und tageweise
  favorisieren, aber nicht unter eigenem Namen ablegen.
- Keine Übungsbilder oder -videos.
- Kein Offline-Modus im Supabase-Betrieb.
