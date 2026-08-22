#!/bin/sh
# Läuft bei jedem Containerstart, bevor nginx hochkommt (nginx' eigenes
# Entrypoint führt alles in /docker-entrypoint.d aus).
#
# Zwei Aufgaben:
#   1. Den Port aus der Umgebung in die nginx-Konfiguration schreiben (Render
#      gibt ihn vor und er kann sich pro Deploy ändern).
#   2. Die Laufzeit-Konfiguration der App erzeugen, damit dasselbe Image mit
#      unterschiedlichen Supabase-Projekten laufen kann.
set -eu

: "${PORT:=8080}"

TEMPLATE=/etc/nginx/kraftwuerfel.conf.template
CONF=/etc/nginx/conf.d/default.conf

# Immer aus dem unveränderten Template erzeugen — so bleibt ein Neustart mit
# anderem Port korrekt.
sed "s/__PORT__/${PORT}/g" "$TEMPLATE" > "$CONF"

# Werte landen in einer JS-Datei, also müssen Anführungszeichen und
# Backslashes escaped werden.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

ENV_FILE=/usr/share/nginx/html/env.js
cat > "$ENV_FILE" <<EOF
window.__KRAFTWUERFEL_ENV__ = {
  "VITE_SUPABASE_URL": "$(json_escape "${VITE_SUPABASE_URL:-}")",
  "VITE_SUPABASE_ANON_KEY": "$(json_escape "${VITE_SUPABASE_ANON_KEY:-}")",
  "VITE_LOCAL_ROLE": "$(json_escape "${VITE_LOCAL_ROLE:-}")"
};
EOF

if [ -z "${VITE_SUPABASE_URL:-}" ] || [ -z "${VITE_SUPABASE_ANON_KEY:-}" ]; then
  echo "kraftwuerfel: WARNUNG — VITE_SUPABASE_URL oder VITE_SUPABASE_ANON_KEY fehlt." >&2
  echo "kraftwuerfel: Die App startet im lokalen Modus: keine Anmeldung, kein KI-Coach," >&2
  echo "kraftwuerfel: Pläne bleiben im Browser des Besuchers." >&2
fi

echo "kraftwuerfel: nginx auf Port ${PORT}, Supabase ${VITE_SUPABASE_URL:-<nicht gesetzt>}"
