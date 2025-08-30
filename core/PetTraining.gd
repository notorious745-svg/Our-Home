extends Node
# ระบบฝึกทริคพื้นฐาน + แจ้งเควส

signal trick_learned(trick: StringName)

@export var pet_controller_path: NodePath
@export var quest_manager_path: NodePath
@export var repeats_to_learn: int = 3

@onready var pet_controller: Node = get_node_or_null(pet_controller_path)
@onready var quest_manager: Node = get_node_or_null(quest_manager_path)

var _progress: Dictionary = {}   # { "sit": 1, "paw": 2, ... }
var _learned: Dictionary = {}    # { "sit": true, ... }

func _ready() -> void:
	_load()

# ---------- Public ----------
func train(trick: StringName) -> void:
	var behavior: String = _trick_to_behavior(trick)
	_play(behavior)

	var key: String = String(trick)
	var c: int = int(_progress.get(key, 0)) + 1
	_progress[key] = c
	_save()

	_notify("train:" + key)

	if c >= repeats_to_learn and not bool(_learned.get(key, false)):
		_learned[key] = true
		_save()
		emit_signal("trick_learned", trick)

func has_learned(trick: StringName) -> bool:
	return bool(_learned.get(String(trick), false))

# ---------- Internal ----------
func _play(behavior: String) -> void:
	if pet_controller and pet_controller.has_method("set_behavior"):
		pet_controller.call("set_behavior", behavior)

func _notify(key: String) -> void:
	if quest_manager and quest_manager.has_method("notify_activity"):
		quest_manager.call("notify_activity", key)

func _trick_to_behavior(trick: StringName) -> String:
	var t: String = String(trick)
	if t == "sit":
		return "sit"
	if t == "lie" or t == "down":
		return "sleep"
	if t == "paw" or t == "shake":
		return "happy"
	return "play"

# ---------- Persistence ----------
func _path() -> String:
	return "user://training.save"

func _load() -> void:
	_progress.clear()
	_learned.clear()
	if not FileAccess.file_exists(_path()):
		return
	var f: FileAccess = FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		_progress = d.get("progress", {})
		_learned  = d.get("learned", {})

func _save() -> void:
	var d := { "progress": _progress, "learned": _learned }
	var text: String = JSON.stringify(d)
	var f: FileAccess = FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
