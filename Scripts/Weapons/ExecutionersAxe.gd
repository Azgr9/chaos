# SCRIPT: ExecutionersAxe.gd
# ATTACH TO: ExecutionersAxe (Node2D) root node in ExecutionersAxe.tscn
# LOCATION: res://Scripts/Weapons/ExecutionersAxe.gd
# Heavy, slow, high damage axe with Guillotine Drop skill

class_name ExecutionersAxe
extends MeleeWeapon

# ============================================
# AXE-SPECIFIC SETTINGS
# ============================================
const GUILLOTINE_DROP_SCENE = preload("res://Scenes/Weapons/GuillotineDrop.tscn")

func _weapon_ready():
	# Heavy axe stats - 2.5x BasicSword damage, but slower
	damage = 25.0
	attack_duration = 0.45  # Slow swing
	attack_cooldown = 0.6   # Long recovery
	swing_arc = 120.0       # Narrower arc
	weapon_length = 90.0    # Slightly longer reach
	weapon_color = Color("#4a4a4a")  # Dark steel
	skill_cooldown = 12.0

	# Heavier knockback
	base_knockback = 500.0
	finisher_knockback = 1000.0

	# Slower combo
	combo_finisher_multiplier = 1.8  # Higher finisher bonus for heavy weapon

func _get_attack_pattern(attack_index: int) -> String:
	# Executioner's Axe: overhead -> overhead -> slam (all vertical chops)
	match attack_index:
		1: return "overhead"
		2: return "overhead"
		3: return "slam"
		_: return "overhead"

func _perform_attack_animation(pattern: String, duration: float, is_dash_attack: bool):
	# Kill existing tween
	if active_attack_tween:
		active_attack_tween.kill()

	var is_finisher = is_combo_finisher()

	# Set attack color
	if is_finisher:
		sprite.color = Color.GOLD
	elif is_dash_attack:
		sprite.color = Color.CYAN

	match pattern:
		"overhead":
			_animate_overhead_chop(duration, is_dash_attack)
		"slam":
			_animate_slam(duration, is_dash_attack)
		_:
			_animate_overhead_chop(duration, is_dash_attack)

func _animate_overhead_chop(duration: float, _is_dash_attack: bool):
	active_attack_tween = create_tween()

	# Get the base angle from attack direction
	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# Vertical chop: raise high, slam down
	var raise_angle = base_angle - 90  # Raised above head
	var chop_angle = base_angle + 30   # Follow through down

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2.ONE

	# Wind up - raise axe
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 20), duration * 0.25)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(is_combo_finisher(), false))

	# Chop down - powerful swing
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(chop_angle), duration * 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Follow through
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(chop_angle + 10), duration * 0.25)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _animate_slam(duration: float, _is_dash_attack: bool):
	# Finisher slam - bigger, more dramatic
	active_attack_tween = create_tween()

	var base_angle = rad_to_deg(current_attack_direction.angle()) + 90.0

	# High raise for slam
	var raise_angle = base_angle - 120
	var slam_angle = base_angle + 45

	pivot.rotation = deg_to_rad(raise_angle)
	pivot.position = Vector2.ZERO
	sprite.scale = Vector2(1.2, 1.2)  # Scale up for finisher

	# Long wind up
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(raise_angle - 30), duration * 0.3)

	# Enable hitbox
	active_attack_tween.tween_callback(_enable_hitbox.bind(true, false))

	# Massive slam
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle), duration * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Ground impact - brief pause
	active_attack_tween.tween_interval(duration * 0.1)

	# Create ground crack effect on slam
	active_attack_tween.tween_callback(_create_slam_impact)

	# Recovery
	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(slam_angle + 5), duration * 0.15)

	active_attack_tween.tween_callback(_disable_hitbox)
	_tween_to_idle(active_attack_tween)

func _create_slam_impact():
	# Ground crack visual
	if not player_reference:
		return

	var impact_pos = player_reference.global_position + current_attack_direction * 60

	# Shockwave ring
	var ring = ColorRect.new()
	ring.size = Vector2(30, 30)
	ring.color = Color(0.6, 0.4, 0.2, 0.8)
	ring.pivot_offset = Vector2(15, 15)
	get_tree().current_scene.add_child(ring)
	ring.global_position = impact_pos - Vector2(15, 15)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(4, 4), 0.3)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

	# Screen shake
	DamageNumberManager.shake(0.3)

func _perform_skill() -> bool:
	# Guillotine Drop skill - leap forward, deal 3x damage in small AoE
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false

	var guillotine = GUILLOTINE_DROP_SCENE.instantiate()
	get_tree().current_scene.add_child(guillotine)

	var skill_damage = damage * 3.0 * damage_multiplier
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	guillotine.initialize(player, direction, skill_damage)

	if guillotine.has_signal("dealt_damage"):
		guillotine.dealt_damage.connect(func(target, dmg):
			dealt_damage.emit(target, dmg)
		)

	return true

func _on_combo_finisher_hit(_target: Node2D):
	# Extra screen shake on finisher hit
	DamageNumberManager.shake(0.4)
