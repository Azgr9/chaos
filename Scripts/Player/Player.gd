class_name Player
extends CharacterBody2D

# Stats
@export var stats: PlayerStats

# Nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var staff_pivot: Node2D = $StaffPivot
@onready var hurt_box: Area2D = $HurtBox

# State
var input_vector: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false

# Pixel-perfect movement
var accumulated_movement: Vector2 = Vector2.ZERO

# Signals
signal health_changed(current_health: float, max_health: float)
signal player_died

func _ready():
	# Create default stats if not assigned
	if not stats:
		stats = PlayerStats.new()
	
	stats.reset_health()
	emit_signal("health_changed", stats.current_health, stats.max_health)
	
	# Connect hurt box for enemy attacks
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	
	# Ensure pixel-perfect positioning
	position = position.round()

func _physics_process(delta):
	handle_input()
	move_player_pixel_perfect(delta)
	update_pivot_rotation()
	update_animation()

func handle_input():
	# Get input from arrow keys or WASD
	input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# For pixel art, we often want 8-directional movement
	# Normalize diagonal movement
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	
	# Track last direction for aiming
	if input_vector.length() > 0:
		last_direction = input_vector.normalized()
		is_moving = true
	else:
		is_moving = false

func move_player_pixel_perfect(delta):
	# Calculate intended movement
	var intended_velocity = input_vector * stats.move_speed
	
	# For pixel-perfect movement, accumulate fractional pixels
	accumulated_movement += intended_velocity * delta
	
	# Only move by whole pixels
	var pixels_to_move = Vector2(
		int(accumulated_movement.x),
		int(accumulated_movement.y)
	)
	
	# Store the fractional part for next frame
	accumulated_movement -= pixels_to_move
	
	# Apply movement
	velocity = pixels_to_move / delta if delta > 0 else Vector2.ZERO
	move_and_slide()
	
	# Ensure position stays on pixel grid
	position = position.round()

func update_pivot_rotation():
	# Rotate weapon and staff pivots to face movement direction
	if last_direction.length() > 0:
		weapon_pivot.rotation = last_direction.angle()
		staff_pivot.rotation = last_direction.angle()

func update_animation():
	# Simple animation placeholder - make sprite pulse when moving
	if is_moving:
		var pulse = abs(sin(Time.get_ticks_msec() * 0.01)) * 0.2 + 0.9
		visuals_pivot.scale = Vector2(pulse, pulse)
	else:
		visuals_pivot.scale = Vector2.ONE

func take_damage(amount: float):
	var is_dead = stats.take_damage(amount)
	emit_signal("health_changed", stats.current_health, stats.max_health)
	
	# Visual feedback - flash red
	sprite.color = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.color = Color("#3b5dc9")  # Back to blue
	
	if is_dead:
		emit_signal("player_died")
		queue_free()

func _on_hurt_box_area_entered(area: Area2D):
	# This will be connected to enemy attacks later
	pass

func heal(amount: float):
	stats.heal(amount)
	emit_signal("health_changed", stats.current_health, stats.max_health)
