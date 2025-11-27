# SCRIPT: BasicStaff.gd
# ATTACH TO: BasicStaff (Node2D) root node in BasicStaff.tscn
# LOCATION: res://scripts/weapons/BasicStaff.gd

class_name BasicStaff
extends Node2D

# Staff stats
@export var projectile_scene: PackedScene
@export var mana_cost: float = 5.0
@export var attack_cooldown: float = 0.3
@export var projectile_spread: float = 5.0  # Degrees of random spread
@export var multi_shot: int = 1  # Number of projectiles per shot

# Nodes
@onready var sprite: ColorRect = $Sprite
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var cooldown_timer: Timer = $AttackCooldown
@onready var muzzle_flash: ColorRect = $MuzzleFlash

# State
var can_attack: bool = true
var damage_multiplier: float = 1.0

# Skill system
var skill_cooldown: float = 12.0  # 12 seconds cooldown
var skill_ready: bool = true
var skill_timer: float = 0.0
var skill_active: bool = false
var skill_duration: float = 5.0  # 5 seconds boost
var skill_duration_timer: float = 0.0
var base_attack_cooldown: float = 0.3

# Signals
signal projectile_fired(projectile: Area2D)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	base_attack_cooldown = attack_cooldown

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

	# Update skill duration
	if skill_active:
		skill_duration_timer -= delta
		if skill_duration_timer <= 0:
			_deactivate_skill()

func use_skill() -> bool:
	if not skill_ready:
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	# Activate attack speed boost
	_activate_skill()

	return true

func _activate_skill():
	skill_active = true
	skill_duration_timer = skill_duration

	# Drastically increase attack speed (10x faster)
	attack_cooldown = base_attack_cooldown * 0.1
	cooldown_timer.wait_time = attack_cooldown

	# Visual feedback - glow effect
	sprite.color = Color.CYAN
	var glow_tween = create_tween()
	glow_tween.set_loops()
	glow_tween.tween_property(sprite, "modulate:v", 1.5, 0.3)
	glow_tween.tween_property(sprite, "modulate:v", 1.0, 0.3)

func _deactivate_skill():
	skill_active = false

	# Reset attack speed
	attack_cooldown = base_attack_cooldown
	cooldown_timer.wait_time = attack_cooldown

	# Reset visual
	sprite.color = Color(0.8, 0.6, 1.0)  # Purple
	sprite.modulate = Color.WHITE

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
	recoil_tween.tween_property(self, "position:x", -3, 0.05)
	recoil_tween.tween_property(self, "position:x", 0, 0.1)
	
	# Staff glow
	sprite.color = Color("#cd853f")  # Lighter brown
	await get_tree().create_timer(0.1).timeout
	sprite.color = Color("#8b4513")  # Back to normal

func _on_cooldown_finished():
	can_attack = true
