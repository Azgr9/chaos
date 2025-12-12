# SCRIPT: PitHazard.gd
# ATTACH TO: Pit (Area2D) - Instant death pit hazard
# LOCATION: res://Scripts/hazards/PitHazard.gd

class_name PitHazard
extends Hazard

# ============================================
# FALL ANIMATION SETTINGS
# ============================================
@export_group("Fall Animation")
@export var fall_duration: float = 0.5
@export var shrink_scale: float = 0.1
@export var rotation_speed: float = 720.0  # Degrees per second

# ============================================
# STATE
# ============================================
var bodies_falling: Array[Node2D] = []

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.DEATH_ZONE
	activation_type = ActivationType.ALWAYS_ACTIVE
	is_instant_kill = true
	damage = 0.0  # Instant kill, no damage value needed

	# Pits are always visible - no warning needed
	warning_duration = 0.0

	# Force ActiveSprite visible immediately (get node directly since @onready may not be ready)
	var pit_sprite = get_node_or_null("ActiveSprite")
	if pit_sprite:
		pit_sprite.visible = true
		print("[PitHazard] ActiveSprite set to visible")
	else:
		print("[PitHazard] WARNING: ActiveSprite not found!")

	# Add to death zone group for enemy avoidance
	add_to_group("death_zone_hazards")

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	if is_active and body not in bodies_falling:
		play_fall_animation(body)

func _handle_body_contact(body: Node2D) -> void:
	# Override to use fall animation instead of instant kill
	if body not in bodies_falling:
		play_fall_animation(body)

# ============================================
# FALL ANIMATION
# ============================================
func play_fall_animation(body: Node2D) -> void:
	if body in bodies_falling:
		return

	bodies_falling.append(body)

	# Disable the body's movement/physics
	_disable_body_control(body)

	# Get the visual node to animate
	var visual_node = _get_visual_node(body)
	if not visual_node:
		visual_node = body

	# Move body behind other things (falling into pit)
	body.z_index = -10

	# Create fall animation tween
	var tween = create_tween()
	tween.set_parallel(true)

	# Move towards pit center
	tween.tween_property(body, "global_position", global_position, fall_duration).set_ease(Tween.EASE_IN)

	# Shrink down
	tween.tween_property(visual_node, "scale", Vector2(shrink_scale, shrink_scale), fall_duration).set_ease(Tween.EASE_IN)

	# Rotate while falling
	var total_rotation = deg_to_rad(rotation_speed * fall_duration)
	tween.tween_property(visual_node, "rotation", visual_node.rotation + total_rotation, fall_duration)

	# Fade out
	tween.tween_property(visual_node, "modulate:a", 0.0, fall_duration)

	# On animation complete, kill the body
	tween.chain().tween_callback(_on_fall_complete.bind(body))

func _on_fall_complete(body: Node2D) -> void:
	bodies_falling.erase(body)
	bodies_in_hazard.erase(body)

	if is_instance_valid(body):
		# Screen shake for dramatic effect
		add_screen_shake(0.4)

		# Apply instant kill
		apply_instant_kill(body)

# ============================================
# HELPER METHODS
# ============================================
func _disable_body_control(body: Node2D) -> void:
	# Disable player control
	if body.is_in_group("player"):
		if body.has_method("set_physics_process"):
			body.set_physics_process(false)
		# Set velocity to zero
		if body is CharacterBody2D:
			body.velocity = Vector2.ZERO

	# Disable enemy AI
	if body.is_in_group("enemies"):
		if "is_dead" in body:
			body.is_dead = true  # This stops the enemy from processing
		if body is CharacterBody2D:
			body.velocity = Vector2.ZERO

func _get_visual_node(body: Node2D) -> Node2D:
	# Try to find the visual pivot node for animation
	# Player has VisualsPivot, enemies might have Sprite2D directly

	if body.has_node("VisualsPivot"):
		return body.get_node("VisualsPivot")
	if body.has_node("Sprite2D"):
		return body.get_node("Sprite2D")
	if body.has_node("AnimatedSprite2D"):
		return body.get_node("AnimatedSprite2D")

	# Return the body itself as fallback
	return body
