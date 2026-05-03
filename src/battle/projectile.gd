class_name Projectile
extends Node2D

# Simple homing projectile. Despawns on hit or if target dies before arrival.

const SPEED := 780.0
const HIT_RADIUS := 21.0

var target: Unit
var source: Unit            # 발사자 — 명중 시 ON_KILL 트리거를 위해 콜백.
var damage: float
var origin: Vector2
var _stray_dir: Vector2 = Vector2.ZERO
var _stray_time: float = 0.0
const STRAY_LIFETIME := 0.6

func setup(from: Vector2, to_unit: Unit, dmg: float, src: Unit = null) -> void:
	origin = from
	target = to_unit
	source = src
	damage = dmg
	global_position = from

func _ready() -> void:
	# Lightweight visual: a yellow oriented quad.
	var body := ColorRect.new()
	body.color = Color(1.0, 0.9, 0.35)
	body.size = Vector2(21, 5)
	body.position = Vector2(-10, -2)
	add_child(body)
	var tip := ColorRect.new()
	tip.color = Color(1.0, 1.0, 0.7)
	tip.size = Vector2(6, 5)
	tip.position = Vector2(10, -2)
	add_child(tip)

func _process(delta: float) -> void:
	# Target is gone — fly straight a bit longer then despawn.
	if target == null or not is_instance_valid(target) or target.state == Unit.State.DEAD:
		if _stray_dir == Vector2.ZERO:
			_stray_dir = Vector2.RIGHT.rotated(rotation)
		_stray_time += delta
		global_position += _stray_dir * SPEED * delta
		modulate.a = clampf(1.0 - _stray_time / STRAY_LIFETIME, 0.0, 1.0)
		if _stray_time >= STRAY_LIFETIME:
			queue_free()
		return
	var to: Vector2 = target.global_position - global_position
	var dist: float = to.length()
	rotation = to.angle()
	if dist <= HIT_RADIUS:
		var actual: float = target.take_damage(damage, false)
		if source != null and is_instance_valid(source):
			source.notify_projectile_hit(target, actual)
		queue_free()
		return
	global_position += to.normalized() * SPEED * delta
