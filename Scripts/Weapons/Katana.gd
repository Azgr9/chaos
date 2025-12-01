# SCRIPT: Katana.gd
class_name Katana
extends Node2D

@export var damage: float = 12.0
@export var attack_duration: float = 0.2
@export var attack_cooldown: float = 0.3

@onready var pivot: Node2D = $Pivot
@onready var sprite: ColorRect = $Pivot/Sprite
@onready var hit_box: Area2D = $Pivot/HitBox
@onready var hit_box_collision: CollisionShape2D = $Pivot/HitBox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

var is_attacking: bool = false
var can_attack: bool = true
var damage_multiplier: float = 1.0
var hits_this_swing: Array = []
var active_attack_tween: Tween = null  # Track active tween to kill it if needed

# Combo system
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 2.0  # Reset combo after 2 seconds
const COMBO_FINISHER_MULTIPLIER: float = 1.5

var skill_cooldown: float = 6.0
var skill_ready: bool = true
var skill_timer: float = 0.0
var is_dash_slashing: bool = false

signal attack_finished
signal dealt_damage(target: Node2D, damage: float)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

func _ready():
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	hit_box_collision.disabled = true
	sprite.color = Color(0.9, 0.2, 0.2)  # Red katana

	# Start visible and always show (like staff)
	visible = true
	modulate.a = 1.0

	# Default idle position - katana held in hand
	# Only set Y position, X is controlled by WeaponPivot in Player
	pivot.position = Vector2.ZERO  # Down slightly
	pivot.rotation = deg_to_rad(45)  # Angled down
	sprite.scale = Vector2(0.6, 0.6)  # Smaller when idle

func _process(delta):
	# Update combo timer
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0  # Reset combo

	if not skill_ready:
		skill_timer -= delta
		if skill_timer <= 0:
			skill_ready = true
			skill_ready_changed.emit(true)

func use_skill() -> bool:
	if not skill_ready or is_attacking:
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	_perform_dash_slash()

	return true

func _perform_dash_slash():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	is_dash_slashing = true

	var dash_distance = 150.0
	var dash_time = 0.15

	# ⭐ DASH TOWARD MOUSE ⭐
	var direction = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT  # fallback so we don't get a zero-length dash

	var desired_position = player.global_position + direction * dash_distance

	# -----------------------------
	# WALL-SAFE DASH (IGNORE PLAYER + ENEMIES)
	# -----------------------------
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		desired_position
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	# Don't hit the player or enemies with this ray
	var exclude: Array = [player]
	exclude.append_array(get_tree().get_nodes_in_group("enemies"))
	query.exclude = exclude

	# If you want to restrict to a specific wall layer, you can optionally set:
	# query.collision_mask = WALL_LAYER_MASK
	# where WALL_LAYER_MASK is the bitmask for your wall/tiles layer.

	var result = space_state.intersect_ray(query)

	var target_position = desired_position

	if result:
		# Hit a wall (or other blocking body) → stop a bit before it
		target_position = result.position - direction * 4.0
	# -----------------------------

	# --- INVULNERABILITY START ---
	if player.has_method("set_invulnerable"):
		player.set_invulnerable(true)

	var tween = create_tween()
	tween.tween_property(player, "global_position", target_position, dash_time)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(false)
		is_dash_slashing = false
	)

	_create_slash_effect(player.global_position)
	_create_dash_damage_area(player, direction, dash_distance)

func _create_dash_damage_area(player: Node2D, _direction: Vector2, _distance: float):
	var dash_time = 0.15
	var checks = 5
	var hit_enemies = []

	for i in range(checks):
		await get_tree().create_timer(dash_time / checks).timeout

		var enemies = get_tree().get_nodes_in_group("enemies")

		for enemy in enemies:
			if enemy.global_position.distance_to(player.global_position) < 30.0:
				if enemy in hit_enemies:
					continue

				hit_enemies.append(enemy)

				var final_damage = damage * damage_multiplier * 1.5
				print("Debug: Katana dash hit ", enemy.name, " for ", final_damage, " damage")

				if enemy.has_method("take_damage"):
					enemy.take_damage(final_damage)
					dealt_damage.emit(enemy, final_damage)
					_create_slash_effect(enemy.global_position)

