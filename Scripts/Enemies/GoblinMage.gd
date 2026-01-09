# SCRIPT: GoblinMage.gd
# ATTACH TO: GoblinMage (CharacterBody2D) root node in GoblinMage.tscn
# LOCATION: res://Scripts/Enemies/GoblinMage.gd
# Ranged Hybrid enemy - casts fireballs from range, teleports away when player gets close

class_name GoblinMage
extends Enemy

# ============================================
# GOBLIN MAGE-SPECIFIC SETTINGS
# ============================================
@export var fireball_damage: float = 15.0
@export var fireball_speed: float = 350.0
@export var attack_range: float = 300.0
@export var attack_cooldown: float = 2.0
@export var teleport_cooldown: float = 5.0
@export var teleport_range: float = 150.0
@export var flee_distance: float = 120.0  # Distance to maintain from player
@export var unlocks_at_wave: int = 4

# Animation constants
const FLOAT_SPEED: float = 3.0
const FLOAT_RANGE: float = 8.0
const CAST_DURATION: float = 0.5

# ============================================
# NODES
# ============================================
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var body_sprite: ColorRect = $VisualsPivot/Body
@onready var hood_sprite: ColorRect = $VisualsPivot/Hood
@onready var staff_sprite: ColorRect = $VisualsPivot/Staff
@onready var orb_sprite: ColorRect = $VisualsPivot/Orb

# ============================================
# STATE
# ============================================
var attack_timer: float = 0.0
var teleport_timer: float = 0.0
var is_casting: bool = false
var time_alive: float = 0.0

# ============================================
# COLORS
# ============================================
const MAGE_BODY_COLOR = Color(0.3, 0.5, 0.3)    # Dark green robe
const MAGE_HOOD_COLOR = Color(0.25, 0.4, 0.25)  # Darker green hood
const MAGE_STAFF_COLOR = Color(0.5, 0.35, 0.2)  # Brown wood
const MAGE_ORB_COLOR = Color(1.0, 0.4, 0.1)     # Orange fire orb
const MAGE_SKIN_COLOR = Color(0.5, 0.7, 0.4)    # Goblin green skin
const FIREBALL_COLOR = Color(1.0, 0.5, 0.1)     # Orange fireball

func _setup_enemy():
	current_health = max_health
	attack_timer = attack_cooldown * 0.3
	teleport_timer = teleport_cooldown

	# Setup visual appearance
	_setup_visuals()

func _setup_visuals():
	# Body - robe shape
	body_sprite.color = MAGE_BODY_COLOR
	body_sprite.size = Vector2(35, 50)
	body_sprite.position = Vector2(-17, -50)

	# Hood
	hood_sprite.color = MAGE_HOOD_COLOR
	hood_sprite.size = Vector2(30, 25)
	hood_sprite.position = Vector2(-15, -80)

	# Staff
	staff_sprite.color = MAGE_STAFF_COLOR
	staff_sprite.size = Vector2(8, 70)
	staff_sprite.position = Vector2(20, -70)

	# Orb on staff
	orb_sprite.color = MAGE_ORB_COLOR
	orb_sprite.size = Vector2(14, 14)
	orb_sprite.position = Vector2(17, -85)

	# Add face
	_create_face()

func _create_face():
	# Face (goblin skin showing under hood)
	var face = ColorRect.new()
	face.name = "Face"
	face.color = MAGE_SKIN_COLOR
	face.size = Vector2(20, 18)
	face.position = Vector2(-10, -72)
	visuals_pivot.add_child(face)

	# Eyes (glowing)
	var left_eye = ColorRect.new()
	left_eye.color = Color(1.0, 0.8, 0.2)
	left_eye.size = Vector2(5, 5)
	left_eye.position = Vector2(-7, -68)
	visuals_pivot.add_child(left_eye)

	var right_eye = ColorRect.new()
	right_eye.color = Color(1.0, 0.8, 0.2)
	right_eye.size = Vector2(5, 5)
	right_eye.position = Vector2(2, -68)
	visuals_pivot.add_child(right_eye)

func _physics_process(delta):
	if is_dead:
		return

	time_alive += delta
	attack_timer -= delta
	teleport_timer -= delta

	# Floating animation
	if not is_casting:
		var float_offset = sin(time_alive * FLOAT_SPEED) * FLOAT_RANGE
		visuals_pivot.position.y = float_offset

		# Orb glow pulsing
		var orb_glow = 0.8 + sin(time_alive * 5) * 0.2
		orb_sprite.modulate = Color(orb_glow, orb_glow, orb_glow, 1.0)

	super._physics_process(delta)

