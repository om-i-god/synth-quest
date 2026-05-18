# The Ring — Combat Effect Design

**Date:** 2026-05-17
**Project:** Synth Quest (norns)
**Affected file (primary):** `synth-quest.lua`
**Builds on:** `docs/specs/2026-05-14-resonances-acquisition-design.md` (acquisition spec — shipped)

## Problem

The Resonances acquisition vertical slice shipped The Ring as a callable battle action on R2, but its actual effect is a stub: R2 deducts 6 MP, plays the signature bell, flashes a banner, and deals one normal-ATK damage as a placeholder. The bible's actual effect — *"next attack ignores enemy DEF and adds a clangor hit at +30% damage. Visually the screen shudders"* — isn't wired up.

## Goal

Replace the stub with the bible-accurate buff-then-attack behavior. Pressing R2 arms Miel; her next ATK fires the empowered hit (1.30× damage, additional clangor sound, larger burst, screen shake). The buff is per-character and per-battle; only ATK consumes it. Add a HUD indicator so the player can tell at a glance that Miel is armed.

## Non-goals

- Wiring up any of the other 7 Resonance effects. Their data rows exist; their behavior ships in follow-on specs.
- Building a generic `apply_resonance_effect(id, p)` dispatcher. Ring's behavior is inlined into the ATK branch directly. The dispatcher gets extracted when the second Resonance effect lands and we can see the pattern.
- New particle systems or new screen-shake primitives. Reuse `ANIM.burst` and `ANIM.shake`.
- A multiplier cap. The max stacked output (Ring × buffed × crit = 3.90×) stands. If playtest shows it's too much, the cap is a follow-on tweak.
- HUD glyphs for the other 7 Resonances. Bell glyph is Miel-specific.
- A telegraph on the enemy ("this enemy will take Ring damage"). Player's HUD indicator only.
- Multi-target. Battle model is single-enemy.
- Audio mix tuning. The clangor velocity / register sit at the spec's defaults; tune in playtest.
- Persistence. `p.ring_armed` does NOT serialize. Save mid-armed and the flag is gone on reload (matches `p.buffed`).
- Saving the player from a "whiffed" empowered ATK. If Miel's ATK ticks with no live enemy, the buff is consumed anyway. Matches existing `p.buffed` behavior.

## Architecture

Five touchpoints in `synth-quest.lua`:

1. **`p.ring_armed`** — single boolean per-player. Lives on the same record as `p.buffed`, `p.rhythm_charged`, `p.reflect`. Default false. Per-battle scope; not persisted.
2. **RESO branch in `apply_player_action`** (currently does stub damage at ~line 14233) — gutted: sets `p.ring_armed = true`, clears `p.queued_resonance`. No damage. MP was already deducted at queue time.
3. **R2 handler in `gamepad.analog`** (currently checks: in BATTLE, has attuned Resonance, has ≥ MP) — adds a third condition: refuse if `p.ring_armed == true` (avoids accidental double-MP burn). Brief "* already armed *" banner.
4. **ATK branch in `apply_player_action`** (~line 13259) — reads `p.ring_armed`. If true: multiplies final damage by 1.30, sets a transient `ring_fx` local, clears the flag. After `damage_enemy` returns, if `ring_fx`, fires clangor sound (root bell + fifth) + larger `ANIM.burst` + `ANIM.shake`.
5. **HUD indicator** — small bell glyph in Miel's HUD column when `p.ring_armed`, rendered inside the existing per-character HUD column loop.

Plus three reset sites: `reset_party_for_battle()`, KO path (wherever `p.buffed = false` is set on death), and revive path.

## Data model

```lua
-- Per-player record gains one field. All other p.* fields unchanged.
p.ring_armed = false  -- transient: set when RESO action fires,
                      -- consumed by next ATK, cleared on KO / battle reset.
```

No save/load changes. The flag is intentionally NOT serialized.

## RESO branch — replace the stub

