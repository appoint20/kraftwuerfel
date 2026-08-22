import { Heart, Play } from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";
import CycleBlock from "./CycleBlock.jsx";

export default function DayBlock({
  day,
  cyclePlans,
  currentCycleIdx,
  isOpen,
  onToggle,
  onFavorite,
  justSaved,
  canFavorite,
  onStartLiveTraining,
}) {
  const { t, weekday } = useI18n();

  return (
    <div className="tp-day-block">
      <div className="tp-day-toggle-row">
        <button className="tp-day-toggle" onClick={onToggle}>
          <span className="tp-day-toggle-label">{weekday(day)}</span>
          <span className="tp-day-toggle-count">
            {t(cyclePlans.length === 1 ? "tp.planCount" : "tp.plansCount", { n: cyclePlans.length })}
          </span>
          <span className="tp-day-toggle-chevron">{isOpen ? "▲" : "▼"}</span>
        </button>
        <div style={{ display: "flex", gap: "6px" }}>
          {onStartLiveTraining && cyclePlans.length > 0 && (
            <button
              className="tp-fav-btn"
              onClick={() => {
                const targetCycle = currentCycleIdx != null && cyclePlans[currentCycleIdx]
                  ? cyclePlans[currentCycleIdx]
                  : cyclePlans[0];
                onStartLiveTraining(targetCycle, `${weekday(day)} · ${t("tp.cycleLabel", { n: (currentCycleIdx || 0) + 1 })}`);
              }}
              title={t("live.startTraining")}
              style={{ color: "var(--accent)" }}
            >
              <Play size={15} fill="currentColor" />
            </button>
          )}
          {canFavorite && (
            <button
              className={`tp-fav-btn ${justSaved ? "saved" : ""}`}
              onClick={() => onFavorite(day, cyclePlans)}
              title={t("tp.favorite")}
            >
              <Heart size={15} fill={justSaved ? "currentColor" : "none"} />
            </button>
          )}
        </div>
      </div>
      {isOpen && (
        <div className="tp-day-cycles">
          {cyclePlans.map((slots, idx) => (
            <CycleBlock
              key={`${day}-${idx}`}
              label={t("tp.cycleLabel", { n: idx + 1 })}
              slots={slots}
              isCurrent={currentCycleIdx === idx}
              onStartLiveTraining={onStartLiveTraining}
              dayName={weekday(day)}
            />
          ))}

          <div className="tp-day-actions-row">
            {canFavorite && (
              <button
                className={`tp-day-fav-btn ${justSaved ? "saved" : ""}`}
                onClick={() => onFavorite(day, cyclePlans)}
              >
                <Heart size={14} fill={justSaved ? "currentColor" : "none"} />
                <span>{justSaved ? "✓ Favorisiert" : "♡ Als Favorit speichern"}</span>
              </button>
            )}
            {onStartLiveTraining && cyclePlans.length > 0 && (
              <button
                className="tp-day-start-btn"
                onClick={() => {
                  const targetCycle = currentCycleIdx != null && cyclePlans[currentCycleIdx]
                    ? cyclePlans[currentCycleIdx]
                    : cyclePlans[0];
                  onStartLiveTraining(targetCycle, `${weekday(day)} · ${t("tp.cycleLabel", { n: (currentCycleIdx || 0) + 1 })}`);
                }}
              >
                <Play size={14} fill="currentColor" />
                <span>{t("live.startTraining")}</span>
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
