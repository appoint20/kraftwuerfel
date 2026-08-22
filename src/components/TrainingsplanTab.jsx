import { Dice5, Dumbbell, RotateCcw, X, Play } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { WEEKDAYS, sortWeekdays, normalizeDate } from "../lib/dateUtils.js";
import { cyclesForDuration, serializeDayPlans } from "../lib/planLogic.js";
import { getProgress, getLastTrained } from "../lib/progress.js";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";
import DayBlock from "./DayBlock.jsx";
import PremiumGate from "./PremiumGate.jsx";

export default function TrainingsplanTab({ settings, tp, active, favorites, onGetPro, onStartLiveTraining }) {
  const { isPremium } = useAuth();
  const { t, split: splitLabel, weekday } = useI18n();
  const { split, method, count, restTime, activeCategories } = settings;
  const { tpDays, toggleTpDay, tpDuration, setTpDuration, resetTpPlans, dayPlans, createDayPlans, expandedDay, setExpandedDay } = tp;
  const { activePlan, loading, status, start, end } = active;

  const progress = getProgress(activePlan);

  const startPlan = () =>
    start({
      startDate: normalizeDate(new Date()).toISOString(),
      duration: tpDuration,
      days: sortWeekdays(tpDays),
      split,
      method,
      count,
      restTime,
      dayPlans: serializeDayPlans(dayPlans),
    });

  const renderDay = (day, cyclePlans, currentCycleIdx) => (
    <DayBlock
      key={day}
      day={day}
      cyclePlans={cyclePlans}
      currentCycleIdx={currentCycleIdx}
      isOpen={expandedDay === day}
      onToggle={() => setExpandedDay(expandedDay === day ? null : day)}
      onFavorite={(d, cycles) => favorites.add(d, cycles, split, method)}
      justSaved={favorites.justSaved.has(day)}
      canFavorite={isPremium}
      onStartLiveTraining={onStartLiveTraining}
      planSalt={`${split}:${method}`}
    />
  );

  if (loading) return <div className="empty">{t("common.loading")}</div>;

  if (activePlan && progress.finished) {
    return (
      <>
        <div className="empty">
          {t("tp.finished")}
          <br />
          {t("tp.finishedHint", { n: activePlan.duration })}
        </div>
        <button className="roll-btn compact" onClick={end}>
          <RotateCcw size={16} /> {t("tp.newPlan")}
        </button>
      </>
    );
  }

  if (activePlan) {
    const activeDays = sortWeekdays(activePlan.days);
    const cycles = cyclesForDuration(activePlan.duration);
    const cycleWeeks = [];
    for (let w = 1; w <= activePlan.duration; w++) {
      cycleWeeks.push({ w, cycleIdx: Math.floor((w - 1) / 2) });
    }
    return (
      <>
        <div className="progress-card">
          <div className="progress-top">
            <div className="progress-week">
              {t("tp.week")} {progress.weekIdx} <span className="progress-of">/ {activePlan.duration}</span>
            </div>
            <div className="progress-label-badge">
              {t("tp.cycle", { n: progress.cycleIdx + 1, total: cycles })}
            </div>
          </div>
          <div className="progress-bar-track">
            <div
              className="progress-bar-fill"
              style={{ width: `${Math.min(100, (progress.weekIdx / activePlan.duration) * 100)}%` }}
            />
          </div>
          <div className="progress-sub">
            {progress.isTrainingDay ? t("tp.isTrainingDay") : t("tp.noTrainingDay")} ·{" "}
            {t("tp.daysLeft", { n: progress.daysLeftTotal })}
          </div>
        </div>

        <div className="tp-timeline">
          {cycleWeeks.map((c) => (
            <div key={c.w} className={`tp-timeline-chip ${c.w === progress.weekIdx ? "now" : ""}`}>
              <span className="tl-week">{c.w}</span>
              <span className="tl-label">Z{c.cycleIdx + 1}</span>
            </div>
          ))}
        </div>

        <div className="weekday-status-row">
          {activeDays.map((day) => {
            const info = getLastTrained(activePlan, day);
            return (
              <div className="weekday-status-chip" key={day}>
                <div className="wd-label">{weekday(day)}</div>
                {info.upcoming ? (
                  <div className="wd-info">{t("tp.inDays", { n: info.inDays })}</div>
                ) : (
                  <div className="wd-info">
                    {info.isToday ? t("tp.today") : t("tp.daysAgo", { n: info.daysAgo })}
                    <span className="wd-plan">Z{info.cycleIdx + 1}</span>
                  </div>
                )}
              </div>
            );
          })}
        </div>

        <div className="section-label">{t("tp.tapDay", { cycles: cycles === 1 ? "" : `${cycles} ` })}</div>
        <div className="tp-day-list">
          {activeDays.map((day) => renderDay(day, (dayPlans && dayPlans[day]) || [], progress.cycleIdx))}
        </div>
        {favorites.status && <div className="save-status">{favorites.status}</div>}

        <button className="remix-btn" onClick={end}>
          <X size={14} /> {t("tp.end")}
        </button>
      </>
    );
  }

  return (
    <>
      <div className="section-label">{t("tp.pickDays")}</div>
      <div className="chip-row">
        {WEEKDAYS.map((d) => (
          <button key={d} className={`chip ${tpDays.has(d) ? "active" : ""}`} onClick={() => toggleTpDay(d)}>
            {weekday(d)}
          </button>
        ))}
      </div>

      <div className="section-label">{t("tp.duration")}</div>
      <div className="chip-row">
        {[2, 4, 6].map((w) => (
          <button key={w} className={`chip ${tpDuration === w ? "active" : ""}`} onClick={() => setTpDuration(w)}>
            {t("tp.weeksShort", { n: w })}
          </button>
        ))}
        {dayPlans && (
          <button className="chip reset-chip-btn" onClick={resetTpPlans} title={t("tp.resetPlans")}>
            <RotateCcw size={13} /> {t("tp.resetPlans")}
          </button>
        )}
      </div>

      <div className="section-label">{t("tp.settingsFromGenerator")}</div>
      <div className="tp-settings-summary">
        {t("tp.summary", {
          split: splitLabel(split),
          count,
          method: METHODS.find((m) => m.id === method)?.label,
          rest: restTime,
        })}
      </div>

      {tpDays.size > 0 && (
        <div className="tp-plan-count-hint">
          {t("tp.countHint", { days: tpDays.size, cycles: cyclesForDuration(tpDuration) })}{" "}
          <strong>{t("tp.countHintStrong", { n: tpDays.size * cyclesForDuration(tpDuration) })}</strong>
        </div>
      )}

      <button
        className="roll-btn compact"
        onClick={createDayPlans}
        disabled={!activeCategories || activeCategories.length === 0 || tpDays.size === 0}
      >
        <Dice5 size={16} /> {t("tp.rollPlans")}
      </button>

      {dayPlans && (
        <>
          <div className="section-label">
            {t("tp.tapDay", { cycles: `${cyclesForDuration(tpDuration)} ` })}
          </div>
          <div className="tp-day-list">
            {sortWeekdays(tpDays).map((day) => renderDay(day, dayPlans[day] || [], null))}
          </div>
          <button className="remix-btn" onClick={createDayPlans}>
            <RotateCcw size={14} /> {t("tp.rollAgain")}
          </button>
          {isPremium ? (
            <button className="save-btn tp-start-btn" onClick={startPlan} disabled={tpDays.size === 0}>
              <Dumbbell size={15} /> {t("tp.start")}
            </button>
          ) : (
            <PremiumGate feature={t("pro.feature.start")} onGetPro={onGetPro} />
          )}
        </>
      )}
      {status && <div className="save-status">{status}</div>}
      {favorites.status && <div className="save-status">{favorites.status}</div>}
    </>
  );
}
