# SCRIPT: FrostProjectile.gd
# FrostStaff's ice shard projectile with slow effect
# LOCATION: res://Scenes/Weapons/FrostStaff/spells/FrostProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Ice colors
const ICE_CORE: Color = Color(0.7, 0.9, 1.0)  # Light ice blue
const ICE_GLOW: Color = Color(0.5, 0.8, 1.0, 0.6)  # Frosty blue
const ICE_CRYSTAL: Color = Color(0.9, 0.95, 1.0)  # Near-white crystal

# Slow effect settings
var slow_duration: float = 2.0
var slow_amount: float = 0.5  # 50% slow

func _ready():
	super._ready()
	damage_type = DamageTypes.Type.ICE
	_setup_frost_visuals()

func _setup_frost_visuals():
	# Set ice shard colors
	if sprite:
		sprite.color = ICE_CORE
		sprite.size = Vector2(10, 20)  # Shard shape

	# Add frost trail
	_start_frost_trail()

	# Connect hit signal for slow effect
	if not projectile_hit.is_connected(_on_frost_hit):
		projectile_hit.connect(_on_frost_hit)

func _on_frost_hit(target: Node2D, _damage: float):
	_apply_slow_effect(target)
	_create_frost_effect(target.global_position)

func _apply_slow_effect(enemy: Node2D):
	if not is_instance_valid(enemy):
		return

	# Apply slow (if enemy has speed property)
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_amount, slow_duration)
	elif "speed" in enemy or "move_speed" in enemy:
		_temporary_slow(enemy)

func _temporary_slow(enemy: Node2D):
	var speed_property = "speed" if "speed" in enemy else "move_speed"
	var original_speed = enemy.get(speed_property)

	# Apply slow
	enemy.set(speed_property, original_speed * slow_amount)

	# Ice visual on enemy
	var original_modulate = enemy.modulate
	enemy.modulate = Color(0.6, 0.8, 1.0)

	# Create timer to restore
	var timer = get_tree().create_timer(slow_duration)
	timer.timeout.connect(func():
		if is_instance_valid(enemy):
			enemy.set(speed_property, original_speed)
			enemy.modulate = original_modulate
	)

func _create_frost_effect(pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	# Ice crystal particles
	for i in range(4):
		var crystal = ColorRect.new()
		crystal.size = Vector2(8, 12)
		crystal.color = ICE_CRYSTAL
		crystal.pivot_offset = Vector2(4, 6)
		crystal.z_index = 100
		scene.add_child(crystal)
		crystal.global_position = pos + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		crystal.rotation = randf_range(-PI/4, PI/4)

		var tween = scene.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(crystal, "global_position:y", crystal.global_position.y - 30, 0.4)
			tween.tween_property(crystal, "modulate:a", 0.0, 0.4)
			tween.tween_property(crystal, "scale", Vector2(0.5, 0.5), 0.4)
			tween.tween_callback(crystal.queue_free)

func _start_frost_trail():
	var timer = Timer.new()
	timer.wait_time = 0.04
	timer.one_shot = false
	add_child(timer)

	var projectile_ref = weakref(self)
	var timer_ref = weakref(timer)

	timer.timeout.connect(func():
		var t = timer_ref.get_ref()
		var p = projectile_ref.get_ref()

		if not t or not p or not is_instance_valid(p):
			if t and is_instance_valid(t):
				t.stop()
			return

		var tree = p.get_tree()
		if not tree or not tree.current_scene:
			return

		# Ice crystal particle
		var crystal = ColorRect.new()
		crystal.size = Vector2(6, 10)
		crystal.color = ICE_CRYSTAL if randf() > 0.6 else ICE_GLOW
		crystal.pivot_offset = Vector2(3, 5)
		crystal.z_index = 100
		tree.current_scene.add_child(crystal)
		crystal.global_position = p.global_position
		crystal.rotation = randf_range(-PI/4, PI/4)

		# Float and fade
		var target_y = crystal.global_position.y - 15
		var target_x = crystal.global_position.x + randf_range(-10, 10)
		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(crystal, "global_position:y", target_y, 0.3)
			tween.tween_property(crystal, "global_position:x", target_x, 0.3)
			tween.tween_property(crystal, "modulate:a", 0.0, 0.3)
			tween.tween_property(crystal, "scale", Vector2(0.3, 0.3), 0.3)
			tween.tween_callback(crystal.queue_free)

		# Occasional snowflake
		if randf() > 0.7:
			p._spawn_trail_snowflake(p.global_position)
	)
	timer.start()

func _spawn_trail_snowflake(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var snow = ColorRect.new()
	snow.size = Vector2(4, 4)
	snow.color = ICE_CRYSTAL
	snow.pivot_offset = Vector2(2, 2)
	snow.z_index = 100
	tree.current_scene.add_child(snow)
	snow.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))

	var tween = tree.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(snow, "global_position:y", snow.global_position.y + 20, 0.4)
		tween.tween_property(snow, "rotation", randf() * TAU, 0.4)
		tween.tween_property(snow, "modulate:a", 0.0, 0.4)
		tween.tween_callback(snow.queue_free)
