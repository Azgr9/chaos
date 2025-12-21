# SCRIPT: TweenHelper.gd
# AUTOLOAD: TweenHelper
# LOCATION: res://Scripts/Systems/TweenHelper.gd
# Centralized tween creation system to prevent lambda capture issues

extends Node

# ============================================
# SAFE TWEEN CREATION
# ============================================

## Creates a scene-tree bound tween (not bound to caller object)
## This prevents "Lambda capture at index 0 was freed" errors
## Named 'new_tween' to avoid overriding Node.create_tween()
func new_tween() -> Tween:
	return get_tree().create_tween()

## Creates a tween with parallel mode enabled
func new_parallel_tween() -> Tween:
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	return tween

# ============================================
# COMMON VISUAL EFFECTS
# ============================================

## Fade out and free a node (works with Node2D and Control)
func fade_and_free(node: CanvasItem, duration: float = 0.2) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween = get_tree().create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
	return tween

## Scale and fade out a node then free it (works with Node2D and Control)
func scale_fade_free(node: CanvasItem, target_scale: Vector2, duration: float = 0.2) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "scale", target_scale, duration)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
	return tween

## Move node to position and fade out then free (Node2D only - uses global_position)
func move_fade_free(node: Node2D, target_pos: Vector2, duration: float = 0.3) -> Tween:
	if not is_instance_valid(node):
		return null
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "global_position", target_pos, duration)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
	return tween

## Create particle burst effect at position
func create_particle_burst(pos: Vector2, count: int, color: Color, size: Vector2 = Vector2(8, 8),
						   distance: float = 80.0, duration: float = 0.3) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return

	for i in range(count):
		var particle = ColorRect.new()
		particle.size = size
		particle.color = color
		particle.pivot_offset = size / 2
		scene.add_child(particle)
		particle.global_position = pos - size / 2

		var angle = (TAU / count) * i + randf_range(-0.2, 0.2)
		var dir = Vector2.from_angle(angle)
		var dist = distance * randf_range(0.8, 1.2)

		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + dir * dist, duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2(0.3, 0.3), duration)
		tween.tween_callback(particle.queue_free)

## Create expanding ring effect at position
func create_ring_effect(pos: Vector2, color: Color, start_size: float = 40.0,
						end_scale: float = 5.0, duration: float = 0.4) -> void:
	var scene = get_tree().current_scene
	if not scene:
		return

	var ring = ColorRect.new()
	ring.size = Vector2(start_size, start_size)
	ring.color = color
	ring.pivot_offset = Vector2(start_size / 2, start_size / 2)
	scene.add_child(ring)
	ring.global_position = pos - ring.pivot_offset

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(end_scale, end_scale), duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)

## Flash a node's color and return to original
func flash_node_color(node: CanvasItem, to_color: Color, original_color: Color, duration: float = 0.1) -> Tween:
	if not is_instance_valid(node):
		return null
	node.modulate = to_color
	var tween = get_tree().create_tween()
	tween.tween_property(node, "modulate", original_color, duration)
	return tween

## Squash and stretch effect (works with Node2D and Control)
func squash_stretch(node: CanvasItem, squash_scale: Vector2, normal_scale: Vector2, duration: float = 0.15) -> Tween:
	if not is_instance_valid(node):
		return null
	node.scale = squash_scale
	var tween = get_tree().create_tween()
	tween.tween_property(node, "scale", normal_scale, duration)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween

# ============================================
# CALLBACK HELPERS
# ============================================

## Add a callback that only fires if the object is still valid
func safe_callback(tween: Tween, object: Object, method: Callable) -> void:
	tween.tween_callback(func():
		if is_instance_valid(object):
			method.call()
	)
