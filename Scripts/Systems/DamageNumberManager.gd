# SCRIPT: DamageNumberManager.gd
# LOCATION: res://Scripts/Systems/DamageNumberManager.gd
# Centralized damage number spawning and screen shake utilities
# Uses static functions - no autoload needed

class_name DamageNumberManager
extends RefCounted

const DamageNumberScene = preload("res://Scenes/Ui/DamageNumber.tscn")

# Spawn a damage number at position with optional type
static func spawn(pos: Vector2, amount: float, type: DamageTypes.Type = DamageTypes.Type.PHYSICAL) -> void:
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree or not scene_tree.current_scene:
		return

	var damage_number = DamageNumberScene.instantiate()
	damage_number.global_position = pos + Vector2(randf_range(-10, 10), -20)
	scene_tree.current_scene.add_child(damage_number)
	damage_number.setup(amount, type)

# Spawn at a body's position
static func spawn_at(body: Node2D, amount: float, type: DamageTypes.Type = DamageTypes.Type.PHYSICAL) -> void:
	if not is_instance_valid(body):
		return
	spawn(body.global_position, amount, type)

# Add screen shake (centralized)
static func shake(amount: float) -> void:
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return

	var viewport = scene_tree.root.get_viewport()
	if not viewport:
		return

	var camera = viewport.get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(amount)
