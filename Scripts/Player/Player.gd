# SCRIPT: Player.gd
# ATTACH TO: Player (CharacterBody2D) root node in Player.tscn
# LOCATION: res://scripts/player/Player.gd

class_name Player
extends CharacterBody2D

# Stats
@export var stats: PlayerStats

# Weapon management
@export var starting_weapon_scene: PackedScene
@export var starting_staff_scene: PackedScene

# Nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: Sprite2D = $VisualsPivot/Icon
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_holder: Marker2D = $WeaponPivot/WeaponHolder
@onready var staff_pivot: Node2D = $StaffPivot
@onready var hurt_box: Area2D = $HurtBox

# State
var input_vector: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var facing_direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false
var is_attacking: bool = false
var current_staff: Node2D = null
var staff_inventory: Array = []
# Weapons
var current_weapon: Node2D = null
var weapon_inventory: Array = []
var current_weapon_index: int = 0

# Pixel-perfect movement
var accumulated_movement: Vector2 = Vector2.ZERO

# Signals
signal health_changed(current_health: float, max_health: float)
signal player_died
signal weapon_switched(weapon: Node2D)

func _ready():
	# Add to player group so enemies can find us
	add_to_group("player")

	# Create default stats if not assigned
	if not stats:
		stats = PlayerStats.new()

	stats.reset_health()
	emit_signal("health_changed", stats.current_health, stats.max_health)

	# Connect hurt box for enemy attacks
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	
	# Ensure pixel-perfect positioning
	position = position.round()
	
	# Spawn starting weapon
	if starting_weapon_scene:
		_spawn_and_equip_weapon(starting_weapon_scene)
		# Spawn starting staff
	if starting_staff_scene:
		_spawn_and_equip_staff(starting_staff_scene)


func _physics_process(delta):
	handle_input()
	if not is_attacking:  # Don't move while attacking
		move_player_pixel_perfect(delta)
	update_facing_direction()
	update_animation()

func handle_input():
	if Input.is_action_just_pressed("melee_attack"):
		print("MELEE ATTACK pressed")
	if Input.is_action_just_pressed("magic_attack"):
		print("MAGIC ATTACK pressed")
	# Movement input
	input_vector = Vector2.ZERO
	
	if not is_attacking:  # Can't change movement during attack
		input_vector.x = Input.get_axis("move_left", "move_right")
		input_vector.y = Input.get_axis("move_up", "move_down")
		
		# Normalize diagonal movement
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		
		# Track last direction for aiming
		if input_vector.length() > 0:
			last_direction = input_vector.normalized()
			is_moving = true
		else:
			is_moving = false
	
	# Attack inputs - CHECK THESE ARE CORRECT
	if Input.is_action_just_pressed("melee_attack") and not is_attacking:
		perform_melee_attack()
		return  # Important: return early so we don't check other attacks
	
	if Input.is_action_just_pressed("magic_attack") and not is_attacking:
		perform_magic_attack()
		return
	
	# Weapon switching
	if Input.is_action_just_pressed("swap_weapon"):
		switch_weapon()
	# Movement input
	input_vector = Vector2.ZERO
	
	if not is_attacking:  # Can't change movement during attack
		input_vector.x = Input.get_axis("move_left", "move_right")
		input_vector.y = Input.get_axis("move_up", "move_down")
		
		# Normalize diagonal movement
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		
		# Track last direction for aiming
		if input_vector.length() > 0:
			last_direction = input_vector.normalized()
			is_moving = true
		else:
			is_moving = false
	
	# Attack inputs
	if Input.is_action_just_pressed("melee_attack") and not is_attacking:
		perform_melee_attack()
	
	if Input.is_action_just_pressed("magic_attack") and not is_attacking:
		perform_magic_attack()
	
	# Weapon switching
	if Input.is_action_just_pressed("swap_weapon"):
		switch_weapon()

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

func update_facing_direction():
	# Get attack direction based on mouse position
	var mouse_pos = get_global_mouse_position()
	var to_mouse = (mouse_pos - global_position).normalized()

	# During attack, face mouse direction
	if is_attacking:
		facing_direction = to_mouse
		# Rotate weapons toward mouse during attack
		weapon_pivot.rotation = facing_direction.angle()
		staff_pivot.rotation = facing_direction.angle()
	# While moving, face movement direction
	elif is_moving:
		facing_direction = last_direction
	# When idle, keep last facing direction

	# Update visual facing (flip sprite if needed)
	if facing_direction.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# Weapons always stay in same position - sword right, staff left
	weapon_pivot.position = Vector2(12, 0)
	staff_pivot.position = Vector2(-12, 0)

	# Keep weapons horizontal when not attacking
	if not is_attacking:
		weapon_pivot.rotation = 0
		staff_pivot.rotation = 0

