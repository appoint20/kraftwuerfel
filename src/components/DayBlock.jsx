import { Heart } from "lucide-react";
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
      {isOpen && (
        <div className="tp-day-cycles">
          {cyclePlans.map((slots, idx) => (
            <CycleBlock
              key={`${day}-${idx}`}
              label={t("tp.cycleLabel", { n: idx + 1 })}
              slots={slots}
              isCurrent={currentCycleIdx === idx}
            />
          ))}
        </div>
      )}
    </div>
  );
}