func _create_dash_trail(player: Node2D):
	for i in range(5):
		await get_tree().create_timer(0.03).timeout

		var ghost = ColorRect.new()
		ghost.size = Vector2(10, 10)
		ghost.color = Color(0.9, 0.2, 0.2, 0.5)
		get_tree().current_scene.add_child(ghost)
		ghost.global_position = player.global_position

		var tween = create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
		tween.tween_callback(ghost.queue_free)

func get_skill_cooldown_percent() -> float:
	if skill_ready:
		return 1.0
	return 1.0 - (skill_timer / skill_cooldown)

func attack(_direction: Vector2, player_damage_multiplier: float = 1.0):
	if not can_attack or is_attacking or is_dash_slashing:
		return false

	damage_multiplier = player_damage_multiplier
	is_attacking = true
	can_attack = false
	hits_this_swing.clear()

	# Increment combo
	combo_count += 1
	combo_timer = COMBO_WINDOW

	# Perform attack based on combo count (3-hit combo cycle)
	# Attack 1: Right to left slash
	# Attack 2: Left to right slash (reversed)
	# Attack 3: Forward stab (combo finisher)
	var attack_in_combo = ((combo_count - 1) % 3) + 1

	match attack_in_combo:
		1:  # First attack - Right to left slash
			_perform_quick_slash(false)
		2:  # Second attack - Left to right slash (reversed)
			_perform_quick_slash(true)
		3:  # Third attack - Forward stab (combo finisher)
			_perform_stab()
		_:
			_perform_quick_slash(false)

	return true

func _perform_quick_slash(reverse: bool = false):
	# Kill any existing tween before creating a new one
	if active_attack_tween:
		active_attack_tween.kill()

	# Check if this is combo finisher
	var attack_in_combo = ((combo_count - 1) % 3) + 1
	var is_combo_finisher = (attack_in_combo == 3)

	if is_combo_finisher:
		sprite.color = Color.GOLD

	active_attack_tween = create_tween()
	active_attack_tween.set_parallel(true)

	# Scale up from idle size
	active_attack_tween.tween_property(sprite, "scale", Vector2(1.6, 0.6), 0.05)

	# Set start and end angles based on direction
	var start_angle: float
	var end_angle: float

	if reverse:  # Left to right slash
		start_angle = 90
		end_angle = -90
	else:  # Right to left slash
		start_angle = -90
		end_angle = 90

	pivot.rotation = deg_to_rad(start_angle)
	pivot.position = Vector2(-10, 0)

	active_attack_tween.set_parallel(false)

	active_attack_tween.tween_callback(func(): hit_box_collision.set_deferred("disabled", false))

	active_attack_tween.tween_property(pivot, "rotation", deg_to_rad(end_angle), attack_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	active_attack_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, attack_duration)

	active_attack_tween.tween_callback(func(): hit_box_collision.set_deferred("disabled", true))

	# Return to idle position
	active_attack_tween.tween_property(pivot, "position", Vector2(0, 8), 0.1)
	active_attack_tween.parallel().tween_property(pivot, "rotation", deg_to_rad(45), 0.1)
	active_attack_tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.1)

	active_attack_tween.tween_callback(finish_attack)

	attack_timer.start(attack_cooldown)

