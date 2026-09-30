extends Node
## Frames of a cable, for looking at: the bench as it opens with its cables
## hanging, the player stood beside one, and the cable swinging after a dash
## through it.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else.

const GameScript := preload("res://app/game.gd")
var dir: String = "user://shots"

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	if OS.has_environment("SHOTS_DIR"):
		dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.reset_profile()
	seed(7)
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(20)
	var sb: Sandbox = game.current
	var view := Views.of(sb.room) as RoomView
	await shot("40_cables")
	if view == null or view.ropes.is_empty():
		print("[SHOT] the bench hung no cables")
		get_tree().quit()
		return
	# The lowest-hanging cable, and the player put in the air beside its
	# middle, dashing through it.
	var rope: Rope = view.ropes[0]
	for r: Rope in view.ropes:
		if r.point_of(r.nodes.size() - 1).y > rope.point_of(rope.nodes.size() - 1).y:
			rope = r
	var mid := rope.point_of(int(rope.nodes.size() / 2))
	sb.player.global_position = mid + Vector2(-70, 0)
	sb.player.velocity = Vector2.ZERO
	sb.player.face(1)
	await frames(2)
	await shot("41_beside_a_cable")
	sb.player.global_position = mid + Vector2(-70, 0)
	Input.action_press("dash")
	await frames(1)
	Input.action_release("dash")
	await frames(5)
	await shot("42_dashed_through")
	await wait(0.35)
	await shot("43_swinging")
	await wait(2.5)
	await shot("44_settled")
	get_tree().quit()
