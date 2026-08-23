import { useState } from "react";
import { ArrowLeft, Check, Sparkles, ShieldCheck, Zap, User, ToggleLeft, ToggleRight } from "lucide-react";
import { supabase } from "../lib/supabase.js";
import { useI18n } from "../lib/i18n.jsx";
import { useAuth } from "../lib/auth.jsx";
import LogoIcon from "./LogoIcon.jsx";

const BENEFITS = [
  "proScreen.benefit.ai",
  "proScreen.benefit.save",
  "proScreen.benefit.plans",
  "proScreen.benefit.sync",
];

export default function ProScreen({ onClose }) {
  const { t } = useI18n();
  const { user, userName, isAuthenticated, isPremium, canSignIn, syncEntitlement, updateUserName } = useAuth();

  const [mode, setMode] = useState("signup");
  const [name, setName] = useState(userName || "");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [selectedPlan, setSelectedPlan] = useState("monthly"); // "monthly" | "yearly"

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [upgraded, setUpgraded] = useState(false);

  // Authentication submit (Sign In / Sign Up)
  const submit = async (e) => {
    e.preventDefault();
    /*
      Ohne Zugangsdaten gibt es keinen Client — supabase ist dann null. Vorher
      lief das direkt in "null is not an object (supabase.auth)", weil dieser
      Bildschirm über die Live-Session auch ohne Backend erreichbar wurde.
    */
    if (!canSignIn || !supabase) {
      setError(t("proScreen.noBackend"));
      return;
    }
    setBusy(true);
    setError("");
    setNotice("");

    const redirectTo =
      typeof window !== "undefined" ? window.location.origin : "https://kraftwuerfel.onrender.com";

    try {
      if (mode === "login") {
        const { data, error: authError } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (authError) throw authError;
      } else {
        const { data, error: authError } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              name: name.trim() || email.split("@")[0],
            },
            emailRedirectTo: redirectTo,
          },
        });
        if (authError) throw authError;
        if (!data.session) {
          setNotice(t("proScreen.confirmMail"));
          setBusy(false);
          return;
        }
      }
      setBusy(false);
      /*
        Nach dem Anmelden gehört man in die App, nicht auf eine Seite, die einem
        erklärt, was man gerade gekauft hat. Vorher blieb hier die Vorteilsliste
        stehen und man musste selbst zurücknavigieren.
      */
      onClose();
    } catch (err) {
      setBusy(false);
      setError(err.message || "Authentifizierungsfehler");
    }
  };

  /*
    Es gibt hier absichtlich keinen Knopf, der Pro freischaltet. Freischalten
    kann nur das Backend: die Testliste in der Edge Function sync-entitlement
    oder später ein Webhook des Zahlungsanbieters. Ein früherer Stand hat Pro
    direkt aus dem Browser gesetzt — auch dann, wenn die Zahlung abgebrochen
    wurde, und ohne dass je Geld geflossen ist.
  */
  const handleCheckout = () => {
    setNotice(t("proScreen.checkoutPending"));
  };

  // Falls das Konto auf der Testliste steht, holt das die Freischaltung ab.
  const handleRefresh = async () => {
    setBusy(true);
    setNotice("");
    const ok = await syncEntitlement();
    setBusy(false);
    if (ok) {
      onClose();
    } else {
      setNotice(t("proScreen.noEntitlement"));
    }
  };

  return (
    <div className="auth-screen">
      <div className="auth-card">
        <button className="auth-back" type="button" onClick={onClose}>
          <ArrowLeft size={14} /> {t("proScreen.back")}
        </button>

        <div className="auth-brand">
          <div className="brand-icon">
            <LogoIcon size={26} />
          </div>
          <div>
            <div className="brand-title">{t("proScreen.headline")}</div>
            <div className="brand-sub">{t("proScreen.pitch")}</div>
          </div>
        </div>

        <ul className="pro-benefits">
          {BENEFITS.map((key) => (
            <li key={key}>
              <Check size={14} />
              <span>{t(key)}</span>
            </li>
          ))}
        </ul>

        {upgraded ? (
          <div className="pro-success-box">
            <Sparkles size={28} className="pro-success-icon" />
            <div className="pro-success-title">{t("proScreen.upgradeSuccess")}</div>
            <button className="kw-btn" style={{ marginTop: "12px" }} onClick={onClose}>
              {t("proScreen.back")}
            </button>
          </div>
        ) : !canSignIn ? (
          /* Ohne Server gibt es kein Konto — kein Formular anbieten, das nicht
             funktionieren kann. */
          <div className="pro-pending">
            <Sparkles size={16} />
            <span>{t("proScreen.noBackend")}</span>
          </div>
        ) : isAuthenticated ? (
          /* AUTHENTICATED: SHOW MEMBERSHIP SELECTION */
          <div className="pro-payment-section">
            {userName && (
              <div className="pro-user-greeting">
                👋 Hallo <strong>{userName}</strong> ({user.email})
              </div>
            )}

            {!isPremium && <div className="auth-title">{t("proScreen.choosePlan")}</div>}

            {!isPremium && (
              <div className="pro-plans-grid">
                <div
                  className={`pro-plan-card ${selectedPlan === "monthly" ? "active" : ""}`}
                  onClick={() => setSelectedPlan("monthly")}
                >
                  <div className="pro-plan-header">
                    <div className="pro-plan-name">{t("proScreen.monthlyPlan")}</div>
                    <div className="pro-plan-price">{t("proScreen.monthlyPrice")}</div>
                  </div>
                  <div className="pro-plan-sub">{t("proScreen.monthlySub")}</div>
                </div>

                <div
                  className={`pro-plan-card ${selectedPlan === "yearly" ? "active" : ""}`}
                  onClick={() => setSelectedPlan("yearly")}
                >
                  <div className="pro-plan-badge">SPART 33%</div>
                  <div className="pro-plan-header">
                    <div className="pro-plan-name">{t("proScreen.yearlyPlan")}</div>
                    <div className="pro-plan-price">{t("proScreen.yearlyPrice")}</div>
                  </div>
                  <div className="pro-plan-sub">{t("proScreen.yearlySub")}</div>
                </div>
              </div>
            )}

            {isPremium ? (
              <div className="pro-active-box">
                <ShieldCheck size={16} />
                <span>{t("proScreen.alreadyPro")}</span>
              </div>
            ) : (
              <>
                <button className="auth-submit" type="button" onClick={handleCheckout}>
                  {t("proScreen.payNow")}
                </button>

                <button className="auth-switch" type="button" onClick={handleRefresh} disabled={busy}>
                  {busy ? "…" : t("proScreen.checkAccess")}
                </button>
              </>
            )}

            {error && <div className="auth-error">{error}</div>}
            {notice && <div className="save-status">{notice}</div>}
          </div>
        ) : (
          /* NOT AUTHENTICATED: SHOW SIGN IN / SIGN UP FORM */
          <form onSubmit={submit}>
            <div className="auth-title">
              {t(mode === "login" ? "proScreen.signIn" : "proScreen.signUp")}
            </div>

            {mode === "signup" && (
              <div className="auth-field">
                <label htmlFor="auth-name">Dein Vorname / Name</label>
                <input
                  id="auth-name"
                  type="text"
                  placeholder="z. B. Alex"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
            )}

            <div className="auth-field">
              <label htmlFor="auth-email">{t("proScreen.email")}</label>
              <input
                id="auth-email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>

            <div className="auth-field">
              <label htmlFor="auth-password">{t("proScreen.password")}</label>
              <input
                id="auth-password"
                type="password"
                autoComplete={mode === "login" ? "current-password" : "new-password"}
                required
                minLength={6}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            <button className="auth-submit" type="submit" disabled={busy}>
              {busy ? "…" : t(mode === "login" ? "proScreen.submitSignIn" : "proScreen.submitSignUp")}
            </button>

            <button
              className="auth-switch"
              type="button"
              onClick={() => {
                setMode(mode === "login" ? "signup" : "login");
                setError("");
                setNotice("");
              }}
            >
              {t(mode === "login" ? "proScreen.toSignUp" : "proScreen.toSignIn")}
            </button>

            {error && <div className="auth-error">{error}</div>}
            {notice && <div className="save-status">{notice}</div>}
          </form>
        )}
      </div>
    </div>
  );
}
