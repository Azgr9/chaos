# SCRIPT: FireGrateHazard.gd
# ATTACH TO: FireGrate (Area2D) - Damage over time zone hazard
# LOCATION: res://Scripts/hazards/FireGrateHazard.gd

class_name FireGrateHazard
extends Hazard

# ============================================
# FIRE SETTINGS
# ============================================
@export_group("Fire Settings")
@export var damage_per_second: float = 15.0
@export var damage_tick_rate: float = 0.25  # Damage every 0.25 seconds

# ============================================
# NODE REFERENCES
# ============================================
@onready var grate_sprite: ColorRect = $GrateSprite if has_node("GrateSprite") else null
@onready var fire_particles: Node2D = $FireParticles if has_node("FireParticles") else null
@onready var glow_light: PointLight2D = $GlowLight if has_node("GlowLight") else null

# ============================================
# STATE
# ============================================
var damage_timer: float = 0.0
var bodies_on_grate: Array[Node2D] = []
var fire_flicker_timer: float = 0.0

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.ZONE
	activation_type = ActivationType.ALWAYS_ACTIVE
	is_instant_kill = false

	# Calculate tick damage
	damage = damage_per_second * damage_tick_rate

# ============================================
# PROCESS
# ============================================
func _process(delta: float) -> void:
	if not is_active:
		return

	# Update fire visual effects
	_update_fire_visuals(delta)

	# Damage tick timer
	damage_timer += delta
	if damage_timer >= damage_tick_rate:
		damage_timer = 0.0
		_apply_damage_tick()

func _update_fire_visuals(delta: float) -> void:
	fire_flicker_timer += delta

	# Flicker the fire particles (simulate randomness)
	if fire_particles:
		var flicker = 0.8 + sin(fire_flicker_timer * 15.0) * 0.2
		fire_particles.modulate.a = flicker

	# Flicker the glow light
	if glow_light:
		var light_flicker = 0.7 + sin(fire_flicker_timer * 12.0) * 0.3
		glow_light.energy = light_flicker

	# Slight color variation on the grate
	if grate_sprite and active_sprite:
		var heat_pulse = 0.9 + sin(fire_flicker_timer * 8.0) * 0.1
		# Subtle red-orange pulse
		active_sprite.modulate = Color(1.0, heat_pulse, heat_pulse * 0.8, 1.0)

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	if body not in bodies_on_grate:
		bodies_on_grate.append(body)

	# Immediate first tick of damage when entering
	if is_active:
		apply_tick_damage(body)

func _on_body_exited(body: Node2D) -> void:
	bodies_in_hazard.erase(body)
	bodies_on_grate.erase(body)

func _handle_body_contact(body: Node2D) -> void:
	# DoT is handled in _process, but add to tracking
	if body not in bodies_on_grate:
		bodies_on_grate.append(body)
		apply_tick_damage(body)

# ============================================
# DAMAGE SYSTEM
# ============================================
func _apply_damage_tick() -> void:
	# Clean up invalid bodies
	var valid_bodies: Array[Node2D] = []
	for body in bodies_on_grate:
		if is_instance_valid(body):
			valid_bodies.append(body)
	bodies_on_grate = valid_bodies

	# Apply damage to all bodies on grate
	for body in bodies_on_grate:
		apply_tick_damage(body)

func apply_tick_damage(body: Node2D) -> void:
	if not is_instance_valid(body):
		return

	var tick_damage = damage_per_second * damage_tick_rate

	# Apply fire resistance for player
	var final_damage = _calculate_fire_damage(body, tick_damage)
	if final_damage <= 0:
		return

	var damage_applied = false
	if body.has_method("take_damage"):
		if body.is_in_group("player"):
			damage_applied = body.take_damage(final_damage, global_position)
			# Spawn fire damage number for player (player doesn't spawn its own)
			if damage_applied and randf() < 0.5:
				_spawn_fire_damage_number(body, final_damage)
		else:
			# Pass FIRE damage type to enemy so it spawns orange damage number
			body.take_damage(final_damage, Vector2.ZERO, 0.0, 0.0, null, DamageTypes.Type.FIRE)
			damage_applied = true

	# Only show effects if damage was actually applied
	if damage_applied:
		body_damaged.emit(body, final_damage)
		_play_sizzle_effect(body)

func _calculate_fire_damage(body: Node2D, base_damage: float) -> float:
	if not body.is_in_group("player"):
		return base_damage

	if not "stats" in body or body.stats == null:
		return base_damage

	var final_damage = base_damage
	var stats = body.stats

	# General hazard resistance
	if "hazard_resistance" in stats:
		final_damage *= (1.0 - stats.hazard_resistance)

	# Fire-specific resistance
	if "fire_resistance" in stats:
		final_damage *= (1.0 - stats.fire_resistance)

	return final_damage

func _spawn_fire_damage_number(body: Node2D, damage_amount: float) -> void:
	DamageNumberManager.spawn(body.global_position, damage_amount, DamageTypes.Type.FIRE)

func _play_sizzle_effect(_body: Node2D) -> void:
	# Disabled - was causing permanent color changes due to overlapping tweens
	# The orange damage numbers provide enough visual feedback
	pass

# ============================================
# UTILITY
# ============================================
func get_bodies_count() -> int:
	return bodies_on_grate.size()

func is_body_on_fire(body: Node2D) -> bool:
	return body in bodies_on_grate
