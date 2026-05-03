extends Control

# PREP phase: 셸의 PlayerZone(3x3 셀 + 배치 토큰) / EnemyZone(적 프리뷰) /
# HandSlot(핸드카드) / BottomBar(돌아가기/요약/전투시작)을 채운다.
# PlacementZone은 셸 소속이라 시그널만 연결.

const ARENA_ROOT := preload("res://src/ui/arena_root.gd")
const HERO_INFO_POPUP_SCENE := preload("res://src/ui/hero_info_popup.tscn")
const CardInfoPopupScript := preload("res://src/ui/card_info_popup.gd")

const GRID_COLS := 3
const GRID_ROWS := 3
const GRID_CELLS := GRID_COLS * GRID_ROWS

# 셀 내부 2×2 서브그리드 — 영웅이 누적될 때 ×N 뱃지 대신 사분면에 분산 배치.
const SUB_GRID_COLS := 2
const SUB_GRID_ROWS := 2
const SUB_GRID_CAPACITY := SUB_GRID_COLS * SUB_GRID_ROWS  # 4

# 필드 토큰 스케일 배율 — 셀에 단독 배치된 토큰 기준값.
const TOKEN_SCALE_SOLO := 0.75

# 전투 좌표계: PlayerZone 글로벌(36,168)~(954,738), EnemyZone(966,168)~(1884,738).
const BATTLE_PLAYER_X_MIN := 36.0
const BATTLE_PLAYER_X_MAX := 954.0
const BATTLE_Y_MIN := 168.0
const BATTLE_Y_MAX := 738.0

signal transition_requested(next: int, payload: Variant)
signal main_menu_requested

var shell: Dictionary = {}

# 셀 상태는 RunState.grid_cells (영구 그리드)로 이관.
# 각 셀은 Array of {slot: RosterSlot, paid: bool, hand_idx: int} Dictionary.
# paid==true 는 이전 라운드에서 결제 완료된 영구 자산, paid==false 는 이번 PREP 미결제.
# hand_idx 는 unpaid entry의 현재 hand 슬롯 인덱스(-1 이면 무효 — 카드 회수 시 단순 폐기).

# hand index → cell index (-1 = 미배치). 카드는 1회용.
# unpaid entry만 _card_to_cell에 등록된다 (paid는 hand_idx=-1 이라 영향 없음).
var _card_to_cell: Array[int] = []
var _selected_cell: int = -1
var _selected_hand_idx: int = -1  # 주황 테두리를 표시할 핸드 카드 인덱스 (-1 = 없음)
var _hand_cards: Array[Control] = []
var _summary_lbl: Label = null
var _start_battle_btn: Button = null
var _hero_info_popup: HeroInfoPopup = null
var _card_info_popup: CardInfoPopup = null
var _coord_mapper: PrepCoordMapper = null
var _item_drop_zone: ItemDropZone = null

func bind_shell(s: Dictionary) -> void:
	shell = s

func _ready() -> void:
	if shell.is_empty():
		push_error("prep_phase: shell not bound")
		return
	_coord_mapper = PrepCoordMapper.new(shell.player_zone, GRID_COLS, GRID_ROWS)
	_reset_placement_state()

	# PlacementZone 시그널 연결 + 셀 상태/프리뷰 콜백 주입
	var pz: PlacementZone = shell.player_zone
	if not pz.place_requested.is_connected(_on_place_requested):
		pz.place_requested.connect(_on_place_requested)
	if not pz.swap_requested.is_connected(_on_swap_requested):
		pz.swap_requested.connect(_on_swap_requested)
	if not pz.drag_started.is_connected(_on_drag_started):
		pz.drag_started.connect(_on_drag_started)
	if not pz.drag_ended.is_connected(_on_drag_ended):
		pz.drag_ended.connect(_on_drag_ended)
	if not pz.cell_clicked.is_connected(_on_cell_clicked):
		pz.cell_clicked.connect(_on_cell_clicked)
	pz.get_cell_has_unit = Callable(self, "_cell_has_unit")
	pz.build_drag_preview = Callable(self, "_build_swap_preview")
	pz.can_drop_hand_card = Callable(self, "_can_drop_hand_card_to_cell")

	_spawn_hero_info_popup()
	_spawn_card_info_popup()
	_build_bottom_bar()
	_build_hand()
	_build_item_slot()
	_render_enemies_preview()
	_render_placed()
	_refresh_hand_state()
	_update_summary_and_button()

