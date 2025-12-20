# SCRIPT: CombatAnimationSystem.gd
# AUTOLOAD: CombatAnimationSystem
# LOCATION: res://Scripts/Systems/CombatAnimationSystem.gd
# PURPOSE: Centralized combat animation state machine with hit-stop, canceling, and blending

extends Node

# ============================================
# SIGNALS
# ============================================
signal animation_started(weapon: Node2D, state: String)
signal animation_finished(weapon: Node2D, state: String)
signal animation_canceled(weapon: Node2D, from_state: String, to_state: String)
signal hit_stop_started(duration: float)
signal hit_stop_ended()

# ============================================
# ANIMATION STATES
# ============================================
enum AnimState {
	IDLE,
	WINDUP,        # Before attack connects
	ACTIVE,        # Attack hitbox active
	RECOVERY,      # After attack, before can act again
	SKILL_WINDUP,
	SKILL_ACTIVE,
	SKILL_RECOVERY,
	STAGGERED,
	CANCELED
}

# ============================================
# HIT-STOP SETTINGS (in REAL seconds, not game time)
# ============================================
const HIT_STOP_LIGHT: float = 0.02      # Light attacks - barely noticeable
const HIT_STOP_MEDIUM: float = 0.035    # Normal attacks - subtle
const HIT_STOP_HEAVY: float = 0.05      # Heavy/finisher attacks
const HIT_STOP_CRITICAL: float = 0.06   # Critical hits
const HIT_STOP_SKILL: float = 0.08      # Skill impacts

# Time scale during hit-stop (higher = less slowdown, lower = more freeze)
const HIT_STOP_TIME_SCALE: float = 0.1  # 10% speed (was 0.05 = 5%)

# ============================================
# CANCEL RULES
# ============================================
# Which states can be canceled into which other states
const CANCEL_RULES: Dictionary = {
	AnimState.IDLE: [AnimState.WINDUP, AnimState.SKILL_WINDUP],
	AnimState.WINDUP: [],  # Cannot cancel windup by default
	AnimState.ACTIVE: [AnimState.SKILL_WINDUP],  # Can cancel active into skill
	AnimState.RECOVERY: [AnimState.WINDUP, AnimState.SKILL_WINDUP],  # Recovery can be canceled
	AnimState.SKILL_WINDUP: [],
	AnimState.SKILL_ACTIVE: [],
	AnimState.SKILL_RECOVERY: [AnimState.WINDUP],  # Skill recovery can cancel into attack
	AnimState.STAGGERED: [],
	AnimState.CANCELED: [AnimState.IDLE, AnimState.WINDUP]
}

# ============================================
# STATE TRACKING
# ============================================
# Per-weapon animation state tracking
var _weapon_states: Dictionary = {}  # weapon_id -> WeaponAnimState

# Global hit-stop state
var _hit_stop_active: bool = false
var _hit_stop_remaining: float = 0.0
var _original_time_scale: float = 1.0

# ============================================
# WEAPON ANIM STATE CLASS
# ============================================
class WeaponAnimState:
	var current_state: int = AnimState.IDLE
	var state_timer: float = 0.0
	var state_duration: float = 0.0
	var active_tween: Tween = null
	var queued_state: int = -1
	var can_cancel: bool = false
	var blend_progress: float = 0.0
	var animation_data: Dictionary = {}

	func reset():
		current_state = AnimState.IDLE
		state_timer = 0.0
		state_duration = 0.0
		queued_state = -1
		can_cancel = false
		blend_progress = 0.0
		if active_tween and active_tween.is_valid():
			active_tween.kill()
		active_tween = null

var _last_frame_time: float = 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Process even during hit-stop
	_last_frame_time = Time.get_ticks_msec() / 1000.0

func _process(_delta: float):
	# Calculate REAL delta (unaffected by time_scale)
	var current_time = Time.get_ticks_msec() / 1000.0
	var real_delta = current_time - _last_frame_time
	_last_frame_time = current_time

	# Clamp to avoid huge deltas from lag spikes
	real_delta = minf(real_delta, 0.1)

	# Handle hit-stop with REAL time
	if _hit_stop_active:
		_hit_stop_remaining -= real_delta
		if _hit_stop_remaining <= 0:
			_end_hit_stop()

# ============================================
# PUBLIC API: Animation State Management
# ============================================

## Register a weapon with the animation system
func register_weapon(weapon: Node2D) -> void:
	var weapon_id = _get_weapon_id(weapon)
	if not _weapon_states.has(weapon_id):
		_weapon_states[weapon_id] = WeaponAnimState.new()

