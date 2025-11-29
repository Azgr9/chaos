# SCRIPT: BasicSword.gd
# ATTACH TO: BasicSword (Node2D) root node in BasicSword.tscn
# LOCATION: res://scripts/weapons/BasicSword.gd

class_name BasicSword
extends Node2D

# Weapon stats
@export var damage: float = 10.0
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.35
@export var swing_arc: float = 150.0  # Total arc of swing

# Visual settings
@export var sword_length: float = 20.0
@export var swing_style: String = "overhead"  # "overhead", "horizontal", "stab"

# Nodes
@onready var pivot: Node2D = $Pivot
@onready var sprite: ColorRect = $Pivot/Sprite
@onready var hit_box: Area2D = $Pivot/HitBox
@onready var hit_box_collision: CollisionShape2D = $Pivot/HitBox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer

# State
var is_attacking: bool = false
var can_attack: bool = true
var damage_multiplier: float = 1.0
var hits_this_swing: Array = []  # Track what we hit this swing

# Skill system
var skill_cooldown: float = 8.0  # 8 seconds cooldown
var skill_ready: bool = true
var skill_timer: float = 0.0
const SPIN_SLASH_SCENE = preload("res://Scenes/Weapons/SpinSlash.tscn")

# Signals
signal attack_finished
signal dealt_damage(target: Node2D, damage: float)
signal skill_used(cooldown: float)
signal skill_ready_changed(ready: bool)

func _ready():
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)

	# Start with hitbox disabled
	hit_box_collision.disabled = true

	# Visual setup
	sprite.color = Color("#c0c0c0")  # Silver

	# Start hidden
	visible = false
	modulate.a = 0.0

func _process(delta):
	# Update skill cooldown
	if not skill_ready:
		skill_timer -= delta
		if skill_timer <= 0:
			skill_ready = true
			skill_ready_changed.emit(true)

func use_skill() -> bool:
	if not skill_ready or is_attacking:
		return false

	skill_ready = false
	skill_timer = skill_cooldown
	skill_used.emit(skill_cooldown)
	skill_ready_changed.emit(false)

	# Perform 360 spin slash
	_perform_spin_slash()

	return true

func _perform_spin_slash():
	# Spawn a separate spinning slash effect at player position
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Create the spin slash effect
	var spin_slash = SPIN_SLASH_SCENE.instantiate()
	get_tree().current_scene.add_child(spin_slash)

	# Initialize with player position and double damage
	var slash_damage = damage * 2.0 * damage_multiplier
	spin_slash.initialize(player.global_position, slash_damage)

	# Connect damage signal
	if spin_slash.has_signal("dealt_damage"):
		spin_slash.dealt_damage.connect(func(target, dmg):
			dealt_damage.emit(target, dmg)
		)

func get_skill_cooldown_percent() -> float:
	if skill_ready:
		return 1.0
	return 1.0 - (skill_timer / skill_cooldown)

func attack(_direction: Vector2, player_damage_multiplier: float = 1.0):
	if not can_attack or is_attacking:
		return false

	damage_multiplier = player_damage_multiplier
	is_attacking = true
	can_attack = false
	hits_this_swing.clear()

	# Perform the appropriate swing style
	match swing_style:
		"overhead":
			_perform_overhead_swing()
		"horizontal":
			_perform_horizontal_swing()
		"stab":
			_perform_stab_attack()
		_:
			_perform_overhead_swing()

	return true

