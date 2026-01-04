# SCRIPT: ArcaneProjectile.gd
# BasicStaff's arcane energy projectile
# LOCATION: res://Scenes/Weapons/BasicStaff/spells/ArcaneProjectile.gd

extends "res://Scripts/Spells/BasicProjectile.gd"

# Arcane colors
const ARCANE_CORE: Color = Color(0.4, 0.8, 1.0)  # Cyan core
const ARCANE_GLOW: Color = Color(0.6, 0.9, 1.0, 0.6)  # Light blue glow

func _ready():
	super._ready()
	_setup_arcane_visuals()

func _setup_arcane_visuals():
	# Set arcane colors
	if sprite:
		sprite.color = ARCANE_CORE
		sprite.size = Vector2(16, 16)

	# Add sparkle trail
	_start_arcane_trail()

func _start_arcane_trail():
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

		var sparkle = ColorRect.new()
		sparkle.size = Vector2(8, 8)
		sparkle.color = ARCANE_GLOW
		sparkle.pivot_offset = Vector2(4, 4)
		sparkle.z_index = 100
		tree.current_scene.add_child(sparkle)
		sparkle.global_position = p.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5))

		var tween = tree.create_tween()
		if tween:
			tween.set_parallel(true)
			tween.tween_property(sparkle, "scale", Vector2(0.2, 0.2), 0.2)
			tween.tween_property(sparkle, "modulate:a", 0.0, 0.2)
			tween.tween_callback(sparkle.queue_free)
	)
	timer.start()
