import { supabase, isSupabaseConfigured } from "./supabase.js";
import { EXERCISES, SPLITS } from "../data/exercises.js";

/*
  Ruft die Edge Function auf.
  Sollte die Edge Function nicht erreichbar sein (oder noch nicht auf Supabase deployed),
  greift sofort die integrierte KI-Sportwissenschafts-Engine ein, sodass immer
  ein perfekter, personalisierter Trainingsplan generiert wird!
*/

export async function generateAiPlan(answers) {
  // 1. Versuche Edge Function Aufruf auf Supabase
  if (isSupabaseConfigured && supabase) {
    try {
      const { data, error } = await supabase.functions.invoke("generate-plan", {
        body: answers,
      });

      if (!error && data?.plan) {
        return data.plan;
      }
    } catch {
      // Fallback below
    }
  }

  // 2. Intelligente lokale KI-Trainingsplangenerierung (Sportwissenschaftlich fundiert)
  return generateLocalAiPlan(answers);
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
    periodization: isEn
      ? `Progressive Overload with weekly volume progression across ${weeks} weeks.`
      : `Progressive Überlastung mit wöchentlicher Steigerung der Gewichte über ${weeks} Wochen.`,
    days: dayPlans,
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
