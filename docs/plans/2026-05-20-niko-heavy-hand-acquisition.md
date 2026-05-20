# Niko / The Heavy Hand Acquisition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Niko's Heavy Hand acquisition path per `docs/specs/2026-05-20-niko-heavy-hand-acquisition-design.md`: a new Ruined Drum-Hall map (37) off Phrygian Night City (36) where Niko finds the iron hand-guard on a plinth and attunes by striking the great war-drum.

**Architecture:** All in `synth-quest.lua`. New interior map 37 (`CONTENT.drumhall_map` + empty npcs), registered in the map-load dispatch; a bidirectional transition tile (92) linking Phrygian map 36 ↔ map 37, gated on `recruits[3].joined`; two new impassable tiles (90 plinth, 91 war-drum) with draw routines + `try_move` interaction handlers; `RESONANCE_SITES.heavy_hand` populated; a new signature scene draw. Combat effect is out of scope (parallel resonance-effects spec owns it).

**Tech Stack:** norns Lua 5.4. Manual playtest on device. No new SynthDef (signature reuses the warrior voice). No SC change → **no SYSTEM > RESTART needed** for this pass.

**Spec:** `docs/specs/2026-05-20-niko-heavy-hand-acquisition-design.md`

**Resolved IDs:** map = 37; tiles = 90 (plinth), 91 (war-drum), 92 (drumhall-door). Phrygian = map 36. Niko = `recruits[3]`, drummer class.

---

## Map 37 layout (canonical — coords referenced by later tasks)

14 wide × 9 tall. `4`=wall, `0`=floor, `81`=rubble (existing decor tile), `90`=plinth, `91`=war-drum, `92`=drumhall-door.

```
row 1:  {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4}
row 2:  {4, 0, 0, 0, 0, 0,91, 0, 0, 0, 0, 0, 0, 4}   -- war-drum at (7,2)
row 3:  {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4}
row 4:  {4, 0, 0,90, 0, 0, 0, 0, 0, 0,81, 0, 0, 4}   -- plinth at (4,4), rubble at (11,4)
row 5:  {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4}
row 6:  {4,81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,81, 4}   -- rubble decor
row 7:  {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4}
row 8:  {4, 4, 4, 4, 4, 4,92, 4, 4, 4, 4, 4, 4, 4}   -- south wall + drumhall-door at (7,8)
row 9:  {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4}
```

- **War-drum** shrine tile: **(7, 2)** → `RESONANCE_SITES.heavy_hand.shrine.{x=7,y=2}`.
- **Plinth** item tile: **(4, 4)**.
- **Door** (37 side): **(7, 8)**. Player entering from Phrygian spawns at **(7, 7)** (one tile north of the door, inside the hall). Player leaving steps onto (7,8) → back to Phrygian.

---

### Task 1: Pre-flight backup

- [ ] **Step 1: Snapshot**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-pre-heavyhand.lua`
Expected: file exists.

- [ ] **Step 2: Confirm + confirm tile ids free**

Run: `ls -la ~/dev/synth-quest/backups/synth-quest-pre-heavyhand.lua && grep -cE "TILE_DRAW\[90\]|TILE_DRAW\[91\]|TILE_DRAW\[92\]|t == 90|t == 91|t == 92" ~/dev/synth-quest/synth-quest.lua`
Expected: backup exists; the grep count is `0` (tiles 90/91/92 are unused). If non-zero, STOP — pick the next free ids and adjust all references in this plan.

---

### Task 2: Define the drum-hall map (37)

**Files:**
- Modify: `synth-quest.lua` — add `CONTENT.drumhall_map` + `CONTENT.drumhall_npcs` near the other interior map defs.

- [ ] **Step 1: Find a sibling interior-map definition**

Run: `grep -n "quarters_map = \|study_map = \|CONTENT.phrygian_city_npcs = " ~/dev/synth-quest/synth-quest.lua | head`
Expected: locations of existing interior maps. Insert the drum-hall near one of them (e.g., after `quarters_map`/`study_map`, or near the Phrygian content). Read ~5 lines around the chosen anchor to get exact surrounding text.

- [ ] **Step 2: Add the map + empty npcs**

Use the Edit tool. Insert (choosing a clean anchor from Step 1 — the example below assumes inserting after the `study_npcs = {...},` block; adapt the `old_string` to the real file):

```lua
  -- Map 37 — Ruined Drum-Hall (off Phrygian Night City, map 36). The
  -- legendary Heavy Hand drummer's hall. His iron hand-guard rests on a
  -- plinth (tile 90); the great war-drum (tile 91) is the Resonance
  -- shrine. Empty of NPCs. Reached via the drumhall-door (tile 92).
  drumhall_map = {
    {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4},
    {4, 0, 0, 0, 0, 0,91, 0, 0, 0, 0, 0, 0, 4},
    {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4},
    {4, 0, 0,90, 0, 0, 0, 0, 0, 0,81, 0, 0, 4},
    {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4},
    {4,81, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,81, 4},
    {4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4},
    {4, 4, 4, 4, 4, 4,92, 4, 4, 4, 4, 4, 4, 4},
    {4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4},
  },
  drumhall_npcs = {},
