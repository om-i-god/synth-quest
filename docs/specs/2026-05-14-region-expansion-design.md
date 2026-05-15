# Synth Quest — Region Expansion (Design)

Date: 2026-05-14
Status: DRAFT — pending user review before implementation planning.

## Summary

Expand the Synth Quest world with **5 new maps across 4 regions**, each deeply built with hand-authored tile grids, 6-10 NPCs (each with party-aware `lead == "<class>"` dialogue), multiple scripted scenes, scripted ambient micro-scenes, and a new music theme. Regions ship one at a time (Approach B). Gating respects the bible's act structure: Lirael Ruins is locked behind a story flag; the rest are reachable from launch.

The pass resolves 11 of 18 named-NPC stubs in the bible, canonizes new content into `story/bible.md` as each region ships, and snapshots both `synth-quest.lua` and `bible.md` to `~/dev/synth-quest/backups/` after every region per the standing rule.

## Scope (locked)

| Item | Decision |
| --- | --- |
| Number of regions | 4 (5 maps total) |
| Map size | 28-40w × 14-18t per map (~400-700 tiles); Lirael multi-zone single map |
| NPC count | 6-10 per region (mostly 7-8) |
| Scene depth | Multiple signature scenes + scripted ambient per region |
| Music themes | 5 new compositions (one per map; Academy + Observatory each distinct) — 2 are entirely new theme strings, 3 replace existing placeholders |
| Gating | Lirael gated by `flag.lirael_unlocked`; others open at launch |
| Ship cadence | Approach B — region by region, snapshot after each |
| Order | Sunward Coast Town → Phrygian Night City → Sage Hub → Lirael Ruins |

## Architecture & Integration

The codebase already supports everything this pass needs; no new engine systems are introduced.

**Map data**: each new region is a new 2D table (`SUNWARD_COAST_MAP`, `PHRYGIAN_CITY_MAP`, `LIRAEL_MAP`, etc.) added to the map-table block near line 4753. Existing `ACADEMY_MAP` (id 19, currently 10×9 stub) and `OBSERVATORY_MAP` (id 24, currently stub) are expanded in place.

**Map IDs**: Sunward Coast Town = **id 35**, Phrygian Night City = **id 36**. Academy keeps id 19, Observatory keeps id 24, Lirael Ruins keeps id 23 (all three currently exist as 10×9 or smaller stubs; this pass expands them in place).

**Routing**: each new map gets entry/exit logic in `step_player()`.
- Sunward Coast Town: hooks off MAINLAND east coast adjacent to Tide Cavern (Cave 3) entrance.
- Phrygian Night City: hooks off EASTERN_REACHES, gateway to Glass Cavern (Cave 4).
- Academy: hooks off Western Region (id 22).
- Velthe's Observatory: hooks off Northern Wilds (id 3) approach, near (but not connected to) Cave 6 until Velthe's Final Entry scene fires.
- Lirael Ruins: hooks off Western Region (id 22), gated by `flag.lirael_unlocked`.

**NPC tables**: each region gets its own `*_NPCS` table following the existing convention: `{x, y, name, visible, scene, dialogue, barks, kind}`. Each NPC's `dialogue` function reads `lead = party[active].class` and returns class-specific lines.

**Music**: five new compositions. The theme-string function (line 11429-11454) currently returns `"academy"`, `"observatory"`, `"lirael"` as placeholder strings for the existing stub maps. This pass **replaces** those three placeholders with composed themes and **adds** two new strings: `"sunward_coast"` and `"phrygian_city"`. Net new strings in the music-theme function: 2. Total OW_THEMES entries to author or rewrite: 5.

**Encounters**: each region's encounter spawn rules added to tables at lines 11707 and 11967. Reuse existing enemy types where mode/biome matches; no new enemy types required for this pass.

**Tile types**: ~15 new tile codes for region-specific aesthetics. Each new tile gets a `draw_<tile>(px, py, t)` function near line 15850+.

**Scenes & particles**: scripts written as standard SCENE arrays. Each region gets its own ambient particle drift (sea spray, dust, ash, etc.) added to the PARTICLES region selector.

