# SCRIPT: ProjectilePool.gd
# AUTOLOAD: ProjectilePool
# LOCATION: res://Scripts/Systems/ProjectilePool.gd
# PURPOSE: Specialized projectile pooling system for high-performance bullet spawning

extends Node

# ============================================
# POOL CONFIGURATION
# ============================================
const POOL_CONFIGS = {
	"projectile_basic": {
		"scene": "res://Scenes/Spells/BasicProjectile.tscn",
		"initial_size": 30,
		"max_size": 100
	},
	"projectile_fire": {
		"scene": "res://Scenes/Spells/BasicProjectile.tscn",
		"initial_size": 20,
		"max_size": 60
	},
	"projectile_ice": {
		"scene": "res://Scenes/Spells/BasicProjectile.tscn",
		"initial_size": 20,
		"max_size": 60
	},
	"projectile_lightning": {
		"scene": "res://Scenes/Spells/BasicProjectile.tscn",
		"initial_size": 20,
		"max_size": 60
	},
	"projectile_enemy": {
		"scene": "res://Scenes/Enemies/EnemyArrow.tscn",
		"initial_size": 15,
		"max_size": 40
	}
}

# ============================================
# STATE
# ============================================
var _initialized: bool = false
var _projectile_container: Node2D = null

# Statistics
var stats = {
	"spawned": 0,
	"recycled": 0,
	"cache_hits": 0,
	"cache_misses": 0
}

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	# Create container for pooled projectiles
	_projectile_container = Node2D.new()
	_projectile_container.name = "ProjectilePoolContainer"
	add_child(_projectile_container)

	# Defer pool registration to ensure ObjectPool is ready
	call_deferred("_register_pools")

func _register_pools():
	if _initialized:
		return

	for pool_name in POOL_CONFIGS:
		var config = POOL_CONFIGS[pool_name]
		var scene_path = config.scene

		if not ResourceLoader.exists(scene_path):
			push_warning("[ProjectilePool] Scene not found: %s" % scene_path)
			continue

		var scene = load(scene_path) as PackedScene
		if scene and ObjectPool:
			ObjectPool.register_pool(pool_name, scene, config.initial_size, config.max_size)
			print("[ProjectilePool] Registered pool: %s" % pool_name)

	_initialized = true

# ============================================
# SPAWN PROJECTILES
# ============================================
func spawn(pool_name: String, position: Vector2, direction: Vector2,
		   damage_multiplier: float = 1.0, knockback: float = 400.0,
		   hitstun: float = 0.1, shooter: Node2D = null,
		   damage_type: int = DamageTypes.Type.PHYSICAL) -> Node2D:
	"""Spawn a projectile from pool with full configuration"""

	if not _initialized:
		_register_pools()

	var projectile: Node2D = null

	# Try to get from pool
	if ObjectPool and ObjectPool.has_pool(pool_name):
		projectile = ObjectPool.acquire(pool_name)
		stats.cache_hits += 1
	else:
		# Fallback: instantiate directly
		var scene_path = POOL_CONFIGS.get(pool_name, {}).get("scene", "res://Scenes/Spells/BasicProjectile.tscn")
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path) as PackedScene
			projectile = scene.instantiate()
			stats.cache_misses += 1

	if not projectile:
		return null

	# Reparent to game scene if needed
	var game_scene = get_tree().current_scene
	if projectile.get_parent() != game_scene:
		if projectile.get_parent():
			projectile.get_parent().remove_child(projectile)
		game_scene.add_child(projectile)

	# Initialize projectile
	if projectile.has_method("initialize"):
		projectile.initialize(position, direction, damage_multiplier, knockback, hitstun, shooter, damage_type)
	else:
		projectile.global_position = position
		if projectile.get("direction") != null:
			projectile.direction = direction
		if projectile.get("velocity") != null:
			var speed_value = projectile.get("speed") if projectile.get("speed") != null else 1000.0
			projectile.velocity = direction.normalized() * speed_value

	# Set pool name for proper release
	if projectile.get("_pool_name") != null:
		projectile._pool_name = pool_name

	stats.spawned += 1
	return projectile

func spawn_basic(position: Vector2, direction: Vector2,
				 damage_multiplier: float = 1.0, shooter: Node2D = null) -> Node2D:
	"""Quick spawn for basic projectile"""
	return spawn("projectile_basic", position, direction, damage_multiplier, 400.0, 0.1, shooter)

func spawn_fire(position: Vector2, direction: Vector2,
				damage_multiplier: float = 1.0, shooter: Node2D = null) -> Node2D:
	"""Quick spawn for fire projectile"""
	var proj = spawn("projectile_fire", position, direction, damage_multiplier, 300.0, 0.15, shooter, DamageTypes.Type.FIRE)
	if proj and proj.get("sprite"):
		proj.sprite.color = Color(1.0, 0.5, 0.1)
	return proj

