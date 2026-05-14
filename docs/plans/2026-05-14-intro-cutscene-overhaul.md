# Intro Cutscene Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four "court emptied months ago" panels in the opening cutscene with a 12-panel "Lirael ordinary night" sequence so the cutscene's framing matches the playable raid that immediately follows.

**Architecture:** Single-file change to `synth-quest.lua`. Three edits: add 21 new `draw_scene_*` functions inside the existing scene-draw `do…end` block; register them in the `SCENE_DRAW` dispatch table; replace `CUTSCENE_LINES` with the 21-panel sequence. No engine, save, music, or state-machine changes. Existing scene functions (`cosmic`, `dark`, `village`, `threat`, `throne`, `coup`, `passage`) are preserved because `ENDING_LINES` and other cutscenes still reference them.

**Tech Stack:** norns (Lua), `screen.*` mono primitives at 128×64. SuperCollider engine unchanged. Manual playtest on device — no unit-test framework.

**Spec:** `docs/specs/2026-05-14-intro-cutscene-overhaul-design.md`

---

## File Structure

| Change | Location | Note |
|---|---|---|
| Add 21 new `draw_scene_*` functions | `synth-quest.lua:22305-22569` block, before `SCENE_DRAW = {…}` at 22569 | Inside the existing `do … end` wrapper at line 22305 |
| Add 21 new entries to `SCENE_DRAW` table | `synth-quest.lua:22569` | Append after the existing 7 entries |
| Replace `CUTSCENE_LINES` body | `synth-quest.lua:958-976` | 21 panels in place of 14 |

No new files. No tests (project has none).

---

### Task 1: Pre-flight backup

**Files:**
- Read: `~/dev/synth-quest/synth-quest.lua`
- Create: `~/dev/synth-quest/backups/synth-quest-pre-intro-overhaul.lua`