```

(If the interior maps are assigned as `CONTENT.x = {...}` statements rather than inside the `CONTENT = {...}` literal, match that form — e.g. `CONTENT.drumhall_map = {...}` / `CONTENT.drumhall_npcs = {}`. The Phrygian npcs at `CONTENT.phrygian_city_npcs = {` (~line 12927) suggest the post-literal assignment form is used for newer content; follow whichever the neighbors use.)

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 3: Register map 37 in the map-load dispatch

**Files:**
- Modify: `synth-quest.lua` — map-load dispatch (the `elseif map_id == N then map = ...; npcs = ...` chain).

- [ ] **Step 1: Find the map-36 dispatch branch**

Run: `grep -n "elseif map_id == 36 then" ~/dev/synth-quest/synth-quest.lua`
Expected: one line (~17194). Read the 3 lines after it to see the exact format.

- [ ] **Step 2: Add the map-37 branch**

Use the Edit tool. `old_string` (confirm exact text via Step 1):

```lua
  elseif map_id == 36 then
    map = CONTENT.phrygian_city_map; npcs = CONTENT.phrygian_city_npcs
```

`new_string`:

```lua
  elseif map_id == 36 then
    map = CONTENT.phrygian_city_map; npcs = CONTENT.phrygian_city_npcs
  elseif map_id == 37 then
    map = CONTENT.drumhall_map; npcs = CONTENT.drumhall_npcs
```

(Match the real variable names from Step 1 — `phrygian_city_map` may differ.)

- [ ] **Step 3: Add map 37 to the "interior, no day/night" + music-region checks if present**

Run: `grep -n "current_map_id == 36" ~/dev/synth-quest/synth-quest.lua`
Expected: several matches (music region label ~13885, interior checks ~13956, ambient ~15285, etc.). For each that lists interior map ids (e.g. region-music selection, "is interior" guards), add `or current_map_id == 37` so the drum-hall gets sensible music + behaves as an interior. At minimum: the music-region function (so it plays the phrygian theme — `grep -n 'return "phrygian_city"'`) should treat 37 like 36. Read each match and extend the ones that are interior/region gates; skip ones that are clearly map-36-specific content.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 4: Tile draw routines (90 plinth, 91 war-drum, 92 door)

**Files:**
- Modify: `synth-quest.lua` — `TILE_DRAW` block (starts ~line 19608).

- [ ] **Step 1: Read a sibling tile-draw for the pattern**

Run: `sed -n '19662,19700p' ~/dev/synth-quest/synth-quest.lua`
Expected: examples like `TILE_DRAW[21]` (bed), `TILE_DRAW[22]` (counter) — each `TILE_DRAW[N] = function(px, py) ... screen.* ... end`. Note `px,py` are screen pixel coords of the tile's top-left; tiles are 8×8.

- [ ] **Step 2: Add the three tile draws**

Use the Edit tool. Insert after an existing `TILE_DRAW[NN] = function...end` block (e.g. after `TILE_DRAW[24]`). Add:

```lua
TILE_DRAW[90] = function(px, py)
  -- Plinth holding the iron hand-guard. Low stone block + metallic glint
  -- on top (the guard). Once collected, CONTENT.resonances.heavy_hand.item
  -- is true and the glint is dropped.
  screen.level(4); screen.rect(px + 1, py + 4, 6, 4); screen.fill()   -- stone block
  screen.level(2); screen.rect(px + 1, py + 7, 6, 1); screen.fill()   -- base shadow
  if not (CONTENT.resonances and CONTENT.resonances.heavy_hand and CONTENT.resonances.heavy_hand.item) then
    screen.level(13); screen.rect(px + 2, py + 2, 4, 2); screen.fill()  -- iron guard
    screen.level(15); screen.pixel(px + 3, py + 2); screen.fill()       -- glint
  end
end

TILE_DRAW[91] = function(px, py)
  -- Great war-drum: tall barrel + taut skin + iron rim.
  screen.level(5); screen.rect(px + 1, py, 6, 8); screen.fill()       -- barrel body
  screen.level(8); screen.rect(px + 1, py + 1, 6, 5); screen.fill()   -- skin
  screen.level(3); screen.rect(px + 1, py, 6, 1); screen.fill()       -- top rim
  screen.level(3); screen.rect(px + 1, py + 6, 6, 1); screen.fill()   -- bottom rim
  screen.level(11); screen.pixel(px + 3, py + 3); screen.pixel(px + 4, py + 3); screen.fill()  -- center boss
end

TILE_DRAW[92] = function(px, py)
  -- Drumhall door: dark archway in the wall.
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(0); screen.rect(px + 2, py + 1, 4, 7); screen.fill()   -- opening
  screen.level(5); screen.rect(px + 1, py, 6, 1); screen.fill()       -- lintel
end
```

- [ ] **Step 3: Register tiles 90/91/92 in the draw-dispatch list (if one gates which tiles call their TILE_DRAW fn)**

Run: `grep -n "t == 73 then fn(sx, sy" ~/dev/synth-quest/synth-quest.lua`
Expected: a long `if t == 3 or t == 6 or ... or t == 84 then fn(sx, sy, tick)` line (the animated/custom-draw allowlist). Add `or t == 90 or t == 91 or t == 92` to it so the new tiles invoke their `TILE_DRAW` functions. (If tiles render via a different dispatch — e.g. `TILE_DRAW[t]` looked up unconditionally — this step may be unnecessary; confirm by reading how `TILE_DRAW[t]` is invoked in the map render loop.)

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 5: Walkability + transition tile (92) routing

**Files:**
- Modify: `synth-quest.lua` — `is_walkable` (so tile 92 is walkable; 90/91 stay impassable) and `try_move` (route 92 by current_map_id).

- [ ] **Step 1: Make tile 92 walkable**

Run: `grep -n "function is_walkable" ~/dev/synth-quest/synth-quest.lua` and read the function. It returns true for a set of tile ids (doors/floors). Add `or t == 92` so the drumhall-door is walkable. Tiles 90 and 91 are NOT added (they stay impassable — their `try_move` handlers `return` without moving).

Use the Edit tool to append `or t == 92   -- drumhall door (Phrygian 36 <-> drum-hall 37)` to the `is_walkable` return expression, matching its existing multi-line `or` style.

- [ ] **Step 2: Add tile-92 routing in try_move**

Run: `grep -n "if t == 71\|if t == 69\|if t == 58 then" ~/dev/synth-quest/synth-quest.lua | head`
Expected: existing transition-tile handlers. Read one (e.g. the tile-58 castle-door handler that routes by `current_map_id`) for the pattern.

Add a new handler for tile 92 (place it near the other transition handlers in `try_move`):

```lua
  if t == 92 then
    -- Drumhall door. Bidirectional: Phrygian (36) <-> Ruined Drum-Hall (37).
    if current_map_id == 36 then
      travel_to(37, 7, 7)   -- enter: spawn inside the hall, north of the door
    elseif current_map_id == 37 then
      travel_to(36, ENTRANCE_X_ON_36, ENTRANCE_Y_ON_36)   -- leave: back to Phrygian
    end
    redraw()
    return
  end
```

`ENTRANCE_X_ON_36` / `ENTRANCE_Y_ON_36` are resolved in Task 6 (where the entrance tile is placed on map 36). Until then, leave a clear marker; Task 6 fills the real coords.

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK` (the marker constants will be replaced in Task 6; if you must syntax-check before Task 6, temporarily use literal numbers).

---

### Task 6: Place the entrance on Phrygian map 36 (gated on Niko)

**Files:**
- Modify: `synth-quest.lua` — the Phrygian Night City map layout + `try_move` gating.

- [ ] **Step 1: Read the Phrygian map layout**

Run: `grep -n "phrygian_city_map" ~/dev/synth-quest/synth-quest.lua` then read the map grid. Identify a sensible edge floor tile to convert into the drumhall-door (tile 92) — a spot on the city's edge that reads as "a collapsed archway." Note its (x, y).

- [ ] **Step 2: Place the door tile on map 36**

Use the Edit tool to change the chosen floor tile in the Phrygian map grid to `92`. Record its (x, y) — these are the `ENTRANCE_X_ON_36` / `ENTRANCE_Y_ON_36` values. Update the Task-5 tile-92 handler's `travel_to(36, ...)` with the tile position **one step back from the door** (so leaving the hall doesn't immediately re-enter), e.g. if the door is at (dx, dy) on the south edge, return to (dx, dy-1).

