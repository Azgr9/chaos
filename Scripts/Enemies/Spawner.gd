# SCRIPT: Spawner.gd
# ATTACH TO: Spawner (CharacterBody2D) root node in Spawner.tscn
# LOCATION: res://Scripts/Enemies/Spawner.gd

class_name Spawner
extends Enemy

# ============================================
# SPAWNER-SPECIFIC SETTINGS
# ============================================
@export var unlocks_at_wave: int = 5
@export var spawn_interval: float = 4.0
@export var max_minions: int = 4
@export var minion_scene: PackedScene = preload("res://Scenes/Enemies/Slime.tscn")

# Colors
const SPAWNER_COLOR: Color = Color(0.5, 0.2, 0.6)  # Dark purple
const SPAWN_COLOR: Color = Color(0.8, 0.4, 1.0)  # Bright purple

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var portal: ColorRect = $VisualsPivot/Portal
@onready var spawn_timer: Timer = $SpawnTimer

# ============================================
# STATE
# ============================================
var time_alive: float = 0.0
var minions: Array = []
var is_spawning: bool = false

func _setup_enemy():

	# Stats loaded from scene file via 
	current_health = max_health

	# Connect timer
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()

	# Color
	sprite.color = SPAWNER_COLOR
	portal.color = SPAWN_COLOR
	portal.modulate.a = 0.5

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta

	# Clean up dead minions from tracking
	minions = minions.filter(func(m): return is_instance_valid(m) and not m.is_dead)

	# Portal rotation and pulse
	portal.rotation += delta * 2.0
	var pulse = 0.4 + sin(time_alive * 4.0) * 0.2
	portal.modulate.a = pulse

	# Ominous floating
	var float_y = sin(time_alive * 1.5) * 5.0
	visuals_pivot.position.y = float_y

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return

	var direction_to_player = (player_reference.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(player_reference.global_position)

	# Face player
	visuals_pivot.scale.x = -1 if direction_to_player.x < 0 else 1

	# Stay at medium distance - let minions do the work
	if distance_to_player < 200:
		# Too close, retreat
		velocity = -direction_to_player * move_speed * 1.2
	elif distance_to_player > 400:
		# Too far, approach slowly
		velocity = direction_to_player * move_speed * 0.5
	else:
		# Good distance, strafe slowly
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		var strafe = sin(time_alive * 0.8) * 0.6
		velocity = perpendicular * move_speed * strafe

func _on_spawn_timer_timeout():
	if minions.size() < max_minions:
		_spawn_minion()

func _spawn_minion():
	if is_dead or not minion_scene:
		return

	is_spawning = true

	# Spawn animation
	var tween = create_tween()
	portal.modulate.a = 1.0
	sprite.color = SPAWN_COLOR
	tween.tween_property(portal, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_callback(_create_minion)
	tween.tween_property(portal, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(portal, "modulate:a", 0.5, 0.3)
	tween.parallel().tween_property(sprite, "color", SPAWNER_COLOR, 0.3)
	tween.tween_callback(func(): is_spawning = false)

func _create_minion():
	var minion = minion_scene.instantiate()

	# Spawn at offset position
	var spawn_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	minion.global_position = global_position + spawn_offset

	# Make minion smaller and weaker
	minion.scale = Vector2(0.7, 0.7)

	# Add to scene
	get_tree().current_scene.call_deferred("add_child", minion)

	# Track minion
	minions.append(minion)

	# Spawn effect
	_create_spawn_effect(global_position + spawn_offset)

	# Set player reference after adding to scene
	if player_reference:
		minion.call_deferred("set_player_reference", player_reference)

func _create_spawn_effect(pos: Vector2):
	# Particles burst from portal
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(10, 10)
		particle.color = SPAWN_COLOR
		get_tree().current_scene.add_child(particle)
		particle.global_position = global_position

		var angle = (i / 6.0) * TAU
		var dir = Vector2(cos(angle), sin(angle))

		var tween = create_tween()
		tween.tween_property(particle, "global_position", pos + dir * 30, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

func _on_damage_taken():
	# Call base class flash (handles the bright white modulate flash)
	super._on_damage_taken()

func _play_hit_squash():
	# Squash effect preserving facing direction
	var facing = sign(visuals_pivot.scale.x) if visuals_pivot.scale.x != 0 else 1.0
	visuals_pivot.scale = Vector2(HIT_SQUASH_SCALE.x * facing, HIT_SQUASH_SCALE.y)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2(facing, 1.0), HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	spawn_timer.stop()
	set_physics_process(false)

	# Kill all minions when spawner dies
	for minion in minions:
		if is_instance_valid(minion) and not minion.is_dead:
			minion.die()

	# Implode effect
	var tween = create_tween()
	# Grow portal
	tween.tween_property(portal, "scale", Vector2(2, 2), 0.2)
	tween.parallel().tween_property(portal, "modulate:a", 1.0, 0.2)
	# Suck in
	tween.tween_property(visuals_pivot, "scale", Vector2.ZERO, 0.3)
	tween.parallel().tween_property(portal, "rotation", portal.rotation + TAU * 2, 0.3)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return SPAWN_COLOR

func _get_death_particle_count() -> int:
	return 8
