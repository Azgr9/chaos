# SCRIPT: HazardManager.gd
# ATTACH TO: HazardManager (Node) - Child of Game scene or WaveManager
# LOCATION: res://Scripts/hazards/HazardManager.gd

class_name HazardManager
extends Node

# ============================================
# HAZARD SCENE REFERENCES
# ============================================
var hazard_scenes: Dictionary = {}

# ============================================
# SPAWN CONFIGURATION (Rectangle Arena)
# ============================================
@export_group("Spawn Settings")
@export var arena_center: Vector2 = Vector2(1280, 720)
@export var arena_half_width: float = 1150.0  # Playable half-width (slightly inside wall)
@export var arena_half_height: float = 630.0  # Playable half-height
@export var min_distance_from_player: float = 100.0
@export var min_distance_between_hazards: float = 80.0
@export var warning_duration: float = 1.5

# ============================================
# WAVE SCALING
# ============================================
var hazards_per_wave: Dictionary = {
	1: {"count": 2, "types": ["fire_grate"]},
	2: {"count": 3, "types": ["fire_grate", "floor_spikes"]},
	3: {"count": 4, "types": ["fire_grate", "floor_spikes", "spike_wall"]},
	4: {"count": 5, "types": ["fire_grate", "floor_spikes", "spike_wall", "crusher"]},
	5: {"count": 6, "types": ["fire_grate", "floor_spikes", "spike_wall", "crusher"]}
}

# Default config for waves beyond 5
var default_wave_config: Dictionary = {
	"count": 6,
	"types": ["fire_grate", "floor_spikes", "spike_wall", "crusher"]
}

# ============================================
# STATE
# ============================================
var active_hazards: Array[Hazard] = []
var player_reference: Node2D = null
var hazard_container: Node2D = null

# ============================================
# SIGNALS
# ============================================
signal hazards_spawned(count: int)
signal hazards_cleared()

# ============================================
# LIFECYCLE
# ============================================
func _ready() -> void:
	# Load hazard scenes
	_load_hazard_scenes()

	# Create container for hazards
	hazard_container = Node2D.new()
	hazard_container.name = "HazardContainer"
	add_child(hazard_container)

	# Cache player reference
	_cache_player_reference()

func _load_hazard_scenes() -> void:
	hazard_scenes = {
		"floor_spikes": load("res://Scenes/hazards/FloorSpikes.tscn"),
		"spike_wall": load("res://Scenes/hazards/SpikeWall.tscn"),
		"fire_grate": load("res://Scenes/hazards/FireGrate.tscn"),
		"crusher": load("res://Scenes/hazards/Crusher.tscn")
	}

func _cache_player_reference() -> void:
	player_reference = get_tree().get_first_node_in_group("player")

# ============================================
# PUBLIC API
# ============================================
func spawn_hazards_for_wave(wave_number: int) -> void:
	# Clear existing hazards first
	clear_all_hazards()

	# Ensure player reference is valid
	if not player_reference:
		_cache_player_reference()

	# Get wave configuration
	var wave_config = hazards_per_wave.get(wave_number, default_wave_config)
	var hazard_count = wave_config["count"]
	var available_types = wave_config["types"]

	# Scale hazard count for higher waves
	if wave_number > 5:
		hazard_count = min(6 + (wave_number - 5), 10)  # Cap at 10 hazards

	# Spawn hazards
	for i in range(hazard_count):
		var hazard_type = get_random_hazard_type(available_types)
		var spawn_pos = get_valid_spawn_position()

		if spawn_pos != Vector2.INF:
			_spawn_hazard(hazard_type, spawn_pos)

	hazards_spawned.emit(active_hazards.size())

func clear_all_hazards() -> void:
	for hazard in active_hazards:
		if is_instance_valid(hazard):
			hazard.queue_free()

	active_hazards.clear()
	hazards_cleared.emit()

func set_player_reference(player: Node2D) -> void:
	player_reference = player

# ============================================
# SPAWNING LOGIC
# ============================================
func _spawn_hazard(hazard_type: String, position: Vector2) -> Hazard:
	if not hazard_scenes.has(hazard_type):
		push_warning("[HazardManager] Unknown hazard type '%s'" % hazard_type)
		return null

	var hazard_scene = hazard_scenes[hazard_type]
	if hazard_scene == null:
		push_warning("[HazardManager] Scene not loaded for '%s'" % hazard_type)
		return null

	var hazard = hazard_scene.instantiate() as Hazard
	if hazard:
		hazard.global_position = position
		hazard.warning_duration = warning_duration
		hazard_container.add_child(hazard)
		active_hazards.append(hazard)

		# Add death zone hazards to special group for enemy avoidance
		if hazard.hazard_type == Hazard.HazardType.DEATH_ZONE:
			hazard.add_to_group("death_zone_hazards")

		return hazard

	return null

func get_random_hazard_type(available_types: Array) -> String:
	if available_types.is_empty():
		return "fire_grate"  # Fallback
	return available_types[randi() % available_types.size()]

func get_valid_spawn_position() -> Vector2:
	var max_attempts = 50
	var attempts = 0

	while attempts < max_attempts:
		attempts += 1

		# Generate random position within rectangle arena
		var x = randf_range(arena_center.x - arena_half_width, arena_center.x + arena_half_width)
		var y = randf_range(arena_center.y - arena_half_height, arena_center.y + arena_half_height)
		var candidate_pos = Vector2(x, y)

		if is_position_valid(candidate_pos):
			return candidate_pos

	# Return invalid position if no valid spot found
	return Vector2.INF

func is_position_valid(pos: Vector2) -> bool:
	# Check if inside rectangle arena
	if abs(pos.x - arena_center.x) > arena_half_width or abs(pos.y - arena_center.y) > arena_half_height:
		return false

	# Check distance from player
	if player_reference and is_instance_valid(player_reference):
		var distance_to_player = pos.distance_to(player_reference.global_position)
		if distance_to_player < min_distance_from_player:
			return false

	# Check distance from other hazards
	for hazard in active_hazards:
		if is_instance_valid(hazard):
			var distance_to_hazard = pos.distance_to(hazard.global_position)
			if distance_to_hazard < min_distance_between_hazards:
				return false

	return true

# ============================================
# DEBUG
# ============================================
func _draw_debug() -> void:
	# Draw arena bounds (rectangle)
	if Engine.is_editor_hint():
		pass

func get_hazard_count() -> int:
	return active_hazards.size()

func get_hazards_of_type(hazard_type: Hazard.HazardType) -> Array[Hazard]:
	var result: Array[Hazard] = []
	for hazard in active_hazards:
		if is_instance_valid(hazard) and hazard.hazard_type == hazard_type:
			result.append(hazard)
	return result
