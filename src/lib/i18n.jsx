import { createContext, useContext, useEffect, useState } from "react";

/*
  Zweisprachig: Deutsch ist Standard, Englisch per Schalter im Header.
  Übungsnamen bleiben deutsch — sie sind Daten, keine Oberfläche. Kategorien
  und Equipment sind geschlossene Listen und werden übersetzt.
*/

const STORAGE_KEY = "kraftwuerfel:lang";

const DE = {
  "app.subtitle": "Zufallsplan & KI-Coach · v2.0",

  "tabs.generator": "GENERATOR",
  "tabs.trainingsplan": "TRAININGSPLAN",
  "tabs.saved": "GESPEICHERT",
  "tabs.favorites": "FAVORITEN",
  "tabs.ai": "KI-COACH",

  "nav.getPro": "PRO HOLEN",
  "nav.signOut": "Abmelden",

  "mode.dice": "Würfeln",
  "mode.ai": "KI-Coach",
  "mode.aiBadge": "PRO",

  "gen.split": "Split wählen",
  "gen.muscles": "Muskelgruppen",
  "gen.count": "Anzahl Übungen",
  "gen.method": "Trainingsmethode",
  "gen.rest": "Pause pro Satz",
  "gen.roll": "WÜRFELN",
  "gen.remix": "Ganzen Plan neu mischen",
  "gen.rerollOne": "Neu würfeln",
  "gen.sets": "Sätze",
  "gen.reps": "Wdh.",
  "gen.restShort": "Pause",
  "gen.namePlaceholder": "Name, z. B. Aktueller Plan",
  "gen.save": "Speichern",
  "gen.empty": "Noch kein Plan gewürfelt.",
  "gen.emptyHint": "Split wählen und auf „WÜRFELN“ tippen.",
  "gen.savedAs": "„{name}“ gespeichert!",
  "gen.defaultName": "Plan vom {date}",

  "ai.title": "Dein Plan, von der KI gebaut",
  "ai.intro": "Ein paar Fragen — daraus baut der KI-Coach einen Trainingsplan, der zu dir passt.",
  "ai.goal": "Ziel",
  "ai.goal.muscle": "Muskelaufbau",
  "ai.goal.strength": "Maximalkraft",
  "ai.goal.definition": "Definition",
  "ai.goal.fitness": "Allgemeine Fitness",
  "ai.experience": "Erfahrung",
  "ai.experience.beginner": "Anfänger",
  "ai.experience.intermediate": "Fortgeschritten",
  "ai.experience.advanced": "Sehr erfahren",
  "ai.days": "Trainingstage",
  "ai.duration": "Dauer pro Einheit",
  "ai.minutes": "{n} Min",
  "ai.equipment": "Verfügbares Equipment",
  "ai.equipmentAll": "Alles",
  "ai.focus": "Schwerpunkt (optional)",
  "ai.limitations": "Einschränkungen (optional)",
  "ai.limitationsPlaceholder": "z. B. Knieprobleme, kein Überkopfdrücken, Bandscheibenvorfall …",
  "ai.weeks": "Planlänge",
  "ai.weeksValue": "{n} Wochen",
  "ai.submit": "KI-PLAN ERSTELLEN",
  "ai.loading": "Der Coach schreibt deinen Plan …",
  "ai.loadingHint": "Das dauert etwa 10–20 Sekunden.",
  "ai.error": "Der Plan konnte nicht erstellt werden: {message}",
  "ai.retry": "Nochmal versuchen",
  "ai.resultTitle": "Dein Trainingsplan",
  "ai.regenerate": "Neuen Plan erstellen",
  "ai.start": "Als Trainingsplan starten",
  "ai.started": "Trainingsplan gestartet!",
  "ai.pickDaysFirst": "Wähle mindestens einen Trainingstag.",
  "ai.notes": "Hinweise vom Coach",
  "ai.dayFocus": "Fokus",
  "ai.limitReached": "Tageslimit erreicht — morgen geht es weiter.",
  "ai.noBackend": "Der KI-Coach braucht das Supabase-Backend. Lokal ist er nicht erreichbar.",

  "tp.pickDays": "Trainingstage wählen",
  "tp.duration": "Dauer",
  "tp.weeksShort": "{n} W",
  "tp.settingsFromGenerator": "Einstellungen (aus Generator)",
  "tp.summary": "Split: {split} · {count} Übungen · {method} · {rest}s Pause",
  "tp.countHint": "{days} Tage × {cycles} Zyklen =",
  "tp.countHintStrong": "{n} unterschiedliche Pläne",
  "tp.rollPlans": "PLÄNE WÜRFELN",
  "tp.rollAgain": "Neu würfeln",
  "tp.start": "Trainingsplan starten",
  "tp.started": "Trainingsplan gestartet!",
  "tp.tapDay": "Tag antippen für alle {cycles}Pläne",
  "tp.week": "WOCHE",
  "tp.cycle": "Zyklus {n} / {total}",
  "tp.isTrainingDay": "Heute ist Trainingstag",
  "tp.noTrainingDay": "Heute kein Trainingstag",
  "tp.daysLeft": "noch {n} Tage bis Planende",
  "tp.end": "Plan beenden",
  "tp.finished": "🎉 Trainingsplan abgeschlossen!",
  "tp.finishedHint": "{n} Wochen geschafft. Zeit für einen neuen Plan.",
  "tp.newPlan": "Neuen Plan erstellen",
  "tp.today": "heute",
  "tp.daysAgo": "vor {n} Tg.",
  "tp.inDays": "in {n} Tg.",
  "tp.cycleLabel": "Zyklus {n}",
  "tp.current": "aktuell",
  "tp.plansCount": "{n} Pläne",
  "tp.planCount": "{n} Plan",
  "tp.favorite": "Als Favorit speichern",

  "saved.title": "Meine gespeicherten Pläne",
  "saved.empty": "Noch keine Pläne gespeichert.",
  "saved.emptyHint": "Erstelle im Generator einen Plan und tippe auf „Speichern“.",
  "saved.exercises": "{n} Übungen",
  "saved.load": "Laden",
  "saved.delete": "Löschen",

  "fav.title": "Favorisierte Tagespläne",
  "fav.empty": "Noch keine Favoriten.",
  "fav.emptyHint": "Tippe im Trainingsplan-Tab auf das ❤️ neben einem Tag.",
  "fav.remove": "Entfernen",
  "fav.added": "„{day}“ zu Favoriten hinzugefügt!",

  "pro.badge": "PRO",
  "pro.gateText": "{feature} gehört zu Kraftwürfel Pro. Würfeln bleibt für alle kostenlos.",
  "pro.cta": "Pro holen",
  "pro.notUnlocked": "Dein Konto ist noch nicht freigeschaltet.",
  "pro.feature.save": "Pläne speichern",
  "pro.feature.start": "Einen Trainingsplan starten",
  "pro.feature.favorites": "Tagespläne favorisieren",
  "pro.feature.ai": "Der KI-Coach",

  "proScreen.back": "Zurück zum Würfeln",
  "proScreen.headline": "KRAFTWÜRFEL PRO",
  "proScreen.pitch": "Würfeln bleibt kostenlos. Pro schaltet den KI-Coach und alles Gespeicherte frei.",
  "proScreen.benefit.ai": "KI-Coach: Plan nach Ziel, Erfahrung, Equipment und Einschränkungen",
  "proScreen.benefit.save": "Pläne speichern und jederzeit wieder laden",
  "proScreen.benefit.plans": "Mehrwochen-Trainingspläne mit Fortschritt",
  "proScreen.benefit.sync": "Auf allen Geräten synchron",
  "proScreen.signIn": "ANMELDEN",
  "proScreen.signUp": "KONTO ERSTELLEN",
  "proScreen.email": "E-Mail",
  "proScreen.password": "Passwort",
  "proScreen.submitSignIn": "LOS GEHT'S",
  "proScreen.submitSignUp": "REGISTRIEREN",
  "proScreen.toSignUp": "Noch kein Konto? Registrieren",
  "proScreen.toSignIn": "Schon ein Konto? Anmelden",
  "proScreen.confirmMail": "Bestätigungs-E-Mail verschickt. Link anklicken, dann anmelden.",

  "common.loading": "Lädt…",
  "common.search": "Übung suchen…",

  "crash.title": "DA IST WAS SCHIEFGELAUFEN",
  "crash.text": "Die App ist auf einen unerwarteten Fehler gestoßen. Neu laden hilft meistens — gespeicherte Pläne bleiben erhalten.",
  "crash.reload": "NEU LADEN",

  "local.title": "Lokaler Modus:",
  "local.text": "Ohne Supabase-Zugangsdaten bleiben Pläne nur in diesem Browser und der KI-Coach ist nicht erreichbar.",
};

