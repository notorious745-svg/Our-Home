# PetMemory.gd  — เก็บสภาพสัตว์เลี้ยงแบบ Global
extends Node

var mood: String = "idle"          # idle | happy | sad
var mood_intensity: float = 0.0    # ความแรง 0..1
var affection: float = 0.0         # ค่าความผูกพัน -1..+1

signal mood_changed(new_mood: String, intensity: float)

func set_mood(new_mood: String, intensity: float = 0.0) -> void:
	mood = new_mood
	mood_intensity = clamp(intensity, 0.0, 1.0)
	emit_signal("mood_changed", mood, mood_intensity)

func bump_affection(delta: float) -> void:
	affection = clamp(affection + delta, -1.0, 1.0)
