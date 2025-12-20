# SCRIPT: WeaponAnimationData.gd
# LOCATION: res://Scripts/Resources/WeaponAnimationData.gd
# PURPOSE: Resource definition for weapon animation patterns

class_name WeaponAnimationData
extends Resource

# ============================================
# ANIMATION PATTERN DEFINITIONS
# ============================================

## Attack pattern types
enum AttackPattern {
	HORIZONTAL,
	HORIZONTAL_REVERSE,
	OVERHEAD,
	UPPERCUT,
	STAB,
	LUNGE,
	SLAM,
	SPIN,
	CUSTOM
}

## Easing types for animation curves
enum EaseType {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	BACK_IN,
	BACK_OUT,
	ELASTIC_OUT
}

# ============================================
# TIMING SETTINGS
# ============================================
@export_group("Timing")
## Time before the attack hitbox becomes active
@export var windup_time: float = 0.08
## Time the hitbox is active
@export var active_time: float = 0.12
## Time after attack before can act again
@export var recovery_time: float = 0.15
## Blend time when transitioning from previous animation
@export var blend_in_time: float = 0.05

# ============================================
# ROTATION SETTINGS
# ============================================
@export_group("Rotation")
## Starting rotation offset (degrees)
@export var start_rotation: float = -60.0
## Ending rotation offset (degrees)
@export var end_rotation: float = 60.0
## Rotation during recovery (degrees)
@export var recovery_rotation: float = 45.0
## Easing for swing rotation
@export var rotation_ease: EaseType = EaseType.EASE_OUT

# ============================================
# POSITION/OFFSET SETTINGS
# ============================================
@export_group("Position")
## Starting position offset
@export var start_offset: Vector2 = Vector2.ZERO
## Peak/impact position offset
@export var peak_offset: Vector2 = Vector2(20, 0)
## Recovery position offset
@export var recovery_offset: Vector2 = Vector2.ZERO
## Easing for position movement
@export var position_ease: EaseType = EaseType.EASE_OUT

# ============================================
# SCALE SETTINGS
# ============================================
@export_group("Scale")
## Starting scale
@export var start_scale: Vector2 = Vector2.ONE
## Scale at impact
@export var peak_scale: Vector2 = Vector2(1.1, 1.1)
## Recovery scale
@export var recovery_scale: Vector2 = Vector2.ONE

# ============================================
# EFFECTS
# ============================================
@export_group("Effects")
## Enable trail effect during swing
@export var enable_trail: bool = true
## Trail color
@export var trail_color: Color = Color(1.0, 1.0, 1.0, 0.5)
## Number of trail segments
@export var trail_segments: int = 4
## Enable screen shake on hit
@export var enable_screen_shake: bool = true
## Screen shake intensity
@export var screen_shake_intensity: float = 0.3
## Flash color on hit
@export var hit_flash_color: Color = Color.WHITE

# ============================================
# HIT-STOP
# ============================================
@export_group("Hit-Stop")
## Hit-stop type for this attack
@export_enum("light", "medium", "heavy", "critical", "skill", "finisher") var hit_stop_type: String = "medium"

# ============================================
# UTILITY METHODS
# ============================================

## Get total animation duration
func get_total_duration() -> float:
	return windup_time + active_time + recovery_time

## Get the time when hitbox should be active
func get_active_start_time() -> float:
	return windup_time

## Get the time when hitbox should deactivate
func get_active_end_time() -> float:
	return windup_time + active_time

## Convert EaseType to Godot Tween transition
func get_tween_transition(ease_type: EaseType) -> Tween.TransitionType:
	match ease_type:
		EaseType.LINEAR:
			return Tween.TRANS_LINEAR
		EaseType.EASE_IN:
			return Tween.TRANS_QUAD
		EaseType.EASE_OUT:
			return Tween.TRANS_QUAD
		EaseType.EASE_IN_OUT:
			return Tween.TRANS_QUAD
		EaseType.BACK_IN:
			return Tween.TRANS_BACK
		EaseType.BACK_OUT:
			return Tween.TRANS_BACK
		EaseType.ELASTIC_OUT:
			return Tween.TRANS_ELASTIC
		_:
			return Tween.TRANS_LINEAR

## Convert EaseType to Godot Tween ease
func get_tween_ease(ease_type: EaseType) -> Tween.EaseType:
	match ease_type:
		EaseType.EASE_IN, EaseType.BACK_IN:
			return Tween.EASE_IN
		EaseType.EASE_OUT, EaseType.BACK_OUT, EaseType.ELASTIC_OUT:
			return Tween.EASE_OUT
		EaseType.EASE_IN_OUT:
			return Tween.EASE_IN_OUT
		_:
			return Tween.EASE_OUT

