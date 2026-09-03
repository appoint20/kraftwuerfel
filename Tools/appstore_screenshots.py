#!/usr/bin/env python3
"""
Screenshots für App Store Connect aus dem Simulator.

Warum es dieses Skript gibt: Ein Bild aus `xcrun simctl io booted screenshot`
hat zwar die richtigen Maße, trägt aber einen Alphakanal — und App Store
Connect lehnt PNGs mit Alphakanal ab. Die Fehlermeldung dort nennt den Grund
nicht, sie sagt nur, das Bild sei ungültig. Genau daran scheitert der Upload.

Der zweite Fallstrick sind die Maße. Ein Bildschirmfoto des Simulator-FENSTERS
(⇧⌘4 unter macOS) enthält Fensterrahmen und ist skaliert; es hat damit nie die
exakte Pixelgröße, die Apple verlangt. Nur die Aufnahme über `simctl` liefert
echte Gerätepixel.

Aufruf:

    python3 Tools/appstore_screenshots.py geraete
    python3 Tools/appstore_screenshots.py starten "Kraft-6.5"
    python3 Tools/appstore_screenshots.py aufnehmen live-session
    python3 Tools/appstore_screenshots.py aufnehmen live-session "Kraft-6.5"
    python3 Tools/appstore_screenshots.py pruefen

Die Bilder landen in Tools/screenshots/<gerät>/ und sind direkt hochladbar.

App Store Connect hat je Bildschirmgröße einen EIGENEN Platz. Ein Bild mit
1320×2868 (6,9") wird im 6,5"-Platz abgelehnt — mit einer Meldung, die nur die
erwarteten Maße nennt und nicht sagt, dass man im falschen Platz steht. Der
Befehl `geraete` zeigt deshalb, welches Gerät welchen Platz bedient.
"""

import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Tools" / "screenshots"

# Die Größen, die App Store Connect für iPhone erwartet.
# 6,9" ist Pflicht; 6,5" nur nötig, wenn kein 6,9"-Gerät bedient wird.
SIZES = {
    (1320, 2868): '6,9" (iPhone 16 Pro Max) — Pflichtformat',
    (1290, 2796): '6,7" (iPhone 15/16 Plus)',
    (1284, 2778): '6,5" (iPhone 12/13 Pro Max)',
    # Nachgemessen: Der Simulator des 11 Pro Max liefert genau das,
    # ebenso der Xs Max. Beide bedienen den 6,5"-Platz.
    (1242, 2688): '6,5" (iPhone 11 Pro Max / Xs Max)',
    (2064, 2752): '13" iPad',
    (2048, 2732): '12,9" iPad',
}


def booted_device() -> str | None:
    """Name des laufenden Simulators, oder None."""
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "booted"],
        capture_output=True, text=True,
    ).stdout
    for line in out.splitlines():
        if "(Booted)" in line:
            return line.strip().split(" (")[0]
    return None


def ensure_booted(name: str) -> bool:
    """Startet das Gerät, falls es noch nicht läuft."""
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices"], capture_output=True, text=True
    ).stdout
    for line in out.splitlines():
        if line.strip().startswith(name + " ("):
            if "(Booted)" in line:
                return True
            subprocess.run(["xcrun", "simctl", "boot", name], capture_output=True)
            import time
            time.sleep(10)
            return True
    return False


def devices() -> int:
    """Welches Gerät bedient welchen Platz in App Store Connect."""
    out = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available"],
        capture_output=True, text=True,
    ).stdout

    print("Verfügbare Simulatoren und ihr Platz im Store:\n")
    seen = set()
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("iPhone") and not line.startswith("iPad") and not line.startswith("Kraft"):
            continue
        name = line.split(" (")[0]
        if name in seen:
            continue
        seen.add(name)
        state = "läuft" if "(Booted)" in line else ""
        print(f"  {name:28} {state}")

    print("\nPflicht ist der 6,9\"-Platz: 1320×2868 (iPhone 16 Pro Max).")
    print("Für den 6,5\"-Platz: 1242×2688 (iPhone 11 Pro Max oder Xs Max).")
    print("\nFehlt ein 6,5\"-Gerät, einmalig anlegen:")
    print('  xcrun simctl create "Kraft-6.5" \\')
    print("    com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max \\")
    print("    com.apple.CoreSimulator.SimRuntime.iOS-18-1")
    return 0


