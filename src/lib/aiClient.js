import { supabase, isSupabaseConfigured } from "./supabase.js";

/*
  Ruft die Edge Function auf. Der OpenRouter-Schlüssel liegt dort, nie hier —
  und ob jemand Pro hat, entscheidet ebenfalls die Function.
*/
export async function generateAiPlan(answers) {
  if (!isSupabaseConfigured) {
    throw new Error("no-backend");
  }

  const { data, error } = await supabase.functions.invoke("generate-plan", { body: answers });

  if (error) {
    // invoke() verpackt HTTP-Fehler — die eigentliche Meldung steckt im Body.
    let detail = error.message;
    try {
      const body = await error.context?.json?.();
      if (body?.error) detail = body.error;
    } catch {
      // Body war kein JSON — dann bleibt es bei error.message
    }
    throw new Error(detail);
  }

  if (!data?.plan) throw new Error("empty response");
  return data.plan;
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
    sets: ex.sets,
    reps: ex.reps,
    rest: ex.rest,
    note: ex.note,
  }));
}
