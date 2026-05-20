# ECHO Eighth Party Member Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship ECHO as the 8th party member per `docs/specs/2026-05-19-echo-eighth-party-member-design.md`. New class `wraith` (new SynthDef + sprite + STIR action + DISPERSE limit break), new recruit slot, recruitment scene at the Academy astrolabe (gated on `CONTENT.act3_silence`), Long Echo Resonance fully wired (auto-granted item + shrine at astrolabe). Combat effect for Long Echo stubbed (consume hook in follow-on spec).

**Architecture:** Touches `lib/Engine_SynthQuest.sc` (new SynthDef + engine commands) and `synth-quest.lua` in ~14 distinct regions. New class joins the existing per-class scaffolding (CLASS_ACTIONS / CLASS_INSTRUMENT / CLASS_GROWTH / CUTOFF_RANGE / SPRITE_BY_CLASS). New recruit at index 4 in `CONTENT.recruits`. Save/load extends to cover the 4th recruit. Recruitment scene reuses the existing SCENE engine pattern (mirrors `start_courtyard_breach_script`).

**Tech Stack:** SuperCollider (norns engine), Lua 5.4 (norns matron). Manual playtest on device — no unit-test framework. After Task 2 (SC change), the norns requires SYSTEM > RESTART.

**Spec:** `docs/specs/2026-05-19-echo-eighth-party-member-design.md`

**Resolved spec placeholders:**
- `<academy_courtyard_map_id>` → `19`
- `<astrolabe_x>` → `13`
- `<astrolabe_y>` → `6`

---

## File Structure

| Change | Location | Note |
|---|---|---|
| Add `sq_wraith` SynthDef | `lib/Engine_SynthQuest.sc` | NEW — granular stutter via CombC, high-register |
| Export engine commands | `lib/Engine_SynthQuest.sc` | NEW — `wraith_cutoff` / `_res` / `_dly` / `_dly_time` / `_xwet` / `_damp` / `_room` |
| Init engine params | `synth-quest.lua` `init()` (~line 17000) | Add `wraith_*` setter calls alongside existing class param setup |
| Add `wraith` to CUTOFF_RANGE | `synth-quest.lua:~126` | New row: `wraith = { min = 1600, max = 6000 }` |
| Add `wraith` to CLASS_ACTIONS | `synth-quest.lua:~162` | `{A="ATK", B="DEF", X="STIR", Y="ITM"}` |
| Add `wraith` to CLASS_INSTRUMENT | `synth-quest.lua:~173` | `wraith = "STIR"` |
| Update `RESONANCES.long_echo` | `synth-quest.lua:~181` | `character = "wraith"`, fill effect/mythos |
| Update `RESONANCE_SITES.long_echo` | `synth-quest.lua:~208` | Replace stub with full entry |
| Add `wraith` to CLASS_GROWTH | `synth-quest.lua:~806` | `wraith = {hp=3, mp=4, atk=0, def=1, mag=2, spd_every=8}` |
| Add 4th recruit slot | `synth-quest.lua:~2748` (`CONTENT.recruits`) | wraith with stats |
| Existing Echo NPC visibility | `synth-quest.lua:3024-3042` (`academy_npcs`) | Add `visible` function with hide-after-recruit clause |
| `start_echo_recruit_scene` | `synth-quest.lua:~6326` (alongside other scene helpers) | NEW function |
| Recruitment trigger hook | `synth-quest.lua:~16596` (post-`travel_to` block) | Fire scene on map 19 entry when act3_silence + not seen |
| Shrine tile handler | `synth-quest.lua` (in per-tile dispatch in try_move) | Astrolabe tile (13, 6) on map 19 fires `start_resonance_attunement("long_echo")` |
| RESO branch: `long_echo` dispatch | `synth-quest.lua:~15867` (RESO branch in `apply_player_action`) | Extend rid switch |
| STIR action branch | `synth-quest.lua:~15642` (`apply_player_action`) | New `elseif p.queued == "STIR"` |
| Limit Break wraith branch | `synth-quest.lua:~13207` (limit-break dispatch) | New `elseif cls == "wraith"` |
| ECHO sprite table | `synth-quest.lua:~20345` (sprite tables area) | NEW 4 dirs × 2 frames |
| `draw_wraith_sprite` + SPRITE_BY_CLASS | `synth-quest.lua:~20716` / `~20911` | NEW helper + register |
| `draw_scene_academy_astrolabe_resonant` | `synth-quest.lua` (scene draw helpers area) | NEW |
| `SCENE_DRAW` register | `synth-quest.lua` (SCENE_DRAW table) | `academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant` |
| Save/load: recruits[4] | `synth-quest.lua` (`save_game` + `load_game`) | Extend `data.recruits_joined` to index 4 |
| Long Echo arm flag | `synth-quest.lua` (RESO branch consume only — Phase D existing edit) | `p.long_echo_armed = true` (stub; no consume hook yet) |

No new files except the SC engine update. No tests (project has none).

---

### Task 1: Pre-flight backup

**Files:**
- Create: `~/dev/synth-quest/backups/synth-quest-pre-echo.lua`
- Create: `~/dev/synth-quest/backups/Engine_SynthQuest-pre-echo.sc`

