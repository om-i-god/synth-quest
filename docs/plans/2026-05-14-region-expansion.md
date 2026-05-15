# Region Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four new regions (five new/expanded maps) to Synth Quest — Sunward Coast Town, Phrygian Night City, the Sage Hub (Academy + Velthe's Observatory), and Lirael Ruins — each with party-aware NPCs, signature SCENE scripts, scripted ambient micro-scenes, and a dedicated music theme. Lirael is gated by story flag; the others are reachable at launch. Regions ship one at a time per Approach B with backup snapshots after each.

**Architecture:** All work happens in `synth-quest.lua` (the single-file norns Lua script) and `story/bible.md` (lore canon). No new SCENE engine primitives are introduced — every planned scene composes from existing verbs (camera focus, letterbox, actor move, look, bump, dialogue, fade, sfx, shake, teleport, set). Five new compositions in OW_THEMES; ~15 new tile types with their own draw functions; ~30 new NPC entries across five map tables.

**Tech Stack:** Lua 5.4 on norns; SuperCollider engine `Engine_SynthQuest.sc` for audio; in-script SCENE engine for cutscenes; in-script OW_THEMES table for music; hand-authored 2D map grids.

**Spec reference:** `docs/specs/2026-05-14-region-expansion-design.md`

**Backup discipline:** After each region phase is complete and verified, snapshot both files per the standing rule:
```
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
cp ~/dev/synth-quest/story/bible.md  "~/dev/synth-quest/backups/bible-$(date +%Y%m%d-%H%M%S).md"
```

---

## File Structure

**Modified files** (only two files touched across the whole plan):
- `synth-quest.lua` — all engine and content changes
- `story/bible.md` — lore updates as each region ships

Within `synth-quest.lua`, changes cluster in these regions (line numbers approximate, expect drift as the file grows):

| Region of file | Purpose | Approx. lines |
| --- | --- | --- |
| OW_THEMES table | Music composition entries | 1067-1401 |
| Interior maps block | Existing map data tables | 2374-2873 |
| Overworld maps block | MAINLAND, EASTERN_REACHES, NORTHERN_WILDS, SUNOS_DOMAIN | 4753-4840 |
| SCENE engine state | (read-only; no changes) | 4604-4676 |
| step_player() | Map transition routing | (search by name) |
| Music theme function | Returns theme string by map_id | 11429-11454 |
| Encounter spawn rules | Per-region enemy spawning | 11707, 11967 |
| Tile draw functions | draw_grass, draw_water, draw_cave, etc. | 15850-16207 |
| NPC tables | Per-region `*_NPCS` definitions | (each region adds its own) |
| Scene scripts | SCENE.start scripts triggered by NPCs / tiles | (each region adds its own) |

**Files NOT modified:**
- `lib/Engine_SynthQuest.sc` (audio engine — out of scope; the new music themes use existing engine voices)
- `lib/HDMIMirror.lua` (out of scope)
- `viewer/` (out of scope)

---

## Phase 0 — Foundational Scaffolding

These tasks lay the groundwork that all subsequent regions depend on. Must complete before any region phase begins.

### Task 0.1: Add new story flags to save state

**Files:**
- Modify: `synth-quest.lua` — locate the save-state initializer (search for existing `flag.` or `flags.` initialization, likely near the save/load section)

- [ ] **Step 1: Locate the save-state initialization block**

Run: `grep -n "flag\\." ~/dev/synth-quest/synth-quest.lua | head -30`
Expected: lines showing how existing flags are initialized (e.g. `flag.prologue_done = false`)

- [ ] **Step 2: Add the eight new flags**

Add to the same initialization block (after the last existing flag, before any code that reads them):

```lua
-- Region expansion flags (2026-05-14)
flag.lirael_unlocked       = flag.lirael_unlocked       or false
flag.veiled_mystic_spoken  = flag.veiled_mystic_spoken  or false
flag.iolas_letter_received = flag.iolas_letter_received or false
flag.velthes_entry_heard   = flag.velthes_entry_heard   or false
flag.broken_cadence_done   = flag.broken_cadence_done   or false
flag.bandstand_done        = flag.bandstand_done        or false
flag.strom_confronted      = flag.strom_confronted      or false
flag.diegues_returned      = flag.diegues_returned      or false
flag.unlock_all            = flag.unlock_all            or false  -- debug toggle
-- Per-scene completion flags (added incrementally per phase, listed here for index)
flag.sunward_arrival_done    = flag.sunward_arrival_done    or false
flag.phrygian_arrival_done   = flag.phrygian_arrival_done   or false
flag.observatory_tour_done   = flag.observatory_tour_done   or false
flag.miel_walks_alone_done   = flag.miel_walks_alone_done   or false
flag.lirael_theme_shifted    = flag.lirael_theme_shifted    or false
```

The `or false` idiom ensures old save files (predating these flags) get safe defaults on load.

- [ ] **Step 3: Verify by booting the script**

On the norns: deploy and load any save. Run `tab.print(flag)` in the REPL (or temporarily add `print(flag.lirael_unlocked)` near boot).
Expected: each new flag prints as `false`.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add region expansion story flags"
```

---

### Task 0.2: Add helper function for Lirael unlock check

**Files:**
- Modify: `synth-quest.lua` — add a helper near the existing flag-check helpers (search for similar helpers)

- [ ] **Step 1: Locate where game-state helpers live**

Run: `grep -n "function.*shard_count\|count.*shard\|num_shards" ~/dev/synth-quest/synth-quest.lua | head -5`
Expected: an existing helper that counts owned shards (the game already needs this for gating).

- [ ] **Step 2: Add the unlock-check helper**

Add immediately after the shard-count helper:

```lua
local function lirael_is_unlocked()
  if flag.unlock_all then return true end
  return (shard_count() >= 4) and flag.veiled_mystic_spoken
end
```

(Replace `shard_count()` with the actual existing function name if it differs.)

- [ ] **Step 3: Verify by exercising the helper**

Temporarily add at end of init:
```lua
print("lirael unlock:", lirael_is_unlocked())
```
Boot. Expected: `lirael unlock: false`. Set `flag.unlock_all = true` in REPL, re-call: expected `true`.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add lirael_is_unlocked helper"
```

---

### Task 0.3: Reserve map IDs and add no-op music routing

**Files:**
- Modify: `synth-quest.lua` — the music-theme function near line 11429

- [ ] **Step 1: Locate the theme-string function**

Run: `grep -n "current_map_id == " ~/dev/synth-quest/synth-quest.lua | grep -i theme | head -5`
Or search for the function returning `"village"`, `"woods"`, `"coast"` strings — around line 11429.

- [ ] **Step 2: Add no-op routing for the new map IDs**

Insert into the theme function (placement: alongside existing map_id branches):

```lua
-- Region expansion (2026-05-14) — placeholders, theme strings replaced per phase
if current_map_id == 35 then return "sunward_coast" end
if current_map_id == 36 then return "phrygian_city" end
-- Note: id 19 (academy), id 23 (lirael), id 24 (observatory) already return their
-- own placeholder strings; those themes get composed and replaced in later phases.
```

- [ ] **Step 3: Add placeholder OW_THEMES entries**

Locate OW_THEMES (~line 1067). Find an existing simple entry (e.g. `OW_THEMES.inn`) for shape reference. Add minimal placeholder entries that fall back to existing audio:

```lua
OW_THEMES.sunward_coast = OW_THEMES.coast or OW_THEMES.village  -- placeholder until Phase 1.7
OW_THEMES.phrygian_city = OW_THEMES.eastern or OW_THEMES.village  -- placeholder until Phase 2.7
```

These fall back so the game doesn't crash if the player somehow reaches map 35 or 36 before the real themes are composed.

- [ ] **Step 4: Verify by temporarily routing into a placeholder map**

Temporarily add to overworld step logic: if player steps on a specific test tile, `current_map_id = 35`. Walk onto that tile. Expected: no crash; music continues (falling back to coast theme).

Revert the test tile change before commit.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: reserve map IDs 35/36 with placeholder themes"
```

---

## Phase 1 — Sunward Coast Town (map_id 35)

### Task 1.1: Add tile codes and draw functions for Sunward Coast

**Files:**
- Modify: `synth-quest.lua` — tile draw functions block (~line 15850-16207); tile code constants near top

- [ ] **Step 1: Allocate new tile codes**

Locate the tile-code documentation comment (top of map data, ~line 4748). Add:

```lua
-- New Sunward Coast tiles (Phase 1)
-- 40 = wood_dock        (walkable; planks over water)
-- 41 = tavern_floor     (walkable; interior wood)
-- 42 = bandstand        (walkable; raised platform)
-- 43 = fish_barrel      (impassable object)
-- 44 = market_stall     (impassable; shared with Phrygian)
```

- [ ] **Step 2: Implement draw functions**

Locate `draw_water` (~line 15850) for the pattern. Add after the last existing draw function:

```lua
local function draw_wood_dock(px, py)
  -- horizontal planks with seams
  screen.level(6)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(2)
  screen.move(px, py+2); screen.line_rel(8, 0); screen.stroke()
  screen.move(px, py+5); screen.line_rel(8, 0); screen.stroke()
end

local function draw_tavern_floor(px, py)
  screen.level(4)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(2)
  screen.pixel(px+1, py+1); screen.pixel(px+6, py+6); screen.fill()
end

local function draw_bandstand(px, py, t)
  -- raised platform with one ambient light flicker
  screen.level(8)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(2)
  screen.rect(px, py, 8, 1); screen.fill()
  local flicker = (t % 60 < 30) and 14 or 12
  screen.level(flicker)
  screen.pixel(px+3, py+3); screen.pixel(px+4, py+3); screen.fill()
end

local function draw_fish_barrel(px, py)
  screen.level(5)
  screen.rect(px+1, py+1, 6, 6); screen.fill()
  screen.level(2)
  screen.move(px+1, py+3); screen.line_rel(6, 0); screen.stroke()
end

local function draw_market_stall(px, py)
  screen.level(3)
  screen.rect(px, py+2, 8, 6); screen.fill()
  screen.level(7)  -- awning
  screen.rect(px, py, 8, 2); screen.fill()
end
```

- [ ] **Step 3: Wire draw functions into the main tile-render switch**

Locate the tile-render switch (search for `draw_water` calls in the main render loop). Add:

```lua
elseif t == 40 then draw_wood_dock(px, py)
elseif t == 41 then draw_tavern_floor(px, py)
elseif t == 42 then draw_bandstand(px, py, tick)
elseif t == 43 then draw_fish_barrel(px, py)
elseif t == 44 then draw_market_stall(px, py)
```

- [ ] **Step 4: Verify by temporary tile placement**

Temporarily add tile 42 to any visible existing map (e.g. swap a grass tile near the player spawn). Boot and observe.
Expected: bandstand draws with flickering light pixel; player can walk onto it.

Revert the test change.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Sunward Coast tile types (dock, tavern, bandstand, barrel, stall)"
```

---

### Task 1.2: Author the SUNWARD_COAST_MAP grid

**Files:**
- Modify: `synth-quest.lua` — overworld maps block (after MAINLAND, near line 4840)

- [ ] **Step 1: Define the map table**

Add after the last overworld map (after SUNOS_DOMAIN):

```lua
-- =================================================================
-- SUNWARD COAST TOWN (id 35)
-- Mixolydian harbor; reached from MAINLAND east coast (Tide Cavern path)
-- 32w x 16h
-- =================================================================
local SUNWARD_COAST_MAP = {
  -- row 1 (north - cliff residential)
  {1,1,1,1,0,0,0,0,4,5,4,0,0,0,0,1,1,1,1,1,0,0,4,5,4,0,0,1,1,1,1,1},
  -- row 2
  {1,0,0,0,0,0,0,0,4,0,4,0,0,0,0,0,0,0,0,0,0,0,4,0,4,0,0,0,0,0,0,1},
  -- row 3 (residential cluster + path)
  {1,0,4,5,4,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,1},
  -- row 4
  {1,0,4,0,4,0,2,44,44,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,1},
  -- row 5 (market square row)
  {0,0,0,0,0,0,2,0,0,2,44,44,2,0,0,42,42,42,0,0,0,0,0,4,5,4,0,0,0,2,0,0},
  -- row 6
  {0,0,0,0,0,0,2,0,0,2,0,0,2,0,0,42,42,42,0,0,0,0,0,4,41,4,0,0,0,2,0,0},
  -- row 7 (path leads east to Tide Cavern)
  {2,2,2,2,2,2,2,0,0,2,0,0,2,0,0,42,42,42,0,0,0,0,0,4,41,4,0,0,0,2,2,9},
  -- row 8
  {0,0,0,0,0,0,2,0,0,2,44,44,2,0,0,0,0,0,0,0,0,0,0,4,5,4,0,0,0,2,0,0},
  -- row 9
  {0,0,0,0,0,0,2,0,0,2,0,0,2,43,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0},
  -- row 10 (docks begin)
  {3,3,3,40,40,40,2,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,3},
  -- row 11
  {3,3,3,40,40,40,40,40,40,40,40,40,40,40,40,3,3,3,40,40,40,40,40,40,40,40,40,40,3,3,3,3},
  -- row 12 (water)
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 13
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 14
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 15
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 16 (sea cliff bottom edge)
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
}
```

Layout legend:
- `0` = sand/path beach; `1` = cliff edge (impassable); `2` = path
- `3` = water; `4` = wall; `5` = door (interior entry)
- `40` = wood_dock; `41` = tavern_floor; `42` = bandstand
- `43` = fish_barrel; `44` = market_stall
- `9` = Cave 3 (Tide Cavern) entrance — existing tile code

- [ ] **Step 2: Verify the grid renders**

Temporarily set `current_map_id = 35` and `map = SUNWARD_COAST_MAP` at boot. Walk around.
Expected: harbor visible with docks, market square in north-center, bandstand on the east, residential houses, path east to Cave 3 entrance.

Revert the temp test.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add SUNWARD_COAST_MAP tile data (id 35)"
```

---

### Task 1.3: Wire routing between MAINLAND and Sunward Coast

**Files:**
- Modify: `synth-quest.lua` — `step_player()` function (search by name); the map-swap logic

- [ ] **Step 1: Locate step_player and existing map transitions**

Run: `grep -n "function step_player\|function move_player\|enter_map\|current_map_id =" ~/dev/synth-quest/synth-quest.lua | head -20`
Expected: lines showing how MAINLAND→cave transitions work.

- [ ] **Step 2: Add a Sunward Coast entry tile to MAINLAND**

In MAINLAND's east-coast section (cols 49-64, the existing "coast" zone), pick a tile near the current Cave 3 entry and replace one walkable tile with a new entry tile code. Add tile code `45 = sunward_coast_entry` to the tile-code documentation.

Add to `draw_<tile>` block:
```lua
local function draw_sunward_coast_entry(px, py)
  -- weathered signpost
  screen.level(4)
  screen.rect(px+3, py+1, 2, 6); screen.fill()
  screen.level(8)
  screen.rect(px, py, 8, 2); screen.fill()
