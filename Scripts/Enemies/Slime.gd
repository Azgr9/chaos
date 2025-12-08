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
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var attack_box: Area2D = $AttackBox

# ============================================
# STATE
# ============================================
var is_hopping: bool = false
var hop_cooldown: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var time_alive: float = 0.0

func _setup_enemy():
	# Slime stats
	max_health = 30.0
	move_speed = 240.0
	damage = 10.0
	current_health = max_health
	health_bar_width = 80.0

	# Connect attack box
	attack_box.area_entered.connect(_on_attack_box_area_entered)

	# Random scale variation
	var scale_variation = randf_range(0.9, 1.1)
	base_scale = Vector2(scale_variation, scale_variation)
	visuals_pivot.scale = base_scale

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	hop_cooldown -= delta

	# Idle bounce animation
	if not is_hopping:
		var idle_bounce = abs(sin(time_alive * BOUNCE_SPEED)) * BOUNCE_RANGE + 0.9
		visuals_pivot.scale.y = base_scale.y * idle_bounce
		visuals_pivot.scale.x = base_scale.x * (2.0 - idle_bounce)

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return

	if knockback_velocity.length() > 0:
		return

	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Hop toward player
	if hop_cooldown <= 0:
		_perform_hop_visual()
		hop_cooldown = hop_interval

	# Move during hop
	if is_hopping:
		velocity = direction_to_player * move_speed * 1.5
	else:
		velocity = Vector2.ZERO

func _perform_hop_visual():
	if is_hopping:
		return

	is_hopping = true

	var tween = create_tween()

	# Squash before jump
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * HOP_STRETCH, base_scale.y * HOP_SQUASH), 0.1)

	# Stretch during jump
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 0.8, base_scale.y * HOP_STRETCH), 0.3)

	# Squash on land
	tween.tween_property(visuals_pivot, "scale", Vector2(base_scale.x * 1.2, base_scale.y * 0.8), 0.1)

	# Return to normal
	tween.tween_property(visuals_pivot, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func(): is_hopping = false)

func _on_damage_taken():
	# Flash white
	sprite.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", Color("#00ff00"), 0.2)

	# Squash effect
	visuals_pivot.scale = base_scale * 1.3
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", base_scale, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)

	# Expand and fade
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "scale", base_scale * 2.0, 0.3)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return Color("#00ff00")

func _on_attack_box_area_entered(area: Area2D):
	if is_dead:
		return

	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(damage, global_position)
		damage_dealt.emit(damage)

		# Yellow flash when hitting
		sprite.color = Color("#ffff00")
		var tween = create_tween()
		tween.tween_property(sprite, "color", Color("#00ff00"), 0.1)
