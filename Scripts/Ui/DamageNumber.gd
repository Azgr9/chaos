# SCRIPT: DamageNumber.gd
# ATTACH TO: DamageNumber (Node2D) root node in DamageNumber.tscn
# LOCATION: res://Scripts/Ui/DamageNumber.gd

extends Node2D

@onready var label: Label = $Label

# Animation settings
@export var float_speed: float = 120.0
@export var float_distance: float = 160.0
@export var fade_duration: float = 1.0
@export var spread: float = 80.0

func _ready():
	# Pause when game pauses (don't keep animating during upgrade menu)
	process_mode = Node.PROCESS_MODE_PAUSABLE

	# Add random horizontal spread
	var random_offset = Vector2(randf_range(-spread, spread), 0)
	position += random_offset

	# Start the float and fade animation
	_animate()

func setup(damage_amount: float):
	# Set the damage text
	label.text = str(int(damage_amount))

	# Color based on damage amount (optional)
	if damage_amount >= 50:
		label.add_theme_color_override("font_color", Color.ORANGE_RED)
	elif damage_amount >= 25:
		label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)

func _animate():
	var tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(self, "position:y", position.y - float_distance, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Scale effect (slightly grow then shrink)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), fade_duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2(0.8, 0.8), fade_duration * 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Remove after animation
	tween.finished.connect(queue_free)
