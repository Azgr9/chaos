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
@onready var camera: Camera2D = $Camera2D

# State
var input_vector: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.RIGHT
var facing_direction: Vector2 = Vector2.RIGHT
var is_moving: bool = false
var is_attacking: bool = false
var is_melee_attacking: bool = false
var is_magic_attacking: bool = false
var current_staff: Node2D = null
var staff_inventory: Array = []
# Weapons
var current_weapon: Node2D = null
var weapon_inventory: Array = []
var current_weapon_index: int = 0

# Pixel-perfect movement
var accumulated_movement: Vector2 = Vector2.ZERO

# Dash mechanic
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
@export var dash_speed: float = 300.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
var dash_cooldown_timer: float = 0.0

# Invulnerability (for katana dash)
var is_invulnerable: bool = false

# Debug mode
var debug_mode: bool = false

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
	health_changed.emit(stats.current_health, stats.max_health)

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
	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	handle_input()

	if is_dashing:
		_handle_dash(delta)
	elif not is_attacking:  # Don't move while attacking
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
	
	# Magic attack - use is_action_pressed when staff skill is active for rapid fire
	var staff_skill_active = current_staff and current_staff.get("skill_active") == true
	var magic_input = Input.is_action_pressed("magic_attack") if staff_skill_active else Input.is_action_just_pressed("magic_attack")

	if magic_input and not is_attacking:
		perform_magic_attack()
		return
	
	# Dash input
	if Input.is_action_just_pressed("dash") and not is_dashing and not is_attacking and dash_cooldown_timer <= 0:
		perform_dash()

	# Weapon skill inputs
	if Input.is_action_just_pressed("sword_skill") and current_weapon:
		if current_weapon.has_method("use_skill"):
			current_weapon.use_skill()

	if Input.is_action_just_pressed("staff_skill") and current_staff:
		if current_staff.has_method("use_skill"):
			current_staff.use_skill()

	# Weapon switching
	if Input.is_action_just_pressed("swap_weapon"):
		switch_weapon()

	# Debug controls
	if Input.is_physical_key_pressed(KEY_O):  # O key
		if not debug_mode:
			debug_mode = true
			print("Debug mode: ON")

	if Input.is_physical_key_pressed(KEY_L):  # L key to turn off
		if debug_mode:
			debug_mode = false
			print("Debug mode: OFF")

	if debug_mode:
		if Input.is_physical_key_pressed(KEY_P):  # P key - Full heal
			stats.current_health = stats.max_health
			health_changed.emit(stats.current_health, stats.max_health)
			print("Debug: Health restored")
			await get_tree().create_timer(0.2).timeout  # Prevent spam

		if Input.is_physical_key_pressed(KEY_I):  # I key - Kill all enemies
			_debug_kill_all_enemies()
			await get_tree().create_timer(0.2).timeout  # Prevent spam

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
		# Only rotate the weapon being used - limit rotation to 45 degrees
		if is_melee_attacking:
			var target_angle = facing_direction.angle()
			weapon_pivot.rotation = clamp(target_angle, -PI/4, PI/4)
		elif is_magic_attacking:
			var target_angle = facing_direction.angle()
			staff_pivot.rotation = clamp(target_angle, -PI/4, PI/4)
	# While moving, face movement direction
	elif is_moving:
		facing_direction = last_direction
	# When idle, keep last facing direction

	# Update visual facing (flip sprite if needed)
	if facing_direction.x < 0:
		visuals_pivot.scale.x = -1
		# When facing left, flip weapon positions
		weapon_pivot.position = Vector2(-12, 0)  # Sword goes to left
		staff_pivot.position = Vector2(12, 0)    # Staff goes to right
	else:
		visuals_pivot.scale.x = 1
		# When facing right, normal positions
		weapon_pivot.position = Vector2(12, 0)   # Sword on right
		staff_pivot.position = Vector2(-12, 0)   # Staff on left

	# Keep weapons horizontal when not attacking
	if not is_melee_attacking:
		weapon_pivot.rotation = 0
	if not is_magic_attacking:
		staff_pivot.rotation = 0

func update_animation():
	# Simple animation - pulse when moving, squash when attacking
	if is_dashing:
		# Dash stretch and fade
		visuals_pivot.scale.y = 1.2
		visuals_pivot.scale.x = abs(visuals_pivot.scale.x) * 0.7 * sign(visuals_pivot.scale.x)
		sprite.modulate.a = 0.6
	elif is_attacking:
		# Attack squash and stretch
		visuals_pivot.scale.y = 0.8
		sprite.modulate.a = 1.0
	elif is_moving:
		# Walking bob
		var bob = abs(sin(Time.get_ticks_msec() * 0.01)) * 0.1 + 0.9
		visuals_pivot.scale.y = bob
		visuals_pivot.scale.x = abs(visuals_pivot.scale.x) * sign(visuals_pivot.scale.x)
		sprite.modulate.a = 1.0
	else:
		# Idle
		visuals_pivot.scale.y = 1.0
		visuals_pivot.scale.x = abs(visuals_pivot.scale.x) * sign(visuals_pivot.scale.x)
		sprite.modulate.a = 1.0

