extends Control

# PREP phase (덱빌딩 모델): 적 공개 → 덱 드로우 → 예산 안에서 3×3 배치 → 버리기 → 전투 시작.
# 골드를 쓰지 않는다 (배치는 예산만 소모). 셸 슬롯 사용은 docs/game_design/SCENES.md §C.PREP 참조.
#
# 옛 누적 모델(4×4·사분면 누적·paid/unpaid·아이템·시너지)에서 전면 재작성됨:
#  · 1칸 1유닛 (사분면 없음)  · 배치=예산 소모(골드 무관)  · 핸드=내 덱에서 드로우  · 버리기(횟수 제한)
#  · 아이템/시너지 UI 제거(조커로 통합)  · 전력 지표 신설

const ARENA_ROOT := preload("res://src/ui/arena_root.gd")

const GRID_COLS := 3
const GRID_ROWS := 3
const GRID_CELLS := GRID_COLS * GRID_ROWS
const TOKEN_SCALE_SOLO := 0.75

const _SELECTED_BORDER := Color(1.0, 0.65, 0.2)
const _SOLDIER_ACCENT := Color(0.55, 0.72, 0.95)
const _MOD_ACCENT := Color(0.55, 0.85, 0.55)
const _SPELL_ACCENT := Color(0.95, 0.75, 0.45)
const _AURA_ACCENT := Color(0.75, 0.6, 0.95)
const _TRAP_ACCENT := Color(0.9, 0.55, 0.6)

signal transition_requested(next: int, payload: Variant)
signal main_menu_requested

var shell: Dictionary = {}
var _coord_mapper: PrepCoordMapper = null
var _hand_cards: Array[Control] = []
var _marked_for_discard: Array[int] = []
var _summary_lbl: Label = null
var _power_lbl: Label = null
var _discard_btn: Button = null
var _start_btn: Button = null

func bind_shell(s: Dictionary) -> void:
	shell = s

func _ready() -> void:
	if shell.is_empty():
		push_error("prep_phase: shell not bound")
		return
	# 판 초기화 + 예산 리셋 + 덱 드로우 + 버리기 횟수 리셋 (단일 지점).
	RunState.begin_prep()
	_coord_mapper = PrepCoordMapper.new(shell.player_zone, GRID_COLS, GRID_ROWS)

	var pz: PlacementZone = shell.player_zone
	if not pz.place_requested.is_connected(_on_place_requested):
		pz.place_requested.connect(_on_place_requested)
	if not pz.swap_requested.is_connected(_on_swap_requested):
		pz.swap_requested.connect(_on_swap_requested)
	if not pz.drag_ended.is_connected(_on_drag_ended):
		pz.drag_ended.connect(_on_drag_ended)
	if not pz.cell_clicked.is_connected(_on_cell_clicked):
		pz.cell_clicked.connect(_on_cell_clicked)
	pz.get_cell_has_unit = Callable(self, "_cell_has_unit")
	pz.build_drag_preview = Callable(self, "_build_swap_preview")
	pz.can_drop_hand_card = Callable(self, "_can_drop_hand_card")

	_build_bottom_bar()
	_build_hand()
	_render_enemies_preview()
	_render_placed()
	_refresh_all()

func _exit_tree() -> void:
	var pz: PlacementZone = shell.get("player_zone")
	if pz != null and is_instance_valid(pz):
		if pz.place_requested.is_connected(_on_place_requested):
			pz.place_requested.disconnect(_on_place_requested)
		if pz.swap_requested.is_connected(_on_swap_requested):
			pz.swap_requested.disconnect(_on_swap_requested)
		if pz.drag_ended.is_connected(_on_drag_ended):
			pz.drag_ended.disconnect(_on_drag_ended)
		if pz.cell_clicked.is_connected(_on_cell_clicked):
			pz.cell_clicked.disconnect(_on_cell_clicked)
		pz.get_cell_has_unit = Callable()
		pz.build_drag_preview = Callable()
		pz.can_drop_hand_card = Callable()

