# SCRIPT: VoidProjectile.gd
# VoidStaff's dark void orb projectile
# LOCATION: res://Scenes/Weapons/VoidStaff/spells/VoidProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Void colors
const VOID_CORE: Color = Color(0.1, 0.0, 0.15)  # Almost black core
const VOID_GLOW: Color = Color(0.5, 0.2, 0.7, 0.8)  # Purple glow
const VOID_OUTER: Color = Color(0.3, 0.1, 0.4, 0.6)  # Dark purple outer
const VOID_SPARK: Color = Color(0.7, 0.4, 1.0)  # Bright purple sparks

func _ready():
	super._ready()
	_setup_void_visuals()

func _setup_void_visuals():
	# Set dark void orb colors
	if sprite:
		sprite.color = VOID_CORE
		sprite.size = Vector2(16, 16)

	# Add void trail
	_start_void_trail()

func _start_void_trail():
	var timer = Timer.new()
	timer.wait_time = 0.035
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

		# Main void trail - dark core
		var trail = ColorRect.new()
		trail.size = Vector2(14, 14)
		trail.color = VOID_OUTER
		trail.pivot_offset = Vector2(7, 7)
		trail.z_index = 100
		tree.current_scene.add_child(trail)
		trail.global_position = p.global_position

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(trail, "scale", Vector2(0.2, 0.2), 0.25)
			tween.tween_property(trail, "modulate:a", 0.0, 0.25)
			tween.tween_callback(trail.queue_free)

		# Swirling void particles being pulled in
		if randf() > 0.6:
			p._spawn_void_swirl_particle(p.global_position)

		# Occasional bright spark
		if randf() > 0.85:
			p._spawn_void_spark(p.global_position)
	)
	timer.start()

func _spawn_void_swirl_particle(center: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var particle = ColorRect.new()
	particle.size = Vector2(6, 6)
	particle.color = VOID_GLOW
	particle.pivot_offset = Vector2(3, 3)
	particle.z_index = 100
	tree.current_scene.add_child(particle)

	# Start from offset position
	var angle = randf() * TAU
	var start_offset = Vector2.from_angle(angle) * randf_range(20, 35)
	particle.global_position = center + start_offset

	# Spiral into center
	var tween = tree.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", center, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.2)
		tween.tween_property(particle, "rotation", angle + PI, 0.2)
		tween.tween_property(particle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(particle.queue_free)

func _spawn_void_spark(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var spark = ColorRect.new()
	spark.size = Vector2(4, 8)
	spark.color = VOID_SPARK
	spark.pivot_offset = Vector2(2, 4)
	spark.z_index = 100
	tree.current_scene.add_child(spark)
	spark.global_position = pos
	spark.rotation = randf() * TAU

	var tween = tree.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.1)
		tween.tween_property(spark, "modulate:a", 0.0, 0.1)
		tween.tween_callback(spark.queue_free)