func _exit_tree() -> void:
	# PlacementZone은 셸 소속이므로 남아있다. 시그널만 끊어둔다.
	var pz: PlacementZone = shell.get("player_zone")
	if pz != null and is_instance_valid(pz):
		if pz.place_requested.is_connected(_on_place_requested):
			pz.place_requested.disconnect(_on_place_requested)
		if pz.swap_requested.is_connected(_on_swap_requested):
			pz.swap_requested.disconnect(_on_swap_requested)
		if pz.drag_started.is_connected(_on_drag_started):
			pz.drag_started.disconnect(_on_drag_started)
		if pz.drag_ended.is_connected(_on_drag_ended):
			pz.drag_ended.disconnect(_on_drag_ended)
		if pz.cell_clicked.is_connected(_on_cell_clicked):
			pz.cell_clicked.disconnect(_on_cell_clicked)
		pz.get_cell_has_unit = Callable()
		pz.build_drag_preview = Callable()
		pz.can_drop_hand_card = Callable()
	# ModalLayer 자식은 phase가 명시적으로 정리 (셸은 _clear_shell_slots에서 일괄 비우지만,
	# 우리가 띄운 노드의 수명은 우리가 책임진다.)
	if _hero_info_popup != null and is_instance_valid(_hero_info_popup):
		_hero_info_popup.queue_free()
		_hero_info_popup = null
	if _card_info_popup != null and is_instance_valid(_card_info_popup):
		_card_info_popup.queue_free()
		_card_info_popup = null

# ─── BottomBar ────────────────────────────────────────────────────────────
func _build_bottom_bar() -> void:
	var bar: HBoxContainer = shell.bottom_bar

	_summary_lbl = Label.new()
	_summary_lbl.custom_minimum_size = Vector2(480, 0)
	_summary_lbl.text = "출전: 0명 / 비용 0 g"
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 24)
	_summary_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))
	bar.add_child(_summary_lbl)

	_start_battle_btn = Button.new()
	_start_battle_btn.text = "전투 시작"
	_start_battle_btn.custom_minimum_size = Vector2(330, 60)
	_start_battle_btn.add_theme_font_size_override("font_size", 30)
	_start_battle_btn.pressed.connect(_on_start_battle)
	# 화면 상단 가운데에 띄운다. PrepPhase 루트(PhaseContainer 자식)에 붙어 있어서
	# phase 전환 시 함께 정리된다.
	_start_battle_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_start_battle_btn.offset_left = -165.0
	_start_battle_btn.offset_right = 165.0
	_start_battle_btn.offset_top = 24.0
	_start_battle_btn.offset_bottom = 84.0
	add_child(_start_battle_btn)

# ─── Hand (HandSlot) ──────────────────────────────────────────────────────
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

	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 12)
	scroll.add_child(hand)

	hand.add_child(_make_reroll_button())

	for i in RunState.hand.size():
		var card := _make_hand_card(i)
		hand.add_child(card)
		_hand_cards.append(card)

func _reset_placement_state() -> void:
	RunState._ensure_grid()
	_resync_card_to_cell()

# 셀은 유지하고 _card_to_cell 만 새 hand 길이에 맞춰 재초기화한다.
# 라운드 진입/리롤 직후에 호출 — 둘 다 hand 갱신 시점이라 hand_idx 매핑이 무효해진 직후다.
func _resync_card_to_cell() -> void:
	_card_to_cell.clear()
	for i in RunState.hand.size():
		_card_to_cell.append(-1)

func _make_reroll_button() -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 200)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = "핸드를 다시 뽑는다 (-%d g)" % RunState.REROLL_COST
	btn.disabled = RunState.gold < RunState.REROLL_COST

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.26)
	sb.border_color = Color(0.55, 0.45, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(0.22, 0.20, 0.34)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = Color(0.10, 0.12, 0.18)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var sb_disabled: StyleBoxFlat = sb.duplicate()
	sb_disabled.bg_color = Color(0.12, 0.13, 0.18)
	sb_disabled.border_color = Color(0.35, 0.30, 0.45)
	btn.add_theme_stylebox_override("disabled", sb_disabled)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := Label.new()
	icon.text = "↻"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 56)
	icon.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = "리롤"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "−%d g" % RunState.REROLL_COST
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.theme_type_variation = &"LabelGold"
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_lbl)

	btn.pressed.connect(_on_reroll_pressed)
	return btn

