# Synth Quest — Final Fantasy Area Style Guide

Goal: every map should read like a Final Fantasy place — composed,
layered, and lived-in — within the 128x64 4-gray OLED and 8x8 tiles.

## What makes an FF map read FF

1. **Composition, not scatter.** Important buildings get framing:
   a path leading to the door, symmetry, a landmark centerpiece
   (fountain plaza, bandstand, gate). Roads have edges — hedges,
   fences, flowerbeds — that guide the eye and the feet.
2. **Layered density.** Three depth layers everywhere: ground
   texture (paths, flowers, sand ripples), mid objects (crates,
   barrels, benches, wells, signs, lamps), and landmarks (towers,
   arches, statues). An empty 6x6 grass field is a bug.
3. **Water is a feature.** Rivers get bridges; coasts get piers and
   moored boats; fountains get plazas. FF loves a bridge moment.
4. **District texture.** Each town quarter feels different: market
   (stalls, crates), residential (flowers, fences), civic (paved
   plaza, lamps). Transitions read on the map.
5. **Light.** Lamps near doors and plazas; the night cue plays off
   them. Interiors: rugs under tables, paintings on walls.

## The decorative tile kit (ids 100+; all impassable unless noted)

- 100 fence_h / 101 fence_v — low picket fence segments
- 102 flowerbed — 2-3 tiny blossoms, walkable? NO (bed), but
  103 flowers_walk — sparse blossoms ON grass, walkable overlay
- 104 bench — side bench, sittable-looking
- 105 crate — market crate; 106 crate_stack — two crates
- 107 well — village well with roof beam
- 108 street_lamp — taller than tile-24 lantern; lit at night
  (brighter glow when sq_is_night)
- 109 hedge — clipped hedge block (softer than tree tile 1)
- 110 bridge_h — plank bridge over water, WALKABLE
- 111 statue — small chord-sigil statue for plazas
- 112 signpost_deco — non-routing wooden sign (distinct from 65)

Rules: verify each new id is unused; add TILE_DRAW with the file's
idiom; only 103/110 join is_walkable; animated tiles (lamp flicker)
join the tick dispatch list; every map edit re-verifies row widths,
NPC clearance, route reachability (BFS mindset), and trigger/chest
coordinates. Never place decor on: entrances/exits, scene coords,
NPC tiles, ambient trigger tiles, chest/campfire tiles.

## Per-map treatment priorities

1. MAINLAND village core — plaza around the fountain (paving + lamps
   + flowerbeds + bench), fenced yards for the three houses, market
   clutter at the shop/inn storefront row, well near Tova's, bridge
   over the river at the pier road.
2. EASTERN town — caravan market texture: crates, stalls' spillover,
   rope-and-post fencing; dune ripples on open sand.
3. NORTHERN town — hearth-village: lamps, wood stacks (crate kit),
   hedges won't fit the fiction — use stone cairns (reuse 111).
4. SUNWARD — harbor: crates+barrels on the dock row, lamps on the
   promenade, flower boxes on cottages.
5. PHRYGIAN — already strong (stalls/alcoves); add lamps + statue
   in the prayer court; keep its doorless language.
6. Overworld routes — tree-lines shaping the roads, occasional
   flowers_walk meadows, a statue waypoint at region borders.
7. Lirael — DO NOT beautify; it is a ruin. Only composition fixes.
8. Interiors — rugs under tables, paintings; already decent.

Every wave ships through the loop: implement → verify (bounds,
reachability, collisions) → commit → deploy.
