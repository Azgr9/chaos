# SCRIPT: EliteModifier.gd
# ATTACH TO: As component on Enemy nodes
# LOCATION: res://Scripts/Systems/EliteModifier.gd
# Handles elite enemy modifiers

class_name EliteModifier
extends Node

# ============================================
# ENUMS
# ============================================
enum ModifierType {
	THORNS,     # Reflect damage back to attacker
	HASTE,      # Faster movement and attacks
	VAMPIRIC,   # Heals on dealing damage
	SHIELDED    # Damage reduction until shield breaks
}

# ============================================
# CONSTANTS
# ============================================
const THORNS_REFLECT_PERCENT: float = 0.25  # 25% damage reflected
const HASTE_SPEED_BONUS: float = 1.5  # 50% faster
const VAMPIRIC_HEAL_PERCENT: float = 0.3  # 30% of damage dealt
const SHIELD_DAMAGE_REDUCTION: float = 0.5  # 50% damage reduction
const SHIELD_HEALTH_THRESHOLD: float = 0.5  # Shield breaks at 50% HP

const ELITE_HP_MULTIPLIER: float = 2.0
const ELITE_GOLD_MULTIPLIER: int = 3
const ELITE_CRYSTAL_GUARANTEED: bool = true

# Modifier colors for aura
const MODIFIER_COLORS = {
	ModifierType.THORNS: Color(0.8, 0.2, 0.8, 1.0),     # Purple
	ModifierType.HASTE: Color(1.0, 0.8, 0.2, 1.0),      # Yellow
	ModifierType.VAMPIRIC: Color(0.8, 0.1, 0.2, 1.0),   # Dark red
	ModifierType.SHIELDED: Color(0.3, 0.6, 1.0, 1.0)    # Blue
}

const MODIFIER_NAMES = {
	ModifierType.THORNS: "Thorns",
	ModifierType.HASTE: "Haste",
	ModifierType.VAMPIRIC: "Vampiric",
	ModifierType.SHIELDED: "Shielded"
}

# ============================================
# STATE
# ============================================
var enemy: Node2D = null
var modifier_type: ModifierType = ModifierType.THORNS
var is_elite: bool = false
var shield_active: bool = true
var base_speed: float = 0.0

# Visual nodes
var aura_visual: Node2D = null
var elite_label: Label = null

# ============================================
# SIGNALS
# ============================================
signal shield_broken()
signal thorns_triggered(damage: float)
signal vampiric_heal(amount: float)

# ============================================
# LIFECYCLE
# ============================================
func _ready():
	enemy = get_parent()
	if enemy:
		base_speed = enemy.move_speed if "move_speed" in enemy else 0

func setup_elite(mod_type: ModifierType):
	if not enemy:
		enemy = get_parent()

	is_elite = true
	modifier_type = mod_type

	# Apply elite stat bonuses
	_apply_elite_stats()

	# Apply modifier-specific effects
	_apply_modifier()

	# Create visuals
	_create_elite_visuals()

	# Connect to damage signals
	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_enemy_health_changed)

func _apply_elite_stats():
	if not enemy:
		return

	# Double HP
	if "max_health" in enemy:
		enemy.max_health *= ELITE_HP_MULTIPLIER
		enemy.current_health = enemy.max_health

	# Increase gold drops
	if "gold_drop_min" in enemy:
		enemy.gold_drop_min *= ELITE_GOLD_MULTIPLIER
		enemy.gold_drop_max *= ELITE_GOLD_MULTIPLIER

	# Guaranteed crystal drop
	if "crystal_drop_chance" in enemy:
		enemy.crystal_drop_chance = 1.0
		enemy.min_crystals = max(enemy.min_crystals, 2)
		enemy.max_crystals = max(enemy.max_crystals, 5)

func _apply_modifier():
	match modifier_type:
		ModifierType.HASTE:
			if "move_speed" in enemy:
				enemy.move_speed *= HASTE_SPEED_BONUS

		ModifierType.SHIELDED:
			shield_active = true

# ============================================
# MODIFIER EFFECTS
# ============================================
func on_take_damage(amount: float, attacker: Node2D = null) -> float:
	if not is_elite:
		return amount

	var final_damage = amount

	# Shielded: reduce damage while shield active
	if modifier_type == ModifierType.SHIELDED and shield_active:
		final_damage *= (1.0 - SHIELD_DAMAGE_REDUCTION)
		_create_shield_hit_effect()

	# Thorns: reflect damage to attacker
	if modifier_type == ModifierType.THORNS and attacker and is_instance_valid(attacker):
		var reflect_damage = amount * THORNS_REFLECT_PERCENT
		if attacker.has_method("take_damage"):
			# Delay slightly so it doesn't interrupt attack
			call_deferred("_reflect_thorns_damage", attacker, reflect_damage)
		thorns_triggered.emit(reflect_damage)

	return final_damage

func _reflect_thorns_damage(attacker: Node2D, damage: float):
	if not is_instance_valid(attacker):
		return

	if attacker.is_in_group("player"):
		attacker.take_damage(damage, enemy.global_position if enemy else Vector2.ZERO)
	else:
		attacker.take_damage(damage, enemy.global_position if enemy else Vector2.ZERO, 0.0, 0.0, null)

	# Visual feedback
	_create_thorns_effect(attacker.global_position)

func on_deal_damage(amount: float, _target: Node2D):
	if not is_elite:
		return

	# Vampiric: heal on damage dealt
	if modifier_type == ModifierType.VAMPIRIC:
		var heal_amount = amount * VAMPIRIC_HEAL_PERCENT
		if enemy and "current_health" in enemy and "max_health" in enemy:
			enemy.current_health = min(enemy.current_health + heal_amount, enemy.max_health)
			_create_vampiric_effect()
			vampiric_heal.emit(heal_amount)

func _on_enemy_health_changed(current: float, max_val: float):
	if not is_elite:
		return

	# Check shield break for shielded modifier
	if modifier_type == ModifierType.SHIELDED and shield_active:
		var health_percent = current / max_val
		if health_percent <= SHIELD_HEALTH_THRESHOLD:
			_break_shield()

func _break_shield():
	shield_active = false
	shield_broken.emit()

	# Visual feedback - shield shatter
	_create_shield_break_effect()

	# Update aura color to indicate shield is down
	if aura_visual:
		for child in aura_visual.get_children():
			if child is ColorRect:
				child.color = Color(0.5, 0.5, 0.5, 0.3)

# ============================================
# VISUALS
# ============================================
func _create_elite_visuals():
	if not enemy:
		return

	var mod_color = MODIFIER_COLORS[modifier_type]

	# Create glowing aura
	aura_visual = Node2D.new()
	enemy.add_child(aura_visual)

	# Outer glow ring
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = mod_color
		particle.color.a = 0.4
		var angle = (TAU / 8) * i
		particle.position = Vector2.from_angle(angle) * 40
		aura_visual.add_child(particle)

		# Rotate around enemy
		var tween = particle.create_tween().set_loops()
		tween.tween_property(aura_visual, "rotation", TAU, 3.0)

	# Pulsing inner glow
	var inner_glow = ColorRect.new()
	inner_glow.size = Vector2(80, 80)
	inner_glow.position = Vector2(-40, -40)
	inner_glow.color = mod_color
	inner_glow.color.a = 0.2
	aura_visual.add_child(inner_glow)

	var pulse_tween = inner_glow.create_tween().set_loops()
	pulse_tween.tween_property(inner_glow, "modulate:a", 0.5, 0.5)
	pulse_tween.tween_property(inner_glow, "modulate:a", 1.0, 0.5)

	# Elite label above enemy
	elite_label = Label.new()
	elite_label.text = MODIFIER_NAMES[modifier_type]
	elite_label.add_theme_font_size_override("font_size", 12)
	elite_label.modulate = mod_color
	elite_label.position = Vector2(-30, -60)
	enemy.add_child(elite_label)

func _create_thorns_effect(target_pos: Vector2):
	if not enemy:
		return

	# Purple spikes shooting toward attacker
	for i in range(4):
		var spike = ColorRect.new()
		spike.size = Vector2(8, 16)
		spike.color = MODIFIER_COLORS[ModifierType.THORNS]
		spike.global_position = enemy.global_position
		spike.rotation = enemy.global_position.angle_to_point(target_pos)
		get_tree().current_scene.add_child(spike)

		var direction = (target_pos - enemy.global_position).normalized()
		var offset = direction.rotated(randf_range(-0.3, 0.3))

		var tween = spike.create_tween()
		tween.tween_property(spike, "global_position", enemy.global_position + offset * 100, 0.2)
		tween.parallel().tween_property(spike, "modulate:a", 0.0, 0.2)
		tween.tween_callback(spike.queue_free)

func _create_vampiric_effect():
	if not enemy:
		return

	# Red particles flowing into enemy
	for i in range(3):
		var particle = ColorRect.new()
		particle.size = Vector2(6, 6)
		particle.color = MODIFIER_COLORS[ModifierType.VAMPIRIC]
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		particle.global_position = enemy.global_position + offset
		get_tree().current_scene.add_child(particle)

		var tween = particle.create_tween()
		tween.tween_property(particle, "global_position", enemy.global_position, 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

func _create_shield_hit_effect():
	if not enemy:
		return

	# Blue flash
	var flash = ColorRect.new()
	flash.size = Vector2(60, 60)
	flash.position = Vector2(-30, -30)
	flash.color = MODIFIER_COLORS[ModifierType.SHIELDED]
	flash.color.a = 0.5
	enemy.add_child(flash)

	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _create_shield_break_effect():
	if not enemy:
		return

	# Shield shatter particles
	for i in range(12):
		var shard = ColorRect.new()
		shard.size = Vector2(10, 10)
		shard.color = MODIFIER_COLORS[ModifierType.SHIELDED]
		shard.global_position = enemy.global_position
		get_tree().current_scene.add_child(shard)

		var angle = (TAU / 12) * i
		var direction = Vector2.from_angle(angle)

		var tween = shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", enemy.global_position + direction * 80, 0.4)
		tween.tween_property(shard, "modulate:a", 0.0, 0.4)
		tween.tween_property(shard, "rotation", randf() * TAU, 0.4)
		tween.tween_callback(shard.queue_free)

	# Screen shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.3)

# ============================================
# UTILITY
# ============================================
func get_modifier_name() -> String:
	return MODIFIER_NAMES[modifier_type]

func get_modifier_color() -> Color:
	return MODIFIER_COLORS[modifier_type]

static func get_random_modifier() -> ModifierType:
	var types = [ModifierType.THORNS, ModifierType.HASTE, ModifierType.VAMPIRIC, ModifierType.SHIELDED]
	return types[randi() % types.size()]
