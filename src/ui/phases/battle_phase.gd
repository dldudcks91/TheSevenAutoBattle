extends Control

# BATTLE phase: 셸의 BattleLayer에 BattleSimulator 인스턴스를 띄운다.
# 시뮬레이터 종료 후 1.2초 딜레이 → RESULT phase로 전환.
# 보상 가산 / 라운드 진행은 이 phase에서 단일 지점으로 처리한다 (BattleSimulator는 결과만 만든다).

const ARENA_ROOT := preload("res://src/ui/arena_root.gd")
const POST_BATTLE_DELAY := 1.2

signal transition_requested(next: int, payload: Variant)
signal main_menu_requested

var shell: Dictionary = {}
var _sim: BattleSimulator = null
var _plan: BattlePlan = null

func bind_shell(s: Dictionary) -> void:
	shell = s

func set_payload(payload: Variant) -> void:
	_plan = payload as BattlePlan

func _ready() -> void:
	if shell.is_empty():
		push_error("battle_phase: shell not bound")
		return
	if _plan == null:
		push_error("battle_phase: BattlePlan not provided")
		return

	# 셸의 info_hud 표시
	var hud: UnitInfoHud = shell.info_hud
	hud.visible = true
	hud.clear()

	# BattleSimulator 인스턴스 생성 → shell.battle_layer 의 자식으로
	_sim = BattleSimulator.new()
	shell.battle_layer.add_child(_sim)
	hud.bind_battle(_sim)
	_sim.battle_ended.connect(_on_battle_ended)
	# add_child 직후 spawn 시작. _ready의 _projectile_layer 초기화는 이미 끝난 시점.
	_sim.start(_plan)

func _on_battle_ended(result: BattleResult) -> void:
	# 보상 가산 / 라운드 진행 단일 지점. 마지막 라운드 클리어 시 advance_round 호출 안 함.
	if result.won:
		RunState.progress.grant_round_reward(RunState.economy)
		if not result.was_last_round:
			RunState.advance_round()
	await get_tree().create_timer(POST_BATTLE_DELAY).timeout
	transition_requested.emit(ARENA_ROOT.PhaseId.RESULT, result)

func _exit_tree() -> void:
	# 시뮬레이터는 셸의 BattleLayer에 add_child 했으므로
	# arena_root._clear_shell_slots()가 정리한다. 여기서는 시그널만 정리.
	if is_instance_valid(_sim):
		if _sim.battle_ended.is_connected(_on_battle_ended):
			_sim.battle_ended.disconnect(_on_battle_ended)
	_sim = null
