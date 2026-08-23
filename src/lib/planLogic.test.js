import { describe, it, expect } from "vitest";
import { buildPlan, buildDayPlans, cyclesForDuration, serializeSlots, deserializeSlots } from "./planLogic.js";
import { EXERCISES, SPLITS, FOCUS_MIN_COUNT } from "../data/exercises.js";
import { weekInfoForDate, mostRecentWeekdayOnOrBefore, nextWeekdayOnOrAfter } from "./dateUtils.js";

const run = (n, fn) => Array.from({ length: n }, (_, i) => fn(i));

describe("Übungsdatenbank", () => {
  it("enthält 137 Übungen", () => {
    expect(EXERCISES).toHaveLength(137);
  });

  it("ordnet Hip Thrust drei Kategorien zu", () => {
    const hip = EXERCISES.find((e) => e.name === "Hip Thrust");
    expect(hip.categories).toEqual(["Gesäß", "Beine", "Rücken"]);
  });

  it("schließt Brust aus dem Frauen-Split aus", () => {
    expect(SPLITS.Frauen).not.toContain("Brust");
  });
});

describe("buildPlan", () => {
  it("liefert die gewünschte Anzahl Übungen ohne Doppelungen", () => {
    run(50, () => {
      const plan = buildPlan(SPLITS.Ganzkörper, 8);
      expect(plan).toHaveLength(8);
      expect(new Set(plan.map((s) => s.exercise.name)).size).toBe(8);
    });
  });

  it("bleibt bei Standard auf 3 Sätzen", () => {
    const plan = buildPlan(SPLITS.Push, 5, "standard");
    expect(plan.every((s) => s.sets === 3)).toBe(true);
  });

  it("vergibt bei 5x4x3 genau einen 5er- und einen 4er-Slot", () => {
    run(30, () => {
      const sets = buildPlan(SPLITS.Ganzkörper, 6, "543").map((s) => s.sets);
      expect(sets.filter((s) => s === 5)).toHaveLength(1);
      expect(sets.filter((s) => s === 4)).toHaveLength(1);
    });
  });

  it("vergibt bei 4x4x3 genau zwei 4er-Slots", () => {
    run(30, () => {
      const sets = buildPlan(SPLITS.Ganzkörper, 6, "443").map((s) => s.sets);
      expect(sets.filter((s) => s === 4)).toHaveLength(2);
      expect(sets.filter((s) => s === 5)).toHaveLength(0);
    });
  });

  it("erzwingt bei Fokus-Methoden mindestens drei Übungen der Fokus-Kategorie", () => {
    run(30, () => {
      const plan = buildPlan(SPLITS.Pull, 5, "brust-fokus");
      const brust = plan.filter((s) => s.exercise.categories.includes("Brust"));
      expect(brust.length).toBeGreaterThanOrEqual(FOCUS_MIN_COUNT);
    });
  });

  it("hebt die Übungszahl an, wenn der Fokus mehr Slots braucht", () => {
    expect(buildPlan(SPLITS.Pull, 2, "beine-fokus").length).toBeGreaterThanOrEqual(FOCUS_MIN_COUNT);
  });

  it("respektiert extraExclude", () => {
    const first = buildPlan(SPLITS.Ganzkörper, 6);
    const used = new Set(first.map((s) => s.exercise.name));
    const second = buildPlan(SPLITS.Ganzkörper, 6, "standard", 60, used);
    expect(second.some((s) => used.has(s.exercise.name))).toBe(false);
  });

  it("bricht nicht ab, wenn der Pool kleiner ist als die Wunschzahl", () => {
    const plan = buildPlan(["Gesäß"], 12);
    expect(plan.length).toBeGreaterThan(0);
    expect(plan.length).toBeLessThanOrEqual(12);
  });
});

