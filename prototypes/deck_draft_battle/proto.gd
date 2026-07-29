# PROTOTYPE - NOT FOR PRODUCTION
# Question: (1) 코스트 예산 배낭 퍼즐이 재밌는가
#           (2) 이중 제약(예산 상한 + 9칸 상한)이 몰빵/물량 선택을 살리는가
#           (3) 조커 엔진이 "폭주"를 만드는가
#           (4) 조커 매개 6종 중 무엇이 살아남는가
#           (5) "버리기"가 상점 리롤보다 나은 손맛인가
# Date: 2026-07-29
#
# 스펙: prototypes/deck_draft_battle/PROTO_V2_SPEC.md
# 실행: 이 씬(proto.tscn)을 열고 F6
extends Node2D

const PROTO_UNIT := preload("res://prototypes/deck_draft_battle/proto_unit.gd")
const DATA := preload("res://prototypes/deck_draft_battle/proto_data.gd")

# ── 튜닝값 (전부 여기) ─────────────────────────────────────
const GRID_COLS: int = 3
const GRID_ROWS: int = 3
const GRID_SIZE: int = 9

const BUDGET_BASE: int = 8
const BUDGET_PER_WAVE: int = 2
const HAND_SIZE: int = 7
const DISCARDS: int = 2
const JOKER_SLOTS_START: int = 2
const JOKER_SLOTS_MAX: int = 5

const GOLD_START: int = 4
const GOLD_PER_WIN: int = 4
const GOLD_WAVE_BONUS: int = 1
const INTEREST_PER: int = 5         # 이자: 보유 골드 이만큼당 +1 (DESIGN_NOTES §9)
const INTEREST_MAX: int = 5
const PRICE_ADD_EXTRA: int = 2      # 카드 구매가 = 카드 코스트 + 이 값
const PRICE_REMOVE: int = 3
const PRICE_SLOT: int = 8           # 조커 슬롯 확장

const BATTLE_SPEED: float = 1.5
const BATTLE_TIMEOUT: float = 60.0
const SUMMON_CARD: String = "militia"

# 전장 좌표
const P_COL_X: float = 320.0        # 후열 x
const P_COL_GAP: float = 150.0      # 열 간격 (col 2 = 전열, 적과 가까움)
const E_COL_X: float = 1620.0
const E_COL_GAP: float = -140.0
const ROW_Y: float = 300.0
const ROW_GAP: float = 230.0

# 준비화면 그리드 UI
const CELL_W: float = 150.0
const CELL_H: float = 132.0
const CELL_GAP: float = 8.0
const GRID_X: float = 40.0
const GRID_Y: float = 195.0

enum St { PREP, BATTLE, RESULT, JOKERPICK, DECKEDIT }

# ── 런 상태 ───────────────────────────────────────────────
var state: int = St.PREP
var wave: int = 0
var gold: int = GOLD_START
var collection: Array = []          # 영구 덱 (카드 id 배열)
var jokers: Array = []              # 장착 조커 id
var joker_slots: int = JOKER_SLOTS_START
var joker_pool_left: Array = []

# ── 준비 단계 상태 ─────────────────────────────────────────
var pool: Array = []                # 이번 준비의 남은 덱
var hand: Array = []
var discard_pile: Array = []
var grid: Array = []                # GRID_SIZE 칸. null 또는 {card,paid,buffs:[{card,paid}]}
var played_free: Array = []         # 주문/오라/조건발동 {card,paid}
var budget_total: int = 0
var budget_left: int = 0
var discards_left: int = 0
var sel_card: int = -1
var discard_mode: bool = false
var marks: Dictionary = {}
var vanguard_cell: int = -1         # 선봉 무료를 소비한 칸

# ── 전투 상태 ─────────────────────────────────────────────
var player_units: Array = []
var enemy_units: Array = []
var battle_time: float = 0.0
var speed_mult: float = 1.0
var momentum: float = 0.0
var momentum_total: float = 0.0
var mom_rage_steps: int = 0
var ally_deaths: int = 0
var enemy_deaths: int = 0
var enemy_start_count: int = 0
var traps_armed: Array = []         # {card, fired}
var battle_log: Array = []
var gold_earned_in_battle: int = 0

var ui: Control
var hud_info: Label
var hud_mom: Label
var hud_log: Label

# ══════════════════════════════════════════════════════════
func _ready() -> void:
	randomize()
	var cl := CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(ui)
	_new_run()

func _new_run() -> void:
	collection = DATA.start_deck()
	jokers.clear()
	joker_slots = JOKER_SLOTS_START
	joker_pool_left = DATA.jokers().keys()
	joker_pool_left.shuffle()
	gold = GOLD_START
	wave = 0
	_enter_prep()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.10, 0.11, 0.14))
	if state == St.BATTLE:
		draw_line(Vector2(960, 160), Vector2(960, 960), Color(1, 1, 1, 0.07), 2.0)

# ══════════════════════════════════════════════════════════
# 준비 단계
# ══════════════════════════════════════════════════════════
func _enter_prep() -> void:
	state = St.PREP
	_clear_battle()
	grid.clear()
	for i in GRID_SIZE:
		grid.append(null)
	played_free.clear()
	sel_card = -1
	discard_mode = false
	marks.clear()
	vanguard_cell = -1
	discards_left = DISCARDS
	budget_total = BUDGET_BASE + wave * BUDGET_PER_WAVE
	if jokers.has("j_supply"):
		budget_total += int(DATA.joker("j_supply").amt)
	budget_left = budget_total

	pool = collection.duplicate()
	pool.shuffle()
	discard_pile.clear()
	hand.clear()
	_draw_cards(HAND_SIZE)
	_build_prep_ui()

func _draw_cards(n: int) -> void:
	for i in n:
		if pool.is_empty():
			if discard_pile.is_empty():
				return
			pool = discard_pile.duplicate()
			discard_pile.clear()
			pool.shuffle()
		hand.append(pool.pop_back())

