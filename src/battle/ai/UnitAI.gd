class_name UnitAI
extends Node

const STATE_IDLE := 0
const STATE_MOVE := 1
const STATE_ATTACK := 2

var unit: Unit = null
var target: Unit = null
var state: int = STATE_IDLE
var attack_cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	if unit == null or unit.is_dead:
		return
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	match state:
		STATE_IDLE:
			_state_idle()
		STATE_MOVE:
			_state_move(delta)
		STATE_ATTACK:
			_state_attack(delta)


func _state_idle() -> void:
	if not _has_valid_target():
		target = _find_nearest_enemy()
	if target != null:
		state = STATE_MOVE
		unit._play("walk")


func _state_move(_delta: float) -> void:
	if not _has_valid_target():
		target = _find_nearest_enemy()
		if target == null:
			unit.velocity = Vector2.ZERO
			unit._play("idle")
			state = STATE_IDLE
			return

	var to_target: Vector2 = target.global_position - unit.global_position
	var dist: float = to_target.length()
	if dist <= unit.data.attack_range:
		unit.velocity = Vector2.ZERO
		state = STATE_ATTACK
		return

	var dir: Vector2 = to_target / max(0.001, dist)
	unit.velocity = dir * unit.data.move_speed
	unit.move_and_slide()


func _state_attack(_delta: float) -> void:
	if not _has_valid_target():
		target = null
		state = STATE_IDLE
		unit._play("idle")
		return

	var dist: float = unit.global_position.distance_to(target.global_position)
	if dist > unit.data.attack_range * 1.15:
		state = STATE_MOVE
		unit._play("walk")
		return

	if attack_cooldown <= 0.0:
		unit._play("attack", true)
		target.take_damage(unit.data.attack)
		attack_cooldown = unit.data.attack_interval


func _has_valid_target() -> bool:
	return target != null and is_instance_valid(target) and not target.is_dead


func _find_nearest_enemy() -> Unit:
	var enemy_group: String = "team_enemy" if unit.team == 0 else "team_ally"
	var candidates: Array = unit.get_tree().get_nodes_in_group(enemy_group)
	var nearest: Unit = null
	var nearest_dist: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var enemy: Unit = c as Unit
		if enemy == null or enemy.is_dead:
			continue
		var d: float = unit.global_position.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest
