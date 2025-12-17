# SCRIPT: Arena.gd
# ATTACH TO: Arena (Node2D) root node in Arena.tscn
# PURPOSE: Provides arena bounds. Collision is set up in the scene with CollisionShape2D nodes.

class_name Arena
extends Node2D

# Arena configuration - edit these in the Inspector!
@export_group("Arena Bounds")
@export var arena_center: Vector2 = Vector2(1280, 720)
@export var arena_half_width: float = 1200.0
@export var arena_half_height: float = 680.0

func _ready():
	add_to_group("arena")

# ============================================
# PUBLIC API - Used by WaveManager, HazardManager, etc.
# ============================================

func get_arena_center() -> Vector2:
	return arena_center

func get_arena_radius() -> float:
	# Return smaller dimension for compatibility
	return min(arena_half_width, arena_half_height)

func is_position_in_arena(pos: Vector2) -> bool:
	return abs(pos.x - arena_center.x) <= arena_half_width and abs(pos.y - arena_center.y) <= arena_half_height

func clamp_to_arena(pos: Vector2, padding: float = 0.0) -> Vector2:
	var clamped = pos
	clamped.x = clamp(pos.x, arena_center.x - arena_half_width + padding, arena_center.x + arena_half_width - padding)
	clamped.y = clamp(pos.y, arena_center.y - arena_half_height + padding, arena_center.y + arena_half_height - padding)
	return clamped

func get_random_position_in_arena(_min_from_center: float = 0.0, padding_from_edge: float = 50.0) -> Vector2:
	var x = randf_range(arena_center.x - arena_half_width + padding_from_edge, arena_center.x + arena_half_width - padding_from_edge)
	var y = randf_range(arena_center.y - arena_half_height + padding_from_edge, arena_center.y + arena_half_height - padding_from_edge)
	return Vector2(x, y)

func get_position_on_edge(angle: float, padding: float = 80.0) -> Vector2:
	var dir = Vector2.from_angle(angle)
	var pos = arena_center
	if abs(dir.x) > abs(dir.y):
		pos.x = arena_center.x + sign(dir.x) * (arena_half_width - padding)
		pos.y = randf_range(arena_center.y - arena_half_height + padding, arena_center.y + arena_half_height - padding)
	else:
		pos.y = arena_center.y + sign(dir.y) * (arena_half_height - padding)
		pos.x = randf_range(arena_center.x - arena_half_width + padding, arena_center.x + arena_half_width - padding)
	return pos
