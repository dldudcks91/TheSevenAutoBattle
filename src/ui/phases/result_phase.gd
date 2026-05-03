extends Control

# RESULT phase: 셸의 ModalLayer 위에 결과 모달을 띄운다.
# 필드는 전투 직후 상태 그대로 (셸 BattleLayer의 잔존 유닛 노드는 arena_root가 정리하지만,
# 시각적 단절 없이 모달이 즉시 뜬다).

const ARENA_ROOT := preload("res://src/ui/arena_root.gd")

signal transition_requested(next: int, payload: Variant)
signal main_menu_requested

var shell: Dictionary = {}
var _modal_root: Control = null
var _result: BattleResult = null

func bind_shell(s: Dictionary) -> void:
	shell = s

func set_payload(payload: Variant) -> void:
	_result = payload as BattleResult

func _ready() -> void:
	if shell.is_empty():
		push_error("result_phase: shell not bound")
		return
	if _result == null:
		# 방어적 fallback — payload 없이 진입하면 빈 결과로 표시.
		_result = BattleResult.new()
	_build_modal()

func _build_modal() -> void:
	var won: bool = _result.won
	var was_last: bool = _result.was_last_round
	var kills: int = _result.kills
	var losses: int = _result.losses
	var gold_earned: int = _result.gold_earned

	_modal_root = Control.new()
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.modal_layer.add_child(_modal_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.add_child(dim)

	var modal := PanelContainer.new()
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.offset_left = -300.0
	modal.offset_top = -240.0
	modal.offset_right = 300.0
	modal.offset_bottom = 240.0
	_modal_root.add_child(modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	modal.add_child(vbox)

	var headline := Label.new()
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 60)
	if won and was_last:
		headline.text = "RUN CLEAR"
		headline.theme_type_variation = &"LabelGold"
	elif won:
		headline.text = "VICTORY"
		headline.theme_type_variation = &"LabelPlayer"
	else:
		headline.text = "DEFEAT"
		headline.theme_type_variation = &"LabelEnemy"
	vbox.add_child(headline)

	var stats_lbl := Label.new()
	stats_lbl.text = "처치 %d  ·  손실 %d" % [kills, losses]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(stats_lbl)

	var gold_lbl := Label.new()
	if gold_earned > 0:
		gold_lbl.text = "+%d g  →  현재 %d g" % [gold_earned, RunState.gold]
	else:
		gold_lbl.text = "현재 %d g" % RunState.gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.add_theme_font_size_override("font_size", 24)
	gold_lbl.theme_type_variation = &"LabelGold"
	vbox.add_child(gold_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "메인 메뉴"
	menu_btn.custom_minimum_size = Vector2(180, 60)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.pressed.connect(func(): main_menu_requested.emit())
	btn_row.add_child(menu_btn)

	# Run-ending state: no "다음 라운드".
	var run_ended: bool = (not won) or was_last
	if not run_ended:
		var next_btn := Button.new()
		next_btn.text = "다음 라운드"
		next_btn.custom_minimum_size = Vector2(280, 60)
		next_btn.add_theme_font_size_override("font_size", 28)
		next_btn.pressed.connect(func(): transition_requested.emit(ARENA_ROOT.PhaseId.PREP, null))
		btn_row.add_child(next_btn)
		next_btn.grab_focus()
	else:
		menu_btn.grab_focus()

func _exit_tree() -> void:
	# 모달은 shell.modal_layer 자식이므로 arena_root._clear_shell_slots()가 정리한다.
	_modal_root = null
