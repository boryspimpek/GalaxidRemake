# GalaxidRemake — Project Context

GalaxidRemake is a Godot 4.6 remake of the classic shooter **Tyrian** (1995, Epic MegaGames).
Vertical-scrolling shoot-'em-up. Game-logic values (velocities, distances) use **Tyrian pixel/frame**
units from the original data. Rendered at **1920×1080**, playfield **608 px wide**.

---

## Scaling

All Tyrian legacy values are in original 288×200 px space. `SCALE_FACTOR = 2.11` (288→608 px).

Applied in:
- `EnemySpawner._setup_enemy()` — spawn position X and Y scaled on instantiation
- `Enemy._process()` — entire movement (velocity + fixed_move_y + scroll_y) scaled before applying to position
- `LevelManager._process()` — `_level_map.position.y` scaled for visual scroll; `level_distance` accumulates unscaled (preserves event timing)

`GameConstants.BOUNDS_*` are in scaled Godot px space (×2.11).
Player clamped to X: 0–608, Y: 0–1080.

---

## Architecture

```
scenes/world/LevelManager.gd        — root node of a level; owns all managers
scripts/managers/EnemySpawner.gd    — instantiates & configures enemy scenes
scripts/managers/EnemyController.gd — global enemy commands (move, accel, fire)
scripts/managers/EventProcessor.gd  — reads lvlXX.json events, dispatches them
scenes/enemy/Enemy.gd               — base class for all enemies (Area2D)
scenes/world/LevelRuler.gd          — @tool, draws distance ruler (reference grid)
addons/level_editor/LevelEditorPanel.gd — @tool editor plugin (timeline + JSON editor)
```

No background system (no TileBackground, TileLayer, Starfield).
Camera2D is static at `(304, 540)` — centers 608 px playfield on 1920 px screen, no pan logic.

---

## Scroll System

Each frame `LevelManager._process` runs:
```gdscript
level_distance += float(back_move)                              # logical timeline — unchanged
_level_map.position.y += float(back_move) * GameConstants.SCALE_FACTOR  # visual scroll — scaled
```

Three scroll speeds correspond to enemy slots:

| Variable     | Slot  | Typical value |
|--------------|-------|---------------|
| `back_move`  | 25,75 | 1–4           |
| `back_move2` | 0     | 2× back_move  |
| `back_move3` | 50    | 3× back_move  |

When `back_move` changes mid-level (event type 2/30), all living enemies' `scroll_y` is
updated immediately and `EnemySpawner.set_scroll_data()` is called.

---

## Level Data Format

Files: `data/lvlXX.json`

```json
{
  "lvl17": {
    "header": {
      "map_x": 1, "map_x2": 1, "map_x3": 1, "map_y": 0,
      "level_enemies": [3, 5, 7],
      "level_enemy_frequency": 96
    },
    "events": [ ... ]
  }
}
```

Events are **sorted by `dist`** (ascending). `dist` is in Tyrian units (== `level_distance`).
Each event has: `dist`, `event_type`, `event_name`, `category` (`"spawn"` or `"context"`).

---

## Event Types

### Context events (change global state, replayed on fast-forward)

| type | event_name            | key fields                                      |
|------|-----------------------|-------------------------------------------------|
| 1    | starfield_speed       | `starfield_speed`                               |
| 2,30 | scroll_speed          | `back_move`, `back_move2`, `back_move3`         |
| 8    | starfield             | `star_active` (bool)                            |
| 13   | disable_random_spawn  | `enemies_active: false`                         |
| 14   | enable_random_spawn   | `enemies_active: true`                          |
| 19   | global_enemy_move     | applies velocity to all live enemies            |
| 20   | global_enemy_accel    | applies acceleration to all live enemies        |
| 26   | small_enemy_adjust    | `small_enemy_adjust` (bool)                     |
| 27   | global_enemy_accelrev | reverse accel                                   |
| 31   | enemy_fire_override   | overrides fire params of live enemies           |
| 34   | enemy_fire_power      | `link_num`, `new_tur[3]`, `new_freq[3]` (-1 = keep current) |

### Spawn events (create enemies)

