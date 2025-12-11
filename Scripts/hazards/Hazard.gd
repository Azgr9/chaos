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

	# Start in warning state
	if warning_duration > 0:
		show_warning()
	else:
		activate()

	# Call subclass setup
	_setup_hazard()

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

	if body.has_method("take_damage"):
		# Player has signature: take_damage(amount, from_position)
		# Enemy has signature: take_damage(amount, from_position, knockback_power, stun_duration)
		if body.is_in_group("player"):
			body.take_damage(damage, global_position)
		else:
			body.take_damage(damage, global_position, 0.0, 0.0)  # No knockback from hazards by default

		body_damaged.emit(body, damage)
		_spawn_damage_number(body, damage)

func apply_instant_kill(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	body_killed.emit(body)

	if body.has_method("die"):
		body.die()
	elif body.has_method("take_damage"):
		# Deal massive damage as fallback
		if body.is_in_group("player"):
			body.take_damage(9999.0, global_position)
		else:
			body.take_damage(9999.0, global_position, 0.0, 0.0)

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
