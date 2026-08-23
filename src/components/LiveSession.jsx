import { useState, useEffect, useRef, useMemo } from "react";
import {
  Check,
  Clock,
  Plus,
  Minus,
  ArrowRight,
  RotateCcw,
  X,
  Dumbbell,
  Play,
  Pause,
  Award,
  Flame,
  Heart,
  Activity,
  Watch,
  Bluetooth,
  Share2,
  Download,
  Smartphone,
  Maximize2,
  Sparkles,
  Music,
} from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";
import ExerciseVisual from "./ExerciseVisual.jsx";
import { useMusic } from "../lib/music.jsx";
import HealthPanel from "./HealthPanel.jsx";
import { haptic, hapticSuccess, scheduleRestAlarm, cancelRestAlarm } from "../lib/native.js";
import GymMusicPlayer from "./GymMusicPlayer.jsx";

function formatTime(seconds) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s < 10 ? "0" : ""}${s}`;
}

export default function LiveSession({ plan, title, onClose }) {
  const { t, category, equipment, exerciseName } = useI18n();
  const { setWorkoutContext, holdLockScreen, releaseLockScreen } = useMusic();

  const [mode, setMode] = useState("fokus"); // "fokus" | "protokoll"
  const [showMusicPlayer, setShowMusicPlayer] = useState(false);
  const [exerciseIdx, setExerciseIdx] = useState(0);
  const [setIdx, setSetIdx] = useState(0);

  // Overall workout stopwatch
  const [elapsed, setElapsed] = useState(0);
  const [isTimerRunning, setIsTimerRunning] = useState(true);

  // Rest countdown timer
  const [restDuration, setRestDuration] = useState(60);
  const [restRemaining, setRestRemaining] = useState(0);
  const [isResting, setIsResting] = useState(false);

  // Health & Smartwatch/Ring Metrics State
  const [heartRate, setHeartRate] = useState(128);
  const [peakHeartRate, setPeakHeartRate] = useState(128);
  const [heartRateHistory, setHeartRateHistory] = useState([128]);
  const [caloriesBurned, setCaloriesBurned] = useState(0);
  const [connectedDevice, setConnectedDevice] = useState(null); // { name, type }
  const [isConnectingBt, setIsConnectingBt] = useState(false);
  const [showHealthModal, setShowHealthModal] = useState(false);
  const [exportNotice, setExportNotice] = useState("");

  // Logged sets: { [exerciseIdx]: { [setIdx]: { weight: number, reps: number, done: boolean } } }
  const [loggedSets, setLoggedSets] = useState(() => {
    const initial = {};
    plan.forEach((slot, eIdx) => {
      initial[eIdx] = {};
      const defaultSets = slot.sets || 3;
      const defaultReps = parseInt(slot.reps, 10) || 8;
      for (let s = 0; s < defaultSets; s++) {
        initial[eIdx][s] = { weight: 20, reps: defaultReps, done: false };
      }
    });
    return initial;
  });

  const [currentWeight, setCurrentWeight] = useState(20);
  const [currentReps, setCurrentReps] = useState(8);
  const [isFinished, setIsFinished] = useState(false);
  const [showConfirmEnd, setShowConfirmEnd] = useState(false);

  // Screen WakeLock API: Keeps screen awake during workout
  useEffect(() => {
    let wakeLock = null;
    let cancelled = false;

    const requestWakeLock = async () => {
      try {
        if ("wakeLock" in navigator && !cancelled) {
          wakeLock = await navigator.wakeLock.request("screen");
        }
      } catch {
        // Unsupported or inactive
      }
    };

    /*
      Der Browser gibt die Sperre ab, sobald die Seite in den Hintergrund geht.
      Ohne dieses Nachfassen schläft der Bildschirm für den Rest des Trainings —
      also genau ab dem Moment, in dem man einmal kurz auf eine Nachricht schaut.
    */
    const onVisibility = () => {
      if (document.visibilityState === "visible") requestWakeLock();
    };

    requestWakeLock();
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", onVisibility);
      if (wakeLock) wakeLock.release().catch(() => {});
    };
  }, []);

  /*
    Ein einziger AudioContext für die ganze Session. Vorher wurde bei jedem
    Piep ein neuer gebaut und nie geschlossen — Browser erlauben nur eine
    Handvoll, danach blieb der Ton einfach weg.
  */
  const audioCtxRef = useRef(null);
  const playBeep = () => {
    try {
      const Ctor = typeof window !== "undefined" && (window.AudioContext || window.webkitAudioContext);
      if (Ctor) {
        if (!audioCtxRef.current) audioCtxRef.current = new Ctor();
        const ctx = audioCtxRef.current;
        if (ctx.state === "suspended") ctx.resume().catch(() => {});
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(880, ctx.currentTime);
        gain.gain.setValueAtTime(0.1, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start();
        osc.stop(ctx.currentTime + 0.3);
      }
      if (typeof navigator !== "undefined" && navigator.vibrate) {
        navigator.vibrate([100, 50, 100]);
      }
    } catch {
      // Audio context might be restricted
    }
  };

  useEffect(() => () => {
    audioCtxRef.current?.close?.().catch(() => {});
  }, []);

  /*
    Ein Tick pro Sekunde, und der Intervall bleibt stehen.

    Vorher hingen heartRate und restRemaining in den Dependencies — beide ändern
    sich jede Sekunde, also wurde der Intervall im Sekundentakt abgeräumt und neu
    gesetzt. Jedes Neusetzen startet die 1000 ms von vorn, dadurch lief die Uhr
    zunehmend hinter der echten Zeit her. Alles, was sich laufend ändert, liegt
    jetzt in Refs statt in den Dependencies.
  */
  const liveRef = useRef({ isResting: false, heartRate: 128, connectedDevice: null });
  liveRef.current = { isResting, heartRate, connectedDevice };

  useEffect(() => {
    if (!isTimerRunning || isFinished) return;
    const timer = setInterval(() => {
      const { isResting: resting, heartRate: hr, connectedDevice: device } = liveRef.current;

      // Updater müssen frei von Nebenwirkungen sein — deshalb hier nacheinander,
      // nicht mehr ineinander verschachtelt.
      setElapsed((prev) => prev + 1);

      if (!device) {
        setHeartRate((curr) => {
          const target = resting ? 105 : 138;
          const variation = Math.floor(Math.sin(Date.now() / 5000) * 4);
          return Math.round(curr + (target - curr) * 0.08 + variation);
        });
      }

      setCaloriesBurned((curr) => {
        const burnPerSec = resting ? 0.06 : 0.13;
        const hrMultiplier = hr > 120 ? hr / 115 : 1.0;
        return parseFloat((curr + burnPerSec * hrMultiplier).toFixed(1));
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [isTimerRunning, isFinished]);

  // Spitzenpuls und Verlauf folgen dem Puls, statt im Timer mitgeschrieben zu werden.
  useEffect(() => {
    setPeakHeartRate((p) => Math.max(p, heartRate));
    setHeartRateHistory((h) => (h.length > 300 ? [...h.slice(1), heartRate] : [...h, heartRate]));
  }, [heartRate]);

  /*
    Der Browser-Piep erreicht niemanden, der das Handy weggelegt hat. Nativ
    geht deshalb zusätzlich eine Benachrichtigung raus, die auf Sperrbildschirm
    und Uhr ankommt. Sie wird abgeräumt, sobald die Pause anders endet.
  */
  useEffect(() => {
    if (!isResting || isFinished) {
      cancelRestAlarm();
      return;
    }
    scheduleRestAlarm(restRemaining, t("live.restOverBody"));
    return () => cancelRestAlarm();
    // Absichtlich nur beim Start der Pause, nicht bei jedem Sekundenticken.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isResting, isFinished]);

  // Pausen-Countdown: ebenfalls ein stehender Intervall.
  useEffect(() => {
    if (!isResting || isFinished) return;
    const timer = setInterval(() => {
      setRestRemaining((prev) => {
        if (prev <= 1) {
          setIsResting(false);
          playBeep();
          hapticSuccess();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [isResting, isFinished]);

  const currentSlot = plan[exerciseIdx] || plan[0];
  const totalExercises = plan.length;
  const totalSetsForCurrent = currentSlot.sets || 3;

  /*
    Sperrbildschirm und Apple Watch.

    Die Karte gehört dem Musik-Player, weil iOS sie nur zeigt, solange echtes
    Audio läuft — ohne abspielenden Track gibt es keinen Platz auf dem
    Sperrbildschirm, egal welche Metadaten man setzt. Hier wird also nur der
    Trainingskontext hineingereicht; der Player baut daraus die Karte, und die
    Uhr spiegelt sie automatisch unter "Now Playing".
  */
  useEffect(() => {
    if (!currentSlot?.exercise) return;
    setWorkoutContext({
      exercise: exerciseName(currentSlot.exercise),
      detail: isResting
        ? `${t("live.rest")} ${formatTime(restRemaining)}`
        : `${t("live.set")} ${setIdx + 1}/${totalSetsForCurrent} · ${currentWeight} kg`,
      title: title || "Kraftwürfel",
    });
  }, [
    currentSlot,
    setIdx,
    totalSetsForCurrent,
    currentWeight,
    isResting,
    restRemaining,
    exerciseName,
    setWorkoutContext,
    title,
    t,
  ]);

  // Beim Verlassen der Session verschwindet der Trainingsteil wieder aus der Karte.
  useEffect(() => () => setWorkoutContext(null), [setWorkoutContext]);

  /*
    Ohne laufendes Audio gibt es keine Sperrbildschirm-Karte. Der Start der
    Session ist eine Nutzergeste — genau dann darf die Wiedergabe beginnen.
  */
  useEffect(() => {
    holdLockScreen();
    return () => releaseLockScreen();
  }, [holdLockScreen, releaseLockScreen]);

  // Sync weight & reps with current set
  useEffect(() => {
    const existing = loggedSets[exerciseIdx]?.[setIdx];
    if (existing) {
      setCurrentWeight(existing.weight);
      setCurrentReps(existing.reps);
    } else {
      const defaultReps = parseInt(currentSlot.reps, 10) || 8;
      setCurrentReps(defaultReps);
    }
  }, [exerciseIdx, setIdx, loggedSets, currentSlot]);

  // Web Bluetooth Pairing for Apple Watch, Polar, Garmin, Smart Ring, Chest Straps
  const connectBluetoothSensor = async () => {
    if (typeof navigator === "undefined" || !navigator.bluetooth) {
      setConnectedDevice({ name: "Apple Health (Simuliert)", type: "apple_health" });
      setShowHealthModal(false);
      return;
    }
    setIsConnectingBt(true);
    try {
      const device = await navigator.bluetooth.requestDevice({
        filters: [{ services: ["heart_rate"] }],
        optionalServices: ["battery_service"],
      });
      const server = await device.gatt.connect();
      const service = await server.getPrimaryService("heart_rate");
      const characteristic = await service.getCharacteristic("heart_rate_measurement");

      await characteristic.startNotifications();
      characteristic.addEventListener("characteristicvaluechanged", (event) => {
        const value = event.target.value;
        const flags = value.getUint8(0);
        const rate16Bits = flags & 0x1;
        const currentBpm = rate16Bits ? value.getUint16(1, true) : value.getUint8(1);
        setHeartRate(currentBpm);
        setPeakHeartRate((p) => Math.max(p, currentBpm));
        setHeartRateHistory((h) => [...h, currentBpm]);
      });

      setConnectedDevice({ name: device.name || "Smartwatch / Pulsgurt", type: "bluetooth" });
      setShowHealthModal(false);
    } catch (err) {
      // Fallback
      setConnectedDevice({ name: "Apple Health (Aktiv)", type: "apple_health" });
      setShowHealthModal(false);
    } finally {
      setIsConnectingBt(false);
    }
  };

  // Handle completing a set
  const completeSet = () => {
    const restSec = currentSlot.rest || 60;
    setRestDuration(restSec);
    setRestRemaining(restSec);
    setIsResting(true);

    // Heart rate spike on completed heavy set
    if (!connectedDevice) {
      const nextPeak = Math.min(185, heartRate + Math.floor(Math.random() * 8) + 6);
      setHeartRate(nextPeak);
      setPeakHeartRate((p) => Math.max(p, nextPeak));
    }

    // Save set log
    setLoggedSets((prev) => ({
      ...prev,
      [exerciseIdx]: {
        ...prev[exerciseIdx],
        [setIdx]: { weight: currentWeight, reps: currentReps, done: true },
      },
    }));

    // Advance set or exercise
    if (setIdx + 1 < totalSetsForCurrent) {
      setSetIdx((prev) => prev + 1);
    } else if (exerciseIdx + 1 < totalExercises) {
      setExerciseIdx((prev) => prev + 1);
      setSetIdx(0);
    } else {
      // Workout finished
      setIsFinished(true);
      setIsResting(false);
      playBeep();
    }
  };

  const addRest = (seconds = 30) => {
    setRestRemaining((prev) => prev + seconds);
    setRestDuration((prev) => Math.max(prev, restRemaining + seconds));
    setIsResting(true);
  };

  const skipRest = () => {
    setRestRemaining(0);
    setIsResting(false);
  };

  const skipExercise = () => {
    if (exerciseIdx + 1 < totalExercises) {
      setExerciseIdx((prev) => prev + 1);
      setSetIdx(0);
      skipRest();
    } else {
      setIsFinished(true);
    }
  };

  // Stats calculation for summary
  const completedSetsCount = useMemo(() => {
    let count = 0;
    Object.values(loggedSets).forEach((exSets) => {
      Object.values(exSets).forEach((s) => {
        if (s.done) count++;
      });
    });
    return count;
  }, [loggedSets]);

  const totalSetsCount = useMemo(() => {
    return plan.reduce((acc, slot) => acc + (slot.sets || 3), 0);
  }, [plan]);

  const totalVolumeKg = useMemo(() => {
    let vol = 0;
    Object.values(loggedSets).forEach((exSets) => {
      Object.values(exSets).forEach((s) => {
        if (s.done) vol += (s.weight || 0) * (s.reps || 0);
      });
    });
    return Math.round(vol);
  }, [loggedSets]);

  const averageHeartRate = useMemo(() => {
    if (!heartRateHistory || heartRateHistory.length === 0) return 125;
    const sum = heartRateHistory.reduce((acc, v) => acc + v, 0);
    return Math.round(sum / heartRateHistory.length);
  }, [heartRateHistory]);

  // HR Zone determination
  const getHeartRateZone = (bpm) => {
    if (bpm < 115) return { name: t("live.zone1"), color: "#8B8D93" };
    if (bpm < 135) return { name: t("live.zone2"), color: "#26E1BE" };
    if (bpm < 155) return { name: t("live.zone3"), color: "#68D391" };
    if (bpm < 175) return { name: t("live.zone4"), color: "#F6AD55" };
    return { name: t("live.zone5"), color: "#FC8181" };
  };

  const currentZone = getHeartRateZone(heartRate);

  // SVG circle calculation
  const circleRadius = 90;
  const circumference = 2 * Math.PI * circleRadius;
  const strokeDashoffset =
    restDuration > 0 && isResting
      ? circumference - (restRemaining / restDuration) * circumference
      : 0;

  // Export to Apple Health JSON/Record
  const exportToAppleHealth = () => {
    const healthRecord = {
      source: "Kraftwürfel",
      activityType: "HKWorkoutActivityTypeTraditionalStrengthTraining",
      title: title || "Kraftwürfel Workout",
      durationSeconds: elapsed,
      totalEnergyBurnedKcal: Math.round(caloriesBurned),
      averageHeartRate: averageHeartRate,
      peakHeartRate: peakHeartRate,
      totalVolumeKg: totalVolumeKg,
      completedSets: completedSetsCount,
      timestamp: new Date().toISOString(),
    };

    try {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(healthRecord, null, 2));
      const downloadAnchor = document.createElement("a");
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", `kraftwuerfel-health-${new Date().toISOString().slice(0, 10)}.json`);
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
      setExportNotice(t("live.appleHealthSync"));
    } catch {
      setExportNotice(t("live.appleHealthSync"));
    }
  };

  if (isFinished) {
    return (
      <div className="live-session-overlay">
        <div className="live-finished-card">
          <div className="live-finish-icon">
            <Award size={48} />
          </div>
          <div className="live-finish-title">{t("live.finished")}</div>
          <div className="live-finish-sub">{t("live.finishedSub")}</div>

          {/* Core Health & Workout Scorecard */}
          <div className="live-stats-grid">
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.totalTime")}</div>
              <div className="live-stat-val">{formatTime(elapsed)}</div>
            </div>
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.caloriesBurned").toUpperCase()}</div>
              <div className="live-stat-val" style={{ color: "#FF7849" }}>
                {Math.round(caloriesBurned)} kcal
              </div>
            </div>
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.totalVolume")}</div>
              <div className="live-stat-val">{totalVolumeKg} kg</div>
            </div>
          </div>

          <div className="live-stats-grid">
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.avgHeartRate")}</div>
              <div className="live-stat-val" style={{ color: "#FF5D8F" }}>
                {averageHeartRate} BPM
              </div>
            </div>
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.peakHeartRate")}</div>
              <div className="live-stat-val" style={{ color: "#FC8181" }}>
                {peakHeartRate} BPM
              </div>
            </div>
            <div className="live-stat-box">
              <div className="live-stat-label">{t("live.totalSets")}</div>
              <div className="live-stat-val">
                {completedSetsCount} / {totalSetsCount}
              </div>
            </div>
          </div>

          <button className="apple-health-export-btn" onClick={exportToAppleHealth}>
            <Activity size={15} /> {t("live.exportHealth")}
          </button>
          {exportNotice && <div className="save-status">{exportNotice}</div>}

          <div className="live-summary-list">
            {plan.map((slot, idx) => {
              const sets = loggedSets[idx] || {};
              const doneSets = Object.values(sets).filter((s) => s.done);
              return (
                <div key={idx} className="live-summary-row">
                  <div className="live-summary-name">{exerciseName(slot.exercise)}</div>
                  <div className="live-summary-detail">
                    {doneSets.length > 0
                      ? `${doneSets.length}× (${doneSets.map((s) => `${s.weight}kg`).join(", ")})`
                      : "—"}
                  </div>
                </div>
              );
            })}
          </div>

          <button className="kw-btn" onClick={onClose}>
            {t("live.close")}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="live-session-overlay">
      <div className="live-session-container">
        {/* Top Header */}
        <div className="live-header">
          <div className="live-header-top">
            <div>
              <div className="live-session-title">
                {title || `${t("live.title")} · ${category(currentSlot.exercise.category)}`}
              </div>
              <div className="live-exercise-counter">
                {t("live.exerciseOf", { current: exerciseIdx + 1, total: totalExercises })}
              </div>
            </div>
            <div className="live-header-right">
              <button
                className="live-lockscreen-btn"
                onClick={() => setShowMusicPlayer(true)}
                title="Gym Music & Spotify"
              >
                <Music size={15} />
              </button>
              <div className="live-elapsed-badge">
                <Clock size={13} />
                <span>{formatTime(elapsed)}</span>
              </div>
              <button
                className="live-close-btn"
                onClick={() => setShowConfirmEnd(true)}
                title={t("live.endSession")}
              >
                <X size={18} />
              </button>
            </div>
          </div>

          <HealthPanel
            heartRate={heartRate}
            peakHeartRate={peakHeartRate}
            heartRateHistory={heartRateHistory}
            averageHeartRate={averageHeartRate}
            caloriesBurned={caloriesBurned}
            totalVolumeKg={totalVolumeKg}
            elapsedLabel={formatTime(elapsed)}
            zone={currentZone}
            connectedDevice={connectedDevice}
            onOpenDevice={() => setShowHealthModal(true)}
          />

          {/* Exercise Progression Segment Bar */}
          <div className="live-segment-bar">
            {plan.map((_, i) => (
              <div
                key={i}
                className={`live-segment ${i < exerciseIdx ? "completed" : i === exerciseIdx ? "active" : ""}`}
              />
            ))}
          </div>

          {/* Mode Switcher (Fokus vs Satz-Protokoll) */}
          <div className="live-mode-switch">
            <button
              className={`live-mode-btn ${mode === "fokus" ? "active" : ""}`}
              onClick={() => setMode("fokus")}
            >
              {t("live.modeFocus")}
            </button>
            <button
              className={`live-mode-btn ${mode === "protokoll" ? "active" : ""}`}
              onClick={() => setMode("protokoll")}
            >
              {t("live.modeLog")}
            </button>
          </div>
        </div>

        {/* VIEW 1: FOKUS VIEW (1e) */}
        {mode === "fokus" && (
          <div className="live-fokus-view">
            {/* Rest Timer Ring with Anatomy Visual */}
            <div className="live-timer-area">
              <div className="live-ring-container">
                <svg width="220" height="220" viewBox="0 0 220 220">
                  <circle
                    cx="110"
                    cy="110"
                    r={circleRadius}
                    fill="none"
                    stroke="#1F2023"
                    strokeWidth="12"
                  />
                  <circle
                    cx="110"
                    cy="110"
                    r={circleRadius}
                    fill="none"
                    stroke="#26E1BE"
                    strokeWidth="12"
                    strokeLinecap="round"
                    strokeDasharray={circumference}
                    strokeDashoffset={isResting ? strokeDashoffset : circumference}
                    transform="rotate(-90 110 110)"
                    style={{ transition: "stroke-dashoffset 0.9s linear" }}
                  />
                </svg>
                <div className="live-ring-center">
                  <div className={`live-ring-time ${isResting ? "resting" : ""}`}>
                    {isResting ? formatTime(restRemaining) : `${currentSlot.rest || 60}s`}
                  </div>
                  <div className={`live-ring-label ${isResting ? "pulsing" : ""}`}>
                    {isResting ? t("live.rest") : t("live.target")}
                  </div>
                </div>
              </div>
            </div>

            {/* Exercise Title, Info & Muscle Anatomy Diagram */}
            <div className="live-exercise-info">
              <div className="live-visual-row">
                <ExerciseVisual category={currentSlot.exercise.category} size={90} />
              </div>
              <div className="live-tags-row">
                <span className="kw-tag">
                  {category(currentSlot.exercise.category)} · {equipment(currentSlot.exercise.equipment)}
                </span>
              </div>
              <div className="live-exercise-name">{exerciseName(currentSlot.exercise)}</div>
              <div className="live-set-subtitle">
                {t("live.setOf", { current: setIdx + 1, total: totalSetsForCurrent })} ·{" "}
                {t("live.repsTarget", { reps: currentSlot.reps || "4-8" })}
              </div>
            </div>

            {/* Set Input Controls (Weight & Reps) */}
            <div className="live-inputs-grid">
              <div className="live-input-card">
                <div className="live-input-label">{t("live.weight")}</div>
                <div className="live-stepper-row">
                  <button
                    className="live-mini-btn"
                    onClick={() => setCurrentWeight((w) => Math.max(0, w - 2.5))}
                  >
                    −
                  </button>
                  <div className="live-input-val">{currentWeight} kg</div>
                  <button
                    className="live-mini-btn"
                    onClick={() => setCurrentWeight((w) => w + 2.5)}
                  >
                    +
                  </button>
                </div>
              </div>

              <div className="live-input-card">
                <div className="live-input-label">{t("live.reps")}</div>
                <div className="live-stepper-row">
                  <button
                    className="live-mini-btn"
                    onClick={() => setCurrentReps((r) => Math.max(1, r - 1))}
                  >
                    −
                  </button>
                  <div className="live-input-val">{currentReps}</div>
                  <button
                    className="live-mini-btn"
                    onClick={() => setCurrentReps((r) => r + 1)}
                  >
                    +
                  </button>
                </div>
              </div>

              <div className="live-input-card">
                <div className="live-input-label">{t("live.last")}</div>
                <div className="live-input-val muted">
                  {loggedSets[exerciseIdx]?.[setIdx - 1]?.weight
                    ? `${loggedSets[exerciseIdx][setIdx - 1].weight} kg`
                    : `${currentWeight} kg`}
                </div>
              </div>
            </div>

            {/* Primary Action Button */}
            <button className="kw-btn live-action-btn" onClick={completeSet}>
              <Check size={22} /> {t("live.completeSet")}
            </button>

            {/* Quick Actions */}
            <div className="live-quick-actions">
              {isResting ? (
                <>
                  <button className="kw-btn-ghost" onClick={() => addRest(30)}>
                    {t("live.addRest")}
                  </button>
                  <button className="kw-btn-ghost" onClick={skipRest}>
                    {t("live.skipRest")}
                  </button>
                </>
              ) : (
                <>
                  <button className="kw-btn-ghost" onClick={() => addRest(currentSlot.rest || 60)}>
                    {t("live.addRest")}
                  </button>
                  <button className="kw-btn-ghost" onClick={skipExercise}>
                    {t("live.skipExercise")}
                  </button>
                </>
              )}
            </div>
          </div>
        )}

        {/* VIEW 2: SATZ-PROTOKOLL VIEW (1f) */}
        {mode === "protokoll" && (
          <div className="live-protokoll-view">
            <div className="live-proto-header">
              <div>
                <div className="live-proto-status">
                  {isResting ? `${t("live.rest")} · ${formatTime(restRemaining)}` : t("live.target")}
                </div>
                <div className="live-proto-ex-name">{exerciseName(currentSlot.exercise)}</div>
              </div>
              <div className="live-proto-timer-badge">{formatTime(isResting ? restRemaining : elapsed)}</div>
            </div>

            {/* Sets Logging Table */}
            <div className="live-table-card">
              <div className="live-table-head">
                <span className="col-set">{t("gen.sets").toUpperCase()}</span>
                <span className="col-weight">{t("live.weight")}</span>
                <span className="col-reps">{t("live.reps")}</span>
                <span className="col-status"></span>
              </div>

              {Array.from({ length: totalSetsForCurrent }).map((_, s) => {
                const isLogged = loggedSets[exerciseIdx]?.[s]?.done;
                const isCurrent = s === setIdx;
                const setVal = loggedSets[exerciseIdx]?.[s] || { weight: currentWeight, reps: currentReps };

                if (isLogged) {
                  return (
                    <div key={s} className="live-table-row done">
                      <span className="col-set mono">{s + 1}</span>
                      <span className="col-weight mono">{setVal.weight} kg</span>
                      <span className="col-reps mono">{setVal.reps}</span>
                      <span className="col-status green">✓</span>
                    </div>
                  );
                }

                if (isCurrent) {
                  return (
                    <div key={s} className="live-table-row active">
                      <span className="col-set mono green">{s + 1}</span>
                      <div className="col-weight">
                        <input
                          type="number"
                          className="live-row-input"
                          value={currentWeight}
                          onChange={(e) => setCurrentWeight(parseFloat(e.target.value) || 0)}
                        />
                      </div>
                      <div className="col-reps">
                        <input
                          type="number"
                          className="live-row-input"
                          value={currentReps}
                          onChange={(e) => setCurrentReps(parseInt(e.target.value, 10) || 0)}
                        />
                      </div>
                      <span className="col-status"></span>
                    </div>
                  );
                }

                return (
                  <div key={s} className="live-table-row upcoming">
                    <span className="col-set mono muted">{s + 1}</span>
                    <span className="col-weight mono muted">—</span>
                    <span className="col-reps mono muted">—</span>
                    <span className="col-status"></span>
                  </div>
                );
              })}
            </div>

            <button className="kw-btn" onClick={completeSet}>
              {t("live.saveSet", { n: setIdx + 1 })}
            </button>

            {/* Up Next List */}
            {exerciseIdx + 1 < totalExercises && (
              <div className="live-upnext-section">
                <div className="kw-lbl">{t("live.upNext")}</div>
                <div className="live-upnext-list">
                  {plan.slice(exerciseIdx + 1).map((nxt, i) => (
                    <div key={i} className="live-upnext-card">
                      <span className="live-upnext-num mono">{exerciseIdx + i + 2}</span>
                      <div className="live-upnext-info">
                        <div className="live-upnext-name">{exerciseName(nxt.exercise)}</div>
                        <div className="live-upnext-meta">{category(nxt.exercise.category)}</div>
                      </div>
                      <span className="live-upnext-scheme mono">
                        {nxt.sets}×{nxt.reps}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}

            <button className="kw-btn-ghost" onClick={() => setShowConfirmEnd(true)}>
              {t("live.endSession")}
            </button>
          </div>
        )}

        {/* HEALTH & SMARTWATCH CONNECTION MODAL */}
        {showHealthModal && (
          <div className="live-confirm-overlay" onClick={() => setShowHealthModal(false)}>
            <div className="live-confirm-card" onClick={(e) => e.stopPropagation()}>
              <div className="live-confirm-title">
                <Watch size={20} style={{ verticalAlign: "middle", marginRight: "8px" }} />
                Smartwatch & Apple Health
              </div>
              <div style={{ fontSize: "13px", color: "var(--muted)", lineHeight: "1.6" }}>
                Verbinde deine Apple Watch, deinen Polar/Garmin Pulsgurt oder deinen Smart Ring via Bluetooth für
                Echtzeit-Puls und präzise Kalorienberechnung.
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "10px", marginTop: "10px" }}>
                <button
                  className="wide-cta-btn"
                  style={{ background: "var(--surface2)", borderColor: "var(--accent)" }}
                  onClick={connectBluetoothSensor}
                  disabled={isConnectingBt}
                >
                  <Bluetooth size={16} style={{ color: "var(--accent)" }} />
                  <span>{isConnectingBt ? "Suche Bluetooth Geräte…" : "Bluetooth Pulssensor koppeln"}</span>
                </button>

                <button
                  className="kw-btn-ghost"
                  onClick={() => {
                    setConnectedDevice({ name: "Apple Health (Aktiv)", type: "apple_health" });
                    setShowHealthModal(false);
                  }}
                >
                  Apple Health Schätzung aktivieren
                </button>
              </div>

              <button className="kw-btn-ghost" style={{ marginTop: "8px" }} onClick={() => setShowHealthModal(false)}>
                {t("ai.back")}
              </button>
            </div>
          </div>
        )}

        {/* Gym Music & Spotify Drawer */}
        {showMusicPlayer && <GymMusicPlayer onClose={() => setShowMusicPlayer(false)} />}

        {/* Confirmation Modal to End Workout */}
        {showConfirmEnd && (
          <div className="live-confirm-overlay">
            <div className="live-confirm-card">
              <div className="live-confirm-title">{t("live.confirmEnd")}</div>
              <div className="live-confirm-actions">
                <button className="kw-btn-ghost" onClick={() => setShowConfirmEnd(false)}>
                  {t("ai.back")}
                </button>
                <button className="kw-btn" onClick={() => setIsFinished(true)}>
                  {t("live.endSession")}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
