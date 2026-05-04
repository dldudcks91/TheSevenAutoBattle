class_name Unit
extends Node2D

signal died(unit: Unit)
signal projectile_requested(from: Vector2, target: Unit, damage: float, source: Unit)
signal clicked(unit: Unit)

enum State { IDLE, MOVE, ATTACK, HURT, DEAD }

var data: UnitData
var stats: EffectiveStats
var team: GameEnums.Team = GameEnums.Team.PLAYER
var hp: float
var state: State = State.IDLE
var target: Unit = null
var attack_cooldown: float = 0.0

# Battle scene이 주입. 둘 다 필수 — 스킬 시스템이 사용한다.
var _enemies_provider: Callable
var _allies_provider: Callable

var _attack_timer: float = 0.0
var _attack_duration: float = 0.6
var _attack_hit_at: float = 0.24
var _attack_dealt: bool = false

# 타겟 재평가 — 0.5초 주기, 새 후보가 현재의 70% 이하 거리일 때만 교체(흔들림 방지).
var _retarget_timer: float = 0.0
const _RETARGET_INTERVAL: float = 0.5
const _RETARGET_HYSTERESIS_SQ: float = 0.49  # 0.7^2 — distance_squared 비교용
# 라인(같은 행) 판정 임계값. 스폰 행 간격 120px의 절반.
const _LINE_TOLERANCE: float = 60.0

var _sprite: AnimatedSprite2D
var _hp_bar: ColorRect
var _hp_bar_bg: ColorRect
var _selection_ring: SelectionRing

# 스킬 / 상태이상 / 영구 보너스
var skill_runtime: SkillRuntime
var _statuses: Array = []                 # Array[StatusEffect]
var _permanent_atk_bonus: float = 0.0     # ON_KILL 등으로 누적되는 영구 ATK 보너스

const HURT_FLASH_TIME := 0.1
const FREEZE_SPEED_MULT := 0.5

func setup(unit_data: UnitData, effective_stats: EffectiveStats, unit_team: GameEnums.Team, enemies_provider: Callable, allies_provider: Callable = Callable()) -> void:
	data = unit_data
	stats = effective_stats
	team = unit_team
	_enemies_provider = enemies_provider
	_allies_provider = allies_provider
	hp = stats.max_hp

func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = SpriteFrameLoader.build(data.sprite_dir)
	_sprite.scale = Vector2.ONE * data.sprite_scale * 0.75
	if team == GameEnums.Team.ENEMY:
		_sprite.flip_h = true
	add_child(_sprite)
	_play("idle")

	if _sprite.sprite_frames.has_animation(&"attack"):
		var n := _sprite.sprite_frames.get_frame_count(&"attack")
		var fps := _sprite.sprite_frames.get_animation_speed(&"attack")
		if n > 0 and fps > 0.0:
			_attack_duration = float(n) / fps
	_attack_hit_at = _attack_duration * data.hit_frame_ratio

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0, 0, 0, 0.6)
	_hp_bar_bg.size = Vector2(60, 8)
	_hp_bar_bg.position = Vector2(-30, -54)
	add_child(_hp_bar_bg)

	_hp_bar = ColorRect.new()
	_hp_bar.color = Color(0.95, 0.25, 0.25) if team == GameEnums.Team.ENEMY else Color(0.3, 0.85, 0.4)
	_hp_bar.size = Vector2(60, 8)
	_hp_bar.position = Vector2(-30, -54)
	add_child(_hp_bar)

	var hit := Area2D.new()
	hit.input_pickable = true
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = data.body_radius
	col.shape = shape
	hit.add_child(col)
	hit.input_event.connect(_on_hit_input)
	add_child(hit)

	_selection_ring = SelectionRing.new()
	# 작게 — body_radius의 60% 정도. 발 밑(아래쪽) 위치.
	_selection_ring.radius = max(8.0, data.body_radius * 0.6)
	_selection_ring.position = Vector2(0, data.body_radius * 0.5 + 4.0)
	_selection_ring.visible = false
	add_child(_selection_ring)

	# 스킬 러ntime 초기화 — units.csv의 default_skill_id 기준. 빈 문자열이면 빈 리스트.
	skill_runtime = SkillRuntime.new()
	var attached: Array = []
	if data.default_skill_id != &"":
		var sd: SkillData = SkillDB.get_by_id(data.default_skill_id)
		if sd != null:
			attached.append(sd)
		else:
			push_warning("Unit: skill id not found: %s" % data.default_skill_id)
	skill_runtime.setup(self, attached)

	_setup_aura_ring(attached)

