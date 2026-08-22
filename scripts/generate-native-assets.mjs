/*
  Erzeugt die Quellbilder für `npx capacitor-assets generate` aus public/icon.svg.

  Warum ein eigenes Skript: capacitor-assets erwartet fertige PNGs in bestimmten
  Größen (App-Icon, Android-Vorder-/Hintergrund, Startbild). Die einzige Quelle
  soll aber das SVG bleiben — sonst driften Web-Icon und App-Icon auseinander.
*/
import sharp from "sharp";
import { readFileSync, mkdirSync, readdirSync } from "node:fs";

mkdirSync("assets", { recursive: true });

const svg = readFileSync("public/icon.svg");
// Ohne die abgerundete Platte — iOS und Android setzen ihre eigene Maske.
const bare = svg.toString().replace(/<rect width="512" height="512"[^>]*\/>/, "");

await sharp(svg, { density: 400 }).resize(1024, 1024).png().toFile("assets/icon-only.png");

await sharp({ create: { width: 1024, height: 1024, channels: 4, background: "#26E1BE" } })
  .png()
  .toFile("assets/icon-background.png");

const foreground = await sharp(Buffer.from(bare), { density: 400 }).resize(560, 560).png().toBuffer();
await sharp({
  create: { width: 1024, height: 1024, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
})
  .composite([{ input: foreground, gravity: "center" }])
  .png()
  .toFile("assets/icon-foreground.png");

// Startbild: großzügiger Rand, damit es jedes Seitenverhältnis übersteht.
const mark = await sharp(svg, { density: 400 }).resize(620, 620).png().toBuffer();
for (const name of ["splash.png", "splash-dark.png"]) {
  await sharp({ create: { width: 2732, height: 2732, channels: 4, background: "#0D0E10" } })
    .composite([{ input: mark, gravity: "center" }])
    .png()
    .toFile(`assets/${name}`);
}

console.log("erzeugt:", readdirSync("assets").join(", "));