def start_app(device: str) -> int:
    """
    App bauen, installieren und starten — auf genau diesem Simulator.

    Ohne diesen Schritt nimmt `aufnehmen` auf, was gerade zu sehen ist, und
    das ist auf einem frisch angelegten Simulator der Startbildschirm von
    iOS. Ein Bildschirmfoto des Home-Bildschirms ist kein Screenshot der App —
    App Store Connect nimmt es an und die Prüfung beanstandet es.
    """
    if not ensure_booted(device):
        print(f"Gerät '{device}' gibt es nicht. `geraete` zeigt die vorhandenen.")
        return 1

    build_dir = ROOT / "build" / "screenshots"
    print(f"Baue für {device} …")
    result = subprocess.run(
        ["xcodebuild", "build",
         "-project", str(ROOT / "Kraftwuerfel.xcodeproj"),
         "-scheme", "Kraftwuerfel",
         "-destination", f"platform=iOS Simulator,name={device}",
         "-derivedDataPath", str(build_dir),
         "-quiet"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(result.stdout[-2000:] or result.stderr[-2000:])
        return 1

    app = build_dir / "Build" / "Products" / "Debug-iphonesimulator" / "Kraftwuerfel.app"
    if not app.exists():
        print(f"Gebaut, aber nicht gefunden: {app}")
        return 1

    subprocess.run(["xcrun", "simctl", "install", device, str(app)], check=True)
    subprocess.run(["xcrun", "simctl", "launch", device, "app.kraftwuerfel"],
                   capture_output=True, check=True)
    subprocess.run(["open", "-a", "Simulator"])

    print(f"Läuft auf {device}.")
    print("Jetzt anmelden, zum gewünschten Bildschirm navigieren, dann:")
    print(f'  python3 Tools/appstore_screenshots.py aufnehmen <name> "{device}"')
    return 0


def flatten(path: Path) -> tuple[int, int]:
    """
    Entfernt den Alphakanal — der eigentliche Grund für den abgelehnten Upload.

    Das Bild wird auf Schwarz gelegt statt der Kanal einfach verworfen: Wäre
    irgendwo eine halbdurchsichtige Stelle, käme sonst Müll heraus. Bei einer
    Aufnahme aus dem Simulator ist ohnehin alles deckend, aber verlassen
    sollte man sich darauf nicht.
    """
    with Image.open(path) as img:
        rgb = Image.new("RGB", img.size, (0, 0, 0))
        rgb.paste(img, mask=img.split()[3] if img.mode == "RGBA" else None)
        rgb.save(path, "PNG", optimize=True)
        return rgb.size


def capture(name: str, device: str | None = None) -> int:
    if device is not None:
        if not ensure_booted(device):
            print(f"Gerät '{device}' gibt es nicht. `geraete` zeigt die vorhandenen.")
            return 1
    else:
        device = booted_device()
    if device is None:
        print("Kein Simulator läuft. Erst in Xcode starten oder:")
        print('  xcrun simctl boot "iPhone 16 Pro Max" && open -a Simulator')
        return 1

    folder = OUT / device.replace(" ", "-")
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / f"{name}.png"

    subprocess.run(
        ["xcrun", "simctl", "io", device, "screenshot", str(target)],
        capture_output=True, check=True,
    )
    size = flatten(target)

    label = SIZES.get(size)
    if label:
        print(f"  {target.relative_to(ROOT)}  {size[0]}×{size[1]}  {label}")
    else:
        print(f"  {target.relative_to(ROOT)}  {size[0]}×{size[1]}")
        print("  ACHTUNG: Diese Größe kennt App Store Connect nicht — anderes Gerät wählen.")
    return 0


def check() -> int:
    files = sorted(OUT.rglob("*.png"))
    if not files:
        print(f"Keine Bilder in {OUT.relative_to(ROOT)}.")
        return 1

    problems = 0
    for path in files:
        with Image.open(path) as img:
            size, alpha = img.size, img.mode in ("RGBA", "LA", "P")
        label = SIZES.get(size)

        notes = []
        if alpha:
            notes.append("Alphakanal — wird abgelehnt")
            problems += 1
        if label is None:
            notes.append("unbekannte Größe")
            problems += 1

        status = "  ok" if not notes else "FEHLER"
        print(f"{status}  {path.relative_to(OUT)}  {size[0]}×{size[1]}"
              + (f"  {label}" if label else "")
              + ("  → " + ", ".join(notes) if notes else ""))

    print()
    print("Alles hochladbar." if problems == 0 else f"{problems} Datei(en) müssen neu erzeugt werden.")
    return 0 if problems == 0 else 1


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] not in {"aufnehmen", "pruefen", "geraete", "starten"}:
        print(__doc__)
        return 1
    if args[0] == "pruefen":
        return check()
    if args[0] == "geraete":
        return devices()
    if args[0] == "starten":
        if len(args) < 2:
            print('Gerät fehlt:  python3 Tools/appstore_screenshots.py starten "Kraft-6.5"')
            return 1
        return start_app(args[1])
    if len(args) < 2:
        print("Name fehlt:  python3 Tools/appstore_screenshots.py aufnehmen live-session")
        return 1
    return capture(args[1], args[2] if len(args) > 2 else None)


if __name__ == "__main__":
    sys.exit(main())