func perform_melee_attack():
	# Make sure we're using current_weapon, NOT current_staff
	if current_weapon and current_weapon.has_method("attack") and not is_attacking:
		# Get attack direction from mouse
		var mouse_pos = get_global_mouse_position()
		var attack_direction = (mouse_pos - global_position).normalized()

		# Lock player during attack
		is_attacking = true
		is_melee_attacking = true
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
	is_melee_attacking = false
	visuals_pivot.scale.y = 1.0

func perform_magic_attack():
	# Make sure we're using current_staff, NOT current_weapon
	if current_staff and current_staff.has_method("attack") and not is_attacking:
		# Get attack direction from mouse
		var mouse_pos = get_global_mouse_position()
		var attack_direction = (mouse_pos - global_position).normalized()

		# Lock player during attack
		is_attacking = true
		is_magic_attacking = true
		input_vector = Vector2.ZERO

		# Face the attack direction
		facing_direction = attack_direction
		staff_pivot.rotation = attack_direction.angle()

		# Perform the STAFF attack
		current_staff.attack(attack_direction, stats.magic_damage_multiplier)

		# Magic attacks are instant, so reset immediately after cooldown
		await get_tree().create_timer(0.3).timeout
		is_attacking = false
		is_magic_attacking = false
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
	
	weapon_switched.emit(weapon_instance)

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
	# Ignore damage if invulnerable
	if is_invulnerable:
		print("Debug: Damage blocked - player is invulnerable")
		return

	var is_dead = stats.take_damage(amount)
	health_changed.emit(stats.current_health, stats.max_health)

	# Screen shake on player damage - scale with percentage of health lost
	if camera and camera.has_method("add_trauma"):
		# Calculate damage as percentage of max health
		var damage_percent = amount / stats.max_health
		# Use square root curve for better low-damage visibility
		# sqrt gives: 5% = 0.22, 10% = 0.32, 20% = 0.45, 50% = 0.71
		var trauma_base = sqrt(damage_percent) * 1.0
		# Clamp between 0.15 and 0.85 for always noticeable but not excessive
		var trauma_amount = clamp(trauma_base, 0.15, 0.85)
		camera.add_trauma(trauma_amount)

	# Visual feedback - flash red
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE

	if is_dead:
		player_died.emit()
		queue_free()

func _on_hurt_box_area_entered(_area: Area2D):
	pass

func heal(amount: float):
	stats.heal(amount)
	health_changed.emit(stats.current_health, stats.max_health)

func on_enemy_killed():
	# Lifesteal healing
	if stats.lifesteal_amount > 0:
		heal(stats.lifesteal_amount)

		# Visual feedback for lifesteal
		var heal_label = Label.new()
		heal_label.text = "+%d HP" % int(stats.lifesteal_amount)
		heal_label.modulate = Color.GREEN
		add_child(heal_label)
		heal_label.position = Vector2(0, -30)

		var tween = create_tween()
		tween.tween_property(heal_label, "position:y", -50, 0.5)
		tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(heal_label.queue_free)

		# Green flash on player
		sprite.modulate = Color.GREEN
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _spawn_and_equip_staff(staff_scene: PackedScene):
	if current_staff:
		current_staff.queue_free()
	var staff_instance = staff_scene.instantiate()
	var staff_holder = $StaffPivot/StaffHolder
	staff_holder.add_child(staff_instance)
	staff_instance.position = Vector2.ZERO
	current_staff = staff_instance

func perform_dash():
	# Set dash direction based on input or last direction
	if input_vector.length() > 0:
		dash_direction = input_vector.normalized()
	else:
		dash_direction = last_direction

	# Start dashing
	is_dashing = true
	dash_cooldown_timer = dash_cooldown

	# Create dash trail effect
	_create_dash_trail()

	# Small screen shake on dash
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.1)

	# Dash animation and duration
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false

func _create_dash_trail():
	# Create multiple ghost sprites for trail effect
	for i in range(3):
		await get_tree().create_timer(dash_duration / 3.0).timeout

		var ghost = Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.global_position = global_position
		ghost.scale = visuals_pivot.scale
		ghost.modulate = Color(1, 1, 1, 0.3)
		get_parent().add_child(ghost)

		# Fade out ghost
		var tween = create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tween.tween_callback(ghost.queue_free)

func _handle_dash(delta):
	# Move in dash direction at dash speed
	velocity = dash_direction * dash_speed
	move_and_slide()
	position = position.round()

func set_invulnerable(invulnerable: bool):
	is_invulnerable = invulnerable
	print("Debug: Player invulnerability set to: ", invulnerable)
	# Visual feedback - slight transparency when invulnerable
	if invulnerable:
		sprite.modulate = Color(1, 1, 1, 0.5)
	else:
		sprite.modulate = Color.WHITE

func _debug_kill_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = enemies.size()
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(9999)
	print("Debug: Killed ", count, " enemies")
