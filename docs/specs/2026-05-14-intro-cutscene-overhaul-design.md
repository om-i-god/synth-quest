# Intro Cutscene Overhaul — Design

**Date:** 2026-05-14
**Project:** Synth Quest (norns)
**Affected file (primary):** `synth-quest.lua`
**Companion script (no changes):** `start_prologue_castle_intro` at `synth-quest.lua:5130`

## Problem

The opening cutscene establishes Miel as the doomed last queen of an emptied court ("Her court emptied months ago. Her crown sits heavy on the marble"). The playable prologue immediately contradicts this: when control hands to Miel, her castle is alive and being raided in real time — Capt. Ren rallies a guard line, a Page sprints to warn her, the scribe Esa is at his desk, the watchman Dren is on the overlook. The framing and the gameplay are saying two different things about Lirael at the same moment.

## Goal

Rewrite the opening cutscene so its closing beats land Miel inside a *living* court the night the raid arrives, not a long-empty one. Preserve the Modalia origin story and Suno foreshadow. End the cutscene on the seam to the existing chamber-wake script with no changes to that script.

## Non-goals

- No changes to `start_prologue_castle_intro` or any post-cutscene playable scene.
- No changes to the engine, save format, battle system, or any music other than continued use of the existing INTRO_PATTERN at INTRO_BPM 70.
- No changes to the ENDING_LINES cutscene.
- No new gameplay states; the cutscene continues to be a linear panel sequence.

## Structure

Total panels: **21** (up from 14). Three movements:

| Movement | Panel range | Count | Change |
|---|---|---|---|
| Cosmic lore | 1–6 | 6 | Prose unchanged; `scene` field per-panel (was all `cosmic`) |
| Dark foreshadow | 7–9 | 3 | Tightened from 4 panels; `scene` field per-panel (was all `dark`) |
| Lirael ordinary night | 10–21 | 12 | New; replaces the 4 "court emptied months ago" panels |

Runtime at INTRO_BPM 70 with the existing 4-bar INTRO_PATTERN: ~3-4 s/panel → ~70-85 s total (was ~45-55 s).

## Panel-by-panel

Each entry is `{text, scene}` exactly as `CUTSCENE_LINES` already expects.

### Cosmic lore (1–6) — prose unchanged

| # | Scene | Text |
|---|---|---|
| 1 | `cosmic_stars` | Long ago, on planet Modalia, the Crystal Synth gave music — and life — to all. |
| 2 | `cosmic_chord` | Seven shards. Seven modes. One chord, holding the world in tune. |
| 3 | `cosmic_modes` | The Lydian. Dorian. Mixolydian. Phrygian. Aeolian. Locrian. Ionian. |
| 4 | `cosmic_world` | When the Crystal sang as one, mountains hummed. Rivers found their tempo. |
| 5 | `cosmic_shatter` | Then it shattered. The seven scattered, one to each musical nation. |
| 6 | `cosmic_drift` | For an age, the world hummed in fragmented harmony. |

### Dark foreshadow (7–9) — tightened

| # | Scene | Text |
|---|---|---|
| 7 | `dark_suno` | Then Suno rose — once a wandering noble, now the dark lord of the silenced lands. |
| 8 | `dark_march` | He hunts every shard, to fold the seven into one bell — and ring it shut. |
| 9 | `dark_village` | Where his silencers march, the songs go cold. Mothers forget their children's names. |

(Old panels 9 + 10 are merged into the single panel 9.)

### Lirael ordinary night (10–21) — new

| # | Scene | Text |
|---|---|---|
| 10 | `lirael_coast` | On the Aeolian shore stands Lirael, a small kingdom that still keeps the chord. |
| 11 | `lirael_belltower` | Tonight, like every night, the keep-bell rings the evening hour. |
| 12 | `lirael_hall` | In the great hall, a scribe scratches at parchment. A page yawns at his post. |
| 13 | `lirael_southwall` | Captain Ren walks the south wall and counts his guards by name. |
| 14 | `lirael_chamber` | In her chamber, Queen Miel sets her crown on the dressing table. |
| 15 | `lirael_candles` | She blows out two of the three candles. She does not blow out the third. |
| 16 | `lirael_road` | Outside, on the road from the west, a lamp goes out that should not. |
| 17 | `lirael_sentry` | On the south wall, a sentry does not answer the next watchword. |
| 18 | `lirael_captain_run` | The captain stops walking. He waits one beat too long. He runs. |
| 19 | `lirael_courtyard` | In the courtyard the bell sounds again — wrong, sharp, twice. |
| 20 | `lirael_gate` | The south gate takes the first blow. The old stones remember. |
| 21 | `lirael_candles_dim` | In her chamber, the queen has not yet woken. The third candle is guttering. |

Panel 21 is the seam: it leaves the camera in Miel's chamber on the third (still-burning, guttering) candle. The existing `start_prologue_castle_intro` opens on "the candles in her chamber are wrong -- two are out, the third is guttering" — same image, no script change required.

## Scene backgrounds

The cutscene's draw layer dispatches on the `scene` field via a table at `synth-quest.lua:22569` keyed to per-scene draw functions defined at `synth-quest.lua:22305-22569`. Today the registered scenes are `cosmic`, `dark`, `village`, `threat`, `throne`, `coup`, `passage`. Of these, `cosmic` / `dark` / `village` are also referenced by `ENDING_LINES` and `throne` / `village` by other cutscenes, so **none of the existing scene functions are removed or renamed.**

This overhaul **adds** 21 new scene keys alongside the existing seven. Each new scene is a small Lua function drawing into the 128×64 mono OLED via `screen.line` / `screen.rect` / `screen.pixel` / `screen.move` / `screen.text` — same primitives the existing seven already use.

