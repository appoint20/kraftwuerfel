import { useCallback, useEffect, useState } from "react";
import { LogOut, Sparkles } from "lucide-react";
import { SPLITS } from "./data/exercises.js";
import { buildPlan, rerollSlot, buildDayPlans, cyclesForDuration, deserializeSlots, deserializeDayPlans } from "./lib/planLogic.js";
import { sortWeekdays } from "./lib/dateUtils.js";
import { useAuth } from "./lib/auth.jsx";
import { useI18n } from "./lib/i18n.jsx";
import { isLocalMode } from "./lib/repository.js";
import useReel from "./hooks/useReel.js";
import useSavedPlans from "./hooks/useSavedPlans.js";
import useActivePlan from "./hooks/useActivePlan.js";
import useFavorites from "./hooks/useFavorites.js";
import { getDynamicGymGreeting } from "./lib/greetings.js";
import LogoIcon from "./components/LogoIcon.jsx";
import GeneratorTab from "./components/GeneratorTab.jsx";
import AiCoachTab from "./components/AiCoachTab.jsx";
import TrainingsplanTab from "./components/TrainingsplanTab.jsx";
import GespeichertTab from "./components/GespeichertTab.jsx";
import FavoritenTab from "./components/FavoritenTab.jsx";
import ProScreen from "./components/ProScreen.jsx";
import LiveSession from "./components/LiveSession.jsx";

const TABS = [
  ["generator", "tabs.generator"],
  ["ki", "tabs.ai"],
  ["trainingsplan", "tabs.trainingsplan"],
  ["gespeichert", "tabs.saved"],
  ["favoriten", "tabs.favorites"],
];