**Where:** `apply_player_action(p)` RESO branch (~line 14228). Current:

```lua
elseif p.queued == "RESO" then
  local rid = p.queued_resonance
  local r   = rid and RESONANCES[rid]
  if r then
    -- (signature sound fire)
    -- (banner)
    -- stub: deal normal-ATK damage
    if enemy and enemy.alive then
      local dmg = INST.atk(p)
      damage_enemy(dmg, false)
    end
    p.last_fire = tick
    p.last_action = "RESO"
  end
```

**New:**

```lua
elseif p.queued == "RESO" then
  local rid = p.queued_resonance
  local r   = rid and RESONANCES[rid]
  if r then
    -- Signature sound (existing wiring — bell tone via sq_trig). KEEP.
    -- Banner "* The Ring *" (existing wiring). KEEP.
    -- Arm the buff. The next ATK by this character will fire the
    -- empowered hit (1.30x damage + clangor + shake + burst).
    if rid == "ring" then
      p.ring_armed = true
    end
    -- Future Resonances dispatch on rid here as they're added.
    p.queued_resonance = nil
    p.last_fire = tick
    p.last_action = "RESO"
  end
```

The existing signature-sound and banner code stays. The only deletion is the stub damage block.

## ATK branch — read and consume

**Where:** the ATK branch in `apply_player_action` (~line 13259). Insert the Ring multiplier AFTER the existing `crit` and `p.buffed` multipliers (so it stacks multiplicatively with both) and BEFORE the `damage_enemy` call.

```lua
if p.queued == "ATK" then
  if enemy and enemy.alive then
    local dmg = INST.atk(p)
    local rhythm_was_set = p.rhythm_charged
    local crit = p.rhythm_charged or (math.random() < ANIM.crit)
    p.rhythm_charged = false
    if rhythm_was_set and unlock_achievement then
      unlock_achievement("first_rhythm_crit", "On the Beat")
    end
    if crit then dmg = dmg * 2 end
    if p.buffed then dmg = math.floor(dmg * 1.5); p.buffed = false end
    -- The Ring (Miel's Resonance): empowered next-attack. 1.30x damage,
    -- additional clangor sound + larger burst + screen shake. Stacks
    -- multiplicatively with crit and buffed (the bell amplifies what
    -- the attack already is).
    local ring_fx = false
    if p.ring_armed then
      dmg = math.floor(dmg * 1.30)
      p.ring_armed = false
      ring_fx = true
    end
    damage_enemy(dmg, crit)
    if ring_fx then
      -- Clangor: root bell + a fifth above. Same class voice (cleric)
      -- as the signature sound; the fifth is the "harmonics no one
      -- could place" beat from the bible.
      local sig = RESONANCE_SITES.ring and RESONANCE_SITES.ring.shrine
                  and RESONANCE_SITES.ring.shrine.signature
      if sig and sig.sound then
        local s = sig.sound
        sq_trig(s.class, midi_to_freq(s.note),
                s.vel or 0.7, s.attack or 0.05, s.release or 4.0,
                math.min(1, (s.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
        sq_trig(s.class, midi_to_freq(s.note + 7),
                0.55, 0.005, 2.0,
                math.min(1, (s.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
      end
      ANIM.burst(96, 32, 10, 15)
      ANIM.shake(2, 10)
    end
  end
  -- ... rest of ATK branch (note_idx increment, etc.) ...
```

**Multiplier table** (for reference, all combinations a Miel ATK can take):

| Combo | Multiplier | Notes |
|---|---|---|
| ATK | ×1.0 | baseline |
| ATK + crit | ×2.0 | existing |
| ATK + buffed | ×1.5 | existing (PLAY arms it) |
| ATK + Ring | ×1.30 | new |
| ATK + crit + Ring | ×2.60 | bell amplifies crit |
| ATK + buffed + Ring | ×1.95 | bell amplifies buff |
| ATK + crit + buffed + Ring | ×3.90 | rare; three setups aligned |

