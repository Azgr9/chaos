# SCRIPT: WaveManager.gd
# ATTACH TO: A new Node in Game.tscn (we'll create it)
# LOCATION: res://scripts/game/WaveManager.gd

class_name WaveManager
extends Node

# Spawn configuration
@export var spawn_radius: float = 250.0
@export var spawn_distance_from_player: float = 150.0
@export var enemy_activation_time: float = 0.5  # Visual polish for spawned enemies

# Enemy definitions with unlock requirements
const ENEMY_TYPES = {
	"imp": {
		"scene": preload("res://Scenes/Enemies/Imp.tscn"),
		"cost": 1,
		"unlocks_at_wave": 1
	},
	"slime": {
		"scene": preload("res://Scenes/Enemies/Slime.tscn"),
		"cost": 2,
		"unlocks_at_wave": 1
	},
	"goblin": {
		"scene": preload("res://Scenes/Enemies/GoblinArcher.tscn"),
		"cost": 3,
		"unlocks_at_wave": 2
	}
}

# Wave state
var current_wave: int = 0
var wave_points_total: int = 0
var points_remaining_to_spawn: int = 0
var enemies_alive: int = 0
var wave_active: bool = false
var player_reference: Node2D = null
var arena_center: Vector2 = Vector2(320, 180)  # Center of our arena

# Batch spawning state
var batches_remaining: int = 0
var current_batch_points: int = 0
var batch_timer: Timer = null
var spawn_queue: Array = []  # Enemies queued for current batch
var spawn_index: int = 0
var spawn_interval_timer: Timer = null

# Signals
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

	# Create batch timer
	batch_timer = Timer.new()
	batch_timer.one_shot = true
	batch_timer.timeout.connect(_on_batch_timer_timeout)
	add_child(batch_timer)

	# Create spawn interval timer for staggered spawning within a batch
	spawn_interval_timer = Timer.new()
	spawn_interval_timer.one_shot = false
	spawn_interval_timer.timeout.connect(_spawn_next_in_batch)
	add_child(spawn_interval_timer)

	# Wait a moment before starting
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func start_next_wave():
	current_wave += 1

	# Calculate wave point pool: wave^2 * 2 + 2
	wave_points_total = current_wave * current_wave * 2 + 2
	points_remaining_to_spawn = wave_points_total
	enemies_alive = 0
	wave_active = true

	# Determine number of batches based on wave number
	if current_wave <= 3:
		batches_remaining = 2  # Early waves: 2 batches
	elif current_wave <= 6:
		batches_remaining = 3  # Mid waves: 3 batches
	else:
		batches_remaining = randi_range(4, 5)  # Late waves: 4-5 batches

	wave_started.emit(current_wave)

	# Show wave notification
	_show_wave_notification()

	# Start first batch immediately
	_spawn_batch()

func _spawn_batch():
	if batches_remaining <= 0 or points_remaining_to_spawn <= 0:
		return

	batches_remaining -= 1

	# Divide remaining points among remaining batches (including this one)
	var total_batches = batches_remaining + 1  # +1 for current batch
	current_batch_points = int(float(points_remaining_to_spawn) / float(total_batches))

	# Ensure at least 1 point for the batch
	if current_batch_points <= 0 and points_remaining_to_spawn > 0:
		current_batch_points = points_remaining_to_spawn

	# Generate enemy spawn queue for this batch
	spawn_queue = _generate_batch_enemies(current_batch_points)
	spawn_index = 0

	# Start spawning enemies with 0.5 second intervals
	if spawn_queue.size() > 0:
		spawn_interval_timer.start(enemy_activation_time)
		_spawn_next_in_batch()  # Spawn first one immediately

