#!/bin/sh
#
# Xcode Cloud: Projektdatei vor dem Bauen neu erzeugen.
#
# Der Build stand fest in der Projektdatei. Ein Lauf hatte die Nummer schon
# hochgeladen, der nächste versuchte dieselbe — App Store Connect lehnt das ab:
# "The bundle version must be higher than the previously uploaded version".
#
# CI_BUILD_NUMBER zählt Xcode Cloud pro Lauf hoch. Damit ist jeder Upload
# eindeutig und höher als der vorige, ohne dass jemand eine Zahl pflegen muss.
#
# `set -e` ist hier ungefährlich: Der Generator endet nur dann mit einem Fehler,
# wenn er die Projektdatei nicht schreiben konnte. Offene Punkte der
# Einreichungsprüfung gibt er nur aus; sie beenden den Lauf nicht.
#
# Ist CI_BUILD_NUMBER nicht gesetzt (Aufruf von Hand), greift der Rückfallwert
# im Generator.
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"
KRAFT_BUILD="$CI_BUILD_NUMBER" python3 Tools/generate_xcodeproj.py
