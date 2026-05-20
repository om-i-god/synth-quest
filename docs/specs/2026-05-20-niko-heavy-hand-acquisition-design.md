# Niko / The Heavy Hand — Acquisition Design

**Date:** 2026-05-20
**Project:** Synth Quest (norns)
**Affected file (primary):** `synth-quest.lua`
**Builds on:** `docs/specs/2026-05-14-resonances-acquisition-design.md`, `docs/specs/2026-05-19-echo-eighth-party-member-design.md`

## Problem

The Resonances acquisition system is built and proven for two characters (Miel → The Ring, ECHO → The Long Echo). Niko (drummer, recruit slot 3) is pinned to **The Heavy Hand** in the `RESONANCES` table (`character = "drummer"`), but its `RESONANCE_SITES.heavy_hand` entry is still a stub (`item = nil, shrine = nil`) — there's no way to acquire it in-world.

## Goal

Build Niko's acquisition path: a new single-screen interior map (the Ruined Drum-Hall), reached from the Phrygian Night City region, where Niko finds the legendary Heavy Hand drummer's **iron hand-guard** and attunes by striking the hall's great war-drum. Two-step find→attune, mirroring Miel's pattern, using the existing `start_resonance_attunement` scaffold.

## Non-goals

- **The Heavy Hand combat effect** (`duck_enemies`, 2 bars, ×0.50 enemy damage). This is owned by the parallel `docs/specs/2026-05-20-resonance-effects-design.md`, which wires it via a `RESO_FX` list + a `damage_party` hook. This spec does NOT touch the effect — only acquisition. The effect data already exists in the `RESONANCES.heavy_hand.effect` field.
- Niko's recruitment itself (recruit slot 3 join logic already exists in code).
- The other unassigned Resonances' acquisition (Scatter, Slow Wheel, Masked Voice, Threefold, Spring).
- A guardian NPC in the hall — the hall is deliberately empty; the war-drum carries the weight.
- New SynthDef. The signature sound reuses the existing warrior voice (deep drum thud).

## Lore frame

The Heavy Hand was a legendary war-drummer — *"a drummer whose strikes were so heavy that every other voice in the room ducked out of his way. His hand still carries the rhythm somewhere in the world."* He is NOT Niko; he's a separate (male) legend. He played until his hands broke; the **iron hand-guard** he wore is all that remains. Niko — herself an ex-Suno house-band drummer who quit "when they took the snare apart" — fits the guard onto her own hand and strikes his war-drum to call his Resonance.

