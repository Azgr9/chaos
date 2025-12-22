# SCRIPT: BasicSword.gd
# ATTACH TO: BasicSword (Node2D) root node in BasicSword.tscn
# LOCATION: res://Scripts/Weapons/BasicSword.gd

class_name BasicSword
extends MeleeWeapon

# ============================================
# SWORD-SPECIFIC SETTINGS
# ============================================
const SPIN_SLASH_SCENE = preload("res://Scenes/Weapons/SpinSlash.tscn")

# Visual colors
const SWORD_BLADE_COLOR: Color = Color(0.85, 0.85, 0.9)  # Polished silver
const SWORD_EDGE_COLOR: Color = Color(1.0, 1.0, 1.0)  # Bright edge
const SWORD_TRAIL_COLOR: Color = Color(0.7, 0.8, 1.0, 0.6)  # Blue-white trail

func _weapon_ready():
	# BasicSword - balanced all-rounder
	damage = 10.0
	attack_duration = 0.22  # Slightly faster for responsiveness
	attack_cooldown = 0.32  # Quick recovery
	swing_arc = 150.0
	weapon_length = 80.0
	weapon_color = SWORD_BLADE_COLOR
	skill_cooldown = 8.0

	# Attack Speed Limits (balanced)
	max_attacks_per_second = 3.0  # ~3 attacks per second base
	min_cooldown = 0.18  # Cannot go below 180ms between attacks

	# Balanced knockback
	base_knockback = 350.0
	finisher_knockback = 600.0

func _get_attack_pattern(attack_index: int) -> String:
	# BasicSword: horizontal -> horizontal_reverse -> overhead
	match attack_index:
		1: return "horizontal"
		2: return "horizontal_reverse"
		3: return "overhead"
		_: return "horizontal"

func _perform_skill() -> bool:
	# Spin Slash skill
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var spin_slash = SPIN_SLASH_SCENE.instantiate()
	get_tree().current_scene.add_child(spin_slash)

	var slash_damage = damage * 2.0 * damage_multiplier
	spin_slash.initialize(player.global_position, slash_damage, player)

	if spin_slash.has_signal("dealt_damage"):
		var sword_ref = weakref(self)
		spin_slash.dealt_damage.connect(func(target, dmg):
			var sword = sword_ref.get_ref()
			if sword:
				sword.dealt_damage.emit(target, dmg)
		)

	return true

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack:
		return Color.CYAN
	return SWORD_BLADE_COLOR

# Visual swing trail for BasicSword
func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Call parent animation
	super._perform_attack_animation(pattern, duration, is_dash_attack)

	# Add swing trail effect
	_create_sword_swing_trail()

func _create_sword_swing_trail():
	if not player_reference:
		return

	# Create multiple trail segments
	for i in range(4):
		var trail = ColorRect.new()
		trail.size = Vector2(8, weapon_length * 0.7)
		trail.color = SWORD_TRAIL_COLOR
		trail.pivot_offset = Vector2(4, weapon_length * 0.35)
		get_tree().current_scene.add_child(trail)
		trail.global_position = global_position
		trail.rotation = pivot.rotation + randf_range(-0.2, 0.2)

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(trail, "modulate:a", 0.0, 0.15)
		tween.tween_property(trail, "scale", Vector2(0.3, 1.0), 0.15)
		tween.tween_callback(trail.queue_free)

func _on_combo_finisher_hit(_target: Node2D):
	# Create flash effect on finisher
	DamageNumberManager.shake(0.3)
	_create_finisher_flash()

func _create_finisher_flash():
	if not player_reference:
		return

	var flash = ColorRect.new()
	flash.size = Vector2(60, 60)
	flash.color = Color(1.0, 1.0, 0.8, 0.8)
	flash.pivot_offset = Vector2(30, 30)
	get_tree().current_scene.add_child(flash)
	flash.global_position = player_reference.global_position + current_attack_direction * 50

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_callback(flash.queue_free)
