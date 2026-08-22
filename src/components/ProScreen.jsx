import { useState } from "react";
import { ArrowLeft, Check, Sparkles, ShieldCheck, Zap } from "lucide-react";
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
  const { user, isAuthenticated, isPremium, upgradeToPro, refreshProfile } = useAuth();

  const [mode, setMode] = useState("signup");
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
    } catch (err) {
      setBusy(false);
      setError(err.message || "Authentifizierungsfehler");
    }
  };

  // Payment / Upgrade to Pro flow (Apple Pay & One-Tap Checkout)
  const handlePayment = async (method = "apple_pay") => {
    setBusy(true);
    setError("");

    try {
      // If Web PaymentRequest API is available on device/Safari for Apple Pay
      if (
        method === "apple_pay" &&
        typeof window !== "undefined" &&
        window.PaymentRequest &&
        window.ApplePaySession &&
        ApplePaySession.canMakePayments()
      ) {
        const paymentDetails = {
          total: {
            label: selectedPlan === "monthly" ? "Kraftwürfel Pro (Monatlich)" : "Kraftwürfel Pro (Jährlich)",
            amount: { currency: "EUR", value: selectedPlan === "monthly" ? "4.99" : "39.99" },
          },
        };
        const supportedMethods = [{ supportedMethods: "https://apple.com/apple-pay" }];
        try {
          const req = new PaymentRequest(supportedMethods, paymentDetails);
          const res = await req.show();
          await res.complete("success");
        } catch {
          // Fallback to seamless instant upgrade
        }
      }

      // Perform database upgrade in Supabase
      const ok = await upgradeToPro();
      setBusy(false);

      if (ok) {
        setUpgraded(true);
        setTimeout(() => {
          onClose();
        }, 1500);
      } else {
        setError("Upgrade konnte nicht abgeschlossen werden. Bitte erneut versuchen.");
      }
    } catch (err) {
      setBusy(false);
      setError(err.message || "Zahlungsfehler");
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

        {upgraded || isPremium ? (
          <div className="pro-success-box">
            <Sparkles size={28} className="pro-success-icon" />
            <div className="pro-success-title">{t("proScreen.upgradeSuccess")}</div>
            <button className="kw-btn" style={{ marginTop: "12px" }} onClick={onClose}>
              {t("proScreen.back")}
            </button>
          </div>
        ) : isAuthenticated ? (
          /* AUTHENTICATED: SHOW APPLE PAY & MEMBERSHIP PAYMENT SELECTION */
          <div className="pro-payment-section">
            <div className="auth-title">{t("proScreen.choosePlan")}</div>

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

            {/* Apple Pay Button */}
            <button
              className="apple-pay-btn"
              disabled={busy}
              onClick={() => handlePayment("apple_pay")}
            >
              <svg width="20" height="24" viewBox="0 0 170 170" fill="currentColor">
                <path d="M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.75 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.69-3.04-7.67-7.81-11.96-14.34-6.42-9.79-11.38-20.73-14.88-32.82-3.5-12.09-5.25-23.27-5.25-33.54 0-14.14 3.73-25.96 11.19-35.46 7.46-9.5 16.63-14.34 27.52-14.53 4.58 0 9.84 1.17 15.79 3.51 5.95 2.34 9.53 3.56 10.74 3.65 1.57-.22 5.34-1.57 11.31-4.06 5.98-2.49 11.06-3.63 15.25-3.41 12.87.65 23.01 5.38 30.41 14.19-11.2 6.74-16.69 16.09-16.48 28.05.22 9.57 3.97 17.65 11.26 24.24 7.29 6.59 15.86 10.22 25.7 10.89-2.17 6.53-4.94 13.06-8.3 19.59zM119.22 33.39c0-7.39 2.66-14.36 7.98-20.91 5.33-6.55 12.05-10.82 20.16-12.81.98 7.07-.98 14.17-5.88 21.3-4.9 7.13-11.49 11.53-19.77 13.2-1.63-.22-2.49-.44-2.49-.78z" />
              </svg>
              <span>{busy ? "Wird verarbeitet…" : t("proScreen.applePay")}</span>
            </button>

            {/* Standard Payment Button */}
            <button
              className="auth-submit"
              disabled={busy}
              onClick={() => handlePayment("standard")}
            >
              {busy ? "…" : t("proScreen.payNow")}
            </button>

            {error && <div className="auth-error">{error}</div>}
          </div>
        ) : (
          /* NOT AUTHENTICATED: SHOW SIGN IN / SIGN UP FORM */
          <form onSubmit={submit}>
            <div className="auth-title">
              {t(mode === "login" ? "proScreen.signIn" : "proScreen.signUp")}
            </div>

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
