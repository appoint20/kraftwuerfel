import { describe, it, expect } from "vitest";
import { rotateWeekdaysFromToday, todayWeekday, sortWeekdays, WEEKDAYS } from "./dateUtils.js";
import { planNameFor, planNamesForDays } from "./planNames.js";
import { normalizePlan } from "./aiClient.js";

// Feste Bezugstage, damit die Tests nicht davon abhängen, wann sie laufen.
const MONTAG = new Date("2026-08-24T10:00:00");
const SONNTAG = new Date("2026-08-23T10:00:00");

describe("Wochentags-Reihenfolge", () => {
  it("erkennt den heutigen Tag in Mo-zuerst-Notation", () => {
    expect(todayWeekday(MONTAG)).toBe("Mo");
    expect(todayWeekday(SONNTAG)).toBe("So");
  });

  it("beginnt die Favoritenliste beim heutigen Tag", () => {
    expect(rotateWeekdaysFromToday(SONNTAG)[0]).toBe("So");
    expect(rotateWeekdaysFromToday(MONTAG)[0]).toBe("Mo");
  });

  it("führt die Woche nach dem heutigen Tag normal weiter", () => {
    expect(rotateWeekdaysFromToday(SONNTAG)).toEqual(["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]);
  });

  it("enthält immer alle sieben Tage genau einmal", () => {
    const rotated = rotateWeekdaysFromToday(MONTAG);
    expect(new Set(rotated).size).toBe(7);
    expect([...rotated].sort()).toEqual([...WEEKDAYS].sort());
  });

  it("sortiert Trainingstage nach Wochentag, nicht nach Auswahlreihenfolge", () => {
    // Genau der gemeldete Fall: So darf nicht vor Mi stehen.
    expect(sortWeekdays(new Set(["So", "Mi", "Fr"]))).toEqual(["Mi", "Fr", "So"]);
    expect(sortWeekdays(["So", "Mo"])).toEqual(["Mo", "So"]);
  });
});

describe("Ein-Wort-Namen", () => {
  it("liefert für denselben Plan immer denselben Namen", () => {
    expect(planNameFor("Ganzkörper:standard:Mo")).toBe(planNameFor("Ganzkörper:standard:Mo"));
  });

  it("ist immer genau ein Wort", () => {
    ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"].forEach((d) => {
      expect(planNameFor(`x:${d}`).split(/\s/)).toHaveLength(1);
    });
  });

  it("vergibt innerhalb eines Plans keine Namen doppelt", () => {
    const names = planNamesForDays(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], "seed");
    expect(new Set(Object.values(names)).size).toBe(7);
  });
});

describe("normalizePlan", () => {
  const day = (weekday, extra = {}) => ({
    weekday,
    focus: "Push",
    exercises: [{ name: "Bankdrücken", category: "Brust", equipment: "Langhantel", sets: 3, reps: "8-10", rest: 60 }],
    ...extra,
  });

  it("sortiert die Tage nach Wochentag", () => {
    const out = normalizePlan({ days: [day("So"), day("Mi"), day("Fr")] });
    expect(out.days.map((d) => d.weekday)).toEqual(["Mi", "Fr", "So"]);
  });

  it("versteht die Feldnamen der Edge Function", () => {
    const out = normalizePlan({
      title: "Plan",
      summary: "Kurzfassung",
      notes: ["Hinweis A", "Hinweis B"],
      days: [day("Mo")],
    });
    expect(out.summary).toBe("Kurzfassung");
    expect(out.notes).toEqual(["Hinweis A", "Hinweis B"]);
  });

  it("versteht die Feldnamen des lokalen Generators", () => {
    const out = normalizePlan({
      title: "Plan",
      overview: "Übersicht",
      periodization: "Steigere wöchentlich",
      days: [{ ...day("Mo"), day: "Mo", weekday: undefined }],
    });
    expect(out.summary).toBe("Übersicht");
    expect(out.notes).toEqual(["Steigere wöchentlich"]);
    expect(out.days[0].weekday).toBe("Mo");
  });

  it("gibt jedem Tag einen Ein-Wort-Namen, auch ohne Vorgabe vom Modell", () => {
    const out = normalizePlan({ days: [day("Mo"), day("Mi")] });
    out.days.forEach((d) => {
      expect(d.name).toBeTruthy();
      expect(d.name.split(/\s/)).toHaveLength(1);
    });
  });

  it("kürzt einen mehrwortigen Namen des Modells auf ein Wort", () => {
    const out = normalizePlan({ days: [day("Mo", { name: "Titan der Kraft" })] });
    expect(out.days[0].name).toBe("Titan");
  });

  it("wirft Tage ohne Übungen weg", () => {
    const out = normalizePlan({ days: [day("Mo"), { weekday: "Di", exercises: [] }] });
    expect(out.days).toHaveLength(1);
  });

  it("merkt sich, ob der Plan aus der Vorlage kam", () => {
    expect(normalizePlan({ source: "local", days: [day("Mo")] }).source).toBe("local");
    expect(normalizePlan({ days: [day("Mo")] }).source).toBe("ai");
  });

  it("kommt mit einem leeren Plan klar", () => {
    expect(normalizePlan(null)).toBeNull();
    expect(normalizePlan({ days: [] }).days).toEqual([]);
  });
});
