export const meta = {
  name: 'decouple-enigami',
  description: 'Map coupling across Enigami modules, design decoupling plans, adversarially verify each recommendation',
  phases: [
    { title: 'Read', detail: 'seven readers, one coupling dimension each' },
    { title: 'Design', detail: 'three independent decoupling plans from different angles' },
    { title: 'Judge', detail: 'score the plans, synthesize one ordered list' },
    { title: 'Verify', detail: 'three refuters per recommendation, distinct lenses' },
    { title: 'Critic', detail: 'what is missing' },
  ],
}

const ROOT = '/Users/soday/Documents/WIPGames/Enigami/master'

const CONTEXT = `
PROJECT: Enigami, Godot 4.5, GDScript. Root: ${ROOT}. 139 .gd files (86 outside tests/), ~21k non-test LOC.
Read ARCHITECTURE.md first (5 modules: circuit/ feature/ graphics/ story/{rules,view} mobile/{input,view}, shell app/). The one rule: a picture may read the rules it draws, a rule never names its picture. tests/shared/module_test.gd enforces it by scanning class names per file (strings and comments stripped).
THE WORKING TREE HAS UNCOMMITTED EDITS in app/game.gd, feature/actors/player.gd, feature/attacks/attacks.gd, feature/world/room.gd, mobile/view/touch_pad.gd. Analyze the working tree as it is. DO NOT EDIT ANY FILE. DO NOT run godot or tests/run.sh. Read-only: cat, sed -n, grep, find.

=== MODULE -> MODULE (count of file-level "names a class/autoload" edges) ===
app -> feature 7 | app -> graphics 6 | app -> mobile/input 2 | app -> mobile/view 1 | app -> story/rules 2
circuit -> app 4 (all Loc)
feature -> app 23 | feature -> circuit 26 | feature -> story/rules 1 (sandbox.gd -> Npc)
graphics -> app 35 | graphics -> circuit 15 | graphics -> feature 55 | graphics -> mobile/input 3 | graphics -> mobile/view 1 | graphics -> story/view 1
mobile/input -> app 1 | mobile/view -> app 4 | mobile/view -> feature 1 (touch_pad.gd -> Player) | mobile/view -> graphics 5 | mobile/view -> mobile/input 1
story/rules -> app 5 | story/rules -> feature 2 (cutscene.gd -> Arena, npc.gd -> Player)
story/view -> app 6 | story/view -> graphics 14 | story/view -> story/rules 8

=== FAN-IN (files most depended on) ===
37 app/loc.gd (Loc) | 19 graphics/ui/ui_kit.gd (UiKit) | 19 graphics/style.gd (Style) | 18 app/cues.gd (Cues) | 17 circuit/components.gd (Components)
13 feature/actors/player.gd (Player) | 12 app/audio/audio.gd (Audio) | 12 feature/core/game_state.gd (GameState) | 12 feature/world/room.gd (Room)
11 app/controls.gd (Controls) | 11 circuit/skill_board.gd (SkillBoard) | 11 circuit/payload.gd (Payload) | 11 graphics/pixel_camera.gd (PixelCamera)
10 feature/actors/actor.gd (Actor) | 10 graphics/ui/pixel_draw.gd (PixelDraw) | 9 graphics/fx.gd (Fx) | 8 feature/attacks/attacks.gd | 8 feature/actors/enemy.gd
7 feature/core/weapons.gd | 7 feature/core/arena.gd | 7 graphics/sprites.gd | 6 mobile/input/touch.gd (Touch) | 6 circuit/skill_runner.gd | 5 feature/world/dragon_test.gd | 5 story/rules/npc.gd

=== FAN-OUT (files naming the most others) ===
30 graphics/views.gd -> AreaBurst, AreaBurstView, DashSlash, DashSlashView, DragonTest, DragonTestView, DragonTower, Enemy, EnemyView, HideoutWorld, HideoutWorldView, LostKit, LostKitView, MeleeArc, MeleeArcView, Pickup, PickupView, PixelCamera, Player, PlayerView, Projectile, ProjectileView, Raid, RaidView, Room, RoomView, Sandbox, SandboxView, StoryViews, TowerView
20 app/game.gd -> Audio, Controls, ControlsPanel, Cutscene, DragonTest, GameState, HideoutWorld, Loc, Npc, Raid, ResultsScreen, Sandbox, SkillEditor, Station, TimeCtl, TitleScreen, Touch, TouchPad, UiKit, VideoRows
16 feature/world/raid.gd -> Actor, Arena, Attacks, Components, Controls, Cues, Enemy, GameState, Loc, LostKit, Monsters, Pickup, Player, RaidMap, Room, TimeCtl
12 feature/attacks/attacks.gd -> Actor, AreaBurst, Arena, Components, Cues, DashSlash, GameState, Loc, MeleeArc, Payload, Projectile, TimeCtl
12 graphics/views/hideout_world_view.gd -> Fx, GameState, Hideout, HideoutWorld, Hud, Loc, PixelCamera, PixelDraw, Room, Station, Style, UiKit
11 feature/actors/player.gd -> Actor, Attacks, Cues, FSMNode, GameState, Payload, Pointer, SkillBoard, SkillRunner, TimeCtl, Weapons
11 feature/world/dragon_test.gd -> Arena, Attacks, Cues, DragonTower, Enemy, Loc, Payload, Player, SkillBoard, SkillRunner, Weapons
11 graphics/ui/skill_editor.gd -> Audio, BoardCode, Components, GameState, Loc, PixelDraw, ShareCodePanel, SkillBoard, SkillRunner, Style, UiKit
9 feature/world/room.gd -> Components, Cues, Enemy, GameState, Loc, LostKit, Monsters, Pickup, Player
9 feature/world/sandbox.gd -> Actor, Arena, Cues, Enemy, GameState, Npc, Player, Room, Weapons
9 graphics/ui/hud.gd -> Controls, Loc, PixelDraw, Player, SkillRunner, Style, Touch, UiKit, Weapons
9 graphics/views/dragon_test_view.gd -> Cues, DragonTest, DragonTestHud, Enemy, Fx, PixelCamera, Room, SkillEditor, UiKit
8 graphics/views/raid_view.gd -> Fx, GameState, Hud, MapPanel, PixelCamera, Raid, Room, SkillEditor
8 graphics/views/sandbox_view.gd -> Fx, Hud, Loc, PixelCamera, Room, Sandbox, SandboxPanel, SkillEditor
7 mobile/view/touch_pad.gd -> Audio, Controls, PixelDraw, Player, Touch, UiKit (+Player is feature)
7 story/view/npc_view.gd -> Controls, DialogueBox, Fx, Npc, PixelCamera, Sprites, Style

=== CROSS-MODULE EDGES worth a look ===
app/pointer.gd -> Touch (app names mobile/input)
app/loc.gd -> string paths res://graphics/assets/fonts/* (app loads graphics assets)
circuit/{board_code,components,skill_board,skill_runner}.gd -> Loc
feature/actors/player.gd -> Pointer (feature reads the shell's pointer)
feature/world/raid.gd -> Controls
feature/world/sandbox.gd -> Npc (documented exception)
graphics/style.gd -> Components, Payload, Pickup (the look table names rule classes)
graphics/fx.gd -> Arena, Video
graphics/pixel_camera.gd -> Loc, Pointer
graphics/views/player_view.gd -> DragonTest ("player.get_parent() is DragonTest")
graphics/views/{raid_view,sandbox_view,dragon_test_view}.gd -> SkillEditor (world views open the editor)
graphics/ui/hud.gd -> Player, SkillRunner, Weapons, Touch, Controls
graphics/ui/controls_panel.gd -> TouchLayoutEditor (documented exception)
graphics/cue_visuals.gd -> Enemy
mobile/view/touch_pad.gd -> Player, Controls, Touch
mobile/view/touch_layout_editor.gd -> Hud
story/rules/npc.gd -> Player, Cues, Loc
story/rules/cutscene.gd -> Arena, Cues

=== FILE-LEVEL CYCLE ===
feature/attacks/{attacks,burst,dash_slash,melee,projectile}.gd form one strongly connected component (attacks.gd names the four; each of the four names Attacks back).

=== AUTOLOADS (project.godot) ===
app: Loc Cues Audio AudioCues Pointer Video | feature: Arena TimeCtl GameState | graphics: Sprites Fx Views CueVisuals

=== IMPLICIT DEPENDENCIES module_test CANNOT SEE (it strips strings) ===
Node groups: "player" group read by app/pointer.gd:148, app/game.gd:128, story/rules/npc.gd:226, story/view/npc_view.gd:112, mobile/view/touch_pad.gd:389; "npcs" group by app/game.gd:141.
Duck typing: app/pointer.gd:149 p.has_method("controls_locked").
Every view does get_parent() as <ConcreteClass> (graphics/views/*.gd, story/view/*.gd).
Cue names (StringName, no central table). Emitted by feature: area_blast attack blink boss_phase dash death extract_done extract_tick hit hurt impact jump kit_back lunge lunge_cut mana_drain melee_arc music_start parry pickup pull raid_lost refused shatter travel ui wall_slide. Emitted by story: scene_direction scene_finished scene_letter scene_line scene_staged talk talk_letter ui.
Handled by graphics/cue_visuals.gd + app/audio/audio_cues.gd: area_blast attack blink boss_phase dash death extract_done extract_tick hit hurt impact jump kit_back lunge_cut mana_drain melee_arc music_start parry pickup pull raid_lost refused scene_direction scene_letter scene_line shatter talk talk_letter travel ui wall_slide. (lunge, scene_staged, scene_finished not handled there; check story/view and app/game.)
Tree lookups (get_node/$/connect/groups/get_parent) count per file: app/game.gd 29, graphics/ui/title_screen.gd 17, graphics/ui/hideout.gd 15, hideout_world_view 8, raid_view 7, dragon_test_view 7, controls_panel 6, feature/world/raid.gd 6, feature/actors/enemy.gd 6.
Only one .tscn outside tests: app/main.tscn.

=== BIGGEST FILES ===
1858 graphics/ui/skill_editor.gd | 1303 graphics/ui/title_screen.gd | 850 mobile/view/touch_pad.gd | 744 feature/core/game_state.gd | 632 graphics/style.gd | 628 feature/actors/player.gd | 609 app/game.gd | 606 circuit/skill_runner.gd | 531 feature/world/room.gd
`