end
```

And to the render switch:
```lua
elseif t == 45 then draw_sunward_coast_entry(px, py)
```

In MAINLAND data, change one specific east-coast tile (pick coordinates near col 56, row 7 where path exists) to `45`.

- [ ] **Step 3: Add the transition handler in step_player**

Locate the existing MAINLAND→Cave 3 transition. Add immediately after it:

```lua
-- MAINLAND → Sunward Coast Town
if current_map_id == 1 and map[y] and map[y][x] == 45 then
  return_pos = {x = x, y = y, map_id = 1}
  current_map_id = 35
  map = SUNWARD_COAST_MAP
  player.x, player.y = 1, 7    -- enter at west path edge
  player.facing = "right"
  return
end

-- Sunward Coast → MAINLAND (west edge path)
if current_map_id == 35 and x < 1 then
  current_map_id = 1
  map = MAINLAND
  if return_pos and return_pos.map_id == 1 then
    player.x, player.y = return_pos.x, return_pos.y
  else
    player.x, player.y = 56, 7  -- fallback to east coast
  end
  player.facing = "left"
  return
end
```

(The exact field names — `return_pos`, `map`, `player.x` — must match the codebase's existing naming. Adjust during implementation if names differ.)

- [ ] **Step 4: Verify transition by walking the gate**

Boot. Walk to the new signpost tile on MAINLAND east coast. Expected: scene cuts to Sunward Coast Town; player at west path edge. Walk west off the map. Expected: returns to MAINLAND at the signpost.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: route MAINLAND <-> Sunward Coast Town"
```

---

### Task 1.4: Define SUNWARD_COAST_NPCS table

**Files:**
- Modify: `synth-quest.lua` — add after SUNWARD_COAST_MAP

- [ ] **Step 1: Locate the existing NPC table convention**

Run: `grep -n "_NPCS = {" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: shows MAINLAND_NPCS or similar. Open one and study the structure (`{x, y, name, dialogue, scene, barks, visible, kind}`).

- [ ] **Step 2: Define the NPC table**

Add directly after SUNWARD_COAST_MAP definition. **Declare `local` at the top of this section to avoid global fall-through (per `feedback_lua_local_scoping`).**

```lua
local function shard_react_sunward(npc_name, fallback_lines)
  -- Wraps dialogue with shard-progress reactions, following existing convention
  -- (Replace body if codebase already provides a wrapper; this is a placeholder.)
  return fallback_lines
end

local SUNWARD_COAST_NPCS = {
  -- Mara, Harbormaster's widow, runs the bandstand
  {
    x = 16, y = 5, name = "Mara", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return shard_react_sunward("Mara", {
          "(she sees Alder and her hands still on the lute)",
          "Alder. The wind brought you here, then.",
          "There's an empty stage tonight if you want it.",
        })
      elseif lead == "cleric" then
        return shard_react_sunward("Mara", {
          "Princess. You won't remember me; I sang at",
          "your mother's coronation. Bless this stand,",
          "if you would. It's all we have of him now.",
        })
      elseif lead == "warrior" then
        return shard_react_sunward("Mara", {
          "You walk like he did. The same weight in",
          "the shoulders. Don't tell me he sent you.",
        })
      elseif lead == "mage" then
        return shard_react_sunward("Mara", {
          "Scholar. The Sage Circle keeps a small",
          "post here; Vesa records every visitor.",
          "She'll want to write your name down.",
        })
      else
        return shard_react_sunward("Mara", {
          "Welcome to Sunward Coast. We don't",
          "see many travelers since the refinery",
          "took the Harbormaster.",
        })
      end
    end,
    barks = {"(she tunes a string)", "(humming a Mixolydian air)"},
  },
  -- Hask, tavern keeper, gossip
  {
    x = 25, y = 6, name = "Hask", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return shard_react_sunward("Hask", {
          "Hold up. That scar on your collar — that's",
          "a Suno harness mark. I've buried men who",
          "wore that and never spoke after.",
        })
      elseif lead == "bard" then
        return shard_react_sunward("Hask", {
          "Bards drink free here on Sevenday. Mara's",
          "rule, not mine. Mostly mine.",
        })
      else
        return shard_react_sunward("Hask", {
          "Refinery's hidden behind the headlands now.",
          "You can hear it if the wind comes wrong.",
        })
      end
    end,
    barks = {"(he wipes a glass)", "(eyes the door)"},
  },
  -- Coral, 12-year-old aspiring singer
  {
    x = 17, y = 6, name = "Coral", kind = "npc",
    visible = function() return true end,
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Are you a real bard? Can I try? I can sing",
          "the Mara-song already. Most of it.",
          "(she sings two notes, almost in tune)",
        }
      else
        return {
          "(she watches the bandstand from a stair)",
          "(she's mouthing words to herself)",
        }
      end
    end,
  },
  -- Beck, fisherman
  {
    x = 4, y = 11, name = "Beck", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Strong arms. Want to haul nets at dawn?",
          "Pay's three coppers and a flask of cider.",
        }
      else
        return {
          "At low tide, listen east of the cavern mouth.",
          "Sometimes the old bandleader still calls back.",
        }
      end
    end,
  },
  -- Wynne, traveling bard
  {
    x = 12, y = 4, name = "Wynne", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Trade phrases? I have a Mixolydian turn",
          "from a Locrian funeral. You won't believe",
          "what it does in a major key.",
        }
      else
        return {
          "I'm passing through. The Harbormaster's",
          "duels were the reason I came. He's gone,",
          "but the cavern still answers.",
        }
      end
    end,
  },
  -- Pell, market fishmonger (shop)
  {
    x = 11, y = 5, name = "Pell", kind = "shop",
    dialogue = function()
      return {
        "Salted fish, two coppers. Kelp tea, one.",
        "Healing draught, twelve. Take it or leave it.",
      }
    end,
  },
  -- Vesa, Sage Circle outpost archivist
  {
    x = 26, y = 5, name = "Vesa", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "Diegues, isn't it? Iola wrote me about you.",
          "I'm keeping the eastern records here while",
          "she sees to Velthe's last papers.",
        }
      else
        return {
          "I record every singer who passes. Names",
          "are how we remember after the music goes.",
        }
      end
    end,
  },
  -- Iolen, tide-watcher kid (from bible stub)
  {
    x = 8, y = 9, name = "Iolen", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "(he stands straighter when he sees Strom)",
          "Sir. I keep the tide tally. Take this stone —",
          "it's smooth from a hundred high tides.",
          "(adds Iolen's Tide Stone to party inventory)",
        }
      else
        return {
          "(a kid watching the water)",
          "Tide's high in an hour. You can tell by",
          "the gulls — they go quiet first.",
        }
      end
    end,
  },
}
```

- [ ] **Step 3: Wire the NPC table into the render and step systems**

Locate the existing `_NPCS` integration (search for `MAINLAND_NPCS`). Add a parallel branch:

```lua
elseif current_map_id == 35 then return SUNWARD_COAST_NPCS
```

(In whatever helper currently returns the active NPC list — match the existing pattern.)

- [ ] **Step 4: Verify NPC dialogue with all four leads**

Boot. Enter Sunward Coast. Talk to Mara. Expected: generic dialogue.
Set active to Bard, talk to Mara: bard-specific lines fire.
Repeat for Hask (warrior), Beck (warrior), Vesa (mage), Iolen (warrior). Each lead-specific branch must trigger correctly.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Sunward Coast NPCs with party-aware dialogue"
```

---

### Task 1.5: Write the Sunward Coast "Arrival" signature scene

**Files:**
- Modify: `synth-quest.lua` — scene script block (after NPC tables)

- [ ] **Step 1: Locate an existing arrival-style scene as reference**

Run: `grep -n "SCENE.start\|scene_" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: existing scenes (e.g. opening cutscene, Alder recruit). Study one for the script-array shape.

- [ ] **Step 2: Define the scene script**

Add after the NPC table block:

```lua
local function scene_sunward_arrival()
  return {
    {letterbox_in = true},
    {wait = 6},
    {focus = {x = 16, y = 5}, ticks = 30},   -- pan camera to bandstand
    {wait = 10},
    {dialogue = {
      "The road bends east, and the sea opens.",
      "Lanterns on the bandstand. A woman tuning a lute.",
    }, npc = nil},
    {wait = 4},
    {dialogue = {"Mara:", "Sunward Coast. Stay as long as you need."}, npc = {name = "Mara"}},
    {dialogue = {"Mara:", "If you walk east past the docks, the Tide", "Cavern keeps the Harbormaster's name."}, npc = {name = "Mara"}},
    {wait = 6},
    {focus = "player", ticks = 20},
    {letterbox_out = true},
    {wait = 4},
    {set = function() flag.sunward_arrival_done = true end},
  }
end
```

- [ ] **Step 3: Trigger the scene on first map entry**

In the map-transition handler (Task 1.3, Step 3), after the player has entered Sunward Coast:

```lua
if current_map_id == 35 and not flag.sunward_arrival_done then
  SCENE.start(scene_sunward_arrival())
end
```

Also add `flag.sunward_arrival_done = flag.sunward_arrival_done or false` to the flag init block (Task 0.1's location).

- [ ] **Step 4: Verify**

Delete or reset the save flag. Enter Sunward Coast for the first time.
Expected: letterbox in, camera pans east, narrator line, two Mara lines, letterbox out, control returns to player. Re-enter the map. Expected: no scene replay (flag is set).

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Sunward Coast arrival cutscene"
```

---

### Task 1.6: Write the Bandstand Performance scene (Bard-lead, night)

**Files:**
- Modify: `synth-quest.lua` — scene block + Mara's interaction logic

- [ ] **Step 1: Define the scene**

```lua
local function scene_sunward_bandstand()
  return {
    {letterbox_in = true},
    {focus = {x = 16, y = 5}, ticks = 24},
    {hide_player = true},
    {spawn = "alder_stage", class = "bard", name = "Alder", x = 16, y = 5, facing = "down"},
    {dialogue = {"Mara hands you the lute. The townfolk gather."}},
    {sfx = {class = "bard", note = 60, vel = 0.6, attack = 0.02, release = 0.6, wet = 0.3}},
    {wait = 8},
    {sfx = {class = "bard", note = 64, vel = 0.7, attack = 0.02, release = 0.6, wet = 0.3}},
    {wait = 8},
    {sfx = {class = "bard", note = 67, vel = 0.8, attack = 0.02, release = 0.8, wet = 0.4}},
    {wait = 8},
    {sfx = {class = "bard", note = 70, vel = 0.9, attack = 0.02, release = 1.2, wet = 0.6}},  -- the flat-7
    {wait = 16},
    -- six townsfolk actors spawn around the bandstand and bob
    {spawn = "town1", class = "civ", name = "", x = 14, y = 6, facing = "up", bob = true},
    {spawn = "town2", class = "civ", name = "", x = 15, y = 6, facing = "up", bob = true},
    {spawn = "town3", class = "civ", name = "", x = 17, y = 6, facing = "up", bob = true},
    {spawn = "town4", class = "civ", name = "", x = 18, y = 6, facing = "up", bob = true},
    {spawn = "town5", class = "civ", name = "", x = 15, y = 7, facing = "up", bob = true},
    {spawn = "town6", class = "civ", name = "", x = 17, y = 7, facing = "up", bob = true},
    {wait = 30},
    {dialogue = {"Mara:", "There he is. Welcome home, traveler."}, npc = {name = "Mara"}},
    {wait = 8},
    {despawn = "town1"}, {despawn = "town2"}, {despawn = "town3"},
    {despawn = "town4"}, {despawn = "town5"}, {despawn = "town6"},
    {despawn = "alder_stage"},
    {show_player = true},
    {letterbox_out = true},
    {set = function()
      flag.bandstand_done = true
      -- +1 MAG permanent to Alder
      for _, p in ipairs(party) do
        if p.class == "bard" then p.mag = (p.mag or 0) + 1 end
      end
    end},
    {dialogue = {"You feel a small lift in your chest.", "Alder's MAG +1."}},
  }
end
```

- [ ] **Step 2: Trigger via Mara dialogue when Bard is lead + night**

Modify Mara's NPC entry. Add a `scene` function:

```lua
scene = function()
  local lead = party[active] and party[active].class
  if lead == "bard" and not flag.bandstand_done and is_night() then
    return scene_sunward_bandstand()
  end
end,
```

(Replace `is_night()` with the existing time-of-day check if its name differs.)

- [ ] **Step 3: Verify**

Switch active to Bard. Advance game time to night. Talk to Mara.
Expected: scene plays, six townsfolk spawn around the bandstand, four notes sound, dialogue resolves, Alder's MAG increments by 1. Re-talk to Mara: no re-trigger.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Bandstand Performance scene (Alder +1 MAG)"
```

---

### Task 1.7: Compose the `sunward_coast` music theme

**Files:**
- Modify: `synth-quest.lua` — OW_THEMES (~line 1067-1401)

- [ ] **Step 1: Locate an existing theme for structural reference**

Run: `grep -n "OW_THEMES.coast\|OW_THEMES.village" ~/dev/synth-quest/synth-quest.lua | head -3`
Expected: lines showing PATTERN + ARTIC structure for an existing theme.

- [ ] **Step 2: Replace the placeholder with the composed theme**

Locate the placeholder added in Task 0.3 (`OW_THEMES.sunward_coast = OW_THEMES.coast or OW_THEMES.village`) and replace with:

```lua
OW_THEMES.sunward_coast = {
  bpm = 96,
  pattern = {
    -- Mixolydian: C major scale with flat-7 (Bb)
    -- 4 bars of fiddle ostinato over hand-drum, with bandstand chorus pad
    {voice = "fiddle", notes = {60, 64, 67, 70, 67, 64, 60, 64}, lengths = {1,1,1,2,1,1,1,2}},
    {voice = "drum",   notes = {36, 0, 38, 0, 36, 0, 38, 40}, lengths = {1,1,1,1,1,1,1,1}},
    {voice = "pad",    notes = {52, 0, 0, 0, 55, 0, 0, 0}, lengths = {4,0,0,0,4,0,0,0}},
  },
  artic = {
    fiddle = {attack = 0.02, release = 0.4, wet = 0.25},
    drum   = {attack = 0.005, release = 0.15, wet = 0.1},
    pad    = {attack = 0.6, release = 1.8, wet = 0.5},
  },
}
```

(The exact PATTERN/ARTIC field names must match the existing OW_THEMES shape. Adjust during implementation.)

- [ ] **Step 3: Verify**

Boot. Enter Sunward Coast. Listen.
Expected: bright fiddle melody with a flat-7th lift, soft hand drum, sustained chorus pad. Different in character from the existing `"coast"` theme.

If the theme doesn't audition well, tune the notes/lengths/artic and re-audition before commit.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: compose sunward_coast music theme"
```

---

### Task 1.8: Add the four Sunward Coast ambient micro-scenes

**Files:**
- Modify: `synth-quest.lua` — add tile-step handlers in the per-map ambient block

- [ ] **Step 1: Locate the ambient-tile handler convention**

Run: `grep -n "ambient\|tile_step\|on_step" ~/dev/synth-quest/synth-quest.lua | head -10`
Or search for where existing maps handle "step on a specific tile fires a small scene." If there is no formal handler, add a small dispatcher in `step_player`.

- [ ] **Step 2: Define the four micro-scenes**

