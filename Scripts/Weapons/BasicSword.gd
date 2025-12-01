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

# Combo system
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 2.0  # Reset combo after 2 seconds
const COMBO_FINISHER_MULTIPLIER: float = 1.5

# Attack speed scaling
var base_attack_cooldown: float = 0.35
const SPEED_BOOST_PER_HIT: float = 0.1  # 10% faster per hit

# Critical hit system
const CRIT_CHANCE: float = 0.2  # 20% chance
const CRIT_MULTIPLIER: float = 2.0

# Dash attack system
var player_reference: Node2D = null
const DASH_ATTACK_WINDOW: float = 0.2
const DASH_ATTACK_MULTIPLIER: float = 1.5

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

	# Start visible and always show (like staff)
	visible = true
	modulate.a = 1.0

	# Default idle state - small sword
	# Position is FULLY controlled by Player's WeaponPivot - we only control rotation and scale
	pivot.position = Vector2.ZERO  # No offset - Player controls position
	pivot.rotation = deg_to_rad(45)  # Angled down
	sprite.scale = Vector2(0.6, 0.6)  # Smaller when idle

	# Get player reference for dash attacks
	await get_tree().process_frame
	player_reference = get_tree().get_first_node_in_group("player")

func _process(delta):
	# Update combo timer
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0  # Reset combo

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

	# Increment combo
	combo_count += 1
	combo_timer = COMBO_WINDOW

	# Calculate attack speed based on combo
	var speed_multiplier = 1.0 + (min(combo_count - 1, 2) * SPEED_BOOST_PER_HIT)
	var modified_duration = attack_duration / speed_multiplier
	var modified_cooldown = base_attack_cooldown / speed_multiplier

	# Check for dash attack bonus
	var is_dash_attack = false
	if player_reference and player_reference.is_dashing:
		is_dash_attack = true
		print("DASH ATTACK!")

	# Perform the appropriate swing style with modified timing
	match swing_style:
		"overhead":
			_perform_overhead_swing(modified_duration, is_dash_attack)
		"horizontal":
			_perform_horizontal_swing(modified_duration, is_dash_attack)
		"stab":
			_perform_stab_attack(modified_duration, is_dash_attack)
		_:
			_perform_overhead_swing(modified_duration, is_dash_attack)

	# Start cooldown with speed scaling
	attack_timer.start(modified_cooldown)

	return true

