# SCRIPT: Player.gd
# ATTACH TO: Player (CharacterBody2D) root node in Player.tscn
# LOCATION: res://scripts/player/Player.gd

class_name Player
extends CharacterBody2D

# Constants
const BASE_MOVE_SPEED: float = 450.0

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
var current_staff_index: int = 0

# Pixel-perfect movement
var accumulated_movement: Vector2 = Vector2.ZERO

# Dash mechanic
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
@export var dash_speed: float = 1600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
var dash_cooldown_timer: float = 0.0

# Invulnerability (for katana dash)
var is_invulnerable: bool = false

# Debug mode
var debug_mode: bool = false

# Phoenix Feather revive tracking
var phoenix_revive_used: bool = false

# Signals
signal health_changed(current_health: float, max_health: float)
signal player_died
signal player_revived
signal weapon_switched(weapon: Node2D)
signal staff_switched(staff: Node2D)

func _ready():
	# Add to player group so enemies can find us
	add_to_group("player")

	# Create default stats if not assigned
	if not stats:
		stats = PlayerStats.new()

	# Apply relic stats from RunManager before resetting health
	apply_relic_stats()

	# Connect to RunManager to update stats when relics are collected
	if RunManager:
		RunManager.stats_changed.connect(_on_relic_stats_changed)

	stats.reset_health()
	health_changed.emit(stats.current_health, stats.max_health)

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

	# Debug mode is now handled by DebugMenu (press O to open)

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
		# Only rotate staff pivot during magic attacks - melee weapon handles its own animation
		if is_magic_attacking:
			var target_angle = facing_direction.angle()
			staff_pivot.rotation = clamp(target_angle, -PI/4, PI/4)
		# Don't touch weapon_pivot during melee attack - animation handles direction
	# While moving, face movement direction
	elif is_moving:
		facing_direction = last_direction
	# When idle, keep last facing direction

	# Update visual facing (flip sprite)
	if facing_direction.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# Weapon pivot flipping - only when NOT melee attacking
	# During melee attack, the animation handles all directions via current_attack_direction
	if is_melee_attacking:
		weapon_pivot.scale.x = 1  # Keep normal scale during attack
		weapon_pivot.rotation = 0  # Animation controls pivot rotation
		# Position weapon slightly away from player center in attack direction
		# This makes the sword swing farther from the player body
		weapon_holder.position = facing_direction * 55
	else:
		# Normal idle/movement - weapon follows player facing
		if facing_direction.x < 0:
			weapon_pivot.scale.x = -1
		else:
			weapon_pivot.scale.x = 1
		weapon_pivot.rotation = 0
		# Return weapon to side position when not attacking
		weapon_holder.position = Vector2(40, 24)

	# Staff pivot always follows facing direction
	if facing_direction.x < 0:
		staff_pivot.scale.x = -1
	else:
		staff_pivot.scale.x = 1

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
		# Don't rotate weapon_pivot - let the weapon animation handle its own rotation
		# The weapon uses current_attack_direction internally for direction-aware animations
		weapon_pivot.rotation = 0

		# Perform the SWORD attack
		current_weapon.attack(attack_direction, stats.melee_damage_multiplier)

		# Connect to attack finished signal if not already connected
		if current_weapon.has_signal("attack_finished"):
			if not current_weapon.attack_finished.is_connected(_on_attack_finished):
				current_weapon.attack_finished.connect(_on_attack_finished)

		# Safety timeout - force reset attack state if signal doesn't fire
		_start_attack_safety_timeout()

var _attack_safety_timer: SceneTreeTimer = null

func _start_attack_safety_timeout():
	# Safety timeout to force reset if attack_finished signal never fires
	_attack_safety_timer = get_tree().create_timer(1.5)
	_attack_safety_timer.timeout.connect(_on_attack_safety_timeout)

func _on_attack_safety_timeout():
	# Only reset if still stuck in attack state
	if is_attacking or is_melee_attacking:
		print("WARNING: Attack state stuck, forcing reset")
		_on_attack_finished()

func _on_attack_finished():
	_attack_safety_timer = null  # Clear safety timer
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
	# Disconnect signals from old weapon before removing
	if current_weapon:
		if current_weapon.has_signal("attack_finished") and current_weapon.attack_finished.is_connected(_on_attack_finished):
			current_weapon.attack_finished.disconnect(_on_attack_finished)
		if current_weapon.has_signal("weapon_broke") and current_weapon.weapon_broke.is_connected(_on_weapon_broke):
			current_weapon.weapon_broke.disconnect(_on_weapon_broke)
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

