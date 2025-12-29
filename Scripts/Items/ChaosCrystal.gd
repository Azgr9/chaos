# SCRIPT: ChaosCrystal.gd
# ATTACH TO: ChaosCrystal (Area2D) root node in ChaosCrystal.tscn
# LOCATION: res://Scripts/Items/ChaosCrystal.gd
# NOTE: Drops Gold currency (was Crystals)

extends Area2D

@export var gold_value: int = 1
@export var magnet_range: float = 240.0
@export var magnet_speed: float = 600.0

@onready var visual: Node2D = $Visual
@onready var crystal_sprite: ColorRect = $Visual/Crystal
@onready var glow: ColorRect = $Visual/Glow
@onready var lifetime_timer: Timer = $LifetimeTimer

var player_reference: Node2D = null
var is_magnetized: bool = false
var spawn_animation_done: bool = false
var time_alive: float = 0.0

signal gold_collected(value: int)

func _ready():
	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	lifetime_timer.timeout.connect(_on_lifetime_expired)

	# Set gold color (override any cached values)
	crystal_sprite.color = Color(1, 0.85, 0.2, 1)  # Gold
	glow.color = Color(1, 0.75, 0.1, 0.3)  # Gold glow

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]

	# Spawn animation
	_spawn_animation()

func _spawn_animation():
	# Start small and grow
	visual.scale = Vector2.ZERO
	position.y -= 40

	var tween = create_tween()
	tween.set_parallel(true)

	# Pop in
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Drop down
	tween.tween_property(self, "position:y", position.y + 40, 0.3)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# Return to normal scale
	tween.chain().tween_property(visual, "scale", Vector2.ONE, 0.1)

	await tween.finished
	spawn_animation_done = true

func _process(delta):
	time_alive += delta

	# Idle animation - pulse and rotate
	if spawn_animation_done and not is_magnetized:
		var pulse = abs(sin(time_alive * 3.0)) * 0.15 + 0.85
		crystal_sprite.scale = Vector2(pulse, pulse)
		glow.scale = Vector2(pulse * 1.2, pulse * 1.2)

		# Rotate crystal
		crystal_sprite.rotation += delta * 2.0
		glow.rotation -= delta * 1.5

	# Pulse glow
	var glow_alpha = abs(sin(time_alive * 4.0)) * 0.3 + 0.2
	glow.modulate.a = glow_alpha

	# Blink when about to expire
	if lifetime_timer.time_left < 5.0:
		var blink = int(time_alive * 8) % 2
		visual.modulate.a = 0.5 if blink == 0 else 1.0

func _physics_process(delta):
	if not player_reference or not spawn_animation_done:
		return

	# Check distance to player for magnetization
	var distance = global_position.distance_to(player_reference.global_position)

	if distance < magnet_range:
		is_magnetized = true

		# Move toward player
		var direction = (player_reference.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta

		# Increase speed as we get closer
		var speed_multiplier = 1.0 + (1.0 - distance / magnet_range)
		global_position += direction * magnet_speed * speed_multiplier * delta

func _on_area_entered(area: Area2D):
	# Check if it's the player's hurtbox
	if area.get_parent() == player_reference:
		_collect()

func _on_body_entered(body: Node2D):
	# Check if it's the player
	if body == player_reference:
		_collect()

func _collect():
	# Prevent double collection
	if not visible:
		return

	# Emit signal
	gold_collected.emit(gold_value)

	# Notify game manager to add gold
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("add_gold"):
		game_manager.add_gold(gold_value)

	# Collection animation
	_collection_animation()

func _collection_animation():
	# Disable collision
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Shrink and move up
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(visual, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "position:y", position.y - 80, 0.3)
	tween.tween_property(visual, "modulate:a", 0.0, 0.3)

	await tween.finished
	queue_free()

func _on_lifetime_expired():
	# Fade out and disappear
	var tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
