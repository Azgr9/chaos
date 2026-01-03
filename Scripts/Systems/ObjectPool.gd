# SCRIPT: ObjectPool.gd
# AUTOLOAD: ObjectPool
# LOCATION: res://Scripts/Systems/ObjectPool.gd
# PURPOSE: Object pooling system to reduce GC pressure and improve performance

extends Node

# ============================================
# POOL STORAGE
# ============================================

# Dictionary of pool_name -> { scene: PackedScene, available: Array[Node], active: Array[Node], max_size: int }
var _pools: Dictionary = {}

# Parent nodes for pooled objects (keeps scene tree organized)
var _pool_containers: Dictionary = {}

# Statistics for debugging
var _stats: Dictionary = {
	"total_created": 0,
	"total_recycled": 0,
	"total_acquired": 0,
	"cache_hits": 0,
	"cache_misses": 0
}

# ============================================
# CONFIGURATION
# ============================================

const DEFAULT_POOL_SIZE: int = 20
const DEFAULT_MAX_SIZE: int = 100
const CLEANUP_INTERVAL: float = 30.0  # Seconds between cleanup passes

var _cleanup_timer: float = 0.0

# ============================================
# LIFECYCLE
# ============================================

func _ready():
	# Create container for pooled objects
	var container = Node.new()
	container.name = "ObjectPoolContainer"
	add_child(container)

func _process(delta):
	_cleanup_timer += delta
	if _cleanup_timer >= CLEANUP_INTERVAL:
		_cleanup_timer = 0.0
		_cleanup_excess_objects()

# ============================================
# POOL MANAGEMENT
# ============================================

## Register a new pool for a scene
## @param pool_name: Unique identifier for this pool
## @param scene: The PackedScene to instantiate
## @param initial_size: How many objects to pre-create
## @param max_size: Maximum objects in pool (0 = unlimited)
func register_pool(pool_name: String, scene: PackedScene, initial_size: int = DEFAULT_POOL_SIZE, max_size: int = DEFAULT_MAX_SIZE) -> void:
	if pool_name in _pools:
		push_warning("ObjectPool: Pool '%s' already exists" % pool_name)
		return

	# Create container for this pool's objects
	var container = Node.new()
	container.name = "Pool_" + pool_name
	$ObjectPoolContainer.add_child(container)
	_pool_containers[pool_name] = container

	_pools[pool_name] = {
		"scene": scene,
		"available": [],
		"active": [],
		"max_size": max_size,
		"container": container
	}

	# Pre-warm the pool (deferred to avoid startup lag)
	call_deferred("_prewarm_pool", pool_name, initial_size)

func _prewarm_pool(pool_name: String, count: int):
	if pool_name not in _pools:
		return
	for i in range(count):
		var obj = _create_pooled_object(pool_name)
		if obj:
			_return_to_pool(pool_name, obj)

## Register a pool using a scene path string
func register_pool_from_path(pool_name: String, scene_path: String, initial_size: int = DEFAULT_POOL_SIZE, max_size: int = DEFAULT_MAX_SIZE) -> void:
	var scene = load(scene_path) as PackedScene
	if scene:
		register_pool(pool_name, scene, initial_size, max_size)
	else:
		push_error("ObjectPool: Failed to load scene at '%s'" % scene_path)

## Get an object from the pool (or create new if empty)
func acquire(pool_name: String) -> Node:
	if pool_name not in _pools:
		push_error("ObjectPool: Pool '%s' not registered" % pool_name)
		return null

	var pool = _pools[pool_name]
	var obj: Node = null

	if pool.available.size() > 0:
		# Get from pool
		obj = pool.available.pop_back()
		_stats.cache_hits += 1
	else:
		# Create new object
		obj = _create_pooled_object(pool_name)
		_stats.cache_misses += 1

	if obj:
		pool.active.append(obj)
		_stats.total_acquired += 1

		# Re-enable and show the object
		_activate_object(obj)

	return obj

## Return an object to the pool
func release(pool_name: String, obj: Node) -> void:
	if pool_name not in _pools:
		push_error("ObjectPool: Pool '%s' not registered" % pool_name)
		obj.queue_free()
		return

	var pool = _pools[pool_name]

	# Remove from active list
	pool.active.erase(obj)

	# Check if pool is at max capacity
	if pool.max_size > 0 and pool.available.size() >= pool.max_size:
		obj.queue_free()
		return

	# Deactivate and return to pool
	_deactivate_object(obj)
	_return_to_pool(pool_name, obj)
	_stats.total_recycled += 1

## Acquire and auto-release after delay
func acquire_temporary(pool_name: String, lifetime: float) -> Node:
	var obj = acquire(pool_name)
	if obj:
		# Create timer to auto-release
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(obj):
				release(pool_name, obj)
		)
	return obj

