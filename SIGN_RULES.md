# Sign rules (design rule for every level)

**Every sign must affect every vehicle, our car and all the other cars, as long as it is close enough
to that vehicle / placed correctly for it.** A sign never works "only on the player's car" or "only on
one particular NPC". If a car is within the sign's reach, the sign acts on it.

- Reach: there is **no global radius yet**. Each level has its own constant (kept as it is). When a level's
  scenario needs a different reach, ask the designer before changing it.
- "Close enough" is measured sideways from the car's path to the sign. A car reacts when it comes up to
  the sign along its own direction of travel (a car going up, down, left or right all behave the same).

## Status per level (not fully audited: tell me where it differs and I ask before changing it)

| Level | Status |
|---|---|
| Zip 1 level 3 (`scripts/Zip1/level_z1_3.gd`) | **Done for the stop sign**: reach `STOP_REACH = 130` px, works on our car, the car from below and the cars from the top. The timed traffic signal is still a placement *zone* (cars from the top only). |
| Zip 1 level 2 | The timed signal is a placement zone and only holds the cars from the top (our car ignores it). |
| Level 3 (old, `scripts/Level3`) | Stop sign / traffic signal rays work on our car and the NPC cars. |
| Levels 4 and 5 | Stop sign and traffic signal: our car uses reach 150 px, the other cars 100 px (`SIGN_REACH`, `NPC_SIGN_REACH`). Give way, no stopping, one way, U-turn and cattle signs only act on our car (or on one kind of car): these are the known gaps. |

## Stop signs and traffic signals belong to one road

A stop sign or traffic signal works on the **whole road** it stands next to (every lane, both directions),
and **only that road**. At a junction it snaps to the nearest road, so it never affects both. A sign that
is further than `Global.ROAD_ADJACENT` (130 px) from every road does nothing.

- Shared helpers in `scripts/global.gd`: `sign_road`, `car_on_sign_road`, `queue_at_signal`, `release_signal_road`.
  A level lists its roads as `Rect2`s (road including curbs) in a `ROADS` constant.
- Done in: Zip 1 level 2, Zip 1 level 3, Zip 2 level 6. **Not yet** in Level 1, Level 2, Level 3, Level 4,
  Level 5 (they still use the old per-lane rays / reach); these need redesigning per level.

### One direction only
A stop sign / traffic signal stops the traffic of **one direction** only, like in real life: the direction of
the first car that comes up to it (`stop_dir`, set in `Global.queue_at_signal` / `Global.sign_stops_heading`).
Cars coming from the opposite direction on the same road ignore it. Done in the same levels as above.

### Flush placement
Stop signs and traffic signals are dragged with `Global.drag_position(..., flush = true)`: after the grid snap
they slide towards the nearest road (up to two grid steps = 40 px) until their edge touches the road edge,
so they sit flush against the curb with no gap (all levels: stop.gd, traffic_signal.gd, timed_signal.gd).
Flush is measured against the VISIBLE road pixels (`Global.road_pixel`), so it also fits the rounded corners of the
junction: a sign within 40 px of a road always ends up touching an edge, never floating in the corner.

## Compulsory left / right turn signs (road-based)
A turn sign snaps flush to the nearest road (like the stop sign / traffic signal) and points the way the traffic
goes on the side of the road where it stands (traffic keeps left: above an east-west road -> points right, below it
-> left; left of a north-south road -> up, right of it -> down; one-way carriageways have a fixed direction).
It only affects the cars of THAT road driving THAT way (our car and the other cars alike): after a car has
completely crossed the sign (75 px) it turns left/right. The picture rotates by itself when the sign snaps.
- Helpers: `Global.sign_heading`, `Global.turn_sign_reached`, `Global.turn_sign_degrees`; a level provides
  `sign_roads()` (and `sign_road_dirs()` for one-way carriageways).
- Rotation + flush snapping: every level with turn signs (Zip 2 level 4 and 6, old Levels 2, 3, 4 and 5).
- Full effect (only the cars of that road and direction): Zip 2 level 4 and 6, old Level 2, old Level 4 (picker 8, the
  highway cars obey it too). **Not yet** in old Level 3 (picker 7) and old Level 5 (picker 9): the picture now points
  the right way, but what the signs DO is still decided by their old rays / scripts until they are redesigned.
