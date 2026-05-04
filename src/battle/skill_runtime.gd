class_name SkillRuntime
extends RefCounted

# 한 유닛에 부착되어 그 유닛의 스킬 발동을 관리한다. Unit.gd가 라이프사이클(트리거 호출)
# 을 호출하고 SkillRuntime이 SkillData에 따라 효과를 푼다.
#
# 책임:
# - 매 프레임 tick: AURA 갱신, PERIODIC 카운트다운, ON_DAMAGED_BELOW 임계 검사
# - 이벤트형 트리거 처리(on_deploy / on_attack / on_kill / on_death / on_ally_death)
# - Effect → 대상 해결 → Unit 메서드로 적용 (heal / add_status / strike 등)

const _AURA_REFRESH_INTERVAL := 0.4   # 오오라 재적용 주기. 데이터 duration보다 짧아야 함.
const _SHOUT_COOLDOWN := 2.0          # 같은 스킬을 연달아 외치지 않도록 막는 쿨다운(초).

var unit: Object = null              # back-ref to Unit (avoid cycle: typed as Object)
var skills: Array = []               # Array[SkillData]
var rng := RandomNumberGenerator.new()

var _periodic_accum: Dictionary = {}        # skill_ref -> seconds since last fire
var _aura_accum: Dictionary = {}            # skill_ref -> seconds since last refresh
var _threshold_fired: Dictionary = {}       # skill_ref -> bool
var _last_shout_time: Dictionary = {}       # skill_ref -> Time.get_ticks_msec() at last shout
var _shouted_once: Dictionary = {}          # skill_ref -> bool (AURA처럼 1회 한정용)

func setup(owner_unit: Object, skill_list: Array) -> void:
	unit = owner_unit
	skills = skill_list
	rng.randomize()
	for s in skills:
		_periodic_accum[s] = 0.0
		_aura_accum[s] = 999.0  # 첫 tick에서 즉시 적용되도록 큰 값으로 시작
		_threshold_fired[s] = false

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle hooks — Unit이 적절한 시점에 호출
# ─────────────────────────────────────────────────────────────────────────────

func on_deploy() -> void:
	for s in skills:
		if s.trigger == SkillData.Trigger.ON_DEPLOY:
			_fire(s, null)

func on_attack(victim: Object, damage_dealt: float) -> void:
	for s in skills:
		if s.trigger == SkillData.Trigger.ON_ATTACK:
			_fire(s, victim, damage_dealt)

func on_kill(victim: Object) -> void:
	for s in skills:
		if s.trigger == SkillData.Trigger.ON_KILL:
			_fire(s, victim)

func on_death() -> void:
	for s in skills:
		if s.trigger == SkillData.Trigger.ON_DEATH:
			_fire(s, null)

func on_ally_death(ally: Object) -> void:
	for s in skills:
		if s.trigger == SkillData.Trigger.ON_ALLY_DEATH:
			_fire(s, ally)

