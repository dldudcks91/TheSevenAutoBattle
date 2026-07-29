extends Control

# SHOP phase: 골드 상점 (전투 밖 편성). 카드 구매 · 카드 제거 · 조커 획득/교체 · 이자 미리보기.
# 배치는 하지 않는다 (그건 PREP). "다음 라운드" 로 PREP 진입.
# 상점 구조(라인업 갱신·리롤·카드 제거 비용)는 GAME_DESIGN §12 미결 — 임시 규칙으로 "빠르게" 구현.

const ARENA_ROOT := preload("res://src/ui/arena_root.gd")

signal transition_requested(next: int, payload: Variant)
signal main_menu_requested

var shell: Dictionary = {}
var _card_offers: Array[Card] = []
var _joker_offers: Array[Joker] = []
var _root: VBoxContainer = null

func bind_shell(s: Dictionary) -> void:
	shell = s

func _ready() -> void:
	_card_offers = CardCatalog.random_offers(RunState.rng, 4)
	_joker_offers = JokerCatalog.random_offers(RunState.rng, 2)
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 14)
	_root.offset_left = 40
	_root.offset_top = 20
	scroll.add_child(_root)

	_add_header()
	_add_section("카드 상점 — 덱에 추가", _build_card_offers())
	_add_section("조커 — 획득 / 교체", _build_joker_offers())
	_add_section("보유 조커 (%d / %d)" % [RunState.jokers.size(), RunState.joker_store.slot_count], _build_owned_jokers())
	_add_section("내 덱 (%d장) — 제거 -%dg" % [RunState.deck.size(), CardCatalog.remove_price()], _build_deck_list())
	_add_footer()

func _refresh() -> void:
	_build()

# ─── Header ───────────────────────────────────────────────────────────────
func _add_header() -> void:
	var title := Label.new()
	title.text = "상점 (편성)"
	title.add_theme_font_size_override("font_size", 40)
	_root.add_child(title)

	var gold := Label.new()
	gold.text = "보유 골드 %d g   ·   아끼면 다음 클리어 이자 +%d" % [RunState.gold, RunState.interest_amount()]
	gold.add_theme_font_size_override("font_size", 20)
	gold.theme_type_variation = &"LabelGold"
	_root.add_child(gold)

func _add_section(header: String, body: Control) -> void:
	var h := Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	_root.add_child(h)
	_root.add_child(body)

# ─── Card offers ──────────────────────────────────────────────────────────
func _build_card_offers() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if _card_offers.is_empty():
		row.add_child(_muted("(품절)"))
		return row
	for i in _card_offers.size():
		var c: Card = _card_offers[i]
		var price := CardCatalog.gold_price(c)
		var btn := _offer_button("%s\n코스트 %d · %d g" % [_card_name(c), c.cost, price], RunState.gold >= price)
		btn.pressed.connect(_on_buy_card.bind(i))
		row.add_child(btn)
	return row

func _on_buy_card(i: int) -> void:
	if i < 0 or i >= _card_offers.size():
		return
	var c: Card = _card_offers[i]
	var price := CardCatalog.gold_price(c)
	if not RunState.spend(price):
		return
	RunState.add_card(c)
	_card_offers.remove_at(i)
	_refresh()

# ─── Joker offers ─────────────────────────────────────────────────────────
func _build_joker_offers() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if _joker_offers.is_empty():
		row.add_child(_muted("(품절)"))
		return row
	var price := JokerCatalog.gold_price()
	for i in _joker_offers.size():
		var j: Joker = _joker_offers[i]
		var label := "%s\n%s\n%d g%s" % [
			_joker_name(j), j.desc_key, price,
			"  (슬롯 만차 → 슬롯1 교체)" if RunState.jokers_full() else ""
		]
		var btn := _offer_button(label, RunState.gold >= price)
		btn.pressed.connect(_on_buy_joker.bind(i))
		row.add_child(btn)
	return row

func _on_buy_joker(i: int) -> void:
	if i < 0 or i >= _joker_offers.size():
		return
	var j: Joker = _joker_offers[i]
	if not RunState.spend(JokerCatalog.gold_price()):
		return
	if RunState.jokers_full():
		# 커밋 압박의 실체 — "빠르게"에선 슬롯1을 자동 교체. (교체 대상 선택 UI는 후속)
		RunState.replace_joker(0, j)
	else:
		RunState.add_joker(j)
	_joker_offers.remove_at(i)
	_refresh()

func _build_owned_jokers() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if RunState.jokers.is_empty():
		row.add_child(_muted("(없음)"))
		return row
	for j in RunState.jokers:
		var jk := j as Joker
		var card := PanelContainer.new()
		var v := VBoxContainer.new()
		card.add_child(v)
		var n := Label.new()
		n.text = _joker_name(jk)
		n.add_theme_font_size_override("font_size", 16)
		v.add_child(n)
		var d := Label.new()
		d.text = jk.desc_key
		d.add_theme_font_size_override("font_size", 12)
		d.modulate = Color(1, 1, 1, 0.7)
		v.add_child(d)
		row.add_child(card)
	return row

# ─── Deck list ────────────────────────────────────────────────────────────
func _build_deck_list() -> Control:
	var wrap := HFlowContainer.new()
	wrap.add_theme_constant_override("h_separation", 8)
	wrap.add_theme_constant_override("v_separation", 8)
	var remove_cost := CardCatalog.remove_price()
	for i in RunState.deck.size():
		var c: Card = RunState.deck[i]
		var btn := Button.new()
		btn.text = "%s (c%d) ✕" % [_card_name(c), c.cost]
		btn.tooltip_text = "덱에서 제거 (-%d g)" % remove_cost
		btn.disabled = RunState.gold < remove_cost or RunState.deck.size() <= 1
		btn.pressed.connect(_on_remove_card.bind(c))
		wrap.add_child(btn)
	return wrap

func _on_remove_card(c: Card) -> void:
	if RunState.deck.size() <= 1:
		return
	if not RunState.spend(CardCatalog.remove_price()):
		return
	RunState.remove_card(c)
	_refresh()

# ─── Footer ───────────────────────────────────────────────────────────────
func _add_footer() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_root.add_child(row)

	var menu := Button.new()
	menu.text = "메인 메뉴"
	menu.custom_minimum_size = Vector2(160, 52)
	menu.pressed.connect(func(): main_menu_requested.emit())
	row.add_child(menu)

	var next := Button.new()
	next.text = "다음 라운드 →"
	next.custom_minimum_size = Vector2(240, 56)
	next.add_theme_font_size_override("font_size", 24)
	next.pressed.connect(func(): transition_requested.emit(ARENA_ROOT.PhaseId.PREP, null))
	row.add_child(next)

# ─── Small helpers ────────────────────────────────────────────────────────
func _offer_button(text: String, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(170, 84)
	btn.disabled = not enabled
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.5)
	return l

func _card_name(c: Card) -> String:
	if c.is_soldier() and c.unit_data != null:
		return tr(c.unit_data.name_key)
	return tr(c.name_key) if c.name_key != "" else String(c.id)

func _joker_name(j: Joker) -> String:
	return tr(j.name_key) if j.name_key != "" else String(j.id)