const FINDINGS_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          kind: { type: 'string', description: 'autoload | concrete-class | registry | cycle | god-object | string-path | group | duck-typing | cue | api-width | other' },
          files: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, line: { type: 'integer' }, excerpt: { type: 'string' } }, required: ['path', 'line', 'excerpt'] } },
          why_it_matters: { type: 'string', description: 'which edits collide, which module cannot be tested/changed alone, concretely' },
          proposed_fix: { type: 'string', description: 'a concrete change, in GDScript/Godot terms' },
          mechanism: { type: 'string', description: 'e.g. injection, signal, data snapshot, self-registration, split file, move file, string key, resource' },
          edges_removed: { type: 'array', items: { type: 'string' }, description: 'module->module or file->Class edges this removes' },
          effort: { type: 'string', description: 'S | M | L' },
          risk: { type: 'string', description: 'low | medium | high, and what breaks' },
        },
        required: ['title', 'kind', 'files', 'why_it_matters', 'proposed_fix', 'mechanism', 'effort', 'risk'],
      },
    },
    not_a_problem: { type: 'array', items: { type: 'string' }, description: 'dependencies in your dimension that are fine as they are, and why' },
  },
  required: ['summary', 'findings', 'not_a_problem'],
}

const READ_RULES = `
Rules for you as a reader:
- Read-only. Never edit, never run godot. Use cat/sed -n/grep/find via Bash.
- Every finding must cite real file:line with a verbatim excerpt you read. A verifier will open the file; a fabricated line kills the finding.
- Say what a dependency costs in THIS project: which two branches would touch the same file, which module cannot be run or tested without another, which test would need a renderer. The project's own goal (ARCHITECTURE.md) is that a change to rules, picture, telling, board engine, and thumb controls are edits to disjoint file sets.
- Distinguish a dependency that is the intended seam (a view reading its parent's public state; a Cue emit) from one that leaks (a rule naming a picture, a picture naming a specific world, a module reaching a global it only needs one value from).
- Propose fixes that work in GDScript 4.5: no interfaces, class_name is global, autoloads are globals, duck typing and signals and Callables and Dictionaries are the tools. Prefer the project's three existing mechanisms (Views, Cues, Style) and its existing pattern base_payload_provider (a Callable handed in) before inventing new ones.
- Rank your findings by coupling reduction per unit of effort. Include a not_a_problem list so the designers do not chase intended seams.
- Aim for 5 to 12 findings. Depth over breadth: read the actual code paths, not just the graph.
`

