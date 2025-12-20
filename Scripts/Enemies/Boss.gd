# SCRIPT: Boss.gd
# ATTACH TO: Boss (CharacterBody2D) in Boss.tscn
# LOCATION: res://Scripts/Enemies/Boss.gd
# Wave 5 Boss - The Chaos Champion

class_name Boss
extends Enemy

# ============================================
# BOSS PHASES
# ============================================
enum Phase {
	INTRO,
	PHASE_1,  # Normal attacks
	PHASE_2,  # Adds + faster attacks
	PHASE_3,  # Enraged - all abilities
	DYING
}

# ============================================
# BOSS SETTINGS
# ============================================

# Phase thresholds
const PHASE_2_THRESHOLD: float = 0.6  # 60% HP
const PHASE_3_THRESHOLD: float = 0.3  # 30% HP

# Attack patterns
const SLAM_COOLDOWN: float = 4.0
const SLAM_RADIUS: float = 150.0
const SLAM_DAMAGE: float = 30.0
const SLAM_WARNING_TIME: float = 1.0

const CHARGE_COOLDOWN: float = 6.0
const CHARGE_SPEED: float = 800.0
const CHARGE_DAMAGE: float = 40.0
const CHARGE_DURATION: float = 0.8

const SUMMON_COOLDOWN: float = 8.0
const SUMMON_COUNT: int = 3

const PROJECTILE_COOLDOWN: float = 3.0
const PROJECTILE_COUNT: int = 5
const PROJECTILE_DAMAGE: float = 15.0

# ============================================
# STATE
# ============================================
var current_phase: Phase = Phase.INTRO
var phase_timer: float = 0.0
var attack_cooldowns: Dictionary = {
	"slam": 0.0,
	"charge": 0.0,
	"summon": 0.0,
	"projectile": 0.0
}
var is_performing_attack: bool = false
var intro_complete: bool = false
var summoned_minions: Array = []
var base_speed: float = 0.0  # Stored from scene for phase multipliers

# Visual nodes
@onready var visuals_pivot: Node2D = $VisualsPivot
@onready var body_sprite: ColorRect = $VisualsPivot/Sprite
var aura_container: Node2D = null
var health_bar_boss: Node2D = null

# ============================================
# SIGNALS
# ============================================
signal phase_changed(new_phase: Phase)
signal boss_defeated()

# ============================================
# LIFECYCLE
# ============================================
func _setup_enemy():
	# Stats loaded from scene file via 
	current_health = max_health
	base_speed = move_speed  # Store for phase multipliers

	_create_boss_visuals()
	_start_intro()

func _physics_process(delta):
	if is_dead:
		return

	# Update cooldowns
	_update_cooldowns(delta)

	if not intro_complete:
		return

	super._physics_process(delta)

	if not is_performing_attack:
		_choose_attack()

func _update_cooldowns(delta):
	for attack in attack_cooldowns.keys():
		if attack_cooldowns[attack] > 0:
			attack_cooldowns[attack] -= delta

# ============================================
# INTRO SEQUENCE
# ============================================
func _start_intro():
	current_phase = Phase.INTRO
	is_performing_attack = true

	# Dramatic entrance
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 1.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Screen shake
	await get_tree().create_timer(0.5).timeout
	_add_screen_shake(0.6)

	# Show boss name
	_show_boss_title()

	await get_tree().create_timer(1.5).timeout
	intro_complete = true
	is_performing_attack = false
	current_phase = Phase.PHASE_1
	phase_changed.emit(current_phase)

