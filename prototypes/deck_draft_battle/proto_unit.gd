# PROTOTYPE - NOT FOR PRODUCTION
# Question: 코스트 예산 배낭 퍼즐 + 3x3 배치 + 조커 엔진이 재밌는가? (PROTO_V2_SPEC.md)
# Date: 2026-07-29
#
# v2 추가분: 전투 이벤트 발행(host.ev), 강화 런타임 이동/복제, 키워드(다단·보호막·처형·도발·흡혈·충격파),
#            스턴 상태, 사거리 공격, 소환체 표시.
extends Node2D

const DATA := preload("res://prototypes/deck_draft_battle/proto_data.gd")

var host: Node = null              # proto.gd — 이벤트 버스
var team: int = 0                  # 0=아군 1=적
var cell: int = -1                 # 아군 한정: 출신 그리드 칸 (인접 판정용)
var uname: String = "?"
var race: String = ""
var cls: String = ""
var is_summon: bool = false

# ── 기본 스탯 (카드 정의에서 세팅) ─────────────────────────
var base_hp: float = 100.0
var base_atk: float = 10.0
var base_def: float = 1.0
var base_aspd: float = 1.0
var atk_range: float = 46.0
var move_speed: float = 95.0

# ── 런타임 보정 (조커 / 오라 / 조건발동) ────────────────────
var bonus_atk: float = 0.0
var mult_atk: float = 1.0
var mult_hp: float = 1.0
var mult_aspd: float = 1.0

# ── 시한부 강화: buff 카드 id 배열 (이동·복제의 대상) ────────
var buffs: Array = []

# ── 파생 스탯 ─────────────────────────────────────────────
var max_hp: float = 100.0
var hp: float = 100.0
var atk: float = 10.0
var defense: float = 1.0
var atk_speed: float = 1.0
var radius: float = 16.0

# ── 키워드 ────────────────────────────────────────────────
var shield: float = 0.0
var shield_cap: float = 0.0
var multihit: int = 0
var execute_thr: float = 0.0
var taunt: bool = false
var lifesteal: float = 0.0
var stun_chance: float = 0.0

var stun_time: float = 0.0
var _dead_emitted: bool = false
var _cd: float = 0.0
var _hit_flash: float = 0.0
var _atk_flash: float = 0.0
var _shot_to: Vector2 = Vector2.ZERO
var _shot_t: float = 0.0

# ══════════════════════════════════════════════════════════
func setup() -> void:
	recompute(false)
	hp = max_hp
	shield = shield_cap

func recompute(keep_ratio: bool = true) -> void:
	var ratio: float = 1.0
	if keep_ratio and max_hp > 0.0:
		ratio = clampf(hp / max_hp, 0.0, 1.0)

	var a: float = base_atk
	var h: float = base_hp
	var d: float = base_def
	var s: float = base_aspd
	multihit = 0
	execute_thr = 0.0
	taunt = false
	lifesteal = 0.0
	stun_chance = 0.0
	shield_cap = 0.0

	for bid in buffs:
		var b: Dictionary = DATA.card(bid)
		match b.stat:
			"atk": a += b.amt
			"hp": h += b.amt
			"def": d += b.amt
			"aspd": s += b.amt
			"multihit": multihit += int(b.amt)
			"shield": shield_cap += b.amt
			"execute": execute_thr = maxf(execute_thr, b.amt)
			"taunt": taunt = true
			"lifesteal": lifesteal += b.amt
			"stun": stun_chance += b.amt

	max_hp = maxf(1.0, h * mult_hp)
	atk = maxf(1.0, (a + bonus_atk) * mult_atk)
	defense = d
	atk_speed = maxf(0.15, s * mult_aspd)
	radius = clampf(14.0 + max_hp * 0.045, 14.0, 46.0)
	if keep_ratio:
		hp = max_hp * ratio
	shield = minf(shield, shield_cap)

# 강화 부착 — 보호막은 부착 시점에 실제로 채워준다
func add_buff(bid: String) -> void:
	var before: float = shield_cap
	buffs.append(bid)
	recompute()
	shield += maxf(0.0, shield_cap - before)

func remove_buff(bid: String) -> bool:
	var i: int = buffs.find(bid)
	if i < 0:
		return false
	buffs.remove_at(i)
	recompute()
	return true

func is_alive() -> bool:
	return hp > 0.0

func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)

func apply_stun(t: float, src: Node = null) -> void:
	if not is_alive():
		return
	stun_time = maxf(stun_time, t)
	if host != null:
		host.ev("status", {"src": src, "tgt": self, "kind": "stun"})

