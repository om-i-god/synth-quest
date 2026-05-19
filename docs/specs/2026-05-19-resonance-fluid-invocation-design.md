# Synth Quest — Resonance Fluid Invocation (Design)

Date: 2026-05-19
Status: DRAFT — pending user review before implementation planning.

## Summary

Replace the current Resonance invocation flow (which consumes a firing slot and shows a banner) with a fluid combat-flourish: tap R2, signature SFX + sprite-attached pixel animation play, buff arms instantly, character can immediately queue ATK in the same tick. Build the framework + 8 distinct per-Resonance animations. Effects stay stubbed for non-Ring Resonances; Ring is the only one with a real combat effect this pass.

## Goals

- Resonance invocation should feel like a flourish, not a turn.
- 8 distinct sprite-attached animations, one per Resonance, each readable on the norns 128×64 screen.
- Per-character 6-tick cooldown prevents spam; MP cost remains the primary resource.
- Denial states (no attunement, already armed, low MP, on cooldown) give clear non-blocking feedback (SFX + bell-glyph red-flash).
- No banner text during invocation or denial.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Turn cost | Free — RESO does not set `p.last_fire` |
| Cooldown | Per-character 6 ticks (one beat at battle BPM) |
| Animation style | Sprite-attached pixel rings/glyphs + ghost-sprites |
| Scope | All 8 Resonances get distinct animations; only Ring has a real effect |
| Error feedback | SFX (varies by cause) + bell-glyph red-flash for 4 ticks; no banner |
| Implementation | Approach A — eight dedicated `play_<id>_invocation_anim(p)` functions |

## Architecture Changes

### Free invocation

In `apply_player_action`, the `p.queued == "RESO"` branch currently ends by setting `p.last_fire = tick` (which consumes the firing slot for this bar). Remove that line. The character can immediately queue ATK in the same tick.

### Per-character cooldown

Add a new field `p.reso_cooldown_until` (defaults to 0). On successful invocation, set `p.reso_cooldown_until = tick + 6`. The R2 handler's pre-fire guards reject invocation if `tick < p.reso_cooldown_until` (with the denial feedback below). This is a separate cooldown from the firing-slot system.

### Animation dispatch

The RESO action's apply step calls a per-id function via a lookup table:

```lua
local RESO_ANIMS = {
  long_echo    = play_long_echo_anim,
  masked_voice = play_masked_voice_anim,
  spring       = play_spring_anim,
  ring         = play_ring_anim,
  heavy_hand   = play_heavy_hand_anim,
  scatter      = play_scatter_anim,
  slow_wheel   = play_slow_wheel_anim,
  threefold    = play_threefold_anim,
}
```

If `RESO_ANIMS[rid]` exists, it's called with the party member ref `p`. The function reads `p.battle_x, p.battle_y` (or the equivalent existing field) and spawns particles via the existing ANIM pool.

### Action menu interaction

The action menu's RESO 5th-item stays as-is (consistent with HEAL/MAG/BLK). Selecting it from the menu calls the same fluid invocation path as R2. Both routes:

1. Run pre-fire guards (attunement, already-armed, MP, cooldown).
2. On success: deduct MP, fire SFX, fire animation, arm the buff, set cooldown.
3. On failure: fire denial SFX, set `p.reso_denied_t = tick` for the bell-glyph flash.

Critical: when invoked from the action menu, the menu closes immediately after the animation starts; the character is NOT considered to have "spent" their turn. The menu can be re-opened to queue ATK or other actions.

### Decoupling from gameplay tick

Animation rendering runs via the ANIM particle pool in the render loop, not the game tick. Combat continues during the 14-18 tick animation; the buff is armed instantly at T0; the animation is purely cosmetic and can be interrupted by enemy hits without losing the buff.

### Save state

No save-game changes. All new state is per-battle:
- `p.reso_cooldown_until` (cleared on `enter_battle` / `exit_battle`)
- `p.reso_denied_t` (cleared on `enter_battle` / `exit_battle`)
- ANIM particles (cleared on battle end naturally)

The existing `p.ring_armed` and analogous future fields persist mid-battle but are cleared on battle end.

## Per-Resonance Animation Vocabulary

Each function takes a party member ref `p` and registers particles in the existing ANIM pool. Each lasts 12-18 ticks.