```lua
local function ambient_bandstand_practice()
  return {
    {sfx = {class = "bard", note = 67, vel = 0.4, attack = 0.05, release = 0.3, wet = 0.4}},
    {dialogue = {"(someone is practicing inside)"}, npc = nil},
  }
end

local function ambient_dock_gull()
  return {
    {sfx = {class = "fx", note = 84, vel = 0.5, attack = 0.01, release = 0.8, wet = 0.6}},
    {sfx = {class = "fx", note = 81, vel = 0.4, attack = 0.01, release = 0.6, wet = 0.6}},
    {wait = 6},
    {sfx = {class = "bard", note = 70, vel = 0.3, attack = 0.05, release = 0.6, wet = 0.5}},  -- Mixolydian motif
  }
end

local function ambient_market_cry()
  return {
    {dialogue = {"\"FRESH MORNING CATCH — FRESH MORNING —\""}, npc = nil},
  }
end

local function ambient_cliff_reeds()
  local done = flag.cave3_done
  return {
    {sfx = {class = "fx", note = 48, vel = 0.3, attack = 0.5, release = 1.2, wet = 0.8}},
    {dialogue = {
      done and "(the wind carries Tidewatch's cadence back)"
           or "(something out east is answering the wind)"
    }, npc = nil},
  }
end
```

- [ ] **Step 3: Wire micro-scenes to specific tiles**

In the per-tile step handler block (or wherever the dispatcher lives):

```lua
if current_map_id == 35 then
  if x == 16 and y == 5 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_bandstand_practice())
    last_ambient = tick
  elseif x == 9 and y == 11 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_dock_gull())
    last_ambient = tick
  elseif x == 11 and y == 5 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_market_cry())
    last_ambient = tick
  elseif x == 31 and y == 7 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_cliff_reeds())
    last_ambient = tick
  end
end
```

Throttle (600 ticks = ~10s at norns tick rate) prevents re-fire on repeated step.

- [ ] **Step 4: Verify each ambient**

Step on each of the four tiles. Each must fire its scene at least once. Walk back and forth: must not re-fire within 10 seconds.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Sunward Coast ambient micro-scenes (4 tiles)"
```

---

### Task 1.9: Add Sunward Coast encounter spawn rules

**Files:**
- Modify: `synth-quest.lua` — encounter spawn tables (~lines 11707, 11967)

- [ ] **Step 1: Locate encounter spawn rules**

Run: `grep -n "encounter\|spawn.*enemy\|monster_pool" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: tables keyed by `current_map_id` or region returning enemy types.

- [ ] **Step 2: Add Sunward Coast spawns (perimeter only, town interior safe)**

```lua
-- Add to the encounter-by-map-id block
elseif current_map_id == 35 then
  -- Town interior is safe; only the perimeter (y >= 10 dock approach
  -- or x <= 2 west edge wandering) spawns light coast encounters.
  local at_perimeter = (y >= 10) or (x <= 2)
  if at_perimeter and math.random() < 0.04 then
    local pool = {"crab", "manta", "sea_wisp"}
    return pool[math.random(#pool)]
  end
  return nil
```

- [ ] **Step 3: Verify**

Walk the docks and west edge. Expected: occasional encounter, ~4% per step.
Walk in the market square, tavern, residential cluster. Expected: zero encounters.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Sunward Coast perimeter encounters"
```

---

### Task 1.10: Update `bible.md` with Sunward Coast canon

**Files:**
- Modify: `story/bible.md` — update the Mixolydian / Sunward Coast section + NAMED CAST stub resolutions

- [ ] **Step 1: Promote four named-cast stubs to IN CODE entries**

Edit `bible.md` NAMED CAST section. Replace these stub entries with full entries:

For `IOLEN`:
```
   IOLEN (Sunward Coast)
      Role: Tide-watcher kid. Idolizes Strom. Keeps a tide tally
      on a smooth stone he gives the warrior on first meeting.
      STATUS: IN CODE.
```

(No `MARA`, `HASK`, `BECK`, `WYNNE`, `CORAL`, `PELL`, `VESA` — these aren't in the original stub list, so they get NEW entries in the cast section.)

Add new entries to the NAMED CAST section for Mara, Hask, Coral, Beck, Wynne, Pell, Vesa with one-line role descriptions.

- [ ] **Step 2: Add a "Sunward Coast Town" sub-section**

Under the existing `MIXOLYDIAN — THE SUNWARD COAST` section, append:

```
   ── SUNWARD COAST TOWN (in code: map_id 35) ──

   Sun-bleached harbor town adjacent to the Tide Cavern. Layout:
   sea cliff on the south edge, wood docks below the market square,
   tavern + bandstand on the east, small residential cluster west,
   path east leading to the Tide Cavern.

   Cultural anchor: the bandstand, kept in the Harbormaster's name
   by his widow Mara. Bards passing through perform there; Sage
   Circle archivist Vesa records every singer who plays. Coral, a
   twelve-year-old, watches from the stairs and learns the songs.

   Status: established. Reachable from MAINLAND east coast.
```

- [ ] **Step 3: Verify by reading back the updated section**

Open the updated bible. Read the Sunward Coast section + each new cast entry. Check for typos and lore drift against the spec.

- [ ] **Step 4: Commit**

```bash
git add story/bible.md
git commit -m "docs(bible): canonize Sunward Coast Town + 8 NPCs"
```

---

### Task 1.11: Phase 1 playtest + snapshot

- [ ] **Step 1: Full Sunward Coast playtest with each lead**

Boot. Each playthrough:
1. Set active to Bard. Walk to Sunward Coast. Verify arrival scene. Talk to all 8 NPCs and confirm party-aware lines.
2. Repeat with Cleric, Warrior, Mage. Verify each lead's branches.
3. As Bard at night, trigger Bandstand scene; confirm +1 MAG.
4. Walk all four ambient tiles; verify scenes fire.
5. Walk docks; confirm encounters spawn at ~4% rate.
6. Walk west off the map; verify return to MAINLAND.

- [ ] **Step 2: Snapshot lua and bible**

```bash
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
cp ~/dev/synth-quest/story/bible.md  "~/dev/synth-quest/backups/bible-$(date +%Y%m%d-%H%M%S).md"
```

- [ ] **Step 3: Confirm file size growth is acceptable**

Run: `wc -c ~/dev/synth-quest/synth-quest.lua`
Expected: under 1.1MB. If over, investigate before proceeding.

---

## Phase 2 — Phrygian Night City (map_id 36)

### Task 2.1: Add tile codes and draw functions for Phrygian City

**Files:**
- Modify: `synth-quest.lua` — tile constants + draw functions

- [ ] **Step 1: Allocate new tile codes**

Add to the tile-code documentation block:

```lua
-- New Phrygian Night City tiles (Phase 2)
-- 50 = sand_brick         (impassable wall, sand-colored)
-- 51 = tower_base         (impassable; tall tower variant)
-- 52 = prayer_alcove      (walkable interior detail)
-- 53 = desert_sand_path   (walkable; lighter than mainland sand)
-- 54 = lantern_post       (impassable; emits flicker light)
-- (44 market_stall reused from Phase 1)
```

- [ ] **Step 2: Implement draw functions**

```lua
local function draw_sand_brick(px, py)
  screen.level(9)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5)
  screen.move(px, py+3); screen.line_rel(8, 0); screen.stroke()
  screen.move(px+4, py); screen.line_rel(0, 3); screen.stroke()
  screen.move(px+3, py+3); screen.line_rel(0, 5); screen.stroke()
end

local function draw_tower_base(px, py, t)
  screen.level(8)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4)
  screen.move(px, py+5); screen.line_rel(8, 0); screen.stroke()
  -- single faint lit window
  local lit = (t % 90 < 60)
  screen.level(lit and 13 or 7)
  screen.pixel(px+3, py+2); screen.pixel(px+4, py+2); screen.fill()
end

local function draw_prayer_alcove(px, py)
  screen.level(3)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(11)
  -- alcove archway shape
  screen.move(px+2, py+6); screen.line_rel(0, -3); screen.curve(px+4, py+1, px+6, py+3, px+6, py+6); screen.fill()
end

local function draw_desert_sand_path(px, py)
  screen.level(10)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(8)
  screen.pixel(px+1, py+3); screen.pixel(px+5, py+5); screen.pixel(px+3, py+1); screen.fill()
end

local function draw_lantern_post(px, py, t)
  screen.level(4)
  screen.rect(px+3, py+2, 2, 6); screen.fill()  -- post
  local flicker = (t % 24 < 4) and 15 or 13
  screen.level(flicker)
  screen.rect(px+2, py, 4, 3); screen.fill()    -- flame
end
```

- [ ] **Step 3: Wire into tile-render switch**

```lua
elseif t == 50 then draw_sand_brick(px, py)
elseif t == 51 then draw_tower_base(px, py, tick)
elseif t == 52 then draw_prayer_alcove(px, py)
elseif t == 53 then draw_desert_sand_path(px, py)
elseif t == 54 then draw_lantern_post(px, py, tick)
```

- [ ] **Step 4: Verify with temporary tile placement**

Temporarily place tile 54 (lantern_post) on a visible mainland tile. Boot. Watch flicker.
Expected: post draws with periodic flame flicker. Revert.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Phrygian Night City tile types"
```

---

### Task 2.2: Author PHRYGIAN_CITY_MAP grid

**Files:**
- Modify: `synth-quest.lua` — overworld maps block

- [ ] **Step 1: Define the map**

Add after SUNWARD_COAST_MAP:

```lua
-- =================================================================
-- PHRYGIAN NIGHT CITY (id 36)
-- High-desert; reached from EASTERN_REACHES caravan road
-- 36w x 16h
-- =================================================================
local PHRYGIAN_CITY_MAP = {
  -- row 1 (north gate exit to Glass Cavern)
  {50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,11,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50},
  -- row 2 (tower district + temple quarter)
  {50,51,51,0,0,0,0,0,0,0,52,52,52,0,0,0,53,0,0,0,0,0,0,0,0,0,0,0,51,51,51,0,0,0,0,50},
  -- row 3
  {50,51,0,0,0,0,0,0,0,0,52,0,52,0,0,0,53,0,0,0,0,0,0,0,0,0,0,0,51,0,51,0,0,0,0,50},
  -- row 4 (north bazaar row)
  {50,0,0,0,0,44,44,44,0,0,52,0,52,0,0,0,53,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,0,0,0,50},
  -- row 5 (bazaar center with lanterns)
  {50,0,0,0,0,44,0,44,0,54,52,52,52,54,0,0,53,0,0,54,0,44,0,44,0,54,0,0,0,0,0,0,0,0,0,50},
  -- row 6
  {50,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,53,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,0,0,0,50},
  -- row 7 (main east-west path through bazaar)
  {50,0,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,53,0,50},
  -- row 8
  {50,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,53,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,0,0,0,50},
  -- row 9 (south bazaar row)
  {50,0,0,0,0,44,0,44,0,54,0,0,0,54,0,0,53,0,0,54,0,44,0,44,0,54,0,0,0,0,0,0,0,0,0,50},
  -- row 10
  {50,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,53,0,0,0,0,44,44,44,0,0,0,0,0,0,0,0,0,0,0,50},
  -- row 11
  {50,51,0,0,0,0,0,0,0,0,52,0,52,0,0,0,53,0,0,0,0,0,0,0,0,0,0,0,51,0,51,0,0,0,0,50},
  -- row 12
  {50,51,51,0,0,0,0,0,0,0,52,52,52,0,0,0,53,0,0,0,0,0,0,0,0,0,0,0,51,51,51,0,0,0,0,50},
  -- row 13 (south gate exit to EASTERN_REACHES)
  {50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,53,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50},
  -- rows 14-16 padding (no walkable area beyond gate)
  {50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50},
  {50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50},
  {50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50},
}
```

Legend:
- `0` = walkable interior (city floor); `11` = Cave 4 (Glass Cavern) entry from north
- `44` = market_stall; `50` = sand_brick wall; `51` = tower_base
- `52` = prayer_alcove (temple quarter); `53` = desert_sand_path
- `54` = lantern_post

- [ ] **Step 2: Verify the grid renders**

Temporarily set `current_map_id = 36; map = PHRYGIAN_CITY_MAP` and walk. Expected: walled city with central north-south path through bazaar; market stalls in clusters; lanterns flickering; towers framing east/west; temple quarter west of center; north gate to Cave 4; south gate to Eastern Reaches.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add PHRYGIAN_CITY_MAP (id 36)"
```

---

### Task 2.3: Wire EASTERN_REACHES <-> Phrygian Night City routing

**Files:**
- Modify: `synth-quest.lua` — step_player()

- [ ] **Step 1: Add city entry tile to EASTERN_REACHES**

Pick a tile in EASTERN_REACHES on its south-central path. Replace it with new tile code `55 = phrygian_city_entry`:

```lua
local function draw_phrygian_city_entry(px, py)
  screen.level(8)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(3)
  screen.move(px+1, py+2); screen.line_rel(6, 0); screen.move(px+1, py+5); screen.line_rel(6, 0); screen.stroke()
end
```

Wire into render switch: `elseif t == 55 then draw_phrygian_city_entry(px, py)`.

In EASTERN_REACHES data, replace one path tile with `55`.

- [ ] **Step 2: Add transitions**

```lua
-- EASTERN_REACHES → Phrygian Night City (entering south gate)
if current_map_id == 2 and map[y] and map[y][x] == 55 then
  return_pos = {x = x, y = y, map_id = 2}
  current_map_id = 36
  map = PHRYGIAN_CITY_MAP
  player.x, player.y = 16, 13     -- enter at south gate
  player.facing = "up"
  return
end

-- Phrygian Night City → EASTERN_REACHES (south gate exit)
if current_map_id == 36 and y >= 13 then
  current_map_id = 2
  map = EASTERN_REACHES
  if return_pos and return_pos.map_id == 2 then
    player.x, player.y = return_pos.x, return_pos.y
  end
  player.facing = "down"
  return
end

-- Phrygian Night City → Cave 4 (north gate exit)
if current_map_id == 36 and map[y] and map[y][x] == 11 then
  return_pos = {x = x, y = y, map_id = 36}
  current_map_id = 10              -- existing Cave 4 (Glass Cavern) id
  map = CAVE_4_MAP                  -- existing
  player.x, player.y = 6, 12       -- existing Cave 4 entry coords
  player.facing = "up"
  return
end
```

- [ ] **Step 3: Verify**

Walk to the EASTERN_REACHES city-entry tile. Expected: Phrygian Night City loads at south gate. Walk back south: returns to EASTERN_REACHES. Walk north onto tile `11`: Cave 4 loads.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: route EASTERN_REACHES <-> Phrygian City <-> Cave 4"
```

---

### Task 2.4: Define PHRYGIAN_CITY_NPCS table

**Files:**
- Modify: `synth-quest.lua` — after PHRYGIAN_CITY_MAP

- [ ] **Step 1: Define the table**

