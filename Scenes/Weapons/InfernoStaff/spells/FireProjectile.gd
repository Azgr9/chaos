# SCRIPT: FireProjectile.gd
# InfernoStaff's blazing fireball projectile
# LOCATION: res://Scenes/Weapons/InfernoStaff/spells/FireProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Fire colors
const FIRE_CORE: Color = Color(1.0, 0.8, 0.2)  # Bright yellow-orange core
const FIRE_MID: Color = Color(1.0, 0.4, 0.1)  # Orange
const FIRE_OUTER: Color = Color(0.8, 0.2, 0.0, 0.7)  # Dark red outer

func _ready():
	super._ready()
	damage_type = DamageTypes.Type.FIRE
	_setup_fire_visuals()

func _setup_fire_visuals():
	# Set fireball colors
	if sprite:
		sprite.color = FIRE_CORE
		sprite.size = Vector2(18, 18)  # Round fireball

	# Add flame trail
	_start_flame_trail()

func _start_flame_trail():
	var timer = Timer.new()
	timer.wait_time = 0.025
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

		# Flame particle
		var flame = ColorRect.new()
		flame.size = Vector2(randf_range(10, 16), randf_range(14, 22))
		# Gradient from yellow core to orange to red
		var color_choice = randf()
		if color_choice > 0.7:
			flame.color = FIRE_CORE
		elif color_choice > 0.3:
			flame.color = FIRE_MID
		else:
			flame.color = FIRE_OUTER
		flame.pivot_offset = flame.size / 2
		flame.z_index = 100
		tree.current_scene.add_child(flame)
		flame.global_position = p.global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))

		# Flames rise and fade
		var target_y = flame.global_position.y - randf_range(15, 30)
		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(flame, "global_position:y", target_y, 0.25)
			tween.tween_property(flame, "scale", Vector2(0.2, 0.4), 0.25)
			tween.tween_property(flame, "modulate:a", 0.0, 0.25)
			tween.tween_callback(flame.queue_free)

		# Smoke particle occasionally
		if randf() > 0.8:
			p._spawn_smoke_particle(p.global_position)
	)
	timer.start()

func _spawn_smoke_particle(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var smoke = ColorRect.new()
	smoke.size = Vector2(10, 10)
	smoke.color = Color(0.3, 0.3, 0.3, 0.4)
	smoke.pivot_offset = Vector2(5, 5)
	smoke.z_index = 100
	tree.current_scene.add_child(smoke)
	smoke.global_position = pos

	var tween = tree.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(smoke, "global_position:y", pos.y - 40, 0.5)
		tween.tween_property(smoke, "global_position:x", pos.x + randf_range(-15, 15), 0.5)
		tween.tween_property(smoke, "scale", Vector2(2.0, 2.0), 0.5)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.5)
		tween.tween_callback(smoke.queue_free)