# 조커 보정이 반영된 실제 코스트
func _cost_of(cid: String, for_cell: int = -1) -> int:
	var c: Dictionary = DATA.card(cid)
	var cost: int = int(c.cost)
	if c.kind == "soldier":
		if jokers.has("j_levy") and c.race == "HUMANS":
			cost -= int(DATA.joker("j_levy").amt)
		if jokers.has("j_vanguard") and (vanguard_cell < 0 or vanguard_cell == for_cell):
			cost = 0
	return maxi(0, cost)

func _build_prep_ui() -> void:
	_clear_ui()
	var wv: Dictionary = DATA.wave_spec(wave)
	_title("웨이브 %d  준비" % [wave + 1])
	_label("예산 %d / %d      버리기 %d회      골드 %d      조커 %d/%d" %
		[budget_left, budget_total, discards_left, gold, jokers.size(), joker_slots],
		40, 90, Color(1.0, 0.92, 0.6), 26)

	_build_grid_ui()
	_build_joker_panel()
	_build_enemy_panel(wv)
	_build_played_panel()
	_build_hand_ui()

	var dm := _btn("버리기 모드: %s" % ["ON" if discard_mode else "OFF"], 1180, 962, 230, 66,
		Color(0.55, 0.42, 0.25) if discard_mode else Color(0.32, 0.32, 0.38))
	dm.pressed.connect(_toggle_discard_mode)
	if discard_mode:
		var doit := _btn("선택 %d장 버리고 재드로우" % marks.size(), 1420, 962, 300, 66, Color(0.6, 0.45, 0.25))
		doit.pressed.connect(_do_discard)
	else:
		var go := _btn("전투 시작 ▶", 1420, 962, 300, 66, Color(0.25, 0.6, 0.35))
		go.pressed.connect(_start_battle)

	if sel_card >= 0 and sel_card < hand.size():
		_label("선택: %s — %s" % [DATA.card(hand[sel_card]).name, _hint_for(hand[sel_card])],
			40, 745, Color(1, 0.95, 0.7), 20)
	else:
		_label("카드를 클릭해 선택 → 칸을 클릭해 배치.  배치된 칸을 (선택 없이) 클릭하면 회수·환불.",
			40, 745, Color(0.65, 0.68, 0.78), 20)

func _hint_for(cid: String) -> String:
	match DATA.card(cid).kind:
		"soldier": return "빈 칸에 배치"
		"buff": return "병사가 있는 칸에 부착 (부착 상한 없음)"
		_: return "한 번 더 클릭하면 즉시 사용"

# ── 그리드 ────────────────────────────────────────────────
func _build_grid_ui() -> void:
	_label("아군 3×3 (1칸 1유닛)", GRID_X, 150, Color(0.8, 0.85, 0.95), 22)
	var col_names := ["후열", "중열", "전열"]
	for c in GRID_COLS:
		_label(col_names[c], GRID_X + c * (CELL_W + CELL_GAP) + 46, 175, Color(0.55, 0.6, 0.7), 16)
	for i in GRID_SIZE:
		var col: int = i % GRID_COLS
		var row: int = floori(float(i) / GRID_COLS)
		var x: float = GRID_X + col * (CELL_W + CELL_GAP)
		var y: float = GRID_Y + row * (CELL_H + CELL_GAP)
		var e = grid[i]
		var txt := ""
		var bg := Color(0.18, 0.19, 0.24)
		if e == null:
			txt = "―"
		else:
			var cd: Dictionary = DATA.card(e.card)
			txt = "%s\n공%d 체%d\n강화 %d" % [cd.name, int(cd.atk), int(cd.hp), e.buffs.size()]
			bg = Color(0.24, 0.32, 0.46)
		var b := _btn(txt, x, y, CELL_W, CELL_H, bg)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_on_cell.bind(i))

func _on_cell(i: int) -> void:
	if discard_mode:
		return
	if sel_card >= 0 and sel_card < hand.size():
		_place_into(sel_card, i)
	elif grid[i] != null:
		_undo_cell(i)
	_build_prep_ui()

func _place_into(hi: int, cell_i: int) -> void:
	var cid: String = hand[hi]
	var cd: Dictionary = DATA.card(cid)
	if cd.kind == "soldier":
		if grid[cell_i] != null:
			_toast("이미 유닛이 있는 칸입니다 (1칸 1유닛)")
			return
		var cost: int = _cost_of(cid, cell_i)
		if cost > budget_left:
			_toast("예산 부족")
			return
		if jokers.has("j_vanguard") and vanguard_cell < 0:
			vanguard_cell = cell_i
		budget_left -= cost
		grid[cell_i] = {"card": cid, "paid": cost, "buffs": []}
		hand.remove_at(hi)
		sel_card = -1
	elif cd.kind == "buff":
		if grid[cell_i] == null:
			_toast("강화는 병사가 있는 칸에만")
			return
		var bcost: int = _cost_of(cid)
		if bcost > budget_left:
			_toast("예산 부족")
			return
		budget_left -= bcost
		grid[cell_i].buffs.append({"card": cid, "paid": bcost})
		hand.remove_at(hi)
		sel_card = -1
	else:
		_toast("이 카드는 칸에 놓지 않습니다 — 카드를 한 번 더 클릭")

func _undo_cell(i: int) -> void:
	var e = grid[i]
	budget_left += int(e.paid)
	hand.append(e.card)
	for b in e.buffs:
		budget_left += int(b.paid)
		hand.append(b.card)
	if vanguard_cell == i:
		vanguard_cell = -1
	grid[i] = null

# ── 핸드 ──────────────────────────────────────────────────
func _build_hand_ui() -> void:
	_label("핸드 (%d장 — 장수 제한 없음, 제한은 예산뿐)" % hand.size(), 40, 780, Color(0.8, 0.85, 0.95), 20)
	var x: float = 40.0
	for i in hand.size():
		var cid: String = hand[i]
		var cd: Dictionary = DATA.card(cid)
		var cost: int = _cost_of(cid)
		var col: Color = cd.col
		if discard_mode and marks.has(i):
			col = Color(0.75, 0.35, 0.3)
		elif i == sel_card:
			col = col.lerp(Color.WHITE, 0.35)
		elif not discard_mode and cost > budget_left:
			col = col.darkened(0.45)
		var sub := ""
		if cd.kind == "soldier":
			sub = "공%d 체%d\n%s·%s" % [int(cd.atk), int(cd.hp), cd.race, cd.cls]
		else:
			sub = str(cd.get("desc", ""))
		var b := _btn("[%d] %s\n%s" % [cost, cd.name, sub], x, 812, 158, 120, col)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_on_hand.bind(i))
		x += 166.0
		if x > 1860.0:
			break

func _on_hand(i: int) -> void:
	if discard_mode:
		if marks.has(i):
			marks.erase(i)
		else:
			marks[i] = true
		_build_prep_ui()
		return
	var cid: String = hand[i]
	var kind: String = DATA.card(cid).kind
	if kind == "spell" or kind == "aura" or kind == "trap":
		if sel_card == i:
			_play_free(i)
		else:
			sel_card = i
	else:
		sel_card = -1 if sel_card == i else i
	_build_prep_ui()

func _play_free(i: int) -> void:
	var cid: String = hand[i]
	var cost: int = _cost_of(cid)
	if cost > budget_left:
		_toast("예산 부족")
		return
	budget_left -= cost
	played_free.append({"card": cid, "paid": cost})
	hand.remove_at(i)
	sel_card = -1

func _build_played_panel() -> void:
	if played_free.is_empty():
		return
	_label("낸 카드 (클릭 회수)", GRID_X, 620, Color(0.8, 0.85, 0.95), 18)
	var x: float = GRID_X
	for i in played_free.size():
		var cd: Dictionary = DATA.card(played_free[i].card)
		var b := _btn("%s" % cd.name, x, 648, 150, 50, cd.col)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_undo_free.bind(i))
		x += 158.0

func _undo_free(i: int) -> void:
	var e = played_free[i]
	budget_left += int(e.paid)
	hand.append(e.card)
	played_free.remove_at(i)
	_build_prep_ui()

# ── 버리기 ────────────────────────────────────────────────
func _toggle_discard_mode() -> void:
	discard_mode = not discard_mode
	marks.clear()
	sel_card = -1
	_build_prep_ui()

func _do_discard() -> void:
	if discards_left <= 0:
		_toast("버리기 횟수 소진")
		return
	if marks.is_empty():
		_toast("버릴 카드를 고르세요")
		return
	var idxs: Array = marks.keys()
	idxs.sort()
	idxs.reverse()
	var n: int = idxs.size()
	for i in idxs:
		discard_pile.append(hand[i])
		hand.remove_at(i)
	_draw_cards(n)
	discards_left -= 1
	marks.clear()
	discard_mode = false
	_build_prep_ui()

# ── 우측 패널 ─────────────────────────────────────────────
func _build_joker_panel() -> void:
	_label("조커 (상시)", 560, 150, Color(0.95, 0.8, 1.0), 22)
	var y: float = 185.0
	if jokers.is_empty():
		_label("― 없음 ―", 560, y, Color(0.5, 0.52, 0.6), 18)
	for jid in jokers:
		var j: Dictionary = DATA.joker(jid)
		_label("● %s" % j.name, 560, y, Color(0.95, 0.85, 1.0), 19)
		_label("   %s" % j.desc, 560, y + 22, Color(0.68, 0.66, 0.78), 16)
		y += 54.0
	if _has_bus():
		_label("※ 기세(공용 자원) 활성 — 전투 중 표시됨", 560, y + 6, Color(0.6, 0.9, 1.0), 16)

func _build_enemy_panel(wv: Dictionary) -> void:
	_label("적 (완전 공개)", 1000, 150, Color(0.95, 0.6, 0.55), 22)
	_label("%s  ×%d   [%s]" % [wv.name, wv.count, wv.race], 1000, 185, Color(0.95, 0.75, 0.7), 20)
	_label("공 %d   체 %d   방 %d   공속 %.1f   사거리 %d" %
		[int(wv.atk), int(wv.hp), int(wv.def), wv.aspd, int(wv.rng)],
		1000, 213, Color(0.8, 0.72, 0.72), 18)
	var e_hp: float = wv.hp * wv.count
	var e_dps: float = wv.atk * wv.aspd * wv.count
	_label("합계 체력 %d   합계 DPS %d" % [int(e_hp), int(e_dps)],
		1000, 241, Color(0.72, 0.66, 0.66), 18)

	# ── 전력 지표 (DESIGN_NOTES §8: 패배=즉시 런 종료이므로 승패 예측 수단은 필수) ──
	var mine: Dictionary = _ally_power()
	_label("내 전력  (배치 %d/9)" % mine.n, 1000, 290, Color(0.7, 0.85, 1.0), 22)
	_label("합계 체력 %d   합계 DPS %d" % [int(mine.hp), int(mine.dps)],
		1000, 320, Color(0.72, 0.8, 0.9), 18)
	if mine.dps > 0.0 and e_dps > 0.0:
		var my_ttk: float = e_hp / mine.dps       # 내가 적을 지우는 데 걸리는 시간
		var his_ttk: float = mine.hp / e_dps      # 적이 나를 지우는 데 걸리는 시간
		var margin: float = his_ttk / maxf(0.01, my_ttk)
		var verdict := "판정 불가"
		var vcol := Color(0.8, 0.8, 0.8)
		if margin >= 1.6:
			verdict = "여유 (%.2f배)" % margin
			vcol = Color(0.5, 0.95, 0.6)
		elif margin >= 1.15:
			verdict = "우세 (%.2f배)" % margin
			vcol = Color(0.75, 0.95, 0.5)
		elif margin >= 0.9:
			verdict = "박빙 (%.2f배)" % margin
			vcol = Color(1.0, 0.9, 0.4)
		else:
			verdict = "열세 (%.2f배)" % margin
			vcol = Color(1.0, 0.45, 0.4)
		_label("소요 %.1fs  vs  피격 %.1fs   →   %s" % [my_ttk, his_ttk, verdict],
			1000, 348, vcol, 22)
	else:
		_label("병사를 배치하면 전력 비교가 표시됩니다", 1000, 348, Color(0.7, 0.7, 0.7), 18)
	_label("※ 방어·사거리·조커·조건발동은 지표에 반영되지 않음 (거친 근사)",
		1000, 378, Color(0.55, 0.58, 0.66), 15)

	var counts: Dictionary = {}
	for c in collection:
		counts[c] = int(counts.get(c, 0)) + 1
	var s := ""
	for cid in counts:
		s += "%s×%d  " % [DATA.card(cid).name, counts[cid]]
	_label("내 덱 %d장" % collection.size(), 1000, 420, Color(0.8, 0.85, 0.95), 20)
	var l := _label(s, 1000, 448, Color(0.6, 0.64, 0.74), 16)
	l.size = Vector2(880, 160)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# 배치된 그리드 + 오라 + 배틀스타트 조커를 반영한 거친 전력 근사