describe("Wochenplan", () => {
  it("leitet Zyklen aus der Dauer ab", () => {
    expect(cyclesForDuration(2)).toBe(1);
    expect(cyclesForDuration(4)).toBe(2);
    expect(cyclesForDuration(6)).toBe(3);
  });

  it("erzeugt pro Tag überschneidungsfreie Zyklen", () => {
    const dayPlans = buildDayPlans(["Mo", "Mi", "Fr"], 3, SPLITS.Ganzkörper, 6, "standard", 60);
    expect(Object.keys(dayPlans)).toEqual(["Mo", "Mi", "Fr"]);
    Object.values(dayPlans).forEach((cycles) => {
      const names = cycles.flatMap((c) => c.map((s) => s.exercise.name));
      expect(new Set(names).size).toBe(names.length);
    });
  });
});

describe("Serialisierung", () => {
  it("überlebt einen Round-Trip", () => {
    const plan = buildPlan(SPLITS.Oberkörper, 5, "543", 90);
    const back = deserializeSlots(serializeSlots(plan));
    expect(back.map((s) => s.exercise.name)).toEqual(plan.map((s) => s.exercise.name));
    expect(back.map((s) => s.sets)).toEqual(plan.map((s) => s.sets));
    expect(back.map((s) => s.rest)).toEqual(plan.map((s) => s.rest));
  });

  it("behält unbekannte Übungen als Platzhalter", () => {
    const [slot] = deserializeSlots([
      { name: "Erfundene Übung", category: "Brust", equipment: "Kurzhantel", sets: 3, reps: "8", rest: 60 },
    ]);
    expect(slot.exercise.name).toBe("Erfundene Übung");
    expect(slot.exercise.categories).toEqual(["Brust"]);
  });
});

describe("Datums-Mathematik", () => {
  const start = new Date(2026, 0, 5); // Montag

  it("zählt Wochen ab 1 und alterniert Zyklen zwischen 0 (Zyklus 1) und 1 (Zyklus 2)", () => {
    expect(weekInfoForDate(new Date(2026, 0, 5), start)).toMatchObject({ weekIdx: 1, cycleIdx: 0 });
    expect(weekInfoForDate(new Date(2026, 0, 11), start)).toMatchObject({ weekIdx: 1, cycleIdx: 0 });
    expect(weekInfoForDate(new Date(2026, 0, 12), start)).toMatchObject({ weekIdx: 2, cycleIdx: 1 });
    expect(weekInfoForDate(new Date(2026, 0, 19), start)).toMatchObject({ weekIdx: 3, cycleIdx: 0 });
    expect(weekInfoForDate(new Date(2026, 1, 2), start)).toMatchObject({ weekIdx: 5, cycleIdx: 0 });
  });

  it("findet den letzten und nächsten Wochentag", () => {
    const wednesday = new Date(2026, 0, 7);
    expect(mostRecentWeekdayOnOrBefore(wednesday, "Mo").getDate()).toBe(5);
    expect(mostRecentWeekdayOnOrBefore(wednesday, "Mi").getDate()).toBe(7);
    expect(nextWeekdayOnOrAfter(wednesday, "Fr").getDate()).toBe(9);
    expect(nextWeekdayOnOrAfter(wednesday, "So").getDate()).toBe(11);
  });
});

import { translateFocusString } from "./i18n.jsx";

describe("translateFocusString i18n", () => {
  it("translates German focus strings to English including umlauts", () => {
    expect(translateFocusString("Brust Fokus", "en")).toBe("Chest Focus");
    expect(translateFocusString("Rücken Fokus", "en")).toBe("Back Focus");
    expect(translateFocusString("Beine Fokus", "en")).toBe("Legs Focus");
    expect(translateFocusString("Schultern Fokus", "en")).toBe("Shoulders Focus");
    expect(translateFocusString("Gesäß Fokus", "en")).toBe("Glutes Focus");
    expect(translateFocusString("Oberkörper", "en")).toBe("Upper Body");
    expect(translateFocusString("Unterkörper", "en")).toBe("Lower Body");
  });

  it("keeps German untouched when lang is de", () => {
    expect(translateFocusString("Brust Fokus", "de")).toBe("Brust Fokus");
    expect(translateFocusString("Rücken Fokus", "de")).toBe("Rücken Fokus");
  });
});

