# Rechtliche Dokumentation: Impressum & Datenschutzerklärung

**App:** Kraftwuerfel  
**Betreiber:** appoint (Inhaber: Shiv Mehra)  
**Stand:** August 2026  

---

## 1. Impressum (§ 5 DDG & § 18 Abs. 2 MStV)

### Angaben gemäß § 5 DDG (Digitale-Dienste-Gesetz)
**Firma / Kleinunternehmen:** appoint  
**Inhaber:** Shiv Mehra  
**Anschrift:**  
Max-Liebermann-Str. 82  
14612 Falkensee  
Deutschland  

### Kontakt
**E-Mail:** appoint.20@gmail.com  
**Telefon:** +49 152 23024756  

### Verantwortlich für den Inhalt nach § 18 Abs. 2 MStV
Shiv Mehra  
Max-Liebermann-Str. 82  
14612 Falkensee  
Deutschland  

### Umsatzsteuer
Gemäß § 19 UStG (Kleinunternehmerregelung) wird keine Umsatzsteuer berechnet und nicht gesondert ausgewiesen.

### EU-Streitschlichtung & Verbraucherstreitbeilegung
Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit:  
https://ec.europa.eu/consumers/odr/  
Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.

### Haftungsausschluss & Gesundheitshinweis
Die von Kraftwuerfel und dem KI-Coach bereitgestellten Trainings- und Ernährungspläne sind allgemeine sportwissenschaftliche Empfehlungen und stellen keine medizinische, therapeutische oder ernährungsmedizinische Beratung dar. Die Durchführung der Übungen erfolgt auf eigene Verantwortung. Bei Vorerkrankungen, akuten Beschwerden oder körperlichen Einschränkungen sollte vor Beginn des Trainings ein Arzt konsultiert werden.

---

## 2. Datenschutzerklärung (Privacy Policy gemäß EU-DSGVO)

### 1. Verantwortlicher und Grundsätze
**Verantwortlicher für die Datenverarbeitung:**  
appoint (Inhaber: Shiv Mehra)  
Max-Liebermann-Str. 82, 14612 Falkensee, Deutschland  
E-Mail: appoint.20@gmail.com | Telefon: +49 152 23024756  

Die Kraftwuerfel-App und Backend-API folgen dem Prinzip der **Datensparsamkeit und Zweckbindung (Art. 5 DSGVO)**. Es werden ausschließlich Daten erhoben und verarbeitet, die für die Bereitstellung des Benutzerkontos, die Synchronisation des Pro-Status und die Generierung von Trainings- und Ernährungsplänen erforderlich sind.

Wir setzen **keine Tracking-Tools, keine Werbe-SDKs und keine Analyse-Cookies** ein.

---

### 2. Personenbezogene Daten & Anonyme Nutzung
Der Begriff der personenbezogenen Daten ist im Bundesdatenschutzgesetz (BDSG) und in der EU-DSGVO definiert. Danach sind dies Einzelangaben über persönliche oder sachliche Verhältnisse einer bestimmten oder bestimmbaren natürlichen Person (z. B. Name, E-Mail-Adresse, biometrische Trainings- und Ernährungsdaten).

Die Basisfunktionen der App (z. B. der lokale Trainingsplan-Würfel) können vollständig **ohne Angabe personenbezogener Daten** genutzt werden.

Beim Aufruf der App und der Kommunikation mit unserer Backend-API werden technisch erforderliche Zugriffsdaten in flüchtigen Server-Logfiles verarbeitet:

| Daten | Zweck der Verarbeitung | Rechtsgrundlage | Speicherdauer |
| :--- | :--- | :--- | :--- |
| **Verwendetes Betriebssystem (iOS-Version)** | Optimierte Darstellung und Systemkompatibilität | Art. 6 Abs. 1 lit. f DSGVO | Für die Dauer der Log-Aufbewahrung (max. 14 Tage) |
| **IP-Adresse** | Technische Bereitstellung der API-Inhalte, Abwehr von Cyberangriffen | Art. 6 Abs. 1 lit. f DSGVO | Bis zu 7 Tage in Sicherheits-Logs |
| **Datum und Uhrzeit des Aufrufs** | Bereitstellung, Lastverteilung & Fehleranalyse | Art. 6 Abs. 1 lit. f DSGVO | Für die Dauer der Log-Aufbewahrung |
| **Gerätemodell (iPhone/iPad) & App-Version** | Release-Kompatibilität und Fehlerbehebung | Art. 6 Abs. 1 lit. f DSGVO | Anonymisiert / aggregiert |