func _ally_power() -> Dictionary:
	var m_atk: float = 1.0
	var m_hp: float = 1.0
	var m_as: float = 1.0
	for p in played_free:
		var acd: Dictionary = DATA.card(p.card)
		if acd.kind != "aura":
			continue
		match acd.eff:
			"atk_mult": m_atk *= (1.0 + acd.amt)
			"hp_mult": m_hp *= (1.0 + acd.amt)
			"aspd_mult": m_as *= (1.0 + acd.amt)
	if jokers.has("j_zealot"):
		m_atk *= (1.0 + DATA.joker("j_zealot").amt)
		m_hp *= (1.0 - DATA.joker("j_zealot").pen)
	if jokers.has("j_bloodpact"):
		m_atk *= (1.0 + DATA.joker("j_bloodpact").amt)

	var thp: float = 0.0
	var tdps: float = 0.0
	var n: int = 0
	for e in grid:
		if e == null:
			continue
		n += 1
		var cd: Dictionary = DATA.card(e.card)
		var a: float = cd.atk
		var h: float = cd.hp
		var sp: float = cd.aspd
		var mh: int = 0
		var sh: float = 0.0
		for b in e.buffs:
			var bd: Dictionary = DATA.card(b.card)
			match bd.stat:
				"atk": a += bd.amt
				"hp": h += bd.amt
				"aspd": sp += bd.amt
				"multihit": mh += 1
				"shield": sh += bd.amt
		thp += h * m_hp + sh
		tdps += a * m_atk * sp * m_as * float(1 + mh)
	return {"hp": thp, "dps": tdps, "n": n}

# ══════════════════════════════════════════════════════════
# 전투
# ══════════════════════════════════════════════════════════
func _start_battle() -> void:
	var soldiers: int = 0
	for e in grid:
		if e != null:
			soldiers += 1
	if soldiers == 0:
		_toast("병사를 최소 1기 배치하세요")
		return

	_clear_ui()
	_clear_battle()
	state = St.BATTLE
	queue_redraw()
	battle_time = 0.0
	speed_mult = 1.0
	momentum = 0.0
	momentum_total = 0.0
	mom_rage_steps = 0
	ally_deaths = 0
	enemy_deaths = 0
	gold_earned_in_battle = 0
	battle_log.clear()
	traps_armed.clear()

	# 아군 스폰 (그리드 좌표 → 전장 좌표)
	for i in GRID_SIZE:
		var e = grid[i]
		if e == null:
			continue
		var col: int = i % GRID_COLS
		var row: int = floori(float(i) / GRID_COLS)
		var pos := Vector2(P_COL_X + col * P_COL_GAP, ROW_Y + row * ROW_GAP)
		var u = _spawn_unit(e.card, 0, pos, i)
		for b in e.buffs:
			u.add_buff(b.card)

	# 적 스폰
	var wv: Dictionary = DATA.wave_spec(wave)
	enemy_start_count = int(wv.count)
	for i in int(wv.count):
		var col: int = i % 3
		var row: int = floori(float(i) / 3.0)
		var pos := Vector2(E_COL_X + col * E_COL_GAP, ROW_Y - 60.0 + row * (ROW_GAP * 0.62))
		var u := PROTO_UNIT.new()
		u.host = self
		u.team = 1
		u.uname = wv.name
		u.race = wv.race
		u.base_hp = wv.hp
		u.base_atk = wv.atk
		u.base_def = wv.def
		u.base_aspd = wv.aspd
		u.atk_range = wv.rng
		u.move_speed = 90.0
		u.setup()
		u.position = pos
		add_child(u)
		enemy_units.append(u)

	_apply_auras()
	_arm_traps()
	_apply_battle_start_jokers()
	_cast_spells()
	_build_battle_hud()

func _spawn_unit(cid: String, team: int, pos: Vector2, cell_i: int, summon: bool = false):
	var cd: Dictionary = DATA.card(cid)
	var u := PROTO_UNIT.new()
	u.host = self
	u.team = team
	u.cell = cell_i
	u.uname = cd.name
	u.race = cd.race
	u.cls = cd.cls
	u.base_hp = cd.hp
	u.base_atk = cd.atk
	u.base_def = cd.def
	u.base_aspd = cd.aspd
	u.atk_range = cd.rng
	u.move_speed = cd.spd
	u.is_summon = summon
	u.setup()
	u.position = pos + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	add_child(u)
	if team == 0:
		player_units.append(u)
	else:
		enemy_units.append(u)
	if summon:
		ev("summon", {"unit": u})
	return u

