extends Control

# 영구 셸 + Phase 라우터.
# 셸(TopBar / FieldFrame / Divider / Labels / PlayerZone / EnemyZone / BattleLayer / HandSlot /
# BottomBar / ModalLayer / HudLayer)은 게임 진행 내내 살아있고, phase 인스턴스만 PhaseContainer에서
# 갈아끼운다. 외부 씬 전환은 메인 메뉴 한 곳뿐.

const MENU_SCENE := "res://src/ui/main_menu.tscn"

const PREP_PHASE := preload("res://src/ui/phases/prep_phase.tscn")
const BATTLE_PHASE := preload("res://src/ui/phases/battle_phase.tscn")
const RESULT_PHASE := preload("res://src/ui/phases/result_phase.tscn")

enum PhaseId { PREP, BATTLE, RESULT }

# ─── Shell node refs (Scene Unique Names — owner-relative) ────────────────
@onready var _round_lbl: Label = %RoundLabel
@onready var _gold_lbl: Label = %GoldLabel
@onready var _phase_hint: Label = %PhaseHintLabel

@onready var _player_zone: PlacementZone = %PlayerZone
@onready var _enemy_zone: Control = %EnemyZone
@onready var _battle_layer: Node2D = %BattleLayer

@onready var _hand_slot: Control = %HandSlot
@onready var _item_slot: Control = %ItemSlot
@onready var _bottom_bar: HBoxContainer = %BottomBar
@onready var _phase_container: Control = %PhaseContainer
@onready var _modal_layer: CanvasLayer = %ModalLayer
@onready var _info_hud: UnitInfoHud = %UnitInfoHud

@onready var _speed_controls: HBoxContainer = %SpeedControls
@onready var _speed_btn_1x: Button = %Speed1xButton
@onready var _speed_btn_15x: Button = %Speed15xButton
@onready var _speed_btn_2x: Button = %Speed2xButton

# ─── State ────────────────────────────────────────────────────────────────
var _phase: int = -1
var _gold_preview: int = -1  # PREP에서 예정 차감 표시용. <0이면 시뮬레이션 표시 안 함
var _battle_speed: float = 2.0  # BATTLE phase에만 Engine.time_scale에 반영. 기본 2배속.

# ─── Lifecycle ────────────────────────────────────────────────────────────
func _ready() -> void:
	_speed_btn_1x.toggled.connect(_on_speed_toggled.bind(1.0))
	_speed_btn_15x.toggled.connect(_on_speed_toggled.bind(1.5))
	_speed_btn_2x.toggled.connect(_on_speed_toggled.bind(2.0))
	_set_phase(PhaseId.PREP)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# ─── Phase machine ────────────────────────────────────────────────────────
func _set_phase(next: int, payload: Variant = null) -> void:
	_clear_shell_slots()
	for c in _phase_container.get_children():
		c.queue_free()
	_gold_preview = -1
	_info_hud.visible = false
	_info_hud.clear()

	var scene: PackedScene = _scene_for_phase(next)
	if scene == null:
		push_error("ArenaRoot: unknown phase %d" % next)
		return
	var inst: Node = scene.instantiate()
	if inst.has_method("bind_shell"):
		inst.bind_shell(_shell_dict())
	if payload != null and inst.has_method("set_payload"):
		inst.set_payload(payload)
	if inst.has_signal("transition_requested"):
		inst.transition_requested.connect(_set_phase)
	if inst.has_signal("main_menu_requested"):
		inst.main_menu_requested.connect(_to_main_menu)
	_phase_container.add_child(inst)

	_phase = next
	_refresh_top_bar()
	_refresh_speed_controls()
	# PlayerZone는 PREP에서만 드래그 입력을 받아야 한다. BATTLE/RESULT에서는
	# 같은 위치에 있는 유닛 Area2D 클릭을 흡수하지 않도록 IGNORE로 풀어준다.
	_player_zone.mouse_filter = Control.MOUSE_FILTER_STOP if next == PhaseId.PREP else Control.MOUSE_FILTER_IGNORE

func _scene_for_phase(p: int) -> PackedScene:
	match p:
		PhaseId.PREP:   return PREP_PHASE
		PhaseId.BATTLE: return BATTLE_PHASE
		PhaseId.RESULT: return RESULT_PHASE
	return null

func _shell_dict() -> Dictionary:
	return {
		"player_zone": _player_zone,
		"enemy_zone": _enemy_zone,
		"battle_layer": _battle_layer,
		"hand_slot": _hand_slot,
		"item_slot": _item_slot,
		"bottom_bar": _bottom_bar,
		"modal_layer": _modal_layer,
		"info_hud": _info_hud,
		"top_bar": self,  # phase가 set_gold_preview / refresh_gold 호출 가능
	}

func _clear_shell_slots() -> void:
	# 셸 컨테이너의 자식만 비운다. 셸 컨테이너 자체는 destroy하지 않는다.
	_clear_children(_player_zone)
	_clear_children(_enemy_zone)
	_clear_children(_battle_layer)
	_clear_children(_hand_slot)
	_clear_children(_item_slot)
	_clear_children(_bottom_bar)
	_clear_children(_modal_layer)

static func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

# ─── TopBar API (phase가 호출) ───────────────────────────────────────────
func set_gold_preview(spent: int) -> void:
	_gold_preview = spent
	_render_gold()

func refresh_gold() -> void:
	_render_gold()

func set_phase_hint(text: String) -> void:
	_phase_hint.text = text

func _refresh_top_bar() -> void:
	_round_lbl.text = "Round %d / %d" % [RunState.current_round + 1, RunState.TOTAL_ROUNDS]
	match _phase:
		PhaseId.PREP:   _phase_hint.text = ""
		PhaseId.BATTLE: _phase_hint.text = ""
		PhaseId.RESULT: _phase_hint.text = ""
	_render_gold()

func _render_gold() -> void:
	if _gold_preview >= 0:
		_gold_lbl.text = "Gold: %d  (예정 −%d → 잔여 %d)" % [
			RunState.gold, _gold_preview, RunState.gold - _gold_preview
		]
	else:
		_gold_lbl.text = "Gold: %d" % RunState.gold

# ─── Battle speed ─────────────────────────────────────────────────────────
func _on_speed_toggled(pressed: bool, value: float) -> void:
	# ButtonGroup이 항상 한 버튼만 켜진 상태를 보장 — pressed=true 신호만 반영.
	if not pressed:
		return
	_battle_speed = value
	if _phase == PhaseId.BATTLE:
		Engine.time_scale = _battle_speed

func _refresh_speed_controls() -> void:
	var in_battle: bool = (_phase == PhaseId.BATTLE)
	_speed_controls.visible = in_battle
	Engine.time_scale = _battle_speed if in_battle else 1.0

# ─── External transition ──────────────────────────────────────────────────
func _to_main_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)