**No new SCENE engine primitives required.** Existing verbs (camera focus, letterbox, actor move, look, bump, dialogue, fade, sfx, shake, teleport, set) cover every planned scene.

## Gating & Flags

New story flags added to the save state:

```
flag.lirael_unlocked        = false   -- requires 4+ shards AND Veiled Mystic spoken
flag.veiled_mystic_spoken   = false   -- set on Phrygian Night City dialogue
flag.iolas_letter_received  = false   -- set on Iola's Letter scene (Academy)
flag.velthes_entry_heard    = false   -- set on Velthe's Final Entry (Observatory)
flag.broken_cadence_done    = false   -- set after Lirael boss fight
flag.bandstand_done         = false   -- set on Sunward Coast bandstand scene completion
flag.strom_confronted       = false   -- set on Phrygian City Aram confrontation
flag.diegues_returned       = false   -- set on Academy first-entry scene
```

Flag dependencies:
- **Lirael unlock**: `(shard_count >= 4) AND flag.veiled_mystic_spoken`
- **Cave 6 approach unlock**: `flag.velthes_entry_heard`
- **Velthe's Final Entry**: requires `flag.iolas_letter_received`
- **Iola's Letter scene**: requires `shard_count >= 3` AND player has visited Academy at least once
- **Iola location**: at Academy until `flag.velthes_entry_heard`; at Observatory thereafter

A debug toggle `flag.unlock_all` (off by default; manual save edit) bypasses all gates for testing.

## Region 1 — Sunward Coast Town

### Map
Size: ~32×16. New `map_id`: **35**.

Layout:
- **South edge**: open water + sea cliff.
- **South-center**: wood docks projecting into the harbor.
- **Center**: market square north of the docks.
- **East side**: tavern + bandstand (the cultural heart).
- **West cluster**: small residential houses.
- **East exit**: path to Tide Cavern (Cave 3).

New tile types: `wood_dock`, `tavern_floor`, `bandstand`, `fish_barrel`, `market_stall` (shared with Phrygian).

### NPCs (8)

1. **Mara** — Harbormaster's widow; runs the bandstand. Bard-lead: invites Alder to perform tonight. Cleric-lead: asks Miel to bless the stand. Universal: shop-like dialogue offering rumor.
2. **Hask** — tavern keeper, gossip-monger. Warrior-lead: recognizes Strom's old Suno-issued harness scar. Mage-lead: comments on Diegues' bookish look. Universal: sells warm drinks (HP item).
3. **Coral** — 12-year-old aspiring singer. Bard-only side scene: asks Alder for a lesson.
4. **Beck** — fisherman; tells the player where Tidewatch's cadence first echoed at low tide. Warrior-lead: tries to recruit Strom to haul nets.
5. **Wynne** — traveling bard, passing through. References the Harbormaster's old duels; Bard-lead: trades a Mixolydian fragment with Alder.
6. **Pell** — market fishmonger; shop NPC selling salted fish + healing items.
7. **Vesa** — Sage Circle outpost archivist; records every visiting singer's name. Mage-lead: references Velthe and Iola (Sage Hub tie-in seed).
8. **Iolen** (from bible stub list) — tide-watcher kid who idolizes Strom. Warrior-lead: gives Strom a "tide tally" stone (passive accessory).

### Signature scenes (2)

1. **Arrival**: triggered on first entry from east coast path. Camera pans across harbor at sunset. Mara on the bandstand tunes her lute. She names the town, mentions the Harbormaster, gestures toward Tide Cavern. Sequence: letterbox in → camera pan → dialogue → letterbox out.

2. **The Bandstand Performance**: Bard-lead + night-tile trigger near bandstand. Alder spawns onstage; Mara hands him a lute; he plays a 4-bar SFX sequence; 6 townsfolk actors spawn around the bandstand bobbing in time; Mixolydian motif from Cave 3 echoes. Sets `flag.bandstand_done`. **Reward: +1 MAG permanent to Alder.**

