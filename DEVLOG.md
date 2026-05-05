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
