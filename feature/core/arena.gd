extends Node

## Where live world nodes belong.
##
## Attacks, loose pickups and scheduled follow-ups have to be parented
## somewhere that outlives the actor that made them but dies with the screen.
## Whatever screen is running — a raid, the sandbox, a test harness — registers
## itself here, and everything that spawns into the world asks for it by name
## rather than carrying a reference down through every call.

var world: Node = null

func register(w: Node) -> void:
	world = w

func current() -> Node:
	if world == null or not is_instance_valid(world):
		return null
	return world
