-- synth quest
-- v0.3 — first dungeon + first battle
--
-- jrpg with synth-based party
-- forked from vinyl fantasy v0.4
--
-- D-pad: walk (overworld) / select party (battle)
-- A: talk / advance dlg / queue ATK / restart
-- B: queue DEF        X: queue MAG       Y: queue ITM
-- right stick: cutoff/res on active voice (battle)

engine.name = "SynthQuest"

-- ============================================================ CONFIG

local TILE = 8
local VIEW_W = 16
local VIEW_H = 8

local OVERWORLD_BPM = 100
local BATTLE_BPM    = 85
local DRONE_FREQ_HZ = 110           -- A2
local DRONE_AMP_BATTLE_END = 0.28

local BATTLE_END_DURATION = 56      -- ticks held on outcome banner

-- Victory fanfare — 24 steps (~3.5 sec @ 85 bpm), plays once on win.
-- Ascending phrase, ends on A5 stab.
local VICTORY_PATTERN_LEN = 24
local VICTORY_PATTERN = {
  --        1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
  mage    ={16,17,19, 0,21, 0, 0, 0,19,20,21, 0,21, 0, 0, 0,22, 0, 0, 0,21, 0, 0, 0},
  cleric  ={11, 0, 0, 0, 0, 0, 0, 0,14, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0, 0, 0, 0, 0},
  warrior ={ 6, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 6, 0, 0, 0},
  bard    ={ 0, 0,19, 0, 0, 0,21, 0, 0, 0,22, 0, 0, 0,21, 0, 0, 0,23, 0, 0,24, 0, 0},
}

-- Triumphant articulation (bigger envelopes + more reverb than overworld)
local VICTORY_ARTIC = {
  mage    = {vel=0.95, attack=0.004, release=0.70, wet=0.60},
  cleric  = {vel=0.70, attack=0.040, release=2.50, wet=0.70},
  warrior = {vel=0.85, attack=0.005, release=0.55, wet=0.40},
  bard    = {vel=0.75, attack=0.010, release=0.65, wet=0.55},
}

-- A minor pentatonic over 5 octaves (MIDI)
local SCALE = {33,36,38,40,43, 45,48,50,52,55, 57,60,62,64,67, 69,72,74,76,79, 81,84,86,88,91}

-- character names by class (display in battle UI)
local CHAR_NAME = {mage="Diegues", cleric="Miel", warrior="Strom", bard="Alder",
                   engineer="Sergei", mathwiz="Paj", drummer="Niko"}

local CUTOFF_RANGE = {
  mage    = {min=400, max=10000},
  cleric  = {min=300, max=4000},
  warrior = {min=300, max=3500},
  bard    = {min=400, max=8000},
  engineer= {min=400, max=10000},   -- shares mage voice
  mathwiz = {min=400, max=8000},    -- shares bard voice
  drummer = {min=300, max=3500},    -- shares warrior voice (low percussion-y)
}

-- Pass 35: reduced velocity headroom across the board so multiple voices
-- summing in a battle (party action + enemy attack + battle-music ostinato)
-- don't clip the master output. ~25% pull-down on the loud entries.
local ARTIC = {
  ATK  = {vel=0.78, attack=0.004, release=0.40, wet=0.10, pitch=0},
  DEF  = {vel=0.26, attack=0.020, release=0.18, wet=0.05, pitch=0},
  MAG  = {vel=0.85, attack=0.025, release=1.30, wet=0.55, pitch=0},
  ITM  = {vel=0.70, attack=0.003, release=0.35, wet=0.25, pitch=12},
  PLAY = {vel=0.78, attack=0.015, release=1.50, wet=0.65, pitch=7},
  BLK  = {vel=0.62, attack=0.001, release=0.25, wet=0.10, pitch=-5},
  -- Per-character instruments — velocity pulled down ~20%, character of
  -- each kept (attack/release/wet/pitch profiles unchanged from before).
  LYRE = {vel=0.62, attack=0.012, release=2.00, wet=0.75, pitch=12},
  LUTE = {vel=0.78, attack=0.015, release=1.50, wet=0.65, pitch=7},
  HORN = {vel=0.85, attack=0.005, release=0.80, wet=0.35, pitch=-7},
  SMPL = {vel=0.78, attack=0.002, release=0.35, wet=0.45, pitch=19},
  MIX  = {vel=0.72, attack=0.001, release=0.25, wet=0.55, pitch=14},
  CODE = {vel=0.68, attack=0.003, release=0.55, wet=0.45, pitch=24},
  DRUM = {vel=0.92, attack=0.001, release=0.18, wet=0.18, pitch=-12},
}

-- per-class action map: which face button → which queued action.
-- A is always ATK; Y is always ITM. B and X vary by class.
local CLASS_ACTIONS = {
  mage     = {A="ATK", B="DEF", X="SMPL", Y="ITM"},
  cleric   = {A="ATK", B="DEF", X="LYRE", Y="ITM"},   -- Miel: lyre
  warrior  = {A="ATK", B="BLK", X="HORN", Y="ITM"},
  bard     = {A="ATK", B="DEF", X="LUTE", Y="ITM"},   -- Alder: lute
  engineer = {A="ATK", B="DEF", X="MIX",  Y="ITM"},   -- Sergei: remix
  mathwiz  = {A="ATK", B="DEF", X="CODE", Y="ITM"},   -- Paj: function call
  drummer  = {A="ATK", B="BLK", X="DRUM", Y="ITM"},   -- Niko: drum hit (uses warrior voice)
}

-- Each class's "instrument" action label.
local CLASS_INSTRUMENT = {bard="LUTE", cleric="LYRE", warrior="HORN", mage="SMPL",
                          engineer="MIX", mathwiz="CODE", drummer="DRUM"}

-- Each enemy has its own attack sequence (gaps between hits, looped) and
-- a unique attack-sound voice (one of the party SynthDefs at a fixed pitch).
local CAVE_POOLS, CAVE_BOSSES
do
local CAVE_ENCOUNTERS = {
  { name="Slime",    hp=140, atk=4,
    attack_pattern={8, 8, 8, 8},                    -- steady plodding
    attack_sound={class="warrior", note=28, vel=0.55, attack=0.003, release=0.18, wet=0.10},
    visual="slime" },
  { name="Bat",      hp=110, atk=3,
    attack_pattern={3, 3, 5, 3, 4},                 -- chittering, slightly off-grid
    attack_sound={class="mage",    note=84, vel=0.50, attack=0.002, release=0.10, wet=0.15},
    visual="bat" },
  { name="Mushroom", hp=180, atk=3,
    attack_pattern={12, 14, 10, 16},                -- patient, irregular spores
    attack_sound={class="bard",    note=33, vel=0.55, attack=0.05,  release=0.60, wet=0.30},
    visual="mushroom" },
  { name="Wisp",     hp=80,  atk=4,
    attack_pattern={2, 2, 2, 2, 6, 2},              -- frantic pecks then breath
    attack_sound={class="mage",    note=88, vel=0.45, attack=0.002, release=0.40, wet=0.55},
    visual="wisp" },
  { name="Wolf",     hp=130, atk=7,
    attack_pattern={3, 3, 3, 10},                   -- triple-strike, rest
    attack_sound={class="warrior", note=30, vel=0.70, attack=0.002, release=0.20, wet=0.05},
    visual="wolf" },
}

-- boss: irregular menacing pattern, deep cleric tone for tells
local CAVE_BOSS = { name="Cave Echo", hp=600, atk=7,
  attack_pattern={16, 12, 8, 12, 16},
  attack_sound={class="cleric", note=28, vel=0.60, attack=0.05, release=1.50, wet=0.65},
  visual="echo" }

-- Cave 2 (Hollow Woods): tougher monsters, Forest Sentinel boss → Dorian Shard
local CAVE2_ENCOUNTERS = {
  { name="Sprite",      hp=90,  atk=5,
    attack_pattern={2, 2, 4, 2, 2, 6},                    -- darting flutter
    attack_sound={class="bard", note=86, vel=0.50, attack=0.003, release=0.30, wet=0.55},
    visual="sprite" },
  { name="Treant",      hp=240, atk=6,
    attack_pattern={14, 14, 10, 18},                       -- ponderous swings
    attack_sound={class="warrior", note=26, vel=0.65, attack=0.005, release=0.35, wet=0.20},
    visual="treant" },
  { name="Hollow Wisp", hp=110, atk=5,
    attack_pattern={4, 2, 4, 2, 8},                        -- echoing pulses, longer rest
    attack_sound={class="mage", note=84, vel=0.50, attack=0.004, release=0.55, wet=0.65},
    visual="wisp" },
  { name="Wood Wolf",   hp=160, atk=8,
    attack_pattern={5, 3, 5, 3, 12},                       -- stalking pounce + lull
    attack_sound={class="warrior", note=27, vel=0.75, attack=0.003, release=0.28, wet=0.08},
    visual="wolf" },
}

local CAVE2_BOSS = { name="Forest Sentinel", hp=850, atk=9,
  attack_pattern={20, 16, 12, 18},
  attack_sound={class="cleric", note=24, vel=0.65, attack=0.06, release=1.80, wet=0.70},
  visual="sentinel" }

-- Cave 3 (Sunward Coast): tide creatures + Tidewatch boss → Mixolydian Shard
local CAVE3_ENCOUNTERS = {
  { name="Crab",       hp=110, atk=6,
    attack_pattern={4, 4, 6, 4, 4, 8},                     -- pinching scuttle
    attack_sound={class="warrior", note=33, vel=0.55, attack=0.003, release=0.18, wet=0.15},
    visual="crab" },
  { name="Manta",      hp=200, atk=7,
    attack_pattern={10, 10, 14, 10},                       -- gliding swoops
    attack_sound={class="cleric", note=40, vel=0.55, attack=0.04, release=0.80, wet=0.50},
    visual="manta" },
  { name="Tide Sprite", hp=120, atk=6,
    attack_pattern={3, 3, 3, 5, 3, 9},                     -- fast tide-spray then crash
    attack_sound={class="bard", note=82, vel=0.55, attack=0.004, release=0.40, wet=0.60},
    visual="sprite" },
  { name="Sea Wisp",   hp=100, atk=5,
    attack_pattern={6, 2, 2, 6, 2, 2, 10},                 -- trickling foam pulses
    attack_sound={class="mage", note=80, vel=0.50, attack=0.003, release=0.50, wet=0.70},
    visual="wisp" },
}

local CAVE3_BOSS = { name="Tidewatch", hp=1100, atk=11,
  attack_pattern={22, 18, 14, 18},
  attack_sound={class="cleric", note=21, vel=0.65, attack=0.08, release=2.00, wet=0.75},
  visual="tide" }

-- Cave 4 (Eastern Reaches): exotic enemies + Dune Rider boss → Phrygian Shard
local CAVE4_ENCOUNTERS = {
  { name="Scorpion",   hp=140, atk=8,
    attack_pattern={5, 5, 3, 7},                           -- snap-snap-snap-pause
    attack_sound={class="warrior", note=36, vel=0.65, attack=0.003, release=0.20, wet=0.10},
    visual="scorpion" },
  { name="Spectre",    hp=170, atk=7,
    attack_pattern={9, 7, 9, 11},                          -- haunting irregular
    attack_sound={class="bard", note=78, vel=0.45, attack=0.02, release=0.80, wet=0.65},
    visual="spectre" },
  { name="Sand Manta", hp=220, atk=8,
    attack_pattern={6, 6, 12, 6, 6, 16},                    -- sand-skim then dive
    attack_sound={class="cleric", note=37, vel=0.60, attack=0.05, release=0.95, wet=0.55},
    visual="manta" },
  { name="Dune Wolf",  hp=180, atk=9,
    attack_pattern={2, 4, 2, 4, 2, 14},                     -- panting hunt + rest
    attack_sound={class="warrior", note=32, vel=0.78, attack=0.002, release=0.22, wet=0.06},
    visual="wolf" },
}

local CAVE4_BOSS = { name="Dune Rider", hp=1300, atk=13,
  attack_pattern={18, 14, 10, 16},
  attack_sound={class="bard", note=22, vel=0.65, attack=0.04, release=1.20, wet=0.60},
  visual="dunerider" }

-- Cave 5 (Northern Wilds): frigid creatures + Snowgaunt boss → Aeolian Shard
local CAVE5_ENCOUNTERS = {
  { name="Frost Wisp",    hp=160, atk=8,
    attack_pattern={5, 3, 5, 3, 5, 11},                    -- shivering pulses
    attack_sound={class="mage", note=82, vel=0.45, attack=0.005, release=0.70, wet=0.75},
    visual="frostwisp" },
  { name="Yeti",          hp=260, atk=10,
    attack_pattern={14, 14, 8, 18},                         -- lumbering, sudden swipe
    attack_sound={class="warrior", note=24, vel=0.80, attack=0.005, release=0.40, wet=0.20},
    visual="yeti" },
  { name="Granite Beast", hp=320, atk=9,
    attack_pattern={20, 18, 12, 22},                        -- slow stone steps
    attack_sound={class="warrior", note=22, vel=0.78, attack=0.010, release=0.55, wet=0.15},
    visual="granite" },
  { name="Crow Wraith",   hp=140, atk=9,
    attack_pattern={3, 3, 3, 5, 3, 3, 8},                    -- shrieking flurry
    attack_sound={class="bard", note=76, vel=0.50, attack=0.003, release=0.60, wet=0.70},
    visual="crow" },
}

local CAVE5_BOSS = { name="Snowgaunt", hp=1500, atk=14,
  attack_pattern={24, 18, 14, 22, 14},
  attack_sound={class="cleric", note=22, vel=0.70, attack=0.10, release=2.50, wet=0.85},
  visual="snowgaunt" }

-- Cave 6 (Locrian Crypt — inside Suno's Domain): cursed half-dead enemies
local CAVE6_ENCOUNTERS = {
  { name="Lich",         hp=220, atk=11,
    attack_pattern={6, 6, 6, 14},                          -- ritualistic
    attack_sound={class="cleric", note=20, vel=0.55, attack=0.04, release=1.40, wet=0.75},
    visual="lich" },
  { name="Voidcrawler",  hp=180, atk=12,
    attack_pattern={2, 2, 2, 4, 12},                       -- swarming, then pause
    attack_sound={class="bard", note=72, vel=0.45, attack=0.003, release=0.25, wet=0.60},
    visual="voidcrawler" },
  { name="Echo of Suno", hp=240, atk=10,
    attack_pattern={8, 8, 4, 4, 4, 16},                    -- mocks the player rhythm
    attack_sound={class="mage", note=48, vel=0.55, attack=0.005, release=0.80, wet=0.70},
    visual="echosuno" },
  { name="Mute Warden",  hp=320, atk=11,
    attack_pattern={20, 16, 12, 24},                        -- silent, slow, devastating
    attack_sound={class="warrior", note=18, vel=0.85, attack=0.005, release=0.60, wet=0.30},
    visual="mutewarden" },
}

local CAVE6_BOSS = { name="Locrius", hp=1900, atk=15,
  attack_pattern={14, 10, 14, 6, 6, 22},
  attack_sound={class="cleric", note=18, vel=0.75, attack=0.12, release=3.00, wet=0.90},
  visual="locrius" }

-- Cave 7 = Suno's chamber. Single brutal fight, no minor encounters.
local CAVE7_ENCOUNTERS = {
  -- placeholder: any pre-boss "encounter" is just Suno (so even the first walk-in fights him)
  { name="Suno", hp=3000, atk=18,
    attack_pattern={10, 6, 6, 10, 6, 14, 4, 4, 4, 18},     -- multi-phase rhythmic onslaught
    attack_sound={class="cleric", note=15, vel=0.85, attack=0.08, release=2.50, wet=0.95},
    visual="suno" },
}

local CAVE7_BOSS = CAVE7_ENCOUNTERS[1]   -- same: walking in IS the boss fight

CAVE_POOLS  = {CAVE_ENCOUNTERS, CAVE2_ENCOUNTERS, CAVE3_ENCOUNTERS, CAVE4_ENCOUNTERS, CAVE5_ENCOUNTERS, CAVE6_ENCOUNTERS, CAVE7_ENCOUNTERS}
CAVE_BOSSES = {CAVE_BOSS, CAVE2_BOSS, CAVE3_BOSS, CAVE4_BOSS, CAVE5_BOSS, CAVE6_BOSS, CAVE7_BOSS}
end  -- cave encounters

local BOSS_THRESHOLD = 3

-- XP values per enemy (defaults if not on the spec)
local function enemy_xp(name)
  local xp = {
    Slime=8, Bat=6, Mushroom=12, Wisp=5, Wolf=14,
    Sprite=7, Treant=18, ["Hollow Wisp"]=12, ["Wood Wolf"]=22,
    Crab=11, Manta=20, ["Tide Sprite"]=18, ["Sea Wisp"]=16,
    Scorpion=22, Spectre=24, ["Sand Manta"]=30, ["Dune Wolf"]=28,
    Yeti=42, ["Frost Wisp"]=28, ["Granite Beast"]=50, ["Crow Wraith"]=36,
    Lich=55, Voidcrawler=42, ["Echo of Suno"]=60, ["Mute Warden"]=70,
    ["Cave Echo"]=60, ["Forest Sentinel"]=90, Tidewatch=120, ["Dune Rider"]=160,
    Snowgaunt=200, Locrius=260, Suno=400,
  }
  return xp[name] or 5
end

-- gold drop per enemy (bosses give substantial purses)
local function enemy_gold(name)
  local g = {
    Slime=4, Bat=3, Mushroom=6, Wisp=3, Wolf=8,
    Sprite=4, Treant=10, ["Hollow Wisp"]=7, ["Wood Wolf"]=12,
    Crab=8, Manta=12, ["Tide Sprite"]=10, ["Sea Wisp"]=9,
    Scorpion=14, Spectre=14, ["Sand Manta"]=18, ["Dune Wolf"]=16,
    Yeti=22, ["Frost Wisp"]=14, ["Granite Beast"]=26, ["Crow Wraith"]=18,
    Lich=28, Voidcrawler=22, ["Echo of Suno"]=30, ["Mute Warden"]=36,
    ["Cave Echo"]=80, ["Forest Sentinel"]=140, Tidewatch=200, ["Dune Rider"]=260,
    Snowgaunt=320, Locrius=420, Suno=999,
  }
  return g[name] or 3
end

local PARTY_TEMPLATE = {
  { class="mage",    spd=4, note_idx=11, note_lo=11, note_hi=21,
    cutoff=2200, resonance=0.30,
    hp_max=20, mp_max=12, atk=2, def=4, mag=4 },
  { class="cleric",  spd=1, note_idx=6,  note_lo=6,  note_hi=15,
    cutoff=1600, resonance=0.20,
    hp_max=24, mp_max=14, atk=1, def=8, mag=3 },
  { class="warrior", spd=3, note_idx=1,  note_lo=1,  note_hi=10,
    cutoff=1300, resonance=0.40,
    hp_max=30, mp_max=4,  atk=4, def=10, mag=1 },
  { class="bard",    spd=5, note_idx=8,  note_lo=8,  note_hi=18,
    cutoff=2200, resonance=0.50,
    hp_max=18, mp_max=16, atk=2, def=5, mag=4 },
}

-- Order: mage, cleric, warrior, bard.
-- Cleric defaults to MAG so she group-heals on every cast (was DEF = useless).
-- Bard defaults to ATK so MP isn't burned through immediately.
local DEFAULT_QUEUED = {"ATK","MAG","ATK","ATK"}

-- ============================================================ INSTRUMENTS
-- Each character can equip one instrument matching their class. Instruments
-- modify both stats AND synth tone (this is a synth-as-party game — equipping
-- a different instrument literally changes how that voice sounds).
--
-- Fields:
--   class           — bard/cleric/warrior/mage
--   atk/def/mag/spd — additive stat boosts
--   wet_add         — additive offset to per-action wet sent to engine
--   atk_mul/rel_mul — multipliers on the per-action attack/release envelopes
local INSTRUMENTS = {
  -- bard ----------------------------------------------------------------
  wandering_lute = { name="Wandering Lute", class="bard",    atk=0, def=0, mag=0, spd=0,
                     wet_add=0.00, atk_mul=1.00, rel_mul=1.00 },
  crystal_lute   = { name="Crystal Lute",   class="bard",    atk=1, def=0, mag=1, spd=1,
                     wet_add=0.10, atk_mul=1.00, rel_mul=1.20 },
  -- Aeolian Lute: cold-northern lute dropped by Snowgaunt. Heavier-bodied
  -- than the wandering lute (more atk) but still a lute in tone — softer
  -- attack + sustain. (Drums are reserved for a future drummer class.)
  aeolian_lute   = { name="Aeolian Lute",   class="bard",    atk=2, def=1, mag=0, spd=0,
                     wet_add=0.10, atk_mul=1.20, rel_mul=1.40 },
  -- cleric --------------------------------------------------------------
  -- Miel plays a lyre. Her three instruments are all lyres of escalating quality.
  pilgrim_lyre   = { name="Pilgrim Lyre",   class="cleric",  atk=0, def=0, mag=0, spd=0,
                     wet_add=0.00, atk_mul=1.00, rel_mul=1.00 },
  silver_lyre    = { name="Silver Lyre",    class="cleric",  atk=0, def=1, mag=1, spd=0,
                     wet_add=0.10, atk_mul=1.00, rel_mul=1.30 },
  sacred_lyre    = { name="Sacred Lyre",    class="cleric",  atk=0, def=2, mag=2, spd=0,
                     wet_add=0.05, atk_mul=1.50, rel_mul=1.50 },
  -- warrior -------------------------------------------------------------
  iron_edge      = { name="Iron Edge",      class="warrior", atk=0, def=0, mag=0, spd=0,
                     wet_add=0.00, atk_mul=1.00, rel_mul=1.00 },
  hymnsword      = { name="Hymnsword",      class="warrior", atk=1, def=1, mag=1, spd=0,
                     wet_add=0.05, atk_mul=1.00, rel_mul=1.10 },
  stormbrand     = { name="Stormbrand",     class="warrior", atk=2, def=2, mag=0, spd=1,
                     wet_add=0.00, atk_mul=0.40, rel_mul=0.50 },
  -- mage ----------------------------------------------------------------
  ash_staff      = { name="Ash Staff",      class="mage",    atk=0, def=0, mag=0, spd=0,
                     wet_add=0.00, atk_mul=1.00, rel_mul=1.00 },
  ember_rod      = { name="Ember Rod",      class="mage",    atk=0, def=0, mag=2, spd=0,
                     wet_add=0.15, atk_mul=1.00, rel_mul=1.20 },
  astral_wand    = { name="Astral Wand",    class="mage",    atk=1, def=0, mag=3, spd=1,
                     wet_add=0.10, atk_mul=1.20, rel_mul=1.40 },
}

-- starter instrument per class (auto-equipped on new game)
local STARTER_INSTRUMENT = {
  bard    = "wandering_lute",
  cleric  = "pilgrim_lyre",
  warrior = "iron_edge",
  mage    = "ash_staff",
}

-- which instrument each cave boss drops the FIRST time it's beaten
local BOSS_INSTRUMENT_DROP = {
  [1] = "crystal_lute",   -- Cave Echo → bard
  [2] = "silver_lyre",    -- Forest Sentinel → cleric (silver lyre)
  [3] = "hymnsword",      -- Tidewatch → warrior
  [4] = "ember_rod",      -- Dune Rider → mage
  [5] = "aeolian_lute",   -- Snowgaunt → bard (cold-northern lute)
  [6] = "sacred_lyre",    -- Locrius → cleric (sacred lyre from cursed crypt)
  [7] = "stormbrand",     -- Suno → warrior (stripped from his tower)
}

-- inventory: which instruments the party owns (set of ids)
local instruments_owned = {}
-- equipped[class] = instrument id
local equipped = {}

-- bundled into one table to keep main-chunk local count under Lua's 200 cap
local INST = {}
INST.of  = function(p) return INSTRUMENTS[equipped[p.class]] end
INST.atk = function(p) local i = INST.of(p); return p.atk + (i and i.atk or 0) + ((p.tonic_ticks or 0) > 0 and 4 or 0) end
INST.def = function(p) local i = INST.of(p); return p.def + (i and i.def or 0) end
INST.mag = function(p) local i = INST.of(p); return p.mag + (i and i.mag or 0) end
INST.spd = function(p) local i = INST.of(p); return p.spd + (i and i.spd or 0) end

-- Per-instrument 8x8 sprite functions (Pass 32). One unique sprite per
-- equippable instrument id. Used by the EQUIP screen + (small) HUD icons.
INST.sprites = {}

INST.sprites.wandering_lute = function(sx, sy)
  -- Plain rounded lute body + slim neck
  screen.level(7); screen.circle(sx + 3, sy + 5, 3); screen.fill()      -- body
  screen.level(3); screen.circle(sx + 3, sy + 5, 1); screen.stroke()    -- soundhole
  screen.level(11); screen.move(sx + 4, sy + 4); screen.line(sx + 7, sy + 1); screen.stroke()  -- neck
  screen.level(13); screen.pixel(sx + 7, sy); screen.fill()             -- pegs
end

INST.sprites.crystal_lute = function(sx, sy)
  -- Faceted body + bright core + neck
  screen.level(11); screen.circle(sx + 3, sy + 5, 3); screen.fill()     -- body
  screen.level(15); screen.pixel(sx + 3, sy + 4); screen.pixel(sx + 4, sy + 5); screen.fill()  -- crystal facet shine
  screen.level(2); screen.move(sx + 1, sy + 3); screen.line(sx + 5, sy + 7); screen.stroke()   -- facet line
  screen.level(13); screen.move(sx + 4, sy + 4); screen.line(sx + 7, sy + 1); screen.stroke()  -- silver neck
end

INST.sprites.aeolian_lute = function(sx, sy)
  -- Cold-blue body + frost rim + heavier neck
  screen.level(8); screen.circle(sx + 3, sy + 5, 3); screen.fill()      -- darker body
  screen.level(15); screen.pixel(sx + 1, sy + 4); screen.pixel(sx + 5, sy + 6); screen.fill()  -- frost flecks
  screen.level(11); screen.move(sx + 4, sy + 4); screen.line(sx + 7, sy + 1); screen.stroke()  -- pale neck
  screen.level(13); screen.pixel(sx + 7, sy); screen.fill()             -- pegs
end

INST.sprites.pilgrim_lyre = function(sx, sy)
  -- Small U-shape lyre with three strings + base
  screen.level(7); screen.move(sx + 1, sy + 6); screen.line(sx + 1, sy + 1); screen.line(sx + 6, sy + 1); screen.line(sx + 6, sy + 6); screen.stroke()
  screen.level(11)
  screen.move(sx + 2, sy + 1); screen.line(sx + 2, sy + 6); screen.stroke()
  screen.move(sx + 4, sy + 1); screen.line(sx + 4, sy + 6); screen.stroke()
  screen.move(sx + 5, sy + 1); screen.line(sx + 5, sy + 6); screen.stroke()
  screen.level(5); screen.rect(sx, sy + 6, 8, 1); screen.fill()         -- base
end

INST.sprites.silver_lyre = function(sx, sy)
  -- Polished U + bright strings + small flourish at top
  screen.level(13); screen.move(sx + 1, sy + 6); screen.line(sx + 1, sy + 2); screen.line(sx + 6, sy + 2); screen.line(sx + 6, sy + 6); screen.stroke()
  screen.level(15)
  screen.move(sx + 2, sy + 2); screen.line(sx + 2, sy + 6); screen.stroke()
  screen.move(sx + 3, sy + 2); screen.line(sx + 3, sy + 6); screen.stroke()
  screen.move(sx + 5, sy + 2); screen.line(sx + 5, sy + 6); screen.stroke()
  -- top flourish
  screen.level(15); screen.move(sx + 1, sy + 2); screen.line(sx + 3, sy); screen.line(sx + 6, sy + 2); screen.stroke()
  screen.level(7); screen.rect(sx, sy + 6, 8, 1); screen.fill()
end

INST.sprites.sacred_lyre = function(sx, sy)
  -- Ornate lyre with halo above
  screen.level(13); screen.move(sx + 1, sy + 6); screen.line(sx + 1, sy + 3); screen.line(sx + 6, sy + 3); screen.line(sx + 6, sy + 6); screen.stroke()
  screen.level(15)
  for i = 0, 3 do
    screen.move(sx + 2 + i, sy + 3); screen.line(sx + 2 + i, sy + 6); screen.stroke()
  end
  -- halo (small ring above) — gentle pulse
  local lit = (tick % 16) < 10
  screen.level(lit and 15 or 11); screen.circle(sx + 3, sy + 1, 2); screen.stroke()
  screen.level(11); screen.rect(sx, sy + 6, 8, 1); screen.fill()
end

INST.sprites.iron_edge = function(sx, sy)
  -- Plain straight blade + simple cross-guard
  screen.level(13); screen.move(sx + 4, sy); screen.line(sx + 4, sy + 6); screen.stroke()    -- blade
  screen.level(11); screen.move(sx + 2, sy + 6); screen.line(sx + 6, sy + 6); screen.stroke() -- guard
  screen.level(5); screen.rect(sx + 3, sy + 7, 2, 1); screen.fill()                          -- pommel
end

INST.sprites.hymnsword = function(sx, sy)
  -- Cross-shaped guard, etched note on the blade
  screen.level(15); screen.move(sx + 4, sy); screen.line(sx + 4, sy + 6); screen.stroke()    -- bright blade
  screen.level(13); screen.move(sx + 1, sy + 5); screen.line(sx + 7, sy + 5); screen.stroke() -- wide guard
  screen.level(0); screen.pixel(sx + 4, sy + 2); screen.fill()                               -- engraved note dot
  screen.level(7); screen.rect(sx + 3, sy + 7, 2, 1); screen.fill()                          -- gold pommel
end

INST.sprites.stormbrand = function(sx, sy)
  -- Jagged blade + spark animation
  screen.level(15)
  screen.move(sx + 4, sy + 6); screen.line(sx + 3, sy + 4); screen.line(sx + 5, sy + 3)
  screen.line(sx + 4, sy + 1); screen.stroke()
  screen.level(11); screen.move(sx + 2, sy + 6); screen.line(sx + 6, sy + 6); screen.stroke()
  screen.level(3); screen.rect(sx + 3, sy + 7, 2, 1); screen.fill()
  -- spark flicker at the tip
  if (tick % 6) < 3 then
    screen.level(15); screen.pixel(sx + 4, sy); screen.pixel(sx + 5, sy + 1); screen.fill()
  end
end

INST.sprites.ash_staff = function(sx, sy)
  -- Wooden staff, gnarled tip
  screen.level(5); screen.move(sx + 4, sy); screen.line(sx + 4, sy + 7); screen.stroke()
  screen.level(7); screen.pixel(sx + 4, sy + 1); screen.pixel(sx + 5, sy + 1); screen.fill()  -- knot
  screen.level(8); screen.pixel(sx + 3, sy + 7); screen.pixel(sx + 5, sy + 7); screen.fill()  -- splayed base
end

INST.sprites.ember_rod = function(sx, sy)
  -- Dark rod with a glowing ember at the tip (pulses)
  screen.level(3); screen.move(sx + 4, sy + 1); screen.line(sx + 4, sy + 7); screen.stroke()
  local hot = (tick % 8) < 5
  screen.level(hot and 15 or 11); screen.circle(sx + 4, sy + 1, 1); screen.fill()
  if hot then screen.level(13); screen.pixel(sx + 3, sy); screen.pixel(sx + 5, sy); screen.fill() end
  screen.level(5); screen.rect(sx + 3, sy + 7, 2, 1); screen.fill()
end

INST.sprites.astral_wand = function(sx, sy)
  -- Thin wand with a star at the tip + orbiting particle
  screen.level(11); screen.move(sx + 4, sy + 2); screen.line(sx + 4, sy + 7); screen.stroke()
  -- four-point star at tip
  screen.level(15); screen.pixel(sx + 4, sy); screen.pixel(sx + 4, sy + 2)
  screen.pixel(sx + 3, sy + 1); screen.pixel(sx + 5, sy + 1); screen.fill()
  screen.level(13); screen.pixel(sx + 4, sy + 1); screen.fill()
  -- orbiting particle (4-frame cycle)
  local f = (tick // 3) % 4
  local px, py = sx + 4, sy + 1
  if f == 0 then px, py = sx + 6, sy + 2
  elseif f == 1 then px, py = sx + 5, sy + 3
  elseif f == 2 then px, py = sx + 3, sy + 3
  else px, py = sx + 2, sy + 2 end
  screen.level(11); screen.pixel(px, py); screen.fill()
end
INST.owned_for = function(class)
  local list = {}
  for id, _ in pairs(instruments_owned) do
    local inst = INSTRUMENTS[id]
    if inst and inst.class == class then list[#list+1] = id end
  end
  table.sort(list, function(a, b)
    local ia, ib = INSTRUMENTS[a], INSTRUMENTS[b]
    return (ia.atk + ia.def + ia.mag + ia.spd) < (ib.atk + ib.def + ib.mag + ib.spd)
  end)
  return list
end

-- ============================================================ LEVEL / XP

local LEVEL_CAP = 50

-- per-class stat growth applied each level-up.
-- Designed so each class develops along its identity: warriors tank+hit,
-- mages spike MAG/MP, clerics get MP/HP/MAG, bards stay agile and balanced.
-- spd_every: SPD goes up only every N levels (so it stays meaningful).
local CLASS_GROWTH = {
  warrior  = { hp=8, mp=1, atk=3, def=2, mag=0, spd_every=6 },
  mage     = { hp=3, mp=4, atk=1, def=1, mag=3, spd_every=5 },
  cleric   = { hp=5, mp=4, atk=1, def=2, mag=2, spd_every=8 },
  bard     = { hp=4, mp=3, atk=2, def=1, mag=2, spd_every=4 },
  engineer = { hp=5, mp=3, atk=2, def=2, mag=3, spd_every=5 },
  mathwiz  = { hp=3, mp=5, atk=1, def=1, mag=4, spd_every=5 },
  drummer  = { hp=7, mp=2, atk=3, def=1, mag=0, spd_every=3 },  -- high HP + fast SPD
}

-- XP curve: cost to advance FROM level L is xp_for_level(L).
-- Quadratic-ish ramp so early levels come fast, late levels feel earned.
local function xp_for_level(lv)
  return 30 + lv * lv * 12 + lv * 18
end

-- ============================================================ SHARDS

local SHARD_ORDER = {"lydian", "dorian", "mixolydian", "phrygian", "aeolian", "locrian", "ionian"}
local SHARD_DISPLAY = {
  lydian = "Lydian", dorian = "Dorian", mixolydian = "Mixolydian",
  phrygian = "Phrygian", aeolian = "Aeolian", locrian = "Locrian", ionian = "Ionian",
}
local SHARD_TOTAL = #SHARD_ORDER

-- ============================================================ OPENING CUTSCENE

-- Each panel: {text, scene}. scene picks a background drawing routine.
local CUTSCENE_LINES = {
  -- ── COSMIC LORE ──
  {text = "Long ago, on planet Modalia, the Crystal Synth gave music — and life — to all.", scene = "cosmic"},
  {text = "Seven shards. Seven modes. One chord, holding the world in tune.", scene = "cosmic"},
  {text = "The Lydian. Dorian. Mixolydian. Phrygian. Aeolian. Locrian. Ionian.", scene = "cosmic"},
  {text = "When the Crystal sang as one, mountains hummed. Rivers found their tempo.", scene = "cosmic"},
  {text = "Then it shattered. The seven scattered, one to each musical nation.", scene = "cosmic"},
  {text = "For an age, the world hummed in fragmented harmony.", scene = "cosmic"},
  -- ── DARK FORESHADOW ──
  {text = "Then Suno rose — once a wandering noble, now the dark lord of the silenced lands.", scene = "dark"},
  {text = "He hunts every shard, to fold the seven into one bell — and ring it shut.", scene = "dark"},
  {text = "Where his silencers march, the songs go cold.", scene = "dark"},
  {text = "Villages forget their lullabies. Mothers forget their children's names.", scene = "dark"},
  -- ── VILLAGE SCENE (Alder introduction) ──
  {text = "On a quiet evening, in a small village clearing...", scene = "village"},
  {text = "...a wandering troupe arrives by lantern-light, weary from the road.", scene = "village"},
  {text = "Among them: Alder, a young bard with a borrowed lute.", scene = "village"},
  {text = "He plays for coin and supper. He knows nothing of fate.", scene = "village"},
  {text = "Tonight he plays for Princess Miel, who fled the capital in her brother's clothes.", scene = "village"},
  {text = "Strom, an old soldier, listens silently from the shadow of a tree.", scene = "village"},
  {text = "Diegues, last student of the shuttered Academy, reads by the firelight.", scene = "village"},
  -- ── TENSION ──
  {text = "But Suno's scouts have followed Miel into the woods.", scene = "threat"},
  {text = "By dawn, the music must not stop. By dawn, four strangers must become one.", scene = "threat"},
  {text = "Alder is about to learn what his songs were truly meant for.", scene = "threat"},
}

-- ENDING cutscene panels (run after defeating Suno).
local ENDING_LINES = {
  {text = "Suno's tower fell silent at last.", scene = "dark"},
  {text = "The seven shards lifted from your hands —", scene = "cosmic"},
  {text = "Lydian. Dorian. Mixolydian. Phrygian.", scene = "cosmic"},
  {text = "Aeolian. Locrian. Ionian.", scene = "cosmic"},
  {text = "They returned to the sky as a single chord.", scene = "cosmic"},
  {text = "Music ran back into Modalia like a held breath let go.", scene = "village"},
  {text = "In the village square, a fountain sang for the first time in an age.", scene = "village"},
  {text = "Alder, Miel, Strom, Diegues — your names became a song,", scene = "village"},
  {text = "and the song was carried on every wind.", scene = "cosmic"},
  {text = "FIN.", scene = "cosmic"},
}

-- INTRO MUSIC — cinematic slow theme played throughout the cutscene
local INTRO_BPM = 70
local INTRO_PATTERN_LEN = 64
local INTRO_PATTERN = {
  -- mage: slow descending → ascending melodic phrases over 4 bars
  mage = {
    19, 0, 0, 0, 18, 0, 0, 0, 16, 0, 0, 0, 14, 0, 0, 0,
    14, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0, 19, 0, 0, 0,
    21, 0, 0, 0, 19, 0, 0, 0, 21, 0, 0, 0, 19, 0, 0, 0,
    18, 0, 0, 0, 16, 0, 0, 0, 14, 0, 0, 0, 11, 0, 0, 0,
  },
  -- cleric: one sustained chord per bar (i → IV → V → i)
  cleric = {
    11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  },
  -- warrior: deep bass once per bar
  warrior = {
    6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  },
  -- bard: sparse high chimes
  bard = {
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 21, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 22, 0, 0, 0, 0, 0, 0, 0, 21, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 0, 0, 0,
  },
}

local INTRO_ARTIC = {
  mage    = {vel=0.40, attack=0.020, release=1.50, wet=0.80},
  cleric  = {vel=0.45, attack=0.100, release=4.00, wet=0.85},
  warrior = {vel=0.40, attack=0.010, release=1.00, wet=0.50},
  bard    = {vel=0.35, attack=0.010, release=1.20, wet=0.85},
}

-- ============================================================ OVERWORLD MUSIC
-- Pattern values are indices into SCALE; 0 = rest. 32-step (2 bars at 16th notes).
-- Theme: A minor pentatonic, calling chord A → E → A.

local OW_PATTERN_LEN = 128
-- Per-region overworld themes. Each entry: { pattern = {mage,cleric,warrior,bard}, artic = {class -> {vel,attack,release,wet}} }
-- Articulation overrides what's in OW_ARTIC for that region (any field present here wins).
local OW_THEMES = {
  -- VILLAGE CLEARING — bright, hopeful A-minor pentatonic; original theme
  village = {
    pattern = {
      mage = {
        16, 0, 0, 0, 18, 0, 0, 0, 19, 0, 0, 0, 18, 0, 0, 0,
        16, 0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0,
        18, 0, 0, 0, 19, 0, 0, 0, 20, 0, 0, 0, 19, 0, 0, 0,
        21, 0, 0, 0, 19, 0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0,
        14, 0, 0, 0, 16, 0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0,
        14, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0, 16, 0, 0, 0,
        18, 0, 0, 0, 19, 0, 0, 0, 20, 0, 0, 0, 21, 0, 0, 0,
        19, 0, 0, 0, 18, 0, 0, 0, 17, 0, 0, 0, 16, 0, 0, 0,
      },
      cleric = {
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         0, 0, 0, 0,  0, 0, 0, 0, 14, 0, 0, 0,  0, 0, 0, 0,
        13, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         0, 0, 0, 0,  0, 0, 0, 0, 12, 0, 0, 0,  0, 0, 0, 0,
        14, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0, 11, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
        6, 0, 0, 0,  0, 0, 0, 0,  9, 0, 0, 0,  0, 0, 0, 0,
        8, 0, 0, 0,  0, 0, 0, 0,  8, 0, 0, 0,  0, 0, 0, 0,
        6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
        6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
        6, 0, 0, 0,  0, 0, 0, 0,  7, 0, 0, 0,  0, 0, 0, 0,
        9, 0, 0, 0,  0, 0, 0, 0,  9, 0, 0, 0,  0, 0, 0, 0,
        6, 0, 0, 0,  4, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
      },
      bard = {
        0, 0,  0, 0,  0, 0, 19, 0,  0, 0, 20, 0,  0, 0, 18, 0,
        0, 0, 17, 0,  0, 0, 19, 0,  0, 0, 18, 0,  0, 0, 21, 0,
        0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 19, 0,  0, 0, 17, 0,
        0, 0, 16, 0,  0, 0, 17, 0,  0, 0, 16, 0,  0, 0, 14, 0,
        0, 0,  0, 0, 14, 0,  0, 0,  0, 0, 17, 0,  0, 0, 19, 0,
        0, 0, 17, 0,  0, 0, 19, 0,  0, 0, 17, 0,  0, 0, 16, 0,
        0, 0, 19, 0,  0, 0, 17, 0,  0, 0, 21, 0,  0, 0, 22, 0,
        0, 0, 14, 0,  0, 0, 16, 0,  0, 0, 14, 0,  0, 0, 11, 0,
      },
    },
    artic = nil,  -- use defaults
  },

  -- HOLLOW WOODS — slow, dark, sparse; lower register; long releases (echoes)
  woods = {
    pattern = {
      mage = {
        -- bar 1: D4 (low pentatonic) → C4 → A3
        13, 0, 0, 0,  0, 0, 0, 0, 12, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0, 13, 0, 0, 0,
        -- bar 3: drift up E4 G4 E4
        14, 0, 0, 0,  0, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0,
        -- bar 4: dwell on A3 (rest of the bar empty)
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        -- bar 5: D4 C4 A3 (descent)
        13, 0, 0, 0, 12, 0, 0, 0, 11, 0, 0, 0,  0, 0, 0, 0,
        -- bar 6: low E4 G4 E4
        14, 0, 0, 0,  0, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0,
        -- bar 7: long C5
        17, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        -- bar 8: dark return A3
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      },
      cleric = {
        -- one held drone per bar, dropping to low E (b5-of-Aeolian feel)
         6, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,   -- A2
         6, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         9, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,   -- E3
         6, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         6, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         7, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,   -- C3
         9, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         6, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        -- low half-time pulse, mostly silent
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,   -- A1
         0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         3, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,   -- D2
         0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         0, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,   -- E2
         3, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      },
      bard = {
        -- distant chime motif, very sparse, on offbeats
         0, 0,  0, 0,  0, 0,  0, 0,  0, 0, 22, 0,  0, 0,  0, 0,
         0, 0,  0, 0,  0, 0, 21, 0,  0, 0,  0, 0,  0, 0,  0, 0,
         0, 0,  0, 0,  0, 0,  0, 0,  0, 0, 19, 0,  0, 0,  0, 0,
         0, 0, 22, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,
         0, 0,  0, 0,  0, 0,  0, 0,  0, 0, 24, 0,  0, 0,  0, 0,
         0, 0,  0, 0,  0, 0, 22, 0,  0, 0,  0, 0,  0, 0,  0, 0,
         0, 0,  0, 0,  0, 0,  0, 0,  0, 0, 21, 0,  0, 0,  0, 0,
         0, 0, 19, 0,  0, 0,  0, 0,  0, 0,  0, 0, 16, 0,  0, 0,
      },
    },
    artic = {
      mage    = {vel=0.45, attack=0.010, release=1.30, wet=0.75},  -- bell long-tail
      cleric  = {vel=0.55, attack=0.20,  release=4.50, wet=0.85},  -- huge pad
      warrior = {vel=0.65, attack=0.005, release=0.90, wet=0.55},  -- low boom
      bard    = {vel=0.40, attack=0.025, release=1.40, wet=0.85},  -- distant chimes
    },
  },

  -- SUNWARD COAST — bright, sparse, lifted; high register; surf rhythm
  coast = {
    pattern = {
      mage = {
        -- bouncing high A5 C6 E6 with sparkle
        21, 0, 22, 0,  0, 0, 24, 0, 21, 0, 22, 0,  0, 0,  0, 0,
        21, 0, 22, 0,  0, 0, 24, 0, 21, 0,  0, 0,  0, 0, 22, 0,
        24, 0, 22, 0,  0, 0, 21, 0, 19, 0,  0, 0, 21, 0, 22, 0,
        21, 0,  0, 0, 22, 0,  0, 0, 24, 0,  0, 0, 22, 0,  0, 0,
        19, 0, 21, 0,  0, 0, 22, 0, 19, 0, 21, 0,  0, 0,  0, 0,
        19, 0, 21, 0,  0, 0, 22, 0, 19, 0,  0, 0,  0, 0, 21, 0,
        21, 0, 22, 0,  0, 0, 24, 0, 22, 0,  0, 0, 21, 0, 22, 0,
        21, 0,  0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 19, 0,  0, 0,
      },
      cleric = {
        -- airy held tones on E and A (open fifth, sun feeling)
         9, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        12, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         9, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        14, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0, 14, 0, 0, 0,  0, 0, 0, 0,
        11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        -- short low pulses, swing-like (surf bass)
         6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  4, 0, 0, 0,
         6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  9, 0, 0, 0,
         8, 0, 0, 0,  0, 0, 0, 0,  8, 0, 0, 0,  6, 0, 0, 0,
         6, 0, 0, 0,  4, 0, 0, 0,  6, 0, 0, 0,  9, 0, 0, 0,
         6, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  4, 0, 0, 0,
         9, 0, 0, 0,  0, 0, 0, 0,  9, 0, 0, 0,  6, 0, 0, 0,
         8, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  4, 0, 0, 0,
         6, 0, 0, 0,  4, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
      },
      bard = {
        -- shimmering offbeats, very high
         0, 0, 24, 0,  0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 24, 0,
         0, 0, 24, 0,  0, 0, 22, 0,  0, 0, 24, 0,  0, 0, 25, 0,
         0, 0, 25, 0,  0, 0, 24, 0,  0, 0, 22, 0,  0, 0, 24, 0,
         0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 22, 0,  0, 0, 21, 0,
         0, 0, 24, 0,  0, 0, 25, 0,  0, 0, 24, 0,  0, 0, 22, 0,
         0, 0, 22, 0,  0, 0, 24, 0,  0, 0, 22, 0,  0, 0, 21, 0,
         0, 0, 24, 0,  0, 0, 25, 0,  0, 0, 22, 0,  0, 0, 24, 0,
         0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 22, 0,  0, 0, 21, 0,
      },
    },
    artic = {
      mage    = {vel=0.50, attack=0.003, release=0.30, wet=0.40},  -- short, clear
      cleric  = {vel=0.40, attack=0.06,  release=1.80, wet=0.55},  -- airy
      warrior = {vel=0.50, attack=0.003, release=0.20, wet=0.20},  -- dry pulse
      bard    = {vel=0.45, attack=0.005, release=0.30, wet=0.45},  -- shimmer
    },
  },

  -- EASTERN REACHES — exotic, sparse, walking bass; emphasizes lowered colors
  -- (within A pentatonic, dwelling on G/E for Phrygian-ish darkness)
  eastern = {
    pattern = {
      mage = {
        -- modal lead: A4 G4 E4 / A4 G4 E4 D4 (no third — modal ambiguity)
        16, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0,  0, 0, 0, 0,
        16, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0, 13, 0, 0, 0,
        14, 0, 0, 0, 15, 0, 0, 0, 16, 0, 0, 0, 15, 0, 0, 0,
        14, 0, 0, 0, 13, 0, 0, 0, 11, 0, 0, 0,  0, 0, 0, 0,
        16, 0, 0, 0, 15, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0,
        16, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0, 13, 0, 0, 0,
        18, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0, 11, 0, 0, 0,
        14, 0, 0, 0, 15, 0, 0, 0, 14, 0, 0, 0, 13, 0, 0, 0,
      },
      cleric = {
        -- low droning A2 with occasional E2 drop (open fifth drone)
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        -- camel-walk: dotted-quarter bass, A2 G2 A2 G2 (trance shuffle)
         6, 0, 0, 0,  0, 0, 5, 0,  0, 0, 0, 0,  6, 0, 0, 0,
         0, 0, 0, 0,  5, 0, 0, 0,  6, 0, 0, 0,  0, 0, 5, 0,
         6, 0, 0, 0,  0, 0, 5, 0,  0, 0, 0, 0,  6, 0, 0, 0,
         0, 0, 0, 0,  5, 0, 0, 0,  6, 0, 0, 0,  0, 0, 5, 0,
         6, 0, 0, 0,  0, 0, 5, 0,  0, 0, 0, 0,  6, 0, 0, 0,
         0, 0, 0, 0,  5, 0, 0, 0,  9, 0, 0, 0,  0, 0, 5, 0,   -- E3 lift
         6, 0, 0, 0,  0, 0, 5, 0,  0, 0, 0, 0,  6, 0, 0, 0,
         0, 0, 0, 0,  5, 0, 0, 0,  6, 0, 0, 0,  4, 0, 0, 0,
      },
      bard = {
        -- finger-cymbal high accents, mid-bar trills
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 22, 0, 21, 0,
         0, 0,  0, 0, 21, 0, 22, 0,  0, 0,  0, 0, 22, 0, 21, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 24, 0, 22, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 22, 0, 21, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 22, 0, 24, 0,
         0, 0,  0, 0, 21, 0, 22, 0,  0, 0,  0, 0, 22, 0, 21, 0,
         0, 0,  0, 0, 24, 0, 22, 0,  0, 0,  0, 0, 22, 0, 21, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 19, 0, 16, 0,
      },
    },
    artic = {
      mage    = {vel=0.50, attack=0.008, release=0.80, wet=0.70},  -- modal lead
      cleric  = {vel=0.55, attack=0.15,  release=5.00, wet=0.85},  -- desert drone
      warrior = {vel=0.65, attack=0.004, release=0.55, wet=0.45},  -- camel bass
      bard    = {vel=0.45, attack=0.003, release=0.25, wet=0.55},  -- finger cymbals
    },
  },

  -- NORTHERN WILDS — windswept, sparse, frozen; high pads + low taiko + bell drift
  northern = {
    pattern = {
      mage = {
        -- floating high D-A-G drift (lonely melody, lots of rests)
        18, 0, 0, 0,  0, 0, 0, 0, 16, 0, 0, 0,  0, 0, 0, 0,
        15, 0, 0, 0,  0, 0, 0, 0, 18, 0, 0, 0,  0, 0, 0, 0,
        21, 0, 0, 0,  0, 0, 0, 0, 19, 0, 0, 0,  0, 0, 0, 0,
        16, 0, 0, 0,  0, 0, 0, 0, 14, 0, 0, 0,  0, 0, 0, 0,
        18, 0, 0, 0,  0, 0, 0, 0, 16, 0, 0, 0, 18, 0, 0, 0,
        15, 0, 0, 0,  0, 0, 0, 0, 14, 0, 0, 0,  0, 0, 0, 0,
        21, 0, 0, 0, 19, 0, 0, 0, 16, 0, 0, 0, 14, 0, 0, 0,
        15, 0, 0, 0, 16, 0, 0, 0, 11, 0, 0, 0,  0, 0, 0, 0,
      },
      cleric = {
        -- huge windy pad: slow A2 → D3 → A2 → C3
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         3, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         2, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         4, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        -- low taiko-like pulses on 1 + 3 (very deep, sparse)
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 0,
      },
      bard = {
        -- ice-bell chimes drifting through, very long-tail
         0, 0,  0, 0, 22, 0,  0, 0,  0, 0,  0, 0, 24, 0,  0, 0,
         0, 0,  0, 0, 21, 0,  0, 0,  0, 0,  0, 0, 22, 0,  0, 0,
         0, 0,  0, 0, 24, 0,  0, 0,  0, 0,  0, 0, 25, 0,  0, 0,
         0, 0,  0, 0, 22, 0,  0, 0,  0, 0,  0, 0, 19, 0,  0, 0,
         0, 0,  0, 0, 22, 0,  0, 0,  0, 0,  0, 0, 24, 0,  0, 0,
         0, 0,  0, 0, 21, 0,  0, 0,  0, 0,  0, 0, 22, 0,  0, 0,
         0, 0,  0, 0, 25, 0,  0, 0,  0, 0,  0, 0, 22, 0,  0, 0,
         0, 0,  0, 0, 19, 0,  0, 0,  0, 0,  0, 0, 16, 0,  0, 0,
      },
    },
    artic = {
      mage    = {vel=0.40, attack=0.020, release=2.20, wet=0.85},  -- floating distant
      cleric  = {vel=0.55, attack=0.30,  release=6.00, wet=0.90},  -- huge windy pad
      warrior = {vel=0.70, attack=0.005, release=1.20, wet=0.55},  -- deep taiko
      bard    = {vel=0.40, attack=0.005, release=2.00, wet=0.90},  -- ice bells
    },
  },

  -- SUNO'S TOWER — dissonant, oppressive; clustered low cleric drone, jagged stabs
  tower = {
    pattern = {
      mage = {
        -- jagged tritone-ish stabs (A → Eb implied via descending scale skips)
        16, 0,  0, 0,  0, 0, 18, 0,  0, 0, 14, 0,  0, 0,  0, 0,
         0, 0, 16, 0,  0, 0,  0, 0, 18, 0,  0, 0, 14, 0,  0, 0,
        21, 0,  0, 0, 19, 0,  0, 0, 16, 0,  0, 0,  0, 0,  0, 0,
        14, 0,  0, 0, 16, 0,  0, 0, 11, 0,  0, 0,  0, 0,  0, 0,
        16, 0, 18, 0,  0, 0, 16, 0,  0, 0, 18, 0,  0, 0, 14, 0,
         0, 0,  0, 0, 21, 0,  0, 0, 19, 0,  0, 0, 16, 0,  0, 0,
        21, 0, 19, 0, 16, 0, 14, 0, 11, 0,  0, 0,  0, 0,  0, 0,
         0, 0, 14, 0, 11, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,
      },
      cleric = {
        -- minor-second cluster: A2 + C3 alternating, never resolving
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
         1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
      },
      warrior = {
        -- heavy pulsing low taiko, every beat
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  4, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  4, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  4, 0, 0, 0,
         1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,  1, 0, 0, 0,
         1, 0, 0, 0,  4, 0, 0, 0,  1, 0, 0, 0,  4, 0, 0, 0,
      },
      bard = {
        -- tense scrape — sparse high tones at unsettling intervals
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0,  0, 0,  0, 0,
         0, 0, 24, 0, 22, 0,  0, 0,  0, 0,  0, 0, 21, 0,  0, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0, 24, 0, 22, 0,
         0, 0, 22, 0,  0, 0, 21, 0,  0, 0, 22, 0, 21, 0,  0, 0,
         0, 0,  0, 0, 22, 0, 21, 0,  0, 0,  0, 0,  0, 0, 24, 0,
         0, 0, 22, 0, 21, 0, 22, 0,  0, 0,  0, 0, 21, 0,  0, 0,
         0, 0,  0, 0, 22, 0, 24, 0,  0, 0, 22, 0, 21, 0,  0, 0,
         0, 0, 21, 0, 22, 0, 21, 0,  0, 0,  0, 0, 19, 0,  0, 0,
      },
    },
    artic = {
      mage    = {vel=0.55, attack=0.003, release=0.40, wet=0.55},  -- jagged stabs
      cleric  = {vel=0.65, attack=0.40,  release=7.00, wet=0.95},  -- crushing cluster drone
      warrior = {vel=0.85, attack=0.003, release=0.30, wet=0.30},  -- pounding low
      bard    = {vel=0.40, attack=0.005, release=0.40, wet=0.65},  -- tense scrape
    },
  },
}

-- Pass 25: per-interior musical themes. Sparse, atmospheric patterns built
-- via a small `mk` helper scoped to a do-block (no new main-chunk locals).
do
  local function mk(events)
    local p = {}
    for i = 1, OW_PATTERN_LEN do p[i] = 0 end
    for _, e in ipairs(events) do p[e[1]] = e[2] end
    return p
  end

  -- INN: warm hearth-room. Long cleric pad + sparse high mage bell + bard
  -- chord on bar 5. No warrior (no rhythm in a quiet room).
  OW_THEMES.inn = {
    pattern = {
      mage    = mk{ {1, 21}, {65, 22}, {97, 21} },               -- gentle high bell every 4 bars
      cleric  = mk{ {1, 14}, {33, 16}, {65, 13}, {97, 16} },     -- warm pad chord changes
      warrior = mk{ },                                            -- silent
      bard    = mk{ {49, 22}, {113, 21} },                        -- tiny lute punctuation
    },
    artic = {
      mage    = {vel=0.30, attack=0.020, release=2.40, wet=0.85},
      cleric  = {vel=0.35, attack=0.40,  release=8.00, wet=0.95},
      bard    = {vel=0.30, attack=0.020, release=2.20, wet=0.85},
    },
  }

  -- SHOP: mellow lo-fi loop, monochrome — just a slow pad + a single bell
  -- chime per bar. Reuses the SHOP-UI feel for the interior overworld.
  OW_THEMES.shop = {
    pattern = {
      mage    = mk{ {17, 21}, {49, 23}, {81, 21}, {113, 23} },   -- bell on bar 2/4/6/8
      cleric  = mk{ {1, 11}, {33, 13}, {65, 11}, {97, 12} },
      warrior = mk{ },
      bard    = mk{ {41, 17}, {105, 19} },                        -- two soft chimes per cycle
    },
    artic = {
      mage    = {vel=0.30, attack=0.005, release=1.60, wet=0.65},
      cleric  = {vel=0.30, attack=0.30,  release=6.00, wet=0.85},
      bard    = {vel=0.25, attack=0.025, release=1.60, wet=0.85},
    },
  }

  -- ECHOES (cave 1): single low mage tone that "echoes" + cleric drone.
  OW_THEMES.echoes = {
    pattern = {
      mage    = mk{ {1, 11}, {9, 11}, {17, 13}, {65, 11}, {73, 11}, {81, 13} },
      cleric  = mk{ {1, 6}, {65, 6} },                            -- huge low drone
      warrior = mk{ {49, 1}, {113, 1} },                          -- distant thud
      bard    = mk{ },
    },
    artic = {
      mage    = {vel=0.45, attack=0.005, release=2.20, wet=0.95},
      cleric  = {vel=0.50, attack=0.30,  release=8.00, wet=0.95},
      warrior = {vel=0.50, attack=0.005, release=1.20, wet=0.70},
    },
  }

  -- GROVE (cave 2): mossy, alive — bird-like high bard chimes over a pad.
  OW_THEMES.grove = {
    pattern = {
      mage    = mk{ {1, 14}, {33, 16}, {65, 14}, {97, 12} },
      cleric  = mk{ {1, 9}, {65, 9} },
      warrior = mk{ },
      bard    = mk{ {13, 22}, {29, 24}, {45, 21}, {77, 22}, {93, 24}, {109, 21} },
    },
    artic = {
      mage    = {vel=0.40, attack=0.020, release=1.80, wet=0.85},
      cleric  = {vel=0.45, attack=0.40,  release=6.00, wet=0.90},
      bard    = {vel=0.35, attack=0.005, release=0.80, wet=0.85},  -- chirpy bird chimes
    },
  }

  -- GROTTO (cave 3): dripping water — sparse bard glints, wide low pad.
  OW_THEMES.grotto = {
    pattern = {
      mage    = mk{ {1, 11}, {49, 12}, {81, 11} },
      cleric  = mk{ {1, 6}, {65, 7} },
      warrior = mk{ {1, 1}, {65, 3} },                            -- low rolling waves
      bard    = mk{ {7, 24}, {23, 22}, {41, 25}, {59, 21}, {89, 24}, {107, 22} },
    },
    artic = {
      mage    = {vel=0.40, attack=0.005, release=2.50, wet=0.95},
      cleric  = {vel=0.40, attack=0.50,  release=8.00, wet=0.95},
      warrior = {vel=0.35, attack=0.30,  release=4.00, wet=0.80},
      bard    = {vel=0.30, attack=0.005, release=0.40, wet=0.95},  -- tiny short drips
    },
  }

  -- DUNE (cave 4): warm, droning. Pulse on the 1 + held middle-register pad.
  OW_THEMES.dune = {
    pattern = {
      mage    = mk{ {1, 16}, {65, 18} },
      cleric  = mk{ {1, 9}, {33, 9}, {65, 11}, {97, 11} },
      warrior = mk{ {1, 4}, {17, 4}, {33, 4}, {49, 4}, {65, 4}, {81, 4}, {97, 4}, {113, 4} },
      bard    = mk{ {25, 21}, {89, 19} },
    },
    artic = {
      mage    = {vel=0.45, attack=0.020, release=2.00, wet=0.75},
      cleric  = {vel=0.40, attack=0.30,  release=5.00, wet=0.85},
      warrior = {vel=0.35, attack=0.005, release=0.30, wet=0.40},  -- low desert pulse
      bard    = {vel=0.30, attack=0.015, release=1.40, wet=0.80},
    },
  }

  -- FROST (cave 5): icy, glassy — fast-attack mage bell + crystal bard chime.
  OW_THEMES.frost = {
    pattern = {
      mage    = mk{ {1, 22}, {17, 24}, {33, 21}, {49, 22}, {65, 24}, {81, 22}, {97, 21}, {113, 24} },
      cleric  = mk{ {1, 8}, {65, 8} },
      warrior = mk{ },
      bard    = mk{ {9, 25}, {41, 24}, {73, 25}, {105, 24} },
    },
    artic = {
      mage    = {vel=0.30, attack=0.001, release=0.80, wet=0.95},  -- icy ping
      cleric  = {vel=0.35, attack=0.40,  release=8.00, wet=0.95},
      bard    = {vel=0.25, attack=0.001, release=0.40, wet=0.95},
    },
  }

  -- HOLLOW: small earthy den — mostly silent with a low bell every 4 bars.
  OW_THEMES.hollow = {
    pattern = {
      mage    = mk{ {1, 13}, {65, 13} },
      cleric  = mk{ {1, 6}, {65, 6} },
      warrior = mk{ {33, 1}, {97, 1} },
      bard    = mk{ },
    },
    artic = {
      mage    = {vel=0.40, attack=0.005, release=2.50, wet=0.90},
      cleric  = {vel=0.40, attack=0.40,  release=7.00, wet=0.95},
      warrior = {vel=0.40, attack=0.005, release=1.50, wet=0.65},
    },
  }

  -- CRYPT (cave 6 — Locrian): tritone-haunted; cluster cleric + scraping bard
  OW_THEMES.crypt = {
    pattern = {
      mage    = mk{ {1, 11}, {17, 13}, {49, 11}, {65, 14}, {81, 13} },
      cleric  = mk{ {1, 1}, {33, 4}, {65, 1}, {97, 4} },
      warrior = mk{ {1, 1}, {65, 1} },
      bard    = mk{ {21, 22}, {53, 21}, {85, 22}, {117, 21} },
    },
    artic = {
      mage    = {vel=0.45, attack=0.005, release=2.20, wet=0.85},
      cleric  = {vel=0.50, attack=0.50,  release=8.00, wet=0.95},
      warrior = {vel=0.45, attack=0.20,  release=4.00, wet=0.85},
      bard    = {vel=0.30, attack=0.005, release=0.60, wet=0.75},
    },
  }

  -- CHAMBER (cave 7 — Suno's): heavy minimal throne hall; massive drone +
  -- three-note descent in the bard
  OW_THEMES.chamber = {
    pattern = {
      mage    = mk{ {1, 11}, {65, 11} },
      cleric  = mk{ {1, 1}, {49, 4}, {97, 1} },
      warrior = mk{ {1, 1}, {33, 1}, {65, 1}, {97, 1} },
      bard    = mk{ {25, 22}, {41, 21}, {57, 19}, {89, 22}, {105, 21}, {121, 19} },
    },
    artic = {
      mage    = {vel=0.55, attack=0.010, release=3.50, wet=0.95},
      cleric  = {vel=0.65, attack=0.60, release=10.0, wet=0.95},
      warrior = {vel=0.55, attack=0.005, release=2.50, wet=0.75},
      bard    = {vel=0.40, attack=0.020, release=2.00, wet=0.90},
    },
  }
end

-- ============================================================ BATTLE THEMES
-- Pass 34: FF4-FF10-style battle themes. Driving 8th-note bass ostinato in
-- the warrior, sustained pad in the cleric, fast melodic line in the mage,
-- and high accent stabs in the bard. Two themes:
--   "encounter" — random battles (faster, busier)
--   "boss"      — cave bosses (heavier, slower bass + more weight)
-- Stored as globals (no main-chunk locals) since we're at the 200 cap.
BATTLE_THEMES = {}
do
  local function mk(events)
    local p = {}
    for i = 1, OW_PATTERN_LEN do p[i] = 0 end
    for _, e in ipairs(events) do p[e[1]] = e[2] end
    return p
  end

  -- Standard random-encounter battle theme — 8 bars of 16 steps each.
  -- Bass ostinato in 8th notes (steps 1, 3, 5, 7, 9, 11, 13, 15 of each bar).
  -- Chord movement: i — i — bVII — i (A minor → A minor → G → A minor).
  BATTLE_THEMES.encounter = {
    pattern = {
      -- WARRIOR: low driving bass ostinato (8th notes). Pulse pattern with
      -- syncopated accent on offbeats every other bar.
      warrior = {
        -- bar 1: A pedal — 1,1,1,1,1,1,4,1
        1, 0, 1, 0, 1, 0, 1, 0,  1, 0, 1, 0, 4, 0, 1, 0,
        -- bar 2: A pedal w/ walk to 3
        1, 0, 1, 0, 1, 0, 3, 0,  1, 0, 1, 0, 1, 0, 4, 0,
        -- bar 3: bVII (G) — same shape one step lower
        4, 0, 4, 0, 4, 0, 4, 0,  4, 0, 4, 0, 6, 0, 4, 0,
        -- bar 4: back to A
        1, 0, 1, 0, 4, 0, 1, 0,  1, 0, 1, 0, 1, 0, 6, 0,
        -- bar 5: A pedal again
        1, 0, 1, 0, 1, 0, 1, 0,  1, 0, 1, 0, 4, 0, 1, 0,
        -- bar 6: A → C walk-up
        1, 0, 1, 0, 3, 0, 1, 0,  3, 0, 1, 0, 4, 0, 6, 0,
        -- bar 7: bVI (F) feel
        2, 0, 2, 0, 2, 0, 4, 0,  2, 0, 4, 0, 6, 0, 4, 0,
        -- bar 8: descending walk back to A
        4, 0, 3, 0, 1, 0, 4, 0,  1, 0, 1, 0, 1, 0, 4, 0,
      },
      -- CLERIC: chord pad — one held note per bar; chord changes at bars 3,5,7
      cleric = {
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,    -- A pad
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        9, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,    -- G pad
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        7, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,    -- C pad
        4, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,    -- F pad
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
      },
      -- MAGE: melodic line — fast staccato. Minor scale runs.
      mage = {
        13, 0,14, 0,15, 0,14, 0, 13, 0,11, 0,13, 0,15, 0,
        16, 0,15, 0,14, 0,13, 0, 11, 0,13, 0,14, 0,16, 0,
        15, 0,14, 0,13, 0,11, 0, 13, 0,11, 0, 9, 0,11, 0,
        13, 0,14, 0,15, 0,16, 0, 15, 0,14, 0,13, 0,15, 0,
        13, 0,14, 0,15, 0,14, 0, 13, 0,11, 0,13, 0,16, 0,
        18, 0,16, 0,15, 0,14, 0, 13, 0,11, 0,13, 0,15, 0,
        14, 0,13, 0,11, 0, 9, 0, 11, 0,13, 0,14, 0,15, 0,
        16, 0,15, 0,13, 0,11, 0, 13, 0,11, 0,13, 0,15, 0,
      },
      -- BARD: high accent stabs on offbeats — call-and-response feel.
      bard = {
         0, 0, 0, 0,21, 0, 0, 0,  0, 0, 0, 0,22, 0, 0, 0,
         0, 0, 0, 0,21, 0, 0, 0,  0, 0,22, 0,21, 0,19, 0,
         0, 0, 0, 0,19, 0, 0, 0,  0, 0, 0, 0,21, 0,19, 0,
         0, 0, 0, 0,21, 0, 0, 0,  0, 0,22, 0,21, 0, 0, 0,
         0, 0, 0, 0,21, 0,22, 0,  0, 0, 0, 0,21, 0,22, 0,
         0, 0, 0, 0,22, 0,24, 0,  0, 0, 0, 0,22, 0,21, 0,
         0, 0, 0, 0,19, 0,21, 0,  0, 0, 0, 0,19, 0,17, 0,
         0, 0, 0, 0,21, 0,22, 0,  0, 0,21, 0,19, 0,21, 0,
      },
    },
    artic = {
      warrior = {vel=0.85, attack=0.003, release=0.18, wet=0.20},  -- punchy bass
      cleric  = {vel=0.40, attack=0.20,  release=4.00, wet=0.80},  -- sustained pad
      mage    = {vel=0.70, attack=0.002, release=0.12, wet=0.30},  -- staccato lead
      bard    = {vel=0.60, attack=0.001, release=0.18, wet=0.55},  -- crisp stabs
    },
  }

  -- Boss battle — slower, heavier, more menacing. Half-time bass + more pad.
  BATTLE_THEMES.boss = {
    pattern = {
      warrior = {
        -- quarter-note bass (steps 1, 5, 9, 13 of each bar) — heavier feel
        1, 0, 0, 0, 1, 0, 0, 0,  1, 0, 0, 0, 4, 0, 0, 0,
        1, 0, 0, 0, 1, 0, 0, 0,  3, 0, 0, 0, 1, 0, 0, 0,
        4, 0, 0, 0, 4, 0, 0, 0,  4, 0, 0, 0, 6, 0, 0, 0,
        1, 0, 0, 0, 4, 0, 0, 0,  1, 0, 0, 0, 6, 0, 0, 0,
        2, 0, 0, 0, 2, 0, 0, 0,  4, 0, 0, 0, 1, 0, 0, 0,
        4, 0, 0, 0, 4, 0, 0, 0,  6, 0, 0, 0, 4, 0, 0, 0,
        1, 0, 0, 0, 1, 0, 0, 0,  3, 0, 0, 0, 1, 0, 0, 0,
        1, 0, 0, 0, 4, 0, 0, 0,  1, 0, 0, 0, 1, 0, 0, 0,
      },
      cleric = {
        -- minor cluster pad: A held longer + dissonant 2nd on alt bars
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        7, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        9, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        4, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        4, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        7, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
        6, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0,
      },
      mage = {
        -- slower dramatic melodic phrases (every 4 steps)
        13, 0, 0, 0,15, 0, 0, 0, 16, 0, 0, 0,15, 0, 0, 0,
        18, 0, 0, 0,16, 0, 0, 0, 15, 0, 0, 0,13, 0, 0, 0,
        15, 0, 0, 0,18, 0, 0, 0, 16, 0, 0, 0,15, 0, 0, 0,
        16, 0, 0, 0,15, 0, 0, 0, 13, 0, 0, 0,11, 0, 0, 0,
        13, 0, 0, 0,16, 0, 0, 0, 18, 0, 0, 0,16, 0, 0, 0,
        20, 0, 0, 0,18, 0, 0, 0, 16, 0, 0, 0,15, 0, 0, 0,
        15, 0, 0, 0,13, 0, 0, 0, 11, 0, 0, 0,13, 0, 0, 0,
        16, 0, 0, 0,15, 0, 0, 0, 13, 0, 0, 0,11, 0, 0, 0,
      },
      bard = {
        -- sparse menacing high stabs on bar 2 + bar 4 of each phrase
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0,22, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0,22, 0,21, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0,24, 0,22, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0,21, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0,22, 0, 0, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0,24, 0,22, 0,21, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0,21, 0,19, 0,
         0, 0, 0, 0, 0, 0, 0, 0,  0, 0,22, 0,21, 0,19, 0,
      },
    },
    artic = {
      warrior = {vel=1.00, attack=0.005, release=0.45, wet=0.30},  -- heavy hits
      cleric  = {vel=0.55, attack=0.30,  release=6.00, wet=0.90},  -- enormous pad
      mage    = {vel=0.75, attack=0.004, release=0.30, wet=0.55},  -- dramatic
      bard    = {vel=0.55, attack=0.002, release=0.40, wet=0.75},  -- menacing stabs
    },
  }
end

-- battle-music step counter is stored on TITLE.battle_step (TITLE is
-- declared further down in this file) and initialised in enter_battle.

-- ============================================================ TITLE THEME
-- FF1-Prelude inspired ascending arpeggios over slow chord pads.
-- Plays continuously on the TITLE screen.

-- TITLE THEME (richer): 4 bars (64 steps) with arpeggio + counter-melody +
-- moving bass + chime descant. FF-Prelude-style climb + descent.
local TITLE_PATTERN_LEN = 64
local TITLE_PATTERN = {
  -- mage: running 16th-note arpeggio, climbing then settling
  mage = {
    11,12,14,16, 11,12,14,16, 13,14,16,18, 13,14,16,18,
    14,16,18,19, 14,16,18,19, 16,18,19,21, 16,18,19,21,
    18,19,21,23, 18,19,21,23, 16,18,19,21, 16,18,19,21,
    14,16,18,19, 13,14,16,18, 12,14,16,17, 11,12,14,16,
  },
  -- cleric: chord pad (i → IV → V → i across the 4 bars)
  cleric = {
    11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    13, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    14, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    11, 0, 0, 0,  0, 0, 0, 0, 11, 0, 0, 0,  0, 0, 0, 0,
  },
  -- warrior: walking bass (anchor → step up → cadence)
  warrior = {
     1, 0, 0, 0,  0, 0, 0, 0,  3, 0, 0, 0,  0, 0, 0, 0,
     3, 0, 0, 0,  0, 0, 0, 0,  4, 0, 0, 0,  0, 0, 0, 0,
     4, 0, 0, 0,  0, 0, 0, 0,  6, 0, 0, 0,  0, 0, 0, 0,
     6, 0, 0, 0,  4, 0, 0, 0,  3, 0, 0, 0,  1, 0, 0, 0,
  },
  -- bard: high ringing chime descant + counter-melody on offbeats
  bard = {
     0, 0, 0, 0,  0, 0,21, 0,  0, 0, 0, 0,  0, 0,22, 0,
     0, 0,23, 0,  0, 0,21, 0,  0, 0,22, 0,  0, 0,24, 0,
     0, 0,25, 0,  0, 0,24, 0,  0, 0,22, 0,  0, 0,21, 0,
     0, 0,19, 0,  0, 0,21, 0,  0, 0,22, 0,  0, 0,16, 0,
  },
}

local TITLE_ARTIC = {
  mage    = {vel=0.45, attack=0.005, release=0.45, wet=0.65},
  cleric  = {vel=0.40, attack=0.10,  release=3.20, wet=0.80},
  warrior = {vel=0.50, attack=0.005, release=0.45, wet=0.40},
  bard    = {vel=0.50, attack=0.012, release=0.80, wet=0.70},
}

-- ============================================================ OVERWORLD MUSIC

-- Articulation per class for overworld voicing — softer, more reverberant than battle
local OW_ARTIC = {
  mage    = {vel=0.55, attack=0.005, release=0.45, wet=0.55},
  cleric  = {vel=0.45, attack=0.05,  release=2.20, wet=0.65},
  warrior = {vel=0.55, attack=0.005, release=0.30, wet=0.35},
  bard    = {vel=0.50, attack=0.012, release=0.55, wet=0.55},
}

-- ============================================================ STATE

local game_state = "TITLE"  -- TITLE | CUTSCENE | OVERWORLD | DIALOGUE | BATTLE | BATTLE_END | MENU | STATUS
local tick = 0
local clock_id

-- l2_held is now a TOGGLE (rising-edge of left trigger flips it).
-- Avoids issues with controller trigger drift causing the modifier to stick on.
-- DECLARED EARLY so all gamepad handlers (dpad/button/analog) share the same local.
local l2_held = false
local _trigger_prev = false  -- previous trigger-pressed state for edge detection

-- DEBUG: track the most recent gamepad event for on-screen display
-- (visibility toggled by "Debug" menu option)
local debug_visible = false
local last_input = ""
local last_input_at = 0

-- pause menu
local MENU_OPTIONS = {"Save Game", "Party Status", "Party", "Items", "Equipment", "Quests", "Bestiary", "Shards", "Jam Pad", "Debug", "Resume"}
local menu_idx = 1
local save_flash_ticks = 0
local save_flash_text = ""

-- party-status page (cycled with L1/R1)
local status_idx = 1
-- equip screen state
local equip_idx = 1       -- which party member 1..4
local equip_choice = 1    -- index into the owned-list for that class

-- last boss-drop instrument id (shown on BATTLE_END screen alongside the shard)
local last_boss_drop = nil

-- when player tries to enter the Tower without 5 shards, show a brief banner
local tower_locked_ticks = 0

-- forward-declared so STORY.play (defined here) can reach it at runtime
local start_dialogue

-- previous game_state captured when entering JAM mode (so SELECT toggles back)
local jam_prev_state = nil

-- title-screen menu state, bundled to keep main-chunk locals under the cap
local TITLE = {idx = 0, flash_ticks = 0, flash_text = ""}

-- bestiary + chest content state, bundled into one table to keep main-chunk
-- locals under Lua's 200 cap.
local CONTENT = {
  bestiary = {},   -- visual id -> {name, hp_max, atk, visual}
  chests = {
    {id = "ch_village_w",  map = 1, x = 30, y = 12, loot = {g = 30, item = "salve"}},
    {id = "ch_woods_n",    map = 1, x = 47, y = 4,  loot = {g = 60, item = "vial"}},
    {id = "ch_coast_e",    map = 1, x = 60, y = 5,  loot = {g = 80}, locked = true},
    {id = "ch_east_dune",  map = 2, x = 26, y = 11, loot = {g = 120, item = "star"}},
    {id = "ch_north_snow", map = 3, x = 22, y = 11, loot = {g = 150, item = "salve"}},
    -- Pass 19: a deep-cave locked stash (Cave 1 interior at 10,8).
    {id = "ch_cave1_deep", map = 7, x = 10, y = 8,  loot = {g = 200, item = "tonic"}, locked = true},
    -- Pass 24: side-dungeon big-payoff chest in The Hollow (map 12).
    {id = "ch_hollow_end", map = 12, x = 10, y = 8, loot = {g = 250, item = "star"}, locked = true},
  },
  opened = {},     -- chest id -> true
  flash_ticks = 0,
  flash_text = "",
  -- Reserve characters. Each: template fields + a `joined` flag set by story
  -- events. Once joined, can be swapped into the active party from the PARTY menu.
  recruits = {
    {class="engineer", spd=3, hp_max=24, mp_max=10, atk=3, def=3, mag=4,
     blurb="Engineer. Cuts new patterns from the noise.",
     joined=false},
    {class="mathwiz",  spd=4, hp_max=18, mp_max=18, atk=2, def=2, mag=5,
     blurb="Math wizard. Calls functions on the air.",
     joined=false},
    {class="drummer",  spd=5, hp_max=30, mp_max=8,  atk=4, def=2, mag=0,
     blurb="Drummer. Keeps the band on the one.",
     joined=false},
  },
  sergei_intervened = false,    -- one-shot Tidewatch rescue
  banner_ticks = 0,             -- generic story-event banner countdown
  banner_text = "",
  partysel_focus = 0,           -- 0 = none, 1 = Sergei, 2 = Paj, 3 = Niko
  -- Campfires: small rest points scattered on overworld; stepping on one heals
  -- the party 25% HP and shows a brief banner. Reusable (no opened state).
  campfires = {
    {map = 1, x = 38, y = 9},     -- Hollow Woods
    {map = 1, x = 53, y = 8},     -- Sunward Coast
    {map = 3, x = 10, y = 9},     -- Northern Wilds
  },
  -- Return position used when exiting an interior (door tile 17).
  -- Set when entering an interior; consumed when exiting.
  return_map = nil, return_x = nil, return_y = nil,
  -- Inn interior: map_id 5. Tiles: 4=wall, 0=floor, 17=exit door, 21=bed, 23=rug, 24=lantern.
  -- Innkeeper at (3,3) handles rest. Cat asleep on rug at (4,5).
  inn_map = {
    {4,4,38,4,4,4,4,4,38,4,4,4},     -- back wall: 2 framed paintings
    {4,21,21,0,0,39,0,0,30,30,0,4},  -- bed bed + plant + fireplace x2
    {4,21,21,0,0,0,0,0,0,0,0,4},     -- bed
    {4,0,0,0,40,32,23,23,0,0,0,4},   -- chair + dining table + rug
    {4,0,0,0,0,0,23,23,0,0,0,4},     -- rug (Mews at 7,5)
    {4,0,0,0,0,0,23,23,0,0,0,4},     -- rug (Pell at 9,6 nearby)
    {4,24,0,0,0,0,0,0,0,0,39,4},     -- lantern + plant in corner
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  -- Shop interior: map_id 6. Tiles: 4=wall, 0=floor, 17=exit, 22=counter,
  -- 24=lantern, 31=wares shelf (back-wall shelving), 33=brass till on
  -- counter, 35=barrel of goods.
  shop_map = {
    {4,4,4,4,4,41,4,4,4,4,4,4},          -- top wall: hanging "OPEN" sign
    {4,31,31,31,31,0,0,31,31,31,31,4},   -- back-wall shelves (with wares)
    {4,24,0,0,0,0,0,0,0,0,24,4},          -- lanterns
    {4,0,0,22,22,22,33,22,22,22,0,4},     -- counter (till at col 7)
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,35,0,0,0,0,0,0,0,0,35,4},          -- barrels in corners
    {4,42,0,0,0,0,0,0,0,0,39,4},          -- broom (left) + plant (right)
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  inn_npcs = {},   -- populated below where dialogue funcs are in scope
  shop_npcs = {},
  -- Cave 1 interior (map id 7). Tiles: 4=wall, 0=cave floor (walkable),
  -- 17=exit door, 27=boss arena marker. Random encounters roll on step.
  cave1_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,27,0,0,0,0,4},
    {4,0,4,4,0,0,0,0,4,4,0,4},
    {4,0,4,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,0,4,4,0,4,4,0,0,4},
    {4,0,0,0,4,0,0,0,4,0,0,4},
    {4,0,4,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  cave1_npcs = {},          -- populated below
  encounter_step_chance = 0.12,  -- per-step chance to roll a random battle in caves
  -- Cave 2 interior (map id 8). Wider, two-tier sentinel grove with vines.
  cave2_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,4,0,0,0,0,4,4,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,0,0,0,27,0,0,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,4,0,0,0,0,4,4,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,4,17,17,4,4,4,4,4,4},
  },
  cave2_npcs = {},
  -- Cave 3 interior (map id 9). Tidewater grotto: water tiles inside.
  cave3_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,27,0,0,0,0,4},
    {4,0,0,3,3,0,0,0,3,3,0,4},
    {4,0,0,3,0,0,0,0,0,3,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,3,3,3,3,0,0,0,4},
    {4,0,0,0,3,0,0,3,0,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  cave3_npcs = {},
  -- Cave 4 (Dune Rider) interior — desert grotto with sand-pillar islands.
  cave4_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,0,8,8,0,0,0,0,0,4},
    {4,0,0,0,8,8,0,0,4,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,4,0,0,27,0,0,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,8,8,0,0,0,4,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  cave4_npcs = {},
  -- Cave 5 (Snowgaunt) interior — frozen vault with ice-pillar maze.
  cave5_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,0,0,0,0,0,0,4,0,0,4},
    {4,0,0,0,0,0,27,0,0,0,0,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,4,0,0,4,4,0,0,4,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,0,0,0,0,0,0,4,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,4,17,17,4,4,4,4,4,4},
  },
  cave5_npcs = {},
  -- Side dungeon "The Hollow" (map id 12). Optional, no shard, no boss —
  -- just exploration + a treasure hunter NPC + a deep chest. Sized 12x10.
  hollow_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,0,0,0,0,4,0,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,0,0,4,4,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,0,4,0,0,0,0,0,0,0,4},
    {4,0,0,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  hollow_npcs = {},
  -- Cave 6 (Locrian Crypt) interior — final-island vault. Tile 27 = boss
  -- arena marker. Map id 13.
  cave6_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,0,0,0,27,0,0,0,0,4,0,4},
    {4,0,4,0,0,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,4,4,0,0,4,4,0,0,0,4},
    {4,0,0,0,4,0,0,0,0,4,0,0,0,4},
    {4,0,0,0,4,0,0,0,0,4,0,0,0,4},
    {4,0,4,0,0,0,0,0,0,0,0,4,0,4},
    {4,0,0,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,4,17,17,4,4,4,4,4,4},
  },
  cave6_npcs = {},
  -- Cave 7 (Suno's Chamber) interior — small antechamber to the final
  -- battle. Map id 14. No NPC, just the long walk to the throne tile.
  cave7_map = {
    {4,4,4,4,4,4,4,4,4,4,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,0,4,0,0,0,27,0,0,0,4,4},
    {4,0,4,0,0,0,0,0,0,0,4,4},
    {4,0,0,0,0,0,0,0,0,0,0,4},
    {4,4,4,4,4,17,17,4,4,4,4,4},
  },
  cave7_npcs = {},
}

-- Global jam controls (root-note transposition in semitones; bpm offset).
-- Adjusted via dpad while in JAM mode; persisted in save.
-- Build a 25-note scale array from a list of semitone intervals (one octave),
-- starting at MIDI base (A1 = 33).
local function build_scale(intervals)
  local out = {}
  local base = 33  -- A1
  local oct = 0
  while #out < 25 do
    for _, semi in ipairs(intervals) do
      out[#out + 1] = base + semi + oct * 12
      if #out >= 25 then break end
    end
    oct = oct + 1
  end
  return out
end

local JAM = {
  root = 0,                 -- semitones (-12 .. +12)
  mode = "pentatonic",       -- which scale is active
  note_names = {"A","A#","B","C","C#","D","D#","E","F","F#","G","G#"},
  -- Scales in A. Pentatonic is the always-available default; modes unlock
  -- as their shards are collected (lydian → Cave 1 boss, etc.).
  scales = {
    pentatonic = build_scale({0, 3, 5, 7, 10}),
    lydian     = build_scale({0, 2, 4, 6, 7, 9, 11}),
    dorian     = build_scale({0, 2, 3, 5, 7, 9, 10}),
    mixolydian = build_scale({0, 2, 4, 5, 7, 9, 10}),
    phrygian   = build_scale({0, 1, 3, 5, 7, 8, 10}),
    aeolian    = build_scale({0, 2, 3, 5, 7, 8, 10}),
    locrian    = build_scale({0, 1, 3, 5, 6, 8, 10}),
    ionian     = build_scale({0, 2, 4, 5, 7, 9, 11}),
  },
  -- Display order for cycling (only entries whose shard is held are picked).
  mode_order = {"pentatonic", "lydian", "dorian", "mixolydian", "phrygian",
                "aeolian", "locrian", "ionian"},
}

-- Current SCALE used by every fire_*_voice — looks up the active mode.
local function active_scale()
  return JAM.scales[JAM.mode] or JAM.scales.pentatonic
end

-- Story / party-banter scenes shown at the inn. Each scene plays once when its
-- trig() condition is true. Persisted via STORY.seen in the save file.
local STORY = {
  seen = {},
  scenes = {
    {
      id = "intro",
      trig = function() return true end,
      lines = {
        "[Miel]    Slept on the road three years.",
        "[Miel]    First mattress in months. I'd forgotten.",
        "[Strom]   I sleep light. The walls help, though.",
        "[Diegues] The old texts say the Crystal once",
        "[Diegues] sang every dawn. Woke villages with it.",
        "[Diegues] I dreamed the chord last night. Almost held it.",
        "[Alder]   You weren't dreaming. You were humming.",
        "[Alder]   ...wasn't bad. We could find that chord.",
        "[Miel]    Then let's go find it. Together, this time.",
        "[Strom]   ...I'll carry the lantern.",
      },
    },
    {
      id = "after_lydian",
      trig = function() return shards.lydian end,
      lines = {
        "[Strom] I served a captain. Brave. Dead now.",
        "[Strom] Suno's silencers came one dawn.",
        "[Strom] Nothing answered when she called for me.",
        "[Strom] I didn't speak for a year after.",
        "[Miel]  And here you are. With us.",
        "[Strom] Here I am. Speaking.",
      },
    },
    {
      id = "after_dorian",
      trig = function() return shards.dorian end,
      lines = {
        "[Diegues] The Academy taught: never split the chord.",
        "[Diegues] We split it anyway. To study.",
        "[Alder]  What did you find?",
        "[Diegues] That a chord apart is not a chord.",
        "[Diegues] Just notes. Cold ones.",
      },
    },
    {
      id = "after_mixolydian",
      trig = function() return shards.mixolydian end,
      lines = {
        "[Miel]  Father wanted me wed to Suno's envoy.",
        "[Miel]  I left at dusk in my brother's clothes.",
        "[Alder] So you're not really a princess?",
        "[Miel]  I am. I've stopped answering to it.",
        "[Strom] We answer to better names now.",
      },
    },
    {
      id = "after_phrygian",
      trig = function() return shards.phrygian end,
      lines = {
        "[Alder] My mother taught me a lullaby.",
        "[Alder] Suno's silencers came when I was nine.",
        "[Alder] They burned the chord-stones in our square.",
        "[Alder] I still sing the lullaby some nights.",
        "[Miel]  Sing it now.",
        "[Alder] ...alright.",
      },
    },
    {
      id = "after_aeolian",
      trig = function() return shards.aeolian end,
      lines = {
        "[Strom] I have a confession.",
        "[Strom] When I was young — not yet a soldier —",
        "[Strom] I carried a stranger across the Reaches.",
        "[Strom] He paid in silver. I asked no name.",
        "[Strom] Years later I learned what he became.",
        "[Diegues] Suno.",
        "[Strom] Suno.",
      },
    },
    {
      id = "after_locrian",
      trig = function() return shards.locrian end,
      lines = {
        "[Diegues] Six shards. The chord is nearly whole.",
        "[Miel]  Tomorrow it ends. One way or another.",
        "[Alder] If we lose tomorrow —",
        "[Strom] We lose every song.",
        "[Diegues] Then let's not lose.",
      },
    },
    {
      id = "two_shards",
      trig = function() return shards.lydian and shards.dorian end,
      lines = {
        "[Miel]  Two notes, sounded together — almost a chord.",
        "[Alder] I can hear the air listening for the next.",
        "[Diegues] Five to go. Five harder roads.",
        "[Strom] We've already gone harder than I thought we could.",
      },
    },
    {
      id = "halfway",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4
      end,
      lines = {
        "[Diegues] Four shards. Halfway through the chord.",
        "[Alder] Doesn't feel halfway.",
        "[Miel]  It rarely does, when you're inside it.",
        "[Strom] Keep walking.",
      },
    },
    {
      id = "before_finale",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 6 and not shards.ionian
      end,
      lines = {
        "[Strom] Suno's tower is open. Six shards. One missing.",
        "[Alder] Tomorrow we walk in.",
        "[Miel]  Tonight we sleep. The chord can wait one night.",
        "[Diegues] One night. And then — the seventh note.",
      },
    },
    -- ── SOLO VIGNETTES — one per character at certain shard milestones ──
    {
      id = "solo_alder",
      trig = function() return shards.lydian end,
      lines = {
        "[Alder] (alone, tuning the lute by the fire)",
        "[Alder] My mother used to hum this one.",
        "[Alder] I never asked her where she learned it.",
        "[Alder] I should have asked her so many things.",
      },
    },
    {
      id = "solo_miel",
      trig = function() return shards.dorian end,
      lines = {
        "[Miel] (writing in a small leather book)",
        "[Miel] I left a letter for him on the bedside table.",
        "[Miel] By dawn he will have read it.",
        "[Miel] By dusk he will not have forgiven me.",
        "[Miel] I am not sure I want him to.",
      },
    },
    {
      id = "solo_strom",
      trig = function() return shards.mixolydian end,
      lines = {
        "[Strom] (sharpening his blade slowly)",
        "[Strom] My captain. I never said her name aloud.",
        "[Strom] I think if I say it now the wind will carry it.",
        "[Strom] And maybe — a little — she will hear me.",
        "[Strom] ...Iela.",
      },
    },
    {
      id = "solo_diegues",
      trig = function() return shards.phrygian end,
      lines = {
        "[Diegues] (a notebook open on his knee)",
        "[Diegues] The Academy held that the seven were one.",
        "[Diegues] Fragmented, they cannot be themselves.",
        "[Diegues] I never quite believed it. Until tonight.",
        "[Diegues] We will reassemble it. Or die explaining why.",
      },
    },
    -- ── RECRUIT BANTER (gated on join flags) ──
    {
      id = "sergei_first_night",
      trig = function() return CONTENT and CONTENT.recruits[1].joined end,
      lines = {
        "[Sergei] (unspooling cable across the inn floor)",
        "[Strom]  You're laying wire indoors?",
        "[Sergei] I lay wire wherever the room lets me.",
        "[Sergei] Listen — your captain. Iela.",
        "[Sergei] I knew her brother. Different rig. Same hands.",
        "[Strom]  ...thank you.",
      },
    },
    {
      id = "sergei_remix",
      trig = function()
        return CONTENT and CONTENT.recruits[1].joined and shards.phrygian
      end,
      lines = {
        "[Sergei] Tonight I'm remixing the campfire.",
        "[Alder]  You can't remix a campfire.",
        "[Sergei] Watch me.",
        "[Miel]   He's adjusting the kindling rhythm.",
        "[Diegues] ...it does sound better.",
      },
    },
    {
      id = "paj_first_night",
      trig = function() return CONTENT and CONTENT.recruits[2].joined end,
      lines = {
        "[Paj]    I solved your travel times. You'd save 11%.",
        "[Alder]  By doing what?",
        "[Paj]    Skipping the pretty path through the woods.",
        "[Alder]  ...I like the pretty path.",
        "[Paj]    Then we save 0%. And you get prettiness.",
        "[Miel]   I take the prettiness.",
      },
    },
    {
      id = "paj_function",
      trig = function()
        return CONTENT and CONTENT.recruits[2].joined and shards.locrian
      end,
      lines = {
        "[Paj]    I have a guess at Suno's function.",
        "[Diegues] Show me.",
        "[Paj]    His chord wants to be silence.",
        "[Paj]    Solving for silence is short. Trivial.",
        "[Paj]    But silence cannot solve for him back.",
        "[Diegues] So we make him a question.",
        "[Paj]    Yes. We make him a question he can't answer.",
      },
    },
    {
      id = "all_six_at_inn",
      trig = function()
        return CONTENT and CONTENT.recruits[1].joined and CONTENT.recruits[2].joined
      end,
      lines = {
        "[Alder]  Six of us under one roof. Crowded.",
        "[Strom]  Quieter than I expected.",
        "[Sergei] That's the trick of a real band.",
        "[Sergei] Loud on stage, hush in the green room.",
        "[Paj]    Tomorrow we'll be loud in both.",
      },
    },

    -- ── Pass 29: backstory scenes + antagonist hooks ─────────────────────

    -- Triggers after the Iret encounter (1+ shards). Strom + Miel react.
    {
      id = "after_iret",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 1
      end,
      lines = {
        "[Miel]   The pale-coat in the plaza —",
        "[Miel]   she said my father's name like she owed it.",
        "[Strom]  Iret. Suno's diplomat.",
        "[Strom]  She came to my barracks once. Captain",
        "[Strom]  laughed her out the door. Two months",
        "[Strom]  later there were no barracks.",
        "[Diegues] So she's an opening move.",
        "[Diegues] Suno tests every door before he kicks it.",
      },
    },

    -- Triggers after the Vance encounter (2+ shards). Strom carries the weight.
    {
      id = "after_vance",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 2
      end,
      lines = {
        "[Strom]  Vance was at my captain's door.",
        "[Strom]  After. He wasn't shouting. Worse.",
        "[Strom]  He was — taking inventory.",
        "[Alder]  And he served under her? Before?",
        "[Strom]  Two summers. He brought her tea.",
        "[Miel]   People become weather, sometimes.",
        "[Miel]   We'll meet him in his storm.",
      },
    },

    -- Triggers after meeting Tess (3+ shards). Alder backstory.
    {
      id = "alder_tess_history",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 3
      end,
      lines = {
        "[Alder]  Tess. She was our second voice.",
        "[Alder]  We played four-piece, four years.",
        "[Alder]  Suno's recruiter came on a Tuesday.",
        "[Alder]  Said the Court paid in beds, not bread.",
        "[Alder]  I left town that night. Didn't tell her.",
        "[Diegues] You let her stay.",
        "[Alder]  I let her decide. There's a difference.",
        "[Alder]  ...there has to be.",
      },
    },

    -- Diegues' deeper backstory: why he left the Academy. Triggers at 3+ shards.
    {
      id = "diegues_academy",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 3 and STORY.seen.alder_tess_history
      end,
      lines = {
        "[Diegues] The Academy taught: the chord is theory.",
        "[Diegues] Ink on paper. Lecture-hall safe.",
        "[Diegues] My dean said Suno was a — climate.",
        "[Diegues] Inevitable. Seasonal. Plan around it.",
        "[Strom]  And you said?",
        "[Diegues] I said the chord is a sword if you sharpen it.",
        "[Diegues] The dean asked me to leave that afternoon.",
        "[Miel]   So you sharpened it.",
      },
    },

    -- Miel's deeper backstory: the marriage she fled. Triggers at 4+ shards.
    {
      id = "miel_marriage",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4
      end,
      lines = {
        "[Miel]   Father wasn't a coward. He was tired.",
        "[Miel]   Tired of burying neighbors.",
        "[Miel]   He thought a Court wedding would —",
        "[Miel]   shelter us. Like a tarp over a fire.",
        "[Strom]  And the envoy?",
        "[Miel]   I left him my brother's coat at the altar.",
        "[Miel]   With a note. Asking him to keep it warm.",
        "[Alder]  ...Miel. That's the meanest thing.",
        "[Miel]   I was seventeen. I am no longer seventeen.",
      },
    },

    -- Strom's captain — the captain Vance and Iret both knew.
    {
      id = "strom_captain",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4 and STORY.seen.miel_marriage
      end,
      lines = {
        "[Strom]  Captain's name was Reya. Reya Vell.",
        "[Strom]  She drilled us in the rain.",
        "[Strom]  Said the rain was Suno's,",
        "[Strom]  but our footing was ours.",
        "[Diegues] Did she know what was coming?",
        "[Strom]  She knew. She didn't run.",
        "[Strom]  Last words she said to me:",
        "[Strom]  'Stay loud. Stay together.'",
        "[Miel]   ...we will, Strom.",
      },
    },

    -- First time the player visits the Old Resonator (1+ shards): party
    -- discusses the discovery; sets up Sergei's eventual intervention.
    {
      id = "sergei_resonator_found",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 1 and STORY.seen.after_iret  -- after meeting Iret too
      end,
      lines = {
        "[Diegues] That tower in the woods — it hummed.",
        "[Diegues] Faintly. A held A. I can still feel it.",
        "[Strom]   The man there. Sergei. He built it,",
        "[Strom]   at nineteen. A music-relay. A resonator.",
        "[Miel]    Suno took the design. Burned the rest.",
        "[Strom]   He goes back to the wreck every dawn.",
        "[Strom]   Studying it. Looking for the shared wire.",
        "[Alder]   Then we walk past him. Slow.",
        "[Alder]   Let him hear us coming someday.",
      },
    },

    -- Sergei's history: he built a music-amplifying resonator — Suno
    -- destroyed it and stole the design. Triggers if Sergei joined +
    -- 3+ shards held.
    {
      id = "sergei_tower",
      trig = function()
        if not (CONTENT and CONTENT.recruits[1].joined) then return false end
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 3
      end,
      lines = {
        "[Sergei] That tower in the woods — it was mine.",
        "[Sergei] Built it at nineteen. A resonator,",
        "[Sergei] meant to carry villages' songs to villages",
        "[Sergei] that had stopped singing. A kind of relay.",
        "[Diegues] And Suno?",
        "[Sergei] Took the schematic. Burned the prototype.",
        "[Sergei] Built his silencers from the same coil.",
        "[Strom]  A relay turned into a muzzle.",
        "[Sergei] I go back at dawn. Dismantling. Studying.",
        "[Sergei] His silencers and my resonator share one wire.",
        "[Sergei] If I trace it backward, I cut his chord too.",
      },
    },

    -- Paj's revelation: she figured out Suno's chord-as-function. Late-game.
    {
      id = "paj_solution",
      trig = function()
        if not (CONTENT and CONTENT.recruits[2].joined) then return false end
        return shards.locrian
      end,
      lines = {
        "[Paj]    I solved it. The chord he plays.",
        "[Paj]    It's a function — input the world, output silence.",
        "[Diegues] Closed-form?",
        "[Paj]    Closed-form. But unstable on the boundary.",
        "[Paj]    A counter-chord — major seventh, root A —",
        "[Paj]    drops it into a divide-by-zero.",
        "[Alder]  English, please.",
        "[Paj]    We sing him into a paradox. He stops working.",
        "[Strom]  ...I love a good paradox.",
      },
    },

    -- Niko's scene: late-game intro at the inn. Joined-condition gated.
    {
      id = "niko_first_night",
      trig = function()
        return CONTENT and CONTENT.recruits[3] and CONTENT.recruits[3].joined
      end,
      lines = {
        "[Niko]   You folks count loud. I like that.",
        "[Alder]  We mostly forget where we are in the bar.",
        "[Niko]   Then I'm in the right room.",
        "[Niko]   I played Suno's house band three years.",
        "[Niko]   Same beat every night. No cymbals.",
        "[Niko]   I quit when they took the snare apart.",
        "[Strom]  ...you can have my hammer for cymbal.",
        "[Niko]   I'll hold you to that.",
      },
    },

    -- Tess's defection scene: post-locrian, on the rest after she defects.
    {
      id = "tess_defected",
      trig = function() return shards.locrian and CONTENT and CONTENT.tess_defected end,
      lines = {
        "[Alder]  Tess gave us a key. And a hundred-fifty.",
        "[Alder]  She kept my second lute, all this time.",
        "[Miel]   Will she sing the seventh with us?",
        "[Alder]  ...she will. From the inn balcony, probably.",
        "[Alder]  She always liked the cheap seats.",
        "[Diegues] We give her the harmony. We take the lead.",
        "[Strom]  Long as the chord rings, who cares who's loud.",
      },
    },

    -- ── Pass 42: deeper character + lore + pre-finale tension ──

    -- DIEGUES + MIEL bookish bond. Triggers after Diegues + Miel have both
    -- had their solo intros AND we have 2+ shards.
    {
      id = "diegues_miel_books",
      trig = function()
        if not (STORY.seen.solo_diegues and STORY.seen.solo_miel) then return false end
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 2
      end,
      lines = {
        "[Diegues] You read late again. The candle was guttering.",
        "[Miel]    The Crystal's first chronicler — Velthe?",
        "[Miel]    She wrote in the margins. Tiny, half-erased.",
        "[Diegues] (sitting up) What did the margins say?",
        "[Miel]    'A chord is a promise the air agrees to keep.'",
        "[Miel]    I think she meant it literally.",
        "[Diegues] ...so do I. Sleep. We'll read together at dawn.",
      },
    },

    -- ALDER + SERGEI music-tinkering. After Sergei joins.
    {
      id = "alder_sergei_tinker",
      trig = function() return CONTENT and CONTENT.recruits[1].joined and shards.dorian end,
      lines = {
        "[Alder]   Your mix coil — could it stretch a third?",
        "[Sergei]  Stretch how? Pitch, or duration?",
        "[Alder]   Both. The lute's third string sags after a fifth bar.",
        "[Sergei]  (already unspooling.) Hand it over. Two minutes.",
        "[Alder]   ...you fixed it. It rings. It actually rings.",
        "[Sergei]  Don't tell anyone. They'll all want one.",
        "[Alder]   I'm telling EVERYONE.",
      },
    },

    -- STROM + NIKO percussionists' bond. After Niko joins.
    {
      id = "strom_niko_percussion",
      trig = function() return CONTENT and CONTENT.recruits[3] and CONTENT.recruits[3].joined end,
      lines = {
        "[Niko]    Your hammer-arm. Drop the elbow on the swing.",
        "[Strom]   Why?",
        "[Niko]    You'll hit the same. With less you.",
        "[Strom]   ...show me.",
        "[Niko]    (taps Strom's shoulder twice on the down-beat.)",
        "[Strom]   (he tries it. nods, slow.) Less me. Better.",
        "[Niko]    See? Drumming.",
      },
    },

    -- WORLD-LORE: the Crystal's origin myth. Triggers at 3+ shards.
    {
      id = "lore_crystal_origin",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 3
      end,
      lines = {
        "[Diegues] The old text says: 'In the first dawn,",
        "[Diegues] Modalia hummed in seven keys at once.'",
        "[Diegues] The Crystal was the seventh's witness.",
        "[Miel]    Witness — not source?",
        "[Diegues] Source is us. The Crystal only listens.",
        "[Alder]   Then we have to keep singing.",
        "[Strom]   Even when no one's listening.",
        "[Miel]    Especially then.",
      },
    },

    -- ALDER writes a SONG. Mid-game.
    {
      id = "alder_writes_song",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4
      end,
      lines = {
        "[Alder]   I wrote something. About the road.",
        "[Alder]   It goes — (he hums six rising notes.)",
        "[Diegues] Mixolydian. With a flat second.",
        "[Alder]   I just thought it sounded sad and brave.",
        "[Diegues] ...you're right. That's better.",
        "[Miel]    Sing it again, Alder. Slow this time.",
        "[Strom]   (he hums along, surprising everyone.)",
      },
    },

    -- MIEL'S FAITH. After 4+ shards.
    {
      id = "miel_faith",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4
      end,
      lines = {
        "[Miel]    My order taught: every prayer is a held note.",
        "[Miel]    You hold it until the world answers.",
        "[Miel]    I held one for years. It went unanswered.",
        "[Strom]   And now?",
        "[Miel]    Now I am the answer. To someone else's note.",
        "[Diegues] ...that's the prettiest thing anyone's said this week.",
        "[Alder]   Don't make it weird, Diegues.",
        "[Diegues] Too late.",
      },
    },

    -- POST-VANCE-2nd-encounter dread. After Vance scene + 4+ shards.
    {
      id = "vance_dread",
      trig = function()
        if not STORY.seen.after_vance then return false end
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 4
      end,
      lines = {
        "[Strom]   Vance was waiting again. Knew our route.",
        "[Diegues] He's running scout patterns in his head.",
        "[Diegues] We're predictable. We need to not be.",
        "[Alder]   Then tonight we sleep with the lantern out.",
        "[Miel]    And tomorrow we take the long road.",
        "[Strom]   ...he'll still be there.",
        "[Miel]    Then we won't be sleeping.",
      },
    },

    -- A QUIET SCENE. No big stakes — just two characters at the fire.
    {
      id = "quiet_at_fire",
      trig = function()
        local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
        return n >= 3 and STORY.seen.diegues_miel_books
      end,
      lines = {
        "[Alder]   You ever miss the road being just a road?",
        "[Strom]   Every day.",
        "[Alder]   ...me too. Especially the bits with no plot.",
        "[Strom]   (almost smiles.) The bits with no plot were the best.",
        "[Alder]   We'll have those again.",
        "[Strom]   ...promise?",
        "[Alder]   Promise.",
      },
    },

    -- PRE-FINALE: the night before Suno's chamber.
    {
      id = "pre_finale_night",
      trig = function() return shards.locrian end,
      lines = {
        "[Diegues] Six shards on the table. Ionian remains.",
        "[Strom]   The Chamber's gate is across the bridge.",
        "[Miel]    No more roads after that. Just the stairs.",
        "[Alder]   Then tonight we play through every song we know.",
        "[Alder]   Once. End to end.",
        "[Sergei]  ...and at dawn, we walk in.",
        "[Miel]    Together.",
        "[Strom]   Together.",
      },
    },

    -- ── Pass 46: in-cave first-entry scenes ──
    {
      id = "enter_cave1",
      trig = function() return CONTENT and CONTENT.cave_entered and CONTENT.cave_entered[1] end,
      lines = {
        "[Diegues] Cave 1. The Echoes.",
        "[Diegues] Listen — every footstep returns shifted.",
        "[Diegues] A perfect fifth lower.",
        "[Strom]   Don't strike on the echo.",
        "[Strom]   Strike between. Always between.",
        "[Alder]   ...this place sings, doesn't it.",
        "[Miel]    It does. We sing back.",
      },
    },
    {
      id = "enter_cave2",
      trig = function() return CONTENT and CONTENT.cave_entered and CONTENT.cave_entered[2] end,
      lines = {
        "[Strom]   The Sentinel grove. Hush, Alder.",
        "[Alder]   I'm being quiet!",
        "[Diegues] (whispering) The trees aren't only trees here.",
        "[Diegues] One of them remembers Velthe by name.",
        "[Miel]    Walk soft. Sing soft.",
        "[Strom]   ...sing not at all, please.",
        "[Alder]   Fine. Fine.",
      },
    },
    {
      id = "enter_cave3",
      trig = function() return CONTENT and CONTENT.cave_entered and CONTENT.cave_entered[3] end,
      lines = {
        "[Miel]    The Tidewater Grotto. Anwell warned us.",
        "[Miel]    Don't trust the still pools.",
        "[Diegues] The Tidewatch keeps a face in each.",
        "[Strom]   (he tilts his lantern to the water.)",
        "[Strom]   ...mine looks angrier than I feel.",
        "[Alder]   Or yours is honest and you aren't.",
        "[Miel]    Both possible.",
      },
    },
    {
      id = "enter_cave4",
      trig = function() return CONTENT and CONTENT.cave_entered and CONTENT.cave_entered[4] end,
      lines = {
        "[Diegues] Dune Hall. Sand carries every footfall.",
        "[Diegues] He'll hear us before we see him.",
        "[Miel]    Iska said: cut on the rest beat. Six-beats out, two back.",
        "[Strom]   Six-and-two. We can keep that meter.",
        "[Alder]   I'll count us in. (he hums a quiet count.)",
      },
    },
    {
      id = "enter_cave5",
      trig = function() return CONTENT and CONTENT.cave_entered and CONTENT.cave_entered[5] end,
      lines = {
        "[Miel]    The Frost Vault. My breath shows.",
        "[Strom]   Don't let the cold pull your tempo.",
        "[Strom]   He waltzes in three. We don't.",
        "[Alder]   I'll hold us in four. Solid four.",
        "[Diegues] Wenna said: drown his time with ours.",
        "[Miel]    Then let's drown it.",
      },
    },

    -- BAND IS A BAND. The morning of the final.
    {
      id = "band_is_a_band",
      trig = function()
        return shards.locrian and STORY.seen.pre_finale_night
      end,
      lines = {
        "[Alder]   We sound like a band now.",
        "[Sergei]  We sound like a band that survives the gig.",
        "[Niko]    (taps a four-count on the table.)",
        "[Niko]    One — two — three — four — let's go.",
        "[Diegues] (he breathes out, quietly.) Yes.",
        "[Miel]    For Velthe. For the held note.",
        "[Strom]   For Reya.",
        "[Alder]   For us.",
      },
    },
  },
}

STORY.play = function()
  for _, sc in ipairs(STORY.scenes) do
    if not STORY.seen[sc.id] and sc.trig() then
      STORY.seen[sc.id] = true
      -- present as a fake-NPC dialogue (advance_dialogue handles the lines)
      start_dialogue({name = "_party_scene", dialogue = sc.lines})
      return true
    end
  end
  return false
end

-- Fire a SPECIFIC scene by id (cave-entry hooks etc.) without iterating
-- over all scenes — avoids accidentally surfacing an inn scene at a cave.
STORY.play_id = function(id)
  if STORY.seen[id] then return false end
  for _, sc in ipairs(STORY.scenes) do
    if sc.id == id and sc.trig() then
      STORY.seen[id] = true
      start_dialogue({name = "_party_scene", dialogue = sc.lines})
      return true
    end
  end
  return false
end

-- Sidequest state. Hens/Brann count random-encounter wins; Tova tracks which
-- regional NPCs the party has spoken to. Persisted in save.
local QUESTS = {
  hens  = {wins = 0, target = 5,  discount = false, claimed = false},
  brann = {wins = 0, target = 10, claimed = false},
  tova  = {spoke = {}, claimed = false},  -- spoke[name]=true for Veris/Aurin/Mira/Iolen
  pith  = {target = 3, claimed = false},  -- report-back when 3+ caves cleared
}

-- battle animation state + helpers (bundled to keep main-chunk locals under cap)
local ANIM = {
  popups = {},   -- floating damage/heal numbers; each {x, y, amt, lev, t}
  proj   = nil,  -- in-flight enemy projectile {sx, sy, tx, ty, t}
  crit   = 0.10, -- crit chance per offensive action
  cave_names = {[1]="CAVE", [2]="DEEP WOOD", [3]="TIDE CAVERN", [4]="GLASS CAVERN", [5]="ICE GROTTO", [6]="LOCRIAN CRYPT", [7]="SUNO'S CHAMBER"},
  -- Pass 53 visual effects state.
  shake_t = 0,                        -- ticks remaining of screen shake
  shake_mag = 0,                      -- shake magnitude (1-3 px)
  hit_flash_t = -99,                  -- tick of last hit flash
  particles = {},                     -- {x, y, vx, vy, t, lev} bursts
  dust = {},                          -- {x, y, t} player footstep puffs
}
-- ──────────────────────────────────────────────────────────────────────────
ANIM.shake = function(mag, ticks)
  ANIM.shake_mag = math.max(ANIM.shake_mag, mag or 1)
  ANIM.shake_t   = math.max(ANIM.shake_t,   ticks or 4)
end
ANIM.flash_hit = function() ANIM.hit_flash_t = tick end
ANIM.burst = function(cx, cy, n, lev)
  for i = 1, (n or 8) do
    local ang = (i / (n or 8)) * math.pi * 2 + math.random() * 0.4
    ANIM.particles[#ANIM.particles + 1] = {
      x = cx, y = cy,
      vx = math.cos(ang) * (1.2 + math.random() * 0.8),
      vy = math.sin(ang) * (1.2 + math.random() * 0.8),
      t = tick, lev = lev or 15,
    }
  end
end
ANIM.dust_puff = function(cx, cy)
  ANIM.dust[#ANIM.dust + 1] = {x = cx, y = cy, t = tick}
end

-- true while in a random overworld encounter (not a cave fight)
local random_battle = false
-- chance per overworld step to spawn a random encounter (outside the village)
-- Pass 35: bumped from 0.04 → 0.07 (more frequent road encounters).
local ENCOUNTER_CHANCE = 0.07

-- Bundled shop/economy state (kept in one table to stay under Lua's 200-local cap)
local SHOP = {
  gold = 0,
  inv = { salve = 0, vial = 0, star = 0, ether = 0, tonic = 0, key = 0 },
  last_gold = 0,        -- gold from most recent kill (shown on BATTLE_END)
  last_item = nil,      -- last ITM item used (shown briefly in battle)
  idx = 1,              -- cursor in shop UI
  flash_ticks = 0,
  flash_text = "",
  items = {
    salve = { name = "Salve", cost = 20, desc = "+35 HP all" },
    vial  = { name = "Vial",  cost = 30, desc = "+10 MP all" },
    star  = { name = "Star",  cost = 80, desc = "Revive KO"  },
    ether = { name = "Ether", cost = 45, desc = "+25 MP all" },
    tonic = { name = "Tonic", cost = 60, desc = "+ATK 1 fight" },
    key   = { name = "Key",   cost = 95, desc = "Open lock"   },
  },
  order = {"salve", "vial", "ether", "star", "tonic", "key"},
}

-- ENDING state runs the final cutscene panels by index
local ending_idx = 1
-- set true on Suno defeat; consumed in exit_battle to flip game_state to ENDING
local ending_pending = false

-- ranges for tempo settings
local BPM_MIN, BPM_MAX, BPM_STEP = 60, 180, 1

-- overworld state
local player = { x = 6, y = 6, facing = "down" }
local cam = { x = 1, y = 1 }

-- dialogue state
local dlg = { npc = nil, line = 1 }

-- party (persists across battles)
local party = {}
local active = 1

-- battle state
local enemy = nil
local battle_end_ticks = 0
local battle_outcome = nil  -- "VICTORY" | "DEFEAT"

-- per-cave progression
-- bundled per-cave progression state to keep main-chunk locals under Lua's 200 cap
local cave_state = {
  [1] = {victories = 0, cleared = false},
  [2] = {victories = 0, cleared = false},
  [3] = {victories = 0, cleared = false},
  [4] = {victories = 0, cleared = false},
  [5] = {victories = 0, cleared = false},
  [6] = {victories = 0, cleared = false},
  [7] = {victories = 0, cleared = false},
}
local current_cave = 1

-- which continent are we on
local current_map_id = 1   -- 1 = Mainland, 2 = Eastern Reaches

-- voyage state
local voyage_ticks = 0
local VOYAGE_DURATION = 80   -- ~5s at 100 BPM
local voyage_target_map = 1
local voyage_target_x = 1
local voyage_target_y = 1

-- region detection (for environment overlays + region-name banner)
local last_region = nil
local region_label_ticks = 0

local function get_region(x)
  if x <= 32 then return "village"
  elseif x <= 48 then return "woods"
  else return "coast"
  end
end

-- level-up flash (visual feedback when a party member gains a level)
local levelup_flash_ticks = 0
local levelup_flash_who = ""

-- overworld music state
local overworld_step = 0
local title_step = 0
local intro_step = 0

-- victory fanfare playback state
local victory_step = 0

-- shards collected
local shards = {lydian=false, dorian=false, mixolydian=false, phrygian=false, aeolian=false, locrian=false, ionian=false}
local last_obtained_shard = nil

-- inn rest banner timer (ticks)
local inn_rest_ticks = 0

-- cutscene step
local cutscene_idx = 1

-- ============================================================ MAP

-- 0=grass 1=tree 2=path 3=water 4=wall 5=door 6=cave1 (Lydian) 7=cave2 (Dorian)
-- 8=sand 9=cave3 (Mixolydian) 10=boat 11=cave4 (Phrygian)
-- Map data is per-continent; active map swaps via travel_to().
-- MAINLAND (64x16): cols 1-32 = Village; 33-48 = Hollow Woods; 49-64 = Sunward Coast.
-- Mountain pass (id 15) at row 1 col 13 → Northern Wilds (current_map_id 3).
local MAINLAND = {
  {1,1,1,1,1,1,1,1,1,1,1,0,15,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1, 1,0,0,0,1,1,0,0,0,0,1,1,1,0,0,1, 1,0,0,0,0,0,0,0,8,8,0,0,0,1,0,1},
  {1,0,4,4,4,0,0,0,4,4,4,0,2,0,0,0,0,0,4,4,4,0,0,0,0,0,0,0,0,0,0,1, 0,0,0,0,0,1,0,0,0,0,0,1,0,0,0,1, 1,0,1,0,0,0,0,0,0,8,8,0,0,0,0,1},
  {1,0,4,0,4,0,0,0,4,0,4,0,2,0,0,0,0,0,4,0,4,0,0,0,1,0,0,0,0,0,0,1, 0,0,0,0,0,0,36,1,0,0,43,0,0,0,1,1, 1,0,0,0,0,0,0,0,0,0,8,8,0,0,1,1},
  {1,0,4,5,4,0,0,0,4,5,4,0,2,0,0,0,0,0,4,5,4,2,2,2,2,2,2,2,2,2,1,1, 0,2,2,2,2,2,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,2,0,0,0,2,0,0,0,1,0,0,0,1,0,0, 1,0,0,0,0,1,0,0,0,0,0,0,1,0,0,1},
  {1,0,0,13,0,12,0,0,0,0,0,0,2,0,14,0,18,0,0,0,0,0,0,0,0,0,0,0,6,0,0,0, 0,2,0,0,0,2,2,2,2,2,2,2,7,0,0,0, 2,2,2,2,2,2,2,2,2,2,2,2,2,9,0,10},
  {1,1,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1, 0,2,0,0,0,2,0,0,0,0,0,0,0,0,1,1, 0,0,0,0,2,0,0,0,0,0,0,0,8,8,0,1},
  {1,1,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,5,4,0,0,0,0,0,1, 1,2,0,0,0,0,0,0,0,0,0,0,1,0,0,1, 1,0,0,0,2,0,0,0,0,0,0,0,8,8,0,1},
  {1,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,0,4,0,1,0,0,0,1, 1,2,0,0,0,0,0,0,0,0,0,1,0,0,0,1, 1,0,0,0,0,0,0,0,0,0,8,8,8,0,0,1},
  {1,0,0,0,0,0,2,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,4,4,4,0,0,0,0,0,1, 1,1,0,0,0,0,0,0,0,0,1,1,0,0,1,1, 1,0,0,0,0,0,0,0,8,8,8,8,0,0,0,1},
  {1,0,1,0,0,0,0,0,45,45,45,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,1, 1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1, 1,1,0,0,0,0,8,8,8,8,0,0,0,0,0,1},
  {1,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,1, 1,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1, 1,1,1,0,0,8,8,8,0,0,0,0,0,0,0,1},
  {1,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,1,1, 1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1, 1,1,1,1,8,8,8,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1, 1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1, 1,1,1,1,8,8,8,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,1,1, 1,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

-- second continent: Eastern Reaches (32×16 desert/exotic)
-- boat lands at (1,7); cave4 at (25,7); NPC Mira at (14,7)
local EASTERN_REACHES = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8,8,0,0,0,0,0,0,1},
  {1,0,0,0,0,8,8,8,8,0,0,1,0,0,0,0,0,0,0,0,8,8,8,0,0,0,0,0,1,0,0,1},
  {1,0,0,0,0,0,0,8,8,8,0,0,0,0,0,0,0,0,0,8,8,0,0,0,0,1,0,0,0,0,0,1},
  {1,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,11,0,0,0,0,0,0,1},
  {10,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,1},
  {1,0,13,0,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,8,8,8,8,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,1,0,0,0,0,0,8,8,8,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,8,8,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,8,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

-- third continent: Northern Wilds (28x14 frozen highlands)
-- Reached via mountain pass (id 15) at MAINLAND (13,1).
-- Cave5 (id 16) at (21, 7); return pass at (5, 13).
local NORTHERN_WILDS = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8,8,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,0,0,0,0,8,8,8,8,0,0,0,0,8,8,8,0,0,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,1,0,0,8,8,0,0,0,2,0,0,8,8,0,0,0,0,0,0,1,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,0,0,0,0,0,0,1,0,0,0,2,0,0,0,0,0,1,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,16,0,0,0,0,0,0,1},
  {1,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1},
  {1,0,0,1,0,2,0,0,8,8,8,0,0,0,0,0,0,0,8,8,8,0,0,0,0,0,0,1},
  {1,0,0,0,0,2,0,8,8,0,0,0,0,0,0,0,0,0,8,8,8,8,0,0,0,1,0,1},
  {1,0,13,0,0,2,0,8,12,0,0,0,0,0,0,0,0,0,0,0,8,8,8,0,0,0,0,1},
  {1,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8,0,0,0,0,1},
  {1,0,0,0,15,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

-- fourth continent: SUNO'S DOMAIN (24x14 dark fortress).
-- Reached via Tower tile (id 18) at village plaza; only walkable when shards >= 5.
-- Cave 6 entry (id 19) at (6,7) → Locrian Shard.
-- Cave 7 entry (id 20) at (18,7) → Suno → Ionian Shard → ENDING.
local SUNOS_DOMAIN = {
  {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4},
  {4,0,1,0,4,4,0,0,0,0,0,4,4,0,0,0,0,4,4,0,1,0,0,4},
  {4,0,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,4,0,0,0,0,0,4},
  {4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4},
  {4,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,4},
  {4,0,0,0,0,0,0,2,2,2,0,0,0,0,0,2,2,2,0,0,0,0,0,4},
  {4,0,0,0,0,0,19,2,0,0,0,0,0,0,0,0,0,2,20,0,0,0,0,4},
  {4,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,4},
  {4,0,0,0,0,0,0,2,2,2,0,0,0,0,0,2,2,2,0,0,0,0,0,4},
  {4,0,0,0,0,0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0,0,0,4},
  {4,0,0,0,4,4,0,0,0,0,0,0,0,0,0,0,0,4,4,0,0,0,0,4},
  {4,0,0,0,0,0,0,0,0,0,0,18,0,0,0,0,0,0,0,0,0,0,0,4},
  {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4},
}

local map = MAINLAND   -- active map (mutable; swaps on travel_to)
local MAP_W = #map[1]
local MAP_H = #map

-- npc.dialogue is a function returning the current line set, so it can vary by progress
-- NPC lists are per-continent; `npcs` points at the active list.
local MAINLAND_NPCS = {
  { x = 4, y = 6, name = "Tova",
    dialogue = function()
      local lead = party[active] and party[active].class
      -- Tova lights up when Diegues (mage / scholar) is in the lead.
      if lead == "mage" then
        return {
          "(her eyes brighten when she sees Diegues)",
          "Academy boy, are you? I read your dean's last paper.",
          "Brilliant. Wrong about the chord — but brilliant.",
          "Ask me about the seven before you leave.",
        }
      end
      -- SIDEQUEST: meet all four regional sages, return for a lore reward.
      local s = QUESTS.tova.spoke
      local visited = (s.Veris and 1 or 0) + (s.Aurin and 1 or 0)
                    + (s.Mira  and 1 or 0) + (s.Iolen and 1 or 0)
      if visited == 4 and not QUESTS.tova.claimed then
        QUESTS.tova.claimed = true
        SHOP.gold = SHOP.gold + 80
        return {
          "You spoke with Veris. Aurin. Mira.",
          "And Iolen of the highlands too.",
          "Each holds a fragment of the chord.",
          "Together they form the old map.",
          "Take this — earned, not given.",
          "(+80 gold)",
        }
      elseif QUESTS.tova.claimed then
        return {
          "The map of the seven sings to me",
          "more clearly now, thanks to you.",
          "Suno fears the chord most of all.",
          "Strike one shard, the next rings true.",
        }
      elseif visited > 0 then
        return {
          "You've met " .. visited .. " of the four sages.",
          "Veris in the Wood. Aurin on the Coast.",
          "Mira in the Reaches. Iolen in the Wilds.",
          "Find them all — return to me.",
        }
      end
      if shards.aeolian then
        return {
          "The Aeolian Shard! Few survive",
          "the Snowgaunt's keening waltz.",
          "You bear the lonely song now.",
          "Two shards still elude us, child.",
        }
      elseif shards.lydian then
        return {
          "I once charted seven nations.",
          "Each held a shard. Each fell silent.",
          "When Suno turned the world quiet,",
          "I retired to my books. Until now.",
          "(Quest: meet the four regional sages.)",
        }
      end
      return {
        "I am Tova. I read the old runes.",
        "The Crystal Synth was a chord —",
        "seven notes ringing as one.",
        "Suno hunts each note alone.",
        "Find them before they go cold.",
        "(Quest: meet the four regional sages.)",
      }
    end,
  },
  -- (Plaza Hens removed Pass 24 — she now runs the item-shop interior;
  -- the village no longer has a duplicate outdoor shop NPC.)
  { x = 19, y = 6, name = "Elder",
    dialogue = function()
      if shards.dorian then
        return {
          "Two shards. Truly remarkable.",
          "The Hollow Woods lie quiet now.",
          "But Suno gathers his armies.",
          "Five shards remain, scattered.",
          "Press on, heroes.",
        }
      elseif shards.lydian then
        return {
          "You found the Lydian Shard.",
          "But Suno hunts six more.",
          "The Hollow Woods lie east.",
          "Veris waits within.",
          "She knows of the next shard.",
        }
      end
      return {
        "Travelers from afar?",
        "Suno's shadow grows.",
        "He hunts the Crystal Synth,",
        "shattered when Modalia formed.",
        "A shard sleeps east in the cave.",
        "Recover it before he does.",
      }
    end,
  },
  { x = 27, y = 9, name = "Brann",
    dialogue = function()
      -- SIDEQUEST: 10 random encounter wins → 200g + a free Star item.
      local q = QUESTS.brann
      if q.wins >= q.target and not q.claimed then
        q.claimed = true
        SHOP.gold = SHOP.gold + 200
        SHOP.inv.star = SHOP.inv.star + 1
        return {
          "Ten road fights. You bring me",
          "ore-stained metal each time.",
          "I melted, I folded, I sang it true.",
          "Take this — and 200g for the slag.",
          "(+200 gold, +1 Star)",
        }
      elseif q.claimed then
        return {
          "Anvil's quiet today. Good road work?",
          "Bring me anything weird from the deeps.",
          "I always have a forge waiting.",
        }
      elseif q.wins > 0 then
        return {
          "Heard you've cleared " .. q.wins .. "/" .. q.target .. " road fights.",
          "Each one drops slag I can refine.",
          "Bring me ten, I'll forge you a marvel.",
        }
      end
      if shards.mixolydian then
        return {
          "Hammered all night. Coast steel",
          "doesn't temper itself, you know.",
          "Survive ten road fights — I'll forge",
          "you something worth the breath.",
          "(Quest: 10 random-encounter wins.)",
        }
      end
      return {
        "Brann. Smith. Don't touch the anvil.",
        "Adventurers always touch the anvil.",
        "Survive ten road fights — bring me",
        "the slag. I'll forge a marvel.",
        "(Quest: 10 random-encounter wins.)",
      }
    end,
  },
  { x = 14, y = 8, name = "Pip",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      if n >= 7 then
        return {
          "The fountain's singing again!",
          "Mama said it hadn't sung in years.",
          "She cried when she heard it.",
          "Did you bring the songs back?",
        }
      elseif n >= 4 then
        return {
          "I tried to sing the Lydian last night.",
          "Mama said I sounded close.",
          "She says I'll sing better when",
          "all the shards come home.",
        }
      elseif n >= 1 then
        -- After your first shard but still early
        return {
          "I heard a humming this morning.",
          "Mama said the wind sounded different.",
          "Was that you? Did you find one?",
          "Keep going! Bring more songs back!",
        }
      end
      -- Pre-first-shard: cycle through 3 sets so Pip doesn't repeat the same
      -- line every time you talk to her at the very beginning.
      local variants = {
        {
          "Hi! I'm Pip.",
          "Are you the new musicians?",
          "Mama said you'd come.",
          "She didn't say when.",
        },
        {
          "Have you been to the cave yet?",
          "I'm not allowed to go.",
          "Mama says I'm too small.",
          "But I'm only a LITTLE small.",
        },
        {
          "The fountain used to sing.",
          "Now it just gurgles.",
          "Gurgles aren't songs.",
          "Bring the songs back, okay?",
        },
      }
      return variants[(tick // 60) % #variants + 1]
    end,
  },
  { x = 16, y = 7, name = "Lyrik",
    dialogue = function()
      if shards.lydian then
        return {
          "The Lydian song returns!",
          "I can feel it in the air.",
          "Each shard you reclaim",
          "weakens Suno's grip.",
          "Continue east, brave ones.",
        }
      end
      return {
        "Greetings, musicians.",
        "I sing the old chronicles.",
        "When the Crystal Synth split,",
        "each shard found a nation.",
        "Modalia waits for heroes.",
        "Travel well, friends.",
      }
    end,
  },
  { x = 56, y = 6, name = "Wren",
    dialogue = function()
      local n = 0
      for _, v in pairs(shards) do if v then n = n + 1 end end
      if n >= 6 then
        return {
          "I sing where the seven once sang.",
          "Six shards in your hands. One left.",
          "Suno hoards the Ionian — the bright one.",
          "Take it. End the silence. End him.",
        }
      elseif n >= 3 then
        return {
          "Wren. I follow the music wherever",
          "music still dares to sing.",
          "Three shards already. Brave troupe.",
          "When you find the Ionian, the chord",
          "will ring. We'll all hear it.",
        }
      end
      return {
        "Wren. Wandering minstrel.",
        "I follow the music, when it lasts.",
        "The Ionian shard — the seventh —",
        "is locked in Suno's tower itself.",
        "Six others lie scattered. Find them.",
      }
    end,
  },
  { x = 51, y = 6, name = "Aurin",
    dialogue = function()
      local lead = party[active] and party[active].class
      -- class-aware opener: Aurin recognizes Strom (warrior) as a fellow soldier
      if lead == "warrior" then
        return {
          "(her eyes find Strom's first)",
          "I know that posture. The same rest, the same sword arm.",
          "You're a soldier still. Be careful here.",
          "The tide-spawn don't fight by rank.",
        }
      end
      if shards.mixolydian then
        return {
          "The Sunward chord rings true.",
          "I'd never have believed it.",
          "Three shards reclaimed.",
          "Four to go, brave hearts.",
          "Sail on, friends.",
        }
      end
      return {
        "I am Aurin, of the Sunward shore.",
        "The third shard, Mixolydian,",
        "lies in the sunken cavern east.",
        "Suno's tide-spawn guard it well.",
        "The sea has waited for heroes.",
        "Wake the song. Let it sing.",
      }
    end,
  },
  { x = 36, y = 7, name = "Veris",
    dialogue = function()
      if shards.dorian then
        return {
          "The Dorian Shard sings again!",
          "The Sentinel sleeps at last.",
          "Beyond these woods lies more.",
          "Other nations need their songs.",
          "Find them. Save Modalia.",
        }
      end
      return {
        "I am Veris, sage of the Wood.",
        "The Dorian Shard sleeps deep,",
        "guarded by the Forest Sentinel.",
        "Old, vast, and slow to wake.",
        "But wake it must, in your hands.",
        "The cave lies east of here.",
      }
    end,
  },
  -- ── RECRUIT NPCs (visible in the world; not yet recruitable into the party) ──
  -- Sergei stands at the Old Resonator — his ruined music-amplifier tower,
  -- destroyed by Suno after the schematic was stolen and weaponized into
  -- the first silencing tower. He returns at dawn to study the wreckage,
  -- looking for the one shared wire that could undo Suno's chord.
  -- Hidden until 1+ shards. The Tidewatch intervention still does the
  -- actual joining (one-shot in damage_party).
  { x = 43, y = 3, name = "Sergei",
    visible = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      return n >= 1
    end,
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lead = party[active] and party[active].class
      if CONTENT.recruits[1].joined then
        return {
          "Sergei: Tidewatch nearly had you.",
          "I never thought I'd throw a wrench at a god.",
          "But Suno burned my work. I owed him the favor.",
          "I'm in the roster. Swap me in any time.",
        }
      end
      -- Pre-join: layered backstory based on shard count + class lead
      if lead == "warrior" then
        return {
          "Sergei: A soldier. Good. Listen —",
          "this tower was a music-relay. A resonator.",
          "Carried village songs to villages that had",
          "stopped singing. Suno took the design.",
          "Burned the prototype. Built the silencers",
          "from the same coil. (...still hurts, that.)",
        }
      end
      if n >= 4 then
        return {
          "Sergei: Four shards. The math's clean now.",
          "I've traced the wire backward through the rubble.",
          "His silencers and my resonator share a coil.",
          "If you ring the chord, I can cut his with it.",
          "Bring me to Tidewatch. I'll be ready.",
        }
      end
      if n >= 2 then
        return {
          "Sergei: Two shards. Faster than I'd hoped.",
          "I built this tower when I was nineteen.",
          "Meant to amplify. To carry songs.",
          "Suno took the schematic and built muzzles.",
          "(...he taps the cracked stone, listens for the hum.)",
          "It still hums faintly. The bones remember.",
        }
      end
      return {
        "Sergei: You found the Old Resonator.",
        "I built it to carry songs across silenced lands.",
        "Suno burned it. Stole the design. Built worse.",
        "I'm here every dawn. Studying the wreckage.",
        "(...unspools cable, doesn't look up.)",
      }
    end,
  },
  -- Hidden NPC: lakeside oracle in the village (sits at the very edge of the lake)
  { x = 3, y = 13, name = "Wina",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      return {
        "(an old woman, watching the lake)",
        "The water remembers every song that was.",
        "Even the ones we never finished singing.",
        n >= 4 and "I hear yours in it now. That's new."
              or  "Sing me one, when you have one to sing.",
      }
    end,
  },
  { x = 6, y = 4, name = "Paj",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      -- Paj joins after Cave 5 (Snowgaunt / Aeolian) is cleared.
      if cave_state[5].cleared and not CONTENT.recruits[2].joined then
        CONTENT.recruits[2].joined = true
        return {
          "The Aeolian Shard. You held it.",
          "I felt the function resolve.",
          "I'm coming with you. Not asking — telling.",
          "(Paj joined the party. Swap her in from MENU > Party.)",
        }
      elseif CONTENT.recruits[2].joined then
        return {
          "I have my notes. I have my coat.",
          "I'm in the roster — switch me in any time.",
          "Two functions still resolve, ours and his.",
        }
      elseif n >= 5 then
        return {
          "Five terms in the equation. Two unknown.",
          "The shape of your trajectory has converged.",
          "Defeat the Snowgaunt and return to me.",
          "I'll join when the Aeolian rings.",
        }
      elseif n >= 2 then
        return {
          "Paj. Math wizard. My family's word, not mine.",
          "I read Tova's older books while she sleeps.",
          "There is a function that solves Suno.",
          "Find me when you're ready to compile.",
        }
      end
      return {
        "Paj. I count the silences between the notes.",
        "Tova lent me her texts. I read fast.",
        "If you find shards, count them carefully.",
        "And please — return to tell me the totals.",
      }
    end,
  },
  -- Pass 26: Pith the cartographer. Quest: clear 3+ caves and report back
  -- for a one-time tonic + 100g reward.
  { x = 22, y = 6, name = "Pith",
    dialogue = function()
      local cleared = 0
      for i = 1, 5 do if cave_state[i].cleared then cleared = cleared + 1 end end
      local q = QUESTS.pith
      if not q.claimed and cleared >= q.target then
        q.claimed = true
        SHOP.gold = SHOP.gold + 100
        SHOP.inv.tonic = (SHOP.inv.tonic or 0) + 1
        return {
          "Pith: Three caves cleared! You've doubled",
          "the data I had on the whole reach.",
          "Take this — bought a Tonic for the trouble,",
          "and a hundred gold. Now go fill in cave four.",
          "(+100g  +1 Tonic)",
        }
      elseif q.claimed then
        return {
          "Pith: Each cave you clear, I redraw a line.",
          "Map's getting busy. Keep me in stories",
          "and I'll keep ink in the well.",
        }
      elseif cleared > 0 then
        return {
          "Pith: " .. cleared .. " of " .. q.target .. " caves logged so far.",
          "Bring me three and I'll draft you a",
          "proper survey — and pay for the trouble.",
        }
      end
      return {
        "Pith: Cartographer. Pith. I draw maps for",
        "a living, but the reach has gone shy lately.",
        "Clear three caves and report back —",
        "I'll fund your next round.",
      }
    end,
  },
  -- Pass 26: Anker the road peddler. Wanders the coast road; gossip + lore
  -- flavor that changes with shard count.
  { x = 52, y = 8, name = "Anker",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      if n >= 5 then
        return {
          "Anker: Five shards, eh? The roads remember",
          "your boots now. Innkeeps the coast over",
          "comp your stew. Don't ask why. Just nod.",
        }
      elseif n >= 2 then
        return {
          "Anker: Two shards in, you say? My grandfather",
          "swore the sea sang seven keys before the",
          "Quiet King. Here's hoping you bring 'em back.",
        }
      end
      return {
        "Anker: Heading east? Tide's in. Heading north?",
        "Bring a coat. Heading west? You're already there.",
        "I sell directions for free; everything else I",
        "swap for gossip. What's the news in the village?",
      }
    end,
  },
  -- Pass 33 flavor NPCs: lake fisherman + village watchwoman.

  -- FERN (lake fisherman) — sits at the end of the lake pier, line in water.
  { x = 11, y = 11, name = "Fern",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      if n >= 5 then
        return {
          "Fern: The fish are noisy again.",
          "I can hear them surface, where I used to",
          "only see the ripples. Sound is back.",
          "(she cups water and lets it drip — listening.)",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "cleric" then
        return {
          "Fern: A cleric. Bless this rod. Just kidding.",
          "...mostly. The trout have been in mourning.",
          "If you bring back the chord, they'll bite again.",
        }
      end
      return {
        "Fern: I cast lines and listen. Mostly listen.",
        "The lake used to gossip. Suno's quiet hit",
        "the water first. Even the reeds went still.",
        "Some days I just sit. Wait for it to thaw.",
      }
    end,
  },

  -- HOLDA (village watchwoman) — stands at the eastern village edge.
  { x = 28, y = 7, name = "Holda",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Holda: Warrior. Your shoulders set wrong.",
          "Captain trained me. Reya. Mountain-rain drills.",
          "(she nods, slow.) Carry her pace east.",
          "You'll find what she pointed you toward.",
        }
      end
      if n >= 3 then
        return {
          "Holda: Three shards in. Whole village sleeps",
          "easier. Mothers stopped triple-locking the doors.",
          "Bring back the rest. I'll keep this corner clean.",
        }
      end
      return {
        "Holda: I watch the east road. Have for ten years.",
        "Suno's silencers came through here twice.",
        "Both times I got my axe ready. Both times,",
        "they passed without looking. (...so far.)",
      }
    end,
  },

  -- Pass 29: Human antagonists. Each appears progressively as a story-gated
  -- NPC keyed on shards-collected. They have unique 8x8 sprites and rich
  -- dialogue that evolves with the player's progress.

  -- IRET — The Diplomat. Suno's silver-tongued envoy. Appears in the village
  -- after the first shard. Tries to talk the party down. (No battle.)
  { x = 15, y = 6, name = "Iret",
    visible = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      return n >= 1
    end,
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lead = party[active] and party[active].class
      if shards.locrian then
        return {
          "Iret: Six shards. We tried, didn't we?",
          "I offered you houses. Coin. Pardon.",
          "You took the road instead.",
          "I'll be at the Tower base when it's done —",
          "to see whether silence finally suits him.",
        }
      end
      if lead == "cleric" then
        return {
          "Iret: Miel. I knew your father.",
          "The match he arranged was an act",
          "of mercy — Suno doesn't kill the wed.",
          "You ran instead. Brave. Stupid. Both.",
          "Come home. The terms still stand.",
        }
      end
      if n >= 4 then
        return {
          "Iret: You're past the bargaining stage.",
          "I'll spare you the offer this round —",
          "you'd only spit it back at me.",
          "Vance grows impatient with this charade.",
          "You'll meet him soon. He doesn't talk.",
        }
      end
      if n >= 2 then
        return {
          "Iret: Two shards in. A respectable first act.",
          "Listen — Suno doesn't want a war. He wants",
          "a quiet world. Lay the chord down. He'll let",
          "your village keep its name. Its fountain.",
          "Its songs at dusk. (...think about it.)",
        }
      end
      return {
        "Iret: Iret of the Quiet Court. I came to",
        "the village in colors, not chains.",
        "The Tuning King doesn't need your sword.",
        "He needs your silence. Sell it to him,",
        "and you'll never want for bread again.",
      }
    end,
  },

  -- VANCE — The Conductor. Suno's enforcer. Appears after 2 shards in the
  -- village plaza, hooded, sword across his back. Cold, brief.
  { x = 24, y = 6, name = "Vance",
    visible = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      return n >= 2
    end,
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lead = party[active] and party[active].class
      if shards.locrian then
        return {
          "Vance: Six. The seventh is mine to defend.",
          "I'll be at the Chamber gate.",
          "Bring the chord whole or don't come at all.",
          "(he turns and walks east without waiting.)",
        }
      end
      if lead == "warrior" then
        return {
          "Vance: Strom. I served under your captain",
          "for two summers. She was — efficient.",
          "She would've taken the offer Iret gave you.",
          "(he watches you for a long moment.)",
          "...maybe she wouldn't have. She liked you.",
        }
      end
      if n >= 4 then
        return {
          "Vance: Four shards. You're inconvenient now.",
          "I'd kill you here, but the King wants",
          "the seventh chord rung in his hall.",
          "Hurry up. I'm bored of this village.",
        }
      end
      return {
        "Vance: I conduct the Quiet Court's affairs.",
        "Iret talks. I do.",
        "Take her offer. She thinks you're charming.",
        "I think you're a mile of bad music",
        "between me and a quiet supper.",
      }
    end,
  },

  -- TESS — Alder's former bandmate, now in Suno's house band. Appears in
  -- Hollow Woods after 3 shards. Conflicted; eventually defects.
  { x = 40, y = 5, name = "Tess",
    visible = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      return n >= 3
    end,
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lead = party[active] and party[active].class
      if shards.locrian and not CONTENT.tess_defected then
        CONTENT.tess_defected = true
        SHOP.gold = SHOP.gold + 150
        SHOP.inv.key = (SHOP.inv.key or 0) + 1
        return {
          "Tess: Alder. I should have left with you.",
          "The Quiet Court isn't quiet inside.",
          "Take this — coin to buy a real ending,",
          "and a key for the chamber's antesanctum.",
          "Bring him down. I'll sing harmony.",
          "(+150g  +1 Key)",
        }
      end
      if CONTENT.tess_defected then
        return {
          "Tess: Listening for the seventh. Still.",
          "When you ring it, I'll know.",
          "I'll be at the inn that night. Stew on me.",
        }
      end
      if lead == "bard" then
        return {
          "Tess: Alder. I almost didn't recognize you.",
          "(she wears the Court's pale livery now.)",
          "I joined his band the year after you left.",
          "It's — not what we played. There's no swing.",
          "There's no rest beats. Just held minor sevenths.",
          "I miss our weeknights. I'm sorry.",
        }
      end
      if n >= 5 then
        return {
          "Tess: I knew Alder before all this.",
          "Tell him — when this is over —",
          "I still have his second lute. Strings rusted.",
          "But I kept it. I always kept it.",
        }
      end
      return {
        "Tess: I shouldn't speak with you. Vance's eyes",
        "are everywhere. (she pretends to gather kindling.)",
        "Three shards in already? You're faster than",
        "the King thought. He's nervous. He doesn't",
        "show it, but the chord — it shakes him.",
      }
    end,
  },

  -- Outdoor village pets (Pass 14): non-essential; pure flavor.
  { x = 8, y = 6, name = "Pim",
    dialogue = function()
      local lines = {
        {"Pim noses your boot, finds it lacking,", "and stalks off with great dignity."},
        {"Pim sits in a sunbeam.", "Pim does not move when you speak."},
        {"Pim chitters at a sparrow on the eaves,", "tail twitching like a metronome."},
      }
      return lines[math.random(#lines)]
    end,
  },
  -- Village kid (Pass 17): runs around the plaza, gives flavor + a gold tip
  { x = 11, y = 9, name = "Tilde",
    dialogue = function()
      if not CONTENT.tilde_paid and SHOP.gold >= 0 then
        CONTENT.tilde_paid = true
        SHOP.gold = SHOP.gold + 5
        return {
          "Tilde: I found a coin in the fountain!",
          "You look like you need it more.",
          "(she presses a sticky 5g into your palm)",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Tilde: Play me a song! Mum says I'll grow",
          "up to be a proper bard if I learn the right",
          "ones early. Teach me the loud one.",
        }
      end
      return {
        "Tilde: Mum says don't talk to the cave folk.",
        "But you don't look cave-folk to me.",
        "You smell like outside. That's good.",
      }
    end,
  },
  -- Wandering minstrel (Pass 17): cycles through fragments of old tunes
  { x = 19, y = 9, name = "Eos",
    dialogue = function()
      local fragments = {
        {
          "Eos: (...strums a chord and lets it ring...)",
          "I knew this tune before the Quiet King.",
          "I knew it. I cannot remember the words.",
        },
        {
          "Eos: A coin? You needn't. I sing for the",
          "echo. The walls remember more than I do.",
          "(...he plays a falling fourth, twice...)",
        },
        {
          "Eos: My teacher said: every silence is",
          "a note Suno bought from us.",
          "Today we steal a few back. Listen —",
          "(...one bar of an old, half-shy melody...)",
        },
      }
      CONTENT.eos_idx = ((CONTENT.eos_idx or 0) % #fragments) + 1
      return fragments[CONTENT.eos_idx]
    end,
  },
  { x = 10, y = 6, name = "Bonk",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Bonk wags so hard he nearly tips.",
          "He recognizes a friendly hammer-arm",
          "when he sees one.",
        }
      end
      return {
        "Bonk drops a dirt-streaked pebble at",
        "your feet. The Look in his eye says",
        "you must throw it. The Pebble Demands.",
      }
    end,
  },
}

-- Eastern Reaches NPCs
local EASTERN_NPCS = {
  -- Pass 21: Harbormaster of the Reaches' little port-town. Sela handles
  -- ferry rumors and Eastern flavor. Lives near the boat landing.
  { x = 6, y = 9, name = "Sela",
    dialogue = function()
      local lead = party[active] and party[active].class
      if shards.mixolydian then
        return {
          "Sela: Word came on the gull-wind: the",
          "Dune Rider rides no more. Strangers used",
          "to vanish in his hooves' echo. No more.",
          "Drink at the inn — first round's mine.",
        }
      end
      if lead == "engineer" then
        return {
          "Sela: An engineer? Take a look at the dock",
          "boards before you walk west, would you?",
          "Salt's chewing them faster than I can mend.",
        }
      end
      return {
        "Sela: Welcome to the Reaches. Inn's east of",
        "the dock; Hens keeps a stall just past it.",
        "Don't wander to cave four 'til your boots dry.",
      }
    end,
  },
  -- Hidden: a wanderer in the dunes who hums fragments of forgotten songs
  { x = 12, y = 5, name = "Karoo",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local lyrics = {
        {"oh— oh— the dune was the chord—", "and the chord was a— a—",
         "...I forget. Sorry. Try me again later."},
        {"hm hm. The line — it had a leap in it.",
         "A fifth or a fourth, the kind that surprises you.",
         "I'll remember when I'm not trying."},
        {"In the village they sang it on Lydian feasts.",
         "Or — was it Phrygian. Or both, alternating.",
         "Songs were so much more flexible then."},
      }
      return lyrics[(n % #lyrics) + 1]
    end,
  },
  { x = 14, y = 7, name = "Mira",
    dialogue = function()
      if shards.phrygian then
        return {
          "The Phrygian song wakes!",
          "The dunes have remembered.",
          "Four shards. Four to go.",
          "Press west, then south.",
          "Suno's tower will not stand.",
        }
      end
      return {
        "I am Mira, of the Eastern dunes.",
        "You crossed the sea — well met.",
        "The Phrygian Shard sleeps east,",
        "in the deep cavern of glass.",
        "The Dune Rider prowls within.",
        "Old. Patient. Hungry.",
      }
    end,
  },
}

-- Northern Wilds NPCs
local NORTHERN_NPCS = {
  -- Pass 26: pilgrim child wandering the snow road. Wisp warms her hands
  -- by passersby; flavor + a subtle gold tip on first encounter.
  { x = 18, y = 12, name = "WispGirl",
    dialogue = function()
      if not CONTENT.wisp_paid then
        CONTENT.wisp_paid = true
        SHOP.gold = SHOP.gold + 8
        return {
          "Wisp: Mam said share with travelers.",
          "Here. Don't argue. (she presses 8g into",
          "your glove and runs back to her cairn.)",
          "(+8g)",
        }
      end
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      if n >= 4 then
        return {
          "Wisp: I made a song for you! It goes —",
          "(she hums four uncertain notes,",
          "stops, and looks pleased with herself.)",
        }
      end
      return {
        "Wisp: I'm walking to the Snowgaunt's old door,",
        "to leave a candle. Mam used to.",
        "She says quiet places need bright friends.",
      }
    end,
  },
  -- Pass 23: mountain guide tending the small north-pass town. Bracken
  -- handles directions, weather warnings, and Snowgaunt rumors.
  { x = 7, y = 12, name = "Bracken",
    dialogue = function()
      local lead = party[active] and party[active].class
      if shards.aeolian then
        return {
          "Bracken: Wind's clean again. Smell that?",
          "No more keening. Snowgaunt's done.",
          "Inn's hot stew tonight, on the house.",
        }
      end
      if lead == "cleric" then
        return {
          "Bracken: A cleric. Good. The Snowgaunt's",
          "song catches in your chest. Bring warm",
          "thoughts and warmer prayers.",
        }
      end
      if cave_state[5].victories >= 1 then
        return {
          "Bracken: You've heard the waltz, then.",
          "Three-time. Always three-time. Don't",
          "let it pull you into its meter.",
        }
      end
      return {
        "Bracken: First time up the pass? Inn's",
        "behind me; Hens keeps a stall beside it.",
        "Cave 5 is east. Don't go without a Vial.",
      }
    end,
  },
  -- Hidden: silent figure near the cave who only speaks once you hold Aeolian
  { x = 16, y = 6, name = "Snow",
    dialogue = function()
      if shards.aeolian then
        return {
          "(turns slowly, snow falling from her shoulders)",
          "You bring back what we never asked you to.",
          "We thought silence was peace.",
          "Thank you. Truly. We were wrong.",
        }
      end
      return {
        "(she does not turn. The snow falls.)",
        "...",
      }
    end,
  },
  { x = 8, y = 8, name = "Iolen",
    dialogue = function()
      if shards.aeolian then
        return {
          "The Aeolian air sings again.",
          "I'd long forgotten its color.",
          "The Snowgaunt waltzes no more.",
          "Bless your strange travelers' luck.",
        }
      end
      return {
        "Iolen, last of the highland watch.",
        "Cave above holds the Aeolian Shard.",
        "Snowgaunt sleeps within — tall, slow,",
        "and very tired of being awake.",
        "Step lightly. The cold listens.",
      }
    end,
  },
}

-- Suno's Domain: a small chorus of haunted attendants (added Pass 11).
local SUNOS_NPCS = {
  { x = 4, y = 4, name = "Lyssa",
    dialogue = function()
      if shards.ionian then
        return {
          "He sings no more, the Tuning King.",
          "I hear my own voice for the first",
          "time in years. It is small. It is mine.",
        }
      end
      return {
        "I tended his lanterns. I knew nothing.",
        "He told us silence was a kind of song.",
        "I no longer believe him.",
      }
    end,
  },
  { x = 21, y = 4, name = "Calder",
    dialogue = function()
      if shards.locrian then
        return {
          "Locrius held the door for centuries.",
          "Strange to mourn a thing that hated us.",
          "He believed in his master to the end.",
        }
      end
      return {
        "Past me lies Locrius. The Half-step.",
        "Do not strike him in time — strike",
        "him out of it. He cannot follow swing.",
      }
    end,
  },
  { x = 12, y = 11, name = "Maren",
    dialogue = function()
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Bard. He took my voice. He took the lute",
          "from my mother's hands. We owe him no",
          "elegy. Strike clean. Sing a true note.",
        }
      end
      if shards.ionian then
        return {
          "It is over. I will not say I forgive him.",
          "But I will sing again. The first song",
          "shall be quiet. The second, less so.",
        }
      end
      return {
        "Beyond that gate lies the Quiet King.",
        "He fears the seventh more than any sword.",
        "Sing the chord whole and watch him fall.",
      }
    end,
  },
}

-- Inn interior NPCs (map id 5). Innkeeper handles the rest action.
CONTENT.inn_npcs = {
  { x = 3, y = 3, name = "Mara",
    dialogue = function()
      -- Heal full HP/MP, revive KO'd, brief 3-note rest chord.
      for _, p in ipairs(party) do
        p.hp = p.hp_max; p.mp = p.mp_max; p.alive = true
      end
      inn_rest_ticks = 36
      local sc = JAM.scales[JAM.mode] or JAM.scales.pentatonic
      for k, idx in ipairs({1, 4, 8}) do
        local pitch = (sc[idx] or 60) + (JAM.root or 0)
        clock.run(function()
          clock.sleep((k - 1) * 0.15)
          engine.trig_cleric(midi_to_freq(pitch), 0.45, 0.05, 1.5, 0.85)
        end)
      end
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Mara: Sit a moment. You look like",
          "you've been swinging that thing all day.",
          "...Better. The room's yours till dawn.",
          "(party fully restored)",
        }
      elseif lead == "cleric" then
        return {
          "Mara: My grandmother served Miel's order.",
          "Three hot meals and a quiet bed —",
          "tradition, not charity.",
          "(party fully restored)",
        }
      end
      return {
        "Mara: Rest a while. The road outside",
        "has been louder than usual lately.",
        "(party fully restored)",
      }
    end,
  },
  { x = 9, y = 6, name = "Pell",
    dialogue = function()
      -- Tale-spinner: rotates through old-world lore tidbits.
      local lore = {
        {
          "Pell: Long before the Tuning King,",
          "the seven shards were stones in a wall.",
          "A wall around a city no map remembers.",
        },
        {
          "Pell: Strom's hammer was a tuning fork once.",
          "Now it tunes skulls. Funny how things",
          "find new uses, no?",
        },
        {
          "Pell: The fountain in the plaza? Listen",
          "close. The water hums in F sharp.",
          "It has done so since I was a boy.",
        },
        {
          "Pell: They say Suno was a child once.",
          "A small voice in a small choir.",
          "Power changes the throat, child.",
        },
      }
      CONTENT.pell_idx = ((CONTENT.pell_idx or 0) % #lore) + 1
      return lore[CONTENT.pell_idx]
    end,
  },
  { x = 7, y = 5, name = "Mews",
    dialogue = function()
      local lines = {
        {"Mews curls tighter on the rug.", "(...purrs...)"},
        {"Mews opens one eye, sees you, closes it.", "(...purrs...)"},
        {"Mews stretches, considers you,", "decides you are not worth standing for."},
      }
      return lines[math.random(#lines)]
    end,
  },
}

-- Shop interior NPCs (map id 6). Hens runs the shop here; talking to her
-- opens the SHOP UI on dialogue exit (advance_dialogue checks for "Hens").
CONTENT.shop_npcs = {
  { x = 6, y = 3, name = "Hens",
    dialogue = function()
      -- Same SIDEQUEST + tier copy as the original plaza Hens, slightly
      -- reworded for the indoor setting.
      local q = QUESTS.hens
      if q.wins >= q.target and not q.discount then
        q.discount = true
        return {
          "Five clean wins on the road, eh?",
          "Word travels. Coin follows word.",
          "I'll knock 25% off everything.",
          "Permanent. Don't tell the elder.",
        }
      elseif q.discount then
        return {
          "Step right up — 25% off, as promised.",
          "Buy more, the chest empties faster,",
          "and faster I restock the goods.",
        }
      elseif q.wins > 0 then
        return {
          "Heard you've won " .. q.wins .. "/" .. q.target .. " road fights.",
          "Survive 5 random scuffles total",
          "and I'll cut a discount for life.",
        }
      end
      if shards.dorian then
        return {
          "Two shards already? Brisk work.",
          "My stock won't keep up at this rate.",
          "Pull up — I'll see what I've got.",
          "(Quest: 5 random-encounter wins → 25% off.)",
        }
      end
      return {
        "Welcome to my shop, traveler.",
        "Strings, reeds, rosin, lantern oil.",
        "Survive five road fights for me",
        "and I'll cut you a discount for life.",
        "(Quest: 5 random-encounter wins.)",
      }
    end,
  },
  { x = 3, y = 5, name = "Rook",
    dialogue = function()
      local lines = {
        {"Rook wags. He sniffs your boots", "and decides you are acceptable."},
        {"Rook drops a chewed wooden coin", "at your feet. Generous of him."},
        {"Rook rolls onto his back, paws up.", "(...he wants belly scritches...)"},
      }
      return lines[math.random(#lines)]
    end,
  },
}

-- Cave 1 interior NPCs. Hollin is a lost caver; the dialogue evolves with progress.
CONTENT.cave1_npcs = {
  { x = 2, y = 8, name = "Hollin",
    dialogue = function()
      if cave_state[1].cleared then
        return {
          "Hollin: The echoes are gone. Just",
          "rocks now. Honest, common rocks.",
          "I'd forgotten how quiet quiet was.",
          "(she leans against the wall, smiling)",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "Hollin: A scholar! Good — I'm out",
          "of my depth. There's a Voice here",
          "that finishes my sentences. Not",
          "kindly. North chamber. Be ready.",
        }
      end
      if cave_state[1].victories >= 2 then
        return {
          "Hollin: You've fought it. I heard",
          "the chord. The Voice rang back",
          "in three keys at once.",
          "The arena's north. It's tired.",
        }
      end
      return {
        "Hollin: Don't go north yet. The",
        "Voice waits there. It echoes you",
        "before you speak. It learns the",
        "song before you sing it.",
      }
    end,
  },
}

-- Cave 2 interior NPCs. Beren is a half-feral hermit who lives in the grove.
CONTENT.cave2_npcs = {
  { x = 2, y = 8, name = "Beren",
    dialogue = function()
      if cave_state[2].cleared then
        return {
          "Beren: The Sentinel sleeps for good now.",
          "Listen — birds again. They'd been quiet",
          "as long as I'd been here. (years.)",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "warrior" then
        return {
          "Beren: A swordhand! Good. The Sentinel",
          "won't be reasoned with. It only knows",
          "the language of broken things.",
        }
      end
      if cave_state[2].victories >= 2 then
        return {
          "Beren: You've cracked some bark off it.",
          "Sap runs slow but it runs. Push on.",
          "The arena is the open ring east of here.",
        }
      end
      return {
        "Beren: I came in for mushrooms. That was",
        "summer. Three summers ago. The Sentinel",
        "watches what comes in, not what leaves.",
      }
    end,
  },
}

-- Cave 3 interior NPCs. The Drowned (Mara's older cousin? — no, distinct) is
-- a half-translucent fisherman who haunts the grotto.
CONTENT.cave3_npcs = {
  { x = 2, y = 8, name = "Anwell",
    dialogue = function()
      if cave_state[3].cleared then
        return {
          "Anwell: The Tidewatch held my crew below",
          "for forty years. The water remembers them",
          "kinder, now that the watcher is silent.",
          "(he begins to fade — gently, this time.)",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "cleric" then
        return {
          "Anwell: A cleric's prayer might unspool me",
          "when the Tidewatch falls. I'd be grateful.",
          "Strike for the seventh wave — it's the loud one.",
        }
      end
      return {
        "Anwell: (his voice arrives a half-breath",
        "after his lips move.) Don't trust the still",
        "pools. The Tidewatch keeps a face in each.",
      }
    end,
  },
}

-- Cave 4 (Dune Rider) interior NPCs. A salt-skinned guide who refused to leave.
CONTENT.cave4_npcs = {
  { x = 2, y = 8, name = "Iska",
    dialogue = function()
      if cave_state[4].cleared then
        return {
          "Iska: The Rider's hooves don't echo here",
          "anymore. I'd been counting them in my sleep.",
          "Tonight I might finally rest.",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "engineer" then
        return {
          "Iska: An engineer? Good. The Dune Rider",
          "moves with a pattern — six beats out, two",
          "back. Cut him on the rest. Promise me.",
        }
      end
      return {
        "Iska: Sand carries every footstep miles.",
        "He hears you coming. He always does.",
        "Strike on the pattern, not the silence.",
      }
    end,
  },
}

-- Cave 5 (Snowgaunt) interior NPCs. A frostbitten singer trapped by the cold.
CONTENT.cave5_npcs = {
  { x = 2, y = 8, name = "Wenna",
    dialogue = function()
      if cave_state[5].cleared then
        return {
          "Wenna: Oh — the cold's gone.",
          "Just regular cold. Plain, kind cold.",
          "I'll walk out before the moon rises.",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "bard" then
        return {
          "Wenna: A bard! Sing in three. Always",
          "three. The Snowgaunt's waltz can't",
          "tolerate other meters. Drown his time",
          "with yours.",
        }
      end
      if cave_state[5].victories >= 3 then
        return {
          "Wenna: He's slowing. The waltz",
          "skips a beat now. North chamber.",
          "Don't let him finish a phrase.",
        }
      end
      return {
        "Wenna: I came in to bury a friend.",
        "The Snowgaunt sings him back every",
        "midnight. I can't stop hearing it.",
      }
    end,
  },
}

-- Cave 6 (Locrian Crypt) NPC. Vessel is a former Suno acolyte, broken,
-- waiting in the antechamber to be undone with the Half-step.
CONTENT.cave6_npcs = {
  { x = 2, y = 8, name = "Vessel",
    dialogue = function()
      if cave_state[6].cleared then
        return {
          "Vessel: Locrius is gone. The unstable",
          "interval — resolved at last. I can hear",
          "the major third again. I had forgotten",
          "what comfort that note carries.",
        }
      end
      local lead = party[active] and party[active].class
      if lead == "mage" then
        return {
          "Vessel: A scholar. Good. Locrius bargains",
          "in tritones; he lives in the gap between",
          "perfect and broken. Strike him on the",
          "weak beat. He cannot answer ambiguity.",
        }
      end
      return {
        "Vessel: I served at his pulpit. I sang the",
        "Half-step every dawn for forty years.",
        "I am ready to be unmade. End him quickly.",
      }
    end,
  },
}

-- The Hollow side-dungeon NPCs. Sett (treasure hunter) up front; Niko
-- (third hidden recruit, drummer) deep in the back-right.
CONTENT.hollow_npcs = {
  -- Niko (drummer): joins the party after collecting 4+ shards. Deep in
  -- the back of The Hollow — easy to miss without exploring.
  { x = 10, y = 2, name = "Niko",
    dialogue = function()
      local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
      local r = CONTENT.recruits[3]
      if r.joined then
        return {
          "Niko: Aye — keep swinging out there.",
          "I'll keep the count solid back home.",
          "(Niko: ready in the Party menu.)",
        }
      end
      if n < 4 then
        return {
          "Niko: (a soft brushed cymbal in the dark)",
          "Niko: Four shards and we'll talk.",
          "I don't drum for amateurs. No offense.",
          "Bring the chord most of the way home —",
          "then come find me here. I'll join.",
        }
      end
      r.joined = true
      return {
        "Niko: Four shards. That's enough chord",
        "for me to lock onto. I've been waiting",
        "for a band worth keeping time for.",
        "(Niko joins your reserve — swap from the",
        "Party menu.)",
      }
    end,
  },
  { x = 2, y = 7, name = "Sett",
    dialogue = function()
      if CONTENT.opened["ch_hollow_end"] then
        return {
          "Sett: You popped the back stash! Knew",
          "you were the type. Drink's on me next",
          "time you swing through the village.",
        }
      end
      if SHOP.inv.key and SHOP.inv.key > 0 then
        return {
          "Sett: A Key in your pocket? Then you're",
          "set. The big chest's at the back of the",
          "Hollow. Don't share with the woods folk.",
        }
      end
      return {
        "Sett: I followed a rumor in here. There's",
        "a chest at the back, locked tight. Bring",
        "a Key from the village shop and we split",
        "the take. Or take it all — I'm not picky.",
      }
    end,
  },
}

local npcs = MAINLAND_NPCS  -- active NPC list (mutable; swaps on travel_to)

-- ============================================================ HELPERS

local function midi_to_freq(n)
  return 440 * 2 ^ ((n - 69) / 12)
end

local function tile_at(tx, ty)
  if tx < 1 or tx > MAP_W or ty < 1 or ty > MAP_H then return 1 end
  return map[ty][tx]
end

local function is_walkable(tx, ty)
  local t = tile_at(tx, ty)
  -- 0 grass/floor, 2 path, 5 door, 23 rug (interior), 45 pier (over water)
  return t == 0 or t == 2 or t == 5 or t == 23 or t == 45
end

-- True when an NPC is currently rendered + interactable. NPCs may have
-- a `visible` function that returns false to hide them (e.g. story-gated
-- antagonists who only show up after a specific milestone).
local function npc_visible(n)
  return (type(n.visible) ~= "function") or n.visible()
end

local function npc_at(tx, ty)
  for _, n in ipairs(npcs) do
    if n.x == tx and n.y == ty and npc_visible(n) then return n end
  end
  return nil
end

local function alive_party()
  local out = {}
  for i, p in ipairs(party) do if p.alive then table.insert(out, i) end end
  return out
end

local function count_shards()
  local n = 0
  for _, has in pairs(shards) do if has then n = n + 1 end end
  return n
end

-- forward-decl so obtain_shard can auto-save when a shard is gained
local save_game

local function obtain_shard(name)
  if shards[name] then return end
  shards[name] = true
  last_obtained_shard = name
  -- auto-save on every shard collection (story milestone)
  if save_game then save_game() end
  -- Mode-specific 4-note "shard sting": play a quick chord/arpeggio in the
  -- mode's scale to musically announce which shard you just earned.
  local sc = JAM.scales[name] or JAM.scales.pentatonic
  -- pick chord tones (1 / 3 / 5 / 8) from the scale array
  local idxs = {1, 3, 5, 8}
  for k, idx in ipairs(idxs) do
    local pitch = (sc[idx] or 60) + (JAM.root or 0)
    local f = midi_to_freq(pitch)
    -- stagger notes by a small clock.run so they arpeggiate quickly
    clock.run(function()
      clock.sleep((k - 1) * 0.08)
      engine.trig_mage(f, 0.65, 0.005, 0.8, 0.7)
      engine.trig_bard(f * 2, 0.5, 0.003, 0.5, 0.6)
    end)
  end
end

-- adjust tempo settings; immediately apply if relevant state is active
local function adjust_battle_bpm(delta)
  BATTLE_BPM = math.max(BPM_MIN, math.min(BPM_MAX, BATTLE_BPM + delta))
  if game_state == "BATTLE" then params:set("clock_tempo", BATTLE_BPM) end
end

local function adjust_journey_bpm(delta)
  OVERWORLD_BPM = math.max(BPM_MIN, math.min(BPM_MAX, OVERWORLD_BPM + delta))
  if game_state ~= "BATTLE" then params:set("clock_tempo", OVERWORLD_BPM) end
end

-- ============================================================ SAVE / LOAD

-- Single save file (Pass 49 multi-slot reverted Pass 54).
local function SAVE_PATH()
  return _path.data .. "synth-quest/save.data"
end
local update_camera   -- forward decl (defined later in OVERWORLD section)
local travel_to       -- forward decl (defined later)

save_game = function()
  os.execute("mkdir -p " .. _path.data .. "synth-quest/")
  local data = {
    player = {x=player.x, y=player.y, facing=player.facing},
    party = {},
    shards = shards,
    cave_state = cave_state,
    current_map_id = current_map_id,
  }
  for i, p in ipairs(party) do
    data.party[i] = {
      hp = p.hp, mp = p.mp, alive = p.alive, queued = p.queued,
      level = p.level, xp = p.xp, xp_total = p.xp_total,
      hp_max = p.hp_max, mp_max = p.mp_max,
      atk = p.atk, def = p.def, mag = p.mag, spd = p.spd,
    }
  end
  data.battle_bpm = BATTLE_BPM
  data.journey_bpm = OVERWORLD_BPM
  -- equipment: list of owned ids + map of class→equipped id
  local owned_list = {}
  for id, _ in pairs(instruments_owned) do owned_list[#owned_list+1] = id end
  data.instruments_owned = owned_list
  data.equipped = {}
  for cls, id in pairs(equipped) do data.equipped[cls] = id end
  -- economy
  data.gold = SHOP.gold
  data.inv = {salve = SHOP.inv.salve, vial = SHOP.inv.vial, star = SHOP.inv.star,
              ether = SHOP.inv.ether, tonic = SHOP.inv.tonic, key = SHOP.inv.key}
  -- sidequests
  data.quests = {
    hens = {wins = QUESTS.hens.wins, discount = QUESTS.hens.discount},
    brann = {wins = QUESTS.brann.wins, claimed = QUESTS.brann.claimed},
    tova = {spoke = {}, claimed = QUESTS.tova.claimed},
    pith = {claimed = QUESTS.pith.claimed},
  }
  for k, v in pairs(QUESTS.tova.spoke) do data.quests.tova.spoke[k] = v end
  -- party-story scenes seen
  data.story_seen = {}
  for k, v in pairs(STORY.seen) do data.story_seen[k] = v end
  -- jam settings (root key offset + active mode)
  data.jam_root = JAM.root
  data.jam_mode = JAM.mode
  -- bestiary
  data.bestiary = {}
  for k, v in pairs(CONTENT.bestiary) do data.bestiary[k] = v end
  -- chests
  data.chests_opened = {}
  for k, v in pairs(CONTENT.opened) do data.chests_opened[k] = v end
  -- recruits joined-flags + Sergei intervention one-shot
  data.recruits_joined = {CONTENT.recruits[1].joined, CONTENT.recruits[2].joined,
                          CONTENT.recruits[3] and CONTENT.recruits[3].joined or false}
  -- Pass 52: persist unlocked achievements.
  data.achievements = {}
  for k, v in pairs(CONTENT.achievements or {}) do data.achievements[k] = v end
  data.sergei_intervened = CONTENT.sergei_intervened
  tab.save(data, SAVE_PATH())
  save_flash_ticks = 24
  save_flash_text = "Game Saved"
end

local function load_game()
  local data = tab.load(SAVE_PATH())
  if not data then
    save_flash_ticks = 24
    save_flash_text = "No save found"
    return false
  end
  player.x = data.player.x
  player.y = data.player.y
  player.facing = data.player.facing
  for i, sp in ipairs(data.party) do
    if party[i] then
      party[i].hp = sp.hp
      party[i].mp = sp.mp
      party[i].alive = sp.alive
      party[i].queued = sp.queued
      if sp.level then party[i].level = sp.level end
      if sp.xp then party[i].xp = sp.xp end
      if sp.xp_total then party[i].xp_total = sp.xp_total end
      if sp.hp_max then party[i].hp_max = sp.hp_max end
      if sp.mp_max then party[i].mp_max = sp.mp_max end
      if sp.atk then party[i].atk = sp.atk end
      if sp.def then party[i].def = sp.def end
      if sp.mag then party[i].mag = sp.mag end
      if sp.spd then party[i].spd = sp.spd end
    end
  end
  for k, v in pairs(data.shards or {}) do shards[k] = v end
  if data.cave_state then
    for i, st in pairs(data.cave_state) do
      if cave_state[i] then
        cave_state[i].victories = st.victories or 0
        cave_state[i].cleared   = st.cleared or false
      end
    end
  end
  if data.current_map_id and data.current_map_id ~= current_map_id then
    travel_to(data.current_map_id, player.x, player.y)
  end
  if data.battle_bpm then BATTLE_BPM = data.battle_bpm end
  if data.journey_bpm then OVERWORLD_BPM = data.journey_bpm end
  -- equipment (gracefully no-op for older saves; migrate cleric instrument names)
  local INST_MIGRATE = {prayer_bell = "pilgrim_lyre", silver_censer = "silver_lyre", hymnal = "sacred_lyre",
                        hollow_drum = "aeolian_lute"}
  if data.instruments_owned then
    instruments_owned = {}
    for _, id in ipairs(data.instruments_owned) do
      id = INST_MIGRATE[id] or id
      if INSTRUMENTS[id] then instruments_owned[id] = true end
    end
  end
  if data.equipped then
    for cls, id in pairs(data.equipped) do
      id = INST_MIGRATE[id] or id
      if INSTRUMENTS[id] then equipped[cls] = id end
    end
  end
  if data.gold then SHOP.gold = data.gold end
  if data.quests then
    if data.quests.hens then
      QUESTS.hens.wins = data.quests.hens.wins or 0
      QUESTS.hens.discount = data.quests.hens.discount or false
    end
    if data.quests.brann then
      QUESTS.brann.wins = data.quests.brann.wins or 0
      QUESTS.brann.claimed = data.quests.brann.claimed or false
    end
    if data.quests.tova then
      QUESTS.tova.claimed = data.quests.tova.claimed or false
      QUESTS.tova.spoke = {}
      for k, v in pairs(data.quests.tova.spoke or {}) do QUESTS.tova.spoke[k] = v end
    end
    if data.quests.pith then
      QUESTS.pith.claimed = data.quests.pith.claimed or false
    end
  end
  if data.story_seen then
    STORY.seen = {}
    for k, v in pairs(data.story_seen) do STORY.seen[k] = v end
  end
  if data.jam_root then JAM.root = data.jam_root end
  if data.jam_mode and JAM.scales[data.jam_mode] then JAM.mode = data.jam_mode end
  if data.bestiary then
    CONTENT.bestiary = {}
    for k, v in pairs(data.bestiary) do CONTENT.bestiary[k] = v end
  end
  if data.chests_opened then
    CONTENT.opened = {}
    for k, v in pairs(data.chests_opened) do CONTENT.opened[k] = v end
  end
  if data.recruits_joined then
    if CONTENT.recruits[1] then CONTENT.recruits[1].joined = data.recruits_joined[1] or false end
    if CONTENT.recruits[2] then CONTENT.recruits[2].joined = data.recruits_joined[2] or false end
    if CONTENT.recruits[3] then CONTENT.recruits[3].joined = data.recruits_joined[3] or false end
  end
  if data.achievements then
    CONTENT.achievements = {}
    for k, v in pairs(data.achievements) do CONTENT.achievements[k] = v end
  end
  if data.sergei_intervened ~= nil then CONTENT.sergei_intervened = data.sergei_intervened end
  if data.inv then
    SHOP.inv.salve = data.inv.salve or 0
    SHOP.inv.vial  = data.inv.vial or 0
    SHOP.inv.star  = data.inv.star or 0
    SHOP.inv.ether = data.inv.ether or 0
    SHOP.inv.tonic = data.inv.tonic or 0
    SHOP.inv.key   = data.inv.key or 0
  end
  -- apply current tempo for the active state
  if game_state == "BATTLE" then
    params:set("clock_tempo", BATTLE_BPM)
  else
    params:set("clock_tempo", OVERWORLD_BPM)
  end
  update_camera()
  save_flash_ticks = 24
  save_flash_text = "Game Loaded"
  return true
end

-- ============================================================ PARTY

local function init_party()
  party = {}
  for i, t in ipairs(PARTY_TEMPLATE) do
    party[i] = {
      class=t.class, spd=t.spd, atb=0, queued=DEFAULT_QUEUED[i],
      note_idx=t.note_idx, note_lo=t.note_lo, note_hi=t.note_hi,
      cutoff=t.cutoff, resonance=t.resonance,
      hp=t.hp_max, hp_max=t.hp_max, mp=t.mp_max, mp_max=t.mp_max,
      atk=t.atk, def=t.def, mag=t.mag,
      level=1, xp=0, xp_total=0,
      alive=true, shield=false, buffed=false, blocking=false,
      last_fire=-99, last_hit=-99,
      -- per-voice latched stick state: each character remembers their own
      -- effect-stick positions so switching voices doesn't reset their effects.
      stick={lx=0, ly=0, rx=0, ry=0},
      xwet=0, dly=0,
    }
  end
  active = 1
  -- starter instruments
  instruments_owned = {}
  equipped = {}
  for _, p in ipairs(party) do
    local id = STARTER_INSTRUMENT[p.class]
    if id then
      instruments_owned[id] = true
      equipped[p.class] = id
    end
  end
end

-- shared XP gain on enemy defeat. Each party member accumulates XP toward
-- their own next-level threshold and levels up via the CLASS_GROWTH table.
-- p.xp is *progress toward next level*; p.xp_total is lifetime XP earned.
local function gain_xp(amount)
  for _, p in ipairs(party) do
    if not p.alive then goto continue end
    p.xp = (p.xp or 0) + amount
    p.xp_total = (p.xp_total or 0) + amount
    while p.level < LEVEL_CAP and p.xp >= xp_for_level(p.level) do
      p.xp = p.xp - xp_for_level(p.level)
      p.level = p.level + 1
      local g = CLASS_GROWTH[p.class] or {hp=4, mp=2, atk=1, def=1, mag=1, spd_every=6}
      p.hp_max = p.hp_max + g.hp
      p.mp_max = p.mp_max + g.mp
      p.atk    = p.atk    + g.atk
      p.def    = p.def    + g.def
      p.mag    = p.mag    + g.mag
      if g.spd_every and (p.level % g.spd_every) == 0 then
        p.spd = (p.spd or 1) + 1
      end
      p.hp = p.hp_max
      p.mp = p.mp_max
      p.last_hit = tick
      levelup_flash_ticks = 32
      levelup_flash_who = CHAR_NAME[p.class] .. " Lv." .. p.level
      -- Triumphant 3-note rising chord: I → V → I' on the bard voice
      local sc = JAM.scales[JAM.mode] or JAM.scales.pentatonic
      for k, idx in ipairs({1, 3, 5}) do
        local pitch = (sc[idx + 12] or sc[idx]) + (JAM.root or 0)
        clock.run(function()
          clock.sleep((k - 1) * 0.06)
          engine.trig_bard(midi_to_freq(pitch), 0.7, 0.003, 0.5, 0.6)
        end)
      end
    end
    if p.level >= LEVEL_CAP then p.xp = 0 end
    ::continue::
  end
end

local function reset_party_for_battle()
  for _, p in ipairs(party) do
    p.atb = 0
    p.shield = false
    p.buffed = false
    p.blocking = false
    p.last_fire = -99
    p.last_hit = -99
    if not p.alive then
      p.alive = true
      p.hp = math.max(1, math.floor(p.hp_max * 0.25))
    end
  end
end

-- ============================================================ OVERWORLD MUSIC

-- which region's theme is currently playing — used to detect transitions
local current_theme = "village"

local function active_theme_id()
  if current_map_id == 2 then return "eastern" end
  if current_map_id == 3 then return "northern" end
  if current_map_id == 4 then return "tower" end
  -- Pass 25: interior themes (inn, shop, each cave, side dungeon).
  if current_map_id == 5 then return "inn" end
  if current_map_id == 6 then return "shop" end
  if current_map_id == 7 then return "echoes" end
  if current_map_id == 8 then return "grove" end
  if current_map_id == 9 then return "grotto" end
  if current_map_id == 10 then return "dune" end
  if current_map_id == 11 then return "frost" end
  if current_map_id == 12 then return "hollow" end
  if current_map_id == 13 then return "crypt" end
  if current_map_id == 14 then return "chamber" end
  local r = get_region(player.x)
  if r == "village" then return "village"
  elseif r == "woods" then return "woods"
  else return "coast"
  end
end

local function fire_ow_voice(class, scale_idx, artic_override)
  if not scale_idx or scale_idx == 0 then return end
  local note = active_scale()[scale_idx] + JAM.root
  if not note then return end
  local freq = midi_to_freq(note)
  local base = OW_ARTIC[class]
  local ovr = artic_override and artic_override[class]
  local vel    = (ovr and ovr.vel)     or base.vel
  local atk    = (ovr and ovr.attack)  or base.attack
  local rel    = (ovr and ovr.release) or base.release
  local wet    = (ovr and ovr.wet)     or base.wet
  engine["trig_" .. class](freq, vel, atk, rel, wet)
end

local function tick_overworld_music()
  -- detect region transition → restart theme cleanly at step 1
  local id = active_theme_id()
  if id ~= current_theme then
    current_theme = id
    overworld_step = 0
  end
  local theme = OW_THEMES[current_theme] or OW_THEMES.village
  overworld_step = (overworld_step % OW_PATTERN_LEN) + 1
  for class, pat in pairs(theme.pattern) do
    fire_ow_voice(class, pat[overworld_step], theme.artic)
  end
end

local function fire_title_voice(class, scale_idx)
  if not scale_idx or scale_idx == 0 then return end
  local note = active_scale()[scale_idx] + JAM.root
  if not note then return end
  local freq = midi_to_freq(note)
  local a = TITLE_ARTIC[class]
  engine["trig_" .. class](freq, a.vel, a.attack, a.release, a.wet)
end

local function tick_title_music()
  title_step = (title_step % TITLE_PATTERN_LEN) + 1
  for class, pat in pairs(TITLE_PATTERN) do
    fire_title_voice(class, pat[title_step])
  end
end

local function fire_intro_voice(class, scale_idx)
  if not scale_idx or scale_idx == 0 then return end
  local note = active_scale()[scale_idx] + JAM.root
  if not note then return end
  local freq = midi_to_freq(note)
  local a = INTRO_ARTIC[class]
  engine["trig_" .. class](freq, a.vel, a.attack, a.release, a.wet)
end

local function tick_intro_music()
  intro_step = (intro_step % INTRO_PATTERN_LEN) + 1
  for class, pat in pairs(INTRO_PATTERN) do
    fire_intro_voice(class, pat[intro_step])
  end
end

local function fire_victory_voice(class, scale_idx)
  if not scale_idx or scale_idx == 0 then return end
  local note = active_scale()[scale_idx] + JAM.root
  if not note then return end
  local freq = midi_to_freq(note)
  local a = VICTORY_ARTIC[class]
  engine["trig_" .. class](freq, a.vel, a.attack, a.release, a.wet)
end

local function tick_victory_music()
  victory_step = victory_step + 1
  if victory_step > VICTORY_PATTERN_LEN then return end
  for class, pat in pairs(VICTORY_PATTERN) do
    fire_victory_voice(class, pat[victory_step])
  end
end

-- ── SHOP THEME ────────────────────────────────────────────────────────────
-- Cheerful 2-bar loop in upper register. Bouncy mage arpeggio + walking bass +
-- sparse pad chords + bell offbeats. Bundled into SHOP table to keep main-chunk
-- locals under Lua's 200 cap.
-- Mellow monochrome shop loop, Digimon-World style: a slow pad cycle + a
-- single bell-ish chime once per bar; no walking bass, no busy arpeggios.
SHOP.step = 0
SHOP.pattern_len = 64
SHOP.pattern = {
  -- mage: a single high bell once per bar (slow, contemplative)
  mage = {
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    21, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    23, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
  },
  -- cleric: long sustained pad; A → D → A → C across 4 bars (very slow)
  cleric = {
    11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    13, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    11, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
    12, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
  },
  -- warrior: nothing (silence — keeps the texture thin)
  warrior = {
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
  },
  -- bard: very sparse single chime on bar 2 + bar 4 (off-the-pad ambience)
  bard = {
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0,17, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
     0, 0, 0, 0,  0, 0, 0, 0,  0, 0,19, 0,  0, 0, 0, 0,
  },
}
SHOP.artic = {
  -- All voices long-tail, low-velocity, very wet — that "still indoor air" feel
  mage    = {vel=0.40, attack=0.020, release=2.50, wet=0.85},
  cleric  = {vel=0.35, attack=0.30,  release=8.00, wet=0.90},
  warrior = {vel=0.40, attack=0.005, release=0.30, wet=0.30},
  bard    = {vel=0.35, attack=0.010, release=2.20, wet=0.85},
}
local function tick_shop_music()
  SHOP.step = (SHOP.step % SHOP.pattern_len) + 1
  for class, pat in pairs(SHOP.pattern) do
    local idx = pat[SHOP.step]
    if idx and idx > 0 then
      local note = active_scale()[idx] + JAM.root
      if note then
        local a = SHOP.artic[class]
        engine["trig_" .. class](midi_to_freq(note), a.vel, a.attack, a.release, a.wet)
      end
    end
  end
end

-- ============================================================ OVERWORLD

update_camera = function()
  cam.x = player.x - math.floor(VIEW_W / 2)
  cam.y = player.y - math.floor(VIEW_H / 2)
  cam.x = math.max(1, math.min(MAP_W - VIEW_W + 1, cam.x))
  cam.y = math.max(1, math.min(MAP_H - VIEW_H + 1, cam.y))
  -- detect place change → show place-name banner briefly. The "place key"
  -- combines map id + sub-region so e.g. crossing village→woods on the
  -- mainland fires a fresh banner, but standing still in the inn doesn't.
  local sub = (current_map_id == 1) and get_region(player.x) or ""
  local r = current_map_id .. ":" .. sub
  if r ~= last_region then
    last_region = r
    region_label_ticks = 28
  end
end

local function facing_offset()
  if player.facing == "up" then return 0, -1
  elseif player.facing == "down" then return 0, 1
  elseif player.facing == "left" then return -1, 0
  elseif player.facing == "right" then return 1, 0
  end
  return 0, 0
end

local function find_facing_npc()
  local dx, dy = facing_offset()
  -- one tile ahead first
  local n = npc_at(player.x + dx, player.y + dy)
  if n then return n end
  -- Talking-over-the-counter: if the immediate tile is a counter (22) or
  -- till (33), peek one more tile ahead — lets the player address the
  -- shopkeeper without standing on the wares.
  local t = tile_at(player.x + dx, player.y + dy)
  if t == 22 or t == 33 then
    return npc_at(player.x + dx * 2, player.y + dy * 2)
  end
  return nil
end

-- forward decls
local enter_battle
-- enter_jam_pad is intentionally global (saves a `local` slot near the 200-cap
-- and is only called from menu handlers via the same name)

-- Random encounter: small chance per overworld step. Skips the village (mainland
-- cols 1-32) and any caves the player hasn't unlocked yet — picks the encounter
-- pool matching the current map/region.
local function try_random_encounter()
  -- village + interiors (inn/shop) are safe zones; never roll encounters there.
  if current_map_id == 5 or current_map_id == 6 then return false end
  if current_map_id == 1 and player.x <= 32 then return false end
  -- Cave interiors use their own per-step encounter rate, not the overworld one.
  -- Side dungeon (The Hollow, map 12) reuses Cave 1's encounter pool.
  -- Suno's Domain caves (13, 14) use caves 6 and 7 pools.
  local cave_for_map = { [7] = 1, [8] = 2, [9] = 3, [10] = 4, [11] = 5,
                         [12] = 1, [13] = 6, [14] = 7 }
  local cv = cave_for_map[current_map_id]
  if cv then
    if math.random() >= (CONTENT.encounter_step_chance or 0.12) then return false end
    enter_battle(cv, true)
    return true
  end
  if math.random() >= ENCOUNTER_CHANCE then return false end
  local cave_id
  if current_map_id == 1 then
    cave_id = (player.x <= 48) and 2 or 3   -- woods or coast
  elseif current_map_id == 2 then
    cave_id = 4                              -- eastern reaches
  elseif current_map_id == 3 then
    cave_id = 5                              -- northern wilds
  else
    cave_id = 6                              -- suno's domain
  end
  enter_battle(cave_id, true)
  return true
end

local function try_move(dx, dy)
  if dy < 0 then player.facing = "up"
  elseif dy > 0 then player.facing = "down"
  elseif dx < 0 then player.facing = "left"
  elseif dx > 0 then player.facing = "right"
  end
  local nx, ny = player.x + dx, player.y + dy
  local t = tile_at(nx, ny)
  if t == 6 then
    -- Cave 1: enter the explorable interior instead of an immediate battle.
    -- Random encounters trigger per-step inside; tile 27 is the boss arena.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(7, 6, 9)   -- spawn just inside the cave's south door
    CONTENT.cave_entered = CONTENT.cave_entered or {}
    if not CONTENT.cave_entered[1] then
      CONTENT.cave_entered[1] = true
      if STORY.play_id("enter_cave1") then return end
    end
    redraw()
    return
  end
  if t == 27 then
    -- Boss arena marker: cave id derives from the current interior map.
    local cave_for_map = { [7] = 1, [8] = 2, [9] = 3, [10] = 4, [11] = 5,
                           [13] = 6, [14] = 7 }
    enter_battle(cave_for_map[current_map_id] or 1)
    return
  end
  if t == 7 then
    -- Cave 2 entry: enter the explorable interior.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(8, 7, 9)
    CONTENT.cave_entered = CONTENT.cave_entered or {}
    if not CONTENT.cave_entered[2] then
      CONTENT.cave_entered[2] = true; if STORY.play_id("enter_cave2") then return end
    end
    redraw()
    return
  end
  if t == 9 then
    -- Cave 3 entry: enter the explorable interior.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(9, 6, 9)
    CONTENT.cave_entered = CONTENT.cave_entered or {}
    if not CONTENT.cave_entered[3] then
      CONTENT.cave_entered[3] = true; if STORY.play_id("enter_cave3") then return end
    end
    redraw()
    return
  end
  if t == 11 then
    -- Cave 4 entry: enter the explorable interior.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(10, 6, 9)
    CONTENT.cave_entered = CONTENT.cave_entered or {}
    if not CONTENT.cave_entered[4] then
      CONTENT.cave_entered[4] = true; if STORY.play_id("enter_cave4") then return end
    end
    redraw()
    return
  end
  if t == 16 then
    -- Cave 5 entry: enter the explorable interior.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(11, 7, 9)
    CONTENT.cave_entered = CONTENT.cave_entered or {}
    if not CONTENT.cave_entered[5] then
      CONTENT.cave_entered[5] = true; if STORY.play_id("enter_cave5") then return end
    end
    redraw()
    return
  end
  if t == 36 then
    -- Side dungeon "The Hollow": optional, no shard. Same encounter pool
    -- as Cave 1 (CAVE1 pool), no boss tile inside.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(12, 6, 9)
    redraw()
    return
  end
  if t == 19 then
    -- Cave 6 (Locrian Crypt) entry — explorable interior on Suno's Domain
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(13, 7, 9)
    redraw()
    return
  end
  if t == 20 then
    -- Cave 7 (Suno's Chamber) entry — small antechamber interior
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(14, 6, 5)
    redraw()
    return
  end
  if t == 18 then
    -- Tower: gated by 5+ shards. Travels bidirectionally to Suno's Domain.
    if count_shards() >= 5 then
      if current_map_id == 4 then
        travel_to(1, 18, 7)         -- back to mainland plaza
      else
        travel_to(4, 12, 12)         -- arrive at Tower base
      end
    else
      tower_locked_ticks = 36
    end
    redraw()
    return
  end
  if t == 15 then
    -- mountain pass: bidirectional teleport between mainland and Northern Wilds
    if current_map_id == 1 then
      travel_to(3, 5, 12)        -- arrive at south of Northern Wilds
    else
      travel_to(1, 13, 2)        -- back to mainland just south of pass
    end
    redraw()
    return
  end
  if t == 10 then
    -- boat tile: trigger voyage to other continent
    if current_map_id == 1 then
      voyage_target_map = 2
      voyage_target_x = 2   -- land just east of boat at (1,8) on Eastern Reaches
      voyage_target_y = 8
    else
      voyage_target_map = 1
      voyage_target_x = 63   -- land just west of mainland boat at (64,7)
      voyage_target_y = 7
    end
    voyage_ticks = VOYAGE_DURATION
    game_state = "VOYAGE"
    redraw()
    return
  end
  if t == 13 then
    -- Inn entry: teleport into the inn interior. Mara (innkeeper) handles
    -- the actual rest action when the player talks to her.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1   -- step out below door
    travel_to(5, 6, 7)
    redraw()
    return
  end
  if t == 12 then
    -- Item shop entry: teleport into the shop interior. Brio (shopkeeper)
    -- opens the SHOP UI when talked to.
    CONTENT.return_map = current_map_id
    CONTENT.return_x = nx; CONTENT.return_y = ny + 1
    travel_to(6, 6, 7)
    redraw()
    return
  end
  if t == 17 then
    -- Interior exit door: pop back to the saved overworld position.
    -- Inn-rest (leaving map 5) is the canonical "campfire moment" that
    -- surfaces an unseen party-banter scene; shop / cave exits should not.
    local was_inn = (current_map_id == 5)
    local rm = CONTENT.return_map or 1
    local rx = CONTENT.return_x or 4
    local ry = CONTENT.return_y or 8
    CONTENT.return_map = nil
    CONTENT.return_x = nil; CONTENT.return_y = nil
    travel_to(rm, rx, ry)
    if was_inn and STORY.play() then return end
    redraw()
    return
  end
  if is_walkable(nx, ny) and not npc_at(nx, ny) then
    -- Pass 53: footstep dust puff at the previous tile (in screen coords).
    do
      local sx = (player.x - cam.x) * TILE + 4
      local sy = (player.y - cam.y) * TILE + 7
      ANIM.dust_puff(sx, sy)
    end
    player.x = nx
    player.y = ny
    update_camera()
    -- campfire pickup: heal party 25% HP if standing on a campfire.
    -- First time at each campfire also triggers a quiet party-memory scene.
    -- If a scene fires, we redraw + return early so a stray random encounter
    -- can't yank the player into BATTLE mid-dialogue.
    local fire_scene_started = false
    for fi, f in ipairs(CONTENT.campfires) do
      if f.map == current_map_id and f.x == nx and f.y == ny then
        for _, q in ipairs(party) do
          if q.alive then q.hp = math.min(q.hp_max, q.hp + math.floor(q.hp_max * 0.25)) end
        end
        CONTENT.flash_text = "+25% HP all"
        CONTENT.flash_ticks = 24
        CONTENT.fire_seen = CONTENT.fire_seen or {}
        if not CONTENT.fire_seen[fi] then
          CONTENT.fire_seen[fi] = true
          local lines
          if fi == 1 then       -- Hollow Woods fire
            lines = {
              "(Strom feeds the fire a fistful of dry needles.)",
              "[Strom]  My captain liked woods like these.",
              "[Strom]  Said trees keep their secrets longer than men.",
              "[Miel]   Then we are in good company tonight.",
            }
          elseif fi == 2 then   -- Sunward Coast fire
            lines = {
              "(Alder tunes the lute by the fire's pop and crackle.)",
              "[Alder]  Salt makes the gut strings sing wider.",
              "[Diegues] An overtone, mostly. The third partial.",
              "[Alder]  Diegues. Just listen for once.",
              "[Diegues] (he listens.)",
            }
          else                  -- Northern Wilds fire
            lines = {
              "(Snow falls onto the fire and hisses out.)",
              "[Miel]   My grandmother walked these passes.",
              "[Miel]   She sang to keep the cold off her hands.",
              "[Strom]  Sing it now, Miel. We'll keep watch.",
              "[Miel]   (...softly, in a key the snow forgets...)",
            }
          end
          dlg.lines = lines
          dlg.line = 1
          dlg.npc = nil
          game_state = "DIALOGUE"
          fire_scene_started = true
        end
        break
      end
    end
    if fire_scene_started then redraw(); return end
    -- chest pickup: scan all chests for one at the player's new position
    for _, c in ipairs(CONTENT.chests) do
      if c.map == current_map_id and c.x == nx and c.y == ny and not CONTENT.opened[c.id] then
        if c.locked then
          if SHOP.inv.key and SHOP.inv.key > 0 then
            SHOP.inv.key = SHOP.inv.key - 1
            CONTENT.opened[c.id] = true
            local msg = "Unlocked!"
            if c.loot.g then
              SHOP.gold = SHOP.gold + c.loot.g
              msg = msg .. "  +" .. c.loot.g .. "g"
            end
            if c.loot.item then
              SHOP.inv[c.loot.item] = (SHOP.inv[c.loot.item] or 0) + 1
              msg = msg .. "  +1 " .. c.loot.item
            end
            CONTENT.flash_text = msg
            CONTENT.flash_ticks = 42
          else
            CONTENT.flash_text = "Locked. Need a Key."
            CONTENT.flash_ticks = 30
          end
        else
          CONTENT.opened[c.id] = true
          local msg = "Chest!"
          if c.loot.g then
            SHOP.gold = SHOP.gold + c.loot.g
            msg = "+" .. c.loot.g .. "g"
          end
          if c.loot.item then
            SHOP.inv[c.loot.item] = (SHOP.inv[c.loot.item] or 0) + 1
            msg = msg .. "  +1 " .. c.loot.item
          end
          CONTENT.flash_text = msg
          CONTENT.flash_ticks = 36
        end
        break
      end
    end
    -- random encounter check: only outside the village safe zone
    if try_random_encounter() then return end
  end
  redraw()
end

-- per-tick guards: prevent duplicate input events (gamepad + keyboard remap)
-- from firing the same action twice within one tick
local _dlg_advance_tick = -1
local _dlg_start_tick  = -1

start_dialogue = function(npc)
  if _dlg_start_tick == tick then return end
  _dlg_start_tick = tick
  -- Tova's sidequest: track when player meets each regional sage
  if npc and (npc.name == "Veris" or npc.name == "Aurin" or npc.name == "Mira" or npc.name == "Iolen") then
    QUESTS.tova.spoke[npc.name] = true
  end
  dlg.npc = npc
  dlg.line = 1
  -- snapshot dialogue lines (NPCs now use function-based dialogue for progress-aware text)
  local raw = npc.dialogue
  dlg.lines = (type(raw) == "function") and raw() or raw
  game_state = "DIALOGUE"
  redraw()
end

local function advance_dialogue()
  if _dlg_advance_tick == tick then return end
  _dlg_advance_tick = tick
  dlg.line = dlg.line + 1
  if dlg.line > #(dlg.lines or {}) then
    local npc = dlg.npc
    dlg.npc = nil
    dlg.lines = nil
    -- Hens (now in the item-shop interior) opens the SHOP UI when her
    -- dialogue ends; other NPCs return to overworld.
    if npc and npc.name == "Hens" then
      SHOP.idx = 1
      SHOP.step = 0
      game_state = "SHOP"
    else
      game_state = "OVERWORLD"
    end
  end
  redraw()
end

-- ============================================================ BATTLE

-- Spawn a floating number above the given screen coords. lev: 15=normal,
-- 13=crit (hot), 11=heal (green-tinged on grayscale), 8=blocked.
ANIM.spawn_dmg = function(x, y, amt, lev)
  table.insert(ANIM.popups, {x = x, y = y, amt = amt, lev = lev or 15, t = tick})
end

local function damage_enemy(amount, is_crit)
  if enemy.invincible then
    -- Practice dummy: show damage numbers but never lose HP or die
    ANIM.spawn_dmg(96, 22, amount, is_crit and 13 or 15)
    if is_crit then ANIM.crit_flash = tick; ANIM.shake(2, 6); ANIM.burst(96, 32, 12, 15) end
    return
  end
  enemy.hp = math.max(0, enemy.hp - amount)
  ANIM.spawn_dmg(96, 22, amount, is_crit and 13 or 15)
  if is_crit then
    ANIM.crit_flash = tick
    ANIM.shake(2, 6)
    ANIM.flash_hit()
    ANIM.burst(96, 32, 12, 15)
  else
    -- non-crit hit gets a tiny burst too (smaller, dimmer)
    ANIM.burst(96, 32, 4, 11)
  end
  if enemy.hp == 0 then
    enemy.alive = false
    gain_xp(enemy_xp(enemy.name))
    SHOP.last_gold = enemy_gold(enemy.name)
    SHOP.gold = SHOP.gold + SHOP.last_gold
    -- bestiary: record this enemy as seen (visual key + name + max stats)
    CONTENT.bestiary[enemy.visual or enemy.name] = {
      name = enemy.name,
      hp_max = enemy.hp_max,
      atk = enemy.atk,
      visual = enemy.visual,
    }
  end
end

-- find the HUD column x for a given party member (index 1..4)
ANIM.party_hud_x = function(p)
  for i, q in ipairs(party) do
    if q == p then return (i - 1) * 32 + 17 end
  end
  return 16
end

local function damage_party(p, amount)
  -- Party is invincible while in JAM mode (so jamming live during a battle
  -- can't accidentally KO anyone).
  if game_state == "JAM" then return end
  -- Strom's BLK: redirect to blocking warrior at 10% damage
  local blocker = nil
  for _, q in ipairs(party) do
    if q.alive and q.blocking and q ~= p then blocker = q; break end
  end
  if blocker then
    amount = math.max(1, math.floor(amount * 0.10))
    blocker.blocking = false
    p = blocker
  end
  if p.shield then
    amount = math.floor(amount / 2)
    p.shield = false
  end
  -- HORN's dmg_reduce buff: halve incoming damage while ticks remain
  if (p.dmg_reduce_ticks or 0) > 0 then
    amount = math.max(1, math.floor(amount / 2))
  end
  p.hp = math.max(0, p.hp - amount)
  p.last_hit = tick
  if p.hp == 0 then p.alive = false end
  ANIM.spawn_dmg(ANIM.party_hud_x(p), 47, amount, 15)
  -- Pass 50: enemy-inflicted status. Each attack has a small chance to
  -- apply a status effect to the hit character. Bosses use higher rates.
  if enemy and p.alive then
    local boss_visuals = {echo=true, sentinel=true, tide=true, dunerider=true,
                          snowgaunt=true, locrius=true, suno=true}
    local poison_chance = boss_visuals[enemy.visual] and 0.18 or 0.06
    local sleep_chance  = boss_visuals[enemy.visual] and 0.10 or 0.03
    if math.random() < poison_chance then
      p.poison_ticks = math.max(p.poison_ticks or 0, 60)
    end
    if math.random() < sleep_chance then
      p.sleep_ticks = math.max(p.sleep_ticks or 0, 24)
    end
  end
  -- ── SERGEI'S INTERVENTION (one-shot, Cave 3 / Tidewatch boss) ──
  -- If the party is about to wipe during the Tidewatch fight and Sergei
  -- hasn't intervened yet, he steps in: revives all members at 50% HP and
  -- joins the recruits roster permanently.
  if not CONTENT.sergei_intervened
     and game_state == "BATTLE" and current_cave == 3
     and enemy and enemy.visual == "tide" then
    local any_alive = false
    for _, q in ipairs(party) do if q.alive then any_alive = true; break end end
    if not any_alive then
      CONTENT.sergei_intervened = true
      CONTENT.recruits[1].joined = true   -- Sergei
      for _, q in ipairs(party) do
        q.alive = true
        q.hp = math.max(1, math.floor(q.hp_max * 0.50))
        q.atb = 0
        q.last_hit = tick
      end
      CONTENT.banner_text  = "SERGEI INTERVENES!"
      CONTENT.banner_ticks = 36
    end
  end
end

local function heal_party(hp_frac, mp_frac)
  for _, q in ipairs(party) do
    if q.alive then
      q.hp = math.min(q.hp_max, q.hp + math.floor(q.hp_max * hp_frac))
      if mp_frac and mp_frac > 0 then
        q.mp = math.min(q.mp_max, q.mp + math.floor(q.mp_max * mp_frac))
      end
      q.last_hit = tick   -- reuse the hit-flash to show heal landing
    end
  end
end

-- When ANY party member plays their instrument, every other living party
-- (Party-jam contagion was removed — caused chain-overwrite of player choices.
-- Each character now only ever fires their own queued action.)
local function trigger_party_jam(except) end

local function apply_player_action(p)
  -- Treat legacy "MAG" save data as the class's instrument.
  if p.queued == "MAG" then p.queued = CLASS_INSTRUMENT[p.class] or "ATK" end
  if p.queued == "ATK" then
    if enemy.alive then
      local dmg = INST.atk(p)
      local crit = math.random() < ANIM.crit
      if crit then dmg = dmg * 2 end
      if p.buffed then dmg = math.floor(dmg * 1.5); p.buffed = false end
      damage_enemy(dmg, crit)
    end
  elseif p.queued == "LYRE" then
    -- Miel's lyre: revive + heal + apply HP/MP regen.
    for _, q in ipairs(party) do
      if not q.alive then
        q.alive = true
        q.hp = math.max(1, math.floor(q.hp_max * 0.30))
        q.atb = 0
        q.last_hit = tick
        break
      end
    end
    heal_party(0.25, 0)
    for _, q in ipairs(party) do
      if q.alive then
        q.regen_hp_ticks = math.max(q.regen_hp_ticks or 0, 32)
        q.regen_mp_ticks = math.max(q.regen_mp_ticks or 0, 32)
        -- Pass 50: Miel's lyre also dispels poison + sleep on the party.
        q.poison_ticks = 0
        q.sleep_ticks = 0
      end
    end
  elseif p.queued == "LUTE" then
    -- Alder's lute: heal all 10% HP + buff next attack of all alive.
    for _, q in ipairs(party) do
      if q.alive then
        q.hp = math.min(q.hp_max, q.hp + math.floor(q.hp_max * 0.10))
        q.buffed = true
        q.last_hit = tick
      end
    end
  elseif p.queued == "MIX" then
    -- Sergei's MIX: remix the enemy's pattern (deal MAG damage, scramble its
    -- attack pattern order, debuff atk).
    if enemy and enemy.alive then
      local dmg = math.floor(INST.mag(p) * 1.4)
      local crit = math.random() < ANIM.crit
      if crit then dmg = dmg * 2 end
      damage_enemy(dmg, crit)
      enemy.atk_debuff_ticks = math.max(enemy.atk_debuff_ticks or 0, 24)
      -- shuffle the enemy's attack_pattern in-place (Fisher-Yates)
      local ap = enemy.attack_pattern
      if ap and #ap > 1 then
        for i = #ap, 2, -1 do
          local j = math.random(i)
          ap[i], ap[j] = ap[j], ap[i]
        end
        enemy.pattern_idx = 1
      end
    end
  elseif p.queued == "CODE" then
    -- Paj's CODE: damage proportional to enemy's CURRENT HP percent (the bigger
    -- the foe, the bigger the bite); also self-heals a small chunk.
    if enemy and enemy.alive then
      local pct = enemy.hp / math.max(1, enemy.hp_max)
      local dmg = math.floor(INST.mag(p) * (1.0 + pct * 1.5))
      local crit = math.random() < ANIM.crit
      if crit then dmg = dmg * 2 end
      damage_enemy(dmg, crit)
    end
    p.hp = math.min(p.hp_max, p.hp + math.floor(p.hp_max * 0.15))
    p.last_hit = tick
  elseif p.queued == "HORN" then
    -- Strom's war horn: party gains attack buff + damage reduction; enemy ATK halved.
    for _, q in ipairs(party) do
      if q.alive then
        q.buffed = true
        q.dmg_reduce_ticks = math.max(q.dmg_reduce_ticks or 0, 28)
      end
    end
    if enemy and enemy.alive then
      enemy.atk_debuff_ticks = math.max(enemy.atk_debuff_ticks or 0, 28)
    end
    trigger_party_jam(p)
  elseif p.queued == "SMPL" then
    -- Diegues' samplers: deal big damage to enemy, debuff its ATK, inspire party.
    if enemy and enemy.alive then
      local dmg = math.floor(INST.mag(p) * 2.0)
      local crit = math.random() < ANIM.crit
      if crit then dmg = dmg * 2 end
      damage_enemy(dmg, crit)
      enemy.atk_debuff_ticks = math.max(enemy.atk_debuff_ticks or 0, 20)
    end
    for _, q in ipairs(party) do
      if q.alive then q.buffed = true end
    end
    trigger_party_jam(p)
  elseif p.queued == "PLAY" then
    -- Alder's bard play: heal all 10% HP + buff next attack of all alive. Now also jams.
    for _, q in ipairs(party) do
      if q.alive then
        q.hp = math.min(q.hp_max, q.hp + math.floor(q.hp_max * 0.10))
        q.buffed = true
        q.last_hit = tick
      end
    end
    trigger_party_jam(p)
  elseif p.queued == "BLK" then
    -- Strom's block-for-party: next enemy hit on someone else redirects to him at 10%. Free.
    p.blocking = true
    p.mp = math.min(p.mp_max, p.mp + 1)
  elseif p.queued == "ITM" then
    -- Item priority: revive a KO'd member with Star → Salve heal-all → Vial MP-all → tiny self-heal
    local revive_target = nil
    for _, q in ipairs(party) do
      if not q.alive then revive_target = q; break end
    end
    if revive_target and SHOP.inv.star > 0 then
      SHOP.inv.star = SHOP.inv.star - 1
      revive_target.alive = true
      revive_target.hp = revive_target.hp_max
      revive_target.atb = 0
      revive_target.last_hit = tick
      SHOP.last_item = "Star"
    elseif SHOP.inv.salve > 0 then
      SHOP.inv.salve = SHOP.inv.salve - 1
      for _, q in ipairs(party) do
        if q.alive then q.hp = math.min(q.hp_max, q.hp + 35) end
      end
      SHOP.last_item = "Salve"
    elseif SHOP.inv.vial > 0 then
      SHOP.inv.vial = SHOP.inv.vial - 1
      for _, q in ipairs(party) do
        if q.alive then q.mp = math.min(q.mp_max, q.mp + 10) end
      end
      SHOP.last_item = "Vial"
    elseif SHOP.inv.ether > 0 then
      SHOP.inv.ether = SHOP.inv.ether - 1
      for _, q in ipairs(party) do
        if q.alive then q.mp = math.min(q.mp_max, q.mp + 25) end
      end
      SHOP.last_item = "Ether"
    elseif SHOP.inv.tonic > 0 then
      -- Tonic: stamps a one-battle ATK boost on every alive party member
      SHOP.inv.tonic = SHOP.inv.tonic - 1
      for _, q in ipairs(party) do
        if q.alive then q.tonic_ticks = 999 end   -- cleared on exit_battle
      end
      SHOP.last_item = "Tonic"
    else
      -- empty pockets: a meager self-care motion
      p.hp = math.min(p.hp_max, p.hp + 4)
      p.mp = math.min(p.mp_max, p.mp + 2)
      SHOP.last_item = "(empty)"
    end
  elseif p.queued == "DEF" then
    p.shield = true
    p.mp = math.min(p.mp_max, p.mp + 1)
  end
end

local function fire(p)
  apply_player_action(p)
  local action = p.queued
  if action == "MAG" and p.mp < 0 then action = "ATK" end
  local a = ARTIC[action] or ARTIC.ATK
  local note = active_scale()[p.note_idx] + a.pitch + JAM.root
  local freq = midi_to_freq(note)
  -- apply equipped instrument's tone overrides
  local inst = INST.of(p)
  local atk_t = a.attack  * (inst and inst.atk_mul or 1)
  local rel_t = a.release * (inst and inst.rel_mul or 1)
  local wet_t = math.max(0, math.min(1, a.wet + (inst and inst.wet_add or 0)))
  engine["trig_" .. (((p.class == "engineer" and "mage") or (p.class == "mathwiz" and "bard") or (p.class == "drummer" and "warrior") or p.class))](freq, a.vel, atk_t, rel_t, wet_t)
  p.last_fire = tick
  p.last_action = action  -- so the HUD can render an action-specific animation
  p.note_idx = p.note_idx + 1
  if p.note_idx > p.note_hi then p.note_idx = p.note_lo end
end

local function enemy_tick()
  if not enemy.alive then return end
  if enemy.invincible then return end  -- practice dummy never attacks
  -- Pass 51: boss phase 2. When a boss drops below 30% HP, it ENRAGES:
  -- attack gaps cut in half + atk +25%. One-shot banner on the trigger.
  local boss_visuals = {echo=true, sentinel=true, tide=true, dunerider=true,
                        snowgaunt=true, locrius=true, suno=true}
  if boss_visuals[enemy.visual] and not enemy.phase2
     and enemy.hp_max > 0 and enemy.hp <= enemy.hp_max * 0.30 then
    enemy.phase2 = true
    enemy.atk = math.ceil(enemy.atk * 1.25)
    -- halve every gap in the attack pattern (faster cadence)
    for i = 1, #enemy.attack_pattern do
      enemy.attack_pattern[i] = math.max(2, math.floor(enemy.attack_pattern[i] / 2))
    end
    CONTENT.banner_text  = "* " .. enemy.name .. " ENRAGES! *"
    CONTENT.banner_ticks = 36
    ANIM.shake(3, 12); ANIM.flash_hit(); ANIM.burst(96, 32, 14, 15)
  end
  local next_gap = enemy.attack_pattern[enemy.pattern_idx] or 8
  if (tick - enemy.last_attack) < next_gap then return end
  enemy.last_attack = tick
  enemy.pattern_idx = (enemy.pattern_idx % #enemy.attack_pattern) + 1
  -- attack-sound voice (each enemy has a unique sonic signature)
  if enemy.attack_sound then
    local s = enemy.attack_sound
    engine["trig_" .. s.class](midi_to_freq(s.note), s.vel, s.attack, s.release, s.wet)
  end
  local alive_idx = alive_party()
  if #alive_idx == 0 then return end
  local target_i = alive_idx[math.random(#alive_idx)]
  local target = party[target_i]
  -- spawn a projectile from the enemy sprite center to the target HUD sprite
  ANIM.proj = {
    sx = 96, sy = 32,
    tx = (target_i - 1) * 32 + 5, ty = 53,
    t = tick,
  }
  -- enemy ATK debuff (HORN/SMPL): halved while ticks remain
  local atk = enemy.atk
  if (enemy.atk_debuff_ticks or 0) > 0 then
    atk = math.max(1, math.floor(atk / 2))
  end
  damage_party(target, atk)
end

local exit_battle  -- forward decl

-- Pass 52: lightweight achievement system. unlock_achievement(id, name)
-- one-shots a flash banner the first time a milestone is hit; stores the
-- flag in CONTENT.achievements (saved/loaded with the rest of CONTENT
-- via the existing snapshot logic).
function unlock_achievement(id, name)
  CONTENT.achievements = CONTENT.achievements or {}
  if CONTENT.achievements[id] then return end
  CONTENT.achievements[id] = true
  CONTENT.flash_text = "* " .. name .. " *"
  CONTENT.flash_ticks = 60
end

local function check_battle_end()
  if not enemy.alive then
    battle_outcome = "VICTORY"
    battle_end_ticks = BATTLE_END_DURATION
    game_state = "BATTLE_END"
    engine.drone_amp(0)         -- silent — victory fanfare plays instead
    victory_step = 0            -- start fanfare from step 1 next tick
    params:set("clock_tempo", OVERWORLD_BPM)  -- victory theme at journey rate
    -- track progression toward boss in the current cave
    last_boss_drop = nil
    local function award_drop(cave_id)
      local id = BOSS_INSTRUMENT_DROP[cave_id]
      if id and not instruments_owned[id] then
        instruments_owned[id] = true
        last_boss_drop = id
      end
    end
    local function clear_boss(cave_id, shard)
      cave_state[cave_id].cleared = true
      cave_state[cave_id].victories = 0
      obtain_shard(shard)
      award_drop(cave_id)
      -- Pass 52 achievement triggers
      unlock_achievement("first_shard", "First Shard")
      local total_cleared = 0
      for i = 1, 7 do if cave_state[i].cleared then total_cleared = total_cleared + 1 end end
      if total_cleared >= 7 then unlock_achievement("all_caves", "All Seven Cleared") end
    end
    -- visual punch on every battle-end
    ANIM.flash_hit()
    if enemy.visual == "echo"      then clear_boss(1, "lydian")
    elseif enemy.visual == "sentinel"  then clear_boss(2, "dorian")
    elseif enemy.visual == "tide"      then clear_boss(3, "mixolydian")
    elseif enemy.visual == "dunerider" then clear_boss(4, "phrygian")
    elseif enemy.visual == "snowgaunt" then clear_boss(5, "aeolian")
    elseif enemy.visual == "locrius"   then clear_boss(6, "locrian")
    elseif enemy.visual == "suno"      then
      clear_boss(7, "ionian")
      -- final victory triggers the ENDING sequence in exit_battle
      ending_pending = true
    elseif random_battle then
      -- random encounters give XP/loot but don't count toward boss progress
      -- — they DO count toward Hens & Brann sidequests though.
      QUESTS.hens.wins  = QUESTS.hens.wins + 1
      QUESTS.brann.wins = QUESTS.brann.wins + 1
      -- Pass 32: random-battle item drops. ~35% chance per win to drop a
      -- consumable. Weighted: salve > vial > ether > tonic > star > key.
      if math.random() < 0.35 then
        local table_drops = {
          {id = "salve", w = 30},
          {id = "vial",  w = 22},
          {id = "ether", w = 14},
          {id = "tonic", w = 8},
          {id = "star",  w = 4},
          {id = "key",   w = 2},
        }
        local total = 0; for _, d in ipairs(table_drops) do total = total + d.w end
        local roll = math.random() * total
        local acc = 0
        for _, d in ipairs(table_drops) do
          acc = acc + d.w
          if roll <= acc then
            SHOP.inv[d.id] = (SHOP.inv[d.id] or 0) + 1
            SHOP.last_item_drop = d.id
            break
          end
        end
      else
        SHOP.last_item_drop = nil
      end
      -- Pass 45: rare encounters override the random-drop with a guaranteed
      -- high-tier item from the rare's own table.
      if enemy.is_rare and enemy.rare_drop then
        SHOP.inv[enemy.rare_drop] = (SHOP.inv[enemy.rare_drop] or 0) + 1
        SHOP.last_item_drop = enemy.rare_drop
        unlock_achievement("first_rare", "Rare Hunter")
      end
    else
      cave_state[current_cave].victories = cave_state[current_cave].victories + 1
    end
  elseif #alive_party() == 0 then
    battle_outcome = "DEFEAT"
    battle_end_ticks = BATTLE_END_DURATION
    game_state = "BATTLE_END"
    engine.drone_amp(DRONE_AMP_BATTLE_END)   -- somber drone for defeat
  end
end

-- ──────────────────────────────────────────────────────────────────────────
-- Pass 34: battle music. Plays underneath combat: warrior bass ostinato,
-- cleric pad, mage melodic line, bard accent stabs. Boss flag picks the
-- heavier "boss" theme; otherwise "encounter" for random+regular fights.
-- Intentionally global to stay under the 200-local main-chunk cap.
function tick_battle_music()
  if not enemy then return end
  -- Practice dummy uses no battle music — let the player jam unobstructed.
  if enemy.invincible then return end
  TITLE.battle_step = (TITLE.battle_step % OW_PATTERN_LEN) + 1
  -- choose theme: boss enemies are the cave bosses. Detect by name match.
  local boss_visuals = {echo=true, sentinel=true, tide=true, dunerider=true,
                        snowgaunt=true, locrius=true, suno=true}
  local theme = (boss_visuals[enemy.visual] and BATTLE_THEMES.boss) or BATTLE_THEMES.encounter
  for class, pat in pairs(theme.pattern) do
    fire_ow_voice(class, pat[TITLE.battle_step], theme.artic)
  end
end

local function tick_battle()
  -- music underlay (Pass 34)
  tick_battle_music()
  -- per-beat status effect ticking
  for _, p in ipairs(party) do
    if p.alive then
      if (p.regen_hp_ticks or 0) > 0 then
        p.regen_hp_ticks = p.regen_hp_ticks - 1
        if (tick % 8) == 0 then
          p.hp = math.min(p.hp_max, p.hp + 1)
        end
      end
      if (p.regen_mp_ticks or 0) > 0 then
        p.regen_mp_ticks = p.regen_mp_ticks - 1
        if (tick % 12) == 0 then
          p.mp = math.min(p.mp_max, p.mp + 1)
        end
      end
      -- Pass 50: POISON — slow HP drip every 6 ticks while poisoned.
      if (p.poison_ticks or 0) > 0 then
        p.poison_ticks = p.poison_ticks - 1
        if (tick % 6) == 0 then
          p.hp = math.max(1, p.hp - 1)
          ANIM.spawn_dmg(ANIM.party_hud_x(p), 47, 1, 9)
        end
      end
      -- Pass 50: SLEEP — countdown only; ATB freeze handled below.
      if (p.sleep_ticks or 0) > 0 then p.sleep_ticks = p.sleep_ticks - 1 end
      if (p.dmg_reduce_ticks or 0) > 0 then p.dmg_reduce_ticks = p.dmg_reduce_ticks - 1 end
    end
  end
  if enemy and (enemy.atk_debuff_ticks or 0) > 0 then
    enemy.atk_debuff_ticks = enemy.atk_debuff_ticks - 1
  end
  if CONTENT.banner_ticks > 0 then CONTENT.banner_ticks = CONTENT.banner_ticks - 1 end
  for _, p in ipairs(party) do
    if p.alive then
      -- Sleep freezes the ATB. Poison still ticks (it's a damage-over-time).
      if (p.sleep_ticks or 0) == 0 then
        p.atb = p.atb + INST.spd(p)
        if p.atb >= 16 then
          p.atb = p.atb - 16
          fire(p)
        end
      end
    end
  end
  enemy_tick()
  check_battle_end()
end

travel_to = function(map_id, x, y)
  current_map_id = map_id
  if map_id == 1 then
    map = MAINLAND; npcs = MAINLAND_NPCS
  elseif map_id == 2 then
    map = EASTERN_REACHES; npcs = EASTERN_NPCS
  elseif map_id == 3 then
    map = NORTHERN_WILDS; npcs = NORTHERN_NPCS
  elseif map_id == 5 then
    map = CONTENT.inn_map; npcs = CONTENT.inn_npcs
  elseif map_id == 6 then
    map = CONTENT.shop_map; npcs = CONTENT.shop_npcs
  elseif map_id == 7 then
    map = CONTENT.cave1_map; npcs = CONTENT.cave1_npcs
  elseif map_id == 8 then
    map = CONTENT.cave2_map; npcs = CONTENT.cave2_npcs
  elseif map_id == 9 then
    map = CONTENT.cave3_map; npcs = CONTENT.cave3_npcs
  elseif map_id == 10 then
    map = CONTENT.cave4_map; npcs = CONTENT.cave4_npcs
  elseif map_id == 11 then
    map = CONTENT.cave5_map; npcs = CONTENT.cave5_npcs
  elseif map_id == 12 then
    map = CONTENT.hollow_map; npcs = CONTENT.hollow_npcs
  elseif map_id == 13 then
    map = CONTENT.cave6_map; npcs = CONTENT.cave6_npcs
  elseif map_id == 14 then
    map = CONTENT.cave7_map; npcs = CONTENT.cave7_npcs
  else
    map = SUNOS_DOMAIN; npcs = SUNOS_NPCS
  end
  MAP_W = #map[1]
  MAP_H = #map
  player.x = x
  player.y = y
  last_region = nil   -- force banner refresh
  update_camera()
end

-- Pass 45: rare encounters. Each cave-pool has a uniquely-named, boosted
-- variant of one of its enemies that drops a guaranteed high-tier item.
-- 4% chance per random encounter to roll rare instead of standard.
-- Global to dodge the 200-local main-chunk cap.
CAVE_RARES = {
  [1] = {name="Elder Slime",     visual="slime",     hp=350, atk=8,
         drop="ether", attack_pattern={6,6,8,6}, attack_sound={class="warrior", note=24, vel=0.65, attack=0.003, release=0.20, wet=0.10}},
  [2] = {name="Sage Sentinel",   visual="sentinel",  hp=420, atk=10,
         drop="tonic", attack_pattern={5,7,5,7,9}, attack_sound={class="cleric", note=42, vel=0.50, attack=0.05, release=0.80, wet=0.50}},
  [3] = {name="Tideturner",      visual="tide",      hp=480, atk=12,
         drop="key",   attack_pattern={4,4,8,4,4}, attack_sound={class="bard", note=48, vel=0.55, attack=0.005, release=0.40, wet=0.55}},
  [4] = {name="Dune Sovereign",  visual="scorpion",  hp=520, atk=13,
         drop="ether", attack_pattern={4,6,4,8}, attack_sound={class="mage", note=72, vel=0.60, attack=0.002, release=0.30, wet=0.40}},
  [5] = {name="Frostfather",     visual="yeti",      hp=600, atk=14,
         drop="tonic", attack_pattern={9,7,5,9}, attack_sound={class="warrior", note=20, vel=0.70, attack=0.005, release=0.50, wet=0.20}},
  [6] = {name="Voidpriest",      visual="lich",      hp=700, atk=15,
         drop="star",  attack_pattern={5,5,5,5,11}, attack_sound={class="cleric", note=30, vel=0.60, attack=0.40, release=2.50, wet=0.85}},
}

enter_battle = function(cave_id, force_random)
  current_cave = cave_id or 1
  random_battle = force_random or false
  local st = cave_state[current_cave]
  local victories = st.victories
  local cleared = st.cleared
  local pool = CAVE_POOLS[current_cave]
  local boss = CAVE_BOSSES[current_cave]
  local e
  local is_boss = false
  local is_rare = false
  if force_random then
    -- Rare encounter: 4% chance, only on random encounters in caves 1-6.
    local rare = CAVE_RARES[current_cave]
    if rare and math.random() < 0.04 then
      e = rare
      is_rare = true
    else
      e = pool[math.random(#pool)]
    end
  elseif victories >= BOSS_THRESHOLD and not cleared then
    e = boss
    is_boss = true
  else
    e = pool[math.random(#pool)]
  end
  -- Boss intro banner: 36 ticks of "BOSS — name" sliding text
  if is_boss then
    CONTENT.banner_text  = "* BOSS: " .. e.name .. " *"
    CONTENT.banner_ticks = 36
  elseif is_rare then
    CONTENT.banner_text  = "* RARE: " .. e.name .. " *"
    CONTENT.banner_ticks = 36
  end
  enemy = {
    name = e.name,
    -- Difficulty multipliers (Pass 35 → 36): ~4x HP on every enemy
    -- (random + boss) for substantially longer, more weighty fights.
    -- ATK still buffed +20%. Multipliers applied at battle-start so the
    -- underlying pool tables stay pristine.
    hp     = math.floor(e.hp  * 4.0),
    hp_max = math.floor(e.hp  * 4.0),
    atk    = math.ceil (e.atk * 1.20),
    is_rare = is_rare,
    rare_drop = e.drop,
    attack_pattern = e.attack_pattern,
    attack_sound   = e.attack_sound,
    pattern_idx = 1,
    last_attack = tick,
    alive = true, visual = e.visual,
  }
  reset_party_for_battle()
  battle_outcome = nil
  game_state = "BATTLE"
  params:set("clock_tempo", BATTLE_BPM)
  engine.drone_amp(0)
  TITLE.battle_step = 0  -- restart battle music ostinato cleanly
  redraw()
end

enter_jam_pad = function()
  unlock_achievement("first_jam", "First Jam")
  random_battle = true
  enemy = {
    name = "Practice Dummy",
    hp = 999, hp_max = 999, atk = 0,
    attack_pattern = {999},
    attack_sound = nil,
    pattern_idx = 1,
    last_attack = tick,
    alive = true,
    visual = "dummy",
    invincible = true,
    is_jam = true,
  }
  reset_party_for_battle()
  battle_outcome = nil
  game_state = "BATTLE"
  params:set("clock_tempo", BATTLE_BPM)
  engine.drone_amp(0)
  redraw()
end

exit_battle = function()
  if battle_outcome == "VICTORY" then
    for _, p in ipairs(party) do
      if p.alive then
        p.hp = math.min(p.hp_max, p.hp + math.floor(p.hp_max * 0.25))
        p.mp = math.min(p.mp_max, p.mp + math.floor(p.mp_max * 0.25))
      end
    end
    -- Pass 44: post-battle character quip. Pick a random one-liner from
    -- the active character's class pool; flash it briefly so the party
    -- has a personality after combat.
    local QUIPS = {
      warrior = {"Strom: One down. Stay close.",
                 "Strom: That'll do.",
                 "Strom: Keep the formation."},
      cleric  = {"Miel: A held note kept us standing.",
                 "Miel: One small mercy received.",
                 "Miel: Bind the wounds. We move.",
                 "Miel: The chord still rings."},
      bard    = {"Alder: Wrote that down for later.",
                 "Alder: Bridge of the encore!",
                 "Alder: Three chords and the truth.",
                 "Alder: Encore? Encore."},
      mage    = {"Diegues: Predicted, more or less.",
                 "Diegues: Let me note the variables.",
                 "Diegues: Theory holds.",
                 "Diegues: Curious. Useful."},
      engineer= {"Sergei: Re-spool the take. Move.",
                 "Sergei: Mix landed. On to the next.",
                 "Sergei: That patch held. Good.",
                 "Sergei: Wire stays clean."},
      mathwiz = {"Paj: Function returned cleanly.",
                 "Paj: Variables resolved.",
                 "Paj: Counted four breaths between hits.",
                 "Paj: Compiles."},
      drummer = {"Niko: Right on the one.",
                 "Niko: Pocket. Stay in pocket.",
                 "Niko: Snare-side, forever.",
                 "Niko: Kick-snare-kick-snare. Easy."},
    }
    local ap = party[active]
    local pool = ap and QUIPS[ap.class] or nil
    if pool and #pool > 0 then
      CONTENT.flash_text = pool[math.random(#pool)]
      CONTENT.flash_ticks = 48
    end
  end
  -- Tonic buff lasts only the current battle. Statuses also clear on exit.
  for _, p in ipairs(party) do
    p.tonic_ticks = 0
    p.poison_ticks = 0
    p.sleep_ticks = 0
  end
  battle_outcome = nil
  enemy = nil
  last_obtained_shard = nil
  -- finale: defeating Suno launches the ending cutscene instead of returning to overworld
  if ending_pending then
    ending_pending = false
    ending_idx = 1
    game_state = "ENDING"
    params:set("clock_tempo", INTRO_BPM)
    redraw()
    return
  end
  game_state = "OVERWORLD"
  params:set("clock_tempo", OVERWORLD_BPM)
  engine.drone_amp(0)
  redraw()
end

local function set_active(i)
  local n = #party
  local idx = ((i - 1) % n) + 1
  for _ = 1, n do
    if party[idx].alive then active = idx; redraw() return end
    idx = (idx % n) + 1
  end
end

local function queue_action(button)
  if not party[active].alive then return end
  local p = party[active]
  local action = CLASS_ACTIONS[p.class] and CLASS_ACTIONS[p.class][button]
  if action then
    p.queued = action
    -- Player explicitly changed this character's action — cancel any pending
    -- "party jam" revert so their choice sticks instead of snapping back.
    p.prev_queued = nil
    p.jamming = false
    redraw()
  end
end

-- ============================================================ INPUT

function gamepad.dpad(axis, sign)
  if debug_visible then
    last_input = "DPAD " .. axis .. "=" .. tostring(sign) .. " l2=" .. tostring(l2_held)
    last_input_at = tick
  end
  if sign == 0 then return end
  if game_state == "TITLE" then
    -- Either axis toggles the New Game / Continue selector — options are
    -- laid out horizontally, so dpad LR is the natural input.
    TITLE.idx = 1 - TITLE.idx
    redraw()
    return
  end
  if game_state == "OVERWORLD" then
    if l2_held then
      -- L2 + dpad UD = overworld BPM, L2 + dpad LR = battle BPM
      if axis == "Y" then
        adjust_journey_bpm(-sign * BPM_STEP)
      elseif axis == "X" then
        adjust_battle_bpm(sign * BPM_STEP)
      end
      redraw()
      return
    end
    if axis == "X" then try_move(sign, 0)
    elseif axis == "Y" then try_move(0, sign)
    end
  elseif game_state == "BATTLE" then
    if l2_held then
      -- L2 in battle: same scheme — UD = overworld BPM, LR = battle BPM
      if axis == "Y" then
        adjust_journey_bpm(-sign * BPM_STEP)
      elseif axis == "X" then
        adjust_battle_bpm(sign * BPM_STEP)
      end
      redraw()
      return
    end
    if axis == "Y" then
      -- dpad UD cycles the queued action for the active character
      local p = party[active]
      if p and p.alive then
        local ca = CLASS_ACTIONS[p.class]
        local list = {ca.A, ca.B, ca.X, ca.Y}
        local cur = 1
        for i, a in ipairs(list) do if a == p.queued then cur = i end end
        p.queued = list[((cur - 1 + sign) % 4) + 1]
        p.prev_queued = nil
        p.jamming = false
        redraw()
      end
    elseif axis == "X" then
      -- dpad LR cycles which character is active
      set_active(active + sign)
    end
  elseif game_state == "MENU" then
    if axis == "Y" then
      menu_idx = ((menu_idx - 1 + sign) % #MENU_OPTIONS) + 1
      redraw()
    end
  elseif game_state == "PARTYSEL" then
    if axis == "Y" then
      -- 0 (no focus) → 1 (Sergei) → 2 (Paj) → 0 (cycle)
      -- 0 (no focus) → 1 (Sergei) → 2 (Paj) → 3 (Niko) → 0 (cycle)
      CONTENT.partysel_focus = (CONTENT.partysel_focus + sign) % 4
      if CONTENT.partysel_focus < 0 then CONTENT.partysel_focus = CONTENT.partysel_focus + 4 end
      redraw()
    elseif axis == "X" then
      set_active(active + sign); redraw()
    end
  elseif game_state == "BESTIARY" and axis == "Y" then
    -- Pass 43: dpad UD scrolls through bestiary entries.
    local total = 0; for _ in pairs(CONTENT.bestiary) do total = total + 1 end
    if total > 0 then
      CONTENT.bestiary_idx = ((CONTENT.bestiary_idx or 1) - 1 + sign) % total + 1
      if CONTENT.bestiary_idx < 1 then CONTENT.bestiary_idx = CONTENT.bestiary_idx + total end
      redraw()
    end
  elseif game_state == "EQUIP" then
    if axis == "Y" then
      local p = party[equip_idx]
      local list = INST.owned_for(p.class)
      local n = math.max(1, #list)
      equip_choice = ((equip_choice - 1 + sign) % n) + 1
      redraw()
    elseif axis == "X" then
      equip_idx = ((equip_idx - 1 + sign) % #party) + 1
      equip_choice = 1
      redraw()
    end
  elseif game_state == "SHOP" then
    if axis == "Y" then
      SHOP.idx = ((SHOP.idx - 1 + sign) % #SHOP.order) + 1
      redraw()
    end
  elseif game_state == "JAM" then
    -- L2 toggle gates BPM: when L2 is OFF (default) dpad UD = scale, dpad LR = ROOT.
    -- When L2 is ON, dpad LR = BPM (more dangerous control behind a modifier).
    if l2_held then
      if axis == "X" then
        adjust_battle_bpm(sign * BPM_STEP)
        adjust_journey_bpm(sign * BPM_STEP)
        redraw()
      end
    else
      if axis == "Y" then
        -- Cycle scale (mode) — all modes always available in jam mode
        -- (the shard-gate only applies to story moments, not the synth toy).
        local cur = JAM.mode
        local idx = 1
        for i, m in ipairs(JAM.mode_order) do if m == cur then idx = i; break end end
        local n = #JAM.mode_order
        JAM.mode = JAM.mode_order[((idx - 1 + sign) % n + n) % n + 1]
        redraw()
      elseif axis == "X" then
        JAM.root = math.max(-12, math.min(12, (JAM.root or 0) + sign))
        redraw()
      end
    end
  end
end

-- edge detection: only fire on press transitions (was up, now down).
-- norns passes state as 0/1 or true/false — normalize to boolean first
-- (Lua 0 is truthy, so `not 0` = false; this broke naive edge detection).
local _btn_state = {}
local function is_press(button, state)
  local pressed = state == true or state == 1
  local prev = _btn_state[button] or false
  _btn_state[button] = pressed
  return pressed and not prev
end

function gamepad.button(button, state)
  if debug_visible then
    last_input = "BTN " .. tostring(button) .. "=" .. tostring(state)
    last_input_at = tick
  end
  -- L2/R2 button events are unreliable on SN30 Pro / Xbox profile (state always 0
  -- regardless of press/release). Their real state comes through gamepad.analog
  -- as triggerleft/triggerright. Ignore them here so we don't clobber l2_held.
  if button == "L2" or button == "R2" then return end
  if not is_press(button, state) then return end
  -- Pass 39 → 40 → 41: stick-click toggles FX latches. Different gamepads
  -- report stick clicks under different button names — accept all the
  -- common ones (L3/R3, thumbleft/thumbright, LSTICK/RSTICK).
  -- On latch-ON we snapshot the ACTIVE voice's current FX values and
  -- broadcast them to all four party voices, so the same effect amounts
  -- apply regardless of which voice is selected (or which voice the
  -- JAM-mode round-robin lands on next). On latch-OFF the stick resumes
  -- live control.
  local LEFT_CLICK  = (button == "L3" or button == "thumbleft"  or button == "LSTICK" or button == "left_thumb")
  local RIGHT_CLICK = (button == "R3" or button == "thumbright" or button == "RSTICK" or button == "right_thumb")
  if LEFT_CLICK or RIGHT_CLICK then
    local p = party[active]
    if p then
      local ALL = {"warrior", "cleric", "bard", "mage"}
      if LEFT_CLICK then
        CONTENT.latch_left = not CONTENT.latch_left
        if CONTENT.latch_left then
          CONTENT.latched_wet = p.xwet or 0
          CONTENT.latched_dly = p.dly  or 0
          for _, v in ipairs(ALL) do
            engine[v .. "_xwet"](CONTENT.latched_wet)
            engine[v .. "_dly" ](CONTENT.latched_dly)
          end
        end
      else  -- right click
        CONTENT.latch_right = not CONTENT.latch_right
        if CONTENT.latch_right then
          local r = CUTOFF_RANGE[p.class] or {min = 300, max = 6000}
          CONTENT.latched_cutoff = p.cutoff or (r.min * (r.max / r.min) ^ 0.5)
          CONTENT.latched_res    = p.resonance or 0.20
          for _, v in ipairs(ALL) do
            engine[v .. "_cutoff"](CONTENT.latched_cutoff)
            engine[v .. "_res"   ](CONTENT.latched_res)
          end
        end
      end
    end
    redraw(); return
  end
  -- SELECT toggles JAM mode from any non-modal state (overworld/battle/menu/etc).
  -- Skipped in TITLE/CUTSCENE/ENDING/VOYAGE to avoid breaking those scripted flows.
  if button == "SELECT"
     and game_state ~= "TITLE" and game_state ~= "CUTSCENE"
     and game_state ~= "ENDING" and game_state ~= "VOYAGE" then
    if game_state == "JAM" then
      game_state = jam_prev_state or "OVERWORLD"
      jam_prev_state = nil
    else
      jam_prev_state = game_state
      game_state = "JAM"
    end
    redraw()
    return
  end
  if game_state == "TITLE" then
    if button == "A" or button == "START" then
      if TITLE.idx == 1 then
        -- Continue: try to load. If no save, fall back to a flash + stay on title.
        if load_game() then
          game_state = "OVERWORLD"
          params:set("clock_tempo", OVERWORLD_BPM)
          engine.drone_amp(0)
          update_camera()
          redraw()
          return
        else
          TITLE.flash_text = "No save found"
          TITLE.flash_ticks = 24
          redraw()
          return
        end
      end
      -- New Game (default)
      game_state = "CUTSCENE"
      cutscene_idx = 1
      CONTENT.cutscene_panel_start = tick
      intro_step = 0
      params:set("clock_tempo", INTRO_BPM)
      redraw()
    end
  elseif game_state == "CUTSCENE" then
    if button == "A" or button == "B" or button == "START" then
      cutscene_idx = cutscene_idx + 1
      CONTENT.cutscene_panel_start = tick
      if cutscene_idx > #CUTSCENE_LINES then
        game_state = "OVERWORLD"
        params:set("clock_tempo", OVERWORLD_BPM)
        engine.drone_amp(0)
        update_camera()
      end
      redraw()
    end
  elseif game_state == "ENDING" then
    if button == "A" or button == "B" or button == "START" then
      ending_idx = ending_idx + 1
      if ending_idx > #ENDING_LINES then
        -- return to title; player can start a new run with all instruments retained
        game_state = "TITLE"
        params:set("clock_tempo", INTRO_BPM)
        engine.drone_amp(0)
      end
      redraw()
    end
  elseif game_state == "OVERWORLD" then
    if button == "A" then
      local npc = find_facing_npc()
      if npc then start_dialogue(npc) end
    elseif button == "L1" then
      set_active(active - 1)
    elseif button == "R1" then
      set_active(active + 1)
    elseif button == "START" then
      game_state = "MENU"
      menu_idx = 1
      redraw()
    end
  elseif game_state == "MENU" then
    if button == "B" or button == "START" then
      game_state = "OVERWORLD"
      redraw()
    elseif button == "A" then
      local opt = MENU_OPTIONS[menu_idx]
      if opt == "Save Game" then
        save_game()
      elseif opt == "Load Game" then
        load_game()
      elseif opt == "Party Status" then
        status_idx = active or 1
        game_state = "STATUS"
      elseif opt == "Equipment" then
        equip_idx = active or 1
        equip_choice = 1
        game_state = "EQUIP"
      elseif opt == "Items" then
        game_state = "ITEMS"
      elseif opt == "Party" then
        game_state = "PARTYSEL"
      elseif opt == "Quests" then
        game_state = "QUESTS"
      elseif opt == "Bestiary" then
        game_state = "BESTIARY"
      elseif opt == "Shards" then
        game_state = "SHARDS"
      elseif opt == "Jam Pad" then
        enter_jam_pad()
      elseif opt == "Debug" then
        debug_visible = not debug_visible
      elseif opt == "Resume" then
        game_state = "OVERWORLD"
      end
      redraw()
    end
  elseif game_state == "STATUS" then
    if button == "L1" then
      status_idx = ((status_idx - 2) % #party) + 1
      redraw()
    elseif button == "R1" then
      status_idx = (status_idx % #party) + 1
      redraw()
    elseif button == "A" or button == "B" or button == "START" then
      game_state = "MENU"
      redraw()
    end
  elseif game_state == "EQUIP" then
    if button == "L1" then
      equip_idx = ((equip_idx - 2) % #party) + 1
      equip_choice = 1
      redraw()
    elseif button == "R1" then
      equip_idx = (equip_idx % #party) + 1
      equip_choice = 1
      redraw()
    elseif button == "A" then
      local p = party[equip_idx]
      local list = INST.owned_for(p.class)
      if list[equip_choice] then
        equipped[p.class] = list[equip_choice]
        local inst = INSTRUMENTS[list[equip_choice]]
        if inst then
          CONTENT.flash_text = "Equipped: " .. inst.name
          CONTENT.flash_ticks = 24
        end
      end
      redraw()
    elseif button == "B" or button == "START" then
      game_state = "MENU"
      redraw()
    end
  elseif game_state == "SHOP" then
    if button == "A" then
      local id = SHOP.order[SHOP.idx]
      local it = SHOP.items[id]
      local price = it and (QUESTS.hens.discount and math.floor(it.cost * 0.75) or it.cost) or 0
      if it and SHOP.gold >= price then
        SHOP.gold = SHOP.gold - price
        SHOP.inv[id] = SHOP.inv[id] + 1
        SHOP.flash_text = "+1 " .. it.name
        SHOP.flash_ticks = 24
      else
        SHOP.flash_text = "Not enough gold"
        SHOP.flash_ticks = 24
      end
      redraw()
    elseif button == "B" or button == "START" then
      game_state = "OVERWORLD"
      redraw()
    end
  elseif game_state == "ITEMS" or game_state == "QUESTS" or game_state == "BESTIARY" or game_state == "SHARDS" then
    if button == "A" or button == "B" or button == "START" then
      game_state = "MENU"; redraw()
    end
  elseif game_state == "PARTYSEL" then
    if button == "L1" then set_active(active - 1); redraw()
    elseif button == "R1" then set_active(active + 1); redraw()
    elseif button == "A" then
      -- Swap focused recruit with party[active] (if recruit has joined)
      local idx = CONTENT.partysel_focus
      local r = CONTENT.recruits[idx]
      if r and r.joined then
        local active_p = party[active]
        local recruit_p = r.party_data
        if not recruit_p then
          -- first time joining: build party entry from template
          recruit_p = {
            class=r.class, spd=r.spd, atb=0, queued="ATK",
            note_idx=11, note_lo=8, note_hi=20,
            cutoff=2000, resonance=0.30,
            hp=r.hp_max, hp_max=r.hp_max, mp=r.mp_max, mp_max=r.mp_max,
            atk=r.atk, def=r.def, mag=r.mag,
            level=1, xp=0, xp_total=0,
            alive=true, shield=false, buffed=false, blocking=false,
            last_fire=-99, last_hit=-99,
            stick={lx=0,ly=0,rx=0,ry=0}, xwet=0, dly=0,
          }
        end
        party[active] = recruit_p
        -- Stash displaced member back into the recruits roster (preserves stats)
        CONTENT.recruits[idx] = {
          class=active_p.class, spd=active_p.spd,
          hp_max=active_p.hp_max, mp_max=active_p.mp_max,
          atk=active_p.atk, def=active_p.def, mag=active_p.mag,
          blurb=r.blurb, joined=true, party_data=active_p,
        }
        redraw()
      end
    elseif button == "B" or button == "START" then
      game_state = "MENU"; redraw()
    end
  elseif game_state == "JAM" then
    -- L1/R1: cycle which voice the sticks edit.
    -- A: toggle FX latch on BOTH sticks (snap & hold cutoff/res/wet/dly
    --    across all 4 voices); press again to release.
    -- X: cycle the unlocked scale mode (moved off A).
    -- B: exit back to previous state.
    if button == "L1" then set_active(active - 1)
    elseif button == "R1" then set_active(active + 1)
    elseif button == "A" then
      local p = party[active]
      if p then
        local ALL = {"warrior", "cleric", "bard", "mage"}
        -- Toggle: if either side is currently latched, releasing both;
        -- otherwise latch both with the active voice's current values.
        local any_on = CONTENT.latch_left or CONTENT.latch_right
        if any_on then
          CONTENT.latch_left = false
          CONTENT.latch_right = false
        else
          CONTENT.latch_left = true
          CONTENT.latch_right = true
          CONTENT.latched_wet = p.xwet or 0
          CONTENT.latched_dly = p.dly  or 0
          local r = CUTOFF_RANGE[p.class] or {min = 300, max = 6000}
          CONTENT.latched_cutoff = p.cutoff or (r.min * (r.max / r.min) ^ 0.5)
          CONTENT.latched_res    = p.resonance or 0.20
          for _, v in ipairs(ALL) do
            engine[v .. "_xwet"  ](CONTENT.latched_wet)
            engine[v .. "_dly"   ](CONTENT.latched_dly)
            engine[v .. "_cutoff"](CONTENT.latched_cutoff)
            engine[v .. "_res"   ](CONTENT.latched_res)
          end
        end
        redraw()
      end
    elseif button == "X" then
      -- Cycle scale mode (was on A; now lives here so A can latch).
      local cur = JAM.mode
      local idx = 1
      for i, m in ipairs(JAM.mode_order) do if m == cur then idx = i; break end end
      local n = #JAM.mode_order
      JAM.mode = JAM.mode_order[(idx % n) + 1]
      redraw()
    elseif button == "B" or button == "START" then
      game_state = jam_prev_state or "OVERWORLD"
      jam_prev_state = nil
      redraw()
    end
  elseif game_state == "DIALOGUE" then
    if button == "A" or button == "B" then advance_dialogue() end
  elseif game_state == "BATTLE" then
    if button == "START" and enemy and enemy.invincible then
      -- Exit Jam Pad practice mode back to overworld
      enemy = nil
      battle_outcome = nil
      game_state = "OVERWORLD"
      params:set("clock_tempo", OVERWORLD_BPM)
      redraw()
      return
    end
    if button == "SELECT" then set_active(active + 1)
    elseif button == "L1" then set_active(active - 1)
    elseif button == "R1" then set_active(active + 1)
    elseif button == "A" or button == "B" or button == "X" or button == "Y" then
      queue_action(button)
    end
  elseif game_state == "BATTLE_END" then
    if button == "A" then exit_battle() end
  end
end

function gamepad.analog(sensor_axis, val, half_reso)
  if debug_visible and (sensor_axis == "triggerleft" or sensor_axis == "triggerright") then
    last_input = sensor_axis .. " " .. string.format("%.2f", val / half_reso)
    last_input_at = tick
  end
  if sensor_axis == "triggerleft" then
    -- TOGGLE: rising-edge of trigger pull flips BPM-edit mode on/off.
    -- This avoids controller trigger drift sticking the modifier in either state.
    local now_pressed = (val / half_reso) > 0.2  -- need a meaningful pull
    if now_pressed and not _trigger_prev then
      l2_held = not l2_held
      redraw()
    end
    _trigger_prev = now_pressed
    return
  end
  if game_state ~= "BATTLE" and game_state ~= "OVERWORLD" and game_state ~= "DIALOGUE" and game_state ~= "JAM" then return end
  local p = party[active]
  if not p then return end
  -- Pass 39: stick latches. L3 freezes the left stick (wet + delay);
  -- R3 freezes the right stick (cutoff + resonance). When latched, the
  -- engine keeps whatever value was last sent — stick movement is ignored
  -- on that side until the latch is released.
  if (sensor_axis == "righty" or sensor_axis == "rightx") and CONTENT.latch_right then return end
  if (sensor_axis == "lefty"  or sensor_axis == "leftx")  and CONTENT.latch_left  then return end
  -- Each axis writes to the active character's latched stick state AND drives
  -- that voice's engine effect. Switching voices doesn't reset anything because
  -- each member has their own stick table + their own engine voice slot.
  local n = val / half_reso
  if sensor_axis == "righty" then
    p.stick.ry = n
    local m = -n
    local r = CUTOFF_RANGE[p.class]
    local cutoff = r.min * (r.max / r.min) ^ ((m + 1) / 2)
    p.cutoff = cutoff
    engine[(((p.class == "engineer" and "mage") or (p.class == "mathwiz" and "bard") or (p.class == "drummer" and "warrior") or p.class)) .. "_cutoff"](cutoff)
  elseif sensor_axis == "rightx" then
    p.stick.rx = n
    -- Resonance: 0.05 .. 0.50 (was 0.05..0.90 — caused clipping at extremes)
    local res = 0.05 + ((n + 1) / 2) * 0.45
    p.resonance = res
    engine[(((p.class == "engineer" and "mage") or (p.class == "mathwiz" and "bard") or (p.class == "drummer" and "warrior") or p.class)) .. "_res"](res)
  elseif sensor_axis == "lefty" then
    p.stick.ly = n
    -- left stick Y: extra reverb on active voice (push up to engage)
    local wet = math.max(0, -n)        -- 0..1, only positive direction adds
    p.xwet = wet
    engine[(((p.class == "engineer" and "mage") or (p.class == "mathwiz" and "bard") or (p.class == "drummer" and "warrior") or p.class)) .. "_xwet"](wet)
  elseif sensor_axis == "leftx" then
    p.stick.lx = n
    -- left stick X: per-class-syncopated delay amount on active voice.
    -- Each class's delay sits at a different feedback ceiling so the
    -- band's repeats overlap polyrhythmically instead of doubling up.
    -- (Engine doesn't expose per-voice delay TIME, so we vary AMOUNT
    --  + bias per class to imply different rhythmic divisions.)
    local raw = math.max(0, n)         -- 0..1, only positive direction adds
    local DLY_CEIL = {
      mage    = 0.55,   -- light, on-the-eighth feel
      cleric  = 0.85,   -- big tail, half-note repeats
      warrior = 0.40,   -- short percussive slap
      bard    = 0.70,   -- triplet-feel sustain
      engineer= 0.55, mathwiz = 0.70, drummer = 0.40,  -- inherit voice family
    }
    local DLY_BIAS = {
      mage    = 0.10, cleric  = 0.20, warrior = 0.05,
      bard    = 0.15, engineer= 0.10, mathwiz = 0.15, drummer = 0.05,
    }
    local ceil_v = DLY_CEIL[p.class] or 0.60
    local bias   = DLY_BIAS[p.class] or 0.10
    local dly    = (raw > 0.05) and (bias + raw * (ceil_v - bias)) or 0
    p.dly = dly
    engine[(((p.class == "engineer" and "mage") or (p.class == "mathwiz" and "bard") or (p.class == "drummer" and "warrior") or p.class)) .. "_dly"](dly)
  end
end

-- ============================================================ NORNS HOOKS

function init()
  params:set("clock_tempo", OVERWORLD_BPM)
  math.randomseed(os.time())
  engine.drone_freq(DRONE_FREQ_HZ)
  engine.drone_cutoff(700)
  engine.drone_amp(0)
  init_party()

  -- ── Pass 47: per-voice synth params for the norns PARAMS menu ──
  -- These let you tweak each voice's filter/FX from the standard norns
  -- params browser AND map any of them to your MPK's knobs (long-press
  -- the knob in the params menu → CC LEARN → twist the MPK knob).
  -- Setter sends the engine command live, so changes take effect instantly.
  params:add_separator("synth_quest_voices", "SYNTH QUEST — voices")
  for _, v in ipairs({"mage", "cleric", "warrior", "bard"}) do
    params:add_group("sq_" .. v, v:upper(), 4)
    params:add_control(v .. "_cutoff_p", v .. " cutoff",
      controlspec.new(200, 10000, 'exp', 1, 2000, 'Hz'))
    params:set_action(v .. "_cutoff_p", function(x) engine[v .. "_cutoff"](x) end)
    params:add_control(v .. "_res_p", v .. " resonance",
      controlspec.new(0.05, 0.50, 'lin', 0.01, 0.20, ''))
    params:set_action(v .. "_res_p", function(x) engine[v .. "_res"](x) end)
    params:add_control(v .. "_wet_p", v .. " reverb",
      controlspec.new(0, 1, 'lin', 0.01, 0.0, ''))
    params:set_action(v .. "_wet_p", function(x) engine[v .. "_xwet"](x) end)
    params:add_control(v .. "_dly_p", v .. " delay",
      controlspec.new(0, 1, 'lin', 0.01, 0.0, ''))
    params:set_action(v .. "_dly_p", function(x) engine[v .. "_dly"](x) end)
  end
  params:add_separator("synth_quest_midi", "SYNTH QUEST — midi")
  params:add_option("midi_voice_p", "MIDI note voice",
    {"bard", "mage", "cleric", "warrior"}, 1)
  params:set_action("midi_voice_p", function(idx)
    local names = {"bard", "mage", "cleric", "warrior"}
    CONTENT.midi_voice = names[idx]
  end)

  -- ── Pass 36: MIDI input (Akai MPK or any class-compliant controller) ──
  -- Notes are routed to a dedicated voice (default: bard, Alder's lute).
  -- 4 knobs map to that voice's FX params:
  --   CC 70 → cutoff (200..6000 Hz log-scaled)
  --   CC 71 → resonance (0.05..0.50)
  --   CC 74 → reverb send (0..1)
  --   CC 71 → delay send  (set CC 73 in firmware if you'd like)
  --   CC 73 → delay send  (0..1)
  -- The MPK's typical bank-A knob CCs are 70-77; remap by editing MIDI_CC.
  -- Held LED-footprint indicator: any MIDI activity flickers a tiny dot
  -- in the top-right corner so you can see the controller is alive.
  CONTENT.midi_voice = "bard"
  CONTENT.midi_active_t = -99
  local MIDI_CC = { cutoff = 70, res = 71, wet = 74, dly = 73 }
  -- Helper: resolve which engine-voice name to use for a given party class.
  -- Recruit classes alias to their voice family (engineer→mage etc).
  local function voice_for_class(cls)
    if cls == "engineer" then return "mage"
    elseif cls == "mathwiz" then return "bard"
    elseif cls == "drummer" then return "warrior"
    end
    return cls or "bard"
  end
  midi_in = midi.connect(1)
  midi_in.event = function(data)
    local d = midi.to_msg(data)
    -- Notes still play through the dedicated MIDI voice (default bard) so
    -- you can layer melodies under whatever the party is doing.
    local note_voice = voice_for_class(CONTENT.midi_voice or "bard")
    -- Knobs (cutoff/res/wet/delay) act on the *selected* party member's
    -- voice — i.e. whichever character is active right now.
    local sel_p = party[active]
    local sel_voice = voice_for_class(sel_p and sel_p.class or "bard")
    if d.type == "note_on" and d.vel > 0 then
      local freq = midi_to_freq(d.note)
      local vel = math.max(0.05, math.min(0.95, d.vel / 127))
      -- In JAM mode the four party SynthDefs act as a 4-voice polyphonic
      -- pool: each new note steals the oldest voice in round-robin order
      -- (warrior → cleric → bard → mage → warrior …). Hold up to 4 notes
      -- at once; a 5th note replaces the longest-held voice. Timbre
      -- varies as the cycle rotates (intentional — you hear the band).
      -- Outside JAM, notes go through the dedicated MIDI voice.
      local v = note_voice
      if game_state == "JAM" then
        local POLY = {"warrior", "cleric", "bard", "mage"}
        CONTENT.midi_rr = ((CONTENT.midi_rr or 0) % 4) + 1
        v = POLY[CONTENT.midi_rr]
      end
      engine["trig_" .. v](freq, vel * 0.85, 0.005, 0.45, 0.35)
      CONTENT.midi_active_t = tick
    elseif d.type == "cc" then
      local val = d.val / 127
      -- Respect stick-FX latches (Pass 40): if the corresponding side is
      -- latched, MPK knob input for those FX is ignored too.
      if d.cc == MIDI_CC.cutoff and not CONTENT.latch_right then
        local r = CUTOFF_RANGE[sel_p and sel_p.class] or {min = 300, max = 6000}
        local cutoff = r.min * (r.max / r.min) ^ val
        if sel_p then sel_p.cutoff = cutoff end
        engine[sel_voice .. "_cutoff"](cutoff)
      elseif d.cc == MIDI_CC.res and not CONTENT.latch_right then
        local res = 0.05 + val * 0.45
        if sel_p then sel_p.resonance = res end
        engine[sel_voice .. "_res"](res)
      elseif d.cc == MIDI_CC.wet and not CONTENT.latch_left then
        if sel_p then sel_p.xwet = val end
        engine[sel_voice .. "_xwet"](val)
      elseif d.cc == MIDI_CC.dly and not CONTENT.latch_left then
        local dly = val * 0.7
        if sel_p then sel_p.dly = dly end
        engine[sel_voice .. "_dly"](dly)
      end
      CONTENT.midi_active_t = tick
    end
  end

  clock_id = clock.run(function()
    while true do
      clock.sync(1/4)
      tick = tick + 1
      if save_flash_ticks > 0 then save_flash_ticks = save_flash_ticks - 1 end
      if SHOP.flash_ticks > 0 then SHOP.flash_ticks = SHOP.flash_ticks - 1 end
      if levelup_flash_ticks > 0 then levelup_flash_ticks = levelup_flash_ticks - 1 end
      if region_label_ticks > 0 then region_label_ticks = region_label_ticks - 1 end
      -- universal flash-text countdown (chest pickup / equip toast / etc.)
      if CONTENT.flash_ticks > 0 then CONTENT.flash_ticks = CONTENT.flash_ticks - 1 end
      if game_state == "BATTLE" then
        tick_battle()
      elseif game_state == "BATTLE_END" then
        battle_end_ticks = battle_end_ticks - 1
        if battle_outcome == "VICTORY" then tick_victory_music() end
      elseif game_state == "OVERWORLD" or game_state == "DIALOGUE" then
        tick_overworld_music()
        if inn_rest_ticks > 0 then inn_rest_ticks = inn_rest_ticks - 1 end
        if tower_locked_ticks > 0 then tower_locked_ticks = tower_locked_ticks - 1 end
      elseif game_state == "JAM" then
        -- Pass 38: JAM mode is silent — no looping music underneath, so
        -- the player can play freely on the MPK / sticks without the
        -- prior state's pattern bleeding through.
      elseif game_state == "SHOP" then
        tick_shop_music()
      elseif game_state == "TITLE" then
        tick_title_music()
      elseif game_state == "CUTSCENE" then
        tick_intro_music()
      elseif game_state == "VOYAGE" then
        tick_overworld_music()  -- gentle music continues during sea travel
        voyage_ticks = voyage_ticks - 1
        if voyage_ticks <= 0 then
          travel_to(voyage_target_map, voyage_target_x, voyage_target_y)
          game_state = "OVERWORLD"
        end
      end
      redraw()
    end
  end)
  redraw()
end

function key(n, z)
  if z == 0 then return end
  if game_state == "TITLE" then
    if n == 2 then
      TITLE.idx = 1 - TITLE.idx
      redraw()
    elseif n == 3 then
      if TITLE.idx == 1 then
        if load_game() then
          game_state = "OVERWORLD"
          params:set("clock_tempo", OVERWORLD_BPM)
          engine.drone_amp(0)
          update_camera()
          redraw()
          return
        else
          TITLE.flash_text = "No save found"
          TITLE.flash_ticks = 24
          redraw()
          return
        end
      end
      game_state = "CUTSCENE"
      cutscene_idx = 1
      CONTENT.cutscene_panel_start = tick
      intro_step = 0
      params:set("clock_tempo", INTRO_BPM)
      redraw()
    end
  elseif game_state == "ENDING" and (n == 2 or n == 3) then
    ending_idx = ending_idx + 1
    if ending_idx > #ENDING_LINES then
      game_state = "TITLE"
      engine.drone_amp(0)
    end
    redraw()
  elseif game_state == "CUTSCENE" and (n == 2 or n == 3) then
    cutscene_idx = cutscene_idx + 1
    CONTENT.cutscene_panel_start = tick
    if cutscene_idx > #CUTSCENE_LINES then
      game_state = "OVERWORLD"
      engine.drone_amp(0)
      update_camera()
    end
    redraw()
  elseif game_state == "OVERWORLD" and n == 3 then
    local npc = find_facing_npc()
    if npc then start_dialogue(npc) end
  elseif game_state == "OVERWORLD" and n == 1 then
    game_state = "MENU"
    menu_idx = 1
    redraw()
  elseif game_state == "MENU" then
    if n == 1 then
      game_state = "OVERWORLD"
      redraw()
    elseif n == 3 then
      local opt = MENU_OPTIONS[menu_idx]
      if opt == "Save Game" then save_game()
      elseif opt == "Load Game" then load_game()
      elseif opt == "Party Status" then status_idx = active or 1; game_state = "STATUS"
      elseif opt == "Equipment" then equip_idx = active or 1; equip_choice = 1; game_state = "EQUIP"
      elseif opt == "Items" then game_state = "ITEMS"
      elseif opt == "Party" then game_state = "PARTYSEL"
      elseif opt == "Quests" then game_state = "QUESTS"
      elseif opt == "Bestiary" then game_state = "BESTIARY"
      elseif opt == "Shards" then game_state = "SHARDS"
      elseif opt == "Jam Pad" then enter_jam_pad()
      elseif opt == "Debug" then debug_visible = not debug_visible
      elseif opt == "Resume" then game_state = "OVERWORLD"
      end
      redraw()
    end
    -- (E2 scrolls cursor; see enc())
  elseif game_state == "STATUS" then
    if n == 2 then
      status_idx = ((status_idx - 2) % #party) + 1
      redraw()
    elseif n == 3 then
      status_idx = (status_idx % #party) + 1
      redraw()
    elseif n == 1 then
      game_state = "MENU"
      redraw()
    end
  elseif game_state == "EQUIP" then
    if n == 2 then
      equip_idx = ((equip_idx - 2) % #party) + 1
      equip_choice = 1
      redraw()
    elseif n == 3 then
      local p = party[equip_idx]
      local list = INST.owned_for(p.class)
      if list[equip_choice] then
        equipped[p.class] = list[equip_choice]
        local inst = INSTRUMENTS[list[equip_choice]]
        if inst then
          CONTENT.flash_text = "Equipped: " .. inst.name
          CONTENT.flash_ticks = 24
        end
      end
      redraw()
    elseif n == 1 then
      game_state = "MENU"
      redraw()
    end
  elseif game_state == "SHOP" then
    if n == 2 then
      SHOP.idx = ((SHOP.idx - 2) % #SHOP.order) + 1
      redraw()
    elseif n == 3 then
      local id = SHOP.order[SHOP.idx]
      local it = SHOP.items[id]
      local price = it and (QUESTS.hens.discount and math.floor(it.cost * 0.75) or it.cost) or 0
      if it and SHOP.gold >= price then
        SHOP.gold = SHOP.gold - price
        SHOP.inv[id] = SHOP.inv[id] + 1
        SHOP.flash_text = "+1 " .. it.name
        SHOP.flash_ticks = 24
      else
        SHOP.flash_text = "Not enough gold"
        SHOP.flash_ticks = 24
      end
      redraw()
    elseif n == 1 then
      game_state = "OVERWORLD"
      redraw()
    end
  elseif game_state == "DIALOGUE" and (n == 2 or n == 3) then
    advance_dialogue()
  elseif game_state == "BATTLE" then
    if n == 1 and enemy and enemy.invincible then
      -- K1 exits the Jam Pad practice mode
      enemy = nil
      battle_outcome = nil
      game_state = "OVERWORLD"
      params:set("clock_tempo", OVERWORLD_BPM)
      redraw()
      return
    end
    if n == 2 then set_active(active - 1)
    elseif n == 3 then set_active(active + 1)
    end
  elseif game_state == "BATTLE_END" and n == 3 then
    exit_battle()
  end
end

function enc(n, d)
  if game_state == "MENU" and n == 2 then
    menu_idx = ((menu_idx - 1 + d) % #MENU_OPTIONS) + 1
    redraw()
    return
  end
  -- (Battle BPM / Journey BPM enc-tweak removed; use L2 + dpad now.)
  if game_state == "EQUIP" and n == 2 then
    local p = party[equip_idx]
    local list = INST.owned_for(p.class)
    local cnt = math.max(1, #list)
    equip_choice = ((equip_choice - 1 + d) % cnt) + 1
    redraw()
    return
  end
  if game_state == "BATTLE" and n == 2 then
    local p = party[active]
    if not p.alive then return end
    local ca = CLASS_ACTIONS[p.class]
    local action_list = {ca.A, ca.B, ca.X, ca.Y}
    local cur = 1
    for i, a in ipairs(action_list) do if a == p.queued then cur = i end end
    p.queued = action_list[((cur - 1 + d) % 4) + 1]
    p.prev_queued = nil
    p.jamming = false
    redraw()
  end
end

function cleanup()
  if clock_id then clock.cancel(clock_id) end
  engine.drone_amp(0)
end

-- ============================================================ DRAWING — TILES

local TILE_DRAW
do
local function draw_grass(px, py, seed)
  -- region-aware grass with multi-pixel tufts (stable per-tile via seed,
  -- gentle 1-px sway driven by (tick + seed) so each tuft breathes slightly out of phase)
  local region = get_region(player.x)
  local a = (seed * 13) % 8
  local b = (seed * 7 + 3) % 8
  local c = (seed * 5 + 1) % 8
  local sway = ((tick + seed) % 32 < 16) and 0 or 1
  a = (a + sway) % 8
  if region == "woods" then
    -- mossy dark with little leaf-litter dots
    screen.level(1)
    screen.pixel(px + a, py + 6); screen.pixel(px + a + 1, py + 6)
    screen.level(3)
    screen.pixel(px + b, py + 2); screen.pixel(px + b, py + 3)
    screen.pixel(px + c, py + 4)
    if (seed % 5) == 0 then
      screen.level(0)
      screen.pixel(px + 4, py + 4); screen.pixel(px + 5, py + 4)
    end
  elseif region == "coast" then
    -- bright, sun-bleached, occasional sand grain glint
    screen.level(4)
    screen.pixel(px + a, py + 5); screen.pixel(px + a + 1, py + 5)
    screen.level(2)
    screen.pixel(px + b, py + 1)
    screen.level(6)
    screen.pixel(px + c, py + 3)
    if (seed % 11) == 0 then
      screen.level(15)
      screen.pixel(px + 3, py + 6)
    end
  else
    -- village: warm green tufts as little V-shapes, occasional flower
    screen.level(3)
    screen.pixel(px + a, py + 6); screen.pixel(px + a + 1, py + 6)
    screen.pixel(px + a, py + 5); screen.pixel(px + a + 2, py + 5)
    screen.level(2)
    screen.pixel(px + b, py + 2); screen.pixel(px + b + 1, py + 3)
    if (seed % 7) == 0 then
      -- yellow flower (4 petals around bright center)
      screen.level(15)
      screen.pixel(px + 5, py + 4)
      screen.level(11)
      screen.pixel(px + 4, py + 4); screen.pixel(px + 6, py + 4)
      screen.pixel(px + 5, py + 3); screen.pixel(px + 5, py + 5)
    elseif (seed % 13) == 0 then
      -- red flower (single bright pixel)
      screen.level(13)
      screen.pixel(px + 2, py + 1); screen.pixel(px + 3, py + 1)
    end
  end
end

local function draw_tree(px, py)
  -- region-aware tree variant — now with proper trunks + textured canopies
  local region = get_region(player.x)
  if region == "woods" then
    -- pine: narrow stacked triangles + thin trunk
    screen.level(7)
    screen.move(px + 4, py); screen.line(px + 1, py + 3); screen.line(px + 7, py + 3)
    screen.close(); screen.fill()
    screen.level(9)
    screen.move(px + 4, py + 2); screen.line(px + 0, py + 5); screen.line(px + 8, py + 5)
    screen.close(); screen.fill()
    -- snow tips
    screen.level(15)
    screen.pixel(px + 4, py); screen.pixel(px + 1, py + 5); screen.pixel(px + 7, py + 5)
    -- trunk
    screen.level(4)
    screen.rect(px + 3, py + 5, 2, 3); screen.fill()
    screen.level(2)
    screen.pixel(px + 3, py + 6)
  elseif region == "coast" then
    -- palm: curved trunk + arching fronds + coconut cluster
    screen.level(5)
    screen.pixel(px + 3, py + 3); screen.pixel(px + 3, py + 4)
    screen.pixel(px + 4, py + 5); screen.pixel(px + 4, py + 6); screen.pixel(px + 4, py + 7)
    screen.level(3)
    screen.pixel(px + 4, py + 4); screen.pixel(px + 3, py + 5)
    -- fronds (4 arching strokes)
    screen.level(9)
    screen.move(px + 3, py + 2); screen.line(px, py + 1); screen.stroke()
    screen.move(px + 3, py + 2); screen.line(px + 1, py); screen.stroke()
    screen.move(px + 4, py + 2); screen.line(px + 7, py + 0); screen.stroke()
    screen.move(px + 4, py + 2); screen.line(px + 8, py + 2); screen.stroke()
    screen.move(px + 3, py + 3); screen.line(px, py + 4); screen.stroke()
    screen.move(px + 4, py + 3); screen.line(px + 7, py + 4); screen.stroke()
    -- coconuts cluster
    screen.level(13)
    screen.pixel(px + 3, py + 3); screen.pixel(px + 4, py + 3)
  else
    -- oak: full canopy with shading + visible trunk + gentle wind sway
    local sway = ((tick + px) % 48 < 24) and 0 or 1
    screen.level(7)  -- darker shadow side
    screen.move(px + 1, py + 4); screen.line(px + 4 + sway, py + 1); screen.line(px + 4, py + 5); screen.close(); screen.fill()
    screen.level(9)  -- lit side
    screen.move(px + 4 + sway, py + 1); screen.line(px + 7, py + 4); screen.line(px + 4, py + 5); screen.close(); screen.fill()
    -- canopy highlight
    screen.level(11)
    screen.pixel(px + 4 + sway, py + 1); screen.pixel(px + 5, py + 2)
    -- trunk
    screen.level(4)
    screen.rect(px + 3, py + 5, 2, 3); screen.fill()
    screen.level(2)
    screen.pixel(px + 3, py + 6)
  end
end

local function draw_path(px, py)
  -- packed-earth path with subtle pebble texture
  screen.level(5)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7)
  screen.rect(px + 1, py + 1, 6, 6); screen.fill()
  -- scattered pebbles
  screen.level(3)
  screen.pixel(px + 2, py + 3); screen.pixel(px + 5, py + 5); screen.pixel(px + 3, py + 6)
  screen.level(9)
  screen.pixel(px + 4, py + 2); screen.pixel(px + 6, py + 4)
end

local function draw_water(px, py, t)
  -- depth gradient + animated wave caps
  screen.level(2)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4)
  screen.rect(px, py + 1, 8, 6); screen.fill()
  screen.level(6)
  screen.rect(px, py + 3, 8, 3); screen.fill()
  -- moving wave caps (two staggered)
  local o = math.floor((t or 0) / 3) % 8
  screen.level(11)
  screen.pixel(px + ((1 + o) % 8), py + 2); screen.pixel(px + ((2 + o) % 8), py + 2)
  screen.level(15)
  screen.pixel(px + ((4 + o) % 8), py + 5); screen.pixel(px + ((5 + o) % 8), py + 5)
end

local function draw_wall(px, py)
  -- stone-block masonry: alternating bricks with mortar lines
  screen.level(8)
  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5)
  -- horizontal mortar at rows 3 and 6
  screen.move(px, py + 3); screen.line(px + 8, py + 3); screen.stroke()
  screen.move(px, py + 6); screen.line(px + 8, py + 6); screen.stroke()
  -- vertical mortar (offset between rows for brick pattern)
  screen.move(px + 4, py); screen.line(px + 4, py + 3); screen.stroke()
  screen.move(px + 2, py + 3); screen.line(px + 2, py + 6); screen.stroke()
  screen.move(px + 5, py + 3); screen.line(px + 5, py + 6); screen.stroke()
  screen.move(px + 4, py + 6); screen.line(px + 4, py + 8); screen.stroke()
  -- highlights (top edge of each brick)
  screen.level(11)
  screen.pixel(px + 1, py); screen.pixel(px + 5, py)
  screen.pixel(px + 1, py + 4); screen.pixel(px + 6, py + 4)
end

local function draw_door(px, py)
  screen.level(10)
  screen.rect(px, py, 8, 8)
  screen.fill()
  screen.level(2)
  screen.rect(px + 2, py + 2, 4, 5)
  screen.fill()
end

local function draw_cave(px, py, t)
  -- darker tile with arched opening
  screen.level(8)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- arched dark mouth
  screen.level(0)
  screen.move(px + 1, py + 7)
  screen.line(px + 1, py + 4)
  screen.line(px + 4, py + 1)
  screen.line(px + 7, py + 4)
  screen.line(px + 7, py + 7)
  screen.close()
  screen.fill()
  -- subtle "pull" - flickering pixel
  if (t % 8) < 4 then
    screen.level(15)
    screen.pixel(px + 4, py + 3)
  end
end

local function draw_cave2(px, py, t)
  -- darker forest cave; jagged opening (different shape from cave1)
  screen.level(6)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- jagged dark mouth
  screen.level(0)
  screen.move(px + 1, py + 7)
  screen.line(px + 2, py + 4)
  screen.line(px + 4, py + 2)
  screen.line(px + 6, py + 4)
  screen.line(px + 7, py + 7)
  screen.close()
  screen.fill()
  -- subtle pulse — different rhythm from cave1
  if (tick % 12) < 6 then
    screen.level(11)
    screen.pixel(px + 3, py + 5)
    screen.pixel(px + 5, py + 5)
  end
end

local function draw_sand(px, py, seed)
  -- light dotted sand tile
  screen.level(11)
  screen.rect(px, py, 8, 8)
  screen.fill()
  screen.level(7)
  local a = (seed * 11) % 8
  local b = (seed * 5 + 4) % 8
  screen.pixel(px + a, py + 3)
  screen.pixel(px + b, py + 6)
end

local function draw_cave3(px, py, t)
  -- coastal cavern: lighter, with sea-blue suggestion
  screen.level(9)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- arched mouth, slightly wider than cave1
  screen.level(0)
  screen.move(px, py + 7)
  screen.line(px + 1, py + 3)
  screen.line(px + 4, py + 1)
  screen.line(px + 7, py + 3)
  screen.line(px + 8, py + 7)
  screen.close()
  screen.fill()
  -- water shimmer at the base
  if (tick % 6) < 3 then
    screen.level(13)
    screen.pixel(px + 3, py + 6)
    screen.pixel(px + 5, py + 6)
  end
end

local function draw_boat(px, py)
  -- water background
  screen.level(3)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- hull
  screen.level(13)
  screen.move(px + 1, py + 5)
  screen.line(px + 7, py + 5)
  screen.line(px + 6, py + 7)
  screen.line(px + 2, py + 7)
  screen.close()
  screen.fill()
  -- mast
  screen.rect(px + 4, py + 1, 1, 4)
  screen.fill()
  -- sail
  screen.move(px + 4, py + 1)
  screen.line(px + 7, py + 4)
  screen.line(px + 4, py + 4)
  screen.close()
  screen.fill()
end

local function draw_cave4(px, py, t)
  -- exotic eastern cavern: warmer tone, ogival arch
  screen.level(7)
  screen.rect(px, py, 8, 8)
  screen.fill()
  screen.level(0)
  screen.move(px + 1, py + 7)
  screen.line(px + 1, py + 4)
  screen.line(px + 3, py + 1)
  screen.line(px + 5, py + 1)
  screen.line(px + 7, py + 4)
  screen.line(px + 7, py + 7)
  screen.close()
  screen.fill()
  if (tick % 10) < 5 then
    screen.level(15)
    screen.pixel(px + 4, py + 4)
  end
end

local function draw_inn(px, py)
  -- village inn: peaked roof + door + lit window
  -- ground / base
  screen.level(2)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- walls (timber)
  screen.level(7)
  screen.rect(px + 1, py + 4, 6, 4)
  screen.fill()
  -- roof (peaked)
  screen.level(11)
  screen.move(px,     py + 4)
  screen.line(px + 4, py)
  screen.line(px + 8, py + 4)
  screen.close()
  screen.fill()
  -- door
  screen.level(0)
  screen.rect(px + 3, py + 5, 2, 3)
  screen.fill()
  -- lit window (warm + flickers)
  if (tick % 14) < 10 then
    screen.level(13)
  else
    screen.level(11)
  end
  screen.pixel(px + 1, py + 5)
  screen.pixel(px + 6, py + 5)
  -- chimney smoke wisp (rises from peak, fades)
  local sm = (tick // 3) % 6
  screen.level(7)
  screen.pixel(px + 4, py - sm)
  screen.level(4)
  screen.pixel(px + 5, py - sm + 1)
end

local function draw_fountain(px, py, t)
  -- Village plaza fountain. Visual state matches narrative shard progress:
  -- 0 shards → dormant (dry basin, no spout, no sparkle)
  -- 1-3   → trickle (a little water, no spout)
  -- 4-6   → low spout, faint sparkle
  -- 7     → full spout, lively sparkle
  local n = 0; for _, v in pairs(shards) do if v then n = n + 1 end end
  -- grass under
  screen.level(2)
  screen.rect(px, py, 8, 8); screen.fill()
  -- basin (stone ring) — always there
  screen.level(7)
  screen.rect(px + 1, py + 4, 6, 3); screen.fill()
  screen.level(n >= 4 and 11 or 8)
  screen.move(px + 1, py + 4); screen.line(px + 7, py + 4); screen.stroke()
  -- water inside basin
  if n >= 1 then
    screen.level(n >= 7 and 13 or (n >= 4 and 11 or 5))
    screen.rect(px + 2, py + 5, 4, 1); screen.fill()
  else
    -- bone-dry: dark crack across the basin floor
    screen.level(2)
    screen.rect(px + 2, py + 5, 4, 1); screen.fill()
    screen.level(0); screen.pixel(px + 4, py + 5); screen.fill()
  end
  -- central spout (only after 4+ shards; full only after 7)
  if n >= 4 then
    local h = (n >= 7) and 4 or 2
    screen.level(n >= 7 and 15 or 11)
    screen.rect(px + 3, py + (5 - h), 2, h); screen.fill()
  end
  -- sparkle (varies per tick) — only after 4+ shards, brighter after 7
  if n >= 4 then
    local s = (t or 0) % 12
    if s < 6 then
      screen.level(n >= 7 and 15 or 11)
      screen.pixel(px + 1, py + 2); screen.pixel(px + 6, py + 3); screen.fill()
    else
      screen.level(n >= 7 and 13 or 8)
      screen.pixel(px + 2, py + 1); screen.pixel(px + 5, py + 2); screen.fill()
    end
  end
end

local function draw_tower(px, py, t)
  -- tall dark spire with a single ominous lit window
  -- ground
  screen.level(2)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- shadowed silhouette
  screen.level(0)
  screen.rect(px + 2, py, 4, 8)
  screen.fill()
  -- crenellations
  screen.level(11)
  screen.pixel(px + 2, py)
  screen.pixel(px + 4, py)
  screen.pixel(px + 5, py)
  -- lit window pulses
  if (t or 0) % 16 < 8 then
    screen.level(15)
  else
    screen.level(13)
  end
  screen.pixel(px + 3, py + 3)
  screen.pixel(px + 4, py + 3)
  -- dark base outline
  screen.level(7)
  screen.move(px + 1, py + 7)
  screen.line(px + 6, py + 7)
  screen.stroke()
end

local function draw_cave6(px, py, t)
  -- locrian crypt door — black archway with red glow
  screen.level(0)
  screen.rect(px, py, 8, 8)
  screen.fill()
  screen.level(2)
  screen.rect(px + 1, py + 2, 6, 6)
  screen.fill()
  screen.level(15)
  screen.move(px + 1, py + 7)
  screen.line(px + 1, py + 4)
  screen.line(px + 4, py + 1)
  screen.line(px + 7, py + 4)
  screen.line(px + 7, py + 7)
  screen.stroke()
  if (t or 0) % 12 < 6 then
    screen.level(15)
    screen.pixel(px + 4, py + 5)
  end
end

local function draw_cave7(px, py, t)
  -- Suno's chamber — same arch as cave6 but with shifting glyphs above
  screen.level(0)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- arch
  screen.level(11)
  screen.move(px + 1, py + 7)
  screen.line(px + 1, py + 3)
  screen.line(px + 4, py)
  screen.line(px + 7, py + 3)
  screen.line(px + 7, py + 7)
  screen.close()
  screen.fill()
  -- glowing core
  if (t or 0) % 8 < 4 then
    screen.level(15)
  else
    screen.level(11)
  end
  screen.rect(px + 3, py + 4, 2, 3)
  screen.fill()
  -- glyphs flickering above
  screen.level(7)
  if (t or 0) % 6 < 3 then
    screen.pixel(px + 2, py + 1)
    screen.pixel(px + 5, py + 1)
  else
    screen.pixel(px + 3, py + 1)
    screen.pixel(px + 4, py + 1)
  end
end

local function draw_cave5(px, py, t)
  -- frosted highland cavern: snow rim + dark ice arch
  -- snow apron
  screen.level(15)
  screen.rect(px, py + 6, 8, 2)
  screen.fill()
  -- granite face
  screen.level(7)
  screen.rect(px, py, 8, 6)
  screen.fill()
  -- dark arch entrance
  screen.level(0)
  screen.move(px + 2, py + 6)
  screen.line(px + 2, py + 3)
  screen.line(px + 4, py + 1)
  screen.line(px + 6, py + 3)
  screen.line(px + 6, py + 6)
  screen.close()
  screen.fill()
  -- icicles glint
  if (tick % 16) < 8 then
    screen.level(13)
    screen.pixel(px + 3, py + 5)
    screen.pixel(px + 5, py + 4)
  end
end

local function draw_mountain_pass(px, py)
  -- snowy peaks framing a passage
  screen.level(2)
  screen.rect(px, py, 8, 8)
  screen.fill()
  -- left peak
  screen.level(11)
  screen.move(px,     py + 7)
  screen.line(px + 2, py + 1)
  screen.line(px + 4, py + 7)
  screen.close()
  screen.fill()
  -- right peak
  screen.move(px + 4, py + 7)
  screen.line(px + 6, py + 2)
  screen.line(px + 8, py + 7)
  screen.close()
  screen.fill()
  -- snow caps
  screen.level(15)
  screen.pixel(px + 2, py + 1)
  screen.pixel(px + 6, py + 2)
  -- pass mouth (dark center)
  screen.level(0)
  screen.rect(px + 3, py + 5, 2, 3)
  screen.fill()
end

TILE_DRAW = {
  [0] = draw_grass,
  [1] = draw_tree,
  [2] = draw_path,
  [3] = draw_water,
  [4] = draw_wall,
  [5] = draw_door,
  [6] = draw_cave,
  [7] = draw_cave2,
  [8] = draw_sand,
  [9] = draw_cave3,
  [10] = draw_boat,
  [11] = draw_cave4,
  [12] = draw_shop,
  [13] = draw_inn,
  [14] = draw_fountain,
  [15] = draw_mountain_pass,
  [16] = draw_cave5,
  [17] = draw_exit_door,
  [18] = draw_tower,
  [19] = draw_cave6,
  [20] = draw_cave7,
}
end  -- tile draws

-- Pass 14 tile draws: registered as anonymous functions on TILE_DRAW directly
-- so they don't add to the main-chunk's local register count.
TILE_DRAW[12] = function(px, py)
  -- Item shop building: timber walls, striped awning, sign, open door, coin in window.
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(6); screen.rect(px + 1, py + 3, 6, 5); screen.fill()
  screen.level(13); screen.rect(px, py + 2, 8, 1); screen.fill()
  screen.level(8);  screen.rect(px, py + 3, 8, 1); screen.fill()
  screen.level(11); screen.pixel(px + 1, py + 5); screen.pixel(px + 1, py + 6)
  screen.level(0);  screen.rect(px + 3, py + 5, 2, 3); screen.fill()
  screen.level(11); screen.pixel(px + 6, py + 5); screen.pixel(px + 6, py + 6); screen.fill()
end

TILE_DRAW.floor = function(px, py)
  -- Wood-plank interior floor (used to override outdoor grass when inside an interior).
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  if (px + py) % 16 == 0 then
    screen.level(3); screen.pixel(px + 1, py + 1); screen.pixel(px + 5, py + 4); screen.fill()
  end
end

TILE_DRAW[17] = function(px, py)
  -- Interior exit door: dark frame with a warm strip at the bottom.
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7); screen.rect(px + 1, py + 1, 6, 6); screen.fill()
  screen.level(0); screen.rect(px + 2, py + 2, 4, 4); screen.fill()
  screen.level(13); screen.rect(px, py + 7, 8, 1); screen.fill()
end

TILE_DRAW[21] = function(px, py)
  -- Bed: mattress + pillow + headboard.
  screen.level(3);  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(9);  screen.rect(px + 1, py + 2, 6, 5); screen.fill()
  screen.level(13); screen.rect(px + 1, py + 1, 3, 2); screen.fill()
  screen.level(5);  screen.rect(px, py, 8, 1); screen.fill()
end

TILE_DRAW[22] = function(px, py)
  -- Counter: dark wood with metal lip.
  screen.level(2);  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7);  screen.rect(px, py + 2, 8, 4); screen.fill()
  screen.level(11); screen.rect(px, py + 2, 8, 1); screen.fill()
  screen.level(3);  screen.pixel(px + 2, py + 4); screen.pixel(px + 5, py + 4); screen.fill()
end

TILE_DRAW[23] = function(px, py)
  -- Woven rug: warm field with cross-stitch dots; walkable.
  screen.level(8);  screen.rect(px, py, 8, 8); screen.fill()
  screen.level(11); screen.rect(px + 1, py + 1, 6, 6); screen.stroke()
  screen.level(13); screen.pixel(px + 3, py + 3); screen.pixel(px + 4, py + 4); screen.fill()
end

TILE_DRAW[24] = function(px, py)
  -- Wall lantern: post + glowing bulb that flickers.
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5); screen.move(px + 4, py + 7); screen.line(px + 4, py + 4); screen.stroke()
  local lit = (tick % 12) < 8
  screen.level(lit and 14 or 11)
  screen.circle(px + 4, py + 3, 2); screen.fill()
  if lit then screen.level(7); screen.circle(px + 4, py + 3, 3); screen.stroke() end
end

-- Cave-floor render (used to override tile 0 inside cave interior). Stable
-- per-tile speckle pattern so the floor isn't visually jumpy.
-- Generic stable per-tile speckler used by the themed cave-floor variants.
-- base = background brightness; speckle = dot brightness; n = dot count.
TILE_DRAW.cavefloor = function(px, py, seed)
  screen.level(1); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(3)
  local s = (seed or 0) * 2654435761
  for i = 0, 4 do
    local r = (s + i * 1103515245) % 64
    screen.pixel(px + (r % 8), py + ((r / 8) % 8))
  end
  screen.fill()
end

-- ── Themed cave-interior floors (one per cave map id 7-12) ─────────────────
-- echoes (cave 1, map 7): plain dark stone, sparse speckle
TILE_DRAW.cavefloor_echoes = TILE_DRAW.cavefloor

-- grove (cave 2, map 8): mossy floor; greenish speckle + an occasional
-- tiny "leaf litter" cluster
TILE_DRAW.cavefloor_grove = function(px, py, seed)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5)
  local s = (seed or 0) * 2654435761
  for i = 0, 5 do
    local r = (s + i * 1103515245) % 64
    screen.pixel(px + (r % 8), py + ((r / 8) % 8))
  end
  screen.fill()
  if (s % 11) == 0 then
    screen.level(7); screen.pixel(px + 3, py + 4); screen.pixel(px + 4, py + 5); screen.fill()
  end
end

-- grotto (cave 3, map 9): wet stone; bright drips that flicker on/off
TILE_DRAW.cavefloor_grotto = function(px, py, seed)
  screen.level(1); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4)
  local s = (seed or 0) * 2654435761
  for i = 0, 3 do
    local r = (s + i * 1103515245) % 64
    screen.pixel(px + (r % 8), py + ((r / 8) % 8))
  end
  screen.fill()
  -- occasional drip puddle (animated shimmer)
  if (s % 9) == 0 then
    local lit = (tick % 8) < 4
    screen.level(lit and 11 or 8); screen.pixel(px + 5, py + 6); screen.fill()
  end
end

-- dune (cave 4, map 10): warm sandstone; horizontal grain
TILE_DRAW.cavefloor_dune = function(px, py, seed)
  screen.level(4); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7); screen.rect(px, py + 3, 8, 1); screen.fill()
  screen.level(6); screen.rect(px, py + 6, 8, 1); screen.fill()
  -- occasional sand drift
  local s = (seed or 0) * 2654435761
  if (s % 7) == 0 then
    screen.level(8); screen.pixel(px + 1, py + 1); screen.pixel(px + 5, py + 5); screen.fill()
  end
end

-- frost (cave 5, map 11): icy floor; pale base + cold gleam
TILE_DRAW.cavefloor_frost = function(px, py, seed)
  screen.level(3); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7)
  local s = (seed or 0) * 2654435761
  for i = 0, 3 do
    local r = (s + i * 1103515245) % 64
    screen.pixel(px + (r % 8), py + ((r / 8) % 8))
  end
  screen.fill()
  -- crystal gleam (slow flicker)
  if (s % 8) == 0 then
    local g = ((tick + (s % 7)) % 18) < 9
    screen.level(g and 15 or 11); screen.pixel(px + 4, py + 2); screen.fill()
  end
end

-- hollow (side dungeon, map 12): earthy den, dark with rootlets
TILE_DRAW.cavefloor_hollow = function(px, py, seed)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4)
  local s = (seed or 0) * 2654435761
  -- rootlet streak (one diagonal per tile, stable per seed)
  local sx_off = s % 4
  screen.move(px + sx_off, py); screen.line(px + sx_off + 4, py + 6); screen.stroke()
  if (s % 13) == 0 then
    screen.level(7); screen.pixel(px + 6, py + 6); screen.fill()
  end
end

-- ── Themed cave walls (override tile 4 inside cave interiors) ──────────────
-- echoes (cave 1): hard dark stone with chiseled blocks
TILE_DRAW.cavewall_echoes = function(px, py)
  screen.level(4); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(2); screen.move(px, py + 3); screen.line(px + 8, py + 3); screen.stroke()
  screen.level(2); screen.move(px + 4, py); screen.line(px + 4, py + 3); screen.stroke()
  screen.level(2); screen.move(px + 1, py + 3); screen.line(px + 1, py + 8); screen.stroke()
  screen.level(2); screen.move(px + 6, py + 3); screen.line(px + 6, py + 8); screen.stroke()
end

-- grove (cave 2): stone with vines + moss patches
TILE_DRAW.cavewall_grove = function(px, py, seed)
  screen.level(4); screen.rect(px, py, 8, 8); screen.fill()
  -- moss splotches (greenish patches)
  screen.level(6); screen.rect(px + 1, py + 1, 2, 2); screen.fill()
  screen.level(5); screen.rect(px + 4, py + 4, 3, 2); screen.fill()
  -- vine streaks (vertical squiggles)
  local s = (seed or 0) * 2654435761
  local vx = (s % 4) + 2
  screen.level(7); screen.move(px + vx, py); screen.line(px + vx, py + 8); screen.stroke()
  screen.level(8); screen.pixel(px + vx + 1, py + 3); screen.pixel(px + vx - 1, py + 5); screen.fill()
end

-- grotto (cave 3): wet stone with drip lines
TILE_DRAW.cavewall_grotto = function(px, py, seed)
  screen.level(3); screen.rect(px, py, 8, 8); screen.fill()
  -- vertical drip streaks (darker)
  local s = (seed or 0) * 2654435761
  local dx = s % 8
  screen.level(1); screen.move(px + dx, py); screen.line(px + dx, py + 8); screen.stroke()
  -- a single bright drop near the bottom (animated)
  if ((tick + dx) % 12) < 4 then
    screen.level(13); screen.pixel(px + dx, py + 7); screen.fill()
  end
end

-- dune (cave 4): warm sandstone with horizontal stripes
TILE_DRAW.cavewall_dune = function(px, py)
  screen.level(5); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(8); screen.rect(px, py + 1, 8, 1); screen.fill()
  screen.level(7); screen.rect(px, py + 4, 8, 1); screen.fill()
  screen.level(6); screen.rect(px, py + 7, 8, 1); screen.fill()
  -- carved glyph dot (stable position per tile)
  screen.level(11); screen.pixel(px + 3, py + 5); screen.fill()
end

-- frost (cave 5): icy crystals, blue-cool gleam
TILE_DRAW.cavewall_frost = function(px, py, seed)
  screen.level(6); screen.rect(px, py, 8, 8); screen.fill()
  -- crystal facets (diagonal lines in pairs)
  screen.level(11); screen.move(px + 1, py); screen.line(px + 6, py + 5); screen.stroke()
  screen.level(11); screen.move(px + 6, py); screen.line(px + 1, py + 5); screen.stroke()
  -- gleam on the high facet (slow flicker)
  local s = (seed or 0) * 2654435761
  if ((tick + (s % 5)) % 16) < 8 then
    screen.level(15); screen.pixel(px + 3, py + 2); screen.pixel(px + 4, py + 3); screen.fill()
  end
end

-- hollow (side dungeon): earthy roots, packed dirt
TILE_DRAW.cavewall_hollow = function(px, py, seed)
  screen.level(3); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5); screen.move(px, py + 4); screen.line(px + 8, py + 4); screen.stroke()
  -- root tendrils (two diagonal scratches)
  screen.level(2); screen.move(px + 1, py + 1); screen.line(px + 6, py + 6); screen.stroke()
  screen.level(2); screen.move(px + 6, py + 2); screen.line(px + 2, py + 7); screen.stroke()
  -- a tiny pebble or two (stable per seed)
  local s = (seed or 0) * 2654435761
  if (s % 6) == 0 then
    screen.level(7); screen.pixel(px + 5, py + 5); screen.fill()
  end
end

-- Side-dungeon entry (tile 36) — a small hollow in the woods, dim mouth.
TILE_DRAW[36] = function(px, py, t)
  -- mossy ground
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4); screen.pixel(px + 1, py + 6); screen.pixel(px + 5, py + 7); screen.fill()
  -- low arched mouth set into the earth
  screen.level(5); screen.move(px + 1, py + 6); screen.line(px + 4, py + 2); screen.line(px + 7, py + 6); screen.stroke()
  -- dark interior
  screen.level(0); screen.rect(px + 2, py + 4, 4, 3); screen.fill()
  -- faint ember in the dark
  if ((t or 0) % 14) < 7 then
    screen.level(11); screen.pixel(px + 4, py + 5); screen.fill()
  end
end

-- Boss arena marker (tile 27): dark rune-ringed slab with a slow pulse.
TILE_DRAW[27] = function(px, py, t)
  screen.level(1); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(4); screen.circle(px + 4, py + 4, 3); screen.stroke()
  local pulse = ((t or 0) % 16) / 16
  screen.level(8 + math.floor(pulse * 6))
  screen.pixel(px + 4, py + 4); screen.pixel(px + 3, py + 4)
  screen.pixel(px + 4, py + 3); screen.pixel(px + 4, py + 5); screen.fill()
end

-- ── Themed walls (override tile 4 inside inn / shop interior) ───────────────
-- Inn walls: warm timber boards with vertical grain + occasional knot.
TILE_DRAW.inn_wall = function(px, py, seed)
  screen.level(5); screen.rect(px, py, 8, 8); screen.fill()             -- base timber
  screen.level(3)                                                        -- darker grain
  screen.move(px + 2, py); screen.line(px + 2, py + 8); screen.stroke()
  screen.move(px + 5, py); screen.line(px + 5, py + 8); screen.stroke()
  -- knots: stable per-tile via seed
  local s = (seed or 0) * 2654435761
  if (s % 5) == 0 then
    screen.level(2); screen.circle(px + (s % 6) + 1, py + ((s / 6) % 6) + 1, 1); screen.fill()
  end
  -- top trim molding
  screen.level(7); screen.rect(px, py, 8, 1); screen.fill()
end

-- Shop walls: tan plaster with a wood wainscot strip at the bottom + sign nail.
TILE_DRAW.shop_wall = function(px, py, seed)
  screen.level(7); screen.rect(px, py, 8, 8); screen.fill()             -- pale plaster
  screen.level(5); screen.rect(px, py + 6, 8, 2); screen.fill()         -- wainscot
  screen.level(3); screen.move(px, py + 6); screen.line(px + 8, py + 6); screen.stroke()
  -- random plaster speckle
  local s = (seed or 0) * 2654435761
  if (s % 4) == 0 then
    screen.level(5); screen.pixel(px + (s % 7), py + ((s / 7) % 5) + 1); screen.fill()
  end
end

-- Tile 30 — Inn fireplace. Stone surround + animated flame.
TILE_DRAW[30] = function(px, py, t)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()             -- back wall (cool dark)
  screen.level(5); screen.rect(px, py + 6, 8, 2); screen.fill()         -- hearth lip
  -- stone surround
  screen.level(7); screen.rect(px, py, 1, 6); screen.fill()
  screen.level(7); screen.rect(px + 7, py, 1, 6); screen.fill()
  screen.level(7); screen.rect(px, py, 8, 1); screen.fill()
  -- inner cavity (dark, with logs)
  screen.level(0); screen.rect(px + 1, py + 1, 6, 5); screen.fill()
  screen.level(4); screen.rect(px + 2, py + 4, 4, 1); screen.fill()    -- log
  -- animated flame
  local flick = (t or 0) % 6
  local h = 2 + (flick % 3)
  screen.level(13); screen.rect(px + 3, py + 5 - h, 2, h); screen.fill()
  screen.level(15); screen.rect(px + 3, py + 4 - math.floor(h/2), 1, 1); screen.fill()
  -- ember glow on hearth lip
  screen.level(8 + ((t or 0) % 4))
  screen.pixel(px + 4, py + 6); screen.fill()
end

-- Tile 31 — Shop wares-shelf (wall fixture). Plank bracket + small parcels.
TILE_DRAW[31] = function(px, py)
  -- plaster behind (matches shop wall)
  screen.level(7); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5); screen.rect(px, py + 6, 8, 2); screen.fill()
  -- shelves: two horizontal planks
  screen.level(3); screen.rect(px, py + 2, 8, 1); screen.fill()
  screen.level(3); screen.rect(px, py + 5, 8, 1); screen.fill()
  -- wares on each shelf (small colored boxes / bottles)
  screen.level(11); screen.rect(px + 1, py + 1, 1, 1); screen.fill()
  screen.level(13); screen.rect(px + 4, py + 1, 2, 1); screen.fill()
  screen.level(9);  screen.rect(px + 6, py,     1, 2); screen.fill()
  screen.level(13); screen.rect(px + 1, py + 4, 1, 1); screen.fill()
  screen.level(11); screen.rect(px + 3, py + 3, 2, 2); screen.fill()
  screen.level(9);  screen.rect(px + 6, py + 4, 1, 1); screen.fill()
end

-- Tile 32 — Dining table (inn). Square top with a mug + plate.
TILE_DRAW[32] = function(px, py)
  -- floor underneath (planks)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  -- table top
  screen.level(7); screen.rect(px, py + 1, 8, 5); screen.fill()
  screen.level(11); screen.rect(px, py + 1, 8, 1); screen.fill()       -- top edge highlight
  -- legs
  screen.level(4); screen.rect(px + 1, py + 6, 1, 2); screen.fill()
  screen.level(4); screen.rect(px + 6, py + 6, 1, 2); screen.fill()
  -- plate (left) + mug (right)
  screen.level(15); screen.rect(px + 1, py + 2, 2, 2); screen.fill()
  screen.level(13); screen.rect(px + 5, py + 2, 2, 2); screen.fill()
  screen.level(15); screen.pixel(px + 5, py + 2); screen.pixel(px + 6, py + 2); screen.fill()
end

-- Tile 33 — Brass till on shop counter.
TILE_DRAW[33] = function(px, py)
  -- counter base (matches counter tile)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(7); screen.rect(px, py + 4, 8, 4); screen.fill()
  screen.level(11); screen.rect(px, py + 4, 8, 1); screen.fill()
  -- brass till body
  screen.level(13); screen.rect(px + 1, py + 1, 6, 3); screen.fill()
  screen.level(11); screen.rect(px + 1, py + 1, 6, 1); screen.fill()    -- top lip
  -- coin slot
  screen.level(0); screen.rect(px + 3, py + 2, 2, 1); screen.fill()
  -- small register key
  screen.level(15); screen.pixel(px + 6, py + 3); screen.fill()
end

-- Tile 38 — Wall painting / framed picture (mounted on inn back wall)
TILE_DRAW[38] = function(px, py, t)
  -- inn-wall background (warm timber) so it blends with adjacent walls
  screen.level(5); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(3); screen.move(px, py + 8); screen.line(px + 8, py + 8); screen.stroke()
  -- gold frame
  screen.level(13); screen.rect(px + 1, py + 1, 6, 5); screen.fill()
  -- painted scene inside (tiny landscape: hill + dot moon)
  screen.level(2); screen.rect(px + 2, py + 2, 4, 3); screen.fill()
  screen.level(7); screen.move(px + 2, py + 4); screen.line(px + 4, py + 3); screen.line(px + 6, py + 4); screen.stroke()
  screen.level(15); screen.pixel(px + 5, py + 2); screen.fill()
  -- subtle frame highlight that pulses (glint of candlelight)
  if ((t or 0) % 16) < 8 then
    screen.level(15); screen.pixel(px + 1, py + 1); screen.fill()
  end
end

-- Tile 39 — Potted plant (decorative, blocking)
TILE_DRAW[39] = function(px, py, t)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  -- pot (dark clay)
  screen.level(4); screen.rect(px + 2, py + 5, 4, 3); screen.fill()
  screen.level(7); screen.rect(px + 2, py + 5, 4, 1); screen.fill()
  -- foliage (rounded blob with leafy pixels)
  screen.level(7); screen.circle(px + 4, py + 3, 3); screen.fill()
  screen.level(11); screen.pixel(px + 3, py + 1); screen.pixel(px + 5, py + 2); screen.fill()
  -- subtle leaf-sway frond
  if ((t or 0) % 32) < 16 then
    screen.level(11); screen.pixel(px + 4, py); screen.fill()
  end
end

-- Tile 40 — Wooden chair (blocking decorative)
TILE_DRAW[40] = function(px, py)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  -- backrest
  screen.level(5); screen.rect(px + 2, py + 1, 4, 3); screen.fill()
  screen.level(3); screen.move(px + 2, py + 3); screen.line(px + 6, py + 3); screen.stroke()
  -- seat
  screen.level(7); screen.rect(px + 1, py + 4, 6, 1); screen.fill()
  -- legs
  screen.level(4); screen.rect(px + 1, py + 5, 1, 3); screen.fill()
  screen.level(4); screen.rect(px + 6, py + 5, 1, 3); screen.fill()
end

-- Tile 41 — Hanging sign (above shop door, says "OPEN")
TILE_DRAW[41] = function(px, py, t)
  -- shop-wall background
  screen.level(7); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5); screen.rect(px, py + 6, 8, 2); screen.fill()
  -- chain (vertical line at top center)
  screen.level(4); screen.move(px + 4, py); screen.line(px + 4, py + 2); screen.stroke()
  -- sign body (warm wood)
  screen.level(11); screen.rect(px + 1, py + 2, 6, 4); screen.fill()
  screen.level(7); screen.move(px + 1, py + 2); screen.line(px + 7, py + 2); screen.stroke()
  -- "$" glyph (coin mark)
  screen.level(15); screen.pixel(px + 4, py + 3); screen.pixel(px + 4, py + 4); screen.fill()
  screen.level(15); screen.pixel(px + 3, py + 3); screen.pixel(px + 5, py + 4); screen.fill()
  -- subtle sway (1-px shift every other beat)
  if ((t or 0) % 16) < 8 then
    screen.level(8); screen.pixel(px + 5, py + 5); screen.fill()
  end
end

-- Tile 45 — Wood-plank pier (walkable; extends out over water tiles).
TILE_DRAW[45] = function(px, py)
  -- water glint underneath shows through at the edges
  screen.level(3); screen.rect(px, py, 8, 8); screen.fill()
  -- plank body (4 horizontal planks)
  screen.level(7); screen.rect(px, py + 1, 8, 6); screen.fill()
  screen.level(5)
  screen.move(px, py + 3); screen.line(px + 8, py + 3); screen.stroke()
  screen.move(px, py + 5); screen.line(px + 8, py + 5); screen.stroke()
  -- plank seams (vertical darker lines)
  screen.level(3)
  screen.move(px + 3, py + 1); screen.line(px + 3, py + 7); screen.stroke()
  -- nail dots
  screen.level(11); screen.pixel(px + 1, py + 2); screen.pixel(px + 6, py + 6); screen.fill()
end

-- Tile 43 — The Old Resonator (Sergei's ruined silencing tower in the marsh).
-- A leaning, partly-collapsed stone tower with a faint humming light at the
-- crack — a tone he never quite tuned out.
TILE_DRAW[43] = function(px, py, t)
  -- ground patch
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  -- cracked stone tower body (slight lean to the right)
  screen.level(5); screen.rect(px + 1, py + 2, 5, 6); screen.fill()
  screen.level(3); screen.rect(px + 6, py + 5, 1, 3); screen.fill()    -- cantilevered remnant
  -- crown stones (irregular)
  screen.level(7); screen.rect(px + 1, py + 1, 1, 1); screen.fill()
  screen.level(7); screen.rect(px + 4, py, 1, 2); screen.fill()
  -- big diagonal crack down the front (dark)
  screen.level(2); screen.move(px + 3, py + 2); screen.line(px + 1, py + 7); screen.stroke()
  -- a faint humming light at the crack (Sergei's resonance, never fully off)
  if ((t or 0) % 14) < 7 then
    screen.level(13); screen.pixel(px + 2, py + 5); screen.fill()
  else
    screen.level(8); screen.pixel(px + 2, py + 5); screen.fill()
  end
  -- small antenna remnant on top
  screen.level(7); screen.move(px + 3, py); screen.line(px + 3, py - 1); screen.stroke()
end

-- Tile 42 — Broom leaning against the wall (shop)
TILE_DRAW[42] = function(px, py)
  screen.level(7); screen.rect(px, py, 8, 8); screen.fill()
  screen.level(5); screen.rect(px, py + 6, 8, 2); screen.fill()
  -- broom handle (diagonal)
  screen.level(4); screen.move(px + 2, py + 7); screen.line(px + 6, py + 1); screen.stroke()
  -- bristle bunch at the base
  screen.level(8); screen.rect(px + 1, py + 6, 3, 2); screen.fill()
  screen.level(11); screen.move(px + 1, py + 6); screen.line(px + 4, py + 8); screen.stroke()
end

-- Tile 35 — Barrel of goods.
TILE_DRAW[35] = function(px, py)
  screen.level(2); screen.rect(px, py, 8, 8); screen.fill()
  -- barrel body (dark wood)
  screen.level(5); screen.rect(px + 1, py + 1, 6, 6); screen.fill()
  -- iron hoops
  screen.level(2); screen.rect(px + 1, py + 2, 6, 1); screen.fill()
  screen.level(2); screen.rect(px + 1, py + 5, 6, 1); screen.fill()
  -- top rim
  screen.level(11); screen.rect(px + 1, py + 1, 6, 1); screen.fill()
  -- contents peeking (a pair of grain pixels)
  screen.level(13); screen.pixel(px + 3, py + 1); screen.pixel(px + 4, py + 1); screen.fill()
end

local SPRITE_BY_CLASS
do

-- Render 8×8 bitmap sprite. data = flat array[64] of brightness 0-15, 0=transparent.
-- If flip is true, render horizontally mirrored (used for left vs right facing).
-- Groups pixels by level so we do at most 15 fill() calls per sprite.
local function draw_sprite(sx, sy, data, flip)
  for lev = 1, 15 do
    local any = false
    for i = 1, 64 do
      if data[i] == lev then
        local cx = (i-1) % 8
        if flip then cx = 7 - cx end
        screen.pixel(sx + cx, sy + math.floor((i-1)/8))
        any = true
      end
    end
    if any then screen.level(lev); screen.fill() end
  end
end

-- Walk frame: 0 = stand, 1 = mid-step (legs alternate every ~0.25 sec)
local function walk_frame() return math.floor(tick / 8) % 2 end

-- ──────────────────────────────────────────────────────────────────────────
-- Player sprites — 8×8 bitmaps with 4 facing directions × 2 walk frames.
-- "right" is drawn; "left" is rendered by horizontal mirror flag at draw time.
-- Brightness levels chosen so silhouettes pop on the textured grass tiles.
-- ──────────────────────────────────────────────────────────────────────────

-- ── ALDER (Bard / protagonist) ─────────────────────────────────────────────
-- Wide-brim hat with feather, tunic, lute slung at hip
local ALDER = {
  down = {
    [0] = {
       0, 0, 0,15, 0, 0, 0, 0,  -- feather
       0,11,11,11,11,11, 0, 0,  -- hat
      11,11,11,11,11,11,11, 0,  -- hat brim
       0, 0,13,13,13, 0, 0, 0,  -- face
       0, 0, 0, 0, 0,14, 0, 0,  -- lute neck
       0, 9, 9, 9, 9,14,14, 0,  -- tunic + lute body
       0, 9, 9, 9, 9,14, 0, 0,  -- lower tunic + lute
       0, 5, 5, 0, 5, 5, 0, 0,  -- boots
    },
    [1] = {
       0, 0, 0,15, 0, 0, 0, 0,
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,
       0, 0,13,13,13, 0, 0, 0,
       0, 0, 0, 0, 0,14, 0, 0,
       0, 9, 9, 9, 9,14,14, 0,
       0, 9, 9, 9, 9,14, 0, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
  },
  up = {
    [0] = {
       0,15, 0, 0, 0, 0, 0, 0,  -- feather tip back
       0,11,11,11,11,11, 0, 0,  -- hat
      11,11,11,11,11,11,11, 0,  -- hat brim
       0, 0, 8, 8, 8, 0, 0, 0,  -- back of head (no face)
       0, 9, 9, 9, 9, 9, 0, 0,  -- tunic shoulders
       0, 9, 9, 9, 9, 9, 0, 0,
       0, 9, 9, 9, 9, 9, 0, 0,
       0, 5, 5, 0, 5, 5, 0, 0,
    },
    [1] = {
       0,15, 0, 0, 0, 0, 0, 0,
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,
       0, 0, 8, 8, 8, 0, 0, 0,
       0, 9, 9, 9, 9, 9, 0, 0,
       0, 9, 9, 9, 9, 9, 0, 0,
       0, 9, 9, 9, 9, 9, 0, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
  },
  right = {
    [0] = {
       0, 0, 0, 0, 0,15, 0, 0,  -- feather trailing
       0, 0,11,11,11,11, 0, 0,  -- hat
       0,11,11,11,11,11,11, 0,  -- hat brim
       0, 0,13,13,13, 0, 0, 0,  -- face profile
       0, 0, 9, 9, 9, 9,14, 0,  -- tunic + lute swung in front
       0, 0, 9, 9, 9, 9,14, 0,
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
    [1] = {
       0, 0, 0, 0, 0,15, 0, 0,
       0, 0,11,11,11,11, 0, 0,
       0,11,11,11,11,11,11, 0,
       0, 0,13,13,13, 0, 0, 0,
       0, 0, 9, 9, 9, 9,14, 0,
       0, 0, 9, 9, 9, 9,14, 0,
       0, 0, 9, 9, 9, 0, 0, 0,
       0, 5, 0, 0, 5, 0, 0, 0,
    },
  },
}

-- ── MIEL (Cleric / Princess) ───────────────────────────────────────────────
-- Three-spike crown, flowing gown, healing gem
local MIEL = {
  down = {
    [0] = {
       0,15, 0,15, 0,15, 0, 0,  -- crown spikes (asymmetric for elegance)
       0,12,12,12,12,12, 0, 0,  -- crown band
       9, 9, 0,13,13, 0, 9, 9,  -- hair sides + face
       0, 9, 0,13,13, 0, 9, 0,  -- hair flowing down + face
       0,11,11,15,11,11, 0, 0,  -- gown + gem
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,  -- gown widens
       0, 8, 0, 0, 0, 8, 0, 0,
    },
    [1] = {
       0,15, 0,15, 0,15, 0, 0,
       0,12,12,12,12,12, 0, 0,
       9, 9, 0,13,13, 0, 9, 9,
       0, 9, 0,13,13, 0, 9, 0,
       0,11,11,15,11,11, 0, 0,
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,
       0, 0, 8, 0, 8, 0, 0, 0,
    },
  },
  up = {
    [0] = {
       0,15, 0,15, 0,15, 0, 0,
       0,12,12,12,12,12, 0, 0,
       9, 9, 9, 9, 9, 9, 9, 0,  -- back hair full
       0, 9, 9, 9, 9, 9, 0, 0,  -- hair
       0,11,11,11,11,11, 0, 0,
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,
       0, 8, 0, 0, 0, 8, 0, 0,
    },
    [1] = {
       0,15, 0,15, 0,15, 0, 0,
       0,12,12,12,12,12, 0, 0,
       9, 9, 9, 9, 9, 9, 9, 0,
       0, 9, 9, 9, 9, 9, 0, 0,
       0,11,11,11,11,11, 0, 0,
       0,11,11,11,11,11, 0, 0,
      11,11,11,11,11,11,11, 0,
       0, 0, 8, 0, 8, 0, 0, 0,
    },
  },
  right = {
    [0] = {
       0,15, 0,15, 0,15, 0, 0,
       0,12,12,12,12,12, 0, 0,
       0, 9, 0,13,13, 0, 9, 9,  -- profile face + hair trail
       0, 0, 0,13,13, 0, 9, 0,
       0,11,11,15,11,11,11, 0,
       0,11,11,11,11,11,11, 0,
       0, 0,11,11,11,11,11, 0,
       0, 0, 0, 0, 0, 8, 0, 0,
    },
    [1] = {
       0,15, 0,15, 0,15, 0, 0,
       0,12,12,12,12,12, 0, 0,
       0, 9, 0,13,13, 0, 9, 9,
       0, 0, 0,13,13, 0, 9, 0,
       0,11,11,15,11,11,11, 0,
       0,11,11,11,11,11,11, 0,
       0, 0,11,11,11,11,11, 0,
       0, 0, 0, 8, 0, 0, 0, 0,
    },
  },
}

-- ── STROM (Warrior / ex-commander) ─────────────────────────────────────────
-- Crested helm with visor slit, heavy plate, broad-shouldered
local STROM = {
  down = {
    [0] = {
       0, 0,13, 0,13, 0, 0, 0,  -- helm crest tufts
       0,10,10,10,10,10, 0, 0,  -- helm top
      10,10,10,10,10,10,10, 0,  -- helm full
       0,10, 1, 1, 1,10,10, 0,  -- visor slit
      13, 8, 8, 8, 8, 8, 8,13,  -- pauldrons + chest
       0, 8, 8,13, 8, 8, 0, 0,  -- chest with rivet
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 5, 5, 0, 5, 5, 0, 0,
    },
    [1] = {
       0, 0,13, 0,13, 0, 0, 0,
       0,10,10,10,10,10, 0, 0,
      10,10,10,10,10,10,10, 0,
       0,10, 1, 1, 1,10,10, 0,
      13, 8, 8, 8, 8, 8, 8,13,
       0, 8, 8,13, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 0, 5, 5, 5, 0, 0, 0,
    },
  },
  up = {
    [0] = {
       0, 0,13, 0,13, 0, 0, 0,
       0,10,10,10,10,10, 0, 0,
      10,10,10,10,10,10,10, 0,
       0,10,10,10,10,10,10, 0,
      13, 8, 8, 8, 8, 8, 8,13,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 5, 5, 0, 5, 5, 0, 0,
    },
    [1] = {
       0, 0,13, 0,13, 0, 0, 0,
       0,10,10,10,10,10, 0, 0,
      10,10,10,10,10,10,10, 0,
       0,10,10,10,10,10,10, 0,
      13, 8, 8, 8, 8, 8, 8,13,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 0, 5, 5, 5, 0, 0, 0,
    },
  },
  right = {
    [0] = {
       0, 0, 0,13, 0, 0, 0, 0,  -- crest tufted right
       0, 0,10,10,10,10, 0, 0,
       0,10,10,10,10,10,10, 0,
       0, 0,10, 1, 1,10,10, 0,
       0, 8, 8, 8, 8, 8, 8,13,  -- shield-arm forward
       0, 0, 8, 8,13, 8, 8, 0,
       0, 0, 8, 8, 8, 8, 0, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
    [1] = {
       0, 0, 0,13, 0, 0, 0, 0,
       0, 0,10,10,10,10, 0, 0,
       0,10,10,10,10,10,10, 0,
       0, 0,10, 1, 1,10,10, 0,
       0, 8, 8, 8, 8, 8, 8,13,
       0, 0, 8, 8,13, 8, 8, 0,
       0, 0, 8, 8, 8, 8, 0, 0,
       0, 5, 0, 0, 5, 0, 0, 0,
    },
  },
}

-- ── DIEGUES (Mage / scholar) ───────────────────────────────────────────────
-- Tall pointed hat, deep robe, glowing staff
local DIEGUES = {
  down = {
    [0] = {
       0, 0, 0, 0, 9, 0, 0, 0,
       0, 0, 0, 9, 9, 9, 0, 0,
       0, 0, 9, 9, 9, 9, 0, 0,
       0, 0,13,13,13, 0,15, 0,  -- face + staff glow
       0, 7, 7, 7, 7, 7,15, 0,  -- robe + staff
       0, 7, 7, 7, 7, 7,15, 0,
      15, 7, 7, 7, 7, 7,15, 0,  -- robe widens, glow at hem
       0, 0, 5, 0, 5, 0,15, 0,  -- boots + staff base glow
    },
    [1] = {
       0, 0, 0, 0, 9, 0, 0, 0,
       0, 0, 0, 9, 9, 9, 0, 0,
       0, 0, 9, 9, 9, 9, 0, 0,
       0, 0,13,13,13, 0,15, 0,
       0, 7, 7, 7, 7, 7,15, 0,
       0, 7, 7, 7, 7, 7,15, 0,
      15, 7, 7, 7, 7, 7,15, 0,
       0, 5, 0, 0, 0, 5,15, 0,
    },
  },
  up = {
    [0] = {
       0, 0, 0, 0, 9, 0, 0, 0,
       0, 0, 0, 9, 9, 9, 0, 0,
       0, 0, 9, 9, 9, 9, 0, 0,
       0, 0, 7, 7, 7, 0,15, 0,  -- back of head/robe
       0, 7, 7, 7, 7, 7,15, 0,
       0, 7, 7, 7, 7, 7,15, 0,
      15, 7, 7, 7, 7, 7,15, 0,
       0, 0, 5, 0, 5, 0,15, 0,
    },
    [1] = {
       0, 0, 0, 0, 9, 0, 0, 0,
       0, 0, 0, 9, 9, 9, 0, 0,
       0, 0, 9, 9, 9, 9, 0, 0,
       0, 0, 7, 7, 7, 0,15, 0,
       0, 7, 7, 7, 7, 7,15, 0,
       0, 7, 7, 7, 7, 7,15, 0,
      15, 7, 7, 7, 7, 7,15, 0,
       0, 5, 0, 0, 0, 5,15, 0,
    },
  },
  right = {
    [0] = {
       0, 0, 0, 0, 0, 0, 9, 0,  -- hat tip leans into direction
       0, 0, 0, 0, 0, 9, 9, 0,
       0, 0, 0, 0, 9, 9, 9, 9,
       0, 0,13,13,13,13, 0, 0,  -- face profile
       0,15, 7, 7, 7, 7, 7, 0,  -- staff held forward + robe
       0,15, 7, 7, 7, 7, 7, 0,
       0,15, 7, 7, 7, 7, 7, 0,
       0,15, 0, 5, 5, 0, 0, 0,
    },
    [1] = {
       0, 0, 0, 0, 0, 0, 9, 0,
       0, 0, 0, 0, 0, 9, 9, 0,
       0, 0, 0, 0, 9, 9, 9, 9,
       0, 0,13,13,13,13, 0, 0,
       0,15, 7, 7, 7, 7, 7, 0,
       0,15, 7, 7, 7, 7, 7, 0,
       0,15, 7, 7, 7, 7, 7, 0,
       0,15, 5, 0, 0, 5, 0, 0,
    },
  },
}

-- Pick the right facing variant (mirror "right" for "left")
local function dirframe(set)
  local f = walk_frame()
  local face = player.facing
  if face == "left" then return set.right[f], true end
  if face == "right" then return set.right[f], false end
  if face == "up" then return set.up[f], false end
  return set.down[f], false
end

local function draw_mage_sprite(sx, sy)
  local data, flip = dirframe(DIEGUES); draw_sprite(sx, sy, data, flip)
end
local function draw_cleric_sprite(sx, sy)
  local data, flip = dirframe(MIEL); draw_sprite(sx, sy, data, flip)
end
local function draw_warrior_sprite(sx, sy)
  local data, flip = dirframe(STROM); draw_sprite(sx, sy, data, flip)
end
local function draw_bard_sprite(sx, sy)
  local data, flip = dirframe(ALDER); draw_sprite(sx, sy, data, flip)
end

-- ── SERGEI (Engineer) ───────────────────────────────────────────────────
-- Headphones, short cap, work coveralls with belt + tool dangling at hip
local SERGEI = {
  down = {
    [0] = {
       0, 0, 7, 7, 7, 7, 0, 0,  -- cap
       0,15, 7, 7, 7, 7,15, 0,  -- headphones cups (bright sides)
       0, 0, 0,13,13, 0, 0, 0,  -- face
       0, 0, 0,13,13, 0, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,  -- coveralls top
       0, 8,11, 8,11, 8,15, 0,  -- belt buttons + wrench glint at hip
       0, 8, 8, 8, 8, 8,15, 0,
       0, 5, 5, 0, 5, 5, 0, 0,
    },
    [1] = {
       0, 0, 7, 7, 7, 7, 0, 0,
       0,15, 7, 7, 7, 7,15, 0,
       0, 0, 0,13,13, 0, 0, 0,
       0, 0, 0,13,13, 0, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8,11, 8,11, 8,15, 0,
       0, 8, 8, 8, 8, 8,15, 0,
       0, 0, 5, 5, 5, 0, 0, 0,
    },
  },
  up = {
    [0] = {
       0, 0, 7, 7, 7, 7, 0, 0,
       0,15, 7, 7, 7, 7,15, 0,
       0, 0, 4, 4, 4, 4, 0, 0,  -- back of head (no face)
       0, 0, 4, 4, 4, 4, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 5, 5, 0, 5, 5, 0, 0,
    },
    [1] = {
       0, 0, 7, 7, 7, 7, 0, 0,
       0,15, 7, 7, 7, 7,15, 0,
       0, 0, 4, 4, 4, 4, 0, 0,
       0, 0, 4, 4, 4, 4, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 8, 8, 8, 8, 8, 0, 0,
       0, 0, 5, 5, 5, 0, 0, 0,
    },
  },
  right = {
    [0] = {
       0, 0, 0, 7, 7, 7, 0, 0,
       0, 0,15, 7, 7, 7,15, 0,
       0, 0, 0, 0,13,13, 0, 0,
       0, 0, 0, 0,13,13, 0, 0,
       0, 0, 8, 8, 8, 8,15, 0,  -- wrench held forward
       0, 0, 8,11, 8, 8,15, 0,
       0, 0, 8, 8, 8, 8, 0, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
    [1] = {
       0, 0, 0, 7, 7, 7, 0, 0,
       0, 0,15, 7, 7, 7,15, 0,
       0, 0, 0, 0,13,13, 0, 0,
       0, 0, 0, 0,13,13, 0, 0,
       0, 0, 8, 8, 8, 8,15, 0,
       0, 0, 8,11, 8, 8,15, 0,
       0, 0, 8, 8, 8, 8, 0, 0,
       0, 5, 0, 0, 5, 0, 0, 0,
    },
  },
}

-- ── PAJ (Math Wizard) ───────────────────────────────────────────────────
-- Bobbed hair w/ headband + glasses (bright glint), academic robe, tablet held
local PAJ = {
  down = {
    [0] = {
       0,11,11,11,11,11,11, 0,  -- bobbed hair top
      11, 4, 4, 4, 4, 4, 4,11,  -- hair sides
      11, 4,15,15,15,15, 4,11,  -- headband
       0, 4,15, 0, 0,15, 4, 0,  -- glasses (bright lenses)
       0, 0, 0,13,13, 0, 0, 0,  -- face / lower
       0, 5, 5,13,13, 5, 5, 0,  -- robe shoulders + neck
       0, 5,13, 5, 5,13, 5, 0,  -- robe + tablet glow
       0, 0, 5, 0, 5, 0, 0, 0,
    },
    [1] = {
       0,11,11,11,11,11,11, 0,
      11, 4, 4, 4, 4, 4, 4,11,
      11, 4,15,15,15,15, 4,11,
       0, 4,15, 0, 0,15, 4, 0,
       0, 0, 0,13,13, 0, 0, 0,
       0, 5, 5,13,13, 5, 5, 0,
       0, 5,13, 5, 5,13, 5, 0,
       0, 5, 0, 0, 0, 5, 0, 0,
    },
  },
  up = {
    [0] = {
       0,11,11,11,11,11,11, 0,
      11, 4, 4, 4, 4, 4, 4,11,
      11, 4, 4, 4, 4, 4, 4,11,
       0, 4, 4, 4, 4, 4, 4, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 0, 5, 0, 5, 0, 0, 0,
    },
    [1] = {
       0,11,11,11,11,11,11, 0,
      11, 4, 4, 4, 4, 4, 4,11,
      11, 4, 4, 4, 4, 4, 4,11,
       0, 4, 4, 4, 4, 4, 4, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 5, 5, 5, 5, 5, 5, 0,
       0, 5, 0, 0, 0, 5, 0, 0,
    },
  },
  right = {
    [0] = {
       0, 0,11,11,11,11,11, 0,
       0,11, 4, 4, 4, 4, 4,11,
       0,11, 4,15,15,15, 4,11,  -- headband from side
       0, 0, 0,13,13,15, 4, 0,  -- glasses lens visible from profile
       0, 0, 0,13,13, 0, 0, 0,
       0, 0, 5, 5, 5,13,13, 0,  -- tablet held forward
       0, 0, 5, 5, 5,13,13, 0,
       0, 0, 5, 5, 0, 0, 0, 0,
    },
    [1] = {
       0, 0,11,11,11,11,11, 0,
       0,11, 4, 4, 4, 4, 4,11,
       0,11, 4,15,15,15, 4,11,
       0, 0, 0,13,13,15, 4, 0,
       0, 0, 0,13,13, 0, 0, 0,
       0, 0, 5, 5, 5,13,13, 0,
       0, 0, 5, 5, 5,13,13, 0,
       0, 5, 0, 0, 5, 0, 0, 0,
    },
  },
}

local function draw_engineer_sprite(sx, sy)
  local data, flip = dirframe(SERGEI); draw_sprite(sx, sy, data, flip)
end
local function draw_mathwiz_sprite(sx, sy)
  local data, flip = dirframe(PAJ); draw_sprite(sx, sy, data, flip)
end

-- Scaled sprite (used by the status screen as a "portrait" of the actual
-- in-game sprite). Always faces down; bobs gently per tick.
local SETS_BY_CLASS = {mage=DIEGUES, cleric=MIEL, warrior=STROM, bard=ALDER,
                        engineer=SERGEI, mathwiz=PAJ, drummer=STROM}  -- Niko reuses Strom's bitmap (same voice family)
local function draw_sprite_scaled(class, sx, sy, scale)
  local SET = SETS_BY_CLASS[class]
  if not SET then return end
  local frame = walk_frame()
  local data = SET.down[frame] or SET.down[0]
  for lev = 1, 15 do
    local any = false
    for i = 1, 64 do
      if data[i] == lev then
        local cx = (i - 1) % 8
        local cy = math.floor((i - 1) / 8)
        screen.rect(sx + cx * scale, sy + cy * scale, scale, scale)
        any = true
      end
    end
    if any then screen.level(lev); screen.fill() end
  end
end

SPRITE_BY_CLASS = {
  mage     = draw_mage_sprite,
  cleric   = draw_cleric_sprite,
  warrior  = draw_warrior_sprite,
  bard     = draw_bard_sprite,
  engineer = draw_engineer_sprite,
  mathwiz  = draw_mathwiz_sprite,
  drummer  = draw_warrior_sprite,   -- Niko reuses Strom's overworld sprite
  scaled   = draw_sprite_scaled,
}
end  -- class sprites

local function draw_player_at(sx, sy)
  -- player sprite reflects whichever party member is currently active
  local p = party[active]
  local fn = (p and SPRITE_BY_CLASS[p.class]) or SPRITE_BY_CLASS.bard
  fn(sx, sy)
end

-- Generic fallback NPC sprite (triangle-headed).
local function draw_npc_at(sx, sy)
  screen.level(11)
  screen.rect(sx + 2, sy + 3, 4, 4)
  screen.fill()
  screen.move(sx + 2, sy + 3)
  screen.line(sx + 4, sy)
  screen.line(sx + 6, sy + 3)
  screen.close()
  screen.fill()
  if (tick % 8) < 4 then
    screen.level(0)
    screen.pixel(sx + 4, sy + 1)
  end
end

local NPC_SPRITES
do
-- Elder: hooded sage with glowing staff
local function draw_npc_elder(sx, sy)
  -- robe / hood
  screen.level(5)
  screen.rect(sx + 2, sy, 4, 8)
  screen.fill()
  screen.rect(sx + 1, sy + 4, 6, 4)
  screen.fill()
  -- face peeking from hood
  screen.level(11)
  screen.pixel(sx + 3, sy + 3)
  screen.pixel(sx + 4, sy + 3)
  -- beard hint
  screen.level(13)
  screen.pixel(sx + 3, sy + 4)
  screen.pixel(sx + 4, sy + 4)
  -- staff
  screen.level(7)
  screen.rect(sx + 7, sy + 1, 1, 7)
  screen.fill()
  -- staff orb (pulses)
  screen.level((tick % 16) < 8 and 15 or 8)
  screen.pixel(sx + 7, sy)
end

-- Lyrik: musician with curls and a small lute held in front
local function draw_npc_lyrik(sx, sy)
  -- head
  screen.level(11)
  screen.rect(sx + 3, sy + 1, 2, 2)
  screen.fill()
  -- curly hair (asymmetric pixels around head)
  screen.level(7)
  screen.pixel(sx + 2, sy + 1)
  screen.pixel(sx + 5, sy + 1)
  screen.pixel(sx + 2, sy)
  screen.pixel(sx + 5, sy)
  screen.pixel(sx + 4, sy)
  -- vest body
  screen.level(8)
  screen.rect(sx + 2, sy + 3, 4, 3)
  screen.fill()
  -- lute body (wider oval below body)
  screen.level(13)
  screen.rect(sx + 1, sy + 5, 6, 2)
  screen.fill()
  -- soundhole
  screen.level(0)
  screen.pixel(sx + 4, sy + 6)
  -- legs
  screen.level(5)
  screen.pixel(sx + 3, sy + 7)
  screen.pixel(sx + 5, sy + 7)
end

-- Veris: forest sage with leaf-crown and earth-toned robe
local function draw_npc_veris(sx, sy)
  -- leaf crown (3 small leaves)
  screen.level(7)
  screen.pixel(sx + 2, sy)
  screen.pixel(sx + 4, sy)
  screen.pixel(sx + 6, sy)
  screen.rect(sx + 1, sy + 1, 7, 1)
  screen.fill()
  -- head
  screen.level(11)
  screen.rect(sx + 3, sy + 2, 2, 2)
  screen.fill()
  -- robe with vine pattern
  screen.level(5)
  screen.rect(sx + 2, sy + 4, 4, 4)
  screen.fill()
  -- vines (squiggle of dark pixels)
  screen.level(0)
  screen.pixel(sx + 3, sy + 5)
  screen.pixel(sx + 4, sy + 6)
  screen.pixel(sx + 3, sy + 7)
end

-- Aurin: sailor with white cap and striped shirt
local function draw_npc_aurin(sx, sy)
  -- sailor cap
  screen.level(15)
  screen.rect(sx + 2, sy, 4, 2)
  screen.fill()
  -- cap band
  screen.level(7)
  screen.rect(sx + 2, sy + 1, 4, 1)
  screen.fill()
  -- head
  screen.level(11)
  screen.rect(sx + 3, sy + 2, 2, 2)
  screen.fill()
  -- striped shirt body
  screen.level(13)
  screen.rect(sx + 2, sy + 4, 4, 4)
  screen.fill()
  screen.level(7)
  screen.move(sx + 2, sy + 5); screen.line(sx + 5, sy + 5); screen.stroke()
  screen.move(sx + 2, sy + 7); screen.line(sx + 5, sy + 7); screen.stroke()
end

-- Tova (sage): hooded scholar with a small book
local function draw_npc_tova(sx, sy)
  -- robe (forest green-ish, dim)
  screen.level(4)
  screen.rect(sx + 1, sy + 4, 6, 4)
  screen.fill()
  -- hood
  screen.level(2)
  screen.rect(sx + 2, sy, 4, 4)
  screen.fill()
  -- face
  screen.level(13)
  screen.pixel(sx + 3, sy + 3)
  screen.pixel(sx + 4, sy + 3)
  -- book in hand
  screen.level(15)
  screen.rect(sx + 5, sy + 5, 2, 2)
  screen.fill()
  screen.level(0)
  screen.pixel(sx + 6, sy + 6)
end

-- Hens (shopkeep): apron and cap
local function draw_npc_hens(sx, sy)
  -- cap
  screen.level(11)
  screen.rect(sx + 2, sy, 4, 2)
  screen.fill()
  -- head
  screen.level(13)
  screen.rect(sx + 3, sy + 2, 2, 2)
  screen.fill()
  -- shirt
  screen.level(7)
  screen.rect(sx + 2, sy + 4, 4, 2)
  screen.fill()
  -- apron (light)
  screen.level(15)
  screen.rect(sx + 3, sy + 4, 2, 4)
  screen.fill()
  -- pocket
  screen.level(3)
  screen.pixel(sx + 3, sy + 6)
  screen.pixel(sx + 4, sy + 6)
end

-- Brann (smith): heavy build, leather apron, hammer
local function draw_npc_brann(sx, sy)
  -- bald head
  screen.level(11)
  screen.rect(sx + 3, sy + 1, 2, 2)
  screen.fill()
  -- broad shoulders
  screen.level(7)
  screen.rect(sx + 1, sy + 3, 6, 2)
  screen.fill()
  -- leather apron
  screen.level(4)
  screen.rect(sx + 2, sy + 5, 4, 3)
  screen.fill()
  -- belt
  screen.level(2)
  screen.move(sx + 2, sy + 6); screen.line(sx + 5, sy + 6); screen.stroke()
  -- hammer (held to side)
  screen.level(13)
  screen.rect(sx, sy + 5, 1, 2)
  screen.fill()
  screen.level(15)
  screen.pixel(sx, sy + 4)
end

-- Iolen (highland watch): heavy cloak, fur-rimmed hood
local function draw_npc_iolen(sx, sy)
  -- snow-frosted hood
  screen.level(15)
  screen.rect(sx + 1, sy, 6, 2)
  screen.fill()
  screen.level(11)
  screen.rect(sx + 2, sy + 1, 4, 1)
  screen.fill()
  -- face
  screen.level(13)
  screen.pixel(sx + 3, sy + 2)
  screen.pixel(sx + 4, sy + 2)
  -- thick cloak (gray)
  screen.level(7)
  screen.rect(sx + 1, sy + 3, 6, 5)
  screen.fill()
  -- belt
  screen.level(2)
  screen.move(sx + 1, sy + 6); screen.line(sx + 6, sy + 6); screen.stroke()
  -- breath plume (shifts with tick — approximate via static for sprite)
  screen.level(11)
  screen.pixel(sx, sy + 3)
end

-- Wren (wandering minstrel): traveler's hat, small flute at hip
local function draw_npc_wren(sx, sy)
  -- traveler's wide hat
  screen.level(7)
  screen.rect(sx + 1, sy, 6, 1)
  screen.fill()
  screen.level(11)
  screen.rect(sx + 2, sy + 1, 4, 1)
  screen.fill()
  -- head
  screen.level(13)
  screen.rect(sx + 3, sy + 2, 2, 2)
  screen.fill()
  -- short cape (green-ish)
  screen.level(5)
  screen.rect(sx + 1, sy + 3, 6, 4)
  screen.fill()
  -- tunic underneath
  screen.level(8)
  screen.rect(sx + 3, sy + 4, 2, 3)
  screen.fill()
  -- small flute (held diagonally)
  screen.level(15)
  screen.move(sx + 5, sy + 5); screen.line(sx + 7, sy + 7)
  screen.stroke()
  -- legs
  screen.level(5)
  screen.pixel(sx + 3, sy + 7); screen.pixel(sx + 4, sy + 7)
end

-- Pip (village child): small body, ponytail tied with bow, simple dress
local function draw_npc_pip(sx, sy)
  -- ponytail (back of head, sticks up-right)
  screen.level(8)
  screen.move(sx + 5, sy + 1); screen.line(sx + 7, sy - 1)
  screen.stroke()
  screen.level(13)
  screen.pixel(sx + 7, sy - 1)  -- ribbon dot
  -- head (small)
  screen.level(13)
  screen.rect(sx + 3, sy + 1, 2, 3); screen.fill()
  -- eyes
  screen.level(0)
  screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2)
  -- pinafore dress (simple A-line)
  screen.level(11)
  screen.rect(sx + 3, sy + 4, 2, 2); screen.fill()
  screen.level(7)
  screen.rect(sx + 2, sy + 6, 4, 1); screen.fill()
  -- legs
  screen.level(5)
  screen.pixel(sx + 3, sy + 7); screen.pixel(sx + 4, sy + 7)
end

-- Mara (innkeeper): apron, kerchief on head
local function draw_npc_mara(sx, sy)
  screen.level(13); screen.rect(sx + 2, sy, 4, 2); screen.fill()       -- kerchief
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(8);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- dress
  screen.level(15); screen.rect(sx + 3, sy + 5, 2, 3); screen.fill()    -- apron
end

-- Pell (tale-spinner): hunched old man, long beard, walking stick
local function draw_npc_pell(sx, sy)
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()    -- bald head
  screen.level(15); screen.pixel(sx + 2, sy + 3); screen.pixel(sx + 5, sy + 3); screen.fill()  -- beard sides
  screen.level(13); screen.rect(sx + 3, sy + 3, 2, 2); screen.fill()    -- beard front
  screen.level(5);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- robe
  screen.level(8);  screen.move(sx + 6, sy + 3); screen.line(sx + 6, sy + 7); screen.stroke()  -- staff
end

-- Brio (shopkeeper): wide-brimmed hat, vest, coin pouch
local function draw_npc_brio(sx, sy)
  screen.level(7); screen.rect(sx + 1, sy, 6, 1); screen.fill()         -- hat brim
  screen.level(11); screen.rect(sx + 2, sy + 1, 4, 1); screen.fill()    -- crown
  screen.level(13); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(4); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()     -- vest
  screen.level(15); screen.pixel(sx + 5, sy + 6); screen.fill()          -- coin
end

-- Mews (cat asleep on rug): curled coil + ears + tail
local function draw_npc_mews(sx, sy)
  screen.level(8); screen.rect(sx + 1, sy + 4, 6, 3); screen.fill()     -- body coil
  screen.level(11); screen.rect(sx + 1, sy + 3, 2, 1); screen.fill()    -- head
  screen.level(11); screen.pixel(sx + 1, sy + 2); screen.pixel(sx + 2, sy + 2); screen.fill()  -- ears
  screen.level(13); screen.move(sx + 6, sy + 6); screen.line(sx + 7, sy + 4); screen.stroke()  -- tail
  if (tick % 32) < 8 then
    screen.level(6); screen.pixel(sx + 4, sy + 2); screen.pixel(sx + 5, sy + 2); screen.fill() -- "Z" puff
  end
end

-- Rook (dog): standing stout, floppy ear, wagging tail
local function draw_npc_rook(sx, sy)
  screen.level(7); screen.rect(sx + 1, sy + 4, 5, 3); screen.fill()     -- body
  screen.level(11); screen.rect(sx, sy + 3, 2, 2); screen.fill()        -- head
  screen.level(5); screen.pixel(sx, sy + 2); screen.fill()              -- floppy ear
  screen.level(15); screen.pixel(sx + 1, sy + 4); screen.fill()         -- eye
  -- legs
  screen.level(7); screen.pixel(sx + 1, sy + 7); screen.pixel(sx + 4, sy + 7); screen.fill()
  -- wagging tail
  local wag = (tick % 8) < 4 and 1 or -1
  screen.level(11); screen.pixel(sx + 6, sy + 4 + wag); screen.fill()
end

-- Lyssa (Suno's attendant): pale hooded figure, lit candle
local function draw_npc_lyssa(sx, sy)
  screen.level(2); screen.rect(sx + 1, sy, 6, 4); screen.fill()         -- hood
  screen.level(11); screen.pixel(sx + 3, sy + 3); screen.pixel(sx + 4, sy + 3); screen.fill()  -- eyes
  screen.level(5); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()     -- robe
  -- candle (right hand)
  screen.level(13); screen.pixel(sx + 6, sy + 5); screen.fill()
  if (tick % 6) < 3 then
    screen.level(15); screen.pixel(sx + 6, sy + 4); screen.fill()
  end
end

-- Calder (Suno's attendant): tall, soldierly, dark cape
local function draw_npc_calder(sx, sy)
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()    -- head
  screen.level(2); screen.rect(sx + 1, sy + 3, 6, 5); screen.fill()     -- cape
  screen.level(7); screen.rect(sx + 3, sy + 4, 2, 3); screen.fill()     -- tunic strip
  screen.level(13); screen.pixel(sx + 6, sy + 4); screen.fill()         -- shoulder badge
end

-- Maren (Suno's attendant): bard-mourner, kneeling, holds a small lute
local function draw_npc_maren(sx, sy)
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- head
  screen.level(7); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()     -- robe
  screen.level(13); screen.rect(sx, sy + 5, 2, 2); screen.fill()        -- lute body
  screen.level(8); screen.move(sx + 1, sy + 5); screen.line(sx + 4, sy + 4); screen.stroke()  -- neck
end

NPC_SPRITES = {
  Elder  = draw_npc_elder,
  Lyrik  = draw_npc_lyrik,
  Veris  = draw_npc_veris,
  Aurin  = draw_npc_aurin,
  Tova   = draw_npc_tova,
  Hens   = draw_npc_hens,
  Brann  = draw_npc_brann,
  Iolen  = draw_npc_iolen,
  Wren   = draw_npc_wren,
  Pip    = draw_npc_pip,
  Mara   = draw_npc_mara,
  Pell   = draw_npc_pell,
  Brio   = draw_npc_brio,
  Mews   = draw_npc_mews,
  Pim    = draw_npc_mews,   -- outdoor village cat shares the cat sprite
  Rook   = draw_npc_rook,
  Bonk   = draw_npc_rook,   -- outdoor village dog shares the dog sprite
  Lyssa  = draw_npc_lyssa,
  Calder = draw_npc_calder,
  Maren  = draw_npc_maren,
  -- (Tilde, Eos, Sela: registered after do-block to keep block locals under cap)
  -- Recruit NPCs use their party-class sprites (via the persistent table —
  -- the local draw_engineer_sprite is out of scope here).
  Sergei = SPRITE_BY_CLASS.engineer,
  Paj    = SPRITE_BY_CLASS.mathwiz,
  -- Hidden NPCs (Wina/Karoo/Snow) use the generic NPC fallback
}
end  -- npc draws

-- Pass 20+ NPC sprites: registered as anonymous functions on NPC_SPRITES so
-- they don't add to the npc-do-block's local register count (we're near the cap).

NPC_SPRITES.Hollin = function(sx, sy)
  -- Hollin (Cave 1): muddy traveler with a small lantern at her hip
  screen.level(7); screen.rect(sx + 2, sy, 4, 2); screen.fill()
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()
  screen.level(4); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()
  screen.level(5); screen.rect(sx + 3, sy + 5, 2, 2); screen.fill()
  screen.level(13); screen.pixel(sx + 7, sy + 5); screen.pixel(sx + 7, sy + 6); screen.fill()
  if (tick % 10) < 6 then screen.level(15); screen.pixel(sx + 7, sy + 5); screen.fill() end
end

NPC_SPRITES.Beren = function(sx, sy)
  -- Beren (Cave 2): bushy beard, leaf-patched cloak
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()
  screen.level(7); screen.rect(sx + 2, sy + 3, 4, 2); screen.fill()
  screen.level(3); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()
  screen.level(9); screen.pixel(sx + 2, sy + 5); screen.pixel(sx + 5, sy + 6); screen.fill()
end

NPC_SPRITES.Anwell = function(sx, sy)
  -- Anwell (Cave 3): translucent ghost; flickers between two brightnesses
  local lev = ((tick % 12) < 6) and 5 or 7
  screen.level(lev); screen.rect(sx + 1, sy, 6, 8); screen.fill()
  screen.level(0); screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2); screen.fill()
  screen.level(8); screen.move(sx + 6, sy + 4); screen.line(sx + 7, sy + 7); screen.stroke()
  screen.level(6); screen.move(sx + 5, sy + 5); screen.line(sx + 7, sy + 6); screen.stroke()
end

NPC_SPRITES.Iska = function(sx, sy)
  -- Iska (Cave 4): broad sun-cloak, scarf wrapped over face
  screen.level(13); screen.rect(sx + 1, sy, 6, 4); screen.fill()
  screen.level(11); screen.pixel(sx + 3, sy + 3); screen.pixel(sx + 4, sy + 3); screen.fill()
  screen.level(8); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()
  screen.level(11); screen.move(sx + 1, sy + 5); screen.line(sx + 6, sy + 5); screen.stroke()
end

-- Karoo (Eastern dunes wanderer): tall, robed, half-remembering a tune
NPC_SPRITES.Karoo = function(sx, sy)
  screen.level(13); screen.rect(sx + 1, sy, 6, 2); screen.fill()        -- sand-cloth wrap
  screen.level(11); screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2); screen.fill()  -- eyes
  screen.level(8); screen.rect(sx + 1, sy + 3, 6, 5); screen.fill()     -- robe
  -- one hand raised as if cupping an ear (a tune-listener)
  screen.level(11); screen.pixel(sx, sy + 4); screen.pixel(sx, sy + 5); screen.fill()
  -- musical note above (flickers in/out)
  if (tick % 18) < 9 then
    screen.level(15); screen.pixel(sx + 5, sy - 1); screen.pixel(sx + 5, sy); screen.fill()
  end
end

-- Mira (Eastern sage): seated scholar, scroll across her lap
NPC_SPRITES.Mira = function(sx, sy)
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()    -- face
  screen.level(7); screen.rect(sx + 2, sy, 4, 1); screen.fill()         -- braided crown
  screen.level(4); screen.rect(sx + 1, sy + 3, 6, 4); screen.fill()     -- robe
  -- scroll across the lap
  screen.level(15); screen.rect(sx + 1, sy + 5, 6, 2); screen.fill()
  screen.level(7); screen.move(sx + 2, sy + 6); screen.line(sx + 6, sy + 6); screen.stroke()
end

-- Sett (Hollow treasure hunter): sly grin, wide-brimmed hat with feather, satchel
NPC_SPRITES.Sett = function(sx, sy)
  screen.level(7); screen.rect(sx + 1, sy, 6, 1); screen.fill()         -- hat brim
  screen.level(11); screen.rect(sx + 2, sy + 1, 4, 1); screen.fill()    -- crown
  screen.level(13); screen.pixel(sx + 6, sy); screen.fill()             -- feather
  screen.level(11); screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2); screen.fill()  -- eyes
  screen.level(5); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()     -- vest
  -- satchel across chest
  screen.level(8); screen.move(sx + 1, sy + 4); screen.line(sx + 6, sy + 6); screen.stroke()
  screen.level(13); screen.rect(sx + 5, sy + 6, 2, 2); screen.fill()    -- satchel pouch
end

-- Snow (Northern silent figure): tall, snow-frosted, head bowed
NPC_SPRITES.Snow = function(sx, sy)
  screen.level(15); screen.rect(sx + 1, sy, 6, 3); screen.fill()        -- snow on shoulders/head
  screen.level(11); screen.pixel(sx + 3, sy + 3); screen.pixel(sx + 4, sy + 3); screen.fill()  -- eyes (closed-feel)
  screen.level(5); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()     -- gray cloak
  -- snow flecks on cloak
  screen.level(13); screen.pixel(sx + 2, sy + 5); screen.pixel(sx + 5, sy + 6); screen.fill()
  -- single falling flake just above (animated)
  if (tick % 24) < 12 then
    screen.level(15); screen.pixel(sx + 4, sy - 1); screen.fill()
  end
end

-- Wina (Mainland hidden walker): cloaked, hood pulled low, wandering
NPC_SPRITES.Wina = function(sx, sy)
  local sway = ((tick % 24) < 12) and 0 or 1
  screen.level(3); screen.rect(sx + 1 + sway, sy, 6, 4); screen.fill()  -- deep hood
  screen.level(7); screen.pixel(sx + 3 + sway, sy + 3); screen.pixel(sx + 4 + sway, sy + 3); screen.fill()  -- shadowed eyes
  screen.level(5); screen.rect(sx + 1 + sway, sy + 4, 6, 4); screen.fill()  -- cloak
  screen.level(2); screen.rect(sx + 2 + sway, sy + 5, 4, 1); screen.fill()  -- waist sash
end

-- IRET (the Diplomat): tall thin figure, narrow Quiet-Court livery, ledger
NPC_SPRITES.Iret = function(sx, sy)
  -- pale-court robe (high contrast)
  screen.level(13); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- robe (white)
  screen.level(7); screen.move(sx + 2, sy + 4); screen.line(sx + 5, sy + 4); screen.stroke()
  -- narrow head, slick hair
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()
  screen.level(2); screen.rect(sx + 3, sy, 2, 1); screen.fill()         -- dark hair line
  -- gold collar pin (Suno's mark)
  screen.level(15); screen.pixel(sx + 4, sy + 3); screen.fill()
  -- ledger held at waist (right hand)
  screen.level(8); screen.rect(sx + 5, sy + 5, 2, 2); screen.fill()
  screen.level(13); screen.pixel(sx + 5, sy + 5); screen.pixel(sx + 6, sy + 5); screen.fill()
end

-- VANCE (the Conductor): broad armored figure, hooded, sword hilt above shoulder
NPC_SPRITES.Vance = function(sx, sy)
  -- dark hood
  screen.level(2); screen.rect(sx + 1, sy, 6, 4); screen.fill()
  screen.level(7); screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2); screen.fill()  -- pale eyes
  -- broad armored shoulders + chest
  screen.level(5); screen.rect(sx + 1, sy + 3, 6, 5); screen.fill()
  screen.level(2); screen.rect(sx + 1, sy + 4, 6, 1); screen.fill()     -- chest band shadow
  -- Quiet-Court chest sigil (silver)
  screen.level(13); screen.pixel(sx + 3, sy + 5); screen.pixel(sx + 4, sy + 5); screen.fill()
  -- sword hilt sticking up over right shoulder
  screen.level(11); screen.move(sx + 6, sy); screen.line(sx + 7, sy + 2); screen.stroke()
  screen.level(15); screen.pixel(sx + 7, sy); screen.fill()
end

-- TESS (Alder's former bandmate): pale livery + lute on her back; conflicted look
NPC_SPRITES.Tess = function(sx, sy)
  -- pale court hood pulled back
  screen.level(13); screen.rect(sx + 2, sy + 1, 4, 1); screen.fill()    -- hair band
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  -- court livery (paler than Vance, similar to Iret)
  screen.level(11); screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()
  -- lute slung on her back (sticks out diagonally)
  screen.level(8); screen.move(sx, sy + 7); screen.line(sx + 6, sy + 1); screen.stroke()
  screen.level(13); screen.rect(sx, sy + 6, 2, 2); screen.fill()        -- lute body bottom-left
  -- subtle gold pin (still wearing the Court's mark)
  screen.level(15); screen.pixel(sx + 4, sy + 4); screen.fill()
end

NPC_SPRITES.Fern = function(sx, sy)
  -- Lake fisherman: wide-brim straw hat, fishing rod sticking out, seated pose
  screen.level(11); screen.rect(sx + 1, sy + 1, 6, 1); screen.fill()    -- hat brim
  screen.level(7);  screen.rect(sx + 3, sy, 2, 1); screen.fill()        -- crown
  screen.level(13); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(5);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- vest / seated
  -- fishing rod (long diagonal up-right)
  screen.level(7); screen.move(sx + 5, sy + 5); screen.line(sx + 7, sy); screen.stroke()
  -- line dropping down (wavy)
  screen.level(8); screen.pixel(sx + 7, sy + 1); screen.pixel(sx + 7, sy + 3); screen.fill()
end

NPC_SPRITES.Holda = function(sx, sy)
  -- Village watchwoman: helm, cloak, axe held at side
  screen.level(7); screen.rect(sx + 2, sy, 4, 2); screen.fill()         -- helm dome
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(5);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- cloak
  screen.level(2);  screen.rect(sx + 2, sy + 5, 4, 1); screen.fill()    -- belt shadow
  -- axe (right-hand): vertical handle + small head at top
  screen.level(7); screen.move(sx + 7, sy + 1); screen.line(sx + 7, sy + 7); screen.stroke()
  screen.level(13); screen.rect(sx + 6, sy, 2, 1); screen.fill()        -- axe head
end

NPC_SPRITES.Tilde = function(sx, sy)
  -- Village kid: tiny, oversized hat, hops in place
  local hop = (tick % 8) < 4 and 0 or -1
  screen.level(7); screen.rect(sx + 2, sy + hop, 4, 1); screen.fill()
  screen.level(11); screen.rect(sx + 3, sy + 1 + hop, 2, 2); screen.fill()
  screen.level(13); screen.rect(sx + 3, sy + 4 + hop, 2, 3); screen.fill()
  screen.level(5);  screen.pixel(sx + 2, sy + 7 + hop); screen.pixel(sx + 5, sy + 7 + hop); screen.fill()
end

NPC_SPRITES.Sela = function(sx, sy)
  -- Eastern harbormaster: peaked hat, oilskin coat, brass buttons
  screen.level(7); screen.move(sx + 1, sy + 1); screen.line(sx + 4, sy - 1); screen.line(sx + 7, sy + 1); screen.stroke()
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()
  screen.level(5); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()
  screen.level(13); screen.pixel(sx + 3, sy + 5); screen.pixel(sx + 3, sy + 7); screen.fill()
  screen.level(13); screen.pixel(sx + 5, sy + 5); screen.pixel(sx + 5, sy + 7); screen.fill()
end

NPC_SPRITES.Eos = function(sx, sy)
  -- Wandering minstrel: cloaked, holds a small lute crosswise
  screen.level(3); screen.rect(sx + 1, sy, 6, 4); screen.fill()
  screen.level(11); screen.pixel(sx + 3, sy + 3); screen.pixel(sx + 4, sy + 3); screen.fill()
  screen.level(5); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()
  screen.level(13); screen.rect(sx + 4, sy + 5, 2, 2); screen.fill()
  screen.level(8); screen.move(sx + 5, sy + 5); screen.line(sx + 1, sy + 7); screen.stroke()
end

NPC_SPRITES.Niko = function(sx, sy)
  -- Niko (drummer): bandana, vest, two drumsticks crossed at chest, snare on hip
  screen.level(13); screen.rect(sx + 1, sy, 6, 1); screen.fill()        -- bandana band
  screen.level(11); screen.rect(sx + 3, sy + 1, 2, 2); screen.fill()    -- face
  screen.level(7);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- vest
  -- crossed drumsticks
  screen.level(15); screen.move(sx + 1, sy + 4); screen.line(sx + 6, sy + 7); screen.stroke()
  screen.level(15); screen.move(sx + 6, sy + 4); screen.line(sx + 1, sy + 7); screen.stroke()
  -- snare drum on hip (right)
  screen.level(8); screen.rect(sx + 6, sy + 5, 2, 2); screen.fill()
  screen.level(13); screen.pixel(sx + 6, sy + 5); screen.pixel(sx + 7, sy + 5); screen.fill()  -- rim
end

NPC_SPRITES.Vessel = function(sx, sy)
  -- Cave 6 NPC: hollow-eyed acolyte, pale robe, hands clasped
  screen.level(15); screen.rect(sx + 1, sy, 6, 3); screen.fill()        -- white hood
  screen.level(0);  screen.pixel(sx + 3, sy + 2); screen.pixel(sx + 4, sy + 2); screen.fill()  -- hollow eyes
  screen.level(7);  screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()    -- robe
  -- ritual sash
  screen.level(2);  screen.rect(sx + 1, sy + 6, 6, 1); screen.fill()
  -- clasped hands at center
  screen.level(13); screen.pixel(sx + 3, sy + 5); screen.pixel(sx + 4, sy + 5); screen.fill()
end

NPC_SPRITES.Pith = function(sx, sy)
  -- Cartographer: wide-brimmed scholar hat, scroll across belly, ink-stained robe.
  screen.level(7); screen.rect(sx + 1, sy, 6, 1); screen.fill()         -- broad hat brim
  screen.level(11); screen.rect(sx + 2, sy + 1, 4, 1); screen.fill()    -- crown
  screen.level(13); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(5);  screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()    -- robe
  -- scroll across belly
  screen.level(15); screen.rect(sx + 1, sy + 5, 6, 1); screen.fill()
  screen.level(11); screen.move(sx + 2, sy + 5); screen.line(sx + 5, sy + 5); screen.stroke()
  -- ink stain on hem
  screen.level(2); screen.pixel(sx + 5, sy + 7); screen.fill()
end

NPC_SPRITES.Anker = function(sx, sy)
  -- Old peddler: stooped, big back-pack, walking stick
  screen.level(7); screen.rect(sx + 2, sy, 4, 2); screen.fill()         -- knit cap
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 1); screen.fill()    -- face
  screen.level(13); screen.pixel(sx + 2, sy + 3); screen.pixel(sx + 5, sy + 3); screen.fill()  -- gray beard
  screen.level(5);  screen.rect(sx + 2, sy + 4, 4, 4); screen.fill()    -- coat
  -- backpack (taller bulge on the left)
  screen.level(8); screen.rect(sx,     sy + 3, 2, 5); screen.fill()
  screen.level(11); screen.pixel(sx + 1, sy + 4); screen.fill()         -- buckle gleam
  -- walking stick (right)
  screen.level(7); screen.move(sx + 7, sy + 1); screen.line(sx + 7, sy + 7); screen.stroke()
end

NPC_SPRITES.WispGirl = function(sx, sy)
  -- Pilgrim kid: small, woolen scarf, candle in cupped hands
  local hop = (tick % 10) < 5 and 0 or -1
  screen.level(13); screen.rect(sx + 3, sy + 1 + hop, 2, 2); screen.fill()  -- face
  screen.level(7); screen.rect(sx + 2, sy + 3 + hop, 4, 1); screen.fill()  -- scarf
  screen.level(11); screen.rect(sx + 2, sy + 4 + hop, 4, 4); screen.fill() -- coat (white)
  -- cupped candle (center, lit)
  screen.level(15); screen.pixel(sx + 4, sy + 5 + hop); screen.fill()
  if (tick % 8) < 5 then
    screen.level(13); screen.pixel(sx + 4, sy + 4 + hop); screen.fill()
  end
end

NPC_SPRITES.Bracken = function(sx, sy)
  -- Bracken (Northern guide): fur cap, bushy beard, snow-flecked coat
  screen.level(7); screen.rect(sx + 1, sy, 6, 2); screen.fill()         -- fur cap
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()    -- face
  screen.level(15); screen.rect(sx + 2, sy + 3, 4, 1); screen.fill()    -- white beard
  screen.level(5); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()     -- coat
  screen.level(15); screen.pixel(sx + 2, sy + 5); screen.pixel(sx + 5, sy + 6); screen.fill()  -- snow flecks
  screen.level(11); screen.move(sx + 3, sy + 4); screen.line(sx + 4, sy + 7); screen.stroke()  -- belt strap
end

NPC_SPRITES.Wenna = function(sx, sy)
  -- Wenna (Cave 5): hunched, breath-cloud above her every other beat
  screen.level(11); screen.rect(sx + 3, sy + 2, 2, 2); screen.fill()
  screen.level(13); screen.rect(sx + 1, sy + 4, 6, 4); screen.fill()
  screen.level(15); screen.rect(sx + 2, sy + 5, 4, 1); screen.fill()
  if (tick % 16) < 8 then
    screen.level(7); screen.pixel(sx + 4, sy + 1); screen.pixel(sx + 5, sy); screen.fill()
  end
end

-- ============================================================ DRAWING — STATES

local function draw_overworld()
  for vy = 0, VIEW_H - 1 do
    for vx = 0, VIEW_W - 1 do
      local tx = cam.x + vx
      local ty = cam.y + vy
      local t = tile_at(tx, ty)
      local sx = vx * TILE
      local sy = vy * TILE
      -- Inside-an-interior overrides:
      --   inn/shop (5/6) → wood planks for floor + themed walls
      --   cave1-5 (7-11) → cave floor for floor
      if (current_map_id == 5 or current_map_id == 6) and t == 0 then
        TILE_DRAW.floor(sx, sy)
      elseif current_map_id == 5 and t == 4 then
        TILE_DRAW.inn_wall(sx, sy, tx + ty * MAP_W)
      elseif current_map_id == 6 and t == 4 then
        TILE_DRAW.shop_wall(sx, sy, tx + ty * MAP_W)
      elseif (current_map_id == 7 or current_map_id == 8 or current_map_id == 9
              or current_map_id == 10 or current_map_id == 11
              or current_map_id == 12 or current_map_id == 13
              or current_map_id == 14) and t == 0 then
        TILE_DRAW.cavefloor(sx, sy, tx + ty * MAP_W)
      else
        local fn = TILE_DRAW[t] or TILE_DRAW[0]
        if t == 3 or t == 6 or t == 7 or t == 9 or t == 11 or t == 14 or t == 16 or t == 18 or t == 19 or t == 20 or t == 24 or t == 27 or t == 30 or t == 36 or t == 38 or t == 39 or t == 41 or t == 43 then fn(sx, sy, tick)
        elseif t == 0 or t == 8 then fn(sx, sy, tx + ty * MAP_W)
        else fn(sx, sy)
        end
      end
    end
  end

  -- NPCs face the camera (down) regardless of where the player is facing,
  -- since some NPC sprites (engineer, mathwiz) use the player.facing
  -- dispatcher when rendered.
  local saved_facing_npc = player.facing
  player.facing = "down"
  for _, n in ipairs(npcs) do
    if n.x >= cam.x and n.x < cam.x + VIEW_W
       and n.y >= cam.y and n.y < cam.y + VIEW_H
       and npc_visible(n) then
      local fn = NPC_SPRITES[n.name] or draw_npc_at
      -- subtle idle bob: each NPC breathes 1px out of phase with the others
      local bob = (((tick + n.x * 7 + n.y * 3) % 32) < 16) and 0 or 1
      fn((n.x - cam.x) * TILE, (n.y - cam.y) * TILE - bob)
    end
  end
  player.facing = saved_facing_npc

  -- campfires (always visible — they don't get used up)
  for _, f in ipairs(CONTENT.campfires) do
    if f.map == current_map_id
       and f.x >= cam.x and f.x < cam.x + VIEW_W
       and f.y >= cam.y and f.y < cam.y + VIEW_H then
      local sx, sy = (f.x - cam.x) * TILE, (f.y - cam.y) * TILE
      -- log base
      screen.level(5)
      screen.rect(sx + 1, sy + 6, 6, 1); screen.fill()
      screen.level(7)
      screen.rect(sx + 2, sy + 5, 4, 1); screen.fill()
      -- flame (animated)
      local f1 = (tick % 4 < 2) and 0 or 1
      screen.level(15)
      screen.move(sx + 4, sy + 1 + f1)
      screen.line(sx + 2, sy + 5)
      screen.line(sx + 6, sy + 5)
      screen.close(); screen.fill()
      screen.level(11)
      screen.pixel(sx + 4, sy + 3 + f1); screen.fill()
    end
  end
  -- treasure chests on the current map (only render unopened ones)
  for _, c in ipairs(CONTENT.chests) do
    if c.map == current_map_id and not CONTENT.opened[c.id]
       and c.x >= cam.x and c.x < cam.x + VIEW_W
       and c.y >= cam.y and c.y < cam.y + VIEW_H then
      local sx, sy = (c.x - cam.x) * TILE, (c.y - cam.y) * TILE
      -- gold chest, lid + body, with a tiny shimmer
      screen.level(11); screen.rect(sx + 1, sy + 3, 6, 4); screen.fill()
      screen.level(15); screen.rect(sx + 1, sy + 2, 6, 1); screen.fill()  -- lid
      screen.level(0);  screen.pixel(sx + 4, sy + 4); screen.fill()       -- keyhole
      if (tick % 8) < 4 then
        screen.level(15); screen.pixel(sx + 5, sy + 1); screen.fill()
      else
        screen.level(13); screen.pixel(sx + 2, sy + 1); screen.fill()
      end
    end
  end

  draw_player_at((player.x - cam.x) * TILE, (player.y - cam.y) * TILE)

  -- prompt: talk OR enter cave OR enter inn
  local fnpc = find_facing_npc()
  local fdx, fdy = facing_offset()
  local ftile = tile_at(player.x + fdx, player.y + fdy)
  if fnpc and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    screen.text_center("A: talk")
  elseif ftile == 5 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    screen.text_center("walk in to rest")
  elseif ftile == 6 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    local s = cave_state[1]
    if s.cleared then screen.text_center("the cave hums softly")
    elseif s.victories >= BOSS_THRESHOLD then screen.text_center("the air thickens...")
    else screen.text_center("walk in to fight (" .. s.victories .. "/" .. BOSS_THRESHOLD .. ")") end
  elseif ftile == 7 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    local s = cave_state[2]
    if s.cleared then screen.text_center("the woods are still")
    elseif s.victories >= BOSS_THRESHOLD then screen.text_center("the trees stop swaying...")
    else screen.text_center("enter the deep wood (" .. s.victories .. "/" .. BOSS_THRESHOLD .. ")") end
  elseif ftile == 9 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    local s = cave_state[3]
    if s.cleared then screen.text_center("the tide breathes calm")
    elseif s.victories >= BOSS_THRESHOLD then screen.text_center("the water rises...")
    else screen.text_center("descend the cavern (" .. s.victories .. "/" .. BOSS_THRESHOLD .. ")") end
  elseif ftile == 11 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    local s = cave_state[4]
    if s.cleared then screen.text_center("the dunes whisper")
    elseif s.victories >= BOSS_THRESHOLD then screen.text_center("sand stirs...")
    else screen.text_center("enter the glass cave (" .. s.victories .. "/" .. BOSS_THRESHOLD .. ")") end
  elseif ftile == 16 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    local s = cave_state[5]
    if s.cleared then screen.text_center("the wind quiets")
    elseif s.victories >= BOSS_THRESHOLD then screen.text_center("the cold deepens...")
    else screen.text_center("enter the ice grotto (" .. s.victories .. "/" .. BOSS_THRESHOLD .. ")") end
  elseif ftile == 15 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    screen.text_center("cross the pass")
  elseif ftile == 10 and (tick % 8) < 5 then
    screen.level(15)
    screen.move(64, 60)
    screen.text_center("set sail")
  end

  -- region environmental overlay (atmospheric particles per region)
  local region = get_region(player.x)
  if region == "woods" then
    -- falling leaves drifting downward
    for i = 1, 4 do
      local lx = (i * 41 + tick * 2) % 128
      local ly = (i * 17 + tick) % 64
      screen.level(7)
      screen.pixel(lx, ly)
    end
    -- dim mist stipple
    screen.level(2)
    for i = 0, 9 do
      screen.pixel((i * 13 + tick) % 128, (i * 7 + 3) % 64)
    end
  elseif region == "coast" then
    -- sun rays from upper-right corner
    screen.level(13)
    for i = 1, 5 do
      local x = 124 - i * 4
      screen.pixel(x, i * 2)
      screen.pixel(x - 1, i * 2 + 1)
    end
    -- shimmer sparkles
    for i = 1, 3 do
      local sx = (i * 53 + tick * 3) % 128
      local sy = (i * 11 + tick) % 28
      if (tick + i * 7) % 8 < 3 then
        screen.level(15)
        screen.pixel(sx, sy)
      end
    end
  end

  -- active voice indicator (top-right) — which character the right stick filters
  if party[active] then
    screen.level(11)
    screen.move(126, 8)
    screen.text_right("> " .. CHAR_NAME[party[active].class])
  end

  -- place label banner (shows briefly on entering a new place / crossing a region)
  if region_label_ticks > 0 then
    -- last_region is "<map_id>:<sub>" — sub is the mainland get_region() value
    -- or empty for non-mainland maps. Map a friendly name per place.
    local PLACE_NAMES = {
      ["1:village"] = "Village Clearing",
      ["1:woods"]   = "Hollow Woods",
      ["1:coast"]   = "Sunward Coast",
      ["2:"]        = "Eastern Reaches",
      ["3:"]        = "Northern Wilds",
      ["4:"]        = "Suno's Domain",
      ["5:"]        = "The Inn",
      ["6:"]        = "Item Shop",
      ["7:"]        = "Cave 1 - The Echoes",
      ["8:"]        = "Cave 2 - Sentinel Grove",
      ["9:"]        = "Cave 3 - Tidewater Grotto",
      ["10:"]       = "Cave 4 - Dune Hall",
      ["11:"]       = "Cave 5 - Frost Vault",
      ["12:"]       = "The Hollow",
      ["13:"]       = "Cave 6 - Locrian Crypt",
      ["14:"]       = "Cave 7 - Suno's Chamber",
    }
    local name = PLACE_NAMES[last_region or ""] or ""
    if name ~= "" then
      screen.level(0)
      screen.rect(8, 22, 112, 14); screen.fill()
      screen.level(15)
      screen.rect(8, 22, 112, 14); screen.stroke()
      screen.move(64, 31); screen.text_center(name)
    end
  end

  -- L2 toggle ON → BPM-edit mode; tiny corner strip + hint
  if l2_held then
    screen.level(0)
    screen.rect(0, 0, 90, 10)
    screen.fill()
    screen.level(15)
    screen.move(2, 8)
    screen.text("JRN " .. OVERWORLD_BPM)
    screen.level(8)
    screen.move(88, 8)
    screen.text_right("L2:exit")
  end

  -- DEBUG overlay (toggle in menu)
  if debug_visible then
    if l2_held then
      screen.level(15)
      screen.move(2, 8)
      screen.text("[L2]")
    end
    if (tick - last_input_at) < 60 then
      screen.level(8)
      screen.move(2, 64)
      screen.text(last_input)
    end
  end

  -- inn rest banner — animated zzz, full heal feedback
  if inn_rest_ticks > 0 then
    screen.level(0)
    screen.rect(18, 20, 92, 24)
    screen.fill()
    screen.level(15)
    screen.rect(18, 20, 92, 24)
    screen.stroke()
    screen.move(64, 30)
    screen.text_center("Rested at the inn")
    -- zzz drift
    local zoff = (tick // 3) % 8
    screen.level(11)
    screen.move(96, 32 - zoff)
    screen.text("z")
    screen.move(100, 28 - zoff)
    screen.text("z")
    screen.move(104, 24 - zoff)
    screen.text("z")
    screen.level(8)
    screen.move(64, 39)
    screen.text_center("HP & MP fully restored")
  end

  -- tower-locked banner (shows briefly when player tries to enter without 5 shards)
  if tower_locked_ticks > 0 then
    screen.level(0)
    screen.rect(8, 22, 112, 20)
    screen.fill()
    screen.level(15)
    screen.rect(8, 22, 112, 20)
    screen.stroke()
    screen.move(64, 30)
    screen.text_center("The Tower bars your way.")
    screen.level(8)
    screen.move(64, 38)
    screen.text_center("Gather 5 shards to enter.")
  end

  -- generic event flash banner (chest, campfire heal, equip toast, etc.)
  if CONTENT.flash_ticks > 0 then
    screen.level(0); screen.rect(20, 28, 88, 12); screen.fill()
    screen.level(15); screen.rect(20, 28, 88, 12); screen.stroke()
    screen.move(64, 36); screen.text_center(CONTENT.flash_text)
  end

end

-- pixel-accurate word wrap using norns screen metrics
local function wrap_text(str, max_px)
  local lines = {}
  local current = ""
  for word in str:gmatch("%S+") do
    local candidate = (#current == 0) and word or (current .. " " .. word)
    if screen.text_extents(candidate) <= max_px then
      current = candidate
    else
      if #current > 0 then table.insert(lines, current) end
      current = word
    end
  end
  if #current > 0 then table.insert(lines, current) end
  return lines
end

-- Maps a party-scene "[Speaker]" tag to a class for sprite lookup.
local DLG_NAME_TO_CLASS = {Alder="bard", Miel="cleric", Strom="warrior", Diegues="mage"}

local function draw_dialogue()
  draw_overworld()
  -- taller box: y=26..63 = 38px tall
  screen.level(0)
  screen.rect(0, 26, 128, 38)
  screen.fill()
  screen.level(15)
  screen.rect(0, 26, 128, 38)
  screen.stroke()

  -- Parse the current line. If it starts with "[Name]", extract the speaker
  -- (so party-scene lines show the actual character + their sprite, not
  -- "_party_scene").
  local cur = (dlg.lines or {})[dlg.line] or ""
  local sp, rest = cur:match("^%[(%S+)%]%s*(.*)$")
  -- dlg.npc may be nil for narrator-style sequences (campfire memories,
  -- in-line story banter). Fall back to no speaker label in that case.
  local speaker = sp or (dlg.npc and dlg.npc.name) or ""
  if speaker == "_party_scene" then speaker = "" end
  local body = rest or cur

  -- If the speaker is a party member, draw their sprite at the left of the
  -- dialogue box, animated like they're talking.
  local cls = DLG_NAME_TO_CLASS[speaker]
  local body_x = 4
  if cls then
    local saved = player.facing
    player.facing = "down"
    local fn = SPRITE_BY_CLASS[cls]
    if fn then
      local bob = ((tick % 6) < 3) and 0 or 1   -- 1-px talk bob
      fn(4, 38 - bob)
      -- yapping dot: little speech-bubble blip that flickers near the mouth
      if (tick % 4) < 2 then
        screen.level(15); screen.pixel(13, 41 - bob); screen.fill()
      end
    end
    player.facing = saved
    body_x = 16  -- shift body text right of the sprite
  end

  -- name strip (uses extracted speaker if available)
  screen.level(15)
  screen.move(body_x, 35)
  screen.text(speaker)
  screen.level(4)
  screen.move(body_x, 37)
  screen.line(60, 37)
  screen.stroke()
  -- wrapped body text — switch to the smaller Tom Thumb font when the
  -- body is long, so 4-5 lines all fit in the dialogue box.
  screen.level(13)
  local lines = wrap_text(body, 124 - body_x)
  if #lines > 3 then
    -- compact font fits ~5 short lines
    screen.font_face(25); screen.font_size(6)
    local lines_compact = wrap_text(body, 124 - body_x)
    for i = 1, math.min(5, #lines_compact) do
      screen.move(body_x, 41 + i * 5)
      screen.text(lines_compact[i])
    end
    screen.font_face(1); screen.font_size(8)
  else
    for i = 1, math.min(3, #lines) do
      screen.move(body_x, 38 + i * 8)
      screen.text(lines[i])
    end
  end
  -- advance prompt
  if (tick % 6) < 4 then
    screen.level(15)
    screen.move(122, 62)
    screen.text("v")
  end
end

-- ============================================================ DRAWING — BATTLE

local DRAW_ENEMY = {}

-- Practice dummy: a stout straw figure with concentric target rings.
-- Drawn calmly (tiny sway only) so it reads as "harmless" rather than alive.
function DRAW_ENEMY.dummy(cx, cy)
  local sway = math.sin(tick / 6) * 0.5
  -- post / pole
  screen.level(4)
  screen.move(cx + sway, cy + 8)
  screen.line(cx + sway, cy + 14)
  screen.stroke()
  -- straw body (rounded rectangle-ish)
  screen.level(8)
  screen.rect(cx - 6 + sway, cy - 6, 12, 14)
  screen.fill()
  -- target rings on the body
  screen.level(0)
  screen.circle(cx + sway, cy, 5)
  screen.stroke()
  screen.level(15)
  screen.circle(cx + sway, cy, 3)
  screen.fill()
  screen.level(0)
  screen.circle(cx + sway, cy, 1)
  screen.fill()
  -- arms (straw tufts)
  screen.level(6)
  screen.move(cx - 6 + sway, cy - 2); screen.line(cx - 9 + sway, cy + 1); screen.stroke()
  screen.move(cx + 6 + sway, cy - 2); screen.line(cx + 9 + sway, cy + 1); screen.stroke()
  -- friendly head: simple circle with two dots
  screen.level(10)
  screen.circle(cx + sway, cy - 9, 3)
  screen.fill()
  screen.level(0)
  screen.pixel(math.floor(cx - 1 + sway), math.floor(cy - 10)); screen.fill()
  screen.pixel(math.floor(cx + 1 + sway), math.floor(cy - 10)); screen.fill()
end

function DRAW_ENEMY.slime(cx, cy)
  local pulse = (tick % 4) / 4
  local r = 6 + math.floor(math.sin(pulse * math.pi * 2) * 1.5)
  screen.level(8)
  screen.circle(cx, cy, r)
  screen.fill()
  screen.level(0)
  screen.circle(cx - 1, cy - 1, 1)
  screen.fill()
end

function DRAW_ENEMY.bat(cx, cy)
  local wing = math.sin((tick % 2) / 2 * math.pi * 2) * 3
  screen.level(12)
  screen.circle(cx, cy, 2)
  screen.fill()
  screen.level(8)
  screen.move(cx - 9, cy - wing)
  screen.line(cx - 4, cy - 1)
  screen.line(cx - 1, cy + 1)
  screen.line(cx + 2, cy - 1)
  screen.line(cx + 6, cy - wing)
  screen.stroke()
end

function DRAW_ENEMY.mushroom(cx, cy)
  -- cap
  screen.level(11)
  screen.circle(cx, cy - 2, 5)
  screen.fill()
  -- stem
  screen.level(7)
  screen.rect(cx - 2, cy + 1, 4, 5)
  screen.fill()
  -- spots, alternating phase
  if (tick % 8) < 4 then
    screen.level(0)
    screen.pixel(cx - 3, cy - 3)
    screen.pixel(cx + 2, cy - 1)
  else
    screen.level(0)
    screen.pixel(cx - 1, cy - 4)
    screen.pixel(cx + 3, cy - 2)
  end
end

function DRAW_ENEMY.wisp(cx, cy)
  local pulse = (tick % 6) / 6
  -- outer halo flickers brightness
  screen.level(math.floor(3 + 3 * math.sin(pulse * math.pi * 2)))
  screen.circle(cx, cy, 5)
  screen.fill()
  -- core
  screen.level(15)
  screen.circle(cx, cy, 2)
  screen.fill()
  -- spark pixels orbit
  if (tick % 4) < 2 then
    screen.level(10)
    screen.pixel(cx - 4, cy - 3)
    screen.pixel(cx + 3, cy + 2)
  else
    screen.level(10)
    screen.pixel(cx + 4, cy - 2)
    screen.pixel(cx - 3, cy + 3)
  end
end

function DRAW_ENEMY.wolf(cx, cy)
  -- body
  screen.level(8)
  screen.rect(cx - 6, cy - 1, 12, 4)
  screen.fill()
  -- head
  screen.rect(cx + 4, cy - 3, 4, 3)
  screen.fill()
  -- ears
  screen.pixel(cx + 5, cy - 4)
  screen.pixel(cx + 7, cy - 4)
  -- tail (line back-and-up)
  screen.move(cx - 6, cy)
  screen.line(cx - 9, cy - 2)
  screen.stroke()
  -- legs
  screen.rect(cx - 5, cy + 3, 1, 2)
  screen.fill()
  screen.rect(cx - 1, cy + 3, 1, 2)
  screen.fill()
  screen.rect(cx + 5, cy + 3, 1, 2)
  screen.fill()
  -- eye
  screen.level(0)
  screen.pixel(cx + 6, cy - 2)
end

function DRAW_ENEMY.echo(cx, cy)
  -- big amorphous body that breathes
  local pulse = math.sin((tick % 8) / 8 * math.pi * 2)
  local r = 9 + math.floor(pulse * 1.5)
  screen.level(6)
  screen.circle(cx, cy, r)
  screen.fill()
  screen.level(2)
  screen.circle(cx, cy, math.max(1, r - 2))
  screen.fill()
  -- multiple eyes pulsing in 3-phase cycle
  local eye_phase = math.floor(tick / 4) % 3
  screen.level(15)
  if eye_phase == 0 then
    screen.rect(cx - 3, cy - 2, 2, 1)
    screen.fill()
    screen.pixel(cx + 2, cy + 1)
  elseif eye_phase == 1 then
    screen.rect(cx + 1, cy - 3, 2, 1)
    screen.fill()
    screen.pixel(cx - 4, cy + 2)
  else
    screen.pixel(cx, cy + 2)
    screen.pixel(cx + 4, cy - 1)
    screen.pixel(cx - 1, cy + 3)
  end
end

function DRAW_ENEMY.sprite(cx, cy)
  -- tiny darting magical creature: bright core + 4 trailing pixels
  local pulse = (tick % 6) / 6
  local r = 2 + math.floor(math.sin(pulse * math.pi * 2) * 1)
  screen.level(15)
  screen.circle(cx, cy, r)
  screen.fill()
  screen.level(8)
  screen.pixel(cx - 4, cy - 2)
  screen.pixel(cx + 4, cy + 1)
  screen.pixel(cx - 2, cy + 3)
  screen.pixel(cx + 3, cy - 3)
end

function DRAW_ENEMY.treant(cx, cy)
  -- A walking tree: wide gnarled trunk + two branch-arms + leafy crown +
  -- glowing eyes peering out of a face carved into the bark. Subtle sway.
  local sway = math.floor(math.sin(tick / 8) * 1)
  -- root base (splayed roots)
  screen.level(3)
  screen.move(cx - 7, cy + 11); screen.line(cx, cy + 7); screen.line(cx + 7, cy + 11)
  screen.close(); screen.fill()
  -- gnarled trunk (wider middle than top)
  screen.level(5)
  screen.rect(cx - 4 + sway, cy - 2, 8, 9); screen.fill()
  screen.level(3)
  screen.move(cx - 4 + sway, cy + 7); screen.line(cx + 4 + sway, cy + 7); screen.stroke()
  -- bark grooves (vertical lines on trunk)
  screen.level(3)
  screen.move(cx - 2 + sway, cy - 1); screen.line(cx - 2 + sway, cy + 6); screen.stroke()
  screen.move(cx + 2 + sway, cy - 1); screen.line(cx + 2 + sway, cy + 6); screen.stroke()
  -- branch-arms (one bent up, one down — like an Ent stride)
  screen.level(5)
  screen.move(cx - 4 + sway, cy);     screen.line(cx - 8 + sway, cy - 3); screen.stroke()
  screen.move(cx - 8 + sway, cy - 3); screen.line(cx - 9 + sway, cy);     screen.stroke()
  screen.move(cx + 4 + sway, cy + 1); screen.line(cx + 8 + sway, cy + 4); screen.stroke()
  screen.move(cx + 8 + sway, cy + 4); screen.line(cx + 9 + sway, cy + 1); screen.stroke()
  -- finger twigs at each hand
  screen.level(3)
  screen.pixel(cx - 9 + sway, cy - 1); screen.pixel(cx - 10 + sway, cy + 1); screen.fill()
  screen.pixel(cx + 9 + sway, cy + 5); screen.pixel(cx + 10 + sway, cy + 3); screen.fill()
  -- leafy crown (rounded blob with little leaf clusters)
  screen.level(7)
  screen.circle(cx + sway, cy - 6, 5); screen.fill()
  screen.level(11)
  screen.pixel(cx - 3 + sway, cy - 8); screen.pixel(cx + 4 + sway, cy - 7)
  screen.pixel(cx - 1 + sway, cy - 10); screen.pixel(cx + 2 + sway, cy - 9); screen.fill()
  screen.level(3)  -- shadow underside of crown
  screen.move(cx - 4 + sway, cy - 3); screen.line(cx + 4 + sway, cy - 3); screen.stroke()
  -- carved face: hollow eyes (glow) + mouth slit
  local lit = (tick % 30) < 22
  screen.level(lit and 13 or 8)
  screen.pixel(cx - 2 + sway, cy + 1); screen.pixel(cx + 2 + sway, cy + 1); screen.fill()
  screen.level(0)
  screen.move(cx - 2 + sway, cy + 4); screen.line(cx + 2 + sway, cy + 4); screen.stroke()
end

function DRAW_ENEMY.sentinel(cx, cy)
  -- tall guardian with antlers, slowly swaying
  local sway = math.floor(math.sin((tick % 32) / 32 * math.pi * 2) * 1.5)
  -- body
  screen.level(8)
  screen.rect(cx - 4 + sway, cy - 4, 8, 12)
  screen.fill()
  -- antlers
  screen.level(11)
  screen.move(cx - 5 + sway, cy - 4)
  screen.line(cx - 7 + sway, cy - 8)
  screen.move(cx - 5 + sway, cy - 4)
  screen.line(cx - 4 + sway, cy - 7)
  screen.move(cx + 4 + sway, cy - 4)
  screen.line(cx + 6 + sway, cy - 8)
  screen.move(cx + 4 + sway, cy - 4)
  screen.line(cx + 3 + sway, cy - 7)
  screen.stroke()
  -- glowing eyes (2-phase)
  local lit = (tick % 16) < 12
  screen.level(lit and 15 or 4)
  screen.pixel(cx - 2 + sway, cy - 1)
  screen.pixel(cx + 2 + sway, cy - 1)
end

function DRAW_ENEMY.crab(cx, cy)
  -- low oval body + 2 claws + skitter offset
  local skitter = (tick % 4) < 2 and -1 or 1
  screen.level(10)
  screen.rect(cx - 4 + skitter, cy, 8, 4)
  screen.fill()
  -- claws (small triangles to either side)
  screen.move(cx - 6 + skitter, cy + 2)
  screen.line(cx - 8 + skitter, cy)
  screen.line(cx - 4 + skitter, cy)
  screen.close()
  screen.fill()
  screen.move(cx + 6 + skitter, cy + 2)
  screen.line(cx + 8 + skitter, cy)
  screen.line(cx + 4 + skitter, cy)
  screen.close()
  screen.fill()
  -- eyes
  screen.level(0)
  screen.pixel(cx - 1 + skitter, cy + 1)
  screen.pixel(cx + 2 + skitter, cy + 1)
end

function DRAW_ENEMY.manta(cx, cy)
  -- diamond/triangle gliding shape, slow swoop
  local sw = math.floor(math.sin((tick % 12) / 12 * math.pi * 2) * 2)
  screen.level(8)
  screen.move(cx, cy - 4)
  screen.line(cx - 7, cy + sw)
  screen.line(cx, cy + 4)
  screen.line(cx + 7, cy + sw)
  screen.close()
  screen.fill()
  -- tail
  screen.move(cx, cy + 4)
  screen.line(cx, cy + 7)
  screen.stroke()
  -- eyespots
  screen.level(0)
  screen.pixel(cx - 2, cy)
  screen.pixel(cx + 2, cy)
end

function DRAW_ENEMY.tide(cx, cy)
  -- broad wave-creature with multiple peaks, slow churning
  local phase = (tick % 16) / 16 * math.pi * 2
  screen.level(5)
  -- low wide body
  screen.rect(cx - 10, cy + 1, 20, 6)
  screen.fill()
  -- wave peaks
  screen.level(8)
  for i = -2, 2 do
    local px = cx + i * 4
    local h = 4 + math.floor(math.sin(phase + i * 0.7) * 2)
    screen.move(px - 2, cy + 1)
    screen.line(px, cy + 1 - h)
    screen.line(px + 2, cy + 1)
    screen.close()
    screen.fill()
  end
  -- shimmering eyes
  if (tick % 8) < 6 then
    screen.level(15)
    screen.pixel(cx - 3, cy + 4)
    screen.pixel(cx + 3, cy + 4)
  end
end

function DRAW_ENEMY.scorpion(cx, cy)
  -- low body + curled tail + claws
  screen.level(10)
  screen.rect(cx - 4, cy + 1, 8, 3)
  screen.fill()
  -- claws (forward)
  screen.move(cx - 6, cy + 1); screen.line(cx - 8, cy - 1); screen.line(cx - 4, cy + 1); screen.close(); screen.fill()
  screen.move(cx + 6, cy + 1); screen.line(cx + 8, cy - 1); screen.line(cx + 4, cy + 1); screen.close(); screen.fill()
  -- segmented tail curling up over the back
  screen.level(13)
  screen.pixel(cx + 1, cy)
  screen.pixel(cx + 2, cy - 1)
  screen.pixel(cx + 1, cy - 2)
  screen.pixel(cx, cy - 3)
  screen.pixel(cx - 1, cy - 2)
  -- stinger
  screen.level(15)
  screen.pixel(cx - 2, cy - 3)
end

function DRAW_ENEMY.spectre(cx, cy)
  -- ghostly tall figure with wavy bottom
  local sw = math.floor(math.sin((tick % 16) / 16 * math.pi * 2) * 1)
  screen.level(7)
  -- body
  screen.move(cx - 4 + sw, cy - 6)
  screen.line(cx + 4 + sw, cy - 6)
  screen.line(cx + 5 + sw, cy + 5)
  screen.line(cx + 2 + sw, cy + 6)
  screen.line(cx + sw,     cy + 5)
  screen.line(cx - 2 + sw, cy + 6)
  screen.line(cx - 5 + sw, cy + 5)
  screen.close()
  screen.fill()
  -- glowing eyes
  if (tick % 12) < 8 then
    screen.level(15)
    screen.pixel(cx - 2 + sw, cy - 3)
    screen.pixel(cx + 2 + sw, cy - 3)
  end
end

function DRAW_ENEMY.dunerider(cx, cy)
  -- large mounted figure: body of sand-mount + rider above
  local phase = (tick % 16) / 16 * math.pi * 2
  -- mount body (low broad)
  screen.level(11)
  screen.rect(cx - 9, cy + 2, 18, 5)
  screen.fill()
  -- mount head
  screen.move(cx + 9, cy + 2)
  screen.line(cx + 12, cy + 4)
  screen.line(cx + 9, cy + 6)
  screen.close()
  screen.fill()
  -- legs (two pairs)
  screen.rect(cx - 6, cy + 7, 1, 2); screen.fill()
  screen.rect(cx - 2, cy + 7, 1, 2); screen.fill()
  screen.rect(cx + 4, cy + 7, 1, 2); screen.fill()
  screen.rect(cx + 7, cy + 7, 1, 2); screen.fill()
  -- rider on top
  screen.level(5)
  screen.rect(cx - 1, cy - 4, 4, 6)
  screen.fill()
  -- rider head
  screen.level(13)
  screen.rect(cx, cy - 6, 2, 2)
  screen.fill()
  -- spear with phase
  screen.level(15)
  screen.move(cx + 3, cy - 4)
  screen.line(cx + 7 + math.floor(math.sin(phase) * 1), cy - 8)
  screen.stroke()
  -- eyes
  if (tick % 8) < 6 then
    screen.level(0)
    screen.pixel(cx - 4, cy + 4)
    screen.pixel(cx + 1, cy + 4)
  end
end

-- Cave 5 enemies (Northern Wilds)
function DRAW_ENEMY.yeti(cx, cy)
  -- huge furred shape, two arms
  screen.level(15)
  screen.rect(cx - 14, cy - 16, 28, 28)  -- white furred body
  screen.fill()
  screen.level(11)
  -- arms
  screen.rect(cx - 18, cy - 8, 4, 14)
  screen.fill()
  screen.rect(cx + 14, cy - 8, 4, 14)
  screen.fill()
  -- darker face hollow
  screen.level(2)
  screen.rect(cx - 6, cy - 10, 12, 6)
  screen.fill()
  -- glowing eyes
  screen.level(15)
  screen.pixel(cx - 3, cy - 7)
  screen.pixel(cx + 2, cy - 7)
  -- horn tusks
  screen.level(13)
  screen.move(cx - 4, cy - 4); screen.line(cx - 6, cy); screen.stroke()
  screen.move(cx + 3, cy - 4); screen.line(cx + 5, cy); screen.stroke()
end

function DRAW_ENEMY.frostwisp(cx, cy)
  -- shimmering ice diamond + drift
  local d = (tick // 4) % 8
  screen.level(15)
  screen.move(cx,     cy - 12 + d)
  screen.line(cx + 8, cy)
  screen.line(cx,     cy + 12 + d)
  screen.line(cx - 8, cy)
  screen.close()
  screen.fill()
  -- inner shadow
  screen.level(7)
  screen.move(cx,     cy - 6 + d)
  screen.line(cx + 4, cy)
  screen.line(cx,     cy + 6 + d)
  screen.line(cx - 4, cy)
  screen.close()
  screen.fill()
  -- core
  screen.level(15)
  screen.pixel(cx, cy)
  -- snowflakes around
  screen.level(13)
  screen.pixel(cx - 12, cy - 4 + d)
  screen.pixel(cx + 13, cy + 6 - d)
end

function DRAW_ENEMY.granite(cx, cy)
  -- jagged stone golem
  screen.level(7)
  screen.rect(cx - 16, cy - 14, 32, 28)
  screen.fill()
  -- carved planes
  screen.level(2)
  screen.move(cx - 16, cy - 14); screen.line(cx + 16, cy - 4); screen.stroke()
  screen.move(cx - 16, cy + 8); screen.line(cx + 16, cy + 14); screen.stroke()
  screen.move(cx, cy - 14); screen.line(cx - 8, cy + 14); screen.stroke()
  -- glowing ore eyes
  screen.level(15)
  screen.pixel(cx - 6, cy - 6)
  screen.pixel(cx + 6, cy - 4)
  -- arms (stubby boulders)
  screen.level(11)
  screen.rect(cx - 20, cy - 4, 4, 12); screen.fill()
  screen.rect(cx + 16, cy - 2, 4, 12); screen.fill()
end

function DRAW_ENEMY.crow(cx, cy)
  -- silhouetted bird wraith
  screen.level(0)
  screen.rect(cx - 14, cy - 8, 28, 16)
  screen.fill()
  -- body
  screen.level(2)
  screen.rect(cx - 6, cy - 4, 12, 10)
  screen.fill()
  -- wings (flap with tick)
  local f = (tick // 4) % 2
  screen.level(0)
  if f == 0 then
    screen.move(cx - 6, cy);  screen.line(cx - 18, cy - 6); screen.line(cx - 6, cy + 4); screen.close(); screen.fill()
    screen.move(cx + 6, cy);  screen.line(cx + 18, cy - 6); screen.line(cx + 6, cy + 4); screen.close(); screen.fill()
  else
    screen.move(cx - 6, cy);  screen.line(cx - 16, cy + 6); screen.line(cx - 6, cy + 4); screen.close(); screen.fill()
    screen.move(cx + 6, cy);  screen.line(cx + 16, cy + 6); screen.line(cx + 6, cy + 4); screen.close(); screen.fill()
  end
  -- head + glowing eyes
  screen.level(0)
  screen.rect(cx - 3, cy - 9, 6, 5)
  screen.fill()
  screen.level(15)
  screen.pixel(cx - 2, cy - 7)
  screen.pixel(cx + 1, cy - 7)
  -- beak
  screen.level(11)
  screen.move(cx - 1, cy - 4); screen.line(cx + 2, cy - 2); screen.line(cx - 1, cy - 2); screen.close(); screen.fill()
end

function DRAW_ENEMY.snowgaunt(cx, cy)
  -- towering frost lich figure
  -- robe shape
  screen.level(11)
  screen.move(cx,      cy - 22)
  screen.line(cx - 18, cy + 18)
  screen.line(cx + 18, cy + 18)
  screen.close()
  screen.fill()
  -- hood frost trim
  screen.level(15)
  screen.move(cx - 10, cy - 12); screen.line(cx + 10, cy - 12); screen.stroke()
  -- skull face inside hood
  screen.level(2)
  screen.rect(cx - 5, cy - 18, 10, 8); screen.fill()
  screen.level(15)
  -- two glowing icy eyes
  screen.pixel(cx - 2, cy - 14); screen.pixel(cx - 3, cy - 14)
  screen.pixel(cx + 2, cy - 14); screen.pixel(cx + 3, cy - 14)
  -- jaw line
  screen.level(0)
  screen.move(cx - 4, cy - 11); screen.line(cx + 4, cy - 11); screen.stroke()
  -- icicle staff
  screen.level(13)
  screen.rect(cx + 16, cy - 16, 1, 30); screen.fill()
  screen.level(15)
  screen.pixel(cx + 16, cy - 17)
  -- snow swirl around base (animates)
  local s = (tick // 3) % 6
  screen.level(15)
  screen.pixel(cx - 12 + s, cy + 18)
  screen.pixel(cx + 12 - s, cy + 16)
end

-- Cave 6 + 7 enemies (Suno's Domain)
function DRAW_ENEMY.lich(cx, cy)
  -- skeletal robed figure
  screen.level(2)
  screen.move(cx, cy - 18); screen.line(cx - 14, cy + 14); screen.line(cx + 14, cy + 14); screen.close(); screen.fill()
  screen.level(15)  -- skull
  screen.rect(cx - 5, cy - 14, 10, 8); screen.fill()
  screen.level(0)
  screen.pixel(cx - 2, cy - 11); screen.pixel(cx + 2, cy - 11)  -- eye sockets
  screen.move(cx - 3, cy - 8); screen.line(cx + 3, cy - 8); screen.stroke()
  -- staff
  screen.level(11)
  screen.rect(cx + 12, cy - 16, 1, 30); screen.fill()
  screen.level(15)
  screen.pixel(cx + 12, cy - 17)
end

function DRAW_ENEMY.voidcrawler(cx, cy)
  -- many-legged shadow with glowing dots
  screen.level(0)
  screen.rect(cx - 14, cy - 6, 28, 14); screen.fill()
  screen.level(2)
  screen.rect(cx - 10, cy - 4, 20, 10); screen.fill()
  -- legs
  screen.level(11)
  for i = 0, 4 do
    screen.move(cx - 10 + i * 5, cy + 6)
    screen.line(cx - 10 + i * 5, cy + 12)
    screen.stroke()
  end
  -- glowing eye-line (animated)
  local s = (tick // 4) % 4
  screen.level(15)
  for i = 0, 3 do
    if i == s then screen.pixel(cx - 6 + i * 4, cy - 1)
    else screen.pixel(cx - 6 + i * 4, cy - 1) end
  end
end

function DRAW_ENEMY.echosuno(cx, cy)
  -- mocking shadow figure resembling suno (smaller, paler)
  screen.level(7)
  screen.move(cx, cy - 16); screen.line(cx - 12, cy + 12); screen.line(cx + 12, cy + 12); screen.close(); screen.fill()
  -- hood
  screen.level(2)
  screen.rect(cx - 4, cy - 14, 8, 6); screen.fill()
  -- eyes (mocking smile)
  screen.level(15)
  screen.pixel(cx - 2, cy - 11); screen.pixel(cx + 2, cy - 11)
  screen.move(cx - 3, cy - 8); screen.line(cx - 1, cy - 6); screen.line(cx + 1, cy - 6); screen.line(cx + 3, cy - 8); screen.stroke()
end

function DRAW_ENEMY.mutewarden(cx, cy)
  -- silent armored sentry, no face
  screen.level(7)
  screen.rect(cx - 12, cy - 14, 24, 26); screen.fill()
  -- helm visor (closed)
  screen.level(0)
  screen.rect(cx - 6, cy - 10, 12, 4); screen.fill()
  -- chestplate cross
  screen.level(11)
  screen.move(cx, cy - 4); screen.line(cx, cy + 8); screen.stroke()
  screen.move(cx - 6, cy + 2); screen.line(cx + 6, cy + 2); screen.stroke()
  -- rivets
  screen.level(13)
  screen.pixel(cx - 10, cy - 12); screen.pixel(cx + 10, cy - 12)
  screen.pixel(cx - 10, cy + 10); screen.pixel(cx + 10, cy + 10)
end

function DRAW_ENEMY.locrius(cx, cy)
  -- conductor of void: tall robed, sweeping arms
  screen.level(2)
  screen.move(cx, cy - 22); screen.line(cx - 18, cy + 18); screen.line(cx + 18, cy + 18); screen.close(); screen.fill()
  -- bone hands extended
  screen.level(15)
  screen.move(cx - 16, cy - 4); screen.line(cx - 22, cy + 4); screen.stroke()
  screen.move(cx + 16, cy - 4); screen.line(cx + 22, cy + 4); screen.stroke()
  -- hood
  screen.level(0)
  screen.rect(cx - 5, cy - 18, 10, 7); screen.fill()
  -- triple-eye mark (locrian/diabolus)
  screen.level(15)
  screen.pixel(cx - 3, cy - 14); screen.pixel(cx, cy - 14); screen.pixel(cx + 3, cy - 14)
  -- whirling shadow at base
  local s = (tick // 3) % 6
  screen.level(11)
  screen.pixel(cx - 14 + s, cy + 18)
  screen.pixel(cx + 14 - s, cy + 16)
end

function DRAW_ENEMY.suno(cx, cy)
  -- towering crowned tyrant with broken-crystal aura
  -- huge robed silhouette
  screen.level(0)
  screen.rect(cx - 22, cy - 22, 44, 44); screen.fill()
  -- robe interior
  screen.level(2)
  screen.move(cx, cy - 22); screen.line(cx - 22, cy + 18); screen.line(cx + 22, cy + 18); screen.close(); screen.fill()
  -- crown spikes
  screen.level(15)
  screen.move(cx - 8, cy - 20); screen.line(cx - 5, cy - 26); screen.line(cx - 2, cy - 20); screen.stroke()
  screen.move(cx - 2, cy - 20); screen.line(cx, cy - 28); screen.line(cx + 2, cy - 20); screen.stroke()
  screen.move(cx + 2, cy - 20); screen.line(cx + 5, cy - 26); screen.line(cx + 8, cy - 20); screen.stroke()
  -- masked face
  screen.level(7)
  screen.rect(cx - 6, cy - 18, 12, 8); screen.fill()
  -- glowing eyes (red-ish on norns = max bright)
  if (tick // 4) % 2 == 0 then
    screen.level(15)
  else
    screen.level(11)
  end
  screen.rect(cx - 4, cy - 15, 3, 2); screen.fill()
  screen.rect(cx + 1, cy - 15, 3, 2); screen.fill()
  -- chest crystal (broken)
  screen.level(13)
  screen.move(cx, cy - 4); screen.line(cx - 4, cy + 2); screen.line(cx, cy + 8); screen.line(cx + 4, cy + 2); screen.close(); screen.fill()
  screen.level(0)
  screen.move(cx, cy - 4); screen.line(cx, cy + 8); screen.stroke()
  -- floating shard fragments (animate around)
  local s = (tick // 2) % 8
  screen.level(15)
  screen.pixel(cx - 18 + s, cy - 8)
  screen.pixel(cx + 18 - s, cy + 4)
  screen.pixel(cx - 14, cy + 12 - s)
  -- arms outstretched
  screen.level(7)
  screen.move(cx - 18, cy + 4); screen.line(cx - 22, cy + 14); screen.stroke()
  screen.move(cx + 18, cy + 4); screen.line(cx + 22, cy + 14); screen.stroke()
end


-- Per-action firing animation. Called from the HUD on the active sprite cell.
-- (sx, sy) = top-left of 8x8 sprite. Animation lasts ~6 ticks (~0.7s @100bpm).
ANIM.draw_action_fx = function(p, sx, sy)
  local t = tick - p.last_fire
  if t < 0 or t > 5 then return end
  local action = p.last_action
  if not action then return end
  local cxc, cyc = sx + 4, sy + 4              -- sprite center
  local ex, ey = 96, 24                         -- enemy center
  if action == "ATK" then
    -- Slash: trail of 3 bright pixels traveling from sprite to enemy
    for k = 0, 2 do
      local prog = (t + 1) / 7 - k * 0.10
      if prog > 0 and prog < 1 then
        local px = math.floor(cxc + (ex - cxc) * prog)
        local py = math.floor(cyc + (ey - cyc) * prog)
        screen.level(15 - k * 4)
        screen.pixel(px, py); screen.pixel(px + 1, py); screen.fill()
      end
    end
    -- short slash mark on the sprite side at the start
    if t < 2 then
      screen.level(15)
      screen.move(sx + 7, sy); screen.line(sx + 9, sy + 5); screen.stroke()
    end
  elseif action == "MAG" then
    -- Spell sparkles: bright stars near the enemy + a vertical bolt arriving
    if t >= 2 then
      screen.level(15)
      screen.rect(ex, ey - 16 + (t - 2) * 4, 1, 4); screen.fill()  -- bolt descends
    end
    local seed = p.last_fire * 17 + t
    for k = 0, 4 do
      local sxk = ex - 8 + ((seed * 13 + k * 7) % 16)
      local syk = ey - 6 + ((seed * 5  + k * 3) % 12)
      screen.level(15 - t * 2)
      screen.pixel(sxk, syk); screen.pixel(sxk + 1, syk); screen.pixel(sxk, syk + 1); screen.fill()
    end
  elseif action == "PLAY" or action == "LYRE" or action == "HORN" or action == "SMPL" then
    -- Musical notes drifting up. Different glyph counts/colors per instrument
    -- so each character's "play" feels visually distinct.
    local count, color = 3, 15
    if action == "LYRE" then count, color = 4, 13          -- gentle gold
    elseif action == "HORN" then count, color = 2, 11      -- bold low notes
    elseif action == "SMPL" then count, color = 5, 15      -- many bright sparks
    end
    for k = 0, count - 1 do
      local nx = sx + 1 + k * 2
      local ny = sy - 2 - k * 3 - t
      if ny > 30 then
        screen.level(color - k * 2)
        screen.rect(nx, ny, 2, 2); screen.fill()
        screen.move(nx + 2, ny - 3); screen.line(nx + 2, ny + 1); screen.stroke()
      end
    end
  elseif action == "BLK" then
    -- Shield bash: thick double outline pulses on the sprite, then fades
    local lev = (t < 3) and 15 or 8
    screen.level(lev)
    screen.rect(sx - 1, sy - 1, 10, 10); screen.stroke()
    if t < 3 then
      screen.rect(sx - 2, sy - 2, 12, 12); screen.stroke()
    end
    -- impact mark center
    if t < 2 then
      screen.level(15)
      screen.rect(cxc - 1, cyc - 1, 3, 3); screen.fill()
    end
  elseif action == "DEF" then
    -- Expanding bright diamond (shield-up) around the sprite
    local r = 3 + t
    screen.level(15 - t * 2)
    screen.move(cxc - r, cyc); screen.line(cxc, cyc - r); screen.stroke()
    screen.move(cxc, cyc - r); screen.line(cxc + r, cyc); screen.stroke()
    screen.move(cxc + r, cyc); screen.line(cxc, cyc + r); screen.stroke()
    screen.move(cxc, cyc + r); screen.line(cxc - r, cyc); screen.stroke()
  elseif action == "ITM" then
    -- Bright + cross on the sprite + 4 corner sparkles flying outward
    screen.level(15 - t)
    screen.move(cxc - 2, cyc); screen.line(cxc + 2, cyc); screen.stroke()
    screen.move(cxc, cyc - 2); screen.line(cxc, cyc + 2); screen.stroke()
    local off = 4 + t
    screen.pixel(cxc - off, cyc - off)
    screen.pixel(cxc + off, cyc - off)
    screen.pixel(cxc - off, cyc + off)
    screen.pixel(cxc + off, cyc + off)
    screen.fill()
  end
end

-- Mini joystick visualizer (8×8). Crosshair + center rest dot + glowing stick
-- dot with a subtle 1-pixel halo. nx, ny in [-1, 1].
ANIM.draw_stick = function(box_x, box_y, nx, ny)
  screen.level(3)
  screen.rect(box_x, box_y, 8, 8); screen.stroke()
  -- crosshair
  screen.level(2)
  screen.move(box_x + 0, box_y + 4); screen.line(box_x + 8, box_y + 4); screen.stroke()
  screen.move(box_x + 4, box_y + 0); screen.line(box_x + 4, box_y + 8); screen.stroke()
  -- center rest tick
  screen.level(4)
  screen.pixel(box_x + 4, box_y + 4); screen.fill()
  -- stick dot with halo
  local dx = math.floor(box_x + 4 + (nx or 0) * 3 + 0.5)
  local dy = math.floor(box_y + 4 + (ny or 0) * 3 + 0.5)
  screen.level(7)
  screen.pixel(dx - 1, dy); screen.pixel(dx + 1, dy); screen.pixel(dx, dy - 1); screen.pixel(dx, dy + 1); screen.fill()
  screen.level(15)
  screen.pixel(dx, dy); screen.fill()
end

local function draw_battle()
  -- ── TOP BAR (rows 0-7): cave name (left) with tiny BPM/key inline ──
  screen.font_face(25); screen.font_size(6)
  screen.level(15)
  screen.move(2, 6)
  screen.text((ANIM.cave_names[current_cave] or "CAVE"))
  -- BPM + key anchored RIGHT NEXT TO the cave name, smaller / dimmer
  local cave_w = screen.text_extents((ANIM.cave_names[current_cave] or "CAVE"))
  screen.level(4)
  screen.move(2 + cave_w + 3, 6)
  screen.text(BATTLE_BPM .. " " .. JAM.note_names[((JAM.root or 0) % 12) + 1])
  screen.font_face(1); screen.font_size(8)
  -- Two stick mini-pads at the top-right (left stick = reverb/delay, right = cutoff/res).
  -- Indicators reflect the ACTIVE voice's latched stick — switching voices makes
  -- the dot jump to that voice's remembered effect setting.
  local apvc = party[active]
  local lx, ly, rx, ry = 0, 0, 0, 0
  if apvc and apvc.stick then
    lx, ly, rx, ry = apvc.stick.lx, apvc.stick.ly, apvc.stick.rx, apvc.stick.ry
  end
  ANIM.draw_stick(108, 0, lx, ly)
  ANIM.draw_stick(118, 0, rx, ry)

  -- ── SCENE (rows 9-44): action popup on left, party sprites bottom-left, enemy right ──
  screen.level(3)
  screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- Climax dimming: as enemy HP drops below 30%, paint a faint dark veil over
  -- the scene area to add visual tension to the final blows.
  if enemy and enemy.hp_max and enemy.hp_max > 0 then
    local hp_pct = enemy.hp / enemy.hp_max
    if hp_pct < 0.30 then
      local dim = math.floor((0.30 - hp_pct) / 0.30 * 3)  -- 0..3
      if dim > 0 then
        screen.level(dim)
        screen.rect(0, 10, 128, 36); screen.fill()
      end
    end
  end
  -- Region-specific battle background: a sparse moving texture layered behind
  -- the enemy + popup. Stays subtle (level 1-3) so foreground reads cleanly.
  do
    local cc = current_cave
    if cc == 1 then
      -- Cave: faint dripping dots
      for i = 1, 6 do
        local dx = (i * 23) % 128
        local dy = 11 + ((tick // 2 + i * 7) % 30)
        screen.level(2); screen.pixel(dx, dy); screen.fill()
      end
    elseif cc == 2 then
      -- Hollow Woods: drifting leaves
      for i = 1, 5 do
        local lx = (i * 31 + tick * 2) % 128
        local ly = 12 + ((i * 11 + tick) % 30)
        screen.level(3); screen.pixel(lx, ly); screen.fill()
      end
    elseif cc == 3 then
      -- Tide cavern: horizontal water shimmer
      for r = 0, 2 do
        local off = (tick * (r + 1)) % 16
        screen.level(2)
        for x = -off, 128, 16 do
          screen.move(x, 14 + r * 10); screen.line(x + 6, 14 + r * 10); screen.stroke()
        end
      end
    elseif cc == 4 then
      -- Glass cavern: sand grains rising
      for i = 1, 7 do
        local sx = (i * 17) % 128
        local sy = 42 - ((tick // 2 + i * 5) % 30)
        screen.level(3); screen.pixel(sx, sy); screen.fill()
      end
    elseif cc == 5 then
      -- Ice grotto: snowflakes drifting down
      for i = 1, 6 do
        local sx = (i * 19 + (tick // 3)) % 128
        local sy = 12 + ((tick + i * 9) % 30)
        screen.level(3); screen.pixel(sx, sy); screen.fill()
        screen.level(2); screen.pixel(sx + 1, sy); screen.fill()
      end
    elseif cc == 6 then
      -- Locrian crypt: pulsing void shadow streaks
      for i = 1, 4 do
        local x = (i * 31) % 128
        local lev = ((tick // 4 + i) % 3) + 1
        screen.level(lev); screen.rect(x, 12, 14, 1); screen.fill()
      end
    elseif cc == 7 then
      -- Suno's chamber: glyph flicker around the boss
      for i = 1, 5 do
        local gx = 60 + ((i * 13 + tick // 4) % 30)
        local gy = 12 + ((i * 7) % 30)
        local lev = ((tick + i * 5) % 8 < 4) and 4 or 2
        screen.level(lev); screen.pixel(gx, gy); screen.pixel(gx + 1, gy + 1); screen.fill()
      end
    end
  end

  -- ENEMY sprite shifted DOWN so its head clears the new compact HP bar above.
  -- Center moved from (96, 24) → (96, 32). Suno (44 tall) still extends a bit
  -- past the HUD divider but clipping is cosmetic.
  if enemy and enemy.alive then
    local fn = DRAW_ENEMY[enemy.visual] or DRAW_ENEMY.slime
    fn(96, 32)
  end
  -- Compact enemy info pinned to the top of the scene (rows 11-15), placed in the
  -- gap between the action popup (x=1-44) and the enemy sprite area on the right.
  if enemy then
    screen.font_face(25); screen.font_size(6)
    screen.level(11)
    screen.move(46, 14)
    screen.text(enemy.name)
    if enemy.invincible then
      -- Practice dummy: replace HP/bar with a calm "JAM PAD" hint and exit prompt
      screen.level(6)
      screen.move(126, 14)
      screen.text_right("JAM PAD")
      screen.level(3)
      screen.move(76, 16); screen.line(126, 16); screen.stroke()
      screen.level(5)
      screen.move(126, 22)
      screen.text_right("START: exit")
    else
      -- HP "X/Y" right-aligned, tiny font
      screen.level(7)
      screen.move(126, 14)
      screen.text_right(math.max(0, enemy.hp) .. "/" .. enemy.hp_max)
      -- HP bar: 1 px tall, narrower (28 wide), positioned just below the text
      local hp_w = 50
      local hp_x = 76
      screen.level(2); screen.rect(hp_x, 16, hp_w, 1); screen.fill()
      if enemy.hp_max > 0 then
        local fill = math.floor(hp_w * math.max(0, enemy.hp) / enemy.hp_max)
        if fill > 0 then
          screen.level(13)
          screen.rect(hp_x, 16, fill, 1); screen.fill()
        end
      end
    end
    screen.font_face(1); screen.font_size(8)
  end

  -- ACTION POPUP on the left (lists the active character's 4 class actions)
  local ap = party[active]
  if ap then
    local px, py, pw, ph = 1, 11, 44, 28
    screen.level(0); screen.rect(px, py, pw, ph); screen.fill()
    screen.level(11); screen.rect(px, py, pw, ph); screen.stroke()
    screen.level(15)
    screen.move(px + pw / 2 - 4, py + 6)
    screen.text_center(CHAR_NAME[ap.class])
    -- Equipped instrument icon (8x8) in the top-right corner
    local eq_id = equipped[ap.class]
    if eq_id and INST.sprites[eq_id] then
      INST.sprites[eq_id](px + pw - 9, py + 1)
    end
    screen.level(4)
    screen.move(px + 1, py + 8); screen.line(px + pw - 1, py + 8); screen.stroke()
    -- 4 actions in fixed A/B/X/Y order
    local ca = CLASS_ACTIONS[ap.class]
    local actions = {ca.A, ca.B, ca.X, ca.Y}
    for i, act in ipairs(actions) do
      local y = py + 13 + (i - 1) * 5
      local sel = (act == ap.queued)
      screen.level(sel and 15 or 6)
      screen.move(px + 3, y)
      screen.font_face(25); screen.font_size(6)
      screen.text((sel and ">" or " ") .. act)
      screen.font_face(1); screen.font_size(8)
    end
  end

  -- ── HUD (bottom 16 px, rows 48-63): 4 compact character columns ──
  -- Sprite (with fire/hit/active animations) + tiny HP number + thin HP/ATB bars
  -- + queued-action label. The HUD sprite IS the battle sprite.
  screen.level(3)
  screen.move(0, 47); screen.line(128, 47); screen.stroke()
  -- face all sprites right toward the enemy in the HUD
  local saved_facing = player.facing
  player.facing = "right"
  for i, p in ipairs(party) do
    local cx = (i - 1) * 32
    local active_col = (i == active)
    -- column highlight bg for active char
    if active_col then
      screen.level(2)
      screen.rect(cx, 48, 32, 16); screen.fill()
    end
    -- low-HP warning: when alive p ≤ 25% HP, pulse a bright frame
    if p.alive and p.hp_max > 0 and p.hp <= p.hp_max / 4 then
      screen.level((tick % 6 < 3) and 15 or 8)
      screen.rect(cx, 48, 32, 16); screen.stroke()
    end
    -- character sprite (left of column at row 49) — battle animations land here
    local sx, sy = cx + 1, 49
    if p.alive then
      local fn = SPRITE_BY_CLASS[p.class]
      if fn then fn(sx, sy) end
      -- per-action firing animation (slash / spell / notes / shield / barrier / heal sparkle)
      ANIM.draw_action_fx(p, sx, sy)
      -- recently hit = bright outline + 4 corner sparks (sprite stays visible)
      if (tick - p.last_hit) < 3 then
        screen.level(15)
        screen.rect(sx - 1, sy - 1, 10, 10); screen.stroke()
        screen.pixel(sx - 2, sy - 2); screen.pixel(sx + 9, sy - 2)
        screen.pixel(sx - 2, sy + 9); screen.pixel(sx + 9, sy + 9); screen.fill()
      end
    else
      -- KO marker: faint X
      screen.level(2)
      screen.rect(sx, sy, 8, 8); screen.fill()
      screen.level(8)
      screen.move(sx, sy); screen.line(sx + 7, sy + 7); screen.stroke()
      screen.move(sx + 7, sy); screen.line(sx, sy + 7); screen.stroke()
    end
    -- right side: tiny HP "X/Y" at native size 6 (crisp) + thin bars
    screen.font_face(25); screen.font_size(6)
    screen.level(p.alive and (p.hp <= p.hp_max / 4 and 15 or 10) or 4)
    screen.move(cx + 30, 52)
    screen.text_right(p.hp .. "/" .. p.hp_max)
    -- HP bar — 1 px tall, slimmer
    local bx, bw = cx + 11, 16
    screen.level(2); screen.rect(bx, 54, bw, 1); screen.fill()
    if p.alive then
      local fill = math.floor(bw * p.hp / p.hp_max)
      if fill > 0 then
        screen.level(p.hp <= p.hp_max / 4 and 15 or 11)
        screen.rect(bx, 54, fill, 1); screen.fill()
      end
    end
    -- ATB bar — 1 px tall
    screen.level(2); screen.rect(bx, 56, bw, 1); screen.fill()
    if p.alive then
      local fill = math.floor(bw * (p.atb / 16))
      if fill > 0 then
        screen.level(active_col and 14 or 8)
        screen.rect(bx, 56, fill, 1); screen.fill()
      end
    end
    -- queued action label (back at native size 6 — readable)
    screen.font_size(6)
    screen.level(p.alive and (active_col and 15 or 11) or 4)
    screen.move(cx + 11, 62)
    screen.text(p.queued or "")
    -- status markers (right edge): up to 2 stacked symbols showing all
    -- active buffs/debuffs at a glance.
    if p.alive then
      local marks = {}
      if p.blocking then marks[#marks+1] = "B" end
      if p.buffed then marks[#marks+1] = "+" end
      if p.shield then marks[#marks+1] = "*" end
      if (p.regen_hp_ticks or 0) > 0 then marks[#marks+1] = "R" end
      if (p.dmg_reduce_ticks or 0) > 0 then marks[#marks+1] = "D" end
      if (p.poison_ticks or 0) > 0 then marks[#marks+1] = "P" end
      if (p.sleep_ticks or 0) > 0 then marks[#marks+1] = "Z" end
      for k, m in ipairs(marks) do
        if k > 2 then break end
        screen.level(15)
        screen.move(cx + 30, 56 + k * 4); screen.text_right(m)
      end
    end
    screen.font_face(1); screen.font_size(8)
  end
  player.facing = saved_facing

  -- L2 toggle ON → BPM-edit mode
  if l2_held then
    screen.level(0); screen.rect(0, 0, 56, 9); screen.fill()
    screen.level(15)
    screen.move(2, 7)
    screen.text("BPM " .. BATTLE_BPM)
    screen.level(8)
    screen.move(54, 7); screen.text_right("L2:exit")
  end

  -- crit-flash pulse on the enemy (3 ticks of bright outline ring)
  if ANIM.crit_flash and (tick - ANIM.crit_flash) < 4 then
    screen.level(15)
    screen.circle(96, 24, 18 - (tick - ANIM.crit_flash) * 2)
    screen.stroke()
  end
  -- in-flight enemy projectile (small bright dot traveling from enemy to target)
  if ANIM.proj then
    local age = tick - ANIM.proj.t
    if age >= 0 and age <= 5 then
      local prog = (age + 1) / 6
      local px = math.floor(ANIM.proj.sx + (ANIM.proj.tx - ANIM.proj.sx) * prog)
      local py = math.floor(ANIM.proj.sy + (ANIM.proj.ty - ANIM.proj.sy) * prog)
      screen.level(15)
      screen.rect(px, py, 2, 2); screen.fill()
      screen.level(11)
      screen.pixel(px - 1, py); screen.pixel(px, py - 1)
      screen.pixel(px + 2, py + 1); screen.pixel(px + 1, py + 2); screen.fill()
    elseif age > 6 then
      ANIM.proj = nil
    end
  end

  -- floating damage numbers (rise + fade); prune expired entries
  for i = #ANIM.popups, 1, -1 do
    local d = ANIM.popups[i]
    local age = tick - d.t
    if age > 12 then
      table.remove(ANIM.popups, i)
    else
      screen.font_face(25); screen.font_size(6)
      local lev = math.max(2, d.lev - math.floor(age * 1.0))
      screen.level(lev)
      screen.move(d.x, d.y - age)
      screen.text_center(tostring(d.amt))
      screen.font_face(1); screen.font_size(8)
    end
  end

  -- level-up flash banner (compact, top-center)
  if levelup_flash_ticks > 0 then
    screen.level(0); screen.rect(40, 11, 48, 8); screen.fill()
    screen.level(15); screen.rect(40, 11, 48, 8); screen.stroke()
    screen.move(64, 17); screen.text_center(levelup_flash_who .. " UP!")
  end
  -- generic story-event banner (Sergei intervention etc.)
  if CONTENT.banner_ticks > 0 then
    screen.level(0); screen.rect(16, 18, 96, 14); screen.fill()
    screen.level(15); screen.rect(16, 18, 96, 14); screen.stroke()
    screen.move(64, 27); screen.text_center(CONTENT.banner_text)
  end
end

local function draw_battle_end()
  draw_battle()
  -- expand the panel a bit when there's a boss drop to announce
  local has_drop = (last_boss_drop and INSTRUMENTS[last_boss_drop])
  local panel_h = has_drop and 38 or 28
  screen.level(0)
  screen.rect(14, 18, 100, panel_h)
  screen.fill()
  screen.level(15)
  screen.rect(14, 18, 100, panel_h)
  screen.stroke()
  screen.move(64, 28)
  screen.text_center(battle_outcome)
  screen.level(8)
  screen.move(64, 36)
  if battle_outcome == "VICTORY" then
    if last_obtained_shard then
      screen.level(15)
      screen.move(64, 36)
      screen.text_center("+ " .. SHARD_DISPLAY[last_obtained_shard] .. " Shard")
    else
      screen.text_center("party heals 25%")
    end
    if has_drop then
      local inst = INSTRUMENTS[last_boss_drop]
      screen.level(11)
      screen.move(64, 45)
      screen.text_center("+ " .. inst.name)
      screen.level(6)
      screen.move(64, 51)
      screen.text_center("(" .. inst.class .. " — equip in menu)")
    end
    -- consumable drop badge (random battles only) — sits below the heal/shard line
    if SHOP.last_item_drop and SHOP.items[SHOP.last_item_drop] then
      screen.level(13)
      screen.move(64, 44)
      screen.text_center("+ 1 " .. SHOP.items[SHOP.last_item_drop].name)
    end
    -- gold drop badge (right corner)
    if SHOP.last_gold and SHOP.last_gold > 0 then
      screen.level(11)
      screen.move(110, 28)
      screen.text_right("+" .. SHOP.last_gold .. "g")
    end
  else
    screen.text_center("retreat to overworld")
  end
  if (tick % 6) < 4 then
    screen.level(12)
    screen.move(64, 18 + panel_h - 4)
    screen.text_center("press A to leave")
  end
end

local function draw_menu()
  draw_overworld()
  -- tighter panel (smaller, anchored center-ish)
  local px, py, pw, ph = 24, 6, 80, 54
  screen.level(0)
  screen.rect(px, py, pw, ph)
  screen.fill()
  screen.level(15)
  screen.rect(px, py, pw, ph)
  screen.stroke()
  -- title (default norns font is crisp at native size 8)
  screen.move(px + pw / 2, py + 7)
  screen.text_center("MENU")
  screen.level(6)
  screen.move(px + 4, py + 10)
  screen.line(px + pw - 4, py + 10)
  screen.stroke()
  -- options — Tom Thumb at NATIVE size 6 (crisp, no sub-native blur) +
  -- 5-px row pitch + start at y=18 so all 9 entries fit inside the 80x54 panel.
  screen.font_face(25)
  screen.font_size(6)
  for i, opt in ipairs(MENU_OPTIONS) do
    local y = py + 12 + (i - 1) * 5
    local label = opt
    if opt == "Debug" then label = opt .. ": " .. (debug_visible and "ON" or "OFF") end
    if i == menu_idx then
      screen.level(15)
      screen.move(px + 4, y)
      screen.text("> " .. label)
    else
      screen.level(7)
      screen.move(px + 8, y)
      screen.text(label)
    end
  end
  -- restore default font for everything else
  screen.font_face(1)
  screen.font_size(8)
  -- save flash (kept on default font)
  if save_flash_ticks > 0 then
    screen.level(0)
    screen.rect(20, 56, 88, 8)
    screen.fill()
    screen.level(15)
    screen.move(64, 62)
    screen.text_center(save_flash_text)
  end
end

-- ============================================================ PORTRAITS
-- Half-body 28x40 portraits drawn at (px, py) (top-left of portrait box).

local PORTRAITS
do
-- Helper: faint horizontal-stripe background to make portraits feel framed.
local function portrait_bg(px, py, lev)
  screen.level(lev or 2)
  screen.rect(px, py, 28, 40); screen.fill()
  screen.level((lev or 2) + 1)
  for y = py + 1, py + 39, 4 do
    screen.move(px, y); screen.line(px + 28, y); screen.stroke()
  end
end

local function draw_portrait_alder(px, py)
  -- Bard: floppy hat with feather, scruffy hair, friendly face, lute body
  portrait_bg(px, py, 2)
  -- Lute over right shoulder (peeking up behind)
  screen.level(7)
  screen.rect(px + 19, py + 22, 9, 18); screen.fill()
  screen.level(4)
  screen.move(px + 21, py + 22); screen.line(px + 21, py + 40); screen.stroke()
  screen.level(13)
  screen.rect(px + 24, py + 26, 1, 12); screen.fill()  -- lute strings
  -- Tunic shoulders (deep brown)
  screen.level(5)
  screen.rect(px + 3, py + 28, 17, 12); screen.fill()
  -- Collar V (lighter brown)
  screen.level(8)
  screen.move(px + 11, py + 28); screen.line(px + 7, py + 36); screen.stroke()
  screen.move(px + 12, py + 28); screen.line(px + 16, py + 36); screen.stroke()
  -- Lacing on tunic
  screen.level(11)
  screen.pixel(px + 9, py + 32); screen.pixel(px + 13, py + 32)
  screen.pixel(px + 9, py + 35); screen.pixel(px + 13, py + 35); screen.fill()
  -- Neck
  screen.level(11)
  screen.rect(px + 10, py + 24, 6, 4); screen.fill()
  -- Head (skin)
  screen.level(13)
  screen.rect(px + 7, py + 12, 12, 14); screen.fill()
  -- Hair (scruffy, peeking from hat sides)
  screen.level(4)
  screen.rect(px + 7, py + 13, 2, 5); screen.fill()
  screen.rect(px + 17, py + 13, 2, 4); screen.fill()
  screen.pixel(px + 8, py + 18); screen.pixel(px + 9, py + 19)
  screen.fill()
  -- Floppy bard cap (with brim shadow)
  screen.level(6)
  screen.rect(px + 4, py + 7, 18, 6); screen.fill()
  screen.level(11)
  screen.rect(px + 5, py + 7, 16, 4); screen.fill()
  screen.level(0)
  screen.move(px + 4, py + 13); screen.line(px + 22, py + 13); screen.stroke()
  -- Hatband
  screen.level(8)
  screen.move(px + 5, py + 11); screen.line(px + 21, py + 11); screen.stroke()
  -- Feather (curving back-right)
  screen.level(15)
  screen.move(px + 21, py + 10); screen.line(px + 26, py + 4); screen.stroke()
  screen.move(px + 22, py + 9); screen.line(px + 26, py + 6); screen.stroke()
  screen.level(11)
  screen.pixel(px + 26, py + 4); screen.fill()
  -- Eyes (slightly under brim shadow)
  screen.level(0)
  screen.rect(px + 10, py + 17, 2, 1); screen.fill()
  screen.rect(px + 14, py + 17, 2, 1); screen.fill()
  -- Eyebrows (short)
  screen.level(3)
  screen.move(px + 10, py + 15); screen.line(px + 12, py + 15); screen.stroke()
  screen.move(px + 14, py + 15); screen.line(px + 16, py + 15); screen.stroke()
  -- Nose
  screen.level(8)
  screen.pixel(px + 13, py + 19); screen.pixel(px + 13, py + 20); screen.fill()
  -- Mouth (warm smile)
  screen.level(0)
  screen.move(px + 11, py + 22); screen.line(px + 15, py + 22); screen.stroke()
  screen.pixel(px + 11, py + 23); screen.pixel(px + 15, py + 23); screen.fill()
  -- Ear hint
  screen.level(8)
  screen.pixel(px + 18, py + 19); screen.pixel(px + 18, py + 20); screen.fill()
end

local function draw_portrait_miel(px, py)
  -- Cleric princess — softer, beautiful look. Long flowing hair, gentle eyes,
  -- subtle blush, small smile, delicate tiara. Less harsh contrast than v1.
  portrait_bg(px, py, 2)
  -- Long flowing hair (filled backdrop with feather edges)
  screen.level(8)
  screen.rect(px + 4, py + 8, 20, 30); screen.fill()
  -- hair side wisps (lighter at extremes for flow)
  screen.level(5)
  screen.rect(px + 2, py + 14, 2, 22); screen.fill()
  screen.rect(px + 24, py + 14, 2, 22); screen.fill()
  -- hair part on top
  screen.level(11)
  screen.move(px + 14, py + 8); screen.line(px + 14, py + 12); screen.stroke()
  -- Robe shoulders (cream)
  screen.level(13)
  screen.rect(px + 2, py + 28, 24, 12); screen.fill()
  -- Gold collar trim
  screen.level(15)
  screen.move(px + 2, py + 30); screen.line(px + 26, py + 30); screen.stroke()
  -- Robe V neckline
  screen.level(8)
  screen.move(px + 14, py + 30); screen.line(px + 11, py + 36); screen.stroke()
  screen.move(px + 14, py + 30); screen.line(px + 17, py + 36); screen.stroke()
  -- Pendant (gold gem)
  screen.level(15)
  screen.rect(px + 13, py + 34, 2, 2); screen.fill()
  screen.level(11)
  screen.pixel(px + 14, py + 33); screen.fill()
  -- Neck (slim)
  screen.level(14)
  screen.rect(px + 12, py + 26, 4, 4); screen.fill()
  -- Face (heart-shaped: rectangular center + soft cheek pixels)
  screen.level(14)
  screen.rect(px + 9, py + 14, 10, 13); screen.fill()
  screen.level(13)
  -- jaw softening (chin)
  screen.pixel(px + 10, py + 26); screen.pixel(px + 17, py + 26); screen.fill()
  -- Bangs (hair across forehead — gentler line, 1 px tall)
  screen.level(8)
  screen.move(px + 9, py + 13); screen.line(px + 18, py + 13); screen.stroke()
  -- Tiara (delicate single band + small jewel)
  screen.level(15)
  screen.move(px + 10, py + 12); screen.line(px + 18, py + 12); screen.stroke()
  screen.level(11)
  screen.pixel(px + 14, py + 11); screen.pixel(px + 14, py + 10); screen.fill()
  -- center jewel (bright)
  screen.level(15)
  screen.pixel(px + 14, py + 12); screen.fill()
  -- Eyes — large, gentle, with eyelashes (2 px wide, lashes above)
  screen.level(2)
  screen.move(px + 10, py + 18); screen.line(px + 12, py + 18); screen.stroke()  -- left lash
  screen.move(px + 15, py + 18); screen.line(px + 17, py + 18); screen.stroke()  -- right lash
  screen.level(0)
  screen.rect(px + 10, py + 19, 3, 2); screen.fill()
  screen.rect(px + 15, py + 19, 3, 2); screen.fill()
  -- iris highlight (catchlight) — gives the gentle "alive" quality
  screen.level(15)
  screen.pixel(px + 11, py + 19); screen.pixel(px + 16, py + 19); screen.fill()
  -- Subtle blush (cheeks)
  screen.level(11)
  screen.pixel(px + 9, py + 22); screen.pixel(px + 18, py + 22); screen.fill()
  -- Nose (soft)
  screen.level(13)
  screen.pixel(px + 13, py + 22); screen.fill()
  -- Lips — small, slightly upturned smile
  screen.level(11)
  screen.move(px + 12, py + 24); screen.line(px + 15, py + 24); screen.stroke()
  screen.level(13)
  screen.pixel(px + 12, py + 23); screen.pixel(px + 15, py + 23); screen.fill()  -- corner highlights
end

local function draw_portrait_strom(px, py)
  -- Warrior knight: full helm with face plate and crest plume; broad pauldrons
  portrait_bg(px, py, 1)
  -- Pauldrons (large, rounded)
  screen.level(8)
  screen.rect(px + 0, py + 24, 28, 16); screen.fill()
  -- pauldron rivets
  screen.level(15)
  screen.pixel(px + 2, py + 26); screen.pixel(px + 25, py + 26)
  screen.pixel(px + 2, py + 30); screen.pixel(px + 25, py + 30)
  screen.pixel(px + 2, py + 34); screen.pixel(px + 25, py + 34); screen.fill()
  -- Pauldron top edge highlight
  screen.level(11)
  screen.move(px + 0, py + 24); screen.line(px + 27, py + 24); screen.stroke()
  -- Chest plate (raised center band)
  screen.level(11)
  screen.rect(px + 9, py + 28, 10, 12); screen.fill()
  screen.level(7)
  screen.move(px + 9, py + 28); screen.line(px + 9, py + 40); screen.stroke()
  screen.move(px + 18, py + 28); screen.line(px + 18, py + 40); screen.stroke()
  -- Engraved cross on chest
  screen.level(15)
  screen.move(px + 13, py + 31); screen.line(px + 13, py + 38); screen.stroke()
  screen.move(px + 14, py + 31); screen.line(px + 14, py + 38); screen.stroke()
  screen.move(px + 11, py + 33); screen.line(px + 16, py + 33); screen.stroke()
  screen.move(px + 11, py + 34); screen.line(px + 16, py + 34); screen.stroke()
  -- Helm body (full enclosure)
  screen.level(9)
  screen.rect(px + 5, py + 9, 18, 17); screen.fill()
  -- Helm darker shading on right
  screen.level(7)
  screen.rect(px + 18, py + 9, 5, 17); screen.fill()
  -- Helm seam (vertical)
  screen.level(13)
  screen.move(px + 14, py + 9); screen.line(px + 14, py + 26); screen.stroke()
  -- Visor slit
  screen.level(0)
  screen.rect(px + 7, py + 17, 14, 3); screen.fill()
  -- Glow inside visor (faint eyes)
  screen.level(15)
  screen.pixel(px + 11, py + 18); screen.pixel(px + 17, py + 18); screen.fill()
  -- Helm chin guard (rectangular)
  screen.level(7)
  screen.rect(px + 8, py + 22, 12, 3); screen.fill()
  -- Helm forehead trim
  screen.level(15)
  screen.move(px + 5, py + 11); screen.line(px + 22, py + 11); screen.stroke()
  -- Crest base
  screen.level(13)
  screen.rect(px + 11, py + 6, 6, 4); screen.fill()
  -- Crest plume (red-ish, layered)
  screen.level(11)
  for i = 0, 5 do
    screen.move(px + 11 + i, py + 6); screen.line(px + 11 + i, py + 1 + (i % 2)); screen.stroke()
  end
  screen.level(15)
  screen.move(px + 13, py + 1); screen.line(px + 13, py + 5); screen.stroke()
end

local function draw_portrait_diegues(px, py)
  -- Mage scholar — anime-style: tall pointy hat with star, brim shadowing eyes,
  -- circular wire glasses catching the light, calm/young face (no beard).
  portrait_bg(px, py, 1)
  -- Pointy hat (large dark triangle)
  screen.level(3)
  screen.move(px + 14, py)
  screen.line(px + 4, py + 16)
  screen.line(px + 24, py + 16)
  screen.close(); screen.fill()
  -- Hat band trim
  screen.level(11)
  screen.move(px + 4, py + 16); screen.line(px + 24, py + 16); screen.stroke()
  screen.move(px + 5, py + 17); screen.line(px + 23, py + 17); screen.stroke()
  -- Star on hat
  screen.level(15)
  screen.pixel(px + 14, py + 7); screen.pixel(px + 13, py + 8); screen.pixel(px + 14, py + 8); screen.pixel(px + 15, py + 8)
  screen.pixel(px + 12, py + 9); screen.pixel(px + 16, py + 9); screen.fill()
  -- Heavy brim shadow stripe over the forehead/eyes
  screen.level(0)
  screen.rect(px + 7, py + 17, 14, 4); screen.fill()
  -- Face (skin) — only the lower portion below the shadow
  screen.level(13)
  screen.rect(px + 9, py + 21, 10, 7); screen.fill()
  -- Hair tufts framing the face (peeking out from under the hat brim)
  screen.level(7)
  screen.rect(px + 8, py + 17, 1, 4); screen.fill()
  screen.rect(px + 19, py + 17, 1, 4); screen.fill()
  -- Anime round glasses: two circles with bright lens-glints; bridge in between
  -- glass rim (lower row + sides — using level 11 for visible-in-shadow effect)
  screen.level(11)
  -- left lens
  screen.move(px + 10, py + 19); screen.line(px + 12, py + 19); screen.stroke()  -- top
  screen.move(px + 10, py + 21); screen.line(px + 12, py + 21); screen.stroke()  -- bottom
  screen.pixel(px + 9, py + 20)
  screen.pixel(px + 13, py + 20); screen.fill()
  -- right lens
  screen.move(px + 15, py + 19); screen.line(px + 17, py + 19); screen.stroke()
  screen.move(px + 15, py + 21); screen.line(px + 17, py + 21); screen.stroke()
  screen.pixel(px + 14, py + 20)
  screen.pixel(px + 18, py + 20); screen.fill()
  -- bridge between lenses
  screen.move(px + 13, py + 20); screen.line(px + 14, py + 20); screen.stroke()
  -- Bright lens glints (the famous anime "no eyes visible / just glasses" look)
  screen.level(15)
  screen.move(px + 10, py + 20); screen.line(px + 12, py + 20); screen.stroke()
  screen.move(px + 15, py + 20); screen.line(px + 17, py + 20); screen.stroke()
  -- Faint eye shapes BEHIND the lens (very dim — barely there)
  screen.level(2)
  screen.pixel(px + 11, py + 20); screen.pixel(px + 16, py + 20); screen.fill()
  -- Nose (small)
  screen.level(11)
  screen.pixel(px + 13, py + 23); screen.pixel(px + 14, py + 23); screen.fill()
  -- Calm small mouth
  screen.level(0)
  screen.move(px + 12, py + 25); screen.line(px + 15, py + 25); screen.stroke()
  -- Robe shoulders (deep indigo)
  screen.level(4)
  screen.rect(px + 0, py + 28, 28, 12); screen.fill()
  -- Gold trim collar
  screen.level(13)
  screen.move(px + 0, py + 28); screen.line(px + 28, py + 28); screen.stroke()
  -- Robe fold lines
  screen.level(2)
  screen.move(px + 5, py + 30); screen.line(px + 5, py + 40); screen.stroke()
  screen.move(px + 22, py + 30); screen.line(px + 22, py + 40); screen.stroke()
  -- Staff (vertical, on right edge)
  screen.level(8)
  screen.rect(px + 26, py + 4, 1, 36); screen.fill()
  -- Staff orb at top (glowing)
  screen.level(15)
  screen.rect(px + 25, py + 3, 3, 3); screen.fill()
  screen.level(11)
  screen.pixel(px + 26, py + 4); screen.fill()
end

PORTRAITS = {
  bard    = draw_portrait_alder,
  cleric  = draw_portrait_miel,
  warrior = draw_portrait_strom,
  mage    = draw_portrait_diegues,
}
end  -- portraits

-- ============================================================ STATUS SCREEN

local function draw_status_bar(x, y, w, cur, max, lvl)
  screen.level(2)
  screen.rect(x, y, w, 3)
  screen.fill()
  if max > 0 then
    local f = math.max(0, math.min(1, cur / max))
    screen.level(lvl or 13)
    screen.rect(x, y, math.floor(w * f + 0.5), 3)
    screen.fill()
  end
  screen.level(4)
  screen.rect(x, y, w, 3)
  screen.stroke()
end

local function draw_status()
  if status_idx > #party then status_idx = 1 end
  local p = party[status_idx]
  local name = CHAR_NAME[p.class]
  local cls = ({bard="Bard",cleric="Cleric",warrior="Warrior",mage="Mage"})[p.class] or p.class

  -- header bar
  screen.level(15)
  screen.move(64, 7)
  screen.text_center(name .. " — " .. cls)
  screen.level(3)
  screen.move(0, 9)
  screen.line(128, 9)
  screen.stroke()

  -- "portrait" — actual in-game sprite blown up 3x and framed at the left.
  -- Replaces the old detailed portraits.
  local fx, fy, fw, fh = 2, 12, 28, 40
  -- frame backdrop
  screen.level(2); screen.rect(fx, fy, fw, fh); screen.fill()
  screen.level(11); screen.rect(fx, fy, fw, fh); screen.stroke()
  -- 3x sprite (24x24) centered horizontally, with a 1-px idle bob
  local bob = ((tick // 6) % 2)
  local sx = fx + math.floor((fw - 24) / 2)
  local sy = fy + 4 - bob
  SPRITE_BY_CLASS.scaled(p.class, sx, sy, 3)
  -- name plate at the bottom of the frame
  screen.font_face(25); screen.font_size(6)
  screen.level(15)
  screen.move(fx + fw / 2, fy + fh - 2)
  screen.text_center(name)
  screen.font_face(1); screen.font_size(8)
  -- KO overlay
  if not p.alive then
    screen.level(0); screen.rect(fx, fy, fw, fh); screen.fill()
    screen.level(8)
    screen.move(fx + fw / 2, fy + fh / 2 + 4); screen.text_center("KO")
  end

  -- stats (right column)
  local rx = 36
  local ry = 14
  local row_h = 6
  local lvl = p.level or 1
  local xp = p.xp or 0
  local xp_next = (lvl >= LEVEL_CAP) and 0 or xp_for_level(lvl)

  -- LV (left) + lifetime XP total (right of name row)
  screen.level(13)
  screen.move(rx, ry)
  screen.text("LV " .. lvl)
  screen.level(6)
  screen.move(126, ry)
  screen.text_right("total " .. (p.xp_total or 0))

  -- XP-to-next bar
  ry = ry + row_h - 1
  if lvl >= LEVEL_CAP then
    screen.level(15)
    screen.move(rx, ry)
    screen.text("MAX LV")
  else
    screen.level(7)
    screen.move(rx, ry)
    screen.text("XP " .. xp .. "/" .. xp_next)
    draw_status_bar(rx, ry + 1, 60, xp, xp_next, 9)
  end

  -- HP bar
  ry = ry + row_h
  screen.level(10)
  screen.move(rx, ry)
  screen.text("HP " .. p.hp .. "/" .. p.hp_max)
  draw_status_bar(rx, ry + 1, 60, p.hp, p.hp_max, 13)

  -- MP bar
  ry = ry + row_h + 1
  screen.level(10)
  screen.move(rx, ry)
  screen.text("MP " .. p.mp .. "/" .. p.mp_max)
  draw_status_bar(rx, ry + 1, 60, p.mp, p.mp_max, 11)

  -- core stats grid (ATK / DEF / MAG / SPD)
  ry = ry + row_h + 1
  screen.level(11)
  local function stat_str(label, base, bonus)
    if bonus and bonus ~= 0 then
      return label .. " " .. base .. (bonus > 0 and "+" or "") .. bonus
    end
    return label .. " " .. base
  end
  local inst = INSTRUMENTS[equipped[p.class]]
  screen.move(rx, ry)
  screen.text(stat_str("ATK", p.atk or 0, inst and inst.atk))
  screen.move(rx + 32, ry)
  screen.text(stat_str("DEF", p.def or 0, inst and inst.def))
  ry = ry + row_h
  screen.move(rx, ry)
  screen.text(stat_str("MAG", p.mag or 0, inst and inst.mag))
  screen.move(rx + 32, ry)
  screen.text(stat_str("SPD", p.spd or 0, inst and inst.spd))

  -- equipped instrument (replaces class blurb — instrument is more actionable info)
  ry = ry + row_h
  screen.level(11)
  screen.move(rx, ry)
  screen.text((inst and inst.name) or "(no instrument)")

  -- footer: page dots + nav hint + shards
  for i = 1, #party do
    local x = 64 + (i - (#party + 1) / 2) * 6
    screen.level(i == status_idx and 15 or 3)
    screen.rect(x - 1, 56, 3, 3)
    screen.fill()
  end
  screen.level(6)
  screen.move(2, 62)
  screen.text("L1/R1: switch")
  screen.level(7)
  screen.move(126, 62)
  screen.text_right(count_shards() .. "/" .. SHARD_TOTAL .. " shards")
end

-- ============================================================ CUTSCENE SCENES

local SCENE_DRAW
do
local function draw_scene_cosmic()
  -- two-layer drifting starfield with a distant ringed planet + brighter stars
  screen.level(2)
  for i = 1, 18 do
    local sx = (i * 13 + tick) % 128
    local sy = (i * 7 + i * 3) % 64
    screen.pixel(sx, sy)
  end
  screen.fill()
  -- closer star layer (brighter, slightly faster)
  screen.level(7)
  for i = 1, 9 do
    local sx = (i * 23 + tick * 2) % 128
    local sy = (i * 11 + 4) % 60
    screen.pixel(sx, sy)
  end
  screen.fill()
  -- a bright pulsar that twinkles
  if (tick % 14) < 7 then
    screen.level(15); screen.pixel(40, 18); screen.pixel(40, 17); screen.pixel(40, 19)
    screen.pixel(39, 18); screen.pixel(41, 18); screen.fill()
  else
    screen.level(13); screen.pixel(40, 18); screen.fill()
  end
  -- ringed planet (distant)
  screen.level(1); screen.circle(100, 14, 8); screen.fill()
  screen.level(3); screen.circle(100, 14, 6); screen.fill()
  screen.level(7); screen.circle(98, 12, 2); screen.fill()                         -- highlight
  -- ring (ellipse approximation)
  screen.level(5)
  screen.move(89, 14); screen.line(94, 13); screen.line(106, 13); screen.line(111, 14); screen.stroke()
  screen.move(89, 14); screen.line(94, 15); screen.line(106, 15); screen.line(111, 14); screen.stroke()
end

local function draw_scene_dark()
  -- sparse dim stars + jagged mountain silhouette + Suno's tower silhouette +
  -- glowing window + occasional distant lightning flash on the horizon
  screen.level(1)
  for i = 1, 7 do
    screen.pixel((i * 19 + tick) % 128, (i * 11) % 28)
  end
  screen.fill()
  -- distant lightning: brief sky flash across all upper rows
  if (tick % 240) < 3 then
    screen.level(8); screen.rect(0, 0, 128, 32); screen.fill()
  end
  -- mountain silhouette
  screen.level(3)
  screen.move(0, 64)
  screen.line(20, 46); screen.line(35, 52); screen.line(52, 38)
  screen.line(72, 50); screen.line(92, 34); screen.line(112, 50)
  screen.line(128, 42); screen.line(128, 64)
  screen.close(); screen.fill()
  -- Suno's tower (thin tall structure on the highest peak at ~92,34)
  screen.level(2)
  screen.rect(89, 18, 6, 18); screen.fill()
  -- battlements at the top
  screen.level(2)
  screen.rect(88, 16, 1, 2); screen.fill()
  screen.rect(91, 14, 2, 4); screen.fill()
  screen.rect(94, 16, 1, 2); screen.fill()
  -- glowing window with steady-pulse
  local on = (tick % 12) < 8
  screen.level(on and 15 or 7)
  screen.pixel(92, 26); screen.pixel(91, 27); screen.fill()
  if on then
    screen.level(8); screen.pixel(90, 26); screen.pixel(93, 27); screen.fill()
  end
  -- a single drifting "silencer" — a small dark figure crossing the foreground
  local fx = (tick // 3) % 160 - 16
  if fx > 0 and fx < 128 then
    screen.level(0); screen.rect(fx, 60, 2, 4); screen.fill()
  end
end

local function draw_scene_village()
  -- night sky with moon, faint stars, chimney smoke wisps, lantern lights
  -- background dim
  screen.level(1); screen.rect(0, 0, 128, 40); screen.fill()
  -- a few far stars
  screen.level(7)
  screen.pixel(70, 8); screen.pixel(85, 14); screen.pixel(38, 6); screen.pixel(50, 18); screen.fill()
  -- crescent moon
  screen.level(11); screen.circle(20, 14, 5); screen.fill()
  screen.level(0); screen.circle(22, 13, 5); screen.fill()
  -- 3 house silhouettes along the bottom
  screen.level(4)
  screen.move(0, 50); screen.line(15, 40); screen.line(30, 50); screen.close(); screen.fill()
  screen.rect(0, 50, 30, 14); screen.fill()
  screen.move(40, 52); screen.line(55, 44); screen.line(70, 52); screen.close(); screen.fill()
  screen.rect(40, 52, 30, 12); screen.fill()
  screen.move(80, 50); screen.line(95, 42); screen.line(110, 50); screen.close(); screen.fill()
  screen.rect(80, 50, 30, 14); screen.fill()
  -- chimney bricks
  screen.level(2)
  screen.rect(20, 38, 2, 4); screen.fill()
  screen.rect(63, 42, 2, 4); screen.fill()
  -- chimney smoke (rising puffs, animated)
  local s = tick // 4
  for i = 0, 2 do
    screen.level(7 - i * 2)
    screen.pixel(21 + (s + i) % 3, 36 - i); screen.fill()
    screen.pixel(64 + (s + i + 1) % 3, 40 - i); screen.fill()
  end
  -- window lights flicker (lantern feel)
  if (tick % 16) < 12 then
    screen.level(13)
    screen.pixel(12, 56); screen.pixel(50, 58); screen.pixel(95, 56); screen.fill()
  else
    screen.level(8)
    screen.pixel(12, 56); screen.pixel(95, 56); screen.fill()
  end
  -- a tiny figure walking the lane (slow rightward drift)
  local fx = (tick // 6) % 160 - 16
  if fx > 0 and fx < 116 then
    local bob = ((tick // 3) % 2)
    screen.level(0); screen.rect(fx, 62 - bob, 2, 2); screen.fill()
    screen.level(11); screen.pixel(fx, 60 - bob); screen.fill()
  end
end

local function draw_scene_threat()
  -- pulsing alarm in the upper sky + jagged silencer silhouettes + glowing
  -- eyes between the figures + ominous eclipsed moon
  local pulse = math.abs(math.sin(tick * 0.18))
  screen.level(math.floor(pulse * 4))
  screen.rect(0, 0, 128, 24); screen.fill()
  -- horizon haze
  screen.level(2)
  screen.rect(0, 24, 128, 4); screen.fill()
  -- jagged dark figures along the bottom (silencers)
  screen.level(8)
  for i = 1, 6 do
    local x = 12 + i * 18
    local h = 18 + (i * 7) % 14
    screen.move(x, 64)
    screen.line(x - 4, 64 - h)
    screen.line(x + 4, 64 - h)
    screen.close(); screen.fill()
    -- glowing eyes (synced pulse, every other figure offset)
    if (tick + i) % 6 < 3 then
      screen.level(15); screen.pixel(x - 1, 64 - h + 3); screen.pixel(x + 1, 64 - h + 3); screen.fill()
      screen.level(8)
    end
  end
  -- ominous eclipsed moon
  screen.level(7); screen.circle(64, 14, 8); screen.fill()
  screen.level(0); screen.circle(67, 13, 7); screen.fill()
  -- corona ring around the eclipse (occasional)
  if (tick % 24) < 12 then
    screen.level(11); screen.circle(64, 14, 9); screen.stroke()
  end
  -- a thin column of distant smoke rising from a torched village
  local smoke_seed = (tick // 4) % 4
  screen.level(2)
  screen.move(102, 64); screen.line(102, 50 + smoke_seed); screen.stroke()
  screen.level(4); screen.pixel(102 + (smoke_seed % 2), 48); screen.fill()
end

SCENE_DRAW = {
  cosmic  = draw_scene_cosmic,
  dark    = draw_scene_dark,
  village = draw_scene_village,
  threat  = draw_scene_threat,
}
end  -- scene draws

local function draw_cutscene()
  local panel = CUTSCENE_LINES[cutscene_idx]
  if type(panel) ~= "table" then panel = {text = tostring(panel or ""), scene = "cosmic"} end

  -- background scene
  local fn = SCENE_DRAW[panel.scene] or SCENE_DRAW.cosmic
  fn()

  -- Panel-change transition: fade text and overlay a brief flash for the
  -- first ~12 ticks after a panel change. cutscene_panel_start is set on
  -- new-game-start AND on every advance.
  local t_in = tick - (CONTENT.cutscene_panel_start or 0)
  local flash_phase = math.max(0, math.min(1, t_in / 4))
  local fade_phase  = math.max(0, math.min(1, (t_in - 2) / 10))

  -- White flash on panel change (4-tick falloff)
  if flash_phase < 1 then
    screen.level(math.floor(15 * (1 - flash_phase)))
    screen.rect(0, 0, 128, 64); screen.fill()
  end

  -- text panel: subtle dark band behind text for readability
  local lines = wrap_text(panel.text, 116)
  local panel_h = 6 + (#lines * 8)
  local panel_y = 28 - math.floor(#lines * 4)
  screen.level(0)
  screen.rect(2, panel_y - 4, 124, panel_h + 2)
  screen.fill()
  screen.level(math.floor(2 + 4 * fade_phase))
  screen.rect(2, panel_y - 4, 124, panel_h + 2)
  screen.stroke()
  for i, line in ipairs(lines) do
    screen.level(math.floor(2 + 11 * fade_phase))
    screen.move(64, panel_y + i * 8)
    screen.text_center(line)
  end

  -- progress dots — current dot pulses gently
  for i = 1, #CUTSCENE_LINES do
    local x = 64 + (i - (#CUTSCENE_LINES + 1) / 2) * 5
    if i == cutscene_idx then
      local pulse = ((tick % 12) < 6) and 15 or 11
      screen.level(pulse)
    else
      screen.level(i < cutscene_idx and 7 or 3)
    end
    screen.rect(x - 1, 58, 2, 2)
    screen.fill()
  end

  -- Advance prompt only appears after the fade-in completes
  if fade_phase >= 1 and (tick % 8) < 5 then
    screen.level(10)
    screen.move(124, 62)
    screen.text_right("A >")
  end
end

local function draw_ending()
  -- mirrors draw_cutscene structure but reads from ENDING_LINES
  local panel = ENDING_LINES[ending_idx]
  if type(panel) ~= "table" then panel = {text = tostring(panel or ""), scene = "cosmic"} end
  local fn = SCENE_DRAW[panel.scene] or SCENE_DRAW.cosmic
  fn()
  local lines = wrap_text(panel.text, 116)
  local panel_h = 6 + (#lines * 8)
  local panel_y = 28 - math.floor(#lines * 4)
  screen.level(0)
  screen.rect(2, panel_y - 4, 124, panel_h + 2)
  screen.fill()
  screen.level(2)
  screen.rect(2, panel_y - 4, 124, panel_h + 2)
  screen.stroke()
  for i, line in ipairs(lines) do
    screen.level(15)
    screen.move(64, panel_y + i * 8)
    screen.text_center(line)
  end
  for i = 1, #ENDING_LINES do
    local x = 64 + (i - (#ENDING_LINES + 1) / 2) * 5
    screen.level(i == ending_idx and 15 or 3)
    screen.rect(x - 1, 58, 2, 2)
    screen.fill()
  end
  if (tick % 8) < 5 then
    screen.level(10)
    screen.move(124, 62)
    screen.text_right("A >")
  end
end

local function draw_voyage()
  -- ocean horizon + scrolling waves; boat sails across center
  -- background: dark sea, faint horizon line
  screen.level(1)
  screen.rect(0, 0, 128, 28)
  screen.fill()
  screen.level(3)
  screen.rect(0, 28, 128, 36)
  screen.fill()
  -- horizon line
  screen.level(5)
  screen.move(0, 28)
  screen.line(128, 28)
  screen.stroke()
  -- distant clouds (drifting slowly)
  local cloud_off = (tick // 4) % 128
  for i = 0, 2 do
    local cx = (i * 50 + cloud_off) % 140 - 12
    screen.level(6)
    screen.rect(cx, 8 + i * 3, 14, 2)
    screen.fill()
  end
  -- wave lines (scroll right→left)
  for row = 0, 6 do
    local wy = 30 + row * 4
    local off = (tick * (row + 1) // 2) % 16
    screen.level(row % 2 == 0 and 7 or 5)
    for x = -off, 128, 16 do
      screen.move(x, wy)
      screen.line(x + 6, wy)
      screen.stroke()
      screen.move(x + 8, wy + 1)
      screen.line(x + 12, wy + 1)
      screen.stroke()
    end
  end
  -- boat: sails left→right or right→left across screen based on which dir
  local progress = 1 - (voyage_ticks / VOYAGE_DURATION)
  local bx
  if voyage_target_map == 2 then
    bx = math.floor(8 + progress * 110)
  else
    bx = math.floor(118 - progress * 110)
  end
  local by = 30 + ((tick // 4) % 2)  -- gentle bob
  -- hull
  screen.level(13)
  screen.move(bx, by + 4)
  screen.line(bx + 14, by + 4)
  screen.line(bx + 12, by + 7)
  screen.line(bx + 2, by + 7)
  screen.close()
  screen.fill()
  -- mast
  screen.level(11)
  screen.rect(bx + 7, by - 4, 1, 8)
  screen.fill()
  -- sail (triangle)
  screen.level(15)
  screen.move(bx + 7, by - 4)
  screen.line(bx + 13, by + 3)
  screen.line(bx + 7, by + 3)
  screen.close()
  screen.fill()
  -- pennant
  screen.level(8)
  screen.pixel(bx + 8, by - 4)
  screen.pixel(bx + 9, by - 4)
  -- text banner
  local dest = voyage_target_map == 2 and "EASTERN REACHES" or "MAINLAND"
  screen.level(0)
  screen.rect(0, 54, 128, 10)
  screen.fill()
  screen.level(2)
  screen.move(0, 54)
  screen.line(128, 54)
  screen.stroke()
  screen.level(13)
  screen.move(64, 62)
  screen.text_center("Sailing to " .. dest)
end

local function draw_title()
  -- Scenic backdrop: layered parallax sky + village + Crystal Synth animation
  -- Sky band (top half, dark)
  screen.level(1)
  screen.rect(0, 0, 128, 36); screen.fill()
  -- Far star layer (slow drift)
  for i = 1, 22 do
    local sx = ((i * 19) + (tick // 4)) % 128
    local sy = (i * 5) % 30
    screen.level((i % 7 == 0) and 13 or 6)
    screen.pixel(sx, sy); screen.fill()
  end
  -- Near star layer (faster drift, dimmer — depth cue)
  for i = 1, 14 do
    local sx = ((i * 31) + (tick // 2)) % 128
    local sy = (i * 7 + 2) % 28
    screen.level((i % 5 == 0) and 11 or 4)
    screen.pixel(sx, sy); screen.fill()
  end
  -- Occasional shooting star — fires once per long cycle, traces a 6-px diagonal
  local cycle = tick % 280
  if cycle < 12 then
    local t = cycle
    local sx = 8 + t * 6
    local sy = 4 + t
    screen.level(15); screen.pixel(sx, sy); screen.fill()
    screen.level(11); screen.pixel(sx - 1, sy); screen.pixel(sx, sy - 1)
    screen.pixel(sx - 2, sy); screen.pixel(sx, sy - 2); screen.fill()
  end
  -- Distant moon (top right) with phase crater
  screen.level(11); screen.circle(110, 10, 5); screen.fill()
  screen.level(2); screen.circle(108, 8, 3); screen.fill()
  screen.level(8); screen.pixel(112, 11); screen.pixel(110, 13); screen.fill()
  -- Drifting cloud silhouette (very slow)
  local cdx = (tick // 8) % 160 - 32
  screen.level(2)
  screen.rect(cdx, 14, 18, 2); screen.fill()
  screen.rect(cdx + 4, 12, 10, 2); screen.fill()
  -- Distant mountain silhouette (back)
  screen.level(2)
  screen.move(0, 36)
  screen.line(20, 24); screen.line(36, 32); screen.line(56, 18)
  screen.line(72, 30); screen.line(92, 22); screen.line(112, 34); screen.line(128, 28)
  screen.line(128, 36); screen.line(0, 36); screen.close(); screen.fill()
  -- Mid-mountain ridge (slightly lighter, smaller silhouette)
  screen.level(3)
  screen.move(0, 40)
  screen.line(14, 34); screen.line(30, 38); screen.line(48, 32); screen.line(68, 38)
  screen.line(86, 34); screen.line(108, 38); screen.line(128, 36); screen.line(128, 40); screen.close(); screen.fill()
  -- Foreground hill (lighter)
  screen.level(4)
  screen.move(0, 52); screen.line(28, 44); screen.line(60, 50)
  screen.line(96, 42); screen.line(128, 50); screen.line(128, 64); screen.line(0, 64); screen.close(); screen.fill()
  -- Distant village lights on the foreground hill (window flickers)
  for i = 0, 4 do
    local vx = 20 + i * 22
    local vy = 47 + (i % 2)
    local on = ((tick // 6) + i * 3) % 5 < 4
    screen.level(on and 15 or 9)
    screen.pixel(vx, vy); screen.fill()
  end
  -- Tiny party silhouettes standing on the hill (4 dots — Diegues, Miel, Strom, Alder)
  local hill_y = 51
  screen.level(0)
  screen.rect(46, hill_y, 1, 3); screen.fill()
  screen.rect(50, hill_y - 1, 1, 4); screen.fill()
  screen.rect(54, hill_y, 1, 3); screen.fill()
  screen.rect(58, hill_y - 1, 1, 4); screen.fill()
  screen.level(11); screen.pixel(46, hill_y - 1); screen.pixel(50, hill_y - 2)
  screen.pixel(54, hill_y - 1); screen.pixel(58, hill_y - 2); screen.fill()

  -- ── CRYSTAL SYNTH (centered, animated) ──
  -- Floating crystal: large diamond outline made of 7 facet shards (one per mode)
  local cx, cy = 64, 22
  -- pulsing aura ring
  local pulse = (tick // 3) % 8
  screen.level(13 - pulse)
  screen.circle(cx, cy, 14 + (pulse % 3)); screen.stroke()
  -- inner crystal — large diamond
  screen.level(15)
  screen.move(cx, cy - 12)
  screen.line(cx + 10, cy)
  screen.line(cx, cy + 12)
  screen.line(cx - 10, cy)
  screen.close()
  screen.fill()
  -- inner facet lines (creating 7 wedges)
  screen.level(2)
  screen.move(cx, cy - 12); screen.line(cx, cy + 12); screen.stroke()
  screen.move(cx - 10, cy); screen.line(cx + 10, cy); screen.stroke()
  screen.move(cx - 5, cy - 6); screen.line(cx + 5, cy + 6); screen.stroke()
  screen.move(cx + 5, cy - 6); screen.line(cx - 5, cy + 6); screen.stroke()
  -- bright core
  screen.level(15)
  screen.rect(cx - 1, cy - 1, 3, 3); screen.fill()
  -- floating particles around crystal
  for i = 0, 5 do
    local ang = (tick * 3 + i * 60) % 360
    local rad = ang * 0.01745
    local px = math.floor(cx + math.cos(rad) * 18 + 0.5)
    local py = math.floor(cy + math.sin(rad) * 9 + 0.5)
    screen.level((i % 3 == 0) and 15 or 11)
    screen.pixel(px, py); screen.fill()
  end

  -- ── TITLE TEXT ──
  screen.level(0); screen.move(65, 45); screen.text_center("SYNTH QUEST")
  screen.level(15); screen.move(64, 44); screen.text_center("SYNTH QUEST")

  screen.font_face(25); screen.font_size(6)
  screen.level(8); screen.move(64, 50); screen.text_center("the chord must sing")
  -- New Game / Continue selector
  for i = 0, 1 do
    local label = (i == 0) and "New Game" or "Continue"
    local sel = (TITLE.idx == i)
    local x = 36 + i * 56
    screen.level(sel and 15 or 7)
    screen.move(x, 58)
    screen.text_center((sel and "> " or "  ") .. label)
    if sel then
      screen.level(15)
      screen.move(x, 60)
      screen.line(x + 22, 60); screen.stroke()
    end
  end
  -- Flash (e.g. "no save found")
  if TITLE.flash_ticks > 0 then
    TITLE.flash_ticks = TITLE.flash_ticks - 1
    screen.level(0); screen.rect(28, 53, 72, 9); screen.fill()
    screen.level(15); screen.move(64, 60); screen.text_center(TITLE.flash_text)
  end
  screen.font_face(1); screen.font_size(8)
end

local function draw_equip()
  if equip_idx > #party then equip_idx = 1 end
  local p = party[equip_idx]
  local list = INST.owned_for(p.class)
  if #list > 0 then
    if equip_choice > #list then equip_choice = #list end
    if equip_choice < 1 then equip_choice = 1 end
  end
  local cur_id = equipped[p.class]
  local cur = INSTRUMENTS[cur_id]
  -- header
  screen.level(15)
  screen.move(64, 7)
  screen.text_center("EQUIP — " .. CHAR_NAME[p.class])
  screen.level(3)
  screen.move(0, 9)
  screen.line(128, 9)
  screen.stroke()
  -- "portrait" — use the in-game sprite (3x scale + frame) to match the status screen
  local fx, fy, fw, fh = 2, 12, 28, 40
  screen.level(2); screen.rect(fx, fy, fw, fh); screen.fill()
  screen.level(11); screen.rect(fx, fy, fw, fh); screen.stroke()
  local bob = ((tick // 6) % 2)
  local sx = fx + math.floor((fw - 24) / 2)
  local sy = fy + 4 - bob
  SPRITE_BY_CLASS.scaled(p.class, sx, sy, 3)
  -- right column
  local rx = 36
  screen.level(11)
  screen.move(rx, 14)
  screen.text("Equipped:")
  -- Equipped instrument sprite (8x8) just below the label
  if cur_id and INST.sprites[cur_id] then
    INST.sprites[cur_id](rx, 16)
  end
  screen.level(15)
  screen.move(rx + 12, 22)
  screen.text(cur and cur.name or "—")
  -- list of owned
  screen.level(6)
  screen.move(rx, 30)
  screen.text("OWNED")
  for i = 1, math.min(#list, 4) do
    local id = list[i]
    local inst = INSTRUMENTS[id]
    local y = 36 + (i - 1) * 6
    local sel = (i == equip_choice)
    local eq  = (id == cur_id)
    -- per-row item sprite (8x8) at the left
    if INST.sprites[id] then INST.sprites[id](rx, y - 5) end
    screen.level(sel and 15 or (eq and 11 or 5))
    screen.move(rx + 10, y)
    screen.text((sel and ">" or " ") .. (eq and "*" or " ") .. inst.name)
  end
  if #list == 0 then
    screen.level(5)
    screen.move(rx, 38)
    screen.text("(none)")
  end
  -- selected-instrument preview deltas vs equipped
  local sel_id = list[equip_choice]
  local sel_inst = sel_id and INSTRUMENTS[sel_id]
  if sel_inst and cur then
    local d_atk = sel_inst.atk - cur.atk
    local d_def = sel_inst.def - cur.def
    local d_mag = sel_inst.mag - cur.mag
    local d_spd = sel_inst.spd - cur.spd
    local function fmt(label, v)
      if v == 0 then return label .. ":·" end
      local s = (v > 0) and ("+" .. v) or tostring(v)
      return label .. ":" .. s
    end
    screen.level(9)
    screen.move(2, 56)
    screen.text(fmt("ATK", d_atk) .. " " .. fmt("DEF", d_def) .. " " .. fmt("MAG", d_mag) .. " " .. fmt("SPD", d_spd))
  end
  -- footer
  for i = 1, #party do
    local x = 64 + (i - (#party + 1) / 2) * 6
    screen.level(i == equip_idx and 15 or 3)
    screen.rect(x - 1, 49, 3, 3)
    screen.fill()
  end
  screen.level(6)
  screen.move(2, 62)
  screen.text("L1/R1 char  A equip  B back")
  -- equip-toast (reuses CONTENT.flash_*) — shows "Equipped: <name>" briefly
  if CONTENT.flash_ticks > 0 then
    screen.level(0); screen.rect(20, 26, 88, 12); screen.fill()
    screen.level(15); screen.rect(20, 26, 88, 12); screen.stroke()
    screen.move(64, 34); screen.text_center(CONTENT.flash_text)
  end
end

local function draw_shop()
  -- header bar
  screen.level(15)
  screen.move(64, 7)
  screen.text_center("HENS' SHOP")
  screen.level(3)
  screen.move(0, 9)
  screen.line(128, 9)
  screen.stroke()
  -- gold balance (right)
  screen.level(11)
  screen.move(126, 7)
  screen.text_right(SHOP.gold .. "g")
  -- items: one row per item, 7px spacing — name | price | own | desc
  screen.font_face(25)
  screen.font_size(6)
  for i, id in ipairs(SHOP.order) do
    local it = SHOP.items[id]
    local y = 16 + (i - 1) * 7
    local sel = (i == SHOP.idx)
    local price = QUESTS.hens.discount and math.floor(it.cost * 0.75) or it.cost
    -- selection caret
    screen.level(sel and 15 or 0)
    screen.move(2, y); screen.text(sel and ">" or " ")
    -- name (highlighted when selected)
    screen.level(sel and 15 or 8)
    screen.move(8, y); screen.text(it.name)
    -- price (right-aligned in column)
    screen.level(sel and 13 or 6)
    screen.move(46, y); screen.text(price .. "g")
    -- owned count
    screen.level(sel and 11 or 5)
    screen.move(64, y); screen.text("x" .. SHOP.inv[id])
    -- description (rest of line)
    screen.level(sel and 11 or 4)
    screen.move(78, y); screen.text(it.desc)
  end
  screen.font_face(1)
  screen.font_size(8)
  -- flash banner (purchase / not enough gold) — sits just above the help line
  if SHOP.flash_ticks > 0 then
    screen.level(0)
    screen.rect(28, 54, 72, 8)
    screen.fill()
    screen.font_face(25); screen.font_size(6)
    screen.level(15)
    screen.move(64, 60)
    screen.text_center(SHOP.flash_text)
    screen.font_face(1); screen.font_size(8)
  else
    screen.font_face(25); screen.font_size(6)
    screen.level(6)
    screen.move(2, 62); screen.text("up/dn pick  A buy  B leave")
    screen.font_face(1); screen.font_size(8)
  end
end

-- ── JAM MODE ──────────────────────────────────────────────────────────────
-- Single-screen synth-jam dashboard. Shows all 4 voices' effect parameters
-- (cutoff / resonance / wet / delay) as bars; sticks edit the active voice;
-- L1/R1 cycle voice; SELECT or B exits back to the prior state.
-- pretty 14×14 stick visualizer with crosshair, range ring, and a glowing dot
ANIM.draw_stick_big = function(box_x, box_y, nx, ny, label)
  -- subtle range ring (octagon outline)
  screen.level(2)
  screen.rect(box_x, box_y, 14, 14); screen.stroke()
  -- crosshair lines
  screen.level(4)
  screen.move(box_x, box_y + 7); screen.line(box_x + 14, box_y + 7); screen.stroke()
  screen.move(box_x + 7, box_y); screen.line(box_x + 7, box_y + 14); screen.stroke()
  -- center dot (rest position)
  screen.level(3)
  screen.pixel(box_x + 7, box_y + 7); screen.fill()
  -- stick dot with halo
  local dx = math.floor(box_x + 7 + (nx or 0) * 6 + 0.5)
  local dy = math.floor(box_y + 7 + (ny or 0) * 6 + 0.5)
  screen.level(8)
  screen.pixel(dx - 1, dy); screen.pixel(dx + 1, dy)
  screen.pixel(dx, dy - 1); screen.pixel(dx, dy + 1); screen.fill()
  screen.level(15)
  screen.rect(dx, dy, 2, 2); screen.fill()
  -- label below
  if label then
    screen.font_face(25); screen.font_size(6)
    screen.level(7)
    screen.move(box_x + 7, box_y + 21); screen.text_center(label)
    screen.font_face(1); screen.font_size(8)
  end
end

-- Map JAM.root semitone offset to a note-name label (A is the home key).
local function jam_root_label()
  local n = ((JAM.root or 0) % 12 + 12) % 12
  local octv = math.floor((JAM.root or 0) / 12)
  return JAM.note_names[n + 1] .. (octv ~= 0 and (octv > 0 and ("+" .. octv) or tostring(octv)) or "")
end

local function draw_jam()
  -- header
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(2, 6); screen.text("JAM MODE")
  -- L2 indicator (BPM-edit mode armed)
  if l2_held then
    screen.level(0); screen.rect(50, 0, 22, 9); screen.fill()
    screen.level(15); screen.move(52, 6); screen.text("L2:BPM")
  end
  local ap = party[active]
  if ap then
    screen.level(11)
    screen.move(126, 6); screen.text_right(CHAR_NAME[ap.class])
  end
  screen.level(3)
  screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- 4 voice columns, 32px wide each — top section (rows 11-44).
  -- Each column tops with the character's animated 8x8 sprite "jamming" its
  -- instrument: a 1-px talk-bob + a flickering note-dot above the sprite.
  local saved_facing = player.facing
  player.facing = "down"
  for i, p in ipairs(party) do
    local cx = (i - 1) * 32
    local act = (i == active)
    if act then
      screen.level(2)
      screen.rect(cx, 11, 32, 33); screen.fill()
    end
    -- jamming sprite (centered horizontally in the column, top of the panel)
    local fn = SPRITE_BY_CLASS[p.class]
    if fn then
      local bob = ((tick + i * 3) % 6 < 3) and 0 or 1
      fn(cx + 12, 11 - bob)
      -- note flicker above the sprite (suggests they're playing)
      if ((tick + i * 5) % 8) < 4 then
        screen.level(15); screen.pixel(cx + 22, 12 - bob); screen.fill()
      else
        screen.level(11); screen.pixel(cx + 9,  13 - bob); screen.fill()
      end
    end
    -- 4 horizontal bars: cutoff / resonance / wet / delay
    local labels = {"CUT", "RES", "WET", "DLY"}
    local r = CUTOFF_RANGE[p.class]
    local norm = {
      math.log(p.cutoff / r.min) / math.log(r.max / r.min),
      ((p.resonance or 0.05) - 0.05) / 0.45,
      p.xwet or 0,
      p.dly or 0,
    }
    for j = 1, 4 do
      local y = 24 + (j - 1) * 5
      local v = math.max(0, math.min(1, norm[j] or 0))
      screen.level(act and 11 or 7)
      screen.move(cx + 2, y); screen.text(labels[j])
      screen.level(2); screen.rect(cx + 16, y - 3, 14, 1); screen.fill()
      screen.level(act and 15 or 8)
      screen.rect(cx + 16, y - 3, math.floor(14 * v + 0.5), 1); screen.fill()
    end
  end
  player.facing = saved_facing
  -- divider
  screen.level(3)
  screen.move(0, 45); screen.line(128, 45); screen.stroke()
  -- bottom section (rows 46-63): global params + bigger stick visualizers
  -- Global params (left)
  screen.level(11); screen.move(2, 51); screen.text("BPM")
  screen.level(15); screen.move(22, 51); screen.text(tostring(BATTLE_BPM))
  screen.level(11); screen.move(2, 58); screen.text("ROOT")
  screen.level(15); screen.move(26, 58); screen.text(jam_root_label())
  -- Mode (current scale) at footer-left, A to cycle through unlocked modes
  screen.level(11); screen.move(2, 63); screen.text("MODE")
  screen.level(15); screen.move(26, 63); screen.text(JAM.mode:upper())
  -- Stick visualizers (only shown in debug mode — kept the jam UI cluttered).
  if debug_visible then
    local lx, ly, rx, ry = 0, 0, 0, 0
    if ap and ap.stick then
      lx, ly, rx, ry = ap.stick.lx, ap.stick.ly, ap.stick.rx, ap.stick.ry
    end
    ANIM.draw_stick_big(60, 47, lx, ly, "L")
    ANIM.draw_stick_big(80, 47, rx, ry, "R")
  end
  -- footer hints (size 5 for tighter footprint than the rest of the UI)
  screen.font_size(5)
  screen.level(6)
  if l2_held then
    screen.move(126, 51); screen.text_right("L2 dpadLR=BPM")
  else
    screen.move(126, 51); screen.text_right("UD scale LR root")
  end
  screen.move(126, 57); screen.text_right("L1/R1 voice  A mode")
  screen.move(126, 63); screen.text_right("B/SELECT exit")
  screen.font_face(1); screen.font_size(8)
end

-- UI is intentionally global (saves a `local` slot — we're at the 200-cap).
UI = {}
UI.draw_quests = function()
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(64, 7); screen.text_center("QUESTS")
  screen.level(3); screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- Hens
  do
    local q = QUESTS.hens
    local status, lev
    if q.discount then status, lev = "DONE  shop -25%", 11
    else status, lev = q.wins .. "/" .. q.target .. " road wins", 15 end
    screen.level(11); screen.move(2, 18); screen.text("Hens (Shopkeep)")
    screen.level(lev); screen.move(2, 24); screen.text(status)
  end
  -- Brann
  do
    local q = QUESTS.brann
    local status, lev
    if q.claimed then status, lev = "DONE  +200g, +1 Star", 11
    else status, lev = q.wins .. "/" .. q.target .. " road wins", 15 end
    screen.level(11); screen.move(2, 32); screen.text("Brann (Smith)")
    screen.level(lev); screen.move(2, 38); screen.text(status)
  end
  -- Tova
  do
    local s = QUESTS.tova.spoke
    local visited = (s.Veris and 1 or 0) + (s.Aurin and 1 or 0)
                  + (s.Mira and 1 or 0) + (s.Iolen and 1 or 0)
    local status, lev
    if QUESTS.tova.claimed then status, lev = "DONE  +80g + lore", 11
    else status, lev = visited .. "/4 sages met", 15 end
    screen.level(11); screen.move(2, 46); screen.text("Tova (Sage)")
    screen.level(lev); screen.move(2, 52); screen.text(status)
  end
  screen.level(6); screen.move(126, 62); screen.text_right("B back")
  screen.font_face(1); screen.font_size(8)
end

UI.draw_shards = function()
  -- Visual constellation of the 7 shards arranged around a central circle.
  -- Lit when collected, dim with diamond outline when not.
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(64, 7); screen.text_center("CRYSTAL SYNTH")
  screen.level(3); screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- centre
  local cx, cy = 64, 36
  local r = 18
  local order = {"lydian", "dorian", "mixolydian", "phrygian", "aeolian", "locrian", "ionian"}
  local n = 0
  -- Draw a subtle outer ring connecting collected shards
  screen.level(2); screen.circle(cx, cy, r); screen.stroke()
  -- Each shard at an angle around the circle
  for i, name in ipairs(order) do
    local ang = -math.pi / 2 + (i - 1) * (2 * math.pi / 7)  -- start at top
    local sx = cx + math.cos(ang) * r
    local sy = cy + math.sin(ang) * r
    local got = shards[name]
    if got then n = n + 1 end
    -- shard glyph: small diamond
    screen.level(got and 15 or 4)
    screen.move(sx, sy - 3); screen.line(sx + 3, sy)
    screen.line(sx, sy + 3); screen.line(sx - 3, sy); screen.close()
    if got then screen.fill() else screen.stroke() end
    -- short label
    screen.level(got and 11 or 3)
    local lx = cx + math.cos(ang) * (r + 8)
    local ly = cy + math.sin(ang) * (r + 8) + 2
    screen.move(math.floor(lx), math.floor(ly))
    screen.text_center(name:sub(1, 3):upper())
  end
  -- centre core (brightens with progress)
  screen.level(math.min(15, 2 + n * 2))
  screen.rect(cx - 1, cy - 1, 3, 3); screen.fill()
  -- count + hint
  screen.level(11)
  screen.move(64, 56); screen.text_center(n .. " / 7 shards collected")
  screen.level(6); screen.move(126, 62); screen.text_right("B back")
  screen.font_face(1); screen.font_size(8)
end

-- Pass 43: per-enemy lore (visual-id keyed, 2 short lines each).
BESTIARY_LORE = {
  slime      = {"Plodding gel of cave damp.", "Drops the same beat each time."},
  bat        = {"Echolocates in flat fifths.", "Quick to chitter, slow to retreat."},
  mushroom   = {"Releases pollen on a 12-beat", "loop. Patient. Almost polite."},
  wisp       = {"A bright orphan note.", "Sings the same syllable until it dies."},
  wolf       = {"Triple-strike pattern. Pack",  "memory; Suno couldn't tame them."},
  echo       = {"Cave-1 boss. Repeats your",  "last move with crueler timing."},
  sprite     = {"Faerie remnant. Distracts",  "with bright pixels mid-cast."},
  treant     = {"Centuries-old. Sap runs slow", "but it runs. Strike the bark."},
  sentinel   = {"Cave-2 boss. Three-meter",   "weight, three-beat tell."},
  crab       = {"Side-stepping coastal pest.", "Hard shell, soft underchord."},
  manta      = {"Tide-glide ambush. Strikes",  "between the seventh wave's beats."},
  tide       = {"Cave-3 boss. Faces in every", "still pool. Anwell knows them."},
  scorpion   = {"Dune-bred. Tail-strike on",   "the rest beat — never the count."},
  spectre    = {"Half-translucent. Was",      "someone's grandmother once."},
  dunerider  = {"Cave-4 boss. Six-beats out,", "two-back. Cut on the rest."},
  yeti       = {"Carries the cold in its lungs.", "Breath alone slows your tempo."},
  frostwisp  = {"A dim wisp the cold caught.",  "Sings in a key it can't escape."},
  granite    = {"Stone golem. Hears all hits", "as the same dull chord."},
  crow       = {"Wraith-feathered. Flies",     "between bars, never on them."},
  snowgaunt  = {"Cave-5 boss. Waltzes in three.", "Don't follow its meter."},
  lich       = {"Robed and bone-fingered.",    "Conducts pain like a downbeat."},
  voidcrawler= {"Many-legged shadow. Each",    "leg a separate pulse."},
  echosuno   = {"Mocking shadow of the King.", "His timing, none of his weight."},
  mutewarden = {"Suno's silent sentry.",      "No face. No call. No mercy."},
  locrius    = {"Cave-6 boss. Half-step demon.", "Strike out of time; he can't follow."},
  suno       = {"The Tuning King.",            "He fears the seventh most of all."},
}

UI.draw_bestiary = function()
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(64, 7); screen.text_center("BESTIARY")
  screen.level(3); screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- collect entries into a stable order
  local list = {}
  for _, e in pairs(CONTENT.bestiary) do list[#list+1] = e end
  table.sort(list, function(a, b) return (a.hp_max or 0) < (b.hp_max or 0) end)
  if #list == 0 then
    screen.level(7); screen.move(64, 36); screen.text_center("(no defeated foes yet)")
  else
    local total = #list
    -- bestiary_idx (selectable via dpad UD in the BESTIARY state handler)
    CONTENT.bestiary_idx = math.max(1, math.min(total, CONTENT.bestiary_idx or 1))
    local sel = CONTENT.bestiary_idx
    screen.level(7); screen.move(126, 16); screen.text_right(sel .. "/" .. total)
    -- Show 4 entries with selection caret; current at top of view.
    local view_start = math.max(1, sel - 1)
    if view_start + 3 > total then view_start = math.max(1, total - 3) end
    for i = 0, math.min(3, total - 1) do
      local idx = view_start + i
      local e = list[idx]
      local y = 18 + i * 7
      local is_sel = (idx == sel)
      screen.level(is_sel and 15 or 0)
      screen.move(2, y + 5); screen.text(is_sel and ">" or " ")
      screen.level(is_sel and 15 or 8); screen.move(8, y + 5); screen.text(e.name)
      screen.level(is_sel and 13 or 6); screen.move(74, y + 5); screen.text("HP " .. e.hp_max)
      screen.level(is_sel and 13 or 6); screen.move(102, y + 5); screen.text("AT " .. e.atk)
    end
    -- Selected entry's lore lines at the bottom (with subtle separator).
    local cur = list[sel]
    local lore = BESTIARY_LORE[cur.visual or cur.name] or {"(no lore yet.)", ""}
    screen.level(3); screen.move(0, 50); screen.line(128, 50); screen.stroke()
    screen.level(11); screen.move(2, 56); screen.text(lore[1] or "")
    screen.level(11); screen.move(2, 62); screen.text(lore[2] or "")
  end
  screen.level(6); screen.move(126, 62); screen.text_right("B back")
  screen.font_face(1); screen.font_size(8)
end

UI.draw_items = function()
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(64, 7); screen.text_center("ITEMS")
  screen.level(3); screen.move(0, 9); screen.line(128, 9); screen.stroke()
  local rows = {
    {"Salve", SHOP.inv.salve, "+35 HP all"},
    {"Vial",  SHOP.inv.vial,  "+10 MP all"},
    {"Ether", SHOP.inv.ether, "+25 MP all"},
    {"Star",  SHOP.inv.star,  "Revive KO'd"},
    {"Tonic", SHOP.inv.tonic, "+ATK 1 fight"},
    {"Key",   SHOP.inv.key,   "Open lock"},
  }
  for i, r in ipairs(rows) do
    local y = 14 + (i - 1) * 8
    screen.level(11); screen.move(8, y); screen.text(r[1])
    screen.level(15); screen.move(46, y); screen.text("x" .. r[2])
    screen.level(7); screen.move(72, y); screen.text(r[3])
  end
  screen.level(11); screen.move(2, 60); screen.text("Gold:")
  screen.level(15); screen.move(28, 60); screen.text(SHOP.gold .. "g")
  screen.level(6); screen.move(126, 60); screen.text_right("B back")
  screen.font_face(1); screen.font_size(8)
end

UI.draw_partysel = function()
  screen.font_face(25); screen.font_size(6)
  screen.level(15); screen.move(64, 7); screen.text_center("PARTY")
  screen.level(3); screen.move(0, 9); screen.line(128, 9); screen.stroke()
  -- ── ACTIVE PARTY (top half, rows 11-37) ──
  local saved_facing = player.facing
  player.facing = "down"
  for i, p in ipairs(party) do
    local cx = (i - 1) * 32
    local act = (i == active)
    if act then
      screen.level(2); screen.rect(cx, 11, 32, 26); screen.fill()
      screen.level(15); screen.rect(cx, 11, 32, 26); screen.stroke()
    end
    local fn = SPRITE_BY_CLASS[p.class]
    if fn then fn(cx + 12, 13) end
    screen.level(act and 15 or 11)
    screen.move(cx + 16, 28); screen.text_center(CHAR_NAME[p.class])
    screen.level(p.alive and 11 or 4)
    screen.move(cx + 16, 35); screen.text_center("HP " .. p.hp .. " L" .. (p.level or 1))
  end
  -- ── RECRUITS (lower half, rows 39-58) ──
  screen.level(3); screen.move(0, 38); screen.line(128, 38); screen.stroke()
  screen.level(11); screen.move(2, 44); screen.text("RECRUITS")
  for i, r in ipairs(CONTENT.recruits) do
    local cx = (i - 1) * 64
    local focused = (CONTENT.partysel_focus == i)
    if focused then
      screen.level(2); screen.rect(cx, 45, 64, 14); screen.fill()
      screen.level(15); screen.rect(cx, 45, 64, 14); screen.stroke()
    end
    -- sprite on left
    local fn = SPRITE_BY_CLASS[r.class]
    if fn then fn(cx + 2, 47) end
    -- name + class + joined badge
    screen.level(focused and 15 or (r.joined and 11 or 7))
    screen.move(cx + 12, 52); screen.text(CHAR_NAME[r.class])
    screen.level(r.joined and 11 or 4)
    screen.move(cx + 12, 58); screen.text(r.joined and "JOINED" or "(locked)")
  end
  player.facing = saved_facing
  if CONTENT.partysel_focus > 0
     and CONTENT.recruits[CONTENT.partysel_focus]
     and CONTENT.recruits[CONTENT.partysel_focus].joined then
    screen.move(2, 63); screen.text("A swap   B back")
  else
    screen.move(2, 63); screen.text("UD focus recruit  B back")
  end
  screen.font_face(1); screen.font_size(8)
end

function redraw()
  screen.clear()
  screen.aa(0)
  -- Pass 53: screen shake — translate the entire frame by a small jittered
  -- offset for the duration of ANIM.shake_t. Reset at end of frame.
  local shake_dx, shake_dy = 0, 0
  if ANIM.shake_t > 0 then
    ANIM.shake_t = ANIM.shake_t - 1
    local m = ANIM.shake_mag
    shake_dx = math.random(-m, m)
    shake_dy = math.random(-m, m)
    screen.translate(shake_dx, shake_dy)
    if ANIM.shake_t == 0 then ANIM.shake_mag = 0 end
  end
  if game_state == "TITLE" then draw_title()
  elseif game_state == "CUTSCENE" then draw_cutscene()
  elseif game_state == "OVERWORLD" then draw_overworld()
  elseif game_state == "DIALOGUE" then draw_dialogue()
  elseif game_state == "BATTLE" then draw_battle()
  elseif game_state == "BATTLE_END" then draw_battle_end()
  elseif game_state == "MENU" then draw_menu()
  elseif game_state == "STATUS" then draw_status()
  elseif game_state == "EQUIP" then draw_equip()
  elseif game_state == "VOYAGE" then draw_voyage()
  elseif game_state == "ENDING" then draw_ending()
  elseif game_state == "SHOP" then draw_shop()
  elseif game_state == "JAM" then draw_jam()
  elseif game_state == "ITEMS" then UI.draw_items()
  elseif game_state == "QUESTS" then UI.draw_quests()
  elseif game_state == "BESTIARY" then UI.draw_bestiary()
  elseif game_state == "SHARDS" then UI.draw_shards()
  elseif game_state == "PARTYSEL" then UI.draw_partysel()
  end
  -- Pass 36: MIDI activity indicator. Tiny dot in the top-right corner
  -- that flickers when an event came in within the last few ticks.
  if (tick - (CONTENT.midi_active_t or -99)) < 6 then
    screen.level(15); screen.rect(125, 0, 3, 3); screen.fill()
    screen.level(8);  screen.pixel(124, 1); screen.fill()
  end
  -- (Pass 48 day/night stipple removed — the density math was inverted,
  --  flooding the screen with black pixels during transitions. If we
  --  bring this back later it should use a single 25%-coverage stipple
  --  pattern scaled by intensity instead of variable stride.)
  -- ── Pass 53 visual-effect overlays ───────────────────────────────────
  -- Particles: little expanding bursts. Lifespan ~12 ticks each.
  for i = #ANIM.particles, 1, -1 do
    local pcl = ANIM.particles[i]
    local age = tick - pcl.t
    if age >= 12 then
      table.remove(ANIM.particles, i)
    else
      local px = math.floor(pcl.x + pcl.vx * age + 0.5)
      local py = math.floor(pcl.y + pcl.vy * age + 0.5)
      screen.level(math.max(2, pcl.lev - age))
      screen.pixel(px, py); screen.fill()
    end
  end
  -- Footstep dust: 2 puff pixels behind player, fading. Lifespan ~10 ticks.
  for i = #ANIM.dust, 1, -1 do
    local d = ANIM.dust[i]
    local age = tick - d.t
    if age >= 10 then
      table.remove(ANIM.dust, i)
    else
      screen.level(math.max(2, 9 - age))
      screen.pixel(d.x - 1, d.y); screen.pixel(d.x + 1, d.y); screen.fill()
    end
  end
  -- Hit flash: invert all pixels for 1 frame. We approximate by drawing a
  -- bright translucent overlay (norns has no real invert; use level-15
  -- stipple). Triggered by ANIM.flash_hit().
  if (tick - ANIM.hit_flash_t) < 2 then
    screen.level(15)
    for y = 0, 63, 2 do
      for x = 0, 127, 2 do screen.pixel(x, y) end
    end
    screen.fill()
  end
  -- Critical-HP vignette: pulsing dark frame when ANY alive party member
  -- is below 25% HP during BATTLE.
  if game_state == "BATTLE" then
    local critical = false
    for _, p in ipairs(party) do
      if p.alive and p.hp_max > 0 and p.hp <= p.hp_max / 4 then critical = true; break end
    end
    if critical then
      local pulse = ((tick % 8) < 4) and 0 or 2
      screen.level(pulse)
      screen.rect(0, 0, 128, 1); screen.fill()
      screen.rect(0, 63, 128, 1); screen.fill()
      screen.rect(0, 0, 1, 64); screen.fill()
      screen.rect(127, 0, 1, 64); screen.fill()
    end
  end
  -- Reset shake translate so the next frame starts clean.
  if shake_dx ~= 0 or shake_dy ~= 0 then
    screen.translate(-shake_dx, -shake_dy)
  end
  screen.update()
end