# ─── BottomBar ────────────────────────────────────────────────────────────
func _build_bottom_bar() -> void:
	var bar: HBoxContainer = shell.bottom_bar
	for c in bar.get_children():
		c.queue_free()

	_summary_lbl = Label.new()
	_summary_lbl.custom_minimum_size = Vector2(360, 0)
	_summary_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 22)
	_summary_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))
	bar.add_child(_summary_lbl)

	_discard_btn = Button.new()
	_discard_btn.custom_minimum_size = Vector2(180, 52)
	_discard_btn.add_theme_font_size_override("font_size", 20)
	_discard_btn.pressed.connect(_on_discard_pressed)
	bar.add_child(_discard_btn)

	_start_btn = Button.new()
	_start_btn.text = "전투 시작"
	_start_btn.custom_minimum_size = Vector2(240, 60)
	_start_btn.add_theme_font_size_override("font_size", 28)
	_start_btn.pressed.connect(_on_start_battle)
	bar.add_child(_start_btn)

	# 전력 지표 — 화면 상단 중앙에 띄운다 (즉사 규칙 공정성 전제, GAME_DESIGN §6).
	_power_lbl = Label.new()
	_power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_lbl.add_theme_font_size_override("font_size", 18)
	_power_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_power_lbl.offset_left = -320.0
	_power_lbl.offset_right = 320.0
	_power_lbl.offset_top = 8.0
	_power_lbl.offset_bottom = 40.0
	add_child(_power_lbl)

# ─── Hand ─────────────────────────────────────────────────────────────────
func _build_hand() -> void:
	var slot: Control = shell.hand_slot
	for c in slot.get_children():
		c.queue_free()
	_hand_cards.clear()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)

	for i in RunState.hand.size():
		var card := _make_hand_card(i)
		row.add_child(card)
		_hand_cards.append(card)

func _make_hand_card(idx: int) -> Control:
	var c: Card = RunState.hand[idx]
	var accent := _accent_for(c.kind)

	var card := HandCard.new()
	card.slot_idx = idx
	card.draggable = true
	card.custom_minimum_size = Vector2(180, 200)
	card.focus_mode = Control.FOCUS_NONE
	var cname := _card_name(c)
	card.preview_unit_name = cname
	if c.is_soldier() and c.unit_data != null:
		card.preview_unit_data = c.unit_data
	_apply_card_styles(card, accent)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	if c.is_soldier() and c.unit_data != null:
		var portrait := _make_hand_portrait(c.unit_data)
		portrait.custom_minimum_size = Vector2(0, 96)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(portrait)
	else:
		var glyph := Label.new()
		glyph.text = _glyph_for(c.kind)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
		glyph.add_theme_font_size_override("font_size", 64)
		glyph.add_theme_color_override("font_color", accent.lightened(0.15))
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(glyph)

	var name_lbl := Label.new()
	name_lbl.text = cname
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", accent.lightened(0.35))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	if c.is_soldier() and c.unit_data != null:
		var stats_lbl := Label.new()
		stats_lbl.text = "♥ %d  ⚔ %d" % [int(c.unit_data.max_hp), int(c.unit_data.attack)]
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(stats_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "코스트 %d" % c.cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 17)
	cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_lbl)

	card.pressed.connect(_on_hand_card_clicked.bind(idx))
	_add_select_border(card)
	return card

# 핸드 카드 클릭 = 버리기 선택 토글. (배치는 드래그로)
func _on_hand_card_clicked(idx: int) -> void:
	if _marked_for_discard.has(idx):
		_marked_for_discard.erase(idx)
	else:
		_marked_for_discard.append(idx)
	_refresh_hand_state()
	_refresh_bottom_bar()

func _apply_card_styles(card: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.20)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(0.18, 0.20, 0.28)
	card.add_theme_stylebox_override("hover", sb_hover)
	var sb_disabled: StyleBoxFlat = sb.duplicate()
	sb_disabled.bg_color = Color(0.10, 0.11, 0.15)
	sb_disabled.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	card.add_theme_stylebox_override("disabled", sb_disabled)

func _add_select_border(card: Control) -> void:
	var sel := ReferenceRect.new()
	sel.name = "SelectBorder"
	sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sel.border_color = _SELECTED_BORDER
	sel.border_width = 3.0
	sel.editor_only = false
	sel.visible = false
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sel)

func _make_hand_portrait(ud: UnitData) -> Control:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrameLoader.build(ud.sprite_dir)
	sprite.scale = Vector2.ONE * ud.sprite_scale * TOKEN_SCALE_SOLO
	sprite.position = Vector2(80, 80)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	holder.add_child(sprite)
	return holder