func on_damage_taken(prev_hp: float, new_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	var prev_ratio: float = prev_hp / max_hp
	var new_ratio: float = new_hp / max_hp
	for s in skills:
		if s.trigger != SkillData.Trigger.ON_DAMAGED_BELOW:
			continue
		if _threshold_fired.get(s, false):
			continue
		if prev_ratio > s.threshold and new_ratio <= s.threshold:
			_threshold_fired[s] = true
			_fire(s, null)

func tick(delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	for s in skills:
		if s.trigger == SkillData.Trigger.AURA:
			var a: float = _aura_accum.get(s, 0.0) + delta
			if a >= _AURA_REFRESH_INTERVAL:
				a = 0.0
				_fire(s, null)
			_aura_accum[s] = a
		elif s.trigger == SkillData.Trigger.PERIODIC:
			if s.interval <= 0.0:
				continue
			var t: float = _periodic_accum.get(s, 0.0) + delta
			if t >= s.interval:
				t -= s.interval
				_fire(s, null)
			_periodic_accum[s] = t

# ─────────────────────────────────────────────────────────────────────────────
# Internals
# ─────────────────────────────────────────────────────────────────────────────

func _fire(skill: SkillData, fire_target: Object, damage_dealt: float = 0.0) -> void:
	if skill.chance < 1.0 and rng.randf() > skill.chance:
		return
	var targets: Array = _resolve_targets(skill, fire_target)
	if targets.is_empty():
		return
	# 시전자 머리 위에 스킬명을 외친다 — 효과가 실제로 적용될 때만, 그리고 쿨다운/1회 규칙을 통과할 때만.
	if unit != null and is_instance_valid(unit) and not unit.is_dead() and _should_shout(skill):
		unit.show_skill_shout(skill.name_key)
		_mark_shouted(skill)
	for t in targets:
		_apply_effect(skill, t, damage_dealt)

func _should_shout(skill: SkillData) -> bool:
	# AURA는 첫 발동 시 1회만 외친다(0.4초마다 갱신되어 시끄럽기 때문).
	if skill.trigger == SkillData.Trigger.AURA:
		return not _shouted_once.get(skill, false)
	# 그 외에는 같은 스킬의 직전 외침 후 _SHOUT_COOLDOWN 초가 지나야 다시 외친다.
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var last: float = _last_shout_time.get(skill, -INF)
	return now - last >= _SHOUT_COOLDOWN

func _mark_shouted(skill: SkillData) -> void:
	_shouted_once[skill] = true
	_last_shout_time[skill] = float(Time.get_ticks_msec()) / 1000.0

func _resolve_targets(skill: SkillData, fire_target: Object) -> Array:
	var out: Array = []
	match skill.target:
		SkillData.TargetSel.SELF:
			if _alive(unit):
				out.append(unit)
		SkillData.TargetSel.CURRENT_TARGET:
			if _alive(fire_target):
				out.append(fire_target)
		SkillData.TargetSel.NEAREST_ENEMY:
			var n: Object = _nearest(_enemies(), unit.global_position)
			if n != null:
				out.append(n)
		SkillData.TargetSel.LOWEST_HP_ALLY:
			var lo: Object = _lowest_hp(_allies())
			if lo != null:
				out.append(lo)
		SkillData.TargetSel.ENEMIES_IN_RADIUS:
			out = _in_radius(_enemies(), unit.global_position, skill.radius_cells * float(GameEnums.CELL_SIZE))
		SkillData.TargetSel.ALLIES_IN_RADIUS:
			out = _in_radius(_allies(), unit.global_position, skill.radius_cells * float(GameEnums.CELL_SIZE))
	return out

func _apply_effect(skill: SkillData, target_unit: Object, damage_dealt: float) -> void:
	if not _alive(target_unit):
		return
	match skill.effect:
		SkillData.Effect.STRIKE:
			var dmg: float = skill.value * unit.current_attack()
			unit.cast_strike_at(target_unit, dmg)
		SkillData.Effect.CLEAVE:
			var ddmg: float = skill.value * unit.current_attack()
			unit.cast_strike_at(target_unit, ddmg)
		SkillData.Effect.HEAL:
			target_unit.heal(skill.value)
		SkillData.Effect.LIFESTEAL:
			# damage_dealt는 _deal_attack 직후 unit이 가한 실 피해(or 추정치).
			var heal_amt: float = damage_dealt * skill.value
			if heal_amt > 0.0:
				target_unit.heal(heal_amt)
		SkillData.Effect.BUFF_ATK:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.BUFF_ATK, skill.value, skill.duration, unit))
		SkillData.Effect.BUFF_DEFENSE:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.BUFF_DEFENSE, skill.value, skill.duration, unit))
		SkillData.Effect.TAUNT:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.TAUNT_TO, 0.0, skill.duration, unit))
		SkillData.Effect.STUN:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.STUN, 0.0, skill.duration, unit))
		SkillData.Effect.FREEZE:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.FREEZE, 0.0, skill.duration, unit))
		SkillData.Effect.POISON:
			var p := StatusEffect.make(StatusEffect.Kind.POISON, skill.value, skill.duration, unit)
			p.tick_interval = 1.0
			target_unit.add_status(p)
		SkillData.Effect.BURN:
			target_unit.add_status(StatusEffect.make(StatusEffect.Kind.BURN, skill.value, skill.duration, unit))

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _allies() -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	return unit.get_allies()

func _enemies() -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	return unit.get_enemies()

static func _alive(u: Object) -> bool:
	return u != null and is_instance_valid(u) and not u.is_dead()

static func _nearest(units: Array, from: Vector2) -> Object:
	var best: Object = null
	var best_d: float = INF
	for raw in units:
		if not _alive(raw):
			continue
		var d: float = from.distance_squared_to(raw.global_position)
		if d < best_d:
			best_d = d
			best = raw
	return best

static func _lowest_hp(units: Array) -> Object:
	var best: Object = null
	var best_ratio: float = INF
	for raw in units:
		if not _alive(raw):
			continue
		var ratio: float = raw.hp / max(1.0, raw.stats.max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = raw
	return best

static func _in_radius(units: Array, center: Vector2, radius: float) -> Array:
	var out: Array = []
	var r2: float = radius * radius
	for raw in units:
		if not _alive(raw):
			continue
		if center.distance_squared_to(raw.global_position) <= r2:
			out.append(raw)
	return out
