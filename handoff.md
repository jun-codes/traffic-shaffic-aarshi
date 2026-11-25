# Handoff: "Traffic Shaffic" (Godot 4.7 2D puzzle game)

Everything a new Claude needs to continue this project. Read it top to bottom once, then use it as a reference.
Project folder: `c:\Users\Arjun\Desktop\traffic-shaffic-copy` (Windows, Git Bash and PowerShell). Godot 4.7.2.
Pronouns: the user's pronouns were never stated. Use they/them.

---

## 1. Where things stand (read first)

- **Branch:** `final-version` (tracks `origin/final-version`). Latest commit is `d626638 "fix bugs for level 2, level 3"`, made by the user. The working tree was clean after it. `origin/main-game` is at `0729ba4 "Added level 3"` (a teammate's commit). `final-version` was merged on top of it.
- **The user commits and pushes themselves.** Don't commit unless asked. Commits are meant for `final-version` only, not `main-game`. If you commit, end the message with the `Co-Authored-By` line the system reminder gives.
- **A stash still exists:** `stash@{0}: stash for level 2`. It holds the user's old pre-merge version of Level 2 and the old level flow, which main-game superseded. It is safe to `git stash drop` once the user agrees. Don't `pop` it, because it conflicts.
- **All 3 levels are playable and win/lose correctly** (tested headless, see section 9).
- **Not built yet:** the star rating / scoring (section 7), a level-select or progress screen, sound, and anything after Level 3. Victory in Level 3 hides the "next level" button.
- **Known leftovers and cleanup candidates** (nothing is broken because of them):
  - `scenes/game2.tscn` is a stale, committed leftover of the user's old Level 2. It references `res://scenes/level_2.tscn`, which no longer exists. Nothing uses it. Delete it with the user's OK.
  - Unused assets: `assets/npc.png`, `cattle ahead.png`, `civilian crossing ahead.png`, `school ahead.png`, `scripts/main.gd` (no scene or script references it by path), `Global.current_scene`. `20 kmph.png` is still in the speed sign's "20" animation inside `speed_limit.tscn`, but the 20 button was removed so that animation is never played. `scripts/npc2.gd` is a copy of `npc.gd` that one Level 1 pedestrian (`npc3`) uses.
  - **`project.godot` `run/main_scene` points at `object.tscn`** (uid `cvhmui15kk1yl`, the traffic signal scene). It came from the teammate's commit. F5 therefore runs only the traffic signal. Use F6 on `scenes/intro.tscn`, or point the main scene at `intro.tscn` (uid `be4fvif1bm1kf`). I told the user and offered; they haven't decided.
  - `res://icon.svg` is missing (harmless error in the log).
  - Level 2's bottom curb is cut off by the bottom of the screen because the road was moved down 100px (deliberate, see section 5).

---

## 2. The vision for the game

A small, educational, pixel-art **road-rules puzzle game set in India** (traffic law and signs follow Indian rules; the hover text is based on the Motor Vehicles Act 1988 and Indian mandatory-sign meanings).

How a level plays:
1. A car sits on a road with some traffic and obstacles. The player sees the road, an **ITEMS sidebar** on the right, and a play button in the top-left.
2. **Before pressing play** the player drags **signs / traffic items** from the sidebar onto the map (never on the road, always on the grass or the divider).
3. The player presses **play**. Nothing else is controlled. The car and the NPCs drive by themselves and **obey the signs the player placed**.
4. The level is won when the player's car reaches the **finish line**, which lights up green. There are three outcomes: win, "YOU CRASHED!", and "YOU DID NOT REACH HOME".

**The core idea (from the user): use as FEW signs as possible to get more stars.** Each level has an optimal ("par") solution (section 7). A level can be solved with more items, but fewer is better. The star system is not implemented yet.

Each level teaches different signs:
- Level 1: the **traffic signal** and pedestrians.
- Level 2: the **U-turn sign** (and a traffic signal as a distractor).
- Level 3: **speed limit** (a reckless driver), **compulsory right turn**, **stop sign**, plus decoys (**left turn**, **U-turn**, **traffic light**).

A recurring design rule from the user: **signs apply to ALL cars**, including the NPC cars, not just the player's car. A sign placed in front of the reckless NPC driver should stop or turn him.

---

## 3. The user's requests, in order (the story so far)

These are the prompts the user gave, grouped, so a new Claude understands the intent behind the code.

**Git and repo**
- Pull level 3 from `main-game` into `final-version` and only commit on `final-version`. Fix the merge conflicts.
- Tidy the repo: the `.godot/` cache was committed and `.gitignore` was a broken UTF-16 file. Both were fixed (`.godot/` untracked, `.vscode/`, `*.tmp` ignored).
- Rename levels so the user's own level became Level 2 and the pulled level became Level 3 (folders `scenes/Level1..3`, `scripts/Level2`, `scripts/Level3`).

**Visuals and layout**
- NPC sprites: use the new coloured pedestrian sprites. Each NPC has a fixed colour by order (orange, red, pink, yellow), never random. The back sprite shows while moving up the screen and the front sprite while moving down.
- Level 3 NPC cars: cyan and purple with their own 5-frame animations. The player's maroon car stays. The frames were re-aligned so all three cars sit centred on the lane.
- All hover/highlight info boxes are uniform across levels, with short Indian-law wording and positioned left of the item.
- Level 2: the road was moved down so it doesn't run under the play button. The U-turn sign's drawn "U-TURN" caption was removed. The U-turn icon flips and rotates 90° once picked up to match the road.
- Sidebars are uniform across levels (five evenly spaced slots, section 4).
- Stretch aspect changed from `expand` to `keep` (no empty space on the right in fullscreen).
- A checkered finish line that turns green when the player's car reaches it.

**Mechanics the user specified**
- **Signs cannot be on the road.** If dragged over the road they jump to the nearest grass. The WHOLE collision shape must clear the road, not just the centre.
- **Snap grid is 20px** in every level (it was 128 in Levels 1 and 3, 20 in Level 2).
- Dragging only moves ONE item at a time.
- **Traffic signal (Level 1 behaviour):** the car stops at a line before the signal, the light turns green, NPCs near it run off, the car continues. The NPC must be "near" the signal (safe zone). Needs "vicinity": if the signal is far from the car's lane it must not work.
- **U-turn sign (Level 2):** the car "sees" the sign with a ray. Correct place means it takes the U-turn. Wrong place means it turns there and crashes into the divider. The sign must also be in the vicinity of the car.
- **Level 3 redesign:** speed sign only toggles 30/50 and starts on 50. The reckless car behind drives at 50, the player and the car in front at 30. Toggling to 30 slows everyone to 30. The speed sign is **frozen once play is pressed**.
- Crash screen **at the instant** the 50 km/h car touches the player's car.
- Going straight in Level 3 (no turn): cars **don't crash and don't stop**, they drive off the screen, then a new **"YOU DID NOT REACH HOME"** screen shows.
- Stop sign and traffic light apply to **NPC cars** too. The stop sign became a draggable sidebar item. The traffic signal appears in all levels' sidebars and works on NPCs.
- Left-turn sign (decoy) and U-turn sign (Level 3): added, cars react (section 6).
- Level 2: the safe zone for the U-turn sign was widened and then narrowed back to 4 grid boxes (see section 5). The sign must never touch the road, including the visible median end caps and the gap.

**Working style of the user**
- Short, direct messages, sometimes with typos ("only f grid boxes" meant four). **If an instruction is genuinely ambiguous, ask one short question** (they answer quickly). Otherwise act.
- They test in the Godot editor. When they say "don't code anything yet", don't.
- They care about uniformity, not changing the art, and keeping things like "all signs apply to all cars" true everywhere.
- They want things verified. I verified every change headless (section 9) and by rendering screenshots.

---

## 4. How the game works (architecture)

### Folder layout
```
scenes/
  intro.tscn                menu (scripts/intro.gd): "new game" button -> Level 1
  Level1/level 1.tscn       Level 1
  Level2/level 2.tscn       Level 2 wrapper (signs, cow, sidebar, victory/death/not_home)
  Level2/map.tscn           Level 2 road map (two tile layers, intersections, car, play button, finish line)
  Level3/level 3.tscn       Level 3
  Level3/right_turn.tscn left_turn.tscn u_turn.tscn stop.tscn speed_limit.tscn
  car.tscn                  the player's car (script scripts/car.gd)
  npc_car.tscn              NPC cars, Level 3 (scripts/Level3/npc_car.gd)
  npc.tscn                  pedestrians (npc.gd / npc2.gd patrol, scripts/npc_sprite.gd picks colour)
  object.tscn               the TRAFFIC SIGNAL item (scripts/traffic_signal.gd)
  safezone.tscn             "near the NPCs" zones (group "safe")
  info_box.tscn             the shared hover box
  death.tscn victory.tscn not_home.tscn   end screens, all driven by scripts/scene_change.gd
scripts/
  global.gd                 autoload "Global": shared state + drag/road helpers
  car.gd                    player's car
  traffic_signal.gd         traffic signal item (Levels 1, 2, 3)
  finish_line.gd            finish line (Area2D, drawn in code)
  info_box.gd               hover box (top_level Label)
  scene_change.gd           death / victory / not_home screen logic + buttons
  npc.gd npc2.gd npc_sprite.gd intro.gd
  Level2/ level2.gd sign.gd (U-turn sign) cow.gd
  Level3/ level3.gd npc_car.gd right_turn.gd direction_sign.gd stop.gd speed_limit.gd speed_button.gd
assets/                     art; assets/npcs/ (8 pedestrian sprites), assets/cars/ (cyan/purple frames + .tres)
```

### `Global` autoload (`scripts/global.gd`)
- State: `safe` (signal is in an NPC safe zone), `play` (play pressed), `speed_mult` (player's car multiplier, used for stops), `speed_limit_kmh` (30 or 50, caps ALL cars), `next_level`, `drag_owner`, `extra_road_rects`.
- `speed_cap_px()`: 50 km/h = **200 px/s**, 30 km/h = **120 px/s**. Cars use `min(own speed, cap)`.
- `GRID = 20`.
- **Dragging helpers:** `mouse_over_area(area)` (exact point hit), `snap_drag()`, `area_footprint(item, area)` (item's whole collision shape), `footprint_on_road(centre, rect, round?)`, `is_road(point)`, `drag_position(mouse, grab_offset, rect, round?)` (snaps to the grid, and if any part would touch road, searches rings of grid points for the nearest clear spot).
- **What "road" means:** any tile on a `TileMapLayer` in the group `road_layer` (curbs included). In Level 2 both `Roads` and `RoadsVisual` are in the group (the visual layer has the median end caps and gap tiles). `extra_road_rects` adds areas that have no tile.
- **Reset on every level start** (and in the end-screen buttons): `play=false`, `safe=false`, `speed_mult=1`, `speed_limit_kmh=50`, `extra_road_rects` cleared (Level 2 sets its gap rect). Because the autoload outlives scene changes, forgetting a reset gave real bugs before.

### The play flow
- The level starts **paused** (`car.gd` calls `pause1()` in `_ready`). Pressing the top-left play button (`pause` Button, toggle mode) fires `car._on_pause_toggled`, which sets `Global.play = true` and unpauses.
- Items are all `process_mode = 3` (they still work while paused so you can drag before play) and refuse to drag once `Global.play` is true.
- Win, crash and not-home screens are nodes (`victory`, `death`, `not_home`) in each level. They start hidden and call `_on_car_death()` / `_on_car_victory()` from `scene_change.gd`, which shows them and pauses the tree. Buttons there unpause, reset globals and change scene.

### Items (drag-and-drop signs)
- Common pattern: a `Node2D` with an `Area2D` (the grabbable shape), a hidden `Label` (instance of `info_box.tscn`), and a `Ray` `Area2D` (collision_layer 0): a **tall thin box in front of the sign**. When a car's body overlaps the ray, the sign's effect fires. Ray box height gives the "vicinity" idea: if the sign is too far from the car's lane, the ray doesn't reach it.
- **Rules every item follows:**
  - Does nothing while it is still in the sidebar (`x >= 933`).
  - Ignores a car that is already past it (`car.x > sign.x`).
  - Each car obeys it at most once.
  - The trigger fires on any body with the right method, so the **player's car and the NPC cars both obey**.
- **Stop / traffic light stop duration:** 1.5 seconds total. The light holds red for 1.0s, then plays red to green, then the car goes about 0.5s later.
- **Sidebar slots:** the column is x=1038; slot y values are **180, 280, 380, 480, 580** in the same order everywhere (traffic light first).
- **Drag visuals:** hovering scales an item by 1.05. Right turn, left turn and U-turn rotate their picture 90° when picked up (the sidebar picture is the "upright" version).
- **Info box (`info_box.tscn`):** 230×190 teal box, font `PixelOperator8-Bold` 16px, always left of the item (right if no room), clamped on screen. Set per item with `title` and `description` on the `Label` node.

### Cars
- `scripts/car.gd` (player): follows the **direction tiles** of the road tilemap (custom data layer `direction`, values like `R`, `U`, `RU`). Probes ahead/behind to pick direction and the turn animation (`TURNS` table). `turn_sig = true` means "scripted motion, stop following tiles" (set by turn signs). Methods called by signs: `_on_turn_right_turn`, `_on_turn_left_turn`, `_on_u_turn` (Level 3), `stop_for(seconds)`. A crash is raised when its crash `Area2D` overlaps an NPC **or when its physics body touches an NPC** (`_check_hit_npc`).
- `scripts/Level3/npc_car.gd`: same movement; has `skin` ("cyan" or "purp", loads `assets/cars/<skin>_frames.tres`), `speed`, and the same sign methods plus `hit_player` signal (raised when its body touches the player's car, so a rear-end is a crash at the moment of contact).
- Speeds: car sprite frames are 320×320 at scale 0.5 (times 0.75 node scale). `U_TURN_SHIFT = 66` px (the U-turning car drops 66px, which is just over its body height, so it doesn't hit cars on the original line).

### Pedestrians
- `npc.tscn` has an `npc_sprite.gd` child that gives each pedestrian a fixed colour by order in the level and picks front/back from its movement. Level 1 pedestrians patrol y 200 to 350 (`npc.gd` constants). When a traffic signal switches near them (`traffic_switched` signal emitted every frame while `npcs_leaving`), they hop up and run off the road.

### Finish line (`scripts/finish_line.gd`)
- An `Area2D` with a `size` export. Checkered while waiting. When the **player's car** (group `maincar`) enters it and `Global.play` is true, it turns green (glow, pulsing), waits 0.5s, then finds the sibling node named `victory` (walks up the tree) and shows it.

---

## 5. Levels in detail

Coordinates are in game pixels (viewport 1152×648). The sidebar starts at x=933. Road centre lines are listed per level.

### Level 1: "learn the traffic signal"
- **Layout:** straight horizontal road, curbs y 200 to 225 (top) and 350 to 380 (bottom), asphalt about 225 to 350, lane/centre line y=285. The player's car starts at (56, 285) and drives right. Road tiles continue under the sidebar.
- **Actors:** 3 pedestrians crossing at x=793, 834, 878 (patrolling up/down). Two safe zones (StaticBody2D from `safezone.tscn`) at (755, 454) and (754, 207), scale (2, 4): about x 735 to 893 and y 414 to 494 / 167 to 247.
- **Mechanic:** the traffic signal item. If it sits on the grass and its collision shape overlaps a safe zone, `Global.safe` becomes true. The player's car stops at a line about 40px before the signal, the light goes green, the pedestrians run off, and the car drives on to the **finish line** at x=892 to 904, y=226 to 350.
- **Why it can still fail:** the signal must be near the NPCs. Away from them the pedestrians stay and the car hits one (crash). Because the signal can't touch the road and is about 72px tall, valid spots near a safe zone are about **y=140 to 160 (above) or y=420 to 500 (below), x about 740 to 780**.
- **Win condition:** reach the finish line.

### Level 2: "U-turn"
- **Layout:** two carriageways with a grey divider (median) between them and a **gap** in the divider. **The whole road is shifted down 100px** so the play button is on grass. Top lane asphalt about y 161 to 320, bottom lane about 480 to 640, divider band y 361 to 441. Tile layers `Map/Roads` (logic) and `Map/RoadsVisual`, both at position (-1, 101). The player's car starts at (81, 561) in the bottom lane heading right. A **cow** (pedestrian, `cow.gd`) stands at (880, 561) in that lane. The finish line is at x=56 to 68, y=162 to 320 (top lane, far left).
- **Mechanic (`level2.gd`):** the car "sees" the U-turn sign when its front (centre + 40) reaches the sign's x and the sign is within 220px of the car vertically.
  - **Sign centre inside `ZONES["u_turn"] = Rect2(320, 361, 80, 80)`:** `_open_route()` paints direction tiles through the gap into the top lane, the car takes the U-turn, drives left along the top lane and crosses the green finish line.
  - **Sign anywhere else:** the car turns up right there, hits the divider (`CRASH_Y = 475`), crash screen.
  - **No sign:** the car hits the cow, crash.
- **Where the sign can go:** it can't touch any road, including the median end caps (x about 400 to 437 and 600 to 640) and the gap itself (registered as `extra_road_rects` Rect2(437, 361, 163, 80)). The sign's circle is 56px and the divider band is 80px, so the only valid grid y is **400**, and the only valid x values touching the correct zone are **320, 340, 360**.
- **Traffic signal in Level 2:** it is a sidebar item too. A `SafeZone` at (691, 400) scale (2, 4) lies over the right half of the divider. A signal on the divider there (e.g. (760, 400)) makes the car stop, the cow run off (it moves down the screen), and the car drive on straight. Without the U-turn it then leaves the screen and shows **"did not reach home"**.
- **Win condition:** the player's car crosses the green finish line after the U-turn.

### Level 3: "reckless driver and the junction"
- **Layout:** one road with a **T-junction** to the right. Top curb y about 200 to 225, asphalt to about 350, centre line y=288. The side road runs down at x about 350 to 470 (the junction is roughly x 350 to 490). The finish line is at (352, 604), size 118×12, across the bottom of the side road.
- **Cars (evenly spaced 170px apart, all on y=288):**
  - purple (behind), x=56, `speed 200` (50 km/h): the **reckless driver**
  - player (maroon, middle), x=226, `speed 120` (30 km/h)
  - cyan (in front), x=396, `speed 120` (30 km/h)
- **The speed sign** (`speed_limit_30` node, at (302, 160) on the grass, not in the sidebar) starts on **50**. Click it before play to open 30/50 buttons. The limit caps every car. It is **frozen once play starts**.
  - **Left on 50:** the purple car catches up and rear-ends the player at about t=1.7s, so a crash.
  - **Set to 30:** everyone drives 120 px/s, so nobody catches anyone.
- **Sidebar items:** traffic light, right turn, left turn, U-turn, stop sign.
- **What each does to ALL cars that reach it** (ours and NPC):
  - **Right turn:** car turns right (south) at the sign. This is the intended solution.
  - **Left turn (decoy):** car turns north onto the grass, then a crash.
  - **U-turn (decoy):** car drops 66px and drives back west. When the player's car leaves the left edge (x<=-90) the **"did not reach home"** screen shows. If a head-on meeting happens (sign placed near the start, x about 420 to 460) it ends in a crash instead.
  - **Stop sign / traffic light:** car stops 1.5s, then drives on. A sign in front of the reckless driver stops only him (the others are already past it).
- **Outcomes** (`level3.gd`):
  - Win: crossing the finish line at the bottom of the side road.
  - Crash: turned too early or too late onto grass (off-road after turning), left turn, or any body contact between cars (the purple car rear-ending the player counts as soon as bodies touch).
  - "Did not reach home": the player never turned and drives off the right edge (x >= 1230, no crash, nothing stops), or the player U-turned and left on the left.
- **Right-turn sign position:** the car turns when its front touches a line about 49px before the sign, so the working window is the sign centre **x about 440 to 580**. It must be off the road, so **y <= 160 or y >= 420**. The ray reaches up to about 160px from the lane.

---

## 6. End screens
- `death.tscn`: "YOU CRASHED!" with *back to menu* and *restart level*.
- `victory.tscn`: "YOU DID IT!!!" with *next level*, *back to menu*, *restart level*. The *next level* button is hidden when `Global.next_level == ""` (Level 3 sets that).
- `not_home.tscn`: "YOU DID NOT REACH HOME" (2 lines, font 72) with the same two buttons. Used by Levels 2 and 3.
- All three use `scripts/scene_change.gd`. Level flow: intro -> Level 1 -> (victory "next") Level 2 -> Level 3 (`Global.next_level`).

---

## 7. Optimal solutions and the star idea

The user's concept: **fewer signs used = more stars.** Not implemented. Below is the "par" for each level (the minimum number of **sidebar items placed**), plus alternatives.

| Level | Optimal solution (par) | Items | Other valid solutions |
|---|---|---|---|
| 1 | Traffic signal on the grass beside the NPCs (overlapping a safe zone), e.g. (760, 140) or (760, 440) | **1** | none (the signal is the only item) |
| 2 | U-turn sign on the divider at (320, 400), (340, 400) or (360, 400) | **1** | none that win (the traffic signal only clears the cow and ends in "did not reach home") |
| 3 | Speed sign set to **30** (not an item, a free toggle) + **right turn** at x 440 to 580, y <= 160 or >= 420 | **1** | **2 items:** stop sign or traffic light in front of the purple car (e.g. stop at (200, 140), light at (200, 160)) + right turn, with the speed sign left on 50. All three speeds-and-signs combos win. |

Notes for implementing stars (proposal, not agreed):
- Count items placed outside the sidebar (an item still at x>=933 doesn't count). Decide whether the Level 3 speed toggle counts. My reading of the user's wording: it is not a sidebar item, so it is free.
- One idea: 3 stars at par, 2 stars at par+1, 1 star for any win. The user hasn't specified.
- Counting at play time: iterate the items that have been moved off the sidebar (`global_position.x < 933`).
- Decoy items (left turn, U-turn in Level 3; traffic signal in Level 2) exist so that fewer is not trivially "use nothing". Placing a wrong item can make the level fail.
- A good place to show stars: the victory screen.

---

## 8. Conventions and rules to keep true (don't regress these)
1. **Signs apply to all cars** (player + NPC cars). New signs must expose the same kind of method on cars and fire from a ray.
2. **Signs can never touch the road.** Use `Global.drag_position(...)` with the item's `area_footprint`. Tag any new level's road tilemap with group `road_layer`.
3. **Grid is 20px.** All items share the same sidebar column and slots.
4. **Unplaced items do nothing** (`x >= 933` guard), and a car already past a sign ignores it.
5. **Reset globals at level start.** If you add a new global that changes gameplay, reset it in every level's `_ready` and in `scene_change.gd`.
6. **The hover boxes are the shared `info_box.tscn`.** Don't draw per-item text boxes.
7. **Don't change the art** unless asked (the user was explicit about this).
8. Crash must fire at the moment of contact, and going off the road without turning in Level 3 must not crash or stop cars (it ends in "did not reach home" once the player's car is offscreen).
9. Pronouns: they/them.

---

## 9. Development environment, testing method and gotchas

- **Godot executable:** `C:\Users\Arjun\Downloads\Godot_v4.7.2-stable_win64_console.exe` (there is also a non-console `.exe`). No Python on the machine. Use bash/PowerShell/Godot only.
- **Run the project headless:** `godot --path . --headless --import --quit` (re-imports assets, prints parse errors; ignore the `icon.svg` error). Run one scene's logic with a custom script: `godot --path . --headless --fixed-fps 60 --script some_test.gd -- args`.
- **Test scripts (all disposable, they lived in the scratchpad and are gone):** a `SceneTree` script that `load()`s a level scene, `add_child`s it, waits a few frames, **moves item nodes with `global_position = ...`**, sets `lvl.get_node("pause").button_pressed = true` to press play, and then watches `lvl.get_node("death"/"victory"/"not_home").visible` and car positions for ~15 seconds. That is how every solution in section 7 was confirmed.
  - For Level 3 toggle the speed with `lvl.get_node("speed_limit_30")._on_thirty_pressed()`.
  - A test can also simulate real mouse drags with `Input.parse_input_event(...)`; **headless window coordinates are scaled**, so first convert positions with `root.get_final_transform() * p`.
- **Gotchas found the hard way:**
  - In a test `_initialize()`, `add_child(level)` does **not** run `_ready` immediately. Anything you set right after `add_child` can be overwritten by `_ready` (for example `Global.speed_limit_kmh`). Set test values a few frames later.
  - `Global` isn't resolvable as an identifier in a standalone `--script`; use `root.get_node("Global")`.
  - `--write-movie` (screenshots) renders at a fixed 10 fps and its physics tick is coarse, so **don't use it for gameplay timing**, only for visuals. Injected mouse events don't reach a windowed run.
  - **The Godot editor caches scripts.** If the user's editor was open while files changed on disk and they choose "ignore" or the editor is stale, the editor's game can differ from disk (it has caused errors like `invalid access to property drag_owner on global.gd`). Fix: File reload / close and reopen the project. Files on disk were correct each time.
  - When running Godot **from the CLI while the editor is open**, the editor's `.godot` cache can drift; if odd things happen, tell the user to restart Godot fully.
  - NPC cars and the player are `CharacterBody2D`s that **physically block each other**, so a rear-end is stopped at about 95px apart. Crash detection therefore uses body contact (`get_slide_collision`) in addition to the crash area.
  - Area2D `body_entered` can fire again when the tree unpauses, so every sign checks "is the car still before me?" (`car.x <= sign.x`) as well as `Global.play`.
  - `RoadsVisual` and `Roads` in Level 2 differ: only the visual layer has the median caps and gap tiles. Placement checks use both.
- **Where the numbers come from if you retune:** `SEE_AHEAD` (40), `SEE_HALF_HEIGHT` (220), `CRASH_Y`, `ZONES` in `scripts/Level2/level2.gd`; `U_TURN_SHIFT` in the car scripts; `STOP_SECONDS` in `scripts/Level3/stop.gd`; `NPC_STOP_SECONDS` in `traffic_signal.gd`; ray box sizes/positions in each item `.tscn` (`Ray/CollisionShape2D`); the speed cap in `Global.speed_cap_px()`; slot positions in each level `.tscn`.

---

## 10. Open questions / next steps for a new Claude
1. **Implement the stars** (section 7). Needs the user's rule for counting, UI on the victory screen, and per-level saved results if they want progress.
2. Decide the `main_scene` (currently `object.tscn`, should probably be `intro.tscn`).
3. Delete the stale `scenes/game2.tscn`, unused assets and `scripts/main.gd` / `npc2.gd` if the user agrees; drop `stash@{0}`.
4. More levels after Level 3 (there is no next level; the victory screen hides *next level*).
5. Possible polish the user may ask for: sound, a menu with level select, balancing the speeds, more decoys.
6. If the user reports "X stopped working" after an editor reload, first check whether the files on disk match and whether the editor cache is stale (section 9) before changing code. Then reproduce headless.

---

## Addendum: menu, progress, stars and Level 4 (added after the sections above)

- **Menu / progress:** `scenes/level_select.tscn` + `scripts/level_select.gd` ("ZIP CODE 1", boxes for every entry of `Global.LEVEL_PATHS`, greyed out until all earlier levels are done, mouse + arrow keys + Enter). Progress and best star rating per level are saved in `user://progress.cfg` (`Global.complete_level`, `reset_progress`, `continue_index`). New Game wipes the save; Continue opens the first unfinished level.
- **Stars:** implemented. `Global.items_used()` counts items moved out of the sidebar (the Level 3 speed sign is free); `Global.stars_for(items, par)` gives 3 stars at par, 2 at par+1, else 1. `Global.PAR = [1, 1, 1, 2]`. Stars show on the victory screen (`scene_change.gd`) and on the level select.
- **UI polish:** autoload `UiFx` (`scripts/ui_fx.gd`) gives every Button a hand cursor and a hover grow, and sets the hand cursor over draggable items and the pause icon (not the whole invisible pause button).
- **Level 4 (highway merge)** `scenes/Level4/level 4.tscn`, `scripts/Level4/level4.gd`: same T-shaped road as Level 3 (the side road goes down to the bottom). The player's car drives UP the side road and turns left onto the highway; `level4.gd` drives it itself (state machine drive / wait / creep / merge / run, `car.turn_sig = true`). Highway cars (`highway_car.gd`) are scripted, not tile-following: 4 cars + 1 "stalling" car come from the right at 500 px/s, eastbound cars (upper lane) are decoration that keep spawning. Items: GIVE WAY (`give_way.gd`) and NO STOPPING OR STANDING (`no_stopping.gd`), both plain draggable signs; the level / the stalling car check how close they are placed (give way within 180 px of the line (380,428); no-stopping within 210 px of the stop spot (170,335)).
  Outcomes (verified headless): nothing / only no-stopping -> crash into traffic at t=1.3s; give way only -> waits, merges slowly, crashes into the stopped car at ~5.5s; both -> reaches the finish line at the left edge, victory at ~7s. Optimal = 2 items (both are needed), so par for Level 4 is 2.
- **Level 4 tray (update):** besides Give Way and No Stopping the tray holds the traffic signal, compulsory right / left turn, U-turn and stop sign from the earlier levels, and they all really work. For the player's car (driving UP the side road) `level4.gd` applies them itself (`_check_signs`: a sign within 170 px sideways of the side road and below the highway is obeyed when the car reaches its height: stop sign / traffic signal hold the car 1.5 s, compulsory left turns at that spot, right turn drives onto the grass = crash, U-turn drives back off the bottom = "did not reach home"); the signs' own rays are disabled for the player (`turned` / `stopped` / `handled_cars` pre-filled). Highway cars still obey the stop sign / traffic signal through the signs' rays (`highway_car.gd stop_for`). Stars: par 2 -> 2 items = 3 stars, 3 items = 2, 4+ = 1.
- **Compulsory turns now happen AFTER the sign (all levels with them):** a car first "sees" the sign (enters its ray), and only turns once it has driven 30 px past the sign (`cross_distance` in `direction_sign.gd` — set on the left turn; `CROSS_DISTANCE` in `right_turn.gd`; Level 4's `_check_signs` uses the same 30 px). The U-turn is unchanged. Consequence for Level 3: the winning spot for the compulsory right turn moved left: sign x ~230-350 (y<=150, or the bottom-left corner next to the side road y 420-520) with the speed set to 30 (the cars drive on to the side road, x=400, after crossing the sign: `turn_road_x` on the right turn sign); cars now turn once they have COMPLETELY crossed the sign (85 px past its centre), and the level counts "on the road" only when the whole car is on asphalt. A car that is already past the sign (e.g. the car ahead, at x=396, when the sign stands left of it) never sees it and drives straight on.
- **Failure feedback:** the crash and "did not reach home" screens show one sentence of feedback. `scene_change.gd` (`_show_feedback`) asks the level's root script for `death_feedback()` / `not_home_feedback()` (only if it has them). Level 1: `scripts/Level1/level1.gd` (nothing placed vs signal placed too far from the pedestrians). Level 2: `level2.gd` (nothing placed, U-turn right of the zone = "needs to see the sign", U-turn elsewhere = "needs to be near the turn", signal that only cleared the cow = not-home text). Levels 3 and 4 have no feedback text yet.
- **Finish line art:** `finish_line.gd` now draws `assets/finish line.png` (a HOME sign whose arrows point up), rotated so the arrows point along the export `heading` (right in L1, left in L2 and L4, down in L3); `sprite_scale` sets the size. Detection (green glow, then victory) is unchanged.
- **Customise screen:** `scenes/customise.tscn` + `scripts/customise.gd` (opened from the intro's CUSTOMISE button) lets the player pick the colour of their own car: red (default, the car in the scenes), cyan or purple. The choice is saved in `progress.cfg` (`[settings] car_skin`, via `Global.set_car_skin`) and `car.gd` applies it in `_ready` (`Global.car_frames()`: the cyan / purple SpriteFrames from `assets/cars/`) in every level. New Game keeps the chosen colour. The other cars stay grey.
- **Failure feedback (update):** every level now records WHY the player failed and `death_feedback()` / `not_home_feedback()` return a specific sentence: `level1.gd` (nothing / signal never reached / signal too far from the pedestrians), `level2.gd` (`crash_kind` early/late, sign never seen, signal that did not clear the cow, signal that cleared it), `level3.gd` (`reason`: hit from behind, hit ahead, too early / too late / wrong side, U-turn crash, straight on, U-turn) and `level4.gd` (`reason`: merged into traffic, Give Way too far / wrong side, stopped car with / without a No Stopping sign, compulsory turn problems, U-turn). `car.gd` keeps `last_hit` (what the player's car crashed into) for this.
- **Tutorial:** New Game wipes progress, then opens `scenes/tutorial.tscn` (`scripts/tutorial.gd`): an 8-slide show where the player's car explains the game with typed-out dialogue and the game's own art (finish sign, items tray, placing signs, play button, everyone obeys signals, stars, good luck). Next / Enter / Space / right arrow (the first press finishes the typing), Back / left arrow, Skip / Esc; the last slide's START (or Skip) opens Level 1. The slide texts and pictures are the `SLIDES` array and `_picture()` in `tutorial.gd`.
- **Other cars crashing ends the level:** in Levels 3 and 4 the NPC cars (`npc_car.gd`, `highway_car.gd`) emit `crashed` when they hit another NPC car, and in Level 3 also when a car that turned off the main road leaves the asphalt (same whole-car-on-asphalt rule as the player). The level scripts show the crash screen with the heading "A DIFFERENT CAR CRASHED!" (`death_title()`, applied by `scene_change.gd`) and "Try finding a way to make everyone drive safely." Side effect in Level 4: a stop sign / traffic signal beside the highway makes cars bunch up and collide, which now ends the level.
- **Settings / effects volume:** the intro's SETTINGS button opens `scenes/settings.tscn` (`scripts/settings.gd`): a pixel-style slider (drag, click, or left/right keys) for the volume of the sound effects. All effects play through an "SFX" audio bus created by the `Sfx` autoload; `Global.sfx_volume` (0..1) drives its volume (`Sfx.apply_volume`) and is saved in `progress.cfg` (`[settings] sfx_volume`). A click plays when you let go of the slider so the new volume can be heard.
- **Road check ignores the hover growth (fix):** items grow 12% while the mouse is on them, and the road check used that enlarged size, so a hovered item did not fit the thin spots (e.g. the Level 2 divider islands) and the ring search could fail, leaving the item on the road (198 of 510 simulated drags ended on the road for the Level 2 traffic signal). `Global.area_footprint` now divides the hover growth out (`HOVER_SCALE`, uses the item's `draggable` flag) and `drag_position` searches up to 40 rings instead of 15.
- **Fixes:** (1) the tutorial now draws the player's car from the saved colour's own pictures (`T_SIDE`), so it no longer shows a blank box after changing the colour on the customise screen; a new second slide "YOUR CAR" shows the player's car and a grey car ("I am the {COLOR} car ... everybody else is grey"). (2) Level 3: any collision (e.g. the reckless driver rear-ending you after a stop sign held him up) is a crash even if the car had already driven past the side road; only driving off the screen without turning is "did not reach home".
- **Fixes:** the pedestrians now start running off the road as soon as the car has stopped at the traffic signal (`npcs_leaving` is set when the car stops, not when the light turns green); the click sound is not played for the play/pause button once the level is running (`UiFx._clicked`).

---

## Level 5 (cross junction with a dual carriageway)

`scenes/Level5/level 5.tscn` (generated from tiles, see below) + `scripts/Level5/level5.gd`. A cross junction: our car starts on the left road pointing right; the road across is a dual carriageway (left half: traffic drives up, right half: traffic drives down) with a divider in the middle that has a gap (rows 4..9 of the tile map), like Level 2. A cow stands on the road to the right in front of the HOME sign. Car art is scale 0.55, like Level 4. The level script drives the car itself with a state machine (drive, wait, creep, arc, north, cross, south, arm; quarter turns are arcs, `_start_arc`).

**Solution (par = 5 items, all five are in the tray):**
1. GIVE WAY (`give_way`, scene from Level 4) west of the junction, within 300 px of the line (175, 320): the car waits for the fast left-half traffic, then merges slowly and drives up. Without it the car merges into the traffic and crashes.
2. ONE WAY (`one_way`; its picture is now `assets/one way right.png` (from the designer; `assets/one way left.png` is also in assets but unused; the old generated placeholder `assets/one way sign.png` is unused)) in the top left (Rect2(0,0,215,290)): without it a grey car spawns at the top and drives down our lane (the wrong way) and hits us.
3. U-TURN on the divider (x 365..455); the car turns where `sign.y - 30` is and goes through the gap at y=125 (the sign has to stand on the grid spot (400|420, 220) on the part of the divider just before the gap). It then drives down the right half.
4. COMPULSORY LEFT TURN (`left_turn`) in the top right (x 605..825, grass, y 180..220): the car turns once it has completely crossed the sign (75 px) onto the road to the right.
5. CATTLE AHEAD (`cattle_ahead`) beside that road (x 640..720): when the car gets within 60 px of it the car waits 3 s (stop 1.5 + signal 1.5) and the cow (`scripts/Level5/cow.gd`, two-frame `AnimatedSprite2D`, walks up at 40 px/s) leaves the road. Without it the car hits the cow.
Other endings: leaving the top/bottom of the screen = "did not reach home"; leaving the asphalt = pavement/divider crash; NPC car crashes = "A DIFFERENT CAR CRASHED!". Feedback texts are in `death_feedback()` of `level5.gd`.

**Tiles:** the map was built by a one-off generator script (not in the repo) from the Level 3 tile pieces: horizontal road rows 16..27, two 12-tile carriageways (cols 11..22 and 29..40) copied from Level 3's stem pattern, plain asphalt across the junction, the four outer rounded corners (the same 4x4 pieces as Level 3), and the divider drawn as two ColorRects behind the tile layer (nothing there is road, so signs can stand on it). `highway_car.gd` now also drives up/down (`direction.y`). `Global.PAR` = [1, 1, 1, 2, 5]; the level picker shows 5 boxes.
- **Level 5 tray (update):** besides its five puzzle items the tray holds the traffic signal, compulsory right turn, stop sign and no stopping sign of the earlier levels (9 items, two columns at x 988/1088, rows y 180..580). They work as elsewhere: for our car `level5.gd` applies them (`_check_player_signs`: stop sign / signal hold the car 1.5 s, the right turn sends it round a right-hand corner (`free` state, it then drives straight on until it leaves the road or the screen)); the other cars (`_other_cars_obey_signs`, reach 100 px) stop for a stop sign / signal beside their lane (their pile-ups end the level with "A DIFFERENT CAR CRASHED"). The no stopping sign has no effect of its own in Level 5. The signs' own rays are blocked for our car (`turned` / `stopped` / `handled_cars`).
- **Level 5 compulsory signs apply to every car:** a compulsory left / right turn is obeyed by our car in ANY state (`_check_player_signs`: within 150 px sideways, after crossing the sign by 75 px; it turns left/right, then drives on in `free` / `arm` state until it leaves the road or the screen) and by every other car within 100 px (`_other_cars_obey_signs` -> `highway_car.start_turn`); an other car that is sent off the asphalt ends the level ("A DIFFERENT CAR CRASHED!"). Because of this the intended left-turn sign has to stand where the right-hand lane's cars are not within 100 px of it (x >= ~680, y 180..220).
- **Music:** `scripts/music.gd` (autoload `Music`) plays `assets/audio/music_intro.mp3` on the menus (intro screen, tutorial, level picker, customise, settings), `music_levels.mp3` in levels 1-4 and `music_boss.mp3` in level 5; it picks the track from the open scene's path, keeps the same track across scenes (menus, level 1 -> 2 ...), fades between tracks, loops, and plays on its own "Music" bus at -8 dB.
- **Level 5 left turn (update):** other cars now see a compulsory turn sign from the same distance as our car (150 px, `NPC_TURN_REACH`); the cars coming down the right half therefore react to a left-turn sign placed near them (x <= ~665) and, being fast, leave the road = "A DIFFERENT CAR CRASHED". Their lane next to the divider (x 515) is the only one used by that traffic, our lane (575) stays free so the intended sign (x 680..725, y 180..220) still works. The compulsory left turn sign turns 180 degrees when it is picked up (`drag_rotation_degrees` in `scenes/Level5/left_turn.tscn`, applied by `scripts/Level5/sign_item.gd`), so it points down and then right: where the car goes.
- **Settings (update):** the settings screen now has two sliders: EFFECTS VOLUME and MUSIC VOLUME (`Global.music_volume`, saved as `[settings] music_volume`, applied to the "Music" audio bus by `Music.apply_volume`). Keyboard: up/down choose the slider, left/right change it.
- **Level 5 traffic and compulsory turns (update):** the right half now has traffic in both lanes (3 cars in the lane next to the divider x=515, ONE car in the lane x=575). Only cars in the lane on the side of the turn obey a compulsory turn (`_in_turn_lane`: for a left turn the east lane when driving down / the west lane when driving up). A car that obeys slows to `TURN_SPEED` (150 px/s), turns onto the cattle road, also obeys the CATTLE AHEAD sign (waits 3 s and starts the cow) and is crashed into the cow if there is no cattle sign ("A DIFFERENT CAR CRASHED!"). There is a single car in lane 575 on purpose: a second one would run into the first while it waits at the cattle sign.
- **Cow already gone:** if another car already set the cow walking (`cow.started`), our car no longer waits at the cattle sign (it only waits while the cow is still walking off). Level 5 par is 5 items: 5 = 3 stars, 6 = 2, 7+ = 1 (`Global.PAR[4]`).

---

## Building the Windows exe

- `export_presets.cfg` has a "Windows Desktop" preset (Embed PCK = one self-contained exe, icon `icon.ico`). The project's main scene is `res://scenes/intro.tscn` and its icon is `icon.png` / `icon.ico` (made from `assets/game icon.png`).
- The Godot 4.7.2 export templates for Windows (x86_64) are installed in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- Build from a terminal in the project folder:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/TrafficShaffic.exe`
  (or in the editor: Project > Export > Windows Desktop > Export Project). The output folder `build/` is in `.gitignore`.
- The exported game keeps its own save file (progress, stars, colour, volumes), separate from the one the editor uses.

## Web build (GitHub Pages)
- Export preset "Web" (export_presets.cfg, single-threaded, so no special server headers) writes to `docs/index.html`.
- Re-export after changes: `Godot --headless --export-release "Web" docs/index.html`. Keep `docs/.nojekyll`.
- Publish: push, then GitHub > Settings > Pages > Deploy from a branch > branch + `/docs`.
- Saves live in the browser (per device); music starts after the first click.

## Level slots (9 levels, 3 zip codes)
- `Global.LEVEL_PATHS` has 9 slots (3 per zip). Zip 1: L1 = old level 1. Zip 2: L5 = old level 2. Zip 3: L7/L8/L9 = old levels 3/4/5. `""` = not made yet (button says COMING SOON and does nothing; it never blocks later levels).
- To add a level: put its scene path into its slot; `Global.PAR` is indexed by slot.
- Old saves (no `[meta] version`) are migrated to the new slots automatically.

## Zip 1, level 2 (timed traffic signal)
- Scene `scenes/Zip1/level 2.tscn` (slot 1 of `Global.LEVEL_PATHS`), script `scripts/Zip1/level_z1_2.gd`, item `scenes/Zip1/timed_signal.tscn` + `scripts/Zip1/timed_signal.gd`.
- The signal is dragged onto the grass beside the road the traffic comes down (zone `SIGNAL_ZONE`). Click it (no drag) to pick 2 s (default) or 5 s. On play the red counts down; the traffic queues in front of the junction until green.
- 2 s: traffic is released while our car is still crossing (crash); 5 s: car is across first. Par 1.
- The scene was generated by a script (cross junction from the Level 5 tiles); edit the roads in the Godot editor like the other levels.

## Zip 1, level 3 (stop sign + timed signal)
- Scene `scenes/Zip1/level 3.tscn` (slot 2), script `scripts/Zip1/level_z1_3.gd`. Same junction as Zip 1 level 2 with a second car coming UP the west lane. The timed signal is pre-placed (click to set 2 s / 5 s); the stop sign is dragged from the tray beside the road below the junction (`STOP_ZONE`).
- Nothing: the car from below hits us. Stop sign only: the top traffic is released after 2 s and hits us. Stop sign + 5 s: win. Par 2 (the pre-placed signal counts as an item).
- Sign rule (see `SIGN_RULES.md`): every sign should affect every car close enough to it. Done for the stop sign in Zip 1 level 3; other levels are listed there as gaps and are to be decided per level.

## Zip 2, level 4 (T junction, compulsory left turn)
- Scene `scenes/Zip2/level 4.tscn` (slot 3), script `scripts/Zip2/level_z2_4.gd`. T junction: road across plus a road going up; HOME at the top. Tray: compulsory left turn (turns 90 degrees when picked up so its arrow shows right-then-up).
- No sign: the car drives off the right edge (did not reach home). Sign beside the road before the junction (x about 245-350 above the road): the car turns once it has crossed the sign and gets home. Too early / too late: crashes into the pavement. Par 1.

## Zip 2, level 6 (T junction, reckless driver)
- Scene `scenes/Zip2/level 6.tscn` (slot 5), script `scripts/Zip2/level_z2_6.gd`. Same T junction as Zip 2 level 4. Tray: traffic signal, compulsory right turn, compulsory left turn, stop sign (no U-turn yet).
- The reckless driver (a `highway_car`) is on the lower lane 50 px ahead of us. Signs act on BOTH cars: turn signs reach 180 px sideways, stop sign / traffic signal 130 px (see `SIGN_RULES.md`; to be confirmed per level).
- Left turn only: both turn, the reckless driver cuts across our lane and hits us. Left turn + stop sign beside the reckless driver (below the road): he waits, we turn first and win. `highway_car.start_turn` now also works for a car turning from a horizontal onto a vertical road. Par is 2 (left turn + stop sign), set in `Global.PAR`.
- Stop signs / traffic signals now belong to ONE road (see `SIGN_RULES.md`): whole road, nearest road wins at junctions. Applied in Zip 1 level 2/3 and Zip 2 level 6; the old levels are unchanged. The pre-placed timed signal of Zip 1 level 2/3 moved to (560, 224).

## Zip 2, level 6 (REDESIGNED: standing NPC, two cars side by side)
- NOTE: the NPC is now a PERSON (the level 1 pedestrian, `scenes/npc.tscn`) that runs to the grass when a car stops at the traffic signal (not a standing car). Replaces the reckless-driver version. Same scene/slot (slot 5, `scripts/Zip2/level_z2_6.gd`). Our car (upper lane) and a second grey car (lower lane) start side by side; a grey car stands in the RIGHT lane of the road going up.
- Left turn only: both turn at the same sign; the lower car's turn is longer (radius + one lane gap) and ends in the right lane, where it hits the NPC ("a different car crashed").
- Left turn + traffic signal NEXT TO THE PERSON (within 170 px): the person sees the cars stop and runs off, then both cars go and we get home. A stop sign does not move the NPC, so it does not solve it. Par 2.
- `Global.next_level` is now computed with `Global.next_path_after(scene_file_path)` in every level script, so the order follows the picker slots (Level 5 -> Level 6 -> Level 7 ...).
- Zip 2 level 6: the traffic signal also works beside the road going up (where the person stands, y about 100-215): cars that have turned onto that road stop at it, then the person runs off. See `_at_line` in `level_z2_6.gd`. Stop signs / traffic signals now sit flush against the road edge when dragged (`Global.flush_to_road`).
- Zip 2 level 4/6: compulsory left turn is one grid box (20 px) more forgiving on the early side (`_turn_radius`, `FORGIVE`): a sign that is a little too early makes the car take a wider arc and still land in its lane. Level 3 (speed limit): the speed limit sign moved from x=302 to x=700. Zip 2 level 6 / Zip 1 level 3 trays: sign sprites set to scale 1 (left and right turn now the same size).
- More turn signs: Zip 2 level 4 got the compulsory RIGHT turn (car turns down onto the grass = pavement crash). Old Level 2 (picker level 5) got compulsory LEFT and RIGHT turn (`_check_turn_signs` in `level2.gd`: car turns after crossing the sign; left -> divider crash, or up through the gap -> pavement crash at the top road; right -> pavement crash; reach 180 px). Zip 2 level 6 got the U-turn (two quarter turns of radius 30 for BOTH cars: our car ends in the lower lane heading left = not home, the lower car leaves the road = a different car crashed / the cars hit each other).

## Level 8 (old Level 4, highway merge) + road-based turn signs
- Without the GIVE WAY sign the car no longer turns onto the highway: it drives straight on and crashes (traffic or pavement). Only a compulsory left turn makes it turn. Alternative solution (verified): STOP sign + TRAFFIC SIGNAL on the side road (3 s wait lets the traffic pass) + compulsory LEFT turn (west of the side road, about y 486) + NO STOPPING near the stalling car -> win. Give way + no stopping still wins.
- Left/right turn signs are now road-based (see `SIGN_RULES.md`): snap flush, point the way the traffic goes on their side of the road, only affect cars of that road/direction. Levels 3 and 5 (old) keep the old behaviour.
- Level 8: the turn onto the highway (give way creep or compulsory left turn) now uses an adaptive radius (`merge_radius`) so the car always lands exactly in the middle of the lane going left, wherever the turn starts. A compulsory left turn sign anywhere from about y=436 to y=546 (west of the side road) now works once the car has waited long enough (stop sign + traffic signal = 3 s).

## "New sign unlocked" screens + reckless driver art
- `scripts/sign_intro.gd` (autoload `SignIntro`): when a level in its `INTROS` table opens, a "NEW SIGN UNLOCKED" screen shows the sign(s) with name + description (read from the sign's own scene, so it matches the hover text) before the level starts. Not shown again on "restart level" (`Global.skip_sign_intro`). To add one: add `level scene path -> [{"scene": sign scene}]` to `INTROS` (optional `heading`, `title`, `text`).
- Current table: Level 1 traffic signal; Zip 1 level 2 "NEW FEATURE: adjustable timer"; Zip 1 level 3 stop sign; Zip 2 level 4 left + right turn; Level 5 (old L2) U-turn; Level 7 (old L3) speed limit; Level 8 (old L4) give way + no stopping; Level 9 (old L5) one way + cattle ahead.
- Reckless driver art: `assets/cars/reckless_frame_1..5.png` + `reckless_frames.tres`, skin "reckless" (npc_car.gd / highway_car.gd). Used by the reckless driver of Level 7 (old Level 3, "npc car2").
- Level 6: the person only runs off if the traffic signal is within 170 px of him (PERSON_SEE_RANGE); a far signal stops the cars but he stays.
- Mini tutorials (`scripts/sign_intro.gd`) now support several pages per level and cards with their own picture/text. New: Zip 1 level 2 "NEW: CLICKABLE SIGNS" (explains the white dashed outline), Level 7 speed limit card mentions it is clickable, and Level 7 gets a second page "WATCH OUT! RECKLESS DRIVER" (reckless asset).
- Already-placed clickable signs (the adjustable traffic signal of Zip 1 level 2/3 and the Level 7 speed limit sign) get a solid white border that follows the exact outline of the asset (traced from its pixels) (`scripts/click_outline.gd`, hidden once play is pressed). The hand cursor over them comes from UiFx (any item with an Area2D).
- Reckless driver skin also used by the car that stalls at the end of Level 8 (old L4) and the wrong-way car in Level 9 (old L5).
- Colours are locked behind total stars (`Global.SKIN_STARS`: cyan 9, purple 18; `total_stars()`, `skin_unlocked()`). The customise screen and the level picker show the total stars (number + gold star) top right; a locked colour shows its cost (number + star) in its button and cannot be picked. A colour whose stars are gone (New Game) falls back to red.
- Level 9 (old L5): the U-turn sign only works at the TOP of the lower divider block, just below the gap: from the highest spot where it can be placed (about y 260, worked out in `_find_u_sign_limit`) down to 2 grid boxes lower (about y 300). Lower down the divider it does nothing ("too far" message).
- Level 9 (old L5): (1) NO traffic comes down the right half any more. (2) The cow also notices a car that STOPS near it (within `COW_SEE_RANGE` = 160 px: stop sign / traffic signal, not only the cattle sign) and starts to walk off. It is slower now (`walk_speed` 28, about 3 s to be clear): ONE stop (stop sign OR traffic signal, 1.5 s) is not enough (crash into the cow), a stop sign AND a traffic signal near the cattle road (3 s) are, and so is the CATTLE AHEAD sign alone (3 s). The 6-item alternative gives 2 stars (par is 5).
- Level picker: one page per zip code with next / previous arrows (and Left/Right keys move across pages). Star counter number baseline y=59 (see customise.gd / level_select.gd).

## Encyclopedia
- Book icon bottom right of the intro screen (`intro.gd`, art `assets/book icon.png`) -> `scenes/encyclopedia.tscn` / `scripts/encyclopedia.gd`: all 10 signs (`SignIntro.SIGN_LIST`) with picture, name and the hover description, always visible. A sign is unlocked once the level that introduces it was opened (`Global.unlock_sign`, saved in progress.cfg [signs]; finished levels backfill it; New Game clears it). Locked signs: flat grey silhouette (nothing of the sign shows) with its outline and a ? inside, "???" as the name and no description.
- Signs flush against a road with a road on BOTH sides (the divider of the old Level 2 / Level 5): the mouse decides which road (Global.flush_to_road, 'wanted'): mouse on the bottom half of the divider -> bottom carriageway, top half -> top carriageway.
- Level 9 (old L5): home tile moved to x=880 and the cow to x=830 (closer to home, more room before it); cattle zone and COW_SEE_RANGE (200) widened to match; cow walk_speed 24. Stop sign / traffic signal on this level are road-based (SIGN_ROADS).

## Levels 4 and 5 swapped
- Picker order is now: 1 Level 1, 2 Zip 1 level 2, 3 Zip 1 level 3, **4 = the dual carriageway U-turn level (scenes/Level2)**, **5 = the T junction with the compulsory left / right turns (scenes/Zip2/level 4.tscn)**, 6 Zip 2 level 6, 7 speed limit, 8 highway, 9 cattle. Save files are version 3; an older save has its level 4 / 5 progress swapped once on load. The left / right turn signs were removed from the U-turn level (level2.gd keeps guarded code in case they come back). Encyclopedia order: traffic signal, stop, U-turn, left, right, speed limit, ...
- Audit "all earlier signs are in every level": missing -> level 4 (stop), level 5 (traffic signal, stop, U-turn), level 8 and 9 (speed limit). Waiting for the designer's decision.
- Level 4 (old Level 2): signs are blocked by the curbs around the divider again (no curb-free placement); the U-turn safe zone is now x 240..400 on the left divider (4 grid boxes further left than before): anywhere in it works, further left than 240 = the car turns too early and hits the divider.
- Level 5 (Zip2/level 4 scene): tray now also has the traffic signal, stop sign and U-turn (all apply to the car: stop / signal road-based, U-turn sends it back left = not home).
- Mini tutorials (sign_intro.gd) are shown only the FIRST time a level is played in a game: Global.seen_intros (saved in progress.cfg [signs]); New Game clears it so they show again once; levels already finished before this change count as seen. Restart / replaying never shows them.
