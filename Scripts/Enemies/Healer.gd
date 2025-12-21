# SCRIPT: Healer.gd
# ATTACH TO: Healer (CharacterBody2D) root node in Healer.tscn
# LOCATION: res://Scripts/Enemies/Healer.gd

class_name Healer
extends Enemy

# ============================================
# HEALER-SPECIFIC SETTINGS
# ============================================
@export var unlocks_at_wave: int = 4
@export var heal_radius: float = 200.0
@export var heal_amount: float = 5.0  # HP per heal tick
@export var heal_interval: float = 1.5  # Seconds between heals
@export var preferred_distance: float = 250.0  # Stays behind other enemies

# Colors
const HEALER_COLOR: Color = Color(0.2, 0.8, 0.4)  # Green
const HEAL_PULSE_COLOR: Color = Color(0.4, 1.0, 0.6)

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var heal_aura: ColorRect = $VisualsPivot/HealAura
@onready var heal_timer: Timer = $HealTimer

# ============================================
# STATE
# ============================================
var time_alive: float = 0.0
var is_healing: bool = false

# ============================================
# PERFORMANCE: Cached enemy list
# ============================================
var _cached_enemies: Array = []
var _cache_frame: int = -1

func _setup_enemy():

	# Stats loaded from scene file via 
	current_health = max_health

	# Connect timer
	heal_timer.wait_time = heal_interval
	heal_timer.timeout.connect(_on_heal_timer_timeout)
	heal_timer.start()

	# Color
	sprite.color = HEALER_COLOR

	# Setup heal aura visual
	heal_aura.modulate.a = 0.2

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta

	# Gentle floating animation
	var float_offset = sin(time_alive * 2.0) * 3.0
	visuals_pivot.position.y = float_offset

	# Heal aura pulsing
	var aura_pulse = 0.15 + sin(time_alive * 3.0) * 0.1
	heal_aura.modulate.a = aura_pulse

	# Rotate aura slowly
	heal_aura.rotation += delta * 0.5

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return

	# Priority 1: Find damaged allies that need healing
	var damaged_ally = _find_most_damaged_ally()

	if damaged_ally:
		# Move toward damaged ally
		var direction_to_ally = (damaged_ally.global_position - global_position).normalized()
		var distance_to_ally = global_position.distance_to(damaged_ally.global_position)

		# Face the ally
		visuals_pivot.scale.x = -1 if direction_to_ally.x < 0 else 1

		if distance_to_ally > heal_radius * 0.8:
			# Move toward ally to heal them
			velocity = direction_to_ally * move_speed
		else:
			# Close enough, stay near them
			velocity = direction_to_ally * move_speed * 0.2
		return

	# Priority 2: No damaged allies, stay away from player
	var direction_to_player = (player_reference.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player_reference.global_position)

	# Face player
	visuals_pivot.scale.x = -1 if direction_to_player.x < 0 else 1

	# Try to stay at preferred distance from player
	if distance_to_player < preferred_distance * 0.7:
		# Too close, retreat
		velocity = -direction_to_player * move_speed
	elif distance_to_player > preferred_distance * 1.3:
		# Too far, approach slowly
		velocity = direction_to_player * move_speed * 0.5
	else:
		# Good distance, strafe
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		var strafe = sin(time_alive * 1.5) * 0.6
		velocity = perpendicular * move_speed * strafe

func _get_cached_enemies() -> Array:
	var current_frame = Engine.get_process_frames()
	if _cache_frame != current_frame:
		_cached_enemies = get_tree().get_nodes_in_group("enemies")
		_cache_frame = current_frame
	return _cached_enemies

func _find_most_damaged_ally() -> Enemy:
	var enemies = _get_cached_enemies()
	var most_damaged: Enemy = null
	var lowest_health_percent: float = 1.0

	for enemy in enemies:
		# Skip self and invalid enemies
		if enemy == self or not is_instance_valid(enemy):
			continue
		# Check is_dead property exists and is true
		if not enemy is Enemy or enemy.is_dead:
			continue
		# Validate health properties exist
		if enemy.max_health <= 0:
			continue

		var health_percent = enemy.current_health / enemy.max_health

		# Only consider enemies that are actually damaged (below 90% health)
		if health_percent < 0.9 and health_percent < lowest_health_percent:
			lowest_health_percent = health_percent
			most_damaged = enemy

	return most_damaged

func _on_heal_timer_timeout():
	_heal_nearby_enemies()

func _heal_nearby_enemies():
	var enemies = _get_cached_enemies()
	var healed_any = false

	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue

		if enemy.is_dead:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance <= heal_radius:
			# Heal the enemy
			if enemy.current_health < enemy.max_health:
				enemy.current_health = min(enemy.current_health + heal_amount, enemy.max_health)
				enemy.health_changed.emit(enemy.current_health, enemy.max_health)
				_create_heal_effect(enemy.global_position)
				healed_any = true

	if healed_any:
		_play_heal_animation()

func _play_heal_animation():
	is_healing = true

	# Pulse effect
	sprite.color = HEAL_PULSE_COLOR
	var tween = TweenHelper.new_tween()
	tween.tween_property(sprite, "color", HEALER_COLOR, 0.3)

	# Scale pulse
	visuals_pivot.scale = Vector2(1.2, 1.2)
	var scale_tween = TweenHelper.new_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Aura flash
	heal_aura.modulate.a = 0.6
	var aura_tween = TweenHelper.new_tween()
	aura_tween.tween_property(heal_aura, "modulate:a", 0.2, 0.5)

	is_healing = false

func _create_heal_effect(target_pos: Vector2):
	# Create a healing particle that travels to target
	var heal_particle = ColorRect.new()
	heal_particle.size = Vector2(12, 12)
	heal_particle.color = HEAL_PULSE_COLOR
	get_tree().current_scene.add_child(heal_particle)
	heal_particle.global_position = global_position

	var tween = TweenHelper.new_tween()
	tween.tween_property(heal_particle, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(heal_particle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(heal_particle.queue_free)

	# Plus sign at target
	var plus = Label.new()
	plus.text = "+"
	plus.add_theme_color_override("font_color", HEAL_PULSE_COLOR)
	plus.add_theme_font_size_override("font_size", 20)
	get_tree().current_scene.add_child(plus)
	plus.global_position = target_pos - Vector2(8, 8)

	var plus_tween = TweenHelper.new_tween()
	plus_tween.tween_property(plus, "global_position:y", target_pos.y - 30, 0.5)
	plus_tween.parallel().tween_property(plus, "modulate:a", 0.0, 0.5)
	plus_tween.tween_callback(plus.queue_free)

func _on_damage_taken():
	# Call base class flash (handles the bright white modulate flash)
	super._on_damage_taken()

func _play_hit_squash():
	# Quick squash effect preserving facing direction - SNAPPY timing
	var facing = sign(visuals_pivot.scale.x) if visuals_pivot.scale.x != 0 else 1.0
	visuals_pivot.scale = Vector2(HIT_SQUASH_SCALE.x * facing, HIT_SQUASH_SCALE.y)
	var scale_tween = TweenHelper.new_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2(facing, 1.0), HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_death():
	heal_timer.stop()
	set_physics_process(false)

	# Quick deflation - SNAPPY death
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.4, 0.4), DEATH_FADE_DURATION * 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals_pivot, "scale", Vector2.ZERO, DEATH_FADE_DURATION * 0.5)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, DEATH_FADE_DURATION)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return HEALER_COLOR

func _get_death_particle_count() -> int:
	return 6