func _on_reroll_pressed() -> void:
	if not RunState.reroll_hand():
		return
	# 카드만 리롤 — 셀에 배치된 병사는 유지(RosterSlot 참조로 보관됨).
	# 새 hand 풀이 갈아엎혀 unpaid entry의 hand_idx 의미 소실 → -1로 무효화.
	# (회수 시 paid==false면 카드 핸드 복귀 없이 단순 폐기로 떨어진다.)
	RunState.grid_invalidate_unpaid_hand_indices()
	_resync_card_to_cell()
	_selected_hand_idx = -1
	_build_hand()
	_render_placed()
	_refresh_hand_state()
	_update_summary_and_button()
	shell.top_bar.set_gold_preview(_total_cost())
	shell.top_bar.refresh_gold()

func _make_hand_card(slot_idx: int) -> Control:
	var slot: RosterSlot = RunState.hand[slot_idx]
	match slot.kind:
		GameEnums.CardKind.HERO:    return _make_hero_card(slot_idx, slot)
		GameEnums.CardKind.UPGRADE: return _make_dummy_card(slot_idx, slot, "강화", PrepCardStyle.ACCENT_UPGRADE, "▲")
		GameEnums.CardKind.SKILL:   return _make_dummy_card(slot_idx, slot, "스킬", PrepCardStyle.ACCENT_SKILL, "✦")
		GameEnums.CardKind.ITEM:    return _make_dummy_card(slot_idx, slot, "아이템", PrepCardStyle.ACCENT_ITEM, "◆")
	return _make_hero_card(slot_idx, slot)

# 영웅 카드는 통일된 단일 컬러로(코스트별 차등 없음).
const _HERO_ACCENT := Color(0.55, 0.72, 0.95)
# 클릭으로 선택된 셀의 외곽선.
const _SELECTED_BORDER := Color(1.0, 0.65, 0.2)
# 카드 종류별 accent는 PrepCardStyle (src/ui/prep/prep_card_style.gd)에서 가져온다.

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
	sb_hover.border_color = accent.lightened(0.2)
	card.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = Color(0.09, 0.10, 0.14)
	card.add_theme_stylebox_override("pressed", sb_pressed)
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

func _make_hero_card(slot_idx: int, slot: RosterSlot) -> Control:
	var ud: UnitData = slot.unit_data
	var price: int = RunState.hire_price_for(ud)
	var accent: Color = _HERO_ACCENT

	var card := HandCard.new()
	card.slot_idx = slot_idx
	var ud_name := tr(ud.name_key)
	card.preview_unit_name = ud_name
	card.preview_unit_data = ud
	card.draggable = true
	card.custom_minimum_size = Vector2(200, 200)
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = "%s\n가격 %d g\nHP %d  ATK %d  DEF %d" % [
		ud_name, price, int(ud.max_hp), int(ud.attack), int(ud.armor)
	]
	_apply_card_styles(card, accent)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var portrait := _make_hand_portrait(ud)
	portrait.custom_minimum_size = Vector2(0, 100)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = ud_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", accent.lightened(0.35))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "♥ %d  ⚔ %d" % [int(ud.max_hp), int(ud.attack)]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d g" % price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.theme_type_variation = &"LabelGold"
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_lbl)

	if not slot.items.is_empty():
		var parts: Array[String] = []
		for it in slot.items:
			parts.append(tr(it.name_key))
		var item_lbl := Label.new()
		item_lbl.text = "[" + ", ".join(parts) + "]"
		item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_lbl.add_theme_font_size_override("font_size", 13)
		item_lbl.modulate = Color(0.85, 0.85, 0.5)
		item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(item_lbl)

	card.pressed.connect(_on_hero_card_clicked.bind(slot_idx))
	_add_select_border(card)
	return card

