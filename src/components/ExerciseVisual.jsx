import React from "react";

// Muscle group SVG path coordinates for anatomical visualization
export default function ExerciseVisual({ category, exerciseName, size = 120 }) {
  const cat = (category || "").toLowerCase();

  // Determine highlighted muscle groups based on exercise category
  const isChest = cat.includes("brust") || cat.includes("chest");
  const isBack = cat.includes("rücken") || cat.includes("back") || cat.includes("nacken");
  const isShoulders = cat.includes("schulter") || cat.includes("shoulder");
  const isBiceps = cat.includes("bizeps") || cat.includes("bicep");
  const isTriceps = cat.includes("trizeps") || cat.includes("tricep") || cat.includes("arm");
  const isLegs = cat.includes("bein") || cat.includes("leg") || cat.includes("quad");
  const isGlutes = cat.includes("gesäß") || cat.includes("glute");
  const isCalves = cat.includes("wade") || cat.includes("calf");
  const isCore = cat.includes("bauch") || cat.includes("core") || cat.includes("abs");
  const isFullBody = cat.includes("ganzkörper") || cat.includes("full");

  const activeColor = "#26E1BE";
  const inactiveColor = "#2A2B30";
  const outlineColor = "#3E4048";

  return (
    <div className="exercise-visual-wrapper" style={{ width: size, height: size }}>
      <svg
        viewBox="0 0 100 120"
        width={size}
        height={size}
        className="exercise-visual-svg"
      >
        {/* Head */}
        <circle cx="50" cy="14" r="8" fill="#32343A" stroke={outlineColor} strokeWidth="1.5" />

        {/* Neck / Traps */}
        <path
          d="M44 22 L56 22 L60 28 L40 28 Z"
          fill={isBack || isShoulders || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isBack || isShoulders ? "muscle-pulse" : ""}
        />

        {/* Shoulders (Deltoids) */}
        {/* Left Shoulder */}
        <path
          d="M38 27 C34 28, 30 32, 28 38 C32 40, 36 36, 40 31 Z"
          fill={isShoulders || isChest || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isShoulders ? "muscle-pulse" : ""}
        />
        {/* Right Shoulder */}
        <path
          d="M62 27 C66 28, 70 32, 72 38 C68 40, 64 36, 60 31 Z"
          fill={isShoulders || isChest || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isShoulders ? "muscle-pulse" : ""}
        />

        {/* Chest (Pectorals) */}
        <path
          d="M40 30 L50 31 L60 30 L58 42 L50 44 L42 42 Z"
          fill={isChest || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isChest ? "muscle-pulse" : ""}
        />

        {/* Upper Back / Lats */}
        <path
          d="M38 32 L42 42 L38 52 L34 40 Z"
          fill={isBack || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isBack ? "muscle-pulse" : ""}
        />
        <path
          d="M62 32 L58 42 L62 52 L66 40 Z"
          fill={isBack || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isBack ? "muscle-pulse" : ""}
        />

        {/* Arms: Biceps & Triceps */}
        {/* Left Upper Arm */}
        <path
          d="M28 38 L24 50 L29 50 L34 40 Z"
          fill={isBiceps || isTriceps || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isBiceps || isTriceps ? "muscle-pulse" : ""}
        />
        {/* Right Upper Arm */}
        <path
          d="M72 38 L76 50 L71 50 L66 40 Z"
          fill={isBiceps || isTriceps || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isBiceps || isTriceps ? "muscle-pulse" : ""}
        />

        {/* Forearms */}
        <path d="M24 50 L20 64 L25 64 L29 50 Z" fill="#32343A" stroke={outlineColor} strokeWidth="1" />
        <path d="M76 50 L80 64 L75 64 L71 50 Z" fill="#32343A" stroke={outlineColor} strokeWidth="1" />

        {/* Core / Abs */}
        <path
          d="M42 44 L58 44 L56 60 L44 60 Z"
          fill={isCore || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isCore ? "muscle-pulse" : ""}
        />

        {/* Pelvis / Glutes */}
        <path
          d="M44 60 L56 60 L60 68 L40 68 Z"
          fill={isGlutes || isLegs || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isGlutes ? "muscle-pulse" : ""}
        />

        {/* Upper Legs (Quads & Hamstrings) */}
        {/* Left Thigh */}
        <path
          d="M40 68 L48 68 L46 90 L38 90 Z"
          fill={isLegs || isGlutes || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isLegs ? "muscle-pulse" : ""}
        />
        {/* Right Thigh */}
        <path
          d="M52 68 L60 68 L62 90 L54 90 Z"
          fill={isLegs || isGlutes || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isLegs ? "muscle-pulse" : ""}
        />

        {/* Lower Legs (Calves) */}
        {/* Left Calf */}
        <path
          d="M38 92 L46 92 L44 114 L39 114 Z"
          fill={isCalves || isLegs || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isCalves ? "muscle-pulse" : ""}
        />
        {/* Right Calf */}
        <path
          d="M54 92 L62 92 L61 114 L56 114 Z"
          fill={isCalves || isLegs || isFullBody ? activeColor : inactiveColor}
          stroke={outlineColor}
          strokeWidth="1"
          className={isCalves ? "muscle-pulse" : ""}
        />
      </svg>
      <div className="exercise-visual-label">{category}</div>
    </div>
  );
}
