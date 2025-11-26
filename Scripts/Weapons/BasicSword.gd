# SCRIPT: BasicSword.gd
# ATTACH TO: BasicSword (Node2D) root node in BasicSword.tscn
# LOCATION: res://scripts/weapons/BasicSword.gd

class_name BasicSword
extends Node2D

# Weapon stats
@export var damage: float = 10.0
@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.35
@export var max_durability: int = 50
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
var current_durability: int
var is_attacking: bool = false
var can_attack: bool = true
var damage_multiplier: float = 1.0
var hits_this_swing: Array = []  # Track what we hit this swing

# Signals
signal attack_finished
signal weapon_broke
signal dealt_damage(target: Node2D, damage: float)

func _ready():
	current_durability = max_durability
	
	# Connect hit detection
	hit_box.area_entered.connect(_on_hit_box_area_entered)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Start with hitbox disabled
	hit_box_collision.disabled = true
	
	# Visual setup
	update_durability_visual()
	
	# Start hidden
	visible = false
	modulate.a = 0.0

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
	
	# Use durability
	current_durability -= 1
	update_durability_visual()
	
	if current_durability <= 0:
		weapon_broke.emit()
		queue_free()
	
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
	
	# Enable hitbox just before main swing
	tween.tween_callback(func(): hit_box_collision.disabled = false)
	
	# Main swing - fast and powerful
	tween.tween_property(pivot, "rotation", deg_to_rad(70), attack_duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pivot, "position", Vector2(5, 5), attack_duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Add slash trail effect
	tween.parallel().tween_property(sprite, "scale:x", 1.3, attack_duration * 0.3)
	tween.tween_property(sprite, "scale:x", 1.0, attack_duration * 0.2)
	
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
		
		# Visual feedback on hit
		_create_hit_effect()
		
		# Small hitstop for impact feel
		get_tree().paused = true
		await get_tree().create_timer(0.02).timeout
		get_tree().paused = false

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
	# Flash white on hit
	sprite.color = Color.WHITE
	await get_tree().create_timer(0.05).timeout
	update_durability_visual()

func update_durability_visual():
	var durability_percent = float(current_durability) / float(max_durability)
	
	if durability_percent > 0.5:
		sprite.color = Color("#c0c0c0")  # Silver
	elif durability_percent > 0.25:
		sprite.color = Color("#ffaa00")  # Orange
	else:
		sprite.color = Color("#ff0000")  # Red

func repair(amount: int):
	current_durability = min(current_durability + amount, max_durability)
	update_durability_visual()

func get_durability_percentage() -> float:
	return float(current_durability) / float(max_durability)
