# SCRIPT: LightningProjectile.gd
# LightningStaff's crackling electric bolt projectile
# LOCATION: res://Scenes/Weapons/LightningStaff/spells/LightningProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Electric colors
const ELECTRIC_CORE: Color = Color(0.4, 0.9, 1.0)  # Bright electric blue
const ELECTRIC_GLOW: Color = Color(0.0, 1.0, 1.0, 0.8)  # Cyan
const ELECTRIC_SPARK: Color = Color(1.0, 1.0, 0.6)  # Yellow-white sparks

func _ready():
	super._ready()
	damage_type = DamageTypes.Type.ELECTRIC
	_setup_electric_visuals()

func _setup_electric_visuals():
	# Set electric bolt colors
	if sprite:
		sprite.color = ELECTRIC_CORE
		sprite.size = Vector2(12, 18)  # Elongated bolt shape

	# Add electric crackling effect
	_start_electric_trail()

func _start_electric_trail():
	var timer = Timer.new()
	timer.wait_time = 0.03
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

		# Electric spark particle
		var spark = ColorRect.new()
		spark.size = Vector2(4, 8)
		spark.color = ELECTRIC_SPARK if randf() > 0.5 else ELECTRIC_GLOW
		spark.pivot_offset = Vector2(2, 4)
		spark.z_index = 100
		tree.current_scene.add_child(spark)
		spark.global_position = p.global_position
		spark.rotation = randf() * TAU

		# Small arc/zap away from projectile
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		var target_pos = p.global_position + offset

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(spark, "global_position", target_pos, 0.1)
			tween.tween_property(spark, "modulate:a", 0.0, 0.1)
			tween.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.1)
			tween.tween_callback(spark.queue_free)

		# Occasional mini-bolt branching off
		if randf() > 0.7:
			p._create_mini_bolt(p.global_position)
	)
	timer.start()

func _create_mini_bolt(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var bolt = Line2D.new()
	bolt.default_color = ELECTRIC_GLOW
	bolt.width = 2.0
	bolt.z_index = 100
	tree.current_scene.add_child(bolt)

	var end_pos = pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	var mid_pos = pos.lerp(end_pos, 0.5) + Vector2(randf_range(-8, 8), randf_range(-8, 8))

	bolt.points = PackedVector2Array([pos, mid_pos, end_pos])

	var tween = tree.create_tween()
	if tween:
		tween.tween_property(bolt, "modulate:a", 0.0, 0.08)
		tween.tween_callback(bolt.queue_free)
