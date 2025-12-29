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

# Pool state
var _is_pooled: bool = false
var _pool_name: String = "projectile_basic"
var _original_color: Color = Color.WHITE

# Signals
signal projectile_hit(target: Node2D, damage: float)

func _ready():
	# Pause when game pauses (don't keep flying during upgrade menu)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Add to projectiles group for cleanup
	add_to_group("projectiles")

	# Setup collision mask - ensure we can hit portal (layer 4) and enemies (layer 16)
	# Mask 24 = 8 (walls) + 16 (enemies) OR use 28 = 4 + 8 + 16 to include portal
	collision_mask = 28  # 4 (portal) + 8 (walls) + 16 (enemies)

	# Connect collision signals (only if not already connected)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timeout)

	# Store original color for pooling reset
	if sprite:
		_original_color = sprite.color

	# Visual setup
	_create_spawn_effect()

# ============================================
# POOL INTERFACE
# ============================================
func on_pool_acquire():
	"""Called when acquired from pool"""
	_is_pooled = true
	_reset_state()
	visible = true
	set_process(true)
	set_physics_process(true)
	collision.disabled = false

func on_pool_release():
	"""Called when returned to pool"""
	_reset_state()
	visible = false
	set_process(false)
	set_physics_process(false)
	collision.disabled = true
	lifetime_timer.stop()

func _reset_state():
	"""Reset all state for reuse"""
	velocity = Vector2.ZERO
	direction = Vector2.ZERO
	damage_multiplier = 1.0
	hits_count = 0
	hit_enemies.clear()
	shooter = null
	damage_type = DamageTypes.Type.PHYSICAL
	modulate = Color.WHITE
	rotation = 0.0
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.color = _original_color

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
	# Check if the area itself has take_damage (like Portal)
	var target = area if area.has_method("take_damage") else area.get_parent()

	# Skip converted minions (NecroStaff allies)
	if target.is_in_group("converted_minion") or target.is_in_group("player_minions"):
		return

	# Check if it's a valid target with take_damage
	if not target in hit_enemies and target.has_method("take_damage"):
		hit_enemies.append(target)

		# Deal damage with knockback position (pass shooter for thorns reflection)
		var final_damage = damage * damage_multiplier
		target.take_damage(final_damage, global_position, knockback_power, hitstun_duration, shooter, damage_type)
		projectile_hit.emit(target, final_damage)

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
	# If pooled, return to pool instead of destroying
	if _is_pooled and ObjectPool and ObjectPool.has_pool(_pool_name):
		# Quick fade out then return to pool
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.1)
		tween.tween_callback(func():
			ObjectPool.release(_pool_name, self)
		)
	else:
		# Cleanup effect for non-pooled projectiles
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
