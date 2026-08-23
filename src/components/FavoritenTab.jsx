import { useState } from "react";
import { X, Play, ChevronDown, ChevronUp } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { deserializeSlots } from "../lib/planLogic.js";
import { rotateWeekdaysFromToday, todayWeekday } from "../lib/dateUtils.js";
import { planNameFor } from "../lib/planNames.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import PremiumGate from "./PremiumGate.jsx";
import CycleBlock from "./CycleBlock.jsx";

export default function FavoritenTab({ favorites: fav, onGetPro, onStartLiveTraining }) {
  const { isPremium } = useAuth();
  const { t, locale, weekday, method: methodLabel } = useI18n();
  const { favorites, loading, remove } = fav;
  const [openId, setOpenId] = useState(null);

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
        sorted.map((f) => {
          const isOpen = openId === f.id;
          const planName = planNameFor(`${f.day}:${f.split || ""}`);
          const methodText = methodLabel(METHODS.find((m) => m.id === f.method)?.label || f.method || "Standard");

          return (
            <div className={`saved-card ${f.day === heute ? "is-today" : ""}`} key={f.id}>
              <button className="saved-card-toggle" onClick={() => setOpenId(isOpen ? null : f.id)}>
                <div>
                  <div className="saved-name">
                    {weekday(f.day)}
                    <span className="plan-name-badge">{planName}</span>
                    {f.day === heute && <span className="today-badge">{t("fav.today")}</span>}
                  </div>
                  <div className="saved-meta">
                    {t(f.cycles.length === 1 ? "tp.planCount" : "tp.plansCount", { n: f.cycles.length })} ·{" "}
                    {methodText} · {new Date(f.favoritedAt).toLocaleDateString(locale)}
                  </div>
                </div>
                <span className="saved-chevron">
                  {isOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                </span>
              </button>

              {isOpen && (
                <div className="tp-day-cycles no-pad">
                  {f.cycles.map((items, idx) => {
                    const slots = deserializeSlots(items);
                    return (
                      <CycleBlock
                        key={`${f.id}-${idx}`}
                        label={t("tp.cycleLabel", { n: idx + 1 })}
                        slots={slots}
                        isCurrent={false}
                        onStartLiveTraining={
                          onStartLiveTraining && slots.length > 0
                            ? () => onStartLiveTraining(slots, `${planName} · ${weekday(f.day)}`)
                            : undefined
                        }
                      />
                    );
                  })}
                </div>
              )}

              <div className="saved-actions">
                {onStartLiveTraining && f.cycles.length > 0 && (
                  <button
                    className="load"
                    onClick={() =>
                      onStartLiveTraining(
                        deserializeSlots(f.cycles[0]),
                        `${planName} · ${weekday(f.day)}`
                      )
                    }
                  >
                    <Play size={13} fill="currentColor" /> {t("live.startTraining")}
                  </button>
                )}
                <button className="delete" onClick={() => remove(f.id)}>
                  <X size={13} /> {t("fav.remove")}
                </button>
              </div>
            </div>
          );
        })
      )}
    </>
  );
}
