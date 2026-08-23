import { useState } from "react";
import usePersistentState, { clearPersistentState } from "../hooks/usePersistentState.js";
import { Sparkles, RotateCcw, Dumbbell, Heart, ArrowRight, ArrowLeft, Check, AlertCircle, Play, User, ChevronUp, ChevronDown } from "lucide-react";
import { CATEGORIES, EQUIPMENT } from "../data/exercises.js";
import { WEEKDAYS, sortWeekdays, normalizeDate } from "../lib/dateUtils.js";
import { serializeSlots } from "../lib/planLogic.js";
import { generateAiPlan, aiDayToSlots, normalizePlan } from "../lib/aiClient.js";
import { useI18n } from "../lib/i18n.jsx";
import { useAuth } from "../lib/auth.jsx";
import PremiumGate from "./PremiumGate.jsx";
import CycleBlock from "./CycleBlock.jsx";

const GOALS = ["muscle", "strength", "definition", "fitness", "abnehmen"];
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
  const { t, category, equipment: equipmentLabel, weekday, focusText, lang } = useI18n();
  const { isPremium } = useAuth();
  const [planView, setPlanView] = useState("workout"); // "workout" | "nutrition"

  // Wizard step (1 to 5)
  const [step, setStep] = usePersistentState("ai.step", 1);

  // Form State: Goal & Experience
  const [goal, setGoal] = usePersistentState("ai.goal", "muscle");
  const [experience, setExperience] = usePersistentState("ai.experience", "intermediate");

  // Form State: Biometrics (Sex, Age, Height, Weight)
  const [sex, setSex] = usePersistentState("ai.sex", "male"); // "male" | "female" | "other"
  const [age, setAge] = usePersistentState("ai.age", 28);
  const [height, setHeight] = usePersistentState("ai.height", 180);
  const [weight, setWeight] = usePersistentState("ai.weight", 80);

  // Form State: Schedule & Equipment
  const [days, setDays] = usePersistentState("ai.days", new Set(["Mo", "Mi", "Fr"]));
  const [sessionMinutes, setSessionMinutes] = usePersistentState("ai.sessionMinutes", 60);
  const [equipment, setEquipment] = usePersistentState("ai.equipment", new Set());
  const [focus, setFocus] = usePersistentState("ai.focus", new Set());
  const [selectedQuickLimits, setSelectedQuickLimits] = usePersistentState("ai.quickLimits", new Set(["none"]));
  const [limitations, setLimitations] = usePersistentState("ai.limitations", "");
  const [weeks, setWeeks] = usePersistentState("ai.weeks", 4);
  // "auto" überlässt dem Coach die Entscheidung anhand von Alter und Erfahrung.
  const [warmup, setWarmup] = usePersistentState("ai.warmup", "auto");
  const [diet, setDiet] = usePersistentState("ai.diet", "omnivore");

  const [plan, setPlan] = usePersistentState("ai.plan", null);
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
        sex,
        age,
        height,
        weight,
        goal,
        experience,
        days: sortWeekdays(days),
        sessionMinutes,
        equipment: [...equipment],
        focus: [...focus],
        limitations: combinedLimits,
        weeks,
        language: lang,
        warmup,
        diet,
      });
      setPlan(normalizePlan(result));
    } catch (e) {
      setError(t("ai.error", { message: e.message || "Fehler bei der Plangenerierung" }));
    } finally {
      setBusy(false);
    }
  };

  /*
    Die Wochentage bleiben in ihrer natürlichen Reihenfolge stehen — getauscht
    wird das Training, das an dem Tag stattfindet. "Nach oben" heißt also:
    dieses Workout früher in der Woche.
  */
  const moveDay = (idx, dir) => {
    const target = idx + dir;
    if (target < 0 || target >= plan.days.length) return;
    setPlan((prev) => {
      const days = [...prev.days];
      const a = days[idx];
      const b = days[target];
      days[idx] = { ...b, weekday: a.weekday };
      days[target] = { ...a, weekday: b.weekday };
      return { ...prev, days };
    });
  };

  const resetWizard = () => {
    setPlan(null);
    setStep(1);
    clearPersistentState("ai.plan");
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
      count: plan.days[0]?.exercises.length || 5,
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
          {plan.source === "local" && (
            <div className="ai-plan-origin">
              {t("ai.localFallback")}
              {plan.fallbackReason && (
                <span className="ai-plan-reason">{t("ai.fallbackReason", { reason: plan.fallbackReason })}</span>
              )}
            </div>
          )}
        </div>

        {plan.nutrition && (
          <div className="live-mode-switch" style={{ margin: "14px 0" }}>
            <button
              className={`live-mode-btn ${planView === "workout" ? "active" : ""}`}
              onClick={() => setPlanView("workout")}
            >
              🏋️ {t("ai.workoutTab")}
            </button>
            <button
              className={`live-mode-btn ${planView === "nutrition" ? "active" : ""}`}
              onClick={() => setPlanView("nutrition")}
            >
              🥗 {t("ai.mealGuideTab")}
            </button>
          </div>
        )}

        {planView === "workout" && (
          <div className="tp-day-list">
            {plan.days.map((dayObj, idx) => {
              const dayName = dayObj.weekday;
              const slots = aiDayToSlots(dayObj);
              return (
                <div className="tp-day-block" key={`${dayName}-${idx}`}>
                  <div className="tp-day-toggle-row">
                    <div className="tp-day-toggle as-header">
                      <span className="tp-day-toggle-label">{weekday(dayName)}</span>
                      <span className="plan-name-badge">{focusText(dayObj.name)}</span>
                      <span className="tp-day-toggle-count">{focusText(dayObj.focus)}</span>
                    </div>
                    <div style={{ display: "flex", gap: "6px" }}>
                      <button
                        className="tp-fav-btn reorder"
                        onClick={() => moveDay(idx, -1)}
                        disabled={idx === 0}
                        title={t("tp.moveUp")}
                      >
                        <ChevronUp size={15} />
                      </button>
                      <button
                        className="tp-fav-btn reorder"
                        onClick={() => moveDay(idx, 1)}
                        disabled={idx === plan.days.length - 1}
                        title={t("tp.moveDown")}
                      >
                        <ChevronDown size={15} />
                      </button>
                      {onStartLiveTraining && (
                        <button
                          className="tp-fav-btn"
                          onClick={() => onStartLiveTraining(slots, `${focusText(dayObj.name)} · ${weekday(dayName)}`)}
                          title={t("live.startTraining")}
                          style={{ color: "var(--accent)" }}
                        >
                          <Play size={15} fill="currentColor" />
                        </button>
                      )}
                      <button
                        className="tp-fav-btn"
                        onClick={() => favorites.add(dayName, [slots], "KI", "standard")}
                        title={t("tp.favorite")}
                      >
                        <Heart size={15} />
                      </button>
                    </div>
                  </div>
                  <div className="tp-day-cycles">
                    {dayObj.warmup?.length > 0 && (
                      <div className="warmup-block">
                        <div className="warmup-head">{t("ai.warmupLabel")}</div>
                        {dayObj.warmup.map((w, wi) => (
                          <div className="warmup-row" key={wi}>
                            <span className="warmup-name">{w.name}</span>
                            {w.duration && <span className="warmup-dur">{w.duration}</span>}
                          </div>
                        ))}
                      </div>
                    )}
                    <CycleBlock slots={slots} />
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {planView === "nutrition" && plan.nutrition && (
          <div className="nutrition-card">
            <div className="nutrition-head">
              <span className="nutrition-title">{t("ai.nutritionTitle")}</span>
              <span className="nutrition-diet">{t(`ai.diet.${plan.nutrition.diet || "omnivore"}`)}</span>
            </div>

            <div className="nutrition-macros">
              <div className="macro big">
                <span className="macro-val">{plan.nutrition.dailyCalories}</span>
                <span className="macro-lbl">kcal / {t("ai.perDay")}</span>
              </div>
              <div className="macro">
                <span className="macro-val">{plan.nutrition.protein} g</span>
                <span className="macro-lbl">{t("ai.protein")}</span>
              </div>
              <div className="macro">
                <span className="macro-val">{plan.nutrition.carbs} g</span>
                <span className="macro-lbl">{t("ai.carbs")}</span>
              </div>
              <div className="macro">
                <span className="macro-val">{plan.nutrition.fat} g</span>
                <span className="macro-lbl">{t("ai.fat")}</span>
              </div>
            </div>

            {plan.nutrition.meals?.length > 0 && (
              <div className="meal-list">
                {plan.nutrition.meals.map((m, mi) => (
                  <div className="meal-row" key={mi}>
                    <div className="meal-when">
                      <span className="meal-time">{m.time}</span>
                      <span className="meal-name">{m.name}</span>
                    </div>
                    <div className="meal-body">
                      <span className="meal-items">{m.items.join(" · ")}</span>
                      {m.calories > 0 && <span className="meal-kcal">{m.calories} kcal</span>}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {plan.nutrition.shakes?.length > 0 && (
              <div className="shake-list">
                <div className="shake-head">{t("ai.shakes")}</div>
                {plan.nutrition.shakes.map((sh, si) => (
                  <div className="shake-row" key={si}>
                    <span className="shake-when">{sh.when}</span>
                    <span className="shake-what">{sh.what}</span>
                  </div>
                ))}
              </div>
            )}

            {plan.nutrition.notes?.length > 0 && (
              <ul className="ai-notes">
                {plan.nutrition.notes.map((n, ni) => (
                  <li key={ni}>{n}</li>
                ))}
              </ul>
            )}

            {/* Gesundheitsbezogene Zahlen ohne Einordnung stehen zu lassen wäre
                falsch — das sind Rechenwerte, keine Beratung. */}
            <div className="nutrition-disclaimer">{t("ai.nutritionDisclaimer")}</div>
          </div>
        )}

        {plan.notes.length > 0 && (
          <ul className="ai-notes" style={{ marginTop: "12px" }}>
            {plan.notes.map((note, i) => (
              <li key={i}>{note}</li>
            ))}
          </ul>
        )}

        <div style={{ display: "flex", flexDirection: "column", gap: "10px", marginTop: "16px" }}>
          {onStartLiveTraining && plan.days[0] && (
            <button
              className="kw-btn"
              onClick={() =>
                onStartLiveTraining(
                  aiDayToSlots(plan.days[0]),
                  `${plan.days[0].name} · ${weekday(plan.days[0].weekday)}`
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
            {step === 2 && t("ai.biometricsTitle")}
            {step === 3 && t("ai.days")}
            {step === 4 && t("ai.equipment")}
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

          <div className="section-label" style={{ marginTop: "18px" }}>
            {t("ai.experience")}
          </div>
          <div className="chip-grid">
            {EXPERIENCE.map((exp) => (
              <button
                key={exp}
                className={`wizard-card-chip ${experience === exp ? "active" : ""}`}
                onClick={() => setExperience(exp)}
              >
                <div className="chip-main-label">{t(`ai.exp.${exp}`)}</div>
              </button>
            ))}
          </div>

          <button className="kw-btn wizard-next-btn" onClick={() => setStep(2)}>
            {t("ai.next")} <ArrowRight size={16} />
          </button>
        </div>
      )}

      {/* STEP 2: BODY & BIOMETRICS (SEX, AGE, HEIGHT, WEIGHT) */}
      {step === 2 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.biometricsTitle")}</div>
          <div className="ai-intro">
            Für präzise Trainingsanpassung, progressive Belastung und exakte Kalorienberechnung.
          </div>

          {/* Sex Selection */}
          <div className="section-label">{t("ai.sex")}</div>
          <div className="chip-grid" style={{ gridTemplateColumns: "1fr 1fr 1fr" }}>
            {[
              { id: "male", label: t("ai.sexMale") },
              { id: "female", label: t("ai.sexFemale") },
              { id: "other", label: t("ai.sexOther") },
            ].map((s) => (
              <button
                key={s.id}
                className={`wizard-card-chip ${sex === s.id ? "active" : ""}`}
                onClick={() => setSex(s.id)}
              >
                <div className="chip-main-label">{s.label}</div>
              </button>
            ))}
          </div>

          {/* Age, Height, Weight inputs */}
          <div className="biometrics-inputs-grid">
            <div className="biometric-card">
              <div className="biometric-label">{t("ai.age")}</div>
              <div className="biometric-stepper">
                <button className="live-mini-btn" onClick={() => setAge((a) => Math.max(14, a - 1))}>
                  −
                </button>
                <div className="biometric-val">{age} <small>{t("ai.years")}</small></div>
                <button className="live-mini-btn" onClick={() => setAge((a) => Math.min(99, a + 1))}>
                  +
                </button>
              </div>
            </div>

            <div className="biometric-card">
              <div className="biometric-label">{t("ai.height")}</div>
              <div className="biometric-stepper">
                <button className="live-mini-btn" onClick={() => setHeight((h) => Math.max(120, h - 1))}>
                  −
                </button>
                <div className="biometric-val">{height} <small>cm</small></div>
                <button className="live-mini-btn" onClick={() => setHeight((h) => Math.min(230, h + 1))}>
                  +
                </button>
              </div>
            </div>

            <div className="biometric-card">
              <div className="biometric-label">{t("ai.weight")}</div>
              <div className="biometric-stepper">
                <button className="live-mini-btn" onClick={() => setWeight((w) => Math.max(35, w - 1))}>
                  −
                </button>
                <div className="biometric-val">{weight} <small>kg</small></div>
                <button className="live-mini-btn" onClick={() => setWeight((w) => Math.min(250, w + 1))}>
                  +
                </button>
              </div>
            </div>
          </div>

          <div className="wizard-btn-row">
            <button className="kw-btn-ghost wizard-back-btn" onClick={() => setStep(1)}>
              <ArrowLeft size={16} /> {t("ai.back")}
            </button>
            <button className="kw-btn wizard-next-btn" onClick={() => setStep(3)}>
              {t("ai.next")} <ArrowRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 3: SCHEDULE & DURATION */}
      {step === 3 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.days")}</div>

          <div className="filter-chips" style={{ marginBottom: "14px" }}>
            {WEEKDAYS.map((d) => (
              <button
                key={d}
                type="button"
                className={`chip ${days.has(d) ? "active" : ""}`}
                onClick={() => toggleSet(setDays)(d)}
              >
                {weekday(d)}
              </button>
            ))}
          </div>

          <div className="section-label" style={{ marginTop: "18px" }}>
            {t("ai.duration")}
          </div>
          <div className="chip-grid">
            {SESSION_MINUTES.map((m) => (
              <button
                key={m}
                className={`wizard-card-chip ${sessionMinutes === m ? "active" : ""}`}
                onClick={() => setSessionMinutes(m)}
              >
                <div className="chip-main-label">{m} Min</div>
              </button>
            ))}
          </div>

          <div className="section-label" style={{ marginTop: "18px" }}>
            {t("ai.weeks")}
          </div>
          <div className="chip-grid">
            {WEEK_OPTIONS.map((w) => (
              <button
                key={w}
                className={`wizard-card-chip ${weeks === w ? "active" : ""}`}
                onClick={() => setWeeks(w)}
              >
                <div className="chip-main-label">{w} {t("tp.weeks")}</div>
              </button>
            ))}
          </div>

          <div className="wizard-btn-row">
            <button className="kw-btn-ghost wizard-back-btn" onClick={() => setStep(2)}>
              <ArrowLeft size={16} /> {t("ai.back")}
            </button>
            <button
              className="kw-btn wizard-next-btn"
              disabled={days.size === 0}
              onClick={() => setStep(4)}
            >
              {t("ai.next")} <ArrowRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 4: EQUIPMENT & LIMITATIONS */}
      {step === 4 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.equipment")}</div>

          <div className="filter-chips">
            {EQUIPMENT.map((eq) => (
              <button
                key={eq}
                type="button"
                className={`chip ${equipment.has(eq) ? "active" : ""}`}
                onClick={() => toggleSet(setEquipment)(eq)}
              >
                {equipmentLabel(eq)}
              </button>
            ))}
          </div>

          <div className="section-label" style={{ marginTop: "18px" }}>
            {t("ai.quickLimitations")}
          </div>
          <div className="filter-chips">
            {QUICK_LIMITATIONS.map((limit) => (
              <button
                key={limit.id}
                type="button"
                className={`chip ${selectedQuickLimits.has(limit.id) ? "active" : ""}`}
                onClick={() => toggleQuickLimit(limit.id)}
              >
                {t(limit.key)}
              </button>
            ))}
          </div>

          <div className="section-label" style={{ marginTop: "18px" }}>
            {t("ai.customLimitations")}
          </div>
          <textarea
            className="ai-textarea"
            rows={2}
            placeholder={t("ai.limitPlaceholder")}
            value={limitations}
            onChange={(e) => setLimitations(e.target.value)}
          />

          <div className="section-label">{t("ai.warmupTitle")}</div>
          <div className="wizard-chip-grid">
            {["auto", "yes", "no"].map((w) => (
              <button
                key={w}
                className={`wizard-card-chip ${warmup === w ? "active" : ""}`}
                onClick={() => setWarmup(w)}
              >
                <div className="chip-main-label">{t(`ai.warmup.${w}`)}</div>
                <div className="chip-sub-label">{t(`ai.warmupHint.${w}`)}</div>
              </button>
            ))}
          </div>

          <div className="section-label">{t("ai.dietTitle")}</div>
          <div className="wizard-chip-grid">
            {["omnivore", "vegetarian", "vegan"].map((d) => (
              <button
                key={d}
                className={`wizard-card-chip ${diet === d ? "active" : ""}`}
                onClick={() => setDiet(d)}
              >
                <div className="chip-main-label">{t(`ai.diet.${d}`)}</div>
              </button>
            ))}
          </div>

          <div className="wizard-btn-row">
            <button className="kw-btn-ghost wizard-back-btn" onClick={() => setStep(3)}>
              <ArrowLeft size={16} /> {t("ai.back")}
            </button>
            <button className="kw-btn wizard-next-btn" onClick={() => setStep(5)}>
              {t("ai.next")} <ArrowRight size={16} />
            </button>
          </div>
        </div>
      )}

      {/* STEP 5: REVIEW & GENERATE */}
      {step === 5 && (
        <div className="wizard-step-content">
          <div className="wizard-headline">{t("ai.review")}</div>
          <div className="ai-intro">{t("ai.reviewSummary")}</div>

          <div className="ai-review-card">
            <div className="review-row">
              <span className="review-lbl">{t("ai.goal")}</span>
              <span className="review-val highlight">{t(`ai.goal.${goal}`)}</span>
            </div>
            <div className="review-row">
              <span className="review-lbl">{t("ai.experience")}</span>
              <span className="review-val">{t(`ai.exp.${experience}`)}</span>
            </div>
            <div className="review-row">
              <span className="review-lbl">{t("ai.biometricsTitle")}</span>
              <span className="review-val">
                {sex === "male" ? t("ai.sexMale") : sex === "female" ? t("ai.sexFemale") : t("ai.sexOther")} · {age} {t("ai.years")} · {height} cm · {weight} kg
              </span>
            </div>
            <div className="review-row">
              <span className="review-lbl">{t("ai.days")}</span>
              <span className="review-val mono">{sortWeekdays(days).map((d) => weekday(d)).join(", ")}</span>
            </div>
            <div className="review-row">
              <span className="review-lbl">Dauer & Wochen</span>
              <span className="review-val">{sessionMinutes} Min · {weeks} Wochen</span>
            </div>
            <div className="review-row">
              <span className="review-lbl">Equipment</span>
              <span className="review-val">
                {equipment.size === 0 ? "Alles" : [...equipment].map((e) => equipmentLabel(e)).join(", ")}
              </span>
            </div>
            {getCombinedLimitations() && (
              <div className="review-row">
                <span className="review-lbl">Einschränkungen</span>
                <span className="review-val highlight">{getCombinedLimitations()}</span>
              </div>
            )}
          </div>

          <button className="kw-btn ai-generate-btn" onClick={submit}>
            <Sparkles size={18} /> {t("ai.submit")}
          </button>

          {error && <div className="auth-error" style={{ marginTop: "12px" }}>{error}</div>}

          <div className="wizard-btn-row" style={{ marginTop: "12px" }}>
            <button className="kw-btn-ghost wizard-back-btn" onClick={() => setStep(4)}>
              <ArrowLeft size={16} /> {t("ai.back")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
