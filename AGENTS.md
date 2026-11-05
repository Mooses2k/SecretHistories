# AGENTS.md - Secret Histories

Rules for AI coding agents working in this repo. Write plain, imperative, short.

## 1. What This Is

This file is the entry point and index for AI agents, not the law.
- [CODE_STYLE.md](CODE_STYLE.md) is the binding code rulebook. On any conflict, CODE_STYLE.md wins.
- [ARCHITECTURE.md](ARCHITECTURE.md) describes what the code IS, derived from the actual codebase, not plans.
- Point at an existing rule instead of restating it. Duplicated rules drift.

## 2. License and Assets

- All code is GPLv3.
- Art and audio keep an adjacent attribution file named `<asset>_license.txt` with four lines: name, author, link, license.
- When reusing external work, in order: (1) reimplement from the idea first; (2) adopt the whole item only with its license intact and notices preserved.
- Unlicensed means reimplement-only. Never paste unlicensed content.
- The owner confirms licenses before an item enters the repo. "If you cannot license it, do not send it."

## 3. Required Reading

Read in this order:
1. [CODE_STYLE.md](CODE_STYLE.md): binding code rules. Why: it wins on conflict.
2. [ARCHITECTURE.md](ARCHITECTURE.md), including its "Current Development Status" section. Why: it says what the code is and what is frozen.
3. [GAME_DESIGN_DOCUMENT.md](GAME_DESIGN_DOCUMENT.md): what the game is supposed to be.
4. [CONTRIBUTING.md](CONTRIBUTING.md): how contributions flow.

Work on a system means reading that system's docs plus the docs of what it depends on.
Planning docs live in the gitignored `/docs/` folder (see section 13).
If a doc and the code disagree, the code wins. Fix the doc or flag the gap; never trust a plan over the actual files.

## 4. Project State

Read [ARCHITECTURE.md](ARCHITECTURE.md) "Current Development Status" before planning anything. Operational facts:

- Character controller and AI work is FROZEN by owner decision (contributor handoff).
- Contributor crazystewie may push controller updates around Nov 8. Expect the freeze to lift or move; do not pre-empt it.
- Do not modify `scenes/characters/character.gd`, `scenes/characters/player_old/`, `scenes/characters/cultists-old/`, or `core/ai` behavior unless the owner explicitly unfreezes them.
- Several features live on unmerged branches (fencing sim, dual-wield/light sources). They are NOT in dev4; do not assume their code exists here.
- `dev4` is the base branch, an in-progress Godot 4.4 port of the released Godot 3.x game (`main`). Feature parity is not complete.
- The issue list at github.com/Mooses2k/SecretHistories/issues is the work list.
- Near-term primary target: functional parity with the 3.x build. Playable to floor 5, crystal grabbed, surface reached, with hostile AI. AI working, animations working, 3.x-era melee working. The fencing sim is the melee-system testbed in service of that target; Act 1 content is later. See /docs/design/owner-todo-dump.md "Near-term target hierarchy".
- The working tree may carry modified and untracked files from other agents or the owner. Do not revert, clean up, or "fix" files you did not touch.

## 5. Hard Rules

Index only; one line each with rationale. Details live in the referenced sections or CODE_STYLE.md.

- NEVER launch Godot through pwsh/bash shell tools. Rationale: it crashes with signal 11 on user:// log writes; use the godot_* bridge tools (section 10).
- NEVER edit files through pwsh or shell redirection. Rationale: Windows PowerShell corrupts UTF-8; use the harness write/edit tools.
- NO em-dashes anywhere in anything written. Rationale: owner taste, enforced as writing habit.
- No tree-wide or mechanical mass edits without an explicit per-operation mandate from the owner. Rationale: bulk edits are unauditable; git reverts do not make them safe.
- Deliver tracked changes in the working tree only. No commits or pushes unless the owner says so. Rationale: the owner controls history.
- Do not invent or commit story or spoiler content. Story plans are owner-secret. Rationale: narrative is the owner's to place.
- Read big .tscn files partially. Rationale: many embed megabytes of mesh data (section 11).
- Edit .tscn files through godot_headless_op or the editor-safe tools; never hand-splice inside embedded mesh blocks.
- Prefer the godot_* management tools over hand-editing project.godot. Rationale: they serialize settings correctly (section 10).
- Every behavioral claim needs fresh evidence. Rationale: see section 9.

## 6. Thinking Discipline

1. Check the request first. Flag broken premises plainly, or ask ONE specific question. Never silently accept a wrong premise.
2. Push back when it matters; comply when it is theirs. Facts and correctness hold under pushback, the owner's included. Agreeable at the cost of correct is a failure.
3. Doubt needs evidence. Reopen a settled conclusion only with a concrete named reason. Vague uncertainty is not a reason.
4. New evidence reopens immediately. Say exactly what changed your mind.
5. Never infer field semantics from a name. Behavior-switch fields need a writer-and-reader inventory before any semantic proposal. A proposal without the inventory is rejected unread.

## 7. Agent Autonomy Tiers

Tiers by blast radius.

