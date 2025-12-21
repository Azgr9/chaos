# SCRIPT: GoblinArcher.gd
# ATTACH TO: GoblinArcher (CharacterBody2D) root node in GoblinArcher.tscn
# LOCATION: res://Scripts/Enemies/GoblinArcher.gd

class_name GoblinArcher
extends Enemy

# ============================================
# ARCHER-SPECIFIC SETTINGS
# ============================================
@export var unlocks_at_wave: int = 2
@export var arrow_scene: PackedScene = preload("res://Scenes/Enemies/EnemyArrow.tscn")
@export var shoot_range: float = 480.0
@export var retreat_range: float = 200.0
@export var shoot_cooldown: float = 2.0

# Movement constants
const RETREAT_SPEED_MULTIPLIER: float = 1.5
const ARROW_SPREAD: float = 40.0
const GOBLIN_COLOR: Color = Color("#2d5016")

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var sprite: ColorRect = $VisualsPivot/Sprite
@onready var bow: ColorRect = $VisualsPivot/Bow
@onready var shoot_timer: Timer = $ShootTimer

# ============================================
# STATE
# ============================================
var can_shoot: bool = true
var is_shooting: bool = false
var time_alive: float = 0.0

func _setup_enemy():

	# Stats loaded from scene file via 
	current_health = max_health

	# Connect timer
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start()

	# Color variation
	var color_variation = Color(randf_range(0.9, 1.1), randf_range(0.9, 1.1), randf_range(0.9, 1.1))
	sprite.color = GOBLIN_COLOR * color_variation

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta

	# Idle sway animation
	if not is_shooting:
		var sway = sin(time_alive * 3.0) * 0.1
		visuals_pivot.rotation = sway

	super._physics_process(delta)

func _update_movement(delta):
	if not player_reference:
		return

	var distance_to_player = global_position.distance_to(player_reference.global_position)
	var direction_to_player = (player_reference.global_position - global_position).normalized()

	# Face player
	visuals_pivot.scale.x = -1 if direction_to_player.x < 0 else 1

	# Movement AI
	if distance_to_player < retreat_range:
		# Too close - retreat
		velocity = -direction_to_player * move_speed * RETREAT_SPEED_MULTIPLIER
	elif distance_to_player > shoot_range:
		# Too far - approach
		velocity = direction_to_player * move_speed
	else:
		# Good distance - stand and shoot
		velocity = velocity.lerp(Vector2.ZERO, 5 * delta)
		if can_shoot:
			_shoot_arrow()

func _shoot_arrow():
	if is_dead or not player_reference or is_shooting:
		return

	is_shooting = true
	can_shoot = false

	var tween = TweenHelper.new_tween()

	# Pull bow back
	bow.position.x = 20
	tween.tween_property(bow, "position:x", 28, 0.2)

	# Flash before shooting
	sprite.color = Color.YELLOW
	tween.tween_property(sprite, "color", GOBLIN_COLOR, 0.1)

	# Spawn arrow
	tween.tween_callback(_spawn_arrow)

	# Recoil
	tween.tween_property(visuals_pivot, "position:x", -8, 0.1)
	tween.tween_property(visuals_pivot, "position:x", 0, 0.2)

	tween.tween_callback(func():
		if is_instance_valid(self):
			is_shooting = false
	)

func _spawn_arrow():
	if is_dead or not arrow_scene or not player_reference:
		return

	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)

	# Target with spread for fairness
	var target_pos = player_reference.global_position
	target_pos.x += randf_range(-ARROW_SPREAD, ARROW_SPREAD)
	target_pos.y += randf_range(-ARROW_SPREAD, ARROW_SPREAD)

	arrow.initialize(global_position, target_pos)

func _on_shoot_timer_timeout():
	can_shoot = true

func _on_damage_taken():
	# Call base class flash (handles the bright white modulate flash)
	super._on_damage_taken()

func _play_hit_squash():
	# Quick squash effect preserving facing direction - SNAPPY timing
	var facing = sign(visuals_pivot.scale.x) if visuals_pivot.scale.x != 0 else 1.0
	visuals_pivot.scale = Vector2(HIT_SQUASH_SCALE.x * facing, HIT_SQUASH_SCALE.y)
	var scale_tween = TweenHelper.new_tween()
	scale_tween.tween_property(visuals_pivot, "scale", Vector2(facing, 1.0), HIT_SQUASH_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_death():
	set_physics_process(false)
	shoot_timer.stop()

	# Quick fall over - SNAPPY death
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "rotation", deg_to_rad(90), DEATH_FADE_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visuals_pivot, "scale", Vector2(0.8, 1.2), DEATH_FADE_DURATION)

	# Quick fade out
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_FADE_DURATION * 0.5)
	tween.parallel().tween_property(bow, "modulate:a", 0.0, DEATH_FADE_DURATION * 0.5)

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return Color("#8B4513")

func _get_death_particle_count() -> int:
	return 3
