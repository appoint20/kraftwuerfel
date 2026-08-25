# KRAFTWÜRFEL

Native SwiftUI-Trainings-App für iPhone und Apple Watch, zweisprachig (Deutsch/Englisch).

**Kostenlos:** Split wählen, Plan würfeln, Sätze/Wiederholungen/Pausen anpassen, einzelne
Übungen neu würfeln, Live-Session mit Pausen-Timer.

**Pro:** KI-Coach, Pläne speichern, Trainingspläne starten und verfolgen, Favoriten.

## Aufbau

Drei Ziele in einem Projekt:

| Ziel | Produkt | Wozu |
|---|---|---|
| `Kraftwuerfel` | iOS-App | Die App selbst |
| `KraftwuerfelWidget` | Widget-Erweiterung | Sperrbildschirm-Karte & Dynamic Island (Live Activity) |
| `KraftwuerfelWatch` | watchOS-App | Pulsmessung, Satzsteuerung am Handgelenk, HKWorkoutSession |

```
Kraftwuerfel/           App-Quellen
  Models/               Datentypen und Plan-Erzeugung
  Services/             Zustand, Persistenz, Systemanbindung
  Theme/                Farben, Schriften, Übersetzungen
  Views/                Bildschirme
  Shared/               Typen, die auch andere Ziele übersetzen
KraftwuerfelWidget/     Live Activity
KraftwuerfelWatch/      Uhren-App
Tools/                  Projektdatei-Generator
```

Mindestversionen: iOS 16.2, watchOS 10.0.

## Bauen

```bash
open Kraftwuerfel.xcodeproj
```

Ein voller Build braucht die installierte watchOS-Plattform (Xcode → Settings → Components).
Ohne sie bricht schon der Asset-Schritt des Uhren-Ziels ab.

## Projektdatei ändern

`project.pbxproj` wird **erzeugt**, nicht von Hand gepflegt. Nach dem Anlegen, Umbenennen oder
Löschen einer Datei:

```bash
python3 Tools/generate_xcodeproj.py
```

Welche Datei in welches Ziel geht, steht oben in `Tools/generate_xcodeproj.py`. Wichtig ist vor
allem `SHARED_WITH_WIDGET`: `WorkoutActivityAttributes.swift` muss in App **und** Erweiterung
übersetzt werden — ActivityKit gleicht den Typ über den Namen ab, und ohne beidseitige Quelle
bleibt der Sperrbildschirm leer.

## Tests

```bash
xcodebuild test -project Kraftwuerfel.xcodeproj -scheme Kraftwuerfel \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

55 Zusicherungen in `KraftwuerfelTests/`: Katalog und Splits, Plan-Erzeugung,
Satzschemata, Fokus-Methoden, Zyklus-Progression, Wochentagsrechnung, Rufnamen,
Serialisierung und die Umwandlung der Server-Antwort. Portierung der
Vitest-Suite der abgelösten Web-App — die Zusicherungen sind dieselben.

### Gegen den echten Dienst prüfen

Die Tests in `LiveBackendTests` sprechen mit `kraftwuerfel-api.onrender.com` und
werden normalerweise übersprungen — ein schlafender Dienst soll die Suite nicht
rot färben. Zum Prüfen der Anbindung:

```bash
TEST_RUNNER_KRAFT_LIVE_API=1 xcodebuild test -project Kraftwuerfel.xcodeproj \
  -scheme Kraftwuerfel -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:KraftwuerfelTests/LiveBackendTests
```

Das Präfix `TEST_RUNNER_` ist nötig — ohne es kommt die Variable nicht im
Testträger an.

## Backend

Die App spricht mit `https://kraftwuerfel-api.onrender.com`:

| Endpunkt | Zweck | Auth |
|---|---|---|
| `GET /health` | Aufwärm-Ping (freier Plan schläft ein) | — |
| `GET /exercises` | Übungskatalog, überschreibt die eingebaute Liste | — |
| `POST /generate-plan` | KI-Plan | Supabase-Token |

Der Dienst liegt in einem eigenen Repository. Ohne Netz oder Token bleibt die App voll
benutzbar: der Katalog fällt auf `ExerciseDatabase.bundled` zurück, der KI-Coach auf die lokale
Erzeugung in `AICoachService`.

## Anmeldung einrichten

Ohne Konto läuft die App vollständig, der KI-Coach rechnet dann lokal. Für die
Server-Pläne braucht es zwei Werte in `Kraftwuerfel/Info.plist`:

```
KWSupabaseURL       https://<projekt>.supabase.co
KWSupabaseAnonKey   <anon-Schlüssel aus Project Settings → API>
```

Solange sie leer sind, sagt der Anmeldebildschirm das offen an. Das Zugriffstoken
liegt im Schlüsselbund, nicht in UserDefaults.

## Impressum und Datenschutz

Beides steht in `Kraftwuerfel/Views/Settings/LegalView.swift`. Die Angaben zum
Betreiber sind **Platzhalter in spitzen Klammern** — solange einer davon steht,
blendet die App oben einen Warnhinweis ein. Vor der Einreichung ausfüllen.

## Gesundheitsdaten

Kurz, weil es in der App-Prüfung zählt:

- Die **Uhr misst** (`HKWorkoutSession`) und schreibt das fertige Training nach Apple Health.
- Das **iPhone liest höchstens mit** und schreibt nie.
- Ohne Uhr zeigt die Live-Session einen **gerechneten** Puls, überall sichtbar als
  „geschätzt“ ausgewiesen — in der App und auf dem Sperrbildschirm.

Geschätzte Werte gehen weder nach Apple Health noch als Messwert auf eine Karte.

## Offene Punkte vor dem Store

Siehe [docs/go-live-report.html](docs/go-live-report.html).
