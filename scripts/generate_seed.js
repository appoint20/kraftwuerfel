import fs from "fs";
import { EXERCISES } from "../src/data/exercises.js";

const sqlValues = EXERCISES.map((ex, idx) => {
  const id = ex.id.replace(/'/g, "''");
  const name = ex.name.replace(/'/g, "''");
  const category = ex.category.replace(/'/g, "''");
  const equipment = ex.equipment.replace(/'/g, "''");
  const isCompound = !!ex.compound;
  return `('${id}', '${name}', '${category}', '${equipment}', ${isCompound})`;
}).join(",\n  ");

const sql = `-- Seed all exercises into public.exercises
CREATE TABLE IF NOT EXISTS public.exercises (
  id text PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL,
  equipment text NOT NULL,
  is_compound boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read exercises" ON public.exercises;
CREATE POLICY "Public read exercises" ON public.exercises FOR SELECT USING (true);

INSERT INTO public.exercises (id, name, category, equipment, is_compound)
VALUES
  ${sqlValues}
ON CONFLICT (id) DO UPDATE SET
  name = excluded.name,
  category = excluded.category,
  equipment = excluded.equipment,
  is_compound = excluded.is_compound;
`;

fs.writeFileSync("./supabase/seed_exercises.sql", sql);
console.log(`Generated ${EXERCISES.length} exercises into supabase/seed_exercises.sql`);
