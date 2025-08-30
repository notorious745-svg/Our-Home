extends Area3D
class_name ScenePortal

@export var target_scene: String = "park"     # ชื่อไฟล์ .tscn (ไม่ต้องมีนามสกุล)
@export var world_router_path: NodePath
@onready var router: Node = get_node_or_null(world_router_path)

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	# ให้ Player ใส่ group "player" หรือชื่อ Node เป็น "PlayerFPS"
	if body.is_in_group("player") or body.name == "PlayerFPS":
		if router != null and router.has_method("go_to"):
			router.call("go_to", target_scene)