func _setup_aura_ring(attached_skills: Array) -> void:
	# AURA 트리거 스킬이 있으면 가장 큰 radius로 발 밑에 표시 링을 깐다.
	var max_radius_cells: float = 0.0
	for raw in attached_skills:
		var s: SkillData = raw
		if s.trigger == SkillData.Trigger.AURA and s.radius_cells > max_radius_cells:
			max_radius_cells = s.radius_cells
	if max_radius_cells <= 0.0:
		return
	var ring := AuraRing.new()
	ring.position = Vector2(0, 6)
	# 적군은 붉은 톤으로 구분.
	if team == GameEnums.Team.ENEMY:
		ring.fill_color = Color(1.0, 0.35, 0.35, 0.15)
		ring.edge_color = Color(1.0, 0.35, 0.35, 0.6)
	ring.set_radius(max_radius_cells * float(GameEnums.CELL_SIZE))
	add_child(ring)

func set_selected(on: bool) -> void:
	if _selection_ring:
		_selection_ring.visible = on

func _on_hit_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if state == State.DEAD:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[Unit] _on_hit_input fired team=%s id=%s pos=%s" % [str(team), str(data.id), str(global_position)])
		clicked.emit(self)
		get_viewport().set_input_as_handled()

func tick(delta: float) -> void:
	if state == State.DEAD:
		return

	# 1) 상태이상 시간 감소 + 부수 효과(POISON)
	_advance_statuses(delta)
	if state == State.DEAD:
		return

	attack_cooldown = max(0.0, attack_cooldown - delta)

	# 2) 스킬 러ntime tick (AURA / PERIODIC)
	if skill_runtime != null:
		skill_runtime.tick(delta)

	# 3) STUN 시 행동 정지(애니는 IDLE 유지)
	if _has_status(StatusEffect.Kind.STUN):
		_set_state(State.IDLE)
		return

	# 4) 타겟 결정 — 도발 강제 → 무효 시 신규 탐색 → 주기적 재평가(가까운 적 등장 시 교체)
	_retarget_timer = max(0.0, _retarget_timer - delta)

	var taunt_src: Unit = _taunt_target()
	if taunt_src != null and taunt_src != target:
		target = taunt_src
	elif target == null or not is_instance_valid(target) or target.state == State.DEAD:
		target = _find_priority_target()
		if target == null:
			_set_state(State.IDLE)
			return
	elif _retarget_timer <= 0.0:
		_retarget_timer = _RETARGET_INTERVAL
		var candidate: Unit = _find_priority_target()
		if candidate != null and candidate != target:
			var cur_d: float = global_position.distance_squared_to(target.global_position)
			var new_d: float = global_position.distance_squared_to(candidate.global_position)
			if new_d < cur_d * _RETARGET_HYSTERESIS_SQ:
				target = candidate

	if target == null:
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()

	if abs(to_target.x) > 0.01:
		_sprite.flip_h = to_target.x < 0.0

	if state == State.ATTACK:
		_advance_attack(delta)
		return

	if dist > stats.attack_range:
		_set_state(State.MOVE)
		var desired := to_target.normalized() * current_move_speed()
		global_position += desired * delta
	else:
		if attack_cooldown <= 0.0:
			_begin_attack()
		else:
			_set_state(State.IDLE)

func _begin_attack() -> void:
	_set_state(State.ATTACK)
	_attack_timer = 0.0
	_attack_dealt = false
	_play("attack", true)

func _advance_attack(delta: float) -> void:
	_attack_timer += delta
	if not _attack_dealt and _attack_timer >= _attack_hit_at:
		_attack_dealt = true
		_deal_attack()
	if _attack_timer >= _attack_duration:
		attack_cooldown = stats.attack_speed
		_set_state(State.IDLE)

func _deal_attack() -> void:
	if target == null or not is_instance_valid(target) or target.state == State.DEAD:
		return
	var atk: float = current_attack()
	if data.is_ranged:
		var muzzle: Vector2 = global_position + Vector2(0, -15)
		projectile_requested.emit(muzzle, target, atk, self)
		# 발사체가 도달하기 전이라도 ON_ATTACK은 공격 시점에 1회 발동 — 추정 피해로 호출.
		if skill_runtime != null:
			var est: float = max(1.0, atk - target.current_defense())
			skill_runtime.on_attack(target, est)
	else:
		if global_position.distance_to(target.global_position) <= stats.attack_range + 12.0:
			var actual: float = target.take_damage(atk, true)
			if skill_runtime != null:
				skill_runtime.on_attack(target, actual)
				if target.state == State.DEAD:
					skill_runtime.on_kill(target)