- [ ] **Step 1: Snapshot the Lua + SC files**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-pre-echo.lua && cp ~/dev/synth-quest/lib/Engine_SynthQuest.sc ~/dev/synth-quest/backups/Engine_SynthQuest-pre-echo.sc`
Expected: no output, both files exist at the backup paths.

- [ ] **Step 2: Confirm snapshots**

Run: `ls -la ~/dev/synth-quest/backups/synth-quest-pre-echo.lua ~/dev/synth-quest/backups/Engine_SynthQuest-pre-echo.sc`
Expected: both files exist with byte sizes matching their source files.

---

### Task 2: Add `sq_wraith` SynthDef + engine commands

**Files:**
- Modify: `lib/Engine_SynthQuest.sc` — add SynthDef + engine commands

**Discovery first:** read the existing engine file to confirm structure.

- [ ] **Step 1: Read the existing engine file**

Run: `wc -l ~/dev/synth-quest/lib/Engine_SynthQuest.sc`
Then: `grep -n "SynthDef.*sq_\|addCommand" ~/dev/synth-quest/lib/Engine_SynthQuest.sc | head -30`
Expected: a list of existing `sq_<class>` SynthDefs and `addCommand` calls per class. Pick one (e.g., `sq_mage` or `sq_cleric`) to use as the structural template.

- [ ] **Step 2: Add the `sq_wraith` SynthDef**

Use the Edit tool. Locate an existing SynthDef (e.g., `sq_cleric`) and add `sq_wraith` immediately after it. The structural template comes from whatever the file's existing pattern is — DO NOT use the spec's literal block verbatim if it doesn't match the project's actual conventions (the spec was a sketch).

The SynthDef must:
- Be named `\sq_wraith`
- Accept args: `out=0, freq=440, vel=0.7, attack=0.005, release=2.5, wet=0.8`
- Generate a high-register sawtooth seed: `Saw.ar(freq * 2.0)` enveloped with a short percussive grain (~60ms)
- Bandpass-filter: `BPF.ar(grain, freq * 3.5, 0.15)` (narrow Q, metallic)
- Add a CombC stutter trail: `CombC.ar(grain, 0.3, 0.07, 1.2)` (~14Hz stutter, ~1.2s decay)
- High-shelf cut at 4kHz, -3dB: `BHiShelf.ar(sig, 4000, 1.0, -3)` (use `BHiShelf` per the BEQSuite naming gotcha — NOT `BHighShelf`)
- Apply overall envelope: `EnvGen.kr(Env.perc(attack, release), doneAction: 2)`
- Output to `out` (panned) AND to the existing reverb send bus (whatever the existing SynthDefs use — read one to see)

- [ ] **Step 3: Add per-voice engine commands**

In the engine's command-registration block (search for existing patterns like `this.addCommand("cleric_cutoff", ...)`), add 7 new commands following the same pattern for `wraith`:

- `wraith_cutoff` — sets the bandpass center frequency on a SynthDef control input
- `wraith_res` — sets the bandpass Q
- `wraith_dly` — sets the CombC delay amount
- `wraith_dly_time` — sets the CombC delay time
- `wraith_xwet` — sets the extra reverb send
- `wraith_damp` — sets reverb damp (if other classes have this)
- `wraith_room` — sets reverb room size (if other classes have this)

Copy whichever existing `cleric_*` or `mage_*` block has the closest analogous structure. The SynthDef must expose matching control inputs for each.

- [ ] **Step 4: Verify SC file is valid SuperCollider syntax**

The norns won't compile the file until SYSTEM > RESTART. Do a basic eyeball check: parens balance, no missing commas, every `SynthDef` has a matching `).add;`. Do NOT deploy yet — Task 3 still depends on the SC file being correct.

---

### Task 3: Engine params init + CUTOFF_RANGE

**Files:**
- Modify: `synth-quest.lua` (`init()` function — locate by `grep -n "engine.drone_amp\|function init()"`)
- Modify: `synth-quest.lua:126` (`CUTOFF_RANGE` table)

- [ ] **Step 1: Add `wraith` to CUTOFF_RANGE**

Use the Edit tool. Read `synth-quest.lua` lines 126-135 first to see the exact table format. The table maps class → `{min = N, max = N}`.

Append `wraith = { min = 1600, max = 6000 },` as a new entry. Match the indentation + style of existing rows.

- [ ] **Step 2: Find the per-class engine param init block in `init()`**

Run: `grep -n "engine.cleric_cutoff\|wraith_cutoff\|cleric_room" ~/dev/synth-quest/synth-quest.lua | head -15`
Expected: a list of existing per-class engine command calls in `init()` or other setup. Identify the block where each class's defaults are set.

- [ ] **Step 3: Add wraith default values**

Add wraith equivalents to whichever per-class init block exists. Default values mirror cleric or mage (whichever is structurally closest):

```lua
if engine.wraith_cutoff then engine.wraith_cutoff(2400) end
if engine.wraith_res then engine.wraith_res(0.15) end
if engine.wraith_dly then engine.wraith_dly(0.4) end
if engine.wraith_dly_time then engine.wraith_dly_time(0.07) end
if engine.wraith_xwet then engine.wraith_xwet(0.3) end
if engine.wraith_damp then engine.wraith_damp(0.5) end
if engine.wraith_room then engine.wraith_room(0.5) end
```

Guard each with `if engine.X then` so the script doesn't crash if the SC engine hasn't been restarted yet.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 4: CLASS_ACTIONS + CLASS_INSTRUMENT + CLASS_GROWTH

**Files:**
- Modify: `synth-quest.lua:162` (CLASS_ACTIONS)
- Modify: `synth-quest.lua:173` (CLASS_INSTRUMENT)
- Modify: `synth-quest.lua:806` (CLASS_GROWTH)

- [ ] **Step 1: Add `wraith` to CLASS_ACTIONS**

Read lines 162-170 first to confirm format. Then use the Edit tool. `old_string`:

```lua
  drummer  = {A="ATK", B="BLK", X="DRUM", Y="ITM"},   -- Niko: drum hit (uses warrior voice)
}
```

`new_string`:

```lua
  drummer  = {A="ATK", B="BLK", X="DRUM", Y="ITM"},   -- Niko: drum hit (uses warrior voice)
  wraith   = {A="ATK", B="DEF", X="STIR", Y="ITM"},   -- ECHO: fragmented chord
}
```

- [ ] **Step 2: Add `wraith` to CLASS_INSTRUMENT**

Read line 173-174 first. The table is on two lines. Use the Edit tool. `old_string`:

```lua
local CLASS_INSTRUMENT = {bard="LUTE", cleric="HEAL", warrior="TUNE", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM"}
```

`new_string`:

```lua
local CLASS_INSTRUMENT = {bard="LUTE", cleric="HEAL", warrior="TUNE", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM",
                          wraith="STIR"}
```

- [ ] **Step 3: Add `wraith` to CLASS_GROWTH**

Read lines 806-815 first to see the format. Then add a new row at the end:

```lua
  wraith   = {hp=3, mp=4, atk=0, def=1, mag=2, spd_every=8},
```

Use the Edit tool with the last existing row + closing brace as anchor, matching the file's actual content.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 5: ECHO sprite table

**Files:**
- Modify: `synth-quest.lua:~20345` (sprite tables area — before/after existing ALDER/MIEL/STROM/etc.)

- [ ] **Step 1: Find a good insertion point**

Run: `grep -n "^local PAJ = \|^local SERGEI = \|^local NIKO = " ~/dev/synth-quest/synth-quest.lua | head -3`
Expected: one or more line numbers. The ECHO table goes alongside these (e.g., immediately after PAJ).

- [ ] **Step 2: Read a sample sprite table for format**

Run: `sed -n '20345,20420p' ~/dev/synth-quest/synth-quest.lua | head -75`
Expected: the ALDER sprite table — it shows the exact format (down/up/left/right keys, frame `[0]` and `[1]` sub-keys, 64-element arrays of brightness values).

- [ ] **Step 3: Add the ECHO sprite table**

Use the Edit tool. Locate the last existing sprite table (likely PAJ or NIKO) and insert `ECHO` immediately after it. The structure matches existing tables:

```lua
local ECHO = {
  down = {
    [0] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 9, 0, 7, 7, 0, 9, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 7, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 5, 0, 0, 5, 0, 0,
    },
    [1] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 9, 0, 7, 7, 0, 9, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 7, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 5, 0, 0, 0, 5, 0,    -- foot stride
    },
  },
  up = {
    [0] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 9, 9, 9, 9, 9, 9, 0,    -- back of head, no eyes
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 7, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 5, 0, 0, 5, 0, 0,
    },
    [1] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 9, 9, 9, 9, 9, 9, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 7, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 5, 0, 0, 0, 5, 0,
    },
  },
  right = {
    [0] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 0, 9, 9, 7, 0, 0, 0,    -- profile: hair + single eye
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,    -- trailing edge at rear (col 2 = level 3)
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 5, 0, 0, 0, 0, 0,
    },
    [1] = {
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 0, 9, 9, 7, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 5, 5, 0, 0, 0,
       0, 0, 0, 7, 7, 7, 0, 0,
       0, 0, 3, 7, 7, 3, 0, 0,
       0, 0, 3, 3, 3, 3, 0, 0,
       0, 0, 0, 0, 0, 5, 0, 0,    -- foot stride
    },
  },
  -- left is rendered by mirroring right via flip flag (matches existing convention)
}
```

(The same `dirframe(p)` helper that other classes use will handle `left = mirror of right` automatically — confirm by reading the existing sprite tables; some have explicit `left` keys, some don't. If existing tables have explicit `left`, add `left` mirror data here too.)

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 6: `draw_wraith_sprite` + SPRITE_BY_CLASS

**Files:**
- Modify: `synth-quest.lua:~20716` (sprite draw helpers — alongside `draw_mage_sprite` etc.)
- Modify: `synth-quest.lua:~20911` (SPRITE_BY_CLASS table)

- [ ] **Step 1: Read existing draw helpers for the exact pattern**

Run: `sed -n '20716,20730p' ~/dev/synth-quest/synth-quest.lua`
Expected: a few one-line draw functions like `draw_mage_sprite`, `draw_cleric_sprite`, etc. All follow `local function draw_X_sprite(sx, sy) local data, flip = dirframe(X); draw_sprite(sx, sy, data, flip) end`.

- [ ] **Step 2: Add `draw_wraith_sprite`**

Use the Edit tool. Locate the last existing sprite draw helper and insert immediately after:

```lua
local function draw_wraith_sprite(sx, sy)
  local data, flip = dirframe(ECHO); draw_sprite(sx, sy, data, flip)
