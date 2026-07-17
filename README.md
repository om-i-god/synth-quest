# synth quest

A JRPG for monome norns where your party *is* a polysynth. Four
musicians — warrior bass, cleric pad, mage lead, bard counter — fight,
travel, and jam; every battle action is a note, every zone has a key,
and the soundtrack is played live by the same voices you command.
Content-complete: prologue, seven shards, the World of Silence, an
ending, NEW GAME+, and a superboss.

## requirements

- monome norns (stock hardware is enough — the whole game is playable
  from the three keys and two encoders)
- optional but recommended: a USB gamepad (8BitDo SN30 Pro, Xbox-profile
  pads, and most HID controllers work) — adds live filter/FX sticks,
  rhythm-crit timing, and one-press Resonances

## install

```
;install https://github.com/om-i-god/synth-quest
```

or copy this folder to `~/dust/code/synth-quest` on the norns.

**Then do SYSTEM > RESTART.** The game ships its own SuperCollider
engine (`lib/Engine_SynthQuest.sc`); norns only picks up new engines
after a restart. If you see `LOAD FAIL` or missing voices, this step
was skipped.

## controls — norns (no controller needed)

Note: K1 is reserved by norns itself (a tap switches to the system
menu), so the game never requires it — everything lives on K2/K3 and
the encoders.

- **title** — K2 toggle New Game / Continue · K3 confirm
- **intro cutscene** — K2/K3 advance (hold K1 to skip)
- **overworld** — E2 walk east/west · E3 walk north/south · K3 talk /
  interact · K2 menu (Jam Mode + Jam Pad live in the menu)
- **dialogue** — K2 or K3 advance
- **battle** — E2 cycle the queued action (plus RESO when that
  character has an attuned Resonance) · K2/K3 previous/next party
  member · K3 advance the results screen · K2 exits Jam Pad practice
  bouts
- **menu** — E2 scroll · K3 select · K2 back
- **items** — E2 cursor · E3 cycle tabs · K3 use · K2 back
- **equip** — E3 cycle character · E2 choose instrument · K3 equip ·
  K2 back
- **party** — E2 focus a standby member · E3 change the active slot ·
  K3 swap in · K2 back
- **shop** — E2 pick · K3 buy · K2 leave
- **quests / map / bestiary / shards / achievements** — E2 scroll ·
  K3 page-flip / detail view · K2 back
- **jam mode** — E2 scale mode · E3 root note · K2 exit (BPM and
  voice/FX-latch controls live on the gamepad)
- **game over** — K3 return to title
- **credits** — K3 begin NEW GAME+ · K2 back to title

## controls — gamepad

- **anywhere** — SELECT toggles jam mode (even mid-battle); press
  again to return
- **overworld** — dpad walk · A talk / interact · X menu · L1/R1
  switch active member
- **battle** — A/B/X/Y queue the class actions · dpad up/down cycles
  the queued action (incl. RESO) · dpad left/right or L1/R1 switch
  member · R2 queues your Resonance · pressing A exactly on the beat
  charges a guaranteed crit
- **sticks (overworld, battle, dialogue, jam)** — right stick: filter
  cutoff (Y) and resonance (X) on the active voice · left stick:
  reverb (up) and delay (right) · click L3/R3 to latch that stick's
  FX across all voices
- **jam mode** — dpad up/down scale · dpad left/right root · hold L2 +
  dpad left/right sets tempo · L1/R1 voice · A latch/release FX ·
  X cycle scale · B or START exit
- **menus** — dpad navigate · A select · B/START back · L1/R1
  tabs/pages/character

## params (norns PARAMS menu)

Battle speed, per-voice octave/filter/delay/reverb, music & combat
reverb mix, MIDI in/out (notes route to a chosen voice; CCs map to
cutoff/res/delay/reverb), a custom-scale picker for jam mode, and the
video stream toggle (below).

## optional: big-screen viewer

The game can mirror the OLED over TCP to a window on another machine
(`viewer/synth-quest-viewer.py`, port 7777). See `viewer/README.md`
for setup and the viewer.conf gotcha. Leave the **video stream** param
OFF unless a viewer is actually running — while it's on and
unreachable, the script pays a small reconnect hitch every 5 seconds.

## repo notes

- `DEVLOG.md` — the full development log; the de-facto changelog.
- `story/bible.md` — the current story bible (`bible.v1-aural.md` and
  `bible.v2-harmonia.md` are earlier drafts, kept for history).
- `docs/plans`, `docs/specs` — internal design docs.
- `lib/Engine_SynthQuest.sc` — the SuperCollider engine.
  `lib/HDMIMirror.lua` — the OLED-over-TCP streamer.

## license

MIT — see `LICENSE`.
