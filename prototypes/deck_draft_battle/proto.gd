# PROTOTYPE - NOT FOR PRODUCTION
# Question: 내가 꾸린 덱에서 핸드를 뽑아 N장(병사+강화)을 배분해 내는 결정 루프가 재밌는가?
#           특히 "병사1+강화4 슈퍼유닛" vs "병사 물량" 선택에 손맛/깊이가 있는가?
# Date: 2026-07-21
#
# 구조: 전투 전 1회 배치 (핸드 → N장 배분 → 오토배틀 1회 해결)
# 실행: 이 씬(proto.tscn)을 열고 F6 (현재 씬 실행)
extends Node2D

const PROTO_UNIT := preload("res://prototypes/deck_draft_battle/proto_unit.gd")

# ── 튜닝값 (대충) ─────────────────────────────
const HAND_SIZE: int = 7
const PLAYS: int = 5
const BATTLE_SPEED: float = 1.6
const BATTLE_TIMEOUT: float = 55.0

const U_ATK: float = 6.0
const U_HP: float = 70.0
const U_DEF: float = 2.0
const U_ASPD: float = 0.5

const PLAYER_X: float = 360.0
const ENEMY_X: float = 1560.0
const FIELD_TOP: float = 200.0
const FIELD_BOT: float = 900.0

enum St { DRAFT, BATTLE, RESULT, DECKEDIT }

var state: int = St.DRAFT
var deck: Array = []
var hand: Array = []
var deployed: Array = []          # {n_atk,n_hp,n_def,n_as}
var selected_idx: int = -1
var plays_left: int = 0
var wave: int = 0

var player_units: Array = []
var enemy_units: Array = []
var battle_time: float = 0.0

var ui: Control

# ── 카드 헬퍼 ─────────────────────────────
func _card(kind: String, stat: String = "") -> Dictionary:
	var lbl := ""
	match kind:
		"soldier": lbl = "⚔ 병사"
		"upgrade":
			match stat:
				"atk": lbl = "＋공격"
				"hp": lbl = "＋체력"
				"def": lbl = "＋방어"
				"aspd": lbl = "＋공속"
	return {"kind": kind, "stat": stat, "label": lbl}

func _start_deck() -> Array:
	var d: Array = []
	for i in 5: d.append(_card("soldier"))
	for i in 2: d.append(_card("upgrade", "atk"))
	for i in 2: d.append(_card("upgrade", "hp"))
	d.append(_card("upgrade", "def"))
	d.append(_card("upgrade", "aspd"))
	return d

func _eff(dep: Dictionary) -> Dictionary:
	return {
		"atk": 10.0 + U_ATK * dep.n_atk,
		"hp": 100.0 + U_HP * dep.n_hp,
		"def": 1.0 + U_DEF * dep.n_def,
		"aspd": 1.0 + U_ASPD * dep.n_aspd,
	}

# ── 초기화 ─────────────────────────────
func _ready() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(ui)
	deck = _start_deck()
	wave = 0
	_enter_draft()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.10, 0.11, 0.14))
	draw_line(Vector2(960, FIELD_TOP - 40), Vector2(960, FIELD_BOT + 40), Color(1, 1, 1, 0.08), 2.0)

# ══════════════════════════════════════════
# DRAFT
# ══════════════════════════════════════════
func _enter_draft() -> void:
	state = St.DRAFT
	_clear_battle()
	deployed.clear()
	selected_idx = -1
	plays_left = PLAYS
	var pool: Array = deck.duplicate()
	pool.shuffle()
	hand = pool.slice(0, HAND_SIZE)
	_build_draft_ui()

func _build_draft_ui() -> void:
	_clear_ui()
	_title("웨이브 %d  —  카드 %d장 배분 (남은 플레이 %d)" % [wave + 1, PLAYS, plays_left])

	var wv := _wave_spec(wave)
	_label("적: %s ×%d  (공%d 체%d)" % [wv.name, wv.count, int(wv.atk), int(wv.hp)],
		1250, 150, Color(0.95, 0.6, 0.55), 22)

	_label("배치한 병사 (클릭해서 선택 → 강화 부여)", 360, 250, Color(0.8, 0.85, 0.95), 20)
	var tx := 360.0
	for i in deployed.size():
		var e := _eff(deployed[i])
		var b := _btn("⚔%d\n♥%d\n방%d 속%.1f" % [int(e.atk), int(e.hp), int(e.def), e.aspd],
			tx, 285, 130, 92)
		if i == selected_idx:
			b.modulate = Color(1.0, 1.0, 0.5)
		b.pressed.connect(_on_select_token.bind(i))
		tx += 142.0

	_label("핸드", 360, 760, Color(0.8, 0.85, 0.95), 20)
	var hx := 360.0
	for i in hand.size():
		var c: Dictionary = hand[i]
		var col := Color(0.35, 0.5, 0.75) if c.kind == "soldier" else Color(0.55, 0.4, 0.65)
		var b := _btn(c.label, hx, 795, 150, 110, col)
		if plays_left <= 0:
			b.disabled = true
		b.pressed.connect(_play_card.bind(i))
		hx += 162.0

	var go := _btn("전투 시작 ▶", 1560, 800, 260, 96, Color(0.25, 0.6, 0.35))
	go.pressed.connect(_start_battle)