func _apply_auras() -> void:
	for p in played_free:
		var cd: Dictionary = DATA.card(p.card)
		if cd.kind != "aura":
			continue
		for u in player_units:
			match cd.eff:
				"atk_mult": u.mult_atk *= (1.0 + cd.amt)
				"hp_mult": u.mult_hp *= (1.0 + cd.amt)
				"aspd_mult": u.mult_aspd *= (1.0 + cd.amt)
		_log("군단 오라: %s" % cd.name)
	for u in player_units:
		u.recompute(false)
		u.hp = u.max_hp

func _arm_traps() -> void:
	for p in played_free:
		if DATA.card(p.card).kind == "trap":
			traps_armed.append({"card": p.card, "fired": false})

func _cast_spells() -> void:
	for p in played_free:
		var cd: Dictionary = DATA.card(p.card)
		if cd.kind != "spell":
			continue
		match cd.eff:
			"dmg_all":
				for u in enemy_units.duplicate():
					u.take_damage(cd.amt, null)
			"shield_all":
				for u in player_units:
					u.shield += cd.amt
					u.shield_cap += cd.amt
			"stun_all":
				for u in enemy_units:
					u.apply_stun(cd.amt, null)
		_log("전술 주문: %s" % cd.name)

func _apply_battle_start_jokers() -> void:
	if jokers.has("j_zealot"):
		var j: Dictionary = DATA.joker("j_zealot")
		for u in player_units:
			u.mult_atk *= (1.0 + j.amt)
			u.mult_hp *= (1.0 - j.pen)
			u.recompute(false)
			u.hp = u.max_hp
		_log("광신도의 인장 — 공격 폭증, 체력 대가")
	if jokers.has("j_bloodpact"):
		var j2: Dictionary = DATA.joker("j_bloodpact")
		for u in player_units:
			u.mult_atk *= (1.0 + j2.amt)
			u.recompute()
		var alive: Array = _alive(player_units)
		if not alive.is_empty():
			var v = alive[randi() % alive.size()]
			_log("피의 계약 — %s 희생" % v.uname)
			v.take_damage(v.hp + 1.0, null)

# ── 프레임 ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state != St.BATTLE:
		return
	var t: float = minf(delta, 0.033) * BATTLE_SPEED * speed_mult
	for u in player_units:
		if is_instance_valid(u) and u.is_alive():
			u.step(t, enemy_units)
	for u in enemy_units:
		if is_instance_valid(u) and u.is_alive():
			u.step(t, player_units)
	_separate(player_units)
	_separate(enemy_units)
	_cull(player_units)
	_cull(enemy_units)
	battle_time += t
	_update_hud()
	if enemy_units.is_empty() or player_units.is_empty() or battle_time > BATTLE_TIMEOUT:
		_end_battle(not player_units.is_empty() and enemy_units.is_empty())

func _separate(arr: Array) -> void:
	for i in arr.size():
		var a = arr[i]
		if not is_instance_valid(a) or not a.is_alive():
			continue
		for j in range(i + 1, arr.size()):
			var b = arr[j]
			if not is_instance_valid(b) or not b.is_alive():
				continue
			var d: Vector2 = a.position - b.position
			var dist: float = d.length()
			var mind: float = a.radius + b.radius
			if dist < mind and dist > 0.01:
				var push: Vector2 = d.normalized() * (mind - dist) * 0.5
				a.position += push
				b.position -= push

func _cull(arr: Array) -> void:
	for i in range(arr.size() - 1, -1, -1):
		var u = arr[i]
		if not is_instance_valid(u) or not u.is_alive():
			if is_instance_valid(u):
				u.queue_free()
			arr.remove_at(i)

func _alive(arr: Array) -> Array:
	var r: Array = []
	for u in arr:
		if is_instance_valid(u) and u.is_alive():
			r.append(u)
	return r

# ══════════════════════════════════════════════════════════
# 이벤트 버스 — 조커 / 조건발동이 여기에 붙는다
# ══════════════════════════════════════════════════════════
func ev(name: String, data: Dictionary = {}) -> void:
	match name:
		"kill": _on_kill(data)
		"death": _on_death(data)
		"hit": _on_hit(data)
		"status": _on_status(data)
		"summon": _log("소환: %s" % data.unit.uname)

func _on_kill(d: Dictionary) -> void:
	var src = d.src
	var victim = d.victim
	if not is_instance_valid(src) or src.team != 0:
		return
	# ── 매개: 처치 ──
	if jokers.has("j_butcher"):
		var amt: float = DATA.joker("j_butcher").amt
		for u in _alive(player_units):
			u.bonus_atk += amt
			u.recompute()
		_log("학살자 문장 — 전군 공격 +%d" % int(amt))
	if jokers.has("j_hunt") and is_instance_valid(victim) and victim.race == DATA.joker("j_hunt").race:
		var a2: float = DATA.joker("j_hunt").amt
		for u in _alive(player_units):
			u.bonus_atk += a2
			u.recompute()
		_log("오크 사냥꾼 — 전군 공격 +%d" % int(a2))
	if jokers.has("j_feral") and src.race == DATA.joker("j_feral").race:
		src.mult_aspd *= (1.0 + DATA.joker("j_feral").amt)
		src.recompute()
		_log("야수의 광란 — %s 공속 폭증" % src.uname)
	# ── 매개: 골드 ──
	if jokers.has("j_bounty"):
		var g: int = int(DATA.joker("j_bounty").amt)
		gold += g
		gold_earned_in_battle += g
	# ── 버스 생산 ──
	if jokers.has("j_mom_kill"):
		_add_momentum(DATA.joker("j_mom_kill").amt)

