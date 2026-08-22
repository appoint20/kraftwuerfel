import { useState } from "react";
import { Sparkles, RotateCcw, Dumbbell, Heart, ArrowRight, ArrowLeft, Check, AlertCircle, Play } from "lucide-react";
import { CATEGORIES, EQUIPMENT } from "../data/exercises.js";
import { WEEKDAYS, sortWeekdays, normalizeDate } from "../lib/dateUtils.js";
import { serializeSlots } from "../lib/planLogic.js";
import { generateAiPlan, aiDayToSlots } from "../lib/aiClient.js";
import { useI18n } from "../lib/i18n.jsx";
import { useAuth } from "../lib/auth.jsx";
import PremiumGate from "./PremiumGate.jsx";
import CycleBlock from "./CycleBlock.jsx";

const GOALS = ["muscle", "strength", "definition", "fitness"];
const EXPERIENCE = ["beginner", "intermediate", "advanced"];
const SESSION_MINUTES = [30, 45, 60, 90];
const WEEK_OPTIONS = [2, 4, 6];

const QUICK_LIMITATIONS = [
  { id: "none", key: "ai.limitNone", text: "" },
  { id: "knee", key: "ai.limitKnee", text: "Knie schonen / keine schweren Kniebeugen" },
  { id: "shoulder", key: "ai.limitShoulder", text: "Schulter schonen / kein schweres Drücken" },
  { id: "overhead", key: "ai.limitOverhead", text: "Kein Überkopfdrücken" },
  { id: "back", key: "ai.limitBack", text: "Unterer Rücken schonen / kein schweres Kreuzheben" },
  { id: "wrists", key: "ai.limitWrists", text: "Handgelenke schonen" },
];

