# SCRIPT: EnemyArrow.gd
# ATTACH TO: EnemyArrow (Area2D) root node in EnemyArrow.tscn
# LOCATION: res://Scripts/Enemies/EnemyArrow.gd

class_name EnemyArrow
extends Area2D

# Arrow properties
@export var speed: float = 150.0
@export var damage: float = 8.0

# Nodes
@onready var sprite: ColorRect = $Sprite
@onready var lifetime_timer: Timer = $LifetimeTimer

# State
var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO

func _ready():
	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_timeout)

func initialize(start_pos: Vector2, target_pos: Vector2):
	global_position = start_pos
	direction = (target_pos - start_pos).normalized()
	velocity = direction * speed

	# Rotate arrow to face direction
	rotation = direction.angle()

func _physics_process(delta):
	position += velocity * delta

func _on_area_entered(area: Area2D):
	# Hit player hurtbox
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
		_destroy_arrow()

func _on_body_entered(body: Node2D):
	# Hit a wall
	if body.collision_layer & 8:  # Walls layer
		_destroy_arrow()

func _on_lifetime_timeout():
	_destroy_arrow()

func _destroy_arrow():
	# Simple fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
