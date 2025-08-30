extends Node
# Facade: เปลี่ยนพฤติกรรม/สายพันธุ์/อายุ + เช็คปลดล็อกฟีเจอร์

@export var pet_node_path: NodePath
@export var default_breed: BreedResource
@export var age_months: float = 6.0              # ตั้งอายุเริ่มต้นที่นี่

@export var min_switch_ms := 180

@onready var _pet: Node = get_node_or_null(pet_node_path)

var _current: String = "idle"
var _last_switch_ms: int = 0

func _ready() -> void:
	if _pet == null:
		push_warning("Pet node not set.")
		return
	if default_breed:
		set_breed(default_breed)
	set_age_months(age_months) # กระจายอายุไปให้ตัวน้อง
	set_behavior("idle")

# ---------- Age ----------
func set_age_months(mo: float) -> void:
	age_months = max(mo, 0.0)
	if _pet and _pet.has_method("set_age_months"):
		_pet.call("set_age_months", age_months)

func get_age_stage() -> String:
	if _pet and _pet.has_method("get_age_stage"):
		return String(_pet.call("get_age_stage"))
	return "adult"

# ---------- Breed ----------
func set_breed(breed: BreedResource) -> void:
	if _pet and _pet.has_method("load_breed"):
		_pet.call("load_breed", breed)
		# เมื่อเปลี่ยนสายพันธุ์ ให้รีเฟรชช่วงวัยตามอายุปัจจุบัน
		set_age_months(age_months)

# ---------- Behavior ----------
func set_mood(mood: String) -> void:
	set_behavior(mood)

func set_behavior(behavior: String) -> void:
	if _pet == null: return
	var now: int = Time.get_ticks_msec()
	if behavior == _current and (now - _last_switch_ms) < min_switch_ms:
		return
	_last_switch_ms = now
	_current = behavior
	if _pet.has_method("set_behavior"):
		_pet.call("set_behavior", behavior)
	elif _pet.has_method("set_mood"):
		_pet.call("set_mood", behavior)

# ---------- Feature unlock ----------
func can_do(feature: String) -> bool:
	if _pet and _pet.has_method("can_do"):
		return bool(_pet.call("can_do", feature))
	return true
