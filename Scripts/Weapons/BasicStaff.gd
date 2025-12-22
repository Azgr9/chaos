# SCRIPT: BasicStaff.gd
# ATTACH TO: BasicStaff (Node2D) root node in BasicStaff.tscn
# LOCATION: res://Scripts/Weapons/BasicStaff.gd
# Standard arcane staff with pure energy projectiles

class_name BasicStaff
extends MagicWeapon

# Projectile colors
const ARCANE_CORE: Color = Color(0.4, 0.8, 1.0)  # Cyan core
const ARCANE_GLOW: Color = Color(0.6, 0.9, 1.0, 0.6)  # Light blue glow

func _weapon_ready():
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

	# Use weakref to safely capture self
	var staff_ref = weakref(self)

	timer.timeout.connect(func():
		if not is_instance_valid(projectile):
			timer.stop()
			timer.queue_free()
			return

		# Check if staff is still valid using weakref
		var staff = staff_ref.get_ref()
		if not staff:
			timer.stop()
			timer.queue_free()
			return

		var sparkle = ColorRect.new()
		sparkle.size = Vector2(8, 8)
		sparkle.color = ARCANE_GLOW
		sparkle.pivot_offset = Vector2(4, 4)
		staff.get_tree().current_scene.add_child(sparkle)
		sparkle.global_position = projectile.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))

		var tween = TweenHelper.new_tween()
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
