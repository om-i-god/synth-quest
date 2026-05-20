# Resonance Combat Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build a small Resonance FX runtime (timed effects + scheduled events + per-action hooks) and wire 6 Resonances to literal bible effects (Heavy Hand, Long Echo, Scatter, Slow Wheel, Masked Voice, Threefold). Ring already done; Spring deferred.

**Architecture:** Three per-battle sub-systems in `synth-quest.lua`: `RESO_FX` (timed-effect list read at use-sites), `RESO_QUEUE` (scheduled future events), and armed flags/counters on party members + enemy fields. A new `apply_resonance_effect(rid, p)` dispatcher replaces the inline Ring arming.

**Tech Stack:** Lua 5.4 on norns. ATB combat at 85 BPM; `RESO_BAR = 24` ticks.

**Spec:** `docs/specs/2026-05-20-resonance-effects-design.md`

> **BLOCKED on ECHO.** Do NOT execute this plan until the user's in-flight ECHO feature (`wraith` 8th party member; ~827 lines uncommitted on main as of 2026-05-20) is committed/stable. Echo assigns **Long Echo → wraith** (not bard). In Task 9, set `long_echo.character = "wraith"`, not `"bard"`. The runtime + the other 5 effects are independent of Echo. Recommended order: finish Echo → this plan → Cave 5 → Cave 6.

**Verification:** `luac -p` + code inspection (no hardware in autonomous session). Hardware playtest deferred to user.

**Backup:** snapshot `synth-quest.lua` after the pass per memory `synth-quest-backups`.

---

## Task 1: Resonance FX runtime scaffold

**Files:** Modify `synth-quest.lua` — add runtime near the ANIM/battle-state definitions; tick hooks in the battle update loop; clears in enter/exit_battle.

- [ ] **Step 1: Find the battle update loop + a home for the runtime**

Run: `cd ~/dev/synth-quest && grep -n "local function battle_tick\|function update_battle\|game_state == \"BATTLE\"" synth-quest.lua | head -10`
Also: `grep -n "COMBO_WINDOW = " synth-quest.lua` (place RESO_BAR near it).

- [ ] **Step 2: Add the runtime globals + helpers**

Near `COMBO_WINDOW` definition, add:

```lua
-- ── Resonance FX runtime ──────────────────────────────────────────────
-- Per-battle. RESO_BAR ≈ 4 beats at 85 BPM (COMBO_WINDOW=6 ticks ≈ 1 beat).
RESO_BAR = 24
RESO_FX = {}      -- active timed effects: {kind, expires, ...params}
RESO_QUEUE = {}   -- scheduled events: {at, fn}

function reso_fx_add(kind, ticks, params)
  local e = {kind = kind, expires = (tick or 0) + ticks}
  if params then for k, v in pairs(params) do e[k] = v end end
  RESO_FX[#RESO_FX + 1] = e
  return e
end

function reso_fx_active(kind)
  for _, e in ipairs(RESO_FX) do
    if e.kind == kind and (tick or 0) < e.expires then return e end
  end
  return nil
end

function reso_schedule(delay, fn)
  RESO_QUEUE[#RESO_QUEUE + 1] = {at = (tick or 0) + delay, fn = fn}
end

function reso_fx_tick()
  for i = #RESO_FX, 1, -1 do
    if (tick or 0) >= RESO_FX[i].expires then table.remove(RESO_FX, i) end
  end
  for i = #RESO_QUEUE, 1, -1 do
    if (tick or 0) >= RESO_QUEUE[i].at then
      local fn = RESO_QUEUE[i].fn
      table.remove(RESO_QUEUE, i)
      if fn then fn() end
    end
  end
end

function reso_clear_all()
  RESO_FX = {}
  RESO_QUEUE = {}
end
```

- [ ] **Step 3: Call reso_fx_tick() in the battle update loop**

Find where the battle state advances each tick (search for where `enemy_tick()` or ATB fill is called per frame). Add `reso_fx_tick()` alongside, guarded to BATTLE state.

- [ ] **Step 4: Clear runtime on battle enter/exit**

In enter_battle and exit_battle (the party-reset areas at lines ~6757/6800/6842/6979 region and exit), call `reso_clear_all()`. Also clear new per-member fields: in the existing party-reset loops that set `p.ring_armed = false`, add `p.long_echo_charges = 0; p.threefold_until = -99`. Clear enemy field where the enemy is initialized: `enemy.confused_until = -99` (find enemy init in enter_battle / start_*_battle).

