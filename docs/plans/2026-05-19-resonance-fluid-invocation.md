# Resonance Fluid Invocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the turn-consuming, banner-displaying Resonance invocation with a fluid, animated combat flourish — free invocation, 8 distinct sprite-attached animations, per-character 6-tick cooldown, non-blocking denial feedback (SFX + bell-glyph red-flash).

**Architecture:** All work in `synth-quest.lua`. Extends the existing `ANIM` particle system with typed particles (kind field) and adds a per-Resonance animation dispatcher. Removes `p.last_fire` setting from the RESO action; adds `p.reso_cooldown_until` and `p.reso_denied_t` per-battle fields. Eight hand-authored `play_<id>_invocation_anim(p)` functions.

**Tech Stack:** Lua 5.4 on norns; existing ANIM particle pool + screen.* primitives; SuperCollider engine `Engine_SynthQuest.sc` for SFX (unchanged).

**Spec reference:** `docs/specs/2026-05-19-resonance-fluid-invocation-design.md`

**Sprite position reference:**
- Party member `index i` sprite at battle: `(cx + 1, 49)` where `cx = (i-1) * 32 + 17`
- Sprite center for animations: `(cx + 5, 53)`
- Sprite is 8×8 px
- Helper exists: `ANIM.party_hud_x(p)` returns `cx` for a given party ref `p`

---

## File Structure

Only one file modified: `synth-quest.lua`. Changes cluster in these regions:

| Region | Purpose | Approx. lines |
| --- | --- | --- |
| `ANIM` table definition | Extend particles with `kind` field, add `ANIM.ghost_sprite` helper | ~5356-5388 |
| Particle render loop | Add render branches for new kinds (ring, ghost_sprite, spring_line, rotating_line) | ~28326-28337 |
| `apply_player_action` RESO branch | Remove `p.last_fire = tick`; call animation dispatcher; set cooldown | ~15902-15931 |
| R2 handler (gamepad.trigger) | Replace banners with cause-specific SFX + `p.reso_denied_t` | ~17615-17653 |
| HUD bell-glyph render | Red-flash when `tick - p.reso_denied_t < 4` | ~24955-24970 |
| `enter_battle` / `exit_battle` | Clear new per-battle fields | (search by name) |
| New per-Resonance functions | 8 `play_<id>_invocation_anim(p)` functions + RESO_ANIMS dispatch table | New block, near other animation helpers |

**Backup discipline:** Per the standing rule (memory `synth-quest-backups`), snapshot `~/dev/synth-quest/synth-quest.lua` to `~/dev/synth-quest/backups/` after the implementation lands. No bible changes in this pass; bible snapshot not needed.

---

## Task 1: Typed particles in ANIM

**Files:**
- Modify: `synth-quest.lua` — `ANIM.burst` (~line 5374), particle render loop (~line 28326)

- [ ] **Step 1: Read the existing particle code**

Run: `cd ~/dev/synth-quest && sed -n '5356,5390p' synth-quest.lua`
Confirm the `ANIM.particles[#ANIM.particles + 1] = { x, y, vx, vy, t, lev }` shape and the render loop at line 28326-28337.

- [ ] **Step 2: Update ANIM.burst to write a `kind` field**

Locate `ANIM.burst` (line ~5374). Change the particle table to include `kind = "spark"` so existing behavior is unchanged but particles are typed:

```lua
ANIM.burst = function(cx, cy, n, lev)
  for i = 1, (n or 8) do
    local ang = (i / (n or 8)) * math.pi * 2 + math.random() * 0.4
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "spark",
      x = cx, y = cy,
      vx = math.cos(ang) * (1.2 + math.random() * 0.8),
      vy = math.sin(ang) * (1.2 + math.random() * 0.8),
      t = tick, lev = lev or 15,
    }
  end
end
```

- [ ] **Step 3: Update the particle render loop to branch on `kind`**

Locate the render loop at line ~28326. Wrap the existing render in a kind check, defaulting to "spark" for old particles missing the field (back-compat for any in-flight particle):

```lua
for i = #ANIM.particles, 1, -1 do
  local pcl = ANIM.particles[i]
  local age = tick - pcl.t
  local kind = pcl.kind or "spark"
  local dur  = pcl.dur or 12
  if age >= dur then
    table.remove(ANIM.particles, i)
  else
    if kind == "spark" then
      local px = math.floor(pcl.x + pcl.vx * age + 0.5)
      local py = math.floor(pcl.y + pcl.vy * age + 0.5)
      screen.level(math.max(2, pcl.lev - age))
      screen.pixel(px, py); screen.fill()
    end
    -- Other kinds added in later tasks (ring, ghost_sprite, spring_line, rotating_line)
  end
end
```

