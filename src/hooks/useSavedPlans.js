import { useCallback, useState } from "react";
import { repository } from "../lib/repository.js";
import { serializeSlots } from "../lib/planLogic.js";
import { useI18n } from "../lib/i18n.jsx";

export default function useSavedPlans() {
  const { t } = useI18n();
  const [plans, setPlans] = useState([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("");

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      setPlans(await repository.listPlans());
    } catch {
      setPlans([]);
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

  const remove = useCallback(async (id) => {
    try {
      await repository.deletePlan(id);
      setPlans((prev) => prev.filter((p) => p.id !== id));
    } catch (e) {
      setStatus(e?.message || "Fehler");
    }
  }, []);

  return { plans, loading, status, reload, save, remove };
}
