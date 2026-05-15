# Resonances — Acquisition System & Vertical Slice (Miel)

**Date:** 2026-05-14
**Project:** Synth Quest (norns)
**Affected file (primary):** `synth-quest.lua`
**Related lore:** `story/bible.md:851-942` (the eight Resonances)

## Problem

The story bible defines eight Resonances — named mythic entities the party can call mid-fight, each tied to a synth/effect technique (tape echo, vocoder, spring reverb, ring modulator, sidechain compressor, granular cloud, analog phaser, vintage chorus). The Resonances themselves are designed; how the player **obtains** them is not. This spec defines the acquisition system end-to-end and ships the first Resonance — Miel's — as a vertical slice the rest can copy from.

## Goal

A two-step "sacred item → attune at a shrine" loop, one Resonance per party member, gated to that character only. Build the shared scaffold once; ship Miel's full path (cat → bell → shrine → attune → callable in battle on R2) as the proof. The other seven Resonances become content additions on the same scaffold, in later passes.

## Non-goals

- Filling in the other seven Resonances' item sites, shrines, dialogue, or signature beats. Their data-table entries get stubbed; their world content lands later.
- The actual battle effect execution (`ignore_def_clangor + 1.30x dmg + screen shake` for The Ring, etc.). The R2 button routes the queued Resonance call and consumes MP; the effect itself stubs as a no-op for this spec.
- A Resonances journal page in the pause menu. The pause-menu inventory will list held sacred items with a one-line attune hint, nothing richer.
- Multiple Resonances per character. Spec assumes one each.
- Items moving between characters. The sacred item is bound to its character at find-time; no swapping.

## Party member ↔ Resonance mapping

