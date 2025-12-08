# SCRIPT: BasicStaff.gd
# ATTACH TO: BasicStaff (Node2D) root node in BasicStaff.tscn
# LOCATION: res://Scripts/Weapons/BasicStaff.gd

class_name BasicStaff
extends MagicWeapon

func _weapon_ready():
	# BasicStaff uses default settings from MagicWeapon
	attack_cooldown = 0.3
	projectile_spread = 5.0
	multi_shot = 1
	staff_color = Color("#8b4513")  # Brown

	# Beam skill settings
	skill_cooldown = 10.0
	beam_damage = 50.0
	beam_range = 800.0
	beam_width = 32.0

func _get_beam_color() -> Color:
	return Color(1.0, 1.0, 0.8, 1.0)  # Bright yellow-white

func _get_beam_glow_color() -> Color:
	return Color(0.4, 0.8, 1.0, 0.6)  # Cyan glow
