# KRAFTWÜRFEL

Native SwiftUI-Trainings-App für iPhone und Apple Watch, zweisprachig (Deutsch/Englisch).

**Konto erforderlich.** Seit der Anmeldeschranke (`RootView`) führt kein Weg an Registrierung
oder Anmeldung vorbei — Pläne, Fortschritt und das Pro-Abo hängen am Konto, nicht am Gerät.
Der Fragebogen danach ist überspringbar; gefragt wird dann dort, wo die Antworten
gebraucht werden.

**Kostenlos:** Split wählen, Plan würfeln, Sätze/Wiederholungen/Pausen anpassen, einzelne
Übungen neu würfeln, Live-Session mit Pausen-Timer, ein Lieblingstag, Trainingspläne
starten und verfolgen.

**Pro:** Die Grenze steht an genau einer Stelle im Code — `ProFeature` in
`Kraftwuerfel/Models/ProFeature.swift`. Die Sperren fragen sie ab, und die Verkaufsseite
zeigt dieselbe Liste, damit beide nicht auseinanderlaufen:

| Funktion | `ProFeature` |
|---|---|
| KI-Coach ohne belohnte Videos | `aiCoach` |
| Pläne & Meal Guides speichern | `savedPlans` |
| Trainingsarchiv im Fortschritt-Tab | `workoutHistory` |
| Planbewertung (`PlanQualityScore`) | `planScore` |
| Mehr als ein Lieblingstag | `unlimitedFavorites` |
| Keine Werbung | `noAds` |

Gesperrt wird das **Ansehen**, nicht das Aufzeichnen: Trainings und gespeicherte Pläne
bleiben liegen, wenn ein Abo ausläuft. Ein abgelaufenes Abo ist kein Grund, die Arbeit des
Nutzers wegzuwerfen — wer wieder abschließt, findet alles vor.

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

Rund 280 Tests in `KraftwuerfelTests/`: Katalog und Splits, Plan-Erzeugung,
Satzschemata, Zyklus-Progression, Wochentagsrechnung, Serialisierung, die
Umwandlung der Server-Antwort — und die Regeln, die sich nicht ansehen lassen:

- **Zeitrechnung der Live-Session** (`SessionTimingTests`): Die Trainingszeit
  kommt aus der Uhrzeit, nicht aus gezählten Takten. Ein gesperrter Bildschirm
  darf keine Minuten verschlucken.
- **Warteschlange der Übungen** (`LiveQueueTests`): Überspringen heißt später,
  nicht weg.
- **Anpassen des laufenden Plans** (`ActivePlanEditingTests`): Der letzte
  Übungsplatz bleibt, Zyklus 2 bleibt unberührt, Änderungen überleben den
  Neustart.
- **Erinnerungen** (`ReminderScheduleTests`): keine Erinnerung an einem Tag, an
  dem schon trainiert wurde.
- **Werbung** (`AdManagerTests`): echte Werbung oder gar keine — nie eine
  nachgebaute.

Die Zahl stand hier lange auf „55 Zusicherungen, Portierung der Vitest-Suite der
abgelösten Web-App". Beides stimmt nicht mehr; die Suite ist seither um ein
Vielfaches gewachsen und prüft Dinge, die es im Web nie gab.

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
| `POST /auth/register`, `/auth/login`, `/auth/refresh` | Konto und Sitzung | — |
| `POST /auth/recover`, `/auth/reset-password` | Passwort vergessen | — |
| `POST /auth/delete` | Konto und alle Serverdaten löschen | Bearer |
| `POST /subscriptions/verify`, `/subscriptions/clear` | StoreKit-2-Kauf prüfen | Bearer |
| `POST /generate-plan` | KI-Plan | Bearer (eigenes JWT) |
| `POST /challenge-plan` | Home-Challenge | Bearer (eigenes JWT) |

Der Dienst liegt in einem eigenen Repository. Ohne Netz bleibt die App benutzbar,
soweit sie ohne Server auskommt: der Katalog fällt auf `ExerciseDatabase.bundled`
zurück, der KI-Coach auf die lokale Erzeugung in `AICoachService`.

## Anmeldung

**Hier stand eine Anleitung für `KWSupabaseURL` und `KWSupabaseAnonKey` in der
Info.plist. Beides gibt es nicht mehr.** Die App spricht ausschließlich mit der
eigenen API (`/auth/*`), die Zugangsdaten für Datenbank und Mailversand kennt nur
der Server. In der App ist nichts zu konfigurieren.

Seit der Anmeldeschranke (`RootView`) ist ein Konto Pflicht — der frühere Satz
„ohne Konto läuft die App vollständig" gilt nicht mehr. Access- und Refresh-Token
liegen im Schlüsselbund, nicht in UserDefaults (die Schlüsselbund-Konten heißen
aus historischen Gründen noch `supabase.accessToken` / `supabase.refreshToken`).

## Screenshots für den App Store

```bash
python3 Tools/appstore_screenshots.py geraete
python3 Tools/appstore_screenshots.py starten "Kraft-6.5"
python3 Tools/appstore_screenshots.py aufnehmen 02-trainingsplan "Kraft-6.5"
python3 Tools/appstore_screenshots.py pruefen
```

`starten` baut die App, installiert sie auf genau diesem Simulator und startet
sie. Ohne diesen Schritt nimmt `aufnehmen` auf, was gerade zu sehen ist — auf
einem frisch angelegten Simulator ist das der Startbildschirm von iOS, und ein
Bild des Home-Bildschirms ist kein Screenshot der App.

Drei weitere Fallstricke, an denen der Upload scheitert — alle drei ohne brauchbare
Fehlermeldung in App Store Connect:

- **Alphakanal.** `xcrun simctl io booted screenshot` liefert PNGs mit
  Alphakanal, und die lehnt App Store Connect ab. Das Skript legt das Bild auf
  Schwarz und speichert ohne Kanal.
- **Maße.** Ein Bildschirmfoto des Simulator-*Fensters* (⇧⌘4) enthält
  Fensterrahmen und ist skaliert — es hat nie die exakte Pixelgröße. Nur die
  Aufnahme über `simctl` gibt echte Gerätepixel.
- **Der falsche Platz.** App Store Connect hat je Bildschirmgröße einen
  eigenen Platz, und die Fehlermeldung nennt nur die erwarteten Maße, nicht
  den Platz. „Mindestens ein Screenshot weist falsche Maße auf … 1242 × 2688px,
  1284 × 2778px" heißt: Du stehst im 6,5"-Platz und lädst ein 6,9"-Bild hoch.

Pflichtformat ist 6,9" (1320×2868, iPhone 16 Pro Max). Für den 6,5"-Platz
braucht es ein eigenes Gerät — `geraete` zeigt, was da ist, und nennt den
Befehl, mit dem sich eines anlegen lässt. `pruefen` geht alle erzeugten Bilder
durch und nennt jedes, das so nicht durchkommt.

## Impressum und Datenschutz

Beides steht in `Kraftwuerfel/Views/Settings/LegalView.swift`. Die Angaben zum
Betreiber (Name, Anschrift, Kontakt, Verantwortlicher, Umsatzsteuer) stehen als
Konstanten oben in der Datei und sind ausgefüllt — hier stand früher der Hinweis,
es seien Platzhalter, und dieser Hinweis war schlicht veraltet.

Der Datenschutztext beschreibt unter anderem den Apple-Health-Zugriff. Er muss
mitgezogen werden, sobald sich dort etwas ändert: Seit dem Schreibzugriff (Gewicht,
Körperfettanteil, abgeschlossene Trainings) genügt „liest die Herzfrequenz" nicht mehr.

## Gesundheitsdaten

Kurz, weil es in der App-Prüfung zählt:

- Die **Uhr misst** (`HKWorkoutSession`) und schreibt das fertige Training nach Apple Health.
- Das **iPhone liest höchstens mit** und schreibt nie.
- Ohne Uhr zeigt die Live-Session einen **gerechneten** Puls, überall sichtbar als
  „geschätzt“ ausgewiesen — in der App und auf dem Sperrbildschirm.

Geschätzte Werte gehen weder nach Apple Health noch als Messwert auf eine Karte.

## Offene Punkte vor dem Store

Siehe [docs/go-live-report.html](docs/go-live-report.html).
