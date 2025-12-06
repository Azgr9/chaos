# SCRIPT: Slime.gd
# ATTACH TO: Slime (CharacterBody2D) root node in Slime.tscn
# LOCATION: res://scripts/enemies/Slime.gd

class_name Slime
extends Enemy

# Slime specific stats
@export var hop_distance: float = 120.0
@export var hop_interval: float = 1.0
@export var unlocks_at_wave: int = 1  # Slimes available from wave 1

# Nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var hurt_box: Area2D = $HurtBox
@onready var attack_box: Area2D = $AttackBox
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var animation_timer: Timer = $AnimationTimer

# Slime state
var hop_direction: Vector2 = Vector2.ZERO
var is_hopping: bool = false
var hop_cooldown: float = 0.0
var squash_amount: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var time_alive: float = 0.0

func _setup_enemy():
	# Slime specific setup
	max_health = 30.0
	move_speed = 240.0
	damage = 10.0

	# Connect signals
	attack_box.area_entered.connect(_on_attack_box_area_entered)
	animation_timer.timeout.connect(_on_animation_timer)

	# Start with random slight scale variation
	var scale_variation = randf_range(0.9, 1.1)
	base_scale = Vector2(scale_variation, scale_variation)
	visuals_pivot.scale = base_scale

	# Hide health bar initially
	health_bar.visible = false

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	hop_cooldown -= delta

	# Update health bar
	_update_health_bar()

	# Idle animation - gentle bounce
	if not is_hopping:
		var idle_bounce = abs(sin(time_alive * 5.0)) * 0.1 + 0.9
		visuals_pivot.scale.y = base_scale.y * idle_bounce
		visuals_pivot.scale.x = base_scale.x * (2.0 - idle_bounce)  # Inverse for squash effect

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return  # Player reference set in base Enemy._ready()

	# Don't move if being knocked back
	if knockback_velocity.length() > 0:
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Move in a hopping pattern using velocity (not tweens)
	# Always pursue player immediately
	if hop_cooldown <= 0:
		# Trigger hop visual
		_perform_hop_visual()
		hop_cooldown = hop_interval

	# Continuous movement during hop
	if is_hopping:
		velocity = direction_to_player * move_speed * 1.5  # Faster during hop
	else:
		velocity = Vector2.ZERO  # Stop between hops

func _perform_hop_visual():
	if is_hopping:
		return

	is_hopping = true

	# Hop animation with tween (visuals only, no position change)
	var tween = create_tween()

	# Squash before jump
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 1.3, base_scale.y * 0.7), 0.1)

	# Jump up - stretch vertically
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 0.8, base_scale.y * 1.3), 0.3)

	# Land - squash on impact
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 1.2, base_scale.y * 0.8), 0.1)

	# Return to normal
	tween.tween_property(visuals_pivot, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Finish hop after animation
	tween.tween_callback(func(): is_hopping = false)

func _on_damage_taken():
	# Flash red on hit
	sprite.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", Color("#00ff00"), 0.2)

	# Show health bar when damaged
	health_bar.visible = true

	# Squash effect on hit
	visuals_pivot.scale = base_scale * 1.3
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", base_scale, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	is_dead = true
	set_physics_process(false)

	# Death animation
	var tween = create_tween()

	# Expand and fade out
	tween.tween_property(visuals_pivot, "scale", base_scale * 2.0, 0.3)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(health_bar, "modulate:a", 0.0, 0.3)

	# Create death particles effect (simple version)
	for i in range(5):
		var particle = ColorRect.new()
		particle.size = Vector2(16, 16)
		particle.position = Vector2(randf_range(-32, 32), randf_range(-32, 32))
		particle.color = Color("#00ff00")
		add_child(particle)

		var particle_tween = create_tween()
		var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		particle_tween.tween_property(particle, "position",
			particle.position + random_dir * 120, 0.5)
		particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)

	# Remove after animation
	tween.tween_callback(queue_free)

func _update_health_bar():
	if health_bar.visible:
		var health_percentage = current_health / max_health
		health_fill.size.x = 80 * health_percentage

func _on_attack_box_area_entered(area: Area2D):
	# Don't deal damage if dead
	if is_dead:
		return

	# Deal damage to player when they touch us
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
		damage_dealt.emit(damage)

		# Small visual feedback when hitting player
		sprite.color = Color("#ffff00")  # Yellow flash
		var tween = create_tween()
		tween.tween_property(sprite, "color", Color("#00ff00"), 0.1)


func _on_animation_timer():
	# Random slight movements for life
	if not is_hopping and not is_dead:
		var random_scale = randf_range(0.95, 1.05)
		visuals_pivot.scale = base_scale * random_scale
