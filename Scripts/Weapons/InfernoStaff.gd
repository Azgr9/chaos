# SCRIPT: InfernoStaff.gd
# ATTACH TO: InfernoStaff (Node2D) root node in InfernoStaff.tscn
# LOCATION: res://Scripts/Weapons/InfernoStaff.gd
# AoE/DoT staff that creates burning zones - affects enemies AND player (risk/reward)

class_name InfernoStaff
extends MagicWeapon

# ============================================
# PROJECTILE COLORS
# ============================================
const FIRE_CORE: Color = Color(1.0, 0.8, 0.2)  # Bright yellow-orange core
const FIRE_MID: Color = Color(1.0, 0.4, 0.1)  # Orange
const FIRE_OUTER: Color = Color(0.8, 0.2, 0.0, 0.7)  # Dark red outer
const EMBER_COLOR: Color = Color(1.0, 0.5, 0.0)  # Ember particles

# ============================================
# INFERNO STAFF SPECIFIC
# ============================================
const PROJECTILE_SCENE_PATH = preload("res://Scenes/Weapons/InfernoStaff/spells/FireProjectile.tscn")
const SKILL_SCENE = preload("res://Scenes/Weapons/InfernoStaff/spells/VolcanoSkill.tscn")

func _weapon_ready():
	# Set projectile scene
	projectile_scene = PROJECTILE_SCENE_PATH

	# Inferno Staff - slower but higher damage fireballs
	attack_cooldown = 0.38  # Slower, heavier fireballs
	projectile_spread = 8.0
	multi_shot = 1
	damage = 14.0  # Higher base damage for slower speed
	damage_type = DamageTypes.Type.FIRE  # Applies BURN status effect

	staff_color = Color("#8b0000")  # Dark red crystal staff
	muzzle_flash_color = Color(1.0, 0.5, 0.1)  # Orange flash

	# Attack Speed Limits (slower, higher damage staff)
	max_attacks_per_second = 2.5  # Slower but powerful
	min_cooldown = 0.28  # Cannot cast faster than this

	# Skill settings - Volcano Eruption
	skill_cooldown = 10.0  # Powerful skill needs longer cooldown
	beam_damage = 0.0  # Not using beam

func _weapon_process(_delta):
	# Ambient fire particle on staff
	if randf() > 0.95:
		_spawn_staff_ember()

func _spawn_staff_ember():
	var ember = ColorRect.new()
	ember.size = Vector2(4, 6)
	ember.color = EMBER_COLOR
	ember.pivot_offset = Vector2(2, 3)
	add_child(ember)
	ember.position = Vector2(randf_range(-5, 5), randf_range(-20, -10))

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(ember, "position:y", ember.position.y - 20, 0.4)
	tween.tween_property(ember, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ember.queue_free)

func _perform_skill() -> bool:
	# Volcano Eruption - explosion at player position with fire immunity
	if not player_reference:
		return false

	# Spawn VolcanoSkill scene
	var skill = SKILL_SCENE.instantiate()
	get_tree().current_scene.add_child(skill)
	skill.initialize(player_reference, player_reference.stats.magic_damage_multiplier)

	# Visual feedback on staff
	_play_skill_animation()

	return true

func _play_skill_animation():
	# Staff glow red during skill
	var original_color = sprite.color
	sprite.color = Color(1.0, 0.3, 0.1)

	# Recoil
	var recoil_tween = TweenHelper.new_tween()
	recoil_tween.tween_property(self, "position:x", -20, 0.1)
	recoil_tween.tween_property(self, "position:x", 0, 0.2)

	# Muzzle flash
	muzzle_flash.modulate = Color(1.0, 0.5, 0.1, 1.0)
	var flash_tween = TweenHelper.new_tween()
	flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)

	# Return to normal color
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self) and sprite:
		sprite.color = original_color

func _get_projectile_color() -> Color:
	return FIRE_CORE

func _get_beam_color() -> Color:
	return Color(1.0, 0.5, 0.1, 1.0)  # Bright orange

func _get_beam_glow_color() -> Color:
	return FIRE_OUTER

# Trail colors - Hot fire orange-yellow
func _get_trail_color() -> Color:
	return Color(1.0, 0.6, 0.1, 0.9)  # Fire orange

func _get_trail_glow_color() -> Color:
	return Color(1.0, 0.9, 0.4, 1.0)  # Bright yellow core

func _get_trail_glow_intensity() -> float:
	return 2.2  # Intense fire glow

func _get_trail_pulse_speed() -> float:
	return 6.0  # Fast flickering like flames

func _get_trail_sparkle_amount() -> float:
	return 0.2  # Less sparkle, more smooth fire

func _customize_projectile(projectile: Node2D):
	# Blazing fireball projectile
	if projectile.has_node("Sprite"):
		var sprite_node = projectile.get_node("Sprite")
		sprite_node.color = FIRE_CORE
		sprite_node.size = Vector2(18, 18)  # Round fireball

	# Add flame trail effect
	_add_flame_trail(projectile)

func _add_flame_trail(projectile: Node2D):
	var timer = Timer.new()
	timer.wait_time = 0.025
	timer.one_shot = false
	projectile.add_child(timer)

	# Use weakref to safely capture references
	var staff_ref = weakref(self)
	var projectile_ref = weakref(projectile)
	var timer_ref = weakref(timer)

	timer.timeout.connect(func():
		var t = timer_ref.get_ref()
		var p = projectile_ref.get_ref()
		var staff = staff_ref.get_ref()

		if not t or not p or not is_instance_valid(p):
			if t and is_instance_valid(t):
				t.stop()
			return

		if not staff or not is_instance_valid(staff):
			if t and is_instance_valid(t):
				t.stop()
			return

		var tree = staff.get_tree()
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
			staff._spawn_smoke_particle(p.global_position)
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