### 1. `play_long_echo_anim(p)` — tape echo two-head

Two ghost-copies of the character's combat sprite spawn at +1px and +2px to the right of the live sprite, at brightness levels 8 and 4 respectively, fading over 6 and 10 ticks. Reads as "the singer keeps echoing behind herself."

Implementation: spawn two `ghost_sprite` entries via the new `ANIM.ghost_sprite(class, x, y, brightness, ticks)` helper (see "Shared helpers" below).

### 2. `play_masked_voice_anim(p)` — vocoder

A thin horizontal bar (2px tall, 6px wide) overlays the character's face at the eye-line position for 4 ticks (the mask). Then dissipates upward as 3-4 small particles drifting straight up over 10 ticks. Total: ~14 ticks.

Implementation: draw the bar via a per-frame check on `tick - invocation_t < 4`; spawn 3-4 `ANIM.burst`-style particles with upward velocity vector.

### 3. `play_spring_anim(p)` — spring reverb

3-4 horizontal wavy pixel-lines emanate left and right from the character. Each line oscillates sinusoidally as it travels outward. Lines fade over 14 ticks. Horizontal motion distinguishes from Ring's concentric.

Implementation: a custom particle subtype `spring_line` with horizontal velocity and per-tick y-offset = `sin(tick * 0.4) * 2`. 4 particles, 2 on each side.

### 4. `play_ring_anim(p)` — ring modulator

3 concentric expanding pixel rings centered on the character. Radii start at 2, 4, 6; expand by 1 per tick. Brightness 15, 13, 11 respectively. Total: ~14 ticks.

Implementation: a custom particle subtype `ring` that draws a `screen.circle(cx, cy, radius)` outline at the given brightness, with radius incrementing per tick and brightness decaying. Three particles spawned at T0, T+2, T+4.

### 5. `play_heavy_hand_anim(p)` — sidechain compressor

A DOWNWARD burst — 6 particles falling AWAY from the character at brightness 15, gravity-style velocity (positive vy, decaying vx). 10 ticks. Plus a 1-tick `ANIM.shake(2, 1)` at T0.

Implementation: `ANIM.burst(p.battle_x, p.battle_y, 6, 15)` with custom velocity override (downward bias), plus `ANIM.shake(2, 1)`.

### 6. `play_scatter_anim(p)` — granular cloud

Wide-dispersion burst: 12 tiny particles flying outward in all directions, brightness varying 7-13 (random per particle). 18 ticks. Reads as fragmentation.

Implementation: extended `ANIM.burst` with higher count + brightness randomization. Existing `ANIM.burst` may already support this; if not, a wrapper `ANIM.scatter_burst(cx, cy, n)`.

### 7. `play_slow_wheel_anim(p)` — analog phaser

A diameter line drawn through the character's center, rotating ~45° every 2 ticks (8 rotation steps total). Fades after 16 ticks. Brightness decays from 13 to 5 over the duration.

Implementation: a custom particle subtype `rotating_line` with rotation angle that advances per tick. Draws as `screen.move(cx - dx, cy - dy); screen.line(cx + dx, cy + dy)` where `dx, dy = cos(angle) * radius, sin(angle) * radius`.

### 8. `play_threefold_anim(p)` — vintage chorus

Two ghost-copies of the character spawn simultaneously at -1px and +1px (one on each side), held for 12 ticks at half brightness (level 7), then fade together over 4 ticks. Three sprites visible at once during the held phase.

Implementation: spawn two `ghost_sprite` entries via the shared helper, both lasting 16 ticks total.

### Shared helpers

A new helper added to the ANIM table, used by Long Echo and Threefold:

```lua
ANIM.ghost_sprite = function(class, x, y, brightness, ticks)
  ANIM.particles[#ANIM.particles + 1] = {
    kind = "ghost_sprite",
    class = class,
    x = x, y = y,
    bright = brightness,
    t = 0,
    dur = ticks,
  }
end
```

The ANIM tick handler is extended to render `kind == "ghost_sprite"` by calling the existing character sprite-draw function at the given x/y with overridden brightness.

For Ring, Spring, Slow Wheel: add corresponding `kind` types ("ring", "spring_line", "rotating_line") with their own per-tick render logic in the ANIM tick handler. Each render block is small (5-10 lines).

