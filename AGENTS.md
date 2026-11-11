# AGENTS.md - Secret Histories

Rules for AI coding agents working in this repo. Write plain, imperative, short.

## 1. What This Is

This file is the entry point and index for AI agents, not the law.
- [CODE_STYLE.md](CODE_STYLE.md) is the binding code rulebook. On any conflict, CODE_STYLE.md wins.
- [ARCHITECTURE.md](ARCHITECTURE.md) describes what the code IS, derived from the actual codebase, not plans.
- Point at an existing rule instead of restating it. Duplicated rules drift.

## 2. License and Assets

- Code is AGPL-3.0 (switched from GPLv3; see LICENSE). Art and audio keep per-asset licenses.
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
ALWAYS read GitHub wiki pages via the raw source URL (`https://raw.githubusercontent.com/wiki/<owner>/<repo>/<Page>.md`), never the rendered HTML page: the rendered page truncates the body and buries it in site chrome.

## 4. Project State

Read [ARCHITECTURE.md](ARCHITECTURE.md) "Current Development Status" before planning anything. Operational facts:

- Character controller is unfrozen: contributor crazystewie is no longer working on the project (owner, 2026-11-09), so all controller work is ours. `player_controller.gd` is editable under the same verification discipline as any Tier B file.
- `scenes/characters/character.gd`, `scenes/characters/player_old/`, and `scenes/characters/cultists-old/` stay read-only: they are 3.x blueprints, not live code. `core/ai` behavior-tree files stay frozen until the P3 deletion gate.
- Several features live on unmerged branches (fencing sim, dual-wield/light sources). They are NOT in dev4; do not assume their code exists here.
- `dev4` is the base branch, an in-progress Godot 4.7 port of the released Godot 3.x game (`main`). Feature parity is not complete.
- The issue list at github.com/Mooses2k/SecretHistories/issues is the work list.
- Near-term primary target: functional parity with the 3.x build. Playable to floor 5, crystal grabbed, surface reached, with hostile AI. AI working, animations working, 3.x-era melee working. The fencing sim is the melee-system testbed in service of that target; Act 1 content is later. See /docs/design/owner-todo-dump.md "Near-term target hierarchy".
- KNOWN RISK AREA: inventory and interaction code produced roughly half of all project bugs for a long time. There is a plan to rework it from inheritance into extensible components, and the surrounding code still likely carries bugs; stackables especially. Treat inventory/interaction code as suspect by default; extra verification on any change there.
- DIRECTION: before expanding feature work much further, the owner wants a refactor and bug shakeout of non-character systems, starting with inventory/interaction. GUT tests should not pin broad swaths of existing behavior first: run a full Brooks-style audit first (the owner will supply the audit skill), then let the test suite grow against audited, cleaned code.
- The working tree may carry modified and untracked files from other agents or the owner. Do not revert, clean up, or "fix" files you did not touch.

## 5. Hard Rules

Index only; one line each with rationale. Details live in the referenced sections or CODE_STYLE.md.

- NEVER launch Godot through pwsh/bash shell tools. Rationale: it crashes with signal 11 on user:// log writes; use the godot_* bridge tools (section 10).
- NEVER edit files through pwsh or shell redirection. Rationale: Windows PowerShell corrupts UTF-8; use the harness write/edit tools.
- NO em-dashes anywhere in anything written. Rationale: owner taste, enforced as writing habit.
- No tree-wide or mechanical mass edits without an explicit per-operation mandate from the owner. Rationale: bulk edits are unauditable; git reverts do not make them safe.
- Deliver tracked changes in the working tree only. Ask the owner before EVERY commit; the owner usually verifies each fix first. Rationale: the owner controls history (section 16).
- Do not invent or commit story or spoiler content. Story plans are owner-secret. Rationale: narrative is the owner's to place.
- Read big .tscn files partially. Rationale: many embed megabytes of mesh data (section 11).
- Fix assets at the asset: no spawn-time or runtime scale/origin compensation for wrong-size assets. Rationale: spawn-site hacks multiply and hide the real defect (CODE_STYLE.md section 9).
- Edit .tscn files through godot_headless_op or the editor-safe tools; never hand-splice inside embedded mesh blocks. CAUTION: godot_headless_op add_node/attach_script repacks and resaves the WHOLE scene, which mangles scenes with editable-instance bases (it inlined humanoid_character_base.tscn into player.tscn and stripped uids): for such scenes, prefer careful text edits or runtime (code) attach instead.
- Prefer the godot_* management tools over hand-editing project.godot. Rationale: they serialize settings correctly (section 10).
- Every behavioral claim needs fresh evidence. Rationale: see section 9.
- Any action on github.com requires the owner's explicit approval first, never inferred. Rationale: public actions are outward-facing and cannot be silently trusted (section 15).

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
- Owner decisions can arrive through the owner's DIRECT chat with a subagent, not only through parent relay. Both channels are authoritative. When a message's provenance is unclear, flag it and ask; never treat a possibly-owner message as fabricated without asking first.

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

