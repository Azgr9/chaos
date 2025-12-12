# SCRIPT: Hazard.gd
# ATTACH TO: Hazard (Area2D) - Base scene for all hazards
# LOCATION: res://Scripts/hazards/Hazard.gd

class_name Hazard
extends Area2D

# ============================================
# ENUMS
# ============================================
enum HazardType {
	DEATH_ZONE,  # Instant kill (pits)
	IMPACT,      # Damage on high-velocity collision (spike walls)
	HIDDEN,      # Triggered traps (floor spikes)
	TIMED,       # Periodic activation (crushers)
	ZONE         # Continuous damage while inside (fire grates)
}

enum ActivationType {
	ALWAYS_ACTIVE,  # Always deals damage
	ON_CONTACT,     # Triggers when touched
	ON_IMPACT,      # Only damages on high-velocity contact
	DELAYED,        # Delay before activation
	PERIODIC        # Activates on a timer
}

# ============================================
# PRELOADED SCENES
# ============================================
const DamageNumber = preload("res://Scenes/Ui/DamageNumber.tscn")

# ============================================
# EXPORTED PROPERTIES
# ============================================
@export_group("Hazard Settings")
@export var hazard_type: HazardType = HazardType.ZONE
@export var activation_type: ActivationType = ActivationType.ALWAYS_ACTIVE
@export var damage: float = 0.0
@export var is_instant_kill: bool = false

@export_group("Targeting")
@export var affects_player: bool = true
@export var affects_enemies: bool = true

@export_group("Timing")
@export var warning_duration: float = 1.5

@export_group("Visual")
@export var hazard_size: Vector2 = Vector2(64, 64)

# ============================================
# NODE REFERENCES
# ============================================
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var warning_sprite: Sprite2D = $WarningSprite if has_node("WarningSprite") else null
@onready var active_sprite: Sprite2D = $ActiveSprite if has_node("ActiveSprite") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# ============================================
# STATE
# ============================================
var is_active: bool = false
var is_warning: bool = false
var bodies_in_hazard: Array[Node2D] = []

# ============================================
# SIGNALS
# ============================================
signal hazard_activated()
signal hazard_deactivated()
signal body_damaged(body: Node2D, damage_amount: float)
signal body_killed(body: Node2D)

# ============================================
# LIFECYCLE
# ============================================
func _ready() -> void:
	add_to_group("hazards")

	# Connect body signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Setup collision
	_setup_collision()

	# Call subclass setup FIRST so it can modify warning_duration etc
	_setup_hazard()

	# Start in warning state
	if warning_duration > 0:
		show_warning()
	else:
		activate()

	print("[Hazard] Spawned %s at %s (type=%d, damage=%d, instant_kill=%s)" % [name, global_position, hazard_type, int(damage), is_instant_kill])

func _setup_collision() -> void:
	# Set collision layer to hazards (layer 11)
	collision_layer = 1 << 10  # Layer 11 (0-indexed)
	# Detect player (layer 2, collision_layer=2) and enemies (layer 3, collision_layer=4)
	# Player CharacterBody2D is on layer 2, Enemy CharacterBody2D is on layer 3
	collision_mask = (1 << 1) | (1 << 2)  # Layers 2 and 3 = bits 1 and 2 = 2 + 4 = 6

# ============================================
# VIRTUAL METHODS - Override in subclasses
# ============================================
func _setup_hazard() -> void:
	# Override in child classes for specific setup
	pass

func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	print("[Hazard] %s entered %s (is_active=%s, is_warning=%s)" % [body.name, name, is_active, is_warning])

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	if is_active:
		_handle_body_contact(body)

func _on_body_exited(body: Node2D) -> void:
	bodies_in_hazard.erase(body)

func _handle_body_contact(body: Node2D) -> void:
	# Override in subclasses for specific contact behavior
	if is_instant_kill:
		apply_instant_kill(body)
	elif damage > 0:
		apply_damage(body)

# ============================================
# ACTIVATION SYSTEM
# ============================================
func show_warning() -> void:
	is_warning = true
	is_active = false

	# Show warning visual
	if warning_sprite:
		warning_sprite.visible = true
	if active_sprite:
		active_sprite.visible = false

	# Play warning animation if available
	if animation_player and animation_player.has_animation("warning_pulse"):
		animation_player.play("warning_pulse")

	# Auto-activate after warning duration
	await get_tree().create_timer(warning_duration).timeout
	activate()

func activate() -> void:
	is_warning = false
	is_active = true

	# Update visuals
	if warning_sprite:
		warning_sprite.visible = false
	if active_sprite:
		active_sprite.visible = true

	# Play idle animation if available
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

	hazard_activated.emit()

	# Process any bodies already in the hazard
	for body in bodies_in_hazard:
		if is_instance_valid(body):
			_handle_body_contact(body)

