# The Ring Combat Effect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Resonances RESO branch stub damage with the bible-accurate buff-then-attack behavior. R2 arms Miel (`p.ring_armed = true`); her next ATK fires the empowered hit (1.30× damage + clangor sound + larger burst + screen shake) and consumes the flag. HUD bell glyph indicates armed state.

**Architecture:** Single-file change to `synth-quest.lua`. Adds one per-player boolean field (`p.ring_armed`), modifies five existing branches (RESO dispatch, ATK dispatch, R2 input handler, damage-party death handler, `reset_party_for_battle`), adds two new code blocks (HUD bell glyph + battle-entry reset sites). No engine, save-format-incompatible, or state-machine changes.

**Tech Stack:** norns (Lua), `screen.*` mono primitives at 128×64, `sq_trig` for audio, `ANIM.burst` + `ANIM.shake` for FX. Manual playtest on device — no unit-test framework.

**Spec:** `docs/specs/2026-05-17-ring-effect-design.md`

---

## File Structure

| Change | Location | Note |
|---|---|---|
| Replace RESO stub damage with arm-flag | `synth-quest.lua:15867-15894` (RESO branch in `apply_player_action`) | Keeps signature sound + banner; gut the damage block |
| Add Ring multiplier + ring_fx to ATK branch | `synth-quest.lua:15625-15641` (ATK branch in `apply_player_action`) | Insert after `p.buffed` consumption, before `damage_enemy` |
| Add R2 "already armed" refuse-branch | `synth-quest.lua:17578-17613` (`triggerright` branch in `gamepad.analog`) | Insert before existing MP check |
| Clear `p.ring_armed` on KO | `synth-quest.lua:15474` (`damage_party`) | Adjacent to `p.alive = false` |
| Clear `p.ring_armed` in `reset_party_for_battle` | `synth-quest.lua:13448` | Adjacent to `p.buffed = false` |
| Clear `p.ring_armed` at 4 other battle-entry sites | `synth-quest.lua:6526, 6569, 6611, 6748` | Each has `p.buffed = false` in the per-party loop |
| Add HUD bell glyph in per-character column | `synth-quest.lua:24463` (just after rhythm-charged indicator) | Inside the existing `for i, p in ipairs(party)` loop |

No new files. No tests (project has none).

---

### Task 1: Pre-flight backup

**Files:**
- Read: `~/dev/synth-quest/synth-quest.lua`
- Create: `~/dev/synth-quest/backups/synth-quest-pre-ring-effect.lua`

