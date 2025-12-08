# SCRIPT: BasicStaff.gd
# ATTACH TO: BasicStaff (Node2D) root node in BasicStaff.tscn
# LOCATION: res://scripts/weapons/BasicStaff.gd

class_name BasicStaff
extends Node2D

# Staff stats
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 0.3
@export var projectile_spread: float = 5.0  # Degrees of random spread
@export var multi_shot: int = 1  # Number of projectiles per shot

# Beam skill stats
@export var beam_damage: float = 50.0  # Base damage for beam
@export var beam_range: float = 800.0  # How far the beam reaches
@export var beam_width: float = 32.0  # Width of the beam hitbox

# Nodes
@onready var sprite: ColorRect = $Sprite
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var cooldown_timer: Timer = $AttackCooldown
@onready var muzzle_flash: ColorRect = $MuzzleFlash

# State
var can_attack: bool = true
var damage_multiplier: float = 1.0

# Skill system
var skill_cooldown: float = 10.0  # 10 seconds cooldown for beam
var skill_ready: bool = true
var skill_timer: float = 0.0

# Signals
signal projectile_fired(projectile: Area2D)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)

	# Start with muzzle flash hidden
	muzzle_flash.modulate.a = 0.0

	# Load default projectile if not set
	if not projectile_scene:
		projectile_scene = preload("res://scenes/spells/BasicProjectile.tscn")

func _process(delta):
	# Update skill cooldown
	if not skill_ready:
		skill_timer -= delta
		if skill_timer <= 0:
			skill_ready = true
			skill_ready_changed.emit(true)

func use_skill() -> bool:
	if not skill_ready:
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	# Fire the beam toward mouse position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var mouse_pos = player.get_global_mouse_position()
		var direction = (mouse_pos - player.global_position).normalized()
		_fire_beam(player.global_position, direction, player.stats.magic_damage_multiplier)

	return true

func _fire_beam(origin: Vector2, direction: Vector2, magic_multiplier: float):
	# Calculate beam endpoint
	var beam_end = origin + direction * beam_range

	# Create beam visual
	var beam_visual = _create_beam_visual(origin, direction)

	# Deal damage to all enemies in the beam path
	var final_damage = beam_damage * magic_multiplier
	_damage_enemies_in_beam(origin, direction, final_damage)

	# Screen shake
	var camera = get_tree().get_first_node_in_group("player")
	if camera and camera.has_node("Camera2D"):
		var cam = camera.get_node("Camera2D")
		if cam.has_method("add_trauma"):
			cam.add_trauma(0.4)

	# Play beam animation then clean up
	await _animate_beam(beam_visual)

func _create_beam_visual(origin: Vector2, direction: Vector2) -> Node2D:
	# Create container for beam
	var beam_container = Node2D.new()
	beam_container.global_position = origin
	beam_container.rotation = direction.angle()
	get_tree().root.add_child(beam_container)

	# Main beam (bright core)
	var beam_core = ColorRect.new()
	beam_core.color = Color(1.0, 1.0, 0.8, 1.0)  # Bright yellow-white
	beam_core.size = Vector2(beam_range, beam_width * 0.4)
	beam_core.position = Vector2(0, -beam_width * 0.2)
	beam_container.add_child(beam_core)

	# Outer glow
	var beam_glow = ColorRect.new()
	beam_glow.color = Color(0.4, 0.8, 1.0, 0.6)  # Cyan glow
	beam_glow.size = Vector2(beam_range, beam_width)
	beam_glow.position = Vector2(0, -beam_width * 0.5)
	beam_container.add_child(beam_glow)
	beam_glow.z_index = -1

	# Edge highlights
	var edge_top = ColorRect.new()
	edge_top.color = Color(1.0, 1.0, 1.0, 0.8)
	edge_top.size = Vector2(beam_range, 4)
	edge_top.position = Vector2(0, -beam_width * 0.5)
	beam_container.add_child(edge_top)

	var edge_bottom = ColorRect.new()
	edge_bottom.color = Color(1.0, 1.0, 1.0, 0.8)
	edge_bottom.size = Vector2(beam_range, 4)
	edge_bottom.position = Vector2(0, beam_width * 0.5 - 4)
	beam_container.add_child(edge_bottom)

	# Impact flash at origin
	var origin_flash = ColorRect.new()
	origin_flash.color = Color(1.0, 1.0, 1.0, 1.0)
	origin_flash.size = Vector2(64, 64)
	origin_flash.position = Vector2(-32, -32)
	origin_flash.pivot_offset = Vector2(32, 32)
	beam_container.add_child(origin_flash)

	return beam_container