export default function AiCoachTab({ active, favorites, onGetPro, onStartLiveTraining }) {
  const { t, category, equipment: equipmentLabel, weekday, lang } = useI18n();
  const { isPremium } = useAuth();

  // Wizard step (1 to 5)
  const [step, setStep] = useState(1);

  // Form State
  const [goal, setGoal] = useState("muscle");
  const [experience, setExperience] = useState("intermediate");
  const [days, setDays] = useState(new Set(["Mo", "Mi", "Fr"]));
  const [sessionMinutes, setSessionMinutes] = useState(60);
  const [equipment, setEquipment] = useState(new Set());
  const [focus, setFocus] = useState(new Set());
  const [selectedQuickLimits, setSelectedQuickLimits] = useState(new Set(["none"]));
  const [limitations, setLimitations] = useState("");
  const [weeks, setWeeks] = useState(4);

  const [plan, setPlan] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [status, setStatus] = useState("");

  if (!isPremium) {
    return (
      <>
        <div className="section-label">{t("ai.title")}</div>
        <div className="ai-intro">{t("ai.intro")}</div>
        <PremiumGate feature={t("pro.feature.ai")} onGetPro={onGetPro} />
      </>
    );
  }

  const toggleSet = (setter) => (value) =>
    setter((prev) => {
      const next = new Set(prev);
      next.has(value) ? next.delete(value) : next.add(value);
      return next;
    });

  const toggleQuickLimit = (id) => {
    setSelectedQuickLimits((prev) => {
      const next = new Set(prev);
      if (id === "none") {
        return new Set(["none"]);
      }
      next.delete("none");
      if (next.has(id)) {
        next.delete(id);
        if (next.size === 0) next.add("none");
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const getCombinedLimitations = () => {
    const limits = [];
    selectedQuickLimits.forEach((id) => {
      const item = QUICK_LIMITATIONS.find((l) => l.id === id);
      if (item && item.text) limits.push(item.text);
    });
    if (limitations.trim()) {
      limits.push(limitations.trim());
    }
    return limits.join(", ");
  };

  const submit = async () => {
    if (days.size === 0) {
      setError(t("ai.pickDaysFirst"));
      return;
    }
    setBusy(true);
    setError("");
    setStatus("");
    try {
      const combinedLimits = getCombinedLimitations();
      const result = await generateAiPlan({
        goal,
        experience,
        days: sortWeekdays(days),
        sessionMinutes,
        equipment: [...equipment],
        focus: [...focus],
        limitations: combinedLimits,
        weeks,
        language: lang,
      });
      setPlan(result);
    } catch (e) {
      if (e.message === "no-backend") {
        setError(t("ai.noBackend"));
      } else if (e.message === "daily limit reached") {
        setError(t("ai.limitReached"));
      } else if (e.message === "premium required") {
        setError(t("pro.gateText", { feature: t("pro.feature.ai") }));
      } else {
        setError(t("ai.error", { message: e.message }));
      }
    } finally {
      setBusy(false);
    }
  };

  const startAsPlan = async () => {
    const dayPlans = {};
    plan.days.forEach((d) => {
      dayPlans[d.weekday] = [serializeSlots(aiDayToSlots(d))];
    });
    const ok = await active.start({
      startDate: normalizeDate(new Date()).toISOString(),
      duration: weeks,
      days: sortWeekdays(plan.days.map((d) => d.weekday)),
      split: "KI",
      method: "standard",
      count: plan.days[0]?.exercises.length || 6,
      restTime: 60,
      dayPlans,
    });
    if (ok) setStatus(t("ai.started"));
  };

  if (busy) {
    return (
      <div className="ai-loading">
        <div className="ai-loading-dice">
          <Sparkles size={26} />
        </div>
        <div className="ai-loading-text">{t("ai.loading")}</div>
        <div className="ai-loading-hint">{t("ai.loadingHint")}</div>
      </div>
    );
  }

  if (plan) {
    return (
      <>
        <div className="ai-plan-head">
          <div className="ai-plan-title">{plan.title}</div>
          {plan.summary && <div className="ai-plan-summary">{plan.summary}</div>}
        </div>

        <div className="tp-day-list">
          {plan.days.map((day, idx) => {
            const slots = aiDayToSlots(day);
            return (
              <div className="tp-day-block" key={`${day.weekday}-${idx}`}>
                <div className="tp-day-toggle-row">
                  <div className="tp-day-toggle as-header">
                    <span className="tp-day-toggle-label">{weekday(day.weekday)}</span>
                    <span className="tp-day-toggle-count">{day.focus}</span>
                  </div>
                  <div style={{ display: "flex", gap: "6px" }}>
                    {onStartLiveTraining && (
                      <button
                        className="tp-fav-btn"
                        onClick={() => onStartLiveTraining(slots, `${weekday(day.weekday)} · ${day.focus}`)}
                        title={t("live.startTraining")}
                        style={{ color: "var(--accent)" }}
                      >
                        <Play size={15} fill="currentColor" />
                      </button>
                    )}
                    <button
                      className="tp-fav-btn"
                      onClick={() => favorites.add(day.weekday, [slots], "KI", "standard")}
                      title={t("tp.favorite")}
                    >
                      <Heart size={15} />
                    </button>
                  </div>
                </div>
                <div className="tp-day-cycles">
                  <CycleBlock slots={slots} />
                </div>
              </div>
            );
          })}
        </div>

        {plan.notes?.length > 0 && (
          <>
            <div className="section-label">{t("ai.notes")}</div>
            <ul className="ai-notes">
              {plan.notes.map((note, i) => (
                <li key={i}>{note}</li>
              ))}
            </ul>
          </>
        )}

        <div style={{ display: "flex", flexDirection: "column", gap: "10px", marginTop: "16px" }}>
          {onStartLiveTraining && plan.days[0] && (
            <button
              className="kw-btn"
              onClick={() =>
                onStartLiveTraining(
                  aiDayToSlots(plan.days[0]),
                  `${weekday(plan.days[0].weekday)} · ${plan.days[0].focus}`
                )
              }
            >
              <Play size={18} fill="currentColor" /> {t("live.startTraining")} ({weekday(plan.days[0].weekday)})
            </button>
          )}

          <button className="save-btn tp-start-btn" onClick={startAsPlan}>
            <Dumbbell size={15} /> {t("ai.start")}
          </button>
        </div>

        {status && <div className="save-status">{status}</div>}
        {active.status && <div className="save-status">{active.status}</div>}
        {favorites.status && <div className="save-status">{favorites.status}</div>}

        <button
          className="remix-btn"
          onClick={() => {
            setPlan(null);
            setStep(1);
          }}
        >
          <RotateCcw size={14} /> {t("ai.regenerate")}
        </button>
      </>
    );
  }

  // WIZARD STEP NAVIGATION
  return (
    <div className="ai-wizard-container">
      {/* Wizard Header with 5-segment Progress Bar */}
      <div className="wizard-header">
        <div className="wizard-progress-info">
          <span className="wizard-step-label">{t("ai.step", { current: step, total: 5 })}</span>
          <span className="wizard-title-badge">
            {step === 1 && t("ai.goal")}
            {step === 2 && t("ai.days")}
            {step === 3 && t("ai.equipment")}
            {step === 4 && t("ai.limitations")}
            {step === 5 && t("ai.review")}
          </span>
        </div>
        <div className="wizard-bar-track">
          {[1, 2, 3, 4, 5].map((s) => (
            <div
              key={s}
              className={`wizard-bar-seg ${s <= step ? "active" : ""}`}
              onClick={() => s < step && setStep(s)}
            />
          ))}
        </div>
      </div>

      {/* STEP 1: GOAL & EXPERIENCE */}
      {step === 1 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.title")}</div>
          <div className="ai-intro">{t("ai.intro")}</div>

          <div className="section-label">{t("ai.goal")}</div>
          <div className="chip-grid">
            {GOALS.map((g) => (
              <button
                key={g}
                className={`wizard-card-chip ${goal === g ? "active" : ""}`}
                onClick={() => setGoal(g)}
              >
                <div className="chip-main-label">{t(`ai.goal.${g}`)}</div>
              </button>
            ))}
          </div>

          <div className="section-label">{t("ai.experience")}</div>
          <div className="chip-grid">
            {EXPERIENCE.map((e) => (
              <button
                key={e}
                className={`wizard-card-chip ${experience === e ? "active" : ""}`}
                onClick={() => setExperience(e)}
              >
                <div className="chip-main-label">{t(`ai.experience.${e}`)}</div>
              </button>
            ))}
          </div>
        </div>
      )}

      {/* STEP 2: DAYS & DURATION */}
      {step === 2 && (
        <div className="wizard-step-content">
          <div className="section-label">{t("ai.days")}</div>
          <div className="chip-row">
            {WEEKDAYS.map((d) => (
              <button
                key={d}
                className={`chip ${days.has(d) ? "active" : ""}`}
                onClick={() => toggleSet(setDays)(d)}
              >
                {weekday(d)}
              </button>
            ))}
          </div>
          {days.size === 0 && (
            <div className="wizard-error-hint">
              <AlertCircle size={13} /> {t("ai.pickDaysFirst")}
            </div>
          )}

          <div className="section-label">{t("ai.duration")}</div>
          <div className="chip-row">
            {SESSION_MINUTES.map((m) => (
              <button
                key={m}
                className={`chip ${sessionMinutes === m ? "active" : ""}`}
                onClick={() => setSessionMinutes(m)}
              >
                {t("ai.minutes", { n: m })}
              </button>
            ))}
          </div>

          <div className="section-label">{t("ai.weeks")}</div>
          <div className="chip-row">
            {WEEK_OPTIONS.map((w) => (
              <button
                key={w}
                className={`chip ${weeks === w ? "active" : ""}`}
                onClick={() => setWeeks(w)}
              >
                {t("ai.weeksValue", { n: w })}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* STEP 3: EQUIPMENT & FOCUS */}
      {step === 3 && (
        <div className="wizard-step-content">
          <div className="section-label">{t("ai.equipment")}</div>
          <div className="chip-row">
            <button
              className={`chip ${equipment.size === 0 ? "active" : ""}`}
              onClick={() => setEquipment(new Set())}
            >
              {t("ai.equipmentAll")}
            </button>
            {EQUIPMENT.map((eq) => (
              <button
                key={eq}
                className={`chip ${equipment.has(eq) ? "active" : ""}`}
                onClick={() => toggleSet(setEquipment)(eq)}
              >
                {equipmentLabel(eq)}
              </button>
            ))}
          </div>

          <div className="section-label">{t("ai.focus")}</div>
          <div className="chip-row">
            {CATEGORIES.map((c) => (
              <button
                key={c}
                className={`chip ${focus.has(c) ? "active" : ""}`}
                onClick={() => toggleSet(setFocus)(c)}
              >
                {category(c)}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* STEP 4: LIMITATIONS & HEALTH */}
      {step === 4 && (
        <div className="wizard-step-content">
          <div className="section-label">{t("ai.quickLimitations")}</div>
          <div className="chip-grid">
            {QUICK_LIMITATIONS.map((l) => (
              <button
                key={l.id}
                className={`wizard-card-chip ${selectedQuickLimits.has(l.id) ? "active" : ""}`}
                onClick={() => toggleQuickLimit(l.id)}
              >
                <div className="chip-main-label">{t(l.key)}</div>
              </button>
            ))}
          </div>

          <div className="section-label">{t("ai.limitations")}</div>
          <textarea
            className="ai-textarea"
            rows={3}
            maxLength={500}
            placeholder={t("ai.limitationsPlaceholder")}
            value={limitations}
            onChange={(e) => setLimitations(e.target.value)}
          />
        </div>
      )}

      {/* STEP 5: REVIEW & SUBMIT */}
      {step === 5 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.reviewSummary")}</div>

          <div className="wizard-summary-card">
            <div className="summary-row">
              <span className="summary-label">{t("ai.goal")}</span>
              <span className="summary-val">{t(`ai.goal.${goal}`)}</span>
            </div>
            <div className="summary-row">
              <span className="summary-label">{t("ai.experience")}</span>
              <span className="summary-val">{t(`ai.experience.${experience}`)}</span>
            </div>
            <div className="summary-row">
              <span className="summary-label">{t("ai.days")}</span>
              <span className="summary-val">
                {sortWeekdays(days)
                  .map((d) => weekday(d))
                  .join(", ") || "—"}
              </span>
            </div>
            <div className="summary-row">
              <span className="summary-label">{t("ai.duration")}</span>
              <span className="summary-val">{sessionMinutes} Min · {weeks} Wochen</span>
            </div>
            <div className="summary-row">
              <span className="summary-label">{t("ai.equipment")}</span>
              <span className="summary-val">
                {equipment.size === 0
                  ? t("ai.equipmentAll")
                  : [...equipment].map((e) => equipmentLabel(e)).join(", ")}
              </span>
            </div>
            {focus.size > 0 && (
              <div className="summary-row">
                <span className="summary-label">{t("ai.focus")}</span>
                <span className="summary-val">{[...focus].map((f) => category(f)).join(", ")}</span>
              </div>
            )}
            {getCombinedLimitations() && (
              <div className="summary-row">
                <span className="summary-label">{t("ai.limitations")}</span>
                <span className="summary-val">{getCombinedLimitations()}</span>
              </div>
            )}
          </div>

          <button className="roll-btn" onClick={submit} disabled={days.size === 0}>
            <Sparkles size={20} /> {t("ai.submit")}
          </button>

          {error && <div className="auth-error">{error}</div>}
        </div>
      )}

      {/* WIZARD FOOTER NAVIGATION */}
      <div className="wizard-footer">
        {step > 1 ? (
          <button className="wizard-back-btn" onClick={() => setStep((s) => s - 1)}>
            <ArrowLeft size={16} /> {t("ai.back")}
          </button>
        ) : (
          <div />
        )}

        {step < 5 ? (
          <button
            className="wizard-next-btn"
            disabled={step === 2 && days.size === 0}
            onClick={() => setStep((s) => s + 1)}
          >
            {t("ai.next")} <ArrowRight size={16} />
          </button>
        ) : null}
      </div>
    </div>
  );
}
