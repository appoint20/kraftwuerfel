import { useCallback, useEffect, useRef, useState } from "react";
import { EXERCISES } from "../data/exercises.js";
import { randOf } from "../lib/planLogic.js";

export default function useReel() {
  const timers = useRef([]);
  const interval = useRef(null);
  const [rollingIdx, setRollingIdx] = useState(new Set());
  const [scramble, setScramble] = useState({});

  const clearTimers = useCallback(() => {
    timers.current.forEach((t) => clearTimeout(t));
    timers.current = [];
    if (interval.current) clearInterval(interval.current);
  }, []);

  useEffect(() => clearTimers, [clearTimers]);

  const runReel = useCallback(
    (finalSlots, onDone) => {
      clearTimers();
      const idxs = finalSlots.map((_, i) => i);
      setRollingIdx(new Set(idxs));
      interval.current = setInterval(() => {
        setScramble((prev) => {
          const next = { ...prev };
          idxs.forEach((i) => {
            next[i] = randOf(EXERCISES).name;
          });
          return next;
        });
      }, 55);
      idxs.forEach((i) => {
        const t = setTimeout(() => {
          setRollingIdx((prev) => {
            const n = new Set(prev);
            n.delete(i);
            return n;
          });
          if (i === idxs.length - 1) {
            clearInterval(interval.current);
            if (onDone) onDone();
          }
        }, 420 + i * 160);
        timers.current.push(t);
      });
    },
    [clearTimers]
  );

  return { rollingIdx, scramble, runReel };
}