## Error Feedback (Denial States)

Four denial cases:
1. No Resonance attuned for this character class
2. Already armed (buff present, not yet consumed)
3. Not enough MP
4. On cooldown (`tick < p.reso_cooldown_until`)

All produce: bell-glyph red-flash for 4 ticks via `p.reso_denied_t = tick`, plus a distinguishing SFX:

| Cause | SFX |
|---|---|
| No attunement | Single note: cleric class, MIDI 28, vel 0.4, attack 0.005, release 0.15, wet 0 |
| Already armed | Two notes 2 ticks apart: MIDI 36, then MIDI 28 (same envelope as above) |
| Not enough MP | Three notes descending: 36, 33, 28, 1 tick apart |
| On cooldown | Single short note: MIDI 32, same envelope as above |

The HUD render loop is extended to draw the bell glyph in red (`screen.level(2)`) when `tick - p.reso_denied_t < 4`, returning to normal level after.

## Risks

1. **Visual clutter** if multiple party members invoke in quick succession. Mitigation: per-character cooldown limits frequency. If still busy in playtest, reduce particle counts in heavier animations (Scatter, Spring).
2. **Distinguishing 8 animations on 128×64**. Mitigation: SFX is the primary differentiator; visuals support. Ghost-sprite animations (Long Echo, Threefold) are most legible since they reuse the character silhouette.
3. **Slow Wheel rotation choppy at 2-tick steps**. Mitigation: increase to 1-tick steps if it reads as too discrete (tradeoff: more frequent rotation calculation).
4. **Hand-authored functions drifting in style** (Approach A risk). Mitigation: share `ANIM.ghost_sprite` helper between Long Echo and Threefold; document convention that each function stays under 20 lines.
5. **Character sprite position** during battle — the design assumes `p.battle_x, p.battle_y` exist or can be derived. If the existing code uses a different field name or computes party-row positions dynamically, the implementation needs to match.

## Acceptance Criteria

Per-character:
- Pressing R2 with an attuned Resonance, enough MP, no buff armed, off cooldown:
  - Fires signature SFX
  - Fires the correct per-Resonance animation visible on the character's sprite
  - Arms the buff (`p.ring_armed` for Ring; analogous flags for others, stubbed for non-Ring)
  - Sets cooldown to `tick + 6`
  - Does NOT set `p.last_fire` (character can immediately queue another action)
  - Does NOT display a banner

- Pressing R2 in denial cases:
  - Fires the cause-specific SFX
  - Sets `p.reso_denied_t = tick` causing 4-tick red-flash on bell glyph
  - Does NOT display a banner
  - Does NOT consume MP or arm the buff

- Animation:
  - Renders at the character's combat sprite position
  - Lasts 12-18 ticks per Resonance
  - Continues if the character is hit / KO'd mid-animation
  - Does not block input or rendering of other combat elements

- Action menu RESO item:
  - Still appears as 5th option when attuned
  - Selecting it triggers the same path as R2 (same animation, same cooldown, no turn consumed)

Across full pass:
- All 8 Resonances have distinct, recognizable animations
- All 8 SFX denial cues are distinguishable by ear after a few hearings
- `luac -p` passes
- File size growth under +5KB

## What This Spec Does NOT Cover

- **Resonance combat effects** for the 7 non-Ring Resonances. Effects stay stubbed; animations + invocation pipeline only.
- **Per-Resonance MP cost tuning**. Existing MP costs in the RESONANCES table are unchanged.
- **Save-game schema changes**. None needed; all new state is per-battle.
- **Visual companion** for the bell-glyph in non-battle states (overworld). Bell glyph only matters during battle.

## Decisions Log

| Decision | Choice |
|---|---|
| Turn cost | Free (no last_fire on RESO) |
| Cooldown | Per-character 6 ticks |
| Animation style | Sprite-attached, 12-18 ticks |
| Scope | 8 animations + Ring effect; other 7 effects stubbed |
| Error feedback | Cause-specific SFX + 4-tick bell red-flash |
| Implementation | Approach A: 8 dedicated functions |
| Action menu RESO item | Kept, routes to same fluid path |
| Save state | No changes; all new state per-battle |
