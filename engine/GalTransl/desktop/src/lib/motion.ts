/**
 * GalTransl Desktop — Motion Design Tokens & Utilities
 *
 * Single source of truth for animation durations, easings, and motion helpers.
 * CSS animations should reference these values via CSS custom properties
 * defined in tokens.css; JS-driven timers should import from here.
 */

// ── Durations ──────────────────────────────────────────
export const DUR = {
  /** Micro feedback (hover, press) */
  micro: 120,
  /** Fast transition (sidebar collapse, tab switch) */
  fast: 200,
  /** Standard enter/exit (page transition, card appear) */
  standard: 300,
  /** Emphasized motion (hero progress, launch charge) */
  emphasized: 500,
  /** Celebration / complex sequences */
  celebration: 800,
} as const;

// ── Easings ────────────────────────────────────────────
export const EASE = {
  /** Default ease for most UI transitions */
  default: 'cubic-bezier(0.25, 0.1, 0.25, 1)',
  /** Deceleration (entering elements) */
  decel: 'cubic-bezier(0, 0, 0.2, 1)',
  /** Acceleration (exiting elements) */
  accel: 'cubic-bezier(0.4, 0, 1, 1)',
  /** Sharp — material-style standard */
  sharp: 'cubic-bezier(0.4, 0, 0.6, 1)',
  /** Spring overshoot (celebrations, badge pop) */
  spring: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
  /** Smooth bar fill */
  barFill: 'cubic-bezier(0.22, 1, 0.36, 1)',
} as const;

// ── Translate-page motion timing (JS-driven) ───────────
export const LAUNCH = {
  chargeMs: DUR.emphasized,
  blastMs: 600,
  particleCount: 12,
  particleDistanceMin: 30,
  particleDistanceMax: 80,
  rippleMs: 600,
  particleMs: 700,
} as const;

export const STRIP_BOOT = {
  scanMs: 500,
  glowMs: 800,
  totalMs: 1200,
} as const;

export const BAR_SURGE = {
  ms: 800,
} as const;

export const COMPLETE = {
  celebrateMs: 1200,
  barGlowMs: 800,
  badgePopMs: 600,
} as const;

/** How long a fresh success row stays highlighted */
export const FRESH_HIGHLIGHT_MS = 2200;

// ── reduced-motion helper ──────────────────────────────

/** The desktop app keeps its own animations independent of the OS setting. */
export function prefersReducedMotion(): boolean {
  return false;
}

/**
 * React hook-shaped helper for motion code that should not follow the OS
 * reduced-motion preference in the desktop app.
 */
export function usePrefersReducedMotion(): boolean {
  return false;
}