func spawn_ice(position: Vector2, direction: Vector2,
			   damage_multiplier: float = 1.0, shooter: Node2D = null) -> Node2D:
	"""Quick spawn for ice projectile"""
	var proj = spawn("projectile_ice", position, direction, damage_multiplier, 200.0, 0.2, shooter, DamageTypes.Type.ICE)
	if proj and proj.get("sprite"):
		proj.sprite.color = Color(0.6, 0.9, 1.0)
	return proj

func spawn_lightning(position: Vector2, direction: Vector2,
					 damage_multiplier: float = 1.0, shooter: Node2D = null) -> Node2D:
	"""Quick spawn for lightning projectile"""
	var proj = spawn("projectile_lightning", position, direction, damage_multiplier, 500.0, 0.05, shooter, DamageTypes.Type.ELECTRIC)
	if proj and proj.get("sprite"):
		proj.sprite.color = Color(0.8, 0.9, 1.0)
	if proj and proj.get("speed") != null:
		proj.speed = 1400.0  # Faster lightning
		proj.velocity = direction.normalized() * proj.speed
	return proj

func spawn_enemy_arrow(position: Vector2, direction: Vector2,
					   damage: float = 10.0, shooter: Node2D = null) -> Node2D:
	"""Spawn enemy arrow projectile"""
	var proj = spawn("projectile_enemy", position, direction, 1.0, 200.0, 0.1, shooter)
	if proj and proj.get("damage") != null:
		proj.damage = damage
	return proj

# ============================================
# MULTI-SPAWN (for shotgun/spread patterns)
# ============================================
func spawn_spread(pool_name: String, position: Vector2, base_direction: Vector2,
				  count: int, spread_angle: float, damage_multiplier: float = 1.0,
				  shooter: Node2D = null, damage_type: int = DamageTypes.Type.PHYSICAL) -> Array:
	"""Spawn multiple projectiles in a spread pattern"""
	var projectiles: Array = []
	var half_spread = spread_angle / 2.0

	for i in range(count):
		var t = float(i) / max(count - 1, 1)  # 0 to 1
		var angle_offset = lerp(-half_spread, half_spread, t)
		var direction = base_direction.rotated(deg_to_rad(angle_offset))

		var proj = spawn(pool_name, position, direction, damage_multiplier, 400.0, 0.1, shooter, damage_type)
		if proj:
			projectiles.append(proj)

	return projectiles

func spawn_ring(pool_name: String, position: Vector2, count: int,
				damage_multiplier: float = 1.0, shooter: Node2D = null,
				damage_type: int = DamageTypes.Type.PHYSICAL) -> Array:
	"""Spawn projectiles in a ring pattern"""
	var projectiles: Array = []

	for i in range(count):
		var angle = (TAU / count) * i
		var direction = Vector2.from_angle(angle)

		var proj = spawn(pool_name, position, direction, damage_multiplier, 400.0, 0.1, shooter, damage_type)
		if proj:
			projectiles.append(proj)

	return projectiles

func spawn_burst(pool_name: String, position: Vector2, base_direction: Vector2,
				 count: int, damage_multiplier: float = 1.0,
				 shooter: Node2D = null, damage_type: int = DamageTypes.Type.PHYSICAL) -> void:
	"""Spawn projectiles in quick succession (burst fire)"""
	for i in range(count):
		# Slight timing offset
		get_tree().create_timer(i * 0.08).timeout.connect(func():
			# Small random spread
			var spread = base_direction.rotated(randf_range(-0.1, 0.1))
			spawn(pool_name, position, spread, damage_multiplier, 400.0, 0.1, shooter, damage_type)
		)

# ============================================
# CLEANUP
# ============================================
func release_all():
	"""Return all active projectiles to pool"""
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	for proj in projectiles:
		if is_instance_valid(proj) and proj.get("_pool_name") != null:
			if ObjectPool and ObjectPool.has_pool(proj._pool_name):
				ObjectPool.release(proj._pool_name, proj)
				stats.recycled += 1

func get_stats() -> Dictionary:
	var pool_stats = {}
	for pool_name in POOL_CONFIGS:
		if ObjectPool and ObjectPool.has_pool(pool_name):
			pool_stats[pool_name] = {
				"available": ObjectPool.get_available_count(pool_name),
				"active": ObjectPool.get_active_count(pool_name)
			}

	return {
		"spawned": stats.spawned,
		"recycled": stats.recycled,
		"cache_hits": stats.cache_hits,
		"cache_misses": stats.cache_misses,
		"hit_rate": float(stats.cache_hits) / max(stats.spawned, 1),
		"pools": pool_stats
	}
