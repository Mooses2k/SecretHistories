# CODE_STYLE.md

Binding code rulebook for Secret Histories. AGENTS.md indexes this file and defers to it on conflict. Every rule applies to agents and humans alike.

## 1. Scope and Authority

- This file is the canonical, binding rulebook for all GDScript in this repo. AGENTS.md is an index, not the law. On conflict, this file wins.
- All rules apply to all new code. Do not retroactively sweep existing files unless the owner explicitly mandates it.
- Consistency with existing sibling files beats personal taste, but new code follows this document.

## 2. Language and Runtime

- GDScript only for game logic. No C#.
- Godot 4.7-stable (owner instruction: track Godot latest).
- The Resource system owns data: entities, items, save data live in `.tres` resources.
- JoltPhysics3D is the physics engine. Do not change it or "clean up" its settings without owner sign-off.

## 3. Formatting

- Tabs for indentation, never spaces.
- Lines under 100 characters, prefer 80.
- Trailing commas in arrays, dictionaries, enums.
- 2 blank lines between functions and classes, and after `class_name`/`extends`.
- One statement per line, except the ternary operator.
- Parentheses around multiline expressions.
- A space before and after arithmetic operators (`2 * 2`, not `2*2`).
- UTF-8 encoding, LF line endings.
- Prefer `and`/`or`/`not` over `&&`/`||`/`!`. Double quotes for strings. Leading and trailing zeros in floats (`0.5`, not `.5`). Underscores in large numbers (`1_000_000`).

## 4. Naming

- Files and scripts: snake_case.
- Classes and nodes: PascalCase.
- Functions and variables: snake_case.
- Signals: past tense, snake_case (`target_hit`, not `hit_target`).
- Constants and enum members: CONSTANT_CASE. Enums: PascalCase.
- Private members: underscore prefix (`_private_var`).
- No milestone or ephemeral names in identifiers or comments ("dev4 pass 2 rewrite" tells nobody anything in a year).
- No em-dashes anywhere: code, comments, docs. Use commas, colons, or periods.
- Comment what IS, not what WAS. No history comments.

## 5. Classes and Autoloads

- `class_name` is PascalCase and matches the file's logical name.
- Never put `class_name` on autoload scripts going forward. The autoload name registered in project.godot is the global identifier; adding a class_name creates a second name for one thing. Do not sweep the existing offenders.
- Access autoloads by their registered name (`Events.foo_signal.emit(...)`), not through `get_node("/root/Events")` chains.
- `Engine.has_singleton()` does NOT detect autoloads (it only sees GDExtension singletons). Just reference autoloads directly.
- The repo has 16 autoloads (one is the agent-bridge debug autoload), listed in ARCHITECTURE.md. Adding a new one is an owner decision, not a reflex.

## 6. Typing Discipline

- Static typing everywhere possible. Typed arrays (`Array[String]`), typed dicts where practical.
- ALWAYS declare a return type, including `-> void`. `-> Variant` only when truly dynamic.
- Treat inference-on-Variant as an error. Never write `var x := <call returning Variant>`. This includes `Dictionary.get()`, `get_script()`, `JSON.parse_string()`, and element access on untyped collections. Annotate the type or cast. `:=` is only for concrete typed returns.

```gdscript
# WRONG: infers Variant
var name := item_data.get("name")
# RIGHT: annotate or cast
var name: String = item_data.get("name", "")
```

- CRITICAL trap: a Dictionary value is a Variant and CANNOT be assigned directly to a typed-array variable (it crashes). Iterate and cast element by element. Every `from_dict()` writing into typed containers must do this.

```gdscript
# WRONG: crashes
var tags: Array[String] = entry.get("tags")
# RIGHT: cast element by element
var tags: Array[String] = []
for raw in entry.get("tags", []):
    tags.append(str(raw))
```

- `String.split()` returns `PackedStringArray`, not `Array[String]`.
- `sort_custom` comparators return `bool`, not `int`.
- GDScript has Null, not Nil.
- Exports get explicit types. Untyped `@export var ammunition_capacity = 0` is a defect.

## 7. Signals and Events

- Declare signals with typed parameters:

```gdscript
signal target_hit(target: Node3D, damage: int)
```

- Cross-system communication goes through the Events autoload event bus (`globals/events.gd`, gdquest pattern). Local intra-node signals live on the node.

```gdscript
# Connect with a named handler; disconnect in _exit_tree.
func _ready() -> void:
    Events.connect_to("night_started", _on_night_started)

func _exit_tree() -> void:
    Events.disconnect_from("night_started", _on_night_started)

func _on_night_started(day: int) -> void:
    pass
```

- Check the Events catalog before adding a signal. No speculative signals: zero production listeners means delete it on contact.
- One fact, one channel. A second channel for the same event is a defect; consumers migrate to the owner.
- Handlers are named methods disconnected in `_exit_tree`. Never anonymous lambdas; they cannot be disconnected.
- Never emit bus signals from a background thread. Use `call_deferred`.
- Never `await` a signal that may never fire without a timeout or completion flag; the coroutine suspends forever.
- `_ready()` order is not deterministic across platforms and runs. Never depend on a sibling's `_ready()` having run; use `call_deferred`, lifecycle signals, or explicit init ordering.
- Call down, signal up. No Law of Demeter violations: no `A.getB().getC().doThing()`.

