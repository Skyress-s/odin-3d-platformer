# Platformer - Project Overview

A 3D platformer game written in **Odin** featuring a grappling hook mechanic, physics-based movement, an in-game level editor, and speedrun timing. Uses **Raylib** for graphics/windowing.

## Quick Start

```bash
# Build and run (debug mode)
odin run src/ -debug

# Build only
odin build src/ -target:windows_amd64
odin build src/ -target:linux_amd64
```

Entry point: `src/main.odin`

## Directory Structure

```
src/
├── main.odin                 # Application entry point
├── game/                     # Main game loop & update logic
├── game_state/               # Game flags, cheat settings
├── global_context/           # Central struct holding all global state
├── Character/                # Player state machine, grappling hook, speedrun timer
├── players/                  # Player mode management (Game/Editor)
├── player_data/              # Look direction/orientation
├── camera/                   # Camera system with FOV interpolation
│
├── Physics/
│   ├── verlet/               # Velocity Verlet (leapfrog) integration
│   └── collision_channel/    # Collision channel bitflags
│
├── Spatial/                  # Spatial hash grid, collision detection
│   ├── Spatial.odin          # Core: hash grid, collision objects, ray/triangle
│   ├── collision_triangle.odin
│   ├── sphere_trace.odin     # Continuous collision (sphere sweep)
│   └── transform.odin        # TRS transform utilities
│
├── ui/
│   ├── clay-odin/            # Clay UI library bindings
│   ├── layout/               # Custom tiling/docking window system
│   ├── layout2/              # Alternative layout implementation
│   ├── game_ui/              # Game-specific UI widgets
│   └── raylib/               # Raylib UI renderer
├── micro-ui/                 # microui-based immediate mode UI
│
├── editor/                   # Editor tools (transform gizmos)
├── editor_player/            # Free-fly camera for editor mode
│
├── render/                   # 3D rendering pipeline
├── lightray/                 # Phong lighting system
├── debug_draw_utils/         # Debug visualization (spheres, lines, etc.)
│
├── level/                    # Level data structure
├── serialization/            # JSON level save/load
│
├── handle_map*/              # Handle-based maps (3 variants for different use cases)
├── input/                    # Input abstraction layer
├── logging/                  # Logging utilities
└── color/                    # Color utilities

content/
├── levels/                   # Level files (.map JSON format)
├── resources/                # Game assets
└── shaders/                  # GLSL shaders (lighting, editor depth)

resources/                    # Font files (.ttf)
```

## Architecture

### Core Systems

**Global Context** (`src/global_context/main.odin`)
Central container holding pointers to all major subsystems:
- Players, game state, current level
- Camera state, UI root node
- Mouse-over-game flag

**Game Loop** (`src/game/game.odin`)
Main update function handling:
- Game/Editor mode switching (press `Q` to toggle editor)
- Input processing
- Physics updates
- Rendering dispatch

### Physics System

- **Spatial Hash Grid**: 128-meter cells for broad-phase collision
- **Verlet Integration**: Velocity Verlet (leapfrog) for physics simulation
- **Sphere Trace**: Continuous collision detection via sphere sweeps
- **Collision Channels**: Bitflags for filtering (blocking, trigger, grappable)

Key files:
- `src/Spatial/Spatial.odin` - Hash grid, collision objects
- `src/Physics/verlet/verlet.odin` - Physics integration

### UI System

Dual-system approach:
1. **Clay** (`src/ui/clay-odin/`) - Cross-platform layout library
2. **Custom Tiling** (`src/ui/layout/`) - Dockable window system built on top

Also includes microui (`src/micro-ui/`) for immediate-mode UI needs.

### Player Character

State machine with two primary states:
- `Grounded` - On surface, normal movement
- `Airborne` - In air, grappling hook available

Grappling hook attaches to surfaces marked "grappable" in the level data.

### Level System

Levels contain:
- Collision geometry (via handle map)
- Spatial hash grid
- Special volumes: finish zones, kill zones, grappable surfaces
- Start position, look direction, velocity
- Author best time

Serialized as JSON (`.map` files in `content/levels/`).

### Editor Mode

Press `Q` to enter editor mode:
- Free-fly camera (`src/editor_player/`)
- Transform gizmos: translate, rotate, scale (`src/editor/tools/`)
- Load/save levels

## Key Data Structures

```odin
// Central state container
Global_Context :: struct {
    players:             ^Players,
    game_state:          ^Game_State,
    current_level:       ^Level,
    camera_state:        camera.Global_State,
    root_node_tiling_ui: ^layout.Tiling_Node,
    mouse_over_game:     bool,
}

// Level data
Level :: struct {
    name:                 string,
    collision_object_map: Collision_Object_Handle_Map,
    spatial_hash_grid:    Spatial_Hash_Grid,
    finish_volumes:       map[Collision_Object_Id]bool,
    kill_volumes:         map[Collision_Object_Id]bool,
    grappable:            map[Collision_Object_Id]bool,
    start_position, start_look_direction, start_velocity: Vector,
    author_time:          f64,
}

// Player character
CharacternData :: struct {
    current_state:       State,  // Grounded | Airborne
    hooked_position:     Vector,
    is_hooked:           bool,
    verlet_component:    Velocity_Verlet_Component,
    look_angles:         Player_Look_Data,
    radius:              f32,
    speedrun_stop_watch: time.Stopwatch,
    best_time:           f64,
}
```

## Dependencies

| Library | Import Path | Purpose |
|---------|-------------|---------|
| Raylib | `vendor:raylib` | Graphics, windowing, input |
| rlgl | `vendor:raylib/rlgl` | Low-level OpenGL |
| microui | `vendor:microui` | Immediate-mode UI |
| Clay | Local (`clay-odin/`) | Cross-platform UI |

## Conventions

- **Package-per-directory**: Each `src/` subdirectory is its own Odin package
- **Handle-based references**: Objects use handles (index + generation) not raw pointers
- **Deferred cleanup**: Uses Odin's `defer` for resource management
- **Debug mode**: `ODIN_DEBUG` enables tracking allocator for leak detection

## Game Features

- Grappling hook with rope physics
- Speedrun timer (per-run and best-time)
- In-game level editor with transform gizmos
- Kill/finish trigger volumes
- Phong lighting with directional/point lights
