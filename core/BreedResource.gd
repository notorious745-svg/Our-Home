extends Resource
class_name BreedResource

# รองรับชนิดเพิ่มได้เรื่อย ๆ
enum Species { DOG, CAT, OTTER, TURTLE, BIRD, MONKEY, CAPYBARA, ALPACA }

@export var breed_name: StringName = &"Unknown"
@export var species: Species = Species.DOG

# โมเดลพื้นฐาน (ผู้ใหญ่)
@export var model_scene: PackedScene
@export var model_scale: Vector3 = Vector3.ONE

# โมเดลช่วงวัย
@export var juvenile_model_scene: PackedScene          # ถ้ามีจะใช้แทนตอนเป็นเด็ก
@export var teen_model_scene: PackedScene              # ปล่อยว่างไว้ได้ (ส่วนใหญ่ใช้โมเดลผู้ใหญ่)
@export var teen_uses_adult_model: bool = true         # true = ใช้โมเดลผู้ใหญ่สำหรับวัยรุ่น
@export_range(0.1, 1.0, 0.01) var teen_scale: float = 0.90

# เกณฑ์ช่วงวัย (หน่วย "เดือน")
# ดีฟอลต์ตรงที่คุยไว้: <3 = เด็ก, 3–6 = วัยรุ่น, >6 = ผู้ใหญ่
@export var age_thresholds: Dictionary = {
	"juvenile_max_mo": 3.0,
	"teen_max_mo": 6.0
}

# ปลดล็อกฟีเจอร์ตามอายุ (ตัวอย่าง: ออกนอกบ้าน)
@export var feature_unlocks: Dictionary = {
	"outdoor_walk_min_age_mo": 6.0
}

# แม็พ "พฤติกรรม" -> "ชื่อคลิปในโมเดล"
@export var anim_map: Dictionary = {
	"idle": "", "happy": "", "sad": "", "affection": "",
	"walk": "", "run": "", "sit": "", "sleep": "",
	"roll": "", "eat": "", "play": "",
	"dog_lick_face": "", "cat_swat": ""
}

# เสียงต่อเหตุการณ์ (ออปชัน)
@export var sfx_map: Dictionary = {
	"bark": null, "meow": null, "purr": null, "eat": null,
	"happy": null, "sad": null
}

# ปรับบุคลิก/พารามิเตอร์ราย "ช่วงวัย"
# คีย์ที่รองรับทั่วไป: speed_mult, gait_bob_mult, play_bias(0..1), scale (ถ้าอยากกำหนดสเกลช่วงวัยเฉพาะ)
@export var stage_params: Dictionary = {
	"juvenile": { "speed_mult": 0.90, "gait_bob_mult": 1.10, "play_bias": 0.90, "scale": 0.85 },
	"teen":     { "speed_mult": 1.10, "gait_bob_mult": 1.00, "play_bias": 0.70, "scale": 0.90 },
	"adult":    { "speed_mult": 1.00, "gait_bob_mult": 1.00, "play_bias": 0.50, "scale": 1.00 }
}

# ป้ายกำกับช่วยค้นหา/ฟิลเตอร์ (ออปชัน)
@export var tags: PackedStringArray = []