func take_damage(d: float, src: Node = null) -> void:
	if not is_alive():
		return
	var left: float = d
	if shield > 0.0:
		var used: float = minf(shield, left)
		shield -= used
		left -= used
	hp -= left
	_hit_flash = 0.16
	if host != null:
		host.ev("hit", {"unit": self, "src": src, "dmg": d})
	if hp <= 0.0 and not _dead_emitted:
		_dead_emitted = true
		hp = 0.0
		if host != null:
			if src != null:
				host.ev("kill", {"src": src, "victim": self})
			host.ev("death", {"unit": self})

# ══════════════════════════════════════════════════════════
func step(delta: float, enemies: Array) -> void:
	if not is_alive():
		return
	if _cd > 0.0: _cd -= delta
	if _hit_flash > 0.0: _hit_flash -= delta
	if _atk_flash > 0.0: _atk_flash -= delta
	if _shot_t > 0.0: _shot_t -= delta
	if stun_time > 0.0:
		stun_time -= delta
		queue_redraw()
		return

	var tgt: Node2D = _pick_target(enemies)
	if tgt == null:
		queue_redraw()
		return

	var to_t: Vector2 = tgt.global_position - global_position
	var dist: float = to_t.length()
	var reach: float = atk_range + radius + tgt.radius
	if dist > reach:
		global_position += to_t.normalized() * move_speed * delta
	elif _cd <= 0.0:
		_swing(tgt)
		_cd = 1.0 / maxf(0.15, atk_speed)
	queue_redraw()

func _swing(tgt) -> void:
	_atk_flash = 0.12
	if atk_range > 100.0:
		_shot_to = tgt.global_position - global_position
		_shot_t = 0.1
	if host != null:
		host.ev("attack", {"src": self, "tgt": tgt})

	var hits: int = 1 + multihit
	for i in hits:
		if not tgt.is_alive():
			return
		var dmg: float = maxf(1.0, atk - tgt.defense)
		tgt.take_damage(dmg, self)
		if lifesteal > 0.0:
			heal(dmg * lifesteal)

	# 처형 — 임계 이하면 즉사
	if execute_thr > 0.0 and tgt.is_alive() and tgt.hp / maxf(1.0, tgt.max_hp) <= execute_thr:
		tgt.take_damage(tgt.hp + 1.0, self)
		return
	# 충격파 — 스턴 부여 (상태이상 매개의 생산처)
	if stun_chance > 0.0 and tgt.is_alive() and randf() < stun_chance:
		tgt.apply_stun(1.0, self)

# 도발 우선 → 그 다음 최근접
func _pick_target(enemies: Array):
	var best = null
	var best_d: float = INF
	var taunt_best = null
	var taunt_d: float = INF
	for e in enemies:
		if e == null or not is_instance_valid(e) or not e.is_alive():
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if e.taunt:
			if d < taunt_d:
				taunt_d = d
				taunt_best = e
		if d < best_d:
			best_d = d
			best = e
	return taunt_best if taunt_best != null else best

# ══════════════════════════════════════════════════════════
func _draw() -> void:
	var base: Color = Color(0.32, 0.56, 0.95) if team == 0 else Color(0.88, 0.32, 0.30)
	if is_summon:
		base = base.lerp(Color(0.6, 0.9, 1.0), 0.45)
	if _atk_flash > 0.0:
		base = base.lerp(Color.WHITE, 0.5)
	draw_circle(Vector2.ZERO, radius, base)
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, _hit_flash * 3.0))
	if shield > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, 0, TAU, 28, Color(0.5, 0.85, 1.0, 0.9), 3.0)
	if taunt:
		draw_arc(Vector2.ZERO, radius + 9.0, 0, TAU, 28, Color(1.0, 0.55, 0.2, 0.8), 2.0)
	if stun_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 13.0, 0, TAU, 20, Color(1.0, 0.95, 0.35, 0.9), 3.0)
	if _shot_t > 0.0:
		draw_line(Vector2.ZERO, _shot_to, Color(1, 1, 0.7, 0.7), 2.0)

	# HP 바
	var w: float = radius * 2.0
	var frac: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var y: float = -radius - 13.0
	draw_rect(Rect2(-radius, y, w, 5.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-radius, y, w * frac, 5.0), Color(0.35, 0.9, 0.4) if team == 0 else Color(0.95, 0.5, 0.3))
	# 강화 pip
	for i in mini(buffs.size(), 8):
		draw_circle(Vector2(-radius + 4.0 + i * 7.0, y - 7.0), 2.5, Color(1, 1, 0.7))