func _on_death(d: Dictionary) -> void:
	var u = d.unit
	if not is_instance_valid(u):
		return
	if u.team == 1:
		enemy_deaths += 1
		_check_traps("half_enemy_dead")
		return

	ally_deaths += 1
	# ── 매개: 사망 (물량 빌드의 페이오프) ──
	if jokers.has("j_martyr"):
		var m: float = DATA.joker("j_martyr").amt
		for a in _alive(player_units):
			a.mult_aspd *= (1.0 + m)
			a.recompute()
		_log("순교자의 깃발 — 전군 공속 상승")
	# ── 매개: 소환 ──
	if jokers.has("j_wraith") and randf() < DATA.joker("j_wraith").amt:
		_spawn_unit(SUMMON_CARD, 0, u.position, -1, true)
		_log("망령 소집 — %s 자리에 망령" % u.uname)
	# ── 매개: 강화 이동 ──
	if jokers.has("j_legacy") and not u.buffs.is_empty():
		var heir = _adjacent_ally(u)
		if heir != null:
			for bid in u.buffs.duplicate():
				heir.add_buff(bid)
			u.buffs.clear()
			_log("유산 전이 — 강화 %d개가 %s에게" % [heir.buffs.size(), heir.uname])
	# ── 버스 생산 ──
	if jokers.has("j_mom_death"):
		_add_momentum(DATA.joker("j_mom_death").amt)
	# ── 조건 발동 ──
	if ally_deaths == 1:
		_check_traps("ally_death_1")
	if ally_deaths == 3:
		_check_traps("ally_death_3")

func _on_hit(d: Dictionary) -> void:
	var u = d.unit
	if not is_instance_valid(u) or u.team != 0:
		return
	if jokers.has("j_mom_hit"):
		_add_momentum(DATA.joker("j_mom_hit").amt)

func _on_status(d: Dictionary) -> void:
	var tgt = d.tgt
	if not is_instance_valid(tgt):
		return
	var src = d.src
	if src == null or not is_instance_valid(src) or src.team != 0:
		return
	if jokers.has("j_sigil"):
		var amt: float = DATA.joker("j_sigil").amt
		_log("저주의 인장 — 상태이상 대상에 %d 추가 피해" % int(amt))
		tgt.take_damage(amt, src)

# ── 기세 (공용 자원 버스) ──────────────────────────────────
func _has_bus() -> bool:
	for jid in jokers:
		if DATA.joker(jid).line == "B":
			return true
	return false

func _add_momentum(v: float) -> void:
	if not _has_bus():
		return
	momentum += v
	momentum_total += v
	_check_momentum_payoffs()

func _check_momentum_payoffs() -> void:
	if jokers.has("j_mom_rage"):
		var j: Dictionary = DATA.joker("j_mom_rage")
		while momentum_total >= float(mom_rage_steps + 1) * j.step:
			mom_rage_steps += 1
			for u in _alive(player_units):
				u.bonus_atk += j.amt
				u.recompute()
			_log("[기세] 격노 %d단 — 전군 공격 +%d" % [mom_rage_steps, int(j.amt)])
	var guard: int = 0
	if jokers.has("j_mom_call"):
		var cost: float = DATA.joker("j_mom_call").amt
		while momentum >= cost and guard < 6:
			guard += 1
			momentum -= cost
			var alive: Array = _alive(player_units)
			var pos: Vector2 = Vector2(P_COL_X, ROW_Y + ROW_GAP)
			if not alive.is_empty():
				pos = alive[randi() % alive.size()].position
			_spawn_unit(SUMMON_CARD, 0, pos, -1, true)
			_log("[기세] 증원 — 민병 소환")
	if jokers.has("j_mom_echo"):
		var cost2: float = DATA.joker("j_mom_echo").amt
		while momentum >= cost2 and guard < 12:
			guard += 1
			momentum -= cost2
			if not _copy_random_buff():
				momentum += cost2
				break

func _copy_random_buff() -> bool:
	var donors: Array = []
	for u in _alive(player_units):
		if not u.buffs.is_empty() and _adjacent_ally(u) != null:
			donors.append(u)
	if donors.is_empty():
		return false
	var src = donors[randi() % donors.size()]
	var heir = _adjacent_ally(src)
	var bid: String = src.buffs[randi() % src.buffs.size()]
	heir.add_buff(bid)
	_log("[기세] 각인 복제 — %s → %s" % [DATA.card(bid).name, heir.uname])
	return true

# 인접 칸(상하좌우)의 살아있는 아군
func _adjacent_ally(u):
	if u.cell < 0:
		return null
	var col: int = u.cell % GRID_COLS
	var row: int = floori(float(u.cell) / GRID_COLS)
	var cands: Array = []
	for o in _alive(player_units):
		if o == u or o.cell < 0:
			continue
		var oc: int = o.cell % GRID_COLS
		var orow: int = floori(float(o.cell) / GRID_COLS)
		if absi(oc - col) + absi(orow - row) == 1:
			cands.append(o)
	if cands.is_empty():
		return null
	return cands[randi() % cands.size()]

# ── 조건 발동 카드 ────────────────────────────────────────
func _check_traps(cond: String) -> void:
	for t in traps_armed:
		if t.fired:
			continue
		var cd: Dictionary = DATA.card(t.card)
		if cd.on != cond:
			continue
		if cond == "half_enemy_dead" and enemy_deaths * 2 < enemy_start_count:
			continue
		t.fired = true
		_log("조건 발동! %s" % cd.name)
		match cd.eff:
			"atk_mult":
				for u in _alive(player_units):
					u.mult_atk *= (1.0 + cd.amt)
					u.recompute()
			"heal_all":
				for u in _alive(player_units):
					u.heal(cd.amt)
			"summon":
				var alive: Array = _alive(player_units)
				for i in int(cd.amt):
					var pos: Vector2 = Vector2(P_COL_X, ROW_Y + i * ROW_GAP)
					if not alive.is_empty():
						pos = alive[randi() % alive.size()].position
					_spawn_unit(SUMMON_CARD, 0, pos, -1, true)

# ══════════════════════════════════════════════════════════
# 전투 HUD
# ══════════════════════════════════════════════════════════
func _build_battle_hud() -> void:
	hud_info = _label("", 40, 40, Color.WHITE, 26)
	hud_mom = _label("", 40, 78, Color(0.6, 0.9, 1.0), 24)
	hud_log = _label("", 40, 620, Color(0.85, 0.85, 0.7), 18)
	hud_log.size = Vector2(600, 320)
	var sp := _btn("속도 ×%d" % int(speed_mult), 1700, 40, 160, 56, Color(0.3, 0.35, 0.45))
	sp.pressed.connect(_cycle_speed)