There is a GUT unit test suite for logic-level tests. Rules: do not encode known bugs as expected behavior. Run it headless via `godot_run_headless` with script `addons/gut/gut_cmdln.gd` and no extra args (it reads `.gutconfig.json`). Tests live in `tests/unit/`, one subject per file, named `test_*.gd` extending GutTest. Scope discipline: per the owner's audit-first direction, tests pin only audited, verified behavior, not broad swaths of unexamined legacy.

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
- Fresh class_name declarations are invisible to headless/runtime loads until the editor regenerates the global class cache. Never reference a newly added class by name from other scripts: load() it or use duck-typed seams.
- **Port-injection defect (upstream godot-bridge):** the game side binds `GODOT_BRIDGE_PORT` from its environment, but a bridge install that does not inject that env var when spawning the game ignores the `port=` parameter of `godot_run_project` (the engine binds a port nobody asked for while the tool reports the requested one), so two agents' bridge commands round-robin across each other's live games. This repo has no launcher script, so the reconcile is a pre-launch ritual: `python tools/mcp_guard.py --verbose` checks every installed plugin copy (PASS/MISSING per copy, exit 0 pass, 1 missing, 2 rebase needed) and `python tools/mcp_guard.py --restore` re-inserts `GODOT_BRIDGE_PORT: String(port),` directly above the `GODOT_BRIDGE_TOKEN: token,` anchor in `spawnOwnInstance`'s env map (one-time .bak backup, idempotent via marker, refuses and reports rebase-needed if a newer template drops the token anchor). The restore self-heals the copy after every plugin upgrade. A patched plugin file takes effect on the next DSH restart: the harness loads plugin code at boot.
- **Two-lane ritual:** before running two bridge lanes concurrently, confirm the installed plugin injects `GODOT_BRIDGE_PORT` on spawn (the check above passes), and verify one spawn's engine log line `McpInteractionServer: Listening on 127.0.0.1:<port>` against the port you asked for.

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
- `docs/old/`: archive of consumed research and plans; add, do not read as current truth.

Before proposing something new, grep /docs for prior gleans so nothing parked or rejected gets re-proposed.
NEVER leave open questions written in a doc. Ask the owner in chat and record only the answer (a decision). An "open questions" section in any doc is a defect; questions are asked, not stored.
Wiki fix drafts also live in /docs until the owner pastes them to GitHub.
Write research and plan reports as you work, not from memory at the end.
GitHub issues are the home for anything smaller than a full design. Do not keep a local md copy of a filed issue; delete it once filed.
Keep /docs free of cruft: when a plan or report is consumed, archive it under /docs/old promptly. Only active work stays in /docs/plans, /docs/research, and /docs/design.

### 13.1 Owner notes intake

When the owner delivers notes directly to an intake agent, each note ends in exactly one of these states:
- Quick and doable now: approve to design, design, build it (same verification discipline as any change).
- An issue already covers it: the intake agent adds a comment to that issue via gh CLI, showing the owner the exact final text first and getting explicit per-item approval (section 15 applies to every write).
- Big, complex, or needing design: ask the owner whether it becomes a GitHub issue or a design doc here, then follow the answer.

Clean up after yourself: docs/design/owner-todo-dump.md is a ledger, not a landfill, and is ultimately to be retired. When an item reaches its final home, shrink its dump entry to a one-line pointer or delete it. Never leave open questions in the dump (section 13 rule).

## 14. Environment Notes (this machine)

- Session workspace: C:\Games\GODOT\SecretHistories, branch dev4, in sync with origin/dev4 at session start.
- File sandbox is workspace-write with approval-on-ask. Writes outside the workspace fail; network goes through the web tools, not raw sockets.
- The harness is DSH (DeepSeek Harness). Use harness write/edit tools, not shell redirection.
- Godot: project.godot declares features 4.7 and the engine binary on this machine is Godot 4.7-stable (the 4.4 declarations were upgraded on owner instruction; the objective is to track Godot latest). Launched only via the bridge (section 10).
- Project facts: 16 autoloads (one is the agent-bridge debug autoload), JoltPhysics3D physics, ~48 defined input actions, most namespaced (see ARCHITECTURE.md for the systems map).

## 15. GitHub and Public Actions

Read-only browsing (opening the issue list or a PR page through web tools) needs no approval. Everything that WRITES to github.com does, with no exceptions:

- Every write requires the owner's explicit approval for THAT action, in THAT session. Never inferred. Never carried over. Silence, a prior blanket statement, or "the issues are the work list" is not approval.
- Gated actions include: filing, editing, closing, reopening, or commenting on issues and PRs; adding or removing labels, assignees, or milestones; wiki edits; releases; forks; branch pushes to anything not already owned by the owner; reactions. Triviality is never assumed, not even a label toggle.
- Before requesting approval for anything wording-related, paste the EXACT final text that would be uploaded or changed: full title, full body, exact labels, exact target (new issue vs existing number). For edits, show old text versus new text.
- Batch approvals are allowed only when the request enumerates every item with its exact text, and the owner explicitly approves the enumerated batch. Anything not in that enumeration needs its own approval.
- If the owner approves with modifications, use the owner's wording, paste the final text actually used, and execute only that.
- Report back with the link and number of everything created or changed. A failed or partially applied write is reported as such, not papered over.

Rationale: this contract is trust-earning, not trust-assuming. The owner reviews before anything leaves the machine; the gitignored /docs work needs no approval, everything public does.

## 16. Commit Discipline

- Ask the owner before every commit. Never commit on inference, momentum, or "it is done". The owner often verifies each fix first.
- One issue per commit. Message: plain imperative summary plus the issue number in parentheses, e.g. "Fix webley_audio script reference (#739)". No prefix, no emojis, no mixing unrelated work into one commit.
- Before asking, capture fresh verification evidence for exactly that issue (section 9 ladder). Present the evidence, the exact file list, and the proposed message; wait for the yes.
- Never stage or commit files the agent did not author this session. Pre-existing working-tree changes stay untouched and unstaged.
- Pushes are a separate gate under section 15: local commit approval never implies push approval.
- Gitignored paths (/docs, export_presets.cfg) are never committed.
- Multi-agent runs keep one game window at a time; tests run only when no build agent is mid-edit on scenes the run would load.