end
```

- [ ] **Step 3: Register in SPRITE_BY_CLASS**

Run: `sed -n '20908,20920p' ~/dev/synth-quest/synth-quest.lua`
Expected: the SPRITE_BY_CLASS table with entries for each existing class.

Use the Edit tool. Add `wraith = draw_wraith_sprite,` as a new entry. `old_string`:

```lua
  drummer  = draw_drummer_sprite,
```

(or whichever the last existing row is — confirm via the read in Step 3)

`new_string`:

```lua
  drummer  = draw_drummer_sprite,
  wraith   = draw_wraith_sprite,
```

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 7: 4th recruit slot

**Files:**
- Modify: `synth-quest.lua:~2748` (`CONTENT.recruits`)

- [ ] **Step 1: Read the existing recruits block**

Run: `sed -n '2748,2760p' ~/dev/synth-quest/synth-quest.lua`
Expected: a 3-entry table with engineer/mathwiz/drummer.

- [ ] **Step 2: Add 4th entry**

Use the Edit tool. `old_string`:

```lua
    {class="drummer",  spd=5, hp_max=30, mp_max=8,  atk=4, def=2, mag=0,
     blurb="Drummer. Keeps the band on the one.",
     joined=false},
  },
```

`new_string`:

```lua
    {class="drummer",  spd=5, hp_max=30, mp_max=8,  atk=4, def=2, mag=0,
     blurb="Drummer. Keeps the band on the one.",
     joined=false},
    {class="wraith",   spd=5, hp_max=60, mp_max=70, atk=2, def=2, mag=7,
     blurb="Wraith. A song-being anchored in the party's chord.",
     joined=false},
  },
```

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 8: Save/load — extend recruits_joined to index 4

**Files:**
- Modify: `synth-quest.lua` `save_game` and `load_game` (locate via grep)

- [ ] **Step 1: Find the save-side recruits_joined block**

Run: `grep -n "data.recruits_joined" ~/dev/synth-quest/synth-quest.lua | head -5`
Expected: 1-2 lines referencing `data.recruits_joined`. Note the exact line numbers — the format is a single-line table literal with 3 entries.

- [ ] **Step 2: Read the save-side block**

Read 3 lines around the save-side match. The existing line looks like:

```lua
data.recruits_joined = {CONTENT.recruits[1].joined, CONTENT.recruits[2].joined,
                        CONTENT.recruits[3] and CONTENT.recruits[3].joined or false}
```

- [ ] **Step 3: Extend the save side to include index 4**

Use the Edit tool. Replace the existing 2-line block with:

```lua
data.recruits_joined = {CONTENT.recruits[1].joined, CONTENT.recruits[2].joined,
                        CONTENT.recruits[3] and CONTENT.recruits[3].joined or false,
                        CONTENT.recruits[4] and CONTENT.recruits[4].joined or false}
```

(Use the exact `old_string` from the file as you read in Step 2.)

- [ ] **Step 4: Find the load-side recruits_joined block**

Run: `grep -n "data.recruits_joined\|recruits_joined\[" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: additional matches in `load_game` where the array is unpacked. Read those lines.

- [ ] **Step 5: Extend the load side**

Add load-side handling for index 4. The exact edit depends on what Step 4 shows, but typically the existing pattern looks like:

```lua
if data.recruits_joined then
  CONTENT.recruits[1].joined = data.recruits_joined[1] or false
  CONTENT.recruits[2].joined = data.recruits_joined[2] or false
  if CONTENT.recruits[3] then
    CONTENT.recruits[3].joined = data.recruits_joined[3] or false
  end
end
```

Add immediately after the `[3]` guard:

