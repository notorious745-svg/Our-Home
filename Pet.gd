extends Node3D
# Data-driven pet behaviors + age stages + procedural fallback per species (Godot 4.x)

@export var animation_player_path: NodePath            # e.g. %Anim หรือ ../AnimationPlayer
@export var model_anchor_path: NodePath = NodePath("%Model")
@export var age_months: float = 6.0                    # อายุเริ่มต้น (เดือน)

@onready var anim: AnimationPlayer = _find_anim()
@onready var model_anchor: Node3D = get_node_or_null(model_anchor_path)

const RUNTIME_LIB: StringName = &"__runtime"

# stage: "juvenile" | "teen" | "adult"
var _stage: String = "adult"
var current_behavior: String = "idle"
var current_breed: BreedResource = null

# multipliers ตามช่วงวัย (รีคอมพิวต์อัตโนมัติ)
var _stage_speed_mult: float = 1.0
var _stage_emote_amp_mult: float = 1.0
var _stage_gait_bob_mult: float = 1.0

# พารามิเตอร์ fallback ทั่วไป (ยังใช้อยู่)
@export var idle_amp: float   = 0.03
@export var idle_speed: float = 1.0
@export var happy_amp: float  = 0.18
@export var happy_speed: float = 2.2
@export var sad_amp: float    = 0.00
@export var sad_speed: float  = 0.6

# ====== Lifecycle =============================================================
func _ready() -> void:
	if model_anchor == null:
		var anchor := Node3D.new()
		anchor.name = "Model"
		add_child(anchor)
		model_anchor = anchor

	if anim == null:
		push_warning("AnimationPlayer not found. Set `animation_player_path` or create %Anim.")
	else:
		_create_or_refresh_core_animations()

	_update_stage_from_age()
	_refresh_model_for_stage()
	set_behavior("idle")

# ====== Public API ============================================================
func set_mood(mood: String) -> void:
	set_behavior(mood)

func set_behavior(behavior: String) -> void:
	current_behavior = _resolve_behavior_alias(behavior)
	_play_behavior(current_behavior)

func load_breed(breed: BreedResource) -> void:
	# clear old model
	for c in model_anchor.get_children():
		c.free()
	current_breed = breed
	_refresh_model_for_stage()
	# ปรับเอฟเฟ็กต์ตามวัยใหม่อีกรอบ (อ่านค่าจาก stage_params)
	_recompute_stage_effects()

func set_age_months(mo: float) -> void:
	age_months = max(mo, 0.0)
	_update_stage_from_age()
	_refresh_model_for_stage()
	_recompute_stage_effects()

func get_age_stage() -> String:
	return _stage

func can_do(feature: String) -> bool:
	if feature == "outdoor_walk":
		var min_age: float = 6.0
		if current_breed != null and current_breed.feature_unlocks.has("outdoor_walk_min_age_mo"):
			min_age = float(current_breed.feature_unlocks["outdoor_walk_min_age_mo"])
		return age_months >= min_age
	return true

# ====== Age / Stage ===========================================================
func _update_stage_from_age() -> void:
	var jmax: float = 3.0
	var tmax: float = 6.0
	if current_breed != null:
		if current_breed.age_thresholds.has("juvenile_max_mo"):
			jmax = float(current_breed.age_thresholds["juvenile_max_mo"])
		if current_breed.age_thresholds.has("teen_max_mo"):
			tmax = float(current_breed.age_thresholds["teen_max_mo"])

	var new_stage: String = "adult"
	if age_months < jmax:
		new_stage = "juvenile"
	elif age_months < tmax:
		new_stage = "teen"

	if new_stage != _stage:
		_stage = new_stage

func _refresh_model_for_stage() -> void:
	if current_breed == null:
		return

	# ลบลูกเดิมทั้งหมด
	for c in model_anchor.get_children():
		c.free()

	# เลือก scene ตามช่วงวัย
	var scene: PackedScene = null
	if _stage == "juvenile" and current_breed.juvenile_model_scene != null:
		scene = current_breed.juvenile_model_scene
	elif _stage == "teen" and current_breed.teen_model_scene != null:
		scene = current_breed.teen_model_scene
	else:
		scene = current_breed.model_scene

	if scene != null:
		var inst := scene.instantiate()
		model_anchor.add_child(inst)
		if inst is Node3D:
			var n3d: Node3D = inst as Node3D
			n3d.transform = Transform3D.IDENTITY

	# ตั้งสเกลตาม breed + stage
	var base: Vector3 = current_breed.model_scale
	var mul: float = _stage_scale_multiplier()
	model_anchor.scale = Vector3(base.x * mul, base.y * mul, base.z * mul)

