# SCRIPT: CircleProgress.gd
# Simple control that draws a filled circle with optional bottom-to-top fill
# LOCATION: res://Scripts/Ui/CircleProgress.gd

extends Control

var circle_color: Color = Color.WHITE
var fill_percent: float = 1.0  # 0 to 1, fills from bottom

func _draw():
	var center = size / 2
	var radius = min(size.x, size.y) / 2

	if fill_percent >= 1.0:
		# Full circle
		draw_circle(center, radius, circle_color)
	elif fill_percent > 0.0:
		# Partial circle - draw arc from bottom
		var fill_height = size.y * fill_percent
		var fill_top = size.y - fill_height

		# Draw using polygon for bottom-to-top fill effect
		var points = PackedVector2Array()
		var segments = 64

		for i in range(segments + 1):
			var angle = PI + (i * TAU / segments)  # Start from bottom
			var point = center + Vector2(cos(angle), sin(angle)) * radius
			if point.y >= fill_top:
				points.append(point)

		if points.size() >= 3:
			draw_colored_polygon(points, circle_color)
