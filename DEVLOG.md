# Synth Quest — Devlog

## 2026-05-02 — Animation, dialogue, sidequests, jam mode

A wide pass touching combat polish, world feel, story, and a new live-tweak mode.

### Animation polish
- **Per-action firing fx** — every battle action now plays its own short
  animation on the HUD sprite: ATK = comet trail to enemy + slash mark, MAG =
  vertical bolt + sparkle starburst, PLAY = floating note glyphs, BLK = thick
  shield outline pulse, DEF = expanding diamond, ITM = `+` cross + corner
  sparkles.
- **Floating damage numbers** — every hit (player or enemy) spawns a number
  that rises and fades. Crits show in hot color (lvl 13).
- **Critical hits** — 10% chance for ATK/MAG to deal 2× damage with a brighter
  popup.
- **Enemy attack projectile** — a small bright dot travels from the enemy
  sprite to the targeted party member's HUD column, arriving as the damage
  lands.
- **Region-specific battle backgrounds** — subtle moving texture per cave:
  cave drips, drifting leaves, water shimmer, sand grains, snowflakes, void
  streaks, and glyph flicker for Suno's chamber.
- **Hit flash redesigned** — the white-square invert was obscuring the sprite;
  now it's a bright outline + four corner sparks (sprite stays visible).
- **Living tile motion** — grass tufts breathe with a 1-px sway out of phase
  per tile, oak canopies sway gently, the inn chimney trails a smoke wisp.

### UI polish
- **Tighter battle HUD** — HP shows current/max again at smaller font_size 5;
  HP and ATB bars trimmed to 1 px tall. Queued action label sits below the
  bars at native size 6.
- **Smaller enemy info** — enemy name on the top-left of the scene (next to
  the action popup), HP `X/Y` on the top-right, 50×1-px HP bar between them;
  enemy sprite center moved down so it doesn't overlap the readout.
- **Stick position indicators** — two 8×8 mini joystick pads in the top bar
  show the active voice's *latched* effect positions (left = reverb/delay,
  right = cutoff/resonance). Switching voices makes the dots jump to that
  voice's remembered settings — each voice now has its own per-axis state
  stored on the party member.

### Story & dialogue
- **Improved character portraits** — Alder/Miel/Strom/Diegues all redrawn at
  28×40 with proper proportions, distinguishing features (hair, helm crests,
  pointy hat with star, beard), shading, and faint horizontal-stripe
  background framing.
- **Party-banter scenes at the inn** — seven story scenes (one per shard
  acquired) play once when the party rests at the inn. Each reveals
  backstory: Strom's silenced captain, Diegues' Academy, Miel's escape from
  the capital, Alder's burned village, Strom's confession about carrying
  Suno across the Reaches, and a final pre-finale moment.

### Sidequests (with persistence)
- **Hens** — 5 random-encounter wins → permanent 25% shop discount.
- **Brann** — 10 random-encounter wins → +200 g and a free Star item.
- **Tova** — meet all four regional sages (Veris/Aurin/Mira/Iolen) → +80 g
  and a lore reveal.
- All quest progress saves and loads.

### Jam Mode
- New game state entered by pressing **SELECT** from the overworld, battle,
  menu, or shop. Single-screen dashboard:
  - 4 columns (one per voice) showing CUT/RES/WET/DLY bars
  - Active voice column highlighted
  - L1/R1 cycles which voice the sticks edit
  - Sticks: right = cutoff/resonance, left = wet/delay (same mapping as
    everywhere else, but now visible at a glance for the whole party)
  - **B** or **SELECT** exits back to whatever state you came from

### Architecture
- A lot of code-organization work to keep main-chunk locals under Lua's hard
  200-cap as content grew: bundled animation state into `ANIM`, sidequests
  into `QUESTS`, story into `STORY`; converted enemy draw functions from
  `local function draw_X` to `DRAW_ENEMY.X = function(...)` so they don't
  consume top-level slots; bundled various unused tables.
- Compile-checked locally with `luac5.4 -p` before every deploy.

### Backup
- A frozen snapshot of the project lives at
  `~/Desktop/synth-quest-backup-<timestamp>` — a known-good state to roll
  back to if a future change misbehaves.

## 2026-05-02 (later) — Combat depth, jam evolution, narrative

### Combat
- **Cleric MAG → free, with revive** — Miel's MAG no longer costs MP. Each
  cast revives one KO'd member at 30% HP and heals the rest 25%.
- **Per-class instrument actions (NEW)** — replaced MAG with class-specific
  PLAY-style abilities:
  - **Alder PLAY** — heal all 10% HP + buff next attack +50% (existing)
  - **Miel LYRE** — revive + heal + apply HP/MP regen (32-tick) to party
  - **Strom HORN** — buff next attack of all + halve incoming damage 28t
    + halve enemy ATK 28t
  - **Diegues SMPL** — big enemy hit (mag×2, can crit) + halve enemy ATK
    20t + inspire whole party (next-attack bonus)
- **Party Jam contagion** — when ANY character plays their instrument, every
  other living party member's *next ATB-fill* auto-fires their own
  instrument (after which they revert to whatever they had queued). Holding
  PLAY/LYRE/HORN/SMPL becomes a chain of jams.
- **Status-effect ticking** — `regen_hp_ticks`, `regen_mp_ticks`,
  `dmg_reduce_ticks`, `enemy.atk_debuff_ticks`. Regen heals 1 HP / 8 ticks
  and 1 MP / 12 ticks while active. Damage taken halved while reduce > 0.
  Enemy ATK halved while debuff > 0.
- **Per-action articulation entries** — LYRE/HORN/SMPL get distinct
  velocity/attack/release/wet/pitch profiles in the ARTIC table so each
  instrument literally sounds different.
- **Per-action firing fx** updated — PLAY/LYRE/HORN/SMPL all spawn music
  notes with class-specific count + brightness for visual variety.

### Battle UI
- **Sequencer beat strip removed** — felt visually noisy.
- **BPM + ROOT KEY anchored next to cave name** in the upper left, tiny
  font, dim — frees space and stops competing with the action popup.
- **HP text fixed** — back to `X/Y` format at native font_size 6 (no longer
  blurry from sub-native rendering).
- **Cleaner small stick visualizers** in the top-right with crosshair, rest
  tick, and a haloed dot.
- **Hit-flash redesigned (again)** — bright outline + 4 corner sparks
  instead of a flash that obscured the sprite.
- **Enemy info compacted** — tiny font name on the left side of the scene,
  HP `X/Y` on the right, 50×1 HP bar between; enemy sprite center moved
  down to (96, 32) to clear the readout.

### Jam Mode (SELECT)
- **ROOT** — global semitone transposition (-12 to +12). Saved to disk.
- **MODE** — scale selector that cycles through any *unlocked* mode:
  - Pentatonic (always)
  - Lydian (after Cave 1)
  - Dorian (after Cave 2)
  - Mixolydian (after Cave 3)
  - Phrygian (after Cave 4)
  - Aeolian (after Cave 5)
  - Locrian (after Cave 6)
  - Ionian (after Cave 7)
  Active scale applies to **everything** the synth plays — overworld,
  battle, intro, victory, shop, party voicings.
- **Bigger 14×14 stick visualizers** in the bottom half with crosshair +
  halo dots showing the active voice's latched stick positions.
- **Controls**: dpad LR = BPM, dpad UD = ROOT, A = next MODE,
  L1/R1 = voice, B / SELECT = exit.
- Per-voice latched effects: each character stores their own
  `stick.lx/ly/rx/ry` plus latched `cutoff/resonance/xwet/dly`. Switching
  voices makes the stick indicators jump to that voice's remembered
  settings.

### New menu options
- **Items** — opens a panel showing potion counts (Salve / Vial / Star)
  and current gold balance.
- **Party** — view all four party members side-by-side with sprites,
  classes, HP, and level. L1/R1 selects who's active.

### Portraits (status screen)
- **Miel** — softer beautiful look: heart-shaped face, larger gentle eyes
  with eyelashes + iris catchlights, subtle blush, small upturned smile,
  delicate single-band tiara, longer flowing hair.
- **Diegues** — anime-style scholar: round wire glasses with bright
  lens-glints (the "no eyes visible" look), tall pointy hat with brim
  shadow stripe over the eyes, hair tufts under the brim, calm small
  mouth.

### Narrative
- **Title screen overhaul** — distant mountain silhouette, foreground
  hills, drifting starfield with an animated moon, and a centered
  **animated Crystal Synth**: pulsing aura ring, 7-faceted diamond shape,
  bright core, six floating particles orbiting on an elliptical path.
  Tagline: *"v0.5  the chord must sing"*.
- **Title music expanded** to 64 steps (4 bars) with a climbing arpeggio,
  i→IV→V→i pad, walking bass cadence, and a chime descant + counter
  melody.
- **Opening cutscene enriched** — added introductions of Strom and Diegues
  in the village scene; deeper Suno foreshadowing (silenced lullabies,
  forgotten names); 7 named modes called out in the cosmic lore.
- **3 more party banter scenes** at the inn — `two_shards`, `halfway`,
  `before_finale` — each gated on shard-count progress, fleshing out
  character voice + tension across the run.
- **Wren the wandering minstrel** — new NPC on the Sunward Coast at
  (56, 6) with shard-count-aware dialogue.
- **Idle bob on every NPC sprite** — each breathes 1 px out of phase based
  on its position, so the towns feel populated.

### Architecture
- More bundling to keep the main-chunk locals under Lua's hard 200-cap as
  systems grew: STORY scenes/play, JAM (root/mode/scales/note_names),
  CLASS_INSTRUMENT, ANIM helpers (spawn_dmg, party_hud_x, draw_action_fx,
  draw_stick), DRAW_ENEMY now built incrementally (`function
  DRAW_ENEMY.X` instead of `local function draw_X`) so each enemy doesn't
  consume a top-level slot.
- `active_scale()` helper reads `JAM.scales[JAM.mode]` so every SCALE
  reference picks up the player's selected mode automatically.
- All new state persisted in save: instruments owned, equipped, gold,
  inventory, quests, story scenes seen, jam root, jam mode.

### Animation polish
- **Floating damage numbers** + crit-color popups
- **Region-specific battle backgrounds** (cave drips, leaves, water
  shimmer, sand, snow, void, glyphs)
- **Enemy projectile** that travels from boss → targeted party HUD column
- **Critical hits** (10% chance, 2× damage)
- **Per-action firing fx** (slash / spell sparkle / music notes / shield
  pulse / barrier diamond / heal cross)
- **Living tile motion** — grass tufts breathe, oak canopies sway, inn
  chimney smoke rises


## 2026-05-02 (final pass) — Title/menu, instrument naming, content & polish

### Title screen
- **New Game / Continue selector** added at the bottom of the title.
  Any dpad direction toggles between the two options (they sit
  horizontally so left/right is natural). A confirms. Continue calls
  `load_game()`; if no save exists it shows a brief "No save found"
  banner and stays on the title.
- **`v0.5` removed** from the title — the tagline is now just
  *"the chord must sing"*.

### Instrument naming
- **Alder's X-button action: PLAY → LUTE.** Behavior unchanged (heal 10%
  HP party + buff next attack +50%). New ARTIC profile (bright fifth
  above, sustained).
- **Miel's instrument family is now all lyres.** Replaced
  Prayer Bell / Silver Censer / Hymnal with **Pilgrim Lyre /
  Silver Lyre / Sacred Lyre**, same stat curves, lyre-themed names.
- **Save migration** — older saves with `prayer_bell` / `silver_censer`
  / `hymnal` auto-upgrade to the new lyre IDs on load.

### Combat fix
- **"Party-jam contagion" feature removed** — it was chain-overwriting
  player choices every time any character fired their instrument, which
  made action selection feel broken. Now each character ONLY ever fires
  their own queued action; no auto-jam.
