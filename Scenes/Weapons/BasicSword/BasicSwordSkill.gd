# SCRIPT: BasicSwordSkill.gd
# ATTACH TO: BasicSwordSkill (Node2D) root node in BasicSwordSkill.tscn
# LOCATION: res://Scenes/Weapons/BasicSword/BasicSwordSkill.gd
# Spin Slash - AoE spinning attack

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual

@export var damage: float = 20.0
@export var spin_duration: float = 0.6
@export var knockback_force: float = 400.0
@export var knockback_stun: float = 0.2

var hits_this_spin: Array = []
var owner_ref: Node2D = null  # Reference to who created the spin slash (for thorns)

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)

	# Setup collision mask - ensure we can hit portal (layer 4) and enemies (layer 16)
	hit_box.collision_mask = 20  # 4 (portal) + 16 (enemies)

	# Start the spin animation
	_perform_spin()

func _perform_spin():
	# Start small and scale up
	visual.scale = Vector2(0.5, 0.5)
	modulate.a = 0.0

	var tween = TweenHelper.new_tween()
	tween.set_parallel(true)

	# Fade in and scale up
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Rotate the visual for spin effect
	tween.set_parallel(false)
	tween.tween_property(visual, "rotation", deg_to_rad(360), spin_duration)\
		.set_trans(Tween.TRANS_LINEAR)

	# Fade out at the end
	tween.tween_property(self, "modulate:a", 0.0, 0.15)

	# Cleanup
	tween.tween_callback(queue_free)

func initialize(player_position: Vector2, slash_damage: float, weapon_owner: Node2D = null):
	global_position = player_position
	damage = slash_damage
	owner_ref = weapon_owner

func _on_hit_box_area_entered(area: Area2D):
	# Check if the area itself has take_damage (like Portal)
	var target = area if area.has_method("take_damage") else area.get_parent()

	# Don't hit the same enemy twice
	if target in hits_this_spin:
		return

	if target.has_method("take_damage"):
		hits_this_spin.append(target)
		target.take_damage(damage, global_position, knockback_force, knockback_stun, owner_ref)
		dealt_damage.emit(target, damage)

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_spin:
		return

	if body.has_method("take_damage"):
		hits_this_spin.append(body)
		body.take_damage(damage, global_position, knockback_force, knockback_stun, owner_ref)
		dealt_damage.emit(body, damage)
