# Resonances Acquisition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Resonances acquisition scaffold + ship Miel's full path (cat → bell → shrine → attune → callable on R2 in battle) per `docs/specs/2026-05-14-resonances-acquisition-design.md`.

**Architecture:** Single-file change to `synth-quest.lua`. New `RESONANCES` + `RESONANCE_SITES` tables for content, `CONTENT.resonances` for per-save state, one shared `start_resonance_attunement(id)` scaffold, one new scene draw helper, R2 trigger handler mirroring the L2 pattern, RESO branch added to `apply_player_action`, and RESO injected into the d-pad action-cycle list. No engine, save-format-incompatible, or state-machine changes.

**Tech Stack:** norns (Lua), `screen.*` mono primitives at 128×64, `gamepad.analog` for the R2 trigger, `tab.save`/`tab.load` for save data, the existing `SCENE.*` engine for the attunement cinematic. Manual playtest on device — no unit-test framework.

**Spec:** `docs/specs/2026-05-14-resonances-acquisition-design.md`

---

## File Structure

| Change | Location | Note |
|---|---|---|
| `RESONANCES` + `RESONANCE_SITES` global tables | `synth-quest.lua:~175` (after `CLASS_INSTRUMENT`) | Content data; declared as globals (project pattern for large tables) |
| `CONTENT.resonances` init | `synth-quest.lua:~2360` (inside `CONTENT = { ... }`) | All 8 ids initialized to `{item=false, attuned=false}` |
| Save/load round-trip | `synth-quest.lua:~11071` (`save_game`) and `~11160` (`load_game`) | Mirror existing pattern (`data.scene_seen` etc.) |
| Tisa dialogue extension | `synth-quest.lua:2613-2622` | Add lead-aware branch with bell-give scene |
| Shrine tile interception | `synth-quest.lua:12311` (existing tile-48 handler) | Intercept BEFORE tapestry-escape teleport |
| `start_resonance_attunement(id)` | `synth-quest.lua:~5320` (after `start_page_warning_scene`) | Shared scaffold function |
| `draw_scene_lirael_bell_alcove` + dispatch entry | `synth-quest.lua:23101` (alongside other lirael_* draws) and `synth-quest.lua:23139` (`SCENE_DRAW` table) | One new scene helper |
| R2 trigger handler | `synth-quest.lua:15091` (`gamepad.analog`, after triggerleft branch) | New `triggerright` branch with rising-edge detection |
| RESO branch in `apply_player_action` | `synth-quest.lua:13259` (action dispatch) | Add `elseif p.queued == "RESO" then ... end` branch |
| RESO in d-pad action cycle | `synth-quest.lua:14565` | Build action list dynamically including RESO when attuned |
| Pause-menu inventory line (optional) | `synth-quest.lua:21853` (`draw_menu`) | Held-items section with attunement status |

No new files. No tests (project has none).

---

### Task 1: Pre-flight backup

**Files:**
- Read: `~/dev/synth-quest/synth-quest.lua`
- Create: `~/dev/synth-quest/backups/synth-quest-pre-resonances.lua`