func _cycle_speed() -> void:
	speed_mult = 1.0 if speed_mult >= 4.0 else speed_mult * 2.0
	_clear_ui()
	_build_battle_hud()

func _update_hud() -> void:
	if hud_info == null or not is_instance_valid(hud_info):
		return
	hud_info.text = "웨이브 %d   아군 %d   적 %d   %.1fs" % [
		wave + 1, player_units.size(), enemy_units.size(), battle_time]
	if _has_bus():
		var bars: int = clampi(int(momentum / 2.0), 0, 30)
		hud_mom.text = "기세 %d  [%s]   (누적 %d)" % [
			int(momentum), "█".repeat(bars), int(momentum_total)]
	else:
		hud_mom.text = ""
	hud_log.text = "\n".join(battle_log)

func _log(s: String) -> void:
	battle_log.append(s)
	if battle_log.size() > 12:
		battle_log.pop_front()

# ══════════════════════════════════════════════════════════
# 결과 → 조커 → 편성
# ══════════════════════════════════════════════════════════
func _end_battle(win: bool) -> void:
	state = St.RESULT
	if jokers.has("j_mom_coin") and momentum_total > 0.0:
		var per: float = DATA.joker("j_mom_coin").amt
		var g: int = int(momentum_total / per)
		gold += g
		gold_earned_in_battle += g
	_clear_ui()
	if win:
		var reward: int = GOLD_PER_WIN + wave * GOLD_WAVE_BONUS
		var interest: int = mini(INTEREST_MAX, floori(float(gold) / INTEREST_PER))
		gold += reward + interest
		wave += 1
		_title("승리 ✔   생존 %d기 · 아군 사망 %d · 누적 기세 %d" % [player_units.size(), ally_deaths, int(momentum_total)])
		_label("골드 +%d (클리어) +%d (이자) +%d (조커)   →  보유 %d" %
			[reward, interest, gold_earned_in_battle, gold],
			40, 140, Color(1.0, 0.92, 0.6), 24)
		_dump_log(40, 200)
		var b := _btn("조커 획득 ▶", 810, 900, 300, 90, Color(0.55, 0.35, 0.65))
		b.pressed.connect(_enter_jokerpick)
	else:
		_title("패배 ✘   런 종료 — 웨이브 %d (재도전·부활 없음)" % [wave + 1])
		_dump_log(40, 200)
		var b := _btn("처음부터", 810, 900, 300, 90, Color(0.6, 0.3, 0.3))
		b.pressed.connect(_new_run)

func _dump_log(x: float, y: float) -> void:
	_label("전투 로그", x, y, Color(0.8, 0.85, 0.95), 20)
	var l := _label("\n".join(battle_log), x, y + 28, Color(0.75, 0.75, 0.62), 17)
	l.size = Vector2(900, 500)

# ── 조커 3택1 ─────────────────────────────────────────────
var _joker_offers: Array = []
var _pending_joker: String = ""

func _enter_jokerpick() -> void:
	state = St.JOKERPICK
	_clear_battle()
	_pending_joker = ""
	_joker_offers.clear()
	for i in 3:
		if joker_pool_left.is_empty():
			break
		_joker_offers.append(joker_pool_left.pop_back())
	_build_jokerpick_ui()

func _build_jokerpick_ui() -> void:
	_clear_ui()
	_title("조커 획득  —  슬롯 %d/%d" % [jokers.size(), joker_slots])
	if _pending_joker != "":
		var pj: Dictionary = DATA.joker(_pending_joker)
		_label("슬롯이 가득 찼습니다. 무엇을 버리고 [%s]를 넣겠습니까?" % pj.name,
			40, 150, Color(1, 0.85, 0.6), 24)
		var y: float = 200.0
		for i in jokers.size():
			var j: Dictionary = DATA.joker(jokers[i])
			var b := _btn("교체: %s\n%s" % [j.name, j.desc], 40, y, 760, 84, Color(0.45, 0.3, 0.35))
			b.add_theme_font_size_override("font_size", 17)
			b.pressed.connect(_replace_joker.bind(i))
			y += 94.0
		var giveup := _btn("포기 (획득하지 않음)", 40, y + 10, 320, 70, Color(0.35, 0.35, 0.4))
		giveup.pressed.connect(_skip_joker)
		return

	var x: float = 40.0
	for jid in _joker_offers:
		var j: Dictionary = DATA.joker(jid)
		var col := Color(0.42, 0.30, 0.52)
		if j.line == "B":
			col = Color(0.24, 0.42, 0.52)
		elif j.line == "C":
			col = Color(0.50, 0.42, 0.24)
		var b := _btn("[%s] %s\n\n%s" % [j.line, j.name, j.desc], x, 200, 580, 220, col)
		b.add_theme_font_size_override("font_size", 19)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_take_joker.bind(jid))
		x += 600.0

	_label("A=직결형   B=공용 자원(기세) 버스형   C=코스트 조작", 40, 450, Color(0.6, 0.64, 0.74), 20)
	var skip := _btn("건너뛰기 ▶", 40, 500, 300, 80, Color(0.35, 0.35, 0.4))
	skip.pressed.connect(_skip_joker)
	if gold >= PRICE_SLOT and joker_slots < JOKER_SLOTS_MAX:
		var ex := _btn("슬롯 확장 (골드 %d)" % PRICE_SLOT, 360, 500, 300, 80, Color(0.3, 0.5, 0.45))
		ex.pressed.connect(_buy_slot)
	_label("골드 %d" % gold, 700, 520, Color(1.0, 0.92, 0.6), 24)

func _take_joker(jid: String) -> void:
	if jokers.size() < joker_slots:
		jokers.append(jid)
		_enter_deckedit()
	else:
		_pending_joker = jid
		_build_jokerpick_ui()