func _stage_scale_multiplier() -> float:
	# 1) ใช้ scale จาก stage_params ถ้ามี
	var stage_scale: float = _stage_param_f("scale", 1.0)

	# 2) ถ้าเป็น teen และ breed ตั้ง teen_uses_adult_model=true ให้ใช้ teen_scale
	if _stage == "teen" and current_breed != null and current_breed.teen_uses_adult_model:
		stage_scale = current_breed.teen_scale

	# 3) ดีฟอลต์กรณีเด็กไม่มีโมเดลเฉพาะ → ย่อหน่อย
	if _stage == "juvenile" and current_breed != null and current_breed.juvenile_model_scene == null:
		if stage_scale == 1.0:
			stage_scale = 0.85

	return stage_scale

func _recompute_stage_effects() -> void:
	# speed_mult
	_stage_speed_mult = _stage_param_f("speed_mult", 1.0)
	# bob/gait
	_stage_gait_bob_mult = _stage_param_f("gait_bob_mult", 1.0)
	# อารมณ์ (happy/play) ขยายตาม play_bias (0..1) → 0.5 = กลาง
	var play_bias: float = _stage_param_f("play_bias", 0.5)
	_stage_emote_amp_mult = 0.8 + (play_bias * 0.4)  # 0.8..1.2

func _stage_param_f(key: String, default_value: float) -> float:
	if current_breed != null and current_breed.stage_params.has(_stage):
		var d: Dictionary = current_breed.stage_params[_stage]
		if d.has(key):
			return float(d[key])
	return default_value

# ====== Runtime Animations (core + lazy) =====================================
func _create_or_refresh_core_animations() -> void:
	if anim == null:
		return

	if anim.has_animation_library(RUNTIME_LIB):
		anim.remove_animation_library(RUNTIME_LIB)

	var lib := AnimationLibrary.new()

	var a_idle: Animation = Animation.new()
	a_idle.loop = true
	_add_bob_track(a_idle, idle_amp, idle_speed)
	lib.add_animation(&"idle", a_idle)

	var a_happy: Animation = Animation.new()
	a_happy.loop = true
	_add_bob_track(a_happy, happy_amp, happy_speed)
	_add_tilt_track(a_happy, 6.0, happy_speed * 1.2)
	lib.add_animation(&"happy", a_happy)

	var a_sad: Animation = Animation.new()
	a_sad.loop = true
	_add_bob_track(a_sad,  sad_amp,  sad_speed)
	_add_tilt_down_pose(a_sad, -14.0)
	lib.add_animation(&"sad", a_sad)

	anim.add_animation_library(RUNTIME_LIB, lib)

func _ensure_runtime_animation(behavior: String) -> void:
	if anim == null:
		return
	var key: StringName = _anim_key(behavior)
	if anim.has_animation(key):
		return

	var lib: AnimationLibrary = anim.get_animation_library(RUNTIME_LIB) as AnimationLibrary
	if lib == null:
		lib = AnimationLibrary.new()
		anim.add_animation_library(RUNTIME_LIB, lib)

	var built: Animation = _build_behavior_animation(behavior)
	if built != null:
		lib.add_animation(StringName(behavior), built)

# ====== Build per behavior (species + stage multipliers) ======================
func _build_behavior_animation(behavior: String) -> Animation:
	var sp: int = BreedResource.Species.DOG
	if current_breed != null:
		sp = current_breed.species

	match behavior:
		"idle":
			var a_idle: Animation = Animation.new(); a_idle.loop = true
			_add_bob_track(a_idle, idle_amp, idle_speed); return a_idle
		"happy":
			return _build_happy(sp)
		"sad":
			return _build_sad(sp)
		"affection":
			return _build_affection(sp)
		"walk":
			return _build_walk(sp, 1.0)
		"run":
			return _build_walk(sp, 2.0)
		"sit":
			return _build_sit(sp)
		"sleep":
			return _build_sleep(sp)
		"roll":
			return _build_roll(sp)
		"eat":
			return _build_eat(sp)
		"play":
			return _build_play(sp)
		"dog_lick_face":
			return _build_dog_lick()
		"cat_swat":
			return _build_cat_swat()
		_:
			var empty: Animation = Animation.new(); empty.loop = true
			return empty