# 발사체가 명중 시 호출. on_attack은 이미 _deal_attack 시점에 1회 발동했으므로
# 여기서는 처치 트리거(ON_KILL)만 처리한다.
func notify_projectile_hit(victim: Unit, _actual_damage: float) -> void:
	if skill_runtime == null:
		return
	if victim != null and is_instance_valid(victim) and victim.state == State.DEAD:
		skill_runtime.on_kill(victim)

# 스킬에 의한 즉발/원거리 타격(=skill STRIKE 등). 이 경로는 attack 사이클과 독립적이다.
func cast_strike_at(victim: Unit, damage: float) -> void:
	if victim == null or not is_instance_valid(victim) or victim.state == State.DEAD:
		return
	if data.is_ranged:
		var muzzle: Vector2 = global_position + Vector2(0, -15)
		projectile_requested.emit(muzzle, victim, damage, self)
	else:
		victim.take_damage(damage, true)
		if skill_runtime != null and victim.state == State.DEAD:
			skill_runtime.on_kill(victim)

func take_damage(amount: float, _is_melee: bool = false) -> float:
	if state == State.DEAD:
		return 0.0
	var burn_extra: float = _burn_amount()
	var raw: float = amount + burn_extra
	var dmg: float = maxf(1.0, raw - current_defense())
	var prev_hp: float = hp
	hp = max(0.0, hp - dmg)
	_update_hp_bar()
	if skill_runtime != null:
		skill_runtime.on_damage_taken(prev_hp, hp, stats.max_hp)
	if hp <= 0.0:
		_die()
		return dmg
	_flash_hurt()
	return dmg

func _flash_hurt() -> void:
	_sprite.modulate = Color(1.6, 0.6, 0.6)
	var t := get_tree().create_timer(HURT_FLASH_TIME)
	t.timeout.connect(_clear_hurt_flash)

func _clear_hurt_flash() -> void:
	if is_instance_valid(self) and state != State.DEAD and _sprite != null:
		_sprite.modulate = Color.WHITE

# 스킬 발동 연출 — 머리 위에 스킬명을 잠깐 띄운다(말풍선 대용).
# 다중 발동 시 기존 라벨을 즉시 갈아끼우고 위로 떠오르며 페이드아웃한다.
const _SHOUT_DURATION := 1.1
const _SHOUT_RISE := 22.0

func show_skill_shout(text_key: String) -> void:
	if state == State.DEAD:
		return
	var lbl := Label.new()
	lbl.text = tr(text_key) if text_key != "" else ""
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(160, 24)
	lbl.position = Vector2(-80, -78)
	lbl.z_index = 10
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - _SHOUT_RISE, _SHOUT_DURATION)
	tw.tween_property(lbl, "modulate:a", 0.0, _SHOUT_DURATION).set_delay(_SHOUT_DURATION * 0.4)
	tw.chain().tween_callback(lbl.queue_free)

