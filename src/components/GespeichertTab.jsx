import { useState } from "react";
import { Shuffle, X, Play, ChevronDown, ChevronUp } from "lucide-react";
import { METHODS } from "../data/exercises.js";
import { deserializeSlots } from "../lib/planLogic.js";
import { useI18n } from "../lib/i18n.jsx";
import CycleBlock from "./CycleBlock.jsx";

export default function GespeichertTab({ saved, onLoad, onStartLiveTraining }) {
  const { t, locale } = useI18n();
  const { plans, loading, remove } = saved;
  // Aufgeklappt wird immer nur ein Plan — sonst scrollt man ewig.
  const [openId, setOpenId] = useState(null);

  return (
    <>
      <div className="section-label">{t("saved.title")}</div>
      {loading ? (
        <div className="empty">{t("common.loading")}</div>
      ) : plans.length === 0 ? (
        <div className="empty">
          {t("saved.empty")}
          <br />
          {t("saved.emptyHint")}
        </div>
      ) : (
        plans.map((sp) => {
          const isOpen = openId === sp.id;
          const slots = deserializeSlots(sp.items);
          return (
            <div className="saved-card" key={sp.id}>
              {/* Die ganze Kopfzeile klappt auf — vorher stand hier nur
                  "6 Übungen" und man kam nicht an die Übungen heran. */}
              <button className="saved-card-toggle" onClick={() => setOpenId(isOpen ? null : sp.id)}>
                <div>
                  <div className="saved-name">{sp.name}</div>
                  <div className="saved-meta">
                    {t("saved.exercises", { n: sp.items.length })} ·{" "}
                    {METHODS.find((m) => m.id === sp.method)?.label || "Standard"} ·{" "}
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
      )}
    </>
  );
}
