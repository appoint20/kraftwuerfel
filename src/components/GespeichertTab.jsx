import { Shuffle, X } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import PremiumGate from "./PremiumGate.jsx";

export default function GespeichertTab({ saved, onLoad, onGetPro }) {
  const { isPremium } = useAuth();
  const { t, locale } = useI18n();
  const { plans, loading, remove } = saved;

  if (!isPremium && plans.length === 0) {
    return (
      <>
        <div className="section-label">{t("saved.title")}</div>
        <PremiumGate feature={t("pro.feature.save")} onGetPro={onGetPro} />
      </>
    );
  }

  return (
    <>
      <div className="section-label">{t("saved.title")}</div>
      {loading ? (
        <div className="empty">{t("common.loading")}</div>
      ) : plans.length === 0 ? (
        <div className="empty">
          {t("saved.empty")}
          <br />
          {t("saved.emptyHint")}
        </div>
      ) : (
        plans.map((sp) => (
          <div className="saved-card" key={sp.id}>
            <div className="saved-card-top">
              <div>
                <div className="saved-name">{sp.name}</div>
                <div className="saved-meta">
                  {t("saved.exercises", { n: sp.items.length })} ·{" "}
                  {METHODS.find((m) => m.id === sp.method)?.label || "Standard"} ·{" "}
                  {new Date(sp.savedAt).toLocaleDateString(locale)}
                </div>
              </div>
            </div>
            <div className="saved-actions">
              <button className="load" onClick={() => onLoad(sp)}>
                <Shuffle size={13} /> {t("saved.load")}
              </button>
              <button className="delete" onClick={() => remove(sp.id)}>
                <X size={13} /> {t("saved.delete")}
              </button>
            </div>
          </div>
        ))
      )}
    </>
  );
}
