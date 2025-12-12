# SCRIPT: SpinSlash.gd
# ATTACH TO: SpinSlash (Node2D) root node in SpinSlash.tscn
# LOCATION: res://Scripts/Weapons/SpinSlash.gd

extends Node2D

@onready var hit_box: Area2D = $HitBox
@onready var visual: Node2D = $Visual

var damage: float = 20.0
var hits_this_spin: Array = []
var spin_duration: float = 0.6
var owner_ref: Node2D = null  # Reference to who created the spin slash (for thorns)

signal dealt_damage(target: Node2D, damage: float)

func _ready():
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)

	# Start the spin animation
	_perform_spin()

func _perform_spin():
	# Start small and scale up
	visual.scale = Vector2(0.5, 0.5)
	modulate.a = 0.0

	var tween = create_tween()
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

func initialize(player_position: Vector2, slash_damage: float, owner: Node2D = null):
	global_position = player_position
	damage = slash_damage
	owner_ref = owner

func _on_hit_box_area_entered(area: Area2D):
	var parent = area.get_parent()

	# Don't hit the same enemy twice
	if parent in hits_this_spin:
		return

	if parent.has_method("take_damage"):
		hits_this_spin.append(parent)
		parent.take_damage(damage, global_position, 400.0, 0.2, owner_ref)
		dealt_damage.emit(parent, damage)

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_spin:
		return

	if body.has_method("take_damage"):
		hits_this_spin.append(body)
		body.take_damage(damage, global_position, 400.0, 0.2, owner_ref)
		dealt_damage.emit(body, damage)