## Unregister a weapon (call when weapon is freed)
func unregister_weapon(weapon: Node2D) -> void:
	var weapon_id = _get_weapon_id(weapon)
	if _weapon_states.has(weapon_id):
		var state = _weapon_states[weapon_id]
		if state.active_tween and state.active_tween.is_valid():
			state.active_tween.kill()
		_weapon_states.erase(weapon_id)

## Get current animation state for a weapon
func get_state(weapon: Node2D) -> int:
	var weapon_id = _get_weapon_id(weapon)
	if _weapon_states.has(weapon_id):
		return _weapon_states[weapon_id].current_state
	return AnimState.IDLE

## Check if a state transition is allowed
func can_transition_to(weapon: Node2D, target_state: int) -> bool:
	var current = get_state(weapon)

	# Always allow transition to IDLE
	if target_state == AnimState.IDLE:
		return true

	# Check cancel rules
	if CANCEL_RULES.has(current):
		return target_state in CANCEL_RULES[current]

	return false

## Request a state transition
func request_transition(weapon: Node2D, target_state: int, force: bool = false) -> bool:
	if not force and not can_transition_to(weapon, target_state):
		# Queue the state for later if we can't transition now
		var weapon_id = _get_weapon_id(weapon)
		if _weapon_states.has(weapon_id):
			_weapon_states[weapon_id].queued_state = target_state
		return false

	_transition_to(weapon, target_state)
	return true

## Set state with full animation parameters
## Note: This function updates state tracking only. The weapon is responsible for
## creating and managing its own tween. Returns null - weapons should create their own tweens.
func start_animation(weapon: Node2D, state: int, duration: float, animation_data: Dictionary = {}) -> Tween:
	var weapon_id = _get_weapon_id(weapon)
	register_weapon(weapon)

	var anim_state = _weapon_states[weapon_id]

	# Kill existing tween if any
	if anim_state.active_tween and anim_state.active_tween.is_valid():
		anim_state.active_tween.kill()
		anim_state.active_tween = null

	# Update state
	var old_state = anim_state.current_state
	anim_state.current_state = state
	anim_state.state_timer = 0.0
	anim_state.state_duration = duration
	anim_state.animation_data = animation_data
	anim_state.blend_progress = 0.0

	# Emit signal
	if old_state != state:
		animation_started.emit(weapon, _state_to_string(state))

	# Return null - weapon creates its own tween
	# This avoids "Tween started with no Tweeners" error
	return null

## Mark animation as finished and return to idle
func finish_animation(weapon: Node2D) -> void:
	var weapon_id = _get_weapon_id(weapon)
	if not _weapon_states.has(weapon_id):
		return

	var anim_state = _weapon_states[weapon_id]
	var finished_state = anim_state.current_state

	# Check for queued state
	if anim_state.queued_state >= 0:
		var queued = anim_state.queued_state
		anim_state.queued_state = -1
		_transition_to(weapon, queued)
	else:
		anim_state.current_state = AnimState.IDLE
		anim_state.state_timer = 0.0

	animation_finished.emit(weapon, _state_to_string(finished_state))

## Check if weapon is in an interruptible state
func is_interruptible(weapon: Node2D) -> bool:
	var state = get_state(weapon)
	return state == AnimState.IDLE or state == AnimState.RECOVERY or state == AnimState.SKILL_RECOVERY

## Check if weapon is currently attacking
func is_attacking(weapon: Node2D) -> bool:
	var state = get_state(weapon)
	return state in [AnimState.WINDUP, AnimState.ACTIVE, AnimState.RECOVERY]

## Check if weapon is using skill
func is_using_skill(weapon: Node2D) -> bool:
	var state = get_state(weapon)
	return state in [AnimState.SKILL_WINDUP, AnimState.SKILL_ACTIVE, AnimState.SKILL_RECOVERY]

# ============================================
# PUBLIC API: Hit-Stop System
# ============================================

## Trigger hit-stop effect
func trigger_hit_stop(duration: float, _scale_with_time_scale: bool = true) -> void:
	if _hit_stop_active:
		# Extend existing hit-stop if new one is longer
		_hit_stop_remaining = maxf(_hit_stop_remaining, duration)
		return

	_hit_stop_active = true
	_hit_stop_remaining = duration
	_original_time_scale = Engine.time_scale

	# Slow down time (uses constant for consistent feel)
	Engine.time_scale = HIT_STOP_TIME_SCALE

	hit_stop_started.emit(duration)

