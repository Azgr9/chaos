# SCRIPT: CameraShake.gd
# ATTACH TO: Camera2D node
# LOCATION: res://Scripts/Player/CameraShake.gd

extends Camera2D

# Trauma system for screen shake
var trauma: float = 0.0
@export var trauma_decay: float = 1.0  # How fast trauma decays per second
@export var max_offset: float = 100.0
@export var max_rotation: float = 0.1  # Radians

# Noise for randomization
var noise: FastNoiseLite
var noise_y: int = 0

func _ready():
	# Setup noise for smooth random shake
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 4.0
	randomize()

func _process(delta):
	if trauma > 0:
		# Decay trauma over time
		trauma = max(trauma - trauma_decay * delta, 0)
		_apply_shake()
	else:
		# Reset camera when no trauma
		offset = Vector2.ZERO
		rotation = 0.0

func add_trauma(amount: float):
	# Add trauma (clamped to 0-1)
	trauma = min(trauma + amount, 1.0)

func _apply_shake():
	# Calculate shake amount (trauma squared for better feel)
	var shake_amount = pow(trauma, 2)

	# Increment noise sample
	noise_y += 1

	# Get noise values for x, y offset and rotation
	var noise_x = noise.get_noise_2d(noise_y, 0)
	var noise_y_offset = noise.get_noise_2d(0, noise_y)
	var noise_rotation = noise.get_noise_2d(noise_y, noise_y)

	# Apply shake to camera
	offset.x = max_offset * shake_amount * noise_x
	offset.y = max_offset * shake_amount * noise_y_offset
	rotation = max_rotation * shake_amount * noise_rotation
