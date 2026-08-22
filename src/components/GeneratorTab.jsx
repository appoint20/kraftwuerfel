import { useState } from "react";
import { Shuffle, Plus, Minus, Dumbbell, RotateCcw, Play } from "lucide-react";
import { SPLITS, CATEGORIES, METHODS, REST_OPTIONS } from "../data/exercises.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import PremiumGate from "./PremiumGate.jsx";

export default function GeneratorTab({
  settings,
  plan,
  reel,
  onGenerate,
  onReroll,
  onUpdateSlot,
  saved,
  onGetPro,
  onStartLiveTraining,
}) {
  const { isPremium } = useAuth();
  const { t, category, equipment, split: splitLabel, locale, exerciseName } = useI18n();
  const { split, setSplit, customCats, toggleCustomCat, count, setCount, method, setMethod, restTime, setRestTime } =
    settings;
  const { rollingIdx, scramble } = reel;
  const [planName, setPlanName] = useState("");

  const savePlan = async () => {
    if (plan.length === 0) return;
    const name = planName.trim() || t("gen.defaultName", { date: new Date().toLocaleDateString(locale) });
    const ok = await saved.save(name, method, plan);
    if (ok) setPlanName("");
  };

  return (
    <>
      <div className="section-label">{t("gen.split")}</div>
      <div className="chip-row">
        {Object.keys(SPLITS).map((s) => (
          <button key={s} className={`chip ${split === s ? "active" : ""}`} onClick={() => setSplit(s)}>
            {splitLabel(s)}
          </button>
        ))}
      </div>

      {split === "Eigene" && (
        <>
          <div className="section-label">{t("gen.muscles")}</div>
          <div className="chip-row">
            {CATEGORIES.map((c) => (
              <button
                key={c}
                className={`chip ${customCats.has(c) ? "active" : ""}`}
                onClick={() => toggleCustomCat(c)}
              >
                {category(c)}
              </button>
            ))}
          </div>
        </>
      )}

      <div className="section-label">{t("gen.count")}</div>
      <div className="stepper">
        <button onClick={() => setCount((c) => Math.max(2, c - 1))}>
          <Minus size={16} />
        </button>
        <div className="stepper-count">{count}</div>
        <button onClick={() => setCount((c) => Math.min(12, c + 1))}>
          <Plus size={16} />
        </button>
      </div>

      <div className="section-label">{t("gen.method")}</div>
      <div className="chip-row">
        {METHODS.map((m) => (
          <button key={m.id} className={`chip ${method === m.id ? "active" : ""}`} onClick={() => setMethod(m.id)}>
            {m.label}
          </button>
        ))}
      </div>

      <div className="section-label">{t("gen.rest")}</div>
      <div className="chip-row">
        {REST_OPTIONS.map((r) => (
          <button key={r} className={`chip ${restTime === r ? "active" : ""}`} onClick={() => setRestTime(r)}>
            {r} s
          </button>
        ))}
      </div>

      <button className="roll-btn" onClick={onGenerate} disabled={split === "Eigene" && customCats.size === 0}>
        <Shuffle size={20} /> {t("gen.roll")}
      </button>

      {plan.length > 0 ? (
        <div className="plan-list">
          {plan.map((slot, i) => {
            const isRolling = rollingIdx.has(i);
            return (
              <div key={i} className={`plan-card ${isRolling ? "rolling" : ""}`}>
                <div className="plan-card-top">
                  <div className="plan-left">
                    <div className="plan-badge">{category(slot.exercise.category)}</div>
                    <div className={`plan-name ${isRolling ? "rolling" : ""}`}>
                      {isRolling ? scramble[i] || exerciseName(slot.exercise) : exerciseName(slot.exercise)}
                    </div>
                  </div>
                  <button className="reroll-btn" onClick={() => onReroll(i)} title={t("gen.rerollOne")}>
                    <Shuffle size={16} />
                  </button>
                </div>

                {!isRolling && (
                  <div className="plan-controls">
                    <div className="control-group">
                      <span className="control-label">{t("gen.sets")}</span>
                      <div className="mini-stepper">
                        <button onClick={() => onUpdateSlot(i, { sets: Math.max(1, slot.sets - 1) })}>
                          <Minus size={12} />
                        </button>
                        <div className="mini-stepper-val">{slot.sets}</div>
                        <button onClick={() => onUpdateSlot(i, { sets: Math.min(10, slot.sets + 1) })}>
                          <Plus size={12} />
                        </button>
                      </div>
                    </div>
                    <div className="control-group">
                      <span className="control-label">{t("gen.reps")}</span>
                      <input
                        className="reps-input"
                        value={slot.reps}
                        onChange={(e) => onUpdateSlot(i, { reps: e.target.value })}
                      />
                    </div>
                    <div className="control-group">
                      <span className="control-label">{t("gen.restShort")}</span>
                      <div className="rest-chip-row">
                        {REST_OPTIONS.map((r) => (
                          <button
                            key={r}
                            className={`rest-chip ${slot.rest === r ? "active" : ""}`}
                            onClick={() => onUpdateSlot(i, { rest: r })}
                          >
                            {r}s
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                )}
                {!isRolling && (
                  <div className="plan-equ-row">
                    <span className="db-equ">{equipment(slot.exercise.equipment)}</span>
                  </div>
                )}
              </div>
            );
          })}
          {onStartLiveTraining && (
            <button
              className="kw-btn live-start-btn"
              onClick={() => onStartLiveTraining(plan, `${splitLabel(split)} · ${plan.length} Übungen`)}
            >
              <Play size={18} fill="currentColor" /> {t("live.startTraining")}
            </button>
          )}

          <button className="remix-btn" onClick={onGenerate}>
            <RotateCcw size={14} /> {t("gen.remix")}
          </button>

          {isPremium ? (
            <>
              <div className="save-row">
                <input
                  className="save-input"
                  placeholder={t("gen.namePlaceholder")}
                  value={planName}
                  onChange={(e) => setPlanName(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") savePlan();
                  }}
                />
                <button className="save-btn" onClick={savePlan}>
                  <Dumbbell size={15} /> {t("gen.save")}
                </button>
              </div>
              {saved.status && <div className="save-status">{saved.status}</div>}
            </>
          ) : (
            <PremiumGate feature={t("pro.feature.save")} onGetPro={onGetPro} />
          )}
        </div>
      ) : (
        <div className="empty">
          {t("gen.empty")}
          <br />
          {t("gen.emptyHint")}
        </div>
      )}
    </>
  );
}
