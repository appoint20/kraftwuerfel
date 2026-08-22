import { useEffect, useState } from "react";
import LogoIcon from "./LogoIcon.jsx";

/*
  Startbildschirm.

  Zwei Aufgaben: die Wartezeit überbrücken, bis die Sitzung geladen ist, und
  dabei nicht flackern. Deshalb eine Mindestdauer — wäre die Sitzung nach 80 ms
  da, würde der Splash sonst nur kurz aufblitzen, was unruhiger wirkt als gar
  keiner.

  Die Animation greift das Thema auf: der Würfel fällt, kippt und bleibt liegen,
  danach kommt der Schriftzug. Wer Animationen reduziert hat, bekommt dasselbe
  Bild ohne Bewegung.
*/

const MIN_VISIBLE_MS = 1500;
const FADE_MS = 420;

export default function SplashScreen({ ready, onDone }) {
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (!ready) return;
    const elapsedTimer = setTimeout(() => setLeaving(true), MIN_VISIBLE_MS);
    return () => clearTimeout(elapsedTimer);
  }, [ready]);

  useEffect(() => {
    if (!leaving) return;
    const t = setTimeout(onDone, FADE_MS);
    return () => clearTimeout(t);
  }, [leaving, onDone]);

  return (
    <div className={`splash ${leaving ? "leaving" : ""}`} role="status" aria-label="Kraftwürfel wird geladen">
      <div className="splash-inner">
        <div className="splash-cube">
          <div className="splash-cube-face">
            <LogoIcon size={46} />
          </div>
        </div>

        <div className="splash-word" aria-hidden="true">
          {"KRAFTWÜRFEL".split("").map((letter, i) => (
            <span key={i} style={{ animationDelay: `${520 + i * 42}ms` }}>
              {letter}
            </span>
          ))}
        </div>

        <div className="splash-rule">
          <span />
        </div>
      </div>
    </div>
  );
}
