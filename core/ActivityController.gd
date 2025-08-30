extends Node
# รวมกิจกรรมหลัก: อาบน้ำ/เดิน/กิน/เล่น/ให้อาหาร และแจ้ง DailyQuestManager

@export var pet_controller_path: NodePath
@export var quest_manager_path: NodePath

@onready var pet_controller: Node = get_node_or_null(pet_controller_path)
@onready var quest_manager: Node = get_node_or_null(quest_manager_path)

# ===== Public API =====
func walk() -> void:
	if _can_do_outdoor():
		_play("walk")
		_notify("walk")

func run() -> void:
	if _can_do_outdoor():
		_play("run")
		_notify("walk") # จะนับรวมเป็นเควสเดินเล่น; อยากแยกก็เปลี่ยนเป็น "run"

func bath() -> void:
	_play("play") # ทดแทนชั่วคราว ถ้ายังไม่มีคลิป "bath"
	_notify("bath")

func feed() -> void:
	_play("eat")
	_notify("feed")

func play_together() -> void:
	_play("play")
	_notify("play")

func sit() -> void:   _play("sit")
func sleep() -> void: _play("sleep")

# ===== Internal =====
func _play(behavior: String) -> void:
	if pet_controller and pet_controller.has_method("set_behavior"):
		pet_controller.call("set_behavior", behavior)
	elif pet_controller and pet_controller.has_method("set_mood"):
		pet_controller.call("set_mood", behavior)

func _notify(key: String) -> void:
	if quest_manager and quest_manager.has_method("notify_activity"):
		quest_manager.call("notify_activity", key)

func _can_do_outdoor() -> bool:
	if pet_controller and pet_controller.has_method("can_do"):
		return bool(pet_controller.call("can_do", "outdoor_walk"))
	return true