- [ ] **Step 3: Gate the entrance on Niko having joined**

In the tile-92 handler (Task 5), wrap the `current_map_id == 36` (entering) branch:

```lua
    if current_map_id == 36 then
      if not (CONTENT.recruits[3] and CONTENT.recruits[3].joined) then
        CONTENT.banner_text  = "* the archway is choked with rubble *"
        CONTENT.banner_ticks = 48
        redraw()
        return
      end
      travel_to(37, 7, 7)
```

So before Niko joins, the archway is blocked; after, it opens.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 7: Plinth interaction (tile 90 — hand-guard pickup)

**Files:**
- Modify: `synth-quest.lua` — `try_move`, new tile-90 handler.

- [ ] **Step 1: Add the tile-90 handler**

Place near the other map-37 / shrine handlers in `try_move`. Use the Edit tool:

```lua
  if t == 90 then
    -- Plinth holding the Heavy Hand drummer's iron hand-guard. First time
    -- with Niko (drummer) as lead, grant the guard. Impassable otherwise.
    local p = party[active]
    if current_map_id == 37 and p and p.class == "drummer"
       and not CONTENT.resonances.heavy_hand.item then
      CONTENT.resonances.heavy_hand.item = true
      CONTENT.banner_text  = "* obtained: the Iron Hand-Guard *"
      CONTENT.banner_ticks = 60
      dlg.lines = pack_dialogue_lines({
        "(Niko lifts the iron guard off the plinth. Heavier than it looks.)",
        "[Niko]    He wore this until his hands quit. Then he kept going.",
        "(she fits it over her own knuckles. It settles like it was waiting.)",
      }, nil)
      dlg.line = 1; dlg.npc = nil
      game_state = "DIALOGUE"
      redraw()
      return
    end
    return   -- impassable; non-Niko leads + post-pickup just don't move
  end
```

