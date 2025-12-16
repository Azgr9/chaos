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

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Update facing direction based on movement
	_update_direction(direction_to_player)

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
		# Update animation to match new direction
		if is_attacking_anim:
			_play_directional_animation("attack")
		elif velocity.length() > 0:
			_play_directional_animation("move")
		else:
			_play_directional_animation("idle")

func _play_directional_animation(anim_type: String):
	var anim_name = anim_type + "_" + current_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _on_animation_finished():
	# When attack animation finishes, return to idle
	if animated_sprite.animation.begins_with("attack_"):
		is_attacking_anim = false
		_play_directional_animation("idle")

func _on_damage_taken():
	# Call base class flash
	super._on_damage_taken()

func _play_hit_squash():
	# Squash effect
	visuals_pivot.scale = Vector2(1.3, 0.7)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2(1.0, 1.0), HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)

	# Expand and fade (like Slime)
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(2.0, 2.0), 0.3)
	tween.parallel().tween_property(animated_sprite, "modulate:a", 0.0, 0.3)

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
	if is_dead or not can_attack or not player_in_attack_range:
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
				var tween = create_tween()
				tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
			break