func _animate_beam(beam_visual: Node2D):
	# Quick flash in
	beam_visual.modulate = Color(1, 1, 1, 0)
	beam_visual.scale = Vector2(1, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)

	# Flash in (0.05s)
	tween.tween_property(beam_visual, "modulate:a", 1.0, 0.05)
	tween.tween_property(beam_visual, "scale:y", 1.2, 0.05)

	await tween.finished

	# Hold briefly (0.15s)
	await get_tree().create_timer(0.15).timeout

	# Fade out (0.3s)
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(beam_visual, "modulate:a", 0.0, 0.3)
	fade_tween.tween_property(beam_visual, "scale:y", 0.1, 0.3)

	await fade_tween.finished
	beam_visual.queue_free()

func _damage_enemies_in_beam(origin: Vector2, direction: Vector2, damage: float):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var hit_enemies: Array = []

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Check if enemy is within beam rectangle
		var to_enemy = enemy.global_position - origin
		var distance_along_beam = to_enemy.dot(direction)

		# Skip if behind origin or beyond range
		if distance_along_beam < 0 or distance_along_beam > beam_range:
			continue

		# Calculate perpendicular distance from beam center line
		var perpendicular = to_enemy - direction * distance_along_beam
		var perpendicular_distance = perpendicular.length()

		# Check if within beam width (plus some enemy hitbox tolerance)
		if perpendicular_distance <= beam_width * 0.5 + 16:
			hit_enemies.append(enemy)

	# Apply damage to all hit enemies
	for enemy in hit_enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
			_create_hit_effect(enemy.global_position)

	print("[BasicStaff] Beam hit %d enemies for %.1f damage each" % [hit_enemies.size(), damage])

func _create_hit_effect(pos: Vector2):
	# Small flash at hit location
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 0.8, 1)
	flash.size = Vector2(32, 32)
	flash.global_position = pos - Vector2(16, 16)
	flash.pivot_offset = Vector2(16, 16)
	get_tree().root.add_child(flash)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(flash.queue_free)

func get_skill_cooldown_percent() -> float:
	if skill_ready:
		return 1.0
	return 1.0 - (skill_timer / skill_cooldown)

func attack(direction: Vector2, magic_damage_multiplier: float = 1.0) -> bool:
	if not can_attack:
		return false

	damage_multiplier = magic_damage_multiplier

	# Fire projectile(s)
	_fire_projectiles(direction)
	
	# Visual effects
	_play_attack_animation()
	
	# Start cooldown
	can_attack = false
	cooldown_timer.start(attack_cooldown)
	
	return true

func _fire_projectiles(direction: Vector2):
	for i in range(multi_shot):
		if not projectile_scene:
			continue
			
		# Create projectile instance
		var projectile = projectile_scene.instantiate()
		
		# Add to scene tree (at world level to avoid rotation issues)
		get_tree().root.add_child(projectile)
		
		# Calculate spread for multiple projectiles
		var spread_angle = 0.0
		if multi_shot > 1:
			var spread_step = deg_to_rad(projectile_spread * 2) / (multi_shot - 1)
			spread_angle = -deg_to_rad(projectile_spread) + (spread_step * i)
		else:
			# Single shot can still have random spread
			spread_angle = randf_range(-deg_to_rad(projectile_spread), deg_to_rad(projectile_spread))
		
		# Apply spread to direction
		var final_direction = direction.rotated(spread_angle)
		
		# Initialize projectile
		projectile.initialize(
			projectile_spawn.global_position,
			final_direction,
			damage_multiplier
		)

		projectile_fired.emit(projectile)

func _play_attack_animation():
	# Muzzle flash
	muzzle_flash.modulate.a = 1.0
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
	
	# Staff recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -12, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)
	
	# Staff glow
	sprite.color = Color("#cd853f")  # Lighter brown
	await get_tree().create_timer(0.1).timeout
	sprite.color = Color("#8b4513")  # Back to normal

func _on_cooldown_finished():
	can_attack = true
