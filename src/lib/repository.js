import { supabase, isSupabaseConfigured } from "./supabase.js";

/*
  Ein Repository, zwei Implementierungen:
  - supabaseRepo: Postgres über Supabase, pro Nutzer via RLS getrennt
  - localRepo:    localStorage, wenn keine Supabase-Zugangsdaten gesetzt sind

  Beide liefern dieselben Formen zurück:
    Plan       { id, name, savedAt, method, items }
    ActivePlan { startDate, duration, days, split, method, count, restTime, dayPlans }
    Favorite   { id, day, favoritedAt, split, method, cycles }
*/

// Schreibvorgänge einmal wiederholen — ein kurzer Netzaussetzer soll keinen Plan verlieren.
async function withRetry(fn) {
  try {
    return await fn();
  } catch (err) {
    await new Promise((r) => setTimeout(r, 400));
    return fn();
  }
}

function unwrap({ data, error }) {
  if (error) throw new Error(error.message);
  return data;
}

const supabaseRepo = {
  async listPlans() {
    const rows = unwrap(
      await supabase.from("plans").select("*").order("saved_at", { ascending: false })
    );
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      savedAt: r.saved_at,
      method: r.method,
      items: r.items,
    }));
  },

  async createPlan({ name, method, items }) {
    return withRetry(async () => {
      const { data: userData } = await supabase.auth.getUser();
      const row = unwrap(
        await supabase
          .from("plans")
          .insert({ user_id: userData.user.id, name, method, items })
          .select()
          .single()
      );
      return { id: row.id, name: row.name, savedAt: row.saved_at, method: row.method, items: row.items };
    });
  },

  async deletePlan(id) {
    unwrap(await supabase.from("plans").delete().eq("id", id));
  },

  async getActivePlan() {
    const row = unwrap(await supabase.from("active_plans").select("*").maybeSingle());
    if (!row) return null;
    return {
      startDate: row.start_date,
      duration: row.duration,
      days: row.days,
      split: row.split,
      method: row.method,
      count: row.exercise_count,
      restTime: row.rest_time,
      dayPlans: row.day_plans,
    };
  },

  async setActivePlan(plan) {
    return withRetry(async () => {
      const { data: userData } = await supabase.auth.getUser();
      unwrap(
        await supabase.from("active_plans").upsert({
          user_id: userData.user.id,
          start_date: plan.startDate,
          duration: plan.duration,
          days: plan.days,
          split: plan.split,
          method: plan.method,
          exercise_count: plan.count,
          rest_time: plan.restTime,
          day_plans: plan.dayPlans,
          updated_at: new Date().toISOString(),
        })
      );
      return plan;
    });
  },

  async clearActivePlan() {
    const { data: userData } = await supabase.auth.getUser();
    unwrap(await supabase.from("active_plans").delete().eq("user_id", userData.user.id));
  },

  async listFavorites() {
    const rows = unwrap(
      await supabase.from("favorites").select("*").order("favorited_at", { ascending: false })
    );
    return rows.map((r) => ({
      id: r.id,
      day: r.day,
      favoritedAt: r.favorited_at,
      split: r.split,
      method: r.method,
      cycles: r.cycles,
    }));
  },

  async createFavorite({ day, split, method, cycles }) {
    return withRetry(async () => {
      const { data: userData } = await supabase.auth.getUser();
      const row = unwrap(
        await supabase
          .from("favorites")
          .insert({ user_id: userData.user.id, day, split, method, cycles })
          .select()
          .single()
      );
      return {
        id: row.id,
        day: row.day,
        favoritedAt: row.favorited_at,
        split: row.split,
        method: row.method,
        cycles: row.cycles,
      };
    });
  },

  async deleteFavorite(id) {
    unwrap(await supabase.from("favorites").delete().eq("id", id));
  },
};

const LS_PLANS = "kraftwuerfel:plans";
const LS_ACTIVE = "kraftwuerfel:active-plan";
const LS_FAVS = "kraftwuerfel:favorites";

const readList = (key) => {
  try {
    return JSON.parse(localStorage.getItem(key)) || [];
  } catch {
    return [];
  }
};
const writeList = (key, list) => localStorage.setItem(key, JSON.stringify(list));
const newId = () => `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const localRepo = {
  async listPlans() {
    return readList(LS_PLANS).sort((a, b) => (b.savedAt || "").localeCompare(a.savedAt || ""));
  },
  async createPlan({ name, method, items }) {
    const plan = { id: newId(), name, method, items, savedAt: new Date().toISOString() };
    writeList(LS_PLANS, [plan, ...readList(LS_PLANS)]);
    return plan;
  },
  async deletePlan(id) {
    writeList(
      LS_PLANS,
      readList(LS_PLANS).filter((p) => p.id !== id)
    );
  },
  async getActivePlan() {
    try {
      return JSON.parse(localStorage.getItem(LS_ACTIVE));
    } catch {
      return null;
    }
  },
  async setActivePlan(plan) {
    localStorage.setItem(LS_ACTIVE, JSON.stringify(plan));
    return plan;
  },
  async clearActivePlan() {
    localStorage.removeItem(LS_ACTIVE);
  },
  async listFavorites() {
    return readList(LS_FAVS).sort((a, b) => (b.favoritedAt || "").localeCompare(a.favoritedAt || ""));
  },
  async createFavorite({ day, split, method, cycles }) {
    const fav = { id: newId(), day, split, method, cycles, favoritedAt: new Date().toISOString() };
    writeList(LS_FAVS, [fav, ...readList(LS_FAVS)]);
    return fav;
  },
  async deleteFavorite(id) {
    writeList(
      LS_FAVS,
      readList(LS_FAVS).filter((f) => f.id !== id)
    );
  },
  async listNutrition() {
    return readList("kraftwuerfel:saved-nutrition").sort((a, b) => (b.savedAt || "").localeCompare(a.savedAt || ""));
  },
  async saveNutrition(plan) {
    const entry = {
      id: newId(),
      ...plan,
      savedAt: new Date().toISOString(),
    };
    writeList("kraftwuerfel:saved-nutrition", [entry, ...readList("kraftwuerfel:saved-nutrition")]);
    return entry;
  },
  async deleteNutrition(id) {
    writeList(
      "kraftwuerfel:saved-nutrition",
      readList("kraftwuerfel:saved-nutrition").filter((n) => n.id !== id)
    );
  },
};

export const repository = isSupabaseConfigured
  ? {
      ...supabaseRepo,
      listNutrition: localRepo.listNutrition,
      saveNutrition: localRepo.saveNutrition,
      deleteNutrition: localRepo.deleteNutrition,
    }
  : localRepo;
export const isLocalMode = !isSupabaseConfigured;