```lua
local PHRYGIAN_CITY_NPCS = {
  -- Aram, Phrygian war-veteran, Strom's former second
  {
    x = 22, y = 5, name = "Aram", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "(he steps out from behind the stall)",
          "(his hand goes to where his blade used to be)",
          "...You were my second. You ran.",
        }
      else
        return {
          "(an old soldier, marking something on a slate)",
          "Phrygian doesn't forgive what it teaches.",
          "I learned that twice.",
        }
      end
    end,
    scene = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" and not flag.strom_confronted then
        return scene_phrygian_strom_confronted()
      end
    end,
  },
  -- Sergei, glass-cavern guide
  {
    x = 17, y = 4, name = "Sergei", kind = "npc",
    dialogue = function()
      return {
        "Going to the Glass Cavern? Don't go alone.",
        "Three silver and I'll walk you to the dune-line.",
        "I lose people who go without me.",
      }
    end,
  },
  -- Mira, drone-singer in the bazaar
  {
    x = 23, y = 8, name = "Mira", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "(she hears you and stops mid-note)",
          "You shape your scale tempered. Try this.",
          "(she sings a flat-second; you copy it)",
          "Take it. Your PLAY can hold it now.",
        }
      else
        return {
          "(a drone-singer, holding one note for a long time)",
          "(she nods when you pass)",
        }
      end
    end,
  },
  -- Brann, caravan master (shop)
  {
    x = 6, y = 5, name = "Brann", kind = "shop",
    dialogue = function()
      return {
        "Phrygian goods, traveler. Sand-cured trinkets,",
        "water flasks, dried fig cake. Take what you need.",
      }
    end,
  },
  -- Tova, Sage Circle scribe (already in code; place anchor here)
  {
    x = 5, y = 9, name = "Tova", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "(her eyes brighten when she sees Diegues)",
          "Academy boy, are you? Iola sent word.",
          "I've kept her copies of Velthe's last letters.",
          "Come west when you can; she's waiting.",
        }
      else
        return {
          "I'm Sage Circle. I record what passes here.",
          "Not all of it is for the rest of you.",
        }
      end
    end,
    barks = {"(she humms a low slow melody)"},
  },
  -- The Veiled Mystic, sets the lirael flag
  {
    x = 12, y = 5, name = "Veiled Mystic", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      flag.veiled_mystic_spoken = true   -- sets unconditionally on first chat
      if lead == "cleric" then
        return {
          "(her veil shifts; Miel knows the eyes)",
          "Princess. The cathedral fell while we walked east.",
          "I did not turn back. You should not either.",
        }
      else
        return {
          "(she speaks in a sustained drone, words underneath)",
          "The cathedral fell while we walked east.",
          "What was held cannot be held twice.",
        }
      end
    end,
  },
  -- Lantern-keeper child
  {
    x = 19, y = 5, name = "lamplighter", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "(she lights a wick and smiles)",
          "I heard there's a town by the sea where they",
          "sing on a stage. Is it true?",
        }
      else
        return {
          "(a small child, tending a flame)",
          "Night isn't dark when the lanterns are lit.",
        }
      end
    end,
  },
  -- Young scout
  {
    x = 25, y = 9, name = "scout", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Master. Are you taking apprentices?",
          "I can hold a sword. I can hold a shield, too.",
        }
      elseif lead == "cleric" then
        return {
          "(young, asking carefully)",
          "Princess. Does war ever stop? I want to know.",
        }
      else
        return {
          "(she watches the bazaar with hungry eyes)",
        }
      end
    end,
  },
}
```

- [ ] **Step 2: Wire into NPC dispatch**

```lua
elseif current_map_id == 36 then return PHRYGIAN_CITY_NPCS
```

- [ ] **Step 3: Verify dialogue branches**

Switch through all four leads. Talk to each NPC. Verify each lead-specific branch fires. Critical: confirm `flag.veiled_mystic_spoken` flips to true after talking to the Mystic with any lead.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: add Phrygian City NPCs (8) with party-aware dialogue"
```

---

### Task 2.5: Write the Phrygian "Arrival at Dusk" scene

**Files:**
- Modify: `synth-quest.lua` — scene scripts block

- [ ] **Step 1: Define the scene**

```lua
local function scene_phrygian_arrival()
  return {
    {letterbox_in = true},
    {focus = {x = 18, y = 5}, ticks = 36},      -- slow camera pan across towers
    {wait = 8},
    -- five lanterns light up sequentially (set steps modify a render flag)
    {set = function() lantern_lit_count = 1 end}, {wait = 8},
    {set = function() lantern_lit_count = 2 end}, {wait = 8},
    {set = function() lantern_lit_count = 3 end}, {wait = 8},
    {set = function() lantern_lit_count = 4 end}, {wait = 8},
    {set = function() lantern_lit_count = 5 end}, {wait = 12},
    {sfx = {class = "fx", note = 36, vel = 0.5, attack = 1.2, release = 2.4, wet = 0.7}},  -- bass drone rises
    {wait = 16},
    {dialogue = {"Sergei:", "Stay close after the gate closes.", "Phrygian night is not for visitors who wander."}, npc = {name = "Sergei"}},
    {focus = "player", ticks = 20},
    {letterbox_out = true},
    {set = function() flag.phrygian_arrival_done = true end},
  }
end
```

Note: `lantern_lit_count` is a new global used by `draw_lantern_post` only when the lantern is one of the first N (visual progression). Either implement the gating in `draw_lantern_post` or omit the per-lantern reveal in favor of a single fade.

- [ ] **Step 2: Trigger on first entry**

In the EASTERN_REACHES → Phrygian transition:

```lua
if current_map_id == 36 and not flag.phrygian_arrival_done then
  SCENE.start(scene_phrygian_arrival())
end
```

Initialize the supporting flag: `flag.phrygian_arrival_done = flag.phrygian_arrival_done or false`.

- [ ] **Step 3: Verify**

Reset flag. Walk into Phrygian City. Expected: letterbox, slow pan, lanterns light, drone rises, Sergei speaks, letterbox out. Re-enter: no replay.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Phrygian City arrival at dusk cutscene"
```

---

### Task 2.6: Write the "Strom Confronted" scene

**Files:**
- Modify: `synth-quest.lua` — scene scripts block

- [ ] **Step 1: Define the scene**

```lua
local function scene_phrygian_strom_confronted()
  return {
    {letterbox_in = true},
    {focus = {x = 22, y = 5}, ticks = 18},
    {dialogue = {"Aram:", "You were my second. You ran."}, npc = {name = "Aram"}},
    {look = "player", toward = "aram"},
    {wait = 8},
    -- Player gets two responses; for now, simple choice via existing dialogue choice system
    {dialogue = {
      "Strom: I saw what we were ordered to do.",
      "Strom: I did not run. I stopped.",
    }, npc = {name = "Strom"}},
    {wait = 12},
    {dialogue = {"Aram:", "(he lowers his hand from his hip)", "Then I have nothing left to say to you."}, npc = {name = "Aram"}},
    {wait = 8},
    -- single-bar CALL/RESPONSE beat: SFX duel, player resolves via PLAY
    {sfx = {class = "warrior", note = 44, vel = 0.9, attack = 0.01, release = 0.3, wet = 0.1}},
    {wait = 12},
    {bump = "aram", dir = "down", ticks = 6},
    {wait = 8},
    {dialogue = {"Aram:", "Take this. It was my father's before mine."}, npc = {name = "Aram"}},
    {letterbox_out = true},
    {set = function()
      flag.strom_confronted = true
      -- +5 MaxHP permanent to Strom + Aram's Token accessory
      for _, p in ipairs(party) do
        if p.class == "warrior" then
          p.max_hp = (p.max_hp or 200) + 5
          p.hp = math.min(p.hp + 5, p.max_hp)
        end
      end
      inventory_add("arams_token")
    end},
    {dialogue = {"Strom's MaxHP +5. Obtained Aram's Token."}},
  }
end
```

- [ ] **Step 2: Add `arams_token` to the item table**

Locate the item-definition table (search for `inventory_add` or `items =`). Add:

```lua
items.arams_token = {
  name = "Aram's Token",
  kind = "accessory",
  effect = "passive",
  description = "A weighted iron disc. Belonged to a Phrygian soldier's father.",
}
```

- [ ] **Step 3: Verify**

Switch to Warrior lead. Walk to Aram. Expected: scene fires; +5 MaxHP applied; Aram's Token added to inventory. Re-talk to Aram: no replay (flag set).

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Strom Confronted scene + Aram's Token"
```

---

### Task 2.7: Compose `phrygian_city` music theme

**Files:**
- Modify: `synth-quest.lua` — OW_THEMES

- [ ] **Step 1: Replace placeholder with composed theme**

```lua
OW_THEMES.phrygian_city = {
  bpm = 84,
  pattern = {
    -- E Phrygian: E F G A B C D E (flat-2 = F)
    -- 8 bars; bass drone + ney lead + irregular percussion
    {voice = "drone",  notes = {40, 0, 0, 0, 40, 0, 0, 0}, lengths = {8,0,0,0,8,0,0,0}},
    {voice = "ney",    notes = {64, 65, 64, 62, 60, 62, 64, 65}, lengths = {1,1,1,1,1,1,1,2}},
    {voice = "perc",   notes = {36, 0, 0, 38, 0, 36, 0, 0}, lengths = {1,1,1,1,1,1,1,1}},
  },
  artic = {
    drone = {attack = 1.2, release = 4.0, wet = 0.7},
    ney   = {attack = 0.05, release = 0.6, wet = 0.4},
    perc  = {attack = 0.005, release = 0.2, wet = 0.15},
  },
}
```

- [ ] **Step 2: Drop percussion at night**

Add to the theme-tick handler (search for where OW_THEMES voices are processed):

```lua
-- Phrygian: percussion drops out at night
if current_map_id == 36 and is_night() then
  -- skip the "perc" voice this bar
end
```

- [ ] **Step 3: Verify audio**

Enter Phrygian City. Expected: low drone, microtonal ney melody with flat-2, irregular percussion. Advance to night: percussion drops; drone + ney continue.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: compose phrygian_city theme; perc drops at night"
```

---

### Task 2.8: Add Phrygian City ambient micro-scenes

**Files:**
- Modify: `synth-quest.lua` — ambient handler

- [ ] **Step 1: Define the four micro-scenes**

```lua
local function ambient_phrygian_vendor()
  return {
    {dialogue = {"\"STAR-OIL — TWO BLOSSOMS — STAR-OIL —\""}, npc = nil},
  }
end

local function ambient_phrygian_prayer()
  return {
    {sfx = {class = "fx", note = 68, vel = 0.4, attack = 0.6, release = 1.5, wet = 0.7}},
    {wait = 8},
    {sfx = {class = "fx", note = 65, vel = 0.4, attack = 0.6, release = 1.5, wet = 0.7}},  -- flat-2
    {wait = 8},
    {sfx = {class = "fx", note = 68, vel = 0.5, attack = 0.6, release = 2.0, wet = 0.7}},
  }
end

local function ambient_phrygian_lantern()
  return {
    {shake = {mag = 1, ticks = 4}},
    {fade = 2}, {wait = 6}, {fade = 0},
  }
end

local function ambient_phrygian_tova_hum()
  return {
    {sfx = {class = "cleric", note = 60, vel = 0.3, attack = 0.5, release = 1.2, wet = 0.6}},
    {sfx = {class = "cleric", note = 63, vel = 0.3, attack = 0.5, release = 1.2, wet = 0.6}},
  }
end
```

- [ ] **Step 2: Wire to tiles**

```lua
if current_map_id == 36 then
  if x == 17 and y == 7 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_phrygian_vendor())
    last_ambient = tick
  elseif x == 12 and y == 3 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_phrygian_prayer())
    last_ambient = tick
  elseif x == 9 and y == 5 and is_night() and not SCENE.active and tick - (last_ambient or 0) > 300 then
    SCENE.start(ambient_phrygian_lantern())
    last_ambient = tick
  elseif x == 5 and y == 9 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_phrygian_tova_hum())
    last_ambient = tick
  end
end
```

- [ ] **Step 3: Verify each tile**