func _input(event):
	# Mouse wheel weapon/staff switching (only when not attacking)
	if event is InputEventMouseButton and not is_attacking:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				# Scroll up = cycle weapons
				_cycle_weapon(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				# Scroll down = cycle staffs
				_cycle_staff(1)

func _cycle_weapon(direction: int):
	if weapon_inventory.size() <= 1:
		return

	var new_index = (current_weapon_index + direction) % weapon_inventory.size()
	if new_index < 0:
		new_index = weapon_inventory.size() - 1
	switch_to_weapon(new_index)

func _cycle_staff(direction: int):
	if staff_inventory.size() <= 1:
		return

	var new_index = (current_staff_index + direction) % staff_inventory.size()
	if new_index < 0:
		new_index = staff_inventory.size() - 1
	switch_to_staff(new_index)

func switch_to_weapon(index: int):
	if index < 0 or index >= weapon_inventory.size():
		return
	if index == current_weapon_index and current_weapon:
		return  # Already using this weapon

	# Hide old weapon
	if current_weapon:
		current_weapon.visible = false

	# Show and set new weapon
	current_weapon_index = index
	current_weapon = weapon_inventory[index]
	current_weapon.visible = true

	# Visual feedback
	_weapon_switch_effect()

	weapon_switched.emit(current_weapon)
	print("[Player] Switched to weapon: %s" % (current_weapon.name if current_weapon else "None"))

func switch_to_staff(index: int):
	if index < 0 or index >= staff_inventory.size():
		return
	if index == current_staff_index and current_staff:
		return  # Already using this staff

	# Hide old staff
	if current_staff:
		current_staff.visible = false

	# Show and set new staff
	current_staff_index = index
	current_staff = staff_inventory[index]
	current_staff.visible = true

	# Visual feedback
	_staff_switch_effect()

	staff_switched.emit(current_staff)
	print("[Player] Switched to staff: %s" % (current_staff.name if current_staff else "None"))

func _weapon_switch_effect():
	# Quick flash effect when switching weapons
	if current_weapon:
		var tween = create_tween()
		tween.tween_property(current_weapon, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(current_weapon, "modulate", Color.WHITE, 0.1)

func _staff_switch_effect():
	# Quick flash effect when switching staffs
	if current_staff:
		var tween = create_tween()
		tween.tween_property(current_staff, "modulate", Color(1.2, 1.2, 1.5), 0.1)
		tween.tween_property(current_staff, "modulate", Color.WHITE, 0.1)

func switch_weapon():
	# Legacy function - cycle to next weapon
	_cycle_weapon(1)

func _on_weapon_broke():
	weapon_inventory.erase(current_weapon)
	current_weapon = null

	if weapon_inventory.size() > 0:
		current_weapon = weapon_inventory[0]
		current_weapon_index = 0

func take_damage(amount: float, from_position: Vector2 = Vector2.ZERO) -> bool:
	# Ignore damage if invulnerable - return false to indicate no damage applied
	if is_invulnerable:
		return false

	# Apply damage reduction from relics
	var reduced_amount = amount * (1.0 - stats.damage_reduction)
	reduced_amount = max(1.0, reduced_amount)  # Minimum 1 damage

	var is_dead = stats.take_damage(reduced_amount)
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

	# Hit knockback jiggle - small recoil in opposite direction of damage source
	_apply_hit_recoil(from_position)

	# Visual feedback - flash red and squash
	_play_hit_effect()

	if is_dead:
		# Check for Phoenix Feather revive
		if _try_phoenix_revive():
			return true

		player_died.emit()
		queue_free()

	return true

func _try_phoenix_revive() -> bool:
	# Check if we already used a revive this run
	if phoenix_revive_used:
		return false

	# Check if player has Phoenix Feather relic
	if RunManager and RunManager.has_special_effect("phoenix_revive"):
		phoenix_revive_used = true

		# Revive with 50% health
		var revive_health = stats.max_health * 0.5
		stats.current_health = revive_health
		health_changed.emit(stats.current_health, stats.max_health)

		# Visual feedback - golden burst
		_phoenix_revive_effect()

		player_revived.emit()
		return true

	return false

func _phoenix_revive_effect():
	# Make player invulnerable briefly
	is_invulnerable = true

	# Golden flash
	sprite.modulate = Color(1, 0.8, 0.2, 1)

	# Screen shake
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.6)

	# Create expanding ring effect
	var ring = ColorRect.new()
	ring.color = Color(1, 0.7, 0.2, 0.6)
	ring.size = Vector2(20, 20)
	ring.position = Vector2(-10, -10)
	ring.pivot_offset = ring.size / 2
	add_child(ring)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(15, 15), 0.5)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)

	# Flash back to normal
	await get_tree().create_timer(0.5).timeout
	sprite.modulate = Color.WHITE

	# Brief invulnerability window
	await get_tree().create_timer(1.0).timeout
	is_invulnerable = false

