import { useCallback, useState } from "react";
import { repository } from "../lib/repository.js";
import { useI18n } from "../lib/i18n.jsx";

export default function useActivePlan() {
  const { t } = useI18n();
  const [activePlan, setActivePlan] = useState(null);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("");

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const loaded = await repository.getActivePlan();
      setActivePlan(loaded);
      return loaded;
    } catch {
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const start = useCallback(
    async (plan) => {
      try {
        await repository.setActivePlan(plan);
        setActivePlan(plan);
        setStatus(t("tp.started"));
        setTimeout(() => setStatus(""), 2500);
        return true;
      } catch (e) {
        setStatus(e?.message || "Fehler");
        return false;
      }
    },
    [t]
  );

  const end = useCallback(async () => {
    try {
      await repository.clearActivePlan();
    } catch (e) {
      setStatus(e?.message || "Fehler");
    }
    setActivePlan(null);
  }, []);

  return { activePlan, loading, status, reload, start, end };
}
