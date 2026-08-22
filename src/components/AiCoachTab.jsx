import { useState } from "react";
import { Sparkles, RotateCcw, Dumbbell, Heart } from "lucide-react";
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

export default function AiCoachTab({ active, favorites, onGetPro }) {
  const { t, category, equipment: equipmentLabel, weekday, lang } = useI18n();
  const { isPremium } = useAuth();

  const [goal, setGoal] = useState("muscle");
  const [experience, setExperience] = useState("intermediate");
  const [days, setDays] = useState(new Set(["Mo", "Mi", "Fr"]));
  const [sessionMinutes, setSessionMinutes] = useState(60);
  const [equipment, setEquipment] = useState(new Set());
  const [focus, setFocus] = useState(new Set());
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

  const toggle = (setter) => (value) =>
    setter((prev) => {
      const next = new Set(prev);
      next.has(value) ? next.delete(value) : next.add(value);
      return next;
    });

  const submit = async () => {
    if (days.size === 0) {
      setError(t("ai.pickDaysFirst"));
      return;
    }
    setBusy(true);
    setError("");
    setStatus("");
    try {
      const result = await generateAiPlan({
        goal,
        experience,
        days: sortWeekdays(days),
        sessionMinutes,
        equipment: [...equipment],
        focus: [...focus],
        limitations,
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
          {plan.days.map((day, idx) => (
            <div className="tp-day-block" key={`${day.weekday}-${idx}`}>
              <div className="tp-day-toggle-row">
                <div className="tp-day-toggle as-header">
                  <span className="tp-day-toggle-label">{weekday(day.weekday)}</span>
                  <span className="tp-day-toggle-count">{day.focus}</span>
                </div>
                <button
                  className="tp-fav-btn"
                  onClick={() => favorites.add(day.weekday, [aiDayToSlots(day)], "KI", "standard")}
                  title={t("tp.favorite")}
                >
                  <Heart size={15} />
                </button>
              </div>
              <div className="tp-day-cycles">
                <CycleBlock slots={aiDayToSlots(day)} />
              </div>
            </div>
          ))}
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

        <button className="save-btn tp-start-btn" onClick={startAsPlan}>
          <Dumbbell size={15} /> {t("ai.start")}
        </button>
        {status && <div className="save-status">{status}</div>}
        {active.status && <div className="save-status">{active.status}</div>}
        {favorites.status && <div className="save-status">{favorites.status}</div>}

        <button className="remix-btn" onClick={() => setPlan(null)}>
          <RotateCcw size={14} /> {t("ai.regenerate")}
        </button>
      </>
    );
  }

  return (
    <>
      <div className="section-label">{t("ai.title")}</div>
      <div className="ai-intro">{t("ai.intro")}</div>

      <div className="section-label">{t("ai.goal")}</div>
      <div className="chip-row">
        {GOALS.map((g) => (
          <button key={g} className={`chip ${goal === g ? "active" : ""}`} onClick={() => setGoal(g)}>
            {t(`ai.goal.${g}`)}
          </button>
        ))}
      </div>

      <div className="section-label">{t("ai.experience")}</div>
      <div className="chip-row">
        {EXPERIENCE.map((e) => (
          <button key={e} className={`chip ${experience === e ? "active" : ""}`} onClick={() => setExperience(e)}>
            {t(`ai.experience.${e}`)}
          </button>
        ))}
      </div>

      <div className="section-label">{t("ai.days")}</div>
      <div className="chip-row">
        {WEEKDAYS.map((d) => (
          <button key={d} className={`chip ${days.has(d) ? "active" : ""}`} onClick={() => toggle(setDays)(d)}>
            {weekday(d)}
          </button>
        ))}
      </div>

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
          <button key={w} className={`chip ${weeks === w ? "active" : ""}`} onClick={() => setWeeks(w)}>
            {t("ai.weeksValue", { n: w })}
          </button>
        ))}
      </div>

      <div className="section-label">{t("ai.equipment")}</div>
      <div className="chip-row">
        <button className={`chip ${equipment.size === 0 ? "active" : ""}`} onClick={() => setEquipment(new Set())}>
          {t("ai.equipmentAll")}
        </button>
        {EQUIPMENT.map((eq) => (
          <button
            key={eq}
            className={`chip ${equipment.has(eq) ? "active" : ""}`}
            onClick={() => toggle(setEquipment)(eq)}
          >
            {equipmentLabel(eq)}
          </button>
        ))}
      </div>

      <div className="section-label">{t("ai.focus")}</div>
      <div className="chip-row">
        {CATEGORIES.map((c) => (
          <button key={c} className={`chip ${focus.has(c) ? "active" : ""}`} onClick={() => toggle(setFocus)(c)}>
            {category(c)}
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

      <button className="roll-btn" onClick={submit} disabled={days.size === 0}>
        <Sparkles size={20} /> {t("ai.submit")}
      </button>

      {error && <div className="auth-error">{error}</div>}
    </>
  );
}
