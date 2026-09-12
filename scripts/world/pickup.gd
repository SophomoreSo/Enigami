class_name Pickup
extends Node2D

## A component or scrap lying on the floor. Loot dropped in a room stays there
## for the rest of the raid, so leaving something behind is a real choice.

signal collected(pickup: Pickup)

var component_id: String = ""
var scrap_amount: int = 0
var velocity: Vector2 = Vector2.ZERO
var room = null
var _t: float = 0.0
var _magnet: bool = false
var _life: float = 0.0

func setup_component(id: String, pos: Vector2) -> void:
	component_id = id
	position = pos
	velocity = Vector2(randf_range(-80, 80), randf_range(-240, -140))

func setup_scrap(amount: int, pos: Vector2) -> void:
	scrap_amount = amount
	position = pos
	velocity = Vector2(randf_range(-60, 60), randf_range(-200, -120))

func _ready() -> void:
	z_index = 35
	add_to_group("pickups")

func _process(delta: float) -> void:
	_t += delta
	_life += delta
	var players := get_tree().get_nodes_in_group("player")
	var player: Node2D = players[0] if players.size() > 0 else null

	if player != null and _life > 0.35:
		var d := global_position.distance_to(player.global_position)
		if d < 70.0:
			_magnet = true
		if _magnet:
			velocity = velocity.lerp((player.global_position - global_position).normalized() * 420.0, clampf(9.0 * delta, 0.0, 1.0))
		if d < 18.0:
			collected.emit(self)
			Audio.play("pickup")
			Fx.burst(global_position, color(), 6, 120.0)
			queue_free()
			return

	if not _magnet:
		velocity.y += 1100.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 240.0 * delta)
		if room != null and room.has_method("is_solid_at"):
			var next := global_position + velocity * delta
			if room.is_solid_at(next + Vector2(0, 6)):
				velocity.y = minf(velocity.y, 0.0)
				velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	position += velocity * delta
	queue_redraw()

func color() -> Color:
	if scrap_amount > 0:
		return Color(0.95, 0.85, 0.45)
	return Components.color_of(component_id)

func label() -> String:
	if scrap_amount > 0:
		return "%d scrap" % scrap_amount
	return String(Components.get_def(component_id).get("name", component_id))

func _draw() -> void:
	var c := color()
	var bob := sin(_t * 4.0) * 2.5
	var glow := c
	glow.a = 0.25 + 0.12 * sin(_t * 5.0)
	draw_circle(Vector2(0, bob), 14.0, glow)
	if scrap_amount > 0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, bob - 7), Vector2(6, bob), Vector2(0, bob + 7), Vector2(-6, bob),
		]), c)
	else:
		draw_rect(Rect2(-7, bob - 7, 14, 14), c)
		draw_rect(Rect2(-7, bob - 7, 14, 14), Color(0.05, 0.07, 0.1), false, 1.5)
		var glyph := String(Components.get_def(component_id).get("glyph", "?"))
		draw_string(ThemeDB.fallback_font, Vector2(-5, bob + 4), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.05, 0.07, 0.1))
