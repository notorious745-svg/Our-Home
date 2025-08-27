extends Resource
class_name BreedResource

@export var id: String = ""
@export var display_name: String = ""
@export var model: PackedScene
@export var animation_map: Dictionary = {
"idle": "Idle",
"happy": "Happy",
"sad": "Sad"
}
@export var voice_set: String = ""
@export var notes: String = ""