- [ ] **Step 1: Snapshot the current script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-pre-intro-overhaul.lua`
Expected: no output, file exists at the new path.

- [ ] **Step 2: Confirm snapshot**

Run: `ls -la ~/dev/synth-quest/backups/synth-quest-pre-intro-overhaul.lua`
Expected: file exists, size matches the source (`wc -c ~/dev/synth-quest/synth-quest.lua`).

---

### Task 2: Add the 6 cosmic_* draw functions

**Files:**
- Modify: `synth-quest.lua` — insert before line 22569 (the `SCENE_DRAW = {` line), inside the `do … end` block opened at line 22305.

**Anchor for Edit:** the `old_string` for the Edit tool is the unique block ending the existing scene functions and beginning the dispatch table. From the current file:

```lua
end

SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
```

This anchor (the closing `end` of `draw_scene_passage`, blank line, `SCENE_DRAW = {`, `cosmic` entry) is unique in the file.

- [ ] **Step 1: Add the 6 cosmic_* functions before SCENE_DRAW**

Use the Edit tool. `old_string`:

```lua
end

SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
```

`new_string`:

```lua
end

local function draw_scene_cosmic_stars()
  -- slow-drifting starfield, three brightness layers, no planet/pulsar
  screen.level(2)
  for i = 1, 22 do
    screen.pixel((i * 13 + tick) % 128, (i * 7) % 64)
  end
  screen.fill()
  screen.level(7)
  for i = 1, 11 do
    screen.pixel((i * 23 + tick * 2) % 128, (i * 11 + 4) % 60)
  end
  screen.fill()
  screen.level(15)
  for i = 1, 3 do
    screen.pixel((i * 41 + 8) % 128, (i * 17 + 12) % 56)
  end
  screen.fill()
end

local function draw_scene_cosmic_chord()
  screen.level(1)
  for i = 1, 12 do screen.pixel((i * 17 + tick) % 128, (i * 9) % 64) end
  screen.fill()
  local pulse = ((tick % 24) < 12) and 15 or 11
  screen.level(pulse); screen.circle(64, 32, 3); screen.fill()
  screen.level(7); screen.circle(64, 32, 5); screen.stroke()
  for i = 0, 6 do
    local a = (i / 7) * math.pi * 2 + tick * 0.01
    local x = 64 + math.floor(math.cos(a) * 22)
    local y = 32 + math.floor(math.sin(a) * 16)
    screen.level(13)
    screen.move(x, y - 2); screen.line(x + 1, y); screen.line(x, y + 2); screen.line(x - 1, y); screen.close(); screen.fill()
  end
end

local function draw_scene_cosmic_modes()
  screen.level(1)
  for i = 1, 10 do screen.pixel((i * 19 + tick) % 128, (i * 11) % 64) end
  screen.fill()
  screen.level(5); screen.circle(64, 32, 2); screen.fill()
  local levels = {15, 13, 11, 9, 7, 5, 3}
  for i = 0, 6 do
    local a = (i / 7) * math.pi * 2 - math.pi / 2
    local x = 64 + math.floor(math.cos(a) * 24)
    local y = 32 + math.floor(math.sin(a) * 18)
    screen.level(levels[i + 1])
    screen.move(x, y - 3); screen.line(x + 2, y); screen.line(x, y + 3); screen.line(x - 2, y); screen.close(); screen.fill()
    if (tick + i * 6) % 28 < 4 then
      screen.level(15); screen.pixel(x, y); screen.fill()
    end
  end
end

local function draw_scene_cosmic_world()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(2)
  for i = 1, 14 do screen.pixel((i * 17 + tick) % 128, (i * 7) % 36) end
  screen.fill()
  -- Modalia, low and central
  screen.level(3); screen.circle(64, 56, 16); screen.fill()
  screen.level(5); screen.circle(60, 52, 12); screen.fill()
  screen.level(7); screen.circle(58, 50, 4); screen.fill()
  screen.level(7); screen.circle(66, 56, 3); screen.fill()
  -- chord humming above the world (three faint horizontal arcs)
  for i = 0, 2 do
    screen.level(7 - i * 2)
    screen.move(48 - i * 2, 42 - i * 2); screen.line(80 + i * 2, 42 - i * 2); screen.stroke()
  end
end

local function draw_scene_cosmic_shatter()
  screen.level(1)
  for i = 1, 10 do screen.pixel((i * 19 + tick) % 128, (i * 11) % 64) end
  screen.fill()
  -- afterglow at the shatter origin
  screen.level(8); screen.pixel(64, 32); screen.pixel(63, 32); screen.pixel(65, 32); screen.pixel(64, 31); screen.pixel(64, 33); screen.fill()
  -- seven shards flying outward, with trails; cycles every 120 ticks
  local prog = math.min(1, (tick % 120) / 60)
  for i = 0, 6 do
    local a = (i / 7) * math.pi * 2
    local d = math.floor(prog * 40)
    screen.level(3)
    for t = 1, 4 do
      local dt = math.max(0, d - t * 3)
      screen.pixel(64 + math.floor(math.cos(a) * dt), 32 + math.floor(math.sin(a) * dt))
    end
    screen.fill()
    screen.level(15)
    screen.pixel(64 + math.floor(math.cos(a) * d), 32 + math.floor(math.sin(a) * d))
    screen.fill()
  end
end

local function draw_scene_cosmic_drift()
  screen.level(1)
  for i = 1, 14 do screen.pixel((i * 17 + tick) % 128, (i * 9) % 64) end
  screen.fill()
  -- seven shards at rest, scattered, dim
  local pos = {{14,12},{40,18},{72,8},{102,16},{20,46},{56,52},{96,48}}
  for _, p in ipairs(pos) do
    local x, y = p[1], p[2]
    screen.level(8)
    screen.move(x, y - 2); screen.line(x + 1, y); screen.line(x, y + 2); screen.line(x - 1, y); screen.close(); screen.fill()
    screen.level(2); screen.pixel(x, y - 3); screen.pixel(x + 2, y); screen.pixel(x, y + 3); screen.pixel(x - 2, y); screen.fill()
  end
end

SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
```

- [ ] **Step 2: Verify the 6 functions parse**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`. (norns ships matrix Lua 5.3; this catches syntax errors before deploy.)

If `lua5.3` is not installed, run `which lua5.3 lua5.4 lua` to find an available interpreter, or skip this step and rely on the on-device load to surface errors.

---

### Task 3: Add the 3 dark_* draw functions

**Files:**
- Modify: `synth-quest.lua` — insert after the 6 new cosmic_* functions and before `SCENE_DRAW = {`.

- [ ] **Step 1: Add the 3 dark_* functions**

Use the Edit tool. `old_string` (which now sits right before the dispatch table after Task 2):

```lua
local function draw_scene_cosmic_drift()
  screen.level(1)
  for i = 1, 14 do screen.pixel((i * 17 + tick) % 128, (i * 9) % 64) end
  screen.fill()
  -- seven shards at rest, scattered, dim
  local pos = {{14,12},{40,18},{72,8},{102,16},{20,46},{56,52},{96,48}}
  for _, p in ipairs(pos) do
    local x, y = p[1], p[2]
    screen.level(8)
    screen.move(x, y - 2); screen.line(x + 1, y); screen.line(x, y + 2); screen.line(x - 1, y); screen.close(); screen.fill()
    screen.level(2); screen.pixel(x, y - 3); screen.pixel(x + 2, y); screen.pixel(x, y + 3); screen.pixel(x - 2, y); screen.fill()
  end
end

SCENE_DRAW = {
```

`new_string`:

```lua
local function draw_scene_cosmic_drift()
  screen.level(1)
  for i = 1, 14 do screen.pixel((i * 17 + tick) % 128, (i * 9) % 64) end
  screen.fill()
  -- seven shards at rest, scattered, dim
  local pos = {{14,12},{40,18},{72,8},{102,16},{20,46},{56,52},{96,48}}
  for _, p in ipairs(pos) do
    local x, y = p[1], p[2]
    screen.level(8)
    screen.move(x, y - 2); screen.line(x + 1, y); screen.line(x, y + 2); screen.line(x - 1, y); screen.close(); screen.fill()
    screen.level(2); screen.pixel(x, y - 3); screen.pixel(x + 2, y); screen.pixel(x, y + 3); screen.pixel(x - 2, y); screen.fill()
  end
end

local function draw_scene_dark_suno()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(2); screen.rect(0, 50, 128, 14); screen.fill()
  -- distant mountains
  screen.level(1)
  screen.move(0, 50); screen.line(30, 36); screen.line(60, 44); screen.line(90, 32); screen.line(128, 42); screen.line(128, 50); screen.close(); screen.fill()
  -- broken seven-pointed sigil in the sky behind Suno
  screen.level(3)
  for i = 0, 6 do
    local a = (i / 7) * math.pi * 2 - math.pi / 2
    screen.pixel(70 + math.floor(math.cos(a) * 12), 22 + math.floor(math.sin(a) * 10))
  end
  screen.fill()
  -- Suno: tall hooded figure dead center
  screen.level(0)
  screen.move(58, 64); screen.line(82, 64); screen.line(76, 28); screen.line(64, 28); screen.close(); screen.fill()
  screen.circle(70, 24, 8); screen.fill()
  -- two faint glints inside the hood
  if (tick % 24) < 14 then
    screen.level(11); screen.pixel(67, 24); screen.pixel(73, 24); screen.fill()
  end
end

local function draw_scene_dark_march()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  -- pale sky
  screen.level(2); screen.rect(0, 0, 128, 36); screen.fill()
  -- pale road across the middle
  screen.level(7); screen.rect(0, 36, 128, 6); screen.fill()
  screen.level(4); screen.rect(0, 42, 128, 22); screen.fill()
  -- distant treeline along the horizon
  screen.level(1)
  for i = 0, 9 do screen.rect(i * 14, 30, 2, 6); screen.fill() end
  -- a line of silencers walking left to right (slow drift)
  local base = (tick // 3) % 24
  for i = 0, 7 do
    local x = -16 + i * 18 + base
    if x > -8 and x < 132 then
      screen.level(0); screen.rect(x, 32, 3, 8); screen.fill()
      screen.level(0); screen.rect(x - 1, 28, 5, 4); screen.fill()
    end
  end
end

local function draw_scene_dark_village()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  -- moonless sky, a few dim stars
  screen.level(1)
  for i = 1, 6 do screen.pixel((i * 19) % 128, (i * 11) % 24) end
  screen.fill()
  -- 4 house silhouettes; chimneys but no smoke
  local houses = {{0,46,28},{30,48,26},{62,44,30},{96,48,32}}
  for _, h in ipairs(houses) do
    local x, y, w = h[1], h[2], h[3]
    screen.level(3)
    screen.move(x, y); screen.line(x + w / 2, y - 8); screen.line(x + w, y); screen.close(); screen.fill()
    screen.rect(x, y, w, 64 - y); screen.fill()
    screen.level(2); screen.rect(x + 4, y - 4, 2, 4); screen.fill()
  end
  -- dark window outlines (unlit)
  screen.level(1)
  screen.rect(8, 52, 4, 4); screen.stroke()
  screen.rect(38, 54, 4, 4); screen.stroke()
  screen.rect(70, 52, 4, 4); screen.stroke()
  screen.rect(104, 54, 4, 4); screen.stroke()
end

SCENE_DRAW = {
```

- [ ] **Step 2: Verify the file still parses**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 4: Add the 12 lirael_* draw functions (first half: 6)

**Files:**
- Modify: `synth-quest.lua` — insert after the 3 new dark_* functions and before `SCENE_DRAW = {`.

- [ ] **Step 1: Add lirael_coast, lirael_belltower, lirael_hall, lirael_southwall, lirael_chamber, lirael_candles**

Use the Edit tool. `old_string`:

```lua
local function draw_scene_dark_village()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  -- moonless sky, a few dim stars
  screen.level(1)
  for i = 1, 6 do screen.pixel((i * 19) % 128, (i * 11) % 24) end
  screen.fill()
  -- 4 house silhouettes; chimneys but no smoke
  local houses = {{0,46,28},{30,48,26},{62,44,30},{96,48,32}}
  for _, h in ipairs(houses) do
    local x, y, w = h[1], h[2], h[3]
    screen.level(3)
    screen.move(x, y); screen.line(x + w / 2, y - 8); screen.line(x + w, y); screen.close(); screen.fill()
    screen.rect(x, y, w, 64 - y); screen.fill()
    screen.level(2); screen.rect(x + 4, y - 4, 2, 4); screen.fill()
  end
  -- dark window outlines (unlit)
  screen.level(1)
  screen.rect(8, 52, 4, 4); screen.stroke()
  screen.rect(38, 54, 4, 4); screen.stroke()
  screen.rect(70, 52, 4, 4); screen.stroke()
  screen.rect(104, 54, 4, 4); screen.stroke()
end

SCENE_DRAW = {
```

`new_string`:

```lua
local function draw_scene_dark_village()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  -- moonless sky, a few dim stars
  screen.level(1)
  for i = 1, 6 do screen.pixel((i * 19) % 128, (i * 11) % 24) end
  screen.fill()
  -- 4 house silhouettes; chimneys but no smoke
  local houses = {{0,46,28},{30,48,26},{62,44,30},{96,48,32}}
  for _, h in ipairs(houses) do
    local x, y, w = h[1], h[2], h[3]
    screen.level(3)
    screen.move(x, y); screen.line(x + w / 2, y - 8); screen.line(x + w, y); screen.close(); screen.fill()
    screen.rect(x, y, w, 64 - y); screen.fill()
    screen.level(2); screen.rect(x + 4, y - 4, 2, 4); screen.fill()
  end
  screen.level(1)
  screen.rect(8, 52, 4, 4); screen.stroke()
  screen.rect(38, 54, 4, 4); screen.stroke()
  screen.rect(70, 52, 4, 4); screen.stroke()
  screen.rect(104, 54, 4, 4); screen.stroke()
end

local function draw_scene_lirael_coast()
  -- night sky
  screen.level(1); screen.rect(0, 0, 128, 36); screen.fill()
  screen.level(7)
  for i = 1, 6 do screen.pixel((i * 21) % 128, (i * 7) % 28) end
  screen.fill()
  -- crescent moon upper-right
  screen.level(13); screen.circle(108, 12, 5); screen.fill()
  screen.level(1); screen.circle(110, 11, 5); screen.fill()
  -- sea on the right (rippling lines)
  screen.level(3); screen.rect(64, 36, 64, 28); screen.fill()
  screen.level(5)
  for y = 40, 60, 4 do
    local off = ((tick + y) // 2) % 6
    screen.move(64 + off, y); screen.line(120, y); screen.stroke()
  end
  -- low headland on the left
  screen.level(2)
  screen.move(0, 64); screen.line(0, 42); screen.line(20, 36); screen.line(48, 38); screen.line(64, 42); screen.line(64, 64); screen.close(); screen.fill()
  -- the keep silhouetted on the headland
  screen.level(0)
  screen.rect(20, 22, 16, 18); screen.fill()
  screen.rect(18, 16, 6, 8); screen.fill()
  screen.rect(32, 16, 6, 8); screen.fill()
  -- a single warm window in the keep
  screen.level(13); screen.pixel(26, 30); screen.pixel(27, 30); screen.fill()
end

local function draw_scene_lirael_belltower()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(1)
  for i = 1, 8 do screen.pixel((i * 17) % 128, (i * 5) % 18) end
  screen.fill()
  -- tower silhouette
  screen.level(3); screen.rect(56, 18, 16, 46); screen.fill()
  -- crenellated top
  screen.rect(54, 14, 4, 4); screen.fill()
  screen.rect(60, 14, 4, 4); screen.fill()
  screen.rect(66, 14, 4, 4); screen.fill()
  -- bell chamber arch
  screen.level(0); screen.rect(58, 22, 12, 12); screen.fill()
  -- bell, swung in evening pattern
  local sw = math.floor(math.sin(tick * 0.12) * 3)
  screen.level(11); screen.rect(62 + sw, 24, 4, 6); screen.fill()
  screen.level(13); screen.pixel(64 + sw, 30); screen.fill()
  -- ground torch beams (suggested as lines)
  screen.level(7)
  screen.move(56, 64); screen.line(60, 36); screen.stroke()
  screen.move(72, 64); screen.line(68, 36); screen.stroke()
  -- two flickering torch flames at the base
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(56, 60); screen.pixel(72, 60); screen.fill()
    screen.level(11); screen.pixel(56, 58); screen.pixel(72, 58); screen.fill()
  else
    screen.level(11); screen.pixel(56, 60); screen.pixel(72, 60); screen.fill()
  end
end

local function draw_scene_lirael_hall()
  -- back wall
  screen.level(2); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(3); screen.rect(0, 0, 128, 28); screen.fill()
  -- tapestry on the back wall
  screen.level(7); screen.rect(54, 4, 20, 22); screen.fill()
  screen.level(11); screen.rect(58, 8, 4, 14); screen.fill()
  -- two tall side windows, moonlit
  screen.level(11); screen.rect(8, 6, 8, 16); screen.fill()
  screen.level(11); screen.rect(112, 6, 8, 16); screen.fill()
  -- floor stripes
  screen.level(3)
  for y = 36, 60, 4 do screen.move(8, y); screen.line(120, y); screen.stroke() end
  -- long table down the middle
  screen.level(5); screen.rect(20, 38, 88, 8); screen.fill()
  screen.level(5); screen.rect(22, 46, 2, 12); screen.fill()
  screen.level(5); screen.rect(104, 46, 2, 12); screen.fill()
  -- scribe at left end of table (head + robe)
  screen.level(7); screen.rect(24, 34, 4, 4); screen.fill()
  screen.level(11); screen.rect(22, 38, 8, 4); screen.fill()
  -- candle near the scribe
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(34, 36); screen.fill()
    screen.level(11); screen.pixel(34, 35); screen.fill()
  else
    screen.level(11); screen.pixel(34, 36); screen.fill()
  end
  -- page near the door at right (yawning bob)
  local bob = (tick // 12) % 2
  screen.level(7); screen.rect(98, 30 + bob, 4, 4); screen.fill()
  screen.level(11); screen.rect(96, 34 + bob, 8, 6); screen.fill()
end

local function draw_scene_lirael_southwall()
  -- night sky
  screen.level(0); screen.rect(0, 0, 128, 36); screen.fill()
  screen.level(1)
  for i = 1, 6 do screen.pixel((i * 19) % 128, (i * 7) % 30) end
  screen.fill()
  -- distant treeline
  screen.level(2)
  for i = 0, 8 do
    local x = i * 16
    screen.move(x, 36); screen.line(x + 4, 30); screen.line(x + 8, 36); screen.close(); screen.fill()
  end
  -- parapet
  screen.level(5); screen.rect(0, 36, 128, 28); screen.fill()
  screen.level(0)
  for x = 0, 124, 12 do screen.rect(x, 36, 4, 4); screen.fill() end
  -- three torches mounted along the wall
  for i = 0, 2 do
    local tx = 24 + i * 40
    screen.level(2); screen.rect(tx, 40, 1, 4); screen.fill()
    if (tick + i * 5) % 10 < 7 then
      screen.level(15); screen.pixel(tx, 38); screen.pixel(tx + 1, 38); screen.pixel(tx, 37); screen.fill()
    else
      screen.level(11); screen.pixel(tx, 38); screen.fill()
    end
  end
  -- captain in profile (slow drift)
  local fx = 60 + (tick // 8) % 16
  screen.level(11); screen.rect(fx + 2, 42, 3, 4); screen.fill()
  screen.level(7); screen.rect(fx, 46, 7, 8); screen.fill()
  screen.level(3); screen.move(fx, 46); screen.line(fx - 4, 54); screen.line(fx - 2, 54); screen.line(fx + 2, 50); screen.close(); screen.fill()
end

local function draw_scene_lirael_chamber()
  screen.level(3); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(2); screen.rect(0, 0, 128, 30); screen.fill()
  -- floor stripes
  screen.level(4)
  for y = 40, 60, 4 do screen.move(8, y); screen.line(120, y); screen.stroke() end
  -- mirror behind the dressing table
  screen.level(11); screen.rect(54, 8, 20, 22); screen.fill()
  screen.level(7);  screen.rect(56, 10, 16, 18); screen.fill()
  -- the table
  screen.level(7); screen.rect(48, 30, 32, 6); screen.fill()
  screen.level(5); screen.rect(50, 36, 2, 16); screen.fill()
  screen.level(5); screen.rect(76, 36, 2, 16); screen.fill()
  -- crown set down on the table
  screen.level(15)
  screen.move(58, 28); screen.line(60, 24); screen.line(62, 28); screen.line(64, 24); screen.line(66, 28); screen.line(68, 24); screen.line(70, 28); screen.stroke()
  screen.level(13); screen.rect(58, 28, 12, 2); screen.fill()
  -- candle on the side of the table
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(82, 28); screen.pixel(83, 28); screen.fill()
    screen.level(11); screen.pixel(82, 27); screen.fill()
  else
    screen.level(11); screen.pixel(82, 28); screen.fill()
  end
end

local function draw_scene_lirael_candles()
  screen.level(2); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(5); screen.rect(0, 50, 128, 14); screen.fill()
  -- three candle holders + bodies
  for i = 0, 2 do
    local cx = 32 + i * 32
    screen.level(7); screen.rect(cx - 3, 46, 6, 4); screen.fill()
    screen.level(11); screen.rect(cx - 1, 30, 2, 16); screen.fill()
  end
  -- candle 1: snuffed; smoke trail rising
  screen.level(7)
  for i = 0, 4 do screen.pixel(32 + (i % 2), 28 - i * 3) end
  screen.fill()
  -- candle 2: snuffed; lower smoke trail
  screen.level(5)
  for i = 0, 3 do screen.pixel(64 + ((i + 1) % 2), 28 - i * 3) end
  screen.fill()
  -- candle 3: burning, animated flame
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(96, 28); screen.pixel(96, 27); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
    screen.level(11); screen.pixel(96, 26); screen.fill()
  else
    screen.level(13); screen.pixel(96, 28); screen.pixel(96, 27); screen.fill()
    screen.level(8); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
  end
  -- pool of warm light around the burning candle
  screen.level(5); screen.circle(96, 36, 10); screen.stroke()
  screen.level(3); screen.circle(96, 36, 14); screen.stroke()
end

SCENE_DRAW = {
```

- [ ] **Step 2: Verify the file still parses**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 5: Add the 12 lirael_* draw functions (second half: 6)

**Files:**
- Modify: `synth-quest.lua` — insert after `draw_scene_lirael_candles` (added in Task 4) and before `SCENE_DRAW = {`.

- [ ] **Step 1: Add lirael_road, lirael_sentry, lirael_captain_run, lirael_courtyard, lirael_gate, lirael_candles_dim**

Use the Edit tool. `old_string`:

```lua
local function draw_scene_lirael_candles()
  screen.level(2); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(5); screen.rect(0, 50, 128, 14); screen.fill()
  -- three candle holders + bodies
  for i = 0, 2 do
    local cx = 32 + i * 32
    screen.level(7); screen.rect(cx - 3, 46, 6, 4); screen.fill()
    screen.level(11); screen.rect(cx - 1, 30, 2, 16); screen.fill()
  end
  -- candle 1: snuffed; smoke trail rising
  screen.level(7)
  for i = 0, 4 do screen.pixel(32 + (i % 2), 28 - i * 3) end
  screen.fill()
  -- candle 2: snuffed; lower smoke trail
  screen.level(5)
  for i = 0, 3 do screen.pixel(64 + ((i + 1) % 2), 28 - i * 3) end
  screen.fill()
  -- candle 3: burning, animated flame
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(96, 28); screen.pixel(96, 27); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
    screen.level(11); screen.pixel(96, 26); screen.fill()
  else
    screen.level(13); screen.pixel(96, 28); screen.pixel(96, 27); screen.fill()
    screen.level(8); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
  end
  -- pool of warm light around the burning candle
  screen.level(5); screen.circle(96, 36, 10); screen.stroke()
  screen.level(3); screen.circle(96, 36, 14); screen.stroke()
end

SCENE_DRAW = {
```

`new_string`:

```lua
local function draw_scene_lirael_candles()
  screen.level(2); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(5); screen.rect(0, 50, 128, 14); screen.fill()
  for i = 0, 2 do
    local cx = 32 + i * 32
    screen.level(7); screen.rect(cx - 3, 46, 6, 4); screen.fill()
    screen.level(11); screen.rect(cx - 1, 30, 2, 16); screen.fill()
  end
  screen.level(7)
  for i = 0, 4 do screen.pixel(32 + (i % 2), 28 - i * 3) end
  screen.fill()
  screen.level(5)
  for i = 0, 3 do screen.pixel(64 + ((i + 1) % 2), 28 - i * 3) end
  screen.fill()
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(96, 28); screen.pixel(96, 27); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
    screen.level(11); screen.pixel(96, 26); screen.fill()
  else
    screen.level(13); screen.pixel(96, 28); screen.pixel(96, 27); screen.fill()
    screen.level(8); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
  end
  screen.level(5); screen.circle(96, 36, 10); screen.stroke()
  screen.level(3); screen.circle(96, 36, 14); screen.stroke()
end

local function draw_scene_lirael_road()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(1)
  for i = 1, 8 do screen.pixel((i * 19) % 128, (i * 11) % 28) end
  screen.fill()
  -- horizon
  screen.level(2); screen.rect(0, 36, 128, 4); screen.fill()
  -- distant trees
  screen.level(2)
  for i = 0, 7 do
    local x = i * 18
    screen.move(x, 40); screen.line(x + 4, 30); screen.line(x + 8, 40); screen.close(); screen.fill()
  end
  -- road receding to a vanishing point
  screen.level(4)
  screen.move(0, 64); screen.line(56, 40); screen.line(72, 40); screen.line(128, 64); screen.close(); screen.fill()
  screen.level(1)
  for y = 44, 62, 4 do screen.move(64, y); screen.line(64, y + 1); screen.stroke() end
  -- lamp post on the right side of the road
  screen.level(7); screen.rect(86, 28, 1, 24); screen.fill()
  screen.level(7); screen.rect(82, 28, 8, 1); screen.fill()
  -- the lamp: dying. faint, intermittent ember
  if (tick % 40) < 10 then
    screen.level(11); screen.pixel(86, 26); screen.fill()
  else
    screen.level(3); screen.pixel(86, 26); screen.fill()
  end
end

local function draw_scene_lirael_sentry()
  screen.level(0); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(1)
  for i = 1, 6 do screen.pixel((i * 17) % 128, (i * 7) % 24) end
  screen.fill()
  -- parapet
  screen.level(5); screen.rect(0, 40, 128, 24); screen.fill()
  screen.level(0)
  for x = 0, 124, 12 do screen.rect(x, 40, 4, 4); screen.fill() end
  -- a thin wooden post for the sentry's lantern
  screen.level(5); screen.rect(60, 22, 1, 18); screen.fill()
  screen.level(5); screen.rect(56, 22, 8, 1); screen.fill()
  -- the lantern, still lit
  screen.level(7); screen.rect(58, 24, 4, 6); screen.stroke()
  if (tick % 12) < 8 then
    screen.level(15); screen.pixel(60, 27); screen.fill()
    screen.level(11); screen.pixel(59, 27); screen.pixel(61, 27); screen.fill()
  else
    screen.level(11); screen.pixel(60, 27); screen.fill()
  end
  -- a halberd leaning against the parapet (no sentry)
  screen.level(7)
  screen.move(80, 64); screen.line(86, 36); screen.stroke()
  screen.move(86, 36); screen.line(90, 32); screen.line(86, 30); screen.close(); screen.stroke()
end

local function draw_scene_lirael_captain_run()
  screen.level(1); screen.rect(0, 0, 128, 36); screen.fill()
  -- corridor stones
  screen.level(3); screen.rect(0, 36, 128, 28); screen.fill()
  screen.level(2)
  for x = 0, 124, 12 do screen.rect(x, 38, 12, 1); screen.fill() end
  for x = 6, 124, 12 do screen.rect(x, 50, 12, 1); screen.fill() end
  -- a torch on the left wall
  screen.level(2); screen.rect(8, 16, 2, 12); screen.fill()
  if (tick % 10) < 7 then
    screen.level(15); screen.pixel(9, 14); screen.pixel(8, 14); screen.pixel(10, 14); screen.fill()
    screen.level(11); screen.pixel(9, 12); screen.fill()
  end
  -- the captain mid-stride, running right
  local fx = 48 + (tick // 4) % 24
  screen.level(7)
  if (tick // 4) % 2 == 0 then
    screen.move(fx, 56); screen.line(fx - 2, 60); screen.stroke()
    screen.move(fx + 4, 56); screen.line(fx + 6, 60); screen.stroke()
  else
    screen.move(fx, 56); screen.line(fx + 2, 60); screen.stroke()
    screen.move(fx + 4, 56); screen.line(fx + 2, 60); screen.stroke()
  end
  screen.level(11); screen.rect(fx, 44, 6, 12); screen.fill()
  screen.level(7); screen.rect(fx + 6, 46, 3, 6); screen.fill()
  screen.level(13); screen.rect(fx + 1, 40, 4, 4); screen.fill()
  -- cloak trailing
  screen.level(3)
  screen.move(fx, 44); screen.line(fx - 8, 50); screen.line(fx - 4, 56); screen.line(fx - 2, 50); screen.close(); screen.fill()
  -- sword hilt
  screen.level(15); screen.pixel(fx + 6, 50); screen.pixel(fx + 7, 50); screen.fill()
end

local function draw_scene_lirael_courtyard()
  -- top-down paving stones
  screen.level(3); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(2)
  for x = 0, 128, 16 do screen.move(x, 0); screen.line(x, 64); screen.stroke() end
  for y = 16, 64, 16 do screen.move(0, y); screen.line(128, y); screen.stroke() end
  -- bell tower at the top of frame
  screen.level(5); screen.rect(54, 0, 20, 14); screen.fill()
  -- bell, swung sharply (alarm)
  local sw = ((tick // 4) % 2 == 0) and 4 or -4
  screen.level(15); screen.rect(60 + sw, 4, 8, 8); screen.fill()
  screen.level(11); screen.rect(62 + sw, 8, 4, 2); screen.fill()
  -- alarm shockwave: two expanding rings
  local r = (tick // 3) % 24
  screen.level(7); screen.circle(64, 8, r + 6); screen.stroke()
  screen.level(3); screen.circle(64, 8, r + 12); screen.stroke()
  -- small figures running across the courtyard
  for i = 0, 4 do
    local fx = (i * 28 + tick // 2) % 128
    local fy = 30 + (i * 7) % 24
    screen.level(0); screen.rect(fx, fy, 2, 4); screen.fill()
    screen.level(0); screen.pixel(fx, fy - 1); screen.fill()
  end
end

local function draw_scene_lirael_gate()
  -- inside of the gatehouse: stone walls
  screen.level(2); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(3)
  for y = 4, 60, 8 do screen.move(0, y); screen.line(128, y); screen.stroke() end
  -- the south gate: heavy double doors, center
  screen.level(7); screen.rect(36, 12, 56, 52); screen.fill()
  -- iron banding
  screen.level(2); screen.rect(36, 22, 56, 2); screen.fill()
  screen.level(2); screen.rect(36, 40, 56, 2); screen.fill()
  screen.level(2); screen.rect(36, 56, 56, 2); screen.fill()
  -- center seam
  screen.level(2); screen.rect(63, 12, 2, 52); screen.fill()
  -- impact crack: jagged line down the right door
  screen.level(0)
  screen.move(70, 16)
  screen.line(74, 22)
  screen.line(72, 28)
  screen.line(78, 36)
  screen.line(74, 44)
  screen.line(80, 52)
  screen.line(76, 60)
  screen.stroke()
  -- splinter cracks
  screen.move(74, 22); screen.line(72, 24); screen.stroke()
  screen.move(78, 36); screen.line(82, 38); screen.stroke()
  -- impact flash on a slow cycle
  if (tick % 60) < 6 then
    screen.level(15); screen.rect(36, 12, 56, 2); screen.fill()
  end
end

local function draw_scene_lirael_candles_dim()
  screen.level(1); screen.rect(0, 0, 128, 64); screen.fill()
  screen.level(4); screen.rect(0, 50, 128, 14); screen.fill()
  for i = 0, 2 do
    local cx = 32 + i * 32
    screen.level(5); screen.rect(cx - 3, 46, 6, 4); screen.fill()
    screen.level(7); screen.rect(cx - 1, 30, 2, 16); screen.fill()
  end
  -- candles 1+2: long-snuffed, smoke nearly gone
  screen.level(3)
  for i = 0, 6 do
    screen.pixel(32 + (i % 2), 28 - i * 4)
    screen.pixel(64 + (i % 2), 28 - i * 4)
  end
  screen.fill()
  -- candle 3: guttering — small flame, intermittent
  local phase = tick % 14
  if phase < 4 then
    screen.level(13); screen.pixel(96, 28); screen.pixel(96, 27); screen.fill()
    screen.level(7); screen.pixel(95, 28); screen.pixel(97, 28); screen.fill()
  elseif phase < 10 then
    screen.level(7); screen.pixel(96, 28); screen.fill()
  else
    screen.level(2); screen.pixel(96, 28); screen.fill()
  end
  -- long smoke trail rising from the guttering wick
  screen.level(5)
  for i = 1, 8 do screen.pixel(96 + ((i + tick // 2) % 3), 27 - i * 3) end
  screen.fill()
  -- much smaller pool of light
  screen.level(2); screen.circle(96, 36, 6); screen.stroke()
end

SCENE_DRAW = {
```

- [ ] **Step 2: Verify the file still parses**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 6: Register all 21 new scenes in SCENE_DRAW

**Files:**
- Modify: `synth-quest.lua` — `SCENE_DRAW` table near line 22569.

- [ ] **Step 1: Add 21 new dispatch entries**

Use the Edit tool. `old_string`:

```lua
SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
  dark    = draw_scene_dark,
  village = draw_scene_village,
  threat  = draw_scene_threat,
  throne  = draw_scene_throne,
  coup    = draw_scene_coup,
  passage = draw_scene_passage,
}
```

`new_string`:

```lua
SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
  dark    = draw_scene_dark,
  village = draw_scene_village,
  threat  = draw_scene_threat,
  throne  = draw_scene_throne,
  coup    = draw_scene_coup,
  passage = draw_scene_passage,
  -- intro overhaul (2026-05-14): per-panel scenes for the rewritten opening cutscene
  cosmic_stars        = draw_scene_cosmic_stars,
  cosmic_chord        = draw_scene_cosmic_chord,
  cosmic_modes        = draw_scene_cosmic_modes,
  cosmic_world        = draw_scene_cosmic_world,
  cosmic_shatter      = draw_scene_cosmic_shatter,
  cosmic_drift        = draw_scene_cosmic_drift,
  dark_suno           = draw_scene_dark_suno,
  dark_march          = draw_scene_dark_march,
  dark_village        = draw_scene_dark_village,
  lirael_coast        = draw_scene_lirael_coast,
  lirael_belltower    = draw_scene_lirael_belltower,
  lirael_hall         = draw_scene_lirael_hall,
  lirael_southwall    = draw_scene_lirael_southwall,
  lirael_chamber      = draw_scene_lirael_chamber,
  lirael_candles      = draw_scene_lirael_candles,
  lirael_road         = draw_scene_lirael_road,
  lirael_sentry       = draw_scene_lirael_sentry,
  lirael_captain_run  = draw_scene_lirael_captain_run,
  lirael_courtyard    = draw_scene_lirael_courtyard,
  lirael_gate         = draw_scene_lirael_gate,
  lirael_candles_dim  = draw_scene_lirael_candles_dim,
}
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

- [ ] **Step 3: Confirm every dispatch value resolves to a defined function**

Run:
```bash
for fn in cosmic_stars cosmic_chord cosmic_modes cosmic_world cosmic_shatter cosmic_drift dark_suno dark_march dark_village lirael_coast lirael_belltower lirael_hall lirael_southwall lirael_chamber lirael_candles lirael_road lirael_sentry lirael_captain_run lirael_courtyard lirael_gate lirael_candles_dim; do
  grep -q "local function draw_scene_${fn}(" ~/dev/synth-quest/synth-quest.lua \
    && echo "ok ${fn}" || echo "MISSING ${fn}"
done
```
Expected: 21 lines, all `ok …`. Any `MISSING …` means that draw function was not added — return to the appropriate prior task.

---

### Task 7: Replace CUTSCENE_LINES with the 21-panel sequence

**Files:**
- Modify: `synth-quest.lua:958-976` — `CUTSCENE_LINES` table body.

- [ ] **Step 1: Replace the CUTSCENE_LINES table**

Use the Edit tool. `old_string`:

```lua
local CUTSCENE_LINES = {
  -- ── COSMIC LORE ──
  {text = "Long ago, on planet Modalia, the Crystal Synth gave music — and life — to all.", scene = "cosmic"},
  {text = "Seven shards. Seven modes. One chord, holding the world in tune.", scene = "cosmic"},
  {text = "The Lydian. Dorian. Mixolydian. Phrygian. Aeolian. Locrian. Ionian.", scene = "cosmic"},
  {text = "When the Crystal sang as one, mountains hummed. Rivers found their tempo.", scene = "cosmic"},
  {text = "Then it shattered. The seven scattered, one to each musical nation.", scene = "cosmic"},
  {text = "For an age, the world hummed in fragmented harmony.", scene = "cosmic"},
  -- ── DARK FORESHADOW ──
  {text = "Then Suno rose — once a wandering noble, now the dark lord of the silenced lands.", scene = "dark"},
  {text = "He hunts every shard, to fold the seven into one bell — and ring it shut.", scene = "dark"},
  {text = "Where his silencers march, the songs go cold.", scene = "dark"},
  {text = "Villages forget their lullabies. Mothers forget their children's names.", scene = "dark"},
  -- ── PROLOGUE: MIEL'S COURT (cinematic preamble; gameplay follows) ──
  {text = "Tonight he comes for the last queen who still sings:", scene = "throne"},
  {text = "Miel of the Aeolian shore, sole ruler of a small nation called Lirael.", scene = "throne"},
  {text = "Her court emptied months ago. Her crown sits heavy on the marble.", scene = "throne"},
  {text = "Boots on the long stair. The doors are about to crack.", scene = "throne"},
}
```

`new_string`:

```lua
local CUTSCENE_LINES = {
  -- ── COSMIC LORE ──
  {text = "Long ago, on planet Modalia, the Crystal Synth gave music — and life — to all.", scene = "cosmic_stars"},
  {text = "Seven shards. Seven modes. One chord, holding the world in tune.", scene = "cosmic_chord"},
  {text = "The Lydian. Dorian. Mixolydian. Phrygian. Aeolian. Locrian. Ionian.", scene = "cosmic_modes"},
  {text = "When the Crystal sang as one, mountains hummed. Rivers found their tempo.", scene = "cosmic_world"},
  {text = "Then it shattered. The seven scattered, one to each musical nation.", scene = "cosmic_shatter"},
  {text = "For an age, the world hummed in fragmented harmony.", scene = "cosmic_drift"},
  -- ── DARK FORESHADOW ──
  {text = "Then Suno rose — once a wandering noble, now the dark lord of the silenced lands.", scene = "dark_suno"},
  {text = "He hunts every shard, to fold the seven into one bell — and ring it shut.", scene = "dark_march"},
  {text = "Where his silencers march, the songs go cold. Mothers forget their children's names.", scene = "dark_village"},
  -- ── LIRAEL: ORDINARY NIGHT (raid arrives; control hands to Miel after final panel) ──
  {text = "On the Aeolian shore stands Lirael, a small kingdom that still keeps the chord.", scene = "lirael_coast"},
  {text = "Tonight, like every night, the keep-bell rings the evening hour.", scene = "lirael_belltower"},
  {text = "In the great hall, a scribe scratches at parchment. A page yawns at his post.", scene = "lirael_hall"},
  {text = "Captain Ren walks the south wall and counts his guards by name.", scene = "lirael_southwall"},
  {text = "In her chamber, Queen Miel sets her crown on the dressing table.", scene = "lirael_chamber"},
  {text = "She blows out two of the three candles. She does not blow out the third.", scene = "lirael_candles"},
  {text = "Outside, on the road from the west, a lamp goes out that should not.", scene = "lirael_road"},
  {text = "On the south wall, a sentry does not answer the next watchword.", scene = "lirael_sentry"},
  {text = "The captain stops walking. He waits one beat too long. He runs.", scene = "lirael_captain_run"},
  {text = "In the courtyard the bell sounds again — wrong, sharp, twice.", scene = "lirael_courtyard"},
  {text = "The south gate takes the first blow. The old stones remember.", scene = "lirael_gate"},
  {text = "In her chamber, the queen has not yet woken. The third candle is guttering.", scene = "lirael_candles_dim"},
}
```

- [ ] **Step 2: Verify file still parses + count panels**

Run: `lua5.3 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

Run: `grep -c '{text = ' ~/dev/synth-quest/synth-quest.lua`
Expected: a number that is 7 higher than before the edit (was 14 panels in CUTSCENE_LINES + N elsewhere; now 21 + N). To get the precise pre/post count, capture before Task 7 with the same grep and confirm the delta is +7.

- [ ] **Step 3: Confirm no panel still says "court emptied"**

Run: `grep -n "court emptied" ~/dev/synth-quest/synth-quest.lua`
Expected: no output. (Acceptance criterion #3 from the spec.)

---

### Task 8: Deploy to norns and reload

**Files:** none modified locally.

**Pre-req:** norns IP — at home, white norns is `192.168.1.133` (per `reference_white_norns.md`). If the user is somewhere else, ask them.

- [ ] **Step 1: Confirm target host**

Ask the user: which norns? (white / clear / yellow). Default to white at `192.168.1.133` if unspecified. Set `NORNS_IP` accordingly.

- [ ] **Step 2: rsync to the norns**

Run: `rsync -avz -e "ssh -i ~/.ssh/norns" ~/dev/synth-quest/ we@$NORNS_IP:/home/we/dust/code/synth-quest/`
Expected: file list ending in `synth-quest.lua` (and unchanged engine/lib files), no errors.

- [ ] **Step 3: Tell the user to reload the script**

Tell the user: "Open Synth Quest on the norns (SELECT > synth-quest > load). No SYSTEM > RESTART needed because the SuperCollider engine wasn't touched. Then start a NEW GAME (not a load) so the cutscene fires."

Wait for the user's playthrough.

---

### Task 9: Manual playthrough verification on device

This is the verification step in lieu of automated tests — see "Tech Stack" note at top of plan.

**Acceptance criteria (from the spec):**

- [ ] **Step 1: Cutscene plays all 21 panels in order**

Ask the user to count the panels they see. Expected: 21 panels, advancing one at a time as the cutscene currently does.

- [ ] **Step 2: Each panel renders a distinct background**

Ask the user to confirm they see visibly different backgrounds for at least the major transitions (cosmic→dark→Lirael→raid). If any panel shows a black screen or the wrong art, capture which one and which scene id and return to the relevant prior task to fix that draw function.

- [ ] **Step 3: Final panel seam to chamber wake**

Confirm the last cutscene panel (`lirael_candles_dim` — three candles, third one guttering) cuts cleanly into the existing `start_prologue_castle_intro` (Miel's chamber, candles wrong, distant impacts). The seam should feel like a continuation, not a jarring scene change.

- [ ] **Step 4: No panel implies Lirael is empty / abandoned**

Confirm none of the 21 panels uses the words "empty", "emptied", "abandoned", or implies the court has been gone "for months" / "for an age" / etc.

- [ ] **Step 5: INTRO music plays continuously**

Confirm the slow 4-bar INTRO_PATTERN at 70 BPM continues across the entire cutscene without pause. (Music is unchanged by this pass; this is a regression check.)

- [ ] **Step 6: Post-cutscene gameplay still works**

After the wake script ends, confirm: Miel can walk the chamber, the existing Page warning scene fires when she steps into the hallway, the courtyard breach fires when she talks to Capt.Ren, the throne scene fires when she enters the throne hall. (Regression check — none of these were touched.)

If any acceptance criterion fails, capture the specific failure and return to the relevant earlier task. Do not commit until all six pass.

---

### Task 10: Snapshot post-pass and commit

**Files:**
- Create: `~/dev/synth-quest/backups/synth-quest-intro-overhaul.lua`
- Modify: `~/dev/synth-quest/DEVLOG.md` (append a one-line entry; matches existing project habit)

- [ ] **Step 1: Snapshot the post-pass script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-intro-overhaul.lua`
Expected: no output, file exists.

- [ ] **Step 2: Append a DEVLOG line**

Read `~/dev/synth-quest/DEVLOG.md`. Append a new entry matching the existing format with date `2026-05-14` and a one-line summary like:

```
## 2026-05-14 — intro cutscene overhaul

Replaced the 4 "court emptied months ago" panels with a 12-panel "Lirael ordinary night" sequence (21 panels total). 21 new draw_scene_* functions, 21 new SCENE_DRAW entries. Cosmic + Dark prose preserved (Dark trimmed 4→3). Existing wake/breach/throne scripts untouched.
```

(If `DEVLOG.md` uses a different format header, mirror its style.)

- [ ] **Step 3: Stage and commit**

Run:
```bash
cd ~/dev/synth-quest && git add synth-quest.lua backups/synth-quest-intro-overhaul.lua DEVLOG.md docs/specs/2026-05-14-intro-cutscene-overhaul-design.md docs/plans/2026-05-14-intro-cutscene-overhaul.md && git status
```
Expected: only the listed files staged. If `git status` shows other modified files (e.g. `lib/Engine_SynthQuest.sc`, `viewer/synth-quest-viewer.py`, `.gitignore`) that are unrelated to this pass, do NOT stage them — leave them as-is.

Run:
```bash
cd ~/dev/synth-quest && git commit -m "$(cat <<'EOF'
intro cutscene overhaul: replace empty-court framing with living-court raid

Rewrites the opening cutscene so its closing beats land Miel inside a
populated, functioning court the night the raid arrives — matching the
playable prologue, which immediately shows Capt.Ren rallying guards,
the Page running warnings, and the scribe Esa at his desk.

- 14 → 21 panels: cosmic (6, prose unchanged) + dark (3, tightened
  from 4) + new "Lirael ordinary night" (12)
- 21 new draw_scene_* functions, 21 new SCENE_DRAW dispatch entries
- Existing scene functions preserved (still used by ENDING_LINES /
  other cutscenes)
- No engine, save, music, or state-machine changes
- Spec: docs/specs/2026-05-14-intro-cutscene-overhaul-design.md
- Plan: docs/plans/2026-05-14-intro-cutscene-overhaul.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds.

---

## Self-review notes

**Spec coverage:** All 21 panels in the spec map to a task (Task 7); all 21 scene draws map to tasks (2/3/4/5); dispatch registration is Task 6; backup discipline is Tasks 1 + 10; manual playthrough acceptance criteria are Task 9; existing scene preservation requirement (don't remove `cosmic`/`dark`/`village`/etc.) is enforced by the `old_string` anchors in Tasks 2-6, which only insert before `SCENE_DRAW = {`.

**Type/name consistency:** Every `draw_scene_<id>` defined in Tasks 2-5 is referenced in Task 6's dispatch table by the same name; every `scene = "<id>"` in Task 7's `CUTSCENE_LINES` matches a key registered in Task 6.

**Placeholder scan:** No "TBD", "TODO", "implement later", "similar to Task N", or unspecified error handling. Every code step contains the actual code.

**TDD note:** This project has no test framework. The skill's TDD pattern doesn't fit norns visual cutscenes; verification is the manual on-device playthrough in Task 9. The `lua5.3 -e 'loadfile(...)'` smoke check after each edit catches syntax errors before deploy, which is the closest equivalent available.
