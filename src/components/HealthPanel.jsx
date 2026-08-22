import { Flame, Heart, Dumbbell, Watch, Timer, Info } from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";

/*
  Die Werte während des Trainings.

  Der Puls ist die Zahl, auf die man zwischen zwei Sätzen schaut — der bekommt
  deshalb die große Fläche und eine Verlaufskurve, damit man sieht, ob man sich
  gerade erholt oder noch oben ist. Alles andere ist Nebeninformation und steht
  klein darunter.

  Wichtig: solange kein Sensor gekoppelt ist, sind Puls und Kalorien geschätzt.
  Das steht auch so da. Gesundheitszahlen sind der falsche Ort für "sieht aus
  wie gemessen".
*/

function Sparkline({ values, color }) {
  if (!values || values.length < 2) return null;

  const width = 100;
  const height = 28;
  const recent = values.slice(-60);
  const min = Math.min(...recent);
  const max = Math.max(...recent);
  const span = Math.max(1, max - min);

  const points = recent
    .map((v, i) => {
      const x = (i / (recent.length - 1)) * width;
      const y = height - ((v - min) / span) * (height - 4) - 2;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const last = recent[recent.length - 1];
  const lastX = width;
  const lastY = height - ((last - min) / span) * (height - 4) - 2;

  return (
    <svg className="hp-spark" viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" aria-hidden="true">
      <polyline points={points} fill="none" stroke={color} strokeWidth="1.8" vectorEffect="non-scaling-stroke" />
      <circle cx={lastX} cy={lastY} r="2.4" fill={color} />
    </svg>
  );
}

export default function HealthPanel({
  heartRate,
  peakHeartRate,
  heartRateHistory,
  averageHeartRate,
  caloriesBurned,
  totalVolumeKg,
  elapsedLabel,
  zone,
  connectedDevice,
  onOpenDevice,
}) {
  const { t } = useI18n();
  const estimated = !connectedDevice;

  return (
    <div className="health-panel">
      <div className="hp-main">
        <div className="hp-hr">
          <div className="hp-hr-top">
            <Heart size={13} className="hp-heart" />
            <span className="hp-label">{t("live.heartRate")}</span>
            {estimated && <span className="hp-est">{t("live.estimated")}</span>}
          </div>
          <div className="hp-hr-value">
            <span className="hp-big">{heartRate}</span>
            <span className="hp-unit">BPM</span>
          </div>
          <div className="hp-zone" style={{ color: zone.color }}>
            <span className="hp-zone-dot" style={{ background: zone.color }} />
            {zone.name}
          </div>
        </div>

        <div className="hp-graph">
          <Sparkline values={heartRateHistory} color={zone.color} />
          <div className="hp-graph-meta">
            <span>
              {t("live.avg")} <strong>{averageHeartRate}</strong>
            </span>
            <span>
              {t("live.peak")} <strong>{peakHeartRate}</strong>
            </span>
          </div>
        </div>
      </div>

      <div className="hp-tiles">
        <div className="hp-tile">
          <Timer size={13} />
          <span className="hp-tile-val">{elapsedLabel}</span>
          <span className="hp-tile-label">{t("live.duration")}</span>
        </div>
        <div className="hp-tile">
          <Flame size={13} className="hp-flame" />
          <span className="hp-tile-val">{Math.round(caloriesBurned)}</span>
          <span className="hp-tile-label">{t("live.calories")}</span>
        </div>
        <div className="hp-tile">
          <Dumbbell size={13} />
          <span className="hp-tile-val">{totalVolumeKg}</span>
          <span className="hp-tile-label">{t("live.volume")}</span>
        </div>
      </div>

      <button className={`hp-device ${connectedDevice ? "active" : ""}`} onClick={onOpenDevice}>
        <Watch size={13} />
        <span>{connectedDevice ? connectedDevice.name : t("live.connectSensor")}</span>
      </button>

      {estimated && (
        <div className="hp-note">
          <Info size={12} />
          <span>{t("live.estimatedNote")}</span>
        </div>
      )}
    </div>
  );
}
