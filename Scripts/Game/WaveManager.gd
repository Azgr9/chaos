# SCRIPT: WaveManager.gd
# ATTACH TO: A new Node in Game.tscn
# LOCATION: res://scripts/game/WaveManager.gd

class_name WaveManager
extends Node

# Spawn configuration
@export var spawn_edge_padding: float = 80.0  # Spawn this far from wall
@export var spawn_distance_from_player: float = 400.0
@export var enemy_activation_time: float = 0.5

# Arena reference (fetched from scene)
var arena: Arena = null
var arena_center: Vector2 = Vector2(1280, 720)  # Fallback
var arena_half_width: float = 1200.0  # Fallback
var arena_half_height: float = 680.0  # Fallback

# Enemy definitions with unlock requirements and weights
const ENEMY_TYPES = {
	"goblin_dual": {
		"scene": preload("res://Scenes/Enemies/GoblinDual.tscn"),
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
	"goblin_archer": {
		"scene": preload("res://Scenes/Enemies/GoblinArcher.tscn"),
		"cost": 3,
		"unlocks_at_wave": 2,
		"base_weight": 1.0,
		"max_alive": 6
	},
	"healer": {
		"scene": preload("res://Scenes/Enemies/Healer.tscn"),
		"cost": 4,
		"unlocks_at_wave": 4,
		"base_weight": 0.8,
		"max_alive": 2
	},
	"spawner": {
		"scene": preload("res://Scenes/Enemies/Spawner.tscn"),
		"cost": 6,
		"unlocks_at_wave": 5,
		"base_weight": 0.4,
		"max_alive": 2
	},
	"boss": {
		"scene": preload("res://Scenes/Enemies/Boss.tscn"),
		"cost": 50,
		"unlocks_at_wave": 5,
		"base_weight": 0.0,  # Never spawns randomly - use spawn_boss()
		"max_alive": 1
	}
}

# Hazard Manager reference
var hazard_manager: HazardManager = null

# Wave state
var current_wave: int = 0
var total_points: int = 0
var points_spawned: int = 0
var points_remaining: int = 0
var enemies_alive: int = 0
var enemies_alive_by_type: Dictionary = {}
var wave_active: bool = false
var player_reference: Node2D = null

# Spawn timing
var spawn_timer: float = 0.0

# Safeguards
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
	# Add to group for easy lookup
	add_to_group("wave_manager")

	# Find arena reference and get bounds
	_find_arena()

	# Find player reference
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

	# Initialize enemy counters
	for enemy_type in ENEMY_TYPES.keys():
		enemies_alive_by_type[enemy_type] = 0

	# Initialize breather checkpoints
	_reset_checkpoints()

	# Setup HazardManager
	_setup_hazard_manager()

	# Wait a moment before starting
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _find_arena():
	# Find arena in scene and get its bounds
	# First try by group
	var arenas = get_tree().get_nodes_in_group("arena")
	if arenas.size() > 0:
		arena = arenas[0] as Arena

	# Fallback: find by class name in parent
	if not arena:
		for child in get_parent().get_children():
			if child is Arena:
				arena = child
				break

	# Fallback: find Arena node by name
	if not arena:
		arena = get_parent().get_node_or_null("Arena") as Arena

	if arena:
		arena_center = arena.get_arena_center()
		arena_half_width = arena.arena_half_width
		arena_half_height = arena.arena_half_height
		print("[WaveManager] Found arena: center=%s, size=%sx%s" % [arena_center, arena_half_width * 2, arena_half_height * 2])
	else:
		push_warning("[WaveManager] Arena not found! Using fallback values.")

func _setup_hazard_manager():
	# Create and add HazardManager as child
	hazard_manager = HazardManager.new()
	hazard_manager.name = "HazardManager"
	add_child(hazard_manager)

	# Set player reference
	if player_reference:
		hazard_manager.set_player_reference(player_reference)

	# Configure rectangle arena bounds for hazards
	hazard_manager.arena_center = arena_center
	hazard_manager.arena_half_width = arena_half_width - 50  # Keep hazards away from walls
	hazard_manager.arena_half_height = arena_half_height - 50

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

	# Wave 5 is the BOSS WAVE
	if current_wave == 5:
		_start_boss_wave()
		return

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

	# Spawn hazards for this wave
	if hazard_manager:
		hazard_manager.spawn_hazards_for_wave(current_wave)

	# Set initial spawn timer (wait for hazard warnings to complete)
	var hazard_warning_time = hazard_manager.warning_duration if hazard_manager else 0.0
	spawn_timer = 1.0 + hazard_warning_time

	wave_started.emit(current_wave)
	_show_wave_notification()

func _start_boss_wave():
	# Boss wave - special handling
	total_points = 50  # Boss cost
	points_remaining = 0  # Don't spawn regular enemies
	points_spawned = 50
	enemies_alive = 0
	wave_active = true

	# Reset enemy type counters
	for enemy_type in ENEMY_TYPES.keys():
		enemies_alive_by_type[enemy_type] = 0

	wave_started.emit(current_wave)
	_show_boss_wave_notification()

	# Wait for dramatic effect then spawn boss
	await get_tree().create_timer(2.0).timeout
	_spawn_boss()

func _spawn_boss():
	var boss_data = ENEMY_TYPES["boss"]
	var boss_scene = boss_data["scene"]

	if not boss_scene:
		push_error("Boss scene not found!")
		return

	var boss = boss_scene.instantiate()
	get_parent().add_child(boss)
	boss.global_position = arena_center

	# Connect signals
	if boss.has_signal("enemy_died"):
		boss.enemy_died.connect(_on_boss_died)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

	# Set player reference
	if boss.has_method("set_player_reference") and player_reference:
		boss.set_player_reference(player_reference)

	enemies_alive = 1
	enemies_alive_by_type["boss"] = 1
	enemy_spawned.emit(boss)

func _on_boss_died(_enemy: Enemy):
	enemies_alive = 0
	enemies_alive_by_type["boss"] = 0
	_complete_wave()

func _on_boss_defeated():
	# Additional boss defeat logic (victory screen, etc.)
	pass

func _show_boss_wave_notification():
	var boss_notification = Label.new()
	boss_notification.text = "FINAL WAVE\nBOSS INCOMING!"
	boss_notification.add_theme_font_size_override("font_size", 48)
	boss_notification.modulate = Color(1, 0.3, 0.3, 1)
	boss_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	get_parent().add_child(boss_notification)
	boss_notification.global_position = Vector2(1280, 350) - boss_notification.size / 2

	var tween = create_tween()
	tween.tween_property(boss_notification, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(boss_notification, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(boss_notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(boss_notification.queue_free)

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

	return enemies[-1] if enemies.size() > 0 else "goblin_dual"

func _get_scaled_weight(enemy_type: String) -> float:
	var enemy_data = ENEMY_TYPES[enemy_type]
	var base = enemy_data["base_weight"]
	var cost = enemy_data["cost"]

	# Weight scaling by wave - cheap enemies become rarer, expensive become more common
	match cost:
		1:  # Very cheap (goblin_dual) - becomes rarer over time
			return max(0.5, base - (current_wave * 0.3))
		2:  # Cheap (slime) - stays stable
			return base
		3:  # Medium (goblin_archer) - becomes more common
			return base + (current_wave * 0.3)
		4:  # Medium-expensive (healer) - gradual increase
			return base + (current_wave * 0.2)
		6:  # Very expensive (spawner) - rare but increases
			return base + (current_wave * 0.1)

	return base

func _spawn_enemies_staggered(enemies: Array):
	var delay = 0.0

	for enemy_type in enemies:
		# Spawn with staggered delay
		await get_tree().create_timer(delay).timeout
		# CRITICAL: Check validity after await - prevents crash if wave ends/scene changes
		if not is_instance_valid(self) or not wave_active:
			return
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

	# Connect enemy signals IMMEDIATELY
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy_type))

	# Set player reference IMMEDIATELY
	if enemy.has_method("set_player_reference") and player_reference:
		enemy.set_player_reference(player_reference)

	# Check for elite spawn (chance increases with wave)
	_try_make_elite(enemy)

	# Update counters IMMEDIATELY (before activation delay)
	enemies_alive += 1
	enemies_alive_by_type[enemy_type] += 1
	points_spawned += enemy_data["cost"]
	points_remaining -= enemy_data["cost"]

	enemy_spawned.emit(enemy)

	# Freeze enemy for activation time (visual polish)
	enemy.set_physics_process(false)

	# Visual spawn effect
	_create_spawn_effect(spawn_pos)

	# Activate enemy after activation time
	await get_tree().create_timer(enemy_activation_time).timeout
	if is_instance_valid(enemy):
		enemy.set_physics_process(true)

# Elite spawn chance: 5% base + 3% per wave (Wave 1: 8%, Wave 5: 20%)
const ELITE_BASE_CHANCE: float = 0.05
const ELITE_WAVE_BONUS: float = 0.03

func _try_make_elite(enemy: Node2D):
	if not enemy.has_method("make_random_elite"):
		return

	var elite_chance = ELITE_BASE_CHANCE + (current_wave * ELITE_WAVE_BONUS)

	if randf() < elite_chance:
		enemy.make_random_elite()

func _get_spawn_position() -> Vector2:
	# Generate random position inside rectangle arena
	var padding = spawn_edge_padding + 50
	var x = randf_range(arena_center.x - arena_half_width + padding, arena_center.x + arena_half_width - padding)
	var y = randf_range(arena_center.y - arena_half_height + padding, arena_center.y + arena_half_height - padding)
	var spawn_pos = Vector2(x, y)

	# Make sure not too close to player
	if player_reference:
		var distance_to_player = spawn_pos.distance_to(player_reference.global_position)
		if distance_to_player < spawn_distance_from_player:
			# Find a position further from player but still in arena
			var dir_from_player = (spawn_pos - player_reference.global_position).normalized()
			spawn_pos = player_reference.global_position + dir_from_player * spawn_distance_from_player
			# Clamp to rectangle arena
			spawn_pos = _clamp_to_arena(spawn_pos)

	return spawn_pos

func _clamp_to_arena(pos: Vector2) -> Vector2:
	# Clamp position to stay inside rectangle arena
	var padding = spawn_edge_padding + 50
	var clamped = pos
	clamped.x = clamp(pos.x, arena_center.x - arena_half_width + padding, arena_center.x + arena_half_width - padding)
	clamped.y = clamp(pos.y, arena_center.y - arena_half_height + padding, arena_center.y + arena_half_height - padding)
	return clamped

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

	# Check if this was the final wave
	if current_wave >= 5:
		all_waves_completed.emit()
		return

	# Wait before starting next wave
	await get_tree().create_timer(3.0).timeout
	# Check validity after await - prevents crash if scene changed during wait
	if not is_instance_valid(self):
		return
	start_next_wave()

func _show_wave_notification():
	# Create a simple wave notification
	var wave_notification = Label.new()
	wave_notification.text = "WAVE %d" % current_wave
	wave_notification.add_theme_font_size_override("font_size", 32)
	wave_notification.modulate = Color.YELLOW

	# Center on screen
	get_parent().add_child(wave_notification)
	wave_notification.global_position = Vector2(1280, 400) - wave_notification.size / 2

	# Animate
	var tween = create_tween()
	tween.tween_property(wave_notification, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(wave_notification, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(wave_notification, "modulate:a", 0.0, 1.0)
	tween.tween_callback(wave_notification.queue_free)

func _create_spawn_effect(position: Vector2):
	# Create a simple spawn indicator
	var effect = ColorRect.new()
	effect.size = Vector2(64, 64)
	effect.position = position - Vector2(32, 32)
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

	# Clean up any remaining enemies
	get_tree().call_group("enemies", "queue_free")

	# Clear all hazards
	if hazard_manager:
		hazard_manager.clear_all_hazards()
