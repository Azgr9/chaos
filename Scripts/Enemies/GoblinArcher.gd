# SCRIPT: GoblinArcher.gd
# ATTACH TO: GoblinArcher (CharacterBody2D) root node in GoblinArcher.tscn
# LOCATION: res://Scripts/Enemies/GoblinArcher.gd

class_name GoblinArcher
extends Enemy

# Archer specific properties
@export var unlocks_at_wave: int = 2  # Goblin Archers unlock at wave 2
@export var arrow_scene: PackedScene = preload("res://Scenes/Enemies/EnemyArrow.tscn")
@export var shoot_range: float = 480.0
@export var retreat_range: float = 200.0
@export var shoot_cooldown: float = 2.0

# Nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var bow: ColorRect = $VisualsPivot/Bow
@onready var hurt_box: Area2D = $HurtBox
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var shoot_timer: Timer = $ShootTimer
@onready var animation_timer: Timer = $AnimationTimer

# State
var can_shoot: bool = true
var is_shooting: bool = false
var time_alive: float = 0.0

func _setup_enemy():
	# Goblin archer stats
	max_health = 20.0  # Less health than slime
	move_speed = 180.0  # Slower movement
	damage = 8.0
	current_health = max_health

	# Connect signals
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	animation_timer.timeout.connect(_on_animation_timer)

	# Start timers
	shoot_timer.start()

	# Hide health bar initially
	health_bar.visible = false

	# Color variation
	var color_variation = Color(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
	sprite.color = Color("#2d5016") * color_variation

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta

	# Update health bar
	_update_health_bar()

	# Idle animation - gentle sway
	if not is_shooting:
		var sway = sin(time_alive * 3.0) * 0.1
		visuals_pivot.rotation = sway

	super._physics_process(delta)

func _update_movement(delta):
	if not player_reference:
		return  # Player reference set in base Enemy._ready()

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Face the player
	if direction_to_player.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# Movement AI
	if distance_to_player < retreat_range:
		# Too close - retreat!
		velocity = -direction_to_player * move_speed * 1.5  # Faster retreat
	elif distance_to_player > shoot_range:
		# Too far - move closer
		velocity = direction_to_player * move_speed
	else:
		# Good distance - stand and shoot
		velocity = velocity.lerp(Vector2.ZERO, 5 * delta)

		# Try to shoot - always shoot when in range
		if can_shoot:
			_shoot_arrow()

func _shoot_arrow():
	# Don't shoot if dead
	if is_dead or not player_reference or is_shooting:
		return

	is_shooting = true
	can_shoot = false

	# Shooting animation
	var tween = create_tween()

	# Pull bow back
	bow.position.x = 20
	tween.tween_property(bow, "position:x", 28, 0.2)

	# Flash before shooting
	sprite.color = Color.YELLOW
	tween.tween_property(sprite, "color", Color("#2d5016"), 0.1)

	# Spawn arrow
	tween.tween_callback(_spawn_arrow)

	# Recoil animation
	tween.tween_property(visuals_pivot, "position:x", -8, 0.1)
	tween.tween_property(visuals_pivot, "position:x", 0, 0.2)

	# Reset
	tween.tween_callback(func(): is_shooting = false)

func _spawn_arrow():
	# Don't spawn arrows if dead
	if is_dead or not arrow_scene or not player_reference:
		return

	# Create arrow
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)

	# Initialize arrow with slight prediction of player movement
	var target_pos = player_reference.global_position

	# Add some inaccuracy for fairness
	var spread = randf_range(-40, 40)
	target_pos.x += spread
	target_pos.y += spread

	arrow.initialize(global_position, target_pos)

func _on_shoot_timer_timeout():
	can_shoot = true

func _on_damage_taken():
	# Flash white on hit
	sprite.color = Color.WHITE
	bow.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", Color("#2d5016"), 0.2)
	tween.parallel().tween_property(bow, "color", Color("#8B4513"), 0.2)

	# Show health bar when damaged
	health_bar.visible = true

	# Knockback animation
	visuals_pivot.scale = Vector2(1.2, 0.8)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	is_dead = true
	set_physics_process(false)
	shoot_timer.stop()

	# Death animation
	var tween = create_tween()

	# Fall over
	tween.tween_property(visuals_pivot, "rotation", deg_to_rad(90), 0.3)
	tween.parallel().tween_property(visuals_pivot, "scale", Vector2(0.8, 1.2), 0.3)

	# Fade out
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(bow, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(health_bar, "modulate:a", 0.0, 0.3)

	# Drop arrows as death effect
	for i in range(3):
		var particle = ColorRect.new()
		particle.size = Vector2(32, 8)
		particle.position = Vector2(randf_range(-32, 32), randf_range(-32, 32))
		particle.color = Color("#8B4513")
		particle.rotation = randf() * TAU
		add_child(particle)

		var particle_tween = create_tween()
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		particle_tween.tween_property(particle, "position",
			particle.position + random_dir * 80, 0.5)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)

	# Remove after animation
	tween.tween_callback(queue_free)

func _update_health_bar():
	if health_bar.visible:
		var health_percentage = current_health / max_health
		health_fill.size.x = 80 * health_percentage

func _on_animation_timer():
	# Occasional idle animations
	if not is_shooting and not is_dead and randf() < 0.3:
		# Adjust bow slightly
		var tween = create_tween()
		tween.tween_property(bow, "rotation", randf_range(-0.2, 0.2), 0.2)
		tween.tween_property(bow, "rotation", 0, 0.2)
