import { supabase, isSupabaseConfigured } from "./supabase.js";
import { EXERCISES } from "../data/exercises.js";
import { WEEKDAYS } from "./dateUtils.js";
import { planNamesForDays } from "./planNames.js";

/*
  Ruft die Edge Function auf.
  Sollte die Edge Function nicht erreichbar sein (oder noch nicht auf Supabase deployed),
  greift sofort die integrierte KI-Sportwissenschafts-Engine ein, sodass immer
  ein perfekter, personalisierter Trainingsplan generiert wird!
*/

export async function generateAiPlan(answers) {
  /*
    Warum der Rückfall passiert, muss sichtbar sein. Vorher wurde jeder Fehler
    verschluckt und der Vorlagenplan kam wortlos heraus — damit ließ sich nicht
    unterscheiden, ob der Schlüssel fehlt, die Function nicht deployt ist oder
    das Tageslimit erreicht wurde.
  */
  let reason = "no-backend";

  if (isSupabaseConfigured && supabase) {
    try {
      const { data, error } = await supabase.functions.invoke("generate-plan", {
        body: answers,
      });

      if (!error && data?.plan) {
        return { ...data.plan, source: "ai" };
      }

      reason = "unknown";
      if (error) {
        // invoke() verpackt HTTP-Fehler; die eigentliche Meldung steckt im Body.
        reason = error.message || "invoke-failed";
        try {
          const body = await error.context?.json?.();
          if (body?.error) reason = body.error;
        } catch {
          // Body war kein JSON
        }
      }
      console.warn("[kraftwuerfel] KI-Coach nicht erreichbar:", reason);
    } catch (err) {
      reason = err?.message || "network";
      console.warn("[kraftwuerfel] KI-Coach nicht erreichbar:", reason);
    }
  }

  // Lokale Vorlagen-Engine. Wird als solche gekennzeichnet, inklusive Grund —
  // ein Plan aus der Vorlage darf sich nicht als Modellantwort ausgeben.
  return { ...generateLocalAiPlan(answers), source: "local", fallbackReason: reason };
}

