class_name Pet
extends Node2D

## A pet summoned by SUMMON PET (`Attacks._summon_pet`). It does nothing yet but
## keep its summoner company: it hovers behind their shoulder and follows them
## wherever they go, easing after them rather than stuck to them. One to a
## summoner. It is nobody's to hit, and goes when its summoner does — dead, or
## gone with the screen. Nothing here draws (`PetView`).

## Where it hovers, from its summoner's middle: behind them, and up by their
## shoulder.
const BEHIND := 30.0
const ABOVE := 38.0
## How quickly it catches up, per second: higher is tighter.
const FOLLOW := 5.0
## How far it bobs up and down as it hovers, and how fast.
const BOB := 3.0
const BOB_SPEED := 3.2

var summoner: Node2D = null
## Which way it faces: the way its summoner does.
var facing := 1
var _t := 0.0

func _ready() -> void:
	add_to_group("pets")

## Where it wants to be, over its summoner's shoulder, behind them.
func home() -> Vector2:
	var way := int(summoner.get("facing")) if summoner.get("facing") != null else 1
	return summoner.global_position + Vector2(-float(way) * BEHIND, -ABOVE)

func _process(delta: float) -> void:
	if summoner == null or not is_instance_valid(summoner) or bool(summoner.get("dead")):
		queue_free()
		return
	_t += delta
	var want := home() + Vector2(0, sin(_t * BOB_SPEED) * BOB)
	global_position = global_position.lerp(want, 1.0 - exp(-FOLLOW * delta))
	var way = summoner.get("facing")
	if way != null and int(way) != 0:
		facing = signi(int(way))

## The pet `summoner` has, or null.
static func of(summoner: Node, tree: SceneTree) -> Pet:
	if tree == null:
		return null
	for p in tree.get_nodes_in_group("pets"):
		if is_instance_valid(p) and not p.is_queued_for_deletion() and (p as Pet).summoner == summoner:
			return p
	return null
