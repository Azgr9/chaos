# SCRIPT: Slime.gd
# ATTACH TO: Slime (CharacterBody2D) root node in Slime.tscn
# LOCATION: res://Scripts/Enemies/Slime.gd

class_name Slime
extends Enemy

# ============================================
# SLIME-SPECIFIC SETTINGS
# ============================================
@export var hop_distance: float = 120.0
@export var hop_interval: float = 1.0
@export var unlocks_at_wave: int = 1

# Animation constants
const BOUNCE_SPEED: float = 5.0
const BOUNCE_RANGE: float = 0.1
const HOP_STRETCH: float = 1.3
const HOP_SQUASH: float = 0.7

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var animated_sprite: AnimatedSprite2D = $VisualsPivot/AnimatedSprite2D
@onready var attack_box: Area2D = $AttackBox

# ============================================
# STATE
# ============================================
var is_hopping: bool = false
var hop_cooldown: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var time_alive: float = 0.0
var current_direction: String = "down"  # down, up, left, right

# Continuous damage tracking
var targets_in_attack_box: Array = []
var attack_tick_timer: float = 0.0
const ATTACK_TICK_INTERVAL: float = 0.5  # Damage every 0.5 seconds

# Frame-based damage
var pending_damage_targets: Array = []  # Targets waiting for damage on hit frame
var has_dealt_damage_this_attack: bool = false
const DAMAGE_FRAME: int = 3  # Frame where damage is dealt (0-indexed, 4th frame)

func _setup_enemy():
	# Stats loaded from scene file
	current_health = max_health

	# Connect attack box
	attack_box.area_entered.connect(_on_attack_box_area_entered)
	attack_box.area_exited.connect(_on_attack_box_area_exited)

	# Connect animation finished signal for attack animation
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)

	# Random scale variation
	var scale_variation = randf_range(0.9, 1.1)
	base_scale = Vector2(scale_variation, scale_variation)
	visuals_pivot.scale = base_scale

	# Start with idle animation
	_play_directional_animation("idle")

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	hop_cooldown -= delta

	# Handle continuous damage to targets in attack box
	_process_continuous_damage(delta)

	# Handle animation pause during hitstun
	if is_stunned:
		animated_sprite.pause()
	elif not animated_sprite.is_playing():
		animated_sprite.play()

	# Idle bounce animation (scale effect on top of sprite animation)
	if not is_hopping and not is_stunned:
		var idle_bounce = abs(sin(time_alive * BOUNCE_SPEED)) * BOUNCE_RANGE + 0.9
		visuals_pivot.scale.y = base_scale.y * idle_bounce
		visuals_pivot.scale.x = base_scale.x * (2.0 - idle_bounce)

	super._physics_process(delta)

func _process_continuous_damage(delta):
	if targets_in_attack_box.is_empty():
		attack_tick_timer = 0.0
		return

	attack_tick_timer += delta
	if attack_tick_timer >= ATTACK_TICK_INTERVAL:
		attack_tick_timer = 0.0
		# Start attack animation - damage will be dealt on DAMAGE_FRAME
		_start_attack(targets_in_attack_box.duplicate())

func _start_attack(targets: Array):
	# Queue targets for damage and start attack animation
	pending_damage_targets = targets
	has_dealt_damage_this_attack = false
	_play_directional_animation("attack")

func _deal_pending_damage():
	if has_dealt_damage_this_attack:
		return
	has_dealt_damage_this_attack = true

	for target in pending_damage_targets:
		if is_instance_valid(target):
			var parent = target.get_parent()
			if parent and parent.has_method("take_damage"):
				var damage_applied = parent.take_damage(damage, global_position)
				if damage_applied:
					damage_dealt.emit(damage)
					# Flash effect when hitting
					animated_sprite.modulate = Color(1.5, 1.5, 0.5)
					var tween = TweenHelper.new_tween()
					tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	pending_damage_targets.clear()

func _on_frame_changed():
	# Deal damage on the hit frame of attack animation
	if animated_sprite.animation.begins_with("attack_") and animated_sprite.frame == DAMAGE_FRAME:
		_deal_pending_damage()

func _update_movement(_delta):
	if knockback_velocity.length() > 0:
		return

	# Get best target (player or nearest minion)
	var target = get_best_target()
	if not target:
		return

	var direction_to_target = (target.global_position - global_position).normalized()

	# Update facing direction based on movement
	_update_direction(direction_to_target)

	# Hop toward target
	if hop_cooldown <= 0:
		_perform_hop_visual()
		hop_cooldown = hop_interval

	# Move during hop
	if is_hopping:
		velocity = direction_to_target * move_speed * 1.5
	else:
		velocity = Vector2.ZERO

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
		if is_hopping:
			_play_directional_animation("move")
		else:
			_play_directional_animation("idle")

func _play_directional_animation(anim_type: String):
	var anim_name = anim_type + "_" + current_direction
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)

func _perform_hop_visual():
	if is_hopping:
		return

	is_hopping = true

	# Play move animation during hop
	_play_directional_animation("move")

	var tween = TweenHelper.new_tween()

	# Squash before jump
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * HOP_STRETCH, base_scale.y * HOP_SQUASH), 0.1)

	# Stretch during jump
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 0.8, base_scale.y * HOP_STRETCH), 0.3)

	# Squash on land
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 1.2, base_scale.y * 0.8), 0.1)

	# Return to normal
	tween.tween_property(visuals_pivot, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	tween.tween_callback(_on_hop_finished)

func _on_hop_finished():
	is_hopping = false
	# Return to idle animation
	_play_directional_animation("idle")

func _on_animation_finished():
	# When attack animation finishes, return to idle
	if animated_sprite.animation.begins_with("attack_"):
		_play_directional_animation("idle")

func _on_damage_taken():
	# Call base class flash (handles the bright white modulate flash)
	super._on_damage_taken()

func _play_hit_squash():
	# Quick squash effect using base_scale - SNAPPY timing
	visuals_pivot.scale = base_scale * Vector2(HIT_SQUASH_SCALE.x, HIT_SQUASH_SCALE.y)
	var scale_tween = TweenHelper.new_tween()
	scale_tween.tween_property(visuals_pivot, "scale", base_scale, HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)

	# Quick pop and fade - SNAPPY death
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale", base_scale * 1.4, DEATH_FADE_DURATION * 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(animated_sprite, "modulate:a", 0.0, DEATH_FADE_DURATION)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return Color("#00ff00")

func _on_attack_box_area_entered(area: Area2D):
	if is_dead:
		return

	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		# Add to tracking list for continuous damage
		if not targets_in_attack_box.has(area):
			targets_in_attack_box.append(area)

		# Start attack animation - damage will be dealt on hit frame
		_start_attack([area])

func _on_attack_box_area_exited(area: Area2D):
	targets_in_attack_box.erase(area)
