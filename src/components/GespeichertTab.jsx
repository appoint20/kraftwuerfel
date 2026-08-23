import { useState } from "react";
import { Shuffle, X, Play, ChevronDown, ChevronUp } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { deserializeSlots } from "../lib/planLogic.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import PremiumGate from "./PremiumGate.jsx";
import CycleBlock from "./CycleBlock.jsx";

export default function GespeichertTab({ saved, onLoad, onStartLiveTraining, onGetPro }) {
  const { isPremium } = useAuth();
  const { t, locale, method: methodLabel } = useI18n();
  const { plans, nutritionPlans = [], loading, remove, removeNutrition } = saved;
  const [subTab, setSubTab] = useState("workouts"); // "workouts" | "nutrition"
  const [openId, setOpenId] = useState(null);

  if (!isPremium && plans.length === 0 && nutritionPlans.length === 0) {
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

      {nutritionPlans.length > 0 && (
        <div className="live-mode-switch" style={{ margin: "10px 0 16px 0" }}>
          <button
            className={`live-mode-btn ${subTab === "workouts" ? "active" : ""}`}
            onClick={() => {
              setSubTab("workouts");
              setOpenId(null);
            }}
          >
            🏋️ {t("saved.workouts")} ({plans.length})
          </button>
          <button
            className={`live-mode-btn ${subTab === "nutrition" ? "active" : ""}`}
            onClick={() => {
              setSubTab("nutrition");
              setOpenId(null);
            }}
          >
            🥗 {t("saved.mealPlans")} ({nutritionPlans.length})
          </button>
        </div>
      )}

      {loading ? (
        <div className="empty">{t("common.loading")}</div>
      ) : subTab === "workouts" ? (
        plans.length === 0 ? (
          <div className="empty">
            {t("saved.empty")}
            <br />
            {t("saved.emptyHint")}
          </div>
        ) : (
          plans.map((sp) => {
            const isOpen = openId === sp.id;
            const slots = deserializeSlots(sp.items);
            const methodText = methodLabel(METHODS.find((m) => m.id === sp.method)?.label || sp.method || "Standard");

            return (
              <div className="saved-card" key={sp.id}>
                <button className="saved-card-toggle" onClick={() => setOpenId(isOpen ? null : sp.id)}>
                  <div>
                    <div className="saved-name">{sp.name}</div>
                    <div className="saved-meta">
                      {t("saved.exercises", { n: sp.items.length })} · {methodText} ·{" "}
                      {new Date(sp.savedAt).toLocaleDateString(locale)}
                    </div>
                  </div>
                  <span className="saved-chevron">
                    {isOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                  </span>
                </button>

                {isOpen && (
                  <div className="tp-day-cycles no-pad">
                    <CycleBlock slots={slots} />
                  </div>
                )}

                <div className="saved-actions">
                  {onStartLiveTraining && slots.length > 0 && (
                    <button className="load" onClick={() => onStartLiveTraining(slots, sp.name)}>
                      <Play size={13} fill="currentColor" /> {t("live.startTraining")}
                    </button>
                  )}
                  <button onClick={() => onLoad(sp)}>
                    <Shuffle size={13} /> {t("saved.load")}
                  </button>
                  <button className="delete" onClick={() => remove(sp.id)}>
                    <X size={13} /> {t("saved.delete")}
                  </button>
                </div>
              </div>
            );
          })
        )
      ) : (
        nutritionPlans.length === 0 ? (
          <div className="empty">{t("saved.noMealPlans")}</div>
        ) : (
          nutritionPlans.map((np) => {
            const isOpen = openId === np.id;
            return (
              <div className="saved-card" key={np.id}>
                <button className="saved-card-toggle" onClick={() => setOpenId(isOpen ? null : np.id)}>
                  <div>
                    <div className="saved-name">🥗 {np.title || t("ai.mealGuideTab")}</div>
                    <div className="saved-meta">
                      {np.dailyCalories} kcal · {t(`ai.diet.${np.diet}`)} ·{" "}
                      {new Date(np.savedAt).toLocaleDateString(locale)}
                    </div>
                  </div>
                  <span className="saved-chevron">
                    {isOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                  </span>
                </button>

                {isOpen && (
                  <div className="nutrition-plan-card" style={{ margin: "10px 0 6px 0" }}>
                    <div className="macro-row">
                      <div className="macro-item kcal">
                        <span className="macro-val">{np.dailyCalories}</span>
                        <span className="macro-label">kcal / Tag</span>
                      </div>
                      <div className="macro-item">
                        <span className="macro-val">{np.protein} g</span>
                        <span className="macro-label">Eiweiß</span>
                      </div>
                      <div className="macro-item">
                        <span className="macro-val">{np.carbs} g</span>
                        <span className="macro-label">Carbs</span>
                      </div>
                      <div className="macro-item">
                        <span className="macro-val">{np.fat} g</span>
                        <span className="macro-label">Fett</span>
                      </div>
                    </div>

                    {np.meals?.length > 0 && (
                      <div className="meal-list" style={{ marginTop: "12px" }}>
                        {np.meals.map((m, mi) => (
                          <div className="meal-row" key={mi}>
                            <div className="meal-time-col">
                              <span className="meal-time">{m.time}</span>
                              <span className="meal-name">{m.name}</span>
                            </div>
                            <div className="meal-desc">
                              <div className="meal-items">{m.items?.join(" · ")}</div>
                              {m.calories > 0 && (
                                <div className="meal-cals">{m.calories} kcal</div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}

                <div className="saved-actions">
                  <button className="delete" onClick={() => removeNutrition(np.id)}>
                    <X size={13} /> {t("saved.delete")}
                  </button>
                </div>
              </div>
            );
          })
        )
      )}
    </>
  );
}