func _show_boss_title():
	var title = Label.new()
	title.text = "CHAOS CHAMPION"
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(1, 0.3, 0.3, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_tree().current_scene.add_child(title)

	# Center on screen
	title.global_position = Vector2(640 - 200, 300)

	var tween = title.create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(title.queue_free)

# ============================================
# PHASE MANAGEMENT
# ============================================
func _on_damage_taken():
	# Call base class flash (handles the bright white modulate flash)
	super._on_damage_taken()

	# Check phase transitions
	var health_percent = current_health / max_health

	if current_phase == Phase.PHASE_1 and health_percent <= PHASE_2_THRESHOLD:
		_enter_phase_2()
	elif current_phase == Phase.PHASE_2 and health_percent <= PHASE_3_THRESHOLD:
		_enter_phase_3()

func _play_hit_squash():
	# Quick boss squash effect - SNAPPY timing
	if visuals_pivot:
		visuals_pivot.scale = HIT_SQUASH_SCALE
		var scale_tween = create_tween()
		scale_tween.tween_property(visuals_pivot, "scale", Vector2.ONE, HIT_SQUASH_DURATION)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _enter_phase_2():
	current_phase = Phase.PHASE_2
	phase_changed.emit(current_phase)

	# Speed up
	move_speed = base_speed * 1.3

	# Visual - change color
	if body_sprite:
		body_sprite.color = Color(0.8, 0.4, 0.1, 1)

	# Screen shake
	_add_screen_shake(0.5)

	# Announcement
	_show_phase_text("ENRAGING...")

func _enter_phase_3():
	current_phase = Phase.PHASE_3
	phase_changed.emit(current_phase)

	# Even faster
	move_speed = base_speed * 1.5

	# Visual - red rage
	if body_sprite:
		body_sprite.color = Color(1, 0.2, 0.1, 1)

	# Screen shake
	_add_screen_shake(0.7)

	# Announcement
	_show_phase_text("CHAOS UNLEASHED!")

	# Start pulsing aura
	_start_rage_aura()

func _show_phase_text(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(1, 0.5, 0.2, 1)
	get_tree().current_scene.add_child(label)
	label.global_position = global_position + Vector2(-80, -100)

	var tween = label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 50, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

# ============================================
# ATTACK AI
# ============================================
func _choose_attack():
	if not player_reference or is_performing_attack:
		return

	var dist = global_position.distance_to(player_reference.global_position)

	# Phase-based attack selection
	match current_phase:
		Phase.PHASE_1:
			if attack_cooldowns["slam"] <= 0 and dist < 200:
				_perform_slam_attack()
			elif attack_cooldowns["projectile"] <= 0 and dist > 150:
				_perform_projectile_attack()
			else:
				_move_toward_player()

		Phase.PHASE_2:
			if attack_cooldowns["summon"] <= 0 and summoned_minions.size() < 3:
				_perform_summon()
			elif attack_cooldowns["charge"] <= 0 and dist > 200:
				_perform_charge_attack()
			elif attack_cooldowns["slam"] <= 0 and dist < 200:
				_perform_slam_attack()
			elif attack_cooldowns["projectile"] <= 0:
				_perform_projectile_attack()
			else:
				_move_toward_player()

		Phase.PHASE_3:
			# All attacks available, faster cooldowns
			if attack_cooldowns["charge"] <= 0 and dist > 150:
				_perform_charge_attack()
			elif attack_cooldowns["slam"] <= 0 and dist < 250:
				_perform_slam_attack()
			elif attack_cooldowns["summon"] <= 0 and summoned_minions.size() < 5:
				_perform_summon()
			elif attack_cooldowns["projectile"] <= 0:
				_perform_projectile_attack()
			else:
				_move_toward_player()

func _move_toward_player():
	if not player_reference:
		return

	var direction = (player_reference.global_position - global_position).normalized()
	velocity = direction * move_speed

# ============================================
# ATTACKS
# ============================================
func _perform_slam_attack():
	is_performing_attack = true
	attack_cooldowns["slam"] = SLAM_COOLDOWN * (0.7 if current_phase == Phase.PHASE_3 else 1.0)

	# Warning indicator
	_create_slam_warning()

	# Wind up
	await get_tree().create_timer(SLAM_WARNING_TIME).timeout

	# Validate after await
	if not is_instance_valid(self) or is_dead:
		return

	# Slam
	_add_screen_shake(0.5)
	_deal_slam_damage()
	_create_slam_effect()

	await get_tree().create_timer(0.3).timeout

	# Validate after await
	if not is_instance_valid(self):
		return
	is_performing_attack = false

func _create_slam_warning():
	var warning = ColorRect.new()
	warning.size = Vector2(SLAM_RADIUS * 2, SLAM_RADIUS * 2)
	warning.position = Vector2(-SLAM_RADIUS, -SLAM_RADIUS)
	warning.color = Color(1, 0.3, 0.1, 0.3)
	add_child(warning)

	# Pulse warning
	var tween = warning.create_tween().set_loops(int(SLAM_WARNING_TIME / 0.2))
	tween.tween_property(warning, "modulate:a", 0.8, 0.1)
	tween.tween_property(warning, "modulate:a", 0.3, 0.1)

	await get_tree().create_timer(SLAM_WARNING_TIME).timeout
	warning.queue_free()

func _deal_slam_damage():
	if not player_reference:
		return

	var dist = global_position.distance_to(player_reference.global_position)
	if dist < SLAM_RADIUS:
		var damage_applied = player_reference.take_damage(SLAM_DAMAGE, global_position)
		if damage_applied:
			_add_screen_shake(0.3)  # Extra feedback when slam connects

func _create_slam_effect():
	for i in range(16):
		var particle = ColorRect.new()
		particle.size = Vector2(20, 20)
		particle.color = Color(1, 0.5, 0.2, 1)
		get_tree().current_scene.add_child(particle)
		particle.global_position = global_position

		var angle = (TAU / 16) * i
		var direction = Vector2.from_angle(angle)

		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position + direction * SLAM_RADIUS, 0.3)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

func _perform_charge_attack():
	is_performing_attack = true
	attack_cooldowns["charge"] = CHARGE_COOLDOWN * (0.6 if current_phase == Phase.PHASE_3 else 1.0)

	if not player_reference:
		is_performing_attack = false
		return

	# Lock direction
	var charge_dir = (player_reference.global_position - global_position).normalized()

	# Warning telegraph
	_create_charge_warning(charge_dir)
	await get_tree().create_timer(0.5).timeout

	# Validate after await
	if not is_instance_valid(self) or is_dead:
		return

	# Charge!
	var start_pos = global_position
	var end_pos = start_pos + charge_dir * 500

	var tween = create_tween()
	tween.tween_property(self, "global_position", end_pos, CHARGE_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Check for hits during charge
	_charge_hit_check(CHARGE_DURATION)

	await tween.finished
	is_performing_attack = false

func _create_charge_warning(direction: Vector2):
	var indicator = ColorRect.new()
	indicator.size = Vector2(500, 40)
	indicator.position = Vector2(0, -20)
	indicator.rotation = direction.angle()
	indicator.color = Color(1, 0.2, 0.1, 0.4)
	add_child(indicator)

	await get_tree().create_timer(0.5).timeout
	indicator.queue_free()

func _charge_hit_check(duration: float):
	var checks = 10
	for i in range(checks):
		await get_tree().create_timer(duration / checks).timeout
		if is_dead:
			return

		if player_reference and global_position.distance_to(player_reference.global_position) < 60:
			var damage_applied = player_reference.take_damage(CHARGE_DAMAGE, global_position)
			if damage_applied:
				_add_screen_shake(0.4)
			break

func _perform_projectile_attack():
	is_performing_attack = true
	attack_cooldowns["projectile"] = PROJECTILE_COOLDOWN * (0.5 if current_phase == Phase.PHASE_3 else 1.0)

	if not player_reference:
		is_performing_attack = false
		return

	var count = PROJECTILE_COUNT + (2 if current_phase == Phase.PHASE_3 else 0)

	for i in range(count):
		_fire_projectile(i, count)
		await get_tree().create_timer(0.15).timeout

	is_performing_attack = false

func _fire_projectile(index: int, total: int):
	if not player_reference:
		return

	var base_dir = (player_reference.global_position - global_position).normalized()
	var spread = deg_to_rad(30)
	var angle_offset = (index - total / 2.0) * (spread / total)
	var direction = base_dir.rotated(angle_offset)

	var projectile = ColorRect.new()
	projectile.size = Vector2(16, 16)
	projectile.color = Color(1, 0.4, 0.8, 1)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position

	var speed = 400.0
	var lifetime = 3.0
	var time_alive = 0.0

	# Simple projectile movement
	while time_alive < lifetime and is_instance_valid(projectile):
		await get_tree().process_frame
		if not is_instance_valid(projectile):
			break

		var delta = get_process_delta_time()
		time_alive += delta
		projectile.global_position += direction * speed * delta

		# Check player hit
		if player_reference and projectile.global_position.distance_to(player_reference.global_position) < 30:
			var damage_applied = player_reference.take_damage(PROJECTILE_DAMAGE, projectile.global_position)
			if damage_applied:
				# Only destroy projectile if damage went through
				projectile.queue_free()
				break

	if is_instance_valid(projectile):
		projectile.queue_free()

func _perform_summon():
	is_performing_attack = true
	attack_cooldowns["summon"] = SUMMON_COOLDOWN

	# Summon animation
	_add_screen_shake(0.3)

	var count = SUMMON_COUNT + (2 if current_phase == Phase.PHASE_3 else 0)

	for i in range(count):
		await get_tree().create_timer(0.3).timeout
		_spawn_minion()

	is_performing_attack = false

func _spawn_minion():
	# Spawn a slime minion
	var SlimeScene = preload("res://Scenes/Enemies/Slime.tscn")
	var minion = SlimeScene.instantiate()

	var spawn_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	minion.global_position = global_position + spawn_offset

	get_tree().current_scene.add_child(minion)

	if minion.has_method("set_player_reference") and player_reference:
		minion.set_player_reference(player_reference)

	# Track minion
	summoned_minions.append(minion)
	if minion.has_signal("enemy_died"):
		minion.enemy_died.connect(_on_minion_died.bind(minion))

	# Spawn effect
	_create_summon_effect(minion.global_position)

func _on_minion_died(_enemy, minion):
	summoned_minions.erase(minion)

func _create_summon_effect(pos: Vector2):
	for i in range(6):
		var particle = ColorRect.new()
		particle.size = Vector2(10, 10)
		particle.color = Color(0.5, 0.2, 0.8, 1)
		get_tree().current_scene.add_child(particle)

		var offset = Vector2(randf_range(-30, 30), 50)
		particle.global_position = pos + offset

		var tween = particle.create_tween()
		tween.tween_property(particle, "global_position:y", pos.y - 20, 0.4)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(particle.queue_free)

# ============================================
# VISUALS
# ============================================
func _create_boss_visuals():
	# body_sprite is set via @onready from scene's VisualsPivot/Sprite

	# Aura container (created dynamically for rotating effect)
	aura_container = Node2D.new()
	if visuals_pivot:
		visuals_pivot.add_child(aura_container)
	else:
		add_child(aura_container)

	# Create rotating aura particles
	for i in range(8):
		var particle = ColorRect.new()
		particle.size = Vector2(12, 12)
		particle.color = Color(1, 0.3, 0.5, 0.5)
		particle.position = Vector2.from_angle((TAU / 8) * i) * 50
		aura_container.add_child(particle)

	# Rotate aura
	var tween = aura_container.create_tween().set_loops()
	tween.tween_property(aura_container, "rotation", TAU, 3.0)

func _get_phase_color() -> Color:
	match current_phase:
		Phase.PHASE_1: return Color(0.6, 0.2, 0.3, 1)
		Phase.PHASE_2: return Color(0.8, 0.4, 0.1, 1)
		Phase.PHASE_3: return Color(1, 0.2, 0.1, 1)
	return Color(0.6, 0.2, 0.3, 1)

func _start_rage_aura():
	if not aura_container:
		return

	# Make aura pulse red
	var tween = aura_container.create_tween().set_loops()
	tween.tween_property(aura_container, "modulate", Color(1.5, 0.5, 0.5, 1), 0.3)
	tween.tween_property(aura_container, "modulate", Color(1, 1, 1, 1), 0.3)

func _get_death_particle_color() -> Color:
	return Color(1, 0.3, 0.5, 1)

func _get_death_particle_count() -> int:
	return 20

func _on_death():
	current_phase = Phase.DYING
	boss_defeated.emit()

	# Kill all summoned minions
	for minion in summoned_minions:
		if is_instance_valid(minion):
			minion.die()

	# Epic death sequence
	_add_screen_shake(0.8)

	# Explosion particles
	for i in range(30):
		await get_tree().create_timer(0.05).timeout
		_create_death_explosion()

	await get_tree().create_timer(0.5).timeout
	queue_free()

func _create_death_explosion():
	var particle = ColorRect.new()
	particle.size = Vector2(randf_range(15, 30), randf_range(15, 30))
	particle.color = Color(1, randf_range(0.2, 0.5), randf_range(0.2, 0.5), 1)
	get_tree().current_scene.add_child(particle)
	particle.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

	var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var distance = randf_range(100, 200)

	var tween = particle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "global_position", particle.global_position + direction * distance, 0.5)
	tween.tween_property(particle, "modulate:a", 0.0, 0.5)
	tween.tween_property(particle, "rotation", randf() * TAU, 0.5)
	tween.tween_callback(particle.queue_free)