const EN = {
  "app.subtitle": "Random rolls & AI coach · v2.0",

  "tabs.generator": "GENERATOR",
  "tabs.trainingsplan": "TRAINING PLAN",
  "tabs.saved": "SAVED",
  "tabs.favorites": "FAVOURITES",
  "tabs.ai": "AI COACH",

  "nav.getPro": "GET PRO",
  "nav.signOut": "Sign out",

  "mode.dice": "Roll",
  "mode.ai": "AI coach",
  "mode.aiBadge": "PRO",

  "gen.split": "Choose split",
  "gen.muscles": "Muscle groups",
  "gen.count": "Number of exercises",
  "gen.method": "Training method",
  "gen.rest": "Rest per set",
  "gen.roll": "ROLL",
  "gen.remix": "Reshuffle the whole plan",
  "gen.rerollOne": "Roll again",
  "gen.sets": "Sets",
  "gen.reps": "Reps",
  "gen.restShort": "Rest",
  "gen.namePlaceholder": "Name, e.g. Current plan",
  "gen.save": "Save",
  "gen.empty": "No plan rolled yet.",
  "gen.emptyHint": "Pick a split and tap “ROLL”.",
  "gen.savedAs": "“{name}” saved!",
  "gen.defaultName": "Plan from {date}",

  "ai.title": "Your plan, built by AI",
  "ai.intro": "A few questions — the AI coach turns them into a training plan that fits you.",
  "ai.goal": "Goal",
  "ai.goal.muscle": "Build muscle",
  "ai.goal.strength": "Maximal strength",
  "ai.goal.definition": "Get lean",
  "ai.goal.fitness": "General fitness",
  "ai.experience": "Experience",
  "ai.experience.beginner": "Beginner",
  "ai.experience.intermediate": "Intermediate",
  "ai.experience.advanced": "Advanced",
  "ai.days": "Training days",
  "ai.duration": "Session length",
  "ai.minutes": "{n} min",
  "ai.equipment": "Available equipment",
  "ai.equipmentAll": "Everything",
  "ai.focus": "Focus (optional)",
  "ai.limitations": "Limitations (optional)",
  "ai.limitationsPlaceholder": "e.g. knee issues, no overhead pressing, disc injury …",
  "ai.weeks": "Plan length",
  "ai.weeksValue": "{n} weeks",
  "ai.submit": "CREATE AI PLAN",
  "ai.loading": "The coach is writing your plan …",
  "ai.loadingHint": "This takes about 10–20 seconds.",
  "ai.error": "The plan could not be created: {message}",
  "ai.retry": "Try again",
  "ai.resultTitle": "Your training plan",
  "ai.regenerate": "Create a new plan",
  "ai.start": "Start as training plan",
  "ai.started": "Training plan started!",
  "ai.pickDaysFirst": "Pick at least one training day.",
  "ai.notes": "Notes from the coach",
  "ai.dayFocus": "Focus",
  "ai.limitReached": "Daily limit reached — try again tomorrow.",
  "ai.noBackend": "The AI coach needs the Supabase backend. It is unreachable in local mode.",

  "tp.pickDays": "Choose training days",
  "tp.duration": "Length",
  "tp.weeksShort": "{n} w",
  "tp.settingsFromGenerator": "Settings (from the generator)",
  "tp.summary": "Split: {split} · {count} exercises · {method} · {rest}s rest",
  "tp.countHint": "{days} days × {cycles} cycles =",
  "tp.countHintStrong": "{n} distinct plans",
  "tp.rollPlans": "ROLL PLANS",
  "tp.rollAgain": "Roll again",
  "tp.start": "Start training plan",
  "tp.started": "Training plan started!",
  "tp.tapDay": "Tap a day for all {cycles}plans",
  "tp.week": "WEEK",
  "tp.cycle": "Cycle {n} / {total}",
  "tp.isTrainingDay": "Today is a training day",
  "tp.noTrainingDay": "No training today",
  "tp.daysLeft": "{n} days left",
  "tp.end": "End plan",
  "tp.finished": "🎉 Training plan complete!",
  "tp.finishedHint": "{n} weeks done. Time for a new plan.",
  "tp.newPlan": "Create a new plan",
  "tp.today": "today",
  "tp.daysAgo": "{n} d ago",
  "tp.inDays": "in {n} d",
  "tp.cycleLabel": "Cycle {n}",
  "tp.current": "current",
  "tp.plansCount": "{n} plans",
  "tp.planCount": "{n} plan",
  "tp.favorite": "Save as favourite",

  "saved.title": "My saved plans",
  "saved.empty": "No plans saved yet.",
  "saved.emptyHint": "Build a plan in the generator and tap “Save”.",
  "saved.exercises": "{n} exercises",
  "saved.load": "Load",
  "saved.delete": "Delete",

  "fav.title": "Favourite day plans",
  "fav.empty": "No favourites yet.",
  "fav.emptyHint": "Tap the ❤️ next to a day in the training plan tab.",
  "fav.remove": "Remove",
  "fav.added": "“{day}” added to favourites!",

  "pro.badge": "PRO",
  "pro.gateText": "{feature} is part of Kraftwürfel Pro. Rolling stays free for everyone.",
  "pro.cta": "Get Pro",
  "pro.notUnlocked": "Your account is not unlocked yet.",
  "pro.feature.save": "Saving plans",
  "pro.feature.start": "Starting a training plan",
  "pro.feature.favorites": "Favouriting day plans",
  "pro.feature.ai": "The AI coach",

  "proScreen.back": "Back to rolling",
  "proScreen.headline": "KRAFTWÜRFEL PRO",
  "proScreen.pitch": "Rolling stays free. Pro unlocks the AI coach and everything you save.",
  "proScreen.benefit.ai": "AI coach: a plan built around your goal, experience, equipment and limitations",
  "proScreen.benefit.save": "Save plans and load them back any time",
  "proScreen.benefit.plans": "Multi-week training plans with progress tracking",
  "proScreen.benefit.sync": "In sync across all your devices",
  "proScreen.signIn": "SIGN IN",
  "proScreen.signUp": "CREATE ACCOUNT",
  "proScreen.email": "Email",
  "proScreen.password": "Password",
  "proScreen.submitSignIn": "LET'S GO",
  "proScreen.submitSignUp": "SIGN UP",
  "proScreen.toSignUp": "No account yet? Sign up",
  "proScreen.toSignIn": "Already have an account? Sign in",
  "proScreen.confirmMail": "Confirmation email sent. Click the link, then sign in.",

  "common.loading": "Loading…",
  "common.search": "Search exercise…",

  "crash.title": "SOMETHING WENT WRONG",
  "crash.text": "The app hit an unexpected error. Reloading usually helps — saved plans are safe.",
  "crash.reload": "RELOAD",

  "local.title": "Local mode:",
  "local.text": "Without Supabase credentials plans stay in this browser only, and the AI coach is unreachable.",
};

