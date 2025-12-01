# SCRIPT: WaveManager.gd
# ATTACH TO: A new Node in Game.tscn
# LOCATION: res://scripts/game/WaveManager.gd

class_name WaveManager
extends Node

# Spawn configuration
@export var spawn_radius: float = 250.0
@export var spawn_distance_from_player: float = 150.0
@export var enemy_activation_time: float = 0.5

# Enemy definitions with unlock requirements and weights
const ENEMY_TYPES = {
	"imp": {
		"scene": preload("res://Scenes/Enemies/Imp.tscn"),
		"cost": 1,
		"unlocks_at_wave": 1,
		"base_weight": 3.0,
		"max_alive": 15
	},
	"slime": {
		"scene": preload("res://Scenes/Enemies/Slime.tscn"),
		"cost": 2,
		"unlocks_at_wave": 1,
		"base_weight": 2.0,
		"max_alive": 10
	},
	"goblin": {
		"scene": preload("res://Scenes/Enemies/GoblinArcher.tscn"),
		"cost": 3,
		"unlocks_at_wave": 2,
		"base_weight": 1.0,
		"max_alive": 6
	}
}

# Wave state
var current_wave: int = 0
var total_points: int = 0
var points_spawned: int = 0
var points_remaining: int = 0
var enemies_alive: int = 0
var enemies_alive_by_type: Dictionary = {}
var wave_active: bool = false
var player_reference: Node2D = null
var arena_center: Vector2 = Vector2(320, 180)

# Spawn timing
var spawn_timer: float = 0.0

# Safeguards
var recent_spawn_angles: Array[float] = []
const MAX_TRACKED_ANGLES = 5
const MIN_ANGLE_DIFFERENCE = deg_to_rad(45)  # 45 degrees apart minimum
var breather_checkpoints = [0.4, 0.75]
var checkpoints_triggered: Dictionary = {}

# Signals
signal breather_started(duration: float)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Enemy)
signal all_waves_completed()
signal enemy_killed(enemies_remaining: int)

func _ready():
	# Find player reference
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

	# Initialize enemy counters
	for enemy_type in ENEMY_TYPES.keys():
		enemies_alive_by_type[enemy_type] = 0

	# Initialize breather checkpoints
	_reset_checkpoints()

	# Wait a moment before starting
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _process(delta):
	if not wave_active or points_remaining <= 0:
		return

	spawn_timer -= delta
	if spawn_timer <= 0:
		# SAFEGUARD 2: Check for breather before spawning
		var breather = _check_for_breather()
		if breather > 0:
			spawn_timer = breather
			breather_started.emit(breather)
			return

		_spawn_batch()

func start_next_wave():
	current_wave += 1

	# Calculate wave point pool: (wave² × 2) + (wave × 2) + 2
	total_points = (current_wave * current_wave * 2) + (current_wave * 2) + 2
	points_remaining = total_points
	points_spawned = 0
	enemies_alive = 0
	wave_active = true

	# Reset enemy type counters
	for enemy_type in ENEMY_TYPES.keys():
		enemies_alive_by_type[enemy_type] = 0

	# Reset safeguards
	_reset_checkpoints()
	recent_spawn_angles.clear()

	# Set initial spawn timer
	spawn_timer = 1.0

	wave_started.emit(current_wave)
	_show_wave_notification()

func _spawn_batch():
	if points_remaining <= 0:
		return

	# Calculate batch size (15-35% of remaining points)
	var batch_points = _calculate_batch_points(points_remaining, current_wave)

	# Generate enemies for this batch
	var enemies_to_spawn = _select_enemies_for_batch(batch_points)

	# Spawn them with slight delays
	_spawn_enemies_staggered(enemies_to_spawn)

	# Calculate next spawn interval with pressure acceleration
	var progress = float(points_spawned) / float(total_points)
	spawn_timer = _get_spawn_interval(current_wave, progress)

func _calculate_batch_points(remaining_points: int, wave: int) -> int:
	var min_percent = 0.15 + (wave * 0.02)
	var max_percent = 0.35 + (wave * 0.03)
	var percent = randf_range(min_percent, max_percent)
	var batch = int(remaining_points * percent)

	# Minimum batch size
	var min_batch = 2 if wave <= 2 else 3
	return max(batch, min(remaining_points, min_batch))

func _get_spawn_interval(wave: int, progress: float) -> float:
	# Accelerating pressure - intervals get shorter as wave progresses
	var base_interval = max(1.5, 4.0 - (wave * 0.3))
	var pressure_multiplier = 1.0 - (sin(progress * PI * 0.5) * 0.6)
	var randomness = randf_range(0.8, 1.2)

	var interval = base_interval * pressure_multiplier * randomness

	# SAFEGUARD 1: Adaptive spawning - slow down if player is overwhelmed
	var max_comfortable = _get_max_comfortable_enemies(wave)
	var enemy_pressure = float(enemies_alive) / float(max_comfortable)

	if enemy_pressure > 1.5:
		# Severely overwhelmed - spawn 100% slower
		interval *= 2.0
	elif enemy_pressure > 1.0:
		# Player overwhelmed - spawn 50% slower
		interval *= 1.5

	return interval

