# SCRIPT: Enemy.gd
# ATTACH TO: Nothing - this is a base class
# LOCATION: res://scripts/enemies/Enemy.gd

class_name Enemy
extends CharacterBody2D

# Preload damage number scene
const DamageNumber = preload("res://Scenes/Ui/DamageNumber.tscn")
const ChaosCrystal = preload("res://Scenes/Items/ChaosCrystal.tscn")

# Base enemy stats
@export var max_health: float = 30.0
@export var move_speed: float = 240.0
@export var damage: float = 10.0
@export var knockback_resistance: float = 0.5
@export var experience_value: int = 10
@export var crystal_drop_chance: float = 0.7
@export var min_crystals: int = 1
@export var max_crystals: int = 3
@export var gold_drop_min: int = 2
@export var gold_drop_max: int = 5

# State
var current_health: float
var player_reference: Node2D = null
var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var hitstun_timer: float = 0.0
var is_stunned: bool = false

# Signals
signal enemy_died(enemy: Enemy)
@warning_ignore("unused_signal")
signal damage_dealt(amount: float)  # Available for future use (e.g., achievements, stats)
signal health_changed(current: float, max: float)

func _ready():
	current_health = max_health
	add_to_group("enemies")

	# Cache player reference once instead of searching every frame
	if not player_reference:
		player_reference = get_tree().get_first_node_in_group("player")

	_setup_enemy()

func _setup_enemy():
	# Override in child classes for specific setup
	pass

func _physics_process(delta):
	if is_dead:
		return

	_update_hitstun(delta)

	if not is_stunned:
		_update_movement(delta)

	_apply_knockback(delta)
	_avoid_player_overlap()
	move_and_slide()

func _update_movement(_delta):
	# Override in child classes for specific movement patterns
	pass

func _update_hitstun(delta):
	if hitstun_timer > 0:
		hitstun_timer -= delta
		is_stunned = true
		if hitstun_timer <= 0:
			hitstun_timer = 0
			is_stunned = false
	else:
		is_stunned = false

func _apply_knockback(delta):
	if knockback_velocity.length() > 0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)
		if knockback_velocity.length() < 5:
			knockback_velocity = Vector2.ZERO

func _avoid_player_overlap():
	# Prevent enemies from going inside the player
	if not player_reference:
		return

	# Calculate distance to player
	var to_player = player_reference.global_position - global_position
	var distance = to_player.length()

	# Minimum distance to maintain from player (based on collision shapes)
	var min_distance = 100.0  # Adjust based on your collision shape sizes

	# If too close, push away from player
	if distance < min_distance and distance > 0:
		var push_direction = -to_player.normalized()
		var push_strength = (min_distance - distance) / min_distance

		# Apply moderate push force (reduced to prevent catapulting)
		if knockback_velocity.length() == 0:
			velocity += push_direction * push_strength * 400.0  # Reduced from 200.0

func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO, knockback_power: float = 600.0, stun_duration: float = 0.0):
	if is_dead:
		return

	current_health -= amount
	health_changed.emit(current_health, max_health)

	# Spawn damage number
	_spawn_damage_number(amount)

	# Apply knockback
	if from_position != Vector2.ZERO:
		var knockback_direction = (global_position - from_position).normalized()
		knockback_velocity = knockback_direction * (knockback_power * (1.0 - knockback_resistance))

	# Apply hitstun
	if stun_duration > 0:
		hitstun_timer = stun_duration

	# Visual feedback
	_on_damage_taken()

	if current_health <= 0:
		die()

func _spawn_damage_number(damage_amount: float):
	# Instance damage number
	var damage_number = DamageNumber.instantiate()
	damage_number.global_position = global_position

	# Add to scene (get the root of the scene tree)
	get_tree().current_scene.add_child(damage_number)

	# Setup the damage amount
	damage_number.setup(damage_amount)

func _on_damage_taken():
	# Override for specific damage effects
	pass

func die():
	is_dead = true
	enemy_died.emit(self)

	# Screen shake on enemy death
	_add_screen_shake(0.3)

	# Spawn chaos crystals
	_spawn_crystals()

	# Drop gold
	_drop_gold()

	# Notify player for lifesteal
	if player_reference and player_reference.has_method("on_enemy_killed"):
		player_reference.on_enemy_killed()

	_on_death()

func _drop_gold():
	if RunManager:
		var gold_amount = randi_range(gold_drop_min, gold_drop_max)
		RunManager.add_gold(gold_amount)

func _spawn_crystals():
	# Random chance to drop crystals
	if randf() > crystal_drop_chance:
		return

	# Random number of crystals to drop
	var num_crystals = randi_range(min_crystals, max_crystals)

	for i in range(num_crystals):
		var crystal = ChaosCrystal.instantiate()

		# Spawn at enemy position with slight random offset
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		crystal.global_position = global_position + offset

		# Add to scene
		get_tree().current_scene.call_deferred("add_child", crystal)

func _add_screen_shake(trauma_amount: float):
	# Find camera and add trauma
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(trauma_amount)

func _on_death():
	# Override for specific death effects
	queue_free()

func set_player_reference(player: Node2D):
	player_reference = player
