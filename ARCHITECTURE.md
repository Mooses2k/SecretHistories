# Secret Histories - Architecture Documentation

## Overview

Secret Histories is a Victorian-era cosmic horror FPS roguelite built in Godot 4.7 (GDScript, JoltPhysics3D), emphasizing systems-driven gameplay over scripted events. The architecture follows a modular design philosophy where every interaction emerges from believable physics and AI behaviors.

**Core Identity**: Victorian-era cosmic horror FPS roguelite with stealth/combat elements  
**Technical Philosophy**: Systems over scripts, emergent gameplay through component interactions  
**License**: Free culture (AGPL-3.0 for code, see LICENSE; art/audio per-asset licenses)

### Current Development Status (dev4)

This document describes the `dev4` branch: an in-progress Godot 4.7 port of the released Godot 3.x game (`main`). Feature parity with `main` is NOT complete; the backlog for parity and everything else lives in the [GitHub issues](https://github.com/Mooses2k/SecretHistories/issues). Known current facts, kept visible on purpose:

- **Character controller development is unfrozen** (owner decision, 2026-11-09: the contributor handoff ended; all controller work is ours). [`scenes/characters/player_controller.gd`](scenes/characters/player/player_controller.gd) and the other player controllers are editable under the normal verification discipline. [`scenes/characters/character.gd`](scenes/characters/character.gd), `scenes/characters/player_old/`, and `scenes/characters/cultists-old/` stay read-only: they are 3.x blueprints, not live code.
- **The AI system is a node-based HFSM.** `core/ai` was rewritten around an HFSM runner (`hfsm.gd`) with a blackboard threat model; the P1 cultist cutover is landed (`scenes/characters/cultist/ai_controller.gd` ticks a `Brain` HFSM at 10 Hz). The old behavior tree files remain in `core/ai`, frozen and pending the P3 deletion gate (they are superseded, not maintained).
- Several features live on **unmerged branches**, not in `dev4`: the "fencing sim" melee demo (`fencing-sim-first-iteration-4dot3` and siblings), and dual-wield/light-source interaction (`light_sources_interaction`).
- Fog/dust weather, room reverb, and the audio library migration (voice lines, footsteps) are wired and live: the atmosphere generation step places fog and dust volumes per room type ([`generate_atmosphere_group.gd`](scenes/worlds/world_gen/generation_steps/populate_room/generate_atmosphere_group.gd)), [`RoomReverbArea`](scenes/effects/room_reverb_area.gd) owns the shared Reverb bus, and [`character_audio.gd`](scenes/characters/character_audio.gd) pulls voicelines and footsteps from [`AudioLibrary`](globals/audio_library.gd).

Planning documents and research notes live in the gitignored `/docs/` folder (local only). Agent-facing process rules live in [AGENTS.md](AGENTS.md).

## High-Level Architecture

```mermaid
graph TB
    subgraph "Core Systems"
        GM[GameManager<br/>Global State]
        Game[Game<br/>Main Controller]
        Events[Events<br/>Event Bus]
    end
    
    subgraph "World Systems"
        WG[World Generation<br/>Procedural Levels]
        GW[GameWorld<br/>Level Instance]
        Nav[Navigation<br/>Runtime Navmesh]
    end
    
    subgraph "Character Systems"
        Player[Player<br/>HumanoidCharacter]
        AI[AI System<br/>HFSM States]
        Inv[Inventory<br/>Equipment Management]
    end
    
    subgraph "Interaction Systems"
        Physics[Physics<br/>Rigid Bodies]
        Light[Light Detection<br/>Stealth Mechanics]
        Sound[Sound Propagation<br/>Audio Cues]
    end
    
    GM --> Game
    Game --> GW
    Game --> Player
    Events --> Game
    Events --> AI
    WG --> GW
    GW --> Nav
    Player --> Inv
    Player --> Physics
    AI --> Physics
    AI --> Light
    AI --> Sound
```

## Core Game Systems

### 1. Game Management System

**Location**: [`globals/game_manager.gd`](globals/game_manager.gd), [`scenes/game.gd`](scenes/game.gd)

The game management system handles the overall game state and flow:

- **GameManager**: Global singleton managing screen filters, acts/chapters, player death state, and world generation RNG
- **Game**: Main game controller managing level loading, player spawning, and floor transitions
- **Floor System**: 5-level dungeon structure (floors -1 to -5) with increasing size and complexity

**Key Features**:
- Floor-based progression with persistent level data via [`FloorLevelHandler`](scenes/worlds/floor_level_handler.gd)
- Dynamic level loading/unloading for memory management
- Staircase-based navigation between floors
- Victory condition: reaching surface with [`ShardOfTheComet`](scenes/objects/pickable_items/equipment/strange_devices/comet_shard/comet_shard.gd)

### 2. AI System (Node-Based HFSM)

**Location**: [`core/ai/`](core/ai/), [`scenes/characters/cultist/ai_controller.gd`](scenes/characters/cultist/ai_controller.gd)

The live AI system is a node-based hierarchical finite state machine (HFSM). Each state is a node in the machine's subtree; the machine evaluates the active state's transition table every tick in declared priority order, so a fresh stimulus interrupts the current action on the next tick instead of waiting for it to finish.

**Core Components**:
- [`HFSM`](core/ai/hfsm.gd): The runner. Holds child state nodes, evaluates transitions every tick, switches by exit-then-enter, and ticks the blackboard on the root machine. Nested sub-machines count as one state of their parent.
- [`Blackboard`](core/ai/blackboard.gd): The creature's world model: an alertness scalar, per-object percepts, the current target, and the threat model that maps stimuli onto alertness. Stimulus weights: SIGHT/SOUND/TOUCH 1.0, LIGHT/INTERACT 0.5. Alertness decays after the 5 s attention span lapses. Sight of a Player floors alertness at the combat bar and names the target. The `target` field is the save compatibility surface: `SaveManager`'s `ai_state.target` capture and restore read it unchanged.
- [`AIState`](core/ai/ai_state_node.gd): Base class for states; declares transitions (to-state plus guard) and publishes movement/facing intents the controller copies into the character.
- State set ([`core/ai/states/`](core/ai/states/)): Idle, Patrol, Suspicious, Investigate, Combat (sub-machine: Approach, GunAttack, MeleeAttack), Flee, Dead.
- Adapters: [`StimulusAdapter`](core/ai/stimulus_adapter.gd) feeds sensor events onto the blackboard, [`NavigationAdapter`](core/ai/navigation_adapter.gd) wraps the NavigationAgent3D and world data, [`AnimationBridge`](core/ai/animation_bridge.gd) maps machine state to animation events (it never forwards `attack_cut`/`attack_thrust`; the melee item fires its own one-shots).

**Wiring**: [`AIController`](scenes/characters/cultist/ai_controller.gd) in the cultist scene owns the blackboard (exposed as `ai_state` for save compatibility), ticks the Brain HFSM from a 10 Hz TickTimer, injects mainhand equipment into the attack states, and copies movement/facing intents into the character input every physics frame.

**Legacy BT (frozen, pending deletion)**: the old behavior tree implementation (`bt_root.gd`, `bt_node.gd`, flow/gun/interest/misc nodes, `InterestMachine`) is still in `core/ai` but superseded by the HFSM. It is frozen until the P3 deletion gate removes it after the parity/supersession check. Do not extend it; new AI behavior means a new [`AIState`](core/ai/ai_state_node.gd) in the HFSM.

### 3. Character System

**Location**: [`scenes/characters/`](scenes/characters/)

The character system provides a unified framework for both player and NPCs:

**Base Classes**:
- [`HumanoidCharacter`](scenes/characters/humanoid_character_base/humanoid_character.gd): Physics-based character controller using RigidBody3D
- [`Character`](scenes/characters/character.gd): Legacy CharacterBody3D-based character (being phased out)
- [`Player`](scenes/characters/player/player.gd): Player-specific extensions

**Character Components**:
- [`HumanoidCharacterInput`](scenes/characters/humanoid_character_base/humanoid_character_input.gd): Input handling
- [`HumanoidCharacterState`](scenes/characters/humanoid_character_base/humanoid_character_state.gd): Character state management
- [`HumanoidCharacterParameters`](scenes/characters/humanoid_character_base/humanoid_character_parameters.gd): Character configuration
- [`CharacterCollision`](scenes/characters/humanoid_character_base/character_collision.gd): Dynamic collision handling
- [`Inventory`](scenes/characters/inventory.gd): Equipment and item management

**Player controller components** ([`scenes/characters/player/`](scenes/characters/player/)): [`player.gd`](scenes/characters/player/player.gd) plus dedicated controller nodes: [`player_controller.gd`](scenes/characters/player/player_controller.gd), [`interact_controller.gd`](scenes/characters/player/interact_controller.gd), [`item_controller.gd`](scenes/characters/player/item_controller.gd), [`inventory_controller.gd`](scenes/characters/player/inventory_controller.gd), [`throw_place_controller.gd`](scenes/characters/player/throw_place_controller.gd), [`pickup_resolver.gd`](scenes/characters/player/pickup_resolver.gd), plus the death cam ([`death_cam.gd`](scenes/characters/player/death_cam.gd), issue #414) and the runtime-mounted camera stress shake ([`camera_stress_shake.gd`](scenes/characters/player/camera_stress_shake.gd), mounted from [`humanoid_character.gd`](scenes/characters/humanoid_character_base/humanoid_character.gd) `_ready` by `load()` so no class cache dependency).

**Key Features**:
- Physics-based movement with ground detection and slope handling
- Dynamic crouching and stamina system
- Integrated inventory system with equipment slots
- Kick mechanics for environmental interaction
- Death flow: the death cam mounts the FPS camera to the head bone and the death screen runs the ragdoll window ([`death_screen.gd`](scenes/ui/death_screen.gd))

**Legacy trees (read-only 3.x blueprints, not live code)**:
- [`character.gd`](scenes/characters/character.gd): previous-generation CharacterBody3D character. Kept as the 3.x reference blueprint. New enemies extend [`HumanoidCharacter`](scenes/characters/humanoid_character_base/humanoid_character.gd), not this.
- [`player_old/`](scenes/characters/player_old/) and [`cultists-old/`](scenes/characters/cultists-old/): pre-refactor player and enemy scenes/scripts, kept for reference and asset recovery only.
- [`undead/`](scenes/characters/undead/): revenant and ghost prototypes (Act 1 content), parked until Act 1; not wired into world generation.

### 4. World Generation System

**Location**: [`scenes/worlds/world_gen/`](scenes/worlds/world_gen/), [`scenes/worlds/procedural_world/`](scenes/worlds/procedural_world/)

The world generation system creates procedural levels while maintaining a hand-crafted feel:

**Core Components**:
- [`GenerationManager`](scenes/worlds/world_gen/generation_steps/generation_manager.gd): Orchestrates generation pipeline
- [`GenerationStep`](scenes/worlds/world_gen/generation_steps/generation_step.gd): Base class for generation phases
- [`RoomData`](scenes/worlds/world_gen/helper_objects/room_data.gd): Room definitions and metadata
- [`RoomPurpose`](scenes/worlds/world_gen/helper_objects/room_purposes/room_purpose.gd): Room functionality definitions

**Generation Pipeline**:
1. **Room Layout**: Generate room positions and connections
2. **Room Assignment**: Assign purposes based on requirements
3. **Population**: Spawn objects, items, and characters
4. **Navigation**: Generate runtime navmesh for AI pathfinding

**Room System**:
- [`RoomRequirements`](scenes/worlds/world_gen/helper_objects/room_requirements/room_requirements.gd): Size, doorway, and feature requirements
- Purpose-driven room generation (staircases, storage, combat areas)
- Modular grid-based design (1.5m² base unit for OSR D&D compatibility)

### 5. Item and Equipment System

**Location**: [`scenes/objects/pickable_items/`](scenes/objects/pickable_items/)

The item system provides a hierarchical equipment framework:

**Item Hierarchy**:
```
PickableItem (base)
├── TinyItem (ammunition, keys, small tools)
├── EquipmentItem (wearable/usable items)
│   ├── MeleeItem (sabre, dagger, hatchet, mace, halberd, crowbar, ...)
│   ├── GunItem (firearms with period-appropriate complexity)
│   │   └── RevolverItem (Webley; double/single-action trigger logic)
│   ├── ToolItem (locks, utility items)
│   │   ├── LanternItem / CandelabraItem (light sources)
│   │   └── PadlockItem
│   ├── ConsumableItem (potions, medical supplies)
│   │   ├── BombItem / Dynamite / Grenade (throwables; wired explosions: impulse pass, damage, camera stress, Reverb-bus audio)
│   │   └── MedicalItem / PotionItem
│   ├── DisposableLightItem (candles, torches; burn down and die)
│   ├── ContainerItem (bags, boxes, storage)
│   ├── StrangeDevice (supernatural items)
│   └── WritingItem (books, notes, documents)
```

Special cases: `EmptyHand` (bare-hand pseudo-item) and `ShardOfTheComet` (victory-condition item).

**Key Features**:
- Physics-based item interaction
- Equipment slots with hand-specific assignments
- Item size taxonomy (tiny/small/medium/bulky/large) driving carry and hotbar capacity (10 + bulky in the main game)
- Victorian-era weapon complexity (optional Receiver-style mechanics; realistic shell ejection is a settings toggle read by [`gun_item.gd`](scenes/objects/pickable_items/equipment/ranged/gun_item.gd) through `GameSettings`)
- Light sources as both tools and stealth mechanics
- Throwables explode through a two-pass blast ([`explosions.gd`](scenes/effects/explosion/explosions.gd)): a character-first impulse pass applies knockback before the damage rays can ragdoll a body, then deduplicated rays apply distance-falloff damage to Hurtboxes and bludgeoning damage to large rigid bodies. A player inside the blast radius gets `add_stress(0.5)` on the runtime-mounted camera stress shake ([`bomb.gd`](scenes/objects/pickable_items/equipment/consumable/bomb/bomb.gd), reached duck-typed because the stress-shake script is mounted by `load()`). Explosion audio rides the shared Reverb bus.

### 6. Interaction Systems

**Location**: [`scenes/sensors/`](scenes/sensors/), [`scenes/objects/interactables/`](scenes/objects/interactables/)

The interaction system handles player-world communication:

**Sensor System**:
- [`CharacterSense`](scenes/sensors/character_sense.gd): Base sensor class
- [`VisualSensor`](scenes/sensors/visual_sensor.gd): Line-of-sight detection
- [`SoundSensor`](scenes/sensors/sound_sensor.gd): Audio-based detection
- [`TouchSensor`](scenes/sensors/touch_sensor.gd): Physical contact detection
- [`LightArea`](scenes/sensors/light_detection/light_area/light_area.gd): Light-based stealth mechanics

**Interaction Framework**:
- [`Interactable`](scenes/objects/interactables/interactable.gd): Base interactable object
- Physics-based interactions through RigidBody3D
- Environmental storytelling through evidence and clues

## Folder Structure

### Root Level Organization

```
SecretHistories/
├── core/                      # Core game systems (currently: the AI HFSM + legacy BT)
├── globals/                   # Global singletons and autoloads
├── resources/                 # Game assets (art, audio, models, etc.)
├── scenes/                    # Game scenes and prefabs
├── script_templates/          # Custom GDScript templates
└── utils/                     # Utility scripts and debug tools

Root project files: project.godot, default_bus_layout.tres (audio buses),
default_env.tres (project default environment resource), debug.tres,
export_presets.cfg, and the root documentation (ARCHITECTURE.md, CODE_STYLE.md,
AGENTS.md, GAME_DESIGN_DOCUMENT.md, CONTRIBUTING.md).
```

### Core Systems (`core/`)

```
core/
└── ai/                        # AI: live HFSM system plus the legacy behavior tree
    ├── hfsm.gd, ai_state_node.gd, blackboard.gd   # HFSM runner, state base, threat model
    ├── states/               # HFSM states (idle, patrol, suspicious, investigate, combat, flee, dead)
    ├── stimulus_adapter.gd, navigation_adapter.gd # sensor/blackboard and navigation adapters
    ├── animation_bridge.gd   # state-to-animation event mapping
    ├── bt_*.gd, flow_nodes/, gun_nodes/, interest_nodes/, misc_nodes/   # legacy behavior tree (frozen, pending P3 deletion)
    ├── debug/                # AI debugging tools (HFSM transition log, debug viz)
    └── phold_icons/          # Placeholder icons for editor
```

### Global Systems (`globals/`)

```
globals/
├── events.gd                 # Event bus autoload for decoupled communication
├── game_manager.gd           # Global game state management
├── save_manager.gd           # Save/load pipeline, including cultist ai_state capture
├── global_consts.gd          # Game-wide constants
├── groups.gd                 # Node group definitions
├── keybinding_manager.gd     # Input mapping system
├── audio_library.gd          # Central audio stream catalog (voicelines, footsteps, sounds)
├── load_*.gd                 # Loading utilities (quotes, scenes)
├── settings*.gd              # Settings system and persistence
└── settings/                 # Per-domain settings managers
    ├── game_settings.gd
    ├── input_settings.gd
    ├── audio_settings.gd
    ├── video_settings.gd
    └── key_input_settings.gd
```

**Autoloads** (16): GameManager, Events, Settings, SettingsConfig, LoadQuotes, LoadScene, KeybindingManager, AudioLibrary, SaveManager, the five `settings/` managers, and BackgroundMusic (the one scene-based autoload, `scenes/effects/background_music.tscn`). Plus `McpInteractionServer` (`autoload/mcp_interaction_server.gd`), the agent-bridge debug autoload; it is tooling, not game state.

### Game Scenes (`scenes/`)

```
scenes/
├── characters/               # Character-related scenes and scripts
│   ├── humanoid_character_base/  # Base humanoid character system
│   ├── player/               # Player-specific implementations (active controller)
│   ├── cultist/              # Enemy character implementations (active)
│   ├── undead/               # Undead enemy prototypes (not yet wired into generation)
│   ├── skeleton_modifiers/   # IK and animation systems
│   ├── player_old/, cultists-old/  # Frozen pre-refactor trees (reference only)
│   └── *.gd                  # Character utilities (inventory, audio, etc.)
├── audio/                    # Impact audio manager (item impact sounds)
├── effects/                  # Visual and particle effects
│   ├── explosion/            # Explosion particles + blast logic
│   └── *_audio.gd            # Per-weapon auto-free audio wrappers
├── objects/                  # Interactive world objects
│   ├── interactables/        # Base interactable system
│   ├── large_objects/        # Furniture, doors, statues, decorations
│   └── pickable_items/       # Item hierarchy and implementations
├── screen_filters/           # Fullscreen post-process filters (GameManager.ScreenFilter)
├── sensors/                  # Detection and sensing systems
├── ui/                       # User interface components (hotbar/, opening_screens, ...)
└── worlds/                   # World and level systems
    ├── procedural_world/     # Procedural generation implementation
    ├── world_gen/            # Generation pipeline and tools
    ├── gridmaps/             # GridMap-based level assembly data
    └── *.gd                  # World utilities (floor_level_handler.gd, ...)
```

### Resources (`resources/`)

```
resources/
├── animations/              # Character and object animations
├── art/                     # 2D artwork and textures
│   ├── game_intro/         # Intro sequence artwork
│   ├── health/             # UI health indicators
│   ├── opening_screens/    # Menu and loading screens
│   └── player ui/          # Player interface elements
├── effects/                 # Particle effects and shaders
├── fonts/                   # Typography resources
├── inventory/               # Item icons and UI elements
├── mesh_libraries/          # Reusable mesh collections
├── models/                  # 3D models organized by category
│   ├── characters/         # Character models and rigs
│   ├── gridmap/            # Modular level pieces
│   ├── items/              # Item models by type
│   └── large_objects/      # Furniture and decoration models
└── shaders/                 # Custom shader implementations
```

### Utilities (`utils/`)

```
utils/
├── debug_scenes/            # Debug and testing scenes
├── tool/                    # Editor tools and utilities
└── *.gd                     # Utility scripts and helpers
```

## System Interactions and Data Flow

### Game Flow Architecture

```mermaid
sequenceDiagram
    participant GM as GameManager
    participant G as Game
    participant WG as WorldGen
    participant P as Player
    participant AI as AI System
    participant E as Events

    GM->>G: Initialize game
    G->>WG: Generate level
    WG->>G: Level ready
    G->>P: Spawn player
    G->>E: Connect staircase events
    
    loop Game Loop
        P->>AI: Player actions affect AI
        AI->>P: AI responds to player
        P->>E: Use staircase
        E->>G: Floor change request
        G->>WG: Generate new floor
        G->>P: Reposition player
    end
```

### AI Decision Flow

```mermaid
graph TD
    A[TickTimer 10 Hz] --> B[Blackboard Tick: stimuli, decay, percept aging]
    B --> C[Evaluate Active State Transitions in Priority Order]
    C --> D{Guard Passes?}
    D -->|Yes| E[Exit Current State, Enter Next]
    D -->|No| F[Tick Active State: intents, actions]
    E --> F
    F --> G[Controller Copies Movement/Facing Intent]
    G --> A
```

### Equipment System Flow

```mermaid
graph LR
    A[Player Input] --> B[Inventory System]
    B --> C{Equipment Type}
    C -->|Weapon| D[Combat System]
    C -->|Tool| E[Utility System]
    C -->|Light| F[Stealth System]
    D --> G[Physics Interaction]
    E --> G
    F --> H[AI Detection]
    G --> I[World State Change]
    H --> I
```

## Coding Patterns and Conventions

### Architecture Patterns

1. **Component-Based Design**: Characters use composition with separate components for input, state, parameters, and collision
2. **Event-Driven Communication**: [`Events`](globals/events.gd) singleton provides decoupled system communication
3. **Node-Based HFSM**: AI states are tree nodes with per-state transition tables, evaluated every tick so new stimuli interrupt mid-action
4. **Physics-First**: All interactions use Godot's physics system for emergent gameplay
5. **Resource-Based Configuration**: Extensive use of Godot resources for data-driven design

### Code Style Guidelines

Following [`CODE_STYLE.md`](CODE_STYLE.md):

- **Naming**: snake_case for files/functions, PascalCase for classes, CONSTANT_CASE for constants
- **Typing**: Static typing with `var name: Type` or `:=` inference
- **Structure**: Modular, extensible, maintainable code with clear separation of concerns
- **Comments**: `##` for documentation, `#` for regular comments

### Common Patterns

**Singleton Pattern**: Global systems use autoload singletons
```gdscript
# globals/game_manager.gd
extends Node
var game: Game
```

**Component Pattern**: Character systems use composition
```gdscript
# HumanoidCharacter components
@onready var parameters: HumanoidCharacterParameters = $Parameters
@onready var state: HumanoidCharacterState = $State
@onready var input: HumanoidCharacterInput = $Input
```

**Observer Pattern**: Event bus for decoupled communication
```gdscript
# globals/events.gd: declare the signal on the bus
signal up_staircase_used

# Emitting (Godot 4 call syntax)
Events.up_staircase_used.emit()

# Connecting: use the bus helpers (idempotent, duplicate-connect guarded)
Events.connect_to("up_staircase_used", self, "_on_staircase_used")
Events.disconnect_from("up_staircase_used", self, "_on_staircase_used")
```

## Development Guidelines

### Adding New Content

**New Enemy Types**:
1. Extend [`HumanoidCharacter`](scenes/characters/humanoid_character_base/humanoid_character.gd)
2. Author an HFSM brain: state nodes under a `Brain` [`HFSM`](core/ai/hfsm.gd), wired by an [`AIController`](scenes/characters/cultist/ai_controller.gd) like the cultist's
3. Add character-specific sensors in [`scenes/sensors/`](scenes/sensors/)
4. Configure spawn data in [`scenes/worlds/procedural_world/`](scenes/worlds/procedural_world/)

**New Items**:
1. Choose appropriate base class from item hierarchy
2. Create 3D model and place in [`resources/models/items/`](resources/models/items/)
3. Implement item-specific behavior (combat, utility, etc.)
4. Add to spawn lists in world generation system

**New Room Types**:
1. Create [`RoomPurpose`](scenes/worlds/world_gen/helper_objects/room_purposes/room_purpose.gd) resource
2. Define [`RoomRequirements`](scenes/worlds/world_gen/helper_objects/room_requirements/room_requirements.gd)
3. Add population logic to generation pipeline
4. Create modular pieces in [`resources/models/gridmap/`](resources/models/gridmap/)

### Performance Considerations

- **Level Streaming**: Use [`FloorLevelHandler`](scenes/worlds/floor_level_handler.gd) for memory management
- **AI Optimization**: The HFSM ticks at 10 Hz from a TickTimer; movement intent applies every physics frame
- **Physics Optimization**: Use appropriate collision layers and RigidBody3D sleep states
- **Rendering**: Implement visibility culling and LOD systems for large levels

### Debugging Tools

- **AI Debug View**: [`ai_debug_view.gd`](core/ai/debug/ai_debug_view.gd) for HFSM transition logs, alertness, and blackboard state
- **Debug Scenes**: [`utils/debug_scenes/`](utils/debug_scenes/) for isolated testing
- **Room Graph Visualization**: [`room_graph_viz.gd`](utils/debug_scenes/room_graph_viz/room_graph_viz.gd) for level layout debugging

### Extension Points

The architecture supports several extension points for modding and additional content:

1. **HFSM States**: Add new AI behaviors by adding [`AIState`](core/ai/ai_state_node.gd) nodes and declaring transitions on the owning controller
2. **Generation Steps**: Extend [`GenerationStep`](scenes/worlds/world_gen/generation_steps/generation_step.gd) for custom world generation
3. **Item Types**: Extend the item hierarchy for new equipment categories
4. **Sensor Types**: Create new detection systems by extending [`CharacterSense`](scenes/sensors/character_sense.gd)
5. **Effect System**: Add visual effects using [`Effect`](scenes/effects/effects.gd) base class

## Technical Specifications

- **Engine**: Godot 4.7 (see project.godot config/features)
- **Language**: GDScript with static typing (no C#)
- **Physics**: JoltPhysics3D; RigidBody3D-based character controller
- **Collision Layers**: 11 named layers (World, Player, PlayerHurtbox, EnemyHurtbox, Enemy, SoftCollisions, ItemDrops, ItemDropsSoftCollisions, Portals, Interactables, Light)
- **Input**: ~48 defined input actions, most namespaced (`movement|move_up`, `player|interact`, `playerhand|mainhand_use`, `itm|next_hotbar_item`, `ablty|...`, `com|...`, `misc|...`), plus `hotbar_1..10`, `debug_*` cheats, and legacy unbound `kick`/`interact`/`ads`
- **AI**: Node-based HFSM with a blackboard threat model (legacy BT files frozen pending P3 deletion)
- **World**: Procedural generation with runtime navmesh
- **Grid Unit**: 1.5m² (compatible with OSR D&D systems)
- **Target Platforms**: PC (Linux, Windows, macOS)

## Future Architecture Considerations

- **Multiplayer**: Co-op support planned with shared vulnerability mechanics
- **Modding Support**: OSR D&D and fantasy/sci-fi genre expansion
- **Performance Scaling**: Large dungeon optimization for deeper floors
- **Save System**: Persistent world state and knowledge progression (SaveManager autoload and the cultist `ai_state` capture already live)
- **Effect System Consolidation**: One parameterized pipeline for explosion/gunsmoke/fire/fog/dust/impacts (issue #169); fog and dust are wired into generation via the atmosphere step, the rest of the consolidation is open
- **Parked to Act 1** (owner ruling): the undead revenant/ghost prototypes, keys/locks, gravel/dirt piles
- **Scene/Mesh Hygiene**: Stop embedding mesh data in .tscn files; link .glb/.res sources instead (statues, candelabra, and lantern scenes are the worst offenders, some over 1 MB each)

---

*This document serves as the primary architectural reference for Secret Histories development. Keep it updated as systems evolve and new components are added.*