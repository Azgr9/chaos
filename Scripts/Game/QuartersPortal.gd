# SCRIPT: QuartersPortal.gd
# ATTACH TO: QuartersPortal (Area2D) root node
# LOCATION: res://Scripts/Game/QuartersPortal.gd
# Portal that spawns after wave completion - enter for Quarters, attack to destroy for Bloodlust

class_name QuartersPortal
extends Area2D

# ============================================
# SIGNALS
# ============================================
signal portal_entered  # Player walked into portal -> go to Quarters
signal portal_destroyed  # Player attacked portal -> Bloodlust mode

# ============================================
# SETTINGS
# ============================================
@export var hits_to_destroy: int = 2  # Always dies in exactly 2 hits
@export var spawn_duration: float = 0.5  # Time to fully appear

# ============================================
# STATE
# ============================================
var current_hits: int = 0
var is_active: bool = false
var is_destroyed: bool = false

# Visual nodes (created in code)
var portal_visual: Node2D
var outer_ring: ColorRect
var inner_ring: ColorRect
var core: ColorRect
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect

# Colors
const PORTAL_COLOR := Color(0.3, 0.6, 1.0, 0.8)  # Blue portal
const PORTAL_CORE := Color(0.8, 0.9, 1.0, 1.0)  # Bright white-blue core
const BLOODLUST_COLOR := Color(1.0, 0.2, 0.1, 0.9)  # Red when damaged

func _ready():
	current_hits = 0
	add_to_group("portal")
	# Add to targetable group so weapons can hit it (separate from actual enemies)
	add_to_group("targetable")

	# Setup collision layers
	# Layer 4 = enemies (so weapons can detect us)
	# Mask 2 = player body (so we detect player entering)
	collision_layer = 4
	collision_mask = 2

	# Setup collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 60.0
	collision.shape = shape
	add_child(collision)

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Create visuals
	_create_visuals()

	# Spawn animation
	_play_spawn_animation()

func _create_visuals():
	portal_visual = Node2D.new()
	add_child(portal_visual)

	# Outer ring (largest, semi-transparent)
	outer_ring = ColorRect.new()
	outer_ring.size = Vector2(120, 120)
	outer_ring.position = Vector2(-60, -60)
	outer_ring.pivot_offset = Vector2(60, 60)
	outer_ring.color = Color(PORTAL_COLOR.r, PORTAL_COLOR.g, PORTAL_COLOR.b, 0.3)
	portal_visual.add_child(outer_ring)

	# Inner ring
	inner_ring = ColorRect.new()
	inner_ring.size = Vector2(80, 80)
	inner_ring.position = Vector2(-40, -40)
	inner_ring.pivot_offset = Vector2(40, 40)
	inner_ring.color = Color(PORTAL_COLOR.r, PORTAL_COLOR.g, PORTAL_COLOR.b, 0.6)
	portal_visual.add_child(inner_ring)

	# Core (brightest center)
	core = ColorRect.new()
	core.size = Vector2(40, 40)
	core.position = Vector2(-20, -20)
	core.pivot_offset = Vector2(20, 20)
	core.color = PORTAL_CORE
	portal_visual.add_child(core)

	# Health bar background
	health_bar_bg = ColorRect.new()
	health_bar_bg.size = Vector2(80, 8)
	health_bar_bg.position = Vector2(-40, 70)
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	portal_visual.add_child(health_bar_bg)

	# Health bar fill
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(80, 8)
	health_bar_fill.position = Vector2(-40, 70)
	health_bar_fill.color = PORTAL_COLOR
	portal_visual.add_child(health_bar_fill)

	# "ENTER" or "DESTROY" hint text
	var hint_label = Label.new()
	hint_label.text = "ENTER or ATTACK"
	hint_label.position = Vector2(-60, -90)
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.modulate = Color(1, 1, 1, 0.8)
	portal_visual.add_child(hint_label)

func _process(_delta):
	if not is_active or is_destroyed:
		return

	# Rotate rings for visual effect
	outer_ring.rotation += _delta * 0.5
	inner_ring.rotation -= _delta * 0.8

	# Pulse core
	var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.1
	core.scale = Vector2(pulse, pulse)

