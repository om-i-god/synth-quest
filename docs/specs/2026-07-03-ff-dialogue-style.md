# Synth Quest — Final Fantasy Dialogue Style Guide

Goal: make the dialogue read like a golden-age Final Fantasy script
(FF9 warmth, FF6 ensemble theatricality, FF4 melodrama) while KEEPING
what already works — the terse, melancholy narration voice. Amplify,
don't flatten.

## The core moves

1. **Character verbal signatures.** Every recurring speaker has a
   recognizable speech pattern that survives out of context:
   - **Alder (bard)** — showman's deflection. Jokes at the wrong
     moment, then one sincere line that lands harder for it. Musical
     metaphors. "Well! That could have gone worse. Statistically."
   - **Miel (cleric/queen)** — royal restraint that cracks into
     warmth. Formal address that softens with trust. Never
     exclamatory until it matters, so when she does, it lands.
   - **Strom (warrior)** — clipped. Soldier's economy. Dark, dry
     humor in as few words as possible. "It is a walk." Never
     explains twice.
   - **Diegues (mage)** — over-precise, flustered when moved.
     Corrects himself mid-line. Quantifies feelings badly.
     "I am... seventy percent certain. Perhaps sixty."
   - **Sergei (engineer)** — rig/signal/patch metaphors, workshop
     confidence. Calls the party "the band."
   - **Paj (mathwiz)** — literal-minded, math imagery, accidentally
     profound. Delighted by patterns.
   - **Niko (drummer)** — laconic rhythm slang. Counts things.
     Coolest person in every room and doesn't know it.
   - **ECHO (wraith)** — fragmentary, echoic. Repeats others' words
     back with new weight. Short lines with ellipses that trail INTO
     meaning, not away from it.
2. **FF punctuation & interjections**, used sparingly and precisely:
   "...!", "?!", "Wh-what?!", a single "Hmph." for dismissals, "..."
   as a full reply (the FF silent beat). Never more than one per
   exchange.
3. **Party banter as texture.** Small cross-talk beats in scenes:
   one character reacts to another's line before the plot continues.
   FF scenes are conversations, not statements in sequence.
4. **NPCs get one vivid want.** Every town NPC's dialogue implies a
   small life: a rivalry, an obsession, a complaint about the
   weather, a wrong opinion held confidently. FF towns feel alive
   because NPCs are petty and particular.
5. **Melodrama at the pillars.** At the big beats (recruitments,
   deaths, endings) go bigger than feels safe: declarations, vows,
   names spoken aloud. FF earns its silences by daring its speeches.

## What to KEEP (do not flatten)

- The parenthetical narration voice: terse, concrete, melancholy.
  It is the game's camera. Never make narration jokey.
- The tag conventions: `[Name]` speakers, `(...)` narration,
  untagged = block npc. Never break the renderer's rules.
- Line length: under ~55 chars for narrator lines, ~70 for tagged
  speech (the packer splits longer; parentheticals must not split).
- Established facts (see story/bible.md + prior audits): Aram was
  Strom's second; Iolen is a woman; Miel is queen (old retainers may
  say "Princess"); grandmother, not mother; Reya; Velthe; the seven
  modes.

## Anti-goals

- No fourth-wall breaks, no memes, no modern slang.
- No renaming characters or changing plot facts.
- No line so long it wraps to a 4th line.
- Don't give every NPC an exclamation point. FF towns have exactly
  a few loud people; the rest are wry.