func _on_hero_card_clicked(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return
	if _card_to_cell[slot_idx] != -1:
		return  # 이미 배치된 카드는 핸드에 숨겨져 있어 클릭 안 됨.
	var slot: RosterSlot = RunState.hand[slot_idx]
	if _card_info_popup != null and _card_info_popup.visible:
		_card_info_popup.hide()
	_selected_hand_idx = slot_idx
	_selected_cell = -1
	_refresh_hand_state()
	if _hero_info_popup != null:
		_hero_info_popup.show_for(slot, {}, RunState.inventory)

func _make_dummy_card(slot_idx: int, slot: RosterSlot, kind_label: String, accent: Color, glyph: String) -> Control:
	var card := HandCard.new()
	card.slot_idx = slot_idx
	card.preview_unit_name = slot.dummy_name
	if slot.item_data != null:
		card.preview_icon = slot.item_data.load_icon()
	card.draggable = true
	card.custom_minimum_size = Vector2(200, 200)
	card.focus_mode = Control.FOCUS_NONE
	var _drag_hint: String = "아이템 인벤토리에 드래그해 구매" if slot.kind == GameEnums.CardKind.ITEM else "영웅에게 드래그해 사용"
	card.tooltip_text = "%s\n가격 %d g\n%s" % [slot.dummy_name, slot.dummy_price, _drag_hint]
	_apply_card_styles(card, accent)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var icon_tex: Texture2D = slot.item_data.load_icon() if slot.item_data != null else null
	if icon_tex != null:
		var center := CenterContainer.new()
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(40, 40)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tex_rect)
		vbox.add_child(center)
	else:
		var glyph_lbl := Label.new()
		glyph_lbl.text = glyph
		glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		glyph_lbl.add_theme_font_size_override("font_size", 76)
		glyph_lbl.add_theme_color_override("font_color", accent.lightened(0.15))
		glyph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(glyph_lbl)

	var kind_lbl := Label.new()
	kind_lbl.text = kind_label
	kind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_lbl.add_theme_font_size_override("font_size", 13)
	kind_lbl.add_theme_color_override("font_color", accent.lightened(0.45))
	kind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(kind_lbl)

	var name_lbl := Label.new()
	name_lbl.text = slot.dummy_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "%d g" % slot.dummy_price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.theme_type_variation = &"LabelGold"
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_lbl)

	card.pressed.connect(_on_dummy_card_clicked.bind(slot_idx, kind_label, accent))
	_add_select_border(card)
	return card

func _on_dummy_card_clicked(slot_idx: int, kind_label: String, accent: Color) -> void:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return
	if _card_to_cell[slot_idx] != -1:
		return
	var slot: RosterSlot = RunState.hand[slot_idx]
	# 영웅 팝업을 닫고 선택 해제.
	if _hero_info_popup != null and _hero_info_popup.visible:
		_hero_info_popup.hide()
		_selected_cell = -1
	_selected_hand_idx = slot_idx
	_refresh_hand_state()
	if _card_info_popup != null:
		_card_info_popup.show_for(slot, kind_label, accent)

func _make_hand_portrait(unit_data: UnitData) -> Control:
	var holder := Control.new()
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrameLoader.build(unit_data.sprite_dir)
	sprite.scale = Vector2.ONE * unit_data.sprite_scale * 0.75
	sprite.position = Vector2(90, 90)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	holder.add_child(sprite)
	return holder

func _refresh_hand_state() -> void:
	var remaining: int = _gold_remaining()
	for i in _hand_cards.size():
		var card: Button = _hand_cards[i] as Button
		# _card_to_cell: -1=핸드 대기, >=0=셀에 배치, -2=더미 사용 후 영구 소모.
		# 한번 쓴 카드는 핸드에서 사라진다 (HERO는 셀에서 회수 시 다시 보임).
		card.visible = (_card_to_cell[i] == -1)
		var slot: RosterSlot = RunState.hand[i]
		var slot_price: int
		if slot.kind == GameEnums.CardKind.HERO:
			slot_price = RunState.hire_price_for(slot.unit_data)
		else:
			slot_price = slot.dummy_price
		# 더미 카드는 즉시 차감이라 _gold_remaining 비교가 정확하지 않을 수 있다 — 단순 잔액 기준.
		var available: int = remaining if slot.kind == GameEnums.CardKind.HERO else RunState.gold
		card.disabled = available < slot_price
		var sel_border: ReferenceRect = card.get_node_or_null("SelectBorder") as ReferenceRect
		if sel_border != null:
			sel_border.visible = (i == _selected_hand_idx)

# ─── Formation data ───────────────────────────────────────────────────────
# 정규화된 (x, y) 위치 (0–1). 레퍼런스 1~10번 역사 전술 반영.
# 슬롯 수 = 해당 웨이브 적 수 이상으로 정의; 초과분은 중앙 컬럼 폴백.
# 진형 좌표/라벨은 FormationLibrary로 분리됨 (src/data/formations/formation_library.gd).

# "적 진영" 글씨 바로 아래 전술 라벨을 위해 상단에 예약하는 높이.
const _TACTIC_LABEL_H: float = 44.0

# ─── Enemy preview (EnemyZone) ────────────────────────────────────────────
func _render_enemies_preview() -> void:
	EnemyPreviewView.render(
		shell.enemy_zone,
		RunState.current_enemy_lineup(),
		RunState.current_tactic_key(),
		Callable(self.get_script(), "_make_field_token")
	)

