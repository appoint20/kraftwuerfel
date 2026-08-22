import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App.jsx";
import { AuthProvider } from "./lib/auth.jsx";
import { I18nProvider } from "./lib/i18n.jsx";
import { MusicProvider } from "./lib/music.jsx";
import ErrorBoundary from "./components/ErrorBoundary.jsx";
import "./styles/app.css";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <I18nProvider>
      <ErrorBoundary>
        <AuthProvider>
          <MusicProvider>
            <App />
          </MusicProvider>
        </AuthProvider>
      </ErrorBoundary>
    </I18nProvider>
  </StrictMode>
);
