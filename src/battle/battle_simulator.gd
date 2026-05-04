class_name BattleSimulator
extends Node2D

# 단일 씬 모델에서 BATTLE phase 동안 동작하는 순수 전투 컨트롤러.
# 스폰·전투 루프·시그널만 담당하며 HUD/오버레이/씬 전환은 부모(battle_phase)가 처리한다.

signal battle_ended(result: BattleResult)

const UNIT_SCRIPT := preload("res://src/battle/unit.gd")
const PROJECTILE_SCRIPT := preload("res://src/battle/projectile.gd")
const POST_BATTLE_DELAY := 1.2

# 전투 영역은 prep의 Field 영역과 동일: 화면 (24,120)~(1896,750), 즉 1872×630.
@export var player_spawn_x: float = 495.0
@export var enemy_spawn_x: float = 1425.0
@export var enemy_zone_top: float = 168.0
@export var enemy_zone_height: float = 570.0
@export var spawn_top_y: float = 420.0
@export var spawn_row_gap: float = 120.0

var _players: Array = []
var _enemies: Array = []
var _phase: String = "idle"  # idle | fighting | finished

var _projectile_layer: Node2D
var _selected: Unit = null
var _detail_card: UnitDetailCard = null

var _kills: int = 0
var _losses: int = 0
var _round_index: int = 0  # start(plan)에서 캡처. 보상 가산은 battle_phase가 책임.
# 유닛 클릭이 처리된 프레임 — 같은 프레임의 _unhandled_input이 deselect로 덮어쓰는 것을 막는 가드.
var _last_select_frame: int = -1

func _ready() -> void:
	_projectile_layer = Node2D.new()
	_projectile_layer.name = "Projectiles"
	add_child(_projectile_layer)

# BattlePlan을 받아 스폰을 시작한다. battle_phase가 add_child 직후 호출.
func start(plan: BattlePlan) -> void:
	if plan == null:
		push_error("BattleSimulator.start: plan is null")
		return
	_round_index = plan.round_index
	_spawn_player_plan(plan.player_units, player_spawn_x, plan.global_items)
	_spawn_enemy_lineup(plan.enemy_lineup, enemy_spawn_x, plan.enemy_positions)
	print("[Battle] round %d start — player=%d enemy=%d" % [
		_round_index + 1, _players.size(), _enemies.size()
	])
	_phase = "fighting"

	# 모든 유닛 스폰 후 ON_DEPLOY 트리거 발동. 양 팀 동시 — 라인업이 모두 맞춰진 시점에서 실행되어야
	# Lancer 충격 돌격 같은 NEAREST_ENEMY 타겟이 정상 해석된다.
	for u in _players:
		if is_instance_valid(u) and u.skill_runtime != null:
			u.skill_runtime.on_deploy()
	for u in _enemies:
		if is_instance_valid(u) and u.skill_runtime != null:
			u.skill_runtime.on_deploy()

func _spawn_player_plan(plan: Array, x: float, global_items: Array = []) -> void:
	var row: int = 0
	for entry in plan:
		var slot: RosterSlot = entry["slot"] as RosterSlot
		if slot == null or slot.unit_data == null:
			continue
		var boosts: Dictionary = entry.get("boosts", {}) as Dictionary
		var effective: EffectiveStats = EffectiveStats.from_slot_with_boosts(slot, boosts, global_items)
		var positions: Array = entry.get("positions", []) as Array
		if positions.is_empty():
			var deploy_count: int = int(entry.get("count", 0))
			for _i in deploy_count:
				_spawn_unit_at(slot.unit_data, effective, GameEnums.Team.PLAYER, Vector2(x, spawn_top_y + spawn_row_gap * float(row)))
				row += 1
		else:
			for raw_pos in positions:
				var p: Vector2 = raw_pos as Vector2
				_spawn_unit_at(slot.unit_data, effective, GameEnums.Team.PLAYER, p)

func _spawn_enemy_lineup(lineup: Array, x: float, positions: Array = []) -> void:
	var n: int = lineup.size()
	if n == 0:
		return
	# prep에서 전달된 좌표가 있으면 그대로 사용 — 전투준비 화면과 동일한 위치에서 시작.
	var use_provided: bool = positions.size() == n
	var row_gap: float = clampf(enemy_zone_height / float(n), 96.0, 156.0)
	var stack_h: float = row_gap * float(n - 1)
	var top_y: float = enemy_zone_top + (enemy_zone_height - stack_h) * 0.5
	for i in n:
		var d: UnitData = lineup[i] as UnitData
		if d == null:
			continue
		var effective: EffectiveStats = EffectiveStats.from_unit_data(d)
		var pos: Vector2 = positions[i] if use_provided else Vector2(x, top_y + row_gap * float(i))
		_spawn_unit_at(d, effective, GameEnums.Team.ENEMY, pos)