# ─── Player placements (PlayerZone) ───────────────────────────────────────
func _render_placed() -> void:
	var zone: Control = shell.player_zone
	for c in zone.get_children():
		c.queue_free()

	for i in GRID_CELLS:
		var rect := ColorRect.new()
		rect.size = _coord_mapper.cell_size()
		rect.position = _coord_mapper.cell_origin(i)
		rect.color = Color(0.18, 0.20, 0.28, 0.6)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(rect)
		var border := ReferenceRect.new()
		border.size = rect.size
		border.position = rect.position
		border.border_color = Color(0.4, 0.42, 0.55, 0.7)
		border.border_width = 1.0
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(border)

	for i in GRID_CELLS:
		var entries: Array = RunState.grid_cells[i]
		if entries.is_empty():
			continue
		var slot: RosterSlot = (entries[0] as Dictionary)["slot"] as RosterSlot
		var count: int = entries.size()
		var center: Vector2 = _coord_mapper.cell_center(i)
		var cs: Vector2 = _coord_mapper.cell_size()
		var visible: int = min(count, SUB_GRID_CAPACITY)
		# 사분면(2×2) 중심에 배치. count==1 이면 셀 중심.
		for k in visible:
			var pos: Vector2 = center + _coord_mapper.sub_cell_offset(k, count, cs)
			var token: Node = _make_field_token(slot.unit_data, pos, false)
			token.name = "token_%d_%d" % [i, k]
			zone.add_child(token)

		# 사분면 4개를 넘는 초과분은 우상단 ×N 뱃지로 표기.
		if count > SUB_GRID_CAPACITY:
			var badge := Label.new()
			badge.text = "+%d" % (count - SUB_GRID_CAPACITY)
			badge.add_theme_font_size_override("font_size", 18)
			badge.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
			badge.size = Vector2(60, 26)
			badge.position = _coord_mapper.cell_origin(i) + Vector2(cs.x - 64, 6)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zone.add_child(badge)

		var upgrade_level: int = RunState.grid_get_upgrade(i)
		if upgrade_level > 0:
			var star_lbl := Label.new()
			star_lbl.text = "★".repeat(upgrade_level)
			star_lbl.add_theme_font_size_override("font_size", 16)
			star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			star_lbl.position = _coord_mapper.cell_origin(i) + Vector2(4, 4)
			star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zone.add_child(star_lbl)

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