const DIMENSIONS = [
  {
    key: 'autoloads',
    prompt: `Dimension: AUTOLOADS AND GLOBAL SINGLETONS. The 13 autoloads (Loc Cues Audio AudioCues Pointer Video | Arena TimeCtl GameState | Sprites Fx Views CueVisuals) are reachable from any file, so the module test is the only thing that stops a module from leaning on them. Examine, for each autoload, who names it and what they actually take from it. In particular: (1) circuit/ names Loc in 4 files: what does the engine need words for, and could the name lookup be handed in (a Callable, a Dictionary, or the caller doing Loc.t on an id the circuit returns) so the circuit names nothing outside itself? (2) feature/ names Loc in many files: is the rule layer building display strings? (3) GameState (744 LOC, fan-in 12): what does it hold, who reads which parts, and does it need splitting (profile / stash / raid-in-progress / facility info)? (4) feature/actors/player.gd names Pointer, feature/world/raid.gd names Controls: a rule reading the shell's input device. (5) graphics/fx.gd names Arena and Video; graphics/pixel_camera.gd names Loc and Pointer. (6) app/pointer.gd names Touch. (7) Audio is named from 12 files across graphics, mobile/view, story/view: should UI sound go through Cues like every other sound (the 'ui' cue exists)? Read app/loc.gd, app/cues.gd, app/pointer.gd, feature/core/game_state.gd, circuit/components.gd, circuit/skill_runner.gd, graphics/fx.gd.`,
  },
  {
    key: 'graphics-feature',
    prompt: `Dimension: GRAPHICS -> FEATURE CONCRETE-CLASS COUPLING (55 file-level edges, the largest in the project). The intended seam is 'a view reads its parent's public state'. Examine how wide the reading actually is. (1) graphics/views.gd is a 30-name registry table naming every rule class and every view class: every new gameplay node is an edit to this file, which is the merge-conflict magnet the architecture says it wants to avoid; evaluate alternatives (a view registered by string key such as a node's class name via get_class()/get_script().get_global_name(), self-registration from the view side with Views.register(&"Player", PlayerView), or a node exporting a meta key), with GDScript 4.5 specifics. (2) Every view does get_parent() as ConcreteClass: list which properties/methods each view reads off its parent (read graphics/views/*.gd fully) and judge whether a view could read a plain Dictionary snapshot or duck-typed properties instead, and whether that is worth it. (3) graphics/views/player_view.gd names DragonTest (a view of the player knowing a specific world) and graphics/views/{raid_view,sandbox_view,dragon_test_view}.gd name SkillEditor. (4) graphics/style.gd names Components, Payload, Pickup: the look table naming rule classes. (5) graphics/ui/hud.gd names Player, SkillRunner, Weapons, Touch, Controls; graphics/ui/dragon_test_hud.gd names DragonTest, Player, SkillRunner. (6) graphics/cue_visuals.gd names Enemy. (7) graphics/ui/skill_editor.gd (1858 LOC) names SkillBoard, SkillRunner, BoardCode, Components, GameState: is the editor a picture of a board or does it own board logic? Read graphics/views.gd, graphics/style.gd, graphics/ui/hud.gd, graphics/cue_visuals.gd, and every file under graphics/views/.`,
  },
  {
    key: 'feature-internals',
    prompt: `Dimension: COUPLING INSIDE feature/ AND WHO REACHES INTO Player. (1) feature/attacks/{attacks,burst,dash_slash,melee,projectile}.gd form a 5-file cycle: attacks.gd names all four, each names Attacks back. Read all five and say what the back-references are for and how to break the cycle (e.g. the attack node takes what it needs as constructor args or a Callable, or the shared thing moves to a leaf file). (2) feature/world/raid.gd names 16 classes and feature/world/room.gd 9: what do they orchestrate, and is any of it a picture or shell concern in disguise? (3) Player (feature/actors/player.gd, 628 LOC) has fan-in 13: graphics/ui/hud.gd, graphics/ui/dragon_test_hud.gd, graphics/views/player_view.gd, graphics/views.gd, mobile/view/touch_pad.gd, story/rules/npc.gd, feature/world/{room,raid,sandbox,hideout_world,dragon_test}.gd, and the "player" node group read from app/pointer.gd, app/game.gd, story/rules/npc.gd, story/view/npc_view.gd, mobile/view/touch_pad.gd. For each reader list exactly which members of Player it touches; then judge whether a narrower surface (a small set of documented public properties, or a signal) would let the player's internals change without those files caring. (4) feature/core/game_state.gd: what is in it, who writes to it, and does anything in graphics/ or mobile/ WRITE to GameState (a picture writing a rule)? (5) feature/world/sandbox.gd names Npc and feature/world/dragon_test.gd names DragonTower: world files staging content. Read feature/actors/player.gd, feature/attacks/*.gd, feature/world/raid.gd, feature/world/room.gd, feature/core/game_state.gd and grep every reader of Player and GameState.`,
  },
  {
    key: 'circuit-seam',
    prompt: `Dimension: THE CIRCUIT SEAM. circuit/ is meant to be an engine that names nothing but itself and Loc. Examine both directions. (1) feature/ -> circuit/ has 26 file-level edges (Components, SkillBoard, SkillRunner, Payload, BoardCode): list every member of the circuit classes that feature/ touches (grep 'SkillRunner\\.' 'SkillBoard\\.' 'Components\\.' 'Payload\\.' in feature/) and judge whether the API is narrow (a few entry points) or whether feature/ reaches into the runner's internals (tick state, slot arrays, cooldown internals). (2) graphics/ -> circuit/ has 15 edges: graphics/ui/skill_editor.gd, share_code_panel.gd, hideout.gd, hud.gd read SkillRunner/SkillBoard/Components/BoardCode. A picture reading the engine directly, bypassing feature/: is that the intended layering or a second seam nobody declared? (3) circuit/ -> Loc in all four files: what strings does the engine produce, for whom, and can the circuit return ids that the caller localizes? (4) base_payload_provider: read how it is set and called; is it the only thing handed in, or does the runner also reach out (Arena, Cues, Engine.time_scale, GameState)? Check for any global the circuit touches that is not a class name: groups, get_tree(), Engine, ProjectSettings, Cues. (5) circuit/components.gd DEFS carry English fallback text; feature/ carries Weapons.DEFS and Monsters.DEFS similarly. Is the data layer (DEFS) mixed with logic, and would moving DEFS to data/ or a Resource reduce the number of files a 'new part' edit touches (ARCHITECTURE.md says a new part touches components.gd, skill_runner.gd, board_code.gd CODE_IDS, and style.gd: four files in three modules)? Read all five circuit/*.gd files and the feature/ callers.`,
  },
  {
    key: 'shell-story-mobile',
    prompt: `Dimension: THE SHELL, story/ AND mobile/. (1) app/game.gd (609 LOC, names 20 classes, 29 tree lookups) is the composition root. Read it fully: is it only wiring, or does it hold screen-flow rules, input handling, or per-screen logic that belongs in a module? Could screens be registered rather than named (each screen is a Control the shell instantiates by name)? (2) app/pointer.gd names Touch and reads the "player" group with has_method("controls_locked") duck typing: the shell's cursor asking the rules whether the player is locked. (3) app/loc.gd loads fonts from res://graphics/assets/fonts by string path: the word table knowing where the picture keeps its faces. (4) mobile/view/touch_pad.gd (850 LOC) names Player and Controls and reads the "player" group; mobile/view/touch_layout_editor.gd names Hud. What does the console need from the player? (5) story/rules/npc.gd names Player and reads the "player" group; story/view/npc_view.gd reads the "player" group; story/rules/cutscene.gd names Arena. A conversation rule naming the concrete Player class rather than 'whoever is nearby and can talk'. (6) graphics/ui/controls_panel.gd names TouchLayoutEditor and feature/world/sandbox.gd names Npc: the two documented exceptions; are they still the only ones, and is there a cheaper mechanism (the shell handing a Callable, a Cue, a screen registry)? (7) app/controls.gd (fan-in 11): what is it, and why do graphics, feature, story/view, mobile all name it? Read app/game.gd, app/pointer.gd, app/controls.gd, app/loc.gd (the font part), mobile/view/touch_pad.gd (the Player part), mobile/input/touch.gd, story/rules/npc.gd, story/view/npc_view.gd.`,
  },
  {
    key: 'enforcement',
    prompt: `Dimension: ENFORCEMENT AND ITS BLIND SPOTS. tests/shared/module_test.gd is the guard that keeps the seam honest, but it only sees capitalized class/autoload names in code with strings and comments stripped. Read it fully, then find every kind of dependency it cannot see and where each occurs: (1) string res:// paths (preload/load/FileAccess) that cross modules (app/loc.gd -> graphics/assets/fonts; who else?); (2) node group names ("player", "npcs"): which modules read them; (3) has_method / get / call by string (duck typing); (4) signal names connected by string; (5) cue names: build the full emitted-vs-handled table yourself (grep Cues.at and Cues.emit_cue across app circuit feature graphics story mobile, and every &"name": handler in graphics/cue_visuals.gd, app/audio/audio_cues.gd, story/view/*, app/game.gd) and list orphans on either side; (6) get_parent() as X and $Path lookups from a view into a rule node's children; (7) scene files (app/main.tscn) and export/preload of scripts; (8) Engine.time_scale and other engine globals as hidden shared state; (9) the README's 'delete the four graphics autoloads and tests still pass' check: is there a script that actually runs it (look in tests/run.sh, .github/, any CI config)? Then propose concrete extensions to module_test.gd (still no renderer needed) that would catch each blind spot, e.g. also scanning string literals for res:// paths and group names against a per-module allow-list, and a cue-name parity check. Also propose what a per-module 'can it be loaded alone' test would look like (a --script SceneTree that loads only one module's scripts and checks parse errors; see if tests/shared already has anything like that).`,
  },
  {
    key: 'tests',
    prompt: `Dimension: WHAT THE TESTS DEPEND ON, AND WHAT EACH REFACTOR WOULD COST. tests/ has 53 scripts in circuit/ feature/ graphics/ story/ mobile/ shared/. Read tests/run.sh and a representative sample of each folder (at least: tests/feature/jump_test.gd, tests/feature/impact_test.gd, tests/circuit/cooldown_test.gd, tests/graphics/focus_test.gd, tests/mobile/touch_pad_test.gd, tests/story/npc_test.gd, tests/shared/smoke.gd, tests/shared/module_test.gd, tests/shared/loc_test.gd) and grep the rest for class names. Report: (1) do feature/circuit/story tests name any graphics or app class (which means the rule tests cannot run with the picture removed)? (2) how do tests build a world: through app/game.gd (the composition root), through Arena, or by instantiating Player/Room directly? This tells us which refactors are safe: a refactor of views.gd registry costs nothing if no test names Views; splitting GameState costs a lot if 20 tests call GameState.reset_profile(). For each of these candidate refactors give the count of test files that would need touching and name them: (a) circuit stops naming Loc; (b) views.gd registry becomes self-registration; (c) GameState split into profile/stash/raid; (d) attacks cycle broken; (e) Player readers narrowed to a public surface; (f) UI Audio.play calls routed through Cues; (g) app/game.gd screen registry; (h) npc.gd/pointer.gd/touch_pad.gd stop naming Player and the "player" group. (3) Are there tests that only pass because of an autoload's side effect at boot (e.g., Views attaching, Fx existing)? (4) Note the project rule: tests write the live save unless HOME is redirected; you are not running them, just reading.`,
  },
]

