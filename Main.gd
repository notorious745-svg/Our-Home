extends Node
# Main: จัดการอินพุต + ไมค์ + เปลี่ยนอารมณ์น้องผ่าน PetController (มี fallback)

@export var use_mic: bool = false
@export var pet_controller_path: NodePath
@export var debug_input: bool = false

@onready var pet_controller: Node = null

const ACT_HAPPY := "pet_happy"
const ACT_SAD   := "pet_sad"

func _ready() -> void:
	set_process_unhandled_input(true)
	_ensure_input_actions()
	_configure_mic_bus()
	pet_controller = _resolve_controller()
	if pet_controller == null:
		push_warning("PetController not assigned; using direct Pet fallback.")

func _configure_mic_bus() -> void:
	var idx: int = AudioServer.get_bus_index("Mic")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, not use_mic)
	else:
		push_warning("Audio bus 'Mic' not found. Skipping mic toggle.")

func _ensure_input_actions() -> void:
	if not InputMap.has_action(ACT_HAPPY): InputMap.add_action(ACT_HAPPY)
	if not InputMap.has_action(ACT_SAD):   InputMap.add_action(ACT_SAD)

	for ev in InputMap.action_get_events(ACT_HAPPY): InputMap.action_erase_event(ACT_HAPPY, ev)
	for ev in InputMap.action_get_events(ACT_SAD):   InputMap.action_erase_event(ACT_SAD, ev)

	var e1 := InputEventKey.new(); e1.keycode = KEY_ENTER
	var e2 := InputEventKey.new(); e2.keycode = KEY_KP_ENTER
	InputMap.action_add_event(ACT_HAPPY, e1); InputMap.action_add_event(ACT_HAPPY, e2)

	var e3 := InputEventKey.new(); e3.keycode = KEY_ESCAPE
	InputMap.action_add_event(ACT_SAD, e3)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var ev: InputEventKey = event as InputEventKey
	if ev.echo or not ev.pressed: return

	# ✅ Fallback ตรวจ keycode ตรง ๆ กันพลาดจาก mapping
	var is_happy := InputMap.event_is_action(event, ACT_HAPPY) or ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER
	var is_sad   := InputMap.event_is_action(event, ACT_SAD)   or ev.keycode == KEY_ESCAPE

	if is_happy:
		if debug_input: print("[INPUT] HAPPY (", ev.keycode, ")")
		_set_mood("happy")
	elif is_sad:
		if debug_input: print("[INPUT] SAD (ESC)")
		_set_mood("sad")
	else:
		if debug_input: print("[INPUT] IDLE (key:", ev.keycode, ")")
		_set_mood("idle")

func _set_mood(mood: String) -> void:
	if pet_controller and pet_controller.has_method("set_mood"):
		pet_controller.call("set_mood", mood); return

	var pet: Node = find_child("Pet", true, false)
	if pet and pet.has_method("set_mood"):
		pet.call("set_mood", mood); return

	var any: Node = _find_node_with_method("set_mood")
	if any: any.call("set_mood", mood)

func _resolve_controller() -> Node:
	if String(pet_controller_path) != "":
		var n: Node = get_node_or_null(pet_controller_path)
		if n != null: return n
	return find_child("PetController", true, false)

func _find_node_with_method(method_name: String) -> Node:
	var q: Array[Node] = []; q.push_back(self)
	while q.size() > 0:
		var cur: Node = q.pop_front() as Node
		if cur != self and cur.has_method(method_name): return cur
		var children: Array = cur.get_children()
		for i in children.size():
			var child: Node = children[i] as Node
			q.push_back(child)
	return null
