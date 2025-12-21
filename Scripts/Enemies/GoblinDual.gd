# SCRIPT: GoblinDual.gd
# ATTACH TO: GoblinDual (CharacterBody2D) root node in GoblinDual.tscn
# LOCATION: res://Scripts/Enemies/GoblinDual.gd

class_name GoblinDual
extends Enemy

# ============================================
# GOBLIN DUAL SETTINGS
# ============================================
@export var unlocks_at_wave: int = 2

# Attack range - stop moving when this close
const ATTACK_RANGE: float = 50.0

# Attack cooldown
const ATTACK_COOLDOWN: float = 0.8

# Dash settings
const DASH_COOLDOWN: float = 8.0
const DASH_SPEED: float = 650.0
const DASH_DURATION: float = 0.25
const DASH_MIN_RANGE: float = 180.0  # Start dashing from further away
const DASH_MAX_RANGE: float = 280.0  # Maximum distance to dash
const DASH_STOP_DISTANCE: float = 100.0  # Stop dash far from player (gives player reaction time)

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var animated_sprite: AnimatedSprite2D = $VisualsPivot/AnimatedSprite2D
@onready var attack_box: Area2D = $AttackBox

# ============================================
# STATE
# ============================================
var current_direction: String = "down"
var is_attacking_anim: bool = false
var can_attack: bool = true
var attack_timer: float = 0.0
var player_in_attack_range: bool = false
var direction_locked: bool = false  # Lock direction during/after attack to prevent jitter

# Dash state
var can_dash: bool = true
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO
var dash_time_remaining: float = 0.0

func _setup_enemy():
	# Stats loaded from scene file
	current_health = max_health

	# Connect attack box
	attack_box.area_entered.connect(_on_attack_box_area_entered)
	attack_box.area_exited.connect(_on_attack_box_area_exited)

	# Connect animation finished signal
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Start with idle animation
	_play_directional_animation("idle")

func _physics_process(delta):
	if is_dead:
		return

	# Handle attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			# If player still in range, attack again
			if player_in_attack_range:
				_do_attack()

	# Handle dash cooldown
	if not can_dash:
		dash_timer -= delta
		if dash_timer <= 0:
			can_dash = true

	# Handle active dash
	if is_dashing:
		dash_time_remaining -= delta
		if dash_time_remaining <= 0:
			_end_dash()

	# Handle animation pause during hitstun
	if is_stunned:
		animated_sprite.pause()
	elif not animated_sprite.is_playing():
		animated_sprite.play()

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return

	if knockback_velocity.length() > 0:
		return

	# If dashing, use dash velocity but stop before reaching player
	if is_dashing:
		var dist_to_player = global_position.distance_to(player_reference.global_position)
		if dist_to_player <= DASH_STOP_DISTANCE:
			# Close enough, end dash early
			_end_dash()
		else:
			velocity = dash_direction * DASH_SPEED
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Update facing direction based on movement
	_update_direction(direction_to_player)

	# Try to dash if within sweet spot range and can dash
	if can_dash and distance_to_player >= DASH_MIN_RANGE and distance_to_player <= DASH_MAX_RANGE and not is_attacking_anim:
		_start_dash(direction_to_player)
		return

	# If close enough, stop and attack - otherwise move toward player
	if distance_to_player <= ATTACK_RANGE:
		# In attack range - stop moving
		velocity = Vector2.ZERO
		if not is_attacking_anim:
			_play_directional_animation("idle")
	else:
		# Not in range - move toward player
		velocity = direction_to_player * move_speed
		if not is_attacking_anim:
			_play_directional_animation("move")

func _update_direction(direction: Vector2):
	# Don't change direction while attacking or direction is locked (prevents jitter)
	if is_attacking_anim or direction_locked:
		return

	# Determine primary direction (4-way)
	var new_direction: String

	if abs(direction.x) > abs(direction.y):
		# Horizontal movement is dominant
		if direction.x > 0:
			new_direction = "right"
		else:
			new_direction = "left"
	else:
		# Vertical movement is dominant
		if direction.y > 0:
			new_direction = "down"
		else:
			new_direction = "up"

	# Only update if direction changed
	if new_direction != current_direction:
		current_direction = new_direction
		# Update animation to match new direction (only when not attacking)
		if velocity.length() > 0:
			_play_directional_animation("move")
		else:
			_play_directional_animation("idle")