const PLAN_SCHEMA = {
  type: 'object',
  properties: {
    angle: { type: 'string' },
    rationale: { type: 'string' },
    steps: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          rank: { type: 'integer' },
          title: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, line: { type: 'integer' } }, required: ['path', 'line'] } },
          change: { type: 'string', description: 'the concrete edit, in Godot/GDScript terms, with before/after sketch' },
          mechanism: { type: 'string' },
          removes: { type: 'array', items: { type: 'string' } },
          effort: { type: 'string' },
          risk: { type: 'string' },
          depends_on: { type: 'array', items: { type: 'integer' } },
          order_reason: { type: 'string' },
        },
        required: ['rank', 'title', 'problem', 'evidence', 'change', 'mechanism', 'removes', 'effort', 'risk', 'order_reason'],
      },
    },
    leave_alone: { type: 'array', items: { type: 'string' } },
  },
  required: ['angle', 'rationale', 'steps', 'leave_alone'],
}

const SCORE_SCHEMA = {
  type: 'object',
  properties: {
    scores: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          plan: { type: 'string' },
          feasibility: { type: 'integer' },
          reduction: { type: 'integer' },
          alignment: { type: 'integer' },
          test_safety: { type: 'integer' },
          total: { type: 'integer' },
          notes: { type: 'string' },
        },
        required: ['plan', 'feasibility', 'reduction', 'alignment', 'test_safety', 'total', 'notes'],
      },
    },
    winner: { type: 'string' },
    graft: { type: 'array', items: { type: 'string' }, description: 'steps from the other plans worth grafting into the winner' },
    reject: { type: 'array', items: { type: 'string' }, description: 'steps in any plan that should not be recommended, and why' },
  },
  required: ['scores', 'winner', 'graft', 'reject'],
}

