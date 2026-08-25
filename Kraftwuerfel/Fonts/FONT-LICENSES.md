# Schriftlizenzen

Drei Schriftfamilien liegen im App-Bündel und werden über `UIAppFonts` in
`Kraftwuerfel/Info.plist`, `KraftwuerfelWidget/Info.plist` und
`KraftwuerfelWatch/Info.plist` registriert.

| Familie | Schnitte im Bündel | Lizenz |
|---|---|---|
| Bebas Neue | Regular | SIL Open Font License 1.1 |
| Inter | Regular, Medium, SemiBold, Bold | SIL Open Font License 1.1 |
| JetBrains Mono | Medium, Bold | SIL Open Font License 1.1 |

Die OFL 1.1 erlaubt das Mitliefern in einer App ausdrücklich, auch in einer
bezahlten. Sie knüpft das aber an zwei Bedingungen, und **beide sind derzeit
nicht erfüllt**:

## Offen 1 — Lizenztext mitliefern

Die OFL verlangt, dass Copyright-Vermerk und vollständiger Lizenztext mit jeder
Kopie der Schrift verteilt werden. Im Bündel liegen bisher nur die `.ttf`.

Zu tun:

1. Aus dem jeweiligen Download die mitgelieferte `OFL.txt` holen — nicht
   abtippen und nicht aus einer anderen Quelle kopieren. Nur die Datei aus dem
   Download trägt den richtigen Copyright-Vermerk samt Jahr und
   „Reserved Font Name“.
   - Bebas Neue — Google Fonts bzw. Dharma Type
   - Inter — <https://github.com/rsms/inter> (Release-Archiv)
   - JetBrains Mono — <https://github.com/JetBrains/JetBrainsMono>
2. Ablegen als `Kraftwuerfel/Fonts/OFL-BebasNeue.txt`, `OFL-Inter.txt`,
   `OFL-JetBrainsMono.txt`.
3. In `Tools/generate_xcodeproj.py` die Endung `.txt` aus `Fonts/` in die
   Ressourcen aufnehmen (dort, wo heute `.ttf` und `.otf` eingesammelt werden),
   damit die Dateien wirklich im Bündel landen.

## Offen 2 — In der App nennen

Es gibt bisher keinen Ort, an dem die Hinweise auftauchen: die App hat weder
einen Einstellungs- noch einen Info-Bildschirm. Ohne den steht der Lizenztext
zwar im Bündel, ist für den Nutzer aber unerreichbar.

Zu tun: einen schlichten Abschnitt „Rechtliches“ ergänzen, der die drei
Familien mit Copyright-Zeile und Lizenz nennt.

## Was ausdrücklich nicht nötig ist

- Keine Lizenzgebühr, kein Vermerk im App-Store-Text.
- Die Schriften dürfen umbenannt im Bündel liegen — die Dateinamen hier sind
  unverändert, damit klar bleibt, welcher Schnitt welcher ist.