(Confirm `pack_dialogue_lines` + the `dlg` / `game_state = "DIALOGUE"` pattern by reading an existing tile-triggered dialogue — `grep -n "game_state = \"DIALOGUE\"" synth-quest.lua | head`. Match the real fields.)

- [ ] **Step 2: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 8: War-drum shrine intercept (tile 91)

**Files:**
- Modify: `synth-quest.lua` — `try_move`, new tile-91 handler. Mirrors the tile-73 astrolabe + tile-48 tapestry intercepts.

- [ ] **Step 1: Add the tile-91 handler**

Use the Edit tool, placing it near the tile-90 handler:

```lua
  if t == 91 then
    -- Great war-drum (Heavy Hand shrine). Niko + hand-guard held + not yet
    -- attuned -> fire the attunement. Impassable otherwise.
    local p = party[active]
    if current_map_id == 37
       and p and p.class == "drummer"
       and CONTENT.resonances.heavy_hand.item
       and not CONTENT.resonances.heavy_hand.attuned
       and start_resonance_attunement then
      start_resonance_attunement("heavy_hand")
      redraw()
      return
    end
    return
  end
```

- [ ] **Step 2: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 9: Populate RESONANCE_SITES.heavy_hand

**Files:**
- Modify: `synth-quest.lua:~245` (`RESONANCE_SITES.heavy_hand` stub).