This places the relic in the Phrygian Eastern Reaches (the war-drumming nation; Strom's old company drilled to Phrygian chants), tying Niko's Resonance to the Strom↔Niko percussionist bond already in the dialogue.

## Architecture

All in `synth-quest.lua`:

1. **New map 37** — `CONTENT.drumhall_map` + `CONTENT.drumhall_npcs` (empty), registered in the map-load dispatch.
2. **Entrance** — a new entrance tile on the Phrygian Night City map (37 ↔ 36), walkable once Niko has joined.
3. **Two new tile types** — a plinth tile (holds the hand-guard) and a war-drum tile (the shrine), with draw routines + `try_move` interaction handlers.
4. **`RESONANCE_SITES.heavy_hand`** — full entry replacing the stub.
5. **Signature scene draw** — `draw_scene_phrygian_drumhall_resonant` + `SCENE_DRAW` registration.

No changes to the RESO branch (the live fluid system is generic — it reads `RESONANCE_SITES[rid].shrine.signature.sound` + `RESO_ANIMS[rid]`; `play_heavy_hand_anim` already exists).

## The Ruined Drum-Hall (map 37)

Single-screen interior, Phrygian sand-stone palette (reuse Night City tile aesthetics). Suggested layout (~14w × 9h, final dims at implementation):

- Back wall: the **great war-drum** (shrine tile) centered.
- Side: a **stone plinth** holding the iron hand-guard (item tile).
- Floor: rubble, fallen rafters, a couple of unlit braziers (decorative impassable tiles, reuse existing ids where possible).
- Entrance/exit tile at the south edge → returns to Phrygian Night City (map 36).
- No NPCs (`drumhall_npcs = {}`).

**Map registration:** add `elseif map_id == 37 then map = CONTENT.drumhall_map; npcs = CONTENT.drumhall_npcs` to the map-load dispatch (alongside the existing `map_id == 36` Phrygian branch).

**Entrance from Phrygian (map 36):** add a new walkable entrance tile to the Phrygian Night City map at a sensible edge location (resolved at implementation by reading the map 36 layout). A `try_move` handler routes that tile → `travel_to(37, <entry_x>, <entry_y>)` and the drum-hall's exit tile routes back → `travel_to(36, <return_x>, <return_y>)`. Gate the entrance so it's only enterable once `CONTENT.recruits[3].joined` (Niko has joined) — before that, the archway is rubble-blocked with a flavor banner.

## Two new tile types

Pick two free tile ids (the codebase is at ~84 per the draw dispatch; use the next free ids, e.g. **74 = plinth**, **75 = war-drum** — confirm free at implementation).

- **Plinth (tile 74):** a low stone plinth with the iron hand-guard resting on it (draw: a small dark block + a bright metallic glint on top). Impassable. Before pickup it shows the guard; after pickup the glint is gone.
- **War-drum (tile 75):** a tall drum against the back wall (draw: a large barrel shape + skin + iron rim). Impassable.

Both get entries in the tile-draw dispatch (the `TILE_DRAW` table / animated-tile list) and `try_move` interaction handlers (below).

## Acquisition flow

### Step 1 — the iron hand-guard (plinth, tile 74)

`try_move` handler for tile 74 on map 37:

- If `current_map_id == 37` AND `party[active].class == "drummer"` AND `not CONTENT.resonances.heavy_hand.item`:
  - Run a short dialogue scene (or `dlg`-based lines): Niko lifts the guard, turns it over, fits it onto her hand.
  - Set `CONTENT.resonances.heavy_hand.item = true`.
  - Banner `* obtained: the Iron Hand-Guard *`, 60 ticks.
  - `return` (don't move onto the plinth — it's impassable).
- Else (non-drummer lead, or already held): a one-line flavor message (*"the plinth is bare — the guard is on Niko's hand"* once held; or *"a heavy iron guard rests here; it is not yours to take"* for non-Niko leads). `return`.

### Step 2 — strike the war-drum (shrine, tile 75)

`try_move` handler for tile 75 on map 37 — mirrors the tile-73 astrolabe / tile-48 tapestry intercepts:

```lua
if t == 75 then
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
  return   -- otherwise impassable scenery
end
```

The shared `start_resonance_attunement("heavy_hand")` scaffold handles the fade, signature sound, dialogue, banner, and sets `CONTENT.resonances.heavy_hand.attuned = true`.

## RESONANCE_SITES.heavy_hand

Replaces the current stub (`heavy_hand = { item = nil, shrine = nil }`):

```lua
heavy_hand = {
  item = {
    kind  = "tile",
    label = "Iron Hand-Guard",
    hint  = "strike the great war-drum",
  },
  shrine = {
    map  = 37,
    x    = <wardrum_x>, y = <wardrum_y>,   -- the tile-75 position; resolved at layout time
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

**Voice note:** `class = "warrior"` at note 31 (a low, heavy thud). The codebase comment marks the drummer as using the warrior voice, and there is no `trig_drummer` engine command. Confirm at implementation; if a dedicated drummer voice exists, swap the class.

## Signature scene draw

`draw_scene_phrygian_drumhall_resonant` — added alongside the other `draw_scene_*` signature helpers, registered in `SCENE_DRAW` as `phrygian_drumhall_resonant`:

- Sand-stone palette background (dim).
- The great war-drum centered — a large barrel/oval with a taut skin and an iron rim.
- On the strike beat: concentric shockwave rings punch outward from the drum (radius grows per tick, fading), synced with a brief `ANIM.shake(2-3, 8)` so the floor "jumps."
- Niko's silhouette beside the drum at solid brightness.

Reuses the ring-expansion + shake idioms from `draw_scene_academy_astrolabe_resonant` and `draw_scene_lirael_bell_alcove`.

## Save format & migration

No new save fields. `CONTENT.resonances.heavy_hand.{item, attuned}` already exists in the save round-trip (from the acquisition pass). Map 37 is reachable only after Niko joins; `recruits[3].joined` already persists. Legacy saves: `heavy_hand` state defaults to `{item=false, attuned=false}`; the new map simply isn't visited until the player goes there.

## Files & locations

- `synth-quest.lua` — `CONTENT.drumhall_map` + `CONTENT.drumhall_npcs` (new, near the other interior map definitions).
- `synth-quest.lua` — map-load dispatch (`grep "map_id == 36"`): add `map_id == 37` branch.
- `synth-quest.lua` — Phrygian map 36 layout: add an entrance tile; `try_move` route 36→37 and 37→36, gated on `recruits[3].joined`.
- `synth-quest.lua` — tile-draw dispatch: add draw routines for tiles 74 (plinth) + 75 (war-drum); add to the animated-tile list if they animate.
- `synth-quest.lua` — `try_move`: add interaction handlers for tile 74 (hand-guard pickup) and tile 75 (war-drum shrine intercept).
- `synth-quest.lua:~237` — `RESONANCE_SITES.heavy_hand`: replace stub with the full entry.
- `synth-quest.lua` — scene-draw block: add `draw_scene_phrygian_drumhall_resonant`; register in `SCENE_DRAW`.
- `~/dev/synth-quest/backups/` — snapshot before the pass.
- `~/dev/synth-quest/DEVLOG.md` — entry.
- `story/bible.md` — flesh out the NIKO stub (currently "location TBD") with the Heavy Hand connection + the drum-hall; canonize the Ruined Drum-Hall location (lore-sync convention).

## Acceptance criteria

1. With Niko joined (`recruits[3].joined`), the Phrygian entrance tile is enterable and leads to map 37 (the drum-hall). Before she joins, it's blocked with a flavor banner.
2. Map 37 renders: war-drum at back, plinth with hand-guard, sand-stone palette, no NPCs, working exit back to map 36.
3. Walking Niko (drummer lead) into the plinth tile for the first time grants the hand-guard: banner `* obtained: the Iron Hand-Guard *`; `CONTENT.resonances.heavy_hand.item == true`.
4. Plinth with a non-drummer lead, or after pickup → flavor line, no re-grant.
5. Walking Niko into the war-drum tile with the hand-guard held fires `start_resonance_attunement("heavy_hand")`: signature warrior-voice thud + `play_heavy_hand_anim`-style rings, three dialogue lines, banner `* Resonance learned -- The Heavy Hand *`; `CONTENT.resonances.heavy_hand.attuned == true`.
6. War-drum without the hand-guard, or wrong lead → impassable, no scene.
7. After attunement, R2 with Niko active fires the Heavy Hand signature + animation + cooldown (via the generic fluid RESO branch). (Combat effect itself is the parallel resonance-effects spec's job; this spec only ensures the call fires.)
8. Save/reload: `heavy_hand.item` + `.attuned` round-trip; the drum-hall remains reachable.
9. Legacy save (pre-heavy_hand): defaults apply, no crash.

## Risks

- **New map + new tiles is the largest surface here.** Map 37 layout, two tile-draw routines, two `try_move` handlers, and the bidirectional entrance all need to land together for the path to work. Mitigation: lay the map out first, hardcode the tile coords into `RESONANCE_SITES`, then wire interactions.
- **Tile id collision.** 74/75 are proposed as free — confirm via `grep "t == 74\|t == 75\|TILE_DRAW\[74\]"` before claiming them.
- **Entrance placement on map 36.** The Phrygian map was built by a parallel session; read its current layout before inserting the entrance tile so it lands on a sensible edge and doesn't overwrite existing content.
- **Drummer voice.** Confirm `sq_trig("warrior", ...)` is the right call for the drum thud (no `trig_drummer` exists today).
- **Parallel-session churn.** Per `feedback_synth_quest_parallel_sessions`, re-grep all anchors at implementation; the Phrygian map + map dispatch may shift.

## Out of scope (deferred)

- Heavy Hand combat effect (parallel resonance-effects spec).
- Other Resonances' acquisition.
- A drum-hall guardian / boss.
- Reusing the hall for anything beyond the Heavy Hand attunement.