func _build_happy(sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	var amp_mul: float = _stage_emote_amp_mult
	if sp == BreedResource.Species.DOG:
		_add_bob_track(a, happy_amp * amp_mul, happy_speed * _stage_speed_mult)
		_add_yaw_track(a, 12.0 * amp_mul, happy_speed * 1.3 * _stage_speed_mult)
	elif sp == BreedResource.Species.CAT:
		_add_bob_track(a, 0.04 * amp_mul, 1.2 * _stage_speed_mult)
		_add_tilt_track(a, 4.0 * amp_mul, 1.2 * _stage_speed_mult)
		_add_yaw_track(a, 3.0 * amp_mul, 2.0 * _stage_speed_mult)
	elif sp == BreedResource.Species.OTTER:
		_add_bob_track(a, 0.06 * amp_mul, 1.6 * _stage_speed_mult)
		_add_roll_track(a, 8.0 * amp_mul, 0.9 * _stage_speed_mult)
	else: # TURTLE และอื่น ๆ
		_add_bob_track(a, 0.01 * amp_mul, 0.6 * _stage_speed_mult)
		_add_tilt_track(a, 2.0 * amp_mul, 0.6 * _stage_speed_mult)
	return a

func _build_sad(sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	if sp == BreedResource.Species.DOG:
		_add_tilt_down_pose(a, -16.0)
	elif sp == BreedResource.Species.CAT:
		_add_tilt_down_pose(a, -10.0)
		_add_yaw_track(a, 2.0, 0.8 * _stage_speed_mult)
	elif sp == BreedResource.Species.OTTER:
		_add_tilt_down_pose(a, -12.0)
	else:
		_add_shrink_pose(a, -0.03) # เต่า: หดคอ
	return a

func _build_affection(sp: int) -> Animation:
	if sp == BreedResource.Species.DOG:
		return _build_dog_lick()
	elif sp == BreedResource.Species.CAT:
		var a_cat: Animation = Animation.new(); a_cat.loop = true
		_add_tilt_track(a_cat, 6.0, 1.2 * _stage_speed_mult)
		_add_bob_track(a_cat, 0.04, 1.4 * _stage_speed_mult) # head bunt-ish
		return a_cat
	elif sp == BreedResource.Species.OTTER:
		var a_ot: Animation = Animation.new(); a_ot.loop = true
		_add_bob_track(a_ot, 0.05, 1.4 * _stage_speed_mult)
		_add_yaw_track(a_ot, 6.0, 1.4 * _stage_speed_mult)
		return a_ot
	else:
		var a_tu: Animation = Animation.new(); a_tu.loop = true
		_add_extend_pose(a_tu, 0.025)
		return a_tu

func _build_walk(sp: int, speed_scale: float) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	var amp: float = 0.03
	var spd: float = 1.2
	if sp == BreedResource.Species.TURTLE:
		amp = 0.03 * 0.4
		spd = 0.5
	spd *= speed_scale * _stage_speed_mult
	_add_bob_track(a, amp * _stage_gait_bob_mult, spd)
	_add_tilt_track(a, 3.0 * speed_scale, spd)
	return a

func _build_sit(_sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_tilt_down_pose(a, -8.0)
	return a

func _build_sleep(_sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_roll_pose(a, 12.0)
	_add_bob_track(a, 0.01, 0.4)
	return a

func _build_roll(_sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_spin_track(a, 360.0, 1.2 * _stage_speed_mult)
	return a

func _build_eat(_sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_peck_track(a, 18.0, 1.2)
	return a

func _build_play(_sp: int) -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	var amp_mul: float = _stage_emote_amp_mult
	_add_bob_track(a, 0.06 * amp_mul, 1.6 * _stage_speed_mult)
	_add_yaw_track(a, 10.0 * amp_mul, 1.4 * _stage_speed_mult)
	return a

func _build_dog_lick() -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_lunge_track(a, 0.05, 2.0 * _stage_speed_mult)
	_add_yaw_track(a, 6.0, 1.2 * _stage_speed_mult)
	return a

func _build_cat_swat() -> Animation:
	var a: Animation = Animation.new(); a.loop = true
	_add_yaw_track(a, 18.0, 2.0 * _stage_speed_mult)
	_add_bob_track(a, 0.02, 1.2 * _stage_speed_mult)
	return a

# ====== Playback resolver =====================================================
func _play_behavior(behavior: String) -> void:
	if anim == null:
		return

	# 1) ถ้าสายพันธุ์ระบุคลิปจริงใน anim_map → ลองเล่นก่อน (ทุกไลบรารี)
	if current_breed != null and current_breed.anim_map.has(behavior):
		var clip: String = String(current_breed.anim_map[behavior])
		if clip != "":
			var clip_sn: StringName = StringName(clip)
			if anim.has_animation(clip_sn):
				anim.play(clip_sn); return
			var libs: PackedStringArray = anim.get_animation_library_list()
			for i in range(libs.size()):
				var key: StringName = StringName("%s/%s" % [String(libs[i]), clip])
				if anim.has_animation(key):
					anim.play(key); return

	# 2) ไม่มีคลิป → ตรวจ/สร้าง procedural runtime
	_ensure_runtime_animation(behavior)
	var rt_key: StringName = _anim_key(behavior)
	if anim.has_animation(rt_key):
		anim.play(rt_key)
		return
	var short_sn: StringName = StringName(behavior)
	if anim.has_animation(short_sn):
		anim.play(short_sn)
		return
	anim.play(_anim_key("idle"))

func _resolve_behavior_alias(behavior: String) -> String:
	if behavior == "affection" and current_breed != null:
		var sp: int = current_breed.species
		if sp == BreedResource.Species.DOG:   return "dog_lick_face"
		if sp == BreedResource.Species.CAT:   return "cat_swat"
	return behavior

# ====== Track helpers (typed) =================================================
func _add_bob_track(a: Animation, amp: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:position:y"))
	var dur: float = 2.0 / max(spd, 0.01)
	a.length = dur
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, amp),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -amp),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

func _add_tilt_track(a: Animation, deg_amp: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:x"))
	var dur: float = 2.0 / max(spd, 0.01)
	a.length = max(a.length, dur)
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, deg_amp),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -deg_amp),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

func _add_yaw_track(a: Animation, deg_amp: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:y"))
	var dur: float = 2.0 / max(spd, 0.01)
	a.length = max(a.length, dur)
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, deg_amp),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -deg_amp),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

func _add_roll_track(a: Animation, deg_amp: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:z"))
	var dur: float = 2.4 / max(spd, 0.01)
	a.length = max(a.length, dur)
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, deg_amp),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -deg_amp),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

func _add_spin_track(a: Animation, deg_total: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:z"))
	var dur: float = 1.2 / max(spd, 0.01)
	a.length = dur
	a.track_insert_key(t, 0.0, 0.0, 1.0)
	a.track_insert_key(t, dur, deg_total, 1.0)

func _add_tilt_down_pose(a: Animation, deg_down: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:x"))
	a.length = max(a.length, 1.0)
	a.track_insert_key(t, 0.0, deg_down, 1.0)
	a.track_insert_key(t, a.length, deg_down, 1.0)

func _add_roll_pose(a: Animation, deg: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:z"))
	a.length = max(a.length, 1.0)
	a.track_insert_key(t, 0.0, deg, 1.0)
	a.track_insert_key(t, a.length, deg, 1.0)

func _add_shrink_pose(a: Animation, dy: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:position:y"))
	a.length = max(a.length, 1.0)
	a.track_insert_key(t, 0.0, dy, 1.0)
	a.track_insert_key(t, a.length, dy, 1.0)

func _add_extend_pose(a: Animation, dz: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:position:z"))
	a.length = max(a.length, 1.0)
	a.track_insert_key(t, 0.0, dz, 1.0)
	a.track_insert_key(t, a.length, dz, 1.0)

func _add_lunge_track(a: Animation, z_amp: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:position:z"))
	var dur: float = 2.0 / max(spd, 0.01)
	a.length = max(a.length, dur)
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, z_amp),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -z_amp),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

func _add_peck_track(a: Animation, down_deg: float, spd: float) -> void:
	var t: int = a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(".:rotation_degrees:x"))
	var dur: float = 2.0 / max(spd, 0.01)
	a.length = max(a.length, dur)
	var keys: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(dur * 0.25, -down_deg),
		Vector2(dur * 0.5, 0.0),
		Vector2(dur * 0.75, -down_deg * 0.6),
		Vector2(dur, 0.0),
	]
	for k in keys:
		a.track_insert_key(t, k.x, k.y, 1.0)

# ====== Utils =================================================================
func _find_anim() -> AnimationPlayer:
	if String(animation_player_path) != "":
		var n: Node = get_node_or_null(animation_player_path)
		if n is AnimationPlayer:
			return n as AnimationPlayer
	var u: Node = get_node_or_null("%Anim")
	if u is AnimationPlayer:
		return u as AnimationPlayer
	var above: Node = get_node_or_null("../AnimationPlayer")
	if above is AnimationPlayer:
		return above as AnimationPlayer
	var below: Node = get_node_or_null("AnimationPlayer")
	if below is AnimationPlayer:
		return below as AnimationPlayer
	return null

func _anim_key(anim_name: String) -> StringName:
	return StringName("%s/%s" % [String(RUNTIME_LIB), anim_name])
