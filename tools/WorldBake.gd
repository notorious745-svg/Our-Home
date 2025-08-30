@tool
extends EditorScript
class_name WorldBake
# ใช้:
# godot --headless --editor --script res://tools/WorldBake.gd -- -layout res://tools/world_layout.json -out res://scenes/world/park.tscn

static func _read_text(path: String) -> String:
	if not path.begins_with("res://") and not path.begins_with("user://"):
		push_error("WorldBake: path must start with res:// or user:// -> " + path)
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("WorldBake: cannot open -> " + path)
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s

static func _own_tree(n: Node, owner: Node) -> void:
	for c in n.get_children():
		if c.owner == null:
			c.owner = owner
		_own_tree(c, owner)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var layout_path: String = ""
	var out_path: String = "res://scenes/world/out.tscn"

	# ---- parse args ----
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if (a == "-layout" or a == "--layout") and i + 1 < args.size():
			layout_path = args[i + 1]; i += 1
		elif (a == "-out" or a == "--out") and i + 1 < args.size():
			out_path = args[i + 1]; i += 1
		i += 1

	if layout_path == "":
		push_error("WorldBake: please pass -layout <res://...json>")
		return

	# ---- read JSON ----
	var text: String = _read_text(layout_path)
	if text == "":
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("WorldBake: JSON root must be a dictionary.")
		return
	var cfg: Dictionary = data

	# schema:
	# { "cell_size":[4,0,4], "rows":["AAA.."], "stamps":{"A":"res://..A.tscn",".":""},
	#   "random_yaw_on":["T"], "place":[{"scene":"res://core/ScenePortal.tscn","at":[0,0,0],"set":{"target_scene":"shop"}}],
	#   "add_light": true }

	var cell_size: Vector3 = Vector3(4, 0, 4)
	if cfg.has("cell_size"):
		var cs: Array = cfg["cell_size"]
		if cs.size() >= 3:
			cell_size = Vector3(float(cs[0]), float(cs[1]), float(cs[2]))

	var rows: PackedStringArray = []
	if cfg.has("rows"): rows = PackedStringArray(cfg["rows"])

	var stamps: Dictionary = {}
	if cfg.has("stamps"): stamps = cfg["stamps"]

	var random_yaw_on: PackedStringArray = []
	if cfg.has("random_yaw_on"): random_yaw_on = PackedStringArray(cfg["random_yaw_on"])

	var placements: Array = []
	if cfg.has("place"): placements = cfg["place"]

	var add_light: bool = bool(cfg.get("add_light", true))

	# ---- build root ----
	var root: Node3D = Node3D.new()
	root.name = "World"

	if add_light:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-40, 35, 0)
		root.add_child(sun)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# ---- lay out stamps (ASCII map) ----
	for z in range(rows.size()):
		var row: String = rows[z]
		for x in range(row.length()):
			var key: String = row.substr(x, 1)
			if not stamps.has(key): continue
			var spath: String = String(stamps[key])
			if spath == "" or spath == "null": continue
			var ps_res: Resource = ResourceLoader.load(spath)
			if ps_res is PackedScene:
				var inst: Node = (ps_res as PackedScene).instantiate()
				root.add_child(inst)
				if inst is Node3D:
					var pos: Vector3 = Vector3(x * cell_size.x, 0.0, z * cell_size.z)
					var n3d: Node3D = inst as Node3D
					n3d.transform = Transform3D(Basis(), pos)
					if random_yaw_on.has(key):
						n3d.rotate_y(deg_to_rad(rng.randf_range(0.0, 360.0)))

	# ---- arbitrary placements ----
	for item in placements:
		if typeof(item) != TYPE_DICTIONARY: continue
		var it: Dictionary = item
		var scene_path: String = String(it.get("scene", ""))
		var at: Array = it.get("at", [0, 0, 0])
		var set_props: Dictionary = it.get("set", {})
		if scene_path == "": continue
		var rs: Resource = ResourceLoader.load(scene_path)
		var node: Node = null
		if rs is PackedScene:
			node = (rs as PackedScene).instantiate()
		else:
			continue
		root.add_child(node)
		if node is Node3D:
			var v3: Vector3 = Vector3(float(at[0]), float(at[1]), float(at[2]))
			(node as Node3D).transform = Transform3D(Basis(), v3)
		for k in set_props.keys():
			var key2: String = String(k)
			var val: Variant = set_props[k]
			if node.has_method("set"):
				node.set(key2, val)

	# ---- save scene ----
	_own_tree(root, root)
	var packed: PackedScene = PackedScene.new()
	var ok: int = packed.pack(root)
	if ok != OK:
		push_error("WorldBake: pack() failed with code %d" % ok)
		return
	var err: int = ResourceSaver.save(packed, out_path) # <-- ส่ง Resource ก่อน path
	if err != OK:
		push_error("WorldBake: save failed -> %s (code %d)" % [out_path, err])
		return
	print("WorldBake: saved -> " + out_path)