# ─── Placement signals ────────────────────────────────────────────────────
func _on_place_requested(hand_idx: int, cell_idx: int) -> void:
	if hand_idx < 0 or hand_idx >= RunState.hand.size():
		return
	var c: Card = RunState.hand[hand_idx]
	var ok := false
	if c.is_soldier():
		ok = RunState.place_soldier(cell_idx, hand_idx)
	elif c.is_mod():
		ok = RunState.attach_mod(cell_idx, hand_idx)
	if not ok:
		return
	_marked_for_discard.clear()  # 핸드 인덱스가 바뀌므로 버리기 선택 초기화
	_build_hand()
	_render_placed()
	_refresh_all()

func _on_cell_clicked(cell_idx: int) -> void:
	# 배치된 칸 클릭 = 회수 (병사+강화 카드 핸드 복귀, 예산 환급).
	if not _cell_has_unit(cell_idx):
		return
	RunState.remove_cell(cell_idx)
	_marked_for_discard.clear()
	_build_hand()
	_render_placed()
	_refresh_all()

func _on_swap_requested(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return
	var cells: Array = RunState.board_cells()
	if from_idx < 0 or from_idx >= cells.size() or to_idx < 0 or to_idx >= cells.size():
		return
	var tmp = cells[from_idx]
	cells[from_idx] = cells[to_idx]
	cells[to_idx] = tmp
	_render_placed()

func _on_drag_ended() -> void:
	_render_placed()

func _cell_has_unit(idx: int) -> bool:
	var cells: Array = RunState.board_cells()
	return idx >= 0 and idx < cells.size() and cells[idx] != null

func _can_drop_hand_card(hand_idx: int, cell_idx: int) -> bool:
	if hand_idx < 0 or hand_idx >= RunState.hand.size():
		return false
	var c: Card = RunState.hand[hand_idx]
	if c.is_soldier():
		return not _cell_has_unit(cell_idx) and RunState.budget_left() >= c.cost
	if c.is_mod():
		return _cell_has_unit(cell_idx) and RunState.budget_left() >= c.cost
	return false

func _build_swap_preview(idx: int, _anchor: Vector2) -> Control:
	var cells: Array = RunState.board_cells()
	if idx < 0 or idx >= cells.size() or cells[idx] == null:
		return null
	var ud: UnitData = (cells[idx]["card"] as Card).unit_data
	if ud == null:
		return null
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_make_field_token(ud, Vector2.ZERO, false))
	return holder

# ─── Enemy preview ────────────────────────────────────────────────────────
func _render_enemies_preview() -> void:
	EnemyPreviewView.render(
		shell.enemy_zone,
		RunState.current_enemy_lineup(),
		RunState.current_tactic_key(),
		Callable(self.get_script(), "_make_field_token")
	)

