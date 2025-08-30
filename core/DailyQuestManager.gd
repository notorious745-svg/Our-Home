extends Node
# จัดการ Daily Quests (สุ่ม/รีเซ็ต/นับ/จ่ายรางวัล)

signal quests_updated
signal quest_progress(id: StringName, progress: int, target: int)
signal quest_completed(id: StringName)

@export var quest_folder: String = "res://quests"  # โฟลเดอร์ .tres ของ QuestResource
@export var num_daily_quests: int = 3
@export var use_persistence: bool = true

@export var pet_controller_path: NodePath
@onready var pet_controller: Node = get_node_or_null(pet_controller_path)

var _deck: Array[QuestResource] = []
var _today_key: String = ""
var _active: Array[Dictionary] = []     # [{id,title,desc,key,progress,target,reward_coins,completed}]
var _coins: int = 0

func _ready() -> void:
	_today_key = _date_key()
	_load_deck()
	_load_state()
	_ensure_todays_quests()
	emit_signal("quests_updated")

# เรียกเมื่อเกิดกิจกรรม เช่น "walk","bath","feed","train:sit"
func notify_activity(action_key: String) -> void:
	var changed: bool = false
	for i in range(_active.size()):
		var q: Dictionary = _active[i]
		if bool(q.get("completed", false)):
			continue
		if String(q.get("key", "")) == action_key:
			var p: int = int(q.get("progress", 0)) + 1
			q["progress"] = p
			_active[i] = q
			emit_signal("quest_progress", StringName(q["id"]), p, int(q["target"]))
			if p >= int(q["target"]):
				q["completed"] = true
				_active[i] = q
				_coins += int(q["reward_coins"])
				emit_signal("quest_completed", StringName(q["id"]))
			changed = true
	if changed:
		_save_state()
		emit_signal("quests_updated")

func get_active_quests() -> Array[Dictionary]:
	return _active.duplicate(true)

func get_coins() -> int:
	return _coins

func add_coins(v: int) -> void:
	_coins += max(v, 0)
	_save_state()
	emit_signal("quests_updated")

# ---------------- Internal ----------------
func _load_deck() -> void:
	_deck.clear()
	# โหลด .tres/.res ทั้งโฟลเดอร์ (ถ้าไม่มีจะสร้างเด็คดีฟอลต์)
	var abs_path: String = ProjectSettings.globalize_path(quest_folder)  # ชื่อใหม่ กันชนฟังก์ชัน abs()
	if DirAccess.dir_exists_absolute(abs_path):
		var dir: DirAccess = DirAccess.open(quest_folder)
		if dir:
			dir.list_dir_begin()
			var f: String = dir.get_next()
			while f != "":
				if not dir.current_is_dir() and (f.ends_with(".tres") or f.ends_with(".res")):
					var p: String = quest_folder.path_join(f)
					var res: Resource = ResourceLoader.load(p)
					if res is QuestResource:
						_deck.append(res as QuestResource)
				f = dir.get_next()
			dir.list_dir_end()
	if _deck.is_empty():
		_build_default_deck()

func _build_default_deck() -> void:
	var q1: QuestResource = QuestResource.new()
	q1.id = &"walk_1"
	q1.title = "ออกไปเดินเล่น"
	q1.description = "พาน้องเดินเล่น 1 ครั้ง"
	q1.action_key = &"walk"
	q1.target_count = 1
	q1.reward_coins = 15
	_deck.append(q1)

	var q2: QuestResource = QuestResource.new()
	q2.id = &"feed_2"
	q2.title = "ให้อาหาร"
	q2.description = "ให้อาหาร 2 ครั้ง"
	q2.action_key = &"feed"
	q2.target_count = 2
	q2.reward_coins = 10
	_deck.append(q2)

	var q3: QuestResource = QuestResource.new()
	q3.id = &"train_sit"
	q3.title = "ฝึกทริค: นั่ง"
	q3.description = "ฝึกนั่ง 1 ครั้ง"
	q3.category = QuestResource.Category.TRAINING
	q3.action_key = &"train:sit"
	q3.target_count = 1
	q3.reward_coins = 20
	_deck.append(q3)

	var q4: QuestResource = QuestResource.new()
	q4.id = &"bath"
	q4.title = "อาบน้ำ"
	q4.description = "อาบน้ำ 1 ครั้ง"
	q4.category = QuestResource.Category.CARE
	q4.action_key = &"bath"
	q4.target_count = 1
	q4.reward_coins = 12
	_deck.append(q4)

func _ensure_todays_quests() -> void:
	var now_key: String = _date_key()
	if now_key != _today_key:
		_today_key = now_key
		_active.clear()

	if _active.size() >= num_daily_quests:
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _seed_from_today()

	# อาจฟิลเตอร์ตามอายุขั้นต่ำของเควส
	var age_mo: float = 0.0
	if pet_controller != null:
		var v: Variant = pet_controller.get("age_months")
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			age_mo = float(v)

	var chosen: Dictionary = {}
	while _active.size() < num_daily_quests and not _deck.is_empty():
		var idx: int = int(rng.randi() % _deck.size())
		var q: QuestResource = _deck[idx]
		if chosen.has(q.id):
			continue
		if age_mo < q.min_age_months:
			continue

		chosen[q.id] = true
		_active.append({
			"id": q.id,
			"title": q.title,
			"desc": q.description,
			"key": String(q.action_key),
			"progress": 0,
			"target": q.target_count,
			"reward_coins": q.reward_coins,
			"completed": false
		})

	_save_state()

func _date_key() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var y: int = int(dt["year"])
	var m: int = int(dt["month"])
	var d: int = int(dt["day"])
	return "%04d-%02d-%02d" % [y, m, d]

func _seed_from_today() -> int:
	return _date_key().hash()

# --------------- Persistence ---------------
func _state_path() -> String:
	return "user://daily_quests.save"

func _load_state() -> void:
	_coins = 0
	if not use_persistence:
		return
	if not FileAccess.file_exists(_state_path()):
		return
	var f: FileAccess = FileAccess.open(_state_path(), FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		var dict: Dictionary = data
		_today_key = String(dict.get("today", _today_key))
		_coins = int(dict.get("coins", 0))
		_active = dict.get("active", []) if dict.has("active") else []

func _save_state() -> void:
	if not use_persistence:
		return
	var dict := {
		"today": _today_key,
		"coins": _coins,
		"active": _active
	}
	var text: String = JSON.stringify(dict)
	var f: FileAccess = FileAccess.open(_state_path(), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
