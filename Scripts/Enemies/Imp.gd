# SCRIPT: Imp.gd
# ATTACH TO: Imp (CharacterBody2D) root node in Imp.tscn
# LOCATION: res://Scripts/Enemies/Imp.gd

class_name Imp
extends Enemy

# ============================================
# IMP-SPECIFIC SETTINGS
# ============================================
@export var unlocks_at_wave: int = 1
@export var dash_cooldown: float = 2.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.3

# Movement constants
const ZIGZAG_FREQUENCY: float = 8.0
const ZIGZAG_AMPLITUDE: float = 60.0
const DASH_TRIGGER_DISTANCE: float = 400.0

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var eye1: ColorRect = $VisualsPivot/Eye1
@onready var eye2: ColorRect = $VisualsPivot/Eye2
@onready var hurt_box: Area2D = $HurtBox

# ============================================
# STATE
# ============================================
var time_alive: float = 0.0
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO

func _setup_enemy():
	# Bestiary info
	enemy_type = "imp"
	enemy_display_name = "Imp"

	# Imp stats - fast, weak, low health
	max_health = 10.0
	move_speed = 360.0
	damage = 5.0
	current_health = max_health
	health_bar_width = 64.0

	# Drop settings
	experience_value = 3
	crystal_drop_chance = 0.5
	min_crystals = 1
	max_crystals = 2

	# Connect contact damage
	hurt_box.monitoring = true
	hurt_box.area_entered.connect(_on_hurt_box_area_entered)

	# Color variation
	var color_variation = Color(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
	sprite.color = Color(0.6, 0.1, 0.2) * color_variation

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	dash_timer -= delta

	# Jittery animation
	if not is_dashing:
		var jitter = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
		visuals_pivot.position = jitter

		# Eye blink
		var blink = int(time_alive * 10) % 20
		eye1.visible = blink != 0
		eye2.visible = blink != 0

	super._physics_process(delta)

func _update_movement(_delta):
	if not player_reference:
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Face player
	visuals_pivot.scale.x = -1 if direction_to_player.x < 0 else 1

	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		# Zigzag movement
		var zigzag = sin(time_alive * ZIGZAG_FREQUENCY) * ZIGZAG_AMPLITUDE
		var perpendicular = Vector2(-direction_to_player.y, direction_to_player.x)
		velocity = (direction_to_player * move_speed) + (perpendicular * zigzag)

		# Dash when close
		if distance_to_player < DASH_TRIGGER_DISTANCE and dash_timer <= 0:
			_perform_dash(direction_to_player)

func _perform_dash(direction: Vector2):
	is_dashing = true
	dash_direction = direction
	dash_timer = dash_cooldown

	# Stretch visual
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(1.5, 0.7) * Vector2(visuals_pivot.scale.x, 1), 0.1)
	tween.tween_property(visuals_pivot, "scale", Vector2.ONE * Vector2(visuals_pivot.scale.x, 1), 0.2)

	# Flash red
	sprite.color = Color.ORANGE_RED
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "color", Color(0.6, 0.1, 0.2), 0.3)

	# End dash
	await get_tree().create_timer(dash_duration).timeout
	is_dashing = false

func _on_damage_taken():
	# Flash white
	sprite.color = Color.WHITE
	eye1.color = Color.WHITE
	eye2.color = Color.WHITE

	var tween = create_tween()
	tween.tween_property(sprite, "color", Color(0.6, 0.1, 0.2), 0.15)
	tween.parallel().tween_property(eye1, "color", Color(1, 0.8, 0), 0.15)
	tween.parallel().tween_property(eye2, "color", Color(1, 0.8, 0), 0.15)

	# Knockback squash
	visuals_pivot.scale = Vector2(1.3, 0.7) * Vector2(visuals_pivot.scale.x, 1)
	var scale_tween = create_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE * Vector2(visuals_pivot.scale.x, 1), 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)

	# Spin and shrink
	var tween = create_tween()
	tween.tween_property(visuals_pivot, "rotation", deg_to_rad(360), 0.3)
	tween.parallel().tween_property(visuals_pivot, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(visuals_pivot, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return Color(0.6, 0.1, 0.2)

func _get_death_particle_count() -> int:
	return 6

func _on_hurt_box_area_entered(area: Area2D):
	if is_dead:
		return

	var parent = area.get_parent()
	if parent and is_instance_valid(parent) and parent.is_in_group("player"):
		if parent.has_method("take_damage"):
			parent.take_damage(damage, global_position)
