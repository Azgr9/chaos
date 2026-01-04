# SCRIPT: VolcanoSkill.gd
# InfernoStaff's Volcano Eruption skill - explosion + lava pool
# LOCATION: res://Scenes/Weapons/InfernoStaff/spells/VolcanoSkill.gd

extends Node2D

# Volcano settings
@export var volcano_radius: float = 150.0
@export var volcano_damage: float = 35.0
@export var lava_pool_damage: float = 10.0
@export var lava_pool_duration: float = 4.0
@export var fire_immunity_duration: float = 3.0

# Colors
const FIRE_CORE: Color = Color(1.0, 0.8, 0.2)
const FIRE_MID: Color = Color(1.0, 0.4, 0.1)
const LAVA_CORE: Color = Color(1.0, 0.6, 0.0)
const LAVA_OUTER: Color = Color(0.8, 0.2, 0.0, 0.8)
const MAGMA_COLOR: Color = Color(1.0, 0.3, 0.0)

var player_ref: Node2D = null
var damage_multiplier: float = 1.0
var damage_type: int = 2  # DamageTypes.Type.FIRE

signal skill_completed
signal dealt_damage(target: Node2D, damage: float)

func initialize(player: Node2D, magic_multiplier: float = 1.0):
	player_ref = player
	damage_multiplier = magic_multiplier
	global_position = player.global_position

	# Make sure skill is visible above everything
	z_index = 100

	# Grant fire immunity FIRST
	_grant_fire_immunity()

	# Create volcano eruption effect
	_create_volcano_eruption()

	# Deal burst damage to all enemies in radius
	_deal_eruption_damage()

	# Create persistent lava pool
	_create_lava_pool()

func _grant_fire_immunity():
	if not player_ref:
		return

	# Grant actual fire immunity
	player_ref.is_fire_immune = true

	# Visual indicator - player glows orange
	player_ref.modulate = Color(1.0, 0.7, 0.4)

	# Create fire aura around player
	_create_fire_aura()

	# Timer to remove immunity
	_remove_fire_immunity_delayed()

func _remove_fire_immunity_delayed():
	await get_tree().create_timer(fire_immunity_duration).timeout
	if is_instance_valid(player_ref):
		player_ref.is_fire_immune = false
		player_ref.modulate = Color.WHITE

func _create_fire_aura():
	if not player_ref:
		return

	# Create particles that orbit around player during immunity
	var aura_container = Node2D.new()
	player_ref.add_child(aura_container)

	# Spawn orbiting embers
	for i in range(8):
		var ember = ColorRect.new()
		ember.size = Vector2(8, 12)
		ember.color = FIRE_CORE
		ember.pivot_offset = Vector2(4, 6)
		aura_container.add_child(ember)

		var angle = (TAU / 8) * i
		ember.position = Vector2.from_angle(angle) * 40

	# Animate the aura
	_animate_fire_aura(aura_container)

func _animate_fire_aura(aura: Node2D):
	var elapsed = 0.0
	while elapsed < fire_immunity_duration:
		if not is_instance_valid(aura):
			break

		var delta = get_process_delta_time()
		elapsed += delta

		# Rotate the aura
		aura.rotation += delta * 3.0

		# Update ember positions with wobble
		var children = aura.get_children()
		for i in range(children.size()):
			var ember = children[i]
			if is_instance_valid(ember):
				var base_angle = (TAU / children.size()) * i + aura.rotation
				var radius = 35 + sin(elapsed * 5.0 + i) * 8
				ember.position = Vector2.from_angle(base_angle) * radius
				ember.color = FIRE_CORE.lerp(FIRE_MID, (sin(elapsed * 8.0 + i) + 1) / 2)

		# Fade out near end
		if elapsed > fire_immunity_duration - 0.5:
			aura.modulate.a = (fire_immunity_duration - elapsed) / 0.5

		await get_tree().process_frame

	if is_instance_valid(aura):
		aura.queue_free()

func _create_volcano_eruption():
	# Initial explosion flash - VERY BRIGHT
	var flash = ColorRect.new()
	flash.size = Vector2(volcano_radius * 3, volcano_radius * 3)
	flash.color = Color(1.0, 0.9, 0.5, 1.0)  # Bright white-yellow
	flash.pivot_offset = flash.size / 2
	add_child(flash)
	flash.position = -flash.pivot_offset  # Center on skill position

	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.2)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(flash.queue_free)

	# Create multiple shockwave rings
	for i in range(4):
		_create_eruption_ring(i * 0.06, volcano_radius * (0.4 + i * 0.25))

	# Spawn erupting fire/magma particles shooting outward
	for i in range(40):
		_spawn_eruption_particle()

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.8)