---

### 3. Benutzerkonto & Gespeicherte Datenbankfelder (PostgreSQL)
Alle persistenten Kontodaten werden in einer abgesicherten **PostgreSQL-Datenbank** (Hosting über Render Services, Inc. im Rechenzentrum Frankfurt am Main / EU) gespeichert:

#### Tabelle: `users` (Benutzerkonten)
| Feldname | Datentyp | Zweck der Verarbeitung | Rechtsgrundlage | Speicherdauer |
| :--- | :--- | :--- | :--- | :--- |
| `id` | UUID | Eindeutige interne Identifikationsnummer (Pseudonym) | Art. 6 Abs. 1 lit. b | Bis zur Kontolöschung |
| `email` | VARCHAR(255) | Benutzeridentifikation, Login, E-Mail-Kommunikation | Art. 6 Abs. 1 lit. b | Bis zur Kontolöschung |
| `password_hash` | VARCHAR(255) | Sichere Authentifizierung (BCrypt mit Work Factor 12) | Art. 6 Abs. 1 lit. b & f | Bis zur Kontolöschung |
| `is_premium` | BOOLEAN | Speichert den Pro-Status zur Funktionsfreischaltung | Art. 6 Abs. 1 lit. b | Bis zur Kontolöschung |
| `is_email_confirmed` | BOOLEAN | Verifizierung der E-Mail-Adresse (Spamschutz) | Art. 6 Abs. 1 lit. f | Bis zur Kontolöschung |
| `confirmation_token`| VARCHAR(255) | Einmal-Token zur Verifizierung der E-Mail | Art. 6 Abs. 1 lit. b | Nach Bestätigung gelöscht |
| `reset_token` | VARCHAR(255) | Einmal-Token für Passwort-Reset | Art. 6 Abs. 1 lit. b | Max. 24 Stunden |
| `reset_token_expires_at`| TIMESTAMPTZ | Ablaufzeitpunkt des Reset-Tokens | Art. 6 Abs. 1 lit. f | Nach Ablauf gelöscht |
| `created_at` / `updated_at` | TIMESTAMPTZ | Systemverwaltung und Missbrauchserkennung | Art. 6 Abs. 1 lit. f | Bis zur Kontolöschung |

#### Tabelle: `refresh_tokens` (Sitzungsverwaltung)
| Feldname | Datentyp | Zweck der Verarbeitung | Rechtsgrundlage | Speicherdauer |
| :--- | :--- | :--- | :--- | :--- |
| `id` / `user_id` | UUID | Sitzungs- und Kontozuordnung (ON DELETE CASCADE) | Art. 6 Abs. 1 lit. b | Bis zum Logout / Löschung |
| `token_hash` | VARCHAR(255) | SHA-256-Hash des Refresh-Tokens (Token nie im Klartext) | Art. 6 Abs. 1 lit. b & f | 30 Tage oder bis Logout |
| `expires_at` / `revoked_at` | TIMESTAMPTZ | Gültigkeitsdauer der Sitzung | Art. 6 Abs. 1 lit. b | Automatisch nach Ablauf |

---

### 4. Datenerhebung für den KI-Coach (Die 13 Fitnessparameter)
Für die Erstellung individueller Trainings- und Ernährungspläne erfassen wir im KI-Assistenten folgende 13 Parameter:

1. **Trainingsziel** (z. B. Muskelaufbau, Kraftaufbau, Fettabbau, Definition, Kraftausdauer)
2. **Trainingserfahrung** (Anfänger, Fortgeschritten, Profi)
3. **Biologisches Geschlecht** (Grundumsatz- und Physiologieberechnung)
4. **Alter** (Bestimmung von Regenerationszeiten und Satzpausen)
5. **Körpergewicht in kg** (Kalorien- und Proteinbedarfsberechnung)
6. **Körpergröße in cm** (BMI- und Energiebedarfsermittlung)
7. **Zielgewicht in kg** (Steuerung des Kaloriendefizits bzw. -überschusses)
8. **Trainingstage** (Wochentage zur Split-Periodisierung)
9. **Dauer pro Einheit in Minuten** (Volumen- und Übungsbegrenzung)
10. **Planlänge in Wochen** (Periodisierungsplanung über 4–12 Wochen)
11. **Trainingsmethode** (z. B. Standard, 5x5, Pyramidentraining, Drop-Sets)
12. **Verfügbares Equipment** (Filterung kompatibler Übungen)
13. **Ernährungsform** (Omnivor, Vegetarisch, Lakto-Vegetarisch, Vegan)

