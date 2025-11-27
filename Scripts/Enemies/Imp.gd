# SCRIPT: Imp.gd
# ATTACH TO: Imp (CharacterBody2D) root node in Imp.tscn
# LOCATION: res://Scripts/Enemies/Imp.gd

class_name Imp
extends Enemy

# Nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var eye1: ColorRect = $VisualsPivot/Eye1
@onready var eye2: ColorRect = $VisualsPivot/Eye2
@onready var hurt_box: Area2D = $HurtBox
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill

# State
var time_alive: float = 0.0
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
@export var dash_cooldown: float = 2.0
@export var dash_speed: float = 150.0
@export var dash_duration: float = 0.3

func _setup_enemy():
	# Imp stats - fast, weak, low health
	max_health = 10.0  # Very low health
	move_speed = 60.0  # Fastest enemy
	damage = 5.0  # Low damage
	current_health = max_health

	# Imp is worth less XP but drops crystals more often
	experience_value = 3
	crystal_drop_chance = 0.5  # 50% chance
	min_crystals = 1
	max_crystals = 2

	# Hide health bar initially
	health_bar.visible = false

	# Color variation for visual interest
	var color_variation = Color(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
	sprite.color = Color(0.6, 0.1, 0.2) * color_variation

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	dash_timer -= delta

	# Update health bar
	_update_health_bar()

	# Jittery animation when not dashing
	if not is_dashing:
		var jitter = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		visuals_pivot.position = jitter

		# Eye blink
		var blink = int(time_alive * 10) % 20
		eye1.visible = blink != 0
		eye2.visible = blink != 0

	super._physics_process(delta)

func _update_movement(delta):
	if not player_reference:
		# Find player if we don't have reference
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_reference = players[0]
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Face the player
	if direction_to_player.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# Dash behavior
	if is_dashing:
		# Continue dash
		velocity = dash_direction * dash_speed
	else:
		# Normal movement - zigzag toward player
		var zigzag = sin(time_alive * 8.0) * 15.0
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		velocity = (direction_to_player * move_speed) + (perpendicular * zigzag)

		# Try to dash when close enough
		if distance_to_player < 100 and dash_timer <= 0:
			_perform_dash(direction_to_player)

func _perform_dash(direction: Vector2):
	is_dashing = true
	dash_direction = direction
	dash_timer = dash_cooldown

	# Visual feedback - stretch in dash direction
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.5, 0.7) * Vector2(visuals_pivot.scale.x, 1), 0.1)
	tween.tween_property(visuals_pivot, "scale", Vector2.ONE * Vector2(visuals_pivot.scale.x, 1), 0.2)

	# Flash red
	sprite.color = Color.ORANGE_RED
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "color", Color(0.6, 0.1, 0.2), 0.3)

	# End dash after duration
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false

func _on_damage_taken():
	# Flash white on hit
	sprite.color = Color.WHITE
	eye1.color = Color.WHITE
	eye2.color = Color.WHITE

	var tween = create_tween()
	tween.tween_property(sprite, "color", Color(0.6, 0.1, 0.2), 0.15)
	tween.parallel().tween_property(eye1, "color", Color(1, 0.8, 0), 0.15)
	tween.parallel().tween_property(eye2, "color", Color(1, 0.8, 0), 0.15)

	# Show health bar when damaged
	health_bar.visible = true

	# Knockback squash animation
	visuals_pivot.scale = Vector2(1.3, 0.7) * Vector2(visuals_pivot.scale.x, 1)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE * Vector2(visuals_pivot.scale.x, 1), 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	is_dead = true
	set_physics_process(false)

	# Death animation - explode into particles
	var tween = create_tween()

	# Spin and shrink
	tween.tween_property(visuals_pivot, "rotation", deg_to_rad(360), 0.3)
	tween.parallel().tween_property(visuals_pivot, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(visuals_pivot, "scale", Vector2.ZERO, 0.15)

	# Fade out
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(health_bar, "modulate:a", 0.0, 0.3)

	# Create explosion particles
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.position = Vector2.ZERO
		particle.color = Color(0.6, 0.1, 0.2)
		add_child(particle)

		var particle_tween = create_tween()
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		particle_tween.tween_property(particle, "position",
			particle.position + random_dir * 25, 0.4)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.4)

	# Remove after animation
	tween.tween_callback(queue_free)

func _update_health_bar():
	if health_bar.visible:
		var health_percentage = current_health / max_health
		health_fill.size.x = 16 * health_percentage