func _create_eruption_ring(delay: float, radius: float):
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(self):
		return

	var ring = ColorRect.new()
	ring.size = Vector2(radius * 2, radius * 2)
	ring.color = LAVA_OUTER
	ring.pivot_offset = Vector2(radius, radius)
	add_child(ring)
	ring.position = -ring.pivot_offset  # Center on skill position
	ring.scale = Vector2(0.3, 0.3)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

func _spawn_eruption_particle():
	var particle = ColorRect.new()
	particle.size = Vector2(randf_range(12, 24), randf_range(16, 32))
	particle.pivot_offset = particle.size / 2
	particle.z_index = 100

	# Random fire color
	var color_roll = randf()
	if color_roll > 0.6:
		particle.color = FIRE_CORE
	elif color_roll > 0.3:
		particle.color = FIRE_MID
	else:
		particle.color = MAGMA_COLOR

	get_tree().current_scene.add_child(particle)
	particle.global_position = global_position

	# Launch in random direction with arc
	var angle = randf() * TAU
	var direction = Vector2.from_angle(angle)
	var target_pos = global_position + direction * randf_range(80, volcano_radius * 1.2)

	# Arc upward then fall
	var peak_height = randf_range(50, 120)
	var duration = randf_range(0.4, 0.7)

	var tween = create_tween()
	tween.set_parallel(true)

	# Horizontal movement
	tween.tween_property(particle, "global_position:x", target_pos.x, duration)

	# Vertical arc - go up then down
	var start_y = global_position.y
	tween.tween_property(particle, "global_position:y", start_y - peak_height, duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(particle, "global_position:y", target_pos.y, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Rotate as it flies
	tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), duration)

	# Fade and shrink at end
	tween.tween_property(particle, "modulate:a", 0.0, duration)
	tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration)
	tween.tween_callback(particle.queue_free)

func _deal_eruption_damage():
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip converted minions
		if enemy.is_in_group("converted_minion") or enemy.is_in_group("player_minions"):
			continue

		var dist = enemy.global_position.distance_to(global_position)
		if dist <= volcano_radius:
			# Full damage at center, less at edge
			var damage_falloff = 1.0 - (dist / volcano_radius) * 0.5
			var final_damage = volcano_damage * damage_multiplier * damage_falloff

			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, global_position, 400.0, 0.2, player_ref, damage_type)
				dealt_damage.emit(enemy, final_damage)

			# Create hit effect
			_create_eruption_hit(enemy.global_position)

func _create_eruption_hit(pos: Vector2):
	var hit = ColorRect.new()
	hit.size = Vector2(40, 40)
	hit.color = FIRE_CORE
	hit.pivot_offset = Vector2(20, 20)
	hit.z_index = 100
	get_tree().current_scene.add_child(hit)
	hit.global_position = pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hit, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(hit, "modulate:a", 0.0, 0.2)
	tween.tween_callback(hit.queue_free)

func _create_lava_pool():
	# Create fire zone using FireZone scene
	var fire_zone_scene = preload("res://Scenes/Weapons/InfernoStaff/spells/FireZone.tscn")
	var fire_zone = fire_zone_scene.instantiate()
	get_tree().current_scene.add_child(fire_zone)

	fire_zone.initialize(
		global_position,
		lava_pool_damage * damage_multiplier,
		lava_pool_duration,
		volcano_radius * 0.8,
		player_ref
	)

	# Add bubbling lava effect on top
	_animate_lava_bubbles()

	# Signal completion after lava pool is created
	skill_completed.emit()

func _animate_lava_bubbles():
	var elapsed = 0.0
	var pool_radius = volcano_radius * 0.8

	while elapsed < lava_pool_duration:
		if not is_instance_valid(self):
			return

		var delta = get_process_delta_time()
		elapsed += delta

		# Spawn bubbling lava particles randomly within pool
		if randf() < 0.3:
			var bubble = ColorRect.new()
			bubble.size = Vector2(randf_range(8, 16), randf_range(8, 16))
			bubble.pivot_offset = bubble.size / 2
			bubble.color = LAVA_CORE if randf() > 0.4 else MAGMA_COLOR
			bubble.z_index = 100

			# Random position within pool
			var angle = randf() * TAU
			var dist = randf() * pool_radius * 0.9
			var spawn_pos = global_position + Vector2.from_angle(angle) * dist

			get_tree().current_scene.add_child(bubble)
			bubble.global_position = spawn_pos

			# Bubble rises and pops
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(bubble, "global_position:y", spawn_pos.y - randf_range(20, 40), 0.3)
			tween.tween_property(bubble, "scale", Vector2(1.5, 1.5), 0.15)
			tween.chain().tween_property(bubble, "scale", Vector2(0.2, 0.2), 0.15)
			tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
			tween.tween_callback(bubble.queue_free)

		await get_tree().process_frame

	queue_free()
