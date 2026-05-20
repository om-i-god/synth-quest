# Synth Quest — Resonance Combat Effects (Design)

Date: 2026-05-20
Status: DRAFT — **BLOCKED on the ECHO 8th-party-member feature** (authored autonomously; user to review on return).

> **DEPENDENCY (discovered 2026-05-20, mid-autonomous-session):** The user has an in-flight ECHO feature (`docs/specs/2026-05-19-echo-eighth-party-member-design.md`, committed as `ab7a7d9`; implementation ~827 lines uncommitted on `main`, parses cleanly). Echo adds a `wraith` class as the 8th party member and assigns **Long Echo → wraith (Echo)**, NOT bard as this spec originally assumed. The Echo plan explicitly defers Long Echo's combat effect to a "follow-on spec" — i.e. THIS spec.
>
> **Resolution:** This pass must run AFTER Echo lands. The corrected class map: cleric=Ring, drummer=Heavy Hand, **wraith=Long Echo**, engineer=Scatter, warrior=Slow Wheel, mage=Masked Voice, mathwiz=Threefold. With Echo as the 8th character, bard and Spring are both currently unassigned — Spring's home is an open design question for the user (Spring is heal-echo, bard isn't a healer). The runtime + the 6 non-Long-Echo effects in this spec are unaffected by Echo and remain valid; only Long Echo's character changes from bard→wraith.
>
> I did NOT implement this pass on top of the user's uncommitted Echo WIP (entanglement / clobber risk). Recommended sequence: finish Echo → this pass → Cave 5 → Cave 6.

## Summary

