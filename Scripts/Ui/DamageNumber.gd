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

func setup(damage_amount: float, damage_type: DamageTypes.Type = DamageTypes.Type.PHYSICAL):
	# Set the damage text (minimum 1 for display)
	var display_amount = maxi(ceili(damage_amount), 1)
	label.text = str(display_amount)

	# Get base color from damage type
	var base_color = DamageTypes.COLORS.get(damage_type, Color.WHITE)

	# For physical damage, also consider damage amount for intensity
	if damage_type == DamageTypes.Type.PHYSICAL:
		if damage_amount >= 50:
			base_color = Color.ORANGE_RED
		elif damage_amount >= 25:
			base_color = Color.ORANGE

	# For crits, make them bigger and add "!" suffix
	if damage_type == DamageTypes.Type.CRIT:
		label.scale = Vector2(1.5, 1.5)
		label.text = str(display_amount) + "!"

	# For heals, show + prefix
	if damage_type == DamageTypes.Type.HEAL:
		label.text = "+" + str(display_amount)

	# For poison, add skull emoji
	if damage_type == DamageTypes.Type.POISON:
		label.text = str(display_amount) + "☠"

	# For electric, add lightning emoji
	if damage_type == DamageTypes.Type.ELECTRIC:
		label.text = "⚡" + str(display_amount)

	label.add_theme_color_override("font_color", base_color)

func _animate():
	var tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(self, "position:y", position.y - float_distance, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Scale effect (slightly grow then shrink) - preserve initial scale
	var initial_scale = label.scale
	tween.tween_property(label, "scale", initial_scale * 1.2, fade_duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", initial_scale * 0.8, fade_duration * 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Remove after animation
	tween.finished.connect(queue_free)
