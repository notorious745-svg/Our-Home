# Pet.gd — ติดกับโหนด "Pet" (พี่น้องกับ AnimationPlayer ใต้ MeshInstance3D)
extends Node

@onready var anim_player: AnimationPlayer = $"../AnimationPlayer"  # sibling
var current_mood := "idle"
var micro_timer := 0.0
var next_micro := 3.0

func _ready() -> void:
	if anim_player == null:
		push_error("AnimationPlayer not found as sibling")
		return
	_create_animations()
	set_mood("idle")
	randomize()

func set_mood(mood: String) -> void:
	current_mood = mood
	if anim_player.has_animation(mood):
		anim_player.seek(0.0, true)
		anim_player.play(mood)
		match mood:
			"happy":
				anim_player.speed_scale = 1.3
			"sad":
				anim_player.speed_scale = 0.9
			_:
				anim_player.speed_scale = 1.0
	else:
		push_error("Unknown mood animation: %s" % mood)

func _process(_delta: float) -> void:   # ใช้ _delta กัน Warning-as-error
	micro_timer += _delta
	if micro_timer >= next_micro:
		micro_timer = 0.0
		next_micro = randf_range(3.0, 7.0)
		_perform_micro_motion()

func _perform_micro_motion() -> void:
	var mesh := get_parent() as Node3D  # พาเรนต์ของ Pet คือ MeshInstance3D
	if mesh == null:
		return
	var start_x := mesh.rotation_degrees.x
	var tween := create_tween()
	tween.tween_property(mesh, "rotation_degrees:x", start_x + randf_range(-2.0, 2.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "rotation_degrees:x", start_x, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _clear_anims() -> void:
	for anim_name in anim_player.get_animation_list():  # รีเนมตัวแปรกัน shadowing
		anim_player.remove_animation(anim_name)

func _create_animations() -> void:
	_clear_anims()

	# ยิงใส่เมช (พาเรนต์ของ AnimationPlayer) ด้วยพาธสัมพัทธ์ ".."
	var root := ".."

	# --- idle: หายใจช้า + กระพริบเล็กน้อย ---
	var idle := Animation.new()
	idle.length = 3.5
	idle.loop_mode = Animation.LOOP_LINEAR
	var t := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(t, NodePath("%s:rotation_degrees:x" % root))
	idle.track_insert_key(t, 0.0, -2.5)
	idle.track_insert_key(t, 1.75, 2.5)
	idle.track_insert_key(t, 3.5, -2.5)

	var blink := idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(blink, NodePath("%s:rotation_degrees:z" % root))
	idle.track_insert_key(blink, 1.20, 0.0)
	idle.track_insert_key(blink, 1.25, -1.0)
	idle.track_insert_key(blink, 1.30, 0.0)
	idle.track_insert_key(blink, 3.00, 0.0)
	idle.track_insert_key(blink, 3.05, 1.0)
	idle.track_insert_key(blink, 3.10, 0.0)

	anim_player.add_animation("idle", idle)

	# --- happy: ส่ายเร็ว + เด้งแรง ---
	var happy := Animation.new()
	happy.length = 0.65
	happy.loop_mode = Animation.LOOP_LINEAR

	var ry := happy.add_track(Animation.TYPE_VALUE)
	happy.track_set_path(ry, NodePath("%s:rotation_degrees:y" % root))
	happy.track_insert_key(ry, 0.0, -28.0)
	happy.track_insert_key(ry, 0.325, 28.0)
	happy.track_insert_key(ry, 0.65, -28.0)

	var by := happy.add_track(Animation.TYPE_VALUE)
	happy.track_set_path(by, NodePath("%s:position:y" % root))
	happy.track_insert_key(by, 0.0, 0.0)
	happy.track_insert_key(by, 0.325, 0.14)
	happy.track_insert_key(by, 0.65, 0.0)

	anim_player.add_animation("happy", happy)

	# --- sad: ค่อย ๆ ยุบตัวลง + ก้มหัวค้าง ---
	var sad := Animation.new()
	sad.length = 1.2
	sad.loop_mode = Animation.LOOP_LINEAR

	var py := sad.add_track(Animation.TYPE_VALUE)
	sad.track_set_path(py, NodePath("%s:position:y" % root))
	sad.track_insert_key(py, 0.0, 0.0)
	sad.track_insert_key(py, 1.2, -0.05)
	sad.track_set_interpolation_type(py, Animation.INTERPOLATION_CUBIC)

	var rx := sad.add_track(Animation.TYPE_VALUE)
	sad.track_set_path(rx, NodePath("%s:rotation_degrees:x" % root))
	sad.track_insert_key(rx, 0.0, 10.0)
	sad.track_insert_key(rx, 1.2, 18.0)
	sad.track_set_interpolation_type(rx, Animation.INTERPOLATION_CUBIC)

	anim_player.add_animation("sad", sad)