The bible has eight Resonances; the party has seven (Alder, Miel, Strom, Diegues, Sergei, Paj, Niko) plus an eighth still to be designed: **ECHO**, a Resonance walking in human form (picks up the bible's ECHO stub at `story/bible.md:1202-1205`). ECHO joining the party effectively *is* their Resonance unlocking.

Mapping (the eighth slot fills in when ECHO is designed):

| Slot | Character | Resonance (id) | Bible #
|---|---|---|---|
| 1 | Alder (Bard) | TBD | tbd |
| 2 | Miel (Cleric) | **The Ring** (`ring`) | 4 |
| 3 | Strom (Warrior) | TBD | tbd |
| 4 | Diegues (Mage) | TBD | tbd |
| 5 | Sergei (Engineer) | TBD | tbd |
| 6 | Paj (Theorist) | TBD | tbd |
| 7 | Niko (Drummer) | **The Heavy Hand** (`heavy_hand`) | 5 — drummer myth fits |
| 8 | ECHO | TBD | tbd |

Only Miel (slot 2) and Niko (slot 7) are pinned in this spec — the rest will be assigned in later passes when each character's hometown / item-shape is decided. Niko is pinned because the bible's drummer myth maps too cleanly to ignore. The seven other rows get table entries with `character = "<class>"` and stub fields.

## Architecture

Five pieces, all in `synth-quest.lua`:

1. **`RESONANCES`** — global catalog table. One row per Resonance with `name`, `character` (cleric/warrior/etc.), `mp_cost`, `mythos` line, and an `effect` table. Effect kinds are placeholders for the deferred effect-execution spec.
2. **`RESONANCE_SITES`** — global world-data table. One row per Resonance with `item = {...}` (where the sacred item lives) and `shrine = {...}` (where attunement fires). Each row keys on the same id as `RESONANCES`.
3. **`CONTENT.resonances`** — per-save state. `{ [id] = {item = bool, attuned = bool} }`. Persists in `save.data`.
4. **`start_resonance_attunement(id)`** — shared scaffold function. Drives a parameterized SCENE script (fade, ambient, character spawn, signature visual, signature sound, dialogue, banner, fade out). Per-Resonance overrides come from `RESONANCE_SITES[id].shrine.signature` (visual + sound + dialogue lines).
5. **MAG menu / R2 input wiring.** R2 trigger becomes the queue-RESO input via the existing analog-trigger pattern; battle UI gains a fifth action slot.

## Data model

```lua
-- Catalog (content; one row per Resonance). Defined near the existing
-- battle/SynthDef constants.
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
  -- six more rows: long_echo (bard?), masked_voice (?), spring (?),
  -- scatter (?), slow_wheel (?), threefold (?). Character fields TBD;
  -- entries exist so RESONANCE_SITES + CONTENT.resonances stay aligned.
  long_echo    = { name = "The Long Echo",    character = nil, mp_cost = 4, mythos = "...", effect = {} },
  masked_voice = { name = "The Masked Voice", character = nil, mp_cost = 6, mythos = "...", effect = {} },
  spring       = { name = "The Spring",       character = nil, mp_cost = 4, mythos = "...", effect = {} },
  scatter      = { name = "The Scatter",      character = nil, mp_cost = 4, mythos = "...", effect = {} },
  slow_wheel   = { name = "The Slow Wheel",   character = nil, mp_cost = 4, mythos = "...", effect = {} },
  threefold    = { name = "The Threefold",    character = nil, mp_cost = 8, mythos = "...", effect = {} },
}

-- World data (sites). One row per Resonance.
RESONANCE_SITES = {
  ring = {
    item = {
      kind  = "npc",        -- "npc" | "tile"
      name  = "Tisa",       -- existing cat NPC at map 28 (7, 4)
      lead  = "cleric",     -- only fires when Miel is lead
      label = "Tisa's Bell",
      hint  = "attune at the tapestry alcove",
    },
    shrine = {
      map  = 20,
      x    = 8, y = 2,      -- tapestry alcove tile in throne hall
      lead = "cleric",
      signature = {
        visual = "lirael_bell_alcove",   -- new tiny scene draw helper (see Section: signature beats)
        sound  = { class = "cleric", note = 67, vel = 0.7, attack = 0.05, release = 4.0, wet = 1.0 },
        dialogue = {
          "(Miel turns the small bell in her hand. It is silent.)",
          "[Miel]    Two bell-tuners. They married. Their sound never finished folding.",
          "(she rings it once. Somewhere far off — outside time — the second bell answers.)",
        },
      },
    },
  },
  -- seven more rows, all populated with placeholder stubs (kind="tile",
  -- map=0, x=0, y=0, lead matching their character) so the data table
  -- stays type-consistent. None of them fire because no shrine tile
  -- handler is registered for them yet.
}

-- Per-save state. Initialized for all 8 ids at new-game.
CONTENT.resonances = {
  ring         = { item = false, attuned = false },
  heavy_hand   = { item = false, attuned = false },
  long_echo    = { item = false, attuned = false },
  masked_voice = { item = false, attuned = false },
  spring       = { item = false, attuned = false },
  scatter      = { item = false, attuned = false },
  slow_wheel   = { item = false, attuned = false },
  threefold    = { item = false, attuned = false },
}
```

## Miel's vertical slice — full path

### Step 1: Item find at Tisa (map 28)

The cat `Tisa` is the existing NPC at map 28 col 7 row 4 (defined at `synth-quest.lua:2613-2622`). Today she has a fixed two-line "yellow eye" interaction visible after `prologue_intro_done`. Extend her dialogue function so the response branches on lead and on `CONTENT.resonances.ring.item`:

- `lead ~= "cleric"` → existing two-liner. Tisa never reveals the bell to anyone but Miel.
- `lead == "cleric"` AND `not CONTENT.resonances.ring.item` → new short scene:
  - Tisa stretches, paws something out from under the bed
  - It's a small bell on a frayed ribbon — the one her grandmother sewed onto Tisa's collar
  - Miel takes it; one reflection line
  - Sets `CONTENT.resonances.ring.item = true`
  - Banner: `* obtained: Tisa's Bell *`
- After collected (`CONTENT.resonances.ring.item == true`) → existing two-liner returns; Tisa never mentions the bell again.

### Step 2: Shrine — tapestry alcove (map 20, throne hall)

The throne hall already has a "tapestry escape" tile at row 2 (the secret door Miel uses post-coup, defined in `castle_map` near `synth-quest.lua:2511`). The alcove behind the tapestry — col 8, row 2 — becomes the shrine.

**Shrine trigger:** when the player walks onto map 20 tile (8, 2), check:

```
lead == RESONANCE_SITES.ring.shrine.lead   -- "cleric"
AND CONTENT.resonances.ring.item            -- true
AND not CONTENT.resonances.ring.attuned     -- not yet done
```

If all three pass, fire `start_resonance_attunement("ring")`. Otherwise the tile behaves as the existing tapestry tile.

The tile is reachable post-prologue. Acceptable for this spec. (Future: if narrative needs to gate this to a later act, add an act check.)

### Step 3: Attunement scene

Driven by the shared scaffold `start_resonance_attunement(id)`. See next section for the scaffold; the Miel-specific overrides are the `signature` block in `RESONANCE_SITES.ring.shrine`.

After the scene: `CONTENT.resonances.ring.attuned = true`. The bell stays in inventory as a memento (display-only — does nothing further).

### Step 4: Battle availability

Miel's R2 input now queues `THE RING` whenever she's the active character with ≥ 6 MP. See "Battle integration" section for the wiring.

## Shared attunement scaffold

```lua
function start_resonance_attunement(id)
  local r = RESONANCES[id]
  local s = RESONANCE_SITES[id].shrine
  local sig = s.signature
  -- Build a SCENE script using the existing SCENE engine. Sequence:
  --   letterbox_in -> fade dim -> spawn the character at the shrine,
  --   facing the alcove -> hold one beat -> play signature.sound ->
  --   draw signature.visual under the alcove for ~30 ticks -> dialogue
  --   (sig.dialogue) -> banner "* Resonance learned — <name> *" ->
  --   set attuned=true -> fade out -> letterbox_out
  -- All steps are SCENE.start({...}) primitives already implemented.
end
```

The scaffold is invariant across all 8 Resonances. Each `signature` table contributes:

- **`visual`** — a string id matched to a small scene-draw helper (e.g., `"lirael_bell_alcove"` for Miel: a slow-swinging bell silhouette growing over the alcove tapestry). New helpers live alongside the existing `draw_scene_*` block at `synth-quest.lua:22305-23139` but are *short* (one to two dozen primitives — the alcove already has a base render).
- **`sound`** — a SCENE `sfx` opts table (class, note, vel, attack, release, wet). Played once at the signature beat.
- **`dialogue`** — three lines, character-specific.

Only one signature helper (`draw_scene_lirael_bell_alcove`) is added in this spec; the other seven scenes' helpers don't exist yet and the scaffold simply skips the visual step if `RESONANCE_SITES[id].shrine.signature.visual == nil`.

## Battle integration

### R2 input

The SN30 Pro X-input profile reports L2/R2 button events unreliably (`feedback_synth_quest_*` notes that L2/R2 buttons-events are stuck at 0). The existing L2-toggle pattern uses `gamepad.analog("triggerleft", val)` with rising-edge detection. R2 mirrors this with `gamepad.analog("triggerright", val)`.

Add an R2 rising-edge handler in the same place L2 is handled. On rising edge (val crosses ~0.5 going up):

- If `game_state ~= "BATTLE"` → no-op (R2 only does anything in battle for now)
- Else find the active character's class. Look up the Resonance attuned to that class:

  ```
  local id = nil
  for rid, r in pairs(RESONANCES) do
    if r.character == active.class
       and CONTENT.resonances[rid].attuned then
      id = rid; break
    end
  end
  ```

- If no `id` (no attuned Resonance for this character) → short "unavailable" feedback, no queue
- Else if `active.mp < r.mp_cost` → "not enough MP" feedback, no queue
- Else queue the action with kind = "RESO" and id = id (parallel to how A queues `kind = "ATK"`); deduct MP at queue time exactly the way the existing MAG cost works

### Battle UI

The on-screen action label area currently shows ATK / DEF / MAG / ITM for the active character. Add a fifth slot: RESO with the attuned Resonance name (or the placeholder `--` when none attuned). The label area renders in the existing battle-HUD draw block — a single-row addition.

### Effect execution (deferred)

When a queued RESO action fires (action's tick lands), the battle engine reads `RESONANCES[id].effect.kind` and dispatches. For this spec, the dispatcher is a stub:

```lua
function apply_resonance_effect(id, source)
  -- TODO (separate spec): dispatch on r.effect.kind to the actual
  -- combat behavior (echo trail, ducking, ignore_def_clangor, etc.)
  -- For now: deal a no-op damage echo (reuse a normal ATK with the
  -- character's current weapon at 1.0x dmg) so the action consumes
  -- a turn and feels like SOMETHING happened.
end
```

The MP is still consumed; the queue still ticks; the player sees the action fire. The actual effect lands in a follow-on spec.

### Feedback when RESO fires

So the player can tell the call happened (even with the stub effect): on RESO action tick, play `RESONANCE_SITES[id].shrine.signature.sound` once and flash a brief banner with the Resonance name (`* The Ring *`) at top of HUD for ~30 ticks. Reuses the existing banner-flash primitive used by the prologue scenes.

## Save format & migration

`CONTENT.resonances` joins the existing save fields under `CONTENT`. Format:

```lua
CONTENT.resonances = {
  ring         = { item = true,  attuned = false },
  heavy_hand   = { item = false, attuned = false },
  -- ... 6 more ...
}
```

**Migration on load:** if `CONTENT.resonances == nil`, initialize the full table with all 8 ids set to `{item = false, attuned = false}`. Existing saves continue working as if no Resonances had been collected.

## Inventory display (pause menu)

The pause-menu inventory iterates `CONTENT.resonances` and renders one line per `[id].item == true` entry:

```
Tisa's Bell   — attuned
Drummer's Coin — attune at <hint>
```

Where `attuned` shows when `[id].attuned == true`, and the `<hint>` text comes from `RESONANCE_SITES[id].item.hint`. No on-tile interactions in the menu — display only.

## Files & locations

- `synth-quest.lua:~400` (near existing battle/synth constants) — add `RESONANCES` and `RESONANCE_SITES` tables.
- `synth-quest.lua:2613-2622` — extend Tisa's dialogue function with the lead-aware branch.
- `synth-quest.lua:2511` (castle_map area) — no map change; the tapestry tile (8, 2) on map 20 already exists. Add a per-tile shrine handler.
- `synth-quest.lua:~5130` (alongside existing prologue scene helpers) — add `start_resonance_attunement(id)`.
- `synth-quest.lua:~22305` (alongside existing `draw_scene_*` block) — add `draw_scene_lirael_bell_alcove`.
- `synth-quest.lua` — wherever L2 trigger handling lives — add the R2 rising-edge mirror.
- `synth-quest.lua` — wherever `CONTENT` is initialized at new-game and wherever save/load happens — add the `CONTENT.resonances` init + migration.
- `synth-quest.lua` — wherever the battle-HUD action labels render — add the fifth label.
- `synth-quest.lua` — wherever the pause-menu inventory renders — add the held-items section.
- `~/dev/synth-quest/backups/` — snapshot before the pass per project convention.

## Acceptance criteria

1. New game from a fresh save: `CONTENT.resonances` initializes with all 8 ids, all flags false.
2. Walking up to Tisa as Miel (lead = cleric) for the first time triggers the bell scene; banner shows; `CONTENT.resonances.ring.item == true` afterward.
3. Walking up to Tisa as any other lead shows the existing two-liner; the bell scene does not fire.
4. Walking onto map 20 tile (8, 2) as Miel with the bell held triggers the attunement scene; banner shows "Resonance learned — The Ring"; `CONTENT.resonances.ring.attuned == true` afterward.
5. Walking onto map 20 tile (8, 2) as Miel without the bell does nothing extra (existing tapestry behavior).
6. In battle with Miel active and ≥ 6 MP, pressing R2 queues a RESO action and deducts 6 MP. The on-screen action label shows "RESO — The Ring".
7. In battle with Miel active and < 6 MP, R2 shows "not enough MP" feedback and does not queue.
8. In battle with any non-cleric character active, R2 shows "unavailable" feedback (no other class has an attuned Resonance in this spec).
9. Save → quit → reload → confirm `CONTENT.resonances.ring.item` and `.attuned` round-trip.
10. Loading an old save (`CONTENT.resonances == nil`) initializes the table to all-false without crashing.

## Risks

- **R2 trigger reliability.** L2/R2 button events are unreliable on this profile — mitigated by using the analog-trigger rising-edge pattern that already works for L2 + BPM. If R2 has its own quirks, may need per-controller calibration.
- **Tile (8, 2) on map 20 is the tapestry escape tile.** Adding a shrine trigger there could conflict with the tapestry-escape behavior (used post-coup as Miel's exit route). Verify the tapestry escape sequence still fires when expected; gate the shrine trigger behind `lead == "cleric" AND has_bell` so it doesn't interfere with the escape when the conditions aren't met.
- **Stub effect feels meaningless.** A RESO call that does normal-ATK damage may underwhelm in playtest. Acceptable for now (this spec ships acquisition only); plan the effect-execution spec immediately after.
- **Eight rows in `CONTENT.resonances` for one Resonance.** Slight code overhead for keeping the table shape consistent. Worth it — saves migration churn when later Resonances land.

## Out of scope (deferred)

- The other 7 Resonance attunement scenes (item sites, shrine sites, signature beats, dialogue).
- Real combat-effect execution for any Resonance.
- Resonances journal page in pause menu.
- Multiple Resonances per character.
- A "renounce/swap" Resonance flow.
- Hint dialogue from NPCs about where the shrines are.