- [ ] **Step 1: Replace the stub**

Run: `grep -n "heavy_hand   = { item = nil, shrine = nil }" ~/dev/synth-quest/synth-quest.lua` to confirm the current line.

Use the Edit tool. `old_string`:

```lua
  heavy_hand   = { item = nil, shrine = nil },
```

`new_string`:

```lua
  heavy_hand   = {
    item = {
      kind  = "tile",
      label = "Iron Hand-Guard",
      hint  = "strike the great war-drum",
    },
    shrine = {
      map  = 37,
      x    = 7, y = 2,
      lead = "drummer",
      signature = {
        visual = "phrygian_drumhall_resonant",
        sound  = { class = "warrior", note = 31, vel = 0.95, attack = 0.001, release = 1.4, wet = 0.5 },
        dialogue = {
          "(Niko sets the iron guard against the great drum's skin and waits for the room to go quiet.)",
          "[Niko]    He hit so hard the others stopped playing. They called it rude. He called it the one.",
          "(she strikes once. The drum answers from somewhere under the floor, and the dust jumps.)",
        },
      },
    },
  },
```

- [ ] **Step 2: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 10: Signature scene draw (`phrygian_drumhall_resonant`)

**Files:**
- Modify: `synth-quest.lua` — scene-draw block + `SCENE_DRAW` table.

- [ ] **Step 1: Find the signature-scene anchor**

Run: `grep -n "function draw_scene_academy_astrolabe_resonant\|academy_astrolabe_resonant =" ~/dev/synth-quest/synth-quest.lua`
Expected: the ECHO signature draw (added in a prior pass) + its SCENE_DRAW registration. Read the function for the ring-expansion + shake idiom.

- [ ] **Step 2: Add the draw function**

Use the Edit tool. Insert immediately before the `SCENE_DRAW = {` table (after the last `draw_scene_*` function):

```lua
function draw_scene_phrygian_drumhall_resonant()
  -- The great war-drum centered; on the strike beat, concentric shockwave
  -- rings punch outward and the floor jumps (handled by ANIM.shake at the
  -- scene's sfx beat). Sand-stone Phrygian palette. Niko stands beside it.
  screen.level(1); screen.rect(0, 0, 128, 64); screen.fill()
  -- sand-stone floor stripes
  screen.level(3)
  for y = 40, 60, 4 do screen.move(0, y); screen.line(128, y); screen.stroke() end
  -- the war-drum: large barrel + skin + rim
  screen.level(5); screen.rect(54, 16, 20, 32); screen.fill()
  screen.level(8); screen.rect(56, 18, 16, 24); screen.fill()
  screen.level(3); screen.rect(54, 16, 20, 2); screen.fill()
  screen.level(3); screen.rect(54, 46, 20, 2); screen.fill()
  -- center boss
  screen.level(11); screen.rect(62, 30, 4, 4); screen.fill()
  -- expanding shockwave rings from the drum center
  for k = 0, 2 do
    local r = ((tick + k * 7) % 22) + 4
    if r < 20 then
      screen.level(math.max(2, 10 - k * 2)); screen.circle(64, 32, r + 8); screen.stroke()
    end
  end
  -- Niko silhouette to the left, solid
  screen.level(11); screen.rect(40, 30, 4, 4); screen.fill()  -- head
  screen.level(11); screen.rect(39, 34, 6, 8); screen.fill()  -- body
end
```

- [ ] **Step 3: Register in SCENE_DRAW**

Run: `grep -n "academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant" ~/dev/synth-quest/synth-quest.lua`
Use the Edit tool. `old_string`:

```lua
  academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant,
```

`new_string`:

