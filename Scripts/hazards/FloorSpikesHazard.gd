# SCRIPT: FloorSpikesHazard.gd
# ATTACH TO: FloorSpikes (Area2D) - Hidden spike trap hazard
# LOCATION: res://Scripts/hazards/FloorSpikesHazard.gd

class_name FloorSpikesHazard
extends Hazard

# ============================================
# ENUMS
# ============================================
enum SpikeState {
	HIDDEN,      # Spikes retracted, trap is dormant
	TRIGGERED,   # Body stepped on, countdown to activation
	ACTIVE,      # Spikes extended, dealing damage
	RETRACTING,  # Spikes going back down
	COOLDOWN     # Waiting before becoming hidden again
}

# ============================================
# SPIKE SETTINGS
# ============================================
@export_group("Spike Settings")
@export var trigger_delay: float = 1.0
@export var active_duration: float = 0.5
@export var retract_duration: float = 0.3
@export var cooldown: float = 2.0
@export var spike_damage: float = 25.0

# ============================================
# NODE REFERENCES
# ============================================
@onready var floor_tile: ColorRect = $FloorTile if has_node("FloorTile") else null
@onready var spikes_sprite: Node2D = $SpikesSprite if has_node("SpikesSprite") else null
@onready var trigger_indicator: ColorRect = $TriggerIndicator if has_node("TriggerIndicator") else null

# ============================================
# STATE
# ============================================
var current_state: SpikeState = SpikeState.HIDDEN
var state_timer: float = 0.0
var triggered_by: Node2D = null

# ============================================
# SETUP
# ============================================
func _setup_hazard() -> void:
	hazard_type = HazardType.HIDDEN
	activation_type = ActivationType.DELAYED
	damage = spike_damage
	is_instant_kill = false

	# Hide spikes initially
	if spikes_sprite:
		spikes_sprite.visible = false
		spikes_sprite.position.y = 0  # Will animate up when popping

	if trigger_indicator:
		trigger_indicator.visible = false

# ============================================
# PROCESS
# ============================================
func _process(delta: float) -> void:
	if not is_active:
		return

	state_timer += delta

	match current_state:
		SpikeState.HIDDEN:
			# Wait for body to step on
			pass

		SpikeState.TRIGGERED:
			_update_trigger_warning(delta)
			if state_timer >= trigger_delay:
				pop_spikes()

		SpikeState.ACTIVE:
			if state_timer >= active_duration:
				retract_spikes()

		SpikeState.RETRACTING:
			if state_timer >= retract_duration:
				enter_cooldown()

		SpikeState.COOLDOWN:
			if state_timer >= cooldown:
				reset_to_hidden()

# ============================================
# BODY CONTACT HANDLING
# ============================================
func _on_body_entered(body: Node2D) -> void:
	if not can_affect(body):
		return

	if body not in bodies_in_hazard:
		bodies_in_hazard.append(body)

	# Trigger the trap if hidden
	if is_active and current_state == SpikeState.HIDDEN:
		trigger_spikes(body)

func _handle_body_contact(body: Node2D) -> void:
	# Only deal damage when spikes are active
	if current_state == SpikeState.ACTIVE:
		apply_damage(body)

# ============================================
# STATE MACHINE
# ============================================
func trigger_spikes(body: Node2D) -> void:
	if current_state != SpikeState.HIDDEN:
		return

	current_state = SpikeState.TRIGGERED
	state_timer = 0.0
	triggered_by = body

	# Show warning indicator
	if trigger_indicator:
		trigger_indicator.visible = true
		trigger_indicator.modulate = Color(1, 0.5, 0, 0.8)

	# Play warning animation - rumble effect
	_play_trigger_warning()

func _play_trigger_warning() -> void:
	if not floor_tile:
		return

	# Shake/rumble effect
	var tween = create_tween()
	tween.set_loops(int(trigger_delay / 0.1))

	tween.tween_property(floor_tile, "position:x", 2.0, 0.05)
	tween.tween_property(floor_tile, "position:x", -2.0, 0.05)

	tween.chain().tween_property(floor_tile, "position:x", 0.0, 0.05)

func _update_trigger_warning(_delta: float) -> void:
	# Pulse the warning indicator faster as time runs out
	if trigger_indicator:
		var progress = state_timer / trigger_delay
		var pulse_speed = lerp(2.0, 10.0, progress)
		var pulse = abs(sin(state_timer * pulse_speed))
		trigger_indicator.modulate.a = lerp(0.4, 1.0, pulse)

		# Change color from orange to red
		trigger_indicator.color = Color(1, lerp(0.5, 0.0, progress), 0, 1)

func pop_spikes() -> void:
	current_state = SpikeState.ACTIVE
	state_timer = 0.0

	# Hide warning
	if trigger_indicator:
		trigger_indicator.visible = false

	# Show and animate spikes popping up
	if spikes_sprite:
		spikes_sprite.visible = true
		spikes_sprite.position.y = 20  # Start below

		var tween = create_tween()
		tween.tween_property(spikes_sprite, "position:y", 0.0, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Screen shake
	add_screen_shake(0.25)

	# Damage ALL bodies currently on the tile
	for body in bodies_in_hazard.duplicate():
		if is_instance_valid(body) and can_affect(body):
			apply_damage(body)

func retract_spikes() -> void:
	current_state = SpikeState.RETRACTING
	state_timer = 0.0

	# Animate spikes going down
	if spikes_sprite:
		var tween = create_tween()
		tween.tween_property(spikes_sprite, "position:y", 20.0, retract_duration)
		tween.tween_callback(func(): spikes_sprite.visible = false)

func enter_cooldown() -> void:
	current_state = SpikeState.COOLDOWN
	state_timer = 0.0

func reset_to_hidden() -> void:
	current_state = SpikeState.HIDDEN
	state_timer = 0.0
	triggered_by = null

	# Reset visuals
	if spikes_sprite:
		spikes_sprite.visible = false
		spikes_sprite.position.y = 0

	if trigger_indicator:
		trigger_indicator.visible = false

# ============================================
# UTILITY
# ============================================
func is_spike_active() -> bool:
	return current_state == SpikeState.ACTIVE

func get_state_name() -> String:
	match current_state:
		SpikeState.HIDDEN: return "HIDDEN"
		SpikeState.TRIGGERED: return "TRIGGERED"
		SpikeState.ACTIVE: return "ACTIVE"
		SpikeState.RETRACTING: return "RETRACTING"
		SpikeState.COOLDOWN: return "COOLDOWN"
	return "UNKNOWN"
