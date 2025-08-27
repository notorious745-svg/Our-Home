# res://core/PetController.gd
extends Node
class_name PetController

@export var pet_node: NodePath                    # points to node with set_mood()
@export var use_anim_tree: bool = false
@export var anim_tree_path: NodePath

const MOODS := { "IDLE": "idle", "HAPPY": "happy", "SAD": "sad" }

var _pet: Node = null
var _tree: AnimationTree = null

func _ready() -> void:
	if pet_node != NodePath():
		_pet = get_node_or_null(pet_node)
	if use_anim_tree and anim_tree_path != NodePath():
		_tree = get_node_or_null(anim_tree_path)
	if Engine.has_singleton("PetMemory"):
		PetMemory.mood_changed.connect(_on_global_mood_changed)

func _on_global_mood_changed(m: String, intensity: float) -> void:
	set_mood(m, intensity)

func set_mood(mood: String, intensity: float = 0.0) -> void:
	if _pet and _pet.has_method("set_mood"):
		_pet.call("set_mood", mood)
		return
	if use_anim_tree and _tree:
		_tree.set("parameters/mood/current", mood)
		_tree.set("parameters/speed_scale", 1.0 + 0.3 * clamp(intensity, 0.0, 1.0))
		return
	push_warning("PetController: no target bound; mood not applied.")

func perform_action(_action: String) -> void:
	pass

func set_breed(_breed_id: String) -> void:
	pass
