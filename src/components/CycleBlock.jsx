import { Play } from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";
import ExerciseVisual from "./ExerciseVisual.jsx";

export default function CycleBlock({ label, slots, isCurrent, onStartLiveTraining, dayName }) {
  const { t, category, equipment, exerciseName } = useI18n();

  return (
    <div className={`tp-cycle-block ${isCurrent ? "current" : ""}`}>
      {label && (
        <div className="tp-cycle-header">
          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <span className="tp-cycle-label">{label}</span>
            {isCurrent && <span className="tp-cycle-now">{t("tp.current")}</span>}
          </div>
          {onStartLiveTraining && (
            <button
              className="tp-cycle-start-btn"
              onClick={(e) => {
                e.stopPropagation();
                onStartLiveTraining(slots, `${dayName ? `${dayName} · ` : ""}${label}`);
              }}
              title={t("live.startTraining")}
            >
              <Play size={12} fill="currentColor" /> {t("live.startTraining")}
            </button>
          )}
        </div>
      )}
      <div className="tp-rows">
        {slots.map((s, i) => (
          <div className="tp-row" key={i}>
            <div style={{ display: "flex", alignItems: "center", gap: "10px", flex: 1, minWidth: 0 }}>
              <ExerciseVisual category={s.exercise.category} size={34} compact />
              <div className="tp-row-main">
                <span className="tp-row-name">{exerciseName(s.exercise)}</span>
                <span className="tp-row-cat">
                  {category(s.exercise.category)}
                  {s.note ? ` · ${s.note}` : ""}
                </span>
              </div>
            </div>
            <div className="tp-row-right">
              <span className="tp-row-sets">
                {s.sets}×{s.reps}
              </span>
              <span className="db-equ">{equipment(s.exercise.equipment)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