func update_animation():
	# Simple animation - pulse when moving, squash when attacking
	if is_attacking:
		# Attack squash and stretch
		visuals_pivot.scale.y = 0.8
	elif is_moving:
		# Walking bob
		var bob = abs(sin(Time.get_ticks_msec() * 0.01)) * 0.1 + 0.9
		visuals_pivot.scale.y = bob
	else:
		# Idle
		visuals_pivot.scale.y = 1.0

func perform_melee_attack():
	# Make sure we're using current_weapon, NOT current_staff
	if current_weapon and current_weapon.has_method("attack") and not is_attacking:
		# Get attack direction from mouse
		var mouse_pos = get_global_mouse_position()
		var attack_direction = (mouse_pos - global_position).normalized()
		
		# Lock player during attack
		is_attacking = true
		input_vector = Vector2.ZERO
		
		# Face the attack direction immediately
		facing_direction = attack_direction
		weapon_pivot.rotation = attack_direction.angle()
		
		# Perform the SWORD attack
		current_weapon.attack(attack_direction, stats.melee_damage_multiplier)
		
		# Connect to attack finished signal if not already connected
		if current_weapon.has_signal("attack_finished"):
			if not current_weapon.attack_finished.is_connected(_on_attack_finished):
				current_weapon.attack_finished.connect(_on_attack_finished)

func _on_attack_finished():
	is_attacking = false
	visuals_pivot.scale.y = 1.0

func perform_magic_attack():
	# Make sure we're using current_staff, NOT current_weapon
	if current_staff and current_staff.has_method("attack"):
		# Get attack direction from mouse
		var mouse_pos = get_global_mouse_position()
		var attack_direction = (mouse_pos - global_position).normalized()
		
		# Face the attack direction
		staff_pivot.rotation = attack_direction.angle()
		
		# Perform the STAFF attack
		current_staff.attack(attack_direction, stats.magic_damage_multiplier)
func _spawn_and_equip_weapon(weapon_scene: PackedScene):
	# Remove current weapon if exists
	if current_weapon:
		current_weapon.queue_free()
	
	# Spawn new weapon
	var weapon_instance = weapon_scene.instantiate()
	weapon_holder.add_child(weapon_instance)
	weapon_instance.position = Vector2.ZERO
	
	current_weapon = weapon_instance
	
	# Connect weapon signals
	if weapon_instance.has_signal("weapon_broke"):
		weapon_instance.weapon_broke.connect(_on_weapon_broke)
	
	# Add to inventory
	if not weapon_instance in weapon_inventory:
		weapon_inventory.append(weapon_instance)
	
	emit_signal("weapon_switched", weapon_instance)

func switch_weapon():
	if weapon_inventory.size() <= 1:
		return
	
	current_weapon_index = (current_weapon_index + 1) % weapon_inventory.size()

func _on_weapon_broke():
	print("Weapon broke!")
	weapon_inventory.erase(current_weapon)
	current_weapon = null
	
	if weapon_inventory.size() > 0:
		current_weapon = weapon_inventory[0]
		current_weapon_index = 0
	else:
		print("No weapons left!")

func take_damage(amount: float):
	var is_dead = stats.take_damage(amount)
	emit_signal("health_changed", stats.current_health, stats.max_health)

	# Visual feedback - flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

	if is_dead:
		emit_signal("player_died")
		queue_free()

func _on_hurt_box_area_entered(_area: Area2D):
	pass

func heal(amount: float):
	stats.heal(amount)
	emit_signal("health_changed", stats.current_health, stats.max_health)

func _spawn_and_equip_staff(staff_scene: PackedScene):
	if current_staff:
		current_staff.queue_free()
	var staff_instance = staff_scene.instantiate()
	var staff_holder = $StaffPivot/StaffHolder
	staff_holder.add_child(staff_instance)
	staff_instance.position = Vector2.ZERO
	current_staff = staff_instance
	
