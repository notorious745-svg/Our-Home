extends Resource
class_name QuestResource

@export var id: StringName = &"quest_id"
@export var title: String = "Daily Quest"
@export_multiline var description: String = ""

enum Category { ACTIVITY, CARE, TRAINING }
@export var category: Category = Category.ACTIVITY

# เงื่อนไขเบื้องต้น
@export var min_age_months: float = 0.0
@export var species_whitelist: PackedInt32Array = []   # ใช้เลข enum จาก BreedResource.Species ถ้าต้องการ

# รูปแบบการนับความคืบหน้า
# เช่น "walk", "bath", "feed", "train:sit"
@export var action_key: StringName = &"walk"
@export var target_count: int = 1

# รางวัล
@export var reward_coins: int = 20
@export var reward_items: Dictionary = {}

# รีเซ็ต
@export var is_daily: bool = true
@export var expires_same_day: bool = true

# น้ำหนักในการสุ่ม
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