const FINAL_SCHEMA = {
  type: 'object',
  properties: {
    diagnosis: { type: 'string', description: 'three to six sentences: where the coupling actually is, in this project' },
    recommendations: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          rank: { type: 'integer' },
          title: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, line: { type: 'integer' }, excerpt: { type: 'string' } }, required: ['path', 'line'] } },
          change: { type: 'string' },
          mechanism: { type: 'string' },
          removes: { type: 'array', items: { type: 'string' } },
          effort: { type: 'string' },
          risk: { type: 'string' },
          tests_touched: { type: 'array', items: { type: 'string' } },
          order_reason: { type: 'string' },
        },
        required: ['rank', 'title', 'problem', 'evidence', 'change', 'mechanism', 'removes', 'effort', 'risk', 'tests_touched', 'order_reason'],
      },
    },
    principles: { type: 'array', items: { type: 'string' }, description: 'rules to adopt so the coupling does not come back' },
    keep_as_is: { type: 'array', items: { type: 'object', properties: { what: { type: 'string' }, why: { type: 'string' } }, required: ['what', 'why'] } },
  },
  required: ['diagnosis', 'recommendations', 'principles', 'keep_as_is'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    confidence: { type: 'integer', description: '0-100' },
    reason: { type: 'string' },
    correction: { type: 'string', description: 'if partly wrong, the corrected claim or a better change; empty if none' },
  },
  required: ['refuted', 'confidence', 'reason', 'correction'],
}

