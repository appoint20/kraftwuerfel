/*
  Die Übungsliste lebt in src/data/exercises.js. Die Edge Function braucht dieselbe
  Liste, kann aber nicht aus src/ importieren (eigenes Deno-Bundle). Dieses Skript
  erzeugt die Kopie. Nach jeder Änderung an den Übungen ausführen:

    npm run sync:exercises
*/
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");

const { EXERCISES, CATEGORIES, EQUIPMENT } = await import(join(root, "src/data/exercises.js"));

const slim = EXERCISES.map((e) => ({
  name: e.name,
  category: e.category,
  categories: e.categories,
  equipment: e.equipment,
  heavy: e.heavy,
}));

const out = `// GENERIERT von scripts/sync-exercises.mjs — nicht von Hand bearbeiten.
// Quelle: src/data/exercises.js

export type Exercise = {
  name: string;
  category: string;
  categories: string[];
  equipment: string;
  heavy: boolean;
};

export const EXERCISES: Exercise[] = ${JSON.stringify(slim, null, 2)};

export const CATEGORIES: string[] = ${JSON.stringify(CATEGORIES)};

export const EQUIPMENT: string[] = ${JSON.stringify(EQUIPMENT)};
`;

const target = join(root, "supabase/functions/_shared/exercises.ts");
writeFileSync(target, out);
console.log(`${slim.length} Übungen -> supabase/functions/_shared/exercises.ts`);
