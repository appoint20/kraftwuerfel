import { useCallback, useState } from "react";
import { repository } from "../lib/repository.js";
import { serializeSlots } from "../lib/planLogic.js";
import { useI18n } from "../lib/i18n.jsx";

export default function useSavedPlans() {
  const { t } = useI18n();
  const [plans, setPlans] = useState([]);
  const [nutritionPlans, setNutritionPlans] = useState([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("");

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const [p, n] = await Promise.all([
        repository.listPlans(),
        repository.listNutrition ? repository.listNutrition() : [],
      ]);
      setPlans(p);
      setNutritionPlans(n);
    } catch {
      setPlans([]);
      setNutritionPlans([]);
    } finally {
      setLoading(false);
    }
  }, []);

  const save = useCallback(
    async (name, method, slots) => {
      try {
        const created = await repository.createPlan({ name, method, items: serializeSlots(slots) });
        setPlans((prev) => [created, ...prev]);
        setStatus(t("gen.savedAs", { name }));
        setTimeout(() => setStatus(""), 2500);
        return true;
      } catch (e) {
        setStatus(e?.message || "Fehler");
        return false;
      }
    },
    [t]
  );

  const saveNutrition = useCallback(
    async (nutritionData, planTitle = "Ernährungsplan") => {
      try {
        if (!repository.saveNutrition) return false;
        const created = await repository.saveNutrition({
          title: planTitle,
          ...nutritionData,
        });
        setNutritionPlans((prev) => [created, ...prev]);
        setStatus(t("ai.mealPlanSaved"));
        setTimeout(() => setStatus(""), 2500);
        return true;
      } catch (e) {
        setStatus(e?.message || "Fehler");
        return false;
      }
    },
    [t]
  );

  const remove = useCallback(async (id) => {
    try {
      await repository.deletePlan(id);
      setPlans((prev) => prev.filter((p) => p.id !== id));
    } catch (e) {
      setStatus(e?.message || "Fehler");
    }
  }, []);

  const removeNutrition = useCallback(async (id) => {
    try {
      if (repository.deleteNutrition) {
        await repository.deleteNutrition(id);
        setNutritionPlans((prev) => prev.filter((n) => n.id !== id));
      }
    } catch (e) {
      setStatus(e?.message || "Fehler");
    }
  }, []);

  return { plans, nutritionPlans, loading, status, reload, save, saveNutrition, remove, removeNutrition };
}