func _perform_stab():
	# Kill any existing tween before creating a new one
	if active_attack_tween:
		active_attack_tween.kill()

	# Combo finisher - Gold color
	var attack_in_combo = ((combo_count - 1) % 3) + 1
	var is_combo_finisher = (attack_in_combo == 3)

	if is_combo_finisher:
		sprite.color = Color.GOLD

	active_attack_tween = create_tween()
	active_attack_tween.set_parallel(true)

	# Scale up for impact
	active_attack_tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.05)

	# Starting position - pulled back
	pivot.rotation = 0
	pivot.position = Vector2(-15, 0)

	active_attack_tween.set_parallel(false)

	# Pull back more (anticipation)
	active_attack_tween.tween_property(pivot, "position", Vector2(-20, 0), attack_duration * 0.3)

	# Enable hitbox
	active_attack_tween.tween_callback(func(): hit_box_collision.set_deferred("disabled", false))

	# Thrust forward
	active_attack_tween.tween_property(pivot, "position", Vector2(15, 0), attack_duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Stretch on impact
	active_attack_tween.parallel().tween_property(sprite, "scale:x", 1.8, attack_duration * 0.2)
	active_attack_tween.tween_property(sprite, "scale:x", 1.0, attack_duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pull back
	active_attack_tween.tween_property(pivot, "position", Vector2(0, 0), attack_duration * 0.3)

	# Disable hitbox
	active_attack_tween.tween_callback(func(): hit_box_collision.set_deferred("disabled", true))

	# Return to idle position
	active_attack_tween.tween_property(pivot, "position", Vector2.ZERO, 0.1)
	active_attack_tween.parallel().tween_property(pivot, "rotation", deg_to_rad(45), 0.1)
	active_attack_tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.1)

	active_attack_tween.tween_callback(finish_attack)

	attack_timer.start(attack_cooldown)

func finish_attack():
	# CRITICAL: Kill active tween to prevent stuck animations
	if active_attack_tween:
		active_attack_tween.kill()
		active_attack_tween = null

	# Use set_deferred to avoid "flushing queries" error
	hit_box_collision.set_deferred("disabled", true)
	is_attacking = false
	# Keep katana visible at all times
	pivot.rotation = deg_to_rad(45)  # Idle angle
	pivot.position = Vector2.ZERO  # Idle position
	sprite.scale = Vector2(0.6, 0.6)  # Idle size
	sprite.color = Color(0.9, 0.2, 0.2)  # Reset to red katana color
	attack_finished.emit()

func _on_attack_cooldown_finished():
	can_attack = true

func _on_hit_box_area_entered(area: Area2D):
	var parent = area.get_parent()

	if parent in hits_this_swing:
		return

	if parent.has_method("take_damage"):
		hits_this_swing.append(parent)
		var final_damage = damage * damage_multiplier

		# Apply combo finisher bonus (every 3rd hit)
		var attack_in_combo = ((combo_count - 1) % 3) + 1
		var is_combo_finisher = (attack_in_combo == 3)
		if is_combo_finisher:
			final_damage *= COMBO_FINISHER_MULTIPLIER
			print("KATANA COMBO FINISHER! x%.1f damage" % COMBO_FINISHER_MULTIPLIER)

		if is_dash_slashing:
			final_damage *= 1.5
		parent.take_damage(final_damage)
		dealt_damage.emit(parent, final_damage)
		_create_slash_effect(parent.global_position)

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_swing:
		return

	if body.has_method("take_damage"):
		hits_this_swing.append(body)
		var final_damage = damage * damage_multiplier
		if is_dash_slashing:
			final_damage *= 1.5
		body.take_damage(final_damage)
		dealt_damage.emit(body, final_damage)
		_create_slash_effect(body.global_position)

func _create_slash_effect(hit_position: Vector2):
	for i in range(3):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 2)
		particle.color = Color(1.0, 0.3, 0.3, 1.0)
		get_tree().current_scene.add_child(particle)
		particle.global_position = hit_position

		var angle = randf_range(-PI, PI)
		var direction = Vector2.from_angle(angle)
		var distance = randf_range(10, 20)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position",
			hit_position + direction * distance, 0.2)
		tween.tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)