# ============================================
# SPECIALIZED ACQUIRE FUNCTIONS
# ============================================

## Acquire and position at a location
func acquire_at(pool_name: String, position: Vector2) -> Node:
	var obj = acquire(pool_name)
	if obj and obj is Node2D:
		obj.global_position = position
	return obj

## Acquire, position, and auto-release
func acquire_at_temporary(pool_name: String, position: Vector2, lifetime: float) -> Node:
	var obj = acquire_at(pool_name, position)
	if obj:
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(obj):
				release(pool_name, obj)
		)
	return obj

# ============================================
# INTERNAL HELPERS
# ============================================

func _create_pooled_object(pool_name: String) -> Node:
	var pool = _pools[pool_name]
	var obj = pool.scene.instantiate()

	if obj:
		_stats.total_created += 1
		# Add to container (hidden by default)
		pool.container.add_child(obj)
		_deactivate_object(obj)

		# Add metadata to track pool origin
		obj.set_meta("_pool_name", pool_name)

	return obj

func _return_to_pool(pool_name: String, obj: Node) -> void:
	var pool = _pools[pool_name]
	if obj not in pool.available:
		pool.available.append(obj)

		# Reparent to pool container if needed
		if obj.get_parent() != pool.container:
			obj.get_parent().remove_child(obj)
			pool.container.add_child(obj)

func _activate_object(obj: Node) -> void:
	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)
	obj.set_process_input(true)

	# Call activation method if exists
	if obj.has_method("on_pool_acquire"):
		obj.on_pool_acquire()
	elif obj.has_method("_on_pool_acquire"):
		obj._on_pool_acquire()

func _deactivate_object(obj: Node) -> void:
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)
	obj.set_process_input(false)

	# Reset position
	if obj is Node2D:
		obj.position = Vector2(-9999, -9999)

	# Call deactivation method if exists
	if obj.has_method("on_pool_release"):
		obj.on_pool_release()
	elif obj.has_method("_on_pool_release"):
		obj._on_pool_release()

func _cleanup_excess_objects() -> void:
	# Remove objects above max size from pools
	for pool_name in _pools:
		var pool = _pools[pool_name]
		if pool.max_size > 0:
			var excess = pool.available.size() - pool.max_size
			for i in range(excess):
				if pool.available.size() > 0:
					var obj = pool.available.pop_back()
					if is_instance_valid(obj):
						obj.queue_free()

# ============================================
# POOL QUERIES
# ============================================

## Get number of available objects in pool
func get_available_count(pool_name: String) -> int:
	if pool_name in _pools:
		return _pools[pool_name].available.size()
	return 0

## Get number of active objects from pool
func get_active_count(pool_name: String) -> int:
	if pool_name in _pools:
		return _pools[pool_name].active.size()
	return 0

## Get total objects (available + active)
func get_total_count(pool_name: String) -> int:
	if pool_name in _pools:
		return _pools[pool_name].available.size() + _pools[pool_name].active.size()
	return 0

## Check if pool exists
func has_pool(pool_name: String) -> bool:
	return pool_name in _pools

## Get all pool names
func get_pool_names() -> Array:
	return _pools.keys()

## Get pool statistics
func get_stats() -> Dictionary:
	var stats = _stats.duplicate()
	stats.pools = {}
	for pool_name in _pools:
		stats.pools[pool_name] = {
			"available": get_available_count(pool_name),
			"active": get_active_count(pool_name),
			"total": get_total_count(pool_name)
		}
	return stats

# ============================================
# CLEANUP
# ============================================

## Clear a specific pool
func clear_pool(pool_name: String) -> void:
	if pool_name not in _pools:
		return

	var pool = _pools[pool_name]

	# Free all objects
	for obj in pool.available:
		if is_instance_valid(obj):
			obj.queue_free()
	for obj in pool.active:
		if is_instance_valid(obj):
			obj.queue_free()

	pool.available.clear()
	pool.active.clear()

## Clear all pools
func clear_all_pools() -> void:
	for pool_name in _pools.keys():
		clear_pool(pool_name)

## Unregister a pool completely
func unregister_pool(pool_name: String) -> void:
	clear_pool(pool_name)
	_pools.erase(pool_name)

	if pool_name in _pool_containers:
		_pool_containers[pool_name].queue_free()
		_pool_containers.erase(pool_name)

# ============================================
# CONVENIENCE - Common pool types
# ============================================

## Register common game object pools
func register_common_pools() -> void:
	# These will be called after scenes are loaded
	pass

## Quick release - finds pool from object metadata
func quick_release(obj: Node) -> void:
	if obj.has_meta("_pool_name"):
		var pool_name = obj.get_meta("_pool_name")
		release(pool_name, obj)
	else:
		# Not a pooled object, just free it
		obj.queue_free()