### Ambient micro-scenes (4)

1. **Bandstand tile (day)**: brief flute trill + caption "(someone is practicing inside)".
2. **Dock-end tile**: distant gull call + Mixolydian motif fragment.
3. **Market center tile**: vendor cry typewriter caption ("FRESH MORNING CATCH —").
4. **Cliff-edge tile**: wind through reeds + Tidewatch echo motif (foreshadows Cave 3 if not yet done; reflects on it if already done).

### Music theme — `"sunward_coast"`
Bright Mixolydian with flat-7th lift; fiddle ostinato + soft hand-drum + bandstand chorus pad. Differentiated from existing `"coast"` (more communal/sung).

### Encounters
Town perimeter only (overworld approach): Crab, Manta, Sea Wisp (existing types). Town interior is safe.

## Region 2 — Phrygian Night City

### Map
Size: ~36×16. New `map_id`: **36**.

Layout:
- **Southern gate**: facing the caravan road from Eastern Reaches.
- **Central bazaar / night market**: lantern-lit, lined with stalls, the city's heart.
- **Eastern tower district**: sand-brick towers, residential.
- **Western temple quarter**: small drone-prayer house.
- **Northern gate**: exit toward Glass Cavern (Cave 4).

The city reads dim and warm; lanterns are the primary light source.

New tile types: `sand_brick`, `tower_base`, `prayer_alcove`, `desert_sand_path` (plus reused `market_stall`, `lantern_post`).

### NPCs (8)

1. **Aram** — Phrygian war-veteran, Strom's former second-in-command. Warrior-lead: triggers Strom Confronted scene. Other leads: oblique grief lines.
2. **Sergei** (from stub list) — glass-cavern guide; offers to escort party through the dunes to Cave 4.
3. **Mira** (from stub list) — drone-singer in the bazaar. Bard-lead: teaches Alder a microtonal motif (adds one note to his PLAY arpeggio).
4. **Brann** (from stub list) — caravan master, shop NPC selling Phrygian items (sand-cured trinkets, water flasks).
5. **Tova** — already in code (Mage-aware). Sage Circle outpost scribe. Mage-lead: references Velthe's last letters; seeds Sage Hub.
6. **The Veiled Mystic** — drone-speaker; gives a cryptic prophecy about the Held Chord. Cleric-lead: Miel recognizes her as a former Aeolian acolyte who walked east after Lirael fell. **Sets `flag.veiled_mystic_spoken` on conversation completion.**
7. **Lantern-keeper child** — lights torches at dusk; idle and curious. Bard-lead: asks Alder about Sunward Coast.
8. **A young scout** — would-be follower. Warrior-lead: asks if Strom is taking apprentices. Cleric-lead: asks Miel if war ever ends.

### Signature scenes (2)

1. **Arrival at dusk**: party crests the dune-line; city silhouette appears as sun sets. Camera slow-pan across the towers; lanterns light one by one (sequential SCENE `set` steps); Mira's drone rises from the bazaar (layered SFX). Sergei at the gate: "Stay close after the gate closes. Phrygian night is not for visitors who wander."

2. **Strom Confronted**: Warrior-lead at bazaar tile near Aram's stall. Aram steps out. Camera focus on the two. Dialogue: "You were my second. You ran." Strom gets two response choices (cosmetic but emotionally weighted). Resolution: Aram either walks away (forgiveness path) or initiates a 1-bar parry mini-mechanic (single CALL/RESPONSE beat). Either resolution: +5 MaxHP permanent to Strom + item **Aram's Token** (passive accessory). Sets `flag.strom_confronted`.

### Ambient micro-scenes (4)

1. **Bazaar center tile**: vendor cry typewriter caption ("STAR-OIL — TWO BLOSSOMS —").
2. **Tower-base tile**: distant call-to-prayer (microtonal vocal SFX, no actor).
3. **Lantern-post tile at night**: lantern flickers + brief shadow play (1-tick `shake` + brief fade).
4. **Sage Circle outpost door tile**: Tova humming a Velthe melody (motif foreshadow).