func _play_directional_animation(anim_type: String):
	var anim_name = anim_type + "_" + current_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		# Only play if animation is actually changing (prevents jitter from redundant calls)
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)

func _on_animation_finished():
	# When attack animation finishes, return to idle
	if animated_sprite.animation.begins_with("attack_"):
		is_attacking_anim = false
		# Lock direction briefly after attack to prevent jitter from diagonal boundary flipping
		direction_locked = true
		_play_directional_animation("idle")
		# Unlock direction after a short delay
		_unlock_direction_delayed()

func _unlock_direction_delayed():
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		direction_locked = false

func _on_damage_taken():
	# Call base class flash
	super._on_damage_taken()

func _play_hit_squash():
	# Quick squash effect - SNAPPY timing
	visuals_pivot.scale = Vector2(HIT_SQUASH_SCALE.x, HIT_SQUASH_SCALE.y)
	var scale_tween = TweenHelper.new_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2(1.0, 1.0), HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)

	# End dash if active (stops trail creation)
	is_dashing = false

	# Reset modulate in case we died mid-dash (was green tinted)
	animated_sprite.modulate = Color.WHITE

	# Quick pop and fade - SNAPPY death
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.4, 1.4), DEATH_FADE_DURATION * 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(animated_sprite, "modulate:a", 0.0, DEATH_FADE_DURATION)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return Color(0.2, 0.5, 0.4)  # Teal-ish green

func _get_death_particle_count() -> int:
	return 8

func _on_attack_box_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		player_in_attack_range = true
		if can_attack:
			_do_attack()

func _on_attack_box_area_exited(area: Area2D):
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		player_in_attack_range = false

func _do_attack():
	# Block new attacks while already attacking (prevents animation restart jitter)
	if is_dead or not can_attack or not player_in_attack_range or is_attacking_anim:
		return

	# Play attack animation
	is_attacking_anim = true
	_play_directional_animation("attack")

	# Start cooldown
	can_attack = false
	attack_timer = ATTACK_COOLDOWN

	# Find player and deal damage
	var areas = attack_box.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent and parent.has_method("take_damage"):
			var damage_applied = parent.take_damage(damage, global_position)
			if damage_applied:
				damage_dealt.emit(damage)
				# Flash effect when hitting
				animated_sprite.modulate = Color(1.5, 1.5, 0.5)
				var tween = TweenHelper.new_tween()
				tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
			break

func _start_dash(direction: Vector2):
	is_dashing = true
	can_dash = false
	dash_direction = direction
	dash_time_remaining = DASH_DURATION
	dash_timer = DASH_COOLDOWN

	# Visual feedback - green tint and stretch
	animated_sprite.modulate = Color(0.8, 1.4, 0.8)
	visuals_pivot.scale = Vector2(1.2, 0.8)

	# Create dash trail effect
	_create_dash_trail()

func _end_dash():
	is_dashing = false
	dash_direction = Vector2.ZERO

	# Reset visual
	animated_sprite.modulate = Color.WHITE
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.0, 1.0), 0.1)

func _create_dash_trail():
	# Create multiple ghost sprites for trail effect
	for i in range(3):
		await get_tree().create_timer(DASH_DURATION / 3.0).timeout

		# Stop if goblin died or dash ended
		if not is_instance_valid(self) or is_dead or not is_dashing:
			break

		# Get current frame texture from animated sprite
		var ghost = Sprite2D.new()
		ghost.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
		ghost.global_position = global_position
		ghost.scale = visuals_pivot.scale * animated_sprite.scale
		ghost.modulate = Color(0.5, 1.0, 0.5, 0.4)  # Green tint for goblin
		get_parent().add_child(ghost)

		# Fade out ghost
		TweenHelper.fade_and_free(ghost, 0.3)