func _replace_joker(i: int) -> void:
	joker_pool_left.push_front(jokers[i])
	jokers[i] = _pending_joker
	_pending_joker = ""
	_enter_deckedit()

func _skip_joker() -> void:
	for jid in _joker_offers:
		if jid != _pending_joker:
			joker_pool_left.push_front(jid)
	_enter_deckedit()

func _buy_slot() -> void:
	gold -= PRICE_SLOT
	joker_slots += 1
	_build_jokerpick_ui()

# ── 덱 편성 ───────────────────────────────────────────────
var _shop_offers: Array = []
var _remove_mode: bool = false

func _enter_deckedit() -> void:
	state = St.DECKEDIT
	_clear_battle()
	_remove_mode = false
	_shop_offers.clear()
	var p: Array = DATA.offer_pool()
	p.shuffle()
	for i in mini(4, p.size()):
		_shop_offers.append(p[i])
	_build_deckedit_ui()

func _build_deckedit_ui() -> void:
	_clear_ui()
	_title("편성  —  덱 %d장 · 골드 %d" % [collection.size(), gold])
	_label("아끼면 다음 클리어 때 이자 +%d  (골드 %d당 +1, 최대 +%d)" %
		[mini(INTEREST_MAX, floori(float(gold) / INTEREST_PER)), INTEREST_PER, INTEREST_MAX],
		40, 92, Color(1.0, 0.92, 0.6), 22)

	_label("카드 구매 (가격 = 코스트 + %d)  —  약한 카드는 공짜여도 순손해다" % PRICE_ADD_EXTRA,
		40, 150, Color(0.8, 0.95, 0.8), 22)
	var x: float = 40.0
	for cid in _shop_offers:
		var cd: Dictionary = DATA.card(cid)
		var price: int = int(cd.cost) + PRICE_ADD_EXTRA
		var col: Color = cd.col if gold >= price else cd.col.darkened(0.5)
		var sub: String = str(cd.get("desc", ""))
		if cd.kind == "soldier":
			sub = "공%d 체%d · %s·%s" % [int(cd.atk), int(cd.hp), cd.race, cd.cls]
		var b := _btn("%s\n코스트 %d / 가격 %d골드\n%s" % [cd.name, int(cd.cost), price, sub],
			x, 190, 300, 130, col)
		b.add_theme_font_size_override("font_size", 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_buy_card.bind(cid, price))
		x += 312.0

	_label("덱 (%d장)  —  카드 제거: %d골드" % [collection.size(), PRICE_REMOVE],
		40, 360, Color(0.9, 0.8, 0.8), 22)
	var rm := _btn("제거 모드: %s" % ["ON" if _remove_mode else "OFF"], 700, 352, 220, 46,
		Color(0.6, 0.3, 0.3) if _remove_mode else Color(0.32, 0.32, 0.38))
	rm.add_theme_font_size_override("font_size", 17)
	rm.pressed.connect(_toggle_remove)

	var cx: float = 40.0
	var cy: float = 400.0
	for i in collection.size():
		var cd2: Dictionary = DATA.card(collection[i])
		var col2: Color = cd2.col
		if _remove_mode:
			col2 = col2.lerp(Color(0.8, 0.2, 0.2), 0.4)
		var b2 := _btn("[%d] %s" % [int(cd2.cost), cd2.name], cx, cy, 150, 50, col2)
		b2.add_theme_font_size_override("font_size", 16)
		b2.pressed.connect(_on_deck_card.bind(i))
		cx += 158.0
		if cx > 1740.0:
			cx = 40.0
			cy += 58.0

	_build_joker_panel_at(40, 800)
	var go := _btn("다음 전투 ▶", 1500, 950, 320, 90, Color(0.25, 0.6, 0.35))
	go.pressed.connect(_enter_prep)

func _build_joker_panel_at(x: float, y: float) -> void:
	_label("조커 %d/%d" % [jokers.size(), joker_slots], x, y, Color(0.95, 0.8, 1.0), 22)
	var jx: float = x
	for jid in jokers:
		var j: Dictionary = DATA.joker(jid)
		var l := _label("● %s\n   %s" % [j.name, j.desc], jx, y + 32, Color(0.85, 0.8, 0.95), 17)
		l.size = Vector2(440, 80)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		jx += 460.0

func _toggle_remove() -> void:
	_remove_mode = not _remove_mode
	_build_deckedit_ui()

func _buy_card(cid: String, price: int) -> void:
	if _remove_mode:
		return
	if gold < price:
		_toast("골드 부족")
		return
	gold -= price
	collection.append(cid)
	_shop_offers.erase(cid)
	_build_deckedit_ui()

func _on_deck_card(i: int) -> void:
	if not _remove_mode:
		return
	if collection.size() <= 4:
		_toast("덱이 너무 작아집니다")
		return
	if gold < PRICE_REMOVE:
		_toast("골드 부족")
		return
	gold -= PRICE_REMOVE
	collection.remove_at(i)
	_build_deckedit_ui()

# ══════════════════════════════════════════════════════════
# UI 헬퍼
# ══════════════════════════════════════════════════════════
func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()
	hud_info = null
	hud_mom = null
	hud_log = null

func _clear_battle() -> void:
	for u in player_units:
		if is_instance_valid(u): u.queue_free()
	for u in enemy_units:
		if is_instance_valid(u): u.queue_free()
	player_units.clear()
	enemy_units.clear()
	queue_redraw()

func _title(t: String) -> void:
	_label(t, 40, 30, Color.WHITE, 34)

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
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.bg_color = col.lightened(0.15)
	b.add_theme_stylebox_override("hover", sb2)
	ui.add_child(b)
	return b

func _toast(msg: String) -> void:
	var l := _label(msg, 700, 700, Color(1, 0.8, 0.4), 28)
	get_tree().create_timer(1.5).timeout.connect(_free_node.bind(l))

func _free_node(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()
