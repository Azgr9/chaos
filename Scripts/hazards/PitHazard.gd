# SCRIPT: PitHazard.gd
# ATTACH TO: Pit (Area2D) - Instant death pit hazard
# LOCATION: res://Scripts/hazards/PitHazard.gd

class_name PitHazard
extends Hazard

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.DEATH_ZONE
	activation_type = ActivationType.ALWAYS_ACTIVE
	is_instant_kill = true
	damage = 0.0  # Not used - instant kill

	# Pits are always active with no warning
	warning_duration = 0.0

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _handle_body_contact(body: Node2D) -> void:
	# Pit is always instant kill
	apply_instant_kill(body)