func _get_max_comfortable_enemies(wave: int) -> int:
	return 8 + (wave * 2)  # Wave 1: 10, Wave 3: 14, Wave 5: 18

func _select_enemies_for_batch(points_budget: int) -> Array:
	var enemies_to_spawn = []
	var remaining_points = points_budget

	while remaining_points > 0:
		# Get available enemies (unlocked, affordable, under max_alive cap)
		var available = _get_available_enemies(remaining_points)

		if available.is_empty():
			break

		# Weighted random selection
		var chosen = _pick_weighted_random(available)
		enemies_to_spawn.append(chosen)
		remaining_points -= ENEMY_TYPES[chosen]["cost"]

	return enemies_to_spawn

func _get_available_enemies(max_cost: int) -> Array:
	var available = []

	for enemy_type in ENEMY_TYPES.keys():
		var enemy_data = ENEMY_TYPES[enemy_type]

		# Check unlock requirement
		if current_wave < enemy_data["unlocks_at_wave"]:
			continue

		# Check affordability
		if enemy_data["cost"] > max_cost:
			continue

		# Check max_alive cap
		if enemies_alive_by_type[enemy_type] >= enemy_data["max_alive"]:
			continue

		available.append(enemy_type)

	return available

func _pick_weighted_random(enemies: Array) -> String:
	# Calculate total weight with wave-based scaling
	var total_weight = 0.0
	for enemy_type in enemies:
		total_weight += _get_scaled_weight(enemy_type)

	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0

	for enemy_type in enemies:
		cumulative += _get_scaled_weight(enemy_type)
		if roll <= cumulative:
			return enemy_type

	return enemies[-1] if enemies.size() > 0 else "imp"

func _get_scaled_weight(enemy_type: String) -> float:
	var enemy_data = ENEMY_TYPES[enemy_type]
	var base = enemy_data["base_weight"]
	var cost = enemy_data["cost"]

	# Weight scaling by wave - cheap enemies become rarer, expensive become common
	match cost:
		1:  # Cheap (imp) - becomes rarer
			return max(0.5, base - (current_wave * 0.3))
		2:  # Medium (slime) - stays stable
			return base
		3:  # Expensive (goblin) - becomes more common
			return base + (current_wave * 0.4)

	return base

func _spawn_enemies_staggered(enemies: Array):
	var delay = 0.0

	for enemy_type in enemies:
		# Spawn with staggered delay
		await get_tree().create_timer(delay).timeout
		_spawn_enemy_of_type(enemy_type)
		delay += 0.3  # 0.3 second stagger between spawns in batch

func _spawn_enemy_of_type(enemy_type: String):
	if not enemy_type in ENEMY_TYPES:
		return

	var enemy_data = ENEMY_TYPES[enemy_type]
	var enemy_scene = enemy_data["scene"]

	if not enemy_scene:
		return

	# Get spawn position
	var spawn_pos = _get_spawn_position()

	# Spawn the enemy
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos

	# Freeze enemy for activation time (visual polish)
	enemy.set_physics_process(false)

	# Visual spawn effect
	_create_spawn_effect(spawn_pos)

	# Activate enemy after activation time
	await get_tree().create_timer(enemy_activation_time).timeout
	if is_instance_valid(enemy):
		enemy.set_physics_process(true)

	# Connect enemy signals
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy_type))

	# Set player reference
	if enemy.has_method("set_player_reference") and player_reference:
		enemy.set_player_reference(player_reference)

	# Update counters
	enemies_alive += 1
	enemies_alive_by_type[enemy_type] += 1
	points_spawned += enemy_data["cost"]
	points_remaining -= enemy_data["cost"]

	enemy_spawned.emit(enemy)

func _get_spawn_position() -> Vector2:
	# SAFEGUARD 3: Spatial distribution - get well-distributed angle
	var angle = _get_distributed_angle()

	# Track this angle
	recent_spawn_angles.append(angle)
	if recent_spawn_angles.size() > MAX_TRACKED_ANGLES:
		recent_spawn_angles.pop_front()

	# Calculate position from angle
	var spawn_pos = arena_center + Vector2.from_angle(angle) * spawn_radius

	# Make sure not too close to player
	if player_reference:
		var distance_to_player = spawn_pos.distance_to(player_reference.global_position)
		if distance_to_player < spawn_distance_from_player:
			var dir_from_player = (spawn_pos - player_reference.global_position).normalized()
			spawn_pos = player_reference.global_position + dir_from_player * spawn_distance_from_player

	# Clamp to arena bounds (with padding)
	spawn_pos.x = clamp(spawn_pos.x, 40, 600)
	spawn_pos.y = clamp(spawn_pos.y, 40, 320)

	return spawn_pos