- [ ] **Step 1: Snapshot the current script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-pre-resonances.lua`
Expected: no output, file exists at the new path.

- [ ] **Step 2: Confirm snapshot exists**

Run: `ls -la ~/dev/synth-quest/backups/synth-quest-pre-resonances.lua`
Expected: file exists with the same byte size as `synth-quest.lua`.

---

### Task 2: Add RESONANCES + RESONANCE_SITES tables

**Files:**
- Modify: `synth-quest.lua` — insert after the `CLASS_INSTRUMENT` declaration at line 173-174.

**Anchor:** the unique two-line block:

```lua
local CLASS_INSTRUMENT = {bard="LUTE", cleric="HEAL", warrior="TUNE", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM"}
```

- [ ] **Step 1: Add the two new tables**

Use the Edit tool. `old_string`:

```lua
local CLASS_INSTRUMENT = {bard="LUTE", cleric="HEAL", warrior="TUNE", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM"}
```

`new_string`:

```lua
local CLASS_INSTRUMENT = {bard="LUTE", cleric="HEAL", warrior="TUNE", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM"}

-- ── RESONANCES ──────────────────────────────────────────────────────────
-- Catalog of all 8 Resonances per docs/specs/2026-05-14-resonances-acquisition-design.md.
-- Each row: name, character (class string), mp_cost, mythos, effect spec.
-- The `effect` spec is read by apply_resonance_effect (stub for now;
-- real combat behaviors land in a separate spec).
RESONANCES = {
  ring = {
    name      = "The Ring",
    character = "cleric",
    mp_cost   = 6,
    mythos    = "Two bell-tuners who married and learned to multiply each other's notes.",
    effect    = { kind = "ignore_def_clangor", dmg_mult = 1.30, screen_shake = true },
  },
  heavy_hand = {
    name      = "The Heavy Hand",
    character = "drummer",
    mp_cost   = 6,
    mythos    = "A drummer whose strikes were so heavy that every other voice in the room ducked out of his way.",
    effect    = { kind = "duck_enemies", duration_bars = 2, dmg_mult = 0.50 },
  },
  long_echo    = { name = "The Long Echo",    character = nil, mp_cost = 4, mythos = "TBD", effect = {} },
  masked_voice = { name = "The Masked Voice", character = nil, mp_cost = 6, mythos = "TBD", effect = {} },
  spring       = { name = "The Spring",       character = nil, mp_cost = 4, mythos = "TBD", effect = {} },
  scatter      = { name = "The Scatter",      character = nil, mp_cost = 4, mythos = "TBD", effect = {} },
  slow_wheel   = { name = "The Slow Wheel",   character = nil, mp_cost = 4, mythos = "TBD", effect = {} },
  threefold    = { name = "The Threefold",    character = nil, mp_cost = 8, mythos = "TBD", effect = {} },
}

-- World data — where each Resonance's item lives + where its shrine is.
-- Only `ring` has fully-populated entries; the other 7 are stubs so
-- iteration over the table stays type-safe. None fire because they have
-- no shrine handler attached.
RESONANCE_SITES = {
  ring = {
    item = {
      kind  = "npc",
      name  = "Tisa",
      lead  = "cleric",
      label = "Tisa's Bell",
      hint  = "the tapestry alcove",
    },
    shrine = {
      map  = 20,
      x    = 8, y = 2,
      lead = "cleric",
      signature = {
        visual = "lirael_bell_alcove",
        sound  = { class = "cleric", note = 67, vel = 0.7, attack = 0.05, release = 4.0, wet = 1.0 },
        dialogue = {
          "(Miel turns the small bell in her hand. It is silent.)",
          "[Miel]    Two bell-tuners. They married. Their sound never finished folding.",
          "(she rings it once. Somewhere far off -- outside time -- the second bell answers.)",
        },
      },
    },
  },
  heavy_hand   = { item = nil, shrine = nil },
  long_echo    = { item = nil, shrine = nil },
  masked_voice = { item = nil, shrine = nil },
  spring       = { item = nil, shrine = nil },
  scatter      = { item = nil, shrine = nil },
  slow_wheel   = { item = nil, shrine = nil },
  threefold    = { item = nil, shrine = nil },
}
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`. (The L2 pass discovered `lua5.3` is not installed; `lua5.4` is the substitute.)

---

### Task 3: Initialize CONTENT.resonances

**Files:**
- Modify: `synth-quest.lua:~2360` — inside the `CONTENT = { ... }` table (declared at line 2320).

**Anchor:** the unique line `banner_ticks = 0,             -- generic story-event banner countdown` at line 2360.

- [ ] **Step 1: Add the `resonances` field**

Use the Edit tool. `old_string`:

```lua
  banner_ticks = 0,             -- generic story-event banner countdown
```

`new_string`:

```lua
  banner_ticks = 0,             -- generic story-event banner countdown
  -- Per-Resonance state. item=true once the sacred item has been collected;
  -- attuned=true once the shrine attunement has fired. Persists in save.data.
  resonances = {
    ring         = { item = false, attuned = false },
    heavy_hand   = { item = false, attuned = false },
    long_echo    = { item = false, attuned = false },
    masked_voice = { item = false, attuned = false },
    spring       = { item = false, attuned = false },
    scatter      = { item = false, attuned = false },
    slow_wheel   = { item = false, attuned = false },
    threefold    = { item = false, attuned = false },
  },
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 4: Save + load round-trip for CONTENT.resonances

**Files:**
- Modify: `synth-quest.lua:11070` (in `save_game`, near `data.scene_seen`).
- Modify: `synth-quest.lua` (in `load_game`, after the legacy-fallback block — find the unique anchor below).

- [ ] **Step 1: Add save side**

Use the Edit tool. `old_string`:

```lua
  data.scene_seen = {}
  for k, v in pairs(CONTENT.scene_seen or {}) do data.scene_seen[k] = v end
  data.silencer_defeated = CONTENT.silencer_defeated
  data.cave_monster_defeated = CONTENT.cave_monster_defeated
  tab.save(data, SAVE_PATH())
```

`new_string`:

```lua
  data.scene_seen = {}
  for k, v in pairs(CONTENT.scene_seen or {}) do data.scene_seen[k] = v end
  data.silencer_defeated = CONTENT.silencer_defeated
  data.cave_monster_defeated = CONTENT.cave_monster_defeated
  -- Resonances state (per-Resonance item-collected + attuned flags).
  data.resonances = {}
  for id, r in pairs(CONTENT.resonances or {}) do
    data.resonances[id] = { item = r.item or false, attuned = r.attuned or false }
  end
  tab.save(data, SAVE_PATH())
```

- [ ] **Step 2: Find the load-side anchor**

Run: `grep -n "data.silencer_defeated\|data.cave_monster_defeated\|silencer_defeated = data\|cave_monster_defeated = data" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: at least one line referencing the load side (something like `CONTENT.silencer_defeated = data.silencer_defeated` or `if data.silencer_defeated then`). Pick the load-side line(s); the matching anchor block is what we'll modify.

- [ ] **Step 3: Add load side**

Look at the Step 2 output to find the exact block in `load_game` that restores `CONTENT.silencer_defeated` and `CONTENT.cave_monster_defeated`. Use the Edit tool to insert the resonances-load block IMMEDIATELY AFTER that block. The insertion text is:

```lua
  -- Resonances state — restore if present, initialize if missing (older saves).
  if data.resonances then
    for id, r in pairs(data.resonances) do
      if CONTENT.resonances[id] then
        CONTENT.resonances[id].item    = r.item or false
        CONTENT.resonances[id].attuned = r.attuned or false
      end
    end
  end
  -- (CONTENT.resonances was already initialized at module load with all 8
  -- ids set to false, so missing data.resonances on a legacy save just
  -- leaves the defaults in place.)
```

The exact `old_string` will depend on what Step 2 found — copy a unique 3-5 line block from the load side that includes the silencer/cave-monster-defeated restore as the anchor, then put the same block + the new insertion as `new_string`.

- [ ] **Step 4: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 5: Extend Tisa's dialogue with the bell-give scene

**Files:**
- Modify: `synth-quest.lua:2613-2622` — Tisa NPC entry in `quarters_npcs`.

- [ ] **Step 1: Replace Tisa's NPC entry with lead-aware branching**

Use the Edit tool. `old_string`:

```lua
    { x = 7, y = 4, name = "Tisa", kind = "pet",
      visible = function() return CONTENT.prologue_intro_done end,
      dialogue = function()
        return {
          "(Tisa, the queen's cat, opens one yellow eye. Closes it.)",
          "(she has slept through every coup in this castle's history. she will sleep through this one.)",
        }
      end,
    },
```

`new_string`:

```lua
    { x = 7, y = 4, name = "Tisa", kind = "pet",
      visible = function() return CONTENT.prologue_intro_done end,
      dialogue = function()
        local lead = party[active] and party[active].class
        -- First-time interaction with Miel as lead: Tisa surrenders the bell.
        if lead == "cleric" and not CONTENT.resonances.ring.item then
          CONTENT.resonances.ring.item = true
          CONTENT.banner_text  = "* obtained: Tisa's Bell *"
          CONTENT.banner_ticks = 60
          return {
            "(Tisa stretches. Paws something out from under the bed -- a small bell on a frayed ribbon.)",
            "(your grandmother sewed this onto her collar. you had forgotten.)",
            "[Miel]    ...thank you, Tisa.",
            "(Tisa closes her eye again. Her work for the night is done.)",
          }
        end
        -- Default (non-cleric lead, or after the bell was given): the standard line.
        return {
          "(Tisa, the queen's cat, opens one yellow eye. Closes it.)",
          "(she has slept through every coup in this castle's history. she will sleep through this one.)",
        }
      end,
    },
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 6: Intercept the tapestry tile for shrine attunement

**Files:**
- Modify: `synth-quest.lua:12311-12318` — existing tile-48 handler in `try_move`.

The tapestry tile (id 48) lives at map 20 cols 7-8 row 2. Today the handler unconditionally teleports to map 21 (escape cave). We add a guard BEFORE the teleport: if it's Miel + has bell + not yet attuned + on map 20 + on the alcove tile, fire the attunement scene instead.

- [ ] **Step 1: Replace the tile-48 handler**

Use the Edit tool. `old_string`:

```lua
  if t == 48 then
    -- Tapestry door (castle interior, prologue). One-way: enters the
    -- escape cave at its starting tile. Sets prologue_state to "escape".
    CONTENT.prologue_state = "escape"
    travel_to(21, 2, 5)
    redraw()
    return
  end
```

`new_string`:

```lua
  if t == 48 then
    -- Resonance shrine intercept (Miel's). When stepping onto the
    -- tapestry tile on map 20 with Miel as lead AND Tisa's Bell held
    -- AND The Ring not yet attuned, fire the attunement scene instead
    -- of the escape teleport. All other contexts keep the original
    -- escape behavior.
    local p = party[active]
    if current_map_id == 20
       and p and p.class == "cleric"
       and CONTENT.resonances.ring.item
       and not CONTENT.resonances.ring.attuned
       and start_resonance_attunement then
      start_resonance_attunement("ring")
      redraw()
      return
    end
    -- Tapestry door (castle interior, prologue). One-way: enters the
    -- escape cave at its starting tile. Sets prologue_state to "escape".
    CONTENT.prologue_state = "escape"
    travel_to(21, 2, 5)
    redraw()
    return
  end
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 7: Add the shared `start_resonance_attunement` scaffold

**Files:**
- Modify: `synth-quest.lua:~5360` — insert before `function start_prologue_throne_scene()` (line 5363) so it sits with the other prologue scene helpers.

- [ ] **Step 1: Add the scaffold function**

Use the Edit tool. `old_string`:

```lua
function start_prologue_throne_scene()
```

`new_string`:

```lua
-- start_resonance_attunement(id) -- shared scaffold for all Resonance
-- attunement scenes. Reads RESONANCE_SITES[id].shrine.signature for the
-- per-Resonance overrides (visual scene-id, sound spec, dialogue lines).
-- Sets CONTENT.resonances[id].attuned = true at the end.
function start_resonance_attunement(id)
  local r   = RESONANCES[id]
  local s   = RESONANCE_SITES[id] and RESONANCE_SITES[id].shrine
  if not (r and s and s.signature) then return end
  local sig = s.signature
  local px, py = player.x, player.y
  local script = {
    {hide_player = true},
    {letterbox_in = true},
    {set = function() SCENE.fade = 12 end},
    {focus = {x = px, y = py}, ticks = 1},
    {fade_in = 24},
    {wait = 12},
    -- Spawn the lead character at the shrine, facing the alcove.
    {spawn = "attuner", class = (party[active] and party[active].class) or s.lead,
     name = (party[active] and CHAR_NAME[party[active].class]) or "",
     x = px, y = py, facing = "up", bob = false},
    {wait = 14},
    -- Signature sound (one-shot).
    {sfx = sig.sound},
    {wait = 8},
    -- Dialogue lines from the signature block.
    {dialogue = sig.dialogue, npc = nil},
    {wait = 12},
    -- Banner + flag flip.
    {set = function()
      CONTENT.banner_text  = "* Resonance learned -- " .. r.name .. " *"
      CONTENT.banner_ticks = 90
      CONTENT.resonances[id].attuned = true
    end},
    {wait = 24},
    {despawn = "attuner"},
    {teleport_player = {x = px, y = py, facing = "up"}},
    {show_player = true},
    {letterbox_out = true},
  }
  SCENE.start(script)
end

function start_prologue_throne_scene()
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 8: Add the `lirael_bell_alcove` signature scene draw

**Files:**
- Modify: `synth-quest.lua` — add `draw_scene_lirael_bell_alcove` function alongside the other lirael draws.
- Modify: `synth-quest.lua:23139` — register it in `SCENE_DRAW`.

This scene is drawn during the attunement when the shared scaffold's signature visual fires. (Note: the current scaffold in Task 7 doesn't actually invoke a per-Resonance scene draw — it just runs sfx + dialogue. The visual hook is reserved for future enhancement; for now we add the draw function so the asset is in place when later passes wire it up. This keeps the spec's signature.visual field meaningful.)

- [ ] **Step 1: Add the draw function**

Use the Edit tool. `old_string`:

```lua
local function draw_scene_lirael_candles_dim()
```

`new_string`:

```lua
function draw_scene_lirael_bell_alcove()
  -- Tapestry alcove with a slow-swinging bell silhouette growing larger
  -- as the attunement reaches its peak. Background is the alcove
  -- (dark tapestry), foreground is the bell.
  screen.level(1); screen.rect(0, 0, 128, 64); screen.fill()
  -- alcove walls (frame the tapestry)
  screen.level(3); screen.rect(40, 4, 48, 56); screen.fill()
  -- tapestry pattern (vertical stripes, dim)
  screen.level(5)
  for x = 44, 84, 4 do screen.move(x, 8); screen.line(x, 56); screen.stroke() end
  -- floor stripes leading to the alcove
  screen.level(2)
  for y = 56, 62, 2 do screen.move(0, y); screen.line(128, y); screen.stroke() end
  -- the bell silhouette: grows over a 60-tick cycle, then resets
  local phase = (tick % 60) / 60
  local r = 6 + math.floor(phase * 14)
  local sw = math.floor(math.sin(tick * 0.18) * 4)
  -- bell body
  screen.level(11)
  screen.circle(64 + sw, 28, r); screen.fill()
  -- bell mouth (cut-out)
  screen.level(0)
  screen.circle(64 + sw, 28 + r, 2); screen.fill()
  -- clapper at the bottom
  screen.level(13); screen.pixel(64 + sw, 28 + r); screen.fill()
  -- soft halo around the bell at peak
  if phase > 0.6 then
    screen.level(7); screen.circle(64 + sw, 28, r + 4); screen.stroke()
  end
end

local function draw_scene_lirael_candles_dim()
```

(Note: declared `function` (global) rather than `local function` to dodge the 200-local main-chunk cap — same convention used by the cosmic_*/dark_*/lirael_* draws added in the cutscene overhaul pass.)

- [ ] **Step 2: Register the scene in SCENE_DRAW**

Use the Edit tool. `old_string`:

```lua
  lirael_candles_dim  = draw_scene_lirael_candles_dim,
}
```

`new_string`:

```lua
  lirael_candles_dim  = draw_scene_lirael_candles_dim,
  lirael_bell_alcove  = draw_scene_lirael_bell_alcove,
}
```

- [ ] **Step 3: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 9: Add R2 trigger handler

**Files:**
- Modify: `synth-quest.lua:15091-15101` — `gamepad.analog`, after the existing `triggerleft` branch.

- [ ] **Step 1: Add the `triggerright` branch**

Use the Edit tool. `old_string`:

```lua
  if sensor_axis == "triggerleft" then
    -- TOGGLE: rising-edge of trigger pull flips BPM-edit mode on/off.
    -- This avoids controller trigger drift sticking the modifier in either state.
    local now_pressed = (val / half_reso) > 0.2  -- need a meaningful pull
    if now_pressed and not _trigger_prev then
      l2_held = not l2_held
      redraw()
    end
    _trigger_prev = now_pressed
    return
  end
```

`new_string`:

```lua
  if sensor_axis == "triggerleft" then
    -- TOGGLE: rising-edge of trigger pull flips BPM-edit mode on/off.
    -- This avoids controller trigger drift sticking the modifier in either state.
    local now_pressed = (val / half_reso) > 0.2  -- need a meaningful pull
    if now_pressed and not _trigger_prev then
      l2_held = not l2_held
      redraw()
    end
    _trigger_prev = now_pressed
    return
  end
  if sensor_axis == "triggerright" then
    -- ONE-SHOT: rising-edge queues RESO action for the active character
    -- in battle. Same drift-resistant pattern as triggerleft.
    local now_pressed = (val / half_reso) > 0.2
    if now_pressed and not _r2_prev then
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
          if not rid then
            CONTENT.banner_text  = "* no resonance attuned *"
            CONTENT.banner_ticks = 36
          elseif p.mp < RESONANCES[rid].mp_cost then
            CONTENT.banner_text  = "* not enough MP *"
            CONTENT.banner_ticks = 36
          else
            p.queued = "RESO"
            p.queued_resonance = rid
            p.prev_queued = nil
            p.jamming = false
          end
          redraw()
        end
      end
    end
    _r2_prev = now_pressed
    return
  end
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 10: Wire RESO into `apply_player_action`

**Files:**
- Modify: `synth-quest.lua` — inside `apply_player_action(p)`, add a new `elseif p.queued == "RESO"` branch. The existing dispatch tower starts at line 13259 (`if p.queued == "ATK" then`) and contains many `elseif` branches. We add ours at the end of the chain (just before the final `end`), right after the existing `elseif p.queued == "REF"` branch which lives near line 13493.

- [ ] **Step 1: Find the exact insertion point**

Run: `grep -n 'elseif p.queued == "REF"' ~/dev/synth-quest/synth-quest.lua`
Expected: a single line number, e.g., `13493:  elseif p.queued == "REF" then`.

Read the lines from that match through the end of the REF block — the REF branch contains a few lines of Miel's reflect logic, ending in some statement before either another `elseif` or the closing `end` of the dispatch chain.

- [ ] **Step 2: Add the RESO branch**

Locate the block ending the REF case. Use the Edit tool to insert the RESO branch IMMEDIATELY AFTER the REF branch's closing statements and BEFORE either the next `elseif` or the closing `end`. The block to add:

```lua
  elseif p.queued == "RESO" then
    -- Resonance call. MP was checked at queue-time, but re-check at fire
    -- time in case it changed (poison drain, etc.). On success, deduct
    -- MP, fire the signature sound, flash a banner, and stub the effect.
    local rid = p.queued_resonance
    local r   = rid and RESONANCES[rid]
    if r and p.mp >= r.mp_cost then
      p.mp = p.mp - r.mp_cost
      -- Feedback: sound + banner so the player can tell the call landed.
      local sig = RESONANCE_SITES[rid] and RESONANCE_SITES[rid].shrine and RESONANCE_SITES[rid].shrine.signature
      if sig and sig.sound then
        sq_trig(sig.sound.class, midi_to_freq(sig.sound.note),
                sig.sound.vel or 0.7,
                sig.sound.attack or 0.05,
                sig.sound.release or 4.0,
                math.min(1, (sig.sound.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
      end
      CONTENT.banner_text  = "* " .. r.name .. " *"
      CONTENT.banner_ticks = 60
      -- TODO (separate spec): apply_resonance_effect(rid, p) per r.effect.kind.
      -- For now: deal a normal-ATK as a placeholder so the action consumes
      -- a turn and feels like SOMETHING happened.
      if enemy and enemy.alive then
        local dmg = INST.atk(p)
        damage_enemy(dmg, false)
      end
    end
    p.last_fire = tick
    p.last_action = "RESO"
```

The exact `old_string`/`new_string` pair: take the last 3-5 lines of the REF branch as `old_string`, then `old_string` + the RESO block above as `new_string`.

- [ ] **Step 3: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 11: Inject RESO into the d-pad action cycle

**Files:**
- Modify: `synth-quest.lua:14560-14572` — battle dpad-Y handler.

When the active character has an attuned Resonance, d-pad up/down should cycle through ATK / DEF-or-similar / instrument / ITM / RESO (5 options instead of 4).

- [ ] **Step 1: Replace the cycle list builder**

Use the Edit tool. `old_string`:

```lua
    if axis == "Y" then
      -- dpad UD cycles the queued action for the active character
      local p = party[active]
      if p and p.alive then
        local ca = CLASS_ACTIONS[p.class]
        local list = {ca.A, ca.B, ca.X, ca.Y}
        local cur = 1
        for i, a in ipairs(list) do if a == p.queued then cur = i end end
        p.queued = list[((cur - 1 + sign) % 4) + 1]
        p.prev_queued = nil
        p.jamming = false
        redraw()
      end
    elseif axis == "X" then
```

`new_string`:

```lua
    if axis == "Y" then
      -- dpad UD cycles the queued action for the active character.
      -- If this character has an attuned Resonance, RESO is appended as
      -- a 5th option in the cycle.
      local p = party[active]
      if p and p.alive then
        local ca = CLASS_ACTIONS[p.class]
        local list = {ca.A, ca.B, ca.X, ca.Y}
        local has_reso = false
        local reso_id  = nil
        for id, r in pairs(RESONANCES) do
          if r.character == p.class
             and CONTENT.resonances[id]
             and CONTENT.resonances[id].attuned then
            has_reso = true; reso_id = id; break
          end
        end
        if has_reso then list[5] = "RESO" end
        local n = #list
        local cur = 1
        for i, a in ipairs(list) do if a == p.queued then cur = i end end
        p.queued = list[((cur - 1 + sign) % n) + 1]
        if p.queued == "RESO" then p.queued_resonance = reso_id end
        p.prev_queued = nil
        p.jamming = false
        redraw()
      end
    elseif axis == "X" then
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 12: Pause-menu inventory section (held items + attunement status)

**Files:**
- Modify: `synth-quest.lua:21853` — `draw_menu` function.

This is the smaller spec requirement: the pause menu shows held sacred items with attunement status. Optional polish; if it doesn't fit cleanly into `draw_menu` after a quick read, defer to a follow-on pass and skip this task.

- [ ] **Step 1: Read draw_menu to find a safe insertion point**

Run: `sed -n '21853,21920p' ~/dev/synth-quest/synth-quest.lua | head -80`

Look for a section of `draw_menu` that draws static text rows; the held-items section can sit at the bottom of the menu's content area. If the menu is highly structured (paged, scrolling, etc.) and adding a row would require restructuring, mark this task DONE_WITH_CONCERNS and skip Step 2.

- [ ] **Step 2: Add the held-items rendering (if Step 1 confirms it fits)**

If `draw_menu` has a clear "render text rows" area, add a small block after the existing rows:

```lua
  -- Held sacred items (Resonance acquisition). One row per item the
  -- player has collected, with attuned/un-attuned status.
  do
    local y = 56  -- adjust based on draw_menu's existing layout
    for id, st in pairs(CONTENT.resonances or {}) do
      if st.item then
        local site = RESONANCE_SITES[id] and RESONANCE_SITES[id].item
        local label = (site and site.label) or id
        local status = st.attuned and "attuned" or ("attune at " .. ((RESONANCE_SITES[id].item and RESONANCE_SITES[id].item.hint) or "?"))
        screen.level(11)
        screen.move(4, y)
        screen.text(label .. "  -- " .. status)
        y = y + 8
      end
    end
  end
```

Place it where it fits the menu's existing layout; update the `local y = 56` starting coordinate to the actual free space.

- [ ] **Step 3: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 13: Deploy to white norns

**Files:** none modified locally.

- [ ] **Step 1: rsync to the norns**

Run: `rsync -avz -e "ssh -i ~/.ssh/norns" ~/dev/synth-quest/synth-quest.lua we@192.168.1.133:/home/we/dust/code/synth-quest/synth-quest.lua`
Expected: file list ending in `synth-quest.lua`, no errors. (No SuperCollider engine changes, so no SYSTEM > RESTART needed.)

- [ ] **Step 2: Tell the user to reload + new game**

Tell the user: "Open Synth Quest on the norns (SELECT > synth-quest > load). Start a NEW GAME (saves don't have the new resonances field). Walk into the chamber, talk to Tisa as Miel — should get the bell. Walk back into the throne hall, into the alcove behind the throne — should fire the attunement scene. Enter a battle as Miel and press R2 — should queue THE RING."

Wait for the user's playthrough.

---

### Task 14: Manual playthrough verification (10 acceptance criteria)

This is the verification step — see the spec for the 10-criterion acceptance list. Walk through each one with the user.

- [ ] **AC1: Fresh save initializes resonances**

After `init_party()` runs on NEW GAME, `CONTENT.resonances` should have all 8 ids with `{item=false, attuned=false}`. Confirm via debug: have the user open the pause menu and verify no held items shown (or via norns repl `for k,v in pairs(CONTENT.resonances) do print(k, v.item, v.attuned) end`).

- [ ] **AC2: Tisa gives Miel the bell**

In the chamber after the wake, walk Miel up to Tisa and press A. Expected: new four-line scene (cat stretches, bell, "thank you, Tisa"); banner "* obtained: Tisa's Bell *"; afterward `CONTENT.resonances.ring.item == true`.

- [ ] **AC3: Tisa shows existing line for non-Miel leads**

Add another character to the party (this requires playing through the prologue's escape + meeting Alder/Strom/Diegues), switch lead with L1/R1, walk back to Tisa, press A. Expected: original two-liner, no bell scene fires, `CONTENT.resonances.ring.item` unchanged. (If this is hard to test pre-recruitment, mark deferred.)

- [ ] **AC4: Shrine fires attunement**

With Miel as lead and bell collected, walk into the throne hall and step onto cols 7 or 8 row 2 (the tapestry alcove). Expected: attunement scene plays — fade in, Miel spawned facing up, signature sound, three dialogue lines, banner "* Resonance learned -- The Ring *", fade out, control returns. Afterward `CONTENT.resonances.ring.attuned == true`. The escape teleport does NOT fire.

- [ ] **AC5: Shrine without bell = normal escape**

In a separate playthrough (or before collecting the bell), step onto the same tile as Miel. Expected: existing tapestry-escape behavior — `CONTENT.prologue_state = "escape"`, teleport to map 21.

- [ ] **AC6: Battle + R2 queues RESO when attuned + ≥6 MP**

Trigger a battle (cave 1 entry has random encounters). With Miel attuned and ≥ 6 MP, press R2. Expected: HUD action label changes to "RESO". On the action's tick fire, banner "* The Ring *" flashes, signature sound plays, 6 MP deducted, enemy takes normal-ATK damage as the stub.

- [ ] **AC7: Battle + R2 with < 6 MP**

Drain Miel's MP (cast HEAL repeatedly until < 6 MP). In battle, press R2. Expected: banner "* not enough MP *" shows, no action queued.

- [ ] **AC8: Battle + R2 on non-cleric character**

Switch to a non-cleric character (Alder/Strom/Diegues) in battle, press R2. Expected: banner "* no resonance attuned *", no action queued.

- [ ] **AC9: Save + reload roundtrip**

After collecting the bell + attuning, save game, reload. Confirm `CONTENT.resonances.ring.item == true` and `.attuned == true` after reload.

- [ ] **AC10: Old save migration**

Load a save from before this overhaul (e.g., the `synth-quest-pre-resonances.lua` backup, if there's a corresponding `save.data` from then). Expected: `CONTENT.resonances` initializes to all-false, no crash.

If any AC fails, return to the relevant earlier task. Do not commit until ACs 1, 2, 4, 6, 9 pass at minimum (the others are nice-to-haves but minor).

---

### Task 15: Snapshot post-pass + commit

**Files:**
- Create: `~/dev/synth-quest/backups/synth-quest-resonances-vertical-slice.lua`
- Modify: `~/dev/synth-quest/DEVLOG.md`

- [ ] **Step 1: Snapshot the post-pass script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-resonances-vertical-slice.lua`
Expected: no output, file exists.

- [ ] **Step 2: Append a DEVLOG entry**

Read `~/dev/synth-quest/DEVLOG.md`. Append a new entry matching the existing format with date `2026-05-14`:

```
## 2026-05-14 — Resonances acquisition (Miel vertical slice)

Added the Resonances acquisition scaffold per spec
(docs/specs/2026-05-14-resonances-acquisition-design.md). Miel's
full path lands: Tisa gives the bell on first cleric-lead
interaction; walking onto the throne hall's tapestry alcove with
the bell + Miel as lead fires the shared attunement scene; The
Ring becomes callable on R2 in battle. Other 7 Resonances stubbed
in the data tables; their item/shrine/signature blocks fill in
later passes. Battle effect execution is stubbed (normal-ATK +
banner) pending a follow-on spec.
```

- [ ] **Step 3: Stage + commit**

Run:
```bash
cd ~/dev/synth-quest && git add synth-quest.lua DEVLOG.md docs/specs/2026-05-14-resonances-acquisition-design.md docs/plans/2026-05-14-resonances-acquisition.md && git status
```
Expected: only those files staged. If any other file ended up staged (`.gitignore`, `lib/*`, `viewer/*`), unstage before committing — those are pre-existing uncommitted work.

Run:
```bash
cd ~/dev/synth-quest && git commit -m "$(cat <<'EOF'
resonances: acquisition scaffold + Miel vertical slice (The Ring)

Two-step "sacred item -> attune at shrine" loop, gated to the
character. Ships Miel's full path: Tisa surrenders the bell on
first cleric-lead interaction; walking onto the throne hall
tapestry alcove with Miel + bell fires the shared attunement
scene; The Ring becomes callable on R2 in battle (with MP cost).

- New global RESONANCES + RESONANCE_SITES tables (8 ids; only
  ring populated, other 7 stubbed)
- New CONTENT.resonances per-save state with save/load + legacy
  migration
- Tisa NPC dialogue extended with lead-aware bell-give scene
- Tile-48 handler intercepted on map 20 for shrine attunement
- Shared start_resonance_attunement(id) scaffold function
- New draw_scene_lirael_bell_alcove signature visual
- gamepad.analog gains a triggerright (R2) rising-edge handler
- apply_player_action gains a RESO branch (MP cost + banner +
  signature sound + stubbed effect)
- D-pad action cycle includes RESO as a 5th option when attuned

Effect execution stubbed pending follow-on spec.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds.

---

## Self-review notes

**Spec coverage:**

- Architecture (5 pieces) — Tasks 2 (RESONANCES + RESONANCE_SITES), 3 (CONTENT.resonances), 7 (start_resonance_attunement), 9 (R2 input), 10 + 11 (MAG menu/queue integration)
- Data model — Tasks 2, 3
- Miel vertical slice (4 sub-steps) — Tasks 5 (item find), 6 (shrine trigger), 7 (attunement scene), 9-11 (battle availability)
- Shared scaffold — Task 7
- Battle integration (R2, UI, effect deferral, firing feedback) — Tasks 9 (R2), 10 (apply + feedback), 11 (cycle)
- Save format & migration — Task 4
- Inventory display — Task 12 (marked optional)
- Acceptance criteria 1-10 — Task 14

**Placeholder scan:**

- Task 4 has a partial-anchor structure for the load-side because the exact load-side pattern wasn't read in advance. Step 2 is the discovery step; Step 3 follows the discovery. This is acceptable per the plan's "find the anchor first" pattern but is the weakest part of the plan.
- Task 10 has the same shape — Step 1 finds the REF branch end; Step 2 inserts after it.
- Task 12 is explicitly optional ("if it fits"). Acceptable since it's not in any acceptance criterion.
- No "TBD", "implement later", or vague error handling.

**Type/name consistency:**

- `CONTENT.resonances[id]` shape `{item=bool, attuned=bool}` consistent across Tasks 3, 4, 5, 6, 9, 10, 11, 12.
- `RESONANCES[id]` fields `name`, `character`, `mp_cost`, `mythos`, `effect` consistent across Tasks 2, 9, 10.
- `RESONANCE_SITES[id].shrine.signature` fields `visual`, `sound`, `dialogue` consistent across Tasks 2, 7, 10.
- Action queue value `"RESO"` consistent across Tasks 9, 10, 11.
- Per-character field `p.queued_resonance` consistent across Tasks 9, 10, 11.

**TDD note:** Same as the cutscene overhaul plan — no test framework available for norns visual scripts. Manual playthrough in Task 14 is the verification, with the per-task `lua5.4 loadfile` smoke checks catching syntax errors before deploy.
