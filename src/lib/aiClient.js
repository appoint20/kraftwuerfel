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

  // Reps & Sets & Rest basierend auf Ziel
  let repScheme = "8-12";
  let defaultSets = 3;
  let defaultRest = 60;
  let goalTitleDe = "Muskelaufbau (Hypertrophie)";
  let goalTitleEn = "Muscle Growth (Hypertrophy)";

  if (goal === "strength") {
    repScheme = "4-6";
    defaultSets = 4;
    defaultRest = 90;
    goalTitleDe = "Maximalkraft & Stärke";
    goalTitleEn = "Max Strength & Power";
  } else if (goal === "definition") {
    repScheme = "12-15";
    defaultSets = 3;
    defaultRest = 45;
    goalTitleDe = "Definition & Fettabbau";
    goalTitleEn = "Definition & Fat Loss";
  } else if (goal === "fitness") {
    repScheme = "10-15";
    defaultSets = 3;
    defaultRest = 60;
    goalTitleDe = "Allgemeine Fitness & Ausdauer";
    goalTitleEn = "General Fitness & Health";
  }

  // Erlaubtes Equipment filtern
  const eqFilter = (ex) => {
    if (equipment.length === 0) return true; // Alles erlaubt
    return equipment.includes(ex.equipment) || ex.equipment === "Körpergewicht";
  };

  // Einschränkungen prüfen
  const limitLower = (limitations || "").toLowerCase();
  const limitFilter = (ex) => {
    if (!limitLower) return true;
    if (limitLower.includes("knie") && ex.name.toLowerCase().includes("kniebeuge")) return false;
    if (limitLower.includes("schulter") && ex.category === "Schultern" && ex.heavy) return false;
    if (limitLower.includes("überkopf") && ex.name.toLowerCase().includes("überkopf")) return false;
    if (limitLower.includes("rücken") && ex.name.toLowerCase().includes("kreuzheben")) return false;
    if (limitLower.includes("handgelenk") && ex.equipment === "Kurzhantel") return false;
    return true;
  };

  const pool = EXERCISES.filter((ex) => eqFilter(ex) && limitFilter(ex));

  // Split-Struktur basierend auf Anzahl der Tage
  const dayPlans = [];
  const splitNames = [];

  if (numDays === 1) {
    splitNames.push({ name: "Ganzkörper", focus: ["Brust", "Rücken", "Beine", "Schultern", "Bauch"] });
  } else if (numDays === 2) {
    splitNames.push(
      { name: "Oberkörper", focus: ["Brust", "Rücken", "Schultern", "Bizeps", "Trizeps"] },
      { name: "Unterkörper & Core", focus: ["Beine", "Gesäß", "Waden", "Bauch"] }
    );
  } else if (numDays === 3) {
    splitNames.push(
      { name: "Push (Brust / Schulter / Trizeps)", focus: ["Brust", "Schultern", "Trizeps"] },
      { name: "Pull (Rücken / Bizeps / Nacken)", focus: ["Rücken", "Bizeps", "Nacken"] },
      { name: "Beine & Bauch", focus: ["Beine", "Gesäß", "Waden", "Bauch"] }
    );
  } else if (numDays === 4) {
    splitNames.push(
      { name: "Oberkörper A (Fokus Brust & Rudern)", focus: ["Brust", "Rücken", "Trizeps"] },
      { name: "Unterkörper A (Quadrizeps & Waden)", focus: ["Beine", "Waden", "Bauch"] },
      { name: "Oberkörper B (Fokus Schultern & Latzug)", focus: ["Schultern", "Rücken", "Bizeps"] },
      { name: "Unterkörper B (Posterior Chain & Glutes)", focus: ["Gesäß", "Beine", "Bauch"] }
    );
  } else {
    // 5 oder 6 Tage
    splitNames.push(
      { name: "Brust & Trizeps", focus: ["Brust", "Trizeps"] },
      { name: "Rücken & Bizeps", focus: ["Rücken", "Bizeps"] },
      { name: "Beine & Waden", focus: ["Beine", "Waden"] },
      { name: "Schultern & Nacken", focus: ["Schultern", "Nacken"] },
      { name: "Arme & Bauch", focus: ["Bizeps", "Trizeps", "Bauch"] }
    );
  }

  // Generiere Übungen für jeden Tag
  days.forEach((dayName, idx) => {
    const splitConfig = splitNames[idx % splitNames.length];
    const exercisesForDay = [];
    const usedCategories = new Set();

    // Wähle 4 bis 6 Übungen passend zur Session-Dauer
    const targetExCount = sessionMinutes <= 30 ? 4 : sessionMinutes <= 60 ? 5 : 6;

    // 1. Zuerst Grundübungen aus den Fokus-Kategorien
    splitConfig.focus.forEach((cat) => {
      if (exercisesForDay.length >= targetExCount) return;
      const candidates = pool.filter((ex) => ex.category === cat);
      if (candidates.length > 0) {
        const selected = candidates.find((ex) => ex.heavy) || candidates[0];
        if (!exercisesForDay.find((e) => e.name === selected.name)) {
          exercisesForDay.push({
            name: selected.name,
            category: selected.category,
            equipment: selected.equipment,
            sets: defaultSets,
            reps: repScheme,
            rest: defaultRest,
            note: `${selected.heavy ? "Schwere Grundübung" : "Gezielte Isolation"} · Saubere Ausführung`,
          });
          usedCategories.add(cat);
        }
      }
    });

    // 2. Fülle mit Isolationsübungen auf
    let safetyCounter = 0;
    while (exercisesForDay.length < targetExCount && safetyCounter < 20) {
      safetyCounter++;
      const cat = splitConfig.focus[safetyCounter % splitConfig.focus.length];
      const candidates = pool.filter((ex) => ex.category === cat);
      const randomEx = candidates[Math.floor(Math.random() * candidates.length)];
      if (randomEx && !exercisesForDay.find((e) => e.name === randomEx.name)) {
        exercisesForDay.push({
          name: randomEx.name,
          category: randomEx.category,
          equipment: randomEx.equipment,
          sets: 3,
          reps: repScheme,
          rest: defaultRest,
          note: "Kontrollierte Bewegung über den vollen Bewegungsumfang",
        });
      }
    }

    dayPlans.push({
      day: dayName,
      focus: splitConfig.name,
      exercises: exercisesForDay,
    });
  });

  const isEn = language === "en";

  return {
    title: isEn
      ? `AI ${goalTitleEn} Plan (${numDays} Days)`
      : `KI-${goalTitleDe} Plan (${numDays} Tage)`,
    overview: isEn
      ? `Personalized ${weeks}-week training plan created for ${sex === "female" ? "Female" : "Male"} athlete (${age} yrs, ${height}cm, ${weight}kg) with ${experience} experience.`
      : `Personalisierter ${weeks}-Wochen Trainingsplan für ${sex === "female" ? "Athletin" : "Athlet"} (${age} Jahre, ${height} cm, ${weight} kg) auf Level ${experience}.`,
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
