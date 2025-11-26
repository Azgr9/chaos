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

# Signals
signal projectile_fired(projectile: Area2D)

func _ready():
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	
	# Start with muzzle flash hidden
	muzzle_flash.modulate.a = 0.0
	
	# Load default projectile if not set
	if not projectile_scene:
		projectile_scene = preload("res://scenes/spells/BasicProjectile.tscn")

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
		
		emit_signal("projectile_fired", projectile)

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