func heal(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	hp = min(stats.max_hp, hp + amount)
	_update_hp_bar()

func _die() -> void:
	state = State.DEAD
	_play("death", true)
	_hp_bar.visible = false
	_hp_bar_bg.visible = false
	if skill_runtime != null:
		skill_runtime.on_death()
	died.emit(self)
	var t := get_tree().create_timer(0.8)
	t.timeout.connect(queue_free)

func _set_state(new_state: State) -> void:
	if state == new_state or state == State.DEAD:
		return
	state = new_state
	match state:
		State.IDLE:   _play("idle")
		State.MOVE:   _play("walk")
		State.ATTACK: _play("attack", true)

func _play(anim: StringName, restart: bool = false) -> void:
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if restart or _sprite.animation != anim:
		_sprite.play(anim)

func _update_hp_bar() -> void:
	var ratio: float = clampf(hp / stats.max_hp, 0.0, 1.0)
	_hp_bar.size = Vector2(60.0 * ratio, 8.0)

# 같은 라인(Y축 ±_LINE_TOLERANCE) 내 X축 최단거리 적을 우선. 라인 내 적이 없으면 유클리드 최단거리로 폴백.
func _find_priority_target() -> Unit:
	var enemies: Array = get_enemies()
	var line_best: Unit = null
	var line_best_dx := INF
	var any_best: Unit = null
	var any_best_d := INF
	for raw in enemies:
		var u: Unit = raw as Unit
		if u == null or not is_instance_valid(u) or u.state == State.DEAD:
			continue
		var diff: Vector2 = u.global_position - global_position
		var d_sq: float = diff.length_squared()
		if d_sq < any_best_d:
			any_best_d = d_sq
			any_best = u
		if absf(diff.y) <= _LINE_TOLERANCE:
			var dx: float = absf(diff.x)
			if dx < line_best_dx:
				line_best_dx = dx
				line_best = u
	return line_best if line_best != null else any_best

# ─────────────────────────────────────────────────────────────────────────────
# Public helpers — SkillRuntime 및 HUD가 사용한다.
# ─────────────────────────────────────────────────────────────────────────────

func get_enemies() -> Array:
	if _enemies_provider.is_valid():
		return _enemies_provider.call()
	return []

func get_allies() -> Array:
	if _allies_provider.is_valid():
		return _allies_provider.call()
	return []

func is_dead() -> bool:
	return state == State.DEAD

func current_attack() -> float:
	var bonus: float = _permanent_atk_bonus
	for raw in _statuses:
		var st: StatusEffect = raw
		if st.kind == StatusEffect.Kind.BUFF_ATK:
			bonus += st.amount
	return stats.attack + bonus

func current_defense() -> float:
	var bonus: float = 0.0
	for raw in _statuses:
		var st: StatusEffect = raw
		if st.kind == StatusEffect.Kind.BUFF_DEFENSE:
			bonus += st.amount
	return stats.defense + bonus

func current_move_speed() -> float:
	var s: float = stats.move_speed
	if _has_status(StatusEffect.Kind.FREEZE):
		s *= FREEZE_SPEED_MULT
	return s

# ─────────────────────────────────────────────────────────────────────────────
# Status effect management
# ─────────────────────────────────────────────────────────────────────────────

func add_status(effect: StatusEffect) -> void:
	if state == State.DEAD or effect == null:
		return
	# 영구 ATK 버프(duration == INF)는 스택형 누적값으로 흡수해 둔다.
	# (Swordsman ON_KILL 처럼 영구 +ATK가 무한 누적되어야 하므로 status로 두면 리스트가 무한히 길어짐.)
	if effect.kind == StatusEffect.Kind.BUFF_ATK and effect.time_left == INF:
		_permanent_atk_bonus += effect.amount
		return
	# 동일 종류 + 동일 source의 기존 효과가 있으면 더 큰 amount/긴 duration으로 갱신.
	for raw in _statuses:
		var existing: StatusEffect = raw
		if existing.kind == effect.kind and existing.source == effect.source:
			existing.amount = max(existing.amount, effect.amount)
			existing.refresh(effect.time_left if effect.time_left != INF else 0.0)
			return
	_statuses.append(effect)

func _advance_statuses(delta: float) -> void:
	if _statuses.is_empty():
		return
	var survivors: Array = []
	for raw in _statuses:
		var st: StatusEffect = raw
		# POISON 틱
		if st.kind == StatusEffect.Kind.POISON and st.tick_interval > 0.0:
			st._tick_accum += delta
			while st._tick_accum >= st.tick_interval and not is_dead():
				st._tick_accum -= st.tick_interval
				take_damage(st.amount, false)
				if is_dead():
					break
		st.decay(delta)
		if not st.is_expired():
			survivors.append(st)
	_statuses = survivors

func _has_status(kind_v: int) -> bool:
	for raw in _statuses:
		var st: StatusEffect = raw
		if st.kind == kind_v:
			return true
	return false

func _burn_amount() -> float:
	var sum: float = 0.0
	for raw in _statuses:
		var st: StatusEffect = raw
		if st.kind == StatusEffect.Kind.BURN:
			sum += st.amount
	return sum

func _taunt_target() -> Unit:
	# TAUNT_TO 상태가 있고 source가 살아있으면 그 유닛을 강제 타겟으로 반환.
	for raw in _statuses:
		var st: StatusEffect = raw
		if st.kind != StatusEffect.Kind.TAUNT_TO:
			continue
		var src: Object = st.source
		if src != null and is_instance_valid(src) and not src.is_dead():
			return src as Unit
	return null

# 영구 ATK 보너스 적립용 (SkillRuntime이 직접 호출하지는 않음 — add_status 경유).
func add_permanent_atk(amount: float) -> void:
	_permanent_atk_bonus += amount