```lua
  academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant,
  phrygian_drumhall_resonant = draw_scene_phrygian_drumhall_resonant,
```

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 11: Bible lore-sync

**Files:**
- Modify: `story/bible.md` — flesh out the NIKO stub + canonize the Ruined Drum-Hall.

- [ ] **Step 1: Find the NIKO stub**

Run: `grep -n "NIKO (location TBD)" ~/dev/synth-quest/story/bible.md`
Expected: one line (~1417).

- [ ] **Step 2: Replace the stub**

Use the Edit tool. `old_string`:

```
   NIKO (location TBD)
      Role: STUB.
```

`new_string`:

```
   NIKO (drummer; recruit slot 3)
      Role: Ex-Suno house-band drummer (3 years) who quit "when
      they took the snare apart." Joins the party late-game; bonds
      with Strom (both percussionists). Carries THE HEAVY HAND
      Resonance, attuned at the Ruined Drum-Hall (see below) by
      taking up the legendary drummer's iron hand-guard and
      striking the great war-drum.
      STATUS: IN CODE.

   THE RUINED DRUM-HALL (off Phrygian Night City, map 37)
      A collapsed hall on the city's edge where a legendary
      Phrygian war-drummer — the Heavy Hand, "whose strikes were
      so heavy that every other voice ducked out of his way" —
      played until his hands broke. His iron hand-guard rests on a
      plinth; his great war-drum stands at the back wall. Niko
      acquires THE HEAVY HAND here. Empty of NPCs; the war-drum
      carries the weight. Entrance is rubble-blocked until Niko
      joins.
      STATUS: IN CODE.
```