## 8. State, Threading, Persistence

- Game-state mutations happen on the main thread only. Async results queue up and get applied in `_process`, a timer, or `call_deferred`.
- No static dictionaries mirroring persistent state. A static var dies with the process, which is a proven defect, not a hypothetical.
- No raw `FileAccess.open()`. All storage goes through the existing load/save pipelines. A new storage path extends the pipeline; it never bypasses it.
- Never pass `res://` paths into native or GDExtension calls. Globalize the path out of the PCK first.
- The main thread never blocks on heavy work: model loads, process spawns, boot-time IO defer or thread with a designed progress surface.

## 9. Nodes and Scenes

- Instantiate scene-backed nodes from their `.tscn` via `preload`/`instantiate()`. Never `.new()` a node that has a scene.
- Call `add_child()` BEFORE setup: `@onready` vars are null until the node is in the tree.

```gdscript
# WRONG: setup() sees null @onready vars
var gun := GunScene.instantiate()
gun.setup(loadout)
add_child(gun)

# RIGHT
var gun := GunScene.instantiate()
add_child(gun)
gun.setup(loadout)
```

- `.tscn` parser gotchas, responsible for most silent load failures:
  - Color values in scene files MUST have all 4 components. A 3-arg Color that is valid in GDScript crashes the parser.
  - `ext_resource` entries for scripts must carry the `.uid`.
- The failure signature is `load()` returning null silently with no console error. When you see it, suspect the scene file, not the script.
- Assets are correct at the asset. A scene or mesh must be authored, exported, or rescaled in its own file so it is final game size with its origin at its base (feet on the floor). Never compensate for a wrong-size or wrong-origin asset at spawn or runtime: no spawn-time scale/offset tables, no per-placement wrapper nodes, no "shrink it when spawning" code. If an asset is wrong, fix the asset file (root transform, mesh instance transform, or re-export), then let every spawn site place it untouched.
  - Rationale: spawn-site corrections multiply silently across every future placement, are invisible at the asset, and turn the asset into a lie that only some code knows about.
  - Exception: dynamic gameplay scaling (a growing creature, a shrink spell) is behavior and lives in code; authoring-time correction is not.

## 10. DRY and Canonical Owners

- Before declaring any constant, table, helper, or vocabulary, grep for an existing owner. A second copy is a defect even when byte-identical; drift is inevitable, and audits prove it bites.
- Do not re-implement a neighbor module's job locally. Before writing a state machine, retry ladder, format parser, or read-loop, check ARCHITECTURE.md for the existing owner.
- Kill dead code on contact. No "keep old code around for safety", no fallbacks to dead systems. Commented-out bodies count.
- Rule of Three is the valve: do not refactor unclear boundaries until the third repetition.
- SOLID applies. "Are you about to tightly couple something? Use a signal."
- Dependency injection via setup parameters. Never tree-walk to find dependencies.
- Data before code: prefer a Resource/`.tres` over a new system; prefer extending an existing system over adding a parallel one.

## 11. Errors and Debugging

- `push_error()` for programming errors. `push_warning()` for recoverable issues.
- Missing lookups return defaults; the game does not crash over a lookup.
- When a lookup fails, trace it with prints at EVERY tier in the chain. That localizes key vs path vs file-on-disk immediately.
- Do not spiral. Stumped means: stop, ask, or add one targeted debug print. Debug prints are cheap; wrong assumptions are expensive.
- Do not ship stray `print()` calls in production paths.

## 12. Comments and File Headers

- `##` for documentation comments, `#` for regular comments, with a space after the marker.
- Do not comment obvious variable names; the name should say it.
- Every NEW file gets a short `##` header block at the top saying what it is.
- No history comments. No "this used to be X".

## 13. Workflow and Process

- Surgical changes only. Every changed line traces to the request. Mention adjacent issues; do not fix them.
- Stop and test after each major phase. Never proceed past an unverified phase.
- 4-phase extraction pattern: (1) create the new thing unwired, (2) wire it and dual-operate, (3) migrate callers, (4) delete the old thing.
- Plans are starting points, not gospel. "Works in the plan" does not mean "works in code". The code is the source of truth; if the planned API does not match it, the plan is wrong.
- If the task creates complexity (a duplicate node, a parallel system), STOP and ask.
- Surface assumptions before implementing. Multiple interpretations: present them, do not pick silently.
- Define verifiable success criteria and loop until they pass.

## 14. UI Craft

- Choose `mouse_filter` deliberately. IGNORE blocks everything, including wheel input.
- Input-carrying Controls raise with `move_to_front()`, not `z_index`.
- Children of a ScrollContainer need `layout_mode` and size flags, or scrolling and resize break.
- Prefer FlowContainer over "+N more" truncation.
- Dictionary flag keys are StringName (`&"flag"`): faster and typo-proof.
- Heavy asset swaps use `ResourceLoader.load_threaded_request()` so transitions never hitch.

## House Rules

- No em-dashes in any file, including this one.
- Code style applies to agents and humans alike.
- When unsure how a rule applies in an existing file, read the sibling files first, then ask.