## Trigger hit-stop based on attack type
func trigger_hit_stop_for_attack(attack_type: String) -> void:
	var duration: float
	match attack_type:
		"light":
			duration = HIT_STOP_LIGHT
		"medium":
			duration = HIT_STOP_MEDIUM
		"heavy":
			duration = HIT_STOP_HEAVY
		"critical":
			duration = HIT_STOP_CRITICAL
		"skill":
			duration = HIT_STOP_SKILL
		"finisher":
			duration = HIT_STOP_HEAVY * 1.5
		_:
			duration = HIT_STOP_MEDIUM

	trigger_hit_stop(duration)

## Check if hit-stop is active
func is_hit_stop_active() -> bool:
	return _hit_stop_active

# ============================================
# PUBLIC API: Animation Helpers
# ============================================

## Create a standard attack animation sequence (windup -> active -> recovery)
func create_attack_sequence(_weapon: Node2D, windup_time: float, active_time: float, recovery_time: float) -> Dictionary:
	return {
		"windup": windup_time,
		"active": active_time,
		"recovery": recovery_time,
		"total": windup_time + active_time + recovery_time
	}

## Get animation progress (0.0 to 1.0)
func get_animation_progress(weapon: Node2D) -> float:
	var weapon_id = _get_weapon_id(weapon)
	if not _weapon_states.has(weapon_id):
		return 1.0

	var anim_state = _weapon_states[weapon_id]
	if anim_state.state_duration <= 0:
		return 1.0

	return clampf(anim_state.state_timer / anim_state.state_duration, 0.0, 1.0)

## Get stored animation data
func get_animation_data(weapon: Node2D) -> Dictionary:
	var weapon_id = _get_weapon_id(weapon)
	if _weapon_states.has(weapon_id):
		return _weapon_states[weapon_id].animation_data
	return {}

# ============================================
# ANIMATION BLENDING
# ============================================

## Calculate blend weight between two animations
func calculate_blend_weight(from_progress: float, blend_duration: float, total_duration: float) -> float:
	if blend_duration <= 0:
		return 1.0

	var blend_start = 1.0 - (blend_duration / total_duration)
	if from_progress < blend_start:
		return 0.0

	return (from_progress - blend_start) / (1.0 - blend_start)

## Apply rotation blend between two angles
func blend_rotation(from_angle: float, to_angle: float, weight: float) -> float:
	# Use shortest path
	var diff = fmod(to_angle - from_angle + PI, TAU) - PI
	return from_angle + diff * weight

## Apply position blend
func blend_position(from_pos: Vector2, to_pos: Vector2, weight: float) -> Vector2:
	return from_pos.lerp(to_pos, weight)

# ============================================
# INTERNAL HELPERS
# ============================================

func _get_weapon_id(weapon: Node2D) -> int:
	return weapon.get_instance_id()

func _transition_to(weapon: Node2D, target_state: int) -> void:
	var weapon_id = _get_weapon_id(weapon)
	register_weapon(weapon)

	var anim_state = _weapon_states[weapon_id]
	var from_state = anim_state.current_state

	# Cancel current animation
	if anim_state.active_tween and anim_state.active_tween.is_valid():
		anim_state.active_tween.kill()

	anim_state.current_state = target_state
	anim_state.state_timer = 0.0
	anim_state.queued_state = -1

	if from_state != target_state:
		animation_canceled.emit(weapon, _state_to_string(from_state), _state_to_string(target_state))

func _end_hit_stop() -> void:
	_hit_stop_active = false
	_hit_stop_remaining = 0.0
	Engine.time_scale = _original_time_scale
	hit_stop_ended.emit()

func _state_to_string(state: int) -> String:
	match state:
		AnimState.IDLE: return "idle"
		AnimState.WINDUP: return "windup"
		AnimState.ACTIVE: return "active"
		AnimState.RECOVERY: return "recovery"
		AnimState.SKILL_WINDUP: return "skill_windup"
		AnimState.SKILL_ACTIVE: return "skill_active"
		AnimState.SKILL_RECOVERY: return "skill_recovery"
		AnimState.STAGGERED: return "staggered"
		AnimState.CANCELED: return "canceled"
		_: return "unknown"

# ============================================
# DEBUG
# ============================================

func get_debug_info() -> Dictionary:
	var weapon_info = {}
	for weapon_id in _weapon_states:
		var state = _weapon_states[weapon_id]
		weapon_info[weapon_id] = {
			"state": _state_to_string(state.current_state),
			"timer": state.state_timer,
			"duration": state.state_duration,
			"queued": state.queued_state
		}

	return {
		"hit_stop_active": _hit_stop_active,
		"hit_stop_remaining": _hit_stop_remaining,
		"weapons": weapon_info
	}
