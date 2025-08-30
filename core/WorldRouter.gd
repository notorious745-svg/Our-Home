extends Node
class_name WorldRouter

@export var world_folder: String = "res://scenes/world"  # โฟลเดอร์ .tscn ของฉากย่อย
@export var default_scene: String = ""                    # เช่น "park" (ปล่อยว่าง = ไม่โหลดอัตโนมัติ)

var _current: Node = null

func _ready() -> void:
	if default_scene != "":
		go_to(default_scene)

func go_to(scene_name: String) -> void:
	var path: String = "%s/%s.tscn" % [world_folder, scene_name]
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_warning("WorldRouter: scene not found -> " + path)
		return
	_swap_scene(ps)

func _swap_scene(ps: PackedScene) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = ps.instantiate()
	add_child(_current)
