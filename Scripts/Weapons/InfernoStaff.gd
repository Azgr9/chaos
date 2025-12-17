# SCRIPT: InfernoStaff.gd
# ATTACH TO: InfernoStaff (Node2D) root node in InfernoStaff.tscn
# LOCATION: res://Scripts/Weapons/InfernoStaff.gd
# AoE/DoT staff that creates burning zones - affects enemies AND player (risk/reward)

class_name InfernoStaff
extends MagicWeapon

# ============================================
# INFERNO STAFF SPECIFIC
# ============================================
const FIRE_ZONE_SCENE = preload("res://Scenes/Spells/FireZone.tscn")

# Fire zone settings
var fire_zone_radius: float = 64.0
var fire_zone_damage: float = 8.0  # Damage per second
var fire_zone_duration: float = 5.0
var fire_zone_mana_cost: float = 35.0  # For future mana system

func _weapon_ready():
	# Inferno Staff settings
	attack_cooldown = 0.35
	projectile_spread = 8.0
	multi_shot = 1
	damage = 12.0  # Slightly higher base damage

	staff_color = Color("#8b0000")  # Dark red crystal staff
	muzzle_flash_color = Color(1.0, 0.5, 0.1)  # Orange flash

	# Skill settings - creates fire zone
	skill_cooldown = 4.0
	beam_damage = 0.0  # Not using beam, using fire zone instead

func _weapon_process(_delta):
	# Optional: Add subtle fire particle effect on staff
	pass

func _perform_skill() -> bool:
	# Hellfire skill - create fire zone at target location
	if not player_reference:
		return false

	var target_pos = player_reference.get_global_mouse_position()

	# Create fire zone
	var fire_zone = FIRE_ZONE_SCENE.instantiate()
	get_tree().current_scene.add_child(fire_zone)

	fire_zone.initialize(
		target_pos,
		fire_zone_damage * player_reference.stats.magic_damage_multiplier,
		fire_zone_duration,
		fire_zone_radius,
		player_reference
	)

	# Visual feedback on staff
	_play_skill_animation()

	return true

func _play_skill_animation():
	# Staff glow red during skill
	var original_color = sprite.color
	sprite.color = Color(1.0, 0.3, 0.1)

	# Recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -20, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(1.0, 0.5, 0.1, 1.0)
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	sprite.color = original_color

func _get_projectile_color() -> Color:
	return Color(1.0, 0.4, 0.1)  # Orange-red fireballs

func _get_beam_color() -> Color:
	return Color(1.0, 0.5, 0.1, 1.0)  # Bright orange

func _get_beam_glow_color() -> Color:
	return Color(1.0, 0.2, 0.0, 0.6)  # Red glow