func _apply_hit_recoil(from_position: Vector2):
	# Small knockback jiggle when hit
	var recoil_direction: Vector2
	if from_position != Vector2.ZERO:
		recoil_direction = (global_position - from_position).normalized()
	else:
		# Random direction if no source specified
		recoil_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# Quick jolt backwards then return
	var original_pos = visuals_pivot.position
	var recoil_offset = recoil_direction * 8.0  # Small 8 pixel recoil

	var tween = create_tween()
	tween.tween_property(visuals_pivot, "position", original_pos + recoil_offset, 0.05)
	tween.tween_property(visuals_pivot, "position", original_pos, 0.1).set_trans(Tween.TRANS_ELASTIC)

func _play_hit_effect():
	# Flash red
	sprite.modulate = Color.RED

	# Squash effect - flatten slightly on hit
	var original_scale = visuals_pivot.scale
	visuals_pivot.scale = Vector2(original_scale.x * 1.2, original_scale.y * 0.8)

	var tween = create_tween()
	# Return to normal with bounce
	tween.tween_property(visuals_pivot, "scale", original_scale, 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Flash back to white
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.1)

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
		heal_label.position = Vector2(0, -120)

		var tween = create_tween()
		tween.tween_property(heal_label, "position:y", -200, 0.5)
		tween.parallel().tween_property(heal_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(heal_label.queue_free)

		# Green flash on player
		sprite.modulate = Color.GREEN
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _spawn_and_equip_staff(staff_scene: PackedScene):
	var staff_instance = staff_scene.instantiate()
	var staff_holder = $StaffPivot/StaffHolder
	staff_holder.add_child(staff_instance)
	staff_instance.position = Vector2.ZERO

	# Add to inventory
	if not staff_instance in staff_inventory:
		staff_inventory.append(staff_instance)

	# Set as current staff
	current_staff = staff_instance
	current_staff_index = staff_inventory.size() - 1

	staff_switched.emit(staff_instance)

func perform_dash():
	# Set dash direction based on input or last direction
	if input_vector.length() > 0:
		dash_direction = input_vector.normalized()
	else:
		dash_direction = last_direction

	# Start dashing - invulnerable during dash
	is_dashing = true
	is_invulnerable = true
	dash_cooldown_timer = dash_cooldown

	# Visual feedback
	sprite.modulate = Color(1, 1, 1, 0.5)

	# Create dash trail effect
	_create_dash_trail()

	# Small screen shake on dash
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.1)

	# Dash animation and duration
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false
	is_invulnerable = false
	sprite.modulate = Color.WHITE

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

func _handle_dash(_delta):
	# Move in dash direction at dash speed
	velocity = dash_direction * dash_speed
	move_and_slide()
	position = position.round()

func set_invulnerable(invulnerable: bool):
	is_invulnerable = invulnerable
	# Visual feedback - slight transparency when invulnerable
	if invulnerable:
		sprite.modulate = Color(1, 1, 1, 0.5)
	else:
		sprite.modulate = Color.WHITE

func _debug_kill_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(9999, Vector2.ZERO, 0.0, 0.0, null)

# ============================================
# RELIC STATS APPLICATION
# ============================================

func apply_relic_stats():
	if not RunManager:
		return

	var calculated = RunManager.run_data.calculated_stats

	# Apply max health bonus (preserve health percentage)
	var health_ratio = stats.get_health_percentage() if stats.current_health > 0 else 1.0
	stats.max_health = calculated.max_health
	stats.current_health = stats.max_health * health_ratio

	# Apply damage multipliers
	stats.melee_damage_multiplier = calculated.damage_multiplier
	stats.magic_damage_multiplier = calculated.damage_multiplier

	# Apply speed multiplier
	stats.move_speed = BASE_MOVE_SPEED * calculated.speed_multiplier

	# Apply attack speed (cooldown reduction)
	stats.attack_speed_multiplier = calculated.cooldown_multiplier

	# Apply crit stats
	stats.crit_chance = calculated.crit_chance
	stats.crit_damage = calculated.crit_damage

	# Apply lifesteal
	stats.lifesteal_amount = calculated.lifesteal

	# Apply damage reduction
	stats.damage_reduction = calculated.damage_reduction

func _on_relic_stats_changed():
	var old_max_health = stats.max_health
	apply_relic_stats()

	# If max health increased, heal for the difference
	if stats.max_health > old_max_health:
		var health_gained = stats.max_health - old_max_health
		stats.current_health = min(stats.current_health + health_gained, stats.max_health)

	health_changed.emit(stats.current_health, stats.max_health)