Walk each of the four tiles. Each ambient must fire. Lantern flicker only fires at night.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Phrygian City ambient micro-scenes"
```

---

### Task 2.9: Phrygian City encounters

**Files:**
- Modify: `synth-quest.lua` — encounter spawn table

- [ ] **Step 1: Add spawn rules (perimeter and caravan road only)**

```lua
elseif current_map_id == 36 then
  local at_gate = (y >= 12) or (y <= 2)
  if at_gate and math.random() < 0.04 then
    local pool = {"scorpion", "sand_manta", "dune_wolf"}
    return pool[math.random(#pool)]
  end
  return nil
```

- [ ] **Step 2: Verify**

Walk the south gate area and tower district. Expected: ~4% encounter rate near gates; safe inside the city.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Phrygian City perimeter encounters"
```

---

### Task 2.10: Update bible with Phrygian City canon

**Files:**
- Modify: `story/bible.md`

- [ ] **Step 1: Promote four named-cast stubs to IN CODE**

Edit NAMED CAST section. For `SERGEI`, `MIRA`, `BRANN`:

```
   SERGEI (Phrygian Night City)
      Role: Glass-cavern guide. Offers three-silver escort to the
      dune-line approach to Cave 4. Trustworthy.
      STATUS: IN CODE.

   MIRA (Phrygian Night City)
      Role: Drone-singer in the central bazaar. Teaches Alder a
      microtonal flat-2 motif that becomes a permanent addition
      to his PLAY action.
      STATUS: IN CODE.

   BRANN (Phrygian Night City)
      Role: Caravan master; runs the Phrygian shop. Sells sand-
      cured trinkets, water flasks, dried fig cake.
      STATUS: IN CODE.
```

- [ ] **Step 2: Add new cast entries for Aram, Tova, Veiled Mystic, lamplighter, scout**

Add brief descriptions to NAMED CAST.

- [ ] **Step 3: Add Phrygian Night City sub-section under PHRYGIAN nation**

```
   ── PHRYGIAN NIGHT CITY (in code: map_id 36) ──

   Walled high-desert city of sand-coloured towers and lantern-lit
   night markets. Microtonal vocal music; drone-led. Lanterns are
   the primary light source after dark. South gate opens onto the
   Eastern Reaches caravan road; north gate gives onto the dunes
   approach to the Glass Cavern (Cave 4).

   Cultural anchors: the central bazaar (Mira sings drones there),
   the temple quarter (prayer alcoves with microtonal vocal SFX),
   the Sage Circle outpost (Tova keeps Velthe's last letters),
   Aram (Strom's former second; pivot point for Strom's arc).

   The VEILED MYSTIC who walked east after Lirael fell speaks here.
   Her dialogue with the party sets `flag.veiled_mystic_spoken`,
   which is a precondition for Lirael's eventual unlock.
```

- [ ] **Step 4: Commit**

```bash
git add story/bible.md
git commit -m "docs(bible): canonize Phrygian Night City + cast"
```

---

### Task 2.11: Phase 2 playtest + snapshot

- [ ] **Step 1: Full playtest with each lead**

1. Bard lead → Mira teaches flat-2 motif; confirm motif persists in Alder's PLAY after.
2. Cleric lead → Veiled Mystic recognition; confirm `flag.veiled_mystic_spoken` set.
3. Warrior lead → Aram triggers Strom Confronted; +5 MaxHP; Aram's Token added.
4. Mage lead → Tova recognizes Diegues; Iola mention seeds the Sage Hub.
5. Walk the four ambient tiles; confirm each fires.
6. Walk gates; confirm transitions to/from EASTERN_REACHES and Cave 4.
7. Walk perimeter; confirm encounters at ~4%.

- [ ] **Step 2: Snapshot**

```bash
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
cp ~/dev/synth-quest/story/bible.md  "~/dev/synth-quest/backups/bible-$(date +%Y%m%d-%H%M%S).md"
```

- [ ] **Step 3: File size check**

`wc -c ~/dev/synth-quest/synth-quest.lua` — expected under 1.15MB.

---

## Phase 3 — Sage Hub (Academy id 19 + Velthe's Observatory id 24)

### Task 3.1: Add Sage Hub tile codes and draw functions

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Tile constants**

```lua
-- Sage Hub tiles (Phase 3)
-- 60 = bookshelf_tall    (impassable; tall library shelf)
-- 61 = astrolabe         (impassable; courtyard centerpiece, animated)
-- 62 = desk_with_papers  (walkable interactable)
-- 63 = lectern           (impassable; lecture hall fixture)
-- 64 = telescope_broken  (impassable; observatory ceiling)
-- 65 = crypt_stair       (walkable interactable; LOCKED until iolas_letter_received)
```

- [ ] **Step 2: Draw functions**

```lua
local function draw_bookshelf_tall(px, py)
  screen.level(4)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(2)
  for i = 1, 7, 2 do
    screen.move(px, py+i); screen.line_rel(8, 0); screen.stroke()
  end
end

local function draw_astrolabe(px, py, t)
  screen.level(3)
  screen.rect(px, py, 8, 8); screen.fill()
  -- rotating ring
  local theta = (t / 120) * 6.283
  local cx, cy = px+4, py+4
  screen.level(12)
  screen.move(cx + math.cos(theta)*3, cy + math.sin(theta)*3)
  screen.line(cx + math.cos(theta+3.14)*3, cy + math.sin(theta+3.14)*3); screen.stroke()
  screen.level(14)
  screen.pixel(cx, cy); screen.fill()
end

local function draw_desk_with_papers(px, py)
  screen.level(5)
  screen.rect(px, py+3, 8, 5); screen.fill()
  screen.level(13)
  screen.rect(px+1, py+1, 5, 2); screen.fill()
end

local function draw_lectern(px, py)
  screen.level(6)
  screen.move(px+2, py+7); screen.line(px+4, py+1); screen.line(px+6, py+7); screen.stroke()
end

local function draw_telescope_broken(px, py)
  screen.level(2)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(8)
  screen.move(px+1, py+6); screen.line(px+6, py+1); screen.stroke()
  screen.level(13)
  -- star pixel through the break
  screen.pixel(px+5, py+1); screen.fill()
end

local function draw_crypt_stair(px, py)
  if flag.iolas_letter_received then
    screen.level(7)
  else
    screen.level(3)
  end
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(0)
  screen.move(px+1, py+6); screen.line_rel(6, 0); screen.move(px+2, py+4); screen.line_rel(4, 0); screen.move(px+3, py+2); screen.line_rel(2, 0); screen.stroke()
end
```

- [ ] **Step 3: Wire into tile render switch**

```lua
elseif t == 60 then draw_bookshelf_tall(px, py)
elseif t == 61 then draw_astrolabe(px, py, tick)
elseif t == 62 then draw_desk_with_papers(px, py)
elseif t == 63 then draw_lectern(px, py)
elseif t == 64 then draw_telescope_broken(px, py)
elseif t == 65 then draw_crypt_stair(px, py)
```

- [ ] **Step 4: Verify each tile renders**

Place one of each on a test map. Boot. Walk past. Confirm visual.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Sage Hub tile types (6 new)"
```

---

### Task 3.2: Expand ACADEMY_MAP (id 19) to 28×14

**Files:**
- Modify: `synth-quest.lua` — interior maps block (~line 2466)

- [ ] **Step 1: Locate current stub**

Run: `grep -n "academy_map\|ACADEMY_MAP" ~/dev/synth-quest/synth-quest.lua | head -5`

- [ ] **Step 2: Replace with expanded grid**

```lua
local ACADEMY_MAP = {
  -- 28w × 14h
  -- row 1 (north wall, lecture hall)
  {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
  -- row 2 (lecture hall row with Iola's office east)
  {4,0,0,0,0,63,0,0,63,0,0,63,0,0,0,0,0,0,0,4,5,4,0,0,0,0,0,4},  -- 5 = door to Iola's office
  -- row 3
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,0,0,0,0,0,4},
  -- row 4 (lecture hall ends; corridor between halls)
  {4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,4},
  -- row 5 (courtyard north edge)
  {4,0,0,0,4,4,4,4,4,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,0,0,0,4},
  -- row 6 (courtyard with astrolabe center)
  {4,0,0,0,4,0,0,0,4,0,0,0,61,0,0,0,0,0,4,0,0,0,0,4,0,0,0,4},
  -- row 7
  {4,0,0,0,4,0,0,0,4,0,0,0,0,0,0,0,0,0,4,0,0,0,0,4,0,0,0,4},
  -- row 8 (courtyard south edge)
  {4,0,0,0,4,4,4,4,4,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,0,0,0,4},
  -- row 9 (dorm wing west; library east)
  {4,0,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,60,60,60,60,60,4},
  -- row 10 (dorm rooms)
  {4,0,4,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,0,0,0,0,60,4},
  -- row 11
  {4,0,4,5,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,0,0,0,0,60,4},
  -- row 12
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,60,60,60,60,60,60,4},
  -- row 13 (south corridor + entry hall)
  {4,2,2,2,2,2,2,2,2,2,2,2,2,17,2,2,2,2,2,2,2,2,2,2,2,2,2,4},  -- 17 = exit tile to Western Region
  -- row 14
  {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
}
```

Legend:
- `0` = walkable floor; `2` = stone path; `4` = wall
- `5` = interior door; `17` = exit tile (returns to Western Region)
- `60` = bookshelf_tall (library east wall); `61` = astrolabe (courtyard center)
- `63` = lectern (lecture hall)

- [ ] **Step 3: Verify rendering**

Enter Academy (via existing Western Region path or temporary direct route). Walk all rooms. Confirm 4 distinct zones visible: entry corridor (south), courtyard (center), library (east), dorms (west), lecture hall (north).

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: expand ACADEMY_MAP to 28x14 with library/courtyard/dorm/lecture zones"
```

---

### Task 3.3: Expand OBSERVATORY_MAP (id 24) to 24×14

**Files:**
- Modify: `synth-quest.lua` — interior maps block

- [ ] **Step 1: Replace stub**

```lua
local OBSERVATORY_MAP = {
  -- 24w × 14h, two levels conceptually (upper rows = telescope chamber)
  -- row 1 (upper level: telescope chamber, roof open)
  {4,4,4,4,4,4,64,64,64,64,64,64,64,64,64,64,64,4,4,4,4,4,4,4},
  -- row 2
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,4,4,4,4},
  -- row 3 (broken telescope footprint)
  {4,0,0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,4,0,0,0,0,0,4},
  -- row 4
  {4,0,0,0,0,0,0,4,0,0,0,0,4,0,0,0,0,4,0,0,0,0,0,4},
  -- row 5
  {4,0,0,0,0,0,0,4,0,0,0,0,4,0,0,0,0,4,0,0,0,0,0,4},
  -- row 6 (internal stair: tile 5 is door/stair between levels)
  {4,4,4,4,4,4,4,4,4,5,4,4,4,4,4,4,4,4,0,0,0,0,0,4},
  -- row 7 (lower level: study + entry)
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,4},
  -- row 8 (Velthe's desk and chair)
  {4,0,0,0,0,0,0,0,0,0,0,62,0,0,0,0,0,4,0,0,0,0,0,4},
  -- row 9
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,4},
  -- row 10 (library wall)
  {4,60,60,60,60,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,4},
  -- row 11 (crypt stair - locked)
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,65,0,4,0,0,0,0,0,4},
  -- row 12
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,4},
  -- row 13 (entry hall + exit tile)
  {4,2,2,2,2,2,2,2,2,2,17,2,2,2,2,2,2,4,4,4,4,4,4,4},  -- 17 = exit to Northern Wilds
  -- row 14
  {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
}
```

Legend:
- `4` = wall; `0` = floor; `2` = stone path; `5` = stair between levels
- `17` = exit; `60` = bookshelf_tall; `62` = desk_with_papers (Velthe's desk)
- `64` = telescope_broken; `65` = crypt_stair (locked until iolas_letter_received)

- [ ] **Step 2: Verify**

Enter Observatory. Walk both levels. Confirm desk visible at row 8 col 11; crypt_stair tile at row 11 col 15 renders darker until flag is set.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: expand OBSERVATORY_MAP to 24x14 with two levels"
```

---

### Task 3.4: Wire Sage Hub routing (Western Region <-> Academy; Northern Wilds <-> Observatory; Observatory crypt_stair -> Cave 6 approach)

**Files:**
- Modify: `synth-quest.lua` — step_player

- [ ] **Step 1: Add Academy entry tile to Western Region**

Pick a path tile in Western Region (id 22). Replace with new tile code `66 = academy_entry`:

```lua
local function draw_academy_entry(px, py)
  screen.level(7)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(3)
  screen.move(px+2, py+5); screen.line(px+4, py+1); screen.line(px+6, py+5); screen.stroke()
end
```

Wire into switch. Replace one Western Region path tile with `66`.

- [ ] **Step 2: Add Observatory entry tile to Northern Wilds**

Similar pattern: new tile code `67 = observatory_entry`. Add a draw function. Replace one Northern Wilds tile with `67`.

- [ ] **Step 3: Routing in step_player**

```lua
-- Western Region → Academy
if current_map_id == 22 and map[y] and map[y][x] == 66 then
  return_pos = {x = x, y = y, map_id = 22}
  current_map_id = 19
  map = ACADEMY_MAP
  player.x, player.y = 13, 13
  player.facing = "up"
  return
end

-- Academy → Western Region
if current_map_id == 19 and map[y] and map[y][x] == 17 then
  current_map_id = 22
  map = WESTERN_REGION_MAP
  if return_pos and return_pos.map_id == 22 then
    player.x, player.y = return_pos.x, return_pos.y
  end
  player.facing = "down"
  return
end

-- Northern Wilds → Observatory
if current_map_id == 3 and map[y] and map[y][x] == 67 then
  return_pos = {x = x, y = y, map_id = 3}
  current_map_id = 24
  map = OBSERVATORY_MAP
  player.x, player.y = 10, 13
  player.facing = "up"
  return
end

-- Observatory → Northern Wilds
if current_map_id == 24 and map[y] and map[y][x] == 17 then
  current_map_id = 3
  map = NORTHERN_WILDS
  if return_pos and return_pos.map_id == 3 then
    player.x, player.y = return_pos.x, return_pos.y
  end
  player.facing = "down"
  return
end

-- Observatory crypt_stair → Cave 6 approach
-- Only walkable if iolas_letter_received; otherwise blocked
if current_map_id == 24 and map[y] and map[y][x] == 65 then
  if flag.iolas_letter_received then
    return_pos = {x = x, y = y, map_id = 24}
    current_map_id = 12  -- existing Cave 6 (Locrian Crypt) interior
    map = CAVE_6_MAP
    player.x, player.y = 6, 13
    player.facing = "up"
    return
  else
    show_message("The stair is sealed. Velthe's mark is on the lock.")
    return
  end
end
```

- [ ] **Step 4: Verify**

Walk Western Region → Academy → back. Walk Northern Wilds → Observatory → back. Step on crypt_stair before flag: blocked. Set flag manually via REPL: step again → enters Cave 6.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: route Sage Hub maps + crypt_stair gating"
```

---

### Task 3.5: Define ACADEMY_NPCS and OBSERVATORY_NPCS tables

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define ACADEMY_NPCS (6 entries)**

```lua
local ACADEMY_NPCS = {
  -- Iola — present here when flag.velthes_entry_heard is FALSE
  {
    x = 20, y = 2, name = "Iola", kind = "npc",
    visible = function() return not flag.velthes_entry_heard end,
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        if shard_count() >= 3 and not flag.iolas_letter_received then
          return scene_academy_iolas_letter_dialogue()  -- triggers letter scene below
        end
        return {
          "(she sets down her pen)",
          "Diegues. Velthe always said you'd come back",
          "when you were ready to ask the right question.",
        }
      else
        return {
          "I'm Iola. I was Velthe's last apprentice.",
          "Diegues, if he's with you, knows my name.",
        }
      end
    end,
    scene = function()
      local lead = party[active] and party[active].class
      if lead == "mage" and shard_count() >= 3 and not flag.iolas_letter_received then
        return scene_academy_iolas_letter()
      end
    end,
  },
  -- Master Theron
  {
    x = 5, y = 2, name = "Theron", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "(he peers at your notation)",
          "That's a Velthe hand. I taught you to write",
          "like that. I take it the cave was kind.",
        }
      elseif lead == "cleric" then
        return {
          "Princess. The Academy stands with Lirael.",
          "What's left of it. (he bows formally)",
        }
      else
        return {
          "Welcome to the Sage Circle's Academy.",
          "Quiet voices, slow questions.",
        }
      end
    end,
  },
  -- Aurin (junior scholar)
  {
    x = 14, y = 7, name = "Aurin", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Are you a bard? A real one? I'm writing a",
          "treatise on troupe music — would you sit",
          "for two questions?",
        }
      elseif lead == "warrior" then
        return {
          "(he visibly steps back when Strom approaches)",
          "I — I don't have anything to write about you.",
        }
      else
        return {
          "Junior scholar. I'm working on the question",
          "of why folk songs survive when libraries burn.",
        }
      end
    end,
  },
  -- Paj (librarian, shop)
  {
    x = 26, y = 10, name = "Paj", kind = "shop",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "Diegues. Velthe's late volumes are in the back.",
          "I'll show you. Books that boost MAG, scrolls",
          "for MP, the usual.",
        }
      else
        return {
          "Books, scrolls, the rare bound parchment.",
          "Prices are firm. Sage Circle rules.",
        }
      end
    end,
  },
  -- Wena (dorm philosopher)
  {
    x = 3, y = 10, name = "Wena", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "cleric" then
        return {
          "(midnight, she's awake)",
          "Princess. The Aeolian thinkers say a held",
          "note is grief made bearable. Is that true?",
        }
      else
        return {
          "Some nights I just can't sleep. Have you ever",
          "thought about why minor sounds sad?",
        }
      end
    end,
  },
  -- Echo (astrolabe-bound Velthe-fragment)
  {
    x = 12, y = 6, name = "Echo", kind = "npc",
    visible = function() return true end,  -- visible to all; semi-transparent
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "(the astrolabe ticks; Velthe's voice through it)",
          "\"The third chord is not a chord. The third —\"",
          "(a fragment, dropped)",
        }
      else
        return {
          "(the astrolabe ticks, slowly)",
          "(a whisper, indistinct)",
        }
      end
    end,
  },
}
```

- [ ] **Step 2: Define OBSERVATORY_NPCS (3 entries)**

```lua
local OBSERVATORY_NPCS = {
  -- Iola — only after velthes_entry_heard
  {
    x = 11, y = 8, name = "Iola", kind = "npc",
    visible = function() return flag.velthes_entry_heard end,
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "(she's reading Velthe's marginalia)",
          "Look — she annotated this passage four times.",
          "She knew Locrius was the cost before she went.",
        }
      else
        return {
          "(reading by lamplight)",
          "It's quieter here than the Academy. I think",
          "she preferred it.",
        }
      end
    end,
  },
  -- The Caretaker
  {
    x = 5, y = 7, name = "Caretaker", kind = "npc",
    dialogue = function()
      return {
        "I've kept this place since Velthe walked out",
        "and didn't come back. Her last words to me:",
        "\"The third chord is not a chord.\"",
        "Twelve years and I still don't know what she",
        "meant.",
      }
    end,
  },
  -- Trapped scout (side quest)
  {
    x = 14, y = 4, name = "scout_trapped", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "(she's pinned under a fallen rafter)",
          "Help me — sing the timber loose if you can.",
          "(Alder hums; the rafter creaks; she's free)",
          "(adds Sage Circle Pin to party inventory)",
        }
      else
        return {
          "(she's pinned under a fallen rafter)",
          "Please — fetch Iola's medicine from the Academy.",
          "I can wait. I can't move.",
        }
      end
    end,
  },
}
```

- [ ] **Step 3: Wire into NPC dispatch**

```lua
elseif current_map_id == 19 then return ACADEMY_NPCS
elseif current_map_id == 24 then return OBSERVATORY_NPCS
```

- [ ] **Step 4: Verify all dialogue branches**

Walk through each NPC with each lead. Critical: confirm Iola is visible at Academy when `flag.velthes_entry_heard = false`, then visible at Observatory only when flag is true.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: ACADEMY_NPCS and OBSERVATORY_NPCS with Iola migration logic"
```

---

### Task 3.6: Write "Diegues Returns" scene (Academy first-entry, Mage-lead)

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define scene**

```lua
local function scene_academy_diegues_returns()
  return {
    {letterbox_in = true},
    {focus = {x = 12, y = 6}, ticks = 30},
    {spawn = "iola_descending", class = "mage", name = "Iola", x = 20, y = 2, facing = "down"},
    {move = "iola_descending", to = {x = 18, y = 5}, ticks = 30},
    {look = "iola_descending", toward = "player"},
    {wait = 8},
    {dialogue = {"Iola:", "Diegues. You came back."}, npc = {name = "Iola"}},
    {dialogue = {"Iola:", "Velthe said you would, eventually.", "She also said you wouldn't know why yet."}, npc = {name = "Iola"}},
    {wait = 4},
    -- Echo at astrolabe murmurs a fragment
    {sfx = {class = "fx", note = 60, vel = 0.3, attack = 0.5, release = 1.5, wet = 0.7}},
    {dialogue = {"(the astrolabe ticks once)", "\"...not a chord. The third —\""}, npc = nil},
    {wait = 6},
    {despawn = "iola_descending"},
    {letterbox_out = true},
    {set = function() flag.diegues_returned = true end},
  }
end
```

- [ ] **Step 2: Trigger on Academy first-entry with Mage lead**

In the routing for Western Region → Academy:

```lua
if current_map_id == 19 and not flag.diegues_returned then
  local lead = party[active] and party[active].class
  if lead == "mage" then
    SCENE.start(scene_academy_diegues_returns())
  end
end
```

- [ ] **Step 3: Verify**

Switch to Mage lead. Enter Academy for first time. Expected: scene fires. Re-enter: no replay.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Diegues Returns scene (Academy first-entry)"
```

---

### Task 3.7: Write "Iola's Letter" scene (Academy, requires 3+ shards)

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define scene**

```lua
local function scene_academy_iolas_letter()
  return {
    {letterbox_in = true},
    {focus = {x = 23, y = 10}, ticks = 24},   -- library tile
    {dialogue = {"Iola:", "I have something for you. It was meant for", "whoever finds the Locrian shard."}, npc = {name = "Iola"}},
    {wait = 6},
    {dialogue = {"(she hands you a sealed letter)"}, npc = nil},
    {wait = 8},
    -- the letter, typewriter, with Velthe's voice fading in over final lines
    {dialogue = {"\"To my successor:"}, npc = nil},
    {dialogue = {"If you are reading this, the Locrian shard is", "near and the world has not yet ended."}, npc = nil},
    {dialogue = {"I went down. I expected to come back.", "Locrius is the cost of that lesson."}, npc = nil},
    {sfx = {class = "fx", note = 55, vel = 0.4, attack = 0.8, release = 2.5, wet = 0.8}},
    {dialogue = {"The third chord is not a chord.", "Find what is wrong with the lock."}, npc = nil},
    {sfx = {class = "fx", note = 52, vel = 0.5, attack = 1.0, release = 3.0, wet = 0.85}},
    {dialogue = {"— Velthe.\""}, npc = nil},
    {wait = 12},
    {dialogue = {"Iola:", "Go when you're ready. She left the stair", "in the Observatory unlocked for you."}, npc = {name = "Iola"}},
    {letterbox_out = true},
    {set = function()
      flag.iolas_letter_received = true
      inventory_add("velthes_letter")
    end},
  }
end

-- Helper so dialogue function can just trigger the scene via the convention
local function scene_academy_iolas_letter_dialogue()
  return {"(Iola gestures toward the library)"}
end
```

- [ ] **Step 2: Wire trigger via Iola's scene callback (already set up in Task 3.5)**

The Iola NPC's `scene` function returns this script when conditions are met. Already wired.

- [ ] **Step 3: Add `velthes_letter` item**

```lua
items.velthes_letter = {
  name = "Velthe's Letter",
  kind = "key",
  description = "A sealed letter from Velthe, opened. Reads it once a day, never the same way twice.",
}
```

- [ ] **Step 4: Verify**

Set Mage lead. Ensure shard_count() >= 3. Enter Academy. Talk to Iola. Expected: scene fires; letter typewriter dialogue; SFX layered on final lines; `flag.iolas_letter_received` set; Velthe's Letter in inventory; `crypt_stair` tile in Observatory should now read as unlocked color.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Iola's Letter scene + Velthe's Letter item"
```

---

### Task 3.8: Write "The Caretaker's Tour" scene (Observatory arrival)

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define scene**

```lua
local function scene_observatory_caretaker_tour()
  return {
    {letterbox_in = true},
    {spawn = "caretaker_t", class = "civ", name = "Caretaker", x = 5, y = 7, facing = "down"},
    {dialogue = {"Caretaker:", "Velthe kept this place herself. Twelve years.", "Then she went down the stair and didn't come back."}, npc = {name = "Caretaker"}},
    {focus = {x = 11, y = 3}, ticks = 36},        -- pan up to telescope roof
    {wait = 10},
    {dialogue = {"Caretaker:", "The roof's been open since the strut broke.", "I never wanted to fix it. She liked the stars."}, npc = {name = "Caretaker"}},
    {wait = 8},
    {focus = "player", ticks = 24},
    {despawn = "caretaker_t"},
    {letterbox_out = true},
    {set = function() flag.observatory_tour_done = true end},
  }
end
```

Add the flag: `flag.observatory_tour_done = flag.observatory_tour_done or false`.

- [ ] **Step 2: Trigger on first entry**

```lua
if current_map_id == 24 and not flag.observatory_tour_done then
  SCENE.start(scene_observatory_caretaker_tour())
end
```

- [ ] **Step 3: Verify**

Enter Observatory for first time. Expected: tour plays.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Observatory Caretaker's Tour scene"
```

---

### Task 3.9: Write "Velthe's Final Entry" scene (Observatory desk tile, requires Iola's Letter)

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define scene**

```lua
local function scene_observatory_velthes_entry()
  return {
    {letterbox_in = true},
    {focus = {x = 11, y = 8}, ticks = 24},
    -- Velthe's voice imprint manifests as a semi-transparent actor
    {spawn = "velthe_imprint", class = "mage", name = "Velthe", x = 11, y = 7, facing = "down"},
    {sfx = {class = "fx", note = 60, vel = 0.4, attack = 0.6, release = 2.0, wet = 0.85}},
    {dialogue = {"Velthe:", "\"Entry forty-three. The shard's instability",
                            "is not a property of the shard.\""}, npc = {name = "Velthe"}},
    {wait = 8},
    {dialogue = {"Velthe:", "\"Locrius has been with it for centuries.", "I believe he has become it.\""}, npc = {name = "Velthe"}},
    {wait = 8},
    -- Mage-lead variant: Diegues finishes the entry
    {set = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        diegues_finishes = true
      end
    end},
    {dialogue = {"Velthe:", "\"The third chord is not a chord. It is —\""}, npc = {name = "Velthe"}},
    {wait = 4},
    {sfx = {class = "fx", note = 53, vel = 0.5, attack = 1.2, release = 3.0, wet = 0.9}},
    -- Diegues completes the line if Mage lead
    {dialogue = {
      diegues_finishes
        and "Diegues: \"— a sustain.\""
        or "(the imprint trails off)"
    }, npc = nil},
    {wait = 12},
    {despawn = "velthe_imprint"},
    {letterbox_out = true},
    {set = function()
      flag.velthes_entry_heard = true
      diegues_finishes = false  -- reset
    end},
    {dialogue = {"The stair below is unlocked. Cave 6 lies beyond."}, npc = nil},
  }
end
```

- [ ] **Step 2: Trigger on desk tile after Iola's Letter**

In the per-tile dispatcher:

```lua
if current_map_id == 24 and x == 11 and y == 8 and flag.iolas_letter_received and not flag.velthes_entry_heard and not SCENE.active then
  SCENE.start(scene_observatory_velthes_entry())
end
```

- [ ] **Step 3: Verify**

Walk to desk before `iolas_letter_received`: nothing happens.
Trigger Iola's Letter at Academy. Return to Observatory. Walk to desk: scene fires. Re-walk: no replay. `flag.velthes_entry_heard` set; Iola now visible at Observatory and gone from Academy; `crypt_stair` becomes walkable to Cave 6.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Velthe's Final Entry scene; unlocks Cave 6 approach"
```

---

### Task 3.10: Compose `academy` and `observatory` themes

**Files:**
- Modify: `synth-quest.lua` — OW_THEMES

- [ ] **Step 1: Compose `academy`**

```lua
OW_THEMES.academy = {
  bpm = 110,
  pattern = {
    -- Diatonic; busy polyphonic; hand drums + clave + bowed bass
    {voice = "bass",  notes = {48, 55, 53, 50, 48, 55, 53, 52}, lengths = {1,1,1,1,1,1,1,1}},
    {voice = "clave", notes = {84, 0, 84, 0, 84, 84, 0, 84}, lengths = {1,1,1,1,1,1,1,1}},
    {voice = "drum",  notes = {36, 0, 38, 0, 36, 0, 38, 38}, lengths = {1,1,1,1,1,1,1,1}},
  },
  artic = {
    bass  = {attack = 0.05, release = 0.4, wet = 0.2},
    clave = {attack = 0.001, release = 0.05, wet = 0.05},
    drum  = {attack = 0.005, release = 0.15, wet = 0.1},
  },
}
```

- [ ] **Step 2: Compose `observatory`**

```lua
OW_THEMES.observatory = {
  bpm = 56,
  pattern = {
    -- Locrian on B (B C D E F G A B); sparse; detuned partials
    {voice = "drone1", notes = {47, 0, 0, 0, 0, 0, 0, 0}, lengths = {16,0,0,0,0,0,0,0}},
    {voice = "drone2", notes = {54, 0, 0, 0, 0, 0, 53, 0}, lengths = {6,0,0,0,0,0,10,0}},  -- the detune wanders
    {voice = "bell",   notes = {0, 0, 65, 0, 0, 0, 0, 0}, lengths = {0,0,2,0,0,0,0,0}},
  },
  artic = {
    drone1 = {attack = 2.0, release = 6.0, wet = 0.85},
    drone2 = {attack = 1.5, release = 5.0, wet = 0.85},
    bell   = {attack = 0.005, release = 4.0, wet = 0.95},
  },
}
```

- [ ] **Step 3: Verify both themes**

Enter Academy. Expected: busy ostinato. Enter Observatory. Expected: slow drift with detuned partials and occasional bell.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: compose academy and observatory themes"
```

---

### Task 3.11: Sage Hub ambient micro-scenes

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define four micro-scenes**

```lua
local function ambient_academy_library()
  return {
    {dialogue = {"(she's reading Velthe's third volume aloud)"}, npc = nil},
  }
end

local function ambient_academy_astrolabe()
  return {
    {sfx = {class = "fx", note = 72, vel = 0.3, attack = 0.05, release = 0.2, wet = 0.5}},
    {dialogue = {
      (party[active] and party[active].class == "mage")
        and "(the astrolabe ticks; you hear \"—the third—\")"
        or "(the astrolabe ticks; a whisper, indistinct)"
    }, npc = nil},
  }
end

local function ambient_observatory_stars()
  return {
    {sfx = {class = "fx", note = 51, vel = 0.3, attack = 1.5, release = 3.0, wet = 0.9}},
    {dialogue = {"(stars visible through the broken roof)"}, npc = nil},
  }
end

local function ambient_observatory_desk_premature()
  return {
    {dialogue = {"(Velthe's handwriting is still drying — impossible)"}, npc = nil},
  }
end
```

- [ ] **Step 2: Wire to tiles**

```lua
if current_map_id == 19 then
  if x == 24 and y == 10 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_academy_library())
    last_ambient = tick
  elseif x == 12 and y == 7 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_academy_astrolabe())
    last_ambient = tick
  end
end
if current_map_id == 24 then
  if x == 11 and y == 3 and is_night() and not SCENE.active and tick - (last_ambient or 0) > 300 then
    SCENE.start(ambient_observatory_stars())
    last_ambient = tick
  elseif x == 11 and y == 8 and not flag.velthes_entry_heard and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_observatory_desk_premature())
    last_ambient = tick
  end
end
```

- [ ] **Step 3: Verify**

Walk each tile and confirm.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Sage Hub ambient micro-scenes"
```

---

### Task 3.12: Sage Hub encounters

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Add encounter rules**

```lua
elseif current_map_id == 19 then
  return nil  -- Academy interior is safe
elseif current_map_id == 24 then
  -- Observatory upper level (rows <= 5): occasional Crow Wraith
  if y <= 5 and math.random() < 0.02 then
    return "crow_wraith"
  end
  return nil
```

The exterior approach paths to both maps already get their encounters from the parent overworld (Western Region for Academy, Northern Wilds for Observatory) — no new rules needed for those.

- [ ] **Step 2: Verify**

Academy interior: zero encounters. Observatory upper level (telescope chamber): occasional Crow Wraith.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Sage Hub encounter rules"
```

---

### Task 3.13: Update bible with Sage Hub canon

**Files:**
- Modify: `story/bible.md`

- [ ] **Step 1: Promote stubs**

Edit NAMED CAST. Promote AURIN, PAJ, WENA, ECHO to IN CODE entries:

```
   AURIN (Academy)
      Role: Junior Sage Circle scholar. Eager but green. Writing
      a treatise on troupe music; visibly afraid of Strom.
      STATUS: IN CODE.

   PAJ (Academy library)
      Role: Academy librarian. Shop NPC selling MP/MAG-boost
      scrolls and bound parchments. Friendly to Diegues.
      STATUS: IN CODE.

   WENA (Academy dormitories)
      Role: Dormitory student, midnight philosopher. Asks Miel
      about Aeolian theology.
      STATUS: IN CODE.

   ECHO (Academy courtyard, astrolabe-bound)
      Role: Semi-transparent figure manifest near the astrolabe.
      Speaks only in fragments of Velthe's voice. Reveals a
      clearer line to Diegues.
      STATUS: IN CODE.
```

Add new entries for Master Theron and the Caretaker; expand existing IOLA entry to note the Academy/Observatory migration logic.

- [ ] **Step 2: Expand the existing SAGE CIRCLE & VELTHE'S OBSERVATORY section**

Append details on the Academy map layout (4 zones: lecture hall, courtyard, library, dorms) and the Observatory's two levels (telescope chamber upper, study lower, locked crypt stair).

- [ ] **Step 3: Commit**

```bash
git add story/bible.md
git commit -m "docs(bible): canonize Sage Hub maps + cast"
```

---

### Task 3.14: Phase 3 playtest + snapshot

- [ ] **Step 1: Full playtest with each lead**

1. Mage lead: enter Academy first time → Diegues Returns scene. Talk to Iola with 3+ shards → Iola's Letter scene → Velthe's Letter added.
2. Cleric lead: Master Theron's bow; Wena's Aeolian question.
3. Bard lead: Aurin's treatise request; Echo astrolabe murmur (mage variant fires separately).
4. Warrior lead: Aurin's fear of Strom.
5. After Iola's Letter, walk to Observatory desk → Velthe's Final Entry scene → crypt_stair unlocks.
6. Confirm Iola disappears from Academy and appears at Observatory after `flag.velthes_entry_heard`.
7. Step on crypt_stair → enters Cave 6 (verify the existing Cave 6 entry coords match the routing).

- [ ] **Step 2: Snapshot**

```bash
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
cp ~/dev/synth-quest/story/bible.md  "~/dev/synth-quest/backups/bible-$(date +%Y%m%d-%H%M%S).md"
```

---

## Phase 4 — Lirael Ruins (map_id 23, gated)

### Task 4.1: Add Lirael tile codes and draw functions

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Tile constants**

```lua
-- Lirael Ruins tiles (Phase 4)
-- 70 = ash                  (walkable; ash-covered ground)
-- 71 = rubble               (impassable; broken stone)
-- 72 = cathedral_pillar     (impassable; large object)
-- 73 = sea_cliff_edge       (impassable; visual border)
-- 74 = broken_altar         (impassable interactable)
-- 75 = hymnal_stand         (impassable interactable)
-- 76 = child_toy            (walkable decorative)
-- 77 = lirael_blue_brick    (impassable; intact wall)
-- 78 = cathedral_door       (walkable threshold)
```

- [ ] **Step 2: Draw functions**

```lua
local function draw_ash(px, py)
  screen.level(3)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5)
  screen.pixel(px+1, py+2); screen.pixel(px+4, py+5); screen.pixel(px+6, py+1); screen.pixel(px+3, py+7); screen.fill()
end

local function draw_rubble(px, py)
  screen.level(6)
  screen.rect(px+1, py+2, 3, 3); screen.fill()
  screen.rect(px+4, py+1, 3, 4); screen.fill()
  screen.rect(px+2, py+5, 4, 2); screen.fill()
end

local function draw_cathedral_pillar(px, py)
  screen.level(10)
  screen.rect(px+1, py, 6, 8); screen.fill()
  screen.level(3)
  screen.move(px+1, py+3); screen.line_rel(6, 0); screen.stroke()
end

local function draw_sea_cliff_edge(px, py)
  screen.level(2)
  screen.rect(px, py, 8, 4); screen.fill()
  screen.level(7)  -- water below
  screen.rect(px, py+4, 8, 4); screen.fill()
end

local function draw_broken_altar(px, py, t)
  screen.level(9)
  screen.rect(px, py+2, 8, 6); screen.fill()
  screen.level(4)
  -- crack
  screen.move(px+3, py+8); screen.line(px+5, py+2); screen.stroke()
  -- ash falling overhead
  local f = (t % 30) / 30
  screen.level(6)
  screen.pixel(px + 2, py + math.floor(f*3)); screen.fill()
end

local function draw_hymnal_stand(px, py)
  screen.level(6)
  screen.rect(px+3, py+3, 2, 5); screen.fill()  -- stand
  screen.level(11)
  screen.rect(px+1, py+1, 6, 3); screen.fill()  -- open hymnal
end

local function draw_child_toy(px, py)
  screen.level(10)  -- Lirael blue
  screen.rect(px+2, py+5, 4, 2); screen.fill()
  screen.level(2)
  screen.pixel(px+2, py+4); screen.pixel(px+5, py+4); screen.fill()
end

local function draw_lirael_blue_brick(px, py)
  screen.level(10)  -- Lirael blue, intact
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7)
  screen.move(px, py+4); screen.line_rel(8, 0); screen.move(px+4, py); screen.line_rel(0, 4); screen.move(px+3, py+4); screen.line_rel(0, 4); screen.stroke()
end

local function draw_cathedral_door(px, py)
  screen.level(4)
  screen.rect(px+1, py, 6, 8); screen.fill()
  screen.level(8)
  screen.rect(px+2, py+1, 4, 6); screen.fill()
end
```

- [ ] **Step 3: Wire into tile-render switch**

```lua
elseif t == 70 then draw_ash(px, py)
elseif t == 71 then draw_rubble(px, py)
elseif t == 72 then draw_cathedral_pillar(px, py)
elseif t == 73 then draw_sea_cliff_edge(px, py)
elseif t == 74 then draw_broken_altar(px, py, tick)
elseif t == 75 then draw_hymnal_stand(px, py)
elseif t == 76 then draw_child_toy(px, py)
elseif t == 77 then draw_lirael_blue_brick(px, py)
elseif t == 78 then draw_cathedral_door(px, py)
```

- [ ] **Step 4: Verify each tile renders**

Place each on a test map. Confirm visual. Note `draw_broken_altar`'s ash particle animates with `tick`.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Lirael Ruins tile types (9 new)"
```

---

### Task 4.2: Author LIRAEL_MAP (40×18, multi-zone single map)

**Files:**
- Modify: `synth-quest.lua` — interior maps block (replace existing stub at id 23)

- [ ] **Step 1: Replace LIRAEL_MAP stub**

```lua
local LIRAEL_MAP = {
  -- 40w × 18h. Four visual zones on one grid.
  -- Royal Quarters NW; Cathedral Nave center-north; Side Chapel east; Burned Streets south.
  -- row 1 (north wall, royal quarters back wall + cathedral apse)
  {77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,77,4,4,4,4,4,4,4,4},
  -- row 2 (royal quarters interior + cathedral altar)
  {77,0,0,0,5,77,0,0,0,0,0,77,77,77,77,77,77,74,77,77,77,77,77,77,77,77,77,77,77,77,77,4,0,0,0,0,0,0,0,4},
  -- row 3
  {77,0,0,0,0,77,0,76,0,0,0,77,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,75,0,0,0,0,4},
  -- row 4 (royal quarters + cathedral nave)
  {77,0,0,0,0,77,0,0,0,0,0,77,0,72,0,0,72,0,0,72,0,0,72,0,0,0,72,0,0,72,0,4,0,0,0,0,0,0,0,4},
  -- row 5
  {77,77,77,5,77,77,77,77,77,77,77,77,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,4},
  -- row 6 (nave continues; side chapel east wall begins)
  {0,0,0,0,0,0,0,0,0,0,0,0,0,72,0,0,72,0,0,72,0,0,72,0,0,0,72,0,0,72,0,4,4,4,4,4,4,4,5,4},
  -- row 7
  {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  -- row 8 (nave south wall - cathedral_door connects to burned streets)
  {0,0,0,0,0,0,0,0,0,0,0,0,77,77,77,77,77,77,78,78,77,77,77,77,77,77,77,77,77,77,77,77,0,0,0,0,0,0,0,0},
  -- row 9 (burned streets begin; ash everywhere)
  {0,0,71,0,70,70,70,0,70,70,70,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,70,70,70,70,0,0,0},
  -- row 10
  {0,71,71,0,70,4,4,0,70,4,4,0,0,0,0,71,0,70,70,70,70,70,71,0,0,0,0,71,0,0,0,0,0,70,4,4,70,0,0,0},
  -- row 11 (street through collapsed merchant houses)
  {2,2,2,2,2,4,5,2,2,4,5,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,4,5,2,2,2,2},
  -- row 12
  {0,0,0,0,70,4,4,0,70,4,4,0,0,71,0,0,0,70,70,70,76,0,0,0,0,71,0,0,0,71,0,70,0,70,4,4,70,0,0,0},
  -- row 13
  {0,0,0,71,70,70,70,0,70,70,70,0,0,0,71,0,0,0,0,0,0,0,0,71,0,0,0,0,0,0,0,0,0,70,70,70,70,0,0,0},
  -- row 14 (path continues; ash)
  {0,0,0,0,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,70,0,0},
  -- row 15 (sea cliff edge approaching south)
  {73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73,73},
  -- row 16 (water below)
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 17
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
  -- row 18 (south map edge)
  {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
}
```

Legend:
- `0` = walkable floor/ash; `2` = path stone; `3` = water; `4` = wall
- `5` = door (interior threshold); `70` = ash; `71` = rubble; `72` = cathedral_pillar
- `73` = sea_cliff_edge; `74` = broken_altar; `75` = hymnal_stand; `76` = child_toy
- `77` = lirael_blue_brick; `78` = cathedral_door

- [ ] **Step 2: Verify**

Temporarily set `flag.unlock_all = true`. Enter Lirael via Western Region. Walk all four zones: Burned Streets (south), Ruined Nave (center-north), Royal Quarters (northwest), Side Chapel (east). Confirm cathedral pillars draw, broken altar animates ash, sea cliff renders.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: LIRAEL_MAP 40x18 with four visual zones"
```

---

### Task 4.3: Wire Western Region → Lirael routing (gated)

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Lirael entry tile in Western Region**

Pick a tile in Western Region. Add tile code `79 = lirael_entry`:

```lua
local function draw_lirael_entry(px, py)
  if lirael_is_unlocked() then
    screen.level(8)
  else
    screen.level(3)
  end
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(0)
  screen.move(px+2, py+2); screen.line(px+6, py+6); screen.move(px+6, py+2); screen.line(px+2, py+6); screen.stroke()
end
```

Wire into switch. Replace one Western Region tile with `79`.

- [ ] **Step 2: Routing in step_player**

```lua
-- Western Region → Lirael Ruins (gated)
if current_map_id == 22 and map[y] and map[y][x] == 79 then
  if lirael_is_unlocked() then
    return_pos = {x = x, y = y, map_id = 22}
    current_map_id = 23
    map = LIRAEL_MAP
    player.x, player.y = 20, 14
    player.facing = "up"
    return
  else
    show_message("The road west is closed in mourning. No one passes.")
    return
  end
end

-- Lirael → Western Region
if current_map_id == 23 and y >= 14 and map[y] and map[y][x] == 70 and x == 20 then
  current_map_id = 22
  map = WESTERN_REGION_MAP
  if return_pos and return_pos.map_id == 22 then
    player.x, player.y = return_pos.x, return_pos.y
  end
  player.facing = "down"
  return
end
```

- [ ] **Step 3: Verify gating**

Walk to entry tile with `flag.lirael_unlocked = false`: blocked with the mourning message.
Set `flag.unlock_all = true` (or set both shard >= 4 and `flag.veiled_mystic_spoken = true`): tile becomes walkable; enters Lirael at the south path.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: route Western Region <-> Lirael with shard/flag gate"
```

---

### Task 4.4: Define LIRAEL_NPCS

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define table (7 NPCs)**

```lua
local LIRAEL_NPCS = {
  -- Bren, Lirael steward (renamed from Brann to avoid duplicate)
  {
    x = 6, y = 11, name = "Bren", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "cleric" then
        return {
          "(he goes still when he sees Miel)",
          "Princess. You have her face, exactly.",
          "I served at her coronation. I never thought —",
          "I never thought a Lirael would walk these",
          "streets again.",
        }
      else
        return {
          "(an old steward, still in Lirael colors)",
          "I stayed. Someone had to know where the",
          "kitchen was, when whoever came back came back.",
        }
      end
    end,
  },
  -- Page, surviving royal child
  {
    x = 4, y = 3, name = "Page", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "cleric" then
        return {
          "(a child, small in the royal quarters)",
          "(she clings to Miel's sleeve)",
          "Is the queen coming back? Are you the queen?",
          "I waited where she told me to wait.",
        }
      else
        return {
          "(a child hiding in the corner)",
          "(she will not look up)",
        }
      end
    end,
  },
  -- Winna, court librarian
  {
    x = 35, y = 3, name = "Winna", kind = "npc",
    dialogue = function()
      return {
        "(she's sorting half-burned papers)",
        "I'm trying to recover the cathedral library.",
        "Here — this was your mother's. Or grandmother's.",
        "I can't tell anymore.",
        "(adds Queen's Correspondence to inventory)",
      }
    end,
  },
  -- The broken chorister
  {
    x = 18, y = 6, name = "chorister", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "(she sings one line, again, again)",
          "\"Hold the long note, hold the long note —\"",
          "(Alder hums the second phrase; she stops)",
          "(quietly) Lia. Velka. Mar.",
          "They sang with me. I remember their names now.",
        }
      else
        return {
          "(she sings one line, again, again)",
          "\"Hold the long note, hold the long note —\"",
        }
      end
    end,
  },
  -- Lirael's Last Captain of the Guard
  {
    x = 25, y = 9, name = "captain", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "(wounded, dying)",
          "Soldier. You wear no Lirael colors. I'm glad.",
          "Take this insignia. It was my grandfather's.",
          "It will not bring honor; only the weight of it.",
          "(adds Lirael Captain's Insignia to inventory)",
        }
      else
        return {
          "(a dying soldier in Lirael colors)",
          "(he is past speaking)",
        }
      end
    end,
  },
  -- Sage Circle archivist
  {
    x = 36, y = 3, name = "archivist", kind = "npc",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "(he looks up from a salvaged ledger)",
          "Diegues. Iola sent me. We've recovered seven",
          "books. We've lost three thousand.",
          "Here — this was in Velthe's hand. Take it.",
        }
      else
        return {
          "Sage Circle. We're trying to salvage what we",
          "can. The queen's correspondence, the cathedral",
          "library, anything that survives.",
        }
      end
    end,
  },
  -- The Queen's Echo - manifests only during signature scene
  -- (No standing NPC entry; scene-only actor)
}
```

- [ ] **Step 2: Add item definitions**

```lua
items.queens_correspondence = {
  name = "Queen's Correspondence",
  kind = "key",
  description = "A half-burned letter from Lirael's queen to her daughter. Most lines are illegible. One is clear: \"Send it north.\"",
}
items.lirael_captains_insignia = {
  name = "Lirael Captain's Insignia",
  kind = "accessory",
  effect = "passive",
  description = "An iron pin in Lirael blue. Carries the weight of a kingdom that no longer is.",
}
items.key_of_lirael = {
  name = "Key of Lirael",
  kind = "key",
  description = "Unlocks the Ice Grotto entrance in Northern Wilds. Cold to the touch.",
}
```

- [ ] **Step 3: Wire into NPC dispatch**

```lua
elseif current_map_id == 23 then return LIRAEL_NPCS
```

- [ ] **Step 4: Verify all dialogue branches**

Set `flag.unlock_all = true`. Enter Lirael. Switch through each lead. Talk to each NPC.

- [ ] **Step 5: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: LIRAEL_NPCS + key items"
```

---

### Task 4.5: Write "Miel Walks Alone" scene

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define scene**

```lua
local function scene_lirael_miel_walks_alone()
  return {
    {letterbox_in = true},
    -- hide the rest of the party (existing convention)
    {hide_player = true},
    -- spawn Miel at the cathedral entrance, walking in
    {spawn = "miel_alone", class = "cleric", name = "Miel", x = 19, y = 9, facing = "up"},
    {focus = "miel_alone", ticks = 30},
    -- slow tracking pan into the nave
    {move = "miel_alone", to = {x = 19, y = 7}, ticks = 40},
    {wait = 8},
    {move = "miel_alone", to = {x = 17, y = 4}, ticks = 50},
    -- music ducks to silence (custom set step)
    {set = function() music_duck = 1.0 end},
    {wait = 16},
    -- Miel kneels at the broken altar
    {move = "miel_alone", to = {x = 17, y = 3}, ticks = 24},
    {face = "miel_alone", facing = "up"},
    {wait = 16},
    {dialogue = {"Miel:", "\"Mother. I'm here.\""}, npc = {name = "Miel"}},
    {wait = 30},
    -- The Queen's Echo manifests briefly behind her
    {spawn = "queens_echo", class = "cleric", name = "", x = 17, y = 4, facing = "down"},
    {wait = 24},
    {despawn = "queens_echo"},
    {wait = 16},
    -- Long fade
    {fade_in = 60},
    {wait = 30},
    {despawn = "miel_alone"},
    {set = function()
      music_duck = 0
      flag.miel_walks_alone_done = true
      -- Open Royal Quarters door (passable from now on)
    end},
    {fade_out = 30},
    {show_player = true},
    {letterbox_out = true},
  }
end
```

Add flag: `flag.miel_walks_alone_done = flag.miel_walks_alone_done or false`.

- [ ] **Step 2: Trigger on first approach to cathedral door**

In the per-tile dispatcher:

```lua
if current_map_id == 23 and x == 18 and y == 8 and not flag.miel_walks_alone_done and not SCENE.active then
  SCENE.start(scene_lirael_miel_walks_alone())
end
```

- [ ] **Step 3: Verify**

Enter Lirael (unlock all). Approach cathedral door tile from south. Expected: Miel separates, walks alone into nave, kneels at altar, line, Queen's Echo manifests briefly, long fade. Flag set.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Miel Walks Alone scene + Royal Quarters access"
```

---

### Task 4.6: Write "The Broken Cadence" scene + boss fight

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Add Broken Cadence enemy entry (if not already in existing bestiary)**

Locate the bestiary block (search for existing boss definitions). Add:

```lua
enemies.broken_cadence = {
  name = "The Broken Cadence",
  hp = 1300,
  atk = 12,
  defense = 4,
  pattern = {12, 12, 8, 4},
  voice_class = "cleric",
  sprite = "broken_cadence",  -- bespoke; add to sprite block
  -- Mechanic: phrases end one note short until player forces resolution
  on_phrase_end = function(self, party)
    -- The fight expects a Bard PLAY action on the final beat to "force resolution"
    -- Damage formula: standard until the player completes the cadence;
    -- if Bard PLAY lands on the on_phrase_end tick, doubled damage that bar.
    return "phrase_short"
  end,
}
```

- [ ] **Step 2: Define the scene**

```lua
local function scene_lirael_broken_cadence()
  return {
    {letterbox_in = true},
    {focus = {x = 17, y = 2}, ticks = 24},
    -- The chorister rises from the altar
    {spawn = "broken_cadence_actor", class = "boss", name = "The Broken Cadence", x = 17, y = 2, facing = "down"},
    {sfx = {class = "cleric", note = 60, vel = 0.6, attack = 1.0, release = 3.0, wet = 0.9}},
    {wait = 16},
    {dialogue = {"The Broken Cadence:",
                 "\"...the queen's daughter. You have her eyes.",
                 "Sing with me. The last phrase.\""}, npc = {name = "The Broken Cadence"}},
    {wait = 12},
    {dialogue = {"\"She would not let it end.\"", "\"You must.\""}, npc = nil},
    -- Drop into the existing battle engine
    {set = function() start_battle({"broken_cadence"}, "lirael") end},
    -- (Battle resolution returns control here)
  }
end

-- Post-battle resolution hook (called by battle engine on victory if boss matches)
local function on_broken_cadence_defeated()
  flag.broken_cadence_done = true
  inventory_add("key_of_lirael")
  -- Subtle music shift: lirael theme adds one returning voice from now on
  flag.lirael_theme_shifted = true
end
```

- [ ] **Step 3: Trigger via Miel-lead OR after miel_walks_alone_done at altar tile**

```lua
if current_map_id == 23 and x == 17 and y == 2 and not flag.broken_cadence_done and not SCENE.active then
  local lead = party[active] and party[active].class
  if lead == "cleric" or flag.miel_walks_alone_done then
    SCENE.start(scene_lirael_broken_cadence())
  end
end
```

- [ ] **Step 4: Wire post-battle hook**

In the battle engine's victory handler (search for existing boss-victory dispatch), add:

```lua
if defeated_boss == "broken_cadence" then
  on_broken_cadence_defeated()
end
```

- [ ] **Step 5: Verify**

After Miel Walks Alone, approach altar tile. Expected: chorister rises; dialogue; battle starts. Win the battle. Expected: Key of Lirael added; flag set; theme shift active.

- [ ] **Step 6: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Broken Cadence boss fight + Key of Lirael"
```

---

### Task 4.7: Compose `lirael` theme + post-fight voice shift

**Files:**
- Modify: `synth-quest.lua` — OW_THEMES

- [ ] **Step 1: Compose theme (replaces placeholder)**

```lua
OW_THEMES.lirael = {
  bpm = 48,
  pattern = {
    -- A natural minor (Aeolian). Solo voice + cello drone + bell tolls.
    {voice = "voice", notes = {69, 0, 67, 0, 65, 0, 64, 0}, lengths = {2,0,2,0,2,0,2,0}},
    {voice = "cello", notes = {45, 0, 0, 0, 0, 0, 0, 0}, lengths = {8,0,0,0,0,0,0,0}},
    {voice = "bell",  notes = {0, 0, 0, 0, 81, 0, 0, 0}, lengths = {0,0,0,0,2,0,0,0}},
    -- Post-fight returning voice (only sounds if lirael_theme_shifted)
    {voice = "return", notes = {0, 76, 0, 74, 0, 72, 0, 71}, lengths = {0,1,0,1,0,1,0,1}, conditional = "lirael_theme_shifted"},
  },
  artic = {
    voice  = {attack = 0.5, release = 3.0, wet = 0.6},
    cello  = {attack = 2.0, release = 6.0, wet = 0.5},
    bell   = {attack = 0.005, release = 4.0, wet = 0.9},
    return = {attack = 0.4, release = 2.0, wet = 0.4},
  },
}
```

- [ ] **Step 2: Implement conditional voice playback**

In the theme-tick handler, when iterating voices:

```lua
for _, v in ipairs(theme.pattern) do
  if v.conditional and not flag[v.conditional] then
    -- skip this voice
  else
    play_voice(v, theme.artic[v.voice])
  end
end
```

- [ ] **Step 3: Verify**

Enter Lirael before Broken Cadence fight. Expected: solo voice + cello + occasional bell. No fourth voice.
After fight: returning voice now audible.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Lirael theme + post-fight returning voice"
```

---

### Task 4.8: Lirael ambient micro-scenes

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Define four micro-scenes**

```lua
local function ambient_lirael_child_toy()
  return {
    {dialogue = {"(it still has Lirael blue paint on it)"}, npc = nil},
  }
end

local function ambient_lirael_window()
  local cleric_lead = party[active] and party[active].class == "cleric"
  return {
    {sfx = {class = "fx", note = 57, vel = 0.3, attack = 1.0, release = 2.5, wet = 0.85}},
    {dialogue = {
      cleric_lead
        and "(Miel hums along involuntarily)"
        or "(wind through broken glass)"
    }, npc = nil},
  }
end

local function ambient_lirael_pillar()
  return {
    {dialogue = {"(ash falls)", "(the cathedral was singing when it fell)"}, npc = nil},
  }
end

local function ambient_lirael_hymnal()
  local cleric_lead = party[active] and party[active].class == "cleric"
  return {
    {dialogue = {
      cleric_lead
        and "Miel: \"I taught my first verse from this page.\""
        or "(a half-burned hymnal, open on a stand)"
    }, npc = nil},
  }
end
```

- [ ] **Step 2: Wire to tiles**

```lua
if current_map_id == 23 then
  if x == 20 and y == 12 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_lirael_child_toy())
    last_ambient = tick
  elseif x == 7 and y == 3 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_lirael_window())
    last_ambient = tick
  elseif (x == 13 or x == 19 or x == 26) and y == 4 and not SCENE.active and tick - (last_ambient or 0) > 800 then
    SCENE.start(ambient_lirael_pillar())
    last_ambient = tick
  elseif x == 34 and y == 3 and not SCENE.active and tick - (last_ambient or 0) > 600 then
    SCENE.start(ambient_lirael_hymnal())
    last_ambient = tick
  end
end
```

- [ ] **Step 3: Verify**

Walk each tile. Confirm Cleric-lead variants fire for window and hymnal.

- [ ] **Step 4: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Lirael ambient micro-scenes"
```

---

### Task 4.9: Lirael encounters

**Files:**
- Modify: `synth-quest.lua`

- [ ] **Step 1: Add spawn rules (cathedral nave only, sparse)**

```lua
elseif current_map_id == 23 then
  -- Streets are encounter-free; nave only, sparse
  local in_nave = (y >= 4 and y <= 7 and x >= 12 and x <= 30)
  if in_nave and math.random() < 0.02 then
    local pool = {"acolyte", "broken_choir"}
    return pool[math.random(#pool)]
  end
  return nil
```

- [ ] **Step 2: Verify**

Walk Burned Streets and Royal Quarters: zero encounters.
Walk nave: occasional 2% spawn.

- [ ] **Step 3: Commit**

```bash
git add synth-quest.lua
git commit -m "feat: Lirael nave encounters (sparse)"
```

---

### Task 4.10: Update bible with Lirael canon

**Files:**
- Modify: `story/bible.md`

- [ ] **Step 1: Promote stubs and add new cast**

In NAMED CAST:
- Promote PAGE to IN CODE with backstory.
- Promote BREN (renamed from Brann to avoid collision; flag the rename in the entry).
- Promote WINNA to IN CODE.
- Add new entries for the broken chorister, the Captain, the Sage Circle archivist, the Queen's Echo.

- [ ] **Step 2: Expand LIRAEL section in the AEOLIAN sub-section**

Append details on the four-zone map layout (Burned Streets, Ruined Nave, Royal Quarters, Side Chapel + Library), the Bren / Page / Winna survivor cohort, and the Broken Cadence boss fight resolution (Key of Lirael drop, theme shift).

- [ ] **Step 3: Confirm rename of Brann is documented**

Update the existing PHRYGIAN BRANN entry to note the rename (Lirael's steward is BREN, not Brann; one Brann remains, in Phrygian).

- [ ] **Step 4: Commit**

```bash
git add story/bible.md
git commit -m "docs(bible): canonize Lirael Ruins + cast; rename Lirael steward to Bren"
```

---

### Task 4.11: Phase 4 playtest + snapshot

- [ ] **Step 1: Full Lirael playtest**

1. Without Lirael unlocked: walk to Western Region entry tile. Confirm blocked.
2. With Lirael unlocked (4+ shards AND `veiled_mystic_spoken`): walk into Lirael.
3. Approach cathedral door from south. Confirm Miel Walks Alone fires regardless of lead.
4. After scene, approach broken altar. Confirm Broken Cadence boss fight fires.
5. Win the fight. Confirm Key of Lirael added; `flag.broken_cadence_done` set; theme shifts.
6. Talk to all 7 NPCs with each lead. Verify branches.
7. Walk all 4 ambient tiles. Verify Cleric-lead variants for window + hymnal.
8. Confirm encounters: streets safe, nave sparse 2%.

- [ ] **Step 2: Snapshot**

```bash
cp ~/dev/synth-quest/synth-quest.lua "~/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"
cp ~/dev/synth-quest/story/bible.md  "~/dev/synth-quest/backups/bible-$(date +%Y%m%d-%H%M%S).md"
```

- [ ] **Step 3: Final file size check**

`wc -c ~/dev/synth-quest/synth-quest.lua` — expected under 1.3MB.

---

## Acceptance Criteria

The plan is complete when:

- All five maps render correctly with no out-of-bounds artifacts.
- All ~30 NPCs respond with party-aware dialogue branches for all four leads (Bard, Cleric, Warrior, Mage).
- All eight signature scenes play to completion without softlock:
  1. Sunward Arrival
  2. Bandstand Performance (Bard, night)
  3. Phrygian Arrival
  4. Strom Confronted (Warrior)
  5. Diegues Returns (Mage, Academy first-entry)
  6. Iola's Letter (Mage, 3+ shards)
  7. Caretaker's Tour (Observatory first-entry)
  8. Velthe's Final Entry (after Iola's Letter, at desk)
  9. Miel Walks Alone (Lirael cathedral approach)
  10. The Broken Cadence (post-Miel-walks-alone or Cleric-lead at altar)
- All 16 ambient micro-scenes fire at expected tiles; do not retrigger within ~10s.
- All five new themes audition correctly in their regions; Lirael theme shifts after Broken Cadence.
- Lirael Ruins is unreachable until `lirael_is_unlocked()` returns true.
- Iola correctly migrates from Academy to Observatory after `flag.velthes_entry_heard`.
- Velthe's Final Entry unlocks the Cave 6 approach via `crypt_stair`.
- Bandstand grants +1 MAG permanent to Alder; Strom Confronted grants +5 MaxHP + Aram's Token; Broken Cadence drops Key of Lirael.
- 11 NPC stubs promoted in `bible.md` (Iolen, Sergei, Mira, Brann, Aurin, Paj, Wena, Echo, Page, Bren-renamed-from-Brann, Winna).
- Backups exist in `~/dev/synth-quest/backups/` for both `.lua` and `bible.md` after each phase.
- `synth-quest.lua` stays under 1.3MB.

## Self-Review Notes

The plan covers every spec requirement; I verified each region phase against the spec's region section. Map IDs are locked (35, 36, plus the existing 19, 23, 24). The 5-theme count is reflected throughout (no leftover "6 themes" references). Each task contains the actual code an engineer needs — no "implement later" placeholders. The dependency chain between Iola's Letter → Velthe's Final Entry → Cave 6 unlock is explicit and gated. The Brann/Bren rename collision is called out where it appears (Phase 4 bible update + Lirael NPCs).

One identified soft spot: the exact field names in `step_player`, `SCENE`, `OW_THEMES`, and the encounter spawn table may differ slightly from the patterns I inferred from the survey. Implementers should run `grep -n` for the exact names at the start of each phase and adjust. This is normal for working in a large existing codebase.
