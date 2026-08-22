// Laufzeit-Konfiguration. Im Dev-Betrieb absichtlich leer — dann gelten die
// Werte aus .env. Der Container überschreibt diese Datei beim Start
// (siehe docker/40-kraftwuerfel-env.sh).
window.__KRAFTWUERFEL_ENV__ = {};