### Scene catalogue

| Scene id | Visual brief |
|---|---|
| `cosmic_stars` | Slow-drifting starfield. New scene; the existing `cosmic` draw remains in place for `ENDING_LINES`. May share helpers with `draw_scene_cosmic` if convenient. |
| `cosmic_chord` | Seven small shards in a ring around a glowing center; equal spacing, all bright. |
| `cosmic_modes` | Same ring; each shard tinted/glyphed to suggest its mode (visual variation only — mono brightness levels, no color on norns). |
| `cosmic_world` | Modalia as a small planet at lower screen; faint concentric arcs above (the chord humming). |
| `cosmic_shatter` | Center crystal breaking — shards flying outward with short trails. |
| `cosmic_drift` | Shards far apart now, dim, scattered across the field. |
| `dark_suno` | Tall hooded silhouette on a horizon; faint sigil behind. |
| `dark_march` | A line of small dark figures crossing a pale road, left-to-right. |
| `dark_village` | Cold village rooftops at night; chimneys, no lit windows. |
| `lirael_coast` | Wide establishing — sea on the right (horizontal lines), keep silhouetted on a low headland on the left. |
| `lirael_belltower` | Bell tower lit from below; bell mid-swing. |
| `lirael_hall` | Great hall interior — long table, scribe figure hunched at one end, page near the door. |
| `lirael_southwall` | Stone parapet at night; captain in profile mid-stride; torches at intervals. |
| `lirael_chamber` | Queen's chamber — dressing table with crown set down; mirror behind. |
| `lirael_candles` | Tight on three candles; two snuffed (smoke trail), one burning. |
| `lirael_road` | The west road at night; a single lamp on a post; flame dying / gone in a follow-up frame. (Static frame is fine — the prose carries the "going out" beat.) |
| `lirael_sentry` | Empty sentry post: lantern still lit, no figure. |
| `lirael_captain_run` | Captain mid-stride, cloak trailing, hand on his sword. |
| `lirael_courtyard` | Courtyard from above; bell visible at top of frame. |
| `lirael_gate` | South gate from inside; first impact crack down its face. |
| `lirael_candles_dim` | Same composition as `lirael_candles` but only the third candle still alight, smaller flame, longer smoke trail. |

### Drawing budget

- Each scene is a self-contained function in the same area of the file as the existing scene draws.
- All scenes use existing primitives — no new draw helpers required.
- Scenes that share composition (`lirael_candles` / `lirael_candles_dim`) may share a helper but are dispatched separately so the cutscene index can switch between them cleanly.

## Sound

- **No new music or SFX.** INTRO_PATTERN, INTRO_BPM, INTRO_ARTIC unchanged.
- The 4-bar pattern continues looping across all 21 panels.
- Per-panel SFX accents are *out of scope* for this overhaul; the existing playable wake script (`start_prologue_castle_intro`) handles all diegetic sounds (distant bell, gate impact, etc.) once the cutscene ends.

## Pacing & input

- Per-panel dwell time, advance behavior, and skip behavior are *unchanged.* Whatever currently advances `cutscene_idx` in the run loop continues to do so.
- The cutscene terminates on the same final-panel transition path it does today; that path drops into `start_prologue_castle_intro`. No state-machine changes.

## Out of scope (deferred)

- Scene-specific SFX beats inside the cutscene (e.g., a bell ring on panel 11, an impact on panel 20). Could be a follow-up pass.
- Character-portrait insets (FF-style head sprites at panel corners). Not in this overhaul.
- A skippable / replayable cutscene menu. Not in this overhaul.

## Risks

- **File size.** `synth-quest.lua` is 24,088 lines; adding ~18 small draw functions adds modest length but no architectural pressure. Locate the new draws adjacent to the existing scene draws (the `cosmic` / `dark` / `throne` block) so the change stays focused.
- **Visual consistency.** Eighteen new scenes is the largest art surface this script has added in one pass. Mitigation: each scene is mono and primitive-based; if any individual scene reads poorly on the OLED in playtest, it can be revised in isolation without touching the panel sequence.
- **Backward compatibility with saves.** None affected — the cutscene plays once on TITLE → CUTSCENE → OVERWORLD and is gated by `prologue_intro_done` afterward; existing saves skip it as before.

## Acceptance criteria

1. New game from a fresh save plays all 21 panels in order, each on its own labeled scene background.
2. Final panel (`lirael_candles_dim`) ends on Miel's chamber with the third candle guttering; the very next thing the player sees is the existing chamber-wake script, opening on the same chamber image.
3. None of the panel text states or implies that Lirael is empty, abandoned, or has been so for any length of time prior to tonight.
4. INTRO music plays continuously across all panels at INTRO_BPM 70 with the existing INTRO_PATTERN.
5. Existing wake script, courtyard breach, throne scene, and all post-prologue gameplay are unchanged.

## Files & locations

- `synth-quest.lua:958` — `CUTSCENE_LINES` table: replace contents with the 21 panels above.
- `synth-quest.lua:22305-22569` — scene-draw function block: append 21 new `draw_scene_<id>` functions adjacent to the existing seven. Do not remove or rename `draw_scene_cosmic` / `draw_scene_dark` / `draw_scene_village` / `draw_scene_threat` / `draw_scene_throne` / `draw_scene_coup` / `draw_scene_passage`.
- `synth-quest.lua:22569` — scene dispatch table: add 21 new entries keyed to the new draw functions.
- `~/dev/synth-quest/backups/` — snapshot `synth-quest.lua` before the pass per the project's backup discipline.
