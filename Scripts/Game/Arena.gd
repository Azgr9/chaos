# SCRIPT: Arena.gd
# ATTACH TO: Arena (Node2D) root node in Arena.tscn
# PURPOSE: Provides arena bounds info and generates circular collision wall.

class_name Arena
extends Node2D

# Arena configuration - edit these in the Inspector!
@export_group("Arena Bounds")
@export var arena_center: Vector2 = Vector2(1280, 720)
@export var arena_radius: float = 900.0

@export_group("Wall Settings")
@export var wall_segments: int = 64  # More segments = smoother circle
@export var wall_thickness: float = 40.0  # Visual thickness of wall ring
@export var wall_color: Color = Color(0.78, 0.06, 0.0, 1.0)  # Red-brown

# Reference to the circular wall collision
@onready var walls: StaticBody2D = $Walls

func _ready():
	add_to_group("arena")
	_generate_circular_collision()
	_generate_visual_ring()

func _generate_circular_collision():
	# Generate segment shapes around the perimeter to create a proper ring wall
	# This prevents players from being pushed outward (which happens with solid CircleShape2D)
	for i in range(wall_segments):
		var angle_start = (float(i) / wall_segments) * TAU
		var angle_end = (float(i + 1) / wall_segments) * TAU

		var point_a = Vector2.from_angle(angle_start) * arena_radius
		var point_b = Vector2.from_angle(angle_end) * arena_radius

		var segment = SegmentShape2D.new()
		segment.a = point_a
		segment.b = point_b

		var collision = CollisionShape2D.new()
		collision.shape = segment
		walls.add_child(collision)

func _generate_visual_ring():
	# Create visual polygon for the wall ring (outer circle with inner hole)
	var visual_circle = walls.get_node_or_null("VisualCircle")
	if not visual_circle:
		visual_circle = Polygon2D.new()
		visual_circle.name = "VisualCircle"
		walls.add_child(visual_circle)

	visual_circle.color = wall_color

	# Create ring polygon (outer then inner points in reverse for hole)
	var points: PackedVector2Array = []
	var outer_radius = arena_radius + wall_thickness / 2
	var inner_radius = arena_radius - wall_thickness / 2

	# Outer circle points
	for i in range(wall_segments + 1):
		var angle = (float(i) / wall_segments) * TAU
		points.append(Vector2.from_angle(angle) * outer_radius)

	# Inner circle points (reversed for hole effect)
	for i in range(wall_segments, -1, -1):
		var angle = (float(i) / wall_segments) * TAU
		points.append(Vector2.from_angle(angle) * inner_radius)

	visual_circle.polygon = points

# ============================================
# PUBLIC API - Used by WaveManager, HazardManager, etc.
# ============================================

func get_arena_center() -> Vector2:
	return arena_center

func get_arena_radius() -> float:
	return arena_radius

func is_position_in_arena(pos: Vector2) -> bool:
	return pos.distance_to(arena_center) <= arena_radius

func clamp_to_arena(pos: Vector2, padding: float = 0.0) -> Vector2:
	var to_center = pos - arena_center
	var distance = to_center.length()
	var max_distance = arena_radius - padding

	if distance > max_distance and distance > 0:
		return arena_center + to_center.normalized() * max_distance
	return pos

func get_random_position_in_arena(min_from_center: float = 0.0, padding_from_edge: float = 50.0) -> Vector2:
	var angle = randf() * TAU
	var max_dist = arena_radius - padding_from_edge
	var distance = randf_range(min_from_center, max_dist)
	return arena_center + Vector2.from_angle(angle) * distance

func get_position_on_edge(angle: float, padding: float = 80.0) -> Vector2:
	return arena_center + Vector2.from_angle(angle) * (arena_radius - padding)
