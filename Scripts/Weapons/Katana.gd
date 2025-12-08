# SCRIPT: Katana.gd
# ATTACH TO: Katana (Node2D) root node in Katana.tscn
# LOCATION: res://Scripts/Weapons/Katana.gd

class_name Katana
extends MeleeWeapon

# ============================================
# KATANA-SPECIFIC STATE
# ============================================
var is_dash_slashing: bool = false

# Dash slash settings
const DASH_DISTANCE: float = 600.0
const DASH_TIME: float = 0.15
const DASH_HIT_RADIUS: float = 120.0
const DASH_DAMAGE_MULTIPLIER: float = 1.5

func _weapon_ready():
	# Katana-specific configuration
	damage = 12.0
	attack_duration = 0.2
	attack_cooldown = 0.3
	weapon_color = Color(0.9, 0.2, 0.2)  # Red katana
	idle_rotation = 45.0
	idle_scale = Vector2(0.6, 0.6)

	# Combo settings
	combo_window = 2.0
	combo_finisher_multiplier = 1.5
	combo_hits = 3

	# Skill settings
	skill_cooldown = 6.0

func _get_attack_pattern(attack_index: int) -> String:
	# Katana: quick slash -> reverse slash -> overhead slash
	match attack_index:
		1: return "horizontal"
		2: return "horizontal_reverse"
		3: return "overhead"
		_: return "horizontal"

func _get_hit_color(combo_finisher: bool, dash_attack: bool, crit: bool) -> Color:
	if crit:
		return Color.RED
	elif combo_finisher:
		return Color.GOLD
	elif dash_attack or is_dash_slashing:
		return Color(1.0, 0.3, 0.3)  # Red-ish for katana dash
	return weapon_color

# ============================================
# KATANA DASH SLASH SKILL
# ============================================
func _perform_skill() -> bool:
	if not player_reference:
		return false

	is_dash_slashing = true
	_execute_dash_slash()
	return true

func _execute_dash_slash():
	var player = player_reference

	# Calculate dash direction toward mouse
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var desired_position = player.global_position + direction * DASH_DISTANCE

	# Wall-safe raycast
	var target_position = _calculate_safe_dash_position(player, desired_position, direction)

	# Make player invulnerable during dash
	if player.has_method("set_invulnerable"):
		player.set_invulnerable(true)

	# Perform dash movement
	var tween = create_tween()
	tween.tween_property(player, "global_position", target_position, DASH_TIME)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(false)
		is_dash_slashing = false
	)

	# Visual effects
	_create_slash_effect(player.global_position)
	_create_dash_trail()

	# Damage enemies during dash
	_dash_damage_loop(player, direction)

func _calculate_safe_dash_position(player: Node2D, desired: Vector2, direction: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(player.global_position, desired)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Exclude player and enemies from ray
	var exclude: Array = [player]
	exclude.append_array(get_tree().get_nodes_in_group("enemies"))
	query.exclude = exclude

	var result = space_state.intersect_ray(query)

	if result and result.has("position"):
		return result.position - direction * 16.0
	return desired

func _dash_damage_loop(player: Node2D, _direction: Vector2):
	var checks = 5
	var hit_enemies: Array = []

	for i in range(checks):
		await get_tree().create_timer(DASH_TIME / checks).timeout

		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy in hit_enemies:
				continue
			if enemy.global_position.distance_to(player.global_position) < DASH_HIT_RADIUS:
				hit_enemies.append(enemy)
				var final_damage = damage * damage_multiplier * DASH_DAMAGE_MULTIPLIER

				if enemy.has_method("take_damage"):
					enemy.take_damage(final_damage)
					dealt_damage.emit(enemy, final_damage)
					_create_slash_effect(enemy.global_position)

func _create_dash_trail():
	if not player_reference:
		return

	for i in range(5):
		await get_tree().create_timer(0.03).timeout

		var ghost = ColorRect.new()
		ghost.size = Vector2(40, 40)
		ghost.color = Color(0.9, 0.2, 0.2, 0.5)
		get_tree().current_scene.add_child(ghost)
		ghost.global_position = player_reference.global_position

		var tween = create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tween.tween_callback(ghost.queue_free)

# ============================================
# VISUAL EFFECTS
# ============================================
func _create_slash_effect(hit_position: Vector2):
	for i in range(3):
		var particle = ColorRect.new()
		particle.size = Vector2(24, 8)
		particle.color = Color(1.0, 0.3, 0.3, 1.0)
		get_tree().current_scene.add_child(particle)
		particle.global_position = hit_position

		var angle = randf_range(-PI, PI)
		var direction = Vector2.from_angle(angle)
		var distance = randf_range(40, 80)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", hit_position + direction * distance, 0.2)
		tween.tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)

# Override attack to block during dash slash
func attack(direction: Vector2, player_damage_multiplier: float = 1.0) -> bool:
	if is_dash_slashing:
		return false
	return super.attack(direction, player_damage_multiplier)
