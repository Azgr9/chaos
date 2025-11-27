# SCRIPT: Katana.gd
# ATTACH TO: Katana (Node2D) root node in Katana.tscn
# LOCATION: res://Scripts/Weapons/Katana.gd

class_name Katana
extends Node2D

# Weapon stats
@export var damage: float = 12.0  # Slightly higher than basic sword
@export var attack_duration: float = 0.2  # Faster attacks
@export var attack_cooldown: float = 0.3

# Nodes
@onready var pivot: Node2D = $Pivot
@onready var sprite: ColorRect = $Pivot/Sprite
@onready var hit_box: Area2D = $Pivot/HitBox
@onready var hit_box_collision: CollisionShape2D = $Pivot/HitBox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

# State
var is_attacking: bool = false
var can_attack: bool = true
var damage_multiplier: float = 1.0
var hits_this_swing: Array = []

# Skill system - Dash Slash
var skill_cooldown: float = 6.0  # 6 seconds cooldown
var skill_ready: bool = true
var skill_timer: float = 0.0
var is_dash_slashing: bool = false

# Signals
signal attack_finished
signal dealt_damage(target: Node2D, damage: float)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

func _ready():
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	# Start with hitbox disabled
	hit_box_collision.disabled = true

	# Visual setup - Red katana
	sprite.color = Color(0.9, 0.2, 0.2)  # Red

	# Start hidden
	visible = false
	modulate.a = 0.0

func _process(delta):
	# Update skill cooldown
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

	# Perform dash slash
	_perform_dash_slash()

	return true

func _perform_dash_slash():
	# Get player and dash forward
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	is_dash_slashing = true
	visible = true
	hits_this_swing.clear()

	# Make player invulnerable during dash
	if player.has_method("set_invulnerable"):
		player.set_invulnerable(true)

	# Dash direction towards mouse
	var mouse_pos = get_global_mouse_position()
	var dash_direction = (mouse_pos - player.global_position).normalized()
	var dash_distance = 80.0

	# Position katana visually
	pivot.position = Vector2.ZERO
	pivot.rotation = dash_direction.angle()

	# Create afterimage trail
	_create_dash_trail(player)

	# Create a damage area that follows the player
	_create_dash_damage_area(player, dash_direction, dash_distance)

	# Move player forward quickly
	var start_pos = player.global_position
	var end_pos = start_pos + dash_direction * dash_distance

	var tween = create_tween()
	tween.set_parallel(true)

	# Dash movement
	tween.tween_property(player, "global_position", end_pos, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Katana flash
	modulate.a = 1.0
	sprite.color = Color.WHITE
	tween.tween_property(sprite, "color", Color(0.9, 0.2, 0.2), 0.3)

	# Cleanup
	tween.tween_callback(func():
		visible = false
		modulate.a = 0.0
		is_dash_slashing = false
		pivot.rotation = 0
		pivot.position = Vector2.ZERO
		# Remove invulnerability
		if player.has_method("set_invulnerable"):
			player.set_invulnerable(false)
	)

func _create_dash_damage_area(player: Node2D, direction: Vector2, distance: float):
	# Manually check for enemies during dash and damage them
	var dash_time = 0.15
	var checks = 5
	var hit_enemies = []

	for i in range(checks):
		await get_tree().create_timer(dash_time / checks).timeout

		# Get all enemies in the game
		var enemies = get_tree().get_nodes_in_group("enemies")

		for enemy in enemies:
			# Check distance to player (within dash radius)
			if enemy.global_position.distance_to(player.global_position) < 30.0:
				# Don't hit same enemy multiple times in one check
				if enemy in hit_enemies:
					continue

				hit_enemies.append(enemy)

				# Deal damage
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

	_perform_quick_slash()

	return true

func _perform_quick_slash():
	# Fast horizontal slash
	visible = true

	var tween = create_tween()
	tween.set_parallel(true)

	# Fade in quickly
	tween.tween_property(self, "modulate:a", 1.0, 0.05)

	# Starting position
	pivot.rotation = deg_to_rad(-90)
	pivot.position = Vector2(-10, 0)

	tween.set_parallel(false)

	# Enable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = false)

	# Lightning fast slash
	sprite.scale = Vector2(1.6, 0.6)
	tween.tween_property(pivot, "rotation", deg_to_rad(90), attack_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, attack_duration)

	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)

	# Quick fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.1)

	tween.tween_callback(finish_attack)

	attack_timer.start(attack_cooldown)

func finish_attack():
	hit_box_collision.disabled = true
	is_attacking = false
	visible = false
	pivot.rotation = 0
	pivot.position = Vector2.ZERO
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
		# Bonus damage during dash slash
		if is_dash_slashing:
			final_damage *= 1.5
			print("Debug: Katana dash hit enemy for ", final_damage, " damage")
		parent.take_damage(final_damage)
		dealt_damage.emit(parent, final_damage)

		# Visual feedback
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
	# Red slash effect
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
