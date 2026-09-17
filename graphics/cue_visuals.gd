extends Node

## What every gameplay cue looks like.
##
## This is the graphics module's half of the seam: `feature/` says *a hit
## landed*, and the table below decides that a hit landed means six sparks in
## the payload's element colour and three pixels of shake. Retuning the feel of
## the whole game is an edit to this one file, and it touches no rule.
##
## An unhandled cue is silence, not an error.

func _ready() -> void:
	Cues.fired.connect(_on_cue)

func _on_cue(name: StringName, d: Dictionary) -> void:
	var pos: Vector2 = d.get("pos", Vector2.ZERO)
	match name:
		&"hit":
			Fx.burst(pos, Style.element_color(d.get("payload")), 6, 150.0)
			Fx.shake(3.0)
		&"impact":
			var spent: bool = String(d.get("kind", "")) == "spent"
			Fx.burst(pos, Style.element_color(d.get("payload")),
				6 if spent else 5, 130.0 if spent else 110.0)
		&"melee_arc":
			Fx.shake(2.5)
		&"area_blast":
			Fx.shake(6.0)
		&"lunge_cut":
			Fx.shake(4.0)
		&"blink":
			Fx.burst(d.get("from", pos), Style.BLINK_TRAIL, 10, 160.0)
			Fx.burst(d.get("to", pos), Style.BLINK_TRAIL, 10, 160.0)
		&"death":
			Fx.burst(pos, _death_color(d.get("actor")), 14, 230.0)
		&"jump":
			_jump(pos, String(d.get("kind", "ground")))
		&"wall_slide":
			# Sparse on purpose: a scrape, not a jet.
			if randf() < 0.3:
				Fx.burst(pos + Vector2(int(d.get("dir", 1)) * 10, 8), Style.WALL_DUST, 1, 40.0)
		&"refused":
			Fx.text(pos + Vector2(0, -44), String(d.get("text", "")),
				Style.refuse_color(String(d.get("kind", ""))))
		&"shatter":
			# Frost coming apart reads as shards, not as a bigger hit.
			Fx.burst(pos, Style.SHATTER_SPARK, 10, 210.0)
			Fx.shake(4.0)
		&"pull":
			# The ring is drawn at the reach the pull actually had, so what it
			# gathered and what the player saw are the same circle.
			Fx.ring(pos, Style.PULL_RING, float(d.get("radius", 150.0)))
			Fx.shake(3.5)
		&"mana_drain":
			Fx.burst(pos, Style.MANA_SPARK, 4, 90.0)
		&"parry":
			Fx.shake(8.0)
			Fx.ring(pos, Style.PARRY, 60.0)
			Fx.text(pos + Vector2(0, -30), "PARRY", Style.PARRY)
		&"hurt":
			Fx.shake(7.0)
		&"boss_phase":
			Fx.shake(14.0)
			Fx.ring(pos, Style.BOSS_RING, 160.0)
			Fx.text(pos + Vector2(0, -60), String(d.get("text", "")), Style.BOSS_TEXT)
		&"pickup":
			Fx.burst(pos, Style.loot_color(String(d.get("id", "")), int(d.get("scrap", 0))), 6, 120.0)
		&"travel":
			Fx.burst(pos, Style.TRAVEL_DUST, 8, 120.0)
		&"extract_tick":
			Fx.burst(pos, Style.EXTRACT_SPARK, 2, 60.0)
		&"raid_lost":
			Fx.shake(16.0)

func _jump(pos: Vector2, kind: String) -> void:
	match kind:
		"ground":
			Fx.burst(pos + Vector2(0, 14), Style.JUMP_DUST, 4, 70.0)
		"air":
			# The air jump gets a ring as well: it is a move you can run out of,
			# so it should look like it cost something.
			Fx.ring(pos + Vector2(0, 10), Color(0.7, 0.9, 1.0), 22.0)
			Fx.burst(pos + Vector2(0, 12), Style.JUMP_DUST, 6, 90.0)

## A death throws the colour of whatever died.
func _death_color(actor) -> Color:
	if actor is Enemy and is_instance_valid(actor):
		if (actor as Enemy).phase > 1:
			return Style.BOSS_PHASE2_COLOR
		return Style.monster_color((actor as Enemy).kind)
	return Style.PLAYER_COLOR
