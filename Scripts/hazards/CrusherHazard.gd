# SCRIPT: CrusherHazard.gd
# ATTACH TO: Crusher (Node2D) - Timed periodic slam hazard
# LOCATION: res://Scripts/hazards/CrusherHazard.gd

class_name CrusherHazard
extends Hazard

# ============================================
# ENUMS
# ============================================
enum CrusherState {
	RAISED,    # Crusher is up, waiting
	WARNING,   # Shadow appears, crusher about to slam
	SLAMMING,  # Crusher coming down fast
	DOWN,      # Crusher on ground
	RISING     # Crusher going back up
}

# ============================================
# CRUSHER SETTINGS
# ============================================
@export_group("Timing")
@export var cycle_time: float = 3.0        # Full cycle duration
@export var warning_time: float = 1.0      # Shadow appears before slam
@export var slam_time: float = 0.1         # Actual slam (very fast!)
@export var down_time: float = 0.5         # Stays down
@export var rise_time: float = 0.5         # Goes back up

@export_group("Damage")
@export var crusher_damage: float = 100.0  # Massive damage (basically instant kill)

# ============================================
# NODE REFERENCES
# ============================================
@onready var crusher_body: Node2D = $CrusherBody if has_node("CrusherBody") else null
@onready var shadow: ColorRect = $Shadow if has_node("Shadow") else null
@onready var danger_zone: Area2D = $DangerZone if has_node("DangerZone") else null

# ============================================
# STATE
# ============================================
var current_state: CrusherState = CrusherState.RAISED
var state_timer: float = 0.0
var bodies_in_danger_zone: Array[Node2D] = []

# Visual properties
var crusher_raised_y: float = -80.0
var crusher_down_y: float = 0.0

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.TIMED
	activation_type = ActivationType.PERIODIC
	damage = crusher_damage
	is_instant_kill = false  # We'll deal massive damage instead

	# Initialize crusher position
	if crusher_body:
		crusher_body.position.y = crusher_raised_y

	# Hide shadow initially
	if shadow:
		shadow.visible = false
		shadow.modulate.a = 0.0

	# Connect danger zone signals if exists
	if danger_zone:
		danger_zone.body_entered.connect(_on_danger_zone_body_entered)
		danger_zone.body_exited.connect(_on_danger_zone_body_exited)

	# Start the cycle timer (start raised)
	state_timer = 0.0

func _ready() -> void:
	super._ready()

	# Crusher has its own collision detection via DangerZone
	# Disable the base Area2D collision - we use it for DangerZone child instead
	if collision_shape:
		collision_shape.disabled = true

# ============================================
# PROCESS
# ============================================
func _process(delta: float) -> void:
	if not is_active:
		return

	state_timer += delta

	match current_state:
		CrusherState.RAISED:
			if state_timer >= cycle_time - warning_time:
				enter_warning_state()

		CrusherState.WARNING:
			_update_warning_visuals(delta)
			if state_timer >= cycle_time:
				enter_slam_state()

		CrusherState.SLAMMING:
			# Handled by tween callback
			pass

		CrusherState.DOWN:
			if state_timer >= down_time:
				enter_rising_state()

		CrusherState.RISING:
			if state_timer >= rise_time:
				enter_raised_state()

# ============================================
# STATE MACHINE
# ============================================
func enter_warning_state() -> void:
	current_state = CrusherState.WARNING

	# Show shadow
	if shadow:
		shadow.visible = true

		# Pulse shadow in
		var tween = create_tween()
		tween.tween_property(shadow, "modulate:a", 0.6, 0.2)

func _update_warning_visuals(_delta: float) -> void:
	if not shadow:
		return

	# Calculate warning progress (0 to 1)
	var warning_elapsed = state_timer - (cycle_time - warning_time)
	var progress = warning_elapsed / warning_time

	# Pulse shadow faster as slam approaches
	var pulse_speed = lerp(3.0, 12.0, progress)
	var pulse = 0.4 + abs(sin(state_timer * pulse_speed)) * 0.4

	shadow.modulate.a = pulse

	# Make shadow grow slightly
	var scale_factor = lerp(0.9, 1.1, progress)
	shadow.scale = Vector2(scale_factor, scale_factor)

func enter_slam_state() -> void:
	current_state = CrusherState.SLAMMING

	# Make shadow fully visible
	if shadow:
		shadow.modulate.a = 0.8

	# Animate crusher slamming down FAST
	if crusher_body:
		var tween = create_tween()
		tween.tween_property(crusher_body, "position:y", crusher_down_y, slam_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(_on_slam_complete)

func _on_slam_complete() -> void:
	# Deal damage to all bodies in danger zone
	_damage_bodies_in_zone()

	# Screen shake
	add_screen_shake(0.5)

	# Spawn impact particles
	_spawn_impact_particles()

	# Enter down state
	enter_down_state()

func _damage_bodies_in_zone() -> void:
	for body in bodies_in_danger_zone.duplicate():
		if is_instance_valid(body) and can_affect(body):
			if body.has_method("take_damage"):
				if body.is_in_group("player"):
					body.take_damage(crusher_damage, global_position)
				else:
					# Pass SPIKE damage type for gray damage numbers
					body.take_damage(crusher_damage, global_position, 200.0, 0.3, null, DamageTypes.Type.SPIKE)

				body_damaged.emit(body, crusher_damage)

func enter_down_state() -> void:
	current_state = CrusherState.DOWN
	state_timer = 0.0

func enter_rising_state() -> void:
	current_state = CrusherState.RISING
	state_timer = 0.0

	# Animate crusher rising
	if crusher_body:
		var tween = create_tween()
		tween.tween_property(crusher_body, "position:y", crusher_raised_y, rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Fade shadow
	if shadow:
		var tween = create_tween()
		tween.tween_property(shadow, "modulate:a", 0.0, rise_time * 0.8)

func enter_raised_state() -> void:
	current_state = CrusherState.RAISED
	state_timer = 0.0

	# Hide shadow
	if shadow:
		shadow.visible = false
		shadow.scale = Vector2.ONE

# ============================================
# DANGER ZONE DETECTION
# ============================================
func _on_danger_zone_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_danger_zone:
		bodies_in_danger_zone.append(body)

func _on_danger_zone_body_exited(body: Node2D) -> void:
	bodies_in_danger_zone.erase(body)

# ============================================
# VISUAL EFFECTS
# ============================================
func _spawn_impact_particles() -> void:
	var particle_count = 8

	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(8, 8)
		particle.color = Color(0.5, 0.4, 0.35, 1)  # Dust/debris color
		particle.global_position = global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		get_tree().current_scene.add_child(particle)

		var tween = create_tween()
		var fly_dir = Vector2(randf_range(-1, 1), randf_range(-1, 0)).normalized()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", particle.global_position + fly_dir * 80, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(particle.queue_free)

# ============================================
# UTILITY
# ============================================
func get_state_name() -> String:
	match current_state:
		CrusherState.RAISED: return "RAISED"
		CrusherState.WARNING: return "WARNING"
		CrusherState.SLAMMING: return "SLAMMING"
		CrusherState.DOWN: return "DOWN"
		CrusherState.RISING: return "RISING"
	return "UNKNOWN"

func is_safe() -> bool:
	return current_state == CrusherState.RAISED

func is_in_warning_state() -> bool:
	return current_state == CrusherState.WARNING

func is_dangerous() -> bool:
	return current_state in [CrusherState.SLAMMING, CrusherState.DOWN]
