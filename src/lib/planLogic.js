import {
  EXERCISES,
  DEFAULT_REPS,
  FOCUS_CATEGORY_BY_METHOD,
  FOCUS_MIN_COUNT,
} from "../data/exercises.js";

export function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

export function randOf(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export function applySetScheme(exercises, method, restTime) {
  const sets = exercises.map(() => 3);

  if (method === "543" || method === "443") {
    const heavyIdx = exercises.map((e, i) => (e.heavy ? i : -1)).filter((i) => i !== -1);
    const pool = shuffle(heavyIdx.length ? heavyIdx : exercises.map((_, i) => i));

    if (method === "543") {
      const fiveIdx = pool[0];
      if (fiveIdx !== undefined) sets[fiveIdx] = 5;
      let fourIdx = pool[1];
      if (fourIdx === undefined) {
        const rest = shuffle(exercises.map((_, i) => i).filter((i) => i !== fiveIdx));
        fourIdx = rest[0];
      }
      if (fourIdx !== undefined) sets[fourIdx] = 4;
    } else {
      const chosen = pool.slice(0, 2);
      if (chosen.length < 2) {
        const rest = shuffle(exercises.map((_, i) => i).filter((i) => !chosen.includes(i)));
        while (chosen.length < 2 && rest.length) chosen.push(rest.shift());
      }
      chosen.forEach((i) => (sets[i] = 4));
    }
  }

  return exercises.map((e, i) => ({ exercise: e, sets: sets[i], reps: DEFAULT_REPS, rest: restTime }));
}

export function buildPlan(categoriesIn, countIn, method = "standard", restTime = 60, extraExclude = new Set()) {
  const focusCat = FOCUS_CATEGORY_BY_METHOD[method];
  const categories = focusCat && !categoriesIn.includes(focusCat) ? [focusCat, ...categoriesIn] : categoriesIn;
  const count = focusCat ? Math.max(countIn, FOCUS_MIN_COUNT) : countIn;

  const attempt = (excludeSet) => {
    const byCat = {};
    categories.forEach((c) => {
      byCat[c] = shuffle(EXERCISES.filter((e) => e.categories.includes(c)));
    });
    const usedNames = new Set(excludeSet);
    const result = [];
    let ci = 0;
    let safety = 0;
    const stillHasUnused = () =>
      categories.some((c) => {
        const arr = byCat[c];
        while (arr.length && usedNames.has(arr[0].name)) arr.shift();
        return arr.length > 0;
      });
    while (result.length < count && safety < count * 40) {
      const cat = categories[ci % categories.length];
      const arr = byCat[cat];
      while (arr.length && usedNames.has(arr[0].name)) arr.shift();
      if (arr.length) {
        const ex = arr.shift();
        usedNames.add(ex.name);
        result.push(ex);
      }
      ci++;
      safety++;
      if (!stillHasUnused()) break;
    }
    return result;
  };

  let result = attempt(extraExclude);
  if (result.length < count) {
    // Nicht genug Übungen ohne Überschneidung übrig -> mit bereits Gewähltem auffüllen
    const already = new Set(result.map((e) => e.name));
    const fill = attempt(already);
    fill.forEach((e) => {
      if (result.length < count && !already.has(e.name)) {
        result.push(e);
        already.add(e.name);
      }
    });
  }

  // Fokus-Methode: garantiert mind. FOCUS_MIN_COUNT Übungen aus der Fokus-Kategorie
  if (focusCat) {
    let focusInResult = result.filter((e) => e.categories.includes(focusCat)).length;
    if (focusInResult < FOCUS_MIN_COUNT) {
      const usedNames = new Set(result.map((e) => e.name));
      const morefocus = shuffle(EXERCISES.filter((e) => e.categories.includes(focusCat) && !usedNames.has(e.name)));
      let needed = FOCUS_MIN_COUNT - focusInResult;
      while (needed > 0 && morefocus.length > 0) {
        if (result.length >= count) {
          let removeIdx = -1;
          for (let i = result.length - 1; i >= 0; i--) {
            if (!result[i].categories.includes(focusCat)) {
              removeIdx = i;
              break;
            }
          }
          if (removeIdx !== -1) result.splice(removeIdx, 1);
          else break; // alles bereits Fokus-Übungen
        }
        result.push(morefocus.shift());
        needed--;
      }
    }
  }

  const setSchemeMethod = focusCat ? "standard" : method;
  return applySetScheme(result, setSchemeMethod, restTime);
}

export function rerollSlot(plan, idx, method) {
  const currentSlot = plan[idx];
  if (!currentSlot) return null;
  const cat = currentSlot.exercise.category;
  const usedNames = new Set(plan.map((p) => p.exercise.name));
  const needsHeavy = method !== "standard" && currentSlot.sets >= 4;

  const buildPool = (allowSameName) => {
    let pool = EXERCISES.filter((e) => e.categories.includes(cat) && (allowSameName || !usedNames.has(e.name)));
    if (allowSameName) pool = pool.filter((e) => e.name !== currentSlot.exercise.name);
    if (needsHeavy) {
      const heavyPool = pool.filter((e) => e.heavy);
      if (heavyPool.length) pool = heavyPool;
    }
    return pool;
  };

  let pool = buildPool(false);
  if (pool.length === 0) pool = buildPool(true);
  if (pool.length === 0) return null;

  return { exercise: randOf(pool), sets: currentSlot.sets, reps: currentSlot.reps, rest: currentSlot.rest };
}

export const cyclesForDuration = (duration) => Math.max(1, Math.round(duration / 2));

export function buildDayPlans(days, cycles, categories, count, method, restTime) {
  const result = {};
  days.forEach((day) => {
    const usedSoFar = new Set();
    const cyclePlans = [];
    for (let c = 0; c < cycles; c++) {
      const p = buildPlan(categories, count, method, restTime, usedSoFar);
      p.forEach((s) => usedSoFar.add(s.exercise.name));
      cyclePlans.push(p);
    }
    result[day] = cyclePlans;
  });
  return result;
}

export const serializeSlots = (slots) =>
  slots.map((s) => ({
    name: s.exercise.name,
    category: s.exercise.category,
    equipment: s.exercise.equipment,
    sets: s.sets,
    reps: s.reps,
    rest: s.rest,
  }));

export const deserializeSlots = (items) =>
  items.map((it) => {
    const match = EXERCISES.find((e) => e.name === it.name) || {
      id: `custom-${it.name}`,
      name: it.name,
      category: it.category,
      categories: [it.category],
      equipment: it.equipment,
    };
    return { exercise: match, sets: it.sets, reps: it.reps, rest: it.rest };
  });

export const serializeDayPlans = (dp) =>
  Object.fromEntries(Object.keys(dp).map((day) => [day, dp[day].map(serializeSlots)]));

export const deserializeDayPlans = (dp) =>
  Object.fromEntries(Object.keys(dp).map((day) => [day, dp[day].map(deserializeSlots)]));