func _on_select_token(idx: int) -> void:
	selected_idx = idx
	_build_draft_ui()

func _play_card(i: int) -> void:
	if plays_left <= 0 or i >= hand.size():
		return
	var c: Dictionary = hand[i]
	if c.kind == "soldier":
		deployed.append({"n_atk": 0, "n_hp": 0, "n_def": 0, "n_aspd": 0})
		selected_idx = deployed.size() - 1
	else:
		if selected_idx < 0:
			_toast("먼저 병사를 낸 뒤 강화를 부여하세요")
			return
		var dep: Dictionary = deployed[selected_idx]
		match c.stat:
			"atk": dep.n_atk += 1
			"hp": dep.n_hp += 1
			"def": dep.n_def += 1
			"aspd": dep.n_aspd += 1
	hand.remove_at(i)
	plays_left -= 1
	_build_draft_ui()

# ══════════════════════════════════════════
# BATTLE
# ══════════════════════════════════════════
func _start_battle() -> void:
	if deployed.is_empty():
		_toast("병사를 최소 1기 배치하세요")
		return
	_clear_ui()
	_clear_battle()
	state = St.BATTLE
	battle_time = 0.0

	var pspecs: Array = []
	for d in deployed:
		pspecs.append(_player_stats(d))
	_spawn_column(pspecs, 0, PLAYER_X, player_units)

	var wv := _wave_spec(wave)
	var elist: Array = []
	for i in wv.count:
		elist.append({"hp": wv.hp, "atk": wv.atk, "def": wv.def, "aspd": wv.aspd})
	_spawn_column(elist, 1, ENEMY_X, enemy_units)

func _player_stats(dep: Dictionary) -> Dictionary:
	var e := _eff(dep)
	return {"hp": e.hp, "atk": e.atk, "def": e.def, "aspd": e.aspd,
		"n_atk": dep.n_atk, "n_hp": dep.n_hp, "n_def": dep.n_def, "n_aspd": dep.n_aspd}

func _spawn_column(specs: Array, team: int, x: float, arr: Array) -> void:
	var n := specs.size()
	var span := FIELD_BOT - FIELD_TOP
	for i in n:
		var s: Dictionary = specs[i]
		var u := PROTO_UNIT.new()
		u.team = team
		u.max_hp = s.hp
		u.atk = s.atk
		u.defense = s.def
		u.atk_speed = s.aspd
		u.n_atk = s.get("n_atk", 0)
		u.n_hp = s.get("n_hp", 0)
		u.n_def = s.get("n_def", 0)
		u.n_as = s.get("n_aspd", 0)
		u.setup()
		var t := (float(i) + 0.5) / float(n)
		u.position = Vector2(x + randf_range(-30, 30), FIELD_TOP + span * t)
		add_child(u)
		arr.append(u)

func _process(delta: float) -> void:
	if state != St.BATTLE:
		return
	var t: float = minf(delta, 0.033) * BATTLE_SPEED
	for u in player_units:
		if u.is_alive(): u.step(t, enemy_units)
	for u in enemy_units:
		if u.is_alive(): u.step(t, player_units)
	_separate(player_units)
	_separate(enemy_units)
	_cull(player_units)
	_cull(enemy_units)
	battle_time += t
	if enemy_units.is_empty() or player_units.is_empty() or battle_time > BATTLE_TIMEOUT:
		var win := not player_units.is_empty() and enemy_units.is_empty()
		_end_battle(win)

func _separate(arr: Array) -> void:
	for i in arr.size():
		var a = arr[i]
		if not a.is_alive(): continue
		for j in range(i + 1, arr.size()):
			var b = arr[j]
			if not b.is_alive(): continue
			var d: Vector2 = a.position - b.position
			var dist: float = d.length()
			var mind: float = a.radius + b.radius
			if dist < mind and dist > 0.01:
				var push: Vector2 = d.normalized() * (mind - dist) * 0.5
				a.position += push
				b.position -= push