# ============================================
# PRESET FACTORIES
# ============================================

## Create a horizontal slash animation
static func create_horizontal_slash() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.06
	data.active_time = 0.10
	data.recovery_time = 0.12
	data.start_rotation = -75.0
	data.end_rotation = 75.0
	data.recovery_rotation = 45.0
	data.peak_offset = Vector2(15, 0)
	data.hit_stop_type = "medium"
	return data

## Create a reverse horizontal slash animation
static func create_horizontal_reverse() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.05
	data.active_time = 0.10
	data.recovery_time = 0.10
	data.start_rotation = 75.0
	data.end_rotation = -75.0
	data.recovery_rotation = 45.0
	data.peak_offset = Vector2(15, 0)
	data.hit_stop_type = "medium"
	return data

## Create an overhead slash animation
static func create_overhead_slash() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.10
	data.active_time = 0.08
	data.recovery_time = 0.15
	data.start_rotation = -120.0
	data.end_rotation = 30.0
	data.recovery_rotation = 45.0
	data.peak_offset = Vector2(20, 10)
	data.peak_scale = Vector2(1.15, 1.15)
	data.hit_stop_type = "heavy"
	data.screen_shake_intensity = 0.4
	return data

## Create a stab/thrust animation
static func create_stab() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.04
	data.active_time = 0.06
	data.recovery_time = 0.08
	data.start_rotation = 0.0
	data.end_rotation = 0.0
	data.recovery_rotation = 30.0
	data.start_offset = Vector2(-10, 0)
	data.peak_offset = Vector2(40, 0)
	data.recovery_offset = Vector2(0, 0)
	data.hit_stop_type = "light"
	data.screen_shake_intensity = 0.15
	return data

## Create a lunge animation
static func create_lunge() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.08
	data.active_time = 0.10
	data.recovery_time = 0.15
	data.start_rotation = -15.0
	data.end_rotation = 15.0
	data.recovery_rotation = 30.0
	data.start_offset = Vector2(-20, 0)
	data.peak_offset = Vector2(60, 0)
	data.peak_scale = Vector2(1.2, 1.0)
	data.hit_stop_type = "heavy"
	data.screen_shake_intensity = 0.35
	return data

## Create a slam/ground pound animation
static func create_slam() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.15
	data.active_time = 0.10
	data.recovery_time = 0.25
	data.start_rotation = -150.0
	data.end_rotation = 45.0
	data.recovery_rotation = 60.0
	data.start_offset = Vector2(-10, -30)
	data.peak_offset = Vector2(25, 20)
	data.peak_scale = Vector2(1.2, 1.2)
	data.hit_stop_type = "finisher"
	data.screen_shake_intensity = 0.6
	return data

## Create a spin attack animation
static func create_spin() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.05
	data.active_time = 0.25
	data.recovery_time = 0.15
	data.start_rotation = 0.0
	data.end_rotation = 360.0
	data.recovery_rotation = 45.0
	data.peak_scale = Vector2(1.1, 1.1)
	data.hit_stop_type = "medium"
	data.trail_segments = 8
	return data

## Create an uppercut animation
static func create_uppercut() -> WeaponAnimationData:
	var data = WeaponAnimationData.new()
	data.windup_time = 0.08
	data.active_time = 0.08
	data.recovery_time = 0.12
	data.start_rotation = 45.0
	data.end_rotation = -90.0
	data.recovery_rotation = 45.0
	data.start_offset = Vector2(0, 10)
	data.peak_offset = Vector2(15, -20)
	data.hit_stop_type = "medium"
	return data

## Get a preset animation by pattern type
static func get_preset(pattern: AttackPattern) -> WeaponAnimationData:
	match pattern:
		AttackPattern.HORIZONTAL:
			return create_horizontal_slash()
		AttackPattern.HORIZONTAL_REVERSE:
			return create_horizontal_reverse()
		AttackPattern.OVERHEAD:
			return create_overhead_slash()
		AttackPattern.STAB:
			return create_stab()
		AttackPattern.LUNGE:
			return create_lunge()
		AttackPattern.SLAM:
			return create_slam()
		AttackPattern.SPIN:
			return create_spin()
		AttackPattern.UPPERCUT:
			return create_uppercut()
		_:
			return create_horizontal_slash()