- [ ] **Step 1: Snapshot the current script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-pre-ring-effect.lua`
Expected: no output, file exists at the new path.

- [ ] **Step 2: Confirm snapshot**

Run: `ls -la ~/dev/synth-quest/backups/synth-quest-pre-ring-effect.lua`
Expected: file exists, byte size matches `~/dev/synth-quest/synth-quest.lua`.

---

### Task 2: Replace RESO stub damage with `p.ring_armed = true`

**Files:**
- Modify: `synth-quest.lua:15867-15894` — RESO branch in `apply_player_action`.

The current RESO branch fires the signature sound, flashes a banner, and stubs the effect with a normal-ATK damage hit. The new behavior keeps the signature sound + banner (so the player knows the call landed) but replaces the damage stub with arming the buff. The next ATK by this character will fire the empowered hit.

- [ ] **Step 1: Replace the stub block**

Use the Edit tool. `old_string`:

```lua
  elseif p.queued == "RESO" then
    -- Resonance call. MP was deducted at queue-time (R2 handler), matching
    -- the existing HEAL/MAG pattern. Fire the signature sound, flash a
    -- banner, and stub the effect.
    local rid = p.queued_resonance
    local r   = rid and RESONANCES[rid]
    if r then
      -- Feedback: sound + banner so the player can tell the call landed.
      local sig = RESONANCE_SITES[rid] and RESONANCE_SITES[rid].shrine and RESONANCE_SITES[rid].shrine.signature
      if sig and sig.sound then
        sq_trig(sig.sound.class, midi_to_freq(sig.sound.note),
                sig.sound.vel or 0.7,
                sig.sound.attack or 0.05,
                sig.sound.release or 4.0,
                math.min(1, (sig.sound.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
      end
      CONTENT.banner_text  = "* " .. r.name .. " *"
      CONTENT.banner_ticks = 36
      -- TODO (separate spec): apply_resonance_effect(rid, p) per r.effect.kind.
      -- For now: deal a normal-ATK as a placeholder so the action consumes
      -- a turn and feels like SOMETHING happened.
      if enemy and enemy.alive then
        local dmg = INST.atk(p)
        damage_enemy(dmg, false)
      end
      p.last_fire = tick
      p.last_action = "RESO"
    end
  end
```

`new_string`:

```lua
  elseif p.queued == "RESO" then
    -- Resonance call. MP was deducted at queue-time (R2 handler), matching
    -- the existing HEAL/MAG pattern. Fire the signature sound, flash a
    -- banner, then ARM the per-Resonance buff. The actual effect lands
    -- on the next compatible action (e.g. Ring is consumed by the next
    -- ATK by this character). See docs/specs/2026-05-17-ring-effect-design.md.
    local rid = p.queued_resonance
    local r   = rid and RESONANCES[rid]
    if r then
      -- Feedback: sound + banner so the player can tell the call landed.
      local sig = RESONANCE_SITES[rid] and RESONANCE_SITES[rid].shrine and RESONANCE_SITES[rid].shrine.signature
      if sig and sig.sound then
        sq_trig(sig.sound.class, midi_to_freq(sig.sound.note),
                sig.sound.vel or 0.7,
                sig.sound.attack or 0.05,
                sig.sound.release or 4.0,
                math.min(1, (sig.sound.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
      end
      CONTENT.banner_text  = "* " .. r.name .. " *"
      CONTENT.banner_ticks = 36
      -- Arm the per-Resonance buff. Other Resonances dispatch on rid
      -- here as they are added in later passes.
      if rid == "ring" then
        p.ring_armed = true
      end
      p.queued_resonance = nil
      p.last_fire = tick
      p.last_action = "RESO"
    end
  end
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 3: Add Ring multiplier + FX to ATK branch

**Files:**
- Modify: `synth-quest.lua:15625-15641` — ATK branch in `apply_player_action`.

The Ring multiplier slots in after the existing `crit` (×2) and `p.buffed` (×1.5) multipliers, before `damage_enemy`. The FX block runs after `damage_enemy` so the clangor + burst + shake feel like a reaction to the hit landing.

- [ ] **Step 1: Replace the ATK branch's inner block**

Use the Edit tool. `old_string`:

```lua
  if p.queued == "ATK" then
    -- Guard with `enemy and` — a previous party member's hit may have
    -- already killed the enemy this tick (e.g. Strom-arc clears the
    -- global `enemy` synchronously on kill).
    if enemy and enemy.alive then
      local dmg = INST.atk(p)
      -- Rhythm-crit: guaranteed crit if charged via on-beat A press.
      local rhythm_was_set = p.rhythm_charged
      local crit = p.rhythm_charged or (math.random() < ANIM.crit)
      p.rhythm_charged = false   -- consumed regardless of outcome
      if rhythm_was_set and unlock_achievement then
        unlock_achievement("first_rhythm_crit", "On the Beat")
      end
      if crit then dmg = dmg * 2 end
      if p.buffed then dmg = math.floor(dmg * 1.5); p.buffed = false end
      damage_enemy(dmg, crit)
    end
```

`new_string`:

```lua
  if p.queued == "ATK" then
    -- Guard with `enemy and` — a previous party member's hit may have
    -- already killed the enemy this tick (e.g. Strom-arc clears the
    -- global `enemy` synchronously on kill).
    if enemy and enemy.alive then
      local dmg = INST.atk(p)
      -- Rhythm-crit: guaranteed crit if charged via on-beat A press.
      local rhythm_was_set = p.rhythm_charged
      local crit = p.rhythm_charged or (math.random() < ANIM.crit)
      p.rhythm_charged = false   -- consumed regardless of outcome
      if rhythm_was_set and unlock_achievement then
        unlock_achievement("first_rhythm_crit", "On the Beat")
      end
      if crit then dmg = dmg * 2 end
      if p.buffed then dmg = math.floor(dmg * 1.5); p.buffed = false end
      -- The Ring (Miel's Resonance): empowered next-attack. 1.30x damage
      -- plus a clangor sound + larger burst + screen shake. Stacks
      -- multiplicatively with crit/buffed (the bell amplifies what the
      -- attack already is). Consumed regardless of whether the hit lands.
      local ring_fx = false
      if p.ring_armed then
        dmg = math.floor(dmg * 1.30)
        p.ring_armed = false
        ring_fx = true
      end
      damage_enemy(dmg, crit)
      if ring_fx then
        -- Clangor: root bell + a fifth above (same cleric voice as
        -- the signature sound; the fifth is the "harmonics no one
        -- could place" beat from the bible).
        local sig = RESONANCE_SITES.ring and RESONANCE_SITES.ring.shrine
                    and RESONANCE_SITES.ring.shrine.signature
        if sig and sig.sound then
          local s = sig.sound
          sq_trig(s.class, midi_to_freq(s.note),
                  s.vel or 0.7, s.attack or 0.05, s.release or 4.0,
                  math.min(1, (s.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
          sq_trig(s.class, midi_to_freq(s.note + 7),
                  0.55, 0.005, 2.0,
                  math.min(1, (s.wet or 1.0) * (CONTENT.combat_reverb_mix or 1.0)))
        end
        ANIM.burst(96, 32, 10, 15)
        ANIM.shake(2, 10)
      end
    end
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 4: Add "already armed" refuse-branch to R2 handler

**Files:**
- Modify: `synth-quest.lua:17593-17606` — `triggerright` branch in `gamepad.analog`.

Pressing R2 while already armed should refuse: no MP deduction, brief banner. Insert this check between the existing "no attuned Resonance" and "not enough MP" branches.

- [ ] **Step 1: Replace the rid-check / MP-check block**

Use the Edit tool. `old_string`:

```lua
          if not rid then
            CONTENT.banner_text  = "* no resonance attuned *"
            CONTENT.banner_ticks = 36
          elseif p.mp < RESONANCES[rid].mp_cost then
            CONTENT.banner_text  = "* not enough MP *"
            CONTENT.banner_ticks = 36
          else
            p.queued = "RESO"
            p.queued_resonance = rid
            p.mp = p.mp - RESONANCES[rid].mp_cost
            p.prev_queued = nil
            p.jamming = false
          end
```

`new_string`:

```lua
          if not rid then
            CONTENT.banner_text  = "* no resonance attuned *"
            CONTENT.banner_ticks = 36
          elseif p.ring_armed then
            -- Refuse re-arm: the buff is already on the player. Avoids
            -- accidental double-MP-burn from R2 spam.
            CONTENT.banner_text  = "* already armed *"
            CONTENT.banner_ticks = 36
          elseif p.mp < RESONANCES[rid].mp_cost then
            CONTENT.banner_text  = "* not enough MP *"
            CONTENT.banner_ticks = 36
          else
            p.queued = "RESO"
            p.queued_resonance = rid
            p.mp = p.mp - RESONANCES[rid].mp_cost
            p.prev_queued = nil
            p.jamming = false
          end
```

(Note: the `p.ring_armed` check assumes the buff was set by Ring. For now only Ring uses this flag; when other Resonances arm their own flags the check will need to generalize. Out of scope here.)

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 5: Clear `p.ring_armed` on KO

**Files:**
- Modify: `synth-quest.lua:15474` — inside `damage_party`, at the point where death is detected.

The spec's acceptance #6 requires the buff to clear when Miel dies while armed. The existing codebase never clears `p.buffed` on death (the spec's "find every site where p.buffed = false is set on death" yields zero results — it only clears at battle-entry resets and on ATK consumption). So we add an explicit clear adjacent to `p.alive = false` on the death tick.

- [ ] **Step 1: Add the KO clear**

Use the Edit tool. `old_string`:

```lua
  p.hp = math.max(0, p.hp - amount)
  p.last_hit = tick
  if p.hp == 0 then p.alive = false end
```

`new_string`:

```lua
  p.hp = math.max(0, p.hp - amount)
  p.last_hit = tick
  if p.hp == 0 then
    p.alive = false
    -- Clear armed Resonance buffs on KO. (p.buffed intentionally
    -- persists per existing behavior, but Ring's spec says the
    -- bell goes silent when the bell-ringer falls.)
    p.ring_armed = false
  end
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 6: Clear `p.ring_armed` at battle-entry reset sites

**Files:**
- Modify: `synth-quest.lua:13448` — `reset_party_for_battle()`.
- Modify: `synth-quest.lua:6526, 6569, 6611, 6748` — four per-party-loop reset sites at various enter-battle paths.

Each of these sites already resets `p.buffed = false`. Add `p.ring_armed = false` alongside each, so the flag clears on every battle entry regardless of which entry path fires.

- [ ] **Step 1: Update `reset_party_for_battle()`**

Use the Edit tool. `old_string`:

```lua
local function reset_party_for_battle()
  for _, p in ipairs(party) do
    p.atb = 0
    p.shield = false
    p.buffed = false
    p.blocking = false
    p.reflect = false
    p.reflect_ticks = 0
    p.limit_used = false   -- limit-break refreshed each battle
    p.last_fire = -99
    p.last_hit = -99
```

`new_string`:

```lua
local function reset_party_for_battle()
  for _, p in ipairs(party) do
    p.atb = 0
    p.shield = false
    p.buffed = false
    p.ring_armed = false   -- Resonance arm-flag is per-battle (matches p.buffed)
    p.blocking = false
    p.reflect = false
    p.reflect_ticks = 0
    p.limit_used = false   -- limit-break refreshed each battle
    p.last_fire = -99
    p.last_hit = -99
```

- [ ] **Step 2: Re-grep the remaining four sites**

Run: `grep -n 'p.buffed = false' ~/dev/synth-quest/synth-quest.lua`
Expected: 5 lines reported. Line 13448 is the one just edited. The other four are:
- ~6526 (and likely a `p.atb = 0; p.shield = false; p.buffed = false; p.blocking = false; ...` single-line)
- ~6569 (similar)
- ~6611 (similar)
- ~6748 (similar)

For each of these, the line is a single-line per-party loop that clears multiple flags. We need to extend each to also clear `p.ring_armed`.

- [ ] **Step 3: Update the line at the first remaining site (~6526)**

Read the exact line first:

```bash
sed -n '6525,6527p' ~/dev/synth-quest/synth-quest.lua
```

Expected: a line matching `    p.atb = 0; p.shield = false; p.buffed = false; p.blocking = false; p.reflect = false; p.reflect_ticks = 0`.

Use the Edit tool with that exact line as `old_string`, replacing `p.buffed = false;` with `p.buffed = false; p.ring_armed = false;`:

`old_string` (the exact line from the file, including leading whitespace):

```
    p.atb = 0; p.shield = false; p.buffed = false; p.blocking = false; p.reflect = false; p.reflect_ticks = 0
```

`new_string`:

```
    p.atb = 0; p.shield = false; p.buffed = false; p.ring_armed = false; p.blocking = false; p.reflect = false; p.reflect_ticks = 0
```

If this `old_string` is ambiguous (matches 4 lines), the Edit tool will fail. In that case, set `replace_all = true` — all four sites are the same line and need the same change.

- [ ] **Step 4: Update the line at the fourth remaining site (~6748)**

This one is slightly different (two-line format):

Read first:

```bash
sed -n '6747,6750p' ~/dev/synth-quest/synth-quest.lua
```

Expected: a two-line block like:
```
    p.atb = 0; p.shield = false; p.buffed = false
    p.blocking = false; p.reflect = false; p.reflect_ticks = 0
```

Use the Edit tool. `old_string`:

```
    p.atb = 0; p.shield = false; p.buffed = false
    p.blocking = false; p.reflect = false; p.reflect_ticks = 0
```

`new_string`:

```
    p.atb = 0; p.shield = false; p.buffed = false; p.ring_armed = false
    p.blocking = false; p.reflect = false; p.reflect_ticks = 0
```

- [ ] **Step 5: Verify all 5 sites now clear `p.ring_armed`**

Run: `grep -n 'p.ring_armed = false' ~/dev/synth-quest/synth-quest.lua`
Expected: 6 matches — the 5 reset sites (battle-entry + `reset_party_for_battle`) plus 1 from the ATK branch consumption (Task 3) plus 1 from the KO clear (Task 5). Total 7 if all clears are inline; if Task 5's clear is multi-line, count may differ slightly. The key check: at least 5 distinct functions/locations have a `p.ring_armed = false` line.

Also: `grep -n 'p.buffed = false' ~/dev/synth-quest/synth-quest.lua | wc -l` — should still return 5 (the buffed sites we anchored on aren't deleted, just extended).

- [ ] **Step 6: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 7: Add HUD bell glyph indicator

**Files:**
- Modify: `synth-quest.lua:24463` — inside the per-character HUD column loop, immediately after the rhythm-charged indicator block.

The bell glyph is a 5×5 pixel cluster drawn in the top-right of Miel's HUD column when `p.ring_armed` is true. Pulses slower than the `♪` rhythm-charged indicator so the two read as distinct when both are armed.

- [ ] **Step 1: Insert the bell-glyph block**

Use the Edit tool. `old_string` (the closing `end` of the rhythm-charged block followed by the next comment):

```lua
    if p.rhythm_charged then
      local age = tick - (p.rhythm_charged_t or tick)
      local lev = math.max(8, 15 - math.floor(age * 0.5))
      screen.level(lev)
      screen.pixel(cx + 27, 49); screen.pixel(cx + 27, 50)
      screen.pixel(cx + 28, 49); screen.pixel(cx + 28, 51)
      screen.pixel(cx + 29, 50); screen.fill()
    end
    -- character sprite (left of column at row 49) — battle animations land here.
```

`new_string`:

```lua
    if p.rhythm_charged then
      local age = tick - (p.rhythm_charged_t or tick)
      local lev = math.max(8, 15 - math.floor(age * 0.5))
      screen.level(lev)
      screen.pixel(cx + 27, 49); screen.pixel(cx + 27, 50)
      screen.pixel(cx + 28, 49); screen.pixel(cx + 28, 51)
      screen.pixel(cx + 29, 50); screen.fill()
    end
    -- The Ring armed indicator (Miel-specific). Bell silhouette in
    -- the top-right of the HUD column, slower pulse than the rhythm
    -- glyph so the two read as distinct when both are armed at once.
    if p.ring_armed and p.alive then
      local bx, by = cx + 25, 49
      local lev = ((tick % 24) < 12) and 13 or 15
      screen.level(lev)
      -- row 0 (bell crown): 3 wide, centered
      screen.pixel(bx + 1, by);     screen.pixel(bx + 2, by);     screen.pixel(bx + 3, by)
      -- row 1-2 (body): full 5 wide
      for c = 0, 4 do
        screen.pixel(bx + c, by + 1); screen.pixel(bx + c, by + 2)
      end
      -- row 3 (mouth narrows): 3 wide centered
      screen.pixel(bx + 1, by + 3); screen.pixel(bx + 2, by + 3); screen.pixel(bx + 3, by + 3)
      -- row 4 (clapper): single center pixel
      screen.pixel(bx + 2, by + 4)
      screen.fill()
    end
    -- character sprite (left of column at row 49) — battle animations land here.
```

- [ ] **Step 2: Verify file still parses**

Run: `lua5.4 -e 'local f, err = loadfile("/Users/omneo/dev/synth-quest/synth-quest.lua"); if not f then print(err) else print("OK") end' 2>&1 | head -5`
Expected: `OK`.

---

### Task 8: Deploy + on-device playthrough verification

**Files:** none modified locally.

**Pre-req:** norns IP — at home, white norns recently seen at `192.168.1.133`. Ping `norns.local` first; fall back to `192.168.1.133` if mDNS resolves there.

- [ ] **Step 1: Confirm current norns IP**

Run: `ping -c 2 -W 2000 norns.local 2>&1 | tail -3`
Expected: 0% packet loss + an IPv4 address in the reply.

If `norns.local` doesn't resolve: ask the user for the current IP. The norns IP is location-dependent + can drift via DHCP renewal.

- [ ] **Step 2: rsync to the norns**

Run (substituting the resolved IP):
```bash
rsync -avz -e "ssh -i ~/.ssh/norns" ~/dev/synth-quest/synth-quest.lua we@<NORNS_IP>:/home/we/dust/code/synth-quest/synth-quest.lua
```
Expected: file list with `synth-quest.lua`, no errors. (No SC engine changes, so no SYSTEM > RESTART needed.)

- [ ] **Step 3: Tell the user to reload + play**

Tell the user: "Reload Synth Quest on the norns (SELECT > synth-quest > load). Load a save that already has The Ring attuned (or start a new game and walk Miel through the bell-and-shrine path). Then enter a battle:

1. With Miel as the active character and ≥ 6 MP, press R2. Banner '* The Ring *', signature bell, 6 MP deducted, bell glyph appears in Miel's HUD column. **No damage to the enemy yet.**
2. Press R2 again immediately. Banner '* already armed *', no MP deducted, no second arming.
3. Press A (ATK) on Miel. Enemy takes ~1.3× her normal ATK damage, two bell tones layer (root + fifth), screen shakes, larger particle burst. Bell glyph disappears.
4. Press R2 again to re-arm, then press X (HEAL) instead. HEAL fires normally; bell glyph stays (HEAL didn't consume the buff). Then press A — the empowered hit fires.
5. (Stretch) Press A in combat enough times that Miel gets KO'd while armed. After death the bell glyph should disappear; revive (Alder's PLAY or another heal) should NOT bring it back."

Wait for the user's playthrough.

---

### Task 9: Manual playthrough verification — acceptance criteria

This is the verification step. Walk through the spec's 10 acceptance criteria with the user.

- [ ] **AC1: R2 arms without dealing damage**

Confirm: R2 with attuned + ≥ 6 MP fires the signature bell, banner, 6 MP deducted, bell glyph appears, NO damage to enemy.

- [ ] **AC2: Next ATK fires empowered hit + consumes buff**

Confirm: Next ATK deals roughly `INST.atk(Miel) × 1.30` damage (compare to a baseline ATK without arming). Two bell tones layer (root + fifth above). Screen shakes. Larger burst at enemy. Bell glyph disappears after. (To verify the 1.30 multiplier roughly: note baseline ATK damage in one fight, then a Ring-armed ATK in the next.)

- [ ] **AC3: R2 while already armed = refused**

Confirm: pressing R2 again with bell glyph showing shows "* already armed *" banner, no MP deducted, no second arming.

- [ ] **AC4: R2 with < 6 MP = existing behavior**

Confirm: drain MP below 6 (cast HEAL repeatedly), press R2. "* not enough MP *" banner, no queue, no flag.

- [ ] **AC5: R2 on non-cleric or no attuned Resonance = existing behavior**

Confirm: switch to Alder/Strom/Diegues (any non-cleric), press R2. "* no resonance attuned *" banner.

- [ ] **AC6: Miel dies while armed → flag cleared**

Confirm: arm Ring, then let Miel take fatal damage. After KO, the bell glyph should NOT be visible (she's dead, so no HUD glyph). Revive Miel (HEAL or PLAY); the bell glyph should NOT come back — she has to re-arm.

- [ ] **AC7: Battle ends → flag clears at next entry**

Confirm: arm Ring, win the battle. Enter the next battle. Bell glyph should NOT be present at battle start.

- [ ] **AC8: Save mid-armed → flag is gone on reload**

Confirm: arm Ring during battle, exit battle, save game, quit, reload. Enter a new battle — bell glyph should NOT be present.

- [ ] **AC9: Switching active character preserves the flag on Miel**

Confirm: arm Ring as Miel, press L1/R1 to switch active to Alder. Bell glyph should STILL show on Miel's column (not Alder's). Switch back; the buff is still there.

- [ ] **AC10: Stacking math**

Confirm (approximately): rhythm-crit + buffed + Ring on the same Miel ATK deals roughly `floor(INST.atk(Miel) × 2 × 1.5 × 1.30)` = `floor(baseline × 3.90)`. Hard to measure precisely in-play; eyeball: does the resulting damage feel like ~4× a baseline ATK? If yes, ship.

If any AC fails, capture the specific failure and return to the relevant earlier task. ACs 1, 2, 3, 6, 7 are the critical path; 8 and 10 are nice-to-have verifications.

---

### Task 10: Snapshot + DEVLOG + commit

**Files:**
- Create: `~/dev/synth-quest/backups/synth-quest-ring-effect.lua`
- Modify: `~/dev/synth-quest/DEVLOG.md`

- [ ] **Step 1: Snapshot the post-pass script**

Run: `cp ~/dev/synth-quest/synth-quest.lua ~/dev/synth-quest/backups/synth-quest-ring-effect.lua`
Expected: no output, file exists.

- [ ] **Step 2: Append a DEVLOG entry**

Read `~/dev/synth-quest/DEVLOG.md`. Append a new entry matching the existing format:

```
## 2026-05-18 — The Ring combat effect

Replaced the Resonances RESO stub with the bible-accurate buff
model per docs/specs/2026-05-17-ring-effect-design.md. Pressing
R2 arms Miel (p.ring_armed); her next ATK fires the empowered
hit (1.30x damage, root bell + fifth above, larger burst, screen
shake) and consumes the flag. Stacks multiplicatively with crit
and buffed (max ~3.90x with all three aligned).

HUD bell glyph on Miel's column while armed (5x5 pixels, top
right, slower pulse than the rhythm-crit '♪'). KO clears the
buff. Reset on every battle entry (5 sites). R2 refuses to
re-arm if already armed (avoids double-MP burn).

Effect dispatch is still inlined into the ATK branch — extract
when the second Resonance effect lands.
```

- [ ] **Step 3: Stage + commit**

Run:
```bash
cd ~/dev/synth-quest && git add synth-quest.lua DEVLOG.md docs/plans/2026-05-18-ring-effect.md && git status
```
Expected: only those 3 files staged. If any other file ended up staged (`luac.out`, `viewer/*`, etc.), unstage before committing — those are pre-existing unrelated work.

Run:
```bash
cd ~/dev/synth-quest && git commit -m "$(cat <<'EOF'
ring: wire the combat effect (buff-then-attack)

Replaces the RESO stub damage with the bible-accurate buff
model. R2 arms p.ring_armed on Miel; her next ATK fires the
empowered hit (1.30x damage + root bell + fifth above + screen
shake + larger burst) and consumes the flag.

- RESO branch no longer deals damage; sets p.ring_armed = true
- ATK branch reads + consumes the flag with the multiplier
  inserted after crit (x2) and buffed (x1.5); stacks
  multiplicatively (max ~3.90x with all three aligned)
- R2 refuses to re-arm if already armed
- KO clears p.ring_armed (bell-ringer falls -> bell silent)
- reset_party_for_battle + 4 enter-battle sites clear the flag
- HUD bell glyph (5x5) on the armed character's column,
  slower pulse than rhythm-crit '♪'
- Spec: docs/specs/2026-05-17-ring-effect-design.md
- Plan: docs/plans/2026-05-18-ring-effect.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: commit succeeds.

---

## Self-review notes

**Spec coverage:**

- Architecture (5 touchpoints) — Tasks 2 (RESO), 3 (ATK), 4 (R2 refuse), 6 (reset sites), 7 (HUD)
- Data model (`p.ring_armed`) — Tasks 2, 3, 6
- RESO branch replacement — Task 2
- ATK branch hook — Task 3
- R2 refuse — Task 4
- Reset sites — Task 6 (5 sites: reset_party_for_battle + 4 enter-battle)
- KO clear — Task 5 (deviation from spec noted: spec said "find p.buffed = false on death", those sites don't exist; added explicit clear at damage_party)
- HUD indicator — Task 7
- All 10 acceptance criteria — Task 9

**Placeholder scan:** No "TBD", "implement later", "similar to Task N". Every step has actual code or a concrete grep/sed command. The Task 4 note about `p.ring_armed` generalizing for other Resonances is explicit out-of-scope, not a placeholder.

**Type/name consistency:**
- `p.ring_armed` boolean — consistent across Tasks 2 (write), 3 (read+clear), 4 (read), 5 (clear), 6 (clear), 7 (read).
- `p.queued_resonance` cleared in Task 2 (RESO branch). Read elsewhere — fine.
- `RESONANCES`, `RESONANCE_SITES` globals from the prior pass — referenced consistently in Tasks 2, 3.
- `CONTENT.banner_text`, `CONTENT.banner_ticks` — consistent banner pattern.
- `ANIM.burst`, `ANIM.shake`, `sq_trig`, `midi_to_freq` — existing primitives, used as in spec.

**TDD note:** Same as the prior plans — no test framework available for norns visual scripts. Manual playthrough in Task 9 is the verification, with per-task `lua5.4 loadfile` smoke checks catching syntax errors before deploy.

**Deviation from spec:** Task 5 (KO clear) adds an explicit `p.ring_armed = false` at `damage_party` line 15474, rather than mirroring `p.buffed = false` death-sites (which don't exist). The spec's intent (acceptance #6) is preserved; the implementation path differs from the spec's literal instruction. Worth noting in commit/DEVLOG.