/*
  Generiert einen maßgeschneiderten Mehrwochen-Trainingsplan basierend auf:
  Geschlecht, Alter, Größe, Gewicht, Ziel, Erfahrung, Trainingstage, Equipment & Einschränkungen.
*/
function generateLocalAiPlan(answers) {
  const {
    sex = "male",
    age = 28,
    height = 180,
    weight = 80,
    goal = "muscle",
    experience = "intermediate",
    days = ["Mo", "Mi", "Fr"],
    sessionMinutes = 60,
    equipment = [],
    limitations = "",
    weeks = 4,
    language = "de",
    warmup = "auto",
    diet = "omnivore",
  } = answers;

  const numDays = Math.max(1, days.length);
  const isFemale = sex === "female";
  const isBeginner = experience === "beginner";
  const isAdvanced = experience === "advanced";
  const isEn = language === "en";

  // Reps & Sets & Rest basierend auf Ziel
  let repScheme = "8-12";
  let defaultSets = 3;
  let defaultRest = 60;
  let goalTitleDe = "Muskelaufbau";
  let goalTitleEn = "Muscle Growth";

  if (goal === "abnehmen") {
    repScheme = "12-18";
    defaultSets = 3;
    defaultRest = 45;
    goalTitleDe = "Abnehmen & Fettverbrennung";
    goalTitleEn = "Fat Loss & Calorie Burn";
  } else if (goal === "strength") {
    repScheme = isFemale ? "6-8" : "4-6";
    defaultSets = 4;
    defaultRest = 90;
    goalTitleDe = "Maximalkraft & Stärke";
    goalTitleEn = "Max Strength & Power";
  } else if (goal === "definition") {
    repScheme = "10-15";
    defaultSets = 3;
    defaultRest = 45;
    goalTitleDe = "Definition & Straffung";
    goalTitleEn = "Toning & Definition";
  } else if (goal === "fitness") {
    repScheme = "10-15";
    defaultSets = 3;
    defaultRest = 60;
    goalTitleDe = "Allgemeine Fitness & Gesundheit";
    goalTitleEn = "General Fitness & Health";
  }

  // Equipment Filter
  const eqFilter = (ex) => {
    if (equipment.length === 0) return true; // Alles erlaubt
    return equipment.includes(ex.equipment) || ex.equipment === "Körpergewicht";
  };

  // Einschränkungen prüfen
  const limitLower = (limitations || "").toLowerCase();
  const limitFilter = (ex) => {
    if (!limitLower) return true;
    const nameLower = ex.name.toLowerCase();
    if (limitLower.includes("knie") && (nameLower.includes("kniebeuge") || nameLower.includes("squat"))) return false;
    if (limitLower.includes("schulter") && ex.category === "Schultern" && ex.heavy) return false;
    if (limitLower.includes("überkopf") && (nameLower.includes("überkopf") || nameLower.includes("press"))) return false;
    if (limitLower.includes("rücken") && nameLower.includes("kreuzheben")) return false;
    if (limitLower.includes("handgelenk") && ex.equipment === "Kurzhantel") return false;
    return true;
  };

  // Beginner Filter (Anfänger bevorzugen geführte Maschinen, Eigengewicht und Kurzhanteln vor Maximalkraft-Langhanteln)
  const experienceFilter = (ex) => {
    if (isBeginner) {
      if (ex.name === "Kreuzheben" || ex.name === "Good Mornings" || ex.name === "Clean and Press") return false;
    }
    return true;
  };

  const pool = EXERCISES.filter((ex) => eqFilter(ex) && limitFilter(ex) && experienceFilter(ex));

  // Helper zum Finden einer Übung aus Pool
  const findEx = (nameQuery, fallbackCategory) => {
    const direct = pool.find((e) => e.name.toLowerCase().includes(nameQuery.toLowerCase()));
    if (direct) return direct;
    const catCandidates = pool.filter((e) => e.category === fallbackCategory);
    return catCandidates[Math.floor(Math.random() * catCandidates.length)] || pool[0];
  };

  // -------------------------------------------------------------
  // SPORTWISSENSCHAFTLICHE SPLIT-STRUKTUREN
  // -------------------------------------------------------------
  const splitConfigs = [];

  if (isFemale) {
    // WEIBLICHE TRAININGSPLÄNE (Glutes, Straffung, Haltung, Core & Beine)
    if (numDays === 1) {
      splitConfigs.push({
        name: isEn ? "Full Body Toning & Glute Focus" : "Ganzkörper & Gesäß-Fokus",
        exercises: [
          { query: "Hip Thrust", cat: "Gesäß", sets: 4, reps: "10-12", note: "Fokus auf maximale Gesäßkontraktion" },
          { query: "Goblet Squats", cat: "Beine", sets: 3, reps: repScheme, note: "Tiefe Kniebeuge für Quads & Glutes" },
          { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Stärkt die Rücken- und Haltungsmuskulatur" },
          { query: "Seitheben (Kurzhantel)", cat: "Schultern", sets: 3, reps: "12-15", note: "Definierte Schultern" },
          { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 3, reps: "10-12", note: "Fokus auf Hamstrings & Po" },
          { query: "Plank", cat: "Bauch", sets: 3, reps: "45-60s", note: "Stabile Rumpfmuskulatur" },
        ],
      });
    } else if (numDays === 2) {
      splitConfigs.push(
        {
          name: isEn ? "Day A: Lower Body & Glutes" : "Tag A: Unterkörper & Gesäß",
          exercises: [
            { query: "Hip Thrust", cat: "Gesäß", sets: 4, reps: "10-12", note: "Hauptübung für den Po" },
            { query: "Bulgarian Split Squats", cat: "Beine", sets: 3, reps: "10-12", note: "Perfekt für straffe Beine" },
            { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 3, reps: "10-12", note: "Dehnung der Beinrückseite" },
            { query: "Beinpresse", cat: "Beine", sets: 3, reps: repScheme, note: "Kontrollierte Beinbelastung" },
            { query: "Cable Crunches", cat: "Bauch", sets: 3, reps: "15", note: "Gezieltes Bauchtraining" },
          ],
        },
        {
          name: isEn ? "Day B: Upper Body, Back & Posture" : "Tag B: Oberkörper, Rücken & Haltung",
          exercises: [
            { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Breiter Rücken für schöne Taille" },
            { query: "Kurzhantel-Schrägbankdrücken", cat: "Brust", sets: 3, reps: repScheme, note: "Strafft die obere Brust" },
            { query: "Kabelrudern sitzend", cat: "Rücken", sets: 3, reps: repScheme, note: "Verbessert die aufrechte Haltung" },
            { query: "Seitheben (Kurzhantel)", cat: "Schultern", sets: 3, reps: "12-15", note: "Runde Schultern" },
            { query: "Trizepsdrücken am Kabel", cat: "Trizeps", sets: 3, reps: "12-15", note: "Straffe Arme" },
            { query: "Russian Twists", cat: "Bauch", sets: 3, reps: "20", note: "Seitliche Bauchmuskeln" },
          ],
        }
      );
    } else if (numDays === 3) {
      splitConfigs.push(
        {
          name: isEn ? "Day 1: Glute & Leg Power" : "Tag 1: Gesäß & Beine A (Hip Focus)",
          exercises: [
            { query: "Hip Thrust", cat: "Gesäß", sets: 4, reps: "8-12", note: "Volle Hüftstreckung oben halten" },
            { query: "Bulgarian Split Squats", cat: "Beine", sets: 3, reps: "10-12", note: "Standbein fest aufgestellt" },
            { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 3, reps: "10-12", note: "Rücken gerade, Po nach hinten" },
            { query: "Beinbeuger liegend", cat: "Beine", sets: 3, reps: "12-15", note: "Beinrückseite isolieren" },
            { query: "Kabelzug Kickback", cat: "Gesäß", sets: 3, reps: "15", note: "Gluteus Maximus Peak-Kontraktion" },
          ],
        },
        {
          name: isEn ? "Day 2: Back, Shoulders & Toned Arms" : "Tag 2: Rücken, Schultern & Arme",
          exercises: [
            { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Ellenbogen nach unten ziehen" },
            { query: "Kurzhantel-Schulterdrücken", cat: "Schultern", sets: 3, reps: repScheme, note: "Aufrecht sitzen" },
            { query: "Kabelrudern sitzend", cat: "Rücken", sets: 3, reps: repScheme, note: "Schulterblätter zusammenziehen" },
            { query: "Seitheben am Kabelzug", cat: "Schultern", sets: 3, reps: "12-15", note: "Seitliche Schultern betonen" },
            { query: "Trizepsdrücken am Kabel (Seil)", cat: "Trizeps", sets: 3, reps: "12-15", note: "Armrückseite straffen" },
            { query: "Plank (Unterarmstütz)", cat: "Bauch", sets: 3, reps: "60s", note: "Bauch fest anspannen" },
          ],
        },
        {
          name: isEn ? "Day 3: Glute Hypertrophy, Legs & Core" : "Tag 3: Gesäß, Oberschenkel & Core",
          exercises: [
            { query: "Goblet Squats", cat: "Beine", sets: 3, reps: repScheme, note: "Aufrechte Haltung" },
            { query: "Beckenheben (Glute Bridge)", cat: "Gesäß", sets: 3, reps: "12-15", note: "Glute Pump" },
            { query: "Ausfallschritte", cat: "Beine", sets: 3, reps: "12", note: "Dynamische Schrittfolge" },
            { query: "Hüftabduktion (Maschine)", cat: "Gesäß", sets: 3, reps: "15-20", note: "Seitliches Gesäß (Gluteus Medius)" },
            { query: "Beinheben hängend", cat: "Bauch", sets: 3, reps: "12-15", note: "Unterer Bauch" },
          ],
        }
      );
    } else {
      // 4+ Tage
      splitConfigs.push(
        {
          name: "Unterkörper A (Glute Fokus)",
          exercises: [
            { query: "Hip Thrust", cat: "Gesäß", sets: 4, reps: "8-12", note: "Top-Übung für Po" },
            { query: "Bulgarian Split Squats", cat: "Beine", sets: 3, reps: "10-12", note: "Einbeinige Stärke" },
            { query: "Beinpresse", cat: "Beine", sets: 3, reps: "12-15", note: "Volle Tiefe" },
            { query: "Kabelzug Kickback", cat: "Gesäß", sets: 3, reps: "15", note: "Glute Isolation" },
            { query: "Plank", cat: "Bauch", sets: 3, reps: "60s", note: "Core Stabilität" },
          ],
        },
        {
          name: "Oberkörper (Rücken & Schultern)",
          exercises: [
            { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Haltungsverbesserung" },
            { query: "Kurzhantel-Schrägbankdrücken", cat: "Brust", sets: 3, reps: repScheme, note: "Obere Brust" },
            { query: "Kabelrudern sitzend", cat: "Rücken", sets: 3, reps: repScheme, note: "Rückenmitte" },
            { query: "Seitheben (Kurzhantel)", cat: "Schultern", sets: 3, reps: "12-15", note: "Schulterkontur" },
            { query: "Trizepsdrücken", cat: "Trizeps", sets: 3, reps: "12-15", note: "Trizeps Toning" },
          ],
        },
        {
          name: "Unterkörper B (Hamstrings & Posterior Chain)",
          exercises: [
            { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 4, reps: "10-12", note: "Hamstrings & Glutes" },
            { query: "Goblet Squats", cat: "Beine", sets: 3, reps: repScheme, note: "Kniebeugenvariante" },
            { query: "Beinbeuger liegend", cat: "Beine", sets: 3, reps: "12-15", note: "Beinbeuger" },
            { query: "Hüftabduktion (Maschine)", cat: "Gesäß", sets: 3, reps: "15-20", note: "Gluteus Medius" },
            { query: "Russian Twists", cat: "Bauch", sets: 3, reps: "20", note: "Taille & Core" },
          ],
        },
        {
          name: "Ganzkörper & Fatburn Conditioning",
          exercises: [
            { query: "Kettlebell Swings", cat: "Ganzkörper", sets: 3, reps: "15-20", note: "Explosive Hüftkraft" },
            { query: "Ausfallschritte", cat: "Beine", sets: 3, reps: "12", note: "Dynamische Kraft" },
            { query: "Face Pulls", cat: "Schultern", sets: 3, reps: "15", note: "Schultergesundheit" },
            { query: "Crunches", cat: "Bauch", sets: 3, reps: "20", note: "Bauchbrennen" },
          ],
        }
      );
    }
  } else {
    // MÄNNLICHE TRAININGSPLÄNE (Klassischer PPL / Upper-Lower / Ganzkörper)
    if (numDays === 1) {
      splitConfigs.push({
        name: isEn ? "Full Body Compound Power" : "Ganzkörper Grundübungen",
        exercises: [
          { query: "Kniebeugen", cat: "Beine", sets: 3, reps: repScheme, note: "Schwere Kniebeugen" },
          { query: "Bankdrücken", cat: "Brust", sets: 3, reps: repScheme, note: "Grundübung für die Brust" },
          { query: "Klimmzüge", cat: "Rücken", sets: 3, reps: repScheme, note: "Breiter Latissimus" },
          { query: "Schulterdrücken (Langhantel)", cat: "Schultern", sets: 3, reps: repScheme, note: "Schulterkraft" },
          { query: "Langhantel-Bizepscurls", cat: "Bizeps", sets: 3, reps: "10-12", note: "Bizeps Peak" },
          { query: "Plank", cat: "Bauch", sets: 3, reps: "60s", note: "Stabiler Rumpf" },
        ],
      });
    } else if (numDays === 2) {
      splitConfigs.push(
        {
          name: isEn ? "Upper Body Power" : "Oberkörper Kraft & Hypertrophie",
          exercises: [
            { query: "Bankdrücken", cat: "Brust", sets: 4, reps: repScheme, note: "Brust Grundübung" },
            { query: "Langhantelrudern vorgebeugt", cat: "Rücken", sets: 4, reps: repScheme, note: "Dicker Rücken" },
            { query: "Schulterdrücken (Kurzhantel)", cat: "Schultern", sets: 3, reps: repScheme, note: "Schultermuskulatur" },
            { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Breite V-Form" },
            { query: "Dips (Trizepsfokus)", cat: "Trizeps", sets: 3, reps: "10-12", note: "Trizepsmasse" },
            { query: "Langhantel-Bizepscurls", cat: "Bizeps", sets: 3, reps: "10-12", note: "Armbeuger" },
          ],
        },
        {
          name: isEn ? "Lower Body & Core" : "Unterkörper & Core",
          exercises: [
            { query: "Kniebeugen", cat: "Beine", sets: 4, reps: repScheme, note: "König der Beinübungen" },
            { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 3, reps: "8-10", note: "Posterior Chain" },
            { query: "Beinpresse", cat: "Beine", sets: 3, reps: "10-12", note: "Quadrizeps Pump" },
            { query: "Wadenheben stehend", cat: "Waden", sets: 3, reps: "12-15", note: "Wadenkraft" },
            { query: "Beinheben hängend", cat: "Bauch", sets: 3, reps: "12-15", note: "Unterer Bauch" },
          ],
        }
      );
    } else if (numDays === 3) {
      splitConfigs.push(
        {
          name: isEn ? "Push (Chest, Delts, Triceps)" : "Push (Brust, Schulter, Trizeps)",
          exercises: [
            { query: "Bankdrücken", cat: "Brust", sets: 4, reps: repScheme, note: "Schwere Grundübung" },
            { query: "Schrägbankdrücken (Kurzhantel)", cat: "Brust", sets: 3, reps: repScheme, note: "Obere Brust" },
            { query: "Schulterdrücken (Kurzhantel)", cat: "Schultern", sets: 3, reps: repScheme, note: "Schulterdrücken" },
            { query: "Seitheben (Kurzhantel)", cat: "Schultern", sets: 3, reps: "12-15", note: "Seitliche Schulterköpfe" },
            { query: "Trizepsdrücken am Kabel (Seil)", cat: "Trizeps", sets: 3, reps: "12-15", note: "Trizeps Peak" },
          ],
        },
        {
          name: isEn ? "Pull (Back, Biceps, Traps)" : "Pull (Rücken, Bizeps, Nacken)",
          exercises: [
            { query: "Klimmzüge", cat: "Rücken", sets: 4, reps: repScheme, note: "Körpergewichts-Grundübung" },
            { query: "Langhantelrudern vorgebeugt", cat: "Rücken", sets: 3, reps: repScheme, note: "Rückendichte" },
            { query: "Latzug breit", cat: "Rücken", sets: 3, reps: repScheme, note: "Latbreite" },
            { query: "Face Pulls", cat: "Schultern", sets: 3, reps: "15", note: "Hintere Schulter & Rotatoren" },
            { query: "Langhantel-Bizepscurls", cat: "Bizeps", sets: 3, reps: "10-12", note: "Bizepsmasse" },
            { query: "Hammer-Curls", cat: "Bizeps", sets: 3, reps: "12", note: "Unterarm & Brachialis" },
          ],
        },
        {
          name: isEn ? "Legs & Core" : "Beine & Core",
          exercises: [
            { query: "Kniebeugen", cat: "Beine", sets: 4, reps: repScheme, note: "Volle Kniebeugetiefe" },
            { query: "Rumänisches Kreuzheben", cat: "Rücken", sets: 3, reps: "8-10", note: "Hamstrings & Glutes" },
            { query: "Beinpresse", cat: "Beine", sets: 3, reps: "10-12", note: "Quadrizeps Isolation" },
            { query: "Beinstrecker", cat: "Beine", sets: 3, reps: "12-15", note: "Oberschenkelvorderseite" },
            { query: "Wadenheben stehend", cat: "Waden", sets: 4, reps: "15", note: "Wadenkontraktion" },
            { query: "Beinheben hängend", cat: "Bauch", sets: 3, reps: "12-15", note: "Core Stärke" },
          ],
        }
      );
    } else {
      // 4+ Tage
      splitConfigs.push(
        {
          name: "Oberkörper A (Fokus Brust & Rudern)",
          exercises: [
            { query: "Bankdrücken", cat: "Brust", sets: 4, reps: repScheme, note: "Schwere Brustübung" },
            { query: "Langhantelrudern vorgebeugt", cat: "Rücken", sets: 3, reps: repScheme, note: "Rücken Grundübung" },
            { query: "Schrägbankdrücken (Kurzhantel)", cat: "Brust", sets: 3, reps: repScheme, note: "Obere Brust" },
            { query: "Trizepsdrücken am Kabel", cat: "Trizeps", sets: 3, reps: "12", note: "Trizeps" },
            { query: "Langhantel-Bizepscurls", cat: "Bizeps", sets: 3, reps: "10-12", note: "Bizeps" },
          ],
        },
        {
          name: "Unterkörper A (Quad & Waden)",
          exercises: [
            { query: "Kniebeugen", cat: "Beine", sets: 4, reps: repScheme, note: "Quadrizeps Fokus" },
            { query: "Beinpresse", cat: "Beine", sets: 3, reps: "10-12", note: "Voller Druck" },
            { query: "Ausfallschritte", cat: "Beine", sets: 3, reps: "12", note: "Beinkraft" },
            { query: "Wadenheben stehend", cat: "Waden", sets: 3, reps: "15", note: "Waden" },
            { query: "Plank", cat: "Bauch", sets: 3, reps: "60s", note: "Core" },
          ],
        },
        {
          name: "Oberkörper B (Fokus Schultern & Latzug)",
          exercises: [
            { query: "Klimmzüge", cat: "Rücken", sets: 4, reps: repScheme, note: "Klimmzüge" },
            { query: "Schulterdrücken (Kurzhantel)", cat: "Schultern", sets: 3, reps: repScheme, note: "Schultern" },
            { query: "Latzug eng (Untergriff)", cat: "Rücken", sets: 3, reps: repScheme, note: "Unterer Lat" },
            { query: "Seitheben (Kurzhantel)", cat: "Schultern", sets: 3, reps: "12-15", note: "Seitliche Schulter" },
            { query: "Hammer-Curls", cat: "Bizeps", sets: 3, reps: "12", note: "Brachialis" },
          ],
        },
        {
          name: "Unterkörper B (Hamstrings & Kreuzheben)",
          exercises: [
            { query: "Kreuzheben", cat: "Rücken", sets: 4, reps: "6-8", note: "Ganzkörper-Ziehübung" },
            { query: "Beinbeuger liegend", cat: "Beine", sets: 3, reps: "12", note: "Hamstrings" },
            { query: "Bulgarian Split Squats", cat: "Beine", sets: 3, reps: "10-12", note: "Glutes & Quads" },
            { query: "Wadenheben sitzend", cat: "Waden", sets: 3, reps: "15", note: "Schollenmuskel" },
            { query: "Beinheben hängend", cat: "Bauch", sets: 3, reps: "12", note: "Unterer Bauch" },
          ],
        }
      );
    }
  }

  /*
    Kalorien nach Mifflin-St Jeor — die Formel, die auch Ernährungsberatungen
    verwenden. Damit liefert die Vorlage denselben Umfang wie das Modell, nur
    ohne dessen Feinabstimmung. Aktivitätsfaktor aus den Trainingstagen,
    Zu-/Abschlag aus dem Ziel.
  */
  const bmr = isFemale
    ? 10 * weight + 6.25 * height - 5 * age - 161
    : 10 * weight + 6.25 * height - 5 * age + 5;
  const activity = 1.2 + Math.min(numDays, 6) * 0.075;
  let dailyCalories = Math.round((bmr * activity) / 10) * 10;
  if (goal === "abnehmen" || goal === "definition") dailyCalories -= 400;
  if (goal === "muscle" || goal === "strength") dailyCalories += 300;
  dailyCalories = Math.max(1200, dailyCalories);

  const proteinPerKg = goal === "abnehmen" || goal === "definition" ? 2.0 : 1.8;
  const protein = Math.round(weight * proteinPerKg);
  const fat = Math.round((dailyCalories * 0.27) / 9);
  const carbs = Math.max(0, Math.round((dailyCalories - protein * 4 - fat * 9) / 4));

  const vegan = diet === "vegan";
  const vegetarian = diet === "vegetarian";
  const proteinSource = vegan
    ? "Tofu, Linsen, Kichererbsen"
    : vegetarian
      ? "Magerquark, Eier, Hüttenkäse"
      : "Hähnchenbrust, Fisch, Magerquark";
  const shakeBase = vegan ? "Erbsen-/Reisprotein mit Hafermilch" : "Whey mit Milch oder Wasser";

  const meals = [
    {
      time: isEn ? "Morning" : "Morgens",
      name: isEn ? "Breakfast" : "Frühstück",
      calories: Math.round(dailyCalories * 0.25),
      items: vegan
        ? ["Haferflocken mit Sojamilch", "Beeren", "Walnüsse"]
        : ["Haferflocken mit Milch", "Beeren", "Magerquark"],
    },
    {
      time: isEn ? "Midday" : "Mittags",
      name: isEn ? "Lunch" : "Mittagessen",
      calories: Math.round(dailyCalories * 0.35),
      items: [proteinSource, isEn ? "Rice or potatoes" : "Reis oder Kartoffeln", isEn ? "Vegetables" : "Gemüse"],
    },
    {
      time: isEn ? "Afternoon" : "Nachmittags",
      name: isEn ? "Snack" : "Zwischenmahlzeit",
      calories: Math.round(dailyCalories * 0.15),
      items: vegan ? ["Obst", "Mandeln"] : ["Obst", "Naturjoghurt"],
    },
    {
      time: isEn ? "Evening" : "Abends",
      name: isEn ? "Dinner" : "Abendessen",
      calories: Math.round(dailyCalories * 0.25),
      items: [proteinSource, isEn ? "Salad" : "Salat", isEn ? "Wholegrain bread" : "Vollkornbrot"],
    },
  ];

  const shakes = [
    {
      when: isEn ? "Within 1h after training" : "Innerhalb 1 Std. nach dem Training",
      what: `${shakeBase} — ${isEn ? "about 30 g protein" : "ca. 30 g Protein"}`,
    },
  ];

  const nutrition = {
    diet,
    dailyCalories,
    protein,
    carbs,
    fat,
    meals,
    shakes,
    notes: isEn
      ? ["These are estimates — adjust by how your weight actually moves.", "Drink 2-3 litres of water a day."]
      : [
          "Das sind Schätzwerte — pass sie an, wie sich dein Gewicht tatsächlich entwickelt.",
          "Trinke 2-3 Liter Wasser am Tag.",
        ],
  };

  const wantsWarmup = warmup !== "no";
  const warmupFor = (focusName) =>
    !wantsWarmup
      ? []
      : [
          { name: isEn ? "5 min cardio" : "5 Min lockeres Cardio", duration: "5 min", note: "" },
          {
            name: /bein|leg|gesäß|glute/i.test(focusName)
              ? isEn ? "Hip and ankle mobility" : "Hüft- und Sprunggelenksmobilisation"
              : isEn ? "Shoulder circles and band pull-aparts" : "Schulterkreisen und Band-Pull-Aparts",
            duration: "2 min",
            note: "",
          },
          { name: isEn ? "2 light warm-up sets" : "2 leichte Aufwärmsätze", duration: "", note: isEn ? "of the first exercise" : "der ersten Übung" },
        ];

  // Erzeuge die Tagespläne passend zu den gewählten Tagen
  const dayPlans = [];

  days.forEach((dayName, idx) => {
    const config = splitConfigs[idx % splitConfigs.length];
    const generatedExercises = [];

    config.exercises.forEach((item) => {
      const resolvedEx = findEx(item.query, item.cat);
      if (resolvedEx) {
        generatedExercises.push({
          name: resolvedEx.name,
          category: resolvedEx.category,
          equipment: resolvedEx.equipment,
          sets: item.sets || defaultSets,
          reps: item.reps || repScheme,
          rest: defaultRest,
          note: item.note || "Saubere Form über vollen Bewegungsumfang",
        });
      }
    });

    dayPlans.push({
      day: dayName,
      focus: config.name,
      warmup: warmupFor(config.name),
      exercises: generatedExercises,
    });
  });

  const athleteLabel = isFemale
    ? (isEn ? "Female Athlete" : "Athletin")
    : (isEn ? "Male Athlete" : "Athlet");

  return {
    title: isEn
      ? `AI ${goalTitleEn} Plan (${numDays} Days)`
      : `KI-${goalTitleDe} Plan (${numDays} Tage)`,
    overview: isEn
      ? `Personalized ${weeks}-week training plan created for ${athleteLabel} (${age} yrs, ${height}cm, ${weight}kg) with ${experience} experience.`
      : `Personalisierter ${weeks}-Wochen Trainingsplan für ${athleteLabel} (${age} Jahre, ${height} cm, ${weight} kg) auf Level ${experience}.`,
    weeks: weeks,
    nutrition,
    periodization: isEn
      ? `Progressive Overload with weekly volume progression across ${weeks} weeks.`
      : `Progressive Überlastung mit wöchentlicher Steigerung der Gewichte über ${weeks} Wochen.`,
    days: dayPlans,
  };
}

/*
  Edge Function und lokaler Generator liefern leicht unterschiedliche Formen:
  die eine nennt den Tag "weekday", "summary", "notes", die andere "day",
  "overview", "periodization". Vorher hat die Oberfläche nur die zweite Variante
  gelesen — beim echten KI-Plan fielen Zusammenfassung und Hinweise deshalb
  stillschweigend weg.

  Hier wird beides auf eine Form gebracht, die Tage in Wochentagsreihenfolge
  sortiert (das Modell liefert sie sonst in beliebiger Folge, und dann stand
  Sonntag vor Mittwoch) und jeder Tag bekommt seinen Ein-Wort-Namen.
*/
export function normalizePlan(plan) {
  if (!plan) return null;

  const rawDays = Array.isArray(plan.days) ? plan.days : [];
  const days = rawDays
    .map((d) => ({ ...d, weekday: d.weekday || d.day }))
    .filter((d) => d.exercises?.length)
    .sort((a, b) => WEEKDAYS.indexOf(a.weekday) - WEEKDAYS.indexOf(b.weekday));

  const fallbackNames = planNamesForDays(
    days.map((d) => d.weekday),
    plan.title || ""
  );

  return {
    source: plan.source || "ai",
    fallbackReason: plan.fallbackReason || "",
    title: plan.title || "",
    summary: plan.summary || plan.overview || "",
    notes: Array.isArray(plan.notes) && plan.notes.length
      ? plan.notes
      : plan.periodization
        ? [plan.periodization]
        : [],
    nutrition: plan.nutrition || null,
    days: days.map((d) => ({
      ...d,
      // Das Modell darf benennen; sonst greift die lokale Wortliste.
      name: (d.name || "").trim().split(/\s+/)[0] || fallbackNames[d.weekday],
      warmup: Array.isArray(d.warmup) ? d.warmup : [],
    })),
  };
}

/* Ein KI-Tag wird zu genau den Slots, die der Rest der App schon versteht. */
export function aiDayToSlots(day) {
  return day.exercises.map((ex) => ({
    exercise: {
      id: `ai-${ex.name}`,
      name: ex.name,
      category: ex.category,
      categories: [ex.category],
      equipment: ex.equipment,
    },
    sets: ex.sets || 3,
    reps: ex.reps || "8-12",
    rest: ex.rest || 60,
    note: ex.note || "",
  }));
}
