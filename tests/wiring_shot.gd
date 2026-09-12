extends Node
const GameScript := preload("res://scripts/core/game.gd")
const DIR := "/private/tmp/claude-501/-Users-soday-Documents-WIPGames-260911/7651cc29-7de6-437f-9c39-ce9cf9c0075c/scratchpad/shots"

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [DIR, name])
	print("[SHOT] ", name)

func _ready() -> void:
	GameState.reset_profile()
	seed(3)
	var game := Node.new()
	game.set_script(GameScript)
	add_child(game)
	await frames(6)
	game.goto_sandbox()
	await frames(12)
	var sb: Sandbox = game.current
	sb._open_editor()
	await frames(4)
	var ed: SkillEditor = sb.editor
	var b: SkillBoard = ed.current_board()
	for c in b.cells.keys().duplicate():
		b.erase_at(c)

	# The board from the second report: flow turns a corner through parts that
	# do not point back at their feeder. This now wires up.
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("OVERCLOCK", Vector2i(1, 2), 1)   # in from the west, out south
	b.place("OVERCLOCK", Vector2i(1, 3), 2)   # in from the north, out west
	b.place("OVERCLOCK", Vector2i(0, 3), 1)   # in from the east, out south
	b.place("SLASH", Vector2i(0, 4), 0)
	b.place("OUTPUT", Vector2i(1, 4), 0)
	ed._sim_dirty = true
	await frames(6)
	await shot("14_corner_board")

	# Three overclocks: the readout shows both halves of the trade.
	for c2 in b.cells.keys().duplicate():
		b.erase_at(c2)
	b.place("INPUT", Vector2i(0, 2), 0)
	b.place("OVERCLOCK", Vector2i(1, 2), 0)
	b.place("OVERCLOCK", Vector2i(2, 2), 0)
	b.place("OVERCLOCK", Vector2i(3, 2), 0)
	b.place("SLASH", Vector2i(4, 2), 0)
	b.place("OUTPUT", Vector2i(5, 2), 0)
	ed._sim_dirty = true
	await frames(6)
	await shot("16_overclock")
	get_tree().quit()