func _get_distributed_angle() -> float:
	# Try up to 10 times to find a good angle
	for attempt in range(10):
		var test_angle = randf() * TAU

		if _is_angle_valid(test_angle):
			return test_angle

	# Fallback: return angle furthest from recent spawns
	return _get_furthest_angle()

func _is_angle_valid(test_angle: float) -> bool:
	for recent_angle in recent_spawn_angles:
		var diff = abs(_angle_difference(test_angle, recent_angle))
		if diff < MIN_ANGLE_DIFFERENCE:
			return false
	return true

func _angle_difference(a: float, b: float) -> float:
	var diff = fmod(b - a + PI, TAU) - PI
	return diff

func _get_furthest_angle() -> float:
	if recent_spawn_angles.is_empty():
		return randf() * TAU

	# Find angle with maximum distance from all recent angles
	var best_angle = 0.0
	var best_min_distance = 0.0

	# Test 8 angles around the circle
	for i in range(8):
		var test_angle = (float(i) / 8.0) * TAU
		var min_distance = TAU

		for recent in recent_spawn_angles:
			var dist = abs(_angle_difference(test_angle, recent))
			min_distance = min(min_distance, dist)

		if min_distance > best_min_distance:
			best_min_distance = min_distance
			best_angle = test_angle

	return best_angle

func _reset_checkpoints():
	checkpoints_triggered = {0.4: false, 0.75: false}

func _check_for_breather() -> float:
	var progress = _get_progress()

	for checkpoint in breather_checkpoints:
		if progress >= checkpoint and not checkpoints_triggered[checkpoint]:
			checkpoints_triggered[checkpoint] = true
			return _get_breather_duration(current_wave)

	return 0.0

func _get_breather_duration(wave: int) -> float:
	# Shorter breathers in later waves (still chaotic!)
	return max(1.5, 3.0 - (wave * 0.2))
	# Wave 1: 2.8s, Wave 3: 2.4s, Wave 5: 2.0s, Wave 10: 1.5s

func _get_progress() -> float:
	if total_points == 0:
		return 0.0
	return float(points_spawned) / float(total_points)

func _on_enemy_died(_enemy: Enemy, enemy_type: String):
	enemies_alive -= 1
	enemies_alive_by_type[enemy_type] = max(0, enemies_alive_by_type[enemy_type] - 1)
	enemy_killed.emit(enemies_alive)

	# Check if wave is complete: all points spawned AND all enemies dead
	if points_remaining <= 0 and enemies_alive <= 0:
		_complete_wave()

func _complete_wave():
	wave_active = false
	wave_completed.emit(current_wave)

	# Wait before starting next wave
	await get_tree().create_timer(3.0).timeout
	start_next_wave()

func _show_wave_notification():
	# Create a simple wave notification
	var wave_notification = Label.new()
	wave_notification.text = "WAVE %d" % current_wave
	wave_notification.add_theme_font_size_override("font_size", 32)
	wave_notification.modulate = Color.YELLOW

	# Center on screen
	get_parent().add_child(wave_notification)
	wave_notification.global_position = Vector2(320, 100) - wave_notification.size / 2

	# Animate
	var tween = create_tween()
	tween.tween_property(wave_notification, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(wave_notification, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(wave_notification, "modulate:a", 0.0, 1.0)
	tween.tween_callback(wave_notification.queue_free)

func _create_spawn_effect(position: Vector2):
	# Create a simple spawn indicator
	var effect = ColorRect.new()
	effect.size = Vector2(16, 16)
	effect.position = position - Vector2(8, 8)
	effect.color = Color.PURPLE
	effect.modulate.a = 0.5
	get_parent().add_child(effect)

	# Animate
	var tween = create_tween()
	tween.tween_property(effect, "scale", Vector2(2, 2), 0.3)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

func get_current_wave() -> int:
	return current_wave

func get_enemies_remaining() -> int:
	return enemies_alive

func reset_waves():
	current_wave = 0
	points_remaining = 0
	enemies_alive = 0
	wave_active = false

	# Reset enemy type counters
	for enemy_type in ENEMY_TYPES.keys():
		enemies_alive_by_type[enemy_type] = 0

	# Reset safeguards
	_reset_checkpoints()
	recent_spawn_angles.clear()

	# Clean up any remaining enemies
	get_tree().call_group("enemies", "queue_free")