Note: the existing render is hardcoded `age >= 12`. Replace with `pcl.dur or 12` so each particle can have its own lifetime.

- [ ] **Step 4: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`
Expected: `SYNTAX OK`

Existing `ANIM.burst` calls (e.g. damage bursts at line 12912) should still produce visually identical bursts since they default to `kind = "spark"` and `dur = 12`.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat(anim): add typed particles with kind field"
```

---

## Task 2: Add ANIM.ghost_sprite helper

**Files:**
- Modify: `synth-quest.lua` — ANIM table definition area (~line 5388)

- [ ] **Step 1: Find SPRITE_BY_CLASS**

Run: `cd ~/dev/synth-quest && grep -n "SPRITE_BY_CLASS\s*=" synth-quest.lua | head -3`
Expected: a table mapping class name (bard/cleric/warrior/mage) to a sprite-draw function. Confirm it takes `(sx, sy)`.

- [ ] **Step 2: Add ANIM.ghost_sprite**

Add immediately after `ANIM.dust_puff` definition (around line 5388):

```lua
ANIM.ghost_sprite = function(class, x, y, brightness, ticks)
  ANIM.particles[#ANIM.particles + 1] = {
    kind = "ghost_sprite",
    class = class,
    x = x, y = y,
    bright = brightness or 8,
    t = tick,
    dur = ticks or 14,
  }
end
```

- [ ] **Step 3: Extend the particle render loop with the ghost_sprite branch**

Inside the kind dispatch added in Task 1, add (after the `kind == "spark"` block, before the closing `end`):

```lua
elseif kind == "ghost_sprite" then
  -- Render the character's sprite at half-or-less brightness using
  -- screen.peek/poke is not available; instead, call SPRITE_BY_CLASS
  -- inside a level-clamped block. We approximate "lower brightness"
  -- by drawing a 1-px outline at the requested level instead of the
  -- full sprite — same silhouette, much dimmer.
  local b = math.max(2, pcl.bright - math.floor(age / 2))
  screen.level(b)
  screen.rect(pcl.x, pcl.y, 8, 8); screen.stroke()
```

**Note:** the norns screen API doesn't support per-sprite brightness override. The simplest approach is an 8×8 silhouette-outline at the requested brightness — visually conveys "ghost" without needing the full sprite. An alternative (calling `SPRITE_BY_CLASS[class](pcl.x, pcl.y)` which internally sets levels) would draw at full brightness, which defeats the "ghost" feel. Outline approach chosen.

- [ ] **Step 4: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 5: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat(anim): add ghost_sprite particle kind for Resonance animations"
```

---

## Task 3: Add per-Resonance animation function stubs + RESO_ANIMS dispatcher

**Files:**
- Modify: `synth-quest.lua` — add a new block near other animation helpers (after ANIM definitions)

- [ ] **Step 1: Find a good insertion point**

Run: `cd ~/dev/synth-quest && grep -n "^local function damage_party\|^local function apply_player_action" synth-quest.lua | head -3`
Pick a line BEFORE `damage_party` (which is at line ~15541) — insert before that, so functions are defined before they're referenced.

A safe location: right after the `ANIM.party_hud_x` definition (~line 15539).

- [ ] **Step 2: Add 8 function stubs + dispatcher**

Insert this block after `ANIM.party_hud_x`:

```lua
-- ── Resonance invocation animations ──────────────────────────────────
-- Each function spawns particles attached to the casting character's
-- combat sprite position. See docs/specs/2026-05-19-resonance-fluid-
-- invocation-design.md for the per-Resonance vocabulary.
-- Sprite position for party member p: (cx+1, 49) where cx = ANIM.party_hud_x(p).
-- Animations target sprite center (cx+5, 53) unless otherwise noted.

function play_ring_anim(p)
  -- stub — implemented in Task 5
end

function play_long_echo_anim(p)
  -- stub — implemented in Task 6
end

function play_threefold_anim(p)
  -- stub — implemented in Task 7
end

function play_masked_voice_anim(p)
  -- stub — implemented in Task 8
end

function play_spring_anim(p)
  -- stub — implemented in Task 9
end

