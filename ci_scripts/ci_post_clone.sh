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

# Der Zähler von Xcode Cloud allein reicht nicht.
#
# Von Hand hochgeladene Archive waren schon bei Build 20, während der Zähler
# hier noch darunter liegt — der nächste Lauf liefe damit erneut in "must be
# higher than the previously uploaded version". Der Sockel von 1000 hebt jeden
# Lauf sicher über alles, was von Hand hochgeladen wurde, und bleibt trotzdem
# von Lauf zu Lauf steigend.
#
# Ohne CI_BUILD_NUMBER (Aufruf von Hand) ergibt das 1000 — auch das liegt über
# den bisherigen Nummern.
KRAFT_BUILD=$((1000 + ${CI_BUILD_NUMBER:-0})) python3 Tools/generate_xcodeproj.py