export default function App() {
  const { user, userName, isAuthenticated, isPremium, canSignIn, signOut, ready } = useAuth();
  const { t, lang, setLang } = useI18n();
  const [tab, setTab] = useState("generator");
  const [showPro, setShowPro] = useState(false);
  const [liveSession, setLiveSession] = useState(null);
  const [greetingQuote, setGreetingQuote] = useState(() => getDynamicGymGreeting(userName, lang));

  useEffect(() => {
    setGreetingQuote(getDynamicGymGreeting(userName, lang));
  }, [userName, lang]);

  const [split, setSplit] = useState("Ganzkörper");
  const [customCats, setCustomCats] = useState(new Set(["Brust", "Rücken"]));
  const [count, setCount] = useState(6);
  const [method, setMethod] = useState("standard");
  const [restTime, setRestTime] = useState(60);
  const [plan, setPlan] = useState([]);

  const [tpDays, setTpDays] = useState(new Set(["Mo", "Mi", "Fr"]));
  const [tpDuration, setTpDuration] = useState(4);
  const [dayPlans, setDayPlans] = useState(null);
  const [expandedDay, setExpandedDay] = useState(null);

  const reel = useReel();
  const saved = useSavedPlans();
  const active = useActivePlan();
  const favorites = useFavorites();

  const activeCategories = split === "Eigene" ? [...customCats] : SPLITS[split];

  const { reload: reloadSaved } = saved;
  const { reload: reloadActive } = active;
  const { reload: reloadFavorites } = favorites;

  // Ohne Konto gibt es nichts zu laden — anonyme Besucher würfeln nur.
  const canLoadData = isLocalMode || isAuthenticated;

  useEffect(() => {
    if (!canLoadData) return;
    if (tab === "gespeichert") reloadSaved();
    if (tab === "favoriten") reloadFavorites();
    if (tab === "trainingsplan") {
      reloadActive().then((loaded) => {
        if (!loaded) return;
        setDayPlans(deserializeDayPlans(loaded.dayPlans));
        setTpDays(new Set(loaded.days));
        setTpDuration(loaded.duration);
        setExpandedDay(loaded.days[0] || null);
      });
    }
  }, [tab, canLoadData, reloadSaved, reloadFavorites, reloadActive]);

  const generate = () => {
    if (!activeCategories || activeCategories.length === 0) return;
    const finalSlots = buildPlan(activeCategories, count, method, restTime);
    if (finalSlots.length === 0) return;
    setPlan(finalSlots);
    reel.runReel(finalSlots);
  };

  const reroll = (idx) => {
    const newSlot = rerollSlot(plan, idx, method);
    if (!newSlot) return;
    const newPlan = [...plan];
    newPlan[idx] = newSlot;
    setPlan(newPlan);
    reel.runReel(newPlan);
  };

  const updateSlot = (idx, changes) =>
    setPlan((prev) => prev.map((s, i) => (i === idx ? { ...s, ...changes } : s)));

  const loadSavedPlan = (savedPlan) => {
    setPlan(deserializeSlots(savedPlan.items));
    setMethod(savedPlan.method || "standard");
    setTab("generator");
  };

  const createDayPlans = () => {
    if (!activeCategories || activeCategories.length === 0) return;
    const days = sortWeekdays(tpDays);
    const result = buildDayPlans(days, cyclesForDuration(tpDuration), activeCategories, count, method, restTime);
    setDayPlans(result);
    setExpandedDay(days[0] || null);
  };

  const endActivePlan = useCallback(async () => {
    await active.end();
    setDayPlans(null);
  }, [active]);

  const toggleCustomCat = (cat) =>
    setCustomCats((prev) => {
      const n = new Set(prev);
      n.has(cat) ? n.delete(cat) : n.add(cat);
      return n;
    });

  const toggleTpDay = (day) =>
    setTpDays((prev) => {
      const n = new Set(prev);
      n.has(day) ? n.delete(day) : n.add(day);
      return n;
    });

  const startLiveTraining = (slotsToRun, sessionTitle) => {
    if (!slotsToRun || slotsToRun.length === 0) return;
    setLiveSession({ plan: slotsToRun, title: sessionTitle });
  };

  const settings = {
    split,
    setSplit,
    customCats,
    toggleCustomCat,
    count,
    setCount,
    method,
    setMethod,
    restTime,
    setRestTime,
    activeCategories,
  };

  if (!ready) return <div className="app" />;

  if (liveSession) {
    return (
      <LiveSession
        plan={liveSession.plan}
        title={liveSession.title}
        onClose={() => setLiveSession(null)}
      />
    );
  }

  if (showPro) return <ProScreen onClose={() => setShowPro(false)} />;

  const openPro = () => setShowPro(true);

  return (
    <div className="app">
      <div className="header">
        <div className="brand">
          <div className="brand-icon">
            <LogoIcon size={26} />
          </div>
          <div className="brand-text">
            <div className="brand-title">KRAFTWÜRFEL</div>
            <div className="brand-sub">{t("app.subtitle")}</div>
          </div>
          <div className="header-actions">
            <div className="lang-toggle">
              <button className={lang === "de" ? "active" : ""} onClick={() => setLang("de")}>
                DE
              </button>
              <button className={lang === "en" ? "active" : ""} onClick={() => setLang("en")}>
                EN
              </button>
            </div>
            {isAuthenticated ? (
              <button className="logout-btn" onClick={signOut} title={t("nav.signOut")}>
                <LogOut size={14} />
              </button>
            ) : (
              canSignIn && (
                <button className="pro-btn" onClick={openPro}>
                  <Sparkles size={13} />
                  <span className="pro-btn-label">{t("nav.getPro")}</span>
                </button>
              )
            )}
          </div>
        </div>

        {isAuthenticated && (
          <div className="account-greeting-bar">
            <span className="account-greeting" onClick={() => setGreetingQuote(getDynamicGymGreeting(userName, lang))} title="Tippen für neuen Motivations-Spruch" style={{ cursor: "pointer" }}>
              {greetingQuote}
            </span>
            <span className={`account-badge ${isPremium ? "pro" : "free"}`}>
              {isPremium ? "PRO" : "FREE"}
            </span>
            <button className="account-pro-manage-btn" onClick={openPro} title="Profil & Abo verwalten">
              ⚙️
            </button>
          </div>
        )}

        <div className="tabs">
          {TABS.map(([id, key]) => (
            <button key={id} className={`tab-btn ${tab === id ? "active" : ""}`} onClick={() => setTab(id)}>
              {t(key)}
              {id === "ki" && !isPremium && <span className="tab-pro-dot">PRO</span>}
            </button>
          ))}
        </div>
      </div>

      {isLocalMode && (
        <div className="local-mode-banner">
          <strong>{t("local.title")}</strong> {t("local.text")}
        </div>
      )}

      <div className="content">
        {tab === "generator" && (
          <GeneratorTab
            settings={settings}
            plan={plan}
            reel={reel}
            onGenerate={generate}
            onReroll={reroll}
            onUpdateSlot={updateSlot}
            saved={saved}
            onGetPro={openPro}
            onStartLiveTraining={startLiveTraining}
          />
        )}

        {tab === "ki" && (
          <AiCoachTab
            active={{ ...active, end: endActivePlan }}
            favorites={favorites}
            onGetPro={openPro}
            onStartLiveTraining={startLiveTraining}
          />
        )}

        {tab === "trainingsplan" && (
          <TrainingsplanTab
            settings={settings}
            tp={{
              tpDays,
              toggleTpDay,
              tpDuration,
              setTpDuration,
              dayPlans,
              createDayPlans,
              expandedDay,
              setExpandedDay,
            }}
            active={{ ...active, end: endActivePlan }}
            favorites={favorites}
            onGetPro={openPro}
            onStartLiveTraining={startLiveTraining}
          />
        )}

        {tab === "gespeichert" && <GespeichertTab saved={saved} onLoad={loadSavedPlan} onGetPro={openPro} />}

        {tab === "favoriten" && <FavoritenTab favorites={favorites} onGetPro={openPro} />}
      </div>
    </div>
  );
}
