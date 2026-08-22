import { useCallback, useState } from "react";
import { repository } from "../lib/repository.js";
import { serializeSlots } from "../lib/planLogic.js";
import { useI18n } from "../lib/i18n.jsx";

export default function useFavorites() {
  const { t, weekday } = useI18n();
  const [favorites, setFavorites] = useState([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState("");
  const [justSaved, setJustSaved] = useState(new Set());

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      setFavorites(await repository.listFavorites());
    } catch {
      setFavorites([]);
    } finally {
      setLoading(false);
    }
  }, []);

  const add = useCallback(
    async (day, cyclePlans, split, method) => {
      try {
        const created = await repository.createFavorite({
          day,
          split,
          method,
          cycles: cyclePlans.map(serializeSlots),
        });
        setFavorites((prev) => [created, ...prev]);
        setJustSaved((prev) => new Set(prev).add(day));
        setStatus(t("fav.added", { day: weekday(day) }));
        setTimeout(() => {
          setJustSaved((prev) => {
            const n = new Set(prev);
            n.delete(day);
            return n;
          });
        }, 1500);
        setTimeout(() => setStatus(""), 2500);
      } catch (e) {
        setStatus(e?.message || "Fehler");
      }
    },
    [t, weekday]
  );

  const remove = useCallback(async (id) => {
    try {
      await repository.deleteFavorite(id);
      setFavorites((prev) => prev.filter((f) => f.id !== id));
    } catch (e) {
      setStatus(e?.message || "Fehler");
    }
  }, []);

  return { favorites, loading, status, justSaved, reload, add, remove };
}