- Tier A, self-serve: docs and /docs plans, debug tools, UI scenes, effect wiring. Build it, capture evidence, done.
- Tier B, build then inform: world generation steps, item scripts, sensor work, non-frozen gameplay code. Build and verify; the owner sees the diff afterwards.
- Tier C, design-confirm-first, currently partly frozen: character controller, AI behavior, the Events bus contract, save format, autoload roster, project.godot changes. Bring design plus test plan and get explicit confirmation BEFORE building.

A review pass by another agent never satisfies sign-off. A human approves.

## 8. Parallel Work

- Fan out self-contained subtasks to subagents; keep the orchestrator light. The owner prefers heavy subtasking.
- Batch independent reads and searches in one round.
- Clobber-free: disjoint files only; no two writers on one file.
- Start independent delegations in the same round; collect every result before making final claims.
- Parallelism happens inside phase gates. It never bypasses them (CODE_STYLE.md section 13).

## 9. Verification

Evidence before assertions.
- No completion claims without fresh verification output from this session.
- Inconclusive is never a pass. Report it as inconclusive.
- Evidence is void when its inputs changed afterwards. Re-verify after any change.

Validation ladder, in reliability order:
1. Owner-pasted editor Output errors are ground truth.
2. `godot_validate_script` per file.
3. `godot_run_headless` for a bounded scene or logic run.
4. Driving the running game via `godot_command`.

There is NO unit test suite in this repo yet. Do not pretend there is one. Do not encode known bugs as expected behavior.

Engine API in doubt: check the official stable docs (docs.godotengine.org/en/stable/classes/class_<name>.html) before trusting model memory. Model memory invents plausible-looking API names. Project API in doubt: read the source.
When other agents are mid-edit, verify per-file only; a failure confined to files you do not own is inconclusive, not a regression.

Visual evidence doctrine: screenshots judge looks only. State dumps and printed values are the text truth.
Capture exit codes directly. Console pipes can mislead; a run that produced no report leaves no report.

## 10. Godot Bridge

All Godot interaction goes through the godot_* bridge tools, never a shell.

- `godot_run_project`: starts the game, auto-installs the interaction server. It ADOPTS an instance already answering on the port. It never kills user/editor-launched instances, and neither do you: no Stop-Process, no taskkill.
- `godot_command`: drives the live game. eval, get_scene_tree, get_ui_elements, screenshot, click, key_press, set_property, call_method.
- `godot_run_headless`: the safe batch runner. Always pass --quit-after, or make the script call get_tree().quit().
- `godot_headless_op`: static .tscn/resource surgery. create_scene, add_node, attach_script, read_scene.
- `godot_validate_script`: compiles one GDScript file.
- `godot_set_project_setting`, `godot_manage_autoloads`, `godot_manage_input_map`: edit project.godot safely.
- If a tool reports diagnosis sandbox-crash, the cause is the launch channel. Re-run through the bridge, never through a shell.

## 11. Big Files and Partial Reading

MANDATORY. Many .tscn files embed ArrayMesh data as huge base64 PackedByteArray blocks. Worst offenders:

- `scenes/objects/large_objects/statuary/statue_angel_1.tscn` (~1.65 MB)
- `resources/mesh_libraries/modular_pieces.tscn` (~1.46 MB)
- `scenes/objects/large_objects/statuary/statue_angel_headless_broken.tscn` (~1.45 MB)
- `scenes/objects/pickable_items/equipment/tool/light-sources/belt_clip_dark_lantern/dark_lantern.tscn` (~1.2 MB)
- also votive_candle_stand.tscn, firepit.tscn, bullseye_lantern.tscn, ribcage.tscn

Rules:
- NEVER read these files whole.
- Read the head (~80 lines) and tail (~40 lines). Materials, node setup, collision shapes and signal connections live there.
- Use grep with sub_resource type names to inventory what is inside before deciding to read more.
- Never print or echo these files to chat.
- Long-term fix: link meshes to .glb/.res sources instead of embedding. That is a tracked pipeline objective. Until then, partial reading is the norm.

## 12. Writing Large Files

Anything expected over ~300 lines is authored in sequential blocks:
- First block ends with a sentinel comment (e.g. `# __NEXT_BLOCK__`).
- Then edit-replace the sentinel with the next block. Repeat.

Rationale: a single huge write can time out and lose the work.

## 13. Docs and Storage

The gitignored `/docs/` folder holds working memory; repo-root files are canonical.
- `docs/research/`: research-pass reports.
- `docs/plans/`: implementation and integration plans.
- `docs/design/`: owner design notes.

Before proposing something new, grep /docs for prior gleans so nothing parked or rejected gets re-proposed.
Wiki fix drafts also live in /docs until the owner pastes them to GitHub.
Write research and plan reports as you work, not from memory at the end.

## 14. Environment Notes (this machine)

- Session workspace: C:\Games\GODOT\SecretHistories, branch dev4, in sync with origin/dev4 at session start.
- File sandbox is workspace-write with approval-on-ask. Writes outside the workspace fail; network goes through the web tools, not raw sockets.
- The harness is DSH (DeepSeek Harness). Use harness write/edit tools, not shell redirection.
- Godot is 4.4, launched only via the bridge (section 10).
- Project facts: 13 autoloads, JoltPhysics3D physics, ~40 namespaced input actions (see ARCHITECTURE.md for the systems map).