function play_heavy_hand_anim(p)
  -- stub — implemented in Task 10
end

function play_scatter_anim(p)
  -- stub — implemented in Task 11
end

function play_slow_wheel_anim(p)
  -- stub — implemented in Task 12
end

RESO_ANIMS = {
  ring         = play_ring_anim,
  long_echo    = play_long_echo_anim,
  threefold    = play_threefold_anim,
  masked_voice = play_masked_voice_anim,
  spring       = play_spring_anim,
  heavy_hand   = play_heavy_hand_anim,
  scatter      = play_scatter_anim,
  slow_wheel   = play_slow_wheel_anim,
}
```

The functions and table are intentionally globals (no `local`) because the file has hit Lua's 200-local-variable-per-chunk limit several times in past tasks.

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK" && grep -nc "play_ring_anim\|play_long_echo_anim\|play_threefold_anim\|play_masked_voice_anim\|play_spring_anim\|play_heavy_hand_anim\|play_scatter_anim\|play_slow_wheel_anim" synth-quest.lua`
Expected: SYNTAX OK and at least 16 matches (each function name appears twice: definition + dispatcher entry).

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: Resonance animation function stubs + RESO_ANIMS dispatch table"
```

---

## Task 4: Fluid invocation flow (remove turn cost, add cooldown, call dispatcher)

**Files:**
- Modify: `synth-quest.lua` — `apply_player_action` RESO branch (~line 15902-15931); `enter_battle` and `exit_battle` for state cleanup

- [ ] **Step 1: Locate the current RESO branch**

Run: `cd ~/dev/synth-quest && grep -n 'p.queued == "RESO"' synth-quest.lua`
Expected: one match around line 15902 (in `apply_player_action`).

- [ ] **Step 2: Replace the RESO branch**

Replace the existing RESO branch (the `elseif p.queued == "RESO" then ... end` block) with:

```lua
elseif p.queued == "RESO" then
  -- Fluid invocation: SFX + animation + arm buff. Does NOT consume the
  -- firing slot (no p.last_fire set). Sets a 6-tick per-character
  -- Resonance cooldown to prevent re-invoke spam.
  -- See docs/specs/2026-05-19-resonance-fluid-invocation-design.md.
  local rid = p.queued_resonance
  local r   = rid and RESONANCES[rid]
  if r then
    -- Signature SFX
    local sig = RESONANCE_SITES[rid] and RESONANCE_SITES[rid].shrine and RESONANCE_SITES[rid].shrine.signature
    if sig and sig.sound then
      sq_trig(sig.sound.class, midi_to_freq(sig.sound.note),
              sig.sound.vel or 0.7,
              sig.sound.attack or 0.05,
              sig.sound.release or 4.0,
              math.min(1, (sig.sound.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
    end
    -- Per-Resonance animation
    if RESO_ANIMS and RESO_ANIMS[rid] then
      RESO_ANIMS[rid](p)
    end
    -- Arm the per-Resonance buff (only Ring has a real effect this pass).
    if rid == "ring" then
      p.ring_armed = true
    end
    -- Per-character 6-tick cooldown — separate from firing slot.
    p.reso_cooldown_until = tick + 6
    p.queued_resonance = nil
    -- NOTE: deliberately do NOT set p.last_fire. RESO is fluid; the
    -- character can immediately queue another action in the same tick.
    p.last_action = "RESO"
  end
end
```

Three deliberate changes from the previous code:
1. Removed the `p.last_fire = tick` line.
2. Added `RESO_ANIMS[rid](p)` call between SFX and buff-arm.
3. Added `p.reso_cooldown_until = tick + 6`.

- [ ] **Step 3: Find enter_battle and exit_battle**

Run: `cd ~/dev/synth-quest && grep -n "^local function enter_battle\|^local function exit_battle\|^function enter_battle\|^function exit_battle" synth-quest.lua`
Expected: two function definitions.

- [ ] **Step 4: Clear per-battle fields in both functions**

In each function (enter_battle and exit_battle), find where party state is initialized/reset. Add to BOTH (matching the existing party-loop pattern):

```lua
for _, p in ipairs(party) do
  p.reso_cooldown_until = 0
  p.reso_denied_t = -99
  p.ring_armed = false
end
```

If a similar party-reset loop already exists, append the three new fields to that loop instead of adding a separate one.

- [ ] **Step 5: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`
Run: `cd ~/dev/synth-quest && grep -n "p.reso_cooldown_until\|p.reso_denied_t" synth-quest.lua | head -10`
Expected: SYNTAX OK + at least 4 matches (apply_player_action, R2 handler in next task, enter_battle, exit_battle).

- [ ] **Step 6: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: free Resonance invocation; per-character cooldown"
```

---

## Task 5: Implement play_ring_anim (concentric rings)

**Files:**
- Modify: `synth-quest.lua` — replace the `play_ring_anim` stub from Task 3; add `ring` kind to the particle render branch

- [ ] **Step 1: Replace the play_ring_anim stub**

```lua
function play_ring_anim(p)
  -- Ring modulator: 3 concentric expanding pixel rings from the character's
  -- sprite center. Brightness 15, 13, 11; radii expand 1px/tick.
  local cx = ANIM.party_hud_x(p) + 5   -- sprite center x
  local cy = 53                         -- sprite center y
  for i = 0, 2 do
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "ring",
      x = cx, y = cy,
      r0 = 1 + i * 2,        -- starting radius for this ring
      lev = 15 - i * 2,      -- 15, 13, 11
      t = tick + i * 2,      -- staggered start (T0, T+2, T+4)
      dur = 14,
    }
  end
end
```

- [ ] **Step 2: Add `ring` render kind to the particle loop**

In the particle render loop (extended in Task 1+2), add this branch:

```lua
elseif kind == "ring" then
  local r = (pcl.r0 or 1) + age
  if age >= 0 and r > 0 then
    screen.level(math.max(2, (pcl.lev or 15) - age))
    screen.circle(pcl.x, pcl.y, r); screen.stroke()
  end
```

Note: `age` may be negative for staggered rings (since `t = tick + 2 * i`). The `age >= 0` guard prevents drawing before the stagger fires.

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

Visual verification on hardware deferred to user playtest.

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_ring_anim (concentric rings) + ring particle kind"
```

---

## Task 6: Implement play_long_echo_anim (ghost trail)

**Files:**
- Modify: `synth-quest.lua` — replace the `play_long_echo_anim` stub

- [ ] **Step 1: Replace the stub**

```lua
function play_long_echo_anim(p)
  -- Tape echo two-head: two ghost-copies of the character spawn at +1px
  -- and +2px to the right of the live sprite. The closer copy fades over
  -- 6 ticks, the further copy over 10. Reads as the singer echoing.
  local cx = ANIM.party_hud_x(p) + 1   -- sprite top-left x (matches draw_battle)
  local sy = 49
  ANIM.ghost_sprite(p.class, cx + 1, sy, 8, 6)
  ANIM.ghost_sprite(p.class, cx + 2, sy, 4, 10)
end
```

- [ ] **Step 2: Verify ghost_sprite kind renders correctly**

The `ghost_sprite` kind was added in Task 2. Confirm by running:
```bash
cd ~/dev/synth-quest && grep -n 'kind == "ghost_sprite"' synth-quest.lua
```
Expected: one match in the particle render loop.

- [ ] **Step 3: Syntax check**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_long_echo_anim (ghost trail)"
```

---

## Task 7: Implement play_threefold_anim (chorus doubling)

**Files:**
- Modify: `synth-quest.lua` — replace the `play_threefold_anim` stub

- [ ] **Step 1: Replace the stub**

```lua
function play_threefold_anim(p)
  -- Vintage chorus: two ghost-copies spawn at -1px and +1px simultaneously,
  -- both held at brightness 7 for 12 ticks then fade over 4. Three sprites
  -- visible at once during the held phase.
  local cx = ANIM.party_hud_x(p) + 1
  local sy = 49
  ANIM.ghost_sprite(p.class, cx - 1, sy, 7, 16)
  ANIM.ghost_sprite(p.class, cx + 1, sy, 7, 16)
end
```

- [ ] **Step 2: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 3: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_threefold_anim (chorus doubling)"
```

---

## Task 8: Implement play_masked_voice_anim (mask + upward drift)

**Files:**
- Modify: `synth-quest.lua` — replace `play_masked_voice_anim` stub; add `mask_bar` kind

- [ ] **Step 1: Replace the stub**

```lua
function play_masked_voice_anim(p)
  -- Vocoder: thin horizontal bar overlays the character's eyes for 4 ticks,
  -- then dissipates upward as 3 small particles drifting straight up.
  local cx = ANIM.party_hud_x(p) + 1
  local sy = 49
  -- The mask bar (custom kind that auto-removes after 4 ticks)
  ANIM.particles[#ANIM.particles + 1] = {
    kind = "mask_bar",
    x = cx + 1, y = sy + 2,
    w = 6, h = 1,
    lev = 13,
    t = tick, dur = 4,
  }
  -- 3 upward-drifting sparks after the bar dissipates
  for i = 1, 3 do
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "spark",
      x = cx + 1 + (i * 2),
      y = sy + 2,
      vx = 0,
      vy = -0.4,
      t = tick + 4, lev = 11,
    }
  end
end
```

- [ ] **Step 2: Add `mask_bar` render kind**

In the particle render loop, add:

```lua
elseif kind == "mask_bar" then
  if age >= 0 then
    screen.level(math.max(2, (pcl.lev or 13) - age * 2))
    screen.rect(pcl.x, pcl.y, pcl.w or 6, pcl.h or 1); screen.fill()
  end
```

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_masked_voice_anim (mask bar + upward drift) + mask_bar kind"
```

---

## Task 9: Implement play_spring_anim (horizontal wavy lines)

**Files:**
- Modify: `synth-quest.lua` — replace `play_spring_anim` stub; add `spring_line` kind

- [ ] **Step 1: Replace the stub**

```lua
function play_spring_anim(p)
  -- Spring reverb: 4 horizontal wavy pixel-lines emanate left and right
  -- from the character, sinusoidally oscillating outward. Fades over 14.
  local cx = ANIM.party_hud_x(p) + 5
  local cy = 53
  for i = 1, 4 do
    local dir = (i % 2 == 0) and 1 or -1
    local y_offset = (i <= 2) and -2 or 2
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "spring_line",
      x = cx, y = cy + y_offset,
      vx = dir * 0.8,
      lev = 13,
      t = tick + (i - 1), dur = 14,
    }
  end
end
```

- [ ] **Step 2: Add `spring_line` render kind**

```lua
elseif kind == "spring_line" then
  if age >= 0 then
    local x = math.floor(pcl.x + pcl.vx * age + 0.5)
    local y = math.floor(pcl.y + math.sin(age * 0.6) * 2 + 0.5)
    screen.level(math.max(2, (pcl.lev or 13) - age))
    screen.pixel(x, y); screen.fill()
  end
```

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_spring_anim (wavy lines) + spring_line kind"
```

---

## Task 10: Implement play_heavy_hand_anim (downward burst + shake)

**Files:**
- Modify: `synth-quest.lua` — replace `play_heavy_hand_anim` stub

- [ ] **Step 1: Replace the stub**

```lua
function play_heavy_hand_anim(p)
  -- Sidechain compressor: 6 particles falling DOWNWARD from the character,
  -- plus 1-tick screen shake (magnitude 2). Particles use the existing
  -- "spark" kind with downward-biased velocity. Lifespan 10 ticks.
  local cx = ANIM.party_hud_x(p) + 5
  local cy = 53
  for i = 1, 6 do
    local ang = (math.pi / 6) * (i - 3.5)   -- spread roughly downward
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "spark",
      x = cx, y = cy,
      vx = math.sin(ang) * 0.6,
      vy = math.abs(math.cos(ang)) * 1.4 + 0.4,    -- biased downward
      t = tick, lev = 15, dur = 10,
    }
  end
  ANIM.shake(2, 1)
end
```

- [ ] **Step 2: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 3: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_heavy_hand_anim (downward burst + shake)"
```

---

## Task 11: Implement play_scatter_anim (wide-dispersion burst)

**Files:**
- Modify: `synth-quest.lua` — replace `play_scatter_anim` stub

- [ ] **Step 1: Replace the stub**

```lua
function play_scatter_anim(p)
  -- Granular cloud: 12 tiny particles flying outward in all directions,
  -- with randomized brightness 7-13 each. Lifespan 18 ticks. Fragmentation feel.
  local cx = ANIM.party_hud_x(p) + 5
  local cy = 53
  for i = 1, 12 do
    local ang = math.random() * math.pi * 2
    local speed = 0.6 + math.random() * 1.0
    ANIM.particles[#ANIM.particles + 1] = {
      kind = "spark",
      x = cx, y = cy,
      vx = math.cos(ang) * speed,
      vy = math.sin(ang) * speed,
      t = tick,
      lev = 7 + math.random(0, 6),
      dur = 18,
    }
  end
end
```

- [ ] **Step 2: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 3: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_scatter_anim (wide-dispersion burst)"
```

---

## Task 12: Implement play_slow_wheel_anim (rotating diameter line)

**Files:**
- Modify: `synth-quest.lua` — replace `play_slow_wheel_anim` stub; add `rotating_line` kind

- [ ] **Step 1: Replace the stub**

```lua
function play_slow_wheel_anim(p)
  -- Analog phaser: a diameter line drawn through the character's sprite
  -- center, rotating ~45° every 2 ticks. Fades after 16. Reads as a wheel.
  local cx = ANIM.party_hud_x(p) + 5
  local cy = 53
  ANIM.particles[#ANIM.particles + 1] = {
    kind = "rotating_line",
    x = cx, y = cy,
    radius = 6,
    lev = 13,
    t = tick, dur = 16,
  }
end
```

- [ ] **Step 2: Add `rotating_line` render kind**

```lua
elseif kind == "rotating_line" then
  if age >= 0 then
    local angle = age * (math.pi / 8)    -- ~22.5° per tick → ~45° per 2 ticks
    local r = pcl.radius or 6
    local dx = math.cos(angle) * r
    local dy = math.sin(angle) * r
    screen.level(math.max(2, (pcl.lev or 13) - math.floor(age / 2)))
    screen.move(pcl.x - dx, pcl.y - dy)
    screen.line(pcl.x + dx, pcl.y + dy)
    screen.stroke()
  end
```

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: play_slow_wheel_anim (rotating line) + rotating_line kind"
```

---

## Task 13: R2 handler — denial SFX + bell-glyph flash (replace banners)

**Files:**
- Modify: `synth-quest.lua` — R2 handler (~line 17615-17653)

- [ ] **Step 1: Locate the R2 handler**

Run: `cd ~/dev/synth-quest && grep -n 'CONTENT\._r2_prev\|"no resonance attuned"\|"already armed"\|"not enough MP"' synth-quest.lua`
Expected: matches showing the handler with three banner-error sites.

- [ ] **Step 2: Replace banner errors with denial SFX + flag**

The handler currently has three error paths setting `banner_text` for: no resonance, already armed, low MP. Plus a new fourth case for cooldown. Replace with cause-specific SFX + `p.reso_denied_t = tick`:

```lua
-- ONE-SHOT: rising-edge queues RESO action for the active character
-- in battle. Same drift-resistant pattern as triggerleft.
local now_pressed = (val / half_reso) > 0.2
if now_pressed and not CONTENT._r2_prev then
  if game_state == "BATTLE" then
    local p = party[active]
    if p and p.alive then
      local rid = nil
      for id, r in pairs(RESONANCES) do
        if r.character == p.class
           and CONTENT.resonances[id]
           and CONTENT.resonances[id].attuned then
          rid = id; break
        end
      end
      local denial = nil
      if not rid then
        denial = "no_attune"
      elseif p.ring_armed then
        denial = "already_armed"
      elseif p.mp < RESONANCES[rid].mp_cost then
        denial = "low_mp"
      elseif p.reso_cooldown_until and tick < p.reso_cooldown_until then
        denial = "cooldown"
      end
      if denial then
        p.reso_denied_t = tick
        -- Cause-specific denial SFX (all cleric class, short releases)
        if denial == "no_attune" then
          sq_trig("cleric", midi_to_freq(28), 0.4, 0.005, 0.15, 0)
        elseif denial == "already_armed" then
          sq_trig("cleric", midi_to_freq(36), 0.4, 0.005, 0.15, 0)
          -- second note 2 ticks later via a queued one-shot would be nice;
          -- simplest: fire them back-to-back. The sound is one beat anyway.
          sq_trig("cleric", midi_to_freq(28), 0.35, 0.005, 0.15, 0)
        elseif denial == "low_mp" then
          sq_trig("cleric", midi_to_freq(36), 0.4, 0.005, 0.15, 0)
          sq_trig("cleric", midi_to_freq(33), 0.35, 0.005, 0.15, 0)
          sq_trig("cleric", midi_to_freq(28), 0.3, 0.005, 0.15, 0)
        elseif denial == "cooldown" then
          sq_trig("cleric", midi_to_freq(32), 0.3, 0.005, 0.12, 0)
        end
      else
        -- Success path: deduct MP and queue RESO
        p.queued = "RESO"
        p.queued_resonance = rid
        p.mp = p.mp - RESONANCES[rid].mp_cost
        p.prev_queued = nil
        p.jamming = false
      end
      redraw()
    end
  end
end
CONTENT._r2_prev = now_pressed
return
```

**Note:** the back-to-back `sq_trig` calls for "already armed" and "low mp" fire simultaneously, not sequentially. Norns audio is non-blocking and there's no built-in delay queue. The combined effect reads as a brief chord rather than a sequence — acceptable for denial feedback. If sequential is preferred later, a small `pending_sfx` queue ticked by the main game loop can be added — out of scope for this pass.

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`
Run: `cd ~/dev/synth-quest && grep -n 'banner_text.*resonance\|banner_text.*already armed\|banner_text.*not enough MP' synth-quest.lua`
Expected: no matches (the three banner strings are gone).

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: R2 denial SFX + reso_denied_t flag (replaces error banners)"
```

---

## Task 14: HUD bell-glyph red-flash on denial

**Files:**
- Modify: `synth-quest.lua` — HUD bell-glyph render block (~line 24955-24970)

- [ ] **Step 1: Locate the bell-glyph render**

Run: `cd ~/dev/synth-quest && grep -n "p.ring_armed and p.alive\|bell crown" synth-quest.lua | head -3`
Expected: bell-glyph render block around line 24955.

- [ ] **Step 2: Add the red-flash branch**

The existing block renders the bell ONLY when `p.ring_armed` is true. We want a 4-tick red-flash on `reso_denied_t` regardless of armed state. Add immediately BEFORE the existing `if p.ring_armed` block:

```lua
-- Denial feedback: brief red-flash on the bell glyph slot whenever
-- a Resonance invocation was rejected. Renders even when no buff is
-- armed, so the player gets a clear visual cue.
if p.reso_denied_t and (tick - p.reso_denied_t) < 4 and p.alive then
  local bx, by = cx + 25, 49
  screen.level(3)   -- dim red-ish (norns is grayscale; level 3 reads as dim/wrong)
  -- Same bell silhouette as the armed indicator, but dim
  screen.pixel(bx + 1, by);     screen.pixel(bx + 2, by);     screen.pixel(bx + 3, by)
  for c = 0, 4 do
    screen.pixel(bx + c, by + 1); screen.pixel(bx + c, by + 2)
  end
  screen.pixel(bx + 1, by + 3); screen.pixel(bx + 2, by + 3); screen.pixel(bx + 3, by + 3)
  screen.pixel(bx + 2, by + 4)
  screen.fill()
end
```

(Norns is grayscale, no real red — level 3 is a dim, wrong-looking gray that reads as "denied" in context. If you want a stronger visual signal, the bell could ALSO add a horizontal slash through it on denial. Keep it simple for this pass.)

- [ ] **Step 3: Verify**

Run: `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK"`

- [ ] **Step 4: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat: bell-glyph denial flash (4 ticks dim render)"
```

---

## Task 15: Final verification + snapshot + user playtest checkpoint

**Files:**
- `~/dev/synth-quest/synth-quest.lua` final state
- `~/dev/synth-quest/backups/` snapshot

- [ ] **Step 1: Final syntax + file size check**

```bash
cd ~/dev/synth-quest && luac -p synth-quest.lua && echo "SYNTAX OK" && wc -c synth-quest.lua
```
Expected: SYNTAX OK + file size under ~1.22 MB (the pass adds ~5KB max).

- [ ] **Step 2: Confirm all 8 dispatchers + 4 new kinds present**

```bash
cd ~/dev/synth-quest && grep -c "play_ring_anim\|play_long_echo_anim\|play_threefold_anim\|play_masked_voice_anim\|play_spring_anim\|play_heavy_hand_anim\|play_scatter_anim\|play_slow_wheel_anim" synth-quest.lua
```
Expected: 16+ (each function appears twice: definition + dispatcher entry, plus any internal refs).

```bash
cd ~/dev/synth-quest && grep -c 'kind == "ring"\|kind == "ghost_sprite"\|kind == "spring_line"\|kind == "mask_bar"\|kind == "rotating_line"' synth-quest.lua
```
Expected: 5 (one render branch per new kind).

- [ ] **Step 3: Confirm banners removed and turn-cost removed**

```bash
cd ~/dev/synth-quest && grep -n 'banner_text.*resonance\|banner_text.*already armed\|banner_text.*not enough MP' synth-quest.lua
```
Expected: no matches.

```bash
cd ~/dev/synth-quest && grep -B 2 -A 2 'p.queued == "RESO"' synth-quest.lua | grep "last_fire"
```
Expected: no matches (no `p.last_fire = tick` in the RESO branch).

- [ ] **Step 4: Snapshot**

```bash
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
```

- [ ] **Step 5: USER PLAYTEST**

Deploy to white norns (IP from memory: 192.168.1.247 or 192.168.1.133 — verify via `ping norns.local`):

```bash
scp -i ~/.ssh/norns ~/dev/synth-quest/synth-quest.lua we@<ip>:/home/we/dust/code/synth-quest/
```

Playtest steps:
1. Enter a battle with Miel as active and Ring attuned.
2. Tap R2 → confirm SFX fires, 3 concentric rings expand from Miel's sprite, bell-glyph appears (armed indicator), no banner.
3. Immediately tap A (ATK) → confirm Miel can fire on the same tick. ATK should land with the +30% Ring damage bonus.
4. Tap R2 again while armed → confirm denial SFX + bell-glyph dims for 4 ticks. No banner.
5. Tap R2 with low MP → confirm 3-note descending denial SFX.
6. Tap R2 within 6 ticks of a successful invocation → confirm cooldown denial SFX.
7. Switch to Alder (different attunement, e.g. Long Echo if attuned) → confirm correct per-Resonance animation (ghost trail, not rings).
8. Repeat for any other character with an attuned Resonance.
9. Exit battle and re-enter → confirm cooldown reset (R2 fires fresh), buff reset (no armed state).

Animations to look for, by Resonance:
- **Ring**: concentric expanding rings
- **Long Echo**: 2 ghost-sprites trailing right
- **Threefold**: 3 sprites side-by-side
- **Masked Voice**: horizontal eye-bar then upward drift
- **Spring**: wavy horizontal pixel-lines spreading left/right
- **Heavy Hand**: downward particle fall + screen shake
- **Scatter**: cloud of tiny pixels everywhere
- **Slow Wheel**: rotating diameter line through sprite

---

## Acceptance Criteria

- Pressing R2 with valid conditions:
  - Fires signature SFX ✓
  - Fires correct per-Resonance animation ✓
  - Arms the buff (Ring only has real effect; others armed-but-stubbed) ✓
  - Sets `p.reso_cooldown_until = tick + 6` ✓
  - Does NOT set `p.last_fire` (character can immediately ATK) ✓
  - Does NOT display banner ✓

- Pressing R2 in denial cases:
  - Fires cause-specific SFX (4 distinct cues) ✓
  - Sets `p.reso_denied_t = tick` causing 4-tick bell-glyph dim ✓
  - Does NOT display banner ✓
  - Does NOT consume MP or arm buff ✓

- All 8 animations distinct and recognizable
- `luac -p` passes
- File size growth under +6KB
- Battle exit clears `reso_cooldown_until`, `reso_denied_t`, `ring_armed`

## Self-Review Notes

**Spec coverage check:**
- Free invocation → Task 4 (removes `p.last_fire`) ✓
- Per-character 6-tick cooldown → Task 4 (sets `reso_cooldown_until`) ✓
- 8 per-Resonance animations → Tasks 5-12 ✓
- Cause-specific denial SFX + bell flash → Tasks 13-14 ✓
- Banner removal → Task 13 ✓
- Per-battle state cleanup → Task 4 ✓
- Action-menu RESO item: the spec says it should route to the same path. The action menu already calls `apply_player_action` with `p.queued == "RESO"`, which now goes through the new fluid path automatically. No separate task needed — covered by Task 4's modification of the RESO branch.

**Placeholder scan:** none.

**Type consistency:** function names match across definitions, dispatcher table, and any references. Particle `kind` strings are consistent ("spark", "ghost_sprite", "ring", "mask_bar", "spring_line", "rotating_line"). No naming drift.

**Identified soft spots:**
- The "already armed" and "low mp" SFX fire multiple `sq_trig` calls simultaneously rather than sequentially (norns audio is non-blocking, no built-in delay). The resulting chord is acceptable for denial feedback but doesn't match the design's "2 ticks apart" / "1 tick apart" intent. Flagged in Task 13. If sequential timing is wanted later, a small `pending_sfx` queue is a future polish task.
- Bell-glyph "red-flash" is grayscale level 3 — reads as dim/wrong rather than red. Norns hardware limitation. Flagged in Task 14.
