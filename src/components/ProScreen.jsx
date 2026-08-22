import { useState } from "react";
import { ArrowLeft, Check, Sparkles } from "lucide-react";
import { supabase } from "../lib/supabase.js";
import { useI18n } from "../lib/i18n.jsx";
import { useAuth } from "../lib/auth.jsx";
import LogoIcon from "./LogoIcon.jsx";

const BENEFITS = ["proScreen.benefit.ai", "proScreen.benefit.save", "proScreen.benefit.plans", "proScreen.benefit.sync"];

export default function ProScreen({ onClose }) {
  const { t } = useI18n();
  const { isAuthenticated } = useAuth();
  const [mode, setMode] = useState("signup");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    setNotice("");
    const fn = mode === "login" ? supabase.auth.signInWithPassword : supabase.auth.signUp;
    const { data, error: authError } = await fn.call(supabase.auth, { email, password });
    setBusy(false);
    if (authError) {
      setError(authError.message);
      return;
    }
    if (mode === "signup" && !data.session) {
      setNotice(t("proScreen.confirmMail"));
      return;
    }
    onClose();
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

        {isAuthenticated ? (
          <div className="pro-pending">
            <Sparkles size={16} />
            <span>{t("pro.notUnlocked")}</span>
          </div>
        ) : (
          <form onSubmit={submit}>
            <div className="auth-title">{t(mode === "login" ? "proScreen.signIn" : "proScreen.signUp")}</div>

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