- Cleric MAG → LYRE branch made class-specific (no longer routes bard
  through Miel's revive code).

### Title/menu polish
- **Items menu option** — opens an inventory panel (Salve / Vial / Star
  counts + gold balance).
- **Party menu option** — full-screen panel showing all four party
  members with sprites, name, class, HP, level. L1/R1 selects active.

### Status & Equipment screens
- **Portraits replaced with the actual in-game sprites.** New
  `SPRITE_BY_CLASS.scaled(class, sx, sy, scale)` helper renders the 8×8
  bitmap at any integer scale; status & equip use 3× (24×24), framed in
  a 28×40 panel, with a 1-px idle bob and the character's name plate at
  the bottom of the frame. KO state still draws the dim "KO" overlay.

### Dialogue polish
- **Party scenes feel like actual conversations now.** Lines starting
  with `[Speaker]` are parsed: the speaker's name appears in the
  dialogue strip and their **8×8 sprite is drawn on the left of the
  dialogue box**, talking — sprite bobs 1 px every 3 ticks with a small
  "yapping" dot flickering near the mouth. Body text shifts right to
  make room. The placeholder `_party_scene` name no longer appears.
- **Pip's dialogue expanded** — 4 stages instead of 3, plus 3 cycling
  variants for the very-first-shard-not-yet state so she doesn't repeat
  the same lines on consecutive talks. New 1-3 shard branch ("I heard a
  humming this morning…").

### Shard-count bug fix
- The shards table is initialized as `{lydian=false, dorian=false, ...}`
  with all 7 keys present, but the counting loop `for _ in pairs(shards)`
  was counting all 7 *regardless of value*, so `n` was always 7 even on
  a fresh game. Fixed to only count truthy values across all five sites
  (Pip, Wren, Tova, two STORY scene triggers, and the new fountain).
  This is why Pip was talking about the fountain singing on a brand-new
  game.

### Fountain visual reflects shard progress
- The plaza fountain now matches the narrative:
  - **0 shards** — bone-dry basin with a dark crack on the floor
  - **1-3** — a thin dim trickle in the basin, no spout
  - **4-6** — water brightens, low 2-px spout, faint sparkles
  - **7** — full 4-px bright spout, brightest water, lively sparkles
- Pip's lines and the fountain visual now agree at every stage.

### Jam mode UX
- **L2-gated BPM control.** When L2 is OFF, the dpad does what you
  usually want: UD = scale, LR = ROOT. When L2 is toggled ON, dpad LR
  becomes BPM and a `L2:BPM` badge appears in the header — protects you
  from accidental tempo blowouts.
- **Music continues in jam mode** — the underlying overworld / battle /
  shop music keeps ticking while you're in jam, so you HEAR every
  param change in real time.
- **Stick visualizers hidden by default.** They only appear when Debug
  is on (toggle from the pause menu) — the regular jam UI is much
  cleaner.
- **Footer hints shrunk** to font_size 5 and reworded shorter, freeing
  visual space.
- **Party sprites at the top of each voice column**, animated with a
  per-column out-of-phase bob plus a flickering note dot to suggest
  they're actively jamming. Replaces the redundant CHAR_NAME label.

### Shop theme reworked (Digimon-World monochrome shop vibe)
- Dropped the bouncy walking warrior bass entirely (warrior silent in
  the shop now).
- Dropped the busy mage arpeggio. Mage plays a single high bell on
  bars 2 and 4 only.
- Cleric pad does a slow A → D → A → C cycle across 4 bars with **8 sec
  release** — that "still indoor air" quality.
- Bard adds a single sparse chime on bars 2 and 4.
- Loop length doubled to 64 steps so the cycle has space to breathe.
- All velocities lowered to ~0.35-0.40 and wet pushed up to ~0.85-0.90.

### Content & narrative
- **Pip** the village child added (in last entry; fleshed out here with
  cycling intro variants, 1-3 shard branch, 4-6 shard branch, and the
  fountain-sings celebration line).

## 2026-05-02 (later still) — Quests, bestiary, chests, anti-clip

### New menu screens
- **Quests** — opens a one-screen log of every sidequest with current
  status: Hens (road wins / discount), Brann (road wins / 200g+Star
  reward), Tova (sages met / lore reward).
- **Bestiary** — tracks every defeated enemy. Records visual id, name,
  HP_max, ATK each time you kill one. List sorted by HP for an easy
  power ramp; "X seen" counter at the top right. Persisted in save.

### Treasure chests on the overworld
- 5 chests scattered across the existing maps:
  - Mainland village west (30, 12) — 30g + Salve
  - Mainland Hollow Woods north (47, 4) — 60g + Vial
  - Mainland Sunward Coast east (60, 5) — 80g
  - Eastern Reaches dunes (26, 11) — 120g + Star
  - Northern Wilds snow (22, 11) — 150g + Salve
- Walk onto a chest to open it: gold lands in your purse, item lands in
  your inventory, a brief "Chest opened!" banner pops with the loot
  text. Opened chests don't re-render; opened state persists across
  saves.
- Chests draw as a small gold lid + body with a flickering shimmer dot
  on the lid corner.

### Filter resonance tamed
- Right-stick X used to push resonance up to 0.90 — caused clipping
  ringing at extremes. Capped at 0.50 now (range 0.05..0.50). Bar
  normalization in jam mode updated to match.

### Party invincibility in JAM mode
- `damage_party` early-returns when `game_state == "JAM"`. You can pop
  into jam mid-battle to fiddle with the synth without taking hits.

### Architecture
- New CONTENT table bundles bestiary + chest data + chest flash state.
- New UI table now holds draw_quests / draw_bestiary / draw_items /
  draw_partysel as fields, freeing more main-chunk local slots.

## 2026-05-02 (closing) — Recruits + jam scale unlocked

### Recruits: Sergei (engineer / MIX) and Paj (math wizard / CODE)
- Two new recruitable characters added as data-complete classes,
  visible in the **Party** menu under "RECRUITS (not yet joined)".
  - **Sergei the Engineer**: ATK 3 / DEF 3 / MAG 4 / SPD 3, HP 24, MP 10.
    His ability **MIX** deals MAG×1.4 damage, applies a 24-tick enemy
    ATK debuff, and **Fisher-Yates shuffles the enemy's attack pattern
    in place** — useful against bosses with patterned attacks.
  - **Paj the Math Wizard**: ATK 2 / DEF 2 / MAG 5 / SPD 4, HP 18, MP 18.
    Her ability **CODE** deals damage scaled by enemy *current* HP
    percent (the bigger the foe, the bigger the bite, peaking at
    MAG×2.5) and self-heals 15% HP per cast.
- Full per-class data added: CHAR_NAME, CLASS_ACTIONS, CLASS_INSTRUMENT,
  CUTOFF_RANGE, CLASS_GROWTH, ARTIC entries for MIX (+14 semitone tight
  transient) and CODE (+24 semitone high mathy chime).
- Engine voice routes through inline aliases: `engineer → trig_mage`,
  `mathwiz → trig_bard`. Same trick for cutoff/res/xwet/dly so each
  recruit's effects work seamlessly through their aliased SynthDef.
- Sprite placeholders: engineer reuses the warrior silhouette, mathwiz
  reuses the mage silhouette. Their scaled portraits work too via
  `SETS_BY_CLASS.engineer = STROM` / `SETS_BY_CLASS.mathwiz = DIEGUES`.
- Active swap mechanic deferred — they're data-complete and visible,
  ready to be wired into a recruitment quest later.

### Jam mode scale unlocked
- Removed the shard-gate on the scale selector in jam mode. All 8 modes
  (Pentatonic + the 7 modal scales) are always available — the gate
  only made narrative sense for story moments, and was preventing any
  actual scale switching at the start of a run.
- A button + dpad UD both cycle through the full 8-mode rotation
  cleanly.

### dpad reverted in jam
- Briefly tried LR=scale / UD=root, then reverted to UD=scale / LR=root
  per request. Footer hint updated to match.

### Architecture
- `CONTENT.recruits` table holds reserve character templates next to the
  bestiary + chest data.
- New UI table now also holds draw_quests / draw_bestiary / draw_items
  / draw_partysel as fields.

## 2026-05-02 (very late) — Solo vignettes + recruit NPCs

### Character development
- **Four solo character vignettes** added to the inn-banter system, each
  gated on a different shard so they unfold across a run:
  - `solo_alder` (after Lydian) — Alder tunes his lute by the fire and
    thinks of his mother and the songs he never asked her about.
  - `solo_miel` (after Dorian) — Miel writes a letter to her father,
    knowing he won't forgive her by dusk. ("And maybe — a little —
    she will hear me." — Iela, Strom's captain, reveal here too.)
  - `solo_strom` (after Mixolydian) — Strom sharpens his blade and
    finally speaks his captain's name aloud: "Iela."
  - `solo_diegues` (after Phrygian) — Diegues opens his Academy
    notebook: "We will reassemble it. Or die explaining why."
- These intercut with the existing party-banter scenes for a richer
  inn cadence.

### Recruit NPCs in the world
- **Sergei** placed at (28, 12) — near Brann's smithy, working a cold
  forge at night. Three dialogue stages keyed to shard count: 0 (loner
  tinkerer), 2 (offers to remix when you've earned it), 5 ("when you
  walk on Suno's tower — let me come").
- **Paj** placed at (6, 4) — by Tova's sage hut, reading her older
  texts. Three stages: 0 (counts silences between notes), 2 ("there is
  a function that solves Suno"), 5 ("when you call the seventh
  function — may I run alongside?").
- Both use their unique 8×8 class sprites (engineer = headphones-cap +
  coveralls + wrench, mathwiz = bobbed hair + glint glasses + tablet)
  in the world view.
- Mechanic to actually swap them into the party still deferred — they
  exist, they speak, they're aware of your progress.

## 2026-05-02 (closing again) — Story-driven recruits

### Sergei joins via Tidewatch intervention
- One-shot event: during the Cave 3 (Tidewatch) boss fight, if the
  whole party is wiped, **Sergei intervenes** instead of triggering
  game-over: revives every member at 50% HP, sets
  `CONTENT.recruits[1].joined = true`, and pops a "SERGEI INTERVENES!"
  banner. After the rescue, Sergei is in the roster and his village
  dialogue updates ("I never expected to throw a wrench at a god").
- The intervention is gated by `CONTENT.sergei_intervened` so it only
  ever fires once per playthrough; persisted in save.

### Paj joins after Cave 5
- After defeating the Snowgaunt (Cave 5 / Aeolian shard), the next
  time the party talks to Paj she joins automatically. Sets
  `CONTENT.recruits[2].joined = true`, dialogue updates ("I felt the
  function resolve. I'm coming with you.").

### Party swap mechanic
- New PARTY-menu cursor: dpad UD focuses one of the recruits (highlight
  + outline). When a JOINED recruit is focused, A swaps them with
  `party[active]`. Press B to back out.
- Displaced characters keep their full state (HP/MP/level/xp/etc.) on
  the recruits roster; swapping them back puts them back exactly as
  you left them.
- First-time joiners are built fresh from their template at level 1.
- Recruit cards show `JOINED` (level 11) or `(locked)` (level 4)
  depending on their flag, plus a context-aware footer hint.
- Persistence: `CONTENT.recruits[*].joined` and
  `CONTENT.sergei_intervened` are saved/loaded so story progress
  survives across sessions.

## 2026-05-02 (final-final pass) — Many small high-impact additions

### Menu addition
- **Shards** — new menu option opens a constellation view: 7 modal shards
  arranged in a circle around a central core, lit when collected, dim
  diamond outlines when not. Center core brightens with progress.
  Footer: "N / 7 shards collected". Visual progress for the central
  goal.

### Battle polish
- **Boss intro banner** — when a boss spawns (not random), a 36-tick
  banner pops with `* BOSS: <name> *` to add weight to the encounter.
  Reuses the generic CONTENT.banner_* state.
- **Climax dimming** — as enemy HP drops below 30%, a faint dark veil
  paints over the scene area, intensifying with HP loss.
- **Crit flash** — when a crit lands, a bright shrinking ring pulses
  around the enemy for 4 ticks.
- **Status icons in HUD** — R (regen active), D (damage-reduce active)
  now stack with the existing B / + / *. Up to 2 visible at once on
  each character's column.

### Story content
- **4 solo character vignettes** at the inn (one per core member,
  shard-gated, see prior entry).
- **5 recruit-banter scenes** at the inn (gated on Sergei/Paj joined
  flags + select shards): `sergei_first_night`, `sergei_remix`,
  `paj_first_night`, `paj_function`, `all_six_at_inn`.
- **3 hidden NPCs** scattered across the maps:
  - **Wina** at mainland (3, 13) — old woman by the lake, "the water
    remembers every song that was".
  - **Karoo** at eastern reaches (12, 5) — dune wanderer hum-talking
    fragments of forgotten songs (3 cycling line sets).
  - **Snow** at northern wilds (16, 6) — silent until you hold the
    Aeolian shard, then turns and thanks you.

### Music polish
- **Shard sting on collect** — when `obtain_shard` fires, a quick 4-note
  arpeggio in the appropriate mode's scale plays via clock.run-spawned
  staggered triggers (mage + bard at octave-up). Each shard sounds
  characteristic of its mode.
- **Level-up triumphant chord** — when a party member levels, a 3-note
  rising chord (I → III → V from the active scale) plays staggered on
  the bard voice. Subtle but rewarding.

### Story & UX
- **Tutorial banner** — first time you exit the intro cutscene, a
  one-shot 80-tick banner shows
  `dpad: walk   A: talk   START: menu  /  SELECT: jam mode`.
  Tracked via `CONTENT.tutorial_seen` so it never repeats.

### Architecture
- New CONTENT fields: `tutorial_ticks`, `tutorial_seen`, `partysel_focus`,
  `banner_ticks`, `banner_text`, `sergei_intervened`, `recruits[*].joined`.
- All persistence wired (joined flags, intervention one-shot,
  bestiary, chests, story scenes, jam settings, equipment, shop, etc.)

---

## Pass 10 — Jam Pad practice mode (2026-05-01)

### Feature
- **Invincible practice dummy** — new "Jam Pad" entry in the pause menu
  drops you into a battle scene against a calm straw practice dummy.
  Lets you freely play the party as a 4-voice synthesizer with no
  combat pressure.

### Implementation
- `enter_jam_pad()` builds an `enemy` table with `invincible = true`
  and `is_jam = true`, then enters the BATTLE state at BATTLE_BPM.
- `damage_enemy` early-returns for invincible enemies (still spawns
  damage-number flair, never decrements HP, never grants XP/gold,
  never records to bestiary).
- `enemy_tick` early-returns for invincible enemies — no attacks,
  no projectiles, no atk-debuff bookkeeping.
- BATTLE-state HUD swaps the HP bar for a `JAM PAD` label and a
  `START: exit` hint when `enemy.invincible`.
- Exit paths: gamepad START or norns K1 (so you can leave without
  having to bury the dummy in damage).

### Sprite
- `DRAW_ENEMY.dummy` — straw post + concentric target rings + tiny
  smiling head with a gentle sway. Reads as harmless practice prop.

### Architecture note
- `enter_jam_pad` is a global (no `local`) — we'd hit the 200-local
  Lua main-chunk cap with an extra forward decl. Saves a slot;
  pattern works because there's only one writer and a few readers.

---

## Passes 11 + 14 + 15 + 16 — Towns, items, explorable cave (2026-05-02)

### Pass 11 — Suno's Domain attendants
- Three end-game NPCs in the empty SUNOS_NPCS list:
  - **Lyssa** — disillusioned candle-tender; reflects on freedom post-Suno
  - **Calder** — weary watchman; warns of Locrius's "out-of-time" attack pattern
  - **Maren** — kneeling lute-mourner; bard-class lead triggers a special line
- New 8×8 sprites for each.

### Pass 14 — Town interiors + animals
- Inn (tile 13) now teleports into a 12×8 INN interior (map id 5);
  Mara (innkeeper) handles the rest action; Pell tells rotating lore tales;
  Mews the cat sleeps on a rug.
- New tile 12 = item shop building on Mainland (col 6, row 7).
  Teleports to a 12×8 SHOP interior (map id 6); Brio opens the SHOP UI on
  dialogue exit; Rook the dog wags by the door.
- Outdoor village pets: Pim (cat at 8,6) + Bonk (dog at 10,6) reuse the
  Mews/Rook sprites for visual consistency.
- New tile types (registered as anonymous functions on TILE_DRAW so they
  don't add main-chunk locals):
  - 12 shop, 17 exit-door, 21 bed, 22 counter, 23 rug (walkable), 24 lantern
  - `TILE_DRAW.floor` overrides outdoor grass for tile 0 inside an interior
- `CONTENT.return_map/x/y` saves the overworld position when entering an
  interior; tile 17 (exit door) consumes it on the way out.
- 8 new NPC sprites: Mara, Pell, Brio, Mews, Rook, Lyssa, Calder, Maren.

### Pass 15 — Ether + Tonic items
- Two new shop items:
  - **Ether** (45g) — +25 MP all (consumed by ITM action)
  - **Tonic** (60g) — +ATK 1 fight (sets `tonic_ticks` on every alive party
    member; cleared in `exit_battle`; surfaces in `INST.atk` as +4 ATK)
- Items list re-laid out (5 rows, tighter line height); save/load roundtrips
  the new inv keys.

### Pass 16 — Cave 1 explorable interior
- Tile 6 (Cave 1 entrance) now teleports into a 12×10 CAVE_1 interior
  (map id 7) instead of triggering an immediate battle.
- New tile 27 = boss arena marker (placed at row 2 col 6, "deep" in the
  cave). Stepping onto it forwards to `enter_battle(1)` so the existing
  boss-progression logic takes over.
- Per-step random encounters at 12% inside cave interiors (config'd via
  `CONTENT.encounter_step_chance`); routed through `enter_battle(1, true)`.
- New NPC **Hollin** at (2,8): lost caver. Dialogue evolves with progress
  — class-aware (mage gets a different line), branches on
  `cave_state[1].victories` and `cave_state[1].cleared`.
- Cave-floor visual: `TILE_DRAW.cavefloor` overrides tile 0 inside cave
  interior (deep gray with stable per-tile speckle).
- `try_random_encounter` now treats inn/shop as safe zones and routes cave
  interiors to their per-step rate.

### Architecture
- Maps + NPC lists for new sub-areas live on `CONTENT` (not new top-level
  locals), to stay under the 200-local main-chunk cap.
- Anonymous-function tile draws after `end -- tile draws` block so they
  don't push the per-block local count over the limit.

---

## Pass 17 — Path-east fix + village NPCs + campfire memories (2026-05-02)

### Bugfix
- The mainland map had wall/tree barriers at col 32 on every row, blocking
  passage from the village to the eastern half (caves 2, 3 + boat to caves
  4, 5). Cleared col 32 on rows 6 + 7 and col 30 on row 7 so players can
  walk straight east from the plaza.

### Campfire memory scenes
- Each of the three campfires (Hollow Woods, Sunward Coast, Northern Wilds)
  now triggers a one-shot party-banter scene the first time the player
  rests at it. Tracked via `CONTENT.fire_seen` (persists in save).
- Scene character: Strom on captains in the woods, Alder/Diegues debating
  string overtones at the coast, Miel humming her grandmother's snow-song.

### New village NPCs
- **Tilde** (kid at 11,9): hops in place; gives +5g the first time you
  speak; bard-lead gets a special "teach me the loud one" line.
- **Eos** (wandering minstrel at 19,9): cycles 3 fragments of half-remembered
  pre-Suno songs; `CONTENT.eos_idx` tracks rotation across visits.
- New 8×8 sprites for both (Tilde with hop-in-place animation; Eos with
  diagonal lute across his cloak).

### Cave 1 NPC continuity
- Hollin's dialogue now branches on `cave_state[1].cleared` and
  `cave_state[1].victories` so the "Voice" framing evolves as you grind.

---

## Passes 18-21 — Five explorable caves + east town + key item (2026-05-03)

### Pass 18 — Caves 2 + 3 explorable
- Tile 7 (Cave 2: Forest Sentinel) and tile 9 (Cave 3: Tidewatch) now
  teleport into 14x10 / 12x10 interior maps (map ids 8 and 9).
- Boss tile (27) now dispatches per-cave via a `current_map_id → cave_id`
  table inside the t==27 handler.
- New NPCs:
  - **Beren** (Cave 2): half-feral hermit; warrior lead gets a special line
  - **Anwell** (Cave 3): drowned fisherman ghost; cleric lead gets
    "unspool me when the Tidewatch falls"
- Cave 3 layout uses water tiles (3) inside as obstacles to navigate around.

### Pass 19 — Key item + locked chests
- New shop item **Key** (95g): consumed when opening a locked chest.
- 1 existing chest marked locked (ch_coast_e: 80g hidden treasure).
- 1 new locked chest deep in Cave 1 interior at (10,8): 200g + Tonic.
- Chest pickup branches on `c.locked`; if no key, banner reads
  "Locked. Need a Key." and the chest stays sealed.
- Save/load roundtrips `key` count.

### Pass 20 — Caves 4 + 5 explorable
- Tile 11 (Cave 4: Dune Rider on Eastern Reaches) → map id 10 interior
  with sand-pillar islands.
- Tile 16 (Cave 5: Snowgaunt on Northern Wilds) → map id 11 interior
  with ice-pillar maze.
- New NPCs:
  - **Iska** (Cave 4): salt-skinned guide; engineer lead gets pattern hint
  - **Wenna** (Cave 5): frostbitten singer; bard lead gets meter advice;
    branches on victories ≥ 3
- Caves 6 + 7 (Suno's Domain) intentionally left as direct-battle gauntlets
  for the climax feel.

### Pass 21 — Eastern Reaches town
- Inn (tile 13) + item shop (tile 12) placed at the boat landing on
  Eastern Reaches (row 9 cols 3 + 5). Both reuse the existing inn / shop
  interior maps and NPCs (Mara, Pell, Mews, Brio, Rook).
- New harbormaster **Sela** at (6, 9): port-town flavor; engineer-lead
  asks her to mend the dock; references the Mixolydian shard if held;
  has unique 8x8 sprite (peaked hat, oilskin coat, brass buttons).

### NPC sprites (registered as anonymous functions on NPC_SPRITES outside
the do-block to avoid main-chunk local-cap pressure)
- New: Hollin, Beren, Anwell, Iska, Wenna, Sela.

### Architecture
- Cave-floor visual (`TILE_DRAW.cavefloor`) now overrides tile 0 in any
  cave-interior map (ids 7-11), giving each cave a distinct dark-speckle
  texture vs. outdoor grass.

---

## Pass 22 — Shop UI fix + place names + interior theming + dialogue crash (2026-05-03)

### Shop UI overflow
- HENS' SHOP UI was hardcoded for 3 items at 12px row spacing, but the
  inventory has grown to 6 (Salve / Vial / Ether / Star / Tonic / Key).
  Rows 5 and 6 fell off the bottom of the screen.
- Rebuilt as a single tight row per item (7px spacing): caret + name +
  price + owned-count + desc on one line. Flash banner moved to a
  dedicated strip above the help line.

### Place-name banners
- Region banner used to handle only mainland sub-regions (village /
  woods / coast); entering an interior or another continent showed an
  empty box.
- New scheme keys on `<map_id>:<sub-region>` and looks up a friendly
  name per place: "The Inn", "Item Shop", "Cave 1 - The Echoes",
  "Cave 2 - Sentinel Grove", "Cave 3 - Tidewater Grotto",
  "Cave 4 - Dune Hall", "Cave 5 - Frost Vault", plus the existing
  Village / Woods / Coast / Eastern Reaches / Northern Wilds / Suno's
  Domain labels. Banner widened to 112×14 to fit longer names.

### Interior theming
- **Inn walls**: timber boards with vertical grain, occasional knots
  (stable per-tile seed), top trim molding.
- **Shop walls**: pale plaster with a wood wainscot strip + speckle.
- New tile 30 — **fireplace** (stone surround, dark cavity, animated
  flame, ember glow); placed at the back of the inn.
- New tile 31 — **wares-shelf** (two horizontal planks with colored
  bottles/parcels); lines the shop's back wall.
- New tile 32 — **dining table** with mug + plate; sits in the inn
  near the rug.
- New tile 33 — **brass till** at the center of the shop counter
  (replaces a counter tile).
- New tile 35 — **barrel of goods** in the shop corners.
- Inn and shop maps redrawn to incorporate the new décor.
- All new tiles registered as anonymous functions on TILE_DRAW so they
  don't add main-chunk locals (we're permanently near the 200 cap).

### Bugfix — campfire memory freeze
- `draw_dialogue` crashed accessing `dlg.npc.name` when a scene used
  narrator-style stage directions (e.g. `(Strom feeds the fire...)`)
  without a `[Speaker]` prefix — `dlg.npc` is nil for inline campfire
  scenes. Guarded the access; speaker label falls back to empty.
- Same fix protects any future inline narrator scenes (memories,
  cutscenes, etc.) that don't go through an NPC.

---

## Passes 23-26 — Towns, side dungeons, theming, NPC sprites (2026-05-03)

### Pass 23 — Northern Wilds town
- Inn (13) + Item Shop (12) building tiles placed at (3,11) + (5,11) on
  Northern Wilds, just above the player's pass landing point.
- New NPC **Bracken**: mountain-guide; cleric-lead variant + Aeolian-shard
  reaction + post-Snowgaunt closing line. Unique sprite (fur cap, white
  beard, snow-flecked coat, belt strap).

### Pass 24 — Side dungeon "The Hollow" + cartographer + Hens consolidation
- New tile 36 = side-dungeon entrance (mossy hollow w/ dim ember) on
  Mainland at (39, 4) in Hollow Woods.
- New map_id 12 = Hollow interior (12×10). Reuses Cave 1's encounter pool;
  no shard, no boss. Per-step 12% encounter rate like other caves.
- New NPC **Sett** (treasure hunter): hints at the back-room locked chest;
  unique sprite (sly grin, feathered hat, satchel).
- New chest `ch_hollow_end` at Hollow (10,8): locked, 250g + Star.
- Place-name banner "The Hollow".
- **Bugfix**: campfire memory scenes were getting yanked into a random
  battle mid-dialogue. Restructured try_move so a fired campfire scene
  redraws + returns early before chest/encounter checks run.
- **Bugfix**: counter blocking dialogue. find_facing_npc now peeks one
  extra tile when the immediate tile is a counter (22) or till (33),
  so you can address Hens across the counter.
- **Hens consolidation**: removed the duplicate plaza Hens NPC; she now
  lives inside the Item Shop interior with the same quest dialogue.
  Brio dropped. Sela / Bracken's directions updated.
- **Bugfix**: flash banner had hardcoded "Chest opened!" title — every
  flash event (campfire heal, equip toast, etc.) showed it. Banner now
  just renders flash_text alone.
- New NPC sprites: Karoo, Mira, Snow, Wina, Sett (the previously
  generic-fallback "ghosts" now have unique 8x8s).

### Pass 25 — Per-interior musical themes
- Added 8 distinct ambient themes to OW_THEMES via a do-block-scoped
  `mk{events}` helper (no new main-chunk locals):
  - **inn**: warm cleric pad + sparse high mage bell + bard chord
  - **shop**: mellow lo-fi pad + bell every other bar + soft chimes
  - **echoes** (Cave 1): low mage echo + huge cleric drone + distant thuds
  - **grove** (Cave 2): bird-like high bard chimes over a mid pad
  - **grotto** (Cave 3): sparse "drip" bard glints + wide low pad +
    rolling waves
  - **dune** (Cave 4): warm pad + steady warrior pulse on every beat
  - **frost** (Cave 5): icy fast-attack mage bells + crystal chimes
  - **hollow**: small earthy den, mostly silent w/ low bells
- `active_theme_id()` extended to dispatch by current_map_id 5-12.

### Pass 26 — Cartographer quest + wandering travelers
- New NPC **Pith** (cartographer at village 22,6): clear 3+ caves and
  report back for +100g + 1 Tonic. Tracks via QUESTS.pith.claimed,
  roundtrips in save/load.
- New NPC **Anker** (coast peddler at 52,8): rolling road gossip;
  flavor scales with shard count.
- New NPC **WispGirl** (Northern pilgrim child at 18,12): one-time
  +8g first encounter; class-aware later lines.
- 3 new sprites with distinctive silhouettes (scholar hat / scroll;
  knit cap / backpack / staff; pilgrim w/ cupped candle).

### Treant sprite pass
- DRAW_ENEMY.treant rewritten — was a flat green triangle on a stick
  (read as "Christmas tree"). Now: gnarled wider trunk with bark grooves,
  splayed roots, two branch-arms (one bent up / one bent down — Ent
  stride), finger twigs at each hand, leafy crown with leaf pixels +
  shadow underside, carved face with glowing hollow eyes + mouth slit,
  subtle sway driven by sin(tick/8).

---

## Passes 28 + 29 — Niko (drummer) + human antagonists + backstory + title polish (2026-05-03)

### Pass 28 — Niko (third hidden recruit)
- New playable class **drummer** with full data: CHAR_NAME["drummer"]="Niko",
  CLASS_ACTIONS (A=ATK, B=BLK, X=DRUM, Y=ITM), CLASS_INSTRUMENT="DRUM",
  CUTOFF_RANGE, CLASS_GROWTH (high HP+SPD, mid ATK, low MP).
- New **DRUM** articulation: low pitch (-12), very fast envelope (atk 0.001,
  rel 0.18), heavy velocity (1.20). Voice-aliased to warrior SynthDef.
- Voice-alias chain (5 sites, sed-batched) extended:
  `engineer → mage`, `mathwiz → bard`, **`drummer → warrior`**.
- 3rd recruit entry in CONTENT.recruits: drummer, spd=5, hp_max=30,
  atk=4, def=2. Save/load roundtrips joined flag (recruits_joined[3]).
- Niko NPC in The Hollow at (10, 2) — easy to miss without exploring.
  Joins after **4+ shards collected** when talked to. Custom sprite
  (bandana, vest, crossed drumsticks, snare on hip).
- PARTYSEL focus cycle 0 → 1 → 2 → 3 (none / Sergei / Paj / Niko).

### Pass 29 — Human antagonists + backstory
- **NPC visibility system**: NPCs may now have a `visible = function() ...`
  predicate. `npc_at` and the overworld render loop skip invisible NPCs,
  enabling story-gated antagonists who appear only at progression milestones.
- 3 new human antagonists, each with unique 8x8 sprite + progressive,
  class-aware dialogue:
  - **Iret** (the Diplomat, village 15,6): visible after 1+ shards.
    Suno's silver-tongued envoy. Tries to bribe the party. Cleric-lead
    gets a personal "I knew your father" line. Closing line at 6 shards.
  - **Vance** (the Conductor, village 24,6): visible after 2+ shards.
    Suno's enforcer. Cold, brief. Warrior-lead gets a "I served under
    your captain" line.
  - **Tess** (Alder's former bandmate, woods 40,5): visible after 3+ shards.
    Conflicted Court bard. Bard-lead gets a "I almost didn't recognize you"
    line. **Defects after Locrian shard**: gives +150g + 1 Key, sets
    `CONTENT.tess_defected`.
- 8 new STORY backstory scenes (trigger at inn rest as conditions are met):
  - `after_iret`, `after_vance`, `alder_tess_history`, `diegues_academy`,
    `miel_marriage`, `strom_captain` (Reya Vell — captain who knew both
    Iret and Vance), `sergei_tower` (Sergei built Suno's first silencing
    tower at 19), `paj_solution` (Paj solves Suno's chord as a function),
    `niko_first_night` (Niko played Suno's house band three years),
    `tess_defected` (post-defection scene).

### Title screen polish
- Added second (faster, dimmer) star layer for parallax depth.
- Shooting star fires once per ~280-tick cycle, traces a 6-px diagonal
  with a 3-pixel tail.
- Moon now has crater details.
- Drifting cloud silhouette across the sky (very slow).
- New mid-mountain ridge layer between the back mountains and foreground hill.
- Distant village lights flicker on the foreground hill (5 windows
  cycling at different phases).
- Tiny party silhouettes (4 figures with bobbing heads) standing on the
  hill — Diegues, Miel, Strom, Alder watching the Crystal Synth.

### Refactor — UI, Tilde/Eos/Sela sprites
- Hit the 200-local cap twice during this pass:
  - Moved Tilde, Eos, Sela sprite functions out of the NPC do-block to
    anonymous functions on NPC_SPRITES (saves 3 main-chunk slots).
  - Converted `local UI = {}` to global `UI = {}` (saves 1 slot).

---

## Pass 30 — Interior detail + opening cutscene polish (2026-05-03)

### Interior detail
- 5 new tile types (registered as anonymous fns on TILE_DRAW, no new locals):
  - **38** painting (gold-framed mini-landscape with candlelight glint)
  - **39** potted plant (dark clay pot + foliage + sway frond)
  - **40** wooden chair (backrest + slat + legs)
  - **41** hanging "OPEN" sign (chain + warm wood + coin glyph + sway)
  - **42** broom (diagonal handle + bristle bunch)
- Inn map updated: 2 paintings on back wall, plant by the fireplace,
  chair at the dining table, plant in the south-east corner.
- Shop map updated: hanging OPEN sign over the door, broom in left
  corner, plant in right corner.

### Opening cutscene polish
- **Panel-change transition**: each new cutscene panel triggers a 4-tick
  white flash (full → fade) followed by an 8-tick fade-in for the text
  panel. Tracked via `CONTENT.cutscene_panel_start = tick` set on every
  advance (gamepad + key paths both wired).
- Advance prompt ("A >") only appears after the fade-in completes, so
  the player isn't told to advance during the transition.
- Progress dots: current dot pulses 11/15; past dots are 7 (subtle
  "completed" tone); future dots are 3 (dim).

### Scene backdrop upgrades
- **cosmic**: added a closer/brighter star layer for parallax, a
  twinkling pulsar, ringed planet (highlight + ring approximated by
  4-segment lines), all on the same dark base.
- **dark**: added Suno's tower silhouette (with battlements) on the
  highest peak, occasional distant lightning that flashes the sky for
  3 ticks every 240, and a small drifting silencer figure in the
  foreground.
- **village**: added far-horizon stars, brick chimneys with rising
  3-pixel animated smoke wisps, and a tiny figure walking the lane.
- **threat**: added glowing pulsing eyes between the silencer
  silhouettes (every-other-frame pulse), corona ring around the
  eclipsed moon (occasional), thin smoke column from a torched
  village in the distance.

---

## Passes 31 + 32 — Sergei backstory + per-instrument sprites + random drops (2026-05-03)

### Pass 31 — Sergei backstory + Old Resonator
- New tile **43 = The Old Resonator**: a leaning, partly-collapsed stone
  tower with a faint humming light at the crack (a tone Sergei never quite
  tuned out). Animated subtle pulse + small antenna remnant on top.
- Placed at Mainland (43, 4) in Hollow Woods.
- **Sergei moved** from village (28, 12) → (43, 3), standing right above
  his ruined tower. Hidden until 1+ shards (uses Pass-29 NPC visibility).
- **Layered backstory dialogue**, branching on shard count + class lead:
  - Warrior lead: explicit confession — "I built the resonator at 19.
    Suno's first silencing engine. Mine. Your captains died because of
    my work. I'm here every dawn now. Tearing it down."
  - 2+ shards: "They paid in gear, not coin. I told myself I didn't
    know what it was for. I knew enough." — taps the cracked stone,
    listens for the hum.
  - 4+ shards: "Stripped to the studs. Could rebuild it as a
    counter-emitter. When the Tidewatch comes for you — and it will —
    I'll be ready. I owe Iela that."
  - Pre-shards: not visible at all.
  - Post-join: "But this tower behind me — I built it. I owed something.
    The wrench was overdue."
- **Tidewatch intervention** still does the actual joining (one-shot in
  damage_party); finding him at the resonator is the introduction, the
  dramatic save at Cave 3 is the recruitment beat.
- New STORY scene **`sergei_resonator_found`** — fires after meeting
  Iret AND finding the resonator. Party reflects on the discovery
  (Diegues felt the held A note, Strom relays Sergei's confession,
  Miel notes he's tearing it down himself, Alder: "Then we walk past
  him. Slow. Let him hear us coming someday").

### Pass 32 — Per-instrument sprites + random battle item drops
- All 12 equippable instruments now have unique 8x8 sprites stored on
  `INST.sprites`:
  - **Lutes**: wandering (rounded body), crystal (faceted shine + silver
    neck), aeolian (cold body + frost flecks)
  - **Lyres**: pilgrim (plain U + 3 strings), silver (polished + flourish),
    sacred (ornate + halo above, pulses)
  - **Swords**: iron edge (plain), hymnsword (cross guard + engraved
    note dot), stormbrand (jagged + spark flicker)
  - **Mage**: ash staff (gnarled tip), ember rod (glowing pulsing tip),
    astral wand (4-point star + orbiting particle)
- **EQUIP screen** now renders the equipped sprite under "Equipped:" label,
  plus a per-row sprite icon next to each owned item in the list.
- **Random battle item drops**: 35% per-random-battle drop chance,
  weighted: salve (30) > vial (22) > ether (14) > tonic (8) > star (4) >
  key (2). New `SHOP.last_item_drop` set on drop and rendered on
  BATTLE_END as "+ 1 <Item>" (level 13). Cleared on each non-dropping
  random battle so the screen never shows a stale drop.

---

## Pass 33 — Northern shop reposition + detail polish (2026-05-03)

### Northern Wilds shop position
- Item Shop was at (5, 11) — directly above the mountain-pass landing
  point at (5, 12), so players walked straight into it on arrival.
  Moved to (9, 11), keeping the inn at (3, 11). Now a short walk in
  either direction from the pass landing.

### Detail additions
- **Equipped instrument icon** in the BATTLE action popup — 8x8 sprite
  in the top-right corner of the popup showing the active character's
  current weapon (lute / lyre / sword / staff). Dynamic per character
  swap.
- New flavor NPC **Fern** (lake fisherman, Mainland 6,11): always
  present at the lakeshore. Cleric-lead variant; reflects on the
  silenced lake. Unique sprite (straw hat, fishing rod with line).
- New flavor NPC **Holda** (village watchwoman, Mainland 28,7): stands
  at the eastern village edge. Warrior-lead gets a personal note about
  Captain Reya Vell — the same captain Vance/Iret/Sergei all knew.
  Unique sprite (helm, cloak, vertical axe).

### Sergei backstory rework
- Sergei is no longer a former Suno collaborator. New backstory:
  he built the Old Resonator at 19 as a music-relay (carrying songs
  from singing villages to silenced ones). **Suno stole the schematic,
  burned the prototype**, and built the first silencing tower from the
  same coil. Sergei returns at dawn to study the wreckage, looking for
  the shared wire that could undo Suno's chord.
- All three Sergei dialogue surfaces updated: the resonator NPC
  (4 conditional branches), the `sergei_resonator_found` STORY scene,
  and the `sergei_tower` STORY scene (now "the chord shares one wire").

---

## Passes 33-56 — massive batch (2026-05-03 through 2026-05-05)

### Sergei rework (33)
- Sergei is no longer a former Suno collaborator. He built the Old
  Resonator at 19 as a music-relay; Suno stole the schematic and built
  the first silencing tower from the same coil. Sergei now studies the
  wreckage, looking for the shared wire that could undo Suno's chord.
- Three dialogue surfaces (NPC + 2 STORY scenes) rewritten.

### FF-style battle themes (34)
- New `BATTLE_THEMES` (global) with `encounter` + `boss` themes.
- Encounter: warrior 8th-note bass ostinato, cleric 4-bar minor pad
  progression (i-i-bVII-i), mage staccato melodic line, bard offbeat
  high stabs.
- Boss: heavier — quarter-note kick-pulse, 6s-release pad with
  dissonant 2nd cluster, dramatic mage phrases, menacing bard stabs.
- `tick_battle_music()` runs every battle tick. Picks `boss` theme
  on cave-boss visuals, `encounter` otherwise. Skipped for jam dummy.
- `TITLE.battle_step` resets on `enter_battle` for clean cadence.

### Intro morning-after rework (34)
- The "intro" STORY scene plays AFTER the first inn rest, so the
  "I'd call it bedtime" line was nonsense. Rewritten as a morning-after
  beat: Miel on the first mattress in months, Strom on light sleep,
  Diegues dreamed the lost chord, Alder caught him humming it,
  Miel: "Then let's go find it. Together, this time."

### Fern's pier (34)
- New tile **45 = pier** (walkable wood planks over water).
- 3-tile pier extends from the lakeshore into the lake on Mainland row 11.
- Fern moved from (6,11) shore -> (11,11) at the end of the pier, line
  in the water.

### Difficulty + clipping + delay (35)
- ENCOUNTER_CHANCE 0.04 -> 0.07.
- Enemy HP/ATK multipliers applied at battle-start.
- ARTIC velocity ceilings dropped ~20-25% across the board to fix
  multi-voice clipping (party action + enemy attack + battle-music
  ostinato all summing).
- Per-class delay ceilings + biases in the leftx-stick handler so each
  voice's delay sits at a polyrhythmically distinct level.

### 4x HP (36) + MIDI input (36)
- Random + boss enemies spawn at 4x base HP.
- `midi.connect(1)` in init(); MIDI notes route to the dedicated
  `CONTENT.midi_voice` (default bard). Knobs (CC 70/71/74/73) drive
  cutoff/res/wet/dly on the **selected** party voice (follows L1/R1).
- In JAM mode: 4-voice round-robin polyphony (notes cycle warrior ->
  cleric -> bard -> mage). JAM mode is silent (no looping music).
- Tiny MIDI activity dot in top-right corner.

### Stick latches + A-button latch (39-41)
- L3/R3 (or thumbleft/thumbright/LSTICK/RSTICK aliases) toggle stick FX
  latches. Latch ON snapshots active voice's FX values and broadcasts
  to all 4 voices.
- In JAM mode, **A button** toggles BOTH latches together (one-press
  freeze-everything). X cycles scale mode (moved off A).
- MIDI knobs respect latches too.

### Story content (42)
- 10 new STORY scenes: character pairings (Diegues+Miel book chronicler
  bond, Alder+Sergei mix-coil tinkering, Strom+Niko drumming wisdom),
  Crystal-origin lore, Alder writes a song, Miel's faith arc, Vance
  dread, quiet at the fire, pre-finale night, dawn-of-final scene.

### Bestiary lore (43)
- 26 enemies each get 2-line BESTIARY_LORE.
- Bestiary screen: dpad UD scrolls entries, selected entry's lore at
  bottom.

### Victory quips (44)
- 3-4 one-liners per class. Active char's quip flashes after victory.
- Later (56) refactored: now renders as a proper dialogue strip on
  BATTLE_END with sprite + name + body matching the in-game dialogue
  style, not a flash banner.

### Rare encounters (45)
- 4% per-random-battle chance. 6 named variants per cave (Elder Slime,
  Sage Sentinel, Tideturner, Dune Sovereign, Frostfather, Voidpriest).
- "* RARE: <name> *" banner. Guaranteed item drop (table-defined).

### In-cave scenes (46)
- 5 cave-entry STORY scenes (one per Cave 1-5). Tracked via
  `CONTENT.cave_entered`. Wired through `STORY.play_id(<id>)` so the
  generic STORY.play doesn't accidentally surface an inn scene at the
  cave (was a bug — Strom's "out of nowhere" dialogue).

### MPK params menu (47)
- Per-voice cutoff/res/wet/dly exposed in the norns PARAMS browser
  with grouped sub-sections (mage/cleric/warrior/bard).
- MIDI note voice selector. Long-press any param + twist a knob to
  CC-learn via the standard norns flow.

### Status effects (50)
- Poison: 1 HP every 6 ticks for 60 ticks. Spawns red damage popup.
- Sleep: 24-tick ATB freeze.
- Enemies inflict on hit: 6%/3% on regular, 18%/10% on bosses.
- Miel's LYRE dispels both. HUD icons P/Z added to status markers.

### Boss phase 2 (51)
- Bosses at <=30% HP enrage: attack-pattern gaps halved, +25% ATK,
  one-shot "* <NAME> ENRAGES! *" banner.

### Achievements (52)
- `unlock_achievement(id, name)` helper + 4 hooks: First Shard, All
  Seven Cleared, Rare Hunter, First Jam. One-shot flash banners.
  Persisted in save.

### Visual FX pack (53)
- Screen shake (translate-jittered frame), particle bursts, footstep
  dust trail, critical-HP vignette frame.
- Later toned down: removed crit screen shake (was hurting framerate),
  removed full-screen hit-flash stipple (too distracting). Kept burst
  + light enrage shake.

### USB controller banner (55)
- Title screen flashes "USB Controller Required" when no gamepad is
  detected. Layered detection: `gamepad.is_connected()`, then
  `hid.devices` typed gamepad/joystick scan, then a `controller_seen`
  fallback flag.

### Dialogue overhaul (56)
- **Two-strip layout**: header (sprite + name + underline at y=27..37)
  and body (3 lines at y=39..62). Sprite top-aligned, name baseline
  vertically centered against sprite.
- **3-line hard cap** per page (was 4-5; "no map" was getting clipped
  for Pell-style long lines).
- **`pack_dialogue_lines`**: merges consecutive same-speaker lines
  into single pages until ~75 chars, so short fragments don't waste
  whole panels.
- **NPC sprite resolution**: 3-layer fallback — DLG_NAME_TO_CLASS
  (party), NPC_SPRITES[name] (NPCs), no sprite.
- **Speaker prefix strip**: pack-time strip of "<NpcName>:" from each
  line + render-time safety net for "[Speaker] Speaker: ..." cases,
  so the name doesn't appear twice.
- **Char scrubbing**: em-dash `—` -> `--`, en-dash `–` -> `-`, multi-
  spaces -> single. Previously these rendered as blank slots in Tom
  Thumb font.
- **Dialogue rewrite sweep**: 27 NPCs converted from old hand-broken
  fragments to natural sentences sized for the new packer. Cave NPCs
  + town NPCs + recruits + antagonists. Mews/Rook left alone (already
  fine).

### Misc fixes / removes
- Day/night cycle (Pass 48) removed — density math was inverted,
  flooded screen with black pixels during transitions.
- Save slots (Pass 49) reverted — back to single save file.
- Resume option removed from pause menu (B button does the same).
- Jam Pad option removed from pause menu (SELECT in overworld still
  enters jam).
- Pause menu opens with **X** instead of START.
- FF7-style menu redesign: party panels (sprite + name + level + HP)
  on left half, menu list on right half. HP bar removed (was slicing
  through the HP text).
- Strom's "Reya would've nodded" quip removed.
- Diegues' SMPL skill now also heals party 8% + revives KO'd at 15%.
- Intro cutscene **START to skip** (gamepad START + norns K1).
- Pause menu fits all entries inside borders (was overflowing).
- Single save slot only.

### Repo + backups
- `~/dev/synth-quest/` is now a git repo on `main`, pushed to
  https://github.com/om-i-god/synth-quest.
- `backups/` directory holds timestamped `.lua` snapshots after each
  notable pass; gitignored.

## 2026-05-09 — Combat overhaul, prologue rewrite, dialogue packer
### Miel = REFLECT (was DEF)
- Cleric's B-button is now `REF`. New `ARTIC.REF` profile (bell-bright
  shimmer, +24 pitch, 2.2s release, 0.85 wet) so the action has a
  distinct sonic signature.
- `damage_party` checks `p.reflect` early (after Strom's blocker
  redirect, before any other reduction): full incoming damage is bounced
  back at the enemy via `damage_enemy(amount, false)`, the reflect is
  consumed, and a silver chime plays. Miel takes no HP damage and gets
  no hit-wobble (no `last_hit` set, no banner) — the read is "she
  repelled it cleanly," and the visible feedback is the damage number
  appearing on the enemy.
- HUD: `M` (mirror) marker added to the per-character status row when
  reflect is armed.
- New action visual on Miel's sprite: two concentric diamonds + four
  orbiting sparkles that rotate with `t`. Brighter than DEF, hangs
  longer.
- All 4 battle-init sites and the post-battle reset clear the new
  `reflect` / `reflect_ticks` fields alongside `shield`/`buffed`/etc.

### Game Over state (was: silent walk-around-with-dead-party)
- Party wipe in real combat now drops to a new `GAME_OVER` game state.
  Black field, 60-tick fade-in of "GAME OVER" centered, decorative rule,
  sparse static beneath, subtitle "the chord falls silent.", blinking
  `A — return to title` after ~80 ticks.
- Tutorial / scripted fights still soft-revive: the prologue silencer
  fights, the escape-cave wisps, and the academy Strom duel all bring
  the party back at 75% HP / 50% MP and return to the overworld with a
  banner ("you fall back. try again."). Avoids the soft-lock from the
  previous design while making "real" deaths actually punitive.
- Press A on the GAME_OVER screen → TITLE with `TITLE.idx = 1`
  (cursor parked on Continue) so a load is one button press away.

### Suno dialogue rework
- The original prologue had Suno effectively coaching Miel to the
  tapestry exit — wrong character voice. Rewrote to make Suno explicitly
  unaware of the secret door:
  - Cuts all "make for the tapestry" hand-holding.
  - Suno now demands the Aeolian shard concretely, asks Miel to sing
    only as a lie-detector ("the shard answers your blood — lie to me
    with your voice and I will hear it"), and orders the silencers to
    take her "hands first" before withdrawing to the corridor.
  - Miel speaks back early ("You will not stand on that dais"), so she
    has agency from the first beat.
  - The escape-door realisation is purely Miel's memory of her
    grandmother's room.
- Finale rework too: Suno's old "you walked from a tapestry to my
  throne" implied he knew the route. Replaced with "You should be a
  wagon-print in the road by now... I underestimated the room I left
  you in." Closes the loop on the prologue without ever revealing he
  knew the door.
- New dedicated `OW_THEMES.castle` underscore: hammered dotted-quarter
  pulse on warrior + dissonant minor-2nd cleric stab + urgent climbing
  8th-note mage figure + brittle bard offbeats. Throne room map (id 20)
  rerouted from the soft `inn` theme to this new `castle` theme.

### Cascade-split dialogue packer
- The pack_dialogue_lines splitter only knew sentence punctuation, so a
  single 100-char sentence with no internal `. ! ?` would render as one
  page that overflowed the 3-line body strip and got clipped.
- Rewrote `split_long` as a delimiter cascade: sentences first, then
  `--` clause break, then `;`, then `,`, then a balanced word-boundary
  split (last resort, equalizes chunk sizes so we don't end up with a
  5-char orphan tail after a 70-char chunk).
- Speaker prefix preservation: when a tagged line `[Suno] long...` is
  split, every produced chunk keeps the `[Suno] ` prefix so the
  re-merger sees consistent speakers.
- Audit: 89 lines previously overflowing the 75-char body budget, now
  zero. No source dialogue edits required — every existing line auto-
  splits into ≤75-char pages.

## 2026-05-09 (later) — SCENE engine + autonomous content expansion
A long autonomous run focused on FF-style scene choreography and net-new
content. Baseline 16,054 lines / 676KB → final 18,155 lines / 752KB.

### SCENE choreography engine
- New `SCENE` global with actor pool, smoothstep position tweens,
  camera tween, fade-in/out (dithered stipple at low values, solid black
  at 15), and a step-based script processor. Step shapes:
  `spawn`, `move`, `face`, `despawn`, `wait`, `dialogue`, `camera_to`,
  `fade_in`/`fade_out`, `sfx`, `shake`, `flash`, `teleport_player`,
  `hide_player`/`show_player`, `set` (arbitrary state poke).
- Actors render between map sprites and the player on the overworld
  draw stack. Per-actor facing is honored by temporarily setting
  `player.facing` while the sprite draws (since SPRITE_BY_CLASS reads
  it at render time), then restoring.
- Per-tick `SCENE.tick` advances tweens always; advances the script
  only when not in DIALOGUE and not waiting. Dialogue steps hand off
  to the existing DIALOGUE state via `CONTENT.post_dialogue` so
  `pack_dialogue_lines` + the dialogue UI continue to be the source
  of truth for line rendering.
- Input suppression: gamepad dpad/button + norns key handlers all
  early-return from OVERWORLD when `SCENE.active` is true, so the
  player can't walk through a cutscene.
- Scope: defined SCENE method bodies after `SPRITE_BY_CLASS` (not at
  the data table) so all needed locals are in lexical scope without
  trying to refactor `cam`/`player`/`dlg` into globals.
- Save/load wipes any in-progress scene; GAME_OVER → TITLE clears
  scene state on the way out.
- An NPC may now declare a `scene = function() return script end`
  field; if present, talking to the NPC fires the script via
  `SCENE.start` instead of the standard text-only dialogue.

### Choreographed scenes (10 SCENE.start callsites)
- **Prologue throne room** — auto-fires on first map-20 entry (state
  "untriggered"). Suno + 2 silencers spawn at the south doorway, Suno
  paces the full hall length over 60 ticks, stops one step short of
  the dais, dialogue beats interleave with sprite turns and lantern
  SFX, Suno walks back out, doors thud, silencers step into Miel's
  path, Miel whispers her grandmother's secret door line. Player gains
  control. Static talk-to-Suno NPC removed (auto-fire replaces it).
- **Diegues academy join** — Diegues turns from the lectern, Strom
  enters from the east doorway, dialogue-with-movement, Diegues walks
  down to flank Miel, on_complete drops Diegues into the active party
  and starts the Strom fight.
- **Strom epilogue (post-battle)** — Strom on his knees mid-room,
  hammer-fall SFX + shake, Diegues walks down from the lectern, beat-
  by-beat dialogue with strom-rises facing changes, both step into
  formation behind Miel.
- **Alder recruit** — soft lute idle SFX, Miel's hum (sustained cleric
  tone), Alder turns down briefly (recoil), faces Miel, stands, walks
  to her tile, joins.
- **Niko recruit** — at the moment of joining, brushed-cymbal sting,
  Niko stands and steps toward Miel, four kick-drum 4-on-the-floor
  hits punctuate the join banner.
- **Reya's Cairn** (Strom-only) — only fires when `class_in_party
  ("warrior")`. Strom walks 70 ticks from Miel to the cairn at (24,5),
  faces it, bell-wind SFX, kneel + stand sequence with two facing
  changes, places a stone, wind answers, both walk back to Miel's
  position. Unlocks `reya_cairn` achievement.
- **Lirael Ruins first visit** — long, slow memory beat. Party
  companions spawn at the south end as standing actors; Miel walks
  alone across the courtyard toward her grandmother's empty throne
  (108 ticks, two-segment path); optional reactions from Strom/Diegues/
  Alder if present (each walks to a different position with their own
  dialogue beat); a bell rings of its own accord; a small white bird
  appears in the rafters; awards a Tonic.
- **Velthe's Observatory first visit** — Iola plucks three orrery
  tones (mage voice ascending), greets Miel, walks down to her, awards
  the Sightings Lens instrument with cleric high-chord SFX, unlocks
  `velthe_sightings` achievement.
- **Choir Hour** at the academy — fires on revisit with ≥3 shards
  after `academy_state == "complete"`. Diegues at the lectern with
  baton, four students (one of each class for sprite variety) seated
  in a semicircle, all face up on the conductor's cue, four-part chord
  stacks bottom-up (warrior C2 → cleric C4 → mage G4 → bard C5) with
  4-second release each, students sit, Diegues smiles. Unlocks
  `choir_hour` achievement.
- **Suno finale approach** — pre-combat scene at cave 7. Suno spawns
  facing away (up); after Miel's "I came here so I could sing for it"
  he turns in two facing-change beats (left → down) with 1.2s release
  warrior-voice SFX punctuating each; six-shard ring fires three
  harmonized triggers across cleric/mage/bard at successive pitches
  with screen shake; on_complete launches the cave-7 boss fight.
- **Campfire choreography** — every campfire memory now seats the
  active party in a deterministic 6-class ring around the flame
  (Miel NW, Alder NE, Strom W, Diegues E, Sergei SW, Paj SE,
  Niko S). Sustained cleric chord on settle. Sprites despawn after
  the dialogue closes.
- **Inn dawn departure** — 25% chance after inn rest (when STORY.play
  has nothing queued and party ≥ 2). Picks a random non-leader
  companion; they appear beside Miel for one short class-flavored
  morning line (per-class line pools — Strom is "two hours' light
  burned", Diegues "I have written down a dream", etc).

### New locations + maps
- **Lirael Ruins (map 23)** — 16×11 burned ancestral home. Bell-tower
  silhouette (col 7-8 row 3-4), twin scorched hearths (col 5/12 row 6),
  the empty throne (col 7 row 6), broken bookshelves, ruined wall
  blocks. Custom ash-floor renderer (dim stone with seeded ash flecks)
  + custom ruined-wall renderer (chipped edge with deterministic
  notch). Reachable via tile 51 (vine-arched stone door) on the
  Western Region west edge. South tile 47 returns to Western Region.
- **Velthe's Observatory (map 24)** — 16×10 dark stone interior.
  Brass orrery centerpiece (col 7 row 5), reading-fire, chart shelves,
  decorative columns. Custom starfield-floor renderer (deep blue-black
  with stable bright pixels) + brass-fitting wall renderer. Reachable
  via tile 52 (lantern-domed wooden door) in the Northern Wilds; gated
  by 3 shards (soft "the door is sealed" banner if under).

### New music themes
- `OW_THEMES.lirael` — mournful Aeolian descent. Cleric breathes a
  slow held A3 → G3 → F3 → E3 ladder (6.5s release each); mage
  answers with a tiny minor-third figure on every other bar; warrior
  pulses a single low A on bar 1 + 5; bard places a brittle high A
  every 8 bars (the bell). Long attacks + heavy reverb so the chamber
  feels empty even with notes in it.
- `OW_THEMES.observatory` — mathematical Lydian sequence. Mage runs a
  5-note climbing figure (1, b3, 5, b7, 1) that resets on bar 4
  coloration; cleric holds a brilliant high pad; warrior pulses a
  clean major triad on every bar one; bard accents the offbeats.
  Bright and curious — sound of doing the math while the stars
  hold still.
- `OW_THEMES.cairn` — single bell-tone with 12-second decay + low
  pedal. Cleric strikes A4 every 8 bars; warrior sustains a low
  pedal. That's the whole arrangement; designed to make the player
  aware they're standing somewhere quiet. (Ready for a future
  cairn-area map; cairn NPC scene currently fires inside Northern
  Wilds without a dedicated map.)

### New tiles (5)
- **32** bell-tower base — pale stone column, arched window slit,
  faint slow-pulsing brass bell glint inside the slit, pitted edge.
- **51** Lirael Ruins arch — narrow stone arch with vine pixels on
  the top, dim warm glow visible deep in the dark.
- **52** Observatory door — wooden door under a small dome with a
  brass lantern that blinks on a 6-tick cycle.
- **53** empty throne — slightly-off-center silhouette, broken back
  with chipped corners, occasional dim heat-bleached stud glint.
- **54** village plaza flag — 7-tile-tall pole with a small banner
  that animates on a 3-frame sway cycle. Banner color follows shard
  progress: dim grey at 0, brass at 4+, bright cream at 7. Placed at
  col 15 row 6 on mainland (directly above the village fountain).

### New NPCs (each with custom 8×8 sprite + animated detail)
- **Tovia the Cartographer** — wandering. Visible in mainland inn
  at 0-2 shards, eastern inn at 3-4, northern inn at 5-6. Russet
  cloak, vellum sheet held in front, occasional bright pixel
  (writing). Lore deepens each appearance; final line at 5 shards
  is a goodbye.
- **Bren the smith** (mainland col 8 row 5) — broad shoulders,
  leather apron, hammer-down posture, occasional anvil glint.
  Plays an anvil-ring SFX on dialogue open. Class-aware lines for
  Strom (recognizes military stance).
- **Tilo the dock-child** (mainland col 22 row 9) — small, hood up,
  hands held together as if counting boats. Boat count grows with
  shard progress.
- **Aunt Vell** (mainland col 5 row 5) — wide-brimmed hat, small
  frame, with a yellow bee particle that orbits her sprite via
  `sin/cos(tick)`. Beekeeper at woods edge; bees fall quiet when
  the chord is broken, sing again as it heals.
- **Iola** (Velthe's Observatory) — chalk-white hair, dark robe,
  occasional silver lens glint. Apprentice; awards Sightings Lens
  on first visit, gives shard-tier flavor on revisits.
- **Maro** (Western Region col 5 row 8) — Tovia's apprentice,
  sketching the academy facade, charcoal-stick flicker.
- **WhiteBird** (Lirael Ruins, in the bell-tower rafters) — tiny
  white sprite that ruffles wings on a 30-tick cycle. Talking to it
  rings the bell once more, very small; Miel "...you remember her."
- **KeeperStone** (Lirael Ruins) — small inscribed stone with two
  lines of voice — Velthe's chronicle and a margin note in another
  hand signed "M.".
- **Orrery** (Observatory centerpiece) — interactable brass-rings
  sprite drawn over the underlying hearth tile. Each interaction
  cycles through 5 named constellations (The Loom, The Captain,
  The Bell, The Long Hand, The Seventh Sister), each with a held
  cleric chord and a brief lore beat.

### Visual ambience — PARTICLES engine
- New `PARTICLES` global with a 60-particle hard-capped pool.
  Per-tick spawn driven by current map / region:
  - Mainland woods → `leaf` (gold pixels, slight horizontal sway)
  - Mainland coast → `mist` (dim flicker)
  - Northern Wilds + Frost Vault → `snow` (pale falling pixels)
  - Western Region → `leaf`
  - Lirael Ruins → `ash` (dim trailing pixels)
  - Dune Hall → `sand` (horizontal streaks)
- Coast-region creatures: rare `bird` (3-pixel V-glyph that flaps
  every 8 ticks, with subtle vertical sine), rare `splash` (small
  expanding ring near pier coords).
- Drawn over the world after the SCENE fade overlay so they read on
  top of even faded scenes.

### Polish + safety
- All NPC visibility / dialogue functions returning long lines now
  pass the new cascade packer cleanly — `python3 /tmp/dlg_audit.py`
  reports 0 overflows across 260 candidate dialogue strings.
- Place names registered for new maps (Lirael Ruins, Velthe's
  Observatory, Reya's Cairn, Hall of Resonance, Western Region, etc.)
  so the place-banner reads correctly on entry.
- `start_dialogue` extended to detect `npc.scene` and prefer it over
  `npc.dialogue` (fallback chain preserved if the scene returns nil).
- New animated tiles (32, 52, 53, 54) added to the per-tick draw call
  so they receive the `tick` argument.

### HDMIMirror robustness (earlier today, included for completeness)
- Viewer was constantly disconnecting/reconnecting because the lua-
  socket `tcp:send` returns `(nil, "timeout", last_byte_sent)` on a
  partial send and the previous code assumed all-or-nothing. Receiver
  read pixel bytes as length headers and dropped the connection in a
  loop.
- Rewrote with a `send_all()` helper that resumes from `last + 1` on
  timeout. Added `tcp-nodelay`. Lowered TARGET_FPS 20→12 (half the
  bandwidth, plenty for a turn-based JRPG). Bumped reconnect interval
  3s → 5s.

### Ergonomics
- Viewer config (`~/.config/synth-quest/viewer.conf` on the norns)
  now points at the Mac's current LAN IP. `viewer/mac-run.sh` still
  prints the IP to set when launched from Terminal.
- All deploys via `rsync -az -e 'ssh -i ~/.ssh/norns'` to
  `we@norns.local:/home/we/dust/code/synth-quest/synth-quest.lua`.
  Snapshots of each major pass live in `backups/` (~7 across the day).

## 2026-05-09 (final wave) — FF4-tier scene polish + camera + typewriter
A second autonomous run focused on dragging every scripted scene up to
Final Fantasy IV/V/VI standard. Baseline 18,155 lines → final 20,400+
lines. The throne-room bug fix that started this pass exposed a deeper
omission: the SCENE engine had no camera-pan support, no letterbox, no
walking animation, no auto-look. All added; every existing scene
reworked to use them.

### Throne-room bug fix
- The original bug: castle map is 12w × 10h; view is 16w × 8h. Player
  starts at (6, 5) → cam.y pinned to 1, view shows rows 1-8. Suno was
  spawning at (6, 9) — OFF SCREEN. Player only saw silencer NPCs (which
  also lit up the moment the scene set `prologue_state = "coup"`).
- Fix #1: gate the static silencer NPCs behind a NEW
  `CONTENT.prologue_scene_done` flag. They no longer materialise
  during the cutscene — only after.
- Fix #2: the throne scene now pans the camera DOWN to the doorway
  (cam.y = 3 → view rows 3-10) BEFORE Suno enters. Suno spawns visible.
  Then a measured walk-up + a SECOND camera pan back to frame Miel +
  Suno across the dais. Pure FF6 establishing-shot grammar.

### SCENE engine extensions
- **`focus = {x, y}` / `focus = id`** — auto-pan camera to a tile or
  to keep an actor centered. Clamps to map bounds. Smoothstep tween.
- **`look = id, toward = id`** — auto-rotate one actor to face another
  based on their relative position. Used for "characters look at each
  other" beats without the writer having to compute facings by hand.
- **`bump = id, dir = "up"|"down"|"left"|"right"`** — small back-and-
  forth tween used for shock reactions. The actor moves 0.4 tile in
  `dir`, then snaps back over the same duration. Reads as a recoil.
- **`letterbox_in` / `letterbox_out`** — animated 6px black bars at top
  + bottom that ease in over ~6 ticks. Drawn between SCENE.draw and
  SCENE.draw_fade so a fade-to-black still covers them.
- **Step-walk animation** — actors lift 1px on alternating beats of
  their move tween (computed from `step_phase = floor(move_t * 4 /
  move_dur) % 2`). Walks now read as footsteps, not ice-skating.
- **NPC sprite priority in SCENE.draw**: explicit `sprite` override →
  `NPC_SPRITES[name]` → `SPRITE_BY_CLASS[class]` → placeholder. Lets
  scenes spawn boss silhouettes by name (Echo, Sentinel, Tidewatch,
  Rider, Snowgaunt, Locrius — each with bespoke 8×8 art).

### FF-polished existing scenes (8)
Every scene from the first pass got the new treatment:
- **Prologue throne room** — full camera choreography (start on Miel,
  pan to doorway, hold during Suno's entry, pan back for dialogue,
  follow Suno out), letterboxed, look/bump for facing changes.
- **Diegues academy join** — Diegues spotted Miel with a `bump = up`
  shock recoil, look-at-each-other beats during the dialogue, Strom
  enters from the south doorway with hammer-drag SFX. Letterboxed.
- **Strom epilogue** — multi-stage facing changes (down for "looking
  at hands", left for "looking at Diegues", left for "looking at
  Miel"). Letterboxed.
- **Alder recruit** — camera focus on the fire, Alder's `bump = down`
  recoil when he hears Miel's hum, look-at-each-other when he stands.
- **Niko recruit** — camera focus on The Hollow's back room, Niko
  looks at his sticks (face down) before turning to Miel.
- **Reya's Cairn** — camera frames player + cairn together, then
  focuses on the cairn for the wind-answer beat, then back to Miel
  on the walk home.
- **Lirael Ruins first visit** — establishing shot of the throne
  before introducing Miel, camera tracks Miel's slow walk to the
  throne, fade-from-black entrance.
- **Velthe Observatory first visit** — camera holds on the orrery
  before introducing Iola, then frames Iola + Miel together.
- **Choir Hour** — letterboxed + fade-from-black opener.
- **Suno finale** — camera cuts between wide-shot, Miel-tight, Suno-
  tight as he turns. Letterboxed.

### New scenes (10)
- **Eastern Reaches arrival** — gull-cry SFX, party walks ashore, Strom
  or Alder one-line reaction.
- **Northern Wilds arrival** — held wind tone, snow falling, Strom
  remembers his lost company.
- **Suno's Domain arrival** — held low drone, party draws together,
  per-companion dread reaction.
- **Tower-entry** — first time on tower tile with 5+ shards: party
  gathers at the threshold, two tower-hum SFX, per-companion goodbye
  to the village, fade-out warps to Suno's Domain.
- **Escape cave first-step** — solo Miel, fade-from-black, tapestry-
  thud, hum begins, walks east into the dark.
- **Village arrival "queen of nothing"** — slow fade-in (60 ticks),
  bell-shimmer SFX, Miel sets back her hood, long pause, the line.
- **Six-shards convergence** — fires when shard count hits 6 (queued
  via `CONTENT.queued_scene` from `obtain_shard`, fires on next
  `exit_battle`). Party gathers at the village fountain; per-companion
  one-liner; full party-chord stack as the held resolution.
- **First-shard celebration** — bespoke aftermath for Cave 1 victory.
  The shard hums home, the village fountain begins to run for the
  first time in 20 years, three-note arpeggio on the basin.
- **Boss-aftermath** for caves 2-6 — shorter beats, one held cleric
  shimmer + one quoted line from the appropriate party member (Strom
  for Sentinel/Snowgaunt, Diegues for Locrius, Miel for Tidewatch,
  Alder for Dune Rider).
- **Strom inn-dream** — black-screen flashback, no actors. Distant
  rain SFX, Reya's voice in his memory, wakes to the line "...Reya."
  Fires once on first inn-rest with Strom in party.
- **Diegues' study** — quiet revisit beat at the academy with 5+
  shards and Diegues in party. He reads his own old chronicle pages
  and admits he was wrong about most of them.
- **Alder ambient** — very rare (~0.5% per tile, throttled to once per
  ~minute) flavor scene fired during village walking. Alder appears
  next to Miel for 3 ticks, plays a 3-note phrase, vanishes.

### Boss approach choreography (caves 1-6)
- New `start_boss_approach_scene(cv)` helper — runs FIRST time the
  player crosses each boss-arena tile. Boss spawns visible with a
  bespoke NPC sprite (Echo flickering ghost, Sentinel mossed wooden
  giant, Tidewatch waving water silhouette, Dune Rider on horseback,
  Snowgaunt conducting figure, Locrius skeletal teeth-glint). Per-
  cave atmosphere SFX cluster + boss tone. Party draws together on
  beat 3. Final `bump` on the boss before transition to combat.
- Cave 7 still routes to `start_finale_scene` (already FF-polished).

### Sage first-meeting choreography (4)
- Veris (woods), Aurin (coast), Mira (eastern dunes), Iolen (north).
  Each is a one-shot `scene` field on the NPC: when the player first
  walks up, the sage approaches from off-tile (or comes into focus),
  letterboxed, three-beat introduction with auto-look. Subsequent
  visits use the original progression-aware dialogue.

### Recruit choreography (3 more)
- **Paj** (mathwiz) — fires the moment she joins (Cave 5 cleared +
  not yet joined). Pen-down SFX, look at Miel, mage-voice resolution
  chord on join.
- **Sergei** (engineer) peaceful path — fires when player visits the
  Old Resonator after defeating Tidewatch without wiping. Cable-thump
  SFX, slow turn, look at Miel.

### Dialogue typewriter (FF char-by-char reveal)
- `draw_dialogue` now reveals body text at ~17 chars/sec
  (TYPEWRITER_CPT = 0.85 chars/tick at 20fps). `dlg.line_start_tick`
  is set on every new line; lazy-init in draw_dialogue so callsites
  that bypass `start_dialogue` still get the reveal.
- A-press behavior: if not yet revealed, FIRST press snaps to fully-
  revealed (`dlg.snap_to_complete = true`); SECOND press advances
  the line. Classic FF dialogue feel.
- The advance "v" prompt only flickers once `dlg.complete` is true.
- Wrap-line stability: font choice (default vs compact) is pinned by
  the FULL body length, not the currently-revealed prefix, so the
  layout doesn't hop mid-reveal.
- Save/load wipes typewriter state so a load mid-dialogue doesn't
  show a stale partial line.

### Battle polish
- **Pre-battle visual sting** — `enter_battle` now fires a 2px shake
  + 8-particle burst + low warrior tone before combat begins. Skipped
  when SCENE is active (boss-approach scenes already handle their
  own entry animation).
- **Character shock-jump** — when a HUD party sprite takes damage,
  it bumps 1-3px down for the first 6 ticks then eases back. Reads
  as recoil from the projectile.
- **Critical-HP vignette** — any party member below 25% HP triggers
  a subtle pulsing screen-corner border tint (alternating brightness
  11 ↔ 7 every 8 ticks). Drawn behind everything else so the battle
  UI stays crisp.

### Shard pickup polish
- `obtain_shard` now ALSO fires a center-screen particle burst (size
  scales with total shards owned), a 12-tick shake, and at shard 5+
  an extra rising 4-note cleric arpeggio over the existing sting.
  At shard 7: a held bass cleric tone + the "* THE CHORD IS WHOLE *"
  banner.

### Particles + ambient
- Bird/splash particles already wired (last pass) — now bird flight
  is more atmospheric in the coast.

### Engine safety
- Save/load wipes SCENE state (active, script, actors, fade,
  letterbox, hide_player, cam_tween) AND the typewriter state. No
  more loading mid-cutscene leaving stale actors on screen.
- GAME_OVER → TITLE clears scene state.
- New `CONTENT.queued_scene` mechanism for scenes that need to fire
  AFTER battle exit (six-shards, boss-aftermath). Set in clear_boss /
  obtain_shard, dispatched at the end of `exit_battle`.
- Old saves predating `prologue_scene_done`: if they're past the
  "untriggered" prologue state, we assume the scene already played
  (so static silencers continue to be visible).

### Cinematic CUTSCENE intro
- The boot-time intro CUTSCENE state is its own slideshow system, but
  it now ramps in 6px letterbox bars over the first panel for
  consistent FF framing.

### Ending polish
- ENDING state gets a constant 4px top letterbox (bottom kept clear
  for progress dots + "A >" prompt).

## 2026-05-14 — Lore catch-up pass: bible reconciled with code

Bible (`story/bible.md`) had drifted from `synth-quest.lua` since
2026-04-29. This pass reconciled the two. No code was changed; this
was a documentation pass only.

### Standing rule established
- Going forward, any narrative content added or changed in the code
  (characters, areas, items, NPCs, factions, dialogue beats) must be
  reflected in `story/bible.md` and `story/scripts/` in the same pass.
  Tracked in user memory as `feedback_synth_quest_lore_sync.md`.

### Surveyed both sources
- Bible state at 2026-04-29: world/cosmology committed, 7 modes
  proposed, 4 party members locked, Suno + 3 lieutenants proposed,
  caves 3-7 sketched with specific bosses (Harbormaster, First Call,
  Broken Cadence, Tritone), Resonances proposed, Ionian = ceremonial.
- Code state at 2026-05-14: 4 party members (match), 24+ named NPCs,
  7 caves named (TIDE CAVERN, GLASS CAVERN, ICE GROTTO, LOCRIAN
  CRYPT, SUNO'S CHAMBER), 8 named bosses, 26 enemy types, regions
  including Lirael, Velthe's Observatory, Reya's Cairn, Far Hills,
  Eastern Reaches, Northern Wilds, the Tower, the Academy. Plus a
  post-game superboss (THE FIRST CHORD, Cave 8).

### Contradictions resolved (per user direction, expand-canon mode)
- **Cave 3**: code's TIDEWATCH is now canonized as the GHOST of the
  bible's old HARBORMASTER. Call-and-response duel mechanic preserved.
- **Cave 4**: GLASS CAVERN is the glass-vitrified buried Phrygian
  palace. TWO bosses now canon: DUNE RIDER (gate, upper) and THE
  FIRST CALL (shard-holder, lower throne room).
- **Cave 5**: split into TWO locations — LIRAEL cathedral catastrophe
  (Act 3 narrative event, boss = THE BROKEN CADENCE, no shard drop)
  and the ICE GROTTO (Cave 5 proper, boss = SNOWGAUNT, shard drop).
  Lirael's last queen sent the shard north before the cathedral fell.
- **Cave 6**: both locations canon — OBSERVATORY above and LOCRIAN
  CRYPT below, connected. THE TRITONE is mid-boss (upper), LOCRIUS
  is shard-boss (lower). Locrius is now lore-tied to Velthe.
- **Cave 7**: TWO STAGES — defeat Suno first, then sustain the Held
  Chord for one minute. Ionian shard is GRANTED by the ceremony,
  not looted from Suno.
- **Lieutenants**: all three (Kael, Quartermaster, Arsen) kept as
  PLANNED. Arsen anchored to the Lirael catastrophe.
- **Resonances**: kept and expanded as worldbuilding lore even if
  the summon system never ships as gameplay.

### Added to bible
- New region entries: LIRAEL, the SAGE CIRCLE & Velthe's Observatory,
  the TOWER & Suno's Domain, plus capsule entries for Eastern Reaches,
  Northern Wilds, Western Region, Far Hills, Escape Cave, Reya's
  Cairn, the Academy.
- New NAMED CAST section: stubs for 18 named NPCs in code that the
  bible hadn't acknowledged (Capt. Ren, Page, Mira, Iolen, Iska,
  Aurin, Wena, Sergei, Paj, Niko, Winna, Brann, Lutist, Echo, Reya,
  Rider, Wanderer, Elder). Each marked STATUS: STUB pending future
  backstory development. Lore-significant figures (Velthe, Iola,
  Locrius, Harbormaster) given full treatment in their region sections.
- New BESTIARY — STANDARD ENEMIES section listing the 26 code-canon
  enemy types by region, with lore guidance that enemy types reflect
  their region's mode.
- New CAVE 8 entry: THE FIRST CHORD as post-game superboss in the
  Crystal Synth's core.
- Header date updated to 2026-05-14; preamble updated with new
  STATUS conventions (IN CODE / STUB / PROPOSED / PLANNED).

### Notes for future sessions
- Several enemy lists in the bestiary (Cave 5 in particular) keep
  the bible's flavor-named placeholders alongside the code's actual
  enemy types. Future passes should decide whether to align code
  to bible names or vice versa.
- Stubs in the named cast are deliberately thin — they exist so
  future sessions know the character is real, but their backstory
  is open. Don't treat stubs as canon, treat them as placeholders.
- The Lirael / Ice Grotto split is structurally important: the
  Broken Cadence does NOT drop the shard. If implemented in code,
  this needs to be coded as two sequential dungeons in Act 3.

## 2026-05-14 — intro cutscene overhaul

Replaced the 4 "court emptied months ago" panels with a 12-panel
"Lirael ordinary night" sequence (21 panels total). 21 new
draw_scene_* functions, 21 new SCENE_DRAW entries. Cosmic + Dark
prose preserved (Dark trimmed 4→3). Existing wake/breach/throne
scripts untouched.


## 2026-05-16 — Resonances acquisition (Miel vertical slice)

Added the Resonances acquisition scaffold per
docs/specs/2026-05-14-resonances-acquisition-design.md. Miel's
full path lands: Tisa gives the bell on first cleric-lead
interaction; walking onto the throne hall's tapestry alcove with
the bell + Miel as lead fires the shared attunement scene; The
Ring becomes callable on R2 in battle (6 MP, deducted at
queue-time per existing MAG pattern). Banner + signature bell
tone confirm the call landed; effect itself stubbed as a normal
ATK pending a follow-on spec.

Also: made `party` + `active` globals (matching the documented
CONTENT pattern at line 2487) so the NPC dialogue closures inside
the CONTENT table literal can read them — fixed a crash on Tisa
that would have hit Maro/Tova/etc. eventually too. And: footstep
dust puffs now apply interior_view_offset (small-map centering),
mirroring the SCENE.draw fix from 2026-05-14.

Other 7 Resonances stubbed in the data tables; their
item/shrine/signature blocks fill in later passes. ECHO will be
the 8th party member when designed.

## 2026-05-19 — The Ring combat effect + UX polish

Wired the Ring's actual combat behavior per
docs/specs/2026-05-17-ring-effect-design.md. RESO branch no
longer deals stub damage — it arms p.ring_armed; the next ATK
fires the empowered hit (1.30x damage + dual-tone clangor [root
+ fifth] + larger burst + screen shake) and consumes the flag.
Stacks multiplicatively with crit and buffed.

Lifecycle: cleared in 5 reset sites (reset_party_for_battle + 4
enter-battle per-party-loops) and on KO. R2 refuses to re-arm
silently if already armed. HUD bell glyph (5x5) on the armed
character's column, slower pulse than rhythm-crit '♪'.

Polish during playthrough:
- Removed "* The Ring *" and "* already armed *" banners — the
  signature bell + HUD glyph carry the feedback; banners blocked
  gameplay view.
- Static Page NPC in the castle hallway now also gates on
  `not SCENE.active`, fixing a visible double-Page during the
  page_warning scene (one cinematic actor + one static NPC
  overlapping).

Effect dispatch still inlined into the ATK branch — extract when
the second Resonance effect lands.

## 2026-05-20 — ECHO joins the party (8th member, wraith class)

Extended the canon astrolabe ECHO NPC into a recruitable 8th
party member per docs/specs/2026-05-19-echo-eighth-party-member-design.md.
New wraith class: new SynthDef sq_wraith (granular stutter +
high-register CombC echo-train), new 8x8 sprite (max brightness
9 -- visually translucent), new STIR action (3-grain MAG-scaled
chord; 6 MP -- note: the only instrument action that costs MP,
flagged for playtest), new DISPERSE limit break (5 ghost-bursts
at MAG*4).

ECHO joins at the Academy courtyard astrolabe (map 19, tile 13,6)
during Act 3's "World of Silence" beat. Trigger gates on
CONTENT.act3_silence OR CONTENT.debug_force_echo_recruit (the
latter for testing before Act 3 systems land). Recruitment scene
auto-grants the Long Echo sacred item; shrine = the astrolabe.

Reconciliation note: the fluid-invocation merge (which landed
since the ECHO spec was written) made the RESO branch generic --
it reads RESONANCE_SITES[rid].shrine.signature.sound for SFX and
RESO_ANIMS[rid] for animation (play_long_echo_anim already
existed). So Long Echo needed no per-Resonance RESO dispatch and
no armed flag (the fluid system only arms Ring). ECHO's Long Echo
fires SFX + animation + 6-tick cooldown on R2; combat effect
remains stubbed.

NOT YET VERIFIED ON DEVICE -- requires SYSTEM > RESTART for the
new sq_wraith SynthDef, then the 12 acceptance criteria in
docs/plans/2026-05-19-echo-eighth-party-member.md (Task 19).

This commit also carries pre-existing uncommitted working-tree
fixes from a parallel session (SHOP/shards _G-mirror closure
fixes, Senna/Pell repositioning) that were intermingled in
synth-quest.lua and could not be cleanly separated.

## 2026-05-20 — Niko / The Heavy Hand acquisition (Ruined Drum-Hall)

New map 37 (Ruined Drum-Hall) off Phrygian Night City. Niko takes
the legendary drummer's iron hand-guard from a plinth (tile 90),
then strikes the great war-drum (tile 91) to attune The Heavy
Hand. New transition tile (92) at Phrygian (35,12), gated on
recruits[3].joined (rubble-blocked before Niko joins). Two-step
find->attune via the existing start_resonance_attunement scaffold;
new "tile" item kind; signature warrior-voice thud +
phrygian_drumhall_resonant shockwave-ring scene draw. Bible NIKO
stub + Ruined Drum-Hall canonized. Device-verified (9/9 ACs).

Acquisition only — the Heavy Hand combat effect (duck_enemies) is
the parallel resonance-effects pass's job.

## 2026-05-21 — Shrines complete + Ice Grotto (catch-up note)

Batch that landed right after the Niko entry, logged here
retroactively: the Spring wired as bard heal-echo (Miel's HEAL —
and, since 2026-07-02, Alder's LUTE — echo twice at 25% per bar
when armed), the Spring acquisition shrine (Alder / bandstand),
the four remaining Resonance shrines, the Ice Grotto enemy set
(Cave 5, from bible), Broken Cadence Ionian weakness + bestiary
lore, Silencer battle sprite, Winna cleric-aware line, and
count_shards promoted to a global (restores the Iola letter
path). All 8 Resonances now have acquisition + combat effects.

## 2026-07-02 — ACT 3: The World of Silence + polish

The big one this session: CONTENT.act3_silence existed only as a
read (the ECHO recruitment gate) with nothing ever setting it —
the 8th party member was unreachable outside the debug flag.
Implemented the World of Silence as a compressed version of the
bible's Act 3:

- Six-shards fountain scene now ends with Suno answering: a
  quarter-tone-bent root from far away, the world's pitch lets
  go of its moorings, act3_silence set. Diegues (or Miel if no
  mage in party) points to the Academy astrolabe. Final flash
  becomes "* the world has lost its tuning *". Skipped when ECHO
  already joined via debug path.
- The bible's midpoint twist, literal: while the flag holds,
  fire_ow_voice bends every note by a random continuous offset
  up to ±6 semitones. Rhythm, voices, register intact — only the
  tuning is gone. Battle themes route through the same funnel,
  so fights during the silence go atonal too — kept deliberately
  (bible: atonal-mode combat, "the fights feel naked"). Scene
  sfx and player jam notes stay in tune.
- Review fixes (subagent adversarial pass): ECHO's map-19 gate
  re-checks SCENE.active fresh so a first-ever Academy entry
  during the silence can't have ECHO's scene wipe the academy
  intro (which would have lost Diegues + Strom for the run);
  act3_silence cleared FIRST in the recruit set-closure (pcall
  safety); migration [2] also checks the ionian shard so v0
  finished saves don't re-arm the silence.
- ECHO's recruitment clears the flag with a re-tune beat (true
  A + E fifth, "I will hold the note. You hold me."). Suno's
  defeat clears it as a backstop; NG+ reset clears it too.
- Persistence: SAVE_VERSION 1→2. data.act3_silence saved and
  restored; SAVE_MIGRATIONS[2] re-arms the flag on old saves
  sitting between six-shards and ECHO/ending so ECHO stays
  reachable.

Also this session:
- Committed a prior session's playtest fixes: banner bleed into
  scripted battles (clear_pending_banner), zone-tempo resume
  after battle (overworld_tempo), removed the flaky L2 BPM
  editor (BPM editing lives in Jam mode).
- Spring now echoes the bard's own LUTE heal (routed through
  heal_party) — it was dead weight in cleric-less parties.
- Housekeeping: viewer/mac-run.sh committed, built .app bundle
  gitignored, fully-merged feature/resonance-effects branch
  pruned. The spring-resonance branch (Spring-as-regen "Spring
  Wash", 2026-05-20, still checked out in a superpowers
  worktree) is SUPERSEDED by main's heal-echo Spring — kept for
  reference, do not merge.

NOT YET VERIFIED ON DEVICE: the World of Silence needs a real
playthrough of the six-shards → Academy → tower stretch (no new
SynthDefs, so no SYSTEM > RESTART needed — script reload is
enough).

## 2026-07-02 (later) — narration is never spoken by a character

User pass: "make sure narration is not spoken by a character; make
sure all scenes and dialogue make sense." Full audit (subagent swept
~1,500 [Name] tags + every scene dialogue step) + fixes:

- Renderer rule: inside scripted scenes, an UNTAGGED fully-
  parenthetical line renders with no speaker header (it's scene
  description). Scoped to SCENE.active on purpose: outside scenes,
  examine-objects (Fountain, gravestones, shelves) speak entirely in
  parentheticals and need their name labels, and an NPC's own stage
  direction under their label is the game's idiom. Long narration
  lines must stay under ~75 chars or the packer splits them and the
  fragments lose their parens (two such lines split at source).
- Tag parser now allows multi-word speakers ("[Cave Echo]",
  "[Dune Rider]" — the latter had NEVER rendered as a tag). All four
  tag-matching sites use the same pattern.
- Cave-1 boss retagged [Echo] → [Cave Echo] (it was pulling the
  academy-girl Echo NPC portrait); sprite aliased.
- CHAR_NAME.wraith="ECHO" (level-up on ECHO was a nil-concat crash)
  + DLG_NAME_TO_CLASS.ECHO so her portrait renders in scenes.
- Prologue throne scene sent the player SOUTH to a tapestry that has
  been in the NORTH wall since Pass 61 (line, facing, flash + five
  stale comments all corrected).
- Niko was "she" twice in the Heavy Hand acquisition narration.
- Second village smith "Bren" (accidental duplicate of the Lirael
  steward's name, stealing his sprite) renamed ANVEL; steward Bren
  got his own sprite. Bible updated.
- STORY lines can now be a function; Strom's solo campfire beat only
  recounts the Sergei conversation if Sergei actually joined (new
  alternate lines otherwise). (The Sergei/Niko group campfire lines
  were already safe — STORY.filter_party_lines drops absent members.)
- ECHO added to the ending name-song + her own ending panel.
- scout_trapped NPC display name → "Scout".
- Misc: garbled academy-choir baton line, Vix backticks, stale
  comments.

Also this pass, from a sprite/scene audit: every party class, ~96
named NPCs, and all 36 enemy visuals have dedicated art (no
placeholders). KNOWN GAP (not yet built): 5 of 8 Resonance shrines
have no full-screen panel art (masked_voice/spring/scatter/
slow_wheel/threefold), and NO attunement scene actually displays its
signature.visual key — the 3 existing panels (bell alcove, astrolabe,
drum-hall) are orphaned. Candidate follow-up pass.

## 2026-07-02 (later still) — show, don't tell: animating narrated actions

User direction: JRPGs shouldn't caption character actions — you
should SEE them. First conversion pass over the highest-traffic
scenes, replacing parenthetical action narration with real scene
choreography:

- Six-shards fountain: Alder turns to the fountain (face step, was
  "(looks at the fountain)"); Diegues' book-taps are two soft
  high-register clicks you hear; Miel's basin touch is a camera
  drift to the fountain + a small water-bright chime.
- World of Silence beat: Diegues' "(turns a slow circle,
  listening)" is now an actual four-facing slow turn.
- ECHO recruit: her shuddering outline is a real despawn/respawn
  flicker with a stuttered half-syllable sfx; the "(a flicker; she
  nearly vanishes, returns)" mid-line became a longer on-screen
  blink between her two lines; Miel's "(steps forward; offers her
  hand)" is a real one-tile move toward ECHO (direction computed
  from spawn positions).
- Niko recruit: "(sets down the drumsticks)/(picks them back up)"
  became wood-click sfx beats inside the existing face-down/
  face-left choreography.

AUTHORING CONVENTION going forward: in scripted scenes, physical
actions by present actors get choreography steps (face / look /
move / sfx / flicker), not captions. Parenthetical narration is
reserved for what can't be shown on an 8x8 sprite: atmosphere,
interiority, sound-images ("Half a syllable, then nothing."),
world description. NPC-talk stage directions outside scenes keep
the game's existing caption idiom.

Remaining candidates for future passes (not yet converted):
prologue castle/Lirael scenes, boss-approach scenes, finale, and
the attunement scaffold (whose orphaned signature.visual panels
are a separate known gap).

Pass 2 (same convention): finale — dropped "(without turning)" and
"(He stands at the center of the chamber.)" (both visible on
screen; his slow turn was already staged); endgame — Strom's
"(looks east)" is a real face-right beat mid-line, Diegues'
"(closes the leather book)" is a soft click sfx. Miel's "(kneels,
palm flat to the basin)" kept — an 8x8 sprite can't kneel; that's
exactly what narration is for. Prologue throne scene reviewed and
left alone: its captions are atmosphere already paired with
shake/sfx staging.

## 2026-07-02 (night) — the 8 Resonance signature panels finally show

Built the 5 missing shrine panels AND the mechanism that displays
all 8 (the 3 that already existed — bell alcove, astrolabe,
drum-hall — were orphaned art nothing ever invoked):

- New SCENE steps: {show_panel = "<SCENE_DRAW key>"} / {hide_panel}.
  Panel draws at the very end of draw_overworld — over the world,
  under the dialogue box and the global fade. Cleared on
  SCENE.start, scene end, and load_game.
- build_resonance_attunement_script shows sig.visual for the
  signature sound (a ~36 hold so you actually see it), through the
  dialogue, and a clean ~20 hold after, then hides it before the
  banner.
- Five new panels, matching the established idiom (dark ground,
  location silhouette, tick-animated resonance motif, solid
  character silhouette):
  - observatory_masked_voice — Velthe's star-window + floating
    mask; the voice-line beneath it re-sings itself as a square
    wave every half-cycle.
  - sunward_bandstand_resonant — bandstand at golden hour; Spring
    droplets rise through the boards; every water ring is answered
    by a dimmer echo of itself a beat later.
  - phrygian_scatter — night bazaar; seven bright points jump to
    new (hash-deterministic) positions every beat around Sergei's
    rig.
  - sunward_slow_wheel — the harbor capstan turning slow and even
    on its own, Strom's hand on the rim.
  - academy_threefold — three tuning forks struck as one; three
    ring-sets bloom and meet in the middle.

Review (subagent) caught the killer before it shipped: the panel
hook lives in draw_overworld, which is defined BEFORE the
`local SCENE_DRAW` declaration — the reference compiled as a
never-assigned GLOBAL read, so every panel would have silently
drawn nothing (the documented Lua local-scoping trap; luac can't
see it). Fixed with a _G.SCENE_DRAW mirror, same pattern as
_G.travel_to. Also per review: per-droplet fill in the bandstand
loop (level batching), SCENE.panel cleared in the end-of-script
reset, longer unobstructed holds around the dialogue box.

NOT YET DEVICE-VERIFIED: needs an attunement playthrough (no new
SynthDefs — script reload is enough).

## 2026-07-02 (late night) — pacing, Lirael = the castle, trap + glitch fixes

User playtest reports, all fixed:

1. "Lirael entry scene absurdly slow / frames dropping" — root
   cause was systemic: the ENTIRE game loop (tick + SCENE.tick +
   redraw) synced to clock_tempo quarter-beats. Lirael's mourning
   theme is 48 BPM → the whole game ran at 3.2 fps there (village
   100 BPM = 6.7). Fixes:
   - Scenes + dialogue now run on a FIXED 10 Hz clock
     (scene_clock_id), decoupled from musical tempo. Every scene
     plays at the same pace in every zone; scene waits are now
     fixed-time (wait = 20 ≈ 1s). Music keeps syncing to the beat.
   - Dialogue typewriter converted to REAL time (util.time, 55
     cps) — was 4 chars/tick, i.e. tempo-dependent.
   - SCENE.draw_fade dither coarsened from per-pixel (8192 iters +
     up to ~4k path ops per frame) to 2x2 blocks — the mid-fade
     frame cost was the "dropped frames" feel.
   Known deltas (reviewed, accepted): scene tweens now also ease
   during dialogue; ANIM.shake decays per-redraw so scene shakes
   read shorter.

2. "Lirael ruins are nothing like the castle" — they are now. The
   NW block (cols 1-11, rows 1-5) was rebuilt as the RUINED THRONE
   HALL mirroring prologue map 20: rubble-choked breach (blocking
   tile 81) in the north wall where the tapestry escape hung,
   ruined throne (53) at cols 8-9 echoing the castle dais, carpet
   remnant running out through the split south doors. First-visit
   scene restaged there: camera opens on the throne, Miel walks
   the carpet to the dais, "That was a tapestry. It bought me my
   life."; Diegues confirms the geometry ("The dais. The split
   doors. The breach where the tapestry hung."). WhiteBird perches
   on the throne's broken back. Page waits in the hall, toy ball
   beside her. The broken-window ambient moved to the hall's west
   wall (2,2).

3. "Sequence traps you in a room with no doors" — the old NW
   "royal quarters" had a room (cols 7-11, rows 2-4) with NO door
   at all and a decorative door to nowhere at (5,2). Dissolving
   the rooms into the open hall removes the trap class entirely.
   (If the user's trap was somewhere else, it's still open — ask.)

4. "Long grey horizontal line mid-screen while walking" — the
   night cue drew a full-width dim line at y=47 on outdoor maps
   during the night phase. Removed; the top-edge line + stars +
   moon carry the cue.

NOT YET DEVICE-VERIFIED: Lirael entry playthrough + a feel-pass on
the new fixed scene pacing (10 Hz; easy to tune via the
scene_clock sleep if scenes now feel too brisk).

## 2026-07-02 (later) — playtest fixes: prompts, pace, visible silencers

- "A: talk" (and cave/inn tile prompts) no longer flash during
  scripted scenes — the whole prompt block is suppressed while
  SCENE.active.
- Scene clock raised 10 → 15 Hz on feedback that scenes still
  played too slowly (wait = 30 ≈ 1s now). Single constant if it
  needs further tuning.
- Courtyard breach: the silencers fought the entire battle
  OFF-SCREEN — the map is 12 rows, the camera's opening focus
  showed rows 4-11, and the silencers spawned at row 14 and
  stopped at row 12. Guards visibly fell to nothing. The camera
  now pans down to the gate row when it breaks, and silencers
  spawn one row closer so they emerge promptly. (The Hova/Borin
  section already refocused correctly.)

## 2026-07-02 (late) — bounds/staging guards + full coordinate audit

User principle adopted: "check that we aren't putting things outside
the dimensions we're working in." Two layers:

1. RUNTIME DEV GUARDS (maiden console only): SCENE.check_bounds warns
   when a spawn/move/teleport target lies outside the current map
   (mark deliberate entrances `offmap = true` — courtyard silencers
   + prologue throne Suno/silencers are flagged); check_visible warns
   when a bump plays outside the camera window. teleport_player
   off-map always warns.

2. STATIC AUDIT (subagent, full map inventory: 35 maps, all row
   widths verified; 136 NPC placements; 59 travel_to targets; ~45
   scenes walked against the camera model). Findings, all fixed:
   - THE TRAP: start_academy_intro was authored for the old 10x9
     academy; on the 28x14 map it teleported the player to (6,6) —
     inside a sealed 3x2 courtyard building with NO DOOR. Every
     playthrough ended the academy intro entombed. Scene fully
     restaged in the lecture hall (player parks/returns at (7,3);
     Diegues at the west lectern; Strom enters along the corridor).
   - travel_to(19,5,7) (academy front door) spawned INTO A WALL on
     every re-entry → now lands at (14,12) like the tile-78 door.
   - travel_to(21,2,5) (tapestry → escape cave, every playthrough)
     spawned into a wall → (2,6).
   - miel_walks_alone: "Mother. I'm here." + the Queen's Echo played
     ABOVE the camera window (courtyard-bug class) → altar refocus
     added after her walk.
   - echo_recruit: party spawned at the map-entry point — entering
     from the south corridor put all four below the window for the
     entire scene → staged at fixed courtyard positions in-window.
   - courtyard breach: camera now pans to the gate row BEFORE
     Hova/Borin's runs (their arrivals were landing off-screen).
   - Iola's letter: she now speaks + hands the letter over on-camera;
     the library pan happens for the letter text only.
   - Stale dimension comments corrected (academy "10x9"/"map_id 17",
     cave 7 "16x14" (it's 12x6), ambient dispatch coords, guard
     columns) — this class of stale comment is what seeded the bugs.

## 2026-07-02 (device playtest) — three more academy box traps

User hit it live: "after you get Strom you're literally trapped in a
box." finish_academy_arc (the Strom-join epilogue) still parked and
returned the player at (6,6) — inside the sealed courtyard building —
along with TWO more scenes using the same pre-expansion staging:
start_diegues_study_scene and start_academy_choir_scene (whose choir
students also stood inside wall tiles). All three restaged in the
lecture hall to match the restaged intro (player parks/returns at
(7,3) / (7,4)). Grep confirms no (6,6) parks or teleports remain.
Lesson for the audit method: "checked clean" must include walkability
of the RETURN position, not just map bounds.

## 2026-07-03 — recursive audit loop, waves 2-3

Wave 2 (dialogue regions + restage verification): sage-quest name
collisions (Phrygian Mira / Sunward Iolen / academy Aurin credited
Tova's quest); start_dialogue set quest flags BEFORE scene closures
ran, so every sage's choreographed first meeting was dead content;
Aram/Strom rank inversion; Iolen's gender drift; 7 post-victory
ionian reacts told the player to kill an already-dead Suno; Mira's
wetland react imagery on a dunes sage; guide Sergei→Serik; Tide
Stone + flat-second now real (granted once / actual grace note on
LUTE); Miel's exile timeline reconciled; Iret/Vance/Tess campfire
refs gated on meeting them; my own echo_recruit restage had put
Strom INSIDE the sealed academy building (fixed east, cols 10-18);
Theron/Aurin now hide during scenes.

Wave 3 (areas + systems): the Observatory's ENTIRE upper floor was
unreachable (orrery + 5 constellation scenes + trapped-Scout quest =
dead content) — alcove wall opened at col 13; sealed east wing got a
door + Velthe's draft shelf; Far Hills entry spawned in a tree;
Cave 7 random encounters could spawn SUNO HIMSELF in a hallway
(ending fired from a random encounter — pool removed); second
observatory entrance ungated vs its twin; escape-cave wisps were
embedded in walls; furniture-standing NPCs seated properly; Suno's
Domain stray trees→ash; Far Hills gets its promised sheep (+sprite).
Systems: rare-enemy visual collision granted FREE SHARDS via
clear_boss (masked with is_rare); rares now pay real XP/gold;
scatter no longer corrupts shared enemy attack-pattern templates
(per-battle copy); tess_defected/tilde_paid/wisp_paid persisted
(save-reload gold dupes); return_map trio persisted (cave exits
after Continue no longer dump to the village); norns-key players
can now leave CREDITS into NG+ and get the proper prologue warp on
cutscene skip; NG+ resets pith quest, cave_entered, STORY.seen and
the flag table (keeping learned gifts); JAM refuses GAME_OVER/
CREDITS. Victory fanfare deliberately stays in tune during the
Silence (same rule as player notes).

## 2026-07-03 — wave 4: the World of Silence was unreachable (again), ending fixed

Progression audit findings, all fixed:
- THE BIG ONE: clear_boss unconditionally overwrote CONTENT.queued_scene
  with "boss_aftermath_N" AFTER obtain_shard queued "six_shards" — and
  the 6th shard always comes from a cave 1-6 boss, so the six-shards
  scene (and the entire World of Silence + ECHO recruitment) never
  fired on any route. Aftermath now yields to bigger queued beats.
- ENDING → CREDITS chain: credits were a queued_scene consumed only by
  the NEXT battle won — finish the game and never fight again = no
  credits, no NG+, no endgame_done ever. ENDING dismiss now chains
  directly into start_endgame_scene.
- load_game ran travel_to BEFORE restoring story flags: Continuing a
  save made inside the academy replayed the entire intro + Strom
  fight. travel_to now runs after all restores.
- Freshly-joined recruits didn't exist in CHARACTERS until save+reload
  (couldn't be swapped in): ensure_recruit_character() at ALL EIGHT
  join sites + autosave on every recruit join.
- Party-select reserve UI drew 3 cells while focus cycled all: window
  now scrolls with focus.
- Lirael tile-51 entry gated like its twin (4 shards + mystic).
- Key of Lirael now actually opens the Ice Grotto (cave 5 gated on it,
  per the bible's Lirael → Ice Grotto sequence; Paj consequently sits
  behind Lirael too).
- Observatory upper-floor encounters crashed (enter_battle got MAP id
  13 instead of cave id 6); double-Iola in the first-visit scene;
  cliff-reeds ambient read the prologue wisp tracker instead of cave-3
  state; comment corrections.

## 2026-07-03 — every door leads somewhere (buildings revamp, phase 1)

User direction: "buildings should be consistent — weird facades with
purposeless doors everywhere, but enterable buildings take 1 square.
I want to enter the blacksmith's shop."

Inventory found the root truth: tile 5 (door) had NO handler — every
exterior door in the game was fake (8 facades across MAINLAND +
SUNWARD). Built the parametric house system: one interior map id (38)
+ CONTENT.HOUSES registry keyed "map:x,y" of the door tile; t==5
handler stashes return position (and the OUTER region warp, restored
on exit) and warps into the keyed interior; save/load persists
house_key and rebuilds the right room on Continue.

Eight interiors, each 10x7 in the inn/shop furniture vocabulary with
flavor objects in the game's voice: Tova's house, Pip's family house,
the Elder's cottage, BRANN'S FORGE (workbench, quench barrel, spare
plate = one-time 15g), Wynne's fisher cottage, the harbormaster's
widow's house (two cups; one unmoved for years), Beck's cottage
(+Salt the cat), and THE TAVERN — Hask now stands behind his own bar
(he lived in a 1-tile corridor before) with Vesa at a table; the
Slow Wheel attunement rewritten for the indoor capstan-ring relic.

Also: backwards Sunward cottage facades rebuilt (doors faced the map
edge); academy's two sealed courtyard boxes got doors + practice/
listening rooms; Far Hills ruin opened into a shepherd's bothy;
Fountain object moved onto the actual fountain tile.

Verification loop caught this batch's bug: TOVA and BONK were
standing on the only approach tiles of two house doors, sealing them
— moved one tile aside. Also preserved the Sunward→mainland signpost
warp across house visits (outer_return stash).

Phase 2 (same pass): terraced storefronts — every town inn/shop
entrance (1-square buildings) now sits flanked by matching
storefront-wall tiles (new tile 93: timber, eaves, deterministic lit
windows), so the village/eastern/northern inns and shops read as real
multi-tile buildings consistent with the house facades. Sela stepped
one tile off the eastern shop's new flank.

## 2026-07-03 — wave 5: Beck freed, region warps hardened, echo crystals

- Tile 60 (wood dock) was never in is_walkable: Beck — his Tide
  Cavern hint, the warrior job offer, the dock-gull ambient — was
  unreachable since the Sunward Coast shipped. One token: or t == 60.
- Region-warp trio hardened: outer_return persisted in saves and the
  cave-3-from-Sunward / cave-4-from-Phrygian entries now stash it
  like houses do; any interior pop restores it.
- Chests/campfire sitting on impassable sand/tree tiles relocated
  (north snow chest, northern campfire + scene key, woods chest).
- Sunward market-cry ambient moved off an impassable stall tile.
- Tavern bar gained a service gap: Hask reachable in 4 steps.
- Cave 1 finally has its theme: echo crystals (new tile 94, shimmer
  + slow glint) at four chamber positions. (Cave 5 ice / cave 6 crypt
  deserve the same treatment in a later pass.)

## 2026-07-03 — wave 6: UI screens + cave themes

Cave 5 has ice pillars (tile 95) and cave 6 grave-candles (tile 96),
completing the per-cave theming that started with cave 1's echo
crystals.

UI audit findings, all fixed:
- Norns-only players were soft-locked in FOUR screens (Quests/Shards/
  Bestiary/Party — no key() branches existed; the CREDITS bug class
  again) and couldn't open Map/Achievements at all. Full norns key +
  encoder navigation added to every info screen.
- The pause menu overflowed 64px with 11 options — rebuilt as two
  columns.
- Rare kills were overwriting boss/base bestiary entries (shared
  visuals): rares are name-keyed now, marked "(a rare, greater
  strain.)".
- The achievements screen silently dropped entries 14-15; "Rare
  Hunter" was granted but undefined; layout now scales.
- Pith's quest joined the journal; the World of Silence finally has
  an on-screen "detuned" cue (battle bar + overworld corner); Long
  Echo charges and the Threefold window got HUD glyphs matching the
  Ring bell; ECHO's name now renders in status + XP summary.
Verification pass: first batch to come back with zero blockers.

## 2026-07-03 — wave 7: fresh-angles polish (engine surface verified clean)

Unconstrained sweep took seven new angles (Lua↔SC command surface,
audio lifecycle, JAM/MIDI, input ordering, viewer stream, draw-loop
truthfulness). Zero blockers — all 33 engine commands match, every
sq_trig call is arity-correct, drone lifecycle is sound. Polish
fixes: MP-starved STIR falls back to ATK with the denial flash
(was a silent wasted turn); wraith joins the FX-latch broadcast +
gets its own MIDI channel; MIDI-in device is now a param (was
hardwired port 1); JAM footer tells the truth (X mode, A latch);
four music tickers had nil-guards after the arithmetic; HDMIMirror's
retry hitch cut 0.5s→0.1s; bark bubbles clamp on-screen; title
flash timing moved off the frame rate; dead battle_end_ticks chain
and the unreachable battle-SELECT branch removed.

## 2026-07-03 — FF revamp: style guides + area wave 1 (village)

Two specs committed: docs/specs/2026-07-03-ff-dialogue-style.md
(character verbal signatures, FF punctuation, banter texture,
melodrama at the pillars — amplify the existing voice, never
flatten) and -ff-area-style.md (composition, layered density,
water features, district texture + the decorative tile kit).

Wave 1 shipped: 13 new decorative tiles (fences, flowerbeds,
walkable flowers, bench, crates, well, night-glowing street lamp,
hedge, walkable bridge, statue, deco signpost) and the village
composed FF-style: fountain plaza with paving ring/lamps/bench/
flowerbeds, picket side-yards on the three houses, market clutter
behind the storefronts, a well by Tova's, flower meadows. BFS
verified: zero unreachable cells, every door/arrival/NPC clear.

## 2026-07-03 — FF dialogue wave A (party voices)

48 scenes reviewed; 22 touched. The existing writing was already
well-voiced (as the guide predicted), so the wave was surgical:
17 substantive rewrites (Diegues now quantifies badly and corrects
himself; Strom got terser; Alder's deflections sharpened), 4
anti-goal violations fixed ("English, please" / "the bits with no
plot" fourth-wall breaks, modern slang), 6 single-line banter beats
added at pillar scenes (Miel finally speaks in the Strom epilogue:
"Then rise, captain. We watch together."; ECHO answers "We will not
let the silence have you" with "...have you. (...) You. You have
me."). ~445 lines kept verbatim.

## 2026-07-03 — FF area wave 2 (Eastern + Northern towns)

Eastern: caravan-market texture (stall crates + rope-fence edge by
Sela, storefront clutter + street lamp between the doors, bench at
the boat landing, road signpost toward the waypost, dune ripples in
open ground). Northern: hearth-village (lamps flanking the
storefront row, wood-pile yard by the shop, hearth-side bench,
stone cairn marking the observatory turn). BFS-verified both maps;
two route hazards caught during placement (Hask's boat-road squeeze,
the northern inn's mandatory corridor) and avoided.

## 2026-07-04 — FF dialogue wave B (village NPCs)

Every village NPC now has one vivid want, threaded through their
shard/lead branches (recorded in the bible): the Elder's ledger of
returning things; Tova's petty scholarly vindication; Lyrik's
drafted sad verse he wants to be forced to rewrite; Anvel's
one-sided anvil rivalry with the serene Brann ("It is not my
ears."); Pip as the village's one loud person (chalk tally, IT IS
NOT CROOKED); Wren picking towns by where music died last; Pell
confidently wrong about the fountain's key. ~21 branches rewritten,
~55 kept verbatim (27%). All quest mechanics untouched.

## 2026-07-04 — FF area wave 3 (Sunward, Phrygian, overworld routes)

Sunward promenade: cottage flower boxes, bench + lamp at the water
viewpoint, tavern lamp, dock-end crates/barrels. Phrygian (doorless
language kept): prayer-court lamps, bazaar statue, stall spillover.
Overworld: road-fork signposts, meadow flowers, a waypoint statue at
the Western arch; Western Region: academy lamp, Lirael-fork
signpost. 171 scripted checks green. Also fixed two flags the wave
surfaced: tile 62 (bandstand) was never in is_walkable despite its
legend — Coral was unreachable (the tile-60/Beck bug class again);
Wina stood ON the Western→Mainland arrival tile.

## 2026-07-04 — FF dialogue wave C (region towns)

Twenty NPCs across Eastern/Northern/Sunward/Phrygian got their one
vivid want (bible-recorded): Marek's hawk-delivered gossip and
bundled OPINIONS; Mara keeping the harbor ledger correct for when
her husband asks; Coral needing "two more weeks, maybe three" before
the REAL stage; Phrygian Brann embracing the name collision ("Yes,
THE Brann. No, not the smith. Better beard."); Aram's slate of every
man he commanded; the lamplighter's nightly score against the dark.
One loud person per town (Marek/Coral/Brann; Northern stays quiet).
~55 of ~200 lines rewritten; villain cast + Suno's court kept
verbatim (already FF-grade). Two stale merchant references fixed.

## 2026-07-04 — FF dialogue wave D (bosses + pillars)

Every cave boss now has a distinct register — the previously MUTE
Sentinel ("I have outwaited mountains. I will outwait you.") and
Tidewatch ("((Come down. Be kept.))") speak; Cave Echo says words
Miel never said; the Dune Rider's courtesy ends; Locrius needles.
Suno gained one line of intimate contempt ("I have heard every lie
this family ever sang."); the Broken Cadence names Miel before "You
must."; VoidEcho went full cosmic-superboss. Defeat banner:
"* you fall back. the song is not over. *". Ending kept 26/26 —
already FF-grade. Timeline guard caught a Snowgaunt line that
contradicted the bible before it shipped.

Final revamp verification: clean across all seven waves (renderer
safety, dual-copy boss lines, 44-map width + BFS mega-check, tile
kit isolation, want consistency). One pre-existing catch fixed on
the spot: a leftover "Lirael bell-tower" TILE_DRAW[32] from the old
courtyard map was clobbering the dining-table drawer — every table
in every inn/shop/house rendered as a stone column. Deleted; tables
are tables again. (Known cosmetic leftovers: dead legacy
BOSS_APPROACH table, bible/code drift on one Brann line.)

## 2026-07-04 — JAM mode-cycling was inaudible (user report)

"Changing the scale in jam mode during the opening castle sequence
doesn't change what's playing." Diagnosis: THREE things conspired,
all by design, none with feedback: (1) JAM MIDI input is chromatic
passthrough (correct — never snap a musician's keyboard); (2)
nothing else in JAM plays scale notes, so the MODE readout had no
audible consumer inside JAM at all; (3) the castle raid theme is
deliberately scale-locked to aeolian ("the raid always plays
minor"), so even after exiting JAM the zone ignores the mode.

Fixes: cycling the mode in JAM (X or dpad) now auditions the new
scale — a quick 1-3-5 strum on the active voice — so the change is
instantly audible; and the JAM screen shows "(zone key locked)"
next to MODE when the current zone theme won't follow (castle).
NOT yet deployed — norns is away; deploy on return.

## 2026-07-14 — Recursive audit wave 8: animation + dialogue + story

Three parallel read-only auditors (animation choreography, post-revamp
dialogue web, end-to-end story spine), then one fix batch.

### Blockers fixed
- **Dune Rider rendered as a generic warrior** in his boss-approach
  scene — sprite registered as `NPC_SPRITES.Rider` but the actor spawns
  as "Dune Rider". Added the alias.
- **JAM "(zone key locked)" collided with the mode name** and could
  overrun the right edge (worst on default PENTATONIC). Now
  right-aligned `text_right(126)` reading "KEY LOCKED".
- **Split canon on who was queen when Lirael fell.** Canonized: Miel
  reigned three years; predecessor was her GRANDMOTHER (the "old
  queen"); her mother died young, never reigned, is entombed in the
  cathedral nave (the "Mother. I'm here." beat). Bren, the Broken
  Cadence, and the (renamed) Mother's Echo all re-aimed; ROYAL LINE
  block + canon addendum written into the bible.
- **Old shard-order assumptions.** `after_locrian` and
  `pre_finale_night` inn scenes announced "six shards" on
  `shards.locrian` alone — under the Lirael-mandatory flow locrian is
  commonly 5th. Both now require count >= 6. Miel's first-visit throne
  speech and the Suno's-Domain arrival line went count-free (player can
  arrive with 4/5).
- **Cave 7 door now requires six shards** (tower opens at five) — a
  five-shard run could previously reach Suno, skip the six-shards scene
  and the whole World of Silence, and see an ECHO ending beat for an
  ECHO never met.

### Ending is party-aware
`ENDING_LINES` filters at ending time: Sergei/Niko/Paj/ECHO panels only
play if recruited; the name-roll panel lists the actual roster.
Academy panel no longer claims the (standing, restored) Academy "had
stood".

### Scene/choreo polish
- Suno's throne exit: removed doubled wait (1.1 s dead air).
- Courtyard: Borin now visibly reaches the gate first, as the next
  line says.
- Academy intro: shock sting fires WITH the bump, not after; all
  scene spawns uniformly bob=false.
- Shrine panels animate on a fixed 15 Hz `SCENE.panel_t` instead of
  the tempo-dependent music tick (they were near-static in 48-BPM
  Lirael).
- nil-t guards on tile drawers 62/67/70/73/84.

### Dialogue web
- Halla's brothers reconciled ("eldest" fell at Frostridge; Skari
  sells next door). Fig cake from Phrygian Brann now acknowledged by
  village Brann post-quest. Miel no longer tells an already-standing
  Strom to rise. Alder's queenship "reveal" reworked to scale-of-it
  (he's known since his join line). Exile timeline standardized (no
  more "a year"/"months" vs the 47-day count). Locrius serves the
  note, not "my king". Modern idiom scrubbed (remix, divide-by-zero,
  11%). Wren/Hask/Coral n>=7 payoffs now land their own setups.
- Dialogue splitter is ellipsis-aware: "..." no longer parses as three
  sentence ends (orphan-"." pages, mangled "…" seams).
- Dead `BOSS_APPROACH` table + unreachable fallback deleted (~85
  lines, double-maintenance hazard).

### Bible sync
Cave 4/7 statuses → PARTIAL (First Call, Held Chord = vision-only),
Tritone marked not-in-code, Tidewatch/Snowgaunt/Locrius voice-drift
notes, Lirael history rewritten to match the shipped prologue (no
Conductor Arsen; shard went north generations ago), Wina/Winna
distinctness recorded, NG+ key-of-lirael carryover ruled intentional.

### Verify pass (wave 8)
Adversarial verifier confirmed 26/29 items and caught three breaks
before commit: (1) "KEY LOCKED" shared the exact right-aligned anchor
with the unconditional "B/SELECT exit" footer hint (an inherited
collision — the old indicator overlapped it too); the y=63 row now
draws ONE string, "KEY LOCKED  B/SEL exit" when the zone is locked.
(2) Locrius's next line "He thinks you'll arrive tired" lost its
antecedent when "My king" became "The note" — now "Suno thinks...".
(3) Alder's "You can't remix a campfire" was left answering a line
nobody said after Sergei's re-rig change — now "re-rig". Plus four
bible leftovers (Queen's Echo retitle at the signature-scene list,
Snowgaunt's courier in the Cave 5 bestiary, "Princess Miel" in the
Act 1 dossier, Act 3 Arsen block now marked superseded). Noted for
the future: the file sits near Lua's 200 top-level local cap.

## 2026-07-15 — Wave 9: saves / critical-path / audio-engine audits

Three parallel auditors on domains no prior wave owned end-to-end.
Two of them independently found the same top blocker.

### Blockers fixed
- **The six-shards beat (World of Silence + ECHO) could be silently
  lost forever by a reload.** The 6th-shard autosave fired BEFORE the
  scene was queued, and `queued_scene` was never persisted — loading
  that autosave meant the n==6 edge could never re-fire, so the whole
  Act 3 beat and the 4th recruit vanished with no error. Fixed three
  ways: autosave moved below the queue-set, `queued_scene` now saved/
  restored, and load_game re-derives + immediately plays the beat for
  older saves (6 banked, no ionian, beat unseen).
- **A recruit's limit break froze the game.** Sergei/Paj/Niko at ≤25%
  HP firing ATK called `engine.trig_engineer` (doesn't exist) inside
  the music-clock coroutine — clock dies, hard freeze. Fixed with the
  standard voice-family alias (+ bespoke limit banner names:
  "SERGEI: FULL PATCH", "PAJ: PROOF BY VOLUME", "NIKO: DOWNBEAT"),
  plus a nil-guard inside sq_trig so any future missing engine command
  degrades to silence instead of death.
- **Beating the Broken Cadence left Lirael's 48-BPM theme at 100 BPM**
  (the victory path bypasses exit_battle and wrote the global tempo;
  the theme-transition writer never re-fires within a zone). Whole
  wrong-tempo family swept: Broken Cadence + Strom-arc bypasses,
  Jam Pad exits, JAM BPM nudge (which could also stomp a battle it
  was opened from), Sergei-intervention resume (lost the battle_speed
  multiplier), and Continue-from-title (new `resync_zone_tempo()`
  snaps theme+tempo to the loaded map; the old writes played themed
  zones at the global 100 whenever the stale theme matched).

### Also
- SAVE_VERSION 3: migration relocates a pre-gate save made inside
  Suno's antechamber (5 shards) to outside the chamber door so the
  wave-8 six-shard gate binds.
- Confirmed by gate-math trace: locrian-BEFORE-aeolian is genuinely
  reachable (Iola's letter opens the crypt at 3 shards + mage lead),
  so the wave-8 cave-7 gate is load-bearing, not belt-and-braces. The
  six-shards scene's "before the tower" / "opens at five" lines now
  branch when the tower was already entered.
- NG+: ECHO's recruit beat pre-seeded when she carried over (run 2 no
  longer re-arms the Silence and re-recruits her mid-party);
  JAM.mode resets to pentatonic (a carried mode couldn't be
  re-selected once cycled off).
- Hygiene: cleanup() closes the viewer TCP stream; ambient weather
  particles no longer render frozen over battles/menus; norns-key
  GAME_OVER dismiss mirrors the gamepad scene-clear; jam audition
  plays recruits' own voice family; story-flag restore replaces
  instead of merges; six-shards warp clears the stale interior return
  target; "music ducks" comment corrected (no duck exists).

### Deliberately not fixed
HDMIMirror's blocking connect (documented tradeoff, ~100ms hitch every
5s only while the stream is on and the viewer unreachable), the
victory-fanfare-at-journey-rate (intentional), shake duration varying
with redraw rate, legacy pre-characters save restore (ancient saves).

## 2026-07-15 — Wave 10: battle system / input parity / economy audits

Three auditors on the last unowned domains. Two independently found
the dead DEF stat and the superboss's missing boss treatment.

### Battle
- **Niko's DRUM was a mechanical no-op** — the action existed in
  CLASS_ACTIONS/ARTIC but apply_player_action had no branch for it;
  his special burned turns on a sound with zero combat effect. Now:
  ATK x1.3 (crit-able) + knocks the enemy off its count (attack-gap
  timer rebased) + short ATK debuff.
- **DEF is now a real stat** (was granted by levels, shown on
  STATUS/EQUIP, and never read anywhere): multiplicative reduction
  x100/(100+def*2), bounded so high-def can't scale into immunity.
- **The First Chord now gets boss treatment**: it was missing from all
  three duplicated boss_visuals sets, so the ultimate fight played the
  trash-encounter theme, never enraged, and used trash status rates.
  Plus explicit 0 XP / 0 gold entries ("the chord is its own reward" —
  it was falling through to the +5/+3 defaults).
- RESO MP economy unified: charged at fire time only (R2-queue used to
  pay-then-lose on cycle-away; dpad-queue was free); after firing,
  queued falls back to ATK (was silently dead-turning forever).
- Bypass victories (Strom arc, Broken Cadence) now scrub battle state —
  poison/sleep/tonic/reso arms used to resume in the NEXT battle.
  exit_battle also clears regen/dmg-reduce/rhythm-charge leaks.
- Scripted battles reset limit_used (a limit spent earlier stayed
  spent vs Broken Cadence), give the standard first-hit grace
  (last_attack = tick, was -99 = instant hit), and honor the
  battle-speed multiplier.
- Sergei's Tidewatch rescue no longer fires on the Tideturner rare.
  Cleric limit revives reset ATB like every other revive. ECHO got
  victory quips (the only class missing from the pool).

### Input parity (norns-only playability)
- **Norns-only players could not move** — try_move was reachable only
  from gamepad.dpad. E2 now walks east/west, E3 north/south.
- **CREDITS was a one-way door into NG+** (destructive shard wipe, no
  alternative, no visible prompt for ~2 min). B/K2 now returns to
  title non-destructively; the prompt reads "A/K3: NEW GAME+  B/K2:
  title".
- **JAM mode was gamepad-only to enter** — K2 in the overworld now
  toggles it (K2 inside already exits); E2 cycles scale, E3 moves
  root. The SELECT/K2 jam toggle is now also blocked mid-scene (the
  overlay froze choreography under it).
- **The Jam Pad practice mode was unreachable by ANY input** — zero
  call sites; its achievement was unobtainable. Now a pause-menu
  entry.
- Battle E2 action cycle includes RESO when attuned (resonances were
  gamepad-only in battle); PARTYSEL E3 cycles the active slot (norns
  had no lead-change outside battle); returning from mid-battle JAM
  rebases the enemy attack timer (no more guaranteed instant hit);
  shop cursor clamps after buying the last visible instrument; MIDI
  notes clamp to 24..108; footer hints advertise the norns keys.

### Economy/progression
- Rare-encounter gate lowered to 60% of CAVE_EXPECTED — the natural
  no-grind curve sits at ~50-60% of that table, so rares 3-6 (and
  their guaranteed drops) were effectively unreachable.
- norns_sampler (Diegues' tier-3, defined + sprited, granted NOWHERE)
  is now purchasable (200g, Hens' shop). Field Lute: 120g -> 60g +
  spd 2 (was strictly dominated by the free cave-1 drop).
- Recruits now join at party-average-minus-one (Sergei arrived at L1 /
  24 HP against a ~L5 party), applying real CLASS_GROWTH gains.
- GEAR tab lists in stable sorted order (was pairs() hash order) and
  includes recruit classes.

### Documented, not changed
Vestigial bespoke boss mechanics (bible reality-check note), ionian
weaknesses as intentional post-game flavor, gamepad-only rhythm-crit,
free-inn source-heavy economy (cozy by design), Heal stays OP (canon).

## 2026-07-15 — Wave 11: integrated regression / render layer / crash surface

Three auditors: a full playthrough walk with waves 8-10 interacting,
the first systematic render audit, and the first crash-surface sweep.

### Progress-loss blocker (regression auditor)
**Finishing the game was never saved.** No save_game() existed anywhere
in ENDING → endgame scene → CREDITS; the disk still held the 7th-shard
autosave with cave 7 marked cleared — from which Suno could never be
re-fought. The wave-10 CREDITS title-exit (and any power-off during the
ending) permanently stranded a finished run out of its own ending and
all post-game. The endgame scene now saves the moment endgame_done is
stamped. Also: the Sergei-intervention autosave fired BEFORE the
party-revive loop (reloading it booted a fully dead party) — reordered;
the ending roster now includes recruited-but-BENCHED members (they lost
their panels and their name in the roll); the rare-encounter gate got
+1 level (at the bare 60% mark a rare was a 70-hit slog with no flee
and no rescue); Jam Pad exits scrub tonic; exit_battle now uses the
shared scrub (its inline copy had already drifted once); resonance
turns no longer play a phantom attack note.

### Render blockers (render auditor)
**The banner system never rendered outside battle.** Its only draw site
was inside draw_battle and its countdown only ticked in tick_battle —
every overworld gate refusal ("needs the Key of Lirael"), every pickup
toast, all 33 scene {flash} steps, ECHO's join banner, NEW GAME+, and
scene-error surfacing were set and silently never shown. Banner now
draws from the redraw() tail in all gameplay states and counts down on
the universal tick. Two more: enter_battle unconditionally WIPED the
BOSS/RARE intro banner it had set 50 lines earlier (boss intros had
never displayed once); the Sunward bandstand scene was the single
fade=15 scene with no fade_in — it played entirely behind black.
Also: level-up and save/load flashes moved to the tail (their old
sites never showed them); weather particles render in the world layer
(they drew OVER dialogue text and scene fades); duplicate critical-HP
vignette removed; mid-battle Sergei dialogue backdrops the paused
battle instead of the overworld; night cue added to Sunward (the one
map with a night-GATED trigger had no night indicator); banners over
~28 chars shortened to fit the box; 78 unpainted screen-path sites
(pixel/rect groups never flushed with fill()) fixed mechanically —
boss eyes, weather pixels, window lights, smoke wisps that had
never rendered or rendered at the wrong brightness.

### Crash hardening (crash auditor: "no realistic normal-play crash
path found" — ten waves showing)
Both clock coroutines are now xpcall-wrapped: one uncaught error in any
tick/draw path used to kill music, battle logic, AND the screen
together, silently, for the rest of the session (the scene clock now
aborts a bad scene cleanly instead of freezing the player). Scene
dialogue packing pcall'd (NPC path already was); load_game tolerates a
save missing its player block; fire()'s scale lookup and enemy pattern
copies got the same guards their siblings had.

### Known-open (audit gaps from a session-limit interruption)
Text-clipping sweep of menu/HUD strings; deep save-file fuzz
(truncated/corrupt tab.load shapes); string.format nil sweep. Next
wave candidates.

## 2026-07-16 — Wave 12: text layout + copy QA / save-file fuzz / docs

Three auditors (two needed transcript-resume after session limits —
same recovery as wave 11).

### Save robustness (fuzz auditor, with an executable harness)
- **Saves are now atomic** (write .tmp, rename). tab.save wrote in
  place; a power-off mid-write truncated the file and tab.load
  rejected it -> "No save found", whole run silently gone. norns users
  pull power routinely — this was the biggest real-world data-loss
  risk in the game.
- **The shard autosave fired before the boss instrument drop** —
  obtain_shard saved, THEN clear_boss granted award_drop + the
  aftermath queue + achievements. A crash right after a boss kill
  reloaded to a cleared cave with the unique instrument permanently
  unobtainable. The autosave now runs at the END of clear_boss (and
  the superboss clear saves too).
- Corrupt/hand-edited save tolerance: type normalizer nils any
  non-table block before the restore loops; Continue is pcall'd on
  both input paths ("Save corrupt" instead of a crash with globals
  half-restored); map-id range validation (unknown ids fell through
  travel_to's else into SUNOS_DOMAIN); player-block field coercion;
  gold/level/hp clamps; bestiary list guards for partial entries.
- 40-scenario fuzz harness ran the real load path: missing blocks,
  wrong types, future versions all traced; only the above needed fixes.

### Text layout (the wave-11 unfinished sweep — 7 clipping blockers)
Every fix measured against the file's own font calibration: enemy
names no longer overprint their HP readout ("The Broken Cadence" +
"1300/1300" shared one 80px row); achievements grid rewritten (locked
hints ran across both columns and off-screen; now dimmed names, all
elided to column width); EQUIP fx readout shortened + relocated (it
overprinted the stat-delta line 2px away AND ran off-screen); victory
quips wrap to two lines (they lost both ends at 45+ chars on a ~28
char strip); all four overworld toast boxes (region/inn/tower/event)
switched to the compact font + full-width boxes (8px font overflowed
every box); bestiary lore de-em-dashed (36 literal "—" rendered as
BLANKS in the Tom Thumb font) + truncation guards; JAM footer no
longer collides with the MODE/ROOT values; dialogue page cap 75->66
(75-char pages could wrap to a clipped 4th line at the renderer's ~25
chars/line); battle-HUD armed-glyph slot hoisted clear of the HP text.
Copy QA came back clean: zero misspellings, zero curly quotes, all
shard/cave pairing claims verified against clear_boss.

### Docs / release readiness (first-ever pass)
- README was 2 lines for a content-complete public game — replaced
  with a full install + dual controls reference (norns-only AND
  gamepad, every claim cited against the actual handlers).
- Script header (the norns SELECT-menu preview) said "v0.3 — first
  dungeon + first battle" and documented gamepad-only controls ->
  v0.5, content complete, norns-first controls.
- Title screen flashed "USB Controller Required" when no gamepad was
  present — false since wave 10. Now "norns keys OK - gamepad
  optional".
- viewer/README.md written (the :7777 stream + the viewer.conf
  IP-drift gotcha, previously undocumented anywhere).
- Deferred: in-game Controls page (menu is at its 12-slot capacity;
  proposal = swap the Debug slot, move debug to params). No LICENSE
  (user's call — flagged).

## 2026-07-16 — norns K1 is system-reserved: full rebind (user report)

User report: "no way to access the menu or leave the item shop with
norns only controls." Root cause: wave 10's parity pass hung actions
on K1 — but norns reserves K1 taps for the system script/menu toggle;
scripts only ever see long holds. Every K1-only binding was therefore
unreachable in practice: opening the game menu, leaving the shop,
backing out of MENU/STATUS/EQUIP, skipping the intro, exiting Jam Pad
practice.

Rebind (K1 versions kept as long-hold extras, never required):
- overworld: K2 = MENU (was jam toggle). Jam Mode moved into the menu
  (took the Debug slot; debug overlay is now a param).
- MENU/STATUS/EQUIP: K2 = back. EQUIP character cycle moved to E3.
- SHOP: K2 = leave (was scroll-up); scrolling moved to E2.
- intro cutscene: K2 = skip, K3 = advance.
- battle: K2 exits Jam Pad practice bouts.
On-screen footers (shop, equip), the script header, and the README
norns section all updated to match; README now states the K1 rule.

## 2026-07-16 — Village redesign + dialogue font consistency (user playtest)

User reports from the first real device session:

1. **"Some text small, then the next paragraph large."** The dialogue
   body rendered short pages in the default 8px font and silently
   switched to the compact 6px font whenever a page wrapped past three
   large lines — so text size hopped page to page. The body now always
   uses the compact font (one size, everywhere), wraps against the
   real font metrics, and gains a 4th line of capacity inside the
   same box.

2. **"The village is really hard to navigate... house sizes are
   inconsistent (1-tile inn vs 9-tile houses)."** Full village
   redesign, single-tile convention:
   - New tile 113 "cottage": a whole house in one tile (roof, door,
     lit window), entered by stepping onto it — same convention as
     the inn/shop, same CONTENT.HOUSES mechanism (registry keys
     unchanged: Tova 4,5 · Pip 10,5 · Elder 20,5 · Forge 25,9).
   - All four 3x3 wall shells removed (28 wall tiles -> open grass /
     walkable flowers). Route-blocking decor removed: three fence
     runs, the crate behind the shop, the crate stack + barrel that
     pinched the inn/shop door approaches, and three trees that NPCs
     were standing ON (Fern, Wina).
   - NPCs moved to their homes: Tova, Elder, Pip, and Brann now stand
     beside their own doors; Iret no longer stands on top of the
     plaza flag.
   - Every scene/warp anchor untouched: fountain (15,7) + the
     (13-16,8) scene spawns, cave mouth (29,7), tower (17,7),
     arrivals (17,2), pass/hills/arch/pier/campfire/chest all fixed.
   - (The inventory pass initially suggested Brann's forge door never
     matched its registry key — that was an off-by-one in the
     inventory itself; the key "1:25,9" was always correct and still
     is.)

## 2026-07-17 — Wave 13: consistency + regression sweep

Three parallel audits (dialogue/canon, town/map inventory, K1-rebind
regression), inline fixes, a serialized map-fix agent, and an
adversarial verify over the whole diff.

### Blockers and crashes
- **Academy library was sealed** — the library ring (rows 9–12, cols
  22–27 of the academy map) was solid bookshelf tile 72 with no door;
  Paj at (26,10) was unreachable. Tile-5 door opened at (22,10),
  matching this map's interior-door convention. BFS-verified.
- **CRITICAL closure-scoping regression (caught by verify agent)** —
  the new story gates referenced `STORY`, `player`, and
  `current_map_id` from closures inside the `local STORY = {...}`
  constructor, where those names bind *globals* (the locals are
  declared later). The village-only gates were dead code and the
  `STORY.seen` gates crashed the inn-scene engine on evaluation. Fixed
  with the codebase's `_G.` mirror pattern: `_G.STORY`, `_G.player`
  (table mirrors), and `_G.current_map_id` (value mirror re-synced in
  `travel_to`). This also un-breaks eight PRE-EXISTING trigs that
  referenced `STORY.seen` from inside the constructor.
- **K1-rebind regressions** — my own wave-12 rebind made K2 skip the
  entire intro cutscene (now: K2/K3 advance, K1-hold skips) and made
  K2 *consume* items in ITEMS (now: K3 use, K2 back).

### Controls & UI truthfulness
- Every remaining footer now names real norns keys: ITEMS all tabs,
  STATUS, JAM ("UD/E2 scale LR/E3 root"), Jam Pad practice
  ("START/K2 exit"), PARTYSEL. SHORT_LBL entries for Jam Pad/Jam Mode;
  dead Debug draw branch removed.
- Footer geometry verified at 128 px: ITEMS pager moved from footer
  center (it collided with any honest hint) to the desc row; JAM
  locked variant kept to 13 chars ("LOCKED - B/K2"); PARTYSEL bring
  hint shortened ("K3: Diegues -> slot 4").

### Party/journal correctness (`ever_joined`)
- New persisted flag with old-save migration inference + self-healing
  (anyone in the active party is stamped). Journal Companions panel
  now lists core four + joined recruits and keeps benched members lit
  (was: benched members looked departed, recruits never shown).
- Closed an exploit: PARTYSEL offered Alder/Strom/Diegues as
  swappable reserve *before their story joins* (all starters live in
  CHARACTERS from minute one for growth tracking). Reserve now
  requires `ever_joined`.

### Map & NPC placement (map-fix agent, BFS-verified per map)
- Nine NPCs off walls/props/stall-centers: Wena (4,10), Academy Iola
  (21,3), Echo (12,6), Phrygian Aram (21,5)/Mira (23,7)/Brann (5,5),
  Sunward Pell (11,6), Lirael Bren (7,11 — the steward now stands in
  his doorway), Winna (34,3). Scene camera focus + shrine record
  coords updated where they referenced old spots.
- Observatory double-Iola: the (9,5) gate now excludes
  `flag.velthes_entry_heard`, so the two entries are mutually
  exclusive.
- Sunward Coast (map 35) converted to the village's single-tile
  cottage convention: fisher (10,2), harbormaster (24,2), Beck (4,3),
  tavern (25,5) — old shells removed, HOUSES keys already aligned,
  tavern south-door alias deleted. Bandstand untouched and verified
  reachable.
- **Maro restored** — the dead shadowed `western_region_npcs` table
  was deleted, but its sole entry (Maro the woods-sketcher, Tovia's
  apprentice, ~30 lines incl. a Diegues seminar branch) existed
  nowhere else. Recovered from git and placed live at (14,8) on the
  academy approach — reachable for the first time ever. (Verify agent
  flagged the spot as the warp arch; a raw dump showed the arch is at
  (14,9) and the *handler comment* was stale. Comment fixed.)

### Dialogue & canon
- Post-ionian payoff branches for Iret/Vance/Tess; locrian lines made
  count-free. Sunward Mara/Coral debut branches with SCENE-active
  visibility guards. Pip is a boy (he/his). Pell's Lirael hymn
  backstory. Strom's "Thirty years of orders" departure line. Young
  Phrygian scout says "My queen." (Veiled Mystic keeps "Princess" —
  she knew Miel before the fall). Tower-entry line reworded.
- Gates: first_night_with_alder + miel_fountain_early require
  first_inn_after_escape; pip_gift/lirael_memorial/miel_fountain_early
  are village-only; solo_strom requires sergei_first_night;
  all_six_at_inn skips if Niko joined first.
- Achievement rename: combo achievement is now "First Harmony" (id
  unchanged; saves keep unlocks) — no longer collides with "First
  Chord Silenced".
- Strom-confrontation +5 MaxHP reward was a no-op (`p.max_hp` vs the
  real field `hp_max`) — fixed.
- Bible: wave-13 canon addendum + two-Tildes note.

### Loop discipline
Audit agents → inline fixes → serialized map agent → adversarial
verify (6 confirmed findings, incl. the critical scoping bug and one
false alarm traced to a stale comment) → all fixed → luac -p green.

## 2026-07-17 — Wave 14: enemy audio scale-conformance (user report)

User: "All sounds they [enemies] make need to fit into the selected
scale. There's a lot of dissonant or just outright wrong notes for
certain enemies such as the wisp."

### Root cause
Party voices and zone themes fire by scale DEGREE through
`active_scale() + JAM.root`, so they always land in the sounding
scale. Every enemy `attack_sound`, though, carries an absolute MIDI
note authored against A-minor pentatonic. Two enemies (Spectre F5,
Sage Sentinel F2) were dissonant even in the DEFAULT scale; 22 more
(every C, D, G signature) go sour the moment the player selects
lydian — the first shard they earn — and any non-zero jam root broke
all of them everywhere. Battle music always follows JAM.mode (zones
never change it; only the castle overworld theme is scale-locked).

### Fix
New global `snap_note_to_scale(note)` (defined after `active_scale`
per the declare-before-reference rule): pitch-class snap to the
sounding scale (JAM.mode + JAM.root), nearest note, ties downward,
register preserved. Exhaustively verified offline: 8 modes x 25 roots
x notes 10..100 — always in scale, in-scale notes untouched, drift
<= 1 semitone in practice.

Routed through it:
- enemy `attack_sound` firing in enemy_tick — the single choke point
  for every enemy, boss, rare, and scripted battle in the game
- battle-entry encounter sting
- Resonance signature SFX (shared invoke site) + the ring's clangor
  root AND fifth (snapped independently; stays a perfect fifth in 7
  of 8 modes, a minor sixth in ionian, never a tritone)
- item chimes (salve's B5 was dissonant in default pentatonic) +
  refusal blip
- verify-agent catches: Sergei's parting "healing chord", Miel's
  WHOLE-NOTE REST limit break, the limit-break broken-chord fifth
  (same idiom as the ring clangor), and Sergei's wrench-skip/
  bell-clang — while his third "chord souring" note stays Bb ON
  PURPOSE, so the sour beat now lands against an in-scale setup.

### Deliberately chromatic, untouched
STIR/RESO/queue denial chords, Mira's C#4 phrygian grace, ECHO's
Disperse chromatic run, act-3 silence detune, MIDI-in passthrough,
scene-engine sfx (incl. the 48.55 quarter-tone), overworld NPC
one-shots (Anvel's anvil, WhiteBird, orrery).

### Known observation (left alone by choice)
ARTIC pitch offsets on party actions (+7 PLAY, -5 BLK, etc.) can
leave the mode by the same mechanism; that's party-voice character,
not enemy audio — revisit only if the user hears it.

## 2026-07-17 — Removals: wandering-musician events + battle stick pads (user request)

- **Ambient wandering-musician events removed** — the "wanderer passes
  by" and "lutist by the road" one-shot overworld events (user: "they're
  broken anyways"). Their picker entries and scene functions are gone;
  the other four ambient events (coin, stillness, ghost note, courier)
  stay. Old saves may carry `wanderer`/`lutist` in `events_seen` —
  harmless, the dispatcher no longer knows those ids. The LUTIST and
  WANDERER character stubs in the bible remain as future-NPC concepts.
- **Battle stick mini-pads removed** — the two 8×8 joystick position
  indicators at the top-right of the battle HUD are gone (the sticks
  themselves still work; only the readout is removed). The World of
  Silence "detuned" tag now right-aligns at the screen edge where the
  pads used to sit. The JAM screen's big stick visualizer is untouched.

## 2026-07-17 — Ambient random events removed entirely (user request)

User: "they just don't hit like i intended." The remaining four
one-shot road events (coin glint, stillness, ghost note, courier)
are gone along with the whole dispatcher: try_ambient_event(), the
per-step roll before the encounter check, the events_seen tracker
(save/load/NG+ reset). Old saves carrying events_seen load fine —
the key is simply ignored. NOTE: the tile-triggered ambient
micro-scenes (Lirael window/pillar/hymnal, Sunward bandstand etc.)
are a separate location-specific system and were kept.

## 2026-07-17 — House owners moved indoors (user request)

User: "anyone with a house should be inside of it rather than outside
of it (unless the story requires them not be present there)."

Moved five house-owner NPCs from standing outside into their own
interiors, verbatim (barks + full party-aware dialogue preserved),
each on a BFS-verified walkable tile that leaves the door clear and
a talk-adjacent tile reachable:
- Tova (mainland 3,5) → her house at her travel desk (3,4, facing up)
- Pip (10,6) → the family cottage (4,4)
- the Elder (20,6) → his house at his table (4,4)
- Brann the smith (26,9) → Brann's Forge at the bench (3,4, facing
  his workbench) — his forge-clang barks now ring INSIDE the forge
- Beck (Sunward Coast 4,11) → Beck's Cottage (4,3), reunited with
  his cat Salt who already lived there

Interiors render/talk/bark through the same name→NPC_SPRITES path as
the overworld (all four village owners have registered draw_npc_*
sprites; Beck has NPC_SPRITES.Beck), so appearance and behavior carry
over unchanged. No scene spawns or story beats referenced these
owners at their old exterior coordinates (checked). NOT moved: the
Phrygian caravan trader "Brann" (different character, a shop vendor,
no house), the wandering cartographer "Tovia" (no house), Anvel (an
open-air smith with no registered house), and the Fisher's/
Harbormaster's cottages (flavor buildings with no owner NPC). The
Sunward Tavern's Hask + Vesa were already inside.

## 2026-07-17 — Sunward Coast: make the exit home legible (user report)

User: re-entering the Sunward Coast, "there's no way to get back to the
village." Investigation: the return WAS functional — the signpost warp
(tile 65) at the far-west edge is reachable and adjacent to the re-entry
spawn (2,7), and the mainland landing (63,7) connects to the village by
land (all BFS-verified). The bug was legibility: the exit was a single
signpost tile buried in an open stretch of walkable west-edge floor, so
it read as border decoration, and the arrival scene pulls attention east
("walk east past the docks").

Fixes:
- **Framed 3-tile road mouth.** The west edge (col 1) is now a cliff
  (tile 1) at rows 1-5 and row 9, with a clear 3-tile road opening
  (tile 65) at rows 6-8. Stepping onto any of the three warps home. BFS
  confirms the mouth and every cottage/bandstand/tavern stay reachable;
  Cave 3 unaffected.
- **Road-threshold tile art.** TILE_DRAW[65] redrawn from a lone
  post+board into a packed-dirt road bed with cart ruts + a signpost, so
  it reads as a path leading off the map (single tile on the mainland
  side, a marked road down the coast mouth).
- **Banner + orientation.** On re-entry (no arrival scene to orient you)
  a banner flashes "Mainland road: west <-" as you spawn beside the
  mouth. Mara's first-visit arrival dialogue now also names the west
  road home, so both first-timers and returners are pointed at it.
