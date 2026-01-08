# SCRIPT: BasicStaff.gd
# ATTACH TO: BasicStaff (Node2D) root node in BasicStaff.tscn
# LOCATION: res://Scripts/Weapons/BasicStaff.gd
# Standard arcane staff with pure energy projectiles

class_name BasicStaff
extends MagicWeapon

# Projectile colors
const ARCANE_CORE: Color = Color(0.4, 0.8, 1.0)  # Cyan core
const ARCANE_GLOW: Color = Color(0.6, 0.9, 1.0, 0.6)  # Light blue glow

# Spell scenes
const PROJECTILE_SCENE = preload("res://Scenes/Weapons/BasicStaff/spells/ArcaneProjectile.tscn")
const SKILL_SCENE = preload("res://Scenes/Weapons/BasicStaff/spells/ArcaneBeamSkill.tscn")

func _weapon_ready():
	# Set projectile scene
	projectile_scene = PROJECTILE_SCENE

	# BasicStaff - balanced arcane staff
	attack_cooldown = 0.28  # Slightly faster than default
	projectile_spread = 5.0
	multi_shot = 1
	damage = 10.0
	staff_color = Color("#5a4a3a")  # Dark wood with arcane glow

	# Attack Speed Limits (balanced staff)
	max_attacks_per_second = 3.5  # Balanced speed
	min_cooldown = 0.18  # Cannot cast faster than this

	# Beam skill settings
	skill_cooldown = 10.0
	beam_damage = 50.0
	beam_range = 800.0
	beam_width = 32.0

func _perform_skill() -> bool:
	if not player_reference:
		return false

	var skill_origin = get_skill_spawn_position()
	var mouse_pos = player_reference.get_global_mouse_position()
	var direction = (mouse_pos - skill_origin).normalized()

	# Spawn skill scene at skill spawn point
	var skill = SKILL_SCENE.instantiate()
	get_tree().current_scene.add_child(skill)
	skill.global_position = skill_origin
	skill.initialize(player_reference, direction, player_reference.stats.magic_damage_multiplier, damage_type)

	return true

func _get_projectile_color() -> Color:
	return ARCANE_CORE

func _customize_projectile(projectile: Node2D):
	# Arcane energy bolt - cyan with sparkle trail
	if projectile.has_node("Sprite"):
		projectile.get_node("Sprite").color = ARCANE_CORE
		projectile.get_node("Sprite").size = Vector2(16, 16)

	# Add sparkle trail
	_add_arcane_trail(projectile)

func _add_arcane_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.04
	timer.one_shot = false
	projectile.add_child(timer)

	# Use weakref to safely capture references
	var staff_ref = weakref(self)
	var projectile_ref = weakref(projectile)
	var timer_ref = weakref(timer)

	timer.timeout.connect(func():
		var t = timer_ref.get_ref()
		var p = projectile_ref.get_ref()
		var staff = staff_ref.get_ref()

		if not t or not p or not is_instance_valid(p):
			if t and is_instance_valid(t):
				t.stop()
			return

		if not staff or not is_instance_valid(staff):
			if t and is_instance_valid(t):
				t.stop()
			return

		var tree = staff.get_tree()
		if not tree or not tree.current_scene:
			return

		var sparkle = ColorRect.new()
		sparkle.size = Vector2(8, 8)
		sparkle.color = ARCANE_GLOW
		sparkle.pivot_offset = Vector2(4, 4)
		sparkle.z_index = 100
		tree.current_scene.add_child(sparkle)
		sparkle.global_position = p.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(sparkle, "scale", Vector2(0.2, 0.2), 0.2)
			tween.tween_property(sparkle, "modulate:a", 0.0, 0.2)
			tween.tween_callback(sparkle.queue_free)
	)
	timer.start()

func _get_beam_color() -> Color:
	return Color(1.0, 1.0, 0.8, 1.0)  # Bright yellow-white

func _get_beam_glow_color() -> Color:
	return ARCANE_GLOW

# Trail colors - Arcane blue with sparkles
func _get_trail_color() -> Color:
	return Color(0.4, 0.8, 1.0, 0.9)  # Cyan-blue

func _get_trail_glow_color() -> Color:
	return Color(0.8, 0.95, 1.0, 1.0)  # Light blue-white

func _get_trail_glow_intensity() -> float:
	return 1.8

func _get_trail_pulse_speed() -> float:
	return 4.0

func _get_trail_sparkle_amount() -> float:
	return 0.4  # More sparkles for arcane magic
