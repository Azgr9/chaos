# SCRIPT: Enemy.gd
# ATTACH TO: Nothing - this is a base class
# LOCATION: res://scripts/enemies/Enemy.gd

class_name Enemy
extends CharacterBody2D

# Base enemy stats
@export var max_health: float = 30.0
@export var move_speed: float = 40.0
@export var damage: float = 10.0
@export var knockback_resistance: float = 0.5
@export var experience_value: int = 10

# State
var current_health: float
var player_reference: Node2D = null
var is_dead: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

# Signals
signal enemy_died(enemy: Enemy)
signal damage_dealt(amount: float)
signal health_changed(current: float, max: float)

func _ready():
	current_health = max_health
	add_to_group("enemies")
	_setup_enemy()

func _setup_enemy():
	# Override in child classes for specific setup
	pass

func _physics_process(delta):
	if is_dead:
		return

	_update_movement(delta)
	_apply_knockback(delta)
	move_and_slide()

func _update_movement(delta):
	# Override in child classes for specific movement patterns
	pass

func _apply_knockback(delta):
	if knockback_velocity.length() > 0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)

func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO):
	if is_dead:
		return

	current_health -= amount
	emit_signal("health_changed", current_health, max_health)

	# Apply knockback
	if from_position != Vector2.ZERO:
		var knockback_direction = (global_position - from_position).normalized()
		knockback_velocity = knockback_direction * (100 * (1.0 - knockback_resistance))

	# Visual feedback
	_on_damage_taken()

	if current_health <= 0:
		die()

func _on_damage_taken():
	# Override for specific damage effects
	pass

func die():
	is_dead = true
	emit_signal("enemy_died", self)
	_on_death()

func _on_death():
	# Override for specific death effects
	queue_free()

func set_player_reference(player: Node2D):
	player_reference = player