(If the bible's NIKO stub text differs, adapt the `old_string`.)

---

### Task 12: Deploy + on-device playthrough

**Files:** none.

- [ ] **Step 1: Confirm norns IP + deploy**

Run: `ping -c 2 -W 2000 norns.local 2>&1 | tail -3`
Then: `rsync -avz -e "ssh -i ~/.ssh/norns" ~/dev/synth-quest/synth-quest.lua we@norns.local:/home/we/dust/code/synth-quest/synth-quest.lua`
Expected: transfers cleanly. **No SYSTEM > RESTART needed** (no SC change this pass).

- [ ] **Step 2: Tell the user to reload + test**

Tell the user: "Reload Synth Quest (SELECT > synth-quest > load). Load a save with Niko joined. Go to Phrygian Night City — the drumhall archway should be open (rubble-blocked if Niko hasn't joined). Enter the Ruined Drum-Hall. Walk Niko (drummer lead) to the plinth → get the Iron Hand-Guard. Then walk her into the great war-drum → the Heavy Hand attunement fires. Then in a battle, R2 with Niko should play the Heavy Hand signature + animation."

Wait for the playthrough.

---

### Task 13: Manual verification (9 acceptance criteria)

Walk the spec's 9 ACs with the user.

- [ ] **AC1:** Entrance gated — open when Niko joined, "* the archway is choked with rubble *" banner before.
- [ ] **AC2:** Map 37 renders (war-drum, plinth+guard, rubble, sand-stone, no NPCs); exit back to map 36 works.
- [ ] **AC3:** Niko (drummer lead) into plinth → "* obtained: the Iron Hand-Guard *"; `heavy_hand.item == true`; guard glint disappears from the plinth.
- [ ] **AC4:** Plinth with non-drummer lead or after pickup → no re-grant.
- [ ] **AC5:** Niko into war-drum with guard → attunement scene (warrior-voice thud + rings + 3 lines + banner "* Resonance learned -- The Heavy Hand *"); `heavy_hand.attuned == true`.
- [ ] **AC6:** War-drum without guard / wrong lead → impassable, no scene.
- [ ] **AC7:** Post-attune, R2 with Niko fires the Heavy Hand signature + animation + cooldown (generic fluid RESO branch). (Effect itself is the parallel spec.)
- [ ] **AC8:** Save/reload — `heavy_hand.item` + `.attuned` round-trip; drum-hall still reachable.
- [ ] **AC9:** Legacy save — defaults apply, no crash.

If any fail, return to the relevant task. ACs 1, 2, 3, 5, 8 are the critical path.

---

### Task 14: Snapshot + DEVLOG + commit

- [ ] **Step 1: Snapshot**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-heavyhand.lua`

- [ ] **Step 2: DEVLOG entry**

Append to `~/dev/synth-quest/DEVLOG.md` (match existing format, date 2026-05-20):

```
## 2026-05-20 — Niko / The Heavy Hand acquisition (Ruined Drum-Hall)

New map 37 (Ruined Drum-Hall) off Phrygian Night City. Niko takes
the legendary drummer's iron hand-guard from a plinth (tile 90),
then strikes the great war-drum (tile 91) to attune The Heavy
Hand. New transition tile (92) gated on recruits[3].joined.
Two-step find->attune via the existing start_resonance_attunement
scaffold; new "tile" item kind; signature warrior-voice thud +
shockwave-ring scene draw. Bible NIKO stub + drum-hall canonized.

Acquisition only — the Heavy Hand combat effect (duck_enemies) is
the parallel resonance-effects pass's job.
```

- [ ] **Step 3: Stage + commit**

Run:
```bash
cd ~/dev/synth-quest && git add synth-quest.lua story/bible.md DEVLOG.md docs/plans/2026-05-20-niko-heavy-hand-acquisition.md && git status --short
```
Expected: only those files staged (leave the parallel resonance-effects docs + artifacts untouched; if synth-quest.lua carries other sessions' uncommitted edits, note it in the commit body).

Run:
```bash
cd ~/dev/synth-quest && git commit -m "$(cat <<'EOF'
niko: Heavy Hand acquisition — Ruined Drum-Hall (map 37)

New single-screen interior off Phrygian Night City. Niko takes the
legendary drummer's iron hand-guard from a plinth (tile 90), then
strikes the great war-drum (tile 91) to attune The Heavy Hand via
the existing start_resonance_attunement scaffold.

- map 37 (drumhall_map) + dispatch + phrygian-theme music region
- transition tile 92 (Phrygian 36 <-> drum-hall 37), gated on
  recruits[3].joined
- tiles 90 (plinth) + 91 (war-drum) draws + try_move handlers
- RESONANCE_SITES.heavy_hand populated (signature = warrior thud +
  drumhall-resonant scene draw)
- bible: NIKO stub + Ruined Drum-Hall canonized

Acquisition only; the duck_enemies combat effect is the parallel
resonance-effects spec's job.

Spec: docs/specs/2026-05-20-niko-heavy-hand-acquisition-design.md
Plan: docs/plans/2026-05-20-niko-heavy-hand-acquisition.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds.

---

## Self-review notes

**Spec coverage:**
- New map 37 → Tasks 2, 3
- Entrance from Phrygian + gating → Tasks 5, 6
- Two new tile types (plinth/war-drum) + door → Tasks 4, 5
- Acquisition flow (find → attune) → Tasks 7 (plinth), 8 (war-drum)
- RESONANCE_SITES.heavy_hand → Task 9
- Signature scene draw → Task 10
- Bible lore-sync → Task 11
- All 9 ACs → Task 13

**Placeholder scan:** The map-36 entrance coords (`ENTRANCE_X_ON_36`) are intentionally resolved in Task 6 after reading the parallel-built Phrygian layout — a discover-then-fill pattern, flagged explicitly. Tile ids 90/91/92 confirmed-free in Task 1 Step 2. No "TBD"/vague-handling.

**Type/name consistency:** tile ids 90/91/92, map 37, `CONTENT.resonances.heavy_hand.{item,attuned}`, `recruits[3]`, class `"drummer"`, shrine coords (7,2), and `RESONANCE_SITES.heavy_hand` are consistent across Tasks 2-11. The signature `visual = "phrygian_drumhall_resonant"` (Task 9) matches the registered scene key (Task 10).

**TDD note:** no test framework; per-task `lua5.4 loadfile` smoke checks + the Task-13 manual playthrough. No SC change → no engine restart this pass (unlike the ECHO pass).

**Parallel-churn note:** every task re-greps its anchor before editing. The Phrygian map (built by a parallel session) MUST be read fresh in Task 6 before placing the entrance.
