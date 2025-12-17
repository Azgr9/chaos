# SCRIPT: FireZone.gd
# ATTACH TO: FireZone (Node2D) root node in FireZone.tscn
# LOCATION: res://Scripts/Spells/FireZone.gd
# Burning ground zone - damages enemies AND player who stand in it (risk/reward)

extends Node2D

# ============================================
# FIRE ZONE SETTINGS
# ============================================
var damage_per_second: float = 8.0
var duration: float = 5.0
var radius: float = 64.0
var owner_ref: Node2D = null  # Who created this zone

# Damage tick rate
const TICK_RATE: float = 0.5  # Damage every 0.5 seconds
var tick_timer: float = 0.0
var time_alive: float = 0.0

# Visual nodes
@onready var visual: Node2D = $Visual
@onready var damage_area: Area2D = $DamageArea
@onready var collision_shape: CollisionShape2D = $DamageArea/CollisionShape2D

# Tracking who's in the zone
var entities_in_zone: Array = []

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	# Connect area signals
	damage_area.area_entered.connect(_on_area_entered)
	damage_area.area_exited.connect(_on_area_exited)
	damage_area.body_entered.connect(_on_body_entered)
	damage_area.body_exited.connect(_on_body_exited)

	# Start spawn animation
	_spawn_animation()

func initialize(pos: Vector2, dps: float, dur: float, rad: float, zone_owner: Node2D = null):
	global_position = pos
	damage_per_second = dps
	duration = dur
	radius = rad
	owner_ref = zone_owner

	# Update collision shape size
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = radius

func _process(delta):
	time_alive += delta
	tick_timer += delta

	# Damage tick
	if tick_timer >= TICK_RATE:
		tick_timer = 0.0
		_deal_tick_damage()

	# Update visual (animated flames)
	_update_flames(delta)

	# Check duration
	if time_alive >= duration:
		_despawn()

func _deal_tick_damage():
	var tick_damage = damage_per_second * TICK_RATE

	# Clean up invalid references
	entities_in_zone = entities_in_zone.filter(func(e): return is_instance_valid(e))

	for entity in entities_in_zone:
		if not is_instance_valid(entity):
			continue

		# Check if it's the player - Player.take_damage(amount, from_position) only takes 2 args
		if entity.is_in_group("player") and entity.has_method("take_damage"):
			# Check for fire immunity
			if "is_fire_immune" in entity and entity.is_fire_immune:
				continue  # Skip damage, player is immune

			# Player takes damage too! Risk/reward mechanic
			entity.take_damage(tick_damage, global_position)
			_create_burn_effect(entity.global_position)
		# For enemies - Enemy.take_damage takes more args
		elif entity.has_method("take_damage"):
			entity.take_damage(tick_damage, global_position, 0.0, 0.0, owner_ref)
			dealt_damage.emit(entity, tick_damage)
			_create_burn_effect(entity.global_position)

func _update_flames(_delta):
	# Animate flame visuals
	for child in visual.get_children():
		if child is ColorRect:
			# Flicker effect
			var flicker = 0.7 + randf() * 0.3
			child.modulate.a = flicker

			# Slight movement
			child.position.y = sin(time_alive * 10 + child.get_index()) * 3

	# Fade out near end
	if time_alive > duration - 1.0:
		var fade = (duration - time_alive) / 1.0
		modulate.a = fade

func _spawn_animation():
	# Start small, grow to full size
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

	# Initial burst effect
	_create_spawn_burst()

func _create_spawn_burst():
	# Fire particles burst outward
	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = Color(1.0, 0.5, 0.1, 0.9)
		particle.pivot_offset = Vector2(6, 6)
		get_tree().current_scene.add_child(particle)
		particle.global_position = global_position

		var angle = (TAU / 12) * i
		var dir = Vector2.from_angle(angle)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position + dir * radius * 1.2, 0.3)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.3)
		tween.tween_callback(particle.queue_free)

func _create_burn_effect(pos: Vector2):
	# Small flame particle at damage position
	var flame = ColorRect.new()
	flame.size = Vector2(10, 16)
	flame.color = Color(1.0, randf_range(0.3, 0.6), 0.1, 0.8)
	flame.pivot_offset = Vector2(5, 16)
	get_tree().current_scene.add_child(flame)
	flame.global_position = pos + Vector2(randf_range(-10, 10), 0)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flame, "global_position:y", pos.y - 30, 0.4)
	tween.tween_property(flame, "modulate:a", 0.0, 0.4)
	tween.tween_property(flame, "scale", Vector2(0.5, 1.5), 0.4)
	tween.tween_callback(flame.queue_free)

func _despawn():
	# Fade out and cleanup
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_callback(queue_free)

# ============================================
# ZONE DETECTION
# ============================================
func _on_area_entered(area: Area2D):
	var parent = area.get_parent()
	if parent and parent not in entities_in_zone:
		# Add enemies
		if parent.is_in_group("enemies"):
			entities_in_zone.append(parent)

func _on_area_exited(area: Area2D):
	var parent = area.get_parent()
	if parent in entities_in_zone:
		entities_in_zone.erase(parent)

func _on_body_entered(body: Node2D):
	if body not in entities_in_zone:
		# Add player or other bodies
		if body.is_in_group("player") or body.is_in_group("enemies"):
			entities_in_zone.append(body)

func _on_body_exited(body: Node2D):
	if body in entities_in_zone:
		entities_in_zone.erase(body)
