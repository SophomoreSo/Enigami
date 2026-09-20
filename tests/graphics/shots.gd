extends Node
const GameScript := preload("res://app/game.gd")
## Writes to `user://shots` unless SHOTS_DIR names somewhere else.
var dir: String = "user://shots"
var game: Node

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.reset_profile()
	seed(4242)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(8)
	await shot("01_title")

	game.goto_hideout()
	await frames(8)
	await shot("02_hideout")

	game._edit_library_skill(0)
	await frames(4)
	var ed: SkillEditor = game.editor
	ed.selected = "SPLIT"
	ed._update_hover(Vector2(300, 250))
	await frames(4)
	await shot("03_workbench")
	game._close_editor()
	await frames(4)

	game._deploy("SWORD", [0, 1, 2])
	await frames(20)
	var raid: Raid = game.current
	# Walk to a room with monsters so the shot shows a fight.
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "normal":
			raid._enter_room(c, -1)
			break
	await frames(20)
	Input.action_press("cast_skill")
	await frames(45)
	await shot("04_raid")
	Input.action_release("cast_skill")

	raid.set_editing(true)
	var red: SkillEditor = Views.of(raid).editor
	red.selected = "DUPLICATE"
	red._update_hover(Vector2(250, 200))
	await frames(20)
	await shot("05_raid_editor")
	raid.set_editing(false)

	raid.set_reading_map(true)
	await frames(10)
	await shot("06_raid_map")
	raid.set_reading_map(false)

	raid._enter_room(raid.map.entry, -1)
	await frames(10)
	await shot("07_extraction")

	game.goto_sandbox()
	await frames(20)
	var sb: Sandbox = game.current
	sb.spawn_monster("ARBITER")
	sb.spawn_monster("CRAWLER")
	await frames(40)
	await shot("08_sandbox")

	sb.set_editing(true)
	var sed: SkillEditor = Views.of(sb).editor
	sed.selected = "FIRE"
	sed._update_hover(Vector2(300, 200))
	await frames(20)
	await shot("09_sandbox_editor")
	sb.set_editing(false)
	await frames(10)
	await shot("10_sandbox_closed")
	get_tree().quit()
