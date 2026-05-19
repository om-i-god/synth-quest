# ECHO — Eighth Party Member Design

**Date:** 2026-05-19
**Project:** Synth Quest (norns)
**Affected file (primary):** `synth-quest.lua`
**Affected file (engine):** `lib/Engine_SynthQuest.sc` (new SynthDef)
**Builds on:** `docs/specs/2026-05-14-resonances-acquisition-design.md`, `docs/specs/2026-05-17-ring-effect-design.md`

## Problem

The Resonances system is built for 8 callers — the 4 starting party + 3 recruits (Sergei, Paj, Niko) + an 8th slot. Of those 8 slots, only 2 are Resonance-pinned in code today: Miel → The Ring, Niko → The Heavy Hand. The 8th party member is a stub. Without an 8th, two Resonances (one of which is `long_echo` — thematically the most central to this game's whole conceit) have no character to attach to, and the world-design for Act 3 has a missing piece.

The bible already has an in-code NPC named **ECHO** at `story/bible.md:1466`: a semi-transparent figure manifest near the Academy courtyard's astrolabe, speaking only in fragments of Velthe's voice. The same name appears as **The Queen's Echo** at the Lirael Ruins (Miel's mother's ghost; scene-only). Neither is a party member.

## Goal

Extend the in-code ECHO NPC into a recruitable 8th party member. New class (`wraith`), new SynthDef (granular stutter / high-register echo-train), new sprite, new Limit Break, new recruitment scene firing during Act 3's "World of Silence" beat. Pair her with **The Long Echo** Resonance — the character whose voice never stopped echoing now carries the Resonance about a singer who repeated phrases that always faded behind her.

The recruitment scene grants the Long Echo sacred item automatically (ECHO IS the singer the myth describes); the shrine is the astrolabe she was anchored to before becoming corporeal.

## Non-goals

- The Long Echo combat effect ("next 2 party attacks duplicate one beat late at 50% damage"). Same deferral pattern as the other 6 unimplemented effects. R2 with ECHO arms a flag; consume hook in ATK lands in a follow-on spec.
- Generic `apply_resonance_effect(id, p)` dispatcher. Still deferred until a second effect lands.
- Act 3's "World of Silence" larger systems (atonal music, broader Modalia-wide silence mechanic). ECHO's recruitment scene depends on `CONTENT.act3_silence` being set by those systems — for this spec the scene is gated on a flag that doesn't exist yet, with a debug toggle for testing before Act 3 lands.
- The other 5 Resonances' character pairings (Masked Voice, Spring, Scatter, Slow Wheel, Threefold).
- Per-region NPC dialogue branches reacting to ECHO as lead. Adds when the world fills in around her.
- ECHO's "trailing echo" sprite render hook — described as optional polish. Ship without it; add if she reads as too solid.
- Modifying or canonizing the Queen's Echo (Lirael Ruins) — separate canon entity, unchanged.

## Identity

| Field | Value |
|---|---|
| **Name** | ECHO |
| **Class** | `wraith` (new class) |
| **Sex / pronouns** | She / her (Velthe is "her" in canon; ECHO speaks in Velthe's voice fragments) |
| **Canon framing** | Extension of the astrolabe ECHO at `story/bible.md:1466`. Not Velthe's ghost — a song-being that learned Velthe's voice, anchored to the astrolabe for years. |
| **Joining moment** | Mid-to-late Act 3 ("World of Silence"). When Modalia goes atonal, ECHO's tenuous existence dissolves; she asks to anchor in the party's chord. |
| **Resonance** | The Long Echo (sole carrier) |
| **MAG affinity** | Locrian (the half-step mode, the unresolved tonic — mirrors her instability) |
| **Inspirations** | FF6 Shadow + FF4 Tellah + FF9 Vivi |

## Voice + SynthDef sketch

```supercollider
// New SynthDef in lib/Engine_SynthQuest.sc, alongside sq_mage/sq_cleric/etc.
SynthDef(\sq_wraith, { |out=0, freq=440, vel=0.7, attack=0.005, release=2.5, wet=0.8|
  var grain, env, trail, sig;
  // High-register sawtooth seed, filtered into a glassy bandpass
  grain = Saw.ar(freq * 2.0) * EnvGen.kr(
    Env.perc(attack, 0.06),
    doneAction: 0
  );
  grain = BPF.ar(grain, freq * 3.5, 0.15);     // narrow Q, metallic
  // Stutter: re-trigger the grain on a fast pulse, each grain quieter
  trail = CombC.ar(grain, 0.3, 0.07, 1.2);    // ~14Hz stutter, gentle decay
  // Overall envelope across the call
  env = EnvGen.kr(Env.perc(attack, release), doneAction: 2);
  sig = (grain + trail * 0.65) * env * vel;
  // High-shelf to thin it; then reverb send for the wet trail
  sig = BHiShelf.ar(sig, 4000, 1.0, -3);     // BHiShelf (abbrev), NOT BHighShelf
  Out.ar(out, Pan2.ar(sig, 0));
  Out.ar(~reverbBus, sig * wet);
})
```

**Per-voice engine params:** matches the existing per-class surface. Add to `lib/Engine_SynthQuest.sc` engine command exports and to `init()` in `synth-quest.lua`:

- `wraith_cutoff` (filter cutoff for the bandpass)
- `wraith_res` (bandpass Q — already at 0.15 default; right-stick override)
- `wraith_dly` (CombC delay time)
- `wraith_dly_time`
- `wraith_xwet` (extra reverb send)
- `wraith_damp`
- `wraith_room`

**CUTOFF_RANGE table** (lives in `synth-quest.lua` near line ~3000 with the other per-class ranges): add `wraith = { min = 1600, max = 6000 }` — high-shifted to match her high-register sit in the mix.

**Engine restart required:** new SynthDef means after the SC file lands, the user has to do SYSTEM > RESTART on the norns. Document in the implementation plan.

## Stat shape + battle role

**Level 1 stat block:**

```lua
-- in PARTY_TEMPLATE / build_starter_record (~line 11337+)
{ class = "wraith", spd = 5, hp_max = 60, mp_max = 70,
  atk = 2, def = 2, mag = 7 }
```

**Class growth:**

```lua
-- in CLASS_GROWTH table
wraith = {hp = 3, mp = 4, atk = 0, def = 1, mag = 2, spd_every = 8}
```

Low HP gain (stays fragile), high MP (4/level), zero ATK growth (she doesn't strike), modest DEF (1/level), strong MAG (2/level), SPD bump every 8 levels.

**Class actions:**

```lua
-- in CLASS_ACTIONS table (~line 162)
wraith = {A = "ATK", B = "DEF", X = "STIR", Y = "ITM"}
```

`STIR` is her class-specific instrument action — fires a fragmented chord (3-5 grains across the active mode at her note register), MP cost 6, deals MAG-scaled damage. Reads as "she stirs the air; pieces of sound fall out." Implemented in `apply_player_action` as a new branch (parallel to HEAL, LUTE, SMPL, etc.).

**CLASS_INSTRUMENT:**

```lua
-- in CLASS_INSTRUMENT table (~line 173)
wraith = "STIR"
```

**Limit Break — ECHO: DISPERSE (≤25% HP, once per battle):** she splits into 5 ghost-copies for one beat. Deals MAG×4 damage spread across all living enemies (or all-on-one if single enemy). Visual: 5 of her flash on screen, each fires once at the enemy(s), the screen briefly dims. No banner; the visual carries it.

Slot in the existing limit-break dispatch at `synth-quest.lua:13207-13257` — add `elseif cls == "wraith"` branch with the MAG-based damage formula and the 5-copy visual effect.

## Sprite

8×8 mono bitmap, 4 directions × 2 walk frames, matching the convention at `synth-quest.lua:17072+`.

Visual brief: scholar's robe, hair pulled back; sparse pixels + low brightness levels (max 9, never 13-15) so she reads as visually translucent regardless of context.

**"down" facing, frame 0:**

```
. . 9 9 9 . . .   ← hair top
. 9 . 7 7 . 9 .   ← eyes (dim) + hair sides
. . . 5 5 . . .   ← face (very dim)
. . . 5 5 . . .
. . 7 7 7 7 . .   ← robe shoulders
. . 3 7 7 3 . .   ← robe taper + trailing edges
. . 3 3 3 3 . .   ← robe hem
. . 5 . . 5 . .   ← feet
```

**"down" frame 1:** same body, foot stride flipped: `. . 5 . . . 5 .`.

**"up":** hair-only top (no eyes visible).

**"left" / "right":** profile — single eye visible at level 7, robe contour, trailing edge at the rear.

The full 8×8 grid for each direction × frame populates an `ECHO` table next to the existing `MIEL`, `STROM`, `ALDER`, `NIKO`, `SERGEI` tables in `synth-quest.lua` (~line 17072+). Draw helper:

```lua
local function draw_wraith_sprite(sx, sy)
  local data, flip = dirframe(ECHO); draw_sprite(sx, sy, data, flip)
end
```

Register in `SPRITE_BY_CLASS` (~line 17633):

```lua
wraith = draw_wraith_sprite,
```

**Trailing-echo render hook (optional, deferred):** a per-draw effect that renders ECHO's sprite twice — once at full brightness at her position, once at half brightness offset 1px in her opposite-facing direction (after-image). Adds an additional motion-feel; spec defers shipping this until playtest shows whether the static sprite alone reads as translucent enough.

## Recruit roster

ECHO joins as the 4th recruit slot in `CONTENT.recruits`:

```lua
-- in CONTENT.recruits (~line 2748)
recruits = {
  {class="engineer", ...},   -- Sergei
  {class="mathwiz",  ...},   -- Paj
  {class="drummer",  ...},   -- Niko
  {class="wraith",   spd=5, hp_max=60, mp_max=70, atk=2, def=2, mag=7,
   blurb="Wraith. A song-being anchored in the party's chord.",
   joined=false},
}
```

Save/load round-trip: `data.recruits_joined` already saves `recruits[1..3]`. Extend to save `recruits[4]` too. Legacy saves (missing index 4) default to `false`.

```lua
-- in save_game (~line 11059)
data.recruits_joined = {
  CONTENT.recruits[1].joined,
  CONTENT.recruits[2].joined,
  CONTENT.recruits[3].joined,
  CONTENT.recruits[4] and CONTENT.recruits[4].joined or false,
}
```

```lua
-- in load_game — extend to index 4
if data.recruits_joined and CONTENT.recruits[4] then
  CONTENT.recruits[4].joined = data.recruits_joined[4] or false
end
```

## Recruitment scene

**Trigger location:** Academy courtyard (existing map). Resolve the map_id + the astrolabe tile coords at implementation time by grep'ing for the astrolabe NPC in the existing `academy_npcs` table.

**Trigger condition:** first entry to the Academy courtyard map AFTER `CONTENT.act3_silence == true`, AND `not CONTENT.scene_seen.echo_recruit`. The trigger sits alongside the existing scene-triggers in `try_move` / the post-`travel_to` hook block at `~line 16596`.

**For test/dev access before Act 3 lands:** a debug toggle (e.g., `CONTENT.debug_force_echo_recruit = true` via the debug menu) bypasses the `act3_silence` check.

**Pre-state:** the canon astrolabe ECHO NPC is gated on `not (CONTENT.scene_seen and CONTENT.scene_seen.echo_recruit)` so she stops appearing after the recruit scene fires. The NPC visibility function gets that condition added.

**Scene script (in `start_echo_recruit_scene()`, alongside the other prologue scene helpers ~line 6326):**

```lua
function start_echo_recruit_scene()
  local px, py = player.x, player.y
  local ax, ay = <astrolabe_x>, <astrolabe_y>   -- resolved at impl time
  local script = {
    {hide_player = true},
    {letterbox_in = true},
    {focus = {x = ax, y = ay - 1}, ticks = 14},
    {spawn = "alder",   class = "bard",    name = "Alder",   x = px - 1, y = py,     facing = "right", bob = false},
    {spawn = "miel",    class = "cleric",  name = "Miel",    x = px,     y = py,     facing = "right", bob = false},
    {spawn = "diegues", class = "mage",    name = "Diegues", x = px - 2, y = py,     facing = "right", bob = false},
    {spawn = "echo",    class = "wraith",  name = "ECHO",    x = ax,     y = ay,     facing = "left",  bob = false},
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

    -- ECHO becomes corporeal. Her voice resolves from fragments to a single tone.
    {sfx = {class = "wraith", note = 72, vel = 0.7, attack = 0.05, release = 4.0, wet = 0.9}},
    {wait = 14},

    {set = function()
      CONTENT.scene_seen.echo_recruit = true
      if CONTENT.recruits[4] then
        CONTENT.recruits[4].joined = true
      end
      -- Auto-grant the Long Echo sacred item (ECHO IS the singer the myth describes).
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
```

**Banner exception:** the "ECHO joins the party" banner is kept. Party-joins are major narrative moments; the banner is appropriate here even though the spec's general posture (after the Ring playtest) leans away from gameplay-blocking banners.

**Party swap:** after the scene, ECHO appears in the PARTY menu as swappable into one of the 4 active slots. Uses the existing recruit-swap UI (no new code).

## Long Echo Resonance: sites + signature

```lua
-- In RESONANCES table (~line 175), already exists as a stub. Confirm:
RESONANCES.long_echo = {
  name      = "The Long Echo",
  character = "wraith",
  mp_cost   = 4,
  mythos    = "A wandering singer who repeated any phrase she was taught — each repetition softer, slightly behind.",
  effect    = { kind = "delay_double", repeats = 2, dmg_mult = 0.50 },
}
```

```lua
-- In RESONANCE_SITES table (~line 208), replace the stub for long_echo:
RESONANCE_SITES.long_echo = {
  item = {
    kind  = "auto",                -- granted at recruitment, not via NPC interaction
    label = "ECHO's First Note",
    hint  = "the empty astrolabe",
  },
  shrine = {
    map  = <academy_courtyard_map_id>,
    x    = <astrolabe_x>,
    y    = <astrolabe_y>,
    lead = "wraith",
    signature = {
      visual = "academy_astrolabe_resonant",
      sound  = { class = "wraith", note = 79, vel = 0.7, attack = 0.05, release = 5.0, wet = 1.0 },
      dialogue = {
        "(ECHO sets her hand on the astrolabe. It rings — once, faintly, on its own.)",
        "[ECHO]    This was where I waited. For years. Repeating what I could not finish.",
        "(her outline steadies. The astrolabe answers her tone, half a beat behind, then again, fainter.)",
      },
    },
  },
}
```

**Shrine trigger:** add a check in the existing `try_move` per-tile dispatch — when the player steps onto the astrolabe tile on the academy courtyard map AND ECHO is lead AND `CONTENT.resonances.long_echo.item` AND `not CONTENT.resonances.long_echo.attuned` AND `start_resonance_attunement` exists, call it with `"long_echo"`. Otherwise the astrolabe tile behaves as it does today.

**Signature scene draw — `draw_scene_academy_astrolabe_resonant`:** add a new draw helper alongside the existing `draw_scene_lirael_bell_alcove` (`synth-quest.lua:~23872`). Visual brief:

- Background: a dark Academy courtyard (silhouette of the astrolabe at center)
- Concentric thin rings expanding outward from the astrolabe; one ring per tick, fading at radius ~20
- ECHO's silhouette stands beside the astrolabe at full brightness — for the duration of the attunement she's at solid level 11-13 (no trailing echo) — visually confirming she's anchored

Register in `SCENE_DRAW` table at `synth-quest.lua:~23966`:

```lua
academy_astrolabe_resonant = draw_scene_academy_astrolabe_resonant,
```

**Long Echo R2 arm (placeholder per non-goal):** the existing RESO branch in `apply_player_action` (~line 15867) already dispatches by `rid`:

```lua
if rid == "ring" then
  p.ring_armed = true
end
```

Extend this with:

```lua
if rid == "ring" then
  p.ring_armed = true
elseif rid == "long_echo" then
  p.long_echo_armed = true
end
```

The consume hook (next 2 ATKs duplicate one beat late at 50%) lands in a follow-on spec. For this spec the flag exists but doesn't do anything yet — calling Long Echo costs 4 MP and arms an unused flag.

## Save format & migration

`CONTENT.recruits[4]` and `CONTENT.resonances.long_echo.{item, attuned}` need persistence:

1. **`recruits[4].joined`** — added to `data.recruits_joined` array at index 4 (see Recruit roster section above).
2. **`CONTENT.resonances.long_echo`** — already in save format from the Resonances acquisition pass. No additional change.
3. **`CONTENT.scene_seen.echo_recruit`** — already covered by the existing `data.scene_seen` round-trip.
4. **`p.long_echo_armed`** — per-battle, not persisted (matches `p.ring_armed`).

**Migration:** legacy saves (no `recruits[4]`, no `resonances.long_echo` state) initialize to defaults at load time. Existing saves continue working as if ECHO has never been recruited and the Long Echo Resonance has never been touched.

## Files & locations

- `lib/Engine_SynthQuest.sc` — add `SynthDef(\sq_wraith, ...)`; export `wraith_cutoff`, `wraith_res`, `wraith_dly`, `wraith_dly_time`, `wraith_xwet`, `wraith_damp`, `wraith_room` commands.
- `synth-quest.lua:~162` (`CLASS_ACTIONS`) — add `wraith = {A="ATK", B="DEF", X="STIR", Y="ITM"}`.
- `synth-quest.lua:~173` (`CLASS_INSTRUMENT`) — add `wraith = "STIR"`.
- `synth-quest.lua:~3000` (`CUTOFF_RANGE`) — add `wraith = { min = 1600, max = 6000 }`.
- `synth-quest.lua:~175` (`RESONANCES`) — confirm `long_echo` entry has `character = "wraith"` and `mp_cost = 4`.
- `synth-quest.lua:~208` (`RESONANCE_SITES`) — replace `long_echo` stub with full entry.
- `synth-quest.lua:~2748` (`CONTENT.recruits`) — add 4th entry for wraith.
- `synth-quest.lua:~11059` (`save_game`) and `~11160` (`load_game`) — extend `recruits_joined` to index 4.
- `synth-quest.lua:~13207` (limit-break dispatch) — add `wraith` branch.
- `synth-quest.lua:~15642` (`apply_player_action`) — add `STIR` branch alongside HEAL, LUTE, etc.
- `synth-quest.lua:~15867` (RESO branch) — extend `rid` dispatch with `long_echo`.
- `synth-quest.lua:~16596` (post-`travel_to` hook block) — add the Academy-courtyard / `act3_silence` trigger for `start_echo_recruit_scene`.
- `synth-quest.lua:~6326` (alongside other scene helpers) — add `start_echo_recruit_scene()`.
- `synth-quest.lua` (existing astrolabe ECHO NPC in `academy_npcs`) — extend `visible` function with `not CONTENT.scene_seen.echo_recruit` clause.
- `synth-quest.lua:~17072` (sprite tables) — add `ECHO` 8x8 sprite table.
- `synth-quest.lua:~17442` (sprite draw helpers) — add `draw_wraith_sprite(sx, sy)`.
- `synth-quest.lua:~17633` (`SPRITE_BY_CLASS`) — add `wraith = draw_wraith_sprite`.
- `synth-quest.lua:~23872` (scene draw helpers) — add `draw_scene_academy_astrolabe_resonant`.
- `synth-quest.lua:~23966` (`SCENE_DRAW`) — register the new scene.
- `synth-quest.lua` — also add `wraith_cutoff` / `wraith_res` / etc. setter calls in `init()` and stick-handler dispatch in `gamepad.analog`.
- `~/dev/synth-quest/backups/` — snapshot before the pass per project convention.
- `~/dev/synth-quest/DEVLOG.md` — add an entry.

## Acceptance criteria

1. **Engine boot:** after SC engine restart, the norns sclang console shows `sq_wraith` SynthDef loaded without error.
2. **Sprite renders:** with ECHO in the active party slot, her sprite draws on the HUD column at battle and on the overworld when she's lead. Sprite appears visually translucent (max brightness 9, not 15).
3. **Recruitment scene fires:** with `CONTENT.act3_silence = true` (or the debug toggle), walking into the Academy courtyard fires `start_echo_recruit_scene` exactly once; banner shows "* ECHO joins the party *"; `CONTENT.recruits[4].joined == true` and `CONTENT.resonances.long_echo.item == true` afterward.
4. **Astrolabe NPC hides post-recruit:** after `scene_seen.echo_recruit == true`, the canon astrolabe ECHO NPC stops appearing in the courtyard.
5. **Party swap:** ECHO appears as swappable in the PARTY menu after joining. Swapping her into the active party retains her stats; she renders in the swapped-in slot.
6. **STIR action:** with ECHO active in battle, X button queues STIR. On fire, deals MAG-scaled damage with the granular-chord SFX. Costs 6 MP.
7. **R2 arms long_echo flag:** with ECHO active + ≥ 4 MP, pressing R2 sets `p.long_echo_armed = true`, plays the signature sound, deducts 4 MP. (Effect itself stubbed per non-goal.)
8. **Shrine attunement:** with ECHO as lead and `resonances.long_echo.item == true`, stepping onto the astrolabe tile fires `start_resonance_attunement("long_echo")`; banner "* Resonance learned -- The Long Echo *"; `resonances.long_echo.attuned == true` afterward.
9. **Bell glyph appears:** ECHO's HUD column shows the bell glyph when `p.long_echo_armed` is true (same render hook as Ring; the glyph is per-character, not per-Resonance).
10. **Limit Break:** at ≤25% HP, ECHO's next ATK fires DISPERSE: 5 ghost-copies, MAG×4 damage to enemy(s).
11. **Save/reload:** save with ECHO recruited + Long Echo attuned, reload, confirm both flags round-trip.
12. **Legacy save migration:** loading a pre-ECHO save initializes `CONTENT.recruits[4]` and the Long Echo state to defaults without crashing.

## Risks

- **Engine restart friction:** every implementer / player will need SYSTEM > RESTART after the SC change lands. Document prominently in the plan and DEVLOG.
- **Sprite reads as too solid.** The trailing-echo render hook is deferred — if she reads as just-another-character on the OLED, plan a follow-up to add the after-image render.
- **STIR balance.** MAG-scaled damage with 5 SPD means ECHO casts faster than Diegues. If she out-damages him in playtest, lower STIR's coefficient or raise the MP cost.
- **Trigger condition depends on Act 3 systems not yet built.** Recruitment scene can't fire under normal play until `CONTENT.act3_silence` exists. Debug toggle covers testing in the interim; flag this clearly in DEVLOG so the team knows the recruit path is dormant until Act 3.
- **MAG affinity (Locrian).** Need to confirm the affinity system in code reads the lead character's class — if `JAM.mode == "locrian"` should boost ECHO's STIR/MAG damage. May require a small hook in the damage path. Punt to a follow-on if the affinity system isn't yet generalized for new classes.
- **Astrolabe coords unknown.** Spec leaves `<astrolabe_x>`, `<astrolabe_y>`, and `<academy_courtyard_map_id>` as placeholders to resolve at implementation time. The implementer must grep for the existing ECHO NPC's coordinates in `academy_npcs` before wiring the trigger or shrine.

## Out of scope (deferred)

- The Long Echo combat effect — armed flag exists but does nothing yet.
- Generic `apply_resonance_effect(id, p)` dispatcher.
- Act 3's "World of Silence" systems.
- ECHO's per-region NPC dialogue branches.
- The other 5 unassigned Resonances' character pairings.
- "Trailing echo" sprite render hook (revisit in playtest).
- Locrian affinity boost integration (depends on affinity-system generalization).
