import { Component } from "react";
import { useI18n } from "../lib/i18n.jsx";

function CrashScreen({ message }) {
  const { t } = useI18n();
  return (
    <div className="crash-screen">
      <div className="crash-card">
        <div className="crash-title">{t("crash.title")}</div>
        <div className="crash-text">{t("crash.text")}</div>
        <div className="crash-detail">{message}</div>
        <button className="auth-submit" onClick={() => window.location.reload()}>
          {t("crash.reload")}
        </button>
      </div>
    </div>
  );
}

export default class ErrorBoundary extends Component {
  state = { error: null };

  static getDerivedStateFromError(error) {
    return { error };
  }

  render() {
    if (!this.state.error) return this.props.children;
    return <CrashScreen message={this.state.error.message} />;
  }
}
