# SCRIPT: NecroProjectile.gd
# NecroStaff's dark soul projectile
# LOCATION: res://Scenes/Weapons/NecroStaff/spells/NecroProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Necro colors
const NECRO_DARK: Color = Color(0.1, 0.05, 0.15)  # Very dark purple-black
const NECRO_GLOW: Color = Color(0.4, 0.1, 0.5, 0.8)  # Dark purple glow
const NECRO_SOUL: Color = Color(0.6, 0.2, 0.8, 0.9)  # Purple soul

func _ready():
	super._ready()
	_setup_necro_visuals()

func _setup_necro_visuals():
	# Set dark soul orb colors
	if sprite:
		sprite.color = NECRO_DARK
		sprite.size = Vector2(12, 12)

	# Add dark trail
	_start_dark_trail()

func _start_dark_trail():
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

		# Dark trail particle
		var trail = ColorRect.new()
		trail.size = Vector2(10, 10)
		trail.color = NECRO_GLOW
		trail.pivot_offset = Vector2(5, 5)
		trail.z_index = 100
		tree.current_scene.add_child(trail)
		trail.global_position = p.global_position

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(trail, "scale", Vector2(0.2, 0.2), 0.15)
			tween.tween_property(trail, "modulate:a", 0.0, 0.15)
			tween.tween_callback(trail.queue_free)

		# Occasional soul wisp
		if randf() > 0.7:
			p._spawn_soul_wisp(p.global_position)
	)
	timer.start()

func _spawn_soul_wisp(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return

	var wisp = ColorRect.new()
	wisp.size = Vector2(6, 10)
	wisp.color = NECRO_SOUL
	wisp.pivot_offset = Vector2(3, 5)
	wisp.z_index = 100
	tree.current_scene.add_child(wisp)
	wisp.global_position = pos + Vector2(randf_range(-8, 8), 0)

	var tween = tree.create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(wisp, "global_position:y", wisp.global_position.y - 25, 0.3)
		tween.tween_property(wisp, "modulate:a", 0.0, 0.3)
		tween.tween_property(wisp, "rotation", randf_range(-0.5, 0.5), 0.3)
		tween.tween_callback(wisp.queue_free)