- [ ] **Step 5: Verify**

`cd ~/dev/synth-quest && luac -p synth-quest.lua && echo SYNTAX OK`
`grep -n "RESO_FX\|RESO_QUEUE\|reso_fx_tick\|reso_clear_all" synth-quest.lua | head` — confirm definitions + tick call + clears.

- [ ] **Step 6: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat(reso): FX runtime scaffold (timed effects + scheduled events)"
```

---

## Task 2: apply_resonance_effect dispatcher (move Ring in)

**Files:** Modify `synth-quest.lua` — add dispatcher near other Resonance helpers; replace inline Ring arming in the RESO branch.

- [ ] **Step 1: Find the RESO arming site**

Run: `cd ~/dev/synth-quest && grep -n 'rid == "ring" then' synth-quest.lua`
This is in `apply_player_action`'s RESO branch (from the fluid-invocation pass). It currently does `if rid == "ring" then p.ring_armed = true end`.

- [ ] **Step 2: Add apply_resonance_effect**

Add near the `play_*_anim` functions (search `^function play_ring_anim`). Insert before them:

```lua
-- Dispatch a Resonance's combat effect at invoke time. Ring arms a
-- consumed-on-next-ATK buff; others push RESO_FX timed effects, set
-- counters, or mark the enemy. See docs/specs/2026-05-20-resonance-effects-design.md.
function apply_resonance_effect(rid, p)
  if rid == "ring" then
    p.ring_armed = true
  elseif rid == "heavy_hand" then
    reso_fx_add("duck_enemies", 2 * RESO_BAR, {mult = 0.50})
  elseif rid == "long_echo" then
    p.long_echo_charges = 2
  elseif rid == "scatter" then
    if enemy and enemy.attack_pattern then
      enemy.confused_until = (tick or 0) + 4 * RESO_BAR
      -- Fisher-Yates shuffle (same as Sergei's MIX)
      local ap = enemy.attack_pattern
      for i = #ap, 2, -1 do
        local j = math.random(i)
        ap[i], ap[j] = ap[j], ap[i]
      end
      enemy.pattern_idx = 1
    end
  elseif rid == "slow_wheel" then
    reso_fx_add("slow_wheel", 4 * RESO_BAR, {spd = 1})
  elseif rid == "masked_voice" then
    reso_fx_add("masked_voice", 1 * RESO_BAR, {mult = 1.25})
  elseif rid == "threefold" then
    p.threefold_until = (tick or 0) + 1 * RESO_BAR
  end
end
```

- [ ] **Step 3: Replace inline Ring arming with the dispatcher call**

In the RESO branch of apply_player_action, replace:
```lua
    if rid == "ring" then
      p.ring_armed = true
    end
```
with:
```lua
    apply_resonance_effect(rid, p)
```

- [ ] **Step 4: Verify**

`luac -p` passes. `grep -n "apply_resonance_effect" synth-quest.lua` shows definition + call. Confirm the old `if rid == "ring" then p.ring_armed = true end` inline block is gone from the RESO branch.

- [ ] **Step 5: Commit**

```bash
cd ~/dev/synth-quest && git add synth-quest.lua && git commit -m "feat(reso): apply_resonance_effect dispatcher (Ring moved in)"
```

---

## Task 3: Heavy Hand — enemy damage ×0.5 for 2 bars

**Files:** Modify `synth-quest.lua` — `damage_party`.

- [ ] **Step 1:** In `damage_party(p, amount)` (line ~15873), after the party-size scaling `do ... end` block, add:

```lua
  -- Heavy Hand (Resonance): enemy output ducked for the effect's duration.
  do
    local hh = reso_fx_active("duck_enemies")
    if hh then amount = math.max(1, math.floor(amount * (hh.mult or 0.5))) end
  end
```

- [ ] **Step 2: Verify** `luac -p` passes; grep `duck_enemies` shows arming (Task 2) + this read site.
- [ ] **Step 3: Commit** `git commit -m "feat(reso): Heavy Hand — enemy damage ducked 2 bars"`

---

## Task 4: Slow Wheel — party SPD +1 for 4 bars

**Files:** Modify `synth-quest.lua` — ATB fill site.

- [ ] **Step 1: Find ATB fill**

Run: `cd ~/dev/synth-quest && grep -n "atb = .*atb\|p.atb = p.atb\|atb +\|INST.spd(" synth-quest.lua | head -10`
Locate where each party member's `p.atb` increments using their SPD per battle tick.

- [ ] **Step 2:** At the effective-SPD computation for the ATB fill, add the Slow Wheel bonus:

```lua
local sw = reso_fx_active("slow_wheel")
local eff_spd = INST.spd(p) + (sw and sw.spd or 0)
```
and use `eff_spd` in the ATB increment instead of `INST.spd(p)`. (Adapt to the actual existing variable names; if the fill uses `INST.spd(p)` inline, wrap it with the bonus.)

- [ ] **Step 3: Verify** `luac -p` passes; grep `slow_wheel` shows arming + read.
- [ ] **Step 4: Commit** `git commit -m "feat(reso): Slow Wheel — party SPD +1 for 4 bars"`

---

## Task 5: Masked Voice — party damage +25% for 1 bar

**Files:** Modify `synth-quest.lua` — `apply_player_action` ATK + MAG damage computation.

- [ ] **Step 1: Find the damage computation**

Run: `cd ~/dev/synth-quest && grep -n "damage_enemy(dmg\|local dmg = INST.atk\|INST.mag" synth-quest.lua | head -10`

- [ ] **Step 2:** Just before each `damage_enemy(dmg, crit)` call in the ATK and MAG branches, apply the multiplier:

```lua
local mv = reso_fx_active("masked_voice")
if mv then dmg = math.floor(dmg * (mv.mult or 1.25)) end
```

Place it AFTER the Ring multiplier (so they stack multiplicatively, which is fine) and AFTER crit/buffed adjustments.

- [ ] **Step 3: Verify** `luac -p` passes; grep `masked_voice` shows arming + read site(s).
- [ ] **Step 4: Commit** `git commit -m "feat(reso): Masked Voice — party damage +25% for 1 bar"`

---

## Task 6: Long Echo — duplicate next 2 ATKs at 50%, 1 beat late

**Files:** Modify `synth-quest.lua` — `apply_player_action` ATK branch.

- [ ] **Step 1:** In the ATK branch, immediately AFTER `damage_enemy(dmg, crit)`, add:

```lua
  -- Long Echo (Resonance): the next 2 attacks echo at 50%, one beat late.
  if (p.long_echo_charges or 0) > 0 then
    p.long_echo_charges = p.long_echo_charges - 1
    local echo_dmg = math.max(1, math.floor(dmg * 0.50))
    reso_schedule(6, function()
      if enemy and enemy.alive then
        damage_enemy(echo_dmg, false)
        ANIM.burst(96, 32, 4, 11)
      end
    end)
  end
```

(96, 32 is the enemy sprite area used by existing damage bursts — confirm by grepping `ANIM.burst(96, 32`.)

- [ ] **Step 2: Verify** `luac -p` passes; grep `long_echo_charges` shows arming (Task 2) + consume here.
- [ ] **Step 3: Commit** `git commit -m "feat(reso): Long Echo — next 2 attacks echo at 50%"`

---

## Task 7: Scatter — CONFUSE enemy 4 bars (re-shuffle in enemy_tick)

**Files:** Modify `synth-quest.lua` — `enemy_tick`.

- [ ] **Step 1:** In `enemy_tick()` (line ~16499), where the next gap is read (`enemy.attack_pattern[enemy.pattern_idx]`), add a re-shuffle when confused:

```lua
  if enemy.confused_until and (tick or 0) < enemy.confused_until then
    local ap = enemy.attack_pattern
    for i = #ap, 2, -1 do
      local j = math.random(i)
      ap[i], ap[j] = ap[j], ap[i]
    end
  end
```

Place it just before `local next_gap = enemy.attack_pattern[enemy.pattern_idx] or 8`.

- [ ] **Step 2: Verify** `luac -p` passes; grep `confused_until` shows arming (Task 2) + this read; confirm enemy.confused_until is initialized/cleared on battle enter.
- [ ] **Step 3: Commit** `git commit -m "feat(reso): Scatter — CONFUSE enemy attack timing 4 bars"`

---

## Task 8: Threefold — party action heals mathwiz caster 5% for 1 bar

**Files:** Modify `synth-quest.lua` — `apply_player_action` (end of function).

- [ ] **Step 1:** At the very END of `apply_player_action(p)` (after all action branches resolve, before the function returns/ends), add:

```lua
  -- Threefold (Resonance): while active, every party action feeds the caster.
  for _, c in ipairs(party) do
    if c.alive and c.threefold_until and (tick or 0) < c.threefold_until then
      local heal = math.floor((c.hp_max or 0) * 0.05)
      if heal > 0 then
        c.hp = math.min(c.hp_max, c.hp + heal)
      end
    end
  end
```

- [ ] **Step 2: Verify** `luac -p` passes; grep `threefold_until` shows arming (Task 2) + this heal hook + the battle-reset clear (Task 1).
- [ ] **Step 3: Commit** `git commit -m "feat(reso): Threefold — party action heals caster 5% for 1 bar"`

---

## Task 9: Catalog updates (RESONANCES table)

**Files:** Modify `synth-quest.lua` — RESONANCES table (~line 180).

- [ ] **Step 1:** Update the 5 stub rows (long_echo, masked_voice, scatter, slow_wheel, threefold) with character + effect + a mythos line. Leave `spring` a stub (`character = nil`). Heavy Hand already has its effect; confirm its `character = "drummer"`.

```lua
  long_echo = {
    name = "The Long Echo", character = "wraith", mp_cost = 4,  -- wraith=Echo per the ECHO feature
    mythos = "A wandering singer who repeated any phrase you taught her, each time softer and behind.",
    effect = { kind = "echo_attacks", charges = 2, dmg_mult = 0.50, delay_ticks = 6 },
  },
  masked_voice = {
    name = "The Masked Voice", character = "mage", mp_cost = 6,
    mythos = "A courtier who could sing in any other person's voice.",
    effect = { kind = "mode_stack", duration_bars = 1, dmg_mult = 1.25 },
  },
  scatter = {
    name = "The Scatter", character = "engineer", mp_cost = 4,
    mythos = "A singer crushed in a bell-mine; the mine echoed her in tiny shards for a year.",
    effect = { kind = "confuse_enemy", duration_bars = 4 },
  },
  slow_wheel = {
    name = "The Slow Wheel", character = "warrior", mp_cost = 4,
    mythos = "A millwright who tuned her wheel to a slow phase; it never stopped turning.",
    effect = { kind = "party_spd", duration_bars = 4, spd = 1 },
  },
  threefold = {
    name = "The Threefold", character = "mathwiz", mp_cost = 8,
    mythos = "Three sisters who sang so closely no one knew which was which. One died; two kept singing for three.",
    effect = { kind = "heal_on_action", duration_bars = 1, heal_pct = 0.05 },
  },
```

Keep `spring = { name = "The Spring", character = nil, mp_cost = 4, mythos = "...", effect = {} },` unchanged (deferred).

- [ ] **Step 2: Verify** `luac -p` passes; grep confirms 7 Resonances have non-nil `character` (ring, heavy_hand, long_echo, masked_voice, scatter, slow_wheel, threefold) and spring is nil.
- [ ] **Step 3: Commit** `git commit -m "feat(reso): catalog — character + effect specs for 5 Resonances"`

---

## Task 10: Final verify + snapshot

- [ ] **Step 1:** `cd ~/dev/synth-quest && luac -p synth-quest.lua && echo SYNTAX OK && wc -c synth-quest.lua`
- [ ] **Step 2:** Confirm dispatcher covers all 7: `grep -c 'rid == "ring"\|rid == "heavy_hand"\|rid == "long_echo"\|rid == "scatter"\|rid == "slow_wheel"\|rid == "masked_voice"\|rid == "threefold"' synth-quest.lua` — expect 7.
- [ ] **Step 3:** Snapshot: `cp ~/dev/synth-quest/synth-quest.lua "$HOME/dev/synth-quest/backups/synth-quest-$(date +%Y%m%d-%H%M%S).lua"`

## Acceptance Criteria
- All 7 active Resonances dispatch through `apply_resonance_effect`; Ring unchanged.
- RESO_FX + RESO_QUEUE ticked each battle frame; cleared on enter/exit.
- Each of the 6 new effects implemented per spec.
- `luac -p` passes; file growth < +8KB.

## Self-Review
- Spec coverage: Task 1 (runtime) → arch §1-3; Task 2 (dispatcher) → arch wiring; Tasks 3-8 → the 6 effect specs; Task 9 → catalog. All spec sections covered.
- Placeholders: none.
- Type consistency: `reso_fx_active`/`reso_fx_add`/`reso_schedule`/`reso_fx_tick`/`reso_clear_all`, fields `long_echo_charges`/`threefold_until`/`confused_until`, effect kinds `duck_enemies`/`slow_wheel`/`masked_voice` — consistent across tasks.
- Soft spot: ATB fill site (Task 4) and damage-computation sites (Task 5) need the implementer to match actual variable names; flagged in those tasks.