func deactivate() -> void:
	is_active = false
	is_warning = false

	if active_sprite:
		active_sprite.visible = false

	hazard_deactivated.emit()

# ============================================
# DAMAGE SYSTEM
# ============================================
func can_affect(body: Node2D) -> bool:
	if body.is_in_group("player") and affects_player:
		return true
	if body.is_in_group("enemies") and affects_enemies:
		return true
	return false

func apply_damage(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	# Calculate final damage after resistances
	var final_damage = _calculate_damage_after_resistance(body, damage)

	# Debug print
	var type_name = _get_hazard_type_name()
	print("[Hazard] %s dealing %.1f damage to %s (base: %.1f, after resistance: %.1f)" % [type_name, final_damage, body.name, damage, final_damage])

	# If fully resisted, skip
	if final_damage <= 0:
		print("[Hazard] Damage fully resisted!")
		return

	if body.has_method("take_damage"):
		# Player has signature: take_damage(amount, from_position)
		# Enemy has signature: take_damage(amount, from_position, knockback_power, stun_duration)
		if body.is_in_group("player"):
			body.take_damage(final_damage, global_position)
		else:
			body.take_damage(final_damage, global_position, 0.0, 0.0, null)  # Hazards dont trigger thorns

		body_damaged.emit(body, final_damage)
		_spawn_damage_number(body, final_damage)

func _get_hazard_type_name() -> String:
	match hazard_type:
		HazardType.DEATH_ZONE: return "Pit"
		HazardType.IMPACT: return "SpikeWall"
		HazardType.HIDDEN: return "FloorSpikes"
		HazardType.TIMED: return "Crusher"
		HazardType.ZONE: return "FireGrate"
	return "Unknown"

func _calculate_damage_after_resistance(body: Node2D, base_damage: float) -> float:
	# Only player has resistance stats
	if not body.is_in_group("player"):
		return base_damage

	if not "stats" in body or body.stats == null:
		return base_damage

	var stats = body.stats
	var final_damage = base_damage

	# Apply general hazard resistance
	if "hazard_resistance" in stats:
		final_damage *= (1.0 - stats.hazard_resistance)

	# Apply type-specific resistance
	match hazard_type:
		HazardType.ZONE:  # Fire grates
			if "fire_resistance" in stats:
				final_damage *= (1.0 - stats.fire_resistance)
		HazardType.HIDDEN, HazardType.IMPACT:  # Floor spikes, spike walls
			if "spike_resistance" in stats:
				final_damage *= (1.0 - stats.spike_resistance)
		HazardType.TIMED:  # Crushers - apply spike resistance too
			if "spike_resistance" in stats:
				final_damage *= (1.0 - stats.spike_resistance)

	return final_damage

func apply_instant_kill(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	var type_name = _get_hazard_type_name()
	print("[Hazard] %s INSTANT KILL on %s at position %s!" % [type_name, body.name, global_position])

	# Check for pit immunity (player only)
	if body.is_in_group("player") and hazard_type == HazardType.DEATH_ZONE:
		if "stats" in body and body.stats != null:
			if "pit_immunity" in body.stats and body.stats.pit_immunity:
				# Player survives! Teleport them to safety
				_rescue_from_pit(body)
				return

	body_killed.emit(body)

	if body.has_method("die"):
		print("[Hazard] Calling die() on %s" % body.name)
		body.die()
	elif body.has_method("take_damage"):
		# Deal massive damage as fallback
		print("[Hazard] Calling take_damage(9999) on %s" % body.name)
		if body.is_in_group("player"):
			body.take_damage(9999.0, global_position)
		else:
			body.take_damage(9999.0, global_position, 0.0, 0.0, null)

func _rescue_from_pit(body: Node2D) -> void:
	# Find a safe position away from the pit
	var safe_offset = Vector2(100, 0).rotated(randf() * TAU)
	var safe_pos = global_position + safe_offset

	# Re-enable physics processing if it was disabled
	if body.has_method("set_physics_process"):
		body.set_physics_process(true)

	# Reset velocity
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	# Teleport to safety
	body.global_position = safe_pos

	# Reset visual effects (scale, rotation, modulate)
	var visual_node = body.get_node_or_null("VisualsPivot")
	if visual_node:
		visual_node.scale = Vector2.ONE
		visual_node.rotation = 0
		visual_node.modulate.a = 1.0

	# Small screen shake for feedback
	add_screen_shake(0.2)

	print("[Hazard] Player rescued from pit by Feather Fall!")

func _spawn_damage_number(body: Node2D, damage_amount: float) -> void:
	var damage_number = DamageNumber.instantiate()
	damage_number.global_position = body.global_position + Vector2(0, -20)
	get_tree().current_scene.add_child(damage_number)
	damage_number.setup(damage_amount)

# ============================================
# UTILITY
# ============================================
func add_screen_shake(trauma_amount: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(trauma_amount)

func get_hazard_center() -> Vector2:
	return global_position