| type | event_name           | key fields                                                   |
|------|----------------------|--------------------------------------------------------------|
| 6    | spawn_ground         | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`(25)        |
| 7    | spawn_top            | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`(50)        |
| 10   | spawn_ground_2       | like 6, slot 75                                              |
| 15   | spawn_sky            | `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`            |
| 17   | spawn_enemy          | generic: `screen_x`, `screen_y`, `enemy_id`, `enemy_slot`, `y_vel` |
| 18   | spawn_sky_bottom     | sky layer, scrolls upward (`-back_move2`)                    |
| 23   | spawn_sky_bottom2    | sky layer, scrolls with slot                                 |
| 32   | spawn_enemy_special  | spawns at y=190, scrolls with `-back_move3`                  |
| 33   | enemy_from_enemy     | spawns enemy when another dies                               |
| 40   | enemy_continual_damage | env damage to player                                       |
| 56   | spawn_ground2_bottom | ground2, offset +6/+3                                        |
| 60   | assign_special_enemy | `dat`..`dat6` fields, marks special/boss enemy               |
| 100  | path_enemy           | `enemy_id`, `path` (node name), `screen_x`, `screen_y`      |
| 200  | spawn_free_enemy     | `enemy_id`, `screen_x`, `screen_y`, `vel_x`, `vel_y` — scroll_y=0, slot=0 |
| 201  | spawn_free_4x4       | `enemy_ids`[4], `screen_x`, `screen_y`, `vel_x`, `vel_y` — 2×2 grid, free |

Common optional fields: `link_num`, `fixed_move_y`, `y_vel`, `enemy_slot`.

---

## Enemy System

Enemy scenes: `scenes/enemies/Enemy_XXX.tscn` (inherit from `scenes/enemy/Enemy.tscn`).
Loaded on demand and cached by `EnemySpawner._scene_for_enemy(id)`.

### Scene-exported fields (set in .tscn, define enemy behaviour)

| field               | meaning                                                  |
|---------------------|----------------------------------------------------------|
| `armor`             | HP; enemy dies when armor ≤ 0                           |
| `esize`             | 0=small, 1=large (affects explosion sound & adjust)      |
| `xmove`             | base velocity X (Tyrian px/frame)                        |
| `ymove`             | base velocity Y (Tyrian px/frame)                        |
| `startx`, `starty`  | default spawn position for random spawn                  |
| `startxc`           | random spread radius for X in random spawn               |
| `excc`, `eycc`      | pendulum acceleration engine (Tyrian xcaccel/ycaccel)    |
| `xrev`, `yrev`      | pendulum reversal threshold velocity                     |
| `xaccel`, `yaccel`  | random per-frame velocity addition                       |
| `tur[3]`            | weapon IDs [down, right, left], 0=none                   |
| `freq[3]`           | fire cooldown frames per weapon                          |

### Runtime movement per frame

```gdscript
velocity.x += float(xaccel)
velocity.y += float(yaccel)
# pendulum engine updates velocity.x / velocity.y via excc/eycc
var move_x = velocity.x * SCALE_FACTOR
var move_y = (float(fixed_move_y) + velocity.y + float(scroll_y)) * SCALE_FACTOR
position.x += move_x
position.y += move_y
```

Enemy is removed when position goes outside `GameConstants.BOUNDS_*`.

### Enemy slot → scroll_y

```
slot 0    → scroll_y = 0          (free, independent)
slot 25   → scroll_y = back_move  (ground layer)
slot 50   → scroll_y = back_move3 (top layer)
slot 75   → scroll_y = back_move  (ground layer)
```

---

## Debug / Play from dist

Plugin saves to `ProjectSettings`:
- `game/debug/start_dist` — level_distance starting value
- `game/debug/level_name` — overrides `LevelManager.level_name` export

`LevelManager._ready()` reads both **before** `init_managers()` / `load_data()`.
`EventProcessor.fast_forward_to(dist)` replays context events to restore global state.

---

## Level Editor Plugin

File: `addons/level_editor/LevelEditorPanel.gd` (`@tool extends Control`)

- Timeline: Y axis = `dist` (inverted: 0 at bottom), X axis = screen X (0–288, legacy units).
- Spawn events drawn as colored circles at `screen_x`.
- Context events drawn as colored bars (full width).
- Filter bar: `spawn` visible by default, `context` hidden by default.
- Click on event → editable form in right panel → "Zapisz zmiany" writes JSON to disk.
- Custom `_serialize()` preserves key insertion order and keeps simple arrays on one line.
- `READONLY_FIELDS = ["event_name", "event_type", "category"]` — never editable.
- `STRIP_FIELDS = ["raw_x"]` — auto-removed on load.
- Zoom buttons `[-]`/`[+]` scale Y axis; scroll center is preserved.