```lua
  if CONTENT.recruits[4] then
    CONTENT.recruits[4].joined = data.recruits_joined[4] or false
  end
```

- [ ] **Step 6: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 9: Update RESONANCES.long_echo + RESONANCE_SITES.long_echo

**Files:**
- Modify: `synth-quest.lua:~181` (`RESONANCES`)
- Modify: `synth-quest.lua:~208` (`RESONANCE_SITES`)

- [ ] **Step 1: Read existing long_echo entry in RESONANCES**

Run: `sed -n '181,210p' ~/dev/synth-quest/synth-quest.lua`
Expected: the RESONANCES table with `long_echo` as a stub entry (`character = nil, mythos = "TBD", effect = {}`).

- [ ] **Step 2: Update RESONANCES.long_echo**

Use the Edit tool. `old_string`:

```lua
  long_echo    = { name = "The Long Echo",    character = nil, mp_cost = 4, mythos = "TBD", effect = {} },
```

`new_string`:

```lua
  long_echo    = { name = "The Long Echo",    character = "wraith", mp_cost = 4,
                   mythos = "A wandering singer who repeated any phrase she was taught — each repetition softer, slightly behind.",
                   effect = { kind = "delay_double", repeats = 2, dmg_mult = 0.50 } },
```

- [ ] **Step 3: Read existing long_echo entry in RESONANCE_SITES**

Run: `sed -n '208,250p' ~/dev/synth-quest/synth-quest.lua`
Expected: RESONANCE_SITES with `long_echo = { item = nil, shrine = nil }` (stub).

- [ ] **Step 4: Update RESONANCE_SITES.long_echo**

Use the Edit tool. `old_string`:

```lua
  long_echo    = { item = nil, shrine = nil },
```

`new_string`:

```lua
  long_echo    = {
    item = {
      kind  = "auto",
      label = "ECHO's First Note",
      hint  = "the empty astrolabe",
    },
    shrine = {
      map  = 19,
      x    = 13, y = 6,
      lead = "wraith",
      signature = {
        visual = "academy_astrolabe_resonant",
        sound  = { class = "wraith", note = 79, vel = 0.7, attack = 0.05, release = 5.0, wet = 1.0 },
        dialogue = {
          "(ECHO sets her hand on the astrolabe. It rings -- once, faintly, on its own.)",
          "[ECHO]    This was where I waited. For years. Repeating what I could not finish.",
          "(her outline steadies. The astrolabe answers her tone, half a beat behind, then again, fainter.)",
        },
      },
    },
  },
```

- [ ] **Step 5: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 10: RESO branch — long_echo dispatch

**Files:**
- Modify: `synth-quest.lua:~15867` (`apply_player_action` RESO branch) — location may have shifted; grep to confirm

- [ ] **Step 1: Find the current RESO branch line**

Run: `grep -n 'elseif p.queued == "RESO"' ~/dev/synth-quest/synth-quest.lua`
Expected: a single line number.

- [ ] **Step 2: Read the current dispatch block**

Read 25 lines starting at the line from Step 1. The existing dispatch should look like:

```lua
      -- Arm the per-Resonance buff. Other Resonances dispatch on rid
      -- here as they are added in later passes.
      if rid == "ring" then
        p.ring_armed = true
      end
```

- [ ] **Step 3: Extend the dispatch to handle long_echo**

Use the Edit tool. `old_string`:

```lua
      -- Arm the per-Resonance buff. Other Resonances dispatch on rid
      -- here as they are added in later passes.
      if rid == "ring" then
        p.ring_armed = true
      end
```

`new_string`:

```lua
      -- Arm the per-Resonance buff. Other Resonances dispatch on rid
      -- here as they are added in later passes.
      if rid == "ring" then
        p.ring_armed = true
      elseif rid == "long_echo" then
        -- Stubbed flag; consume hook (next 2 ATKs duplicate one beat
        -- late at 50%) lands in a follow-on spec.
        p.long_echo_armed = true
      end
```

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 11: STIR action branch

**Files:**
- Modify: `synth-quest.lua` `apply_player_action` (locate by grep)

- [ ] **Step 1: Find a sibling action branch to use as the structural template**

Run: `grep -n 'elseif p.queued == "HEAL"\|elseif p.queued == "LUTE"\|elseif p.queued == "SMPL"' ~/dev/synth-quest/synth-quest.lua | head -3`
Expected: 3 line numbers for the existing instrument-action branches (HEAL, LUTE, SMPL).

- [ ] **Step 2: Read SMPL or LUTE as a template**

Read about 20 lines around the `SMPL` branch. SMPL is the closest match for STIR (both are MAG-scaled single-target damage spells with sound + animation).

- [ ] **Step 3: Add the STIR branch**

Use the Edit tool. Insert a new `elseif p.queued == "STIR"` branch immediately after the SMPL branch's closing statements. The branch should:

- Cost MP: `if p.mp < 6 then return end; p.mp = p.mp - 6`
- Compute damage: `local dmg = math.floor(p.mag * 1.6)` (MAG-scaled, slightly above flat MAG to give STIR a tactical reason vs ATK)
- Fire a fragmented chord SFX: 3-5 `sq_trig` calls in quick succession at notes from the active mode, on the wraith voice
- Apply damage: `if enemy and enemy.alive then damage_enemy(dmg, false) end`
- Visual: `ANIM.burst(96, 32, 6, 11)` (modest mid-brightness burst at enemy position)
- Set `p.last_fire = tick` and `p.last_action = "STIR"`

The exact code to insert:

```lua
  elseif p.queued == "STIR" then
    -- ECHO's STIR: fragmented chord on the wraith voice. MAG-scaled
    -- damage; 6 MP cost. Plays as 3 grains across the active mode at
    -- her high register.
    if p.mp >= 6 then
      p.mp = p.mp - 6
      local sc = (JAM and JAM.scales and JAM.scales[JAM.mode]) or {0, 2, 4, 5, 7, 9, 11}
      local root = (JAM and JAM.root) or 0
      -- 3 grains, rising
      for k, deg in ipairs({1, 4, 6}) do
        local note = (sc[deg] or sc[1]) + root + 60
        clock.run(function()
          clock.sleep((k - 1) * 0.06)
          sq_trig("wraith", midi_to_freq(note), 0.65, 0.005, 1.2,
                  math.min(1, 0.85 * (CONTENT.combat_reverb_mix or 1.0)))
        end)
      end
      if enemy and enemy.alive then
        local dmg = math.floor(p.mag * 1.6)
        damage_enemy(dmg, false)
        ANIM.burst(96, 32, 6, 11)
      end
      p.last_fire = tick
      p.last_action = "STIR"
    end
```

