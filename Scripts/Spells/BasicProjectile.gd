# SCRIPT: BasicProjectile.gd
# ATTACH TO: BasicProjectile (Area2D) root node in BasicProjectile.tscn
# LOCATION: res://scripts/spells/BasicProjectile.gd

class_name BasicProjectile
extends Area2D

# Projectile stats
@export var speed: float = 1000.0
@export var damage: float = 5.0
@export var pierce_count: int = 0  # How many enemies it can pass through
@export var knockback_power: float = 400.0
@export var hitstun_duration: float = 0.1
@export var damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL

# Nodes
@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer

# State
var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var damage_multiplier: float = 1.0
var hits_count: int = 0
var hit_enemies: Array = []
var shooter: Node2D = null  # Reference to who fired the projectile (for thorns)

# Signals
signal projectile_hit(target: Node2D, damage: float)

func _ready():
	# Pause when game pauses (don't keep flying during upgrade menu)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Add to projectiles group for cleanup
	add_to_group("projectiles")

	# Connect collision signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

	# Visual setup
	_create_spawn_effect()

func initialize(start_position: Vector2, dir: Vector2, magic_damage_multiplier: float = 1.0, kb_power: float = 400.0, stun_dur: float = 0.1, attacker: Node2D = null, dmg_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL):
	global_position = start_position
	direction = dir.normalized()
	velocity = direction * speed
	damage_multiplier = magic_damage_multiplier
	knockback_power = kb_power
	hitstun_duration = stun_dur
	shooter = attacker
	damage_type = dmg_type

	# Rotate projectile to face direction
	rotation = direction.angle()

func _physics_process(delta):
	# Move the projectile
	position += velocity * delta
	
	# Optional: Add wobble or spiral movement
	_update_visual_effect()

func _update_visual_effect():
	# Gentle pulse effect
	var pulse = abs(sin(Time.get_ticks_msec() * 0.02)) * 0.2 + 0.9
	sprite.scale = Vector2(pulse, pulse)

func _create_spawn_effect():
	# Quick flash on spawn
	sprite.scale = Vector2(1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	
	# Check if it's an enemy hurtbox
	if not parent in hit_enemies and parent.has_method("take_damage"):
		hit_enemies.append(parent)

		# Deal damage with knockback position (pass shooter for thorns reflection)
		var final_damage = damage * damage_multiplier
		parent.take_damage(final_damage, global_position, knockback_power, hitstun_duration, shooter, damage_type)
		projectile_hit.emit(parent, final_damage)

		# Visual feedback
		_create_hit_effect()

		# Check pierce
		hits_count += 1
		if hits_count > pierce_count:
			_destroy_projectile()

func _on_body_entered(body: Node2D):
	# Hit a wall
	if body.collision_layer & 4:  # Check if it's on walls layer
		_create_wall_hit_effect()
		_destroy_projectile()

func _on_lifetime_timeout():
	_destroy_projectile()

func _create_hit_effect():
	# Flash white on hit
	sprite.color = Color.WHITE
	var tween = create_tween()
	tween.tween_property(sprite, "color", Color("#00ffff"), 0.1)

func _create_wall_hit_effect():
	# Scale down quickly
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.1)

func _destroy_projectile():
	# Cleanup effect
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
