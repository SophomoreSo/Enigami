extends Node
## The world is drawn at the art's resolution and slid by what the camera has
## left over. Checked across shake offsets, in a raid and on the bench: the
## picture covers the screen, a world point lands where the real camera puts it
## (to the half pixel the slide is rounded to), the slide is whole pixels, and
## what reaches the screen really is 2× pixels.
##
## Needs a real renderer: the block check reads the frame back.

const GameScript := preload("res://app/game.gd")

var game: Node
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("[PIXEL] PASS ", what)
	else:
		fails += 1
		push_error("PIXEL FAIL: " + what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func audit(name: String, pixels: PixelCamera) -> void:
	check(pixels != null and is_instance_valid(pixels), "%s draws through a pixel camera" % name)
	if pixels == null or not is_instance_valid(pixels):
		return
	var screen := get_viewport().get_visible_rect().size
	var want := Vector2i(screen / PixelCamera.SCALE) + Vector2i.ONE * PixelCamera.BORDER * 2
	check(pixels._view.size == want,
		"%s: the buffer is the screen at 1/%d plus the border (%s)" % [name, PixelCamera.SCALE, pixels._view.size])

	var cam: Camera2D = Fx.camera
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tries := 48
	var covered := 0
	var whole := 0
	var worst := 0.0
	for i in tries:
		# Fx eases the offset back towards zero every frame, which only adds
		# more fractional positions to the sample.
		cam.offset = Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		await frames(2)
		var img: Sprite2D = pixels._image
		var shown := Rect2(img.position, img.texture.get_size() * img.scale)
		if shown.encloses(Rect2(Vector2.ZERO, screen)):
			covered += 1
		if img.position == img.position.round():
			whole += 1
		var xf := get_viewport().get_canvas_transform()
		for p in [Vector2(37.3, 21.9), Vector2(640.0, 352.0), Vector2(1201.7, 690.2)]:
			var truth: Vector2 = xf * p
			var drawn: Vector2 = img.position + (pixels._view.canvas_transform * p) * img.scale
			worst = maxf(worst, truth.distance_to(drawn))
	cam.offset = Vector2.ZERO
	check(covered == tries, "%s: the picture covers the screen at every offset (%d/%d)" % [name, covered, tries])
	check(whole == tries, "%s: the slide is whole screen pixels (%d/%d)" % [name, whole, tries])
	check(worst <= 0.5 * sqrt(2.0) + 0.001,
		"%s: world points land where the camera puts them (worst %.3f px)" % [name, worst])

## What reaches the screen is the buffer at SCALE×: every block lined up with
## the slide is a single colour. The HUD is sharp on purpose, so it is hidden —
## and so is an NPC's talk prompt, reading text drawn over the picture at the
## screen's resolution for the same reason.
func blocks(name: String, pixels: PixelCamera, hud_layer: CanvasLayer) -> void:
	if pixels == null or not is_instance_valid(pixels):
		return
	var sharp: Array = [hud_layer]
	for n in get_tree().get_nodes_in_group("npcs"):
		var v = Views.of(n)
		if v is NpcView:
			sharp.append(v.prompt_layer)
	for layer in sharp:
		layer.visible = false
	await frames(6)
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image()
	var pos := Vector2i(pixels._image.position)
	for layer in sharp:
		layer.visible = true
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if im.get_size() != screen:
		print("[PIXEL] skip %s block check: the frame is %s, not %s" % [name, im.get_size(), screen])
		return
	var s := PixelCamera.SCALE
	var seen := 0
	var split := 0
	for y in range(posmod(pos.y, s), screen.y - s + 1, 3 * s):
		for x in range(posmod(pos.x, s), screen.x - s + 1, 3 * s):
			seen += 1
			var c := im.get_pixel(x, y)
			var same := true
			for dy in s:
				for dx in s:
					if im.get_pixel(x + dx, y + dy) != c:
						same = false
			if not same:
				split += 1
	check(split == 0, "%s: every %d×%d block on screen is one colour (%d of %d split)" % [name, s, s, split, seen])

func frame_ms(n: int = 240) -> float:
	await frames(30)
	var t0 := Time.get_ticks_usec()
	await frames(n)
	return float(Time.get_ticks_usec() - t0) / float(n) / 1000.0

func _ready() -> void:
	GameState.reset_profile()
	seed(4242)
	game = Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(8)

	# A room with monsters in it, so actors and what they throw are in frame.
	game._deploy("SWORD", [0, 1, 2])
	await frames(20)
	var raid: Raid = game.current
	for c in raid.map.rooms.keys():
		if String(raid.map.rooms[c].get("kind", "")) == "normal":
			raid._enter_room(c, -1)
			break
	raid.player.invuln = 999.0
	await frames(20)
	var rv: RaidView = Views.of(raid)
	await audit("raid", rv.pixels)
	await blocks("raid", rv.pixels, rv.hud.get_parent() as CanvasLayer)

	# The bench never ends on its own, so the timing runs there.
	game.goto_sandbox()
	await frames(20)
	var sb: Sandbox = game.current
	sb.spawn_monster("CRAWLER")
	sb.spawn_monster("SENTRY")
	await frames(20)
	var sv: SandboxView = Views.of(sb)
	await audit("sandbox", sv.pixels)
	await blocks("sandbox", sv.pixels, sv.panel.get_parent() as CanvasLayer)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var through: float = await frame_ms()
	sv.pixels.queue_free()
	var direct: float = await frame_ms()
	print("[PIXEL] bench frame, uncapped: %.2f ms through the pixel camera, %.2f ms without"
		% [through, direct])

	print("[PIXEL] ---- %d failures ----" % fails)
	get_tree().quit()