func _spawn_unit_at(unit_data: UnitData, effective: EffectiveStats, team: GameEnums.Team, pos: Vector2) -> void:
	var u: Node2D = Node2D.new()
	u.set_script(UNIT_SCRIPT)
	var enemies_provider: Callable
	var allies_provider: Callable
	if team == GameEnums.Team.PLAYER:
		enemies_provider = Callable(self, "_get_enemies")
		allies_provider = Callable(self, "_get_players")
	else:
		enemies_provider = Callable(self, "_get_players")
		allies_provider = Callable(self, "_get_enemies")
	u.setup(unit_data, effective, team, enemies_provider, allies_provider)
	u.global_position = pos
	u.died.connect(_on_unit_died.bind(team))
	u.projectile_requested.connect(_on_projectile_requested)
	u.clicked.connect(_on_unit_clicked)
	add_child(u)
	if team == GameEnums.Team.PLAYER:
		_players.append(u)
	else:
		_enemies.append(u)

func _physics_process(delta: float) -> void:
	if _phase != "fighting":
		return
	for u in _players:
		if is_instance_valid(u):
			u.tick(delta)
	for u in _enemies:
		if is_instance_valid(u):
			u.tick(delta)

	_players = _players.filter(_is_alive)
	_enemies = _enemies.filter(_is_alive)

	if _players.is_empty() or _enemies.is_empty():
		_finish_round()

func _is_alive(u) -> bool:
	return is_instance_valid(u) and u.state != Unit.State.DEAD

func _on_unit_died(u: Unit, team: GameEnums.Team) -> void:
	if team == GameEnums.Team.ENEMY:
		_kills += 1
	else:
		_losses += 1
	if _selected == u:
		u.set_selected(false)

func bind_detail_card(card: UnitDetailCard) -> void:
	_detail_card = card

func _on_unit_clicked(u: Unit) -> void:
	print("[Battle] _on_unit_clicked team=%s detail_card=%s" % [str(u.team), str(_detail_card)])
	_last_select_frame = Engine.get_process_frames()
	_select(u)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = get_viewport().get_mouse_position()
		print("[Battle] _input LMB at %s players=%d enemies=%d" % [str(mp), _players.size(), _enemies.size()])

func _select(u: Unit) -> void:
	# 셀렉션 링은 항상 토글. 좌상단 상세 카드는 양 팀 모두에 표시 — 클릭한 유닛 정보를 띄운다.
	if _selected != u:
		if is_instance_valid(_selected):
			_selected.set_selected(false)
		_selected = u
		if u != null:
			u.set_selected(true)
	if _detail_card == null:
		return
	if u != null:
		_detail_card.bind_unit(u)
	else:
		_detail_card.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 같은 프레임에 유닛 클릭이 이미 처리됐다면 deselect 무시 — 카드가 깜빡이며 사라지는 것을 방지.
		if Engine.get_process_frames() == _last_select_frame:
			return
		_select(null)

func _on_projectile_requested(from: Vector2, target: Unit, damage: float, source: Unit) -> void:
	var p: Node2D = Node2D.new()
	p.set_script(PROJECTILE_SCRIPT)
	_projectile_layer.add_child(p)
	p.setup(from, target, damage, source)

func _finish_round() -> void:
	_phase = "finished"
	var player_won: bool = not _players.is_empty()

	# 결과만 빌드해서 전달. 보상/라운드 진행은 battle_phase가 단일 지점에서 처리한다.
	var result := BattleResult.new()
	result.won = player_won
	result.was_last_round = RunState.progress.is_last_round()
	result.kills = _kills
	result.losses = _losses
	result.round_index = _round_index
	# 시뮬레이터는 보상 가산을 하지 않으므로 RunProgress의 공식을 조회만 한다.
	result.gold_earned = RunState.progress.current_round_reward(RunState.economy) if player_won else 0

	print("[Battle] end won=%s kills=%d losses=%d gold=+%d" % [
		str(player_won), _kills, _losses, result.gold_earned
	])
	battle_ended.emit(result)

func _get_players() -> Array:
	return _players

func _get_enemies() -> Array:
	return _enemies

# ─── Public read-only API ─────────────────────────────────────────────────
# 외부(HUD 등)는 사본을 받아 내부 배열을 mutate할 수 없게 한다.
func get_players() -> Array:
	return _players.duplicate()

func get_enemies() -> Array:
	return _enemies.duplicate()

func get_units(team: GameEnums.Team) -> Array:
	return get_players() if team == GameEnums.Team.PLAYER else get_enemies()