The `old_string` for the Edit depends on what Step 2 showed — typically the last few lines of the SMPL branch. Use enough context to be unique.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 12: Limit Break — wraith DISPERSE branch

**Files:**
- Modify: `synth-quest.lua:~13207` (limit-break dispatch in `apply_player_action`) — grep to confirm

- [ ] **Step 1: Find the limit-break dispatch**

Run: `grep -n 'if cls == "cleric"\|elseif cls == "warrior"\|p.limit_used' ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: line numbers near the limit-break logic. Read 50 lines around it.

- [ ] **Step 2: Add the wraith DISPERSE branch**

Find the existing limit-break dispatch chain (looks like `if cls == "cleric" then ... elseif cls == "warrior" then ... ... else ... end`). Add a new branch before the final `else`/`end`:

```lua
    elseif cls == "wraith" then
      -- ECHO: DISPERSE. Splits into 5 ghost-copies for one beat,
      -- each firing at the enemy. MAG*4 total damage. The screen
      -- dims briefly to read the "she's everywhere" effect.
      if enemy and enemy.alive then
        local dmg = math.floor(p.mag * 4)
        damage_enemy(dmg, true)   -- treat as crit for visual
        -- 5 ghost-bursts spaced across the enemy column
        for k = 1, 5 do
          clock.run(function()
            clock.sleep((k - 1) * 0.04)
            ANIM.burst(90 + k * 3, 28 + (k % 2) * 6, 4, 13)
            sq_trig("wraith", midi_to_freq(67 + k), 0.55, 0.005, 0.6,
                    math.min(1, 0.7 * (CONTENT.combat_reverb_mix or 1.0)))
          end)
        end
        ANIM.shake(2, 8)
      end
```

The `old_string` for the Edit uses the closing statements of whichever branch is currently last (typically the generic `else` for "any other class"). Read carefully before editing.

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 13: `start_echo_recruit_scene` function

**Files:**
- Modify: `synth-quest.lua` (alongside other scene helpers — locate by `grep -n "function start_page_warning_scene\|function start_courtyard_breach"`)

- [ ] **Step 1: Find a good insertion point**

Run: `grep -n "^function start_page_warning_scene\|^function start_courtyard_breach_script\|^function start_resonance_attunement" ~/dev/synth-quest/synth-quest.lua | head -5`
Expected: line numbers for existing scene helpers. The new function goes alongside these — insert before `start_resonance_attunement` for ordering.

- [ ] **Step 2: Add `start_echo_recruit_scene`**

Use the Edit tool. `old_string`: the existing line `function start_resonance_attunement(id)` and the comment block immediately above it.

`new_string`: the same content PLUS the new function inserted before:

```lua
-- start_echo_recruit_scene() -- Act 3 "World of Silence" beat at the
-- Academy courtyard astrolabe (map 19, tile 13, 6). ECHO's tenuous
-- existence is dissolving with Modalia's silence; she asks to anchor
-- in the party's chord. They consent; she joins the party (recruits
-- slot 4) and the Long Echo sacred item auto-grants.
function start_echo_recruit_scene()
  local px, py = player.x, player.y
  local ax, ay = 13, 6
  local script = {
    {hide_player = true},
    {letterbox_in = true},
    {focus = {x = ax, y = ay - 1}, ticks = 14},
    {spawn = "alder",   class = "bard",    name = "Alder",   x = px - 1, y = py, facing = "right", bob = false},
    {spawn = "miel",    class = "cleric",  name = "Miel",    x = px,     y = py, facing = "right", bob = false},
    {spawn = "diegues", class = "mage",    name = "Diegues", x = px - 2, y = py, facing = "right", bob = false},
    {spawn = "echo",    class = "wraith",  name = "ECHO",    x = ax,     y = ay, facing = "left",  bob = false},
    {wait = 12},
    -- ECHO speaks. Her sprite flickers — the silence is dissolving her.
    {sfx = {class = "wraith", note = 79, vel = 0.4, attack = 0.005, release = 1.2, wet = 1.0}},
    {dialogue = {
      "(ECHO's outline shudders. Half a syllable, then nothing. Then again.)",
      "[ECHO]    ...the chord. You still carry...",
      "[ECHO]    I cannot hold here without it. The silence eats my edges.",
    }, npc = {name = "ECHO"}},
    {wait = 8},
    -- Diegues recognizes what's happening.
    {look = "diegues", toward = "echo"},
    {dialogue = {
      "[Diegues] (quietly) She was never quite real. The astrolabe held her shape.",
      "[Diegues] The astrolabe is going quiet too. She has hours, maybe.",
    }, npc = {name = "Diegues"}},
    {wait = 6},
    -- ECHO asks.
    {dialogue = {
      "[ECHO]    Let me walk with you. (a flicker; she nearly vanishes, returns)",
      "[ECHO]    Your chord is the loudest thing left.",
    }, npc = {name = "ECHO"}},
    {wait = 8},
    -- Miel answers.
    {dialogue = {
      "[Miel]    (steps forward; offers her hand)",
      "[Miel]    We will not let the silence have you.",
    }, npc = {name = "Miel"}},
    {wait = 10},
    -- ECHO becomes corporeal. Her voice resolves from fragments to a single sustained tone.
    {sfx = {class = "wraith", note = 72, vel = 0.7, attack = 0.05, release = 4.0, wet = 0.9}},
    {wait = 14},
    {set = function()
      CONTENT.scene_seen = CONTENT.scene_seen or {}
      CONTENT.scene_seen.echo_recruit = true
      if CONTENT.recruits[4] then
        CONTENT.recruits[4].joined = true
      end
      CONTENT.resonances.long_echo.item = true
      CONTENT.banner_text  = "* ECHO joins the party *"
      CONTENT.banner_ticks = 90
    end},
    {wait = 24},
    {despawn = "alder"}, {despawn = "miel"}, {despawn = "diegues"}, {despawn = "echo"},
    {teleport_player = {x = px, y = py, facing = "left"}},
    {show_player = true},
    {letterbox_out = true},
  }
  SCENE.start(script)
end