func _cull(arr: Array) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if not arr[i].is_alive():
			arr[i].queue_free()
			arr.remove_at(i)

# ══════════════════════════════════════════
# RESULT → DECK EDIT
# ══════════════════════════════════════════
func _end_battle(win: bool) -> void:
	state = St.RESULT
	_clear_ui()
	if win:
		_title("승리! ✔  (남은 병사 %d기)" % player_units.size())
		wave += 1
		var b := _btn("덱 편집 ▶", 810, 560, 300, 100, Color(0.25, 0.55, 0.7))
		b.pressed.connect(_enter_deckedit)
	else:
		_title("패배 ✘  — 런 재시작")
		var b := _btn("처음부터", 810, 560, 300, 100, Color(0.6, 0.3, 0.3))
		b.pressed.connect(_on_restart)

func _on_restart() -> void:
	deck = _start_deck()
	wave = 0
	_enter_draft()

func _enter_deckedit() -> void:
	state = St.DECKEDIT
	_clear_battle()
	_build_deckedit_ui()

func _build_deckedit_ui() -> void:
	_clear_ui()
	_title("덱 편집  —  현재 %d장" % deck.size())

	var counts := {"soldier": 0, "atk": 0, "hp": 0, "def": 0, "aspd": 0}
	for c in deck:
		if c.kind == "soldier": counts.soldier += 1
		else: counts[c.stat] += 1
	_label("병사 %d  ｜  ＋공%d  ＋체%d  ＋방%d  ＋속%d" %
		[counts.soldier, counts.atk, counts.hp, counts.def, counts.aspd],
		360, 250, Color(0.85, 0.9, 1.0), 24)

	_label("카드 1장 추가 (선택 시 다음 전투로)", 360, 340, Color(0.8, 0.95, 0.8), 20)
	var offers := [_card("soldier"), _random_upgrade(), _random_upgrade()]
	var ox := 360.0
	for c in offers:
		var col := Color(0.35, 0.5, 0.75) if c.kind == "soldier" else Color(0.55, 0.4, 0.65)
		var b := _btn("＋ " + c.label, ox, 380, 170, 100, col)
		b.pressed.connect(_on_add_offer.bind(c))
		ox += 185.0

	var skip := _btn("추가 없이 다음 전투 ▶", 360, 520, 320, 80, Color(0.4, 0.4, 0.45))
	skip.pressed.connect(_enter_draft)

func _on_add_offer(card: Dictionary) -> void:
	deck.append(card)
	_enter_draft()

func _random_upgrade() -> Dictionary:
	var stats := ["atk", "hp", "def", "aspd"]
	return _card("upgrade", stats[randi() % stats.size()])

# ── 웨이브 정의 (대충 증가) ─────────────────────
func _wave_spec(w: int) -> Dictionary:
	var tiers := [
		{"name": "오크", "count": 3, "hp": 100.0, "atk": 9.0, "def": 1.0, "aspd": 1.0},
		{"name": "오크", "count": 5, "hp": 110.0, "atk": 10.0, "def": 1.0, "aspd": 1.0},
		{"name": "오크", "count": 7, "hp": 120.0, "atk": 11.0, "def": 2.0, "aspd": 1.0},
		{"name": "정예오크", "count": 6, "hp": 190.0, "atk": 14.0, "def": 3.0, "aspd": 1.1},
		{"name": "군단", "count": 10, "hp": 140.0, "atk": 12.0, "def": 2.0, "aspd": 1.1},
	]
	return tiers[mini(w, tiers.size() - 1)]

# ══════════════════════════════════════════
# UI 헬퍼
# ══════════════════════════════════════════
func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()

func _clear_battle() -> void:
	for u in player_units:
		if is_instance_valid(u): u.queue_free()
	for u in enemy_units:
		if is_instance_valid(u): u.queue_free()
	player_units.clear()
	enemy_units.clear()

func _title(t: String) -> void:
	_label(t, 360, 90, Color.WHITE, 34)

func _label(t: String, x: float, y: float, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.position = Vector2(x, y)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	ui.add_child(l)
	return l

func _btn(t: String, x: float, y: float, w: float, h: float, col: Color = Color(0.3, 0.35, 0.45)) -> Button:
	var b := Button.new()
	b.text = t
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	ui.add_child(b)
	return b

func _toast(msg: String) -> void:
	var l := _label(msg, 700, 700, Color(1, 0.8, 0.4), 26)
	get_tree().create_timer(1.5).timeout.connect(_free_node.bind(l))

func _free_node(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