## R2 handler — refuse if already armed

**Where:** the R2 (`triggerright`) branch in `gamepad.analog` (~line 15890). Currently checks two conditions in order: has attuned Resonance for this class? has enough MP? Add a third:

```lua
-- After the rid lookup, before the MP check, add:
if p.ring_armed then
  CONTENT.banner_text  = "* already armed *"
  CONTENT.banner_ticks = 36
  CONTENT._r2_prev = now_pressed
  return
end
```

This sits between the "no attuned Resonance" banner and the "not enough MP" banner. Same banner-ticks duration (36) as the other two for consistency.

## Reset sites — clear on death + battle start

**`reset_party_for_battle()`** (~line 11405). Find the existing block that clears per-battle flags:

```lua
p.shield = false
p.buffed = false
p.blocking = false
p.reflect = false
p.reflect_ticks = 0
p.limit_used = false
```

Add `p.ring_armed = false` to this list (anywhere in the block — order doesn't matter).

**KO path.** Find every site where `p.buffed = false` is set on death/revive (grep target: `p.buffed = false`). Add `p.ring_armed = false` adjacent to each. Likely sites: the damage path when `p.hp` drops to 0, and the revive path in HEAL.

## HUD indicator

**Where:** inside the per-character HUD column loop at `synth-quest.lua:21439-21461` (just after the `p.rhythm_charged` indicator block that ends at line ~21462).

**Glyph (5×5 pixels, drawn as discrete pixels):**

```
.###.    rows 0:    ###
#####    row 1:   #####
#####    row 2:   #####
.###.    row 3:    ###
..#..    row 4:     #
```

**Render code:**

```lua
-- The Ring armed indicator (Miel-specific). Bell silhouette in
-- the top-right of the HUD column, slower pulse than the rhythm
-- glyph so the two read as distinct when both are armed at once.
if p.ring_armed and p.alive then
  local bx = cx + 25  -- 2px left of the rhythm-charged ♪ position
  local by = 49
  local lev = ((tick % 24) < 12) and 13 or 15
  screen.level(lev)
  -- row 0 (bell crown): 3 wide, centered
  screen.pixel(bx + 1, by);     screen.pixel(bx + 2, by);     screen.pixel(bx + 3, by)
  -- row 1-2 (body): full 5 wide
  for c = 0, 4 do
    screen.pixel(bx + c, by + 1); screen.pixel(bx + c, by + 2)
  end
  -- row 3 (mouth narrows): 3 wide centered
  screen.pixel(bx + 1, by + 3); screen.pixel(bx + 2, by + 3); screen.pixel(bx + 3, by + 3)
  -- row 4 (clapper): single center pixel
  screen.pixel(bx + 2, by + 4)
  screen.fill()
end
```

**Disappearance:** drawn only when the flag is true. The moment the ATK branch clears `p.ring_armed`, the next redraw skips this block. No fade — just on/off, matching the existing `♪` indicator.

## Edge cases

| Situation | Behavior |
|---|---|
| R2 spam while already armed | Refused; "* already armed *" banner; no MP deducted |
| R2 with < 6 MP | Existing "* not enough MP *" banner; no queue, no flag |
| R2 outside BATTLE | Existing no-op |
| Miel dies while armed | `p.ring_armed = false` on KO; MP gone (no refund) |
| Miel revived after dying armed | Stays cleared — has to re-arm |
| Player switches active character with L1/R1 while Miel is armed | Flag persists on Miel; HUD bell shows on Miel's column regardless of who's active |
| Miel queues HEAL or DEF or other action while armed | Buff persists (only ATK consumes it) |
| Miel's ATK whiffs (no live enemy) | Buff IS consumed (matches `p.buffed`) |
| Player dpad-cycles between actions before firing | Buff stays — only the actual ATK tick consumes |
| Battle ends mid-armed | Flag cleared in `reset_party_for_battle()` at next battle start |
| Save mid-armed | Flag is lost on save (not serialized); reload starts cleared |
| D-pad cycle lands on RESO without firing | No arming. The action-tick is the canonical "press happened." |

## Acceptance criteria

1. Pressing R2 with Miel attuned + ≥ 6 MP + not already armed: HUD label changes to RESO, 6 MP deducted, action fires when tick lands, bell signature sound plays, "* The Ring *" banner shows, `p.ring_armed = true` afterward, HUD bell indicator appears on Miel's column. **No damage to enemy from the RESO action itself.**
2. Next ATK Miel queues (A press, dpad-cycle, or rhythm-tick): enemy takes `INST.atk(Miel) × 1.30` damage (with crit/buffed stacking), root bell + fifth play via two `sq_trig` calls, screen shakes, larger particle burst at the enemy position. `p.ring_armed = false` after.
3. R2 with `p.ring_armed == true`: "* already armed *" banner, no MP deducted, no second arming.
4. R2 with < 6 MP: existing behavior unchanged.
5. R2 with non-cleric active or no attuned Resonance: existing behavior unchanged.
6. Miel dies while armed: `p.ring_armed` is false after the KO. Revive does not restore.
7. Battle ends + new battle starts: `p.ring_armed = false` at battle entry regardless of prior state.
8. Save while armed, quit, reload: `p.ring_armed = false` (not serialized).
9. Player switches active away from Miel while she's armed: HUD bell still shows on Miel's column.
10. Stacking math: a Miel ATK with crit + buffed + Ring deals `floor(INST.atk(Miel) × 2 × 1.5 × 1.30)` damage.

## Files & locations

- `synth-quest.lua:11405` (`reset_party_for_battle`) — add `p.ring_armed = false` to the per-battle reset block.
- `synth-quest.lua:13259` (ATK branch in `apply_player_action`) — insert the Ring multiplier + ring_fx block after the `p.buffed` consumption and before `damage_enemy`.
- `synth-quest.lua:14228` (RESO branch in `apply_player_action`) — replace the stub damage block with `p.ring_armed = true`.
- `synth-quest.lua:15890` (R2 handler in `gamepad.analog`) — add the `p.ring_armed` refuse-branch before the MP check.
- `synth-quest.lua:21462` (HUD column draw, just after rhythm-charged indicator) — add the bell glyph render block.
- `synth-quest.lua` (KO/death sites — grep `p.buffed = false`) — add `p.ring_armed = false` adjacent to each.
- `~/dev/synth-quest/backups/` — snapshot before the pass per project convention.

## Risks

- **Stacking damage feels too high.** 3.90× max with all three buffs aligned might one-shot enemies it shouldn't. Mitigation: playtest, add a cap only if needed. Don't pre-optimize.
- **Clangor audio is muddy.** Two `sq_trig` calls layered on the cleric voice with no decay separation might smear. If so, tune the second `sq_trig`'s `attack` higher (more like 0.05) or shorten its `release`.
- **HUD bell competes visually with the rhythm-charged `♪`.** Placement (`cx + 25`) leaves room for both but they may visually crowd in the 32px column. If so, move the bell to `cx + 21` or stack vertically.
- **Player keeps arming Ring and never firing it because they get distracted in battle.** Acceptable. The arm is sticky by design — that's the point.
- **`p.ring_armed` survives unintentionally across a battle if `reset_party_for_battle` is bypassed on a specific entry path.** Audit by running through the prologue + cave 1 + cave 2 entry paths to confirm the reset fires.

## Out of scope (deferred)

- Generic `apply_resonance_effect(id, p)` dispatcher (extract when second effect lands).
- The other 7 Resonance effects.
- Multi-target Ring.
- Cap on stacked multipliers.
- HUD glyphs for the other 7 Resonances.
- Re-arm via menu or D-pad cycle (the action-tick is the canonical arming moment).
- Audio mix tuning.
- Telegraph on the enemy sprite.
- Custom Ring crit visual beyond `ANIM.burst` + `ANIM.shake`.