-- start_resonance_attunement(id) -- shared scaffold for all Resonance
-- attunement scenes. Reads RESONANCE_SITES[id].shrine.signature for the
-- per-Resonance overrides (visual scene-id, sound spec, dialogue lines).
-- Sets CONTENT.resonances[id].attuned = true at the end.
function start_resonance_attunement(id)
```

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 14: Recruitment trigger hook

**Files:**
- Modify: `synth-quest.lua:~16596` (post-`travel_to` hook block) — grep to confirm

- [ ] **Step 1: Find the hook block**

Run: `grep -n "start_page_warning_scene\|start_prologue_castle_intro\|CONTENT.scene_seen" ~/dev/synth-quest/synth-quest.lua | head -10`
Expected: several line numbers. Find the one inside `travel_to` (or its post-arrival hook) that conditionally fires existing scenes when map_id matches.

- [ ] **Step 2: Add the ECHO recruit trigger**

Use the Edit tool. Locate the existing scene trigger block (likely after the page_warning trigger). Insert a new trigger:

```lua
  -- ECHO recruitment: Act 3 "World of Silence" beat at the Academy
  -- courtyard. Fires once when the player enters map 19 with the
  -- silence flag set. Until Act 3 systems land, the debug flag
  -- `CONTENT.debug_force_echo_recruit` bypasses the act3_silence check
  -- for testing.
  if not _scene_busy and map_id == 19 and CONTENT
     and (CONTENT.act3_silence or CONTENT.debug_force_echo_recruit)
     and not (CONTENT.scene_seen and CONTENT.scene_seen.echo_recruit) then
    if start_echo_recruit_scene then start_echo_recruit_scene() end
  end