Implement the actual combat effects for the Resonances. The fluid invocation (R2 → SFX + animation + arm) shipped 2026-05-19; only Ring has a real effect. This pass builds a small **Resonance FX runtime** (timed effects + scheduled events + per-action hooks) and wires 6 more Resonances to literal bible effects. Spring is deferred (no clean 1:1 character home; see acquisition spec's "one per character" constraint). One Resonance per character.

## Decisions (locked — autonomous, documented for review)

| Decision | Choice | Rationale |
|---|---|---|
| Faithfulness | Literal — build the engine features | User chose "literal everywhere" |
| 8th Resonance | Defer Spring | User chose; Spring's natural owner (healer) is cleric, who has Ring |
| Class map | cleric=Ring (done), drummer=Heavy Hand, bard=Long Echo, engineer=Scatter, warrior=Slow Wheel, mage=Masked Voice, mathwiz=Threefold | Lore-fit; one per character per acquisition spec |
| Bar length | `RESO_BAR = 24` ticks (≈4 beats at 85 BPM; combo window of 6 ticks ≈ 1 beat) | Matches existing COMBO_WINDOW timing |

## Engine facts (from current code)

- Combat is ATB-based: `p.atb` fills over time; `INST.spd(p) = p.spd + instrument.spd` gates fill rate; ATB resets to 0 after acting.
- `BATTLE_BPM = 85`. `COMBO_WINDOW = 6` ticks ≈ one beat. So 1 bar ≈ 24 ticks.
- `damage_party(p, amount)` (line ~15873) computes incoming damage to a party member — insertion point for Heavy Hand's enemy-damage reduction.
- Enemy has `enemy.attack_pattern` (array of gaps) + `enemy.pattern_idx`; `enemy_tick()` (line ~16499) drives attacks. Sergei's MIX (line ~16177) already shuffles `attack_pattern` Fisher-Yates — **Scatter's CONFUSE reuses this exact mechanic.**
- `p.ring_armed` is the existing armed-buff precedent (set on invoke, consumed by next ATK).
- Party-reset loops at lines 6757/6800/6842/6979 clear per-battle flags — new fields cleared here.

## Architecture — Resonance FX runtime

Three lightweight sub-systems, all per-battle (cleared on enter/exit):

### 1. `RESO_FX` — active timed effects list

A global list. Each entry: `{kind = "<name>", expires = tick + N, ...params}`. Ticked once per battle frame by a new `reso_fx_tick()` called from the main battle update. Expired entries removed. Effects that need a continuous modifier (Slow Wheel SPD, Heavy Hand enemy-damage, Masked Voice party-damage) are READ from this list at the point of use rather than mutating base stats — avoids stat-drift bugs if an effect is interrupted.

Helper: `reso_fx_active(kind)` returns the entry if an effect of that kind is currently active (tick < expires), else nil. Used at read sites.

### 2. `RESO_QUEUE` — scheduled future events

A global list of `{at = tick + delay, fn = function() ... end}`. Ticked by `reso_queue_tick()`; entries whose `at <= tick` fire and are removed. Used by Long Echo (echo a 50% attack 1 beat after the real one).

### 3. Armed flags / counters on party members

- `p.ring_armed` (exists) — Ring
- `p.long_echo_charges` (0-2) — Long Echo
- `p.threefold_until` (tick) — Threefold's per-action heal window

Per-target fields:
- `enemy.confused_until` (tick) — Scatter
- (Heavy Hand, Slow Wheel, Masked Voice use RESO_FX entries, not target fields)

All new fields cleared in the four party-reset loops + on enter/exit_battle for the enemy fields.

## Per-Resonance Effect Specs

### Ring (cleric) — DONE, no change
Armed buff: next ATK deals ×1.30 and ignores enemy DEF. (`p.ring_armed`.)

### Heavy Hand (drummer) — `duck_enemies`, 2 bars, ×0.50
On invoke: push `RESO_FX` entry `{kind="duck_enemies", expires=tick+2*RESO_BAR, mult=0.50}`.
In `damage_party(p, amount)`, near the top (after party-size scaling): if `reso_fx_active("duck_enemies")`, multiply `amount` by its `mult`. Reads the active effect; does not mutate enemy stats. Bible: "every other voice ducked out of his way" — enemy output reduced.

### Long Echo (bard) — duplicate next 2 attacks 1 beat late at 50%
On invoke: set `p.long_echo_charges = 2`.
In `apply_player_action` ATK branch (after `damage_enemy(dmg, crit)`), if the acting `p.long_echo_charges > 0`:
- decrement charges
- capture `dmg` (the damage just dealt)
- schedule a `RESO_QUEUE` event at `tick + 6` (1 beat) that calls `damage_enemy(math.floor(dmg * 0.50), false)` if the enemy is still alive, plus a small `ANIM.burst` at the enemy for the echo visual.
Charges persist across the 2 attacks; expire only by consumption (cleared on battle end).

### Scatter (engineer) — CONFUSE one enemy 4 bars
On invoke: set `enemy.confused_until = tick + 4*RESO_BAR` and immediately shuffle `enemy.attack_pattern` Fisher-Yates (reuse the exact loop from Sergei's MIX at line ~16177).
In `enemy_tick()`, when the enemy is about to choose its next gap: if `enemy.confused_until and tick < enemy.confused_until`, re-shuffle `attack_pattern` before reading the next gap (so the timing stays chaotic for the whole window). When the window expires, behavior returns to the ordered pattern.

### Slow Wheel (warrior) — party SPD +1 for 4 bars
On invoke: push `RESO_FX` entry `{kind="slow_wheel", expires=tick+4*RESO_BAR, spd=1}`.
At the ATB-fill site (where `INST.spd(p)` gates `p.atb` increment), add `+ (reso_fx_active("slow_wheel") and reso_fx_active("slow_wheel").spd or 0)` to the effective SPD for ALL party members. Reads the active effect; does not mutate `p.spd`.

### Masked Voice (mage) — party damage +25% for 1 bar (mode-stack)
Interpretation of bible's "all party damage carries the active voice's mode (mode-bonus stacking)": a flat +25% party ATK/MAG damage for 1 bar. Concrete and balance-able.
On invoke: push `RESO_FX` entry `{kind="masked_voice", expires=tick+1*RESO_BAR, mult=1.25}`.
In `apply_player_action` (ATK and MAG damage computation), if `reso_fx_active("masked_voice")`, multiply the outgoing `dmg` by its `mult` before `damage_enemy`.

### Threefold (mathwiz) — party action heals caster 5% maxHP for 1 bar
On invoke: set `p.threefold_until = tick + 1*RESO_BAR` on the casting mathwiz.
In `apply_player_action`, at the END of any party member's action resolution: find any alive party member `c` with `c.threefold_until and tick < c.threefold_until`; heal `c` by `math.floor(c.hp_max * 0.05)` (capped at hp_max). "Three sisters singing for three" — every voice's action feeds the caster.

## Wiring: apply_resonance_effect

A new `apply_resonance_effect(rid, p)` function (the catalog comment already anticipates this) is called from the RESO branch in `apply_player_action` (where Ring is currently armed). It dispatches per-rid to set the armed flag / push the RESO_FX entry / set the enemy field. Replaces the current inline `if rid == "ring" then p.ring_armed = true end` with:

```lua
apply_resonance_effect(rid, p)
```

where `apply_resonance_effect` contains the per-Resonance arming logic above. Ring's existing behavior is preserved (moved into this function).

## Catalog updates

Fill in `RESONANCES` table `character` + `effect` + `mythos` for the 6 newly-wired Resonances (drummer/Heavy Hand already has effect; add character assignments + effect specs for long_echo, scatter, slow_wheel, masked_voice, threefold). Spring stays a stub with `character = nil`.

`RESONANCE_SITES` shrine/item entries for the 6 stay stubs (acquisition is a separate concern; this pass is combat effects only — a player can only invoke a Resonance they've attuned, and only Ring has a real attunement path so far). The effects are dormant until acquisition is built per-character in later passes, but the code path is complete and testable via the `flag.unlock_all`-style debug or by temporarily attuning.

## Edge cases

- **Effect interrupts:** RESO_FX effects are read at use-sites, so a KO'd caster doesn't corrupt a party-wide buff — the buff persists to its timer. (Design choice: Resonance effects, once invoked, run their full duration regardless of caster state, matching the bible's "the call carries.")
- **Stacking same effect:** invoking the same Resonance twice (where allowed) refreshes/extends the timer rather than stacking multiplicatively — the "already armed" / cooldown guards from the fluid-invocation pass already prevent rapid re-invoke.
- **Enemy death mid-echo:** Long Echo's scheduled echo checks `enemy.alive` before dealing damage; no-op if the enemy is already dead.
- **Battle end:** RESO_FX, RESO_QUEUE cleared; all per-member counters reset; enemy fields reset.
- **CONFUSE on a single-pattern enemy:** shuffling a 1-element pattern is a no-op; harmless.

## Acceptance Criteria

- `apply_resonance_effect(rid, p)` dispatches all 7 active Resonances (Ring + 6 new); Ring behavior unchanged.
- Heavy Hand: enemy damage to party halved for 2 bars after invoke.
- Long Echo: the next 2 party ATKs each spawn a 50%-damage echo ~6 ticks later (visible as a second damage number + burst).
- Scatter: enemy attack timing becomes chaotic for 4 bars (pattern re-shuffled), returns to order after.
- Slow Wheel: party ATB fills faster (SPD+1) for 4 bars.
- Masked Voice: party ATK/MAG damage +25% for 1 bar.
- Threefold: while active (1 bar), each party action heals the mathwiz caster 5% maxHP.
- RESO_FX + RESO_QUEUE ticked each battle frame; both cleared on enter/exit_battle.
- `luac -p` passes. File growth < +8KB.
- No regression to Ring or to existing combat (damage_party, enemy_tick, ATB).

## What This Spec Does NOT Cover

- **Spring** (deferred).
- **Acquisition paths** for the 6 newly-wired Resonances (sacred item → shrine → attune). Only Ring has a real path. Effects are dormant until acquisition is built per-character later. This pass makes the effects real and testable; it does not make the other 6 obtainable in normal play.
- **Balance tuning** beyond the bible's stated numbers. Hardware playtest deferred to user.
- **Animation/SFX** — already shipped in the fluid-invocation pass.

## Notes for the user (review on return)

- "Masked Voice mode-bonus stacking" was interpreted as a flat +25% party damage for 1 bar. If you want it tied to the actual chord/consonance system (the combo bonus), that's a follow-up.
- Effects are wired but mostly un-obtainable until each Resonance gets an acquisition path (only Ring has one). I built the effect layer so it's ready; acquisition is the natural next Resonance pass.
- Hardware playtest (balance feel, echo timing, CONFUSE chaos level) deferred to you.
