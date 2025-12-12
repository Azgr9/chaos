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

func _find_most_damaged_ally() -> Enemy:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var most_damaged: Enemy = null
	var lowest_health_percent: float = 1.0

	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if enemy.is_dead:
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
	var enemies = get_tree().get_nodes_in_group("enemies")
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
	var tween = create_tween()
	tween.tween_property(sprite, "color", HEALER_COLOR, 0.3)

	# Scale pulse
	visuals_pivot.scale = Vector2(1.2, 1.2)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Aura flash
	heal_aura.modulate.a = 0.6
	var aura_tween = create_tween()
	aura_tween.tween_property(heal_aura, "modulate:a", 0.2, 0.5)

	is_healing = false

func _create_heal_effect(target_pos: Vector2):
	# Create a healing particle that travels to target
	var heal_particle = ColorRect.new()
	heal_particle.size = Vector2(12, 12)
	heal_particle.color = HEAL_PULSE_COLOR
	get_tree().current_scene.add_child(heal_particle)
	heal_particle.global_position = global_position

	var tween = create_tween()
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

	var plus_tween = create_tween()
	plus_tween.tween_property(plus, "global_position:y", target_pos.y - 30, 0.5)
	plus_tween.parallel().tween_property(plus, "modulate:a", 0.0, 0.5)
	plus_tween.tween_callback(plus.queue_free)

func _on_damage_taken():
	# Flash white
	sprite.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", HEALER_COLOR, 0.15)

	# Squash
	visuals_pivot.scale = Vector2(1.3, 0.7)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	heal_timer.stop()
	set_physics_process(false)

	# Sad deflation
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.5, 0.3), 0.2)
	tween.tween_property(visuals_pivot, "scale", Vector2.ZERO, 0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return HEALER_COLOR

func _get_death_particle_count() -> int:
	return 6
