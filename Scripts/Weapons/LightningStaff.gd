# SCRIPT: LightningStaff.gd
# ATTACH TO: LightningStaff (Node2D) root node in LightningStaff.tscn
# LOCATION: res://Scripts/Weapons/LightningStaff.gd

class_name LightningStaff
extends Node2D

# Staff stats
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 0.3
@export var projectile_spread: float = 5.0
@export var multi_shot: int = 1
@export var damage: float = 12.0

# Chain Lightning ability stats
@export var chain_lightning_duration: float = 3.0
@export var chain_lightning_cooldown: float = 8.0
@export var chain_range: float = 150.0
@export var chain_damage: float = 8.0
@export var max_chains: int = 3

# Nodes
@onready var sprite: ColorRect = $Sprite
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var cooldown_timer: Timer = $AttackCooldown
@onready var muzzle_flash: ColorRect = $MuzzleFlash
@onready var ability_timer: Timer = $AbilityTimer
@onready var ability_cooldown_timer: Timer = $AbilityCooldownTimer

# State
var can_attack: bool = true
var damage_multiplier: float = 1.0
var ability_active: bool = false
var can_use_ability: bool = true
var player: Node2D = null

# Signals
signal projectile_fired(projectile: Area2D)
signal attack_finished

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	ability_timer.timeout.connect(_on_ability_duration_finished)
	ability_cooldown_timer.timeout.connect(_on_ability_cooldown_finished)

	# Start with muzzle flash hidden
	muzzle_flash.modulate.a = 0.0

	# Load default projectile if not set
	if not projectile_scene:
		projectile_scene = preload("res://Scenes/Spells/BasicProjectile.tscn")

	# Get player reference
	await get_tree().process_frame
	player = get_parent().get_parent().get_parent()

func _process(_delta):
	# Check for ability activation (E key)
	if can_use_ability and not ability_active:
		if Input.is_action_just_pressed("staff_skill"):
			_activate_chain_lightning()

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
	# Muzzle flash - purple/blue for lightning
	muzzle_flash.modulate.a = 1.0
	var flash_tween = create_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)

	# Staff recoil
	var recoil_tween = create_tween()
	recoil_tween.tween_property(self, "position:x", -3, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)

	# Staff glow - electric blue
	sprite.color = Color("#66ccff")
	await get_tree().create_timer(0.1).timeout
	if not ability_active:
		sprite.color = Color("#4488ff")  # Back to normal blue

func _activate_chain_lightning():
	print("Activating Chain Lightning ability!")
	ability_active = true
	can_use_ability = false

	# Visual feedback
	sprite.color = Color("#ffff00")  # Bright yellow during ability

	# Start ability duration timer
	ability_timer.start(chain_lightning_duration)

	# Start zapping enemies
	_chain_lightning_loop()

func _chain_lightning_loop():
	while ability_active:
		_perform_chain_lightning()
		await get_tree().create_timer(0.3).timeout  # Zap every 0.3 seconds

func _perform_chain_lightning():
	if not player:
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# Find closest enemy within range
	var closest_enemy = null
	var closest_distance = chain_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = player.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	if not closest_enemy:
		return

	# Start chain from player to first enemy
	var chain_targets = [closest_enemy]
	var current_target = closest_enemy

	# Find additional chain targets
	for i in range(max_chains - 1):
		var next_target = _find_next_chain_target(current_target, chain_targets)
		if next_target:
			chain_targets.append(next_target)
			current_target = next_target
		else:
			break

	# Damage all targets in chain
	for target in chain_targets:
		if is_instance_valid(target) and target.has_method("take_damage"):
			var final_damage = chain_damage * damage_multiplier
			target.take_damage(final_damage)

	# Visual effect - draw lightning between targets
	_draw_lightning_chain(chain_targets)

func _find_next_chain_target(from_enemy: Node2D, exclude_list: Array) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = chain_range

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in exclude_list:
			continue

		var distance = from_enemy.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy

func _draw_lightning_chain(targets: Array):
	if targets.is_empty() or not player:
		return

	# Create lightning bolt from player to first target
	_create_lightning_bolt(player.global_position, targets[0].global_position)

	# Create lightning bolts between subsequent targets
	for i in range(targets.size() - 1):
		if is_instance_valid(targets[i]) and is_instance_valid(targets[i + 1]):
			_create_lightning_bolt(targets[i].global_position, targets[i + 1].global_position)

func _create_lightning_bolt(from: Vector2, to: Vector2):
	var bolt = Line2D.new()
	get_tree().root.add_child(bolt)

	# Lightning color - bright cyan/white
	bolt.default_color = Color("#00ffff")
	bolt.width = 2.0

	# Create jagged lightning effect
	var segments = 5
	var points = PackedVector2Array()
	points.append(from)

	for i in range(1, segments):
		var t = float(i) / float(segments)
		var point = from.lerp(to, t)
		# Add random offset perpendicular to direction
		var direction = (to - from).normalized()
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = perpendicular * randf_range(-10, 10)
		points.append(point + offset)

	points.append(to)
	bolt.points = points

	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.2)
	tween.tween_callback(bolt.queue_free)

func _on_ability_duration_finished():
	ability_active = false
	sprite.color = Color("#4488ff")  # Back to normal blue

	# Start cooldown
	ability_cooldown_timer.start(chain_lightning_cooldown)
	print("Chain Lightning ended. Cooldown: ", chain_lightning_cooldown, "s")

func _on_ability_cooldown_finished():
	can_use_ability = true
	print("Chain Lightning ready!")

func _on_cooldown_finished():
	can_attack = true