# ─── Placed tokens ────────────────────────────────────────────────────────
func _render_placed() -> void:
	var zone: Control = shell.player_zone
	for c in zone.get_children():
		c.queue_free()

	var cs: Vector2 = _coord_mapper.cell_size()
	for i in GRID_CELLS:
		var origin: Vector2 = _coord_mapper.cell_origin(i)
		var bg := ColorRect.new()
		bg.size = cs
		bg.position = origin
		bg.color = Color(0.18, 0.20, 0.28, 0.5) if i % 2 == 0 else Color(0.22, 0.24, 0.32, 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(bg)
		var border := ReferenceRect.new()
		border.size = cs
		border.position = origin
		border.border_color = Color(0.4, 0.42, 0.55, 0.7)
		border.border_width = 1.0
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(border)

	var cells: Array = RunState.board_cells()
	for i in GRID_CELLS:
		var entry = cells[i]
		if entry == null:
			continue
		var ud: UnitData = (entry["card"] as Card).unit_data
		var center: Vector2 = _coord_mapper.cell_center(i)
		var y_comp: float = ud.sprite_scale * TOKEN_SCALE_SOLO * 18.0
		var y_lift: float = cs.y * 0.5
		var pos: Vector2 = center + Vector2(0.0, y_comp - y_lift)
		var token: Node = _make_field_token(ud, pos, false)
		zone.add_child(token)

		var mods: Array = entry["mods"]
		if not mods.is_empty():
			var badge := Label.new()
			badge.text = "+%d" % mods.size()
			badge.add_theme_font_size_override("font_size", 16)
			badge.add_theme_color_override("font_color", _MOD_ACCENT.lightened(0.3))
			badge.position = origin_of(i) + Vector2(cs.x - 34, 4)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zone.add_child(badge)

func origin_of(i: int) -> Vector2:
	return _coord_mapper.cell_origin(i)

static func _make_field_token(unit_data: UnitData, local_pos: Vector2, is_enemy: bool, scale_mult: float = TOKEN_SCALE_SOLO) -> Node:
	var holder := Node2D.new()
	holder.position = local_pos
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrameLoader.build(unit_data.sprite_dir)
	sprite.scale = Vector2.ONE * unit_data.sprite_scale * scale_mult
	if is_enemy:
		sprite.flip_h = true
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	holder.add_child(sprite)
	return holder

# ─── Refresh ──────────────────────────────────────────────────────────────
func _refresh_all() -> void:
	_refresh_hand_state()
	_refresh_bottom_bar()
	_refresh_power()

func _refresh_hand_state() -> void:
	for i in _hand_cards.size():
		var card: Button = _hand_cards[i] as Button
		var c: Card = RunState.hand[i]
		# 예산 부족이면 배치 불가 표시 (버리기 선택은 여전히 가능하므로 disabled로 막지 않는다).
		var sel: ReferenceRect = card.get_node_or_null("SelectBorder") as ReferenceRect
		if sel != null:
			sel.visible = _marked_for_discard.has(i)
		card.modulate = Color(1, 1, 1, 1) if RunState.budget_left() >= c.cost else Color(1, 0.7, 0.7, 1)

func _refresh_bottom_bar() -> void:
	if _summary_lbl != null:
		_summary_lbl.text = "예산 %d / %d   ·   출전 %d기" % [
			RunState.budget_left(), RunState.budget_total, RunState.soldier_count()
		]
	if _discard_btn != null:
		var n := _marked_for_discard.size()
		_discard_btn.text = "버리기 (%d) [남은 %d회]" % [n, RunState.discard_left]
		_discard_btn.disabled = RunState.discard_left <= 0 or n == 0
	if _start_btn != null:
		_start_btn.disabled = RunState.soldier_count() == 0

func _refresh_power() -> void:
	if _power_lbl == null:
		return
	var ally := _totals_from_board()
	var enemy := _totals_from_lineup(RunState.current_enemy_lineup())
	var ttk_ally: float = enemy["hp"] / maxf(ally["dps"], 0.01)   # 우리가 적을 지우는 시간
	var ttk_enemy: float = ally["hp"] / maxf(enemy["dps"], 0.01)  # 적이 우리를 지우는 시간
	var ratio: float = ttk_enemy / maxf(ttk_ally, 0.01)
	var verdict := "열세"
	var col := Color(0.95, 0.5, 0.5)
	if ally["dps"] <= 0.0:
		verdict = "—"
		col = Color(0.7, 0.7, 0.7)
	elif ratio >= 1.35:
		verdict = "여유"; col = Color(0.5, 0.9, 0.6)
	elif ratio >= 1.05:
		verdict = "우세"; col = Color(0.7, 0.9, 0.5)
	elif ratio >= 0.85:
		verdict = "박빙"; col = Color(0.95, 0.85, 0.45)
	_power_lbl.add_theme_color_override("font_color", col)
	_power_lbl.text = "전력  아군 HP %d·DPS %d  vs  적 HP %d·DPS %d   →  [%s]  (방어·조커 미반영 근사)" % [
		int(ally["hp"]), int(ally["dps"]), int(enemy["hp"]), int(enemy["dps"]), verdict
	]

func _totals_from_board() -> Dictionary:
	var hp := 0.0
	var dps := 0.0
	for e in RunState.board_cells():
		if e == null:
			continue
		var ud: UnitData = (e["card"] as Card).unit_data
		var s := _base_stats(ud)
		for m in (e["mods"] as Array):
			_apply_mod(s, m as Card)
		hp += s["hp"] + s["defense"] * 3.0
		dps += s["atk"] * s["aspd"]
	return {"hp": hp, "dps": dps}

func _totals_from_lineup(lineup: Array) -> Dictionary:
	var hp := 0.0
	var dps := 0.0
	for u in lineup:
		var ud := u as UnitData
		if ud == null:
			continue
		hp += ud.max_hp + ud.defense * 3.0
		dps += ud.attack * ud.attack_speed
	return {"hp": hp, "dps": dps}

func _base_stats(ud: UnitData) -> Dictionary:
	return {"hp": ud.max_hp, "atk": ud.attack, "defense": ud.defense, "aspd": ud.attack_speed}

func _apply_mod(s: Dictionary, m: Card) -> void:
	match String(m.mod_stat):
		"hp":      s["hp"] += m.mod_amount
		"atk":     s["atk"] += m.mod_amount
		"defense": s["defense"] += m.mod_amount
		"attack_speed": s["aspd"] += m.mod_amount
	# 키워드형 강화는 거친 근사에서 제외 (화면에 명시).

# ─── Discard ──────────────────────────────────────────────────────────────
func _on_discard_pressed() -> void:
	if _marked_for_discard.is_empty():
		return
	if not RunState.discard_and_redraw(_marked_for_discard.duplicate()):
		return
	_marked_for_discard.clear()
	_build_hand()
	_refresh_all()

# ─── PREP → BATTLE ────────────────────────────────────────────────────────
func _on_start_battle() -> void:
	if RunState.soldier_count() == 0:
		return
	var pz_origin: Vector2 = (shell.player_zone as Control).global_position
	var cells: Array = RunState.board_cells()
	var plan_units: Array = []
	for i in GRID_CELLS:
		var entry = cells[i]
		if entry == null:
			continue
		var center: Vector2 = _coord_mapper.cell_center(i)
		plan_units.append({
			"card": entry["card"],
			"mods": (entry["mods"] as Array).duplicate(),
			"position": pz_origin + center,
		})

	var plan := BattlePlan.new()
	plan.player_units = plan_units
	plan.enemy_lineup = RunState.current_enemy_lineup()
	plan.enemy_positions = _collect_enemy_positions()
	plan.round_index = RunState.current_round
	plan.tactic_key = RunState.current_tactic_key()
	plan.jokers = RunState.jokers.duplicate()

	RunState.commit_deployment(plan_units, plan.enemy_positions)
	transition_requested.emit(ARENA_ROOT.PhaseId.BATTLE, plan)

func _collect_enemy_positions() -> Array:
	var ez: Control = shell.enemy_zone
	var lineup: Array = RunState.current_enemy_lineup()
	var n: int = lineup.size()
	if n == 0 or ez == null:
		return []
	var origin: Vector2 = ez.global_position
	var zone_w: float = ez.size.x if ez.size.x > 0.0 else 360.0
	var zone_h: float = ez.size.y if ez.size.y > 0.0 else 360.0
	var field_h: float = zone_h - EnemyPreviewView.TACTIC_LABEL_H
	var positions: Array = FormationLibrary.positions_for(RunState.current_tactic_key(), n, zone_w, field_h)
	var out: Array = []
	for pos in positions:
		out.append(origin + pos + Vector2(0.0, EnemyPreviewView.TACTIC_LABEL_H))
	return out

# ─── Card presentation helpers ────────────────────────────────────────────
func _accent_for(kind: int) -> Color:
	match kind:
		GameEnums.CardType.SOLDIER: return _SOLDIER_ACCENT
		GameEnums.CardType.MOD:     return _MOD_ACCENT
		GameEnums.CardType.SPELL:   return _SPELL_ACCENT
		GameEnums.CardType.AURA:    return _AURA_ACCENT
		GameEnums.CardType.TRAP:    return _TRAP_ACCENT
	return _SOLDIER_ACCENT

func _glyph_for(kind: int) -> String:
	match kind:
		GameEnums.CardType.MOD:   return "▲"
		GameEnums.CardType.SPELL: return "✦"
		GameEnums.CardType.AURA:  return "◎"
		GameEnums.CardType.TRAP:  return "⚑"
	return "◆"

func _card_name(c: Card) -> String:
	if c.is_soldier() and c.unit_data != null:
		return tr(c.unit_data.name_key)
	if c.name_key != "":
		return tr(c.name_key)
	return "?"