// Kategorien und Equipment sind geschlossene Listen und Teil der Oberfläche.
const CATEGORY_EN = {
  Brust: "Chest",
  Rücken: "Back",
  Nacken: "Neck",
  Schultern: "Shoulders",
  Bizeps: "Biceps",
  Trizeps: "Triceps",
  Beine: "Legs",
  Gesäß: "Glutes",
  Waden: "Calves",
  Bauch: "Core",
  Ganzkörper: "Full body",
};

const EQUIPMENT_EN = {
  Langhantel: "Barbell",
  Kurzhantel: "Dumbbell",
  Maschine: "Machine",
  Kabelzug: "Cable",
  Körpergewicht: "Bodyweight",
  Multipresse: "Smith machine",
  Kettlebell: "Kettlebell",
  Gewichtsscheibe: "Weight plate",
};

const SPLIT_EN = {
  Ganzkörper: "Full body",
  Oberkörper: "Upper body",
  Unterkörper: "Lower body",
  Push: "Push",
  Pull: "Pull",
  Beine: "Legs",
  Bauch: "Core",
  Frauen: "Women",
  Eigene: "Custom",
};

const WEEKDAY_EN = { Mo: "Mon", Di: "Tue", Mi: "Wed", Do: "Thu", Fr: "Fri", Sa: "Sat", So: "Sun" };

const DICTS = { de: DE, en: EN };

const I18nContext = createContext(null);

function interpolate(template, vars) {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (match, key) => (key in vars ? String(vars[key]) : match));
}

export function I18nProvider({ children }) {
  const [lang, setLangState] = useState(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored === "en" || stored === "de" ? stored : "de";
  });

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, lang);
    document.documentElement.lang = lang;
  }, [lang]);

  const value = {
    lang,
    setLang: setLangState,
    t: (key, vars) => interpolate(DICTS[lang][key] ?? key, vars),
    category: (name) => (lang === "en" ? CATEGORY_EN[name] || name : name),
    equipment: (name) => (lang === "en" ? EQUIPMENT_EN[name] || name : name),
    split: (name) => (lang === "en" ? SPLIT_EN[name] || name : name),
    weekday: (name) => (lang === "en" ? WEEKDAY_EN[name] || name : name),
    locale: lang === "en" ? "en-GB" : "de-DE",
  };

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n muss innerhalb von I18nProvider verwendet werden");
  return ctx;
}
