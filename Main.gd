extends Node3D

@onready var mesh: Node3D = $MeshInstance3D
@onready var pet: Node = $MeshInstance3D/Pet          # ✅ แก้ path ให้ตรงกับซีน
@onready var mic_player: AudioStreamPlayer = $MicPlayer

@export var use_mic: bool = false                      # ✅ ปิดไมค์ไว้ก่อน

var mic_bus: int = -1
var last_change: float = 0.0
var last_mood: String = "idle"

func _ready() -> void:
	if pet and pet.has_method("set_mood"):
		pet.set_mood("idle"); last_mood = "idle"

	if use_mic:
		var mic := AudioStreamMicrophone.new()
		mic_player.stream = mic
		mic_player.bus = "Mic"
		mic_player.play()
		mic_bus = AudioServer.get_bus_index("Mic")
		if mic_bus == -1:
			push_warning('Audio bus "Mic" not found. Create it in Project > Audio > Bus Layout.')
	else:
		mic_bus = -1  # ✅ ปิดไมค์ = ไม่อ่านเสียง

func _process(delta: float) -> void:
	if mic_bus == -1:
		return  # ✅ ตอนนี้ทดสอบด้วยคีย์บอร์ดอย่างเดียว

	# (โค้ดอ่าน dB ของคุณคงเดิมได้เลย ถ้าจะใช้ไมค์ในภายหลัง)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and pet:
		match event.keycode:
			KEY_ENTER:
				pet.set_mood("happy"); last_mood = "happy"
			KEY_ESCAPE:
				pet.set_mood("sad"); last_mood = "sad"
			_:
				pet.set_mood("idle"); last_mood = "idle"
