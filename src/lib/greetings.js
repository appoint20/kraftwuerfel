/*
  KRAFTWÜRFEL — Dynamic AI & Time-Aware Gym Greeting Generator
*/

const MOTIVATION_QUOTES = {
  de: {
    morning: [
      "☕ Pre-Workout kickt rein, {name} — Zeit für neue PRs!",
      "🌅 Der frühe Vogel drückt Bank, {name}! Auf geht's!",
      "🔥 Guten Morgen {name}! Ready to pump? Das Eisen wartet.",
      "⚡ Kaffee intus, Fokus an: Mach die Gewichte leicht, {name}!",
    ],
    midday: [
      "💪 Mittagspause im Gym, {name}? Der beste Snack ist der Pump!",
      "⚡ Energielevel 100%, {name} — lass die Hanteln brennen!",
      "🔥 Hey {name}, kein Mittagstief heute — nur maximale Gains!",
    ],
    afternoon: [
      "🔥 Feierabend-Pump aktiviert, {name}! Beast Mode an!",
      "🦾 {name}, heute wird nicht diskutiert — heute wird gehoben!",
      "🍕 Die Kalorien verbrennen sich nicht von alleine, {name}. Let's go!",
      "🏋️‍♂️ Auf geht's {name}! Der beste Stresskiller heißt Eisen.",
    ],
    evening: [
      "🔥 Prime-Time im Eisen-Tempel, {name}! Lass alles auf der Bank.",
      "🦾 Hey {name}, ready to pump? Schließe den Tag wie ein Champion ab!",
      "⚡ Musik laut, Fokus an, {name} — Zeit für den ultimativen Pump!",
      "💪 {name}, mach heute zu deinem stärksten Tag der Woche!",
    ],
    night: [
      "🌙 Late-Night Gains, {name}! Echte Champions trainieren, wenn andere schlafen.",
      "🦾 Nachtschicht im Gym, {name}? Maximaler Respekt — keine Ausreden!",
      "🔥 Fokus pur in der Nacht, {name}. Hol dir den Pump ab!",
    ],
  },
  en: {
    morning: [
      "☕ Pre-workout is kicking in, {name} — time for new PRs!",
      "🌅 Early morning iron session, {name}! Let's crush it!",
      "🔥 Good morning {name}! Ready to pump? The iron is calling.",
      "⚡ Coffee down, focus on: make those weights feel light, {name}!",
    ],
    midday: [
      "💪 Lunch break at the gym, {name}? The best snack is the pump!",
      "⚡ Energy at 100%, {name} — make the dumbbells burn!",
      "🔥 Hey {name}, no midday slump today — only maximum gains!",
    ],
    afternoon: [
      "🔥 Post-work pump activated, {name}! Beast Mode: ENGAGED!",
      "🦾 {name}, no talk today — just heavy lifts and big energy!",
      "🍕 Those calories won't burn themselves, {name}. Let's go!",
      "🏋️‍♂️ Let's crush it {name}! The ultimate stress relief is iron.",
    ],
    evening: [
      "🔥 Prime-time in the iron temple, {name}! Leave it all on the platform.",
      "🦾 Hey {name}, ready to pump? Finish the day like a champion!",
      "⚡ Volume up, world off, {name} — time for that legendary pump!",
      "💪 {name}, make today your strongest session of the week!",
    ],
    night: [
      "🌙 Late-night gains, {name}! Real champions work when others sleep.",
      "🦾 Midnight session, {name}? Massive respect — zero excuses!",
      "🔥 Pure late-night focus, {name}. Go get that pump!",
    ],
  },
};

export function getDynamicGymGreeting(rawName = "", lang = "de") {
  const name = rawName ? rawName.trim() : lang === "en" ? "Champ" : "Athlet";
  const hour = new Date().getHours();
  const currentLang = lang === "en" ? "en" : "de";
  const quotesObj = MOTIVATION_QUOTES[currentLang];

  let timeKey = "afternoon";
  if (hour >= 5 && hour < 10) timeKey = "morning";
  else if (hour >= 10 && hour < 14) timeKey = "midday";
  else if (hour >= 14 && hour < 18) timeKey = "afternoon";
  else if (hour >= 18 && hour < 22) timeKey = "evening";
  else timeKey = "night";

  const pool = quotesObj[timeKey] || quotesObj.evening;
  const randomIndex = Math.floor(Math.random() * pool.length);
  const selectedQuote = pool[randomIndex];

  return selectedQuote.replace("{name}", name);
}