func _play_spawn_animation():
	portal_visual.scale = Vector2.ZERO
	portal_visual.modulate.a = 0.0

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(portal_visual, "scale", Vector2.ONE, spawn_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portal_visual, "modulate:a", 1.0, spawn_duration)
	tween.chain().tween_callback(func(): is_active = true)

	# Spawn particles
	_spawn_appear_particles()

func _spawn_appear_particles():
	var parent = get_parent()
	if not parent:
		return

	for i in range(12):
		var particle = ColorRect.new()
		particle.size = Vector2(10, 10)
		particle.color = PORTAL_COLOR
		particle.pivot_offset = Vector2(5, 5)
		parent.add_child(particle)
		particle.global_position = global_position

		var angle = (TAU / 12) * i
		var dir = Vector2.from_angle(angle)
		var end_pos = global_position + dir * 100

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", end_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), 0.4)
		tween.chain().tween_callback(particle.queue_free)

func _on_body_entered(body: Node2D):
	if not is_active or is_destroyed:
		return

	if body.is_in_group("player"):
		_enter_portal()

func _enter_portal():
	is_active = false

	# Visual feedback - bright flash and expand
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(portal_visual, "scale", Vector2(3, 3), 0.3)
	tween.tween_property(portal_visual, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(func():
		portal_entered.emit()
		queue_free()
	)

	# Screen effect
	if DamageNumberManager:
		DamageNumberManager.shake(0.3)

func take_damage(_amount: float, _from_position: Vector2 = Vector2.ZERO, _knockback: float = 0.0, _stun: float = 0.0, _attacker: Node2D = null, _damage_type: int = 0):
	if not is_active or is_destroyed:
		return

	current_hits += 1

	# Update health bar based on hits
	var health_percent = 1.0 - (float(current_hits) / float(hits_to_destroy))
	health_bar_fill.size.x = 80 * max(health_percent, 0.0)

	# Flash red on damage
	_flash_damage()

	# Spawn damage number showing hits remaining
	if DamageNumberManager:
		DamageNumberManager.spawn(global_position, hits_to_destroy - current_hits)

	if current_hits >= hits_to_destroy:
		_destroy_portal()

func _flash_damage():
	# Brief red flash
	var original_colors = {
		"outer": outer_ring.color,
		"inner": inner_ring.color,
		"core": core.color
	}

	outer_ring.color = BLOODLUST_COLOR
	inner_ring.color = BLOODLUST_COLOR
	core.color = Color.WHITE

	var tween = TweenHelper.new_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		if is_instance_valid(outer_ring):
			outer_ring.color = original_colors["outer"]
		if is_instance_valid(inner_ring):
			inner_ring.color = original_colors["inner"]
		if is_instance_valid(core):
			core.color = original_colors["core"]
	)

func _destroy_portal():
	is_destroyed = true
	is_active = false

	# Bloodlust activation effect - red explosion
	_spawn_destruction_particles()

	# Screen shake
	if DamageNumberManager:
		DamageNumberManager.shake(0.5)

	# Collapse animation
	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(portal_visual, "scale", Vector2(0.1, 0.1), 0.2)
	tween.tween_property(portal_visual, "modulate", BLOODLUST_COLOR, 0.1)
	tween.tween_property(portal_visual, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func():
		portal_destroyed.emit()
		queue_free()
	)

func _spawn_destruction_particles():
	var parent = get_parent()
	if not parent:
		return

	# Red/orange particles exploding outward
	for i in range(16):
		var particle = ColorRect.new()
		particle.size = Vector2(15, 15)
		particle.color = BLOODLUST_COLOR if randf() > 0.3 else Color(1.0, 0.5, 0.1)
		particle.pivot_offset = Vector2(7.5, 7.5)
		parent.add_child(particle)
		particle.global_position = global_position

		var angle = (TAU / 16) * i + randf_range(-0.2, 0.2)
		var dir = Vector2.from_angle(angle)
		var dist = randf_range(80, 150)
		var end_pos = global_position + dir * dist

		var tween = TweenHelper.new_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", end_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), 0.35)
		tween.tween_property(particle, "modulate:a", 0.0, 0.35)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.35)
		tween.chain().tween_callback(particle.queue_free)