# ─── Placement signals ────────────────────────────────────────────────────
func _on_place_requested(slot_idx: int, cell_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return
	if cell_idx < 0 or cell_idx >= GRID_CELLS:
		return
	# 이미 다른 셀에 배치되었거나 더미로 소모된 카드는 거부 — 카드는 1회용.
	if _card_to_cell[slot_idx] != -1:
		return
	var slot: RosterSlot = RunState.hand[slot_idx]
	if slot.kind != GameEnums.CardKind.HERO:
		_apply_dummy_card_to_cell(slot_idx, slot, cell_idx)
		return
	var entries: Array = RunState.grid_cells[cell_idx]
	# 셀당 한 종류 규칙: 첫 카드의 유닛 ID와 일치해야 한다.
	if not entries.is_empty():
		var head: RosterSlot = (entries[0] as Dictionary)["slot"] as RosterSlot
		if head.unit_data.id != slot.unit_data.id:
			return
	# 셀당 최대 SUB_GRID_CAPACITY(=4) 명. 5번째 배치는 거부 — 다른 셀로 분산해야 한다.
	if entries.size() >= SUB_GRID_CAPACITY:
		return
	var price: int = RunState.hire_price_for(slot.unit_data)
	if _gold_remaining() < price:
		return
	entries.append({"slot": slot, "paid": false, "hand_idx": slot_idx})
	_card_to_cell[slot_idx] = cell_idx
	_render_placed()
	_refresh_hand_state()
	_update_summary_and_button()
	shell.top_bar.set_gold_preview(_total_cost())

func _on_drag_started(from_idx: int) -> void:
	var pz: Control = shell.player_zone
	for k in SUB_GRID_CAPACITY:
		var token := pz.get_node_or_null("token_%d_%d" % [from_idx, k])
		if token != null:
			token.visible = false

func _on_drag_ended() -> void:
	# 드래그 성공/취소 무관하게 셀 상태 기준으로 다시 그려서 숨겨졌던 토큰 복구.
	_render_placed()

func _on_swap_requested(from_idx: int, to_idx: int) -> void:
	if from_idx < 0 or from_idx >= GRID_CELLS:
		return
	if to_idx < 0 or to_idx >= GRID_CELLS:
		return
	if from_idx == to_idx:
		return
	var src: Array = RunState.grid_cells[from_idx]
	if src.is_empty():
		return
	var dst: Array = RunState.grid_cells[to_idx]
	RunState.grid_cells[to_idx] = src
	RunState.grid_cells[from_idx] = dst
	RunState.grid_swap_boosts(from_idx, to_idx)
	# unpaid entry는 hand_idx로 _card_to_cell에 등록돼 있으므로 셀 인덱스를 다시 매핑.
	# paid entry는 hand_idx=-1 이라 자동으로 무시된다. paid↔unpaid 혼합 스왑도 동일 로직.
	_selected_cell = -1
	_selected_hand_idx = -1
	if _hero_info_popup != null:
		_hero_info_popup.hide()
	_recompute_card_to_cell_from_grid()
	_render_placed()
	_refresh_hand_state()

func _recompute_card_to_cell_from_grid() -> void:
	var n: int = RunState.hand.size()
	_card_to_cell.clear()
	for i in n:
		_card_to_cell.append(-1)
	for cell_idx in GRID_CELLS:
		var entries: Array = RunState.grid_cells[cell_idx]
		for entry in entries:
			var d: Dictionary = entry as Dictionary
			if bool(d.get("paid", false)):
				continue
			var hand_idx: int = int(d.get("hand_idx", -1))
			if hand_idx < 0 or hand_idx >= n:
				continue
			# hand 슬롯이 다른 RosterSlot으로 갈렸으면 더 이상 같은 카드가 아님.
			if RunState.hand[hand_idx] != d["slot"]:
				continue
			_card_to_cell[hand_idx] = cell_idx

func _cell_has_unit(idx: int) -> bool:
	if idx < 0 or idx >= GRID_CELLS:
		return false
	return not (RunState.grid_cells[idx] as Array).is_empty()

func _cell_has_unpaid(idx: int) -> bool:
	if idx < 0 or idx >= GRID_CELLS:
		return false
	for entry in RunState.grid_cells[idx]:
		if not bool((entry as Dictionary).get("paid", false)):
			return true
	return false

func _build_swap_preview(idx: int, _anchor: Vector2) -> Control:
	if idx < 0 or idx >= GRID_CELLS:
		return null
	var entries: Array = RunState.grid_cells[idx]
	if entries.is_empty():
		return null
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count: int = min(entries.size(), SUB_GRID_CAPACITY)
	var cs: Vector2 = _coord_mapper.cell_size()
	for k in count:
		var ud: UnitData = ((entries[k] as Dictionary)["slot"] as RosterSlot).unit_data
		var offset: Vector2 = _coord_mapper.sub_cell_offset(k, count, cs)
		var y_comp: float = ud.sprite_scale * TOKEN_SCALE_SOLO * 18.0
		holder.add_child(_make_field_token(ud, Vector2(offset.x, offset.y + y_comp), false))
	return holder

func _can_drop_hand_card_to_cell(slot_idx: int, cell_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return false
	if _card_to_cell[slot_idx] != -1:
		return false
	var slot: RosterSlot = RunState.hand[slot_idx]
	if slot.kind == GameEnums.CardKind.HERO:
		return true  # 영웅은 어느 셀에나 드롭 가능 (동종 체크는 place_requested에서 처리)
	if slot.kind == GameEnums.CardKind.ITEM:
		return false  # 아이템은 ItemDropZone으로만 드롭
	if slot.kind == GameEnums.CardKind.UPGRADE:
		return _cell_has_unit(cell_idx) and RunState.grid_get_upgrade(cell_idx) < RunState.MAX_UPGRADE_LEVEL
	return _cell_has_unit(cell_idx)  # 비-영웅은 유닛이 있는 셀에만

func _apply_dummy_card_to_cell(slot_idx: int, slot: RosterSlot, cell_idx: int) -> void:
	if not _cell_has_unit(cell_idx):
		return
	if slot.kind == GameEnums.CardKind.UPGRADE and RunState.grid_get_upgrade(cell_idx) >= RunState.MAX_UPGRADE_LEVEL:
		return
	var paid: bool
	if slot.kind == GameEnums.CardKind.ITEM and slot.item_data != null:
		paid = RunState.buy_item(slot.item_data)
	else:
		paid = RunState.spend(slot.dummy_price)
	if not paid:
		return
	if slot.kind == GameEnums.CardKind.UPGRADE:
		RunState.grid_add_boost(cell_idx, slot.upgrade_stat)
		_render_placed()
	_card_to_cell[slot_idx] = -2
	if _card_info_popup != null:
		_card_info_popup.hide()
	_refresh_hand_state()
	_update_summary_and_button()
	shell.top_bar.set_gold_preview(_total_cost())
	shell.top_bar.refresh_gold()

func _spawn_hero_info_popup() -> void:
	var ml: CanvasLayer = shell.modal_layer
	_hero_info_popup = HERO_INFO_POPUP_SCENE.instantiate() as HeroInfoPopup
	ml.add_child(_hero_info_popup)
	_hero_info_popup.close_requested.connect(_on_hero_info_popup_close)

func _spawn_card_info_popup() -> void:
	var ml: CanvasLayer = shell.modal_layer
	_card_info_popup = CardInfoPopupScript.new() as CardInfoPopup
	ml.add_child(_card_info_popup)
	_card_info_popup.close_requested.connect(_on_card_info_popup_close)

func _on_cell_clicked(cell_idx: int) -> void:
	if cell_idx < 0 or cell_idx >= GRID_CELLS:
		return
	var entries: Array = RunState.grid_cells[cell_idx]
	if entries.is_empty():
		_selected_cell = -1
		_selected_hand_idx = -1
		_refresh_hand_state()
		if _hero_info_popup != null:
			_hero_info_popup.hide()
		return
	# 카드 팝업이 열려 있으면 닫는다.
	if _card_info_popup != null:
		_card_info_popup.hide()
	_selected_cell = cell_idx
	# 해당 셀의 unpaid entry 중 유효한 hand_idx를 찾아 카드에 주황 테두리를 준다.
	_selected_hand_idx = -1
	var n: int = RunState.hand.size()
	for entry in entries:
		var d: Dictionary = entry as Dictionary
		if bool(d.get("paid", false)):
			continue
		var hidx: int = int(d.get("hand_idx", -1))
		if hidx >= 0 and hidx < n and RunState.hand[hidx] == d["slot"]:
			_selected_hand_idx = hidx
			break
	_refresh_hand_state()
	var slot: RosterSlot = (entries[0] as Dictionary)["slot"] as RosterSlot
	if _hero_info_popup != null:
		_hero_info_popup.show_for(slot, RunState.grid_get_boosts(cell_idx), RunState.inventory)

func _on_hero_info_popup_close() -> void:
	_selected_cell = -1
	_selected_hand_idx = -1
	_refresh_hand_state()
	if _hero_info_popup != null:
		_hero_info_popup.hide()

func _on_card_info_popup_close() -> void:
	_selected_hand_idx = -1
	_refresh_hand_state()
	if _card_info_popup != null:
		_card_info_popup.hide()

func _update_summary_and_button() -> void:
	var deployed: int = _total_count()
	var spent: int = _total_cost()
	var new_count: int = RunState.grid_unpaid_count()
	if new_count > 0:
		_summary_lbl.text = "출전: %d명 (신규 +%d) / 비용 %d g" % [deployed, new_count, spent]
	else:
		_summary_lbl.text = "출전: %d명 / 비용 %d g" % [deployed, spent]
	_start_battle_btn.disabled = deployed == 0 or spent > RunState.gold

# ─── PREP → BATTLE ────────────────────────────────────────────────────────
func _on_start_battle() -> void:
	var spent: int = _total_cost()
	if spent > RunState.gold or _total_count() == 0:
		return
	RunState.spend(spent)
	# 신규 배치분을 영구 자산으로 확정. 다음 라운드 PREP 진입 시 재차감 없이 보존된다.
	RunState.grid_commit_paid()

	# 셀당 같은 유닛 타입만 담기므로 첫 인덱스를 대표로 plan 한 entry 생성.
	# 전투 시작 좌표는 prep PlayerZone 토큰의 글로벌 좌표를 그대로 사용한다.
	var pz_origin: Vector2 = (shell.player_zone as Control).global_position
	var plan: Array = []
	for i in GRID_CELLS:
		var entries: Array = RunState.grid_cells[i]
		if entries.is_empty():
			continue
		var count: int = entries.size()
		var center: Vector2 = _coord_mapper.cell_center(i)
		var cs: Vector2 = _coord_mapper.cell_size()
		var positions: Array = []
		# 전투 시작 좌표를 PREP의 사분면 위치와 일치시킨다 — 플레이어가 본 그대로 출전.
		for k in count:
			var offset: Vector2 = _coord_mapper.sub_cell_offset(k, count, cs)
			positions.append(pz_origin + center + offset)
		plan.append({
			"slot": (entries[0] as Dictionary)["slot"],
			"positions": positions,
			"boosts": RunState.grid_get_boosts(i),
		})
	# BattlePlan DTO를 만들어 단방향 전달. RunState 글로벌 mutate 없음.
	var battle_plan := BattlePlan.new()
	battle_plan.player_units = plan
	battle_plan.enemy_lineup = RunState.current_enemy_lineup()
	battle_plan.enemy_positions = _collect_enemy_positions()
	battle_plan.round_index = RunState.current_round
	battle_plan.tactic_key = RunState.current_tactic_key()
	battle_plan.global_items = RunState.inventory.duplicate()
	transition_requested.emit(ARENA_ROOT.PhaseId.BATTLE, battle_plan)

# 진형 좌표를 그대로 전투 시작 좌표로 사용한다 (프리뷰와 일치).
func _collect_enemy_positions() -> Array:
	var ez: Control = shell.enemy_zone
	var lineup: Array = RunState.current_enemy_lineup()
	var n: int = lineup.size()
	if n == 0 or ez == null:
		return []
	var origin: Vector2 = ez.global_position
	var zone_w: float = ez.size.x if ez.size.x > 0.0 else 360.0
	var zone_h: float = ez.size.y if ez.size.y > 0.0 else 360.0
	var tactic_key: StringName = RunState.current_tactic_key()
	var field_h: float = zone_h - _TACTIC_LABEL_H
	var positions: Array = FormationLibrary.positions_for(tactic_key, n, zone_w, field_h)
	var out: Array = []
	for pos in positions:
		out.append(origin + pos + Vector2(0.0, _TACTIC_LABEL_H))
	return out

func _prep_to_battle_pos(prep_pos: Vector2) -> Vector2:
	var zone_size: Vector2 = (shell.player_zone as Control).size
	if zone_size.x <= 0.0 or zone_size.y <= 0.0:
		return Vector2(BATTLE_PLAYER_X_MIN, BATTLE_Y_MIN)
	var tx: float = clampf(prep_pos.x / zone_size.x, 0.0, 1.0)
	var ty: float = clampf(prep_pos.y / zone_size.y, 0.0, 1.0)
	var bx: float = lerpf(BATTLE_PLAYER_X_MIN, BATTLE_PLAYER_X_MAX, tx)
	var by: float = lerpf(BATTLE_Y_MIN, BATTLE_Y_MAX, ty)
	return Vector2(bx, by)

# ─── Helpers ──────────────────────────────────────────────────────────────
# 비용은 이번 라운드 미결제(unpaid) 병사 합. paid 영구 자산은 재차감 없음.
func _total_cost() -> int:
	return RunState.grid_unpaid_cost()

# 출전 인원수는 paid + unpaid 전부 (영구 군대도 매 라운드 출전).
func _total_count() -> int:
	return RunState.grid_total_count()

func _gold_remaining() -> int:
	return RunState.gold - _total_cost()

# ─── Item Slot ────────────────────────────────────────────────────────────
func _build_item_slot() -> void:
	if not shell.has("item_slot"):
		return
	_render_item_slot()

func _render_item_slot() -> void:
	var slot: Control = shell.item_slot
	ItemInventoryView.render(slot, RunState.inventory)
	_item_drop_zone = ItemDropZone.new()
	_item_drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	_item_drop_zone.can_drop_item = Callable(self, "_can_drop_item_card")
	_item_drop_zone.item_dropped.connect(_on_item_dropped)
	slot.add_child(_item_drop_zone)

func _can_drop_item_card(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return false
	if _card_to_cell[slot_idx] != -1:
		return false
	var slot: RosterSlot = RunState.hand[slot_idx]
	return slot.kind == GameEnums.CardKind.ITEM and slot.item_data != null

func _on_item_dropped(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= RunState.hand.size():
		return
	if _card_to_cell[slot_idx] != -1:
		return
	var slot: RosterSlot = RunState.hand[slot_idx]
	if slot.kind != GameEnums.CardKind.ITEM or slot.item_data == null:
		return
	if not RunState.buy_item(slot.item_data):
		return
	_card_to_cell[slot_idx] = -2
	if _card_info_popup != null:
		_card_info_popup.hide()
	_render_item_slot()
	_refresh_hand_state()
	_update_summary_and_button()
	shell.top_bar.set_gold_preview(_total_cost())
	shell.top_bar.refresh_gold()
