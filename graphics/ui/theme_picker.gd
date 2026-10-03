class_name ThemePicker
extends VBoxContainer

## The hideout's looks, one a row, for the page the pause menu keeps for them
## while one is being chosen (`HideoutThemes`): the look in force lit and
## unpressable, the way the answer in force is on a settings row, and the rest
## to be pressed. Pressing one dresses the room in it there and then, behind
## the page, and the list is built again round the new answer — as it is when
## the look is changed by anything else.

## Whether the keyboard was on the list when a look was pressed, and so goes
## back onto it once it has been built again.
var _refocus := false

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	HideoutThemes.watch(_on_picked)
	_build(false)

## What a look's button is called, for whoever goes looking for one.
static func button_name(id: String) -> String:
	return "Look_%s" % id

func _build(refocus: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var first: Button = null
	for id: String in HideoutThemes.LOOKS:
		var in_force := id == HideoutThemes.picked()
		var b := UiKit.button(HideoutThemes.name_for(id), UiKit.ACCENT if in_force else UiKit.DIM, true)
		b.name = button_name(id)
		b.custom_minimum_size = Vector2(0, maxf(36, UiKit.thumb()))
		if in_force:
			UiKit.mark_chosen(b)
		b.pressed.connect(_pick.bind(id))
		add_child(b)
		if first == null and not in_force:
			first = b
	# The button just pressed is freed by its own press, and the one in its
	# place cannot hold the keyboard: it goes to the first look still to try.
	if refocus and first != null:
		first.grab_focus()

func _pick(id: String) -> void:
	Audio.play("ui")
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	_refocus = focused != null and is_ancestor_of(focused)
	HideoutThemes.pick(id)

func _on_picked(_id: String) -> void:
	_build(_refocus)
	_refocus = false