const CRITIC_SCHEMA = {
  type: 'object',
  properties: {
    gaps: { type: 'array', items: { type: 'object', properties: { what: { type: 'string' }, why: { type: 'string' }, evidence: { type: 'string' } }, required: ['what', 'why'] } },
    overall: { type: 'string' },
  },
  required: ['gaps', 'overall'],
}

// ---------- Phase 1: readers (barrier: designers need every dimension) ----------
phase('Read')
log('Reading seven coupling dimensions in parallel')
const reads = await parallel(DIMENSIONS.map(d => () =>
  agent(`${CONTEXT}\n${READ_RULES}\n${d.prompt}`, { label: `read:${d.key}`, phase: 'Read', schema: FINDINGS_SCHEMA })
    .then(r => r && { key: d.key, ...r })
))
const findings = reads.filter(Boolean)
log(`${findings.length}/${DIMENSIONS.length} readers returned, ${findings.reduce((n, r) => n + r.findings.length, 0)} findings`)
const FINDINGS_TEXT = JSON.stringify(findings, null, 1)

// ---------- Phase 2: three independent plans (barrier: judges need all three) ----------
phase('Design')
const ANGLES = [
  { key: 'roi', angle: 'RETURN ON EFFORT FIRST: order by coupling edges removed per hour of work. Small, mechanical, safe edits first; a large refactor only if it pays for itself many times over.' },
  { key: 'isolation', angle: 'ISOLATION FIRST: order by which module becomes runnable and testable alone soonest. The finish line is: circuit/ loads with no autoload at all; feature/ runs with the graphics autoloads and mobile/ and story/view deleted; graphics/ can be pointed at a fake rule node. Prefer changes that shrink a module\'s import surface to a documented handful of names.' },
  { key: 'branches', angle: 'PARALLEL BRANCHES FIRST: the project\'s own stated goal is that a change to the rules, the picture, the telling, the engine and the thumb controls are edits to disjoint files. Order by which files are merge-conflict magnets today (views.gd registry, game.gd, style.gd, components.gd + skill_runner.gd + board_code.gd for a new part) and which change removes the most "both branches must open this file" cases.' },
]
const plans = (await parallel(ANGLES.map(a => () =>
  agent(`${CONTEXT}
You are one of three architects. Each of you gets the same findings and must produce a prioritized decoupling plan from a different angle. Your angle:
${a.angle}

The findings from seven readers (JSON). Trust the file:line evidence they cite but read the files yourself where the change is non-obvious; you may grep and read (read-only, no edits, no godot):
${FINDINGS_TEXT}

Produce 8 to 14 ordered steps. Each step is one concrete change a developer can do in one sitting or one PR, in GDScript 4.5 terms, with a before/after sketch. State what it removes (edges, merge-conflict files, autoload dependencies). Mark dependencies between steps. Include a leave_alone list of intended seams the readers flagged that you would NOT change, with reasons. Do not recommend anything that violates ARCHITECTURE.md's one rule or that would require an autoload to be added by a non-shell module. Assume the developer values the current design's spirit and wants it enforced harder and leaked less, not replaced.`,
    { label: `design:${a.key}`, phase: 'Design', schema: PLAN_SCHEMA }).then(p => p && { key: a.key, ...p })
))).filter(Boolean)
log(`${plans.length} plans drafted`)
const PLANS_TEXT = JSON.stringify(plans, null, 1)

