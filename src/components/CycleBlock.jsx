import { useI18n } from "../lib/i18n.jsx";

export default function CycleBlock({ label, slots, isCurrent }) {
  const { t, category, equipment } = useI18n();

  return (
    <div className={`tp-cycle-block ${isCurrent ? "current" : ""}`}>
      {label && (
        <div className="tp-cycle-header">
          <span className="tp-cycle-label">{label}</span>
          {isCurrent && <span className="tp-cycle-now">{t("tp.current")}</span>}
        </div>
      )}
      <div className="tp-rows">
        {slots.map((s, i) => (
          <div className="tp-row" key={i}>
            <div className="tp-row-main">
              <span className="tp-row-name">{s.exercise.name}</span>
              <span className="tp-row-cat">
                {category(s.exercise.category)}
                {s.note ? ` · ${s.note}` : ""}
              </span>
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
