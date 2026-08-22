import { Sparkles } from "lucide-react";
import { useAuth } from "../lib/auth.jsx";
import { useI18n } from "../lib/i18n.jsx";

/*
  Zeigt an, warum etwas gesperrt ist, und bietet den nächsten Schritt an.
  Wer schon angemeldet, aber nicht freigeschaltet ist, sieht keinen Button.
*/
export default function PremiumGate({ feature, onGetPro }) {
  const { isAuthenticated, canSignIn } = useAuth();
  const { t } = useI18n();

  return (
    <div className="premium-gate">
      <div className="premium-gate-head">
        <Sparkles size={14} />
        <span>{t("pro.badge")}</span>
      </div>
      <div className="premium-gate-text">{t("pro.gateText", { feature })}</div>
      {canSignIn &&
        (isAuthenticated ? (
          <div className="premium-gate-hint">{t("pro.notUnlocked")}</div>
        ) : (
          <button className="premium-gate-btn" onClick={onGetPro}>
            {t("pro.cta")}
          </button>
        ))}
    </div>
  );
}