func _perform_overhead_swing(duration: float = 0.25, is_dash_attack: bool = false):
	# Enhanced visuals for combo finisher
	var is_combo_finisher = (combo_count == 3)
	if is_combo_finisher:
		sprite.color = Color.GOLD  # Gold for combo finisher
	elif is_dash_attack:
		sprite.color = Color.CYAN  # Cyan for dash attack

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale up from idle size to full attack size
	tween.tween_property(sprite, "scale", Vector2.ONE, duration * 0.3)

	# Starting position - raised up and back
	pivot.rotation = deg_to_rad(-120)
	pivot.position = Vector2(-5, -10)

	# Create swing arc
	tween.set_parallel(false)

	# Anticipation - pull back slightly more (shorter for speed)
	tween.tween_property(pivot, "rotation", deg_to_rad(-130), duration * 0.2)
	tween.parallel().tween_property(pivot, "position", Vector2(-8, -12), duration * 0.2)

	# Enable hitbox and create enhanced trail
	tween.tween_callback(func():
		hit_box_collision.disabled = false
		_create_swing_trail(is_combo_finisher, is_dash_attack)
	)

	# Main swing - more stretch for combo finisher
	var stretch_amount = 1.7 if is_combo_finisher else 1.5
	sprite.scale = Vector2(stretch_amount, 0.6)
	tween.tween_property(pivot, "rotation", deg_to_rad(70), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", Vector2(5, 5), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Reset scale with bounce
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Follow through
	tween.tween_property(pivot, "rotation", deg_to_rad(90), duration * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)

	# Return to idle position
	tween.tween_property(pivot, "position", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(pivot, "rotation", deg_to_rad(45), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.15)

	# Finish
	tween.tween_callback(finish_attack)

func _perform_horizontal_swing(duration: float = 0.25, is_dash_attack: bool = false):
	# Enhanced visuals for combo finisher
	var is_combo_finisher = (combo_count == 3)
	if is_combo_finisher:
		sprite.color = Color.GOLD  # Gold for combo finisher
	elif is_dash_attack:
		sprite.color = Color.CYAN  # Cyan for dash attack

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale up from idle size to full attack size
	tween.tween_property(sprite, "scale", Vector2.ONE, duration * 0.3)

	# Starting position - pulled to the side
	pivot.rotation = deg_to_rad(-90)
	pivot.position = Vector2(-8, 0)

	tween.set_parallel(false)

	# Anticipation
	tween.tween_property(pivot, "rotation", deg_to_rad(-100), duration * 0.2)

	# Enable hitbox and create enhanced trail
	tween.tween_callback(func():
		hit_box_collision.disabled = false
		_create_swing_trail(is_combo_finisher, is_dash_attack)
	)

	# Main sweep - more stretch for combo finisher
	var stretch_amount = 0.6 if is_combo_finisher else 0.7
	sprite.scale.y = stretch_amount
	tween.tween_property(pivot, "rotation", deg_to_rad(90), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", Vector2(8, 0), duration * 0.5)

	# Reset scale with bounce
	tween.parallel().tween_property(sprite, "scale:y", 1.0, duration * 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Follow through
	tween.tween_property(pivot, "rotation", deg_to_rad(100), duration * 0.3)

	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)

	# Return to idle position
	tween.tween_property(pivot, "position", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(pivot, "rotation", deg_to_rad(45), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.15)

	tween.tween_callback(finish_attack)

func _perform_stab_attack(duration: float = 0.25, is_dash_attack: bool = false):
	# Enhanced visuals for combo finisher
	var is_combo_finisher = (combo_count == 3)
	if is_combo_finisher:
		sprite.color = Color.GOLD  # Gold for combo finisher
	elif is_dash_attack:
		sprite.color = Color.CYAN  # Cyan for dash attack

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale up from idle size to full attack size
	tween.tween_property(sprite, "scale", Vector2.ONE, duration * 0.3)

	# Starting position - pulled back
	pivot.rotation = 0
	pivot.position = Vector2(-15, 0)

	tween.set_parallel(false)

	# Pull back more (anticipation)
	tween.tween_property(pivot, "position", Vector2(-20, 0), duration * 0.3)

	# Enable hitbox and create enhanced trail
	tween.tween_callback(func():
		hit_box_collision.disabled = false
		_create_swing_trail(is_combo_finisher, is_dash_attack)
	)

	# Thrust forward - faster and further for combo finisher
	var thrust_distance = 18.0 if is_combo_finisher else 15.0
	tween.tween_property(pivot, "position", Vector2(thrust_distance, 0), duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Scale for impact - more stretch for combo finisher
	var stretch_amount = 1.8 if is_combo_finisher else 1.5
	tween.parallel().tween_property(sprite, "scale:x", stretch_amount, duration * 0.2)
	tween.tween_property(sprite, "scale:x", 1.0, duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Pull back
	tween.tween_property(pivot, "position", Vector2(0, 0), duration * 0.3)

	# Disable hitbox
	tween.tween_callback(func(): hit_box_collision.disabled = true)

	# Return to idle position
	tween.tween_property(pivot, "position", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(pivot, "rotation", deg_to_rad(45), 0.15)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.6, 0.6), 0.15)

	tween.tween_callback(finish_attack)

func finish_attack():
	# Use set_deferred to avoid "flushing queries" error
	hit_box_collision.set_deferred("disabled", true)
	is_attacking = false
	# Keep sword visible at all times
	pivot.rotation = deg_to_rad(45)  # Idle angle
	pivot.position = Vector2.ZERO  # No offset - Player controls all positioning
	sprite.color = Color("#c0c0c0")  # Reset to silver
	sprite.scale = Vector2(0.6, 0.6)  # Idle size
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

		# Apply combo finisher bonus (3rd hit)
		var is_combo_finisher = (combo_count == 3)
		if is_combo_finisher:
			final_damage *= COMBO_FINISHER_MULTIPLIER
			print("COMBO FINISHER! x%.1f damage" % COMBO_FINISHER_MULTIPLIER)

		# Apply dash attack bonus
		if player_reference and player_reference.is_dashing:
			final_damage *= DASH_ATTACK_MULTIPLIER
			print("DASH BONUS! x%.1f damage" % DASH_ATTACK_MULTIPLIER)

		# Apply critical hit
		var is_crit = randf() < CRIT_CHANCE
		if is_crit:
			final_damage *= CRIT_MULTIPLIER
			print("CRITICAL HIT!")
			_spawn_crit_text(parent.global_position)

		parent.take_damage(final_damage)
		dealt_damage.emit(parent, final_damage)

		# Enhanced visual feedback on hit
		_create_hit_effect(is_combo_finisher, is_crit)
		_create_impact_particles(parent.global_position, is_combo_finisher, is_crit)

		# Combo finisher gets longer hitstop
		var freeze_duration = clamp(final_damage / 100.0, 0.01, 0.05)
		if is_combo_finisher:
			freeze_duration *= 1.5  # 50% longer freeze for combo finisher

		Engine.time_scale = 0.05  # Slow to 5% speed for dramatic effect
		await get_tree().create_timer(freeze_duration, true, false, true).timeout
		Engine.time_scale = 1.0

		# Reset combo after finisher
		if is_combo_finisher:
			combo_count = 0

func _on_hit_box_body_entered(body: Node2D):
	if body in hits_this_swing:
		return
		
	if body.has_method("take_damage"):
		hits_this_swing.append(body)
		var final_damage = damage * damage_multiplier
		body.take_damage(final_damage)
		dealt_damage.emit(body, final_damage)
		_create_hit_effect()

func _create_hit_effect(is_combo_finisher: bool = false, is_crit: bool = false):
	# Flash color based on hit type
	if is_crit:
		sprite.color = Color.RED  # Red flash for crit
	elif is_combo_finisher:
		sprite.color = Color.GOLD  # Gold flash for combo finisher
	else:
		sprite.color = Color.WHITE

	var original_scale = sprite.scale
	var squash_amount = 1.6 if (is_combo_finisher or is_crit) else 1.4
	sprite.scale = Vector2(squash_amount, 0.8)  # Squash on impact

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "color", Color("#c0c0c0"), 0.1)
	tween.tween_property(sprite, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _create_impact_particles(hit_position: Vector2, is_combo_finisher: bool = false, is_crit: bool = false):
	# More particles for special hits
	var particle_count = 8 if (is_combo_finisher or is_crit) else 4

	# Color based on hit type
	var particle_color = Color(1.0, 0.9, 0.5, 1.0)  # Default yellow-white
	if is_crit:
		particle_color = Color.RED
	elif is_combo_finisher:
		particle_color = Color.GOLD

	for i in range(particle_count):
		var particle = ColorRect.new()
		var size = 6 if (is_combo_finisher or is_crit) else 4
		particle.size = Vector2(size, size)
		particle.color = particle_color
		get_tree().current_scene.add_child(particle)
		particle.global_position = hit_position

		# Random direction outward
		var angle = (TAU / particle_count) * i + randf_range(-0.2, 0.2)
		var direction = Vector2.from_angle(angle)
		var distance = randf_range(20, 35) if (is_combo_finisher or is_crit) else randf_range(15, 25)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position",
			hit_position + direction * distance, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
		tween.tween_callback(particle.queue_free)

func _spawn_crit_text(position: Vector2):
	# Create "CRIT!" text
	var crit_label = Label.new()
	crit_label.text = "CRIT!"
	crit_label.add_theme_font_size_override("font_size", 24)
	crit_label.modulate = Color.RED
	get_tree().current_scene.add_child(crit_label)
	crit_label.global_position = position + Vector2(-20, -30)

	# Animate
	var tween = create_tween()
	tween.tween_property(crit_label, "global_position:y", position.y - 50, 0.5)
	tween.parallel().tween_property(crit_label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(crit_label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.parallel().tween_property(crit_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(crit_label.queue_free)

func _create_swing_trail(is_combo_finisher: bool = false, is_dash_attack: bool = false):
	# Create motion trail effect during swing
	var trail_count = 5 if (is_combo_finisher or is_dash_attack) else 3

	for i in range(trail_count):
		await get_tree().create_timer(0.02).timeout

		var trail = ColorRect.new()
		trail.size = sprite.size

		# Enhanced colors for special attacks
		if is_combo_finisher:
			trail.color = Color.GOLD.darkened(0.2)  # Gold trail for combo finisher
		elif is_dash_attack:
			trail.color = Color.CYAN.darkened(0.2)  # Cyan trail for dash attack
		else:
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
