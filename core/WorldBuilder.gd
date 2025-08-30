@tool
extends Node3D
class_name WorldBuilder

# ---------- โหมด ----------
@export var use_json: bool = false
@export_file("*.json") var layout_path: String = "res://tools/world_layout.json"

# ---------- โหมด Inspector (ไม่ใช้ JSON) ----------
@export var cell_size: Vector3 = Vector3(6, 0, 6)
@export var layout: PackedStringArray = [
	"AAA..BBB..TTTT",
	"A..T..B...T..T",
	"A..T..B...T..T",
	"AAA..BBB..TTTT",
]
# คีย์ (ตัวอักษร) -> Scene (ลาก .tscn ได้ หรือใส่พาธ string ก็ได้)
@export var stamps: Dictionary = {
	"A": null,  # ตึก A
	"B": null,  # ตึก B
	"T": null,  # ต้นไม้
	".": null   # ช่องว่าง
}
@export var random_yaw_on: PackedStringArray = ["T"]
@export var add_light: bool = true

# ---------- ปุ่มใน Inspector ----------
@export var rebuild_now: bool = false:
	set(value):
		if value:
			build()
			set_deferred("rebuild_now", false) # กัน setter เรียกตัวเองซ้ำ

@export var clear_built: bool = false:
	set(value):
		if value:
			_clear_children()
			set_deferred("clear_built", false) # กัน setter เรียกตัวเองซ้ำ

# ---------- ภายใน ----------
var _map_root: Node3D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_ensure_root()

func _ensure_root() -> void:
	if _map_root == null or not is_instance_valid(_map_root):
		_map_root = Node3D.new()
		_map_root.name = "MapRoot"
		add_child(_map_root)

func _clear_children() -> void:
	_ensure_root()
	for c in _map_root.get_children():
		c.queue_free()

func build() -> void:
	_ensure_root()
	_clear_children()

	var cs: Vector3 = cell_size
	var rows: PackedStringArray = layout
	var key_to_scene: Dictionary = stamps
	var yaw_keys: PackedStringArray = random_yaw_on
	var add_sun: bool = add_light

	# ถ้าใช้ JSON ให้อ่านค่าแทน
	if use_json:
		var f: FileAccess = FileAccess.open(layout_path, FileAccess.READ)
		if f == null:
			push_error("WorldBuilder: cannot open JSON -> " + layout_path)
			return
		var text: String = f.get_as_text()
		f.close()
		var data: Variant = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY:
			push_error("WorldBuilder: JSON root must be a dictionary")
			return
		var cfg: Dictionary = data
		if cfg.has("cell_size"):
			var arr: Array = cfg["cell_size"]
			if arr.size() >= 3:
				cs = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		if cfg.has("rows"):
			rows = PackedStringArray(cfg["rows"])
		if cfg.has("stamps"):
			key_to_scene = cfg["stamps"]
		if cfg.has("random_yaw_on"):
			yaw_keys = PackedStringArray(cfg["random_yaw_on"])
		add_sun = bool(cfg.get("add_light", add_light))

	# แสงเบาๆ สำหรับดูฉาก
	if add_sun:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-40, 35, 0)
		_map_root.add_child(sun)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# วางชิ้นตามแผนผังตัวอักษร
	for z in range(rows.size()):
		var row: String = rows[z]
		for x in range(row.length()):
			var key: String = row.substr(x, 1)
			if not key_to_scene.has(key):
				continue

			var ps: PackedScene = _as_packed_scene(key_to_scene[key])
			if ps == null:
				continue

			var inst: Node = ps.instantiate()
			_map_root.add_child(inst)
			if inst is Node3D:
				var pos: Vector3 = Vector3(x * cs.x, 0.0, z * cs.z)
				var n3d: Node3D = inst as Node3D
				n3d.transform = Transform3D(Basis(), pos)
				if yaw_keys.has(key):
					n3d.rotate_y(deg_to_rad(rng.randf_range(0.0, 360.0)))

	print("WorldBuilder: built with %d rows" % rows.size())

# รับทั้ง String path และ PackedScene จาก Inspector
func _as_packed_scene(entry: Variant) -> PackedScene:
	if entry is PackedScene:
		return entry
	elif typeof(entry) == TYPE_STRING and String(entry) != "":
		var res: Resource = ResourceLoader.load(String(entry))
		return res as PackedScene
	return null