func _perform_overhead_swing():
	# Make sword visible with fade in
	visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	# Starting position - raised up and back
	pivot.rotation = deg_to_rad(-120)
	pivot.position = Vector2(-5, -10)  # Pull back and up
	
	# Create swing arc
	tween.set_parallel(false)
	
	# Anticipation - pull back slightly more
	tween.tween_property(pivot, "rotation", deg_to_rad(-130), attack_duration * 0.2)
	tween.parallel().tween_property(pivot, "position", Vector2(-8, -12), attack_duration * 0.2)
	
	# Enable hitbox and create trail just before main swing
	tween.tween_callback(func():
		hit_box_collision.disabled = false
		_create_swing_trail()
	)

	# Main swing - fast and powerful with stretch
	sprite.scale = Vector2(1.5, 0.7)  # Stretch for speed
	tween.tween_property(pivot, "rotation", deg_to_rad(70), attack_duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", Vector2(5, 5), attack_duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Reset scale with bounce
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, attack_duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Follow through
	tween.tween_property(pivot, "rotation", deg_to_rad(90), attack_duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	
	# Finish
	tween.tween_callback(finish_attack)
	
	# Start cooldown timer
	attack_timer.start(attack_cooldown)

func _perform_horizontal_swing():
	visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	# Starting position - pulled to the side
	pivot.rotation = deg_to_rad(-90)
	pivot.position = Vector2(-8, 0)
	
	tween.set_parallel(false)
	
	# Anticipation
	tween.tween_property(pivot, "rotation", deg_to_rad(-100), attack_duration * 0.2)
	
	# Enable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = false)
	
	# Main sweep
	tween.tween_property(pivot, "rotation", deg_to_rad(90), attack_duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", Vector2(8, 0), attack_duration * 0.5)
	
	# Stretch effect for speed
	tween.parallel().tween_property(sprite, "scale:y", 0.7, attack_duration * 0.3)
	tween.tween_property(sprite, "scale:y", 1.0, attack_duration * 0.2)
	
	# Follow through
	tween.tween_property(pivot, "rotation", deg_to_rad(100), attack_duration * 0.3)
	
	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	
	tween.tween_callback(finish_attack)
	
	attack_timer.start(attack_cooldown)

func _perform_stab_attack():
	visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	# Starting position - pulled back
	pivot.rotation = 0
	pivot.position = Vector2(-15, 0)
	
	tween.set_parallel(false)
	
	# Pull back more (anticipation)
	tween.tween_property(pivot, "position", Vector2(-20, 0), attack_duration * 0.3)
	
	# Enable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = false)
	
	# Thrust forward
	tween.tween_property(pivot, "position", Vector2(15, 0), attack_duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Scale for impact
	tween.parallel().tween_property(sprite, "scale:x", 1.5, attack_duration * 0.2)
	tween.tween_property(sprite, "scale:x", 1.0, attack_duration * 0.2)
	
	# Pull back
	tween.tween_property(pivot, "position", Vector2(0, 0), attack_duration * 0.3)
	
	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	
	tween.tween_callback(finish_attack)
	
	attack_timer.start(attack_cooldown)

func finish_attack():
	hit_box_collision.disabled = true
	is_attacking = false
	visible = false
	pivot.rotation = 0
	pivot.position = Vector2.ZERO
	attack_finished.emit()

func _on_attack_cooldown_finished():
	can_attack = true

func _on_hit_box_area_entered(area: Area2D):
	var parent = area.get_parent()

	# Don't hit the same enemy twice in one swing
	if parent in hits_this_swing:
		return

	if parent.has_method("take_damage"):
		hits_this_swing.append(parent)
		var final_damage = damage * damage_multiplier
		parent.take_damage(final_damage)
		dealt_damage.emit(parent, final_damage)

		# Enhanced visual feedback on hit
		_create_hit_effect()
		_create_impact_particles(parent.global_position)

		# Dynamic hitstop - use time_scale for better timing control
		var freeze_duration = clamp(final_damage / 100.0, 0.01, 0.05)
		Engine.time_scale = 0.05  # Slow to 5% speed for dramatic effect
		await get_tree().create_timer(freeze_duration, true, false, true).timeout
		Engine.time_scale = 1.0

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_swing:
		return
		
	if body.has_method("take_damage"):
		hits_this_swing.append(body)
		var final_damage = damage * damage_multiplier
		body.take_damage(final_damage)
		dealt_damage.emit(body, final_damage)
		_create_hit_effect()

func _create_hit_effect():
	# Flash white on hit with squash and stretch
	sprite.color = Color.WHITE
	var original_scale = sprite.scale
	sprite.scale = Vector2(1.4, 0.8)  # Squash on impact

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "color", Color("#c0c0c0"), 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _create_impact_particles(hit_position: Vector2):
	# Create impact particles at hit location
	for i in range(4):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(1.0, 0.9, 0.5, 1.0)  # Yellow-white flash
		get_tree().current_scene.add_child(particle)
		particle.global_position = hit_position

		# Random direction outward
		var angle = (TAU / 4.0) * i + randf_range(-0.3, 0.3)
		var direction = Vector2.from_angle(angle)
		var distance = randf_range(15, 25)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position",
			hit_position + direction * distance, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(particle.queue_free)

func _create_swing_trail():
	# Create motion trail effect during swing
	for i in range(3):
		await get_tree().create_timer(0.03).timeout

		var trail = ColorRect.new()
		trail.size = sprite.size
		trail.color = Color(0.8, 0.8, 1.0, 0.4)  # Light blue trail
		get_tree().current_scene.add_child(trail)
		trail.global_position = sprite.global_position
		trail.rotation = pivot.rotation  # Use pivot rotation for correct angle
		trail.scale = sprite.scale

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(trail, "modulate:a", 0.0, 0.2)
		tween.tween_property(trail, "scale", trail.scale * 1.3, 0.2)
		tween.tween_callback(trail.queue_free)
