extends Node
## Frames of the foliage, for looking at: the bench as it opens with its
## floors grown over, a sheet of the plants on their own, and filmstrips — a
## patch of grass in the wind, run through, dashed through and blasted, with
## the velocity buffer beside each, and a bush dashed through.
##
## A filmstrip is a dozen frames of one crop stacked top to bottom, so the
## motion can be read in one picture. The buffer is drawn the way the
## package's preview draws it: pushed right in red, left in blue, up or down
## in green.
##
## Needs a real renderer — `--headless` draws into a dummy and saves black.
## Writes to `user://shots` unless SHOTS_DIR names somewhere else.

const GameScript := preload("res://app/game.gd")
var dir: String = "user://shots"
var pixels: PixelCamera

func shot(name: String, crop: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
		img.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name, " -> ", dir, "" if err == OK else " FAILED (%d)" % err)

## The velocity buffer under the screen's `crop`, as the package's preview
## shows it, three times the size.
func buffer_shot(name: String, crop: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var buf := pixels.velocity.texture().get_image()
	var area := pixels.velocity.area()
	var corner := get_viewport().get_canvas_transform().affine_inverse().origin
	var out := Image.create_empty(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8)
	for y in crop.size.y:
		for x in crop.size.x:
			var t := Vector2i(((corner + Vector2(crop.position + Vector2i(x, y)) - area.position) / Foliage.S).floor())
			var d := Vector2.ZERO
			if t.x >= 0 and t.y >= 0 and t.x < buf.get_width() and t.y < buf.get_height():
				var c := buf.get_pixel(t.x, t.y)
				d = Vector2(c.r, c.g)
			out.set_pixel(x, y, Color(clampf(d.x, 0.0, 1.0), clampf(absf(d.y), 0.0, 1.0), clampf(-d.x, 0.0, 1.0)))
	out.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name)

## `n` frames of the screen's `crop`, `every` seconds apart, stacked top to
## bottom with a line between them.
func strip(name: String, crop: Rect2i, n: int = 12, every: float = 0.05) -> void:
	var out := Image.create_empty(crop.size.x, (crop.size.y + 2) * n, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.1, 0.1))
	for i in n:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image().get_region(crop)
		img.convert(Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, crop.size), Vector2i(0, i * (crop.size.y + 2)))
		await wait(every)
	out.resize(crop.size.x * 3, out.get_height() * 3, Image.INTERPOLATE_NEAREST)
	out.save_png(dir.path_join(name + ".png"))
	print("[SHOT] ", name)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()

## The player stood at `at`, facing right, then dashed that way.
func dash_from(player: Player, at: Vector2) -> void:
	player.global_position = at
	Input.action_press("move_right")
	await frames(2)
	Input.action_press("dash")
	await frames(1)
	Input.action_release("dash")
	Input.action_release("move_right")

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
	pixels = (Views.of(sb) as SandboxView).pixels
	await shot("50_foliage")
	if view == null or view.plants.is_empty():
		print("[SHOT] the bench grew nothing")
		get_tree().quit()
		return

	# A sheet of plants on their own, from several rolls, in the air over the
	# middle of the room: bushes a cell wide and two, and flowers.
	var sheet: Array = []
	for i in 8:
		var kind := "bush" if i < 6 else "flowers"
		var f := Foliage.of(kind)
		f.grow((16 if i % 2 == 0 else 32) if kind == "bush" else 32, 100 + i)
		f.position = Vector2(352 + i * 80, 416)
		f.visibility_layer = PixelCamera.WORLD_LAYER
		view.add_child(f)
		sheet.append(f)
	await frames(2)
	await shot("51_sheet", Rect2i(Vector2i(330, 380), Vector2i(660, 44)))
	for f in sheet:
		f.queue_free()

	# The longest patch of grass on the bench, and a strip just over it.
	var patch: Foliage = null
	for f: Foliage in view.plants:
		if f.form == "blades" and (patch == null or f.span > patch.span):
			patch = f
	if patch == null:
		patch = view.plants[0]
	var floor_at := patch.global_position
	var crop := Rect2i(Vector2i(floor_at) + Vector2i(-60, -40), Vector2i(mini(patch.span * Foliage.S + 120, 340), 50))
	var aside := floor_at + Vector2(-200, -16)
	sb.player.global_position = aside
	await wait(2.0)
	await strip("52_wind", crop, 8, 0.1)

	# Run through it from just inside its left end — the bench's apprentice
	# stands by the wall, and a run from further off stops at them.
	sb.player.global_position = floor_at + Vector2(50, -16)
	Input.action_press("move_right")
	await strip("53_run", crop, 12, 0.025)
	Input.action_release("move_right")
	await buffer_shot("53_run_buffer", crop)
	sb.player.global_position = aside
	await wait(2.5)

	await dash_from(sb.player, floor_at + Vector2(-40, -16))
	await strip("54_dash", crop)
	await buffer_shot("54_dash_buffer", crop)
	sb.player.global_position = aside
	await wait(2.5)

	Attacks._burst(Payload.new(), floor_at + Vector2(140, -20), 0, null, sb.room)
	await frames(4)
	await buffer_shot("55_blast_buffer", crop)
	await strip("55_blast", crop)
	await wait(2.5)

	# A bush of its own on the floor, dashed through.
	var bush := Foliage.of("bush")
	bush.grow(32, 101)
	bush.position = Vector2(736, (Room.H - 2) * Room.CELL)
	bush.visibility_layer = PixelCamera.WORLD_LAYER
	view.add_child(bush)
	sb.player.global_position = bush.position + Vector2(-90, -16)
	await wait(1.0)
	await dash_from(sb.player, sb.player.global_position)
	await strip("56_bush", Rect2i(Vector2i(bush.position) + Vector2i(-100, -48), Vector2i(240, 52)))
	get_tree().quit()