func _update_movement(_delta):
	if knockback_velocity.length() > 0 or is_casting:
		return

	var target = get_best_target()
	if not target:
		velocity = Vector2.ZERO
		return

	var direction_to_target = (target.global_position - global_position).normalized()
	var distance_to_target = global_position.distance_to(target.global_position)

	# Update facing
	if direction_to_target.x < 0:
		visuals_pivot.scale.x = -1
	else:
		visuals_pivot.scale.x = 1

	# If player is too close, teleport away
	if distance_to_target < flee_distance and teleport_timer <= 0:
		_perform_teleport(target)
		return

	# If in attack range, stop and cast
	if distance_to_target <= attack_range and attack_timer <= 0:
		_cast_fireball(target)
		velocity = Vector2.ZERO
		return

	# Move to maintain optimal distance
	if distance_to_target > attack_range * 0.8:
		# Move closer
		velocity = direction_to_target * move_speed
	elif distance_to_target < flee_distance * 1.5:
		# Move away
		velocity = -direction_to_target * move_speed * 0.8
	else:
		# Strafe sideways
		var strafe_dir = direction_to_target.rotated(PI / 2)
		if fmod(time_alive, 4.0) > 2.0:
			strafe_dir = -strafe_dir
		velocity = strafe_dir * move_speed * 0.5

func _cast_fireball(target: Node2D):
	is_casting = true
	attack_timer = attack_cooldown
	velocity = Vector2.ZERO

	# Cast animation - raise staff
	var tween = TweenHelper.new_tween()
	tween.tween_property(staff_sprite, "rotation", deg_to_rad(-30), 0.2)
	tween.parallel().tween_property(orb_sprite, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(orb_sprite, "modulate", Color(2.0, 1.5, 1.0), 0.2)

	# Wait for cast time
	tween.tween_interval(0.2)

	# Fire!
	tween.tween_callback(func():
		_spawn_fireball(target)
	)

	# Return to normal
	tween.tween_property(staff_sprite, "rotation", 0, 0.15)
	tween.parallel().tween_property(orb_sprite, "scale", Vector2(1, 1), 0.15)
	tween.parallel().tween_property(orb_sprite, "modulate", Color.WHITE, 0.15)

	tween.tween_callback(func(): is_casting = false)

func _spawn_fireball(target: Node2D):
	if not target or not is_instance_valid(target):
		return

	var scene = get_tree().current_scene
	if not scene:
		return

	var direction = (target.global_position - global_position).normalized()
	var spawn_pos = global_position + direction * 40

	# Create fireball projectile
	var fireball = _create_fireball_node()
	scene.add_child(fireball)
	fireball.global_position = spawn_pos

	# Animate fireball
	var travel_time = attack_range * 1.5 / fireball_speed
	var end_pos = spawn_pos + direction * attack_range * 1.5

	var tween = TweenHelper.new_tween()
	tween.tween_property(fireball, "global_position", end_pos, travel_time)
	tween.tween_callback(fireball.queue_free)

	# Check for collision during flight
	_track_fireball_collision(fireball, direction)

func _create_fireball_node() -> Node2D:
	var fireball = Node2D.new()
	fireball.add_to_group("enemy_projectiles")

	# Core
	var core = ColorRect.new()
	core.size = Vector2(20, 20)
	core.pivot_offset = Vector2(10, 10)
	core.position = Vector2(-10, -10)
	core.color = Color(1.0, 0.9, 0.3)
	fireball.add_child(core)

	# Outer glow
	var glow = ColorRect.new()
	glow.size = Vector2(30, 30)
	glow.pivot_offset = Vector2(15, 15)
	glow.position = Vector2(-15, -15)
	glow.color = Color(FIREBALL_COLOR.r, FIREBALL_COLOR.g, FIREBALL_COLOR.b, 0.5)
	glow.z_index = -1
	fireball.add_child(glow)

	# Animate glow
	var tween = TweenHelper.new_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.1)

	return fireball