func _generate_batch_enemies(batch_points: int) -> Array:
	var enemies = []
	var points_left = batch_points

	# Build list of unlocked enemy types for current wave
	while points_left > 0:
		var available_types = []

		# Check each enemy type for unlock status and affordability
		for enemy_type in ENEMY_TYPES.keys():
			var enemy_data = ENEMY_TYPES[enemy_type]
			# Check if unlocked for current wave AND affordable
			if current_wave >= enemy_data["unlocks_at_wave"] and points_left >= enemy_data["cost"]:
				available_types.append(enemy_type)

		if available_types.size() == 0:
			break  # No affordable unlocked enemies

		# Randomly choose from available types (truly random)
		var chosen_type = available_types[randi() % available_types.size()]

		enemies.append(chosen_type)
		points_left -= ENEMY_TYPES[chosen_type]["cost"]

	# Deduct used points from wave total
	points_remaining_to_spawn -= (batch_points - points_left)

	return enemies

func _spawn_next_in_batch():
	if spawn_index >= spawn_queue.size():
		# Batch complete - stop interval timer
		spawn_interval_timer.stop()

		# Schedule next batch
		_schedule_next_batch()
		return

	var enemy_type = spawn_queue[spawn_index]
	spawn_index += 1

	# Spawn the enemy
	_spawn_enemy_of_type(enemy_type)

func _schedule_next_batch():
	if batches_remaining <= 0:
		# No more batches - wave will complete when all enemies die
		return

	# Determine interval until next batch
	var batch_interval: float

	if current_wave <= 3:
		batch_interval = randf_range(8.0, 10.0)  # Early waves: 8-10 seconds
	elif current_wave <= 6:
		batch_interval = randf_range(6.0, 8.0)   # Mid waves: 6-8 seconds
	else:
		batch_interval = randf_range(4.0, 6.0)   # Late waves: 4-6 seconds

	batch_timer.start(batch_interval)

func _on_batch_timer_timeout():
	# Check for early acceleration: if all spawned enemies are dead
	if enemies_alive <= 0 and points_remaining_to_spawn > 0:
		# Spawn next batch after short delay (1-2 seconds)
		await get_tree().create_timer(randf_range(1.0, 2.0)).timeout

	_spawn_batch()

func _spawn_enemy_of_type(enemy_type: String):
	# Get enemy data from ENEMY_TYPES dictionary
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
		enemy.enemy_died.connect(_on_enemy_died)

	# Set player reference if enemy has the method
	if enemy.has_method("set_player_reference") and player_reference:
		enemy.set_player_reference(player_reference)

	enemies_alive += 1
	enemy_spawned.emit(enemy)

func _get_spawn_position() -> Vector2:
	# Spawn in a circle around the arena, but not too close to player
	var angle = randf() * TAU  # Random angle in radians
	var spawn_pos = arena_center + Vector2.from_angle(angle) * spawn_radius

	# Make sure not too close to player
	if player_reference:
		var distance_to_player = spawn_pos.distance_to(player_reference.global_position)
		if distance_to_player < spawn_distance_from_player:
			# Push spawn position away from player
			var dir_from_player = (spawn_pos - player_reference.global_position).normalized()
			spawn_pos = player_reference.global_position + dir_from_player * spawn_distance_from_player

	# Clamp to arena bounds (with padding)
	spawn_pos.x = clamp(spawn_pos.x, 40, 600)
	spawn_pos.y = clamp(spawn_pos.y, 40, 320)

	return spawn_pos

func _on_enemy_died(_enemy: Enemy):
	enemies_alive -= 1
	enemy_killed.emit(enemies_alive)

	# Check if wave is complete: all points spawned AND all enemies dead
	if points_remaining_to_spawn <= 0 and enemies_alive <= 0 and batches_remaining <= 0:
		_complete_wave()
	# Early acceleration: if all spawned enemies dead and more batches to come
	elif enemies_alive <= 0 and batches_remaining > 0 and not batch_timer.is_stopped():
		# Cancel current timer and spawn next batch sooner
		batch_timer.stop()
		await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
		_spawn_batch()

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
	points_remaining_to_spawn = 0
	enemies_alive = 0
	wave_active = false
	batches_remaining = 0
	spawn_queue.clear()

	# Stop timers
	if batch_timer:
		batch_timer.stop()
	if spawn_interval_timer:
		spawn_interval_timer.stop()

	# Clean up any remaining enemies
	get_tree().call_group("enemies", "queue_free")