### Music theme — `"phrygian_city"`
Drone-based, microtonal. Bass drone (sustained) + ney-flute lead playing the flat-2 motif + irregular percussion that refuses to settle on a downbeat. Same theme day/night, but percussion layer drops out at night.

### Encounters
City perimeter and caravan road only: Scorpion, Sand Manta, Dune Wolf. City interior is safe.

## Region 3 — Sage Hub (Academy + Velthe's Observatory)

The paired region. Two maps connected by an in-fiction footpath from Western Region to the northern approach.

### Academy (existing `map_id 19`, expanding to ~28×14)

Layout:
- **South**: entry hall + reception.
- **East**: main library / archive (Diegues' old haunt).
- **West**: dormitory wing with three small bedrooms.
- **North**: lecture hall + Iola's office.
- **Center**: stone courtyard with a tall astrolabe.

New tile types: `bookshelf_tall`, `astrolabe`, `desk_with_papers` (shared with Observatory), `lectern`.

**NPCs (6)**

1. **Iola** — Velthe's last apprentice, senior scholar. Lore anchor. Mage-lead: full Velthe-era backstory; gives Diegues a sealed letter after 3+ shards.
2. **Master Theron** (new) — Academy headmaster. Mage-lead: recognizes Diegues' notation. Cleric-lead: formally blesses Miel.
3. **Aurin** (from stub list) — junior scholar. Bard-lead: wants to write a treatise on troupe music. Warrior-lead: visibly afraid of Strom.
4. **Paj** (from stub list) — librarian; shop NPC selling books/scrolls as MP/MAG-boost items. Mage-lead: recommends Velthe's late volumes.
5. **Wena** (from stub list) — dormitory student, midnight philosopher. Cleric-lead: asks Miel about Aeolian theology.
6. **Echo** (from stub list) — semi-transparent figure near the courtyard astrolabe; speaks only in Velthe-fragments. Mage-lead: unlocks a hidden Velthe note in the library.

**Signature scenes (2)**

1. **Diegues Returns** — Mage-lead, first entry. Camera focus on Diegues in the courtyard. Students cluster. Iola descends from her office. Brief reunion dialogue. Echo murmurs a Velthe fragment. Sets `flag.diegues_returned`.

2. **Iola's Letter** — requires `shard_count >= 3` AND `flag.diegues_returned`. Iola finds Diegues in the library; hands him Velthe's sealed letter ("to whoever finds the Locrian shard"). Typewriter dialogue; Velthe's voice fades in over final lines (layered SFX). Sets `flag.iolas_letter_received`. **Unlocks the Observatory's `crypt_stair` tile.**

### Velthe's Observatory (existing `map_id 24`, expanding to ~24×14)

Layout:
- **Lower level**: entry chamber + Velthe's study (desk + chair preserved).
- **Upper level (via internal stair)**: telescope chamber with broken roof open to the sky.
- **Locked `crypt_stair` tile** in the lower level: secret stair toward the Locrian Crypt approach. Locked until `flag.iolas_letter_received`. Becomes interactable only after Velthe's Final Entry fires.

New tile types: `telescope_broken`, `crypt_stair` (initially locked). Reused: `desk_with_papers`, `bookshelf_tall`.

**NPCs (3)**

1. **Iola** — present here only after `flag.velthes_entry_heard`. Before that flag, she remains at the Academy. Mage-lead at the desk: shows Diegues Velthe's marginalia.
2. **The Caretaker** — kept the Observatory since Velthe vanished. Universal lead: tells the player Velthe's last spoken words ("the third chord is not a chord").
3. **A trapped Sage Circle scout** — pinned under fallen rafters on the upper level. Minor side scene: fetch medicine from Iola at the Academy. Bard-lead variant: Alder sings her free.

**Signature scenes (2)**

1. **The Caretaker's Tour** — arrival scene. Caretaker walks the party through both levels. Camera pans up to telescope roof; star-chart particle drift overhead. Explains Velthe's twelve years of observations before her disappearance.

2. **Velthe's Final Entry** — triggered by stepping on Velthe's desk tile, requires `flag.iolas_letter_received`. Velthe's voice imprint manifests at the desk (semi-transparent actor). Reads her last entry aloud. **Mentions Locrius by name.** Sets `flag.velthes_entry_heard` → unlocks `crypt_stair` tile → unlocks Cave 6 approach. Mage-lead variant: Diegues finishes the entry in his own voice.

### Sage Hub ambient micro-scenes (4, distributed)

1. **Academy library tile**: a student reading aloud, caption "(she's reading Velthe's third volume)".
2. **Academy courtyard tile under astrolabe**: ticking + Echo's whisper. Mage-lead variant: Diegues hears a clearer line.
3. **Observatory roof tile at night**: stars visible + brief Locrian motif fragment.
4. **Observatory desk tile (before Velthe's Final Entry fires)**: paper rustles + caption "(Velthe's handwriting is still drying — impossible)".

### Music themes — 2 distinct

- `"academy"` — scholarly ostinato; busy, lightly polyphonic; hand-drums + clave + bowed bass; diatonic-leaning. Suggests an institution full of activity.
- `"observatory"` — slow Locrian drift; single sustained pitch with detuned partials wandering above; sparse, wide, cold. Under 4 notes per bar.

### Encounters
Academy interior: safe. Observatory exterior approach: light Locrian-edge — Husk, Flat-Bird, occasional Crow Wraith. Observatory interior: safe but with a single Crow Wraith encounter possible in the upper room (flavor fight).

## Region 4 — Lirael Ruins (gated)

### Map
Size: ~40×18, single `map_id 23` (existing reserved ID, expanding from stub). Multi-zoned visually on one grid.

Layout (four distinct zones on the same grid):
- **South (rows 13-18): The Burned Streets** — entry. Cobble + ash + rubble. Broken merchant houses. Sea cliff on south edge with pale blue water below.
- **Center-north (rows 4-12, cols 14-32): The Ruined Nave** — cathedral interior. Broken pillars, debris, ash falling overhead. Broken altar at the north edge.
- **Northwest (rows 4-8, cols 1-13): The Royal Quarters** — Miel's childhood rooms; partly intact, last Lirael-blue paint.
- **East (rows 4-12, cols 33-40): Side Chapel + Library** — small, intimate; half-burned hymnal open on a stand.

New tile types: `ash`, `rubble`, `cathedral_pillar`, `sea_cliff_edge`, `broken_altar`, `hymnal_stand`, `child_toy`, `lirael_blue_brick`, `cathedral_door`.

### NPCs (7 — sparser, ruins should feel still)

1. **Bren** (Lirael steward; renamed from stub-Brann to avoid duplicate with Phrygian's Brann) — refused to leave after the fall. Cleric-lead: recognized Miel's mother by sight; walks the party through the cathedral.
2. **Page** (from stub list) — surviving royal child hiding in the royal quarters. Cleric-lead: clings to Miel, asks if the queen is coming back.
3. **Winna** (from stub list) — court librarian trying to recover the cathedral library. Universal lead: gives a piece of the queen's correspondence (lore item).
4. **The broken chorister** — survivor; sings only one line over and over. Bard-lead: Alder finishes her line for her, briefly restoring her; she names two of her dead choirmates.
5. **Lirael's Last Captain of the Guard** — wounded, dying near the cathedral entrance. Warrior-lead: Strom holds his hand while he passes; the Captain gives Strom a Lirael military insignia (passive accessory).
6. **A Sage Circle archivist** — sent from the Academy by Iola to salvage the cathedral library. Mage-lead: Diegues recognizes them from his Academy days; shares a sealed Velthe note.
7. **The Queen's Echo** — ghostly figure in the royal quarters. Manifests only during the Miel Walks Alone signature scene. Not a standing NPC.

### Signature scenes (2)

1. **Miel Walks Alone** — triggered when the party first approaches the cathedral entrance (ANY lead). Other three party members hold back at the doorway (`hide_player` for them). Miel steps forward; camera follows her in a slow third-person tracking pan into the nave. Overworld music ducks to silence. She kneels at the broken altar. One line — *"Mother. I'm here."* — typewriter. Long fade. Queen's Echo briefly manifests behind her (semi-transparent, no dialogue). After this scene, Royal Quarters door becomes accessible.

2. **The Broken Cadence** — Miel-lead OR auto-triggered after Miel Walks Alone, at broken altar tile. Chorister figure rises from the altar. She names Miel as the queen's daughter. Fight begins per bible mechanic: phrases end one note short until the player forces resolution (Bard PLAY on the final beat). On defeat, she crumbles to ash; her hand drops **KEY OF LIRAEL** — unlocks Ice Grotto entrance in Northern Wilds (gates Cave 5). Sets `flag.broken_cadence_done`.

### Ambient micro-scenes (4)

1. **Burned Streets tile** near a collapsed merchant house: child's toy on the cobble + caption "(it still has Lirael blue paint on it)".
2. **Royal Quarters window tile**: wind through broken glass + brief Aeolian motif fragment. Cleric-lead variant: Miel hums along involuntarily.
3. **Cathedral pillar tile (any)**: ash falls + caption "(the cathedral was singing when it fell)".
4. **East chapel hymnal-stand tile**: Cleric-lead only — caption "(I taught my first verse from this page)".

### Music theme — `"lirael"`
Aeolian dirge. Solo voice (long sustained notes) + low cello-like drone + occasional bell tolls. No percussion. Slowest tempo of all six new themes. **After `flag.broken_cadence_done`, the theme shifts subtly to add one returning voice** — callback to "every recovered shard adds one voice." Shift persists across return visits via the existing save flag system.

### Encounters
Minimal. Streets are encounter-free (pure narrative space). Cathedral nave has sparse Acolyte and Broken Choir spawns (existing types) — never more than 1-2 enemies per encounter.

### Gating
Lirael Ruins is unreachable until `flag.lirael_unlocked = (shard_count >= 4) AND flag.veiled_mystic_spoken`. Until both fire, the path tile from Western Region toward Lirael shows: *"The road west is closed in mourning. No one passes."*

## NPC Stub Resolution

This pass canonizes 11 of 18 named-NPC stubs from the bible by placing them and writing backstories. After each region ships, `story/bible.md` is updated to move each placed NPC from STUB → IN CODE (with backstory). The bible's NAMED CAST section is updated entry-by-entry.

| Stub | Region | Role |
| --- | --- | --- |
| Iolen | Sunward Coast | Tide-watcher kid, Strom-aware |
| Sergei | Phrygian City | Glass-cavern guide |
| Mira | Phrygian City | Drone-singer in bazaar |
| Brann | Phrygian City | Caravan master (shop) |
| Aurin | Academy | Junior scholar |
| Paj | Academy | Librarian (shop) |
| Wena | Academy | Dormitory philosopher |
| Echo | Academy | Astrolabe-bound Velthe-fragment |
| Page | Lirael | Surviving royal child |
| Bren (renamed from Brann to avoid duplication) | Lirael | Lirael steward |
| Winna | Lirael | Court librarian |

**Remaining stubs not resolved this pass** (still STUB): Capt. Ren, Iska, Niko, Lutist, Reya, Rider, Wanderer.

## Implementation Notes

- **Each region ships as a discrete batch**, snapshotting `synth-quest.lua` AND `story/bible.md` to `~/dev/synth-quest/backups/` after the region is compile-checked and deployed.
- **Bible updates per region**: as each region ships, its new NPCs and lore additions are written into `story/bible.md` in the same pass. The standing rule (`feedback_synth_quest_lore_sync`) requires this.
- **Music composition** ships last per region — after map + NPCs + scenes are working, so each theme can be auditioned in context.
- **Party-aware dialogue** must follow the existing `lead == "<class>"` convention; every NPC who could plausibly know a party member needs a branch (per `feedback_npc_party_aware`).
- **Lua local declarations**: with ~30 new NPCs across 5 maps, NPC tables must be declared `local` at the top of their section (per `feedback_lua_local_scoping`) to avoid silent global fall-through.
- **Debug toggle**: `flag.unlock_all = true` (off by default) bypasses all gates during playtesting.
- **Map ID allocation** done at implementation time (next free slot from 35).

## Risks

1. **File size**: `synth-quest.lua` is ~1MB. This pass adds ~80-120KB. Likely stays under 1.2MB; worth tracking. If performance suffers on norns, may need to split lua into requires (out of scope for this pass).
2. **Music quality**: 5 new theme compositions is the largest creative lift. A theme that doesn't gel hurts its region. Mitigation: theme is the last step per region, audition in context.
3. **Dialogue surface area**: ~30 NPCs × 4 leads ≈ 120 dialogue branches. Typo and stale-branch risk. Mitigation: per-region playtest pass with each lead before snapshot.
4. **Gating bugs**: if `flag.lirael_unlocked` chain breaks, Lirael becomes inaccessible. Mitigation: `flag.unlock_all` debug toggle.
5. **Encounter balance**: new regions overlap existing biome stats; existing enemy scaling may not fit. Mitigation: tune in per-region playtest.
6. **Lua scoping gotcha**: shared state across input handlers needs `local` declarations at the top of the state section.

## What This Spec Does NOT Cover

- **Cave 6 interior implementation** (Locrian Crypt + Observatory upper level mid-boss "The Tritone"). Velthe's Final Entry unlocks the *approach* but the actual Cave 6 interior content is a future pass.
- **Ice Grotto / Snowgaunt fight** in Northern Wilds. The Key of Lirael unlocks the *entrance* but the Cave 5 interior is a future pass.
- **Kael of the Second Voice** appearance in Lirael. Mentioned in bible canon but not implemented this pass; she remains STATUS: PLANNED.
- **Resonances system**. Out of scope; remains worldbuilding only.
- **Remaining NPC stubs** (Capt. Ren, Iska, Niko, Lutist, Reya, Rider, Wanderer). Future passes.

## Acceptance Criteria

Per region:
- Map tile data renders correctly without out-of-bounds artifacts.
- All NPCs present and party-aware-dialogue verified for all four leads.
- Both signature scenes play to completion without softlock; flags set on completion.
- All 4 ambient micro-scenes fire when expected; do not retrigger inappropriately.
- Music theme plays on entry; does not bleed into adjacent maps.
- Encounters fire at expected biome rates; existing enemy scaling is acceptable.
- Snapshot of `synth-quest.lua` AND `bible.md` exists in `~/dev/synth-quest/backups/` with timestamp matching the region's ship.

Across pass:
- Lirael Ruins unreachable until `(shard_count >= 4) AND flag.veiled_mystic_spoken`.
- Velthe's Final Entry unlocks the Cave 6 approach.
- Iola correctly migrates Academy → Observatory after `flag.velthes_entry_heard`.
- 11 NPC stubs resolved in bible with backstories.
- `synth-quest.lua` file size under 1.3MB.

## Decisions Log

| Decision | Choice |
| --- | --- |
| Scope size | 4 regions / 5 maps deeply built |
| Regions | Lirael Ruins, Sage Hub (Academy + Observatory), Sunward Coast Town, Phrygian Night City |
| Scene depth | Multiple signature scenes + scripted ambient per region |
| Gating | Lirael gated; others open |
| Music count | 5 theme compositions (Academy + Observatory each distinct; 2 new strings + 3 replacing placeholders) |
| Map size | Large town-scale (28-40w × 14-18t); Lirael multi-zone single map |
| NPC density | 6-10 per region (mostly 7-8) |
| Ship cadence | Approach B — region by region, snapshot after each |
| Region order | Sunward Coast → Phrygian City → Sage Hub → Lirael |
| Velthe's Final Entry | Unlocks Cave 6 approach |
| Iola location | Academy until `velthes_entry_heard`, Observatory thereafter |
| Bandstand reward | +1 MAG permanent to Alder |
| Strom Confronted reward | +5 MaxHP permanent + Aram's Token accessory |
