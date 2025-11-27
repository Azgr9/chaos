# SCRIPT: WaveManager.gd
# ATTACH TO: A new Node in Game.tscn (we'll create it)
# LOCATION: res://scripts/game/WaveManager.gd

class_name WaveManager
extends Node

# Wave configuration
@export var enemy_scenes: Array[PackedScene] = []  # Add enemy scenes in editor
@export var spawn_radius: float = 250.0
@export var spawn_distance_from_player: float = 150.0
@export var time_between_spawns: float = 0.5
@export var time_between_waves: float = 3.0

# Wave definitions - enemies to spawn per type
var wave_configs = [
	{"wave": 1, "slime": 3, "goblin": 0, "imp": 2},
	{"wave": 2, "slime": 4, "goblin": 1, "imp": 3},
	{"wave": 3, "slime": 5, "goblin": 2, "imp": 4},
	{"wave": 4, "slime": 6, "goblin": 4, "imp": 6},
	{"wave": 5, "slime": 8, "goblin": 7, "imp": 10}
]

# Enemy scenes
const SLIME_SCENE = preload("res://Scenes/Enemies/Slime.tscn")
const GOBLIN_SCENE = preload("res://Scenes/Enemies/GoblinArcher.tscn")
const IMP_SCENE = preload("res://Scenes/Enemies/Imp.tscn")

# State
var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var wave_active: bool = false
var spawn_timer: float = 0.0
var player_reference: Node2D = null
var arena_center: Vector2 = Vector2(320, 180)  # Center of our arena

# Track remaining enemies per type for current wave
var slimes_remaining: int = 0
var goblins_remaining: int = 0
var imps_remaining: int = 0

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
	
	# Wait a moment before starting
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _process(delta):
	if wave_active and enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			spawn_timer = time_between_spawns

func start_next_wave():
	if current_wave >= wave_configs.size():
		all_waves_completed.emit()
		return

	current_wave += 1
	var config = wave_configs[current_wave - 1]

	# Set enemy counts from config
	slimes_remaining = config.get("slime", 0)
	goblins_remaining = config.get("goblin", 0)
	imps_remaining = config.get("imp", 0)
	enemies_to_spawn = slimes_remaining + goblins_remaining + imps_remaining
	enemies_spawned = 0
	enemies_alive = 0
	wave_active = true
	spawn_timer = 0.0

	wave_started.emit(current_wave)

	# Show wave notification
	_show_wave_notification()

func spawn_enemy():
	if enemies_to_spawn <= 0:
		return

	# Get spawn position
	var spawn_pos = _get_spawn_position()

	# Choose enemy type based on what's left to spawn
	var enemy_scene: PackedScene = null

	# Build list of available enemy types
	var available_types = []
	if slimes_remaining > 0:
		available_types.append("slime")
	if goblins_remaining > 0:
		available_types.append("goblin")
	if imps_remaining > 0:
		available_types.append("imp")

	# Randomly choose from available types
	if available_types.size() > 0:
		var chosen_type = available_types[randi() % available_types.size()]
		match chosen_type:
			"slime":
				enemy_scene = SLIME_SCENE
				slimes_remaining -= 1
			"goblin":
				enemy_scene = GOBLIN_SCENE
				goblins_remaining -= 1
			"imp":
				enemy_scene = IMP_SCENE
				imps_remaining -= 1
	else:
		# Shouldn't happen, but default to slime
		enemy_scene = SLIME_SCENE

	# Spawn the enemy
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = spawn_pos

	# Connect enemy signals
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

	# Set player reference if enemy has the method
	if enemy.has_method("set_player_reference") and player_reference:
		enemy.set_player_reference(player_reference)

	enemies_to_spawn -= 1
	enemies_spawned += 1
	enemies_alive += 1

	enemy_spawned.emit(enemy)

	# Visual spawn effect
	_create_spawn_effect(spawn_pos)

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

	# Check if wave is complete
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		_complete_wave()

func _complete_wave():
	wave_active = false
	wave_completed.emit(current_wave)
	
	# Wait before starting next wave
	await get_tree().create_timer(time_between_waves).timeout
	start_next_wave()

func _show_wave_notification():
	# Create a simple wave notification (we'll make this prettier later)
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
	return enemies_alive + enemies_to_spawn

func reset_waves():
	current_wave = 0
	enemies_to_spawn = 0
	enemies_alive = 0
	wave_active = false
	
	# Clean up any remaining enemies
	get_tree().call_group("enemies", "queue_free")
