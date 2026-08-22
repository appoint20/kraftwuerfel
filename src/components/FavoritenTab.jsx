import { X } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { deserializeSlots } from "../lib/planLogic.js";
import { rotateWeekdaysFromToday, todayWeekday } from "../lib/dateUtils.js";
import { planNameFor } from "../lib/planNames.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import CycleBlock from "./CycleBlock.jsx";
import PremiumGate from "./PremiumGate.jsx";

export default function FavoritenTab({ favorites: fav, onGetPro }) {
  const { isPremium } = useAuth();
  const { t, locale, weekday } = useI18n();
  const { favorites, loading, remove } = fav;

  /*
    Der Plan von heute steht oben — das ist der, den man im Gym aufschlägt.
    Danach geht es in Wochentagsreihenfolge weiter, beginnend beim heutigen Tag.
    Gibt es für heute keinen Favoriten, fängt die Liste beim nächsten an.
  */
  const order = rotateWeekdaysFromToday();
  const heute = todayWeekday();
  const sorted = [...favorites].sort((a, b) => {
    const ai = order.indexOf(a.day);
    const bi = order.indexOf(b.day);
    if (ai !== bi) return ai - bi;
    return (b.favoritedAt || "").localeCompare(a.favoritedAt || "");
  });

  if (!isPremium && favorites.length === 0) {
    return (
      <>
        <div className="section-label">{t("fav.title")}</div>
        <PremiumGate feature={t("pro.feature.favorites")} onGetPro={onGetPro} />
      </>
    );
  }

  return (
    <>
      <div className="section-label">{t("fav.title")}</div>
      {loading ? (
        <div className="empty">{t("common.loading")}</div>
      ) : favorites.length === 0 ? (
        <div className="empty">
          {t("fav.empty")}
          <br />
          {t("fav.emptyHint")}
        </div>
      ) : (
        sorted.map((f) => (
          <div className={`saved-card ${f.day === heute ? "is-today" : ""}`} key={f.id}>
            <div className="saved-card-top">
              <div>
                <div className="saved-name">
                  {weekday(f.day)}
                  <span className="plan-name-badge">{planNameFor(`${f.day}:${f.split || ""}`)}</span>
                  {f.day === heute && <span className="today-badge">{t("fav.today")}</span>}
                </div>
                <div className="saved-meta">
                  {t(f.cycles.length === 1 ? "tp.planCount" : "tp.plansCount", { n: f.cycles.length })} ·{" "}
                  {METHODS.find((m) => m.id === f.method)?.label || "Standard"} ·{" "}
                  {new Date(f.favoritedAt).toLocaleDateString(locale)}
                </div>
              </div>
            </div>
            <div className="tp-day-cycles no-pad">
              {f.cycles.map((items, idx) => (
                <CycleBlock
                  key={`${f.id}-${idx}`}
                  label={t("tp.cycleLabel", { n: idx + 1 })}
                  slots={deserializeSlots(items)}
                  isCurrent={false}
                />
              ))}
            </div>
            <div className="saved-actions">
              <button className="delete" onClick={() => remove(f.id)}>
                <X size={13} /> {t("fav.remove")}
              </button>
            </div>
          </div>
        ))
      )}
    </>
  );
}
