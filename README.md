# Metro Ops

Steam Deck–first city-builder vertical slice (Godot **4.7.2**, Forward+).

War-room locks from day one: **40 FPS** target, **FSR2** at 0.67 scale, **1280×800**, aggregate sims only (no per-citizen agents, no full traffic pathfinding).

## Path

```
/workspace/metro-ops
```

Godot binary:

```
/workspace/tools/godot/godot
```

## How to run

```bash
/workspace/tools/godot/godot --path /workspace/metro-ops
```

Windowed Deck-native viewport: **1280×800**. Engine cap: `Engine.max_fps = 40` (also `debug/settings/fps/force_fps=40` in project settings).

### Headless smoke

```bash
/workspace/tools/godot/godot --headless --path /workspace/metro-ops -s res://tests/smoke_headless.gd
```

Expect `SMOKE_OK` and exit code 0.

## Deck / FSR / 40 FPS

| Setting | Value |
|--------|--------|
| Renderer | Forward+ (`rendering_method=forward_plus`) |
| Viewport | 1280×800 |
| Max FPS | **40** |
| FSR | `scaling_3d/mode=2` (FSR2), `scale=0.67`, `fsr_sharpness=0.2` |
| Feel | Saturated flat tiles, no heavy shadows / volumetrics |

Gamepad-first (Steam Deck):

| Input | Action |
|-------|--------|
| D-pad / left stick | Pan |
| A / Space / LMB | Paint |
| L1 / R1 (Q / E) | Cycle tool |
| Start / Esc | Pause + advisor |
| Select / F3 | FPS overlay |
| UI buttons or keys `1` / `2` | War / Disaster events |

## Map & chunks

- **Map:** 256×256 tiles  
- **Chunk:** 16×16 tiles → **16×16 chunks** covering the map  
- **Tile pixel size:** 8 px (world ≈ 2048×2048)  
- **Fog-of-build:** tiles only reveal/build near roads & HQ  
- **Active-chunk sim:** only chunks touched by roads/HQ/services tick occupancy & tax  

## Vertical slice (playable)

1. **Paint RCI zones** (Residential / Commercial / Industrial) on dirt/grass  
2. **Paint roads** — cheap service-connectivity graph only (no cars / no pathfinding)  
3. **Power plant** (radius) + **water tower** (radius) — zones need **both** (+ road adjacency) to grow occupancy %  
4. **Budget ledger** — tax from aggregate occupancy, upkeep for plants/towers; cash HUD  
5. **Advisor panel** — warns/blocks bad first moves (e.g. mass zones before power)  
6. **War event** — trade embargo (tax ×0.45) + military levy (−$4000)  
7. **Disaster event** — damages a random **active** chunk (zones offline) + temporary demand crash  
8. Gamepad-first controls + keyboard fallback  
9. Optional FPS overlay for Deck perf checks  

HQ seeds a small revealed road cross and a tiny starter power/water bubble so the first minutes are not softlocked.

## Systems overview

| Module | Role |
|--------|------|
| `scripts/core/game_constants.gd` | Locked sizes, costs, FSR/FPS constants |
| `scripts/core/tile_types.gd` | Terrain / zone / service enums + colors |
| `scripts/core/chunk_data.gd` | Per-chunk aggregate occupancy stats |
| `scripts/systems/map_data.gd` | Flat tile arrays, fog, radii, paint API |
| `scripts/systems/sim_system.gd` | Active-chunk growth + war/disaster |
| `scripts/systems/budget_system.gd` | Cash, tax, upkeep |
| `scripts/systems/advisor_system.gd` | Warnings / soft blocks |
| `scripts/systems/tool_system.gd` | Road / RCI / power / water tools |
| `scripts/systems/map_view.gd` | Nearest-neighbor colored tile view |
| `scripts/input/deck_controller.gd` | Deck + keyboard input |
| `scripts/ui/hud.gd` | Cash, advisor, events, FPS |
| `scripts/main.gd` | Slice glue |
| `scenes/main.tscn` | Entry scene |

## Non-goals (slice)

- Per-citizen agents  
- Car traffic / full pathfinding  
- Gamescope dual-stack notes  
- Touching `/workspace/scrap-orbit`  

## License / repo

Ops owns the git repo — this scaffold does not create commits.
