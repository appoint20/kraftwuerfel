import { describe, it, expect } from "vitest";
import { aiDayToSlots } from "./aiClient.js";
import { serializeSlots, deserializeSlots } from "./planLogic.js";

const DAY = {
  weekday: "Mo",
  focus: "Push",
  exercises: [
    { name: "Bankdrücken", category: "Brust", equipment: "Langhantel", sets: 4, reps: "6-8", rest: 120, note: "Eng" },
    { name: "Butterfly", category: "Brust", equipment: "Maschine", sets: 3, reps: "10-12", rest: 60, note: "" },
  ],
};

describe("KI-Plan -> App-Format", () => {
  it("macht aus einem KI-Tag die Slots, die der Rest der App kennt", () => {
    const slots = aiDayToSlots(DAY);
    expect(slots).toHaveLength(2);
    expect(slots[0].exercise.name).toBe("Bankdrücken");
    expect(slots[0].exercise.categories).toEqual(["Brust"]);
    expect(slots[0].sets).toBe(4);
    expect(slots[0].rest).toBe(120);
    expect(slots[0].note).toBe("Eng");
  });

  it("überlebt den Weg durch die Persistenz", () => {
    const slots = aiDayToSlots(DAY);
    const back = deserializeSlots(serializeSlots(slots));
    expect(back.map((s) => s.exercise.name)).toEqual(["Bankdrücken", "Butterfly"]);
    expect(back.map((s) => s.sets)).toEqual([4, 3]);
    expect(back.map((s) => s.rest)).toEqual([120, 60]);
  });
});
