# PROTOTYPE - NOT FOR PRODUCTION
# Question: 덱 드래프트(병사+강화 N장 배분)가 재밌는가?
# Date: 2026-07-21
extends Node2D

# 팀 / 스탯 (전부 하드코딩·런타임 세팅)
var team: int = 0                 # 0=아군, 1=적
var max_hp: float = 100.0
var hp: float = 100.0
var atk: float = 10.0
var defense: float = 1.0
var atk_speed: float = 1.0        # 초당 공격 횟수
var move_speed: float = 90.0
var atk_range: float = 46.0
var radius: float = 16.0

# 강화 개수 (표시용 pip)
var n_atk: int = 0
var n_hp: int = 0
var n_def: int = 0
var n_as: int = 0

var _cd: float = 0.0
var _hit_flash: float = 0.0
var _atk_flash: float = 0.0

func setup() -> void:
	hp = max_hp
	radius = clampf(15.0 + max_hp * 0.055, 15.0, 52.0)

func is_alive() -> bool:
	return hp > 0.0

func take_damage(d: float) -> void:
	hp -= d
	_hit_flash = 0.14

# enemies: 살아있는 상대 팀 배열
func step(delta: float, enemies: Array) -> void:
	if not is_alive():
		return
	if _cd > 0.0:
		_cd -= delta
	if _hit_flash > 0.0:
		_hit_flash -= delta
	if _atk_flash > 0.0:
		_atk_flash -= delta

	var tgt = _nearest(enemies)
	if tgt == null:
		queue_redraw()
		return

	var to_t: Vector2 = tgt.global_position - global_position
	var dist: float = to_t.length()
	var reach: float = atk_range + radius + tgt.radius
	if dist > reach:
		global_position += to_t.normalized() * move_speed * delta
	elif _cd <= 0.0:
		tgt.take_damage(maxf(1.0, atk - tgt.defense))
		_cd = 1.0 / maxf(0.15, atk_speed)
		_atk_flash = 0.12
	queue_redraw()

func _nearest(enemies: Array):
	var best = null
	var best_d: float = INF
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _draw() -> void:
	var base: Color = Color(0.32, 0.56, 0.95) if team == 0 else Color(0.88, 0.32, 0.30)
	if _atk_flash > 0.0:
		base = base.lerp(Color.WHITE, 0.5)
	# 본체
	draw_circle(Vector2.ZERO, radius, base)
	# 피격 플래시
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, _hit_flash * 3.0))
	# 강화 링 (아군만): 공=빨강, 체=초록, 방=파랑, 속=노랑
	var ring: Color = Color(0, 0, 0, 0)
	var top: int = maxi(maxi(n_atk, n_hp), maxi(n_def, n_as))
	if team == 0 and top > 0:
		if n_atk == top: ring = Color(1.0, 0.4, 0.3)
		elif n_hp == top: ring = Color(0.4, 1.0, 0.5)
		elif n_def == top: ring = Color(0.4, 0.7, 1.0)
		else: ring = Color(1.0, 0.9, 0.3)
		draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 32, ring, 3.0)
	# HP 바
	var w: float = radius * 2.0
	var frac: float = clampf(hp / max_hp, 0.0, 1.0)
	var y: float = -radius - 12.0
	draw_rect(Rect2(-radius, y, w, 5.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-radius, y, w * frac, 5.0), Color(0.35, 0.9, 0.4) if team == 0 else Color(0.95, 0.5, 0.3))
	# 강화 pip
	var pips: int = n_atk + n_hp + n_def + n_as
	for i in pips:
		draw_circle(Vector2(-radius + 4.0 + i * 7.0, y - 6.0), 2.5, Color(1, 1, 0.7))