> **WICHTIG — Keine Speicherung in der Datenbank:**  
> Diese 13 Parameter werden weder in unserer PostgreSQL-Datenbank noch in Server-Logs persistent gespeichert. Die Verarbeitung erfolgt rein flüchtig im Arbeitsspeicher während der HTTP-Berechnungsanfrage.

- **Besondere Datenkategorie (Art. 9 DSGVO):** Diese Daten stellen im Fitnesskontext Gesundheitsdaten dar. Die Verarbeitung erfolgt auf Basis Deiner ausdrücklichen Einwilligung (**Art. 9 Abs. 2 lit. a DSGVO**).
- **KI-Inferenz (OpenRouter):** Die Parameter werden in anonymisierter Form (ohne Name oder E-Mail) über eine verschlüsselte Schnittstelle an OpenRouter Inc. (USA) übermittelt. Grundlage sind EU-Standardvertragsklauseln (Art. 46 DSGVO). Prompt-Daten werden gemäß den geltenden Richtlinien nicht für das Training öffentlicher KI-Modelle genutzt.

---

### 5. Eingesetzte Drittanbieter & Auftragsverarbeiter

| Dienst / Anbieter | Zweck | Serverstandort / Übermittlung | Rechtsgrundlage & Garantien |
| :--- | :--- | :--- | :--- |
| **Render Services, Inc.** | Cloud-Hosting & PostgreSQL-Datenbank | Frankfurt am Main, Deutschland (EU-Region) | Art. 6 Abs. 1 lit. b & f DSGVO. AVV mit Standardvertragsklauseln (SCCs). |
| **Mailjet (Sinch SAS)** | Transaktionaler E-Mail-Versand (Bestätigungs- & Reset-Mails) | Europäische Union (Frankreich / Deutschland) | Art. 6 Abs. 1 lit. b DSGVO. AVV mit ISO 27001-zertifiziertem EU-Anbieter. |
| **OpenRouter Inc.** | KI-Plangenerierung (Flüchtige Prompt-Verarbeitung) | USA / Global | Art. 6 Abs. 1 lit. a & b DSGVO. Anonyme Übermittlung, Standardvertragsklauseln. Keine Datenhaltung zum Modelltraining. |
| **Apple Inc. (StoreKit 2)** | In-App-Käufe & Abonnement-Abrechnung | EU / Irland | Art. 6 Abs. 1 lit. b DSGVO. Zahlungsdaten verbleiben bei Apple; unsere API prüft nur die kryptografische JWS-Quittung. |

---

### 6. Technische und organisatorische Sicherheitsmaßnahmen (TOMs)
- **Transportverschlüsselung:** Sämtliche Kommunikation erfolgt über TLS 1.3 / HTTPS mit Perfect Forward Secrecy.
- **Passwort-Sicherheit:** Passwörter werden mit BCrypt (Work Factor 12) gesalzen und gehasht.
- **Token-Sicherheit:** HS256-signierte JWT Access Tokens (60 Minuten Gültigkeit) und 64-Byte Refresh-Tokens, die in der Datenbank ausschließlich als SHA-256-Hash gespeichert werden.
- **Keine Speicherung von Zahlungsdaten:** Zahlungs- und Bankdaten werden niemals über unsere Server verarbeitet.

---

### 7. Betroffenenrechte (Art. 15–22 DSGVO)
Dir stehen nach der EU-DSGVO folgende Rechte zu:
1. **Recht auf Auskunft (Art. 15 DSGVO)**
2. **Recht auf Berichtigung (Art. 16 DSGVO)**
3. **Recht auf Löschung / „Recht auf Vergessenwerden“ (Art. 17 DSGVO)**
4. **Recht auf Einschränkung der Verarbeitung (Art. 18 DSGVO)**
5. **Recht auf Datenübertragbarkeit (Art. 20 DSGVO)**
6. **Widerspruchsrecht (Art. 21 DSGVO)**
7. **Widerruf erteilter Einwilligungen (Art. 7 Abs. 3 DSGVO)**
8. **Beschwerderecht bei einer Datenschutz-Aufsichtsbehörde (Art. 77 DSGVO)** *(z. B. Landesbeauftragte für den Datenschutz Brandenburg)*

**Kontakt für Datenschutzanfragen:**  
E-Mail: **appoint.20@gmail.com**  
Postanschrift: appoint, Inh. Shiv Mehra, Max-Liebermann-Str. 82, 14612 Falkensee