```

The `old_string` is the existing surrounding scene-trigger block — pick a few unique lines (e.g., the page_warning trigger's `if not _scene_busy and map_id == 27 ...` chunk) and add the new block immediately after.

- [ ] **Step 3: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 15: Hide existing Echo NPC after recruitment

**Files:**
- Modify: `synth-quest.lua:3024-3042` (the Echo NPC in academy_npcs)

The existing Echo NPC doesn't have a `visible` function — she always shows. After recruitment, she shouldn't appear (she's in the party).

- [ ] **Step 1: Add `visible` function to the Echo NPC**

Use the Edit tool. `old_string`:

```lua
    -- Echo — semi-transparent figure near astrolabe (from bible stub)
    {
      x = 13, y = 6, name = "Echo", kind = "npc",
      dialogue = function()
```

`new_string`:

```lua
    -- Echo — semi-transparent figure near astrolabe (from bible stub).
    -- Hidden after the recruitment scene fires (she's in the party then).
    -- Also hidden while any SCENE is active so the static NPC doesn't
    -- visually overlap the scene's spawned actor (per the Page warning fix).
    {
      x = 13, y = 6, name = "Echo", kind = "npc",
      visible = function()
        return not (CONTENT.scene_seen and CONTENT.scene_seen.echo_recruit)
               and not (SCENE and SCENE.active)
      end,
      dialogue = function()
```

- [ ] **Step 2: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 16: Shrine tile handler for long_echo

**Files:**
- Modify: `synth-quest.lua` `try_move` (per-tile dispatch)

The astrolabe tile is tile 73 at (13, 6) on map 19. We need to intercept stepping onto it (or interacting with it) to fire the attunement scene if the conditions match. The existing Ring shrine intercepts at tile 48 in try_move; this is the same pattern.

- [ ] **Step 1: Find the existing Ring shrine intercept (for the template)**

Run: `grep -n 'start_resonance_attunement("ring")' ~/dev/synth-quest/synth-quest.lua`
Expected: 1 line — the existing Ring shrine intercept inside `try_move`'s tile-48 handler.

- [ ] **Step 2: Read the context around it**

Read 25 lines around the Ring intercept. The pattern is:

```lua
if t == 48 then
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
  -- existing tile-48 behavior follows
end
```

- [ ] **Step 3: Find or add the tile-73 handler**

Run: `grep -n "if t == 73\|t == 73" ~/dev/synth-quest/synth-quest.lua | head -5`
Expected: 0 matches (no existing handler for tile 73), OR some matches if an interaction handler exists.

If no existing tile-73 handler exists in `try_move`: add a new one in the same area as the tile-48 handler. The new handler:

```lua
  if t == 73 then
    -- Astrolabe (Academy courtyard, map 19). When ECHO is lead and
    -- has the Long Echo sacred item AND it's not yet attuned, fire
    -- the attunement scene. Otherwise the tile is impassable (it
    -- already is per the tile definition; we just don't move into it).
    local p = party[active]
    if current_map_id == 19
       and p and p.class == "wraith"
       and CONTENT.resonances.long_echo.item
       and not CONTENT.resonances.long_echo.attuned
       and start_resonance_attunement then
      start_resonance_attunement("long_echo")
      redraw()
      return
    end
    -- Otherwise tile 73 is impassable per its tile definition.
    return
  end
```

Insert this immediately after the tile-48 handler block.

If a tile-73 handler ALREADY exists: extend it with the shrine check at the TOP (before any other behavior), using the same conditional shape.

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 17: `draw_scene_academy_astrolabe_resonant` + SCENE_DRAW

**Files:**
- Modify: `synth-quest.lua` (scene draw helpers area — locate by `grep`)

- [ ] **Step 1: Find the existing scene draw helpers**

Run: `grep -n "^function draw_scene_lirael_bell_alcove\|^local function draw_scene_lirael_candles_dim" ~/dev/synth-quest/synth-quest.lua | head -3`
Expected: line numbers for existing scene draws. Read 20 lines around `draw_scene_lirael_bell_alcove` to confirm the style.

- [ ] **Step 2: Add the new scene draw**

Use the Edit tool. Locate the end of `draw_scene_lirael_bell_alcove` and add immediately after:

```lua
function draw_scene_academy_astrolabe_resonant()
  -- Academy courtyard backdrop with the astrolabe at center. Concentric
  -- rings expand outward from it. ECHO's silhouette stands beside it at
  -- solid (no-trail) brightness — visually confirming she's anchored.
  screen.level(1); screen.rect(0, 0, 128, 64); screen.fill()
  -- courtyard floor (paving stripes)
  screen.level(3)
  for y = 36, 60, 4 do screen.move(0, y); screen.line(128, y); screen.stroke() end
  -- astrolabe silhouette at center: pillar + ring on top
  screen.level(7); screen.rect(60, 28, 8, 24); screen.fill()
  -- the rotating ring (slowly rotates with tick)
  screen.level(11)
  local a = (tick * 0.05) % (math.pi * 2)
  screen.circle(64, 24, 8); screen.stroke()
  screen.level(13)
  screen.pixel(64 + math.floor(math.cos(a) * 8), 24 + math.floor(math.sin(a) * 8))
  screen.fill()
  -- expanding rings emanating from the astrolabe — one ring per ~3 ticks
  for k = 0, 2 do
    local r = ((tick + k * 8) % 24) + 4
    if r < 22 then
      screen.level(math.max(3, 11 - k * 2))
      screen.circle(64, 24, r); screen.stroke()
    end
  end
  -- ECHO silhouette to the left of the astrolabe (solid brightness, no trail)
  screen.level(11); screen.rect(50, 26, 4, 4); screen.fill()  -- head
  screen.level(11); screen.rect(49, 30, 6, 8); screen.fill()  -- body
end
```

- [ ] **Step 3: Register in SCENE_DRAW**

Run: `grep -n "lirael_bell_alcove  = draw_scene_lirael_bell_alcove" ~/dev/synth-quest/synth-quest.lua`
Expected: 1 line — the existing SCENE_DRAW registration.

Use the Edit tool. `old_string`:

```lua
  lirael_bell_alcove  = draw_scene_lirael_bell_alcove,
```

`new_string`:

```lua
  lirael_bell_alcove  = draw_scene_lirael_bell_alcove,
  academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant,
```

- [ ] **Step 4: Syntax check**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 18: Deploy + engine restart

**Files:** none modified locally.

- [ ] **Step 1: Confirm norns IP**

Run: `ping -c 2 -W 2000 norns.local 2>&1 | tail -3`
Expected: 0% packet loss + a resolved IPv4 address.

If `norns.local` doesn't resolve: ask the user. White norns at home recently seen at `192.168.1.133`.

- [ ] **Step 2: rsync both Lua and SC files**

Run (substitute resolved IP — `norns.local` works if mDNS resolves):
```bash
rsync -avz -e "ssh -i ~/.ssh/norns" ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/lib/Engine_SynthQuest.sc we@norns.local:/home/we/dust/code/synth-quest/
```
Expected: file list with both files, no errors.

- [ ] **Step 3: Tell the user to SYSTEM > RESTART**

Tell the user: "Engine SynthDef changed (new `sq_wraith`). Do SYSTEM > RESTART on the norns to reload the SuperCollider engine. After restart, open Synth Quest. To force-test the ECHO recruit scene before Act 3 lands, set `CONTENT.debug_force_echo_recruit = true` via the debug menu (or whatever entry point you have for poking CONTENT), then walk into the Academy courtyard (map 19). The scene should fire."

Wait for the user.

---

### Task 19: Manual playthrough verification (12 acceptance criteria)

Walk through the spec's 12 ACs with the user.

- [ ] **AC1: Engine boot — sq_wraith loaded**

Confirm via the norns matron/sclang log: no SynthDef errors at boot, `sq_wraith` registered. (Check `journalctl --user -u norns-matron -n 40` via SSH if needed.)

- [ ] **AC2: Sprite renders translucent**

Force-add ECHO to the active party (via PARTY menu after triggering recruit). Confirm her sprite renders on her HUD column at battle and on the overworld. The sprite should look visibly dimmer / more sparse than the other characters' sprites (max brightness 9 vs 13-15 elsewhere).

- [ ] **AC3: Recruitment scene fires once**

With `CONTENT.debug_force_echo_recruit = true` (or `CONTENT.act3_silence = true`), walk into the Academy courtyard (map 19). Expected: scene plays — three party members spawn, ECHO speaks, Diegues responds, ECHO asks, Miel accepts, banner "* ECHO joins the party *". Afterward `CONTENT.recruits[4].joined == true` and `CONTENT.resonances.long_echo.item == true`. Walking into the courtyard again does NOT re-trigger.

- [ ] **AC4: Astrolabe NPC hides after recruit**

After AC3, walk back through the courtyard. The semi-transparent Echo NPC should no longer appear at the astrolabe.

- [ ] **AC5: Party swap — ECHO in PARTY menu**

Open the PARTY menu. ECHO should appear as a swappable recruit. Swap her into the active party (replacing one of the 4 slots). Her sprite + stats persist; she renders in the swapped slot.

- [ ] **AC6: STIR action works**

In battle with ECHO active, press X (her instrument action). Queues STIR. On fire: 3 grain SFX in quick succession on the wraith voice, MAG-scaled damage to enemy, modest particle burst at the enemy. 6 MP deducted.

- [ ] **AC7: R2 arms long_echo**

With ECHO active + ≥ 4 MP, press R2. Bell signature plays, 4 MP deducted, bell glyph appears on her HUD column (`p.long_echo_armed = true`). No damage to enemy. (Per non-goal: the consume hook isn't wired; the empowered ATK is stubbed.)

- [ ] **AC8: Shrine attunement**

After recruitment, with ECHO as lead, walk to (13, 6) on map 19 (the astrolabe). Attunement scene fires — fade, astrolabe rings, three dialogue lines, banner "* Resonance learned -- The Long Echo *". `CONTENT.resonances.long_echo.attuned == true` afterward.

- [ ] **AC9: Bell glyph appears on ECHO**

After R2 (AC7), the bell glyph renders on ECHO's HUD column (same render hook as Ring; the glyph is per-character via `p.<resonance_id>_armed`).

- [ ] **AC10: Limit Break DISPERSE**

Drain ECHO's HP to ≤25% (let her get hit until low). Next ATK fires DISPERSE: 5 ghost-bursts at the enemy column, MAG×4 damage, screen shakes briefly. `p.limit_used = true` afterward.

- [ ] **AC11: Save/reload roundtrip**

After all the above, save game, quit, reload. Confirm: `CONTENT.recruits[4].joined == true`, `CONTENT.resonances.long_echo.item == true`, `CONTENT.resonances.long_echo.attuned == true`. ECHO still in the party.

- [ ] **AC12: Legacy save migration**

Load a pre-ECHO save (e.g., from `~/dev/synth-quest/backups/synth-quest-pre-echo.lua`'s associated save.data if one exists). Expected: no crash; `CONTENT.recruits[4]` exists (initialized from CONTENT defaults); `CONTENT.recruits[4].joined == false`.

If any AC fails, return to the relevant earlier task. ACs 3, 5, 6, 7, 8, 11 are the critical path.

---

### Task 20: Snapshot + DEVLOG + commit

**Files:**
- Create: `~/dev/synth-quest/backups/synth-quest-echo.lua`
- Create: `~/dev/synth-quest/backups/Engine_SynthQuest-echo.sc`
- Modify: `~/dev/synth-quest/DEVLOG.md`

- [ ] **Step 1: Snapshot post-pass**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-echo.lua && cp ~/dev/synth-quest/lib/Engine_SynthQuest.sc ~/dev/synth-quest/backups/Engine_SynthQuest-echo.sc`
Expected: both files exist.

- [ ] **Step 2: Append DEVLOG entry**

Read `~/dev/synth-quest/DEVLOG.md` (just the last entry to confirm style). Append a new entry matching the existing format. Use today's date.

```
## 2026-05-19 — ECHO joins the party (8th member, wraith class)

Extended the canon astrolabe ECHO NPC into a recruitable 8th
party member per docs/specs/2026-05-19-echo-eighth-party-member-design.md.
New wraith class with new SynthDef (granular stutter + high-
register echo-train via CombC), new sprite (max brightness 9 —
visually translucent), new STIR action (3-grain MAG-scaled
chord at 6 MP), new DISPERSE limit break (5 ghost-bursts at
MAG*4 damage).

ECHO joins at the Academy courtyard astrolabe (map 19, tile 13,6)
during Act 3's "World of Silence" beat. Trigger gates on
CONTENT.act3_silence OR CONTENT.debug_force_echo_recruit (the
latter for testing before Act 3 systems land). Recruitment scene
auto-grants the Long Echo sacred item (ECHO IS the singer the
myth describes); shrine = the astrolabe she was anchored to.

Long Echo R2 arms p.long_echo_armed (combat effect stubbed —
the consume hook for "next 2 ATKs duplicate one beat late at
50%" lands in a follow-on spec).

Engine restart required after this pass (new sq_wraith SynthDef
in lib/Engine_SynthQuest.sc).
```

- [ ] **Step 3: Stage + commit**

Run:
```bash
cd ~/dev/synth-quest && git add synth-quest.lua lib/Engine_SynthQuest.sc DEVLOG.md docs/plans/2026-05-19-echo-eighth-party-member.md && git status --short
```
Expected: those 4 files staged. If any unrelated files staged (`luac.out`, `viewer/*`, the parallel session's fluid-invocation spec, etc.), unstage them.

Run:
```bash
cd ~/dev/synth-quest && git commit -m "$(cat <<'EOF'
echo: 8th party member (wraith class + Long Echo Resonance)

Extends the canon astrolabe ECHO NPC into a recruitable 8th
party member. New wraith class with:

- New SynthDef sq_wraith (granular stutter + CombC echo-train)
- New per-voice engine commands (wraith_cutoff/_res/_dly/etc.)
- New 8x8 sprite (max brightness 9 — visually translucent)
- New STIR action (3-grain MAG-scaled chord; 6 MP)
- New DISPERSE limit break (5 ghost-bursts; MAG*4 damage)
- CUTOFF_RANGE / CLASS_ACTIONS / CLASS_INSTRUMENT / CLASS_GROWTH
- 4th slot in CONTENT.recruits + save/load extension

Joins at Academy courtyard astrolabe (map 19, 13,6) during Act 3
"World of Silence" beat. Trigger: CONTENT.act3_silence OR
CONTENT.debug_force_echo_recruit (the latter for testing before
Act 3 systems land). Recruitment scene auto-grants the Long Echo
sacred item; shrine = the astrolabe. Long Echo R2 arms
p.long_echo_armed (consume hook stubbed pending follow-on spec).

Engine restart required after this pass (SC change).

Spec: docs/specs/2026-05-19-echo-eighth-party-member-design.md
Plan: docs/plans/2026-05-19-echo-eighth-party-member.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds.

---

## Self-review notes

**Spec coverage:**
- Identity (Section 1) — Tasks 4 (class actions/instrument/growth) + 7 (recruit slot)
- Voice + SynthDef (Section 2) — Tasks 2 (SC SynthDef) + 3 (Lua params)
- Stat shape + battle role (Section 3) — Tasks 4 (growth) + 7 (recruit stats) + 11 (STIR) + 12 (DISPERSE)
- Sprite (Section 4) — Tasks 5 + 6
- Recruit roster (recruits[4]) — Task 7
- Save/load — Task 8
- Recruitment scene — Tasks 13 (function) + 14 (trigger) + 15 (NPC hide)
- Long Echo Resonance: sites + signature — Tasks 9 (data) + 10 (R2 dispatch) + 16 (shrine tile) + 17 (signature scene draw)
- All 12 acceptance criteria — Task 19

**Placeholder scan:**
- Task 2 (SC SynthDef) intentionally describes the SynthDef shape rather than providing the exact code because the existing engine file format wasn't read — implementer must read Step 1 first. Acceptable per the plan's "discover first" pattern.
- Task 8 Step 5 says "depends on what Step 4 shows" — discovery-then-edit pattern, like Phase A's Task 4 in the prior Resonances plan. Acceptable.
- No "TBD", "implement later", or vague error-handling instructions.

**Type/name consistency:**
- Class string `"wraith"` consistent across all tasks (CLASS_ACTIONS, CLASS_INSTRUMENT, CLASS_GROWTH, RESONANCES.long_echo.character, RESONANCE_SITES.long_echo.shrine.lead, recruits[4].class, SPRITE_BY_CLASS).
- Resonance id `"long_echo"` consistent across Tasks 9, 10, 16, 17.
- `p.long_echo_armed` boolean — set in Task 10; consume hook is OUT OF SCOPE per spec.
- `CONTENT.resonances.long_echo.{item, attuned}` consistent across Tasks 9, 13 (auto-grant), 16 (shrine check).
- `CONTENT.scene_seen.echo_recruit` consistent across Tasks 13 (set), 14 (gate), 15 (NPC visibility).
- `CONTENT.recruits[4]` consistent across Tasks 7, 8, 13.
- Astrolabe coords `(13, 6)` map 19 consistent across Tasks 9, 13, 16, 17.

**TDD note:** Same as prior plans — no test framework. Manual playthrough in Task 19 is the verification, with per-task `lua5.4 loadfile` smoke checks catching syntax errors before deploy. SC syntax can't be smoke-checked without sclang available locally; relies on the on-device boot to surface errors.

**Engine restart caveat:** Task 18 Step 3 reminds the user about SYSTEM > RESTART. This is critical — without it the `sq_wraith` SynthDef won't be loaded, and ECHO's voice will be silent (and the existing `if engine.wraith_cutoff then` guards in Task 3 prevent crashes but mask the failure).

**Parallel-session-churn caveat:** several spec line numbers may have shifted further between writing this plan and execution. Every task that anchors on a line range begins with a `grep -n` discovery step to confirm the current location. Implementers should NOT trust line numbers in the "Files & locations" table without re-grepping.