func _track_fireball_collision(fireball: Node2D, _direction: Vector2):
	# Create a timer to check collision
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.one_shot = false
	fireball.add_child(timer)

	var fireball_ref = weakref(fireball)
	var self_ref = weakref(self)

	timer.timeout.connect(func():
		var fb = fireball_ref.get_ref()
		var s = self_ref.get_ref()
		if not fb or not is_instance_valid(fb) or not s:
			if timer and is_instance_valid(timer):
				timer.stop()
			return

		# Check for player collision
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var dist = fb.global_position.distance_to(player.global_position)
			if dist < 30:
				# Hit!
				if player.has_method("take_damage"):
					player.take_damage(fireball_damage, fb.global_position)
				_create_fireball_explosion(fb.global_position)
				fb.queue_free()
				timer.stop()
	)
	timer.start()

func _create_fireball_explosion(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Explosion effect
	var explosion = ColorRect.new()
	explosion.size = Vector2(30, 30)
	explosion.pivot_offset = Vector2(15, 15)
	explosion.color = FIREBALL_COLOR
	scene.add_child(explosion)
	explosion.global_position = pos - Vector2(15, 15)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(3, 3), 0.2)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.2)
	tween.tween_callback(explosion.queue_free)

	# Sparks
	for i in range(6):
		var spark = ColorRect.new()
		spark.size = Vector2(8, 8)
		spark.color = Color(1.0, 0.8, 0.3)
		scene.add_child(spark)
		spark.global_position = pos

		var angle = randf() * TAU
		var end_pos = pos + Vector2.from_angle(angle) * randf_range(30, 60)

		var s_tween = TweenHelper.new_tween()
		s_tween.set_parallel(true)
		s_tween.tween_property(spark, "global_position", end_pos, 0.3)
		s_tween.tween_property(spark, "modulate:a", 0.0, 0.3)
		s_tween.tween_callback(spark.queue_free)

func _perform_teleport(target: Node2D):
	teleport_timer = teleport_cooldown

	# Teleport effect at start position
	_create_teleport_effect(global_position)

	# Calculate new position (away from player)
	var away_dir = (global_position - target.global_position).normalized()
	var new_pos = global_position + away_dir * teleport_range

	# Make sure new position is valid (within bounds)
	# Clamp to reasonable arena bounds
	new_pos.x = clamp(new_pos.x, -800, 800)
	new_pos.y = clamp(new_pos.y, -600, 600)

	# Flash out
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		global_position = new_pos
	)
	tween.tween_property(visuals_pivot, "modulate:a", 1.0, 0.1)
	tween.tween_callback(func():
		_create_teleport_effect(global_position)
	)

func _create_teleport_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Magic circle
	var circle = ColorRect.new()
	circle.size = Vector2(40, 40)
	circle.pivot_offset = Vector2(20, 20)
	circle.color = Color(0.5, 1.0, 0.5, 0.6)
	scene.add_child(circle)
	circle.global_position = pos - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(3, 3), 0.3)
	tween.tween_property(circle, "rotation", TAU, 0.3)
	tween.tween_property(circle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(circle.queue_free)

	# Sparkles
	for i in range(5):
		var sparkle = ColorRect.new()
		sparkle.size = Vector2(6, 6)
		sparkle.color = Color(0.8, 1.0, 0.8)
		scene.add_child(sparkle)
		sparkle.global_position = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))

		var s_tween = TweenHelper.new_tween()
		s_tween.set_parallel(true)
		s_tween.tween_property(sparkle, "global_position:y", sparkle.global_position.y - 40, 0.4)
		s_tween.tween_property(sparkle, "modulate:a", 0.0, 0.4)
		s_tween.tween_callback(sparkle.queue_free)

func _on_damage_taken():
	super._on_damage_taken()

func _play_hit_squash():
	visuals_pivot.scale.y = 0.85
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale:y", 1.0, 0.15).set_trans(Tween.TRANS_BACK)

func _on_death():
	set_physics_process(false)

	# Magical death - dissolve into particles
	var tween = TweenHelper.new_tween()
	tween.tween_property(visuals_pivot, "scale", Vector2(0.5, 1.5), 0.2)
	tween.parallel().tween_property(visuals_pivot, "modulate:a", 0.0, 0.3)

	# Staff falls
	tween.parallel().tween_property(staff_sprite, "rotation", deg_to_rad(90), 0.3)
	tween.parallel().tween_property(staff_sprite, "position:y", staff_sprite.position.y + 80, 0.3)

	# Orb explosion
	_create_fireball_explosion(global_position + Vector2(20, -70))

	tween.tween_callback(queue_free)

func _get_death_particle_color() -> Color:
	return MAGE_BODY_COLOR

func _get_death_particle_count() -> int:
	return 8
