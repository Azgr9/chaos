# SCRIPT: BasicSwordSkill.gd
# ATTACH TO: BasicSwordSkill (Node2D) root node in BasicSwordSkill.tscn
# LOCATION: res://Scenes/Weapons/BasicSword/BasicSwordSkill.gd
# Sword Beam - Energy wave projectile that travels forward and pierces enemies

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual

@export var damage: float = 30.0
@export var beam_speed: float = 900.0
@export var beam_range: float = 500.0
@export var knockback_force: float = 400.0
@export var knockback_stun: float = 0.15

var hits_this_beam: Array = []
var owner_ref: Node2D = null
var beam_direction: Vector2 = Vector2.RIGHT
var traveled_distance: float = 0.0
var is_active: bool = true

# Visual colors
const BEAM_COLOR: Color = Color(0.7, 0.85, 1.0, 0.95)  # Light blue-white
const BEAM_GLOW: Color = Color(0.5, 0.7, 1.0, 0.6)  # Blue glow
const BEAM_CORE: Color = Color(1.0, 1.0, 1.0, 1.0)  # White core

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)

	hit_box.collision_mask = 28  # enemies (16) + portal (4) + walls (8)

	_start_beam()

func _physics_process(delta):
	if not is_active:
		return

	# Move beam forward
	var move_amount = beam_direction * beam_speed * delta
	global_position += move_amount
	traveled_distance += move_amount.length()

	# Destroy when out of range
	if traveled_distance >= beam_range:
		_destroy_beam()

func _start_beam():
	# Orient to direction
	rotation = beam_direction.angle()

	# Initial animation
	visual.scale = Vector2(0.3, 0.3)
	modulate.a = 0.0

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.06)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Trail effect
	_start_trail_effect()

func _start_trail_effect():
	var timer = Timer.new()
	timer.wait_time = 0.025
	timer.one_shot = false
	add_child(timer)

	var beam_ref = weakref(self)
	timer.timeout.connect(func():
		var b = beam_ref.get_ref()
		if b and is_instance_valid(b) and b.is_active:
			b._spawn_trail_particle()
		else:
			timer.stop()
	)
	timer.start()

func _spawn_trail_particle():
	var scene = get_tree().current_scene
	if not scene:
		return

	# Main trail
	var trail = ColorRect.new()
	trail.size = Vector2(30, 16)
	trail.color = BEAM_GLOW
	trail.pivot_offset = Vector2(15, 8)
	scene.add_child(trail)
	trail.global_position = global_position - Vector2(15, 8)
	trail.rotation = rotation

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(trail, "scale", Vector2(0.2, 0.4), 0.12)
	tween.tween_property(trail, "modulate:a", 0.0, 0.12)
	tween.tween_callback(trail.queue_free)

func initialize(start_pos: Vector2, direction: Vector2, beam_damage: float, weapon_owner: Node2D = null):
	global_position = start_pos
	beam_direction = direction.normalized() if direction.length() > 0 else Vector2.RIGHT
	damage = beam_damage
	owner_ref = weapon_owner

func _on_hit_box_area_entered(area: Area2D):
	var target = area if area.has_method("take_damage") else area.get_parent()

	if target in hits_this_beam:
		return

	if target.is_in_group("converted_minion") or target.is_in_group("player_minions"):
		return

	if target.has_method("take_damage"):
		hits_this_beam.append(target)
		target.take_damage(damage, global_position, knockback_force, knockback_stun, owner_ref)
		dealt_damage.emit(target, damage)
		_create_hit_effect(target.global_position)

func _on_hit_box_body_entered(body: Node2D):
	# Hit wall
	if body.collision_layer & 8:
		_destroy_beam()
		return

	if body in hits_this_beam:
		return

	if body.has_method("take_damage"):
		hits_this_beam.append(body)
		body.take_damage(damage, global_position, knockback_force, knockback_stun, owner_ref)
		dealt_damage.emit(body, damage)
		_create_hit_effect(body.global_position)

func _create_hit_effect(hit_pos: Vector2):
	var scene = get_tree().current_scene
	if not scene:
		return

	var flash = ColorRect.new()
	flash.size = Vector2(40, 40)
	flash.color = BEAM_CORE
	flash.pivot_offset = Vector2(20, 20)
	scene.add_child(flash)
	flash.global_position = hit_pos - Vector2(20, 20)

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(flash.queue_free)

	# Sparks
	for i in range(5):
		var spark = ColorRect.new()
		spark.size = Vector2(4, 10)
		spark.color = BEAM_COLOR
		spark.pivot_offset = Vector2(2, 5)
		scene.add_child(spark)
		spark.global_position = hit_pos

		var angle = randf() * TAU
		spark.rotation = angle
		var dir = Vector2.from_angle(angle)
		var end_pos = hit_pos + dir * randf_range(25, 50)

		var spark_tween = TweenHelper.new_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", end_pos, 0.1)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.1)
		spark_tween.tween_callback(spark.queue_free)

func _destroy_beam():
	is_active = false

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_property(visual, "scale", Vector2(0.5, 1.5), 0.08)
	tween.tween_callback(queue_free)