// ---------- Phase 3: judges then synthesis ----------
phase('Judge')
const JUDGE_LENSES = [
  'Judge as the developer who has to live with the tests: weight test_safety and feasibility. Check specific claims by reading files.',
  'Judge as a reviewer of architecture: weight reduction (edges actually removed, not moved) and alignment with ARCHITECTURE.md. Penalize plans that add a new global mechanism when an existing one (Views, Cues, Style, base_payload_provider Callable) would do.',
]
const judgements = (await parallel(JUDGE_LENSES.map((lens, i) => () =>
  agent(`${CONTEXT}
${lens}
Score each of these three plans 1-10 on feasibility (works in GDScript 4.5, in this codebase), reduction (how much coupling it actually removes rather than relocates), alignment (respects the project's existing architecture and mechanisms), test_safety (how many of the 53 tests break, per the findings' tests dimension). Sum to total. Name the winner, list steps from the losers worth grafting into the winner, and list steps in ANY plan that should be rejected outright with the reason. Read-only, no edits, no godot.
Reader findings for reference:
${FINDINGS_TEXT}
The three plans:
${PLANS_TEXT}`, { label: `judge:${i + 1}`, phase: 'Judge', schema: SCORE_SCHEMA })
))).filter(Boolean)
log(`${judgements.length} judgements in; synthesizing`)

const synthesis = await agent(`${CONTEXT}
You are the synthesizer. Three architects produced plans; two judges scored them. Produce ONE final ordered list of at most 10 recommendations for the developer, who asked: "How would I be able to improve the dependency issue for this project? I would like to separate the modules so that the codes depend less on other codes."
Start from the winning plan, graft the judges' recommended steps from the others, drop the rejected ones, and merge duplicates. Every recommendation needs: the problem in one or two sentences, real file:line evidence with excerpt (copy from the findings; verifiers will open the files), the concrete change with a before/after sketch in GDScript, the mechanism, what it removes, effort, risk, which test files must change, and why it sits at that rank. Also write a diagnosis (where the coupling really is, in this project, in plain words), a short list of principles that keep it from coming back (rules the module test can enforce), and a keep_as_is list of things the readers flagged that are actually fine.
Read-only, no edits, no godot. You may read files to resolve disagreements between judges.
Findings:
${FINDINGS_TEXT}
Plans:
${PLANS_TEXT}
Judgements:
${JSON.stringify(judgements, null, 1)}`, { label: 'synthesize', phase: 'Judge', schema: FINAL_SCHEMA })

if (!synthesis) return { error: 'synthesis failed', findings, plans, judgements }
log(`${synthesis.recommendations.length} recommendations; verifying each with three refuters`)

// ---------- Phase 4: adversarial verify, pipelined per recommendation ----------
phase('Verify')
const LENSES = [
  { key: 'evidence', prompt: 'LENS: DOES IT REPRODUCE. Open every cited file:line. Is the excerpt really there (working tree, not HEAD)? Does the dependency exist as described? Does grep confirm the claimed set of readers/edges? If any citation is wrong or the dependency is narrower than claimed, refute or correct.' },
  { key: 'reduction', prompt: 'LENS: DOES IT ACTUALLY DECOUPLE. Trace the proposed change: after it, which files name which classes? Is an edge removed, or just relocated (e.g. from a class name to a string key nobody checks, or into app/game.gd which already names everything)? Does it make a module runnable/testable alone that was not before, or make two branches stop touching the same file? If the net effect is zero or negative, refute.' },
  { key: 'feasibility', prompt: 'LENS: DOES IT WORK IN GODOT 4.5 GDSCRIPT AND THIS CODEBASE. Check the sketch against GDScript 4.5 semantics (class_name globals, autoload singletons, static funcs, Callables, StringName, typed arrays, get_script().get_global_name(), signals). Check it against ARCHITECTURE.md: does it violate the one rule or add an autoload from a non-shell module? Check the claimed tests_touched by grepping tests/. If the change cannot be done as described, or breaks more than claimed, refute or correct.' },
]
const verified = await pipeline(
  synthesis.recommendations,
  rec => parallel(LENSES.map(l => () =>
    agent(`${CONTEXT}
You are a skeptic. Your job is to REFUTE this recommendation. Default to refuted=true if you cannot confirm it. Read-only, no edits, no godot.
${l.prompt}
Recommendation:
${JSON.stringify(rec, null, 1)}`, { label: `verify:${rec.rank}:${l.key}`, phase: 'Verify', schema: VERDICT_SCHEMA })
      .then(v => v && { lens: l.key, ...v })
  )).then(votes => {
    const vs = votes.filter(Boolean)
    const upheld = vs.filter(v => !v.refuted).length
    return { ...rec, votes: vs, survives: upheld >= 2, upheld, of: vs.length }
  })
)
const survivors = verified.filter(Boolean).filter(r => r.survives)
const killed = verified.filter(Boolean).filter(r => !r.survives)
log(`${survivors.length} recommendations survive, ${killed.length} refuted`)

// ---------- Phase 5: completeness critic ----------
phase('Critic')
const critic = await agent(`${CONTEXT}
You are the completeness critic. Given the reader findings and the verified recommendations below, ask: what is missing? A coupling dimension nobody read? A hotspot in the graph (top fan-in/fan-out above) no recommendation addresses? A recommendation whose 'removes' list overstates? A cheap enforcement the module test could add that no one proposed? Read files to check (read-only, no edits, no godot). Return concrete gaps with evidence; do not restate what is already covered.
Findings:
${FINDINGS_TEXT}
Verified recommendations:
${JSON.stringify(survivors, null, 1)}
Refuted recommendations (with votes):
${JSON.stringify(killed.map(k => ({ title: k.title, votes: k.votes })), null, 1)}`, { label: 'critic', phase: 'Critic', schema: CRITIC_SCHEMA })

return { diagnosis: synthesis.diagnosis, principles: synthesis.principles, keep_as_is: synthesis.keep_as_is, survivors, killed, critic, readers: findings.map(f => ({ key: f.key, summary: f.summary, not_a_problem: f.not_a_problem })) }
