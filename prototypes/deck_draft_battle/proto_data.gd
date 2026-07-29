# PROTOTYPE - NOT FOR PRODUCTION
# Question: 코스트 예산 배낭 퍼즐 + 3x3 배치 + 조커 엔진이 재밌는가? (PROTO_V2_SPEC.md)
# Date: 2026-07-29
#
# 카드 / 조커 / 웨이브 카탈로그. 수치는 전부 여기와 proto.gd 상단 const에만 존재한다.
extends RefCounted

# ══════════════════════════════════════════════════════════
# 카드
#   kind: soldier | buff | spell | aura | trap
#   모든 카드는 cost 를 가지며 배치 예산에서 차감된다.
# ══════════════════════════════════════════════════════════
static var _cards: Dictionary = {}

static func cards() -> Dictionary:
	if _cards.is_empty():
		_cards = _build_cards()
	return _cards

static func card(id: String) -> Dictionary:
	return cards()[id]

static func _build_cards() -> Dictionary:
	return {
	# ── 병사: 코스트 티어 (1 / 2 / 3 / 4) ────────────────────
	"militia": {"kind": "soldier", "name": "민병", "cost": 1, "col": Color(0.36, 0.50, 0.74),
		"hp": 95.0, "atk": 8.0, "def": 1.0, "aspd": 1.0, "rng": 46.0, "spd": 95.0,
		"race": "HUMANS", "cls": "WARRIOR"},
	"archer": {"kind": "soldier", "name": "궁수", "cost": 2, "col": Color(0.36, 0.50, 0.74),
		"hp": 85.0, "atk": 12.0, "def": 0.0, "aspd": 0.9, "rng": 260.0, "spd": 85.0,
		"race": "DARK_ELVES", "cls": "ARCHER"},
	"wolfkin": {"kind": "soldier", "name": "늑대인간", "cost": 2, "col": Color(0.36, 0.50, 0.74),
		"hp": 130.0, "atk": 9.0, "def": 1.0, "aspd": 1.4, "rng": 46.0, "spd": 130.0,
		"race": "BEASTMEN", "cls": "ASSASSIN"},
	"knight": {"kind": "soldier", "name": "기사", "cost": 3, "col": Color(0.36, 0.50, 0.74),
		"hp": 300.0, "atk": 14.0, "def": 5.0, "aspd": 0.8, "rng": 46.0, "spd": 80.0,
		"race": "HUMANS", "cls": "KNIGHT"},
	"flamelord": {"kind": "soldier", "name": "화염군주", "cost": 4, "col": Color(0.36, 0.50, 0.74),
		"hp": 340.0, "atk": 24.0, "def": 3.0, "aspd": 0.9, "rng": 70.0, "spd": 90.0,
		"race": "ORDER_OF_THE_FIRE", "cls": "GENERAL"},

	# ── 시한부 강화: 스탯형 ────────────────────────────────
	"b_atk": {"kind": "buff", "name": "＋공격", "cost": 1, "col": Color(0.62, 0.35, 0.35), "stat": "atk", "amt": 7.0, "desc": "공격 +7"},
	"b_hp": {"kind": "buff", "name": "＋체력", "cost": 1, "col": Color(0.35, 0.58, 0.40), "stat": "hp", "amt": 80.0, "desc": "체력 +80"},
	"b_def": {"kind": "buff", "name": "＋방어", "cost": 1, "col": Color(0.35, 0.48, 0.66), "stat": "def", "amt": 2.5, "desc": "방어 +2.5"},
	"b_as": {"kind": "buff", "name": "＋공속", "cost": 1, "col": Color(0.62, 0.58, 0.32), "stat": "aspd", "amt": 0.35, "desc": "공속 +0.35"},

	# ── 시한부 강화: 키워드형 (상태이상 매개의 생산처를 겸한다) ──
	"b_multi": {"kind": "buff", "name": "다단히트", "cost": 2, "col": Color(0.58, 0.38, 0.62), "stat": "multihit", "amt": 1.0, "desc": "타격 1회 추가"},
	"b_shield": {"kind": "buff", "name": "보호막", "cost": 2, "col": Color(0.58, 0.38, 0.62), "stat": "shield", "amt": 90.0, "desc": "보호막 90"},
	"b_exec": {"kind": "buff", "name": "처형", "cost": 2, "col": Color(0.58, 0.38, 0.62), "stat": "execute", "amt": 0.22, "desc": "체력 22% 이하 즉사"},
	"b_taunt": {"kind": "buff", "name": "도발", "cost": 1, "col": Color(0.58, 0.38, 0.62), "stat": "taunt", "amt": 1.0, "desc": "적이 우선 공격"},
	"b_vamp": {"kind": "buff", "name": "흡혈", "cost": 2, "col": Color(0.58, 0.38, 0.62), "stat": "lifesteal", "amt": 0.45, "desc": "가한 피해 45% 회복"},
	"b_stun": {"kind": "buff", "name": "충격파", "cost": 2, "col": Color(0.58, 0.38, 0.62), "stat": "stun", "amt": 0.22, "desc": "22% 확률 스턴 1초"},

	# ── 전술 주문: 1회성, 전투 개시 순간 발동 ────────────────
	"s_meteor": {"kind": "spell", "name": "화염 세례", "cost": 3, "col": Color(0.70, 0.42, 0.25),
		"eff": "dmg_all", "amt": 55.0, "desc": "개시: 적 전체 55 피해"},
	"s_ward": {"kind": "spell", "name": "응급 처치", "cost": 2, "col": Color(0.70, 0.42, 0.25),
		"eff": "shield_all", "amt": 60.0, "desc": "개시: 아군 전체 보호막 60"},
	# ※ "예산 → 골드" 환전 주문은 논의 4차(DESIGN_NOTES §8)에서 기각되어 넣지 않는다.
	#    예산↔골드를 태환하면 배낭 퍼즐이 "돈을 태울까"라는 단일 축으로 붕괴한다.
	"s_stunwave": {"kind": "spell", "name": "섬광탄", "cost": 2, "col": Color(0.70, 0.42, 0.25),
		"eff": "stun_all", "amt": 2.0, "desc": "개시: 적 전체 2초 스턴"},

	# ── 군단 오라: 전군 지속 (물량 빌드의 페이오프) ───────────
	"a_atk": {"kind": "aura", "name": "군단: 진군가", "cost": 3, "col": Color(0.30, 0.55, 0.55),
		"eff": "atk_mult", "amt": 0.25, "desc": "전군 공격 +25%"},
	"a_hp": {"kind": "aura", "name": "군단: 방벽", "cost": 3, "col": Color(0.30, 0.55, 0.55),
		"eff": "hp_mult", "amt": 0.30, "desc": "전군 체력 +30%"},
	"a_as": {"kind": "aura", "name": "군단: 북소리", "cost": 2, "col": Color(0.30, 0.55, 0.55),
		"eff": "aspd_mult", "amt": 0.20, "desc": "전군 공속 +20%"},

	# ── 조건 발동: 배치 때 예약, 전투 중 자동 발동 ────────────
	"t_firstblood": {"kind": "trap", "name": "첫 피 서약", "cost": 2, "col": Color(0.45, 0.40, 0.62),
		"on": "ally_death_1", "eff": "atk_mult", "amt": 0.50, "desc": "첫 아군 사망 시 전군 공격 +50%"},
	"t_rally": {"kind": "trap", "name": "반격 나팔", "cost": 2, "col": Color(0.45, 0.40, 0.62),
		"on": "half_enemy_dead", "eff": "heal_all", "amt": 70.0, "desc": "적 절반 처치 시 전군 70 회복"},
	"t_revenge": {"kind": "trap", "name": "복수의 맹세", "cost": 3, "col": Color(0.45, 0.40, 0.62),
		"on": "ally_death_3", "eff": "summon", "amt": 2.0, "desc": "아군 3기 사망 시 민병 2기 소환"},
	}

# ══════════════════════════════════════════════════════════
# 조커 — 덱과 분리된 상시 슬롯 계층
#   line: "A" 직결형 / "B" 공용 자원(기세) 버스형 / "C" 코스트 조작
#   medium: kill / death / status / summon / buffmove / gold / cost
# ══════════════════════════════════════════════════════════
static var _jokers: Dictionary = {}

static func jokers() -> Dictionary:
	if _jokers.is_empty():
		_jokers = _build_jokers()
	return _jokers

static func joker(id: String) -> Dictionary:
	return jokers()[id]

static func _build_jokers() -> Dictionary:
	return {
	# ── (A) 직결형: 이벤트 → 효과 ──────────────────────────
	"j_butcher": {"line": "A", "medium": "kill", "name": "학살자 문장",
		"desc": "적 처치 시 전군 공격 +2 (전투 내 누적)", "amt": 2.0},
	"j_martyr": {"line": "A", "medium": "death", "name": "순교자의 깃발",
		"desc": "아군 사망 시 남은 전군 공속 +12% (누적)", "amt": 0.12},
	"j_sigil": {"line": "A", "medium": "status", "name": "저주의 인장",
		"desc": "상태이상 부여 시 그 대상에 40 추가 피해", "amt": 40.0},
	"j_wraith": {"line": "A", "medium": "summon", "name": "망령 소집",
		"desc": "아군 사망 시 30% 확률로 그 자리에 망령 소환", "amt": 0.30},
	"j_legacy": {"line": "A", "medium": "buffmove", "name": "유산 전이",
		"desc": "강화 보유 아군 사망 시 강화 전부가 인접 아군에게 이동", "amt": 1.0},
	"j_bounty": {"line": "A", "medium": "gold", "name": "전리품 사냥꾼",
		"desc": "적 처치마다 골드 +1", "amt": 1.0},

	# ── (B) 공용 자원 버스형: 생산 ─────────────────────────
	"j_mom_kill": {"line": "B", "medium": "kill", "name": "[생산] 피의 각인",
		"desc": "적 처치 시 기세 +2", "amt": 2.0},
	"j_mom_death": {"line": "B", "medium": "death", "name": "[생산] 장송곡",
		"desc": "아군 사망 시 기세 +4", "amt": 4.0},
	"j_mom_hit": {"line": "B", "medium": "status", "name": "[생산] 인내의 북",
		"desc": "아군이 피격당할 때마다 기세 +1", "amt": 1.0},

	# ── (B) 공용 자원 버스형: 페이오프 ──────────────────────
	"j_mom_rage": {"line": "B", "medium": "kill", "name": "[페이오프] 격노",
		"desc": "누적 기세 10마다 전군 공격 +4", "amt": 4.0, "step": 10.0},
	"j_mom_call": {"line": "B", "medium": "summon", "name": "[페이오프] 증원",
		"desc": "기세 15 소비 → 민병 1기 소환", "amt": 15.0},
	"j_mom_echo": {"line": "B", "medium": "buffmove", "name": "[페이오프] 각인 복제",
		"desc": "기세 12 소비 → 아군 강화 1개를 인접 칸에 복제", "amt": 12.0},
	"j_mom_coin": {"line": "B", "medium": "gold", "name": "[페이오프] 환전",
		"desc": "전투 종료 시 누적 기세 5당 골드 +1", "amt": 5.0},

	# ── (C) 코스트 조작 = 프리미엄 빌드어라운드 ───────────────
	"j_supply": {"line": "C", "medium": "cost", "name": "보급 확장",
		"desc": "배치 예산 +3", "amt": 3.0},
	"j_levy": {"line": "C", "medium": "cost", "name": "인간 징집령",
		"desc": "HUMANS 병사 코스트 -1 (태그 빌드어라운드)", "amt": 1.0, "race": "HUMANS"},
	"j_vanguard": {"line": "C", "medium": "cost", "name": "선봉 무료",
		"desc": "매 준비마다 첫 병사 카드 코스트 0", "amt": 1.0},

	# ── 단점형: 강효과 + 대가 ──────────────────────────────
	"j_zealot": {"line": "A", "medium": "kill", "name": "광신도의 인장",
		"desc": "전군 공격 +55% / 최대 체력 -30%", "amt": 0.55, "pen": 0.30},
	"j_bloodpact": {"line": "A", "medium": "death", "name": "피의 계약",
		"desc": "전투 시작 시 아군 1기 즉사, 전군 공격 +35%", "amt": 0.35},

	# ── 태그 빌드어라운드 ──────────────────────────────────
	"j_feral": {"line": "A", "medium": "kill", "name": "야수의 광란",
		"desc": "BEASTMEN 아군이 처치할 때마다 그 유닛 공속 +25%", "amt": 0.25, "race": "BEASTMEN"},
	"j_hunt": {"line": "A", "medium": "kill", "name": "오크 사냥꾼",
		"desc": "ORC 적을 처치할 때마다 전군 공격 +3", "amt": 3.0, "race": "ORC"},
	}

# ══════════════════════════════════════════════════════════
# 웨이브
# ══════════════════════════════════════════════════════════
static func wave_spec(w: int) -> Dictionary:
	var tiers: Array = [
		{"name": "오크 정찰대", "race": "ORC", "count": 4, "hp": 110.0, "atk": 9.0, "def": 1.0, "aspd": 1.0, "rng": 46.0},
		{"name": "오크 무리", "race": "ORC", "count": 6, "hp": 130.0, "atk": 11.0, "def": 1.0, "aspd": 1.0, "rng": 46.0},
		{"name": "오크 궁수대", "race": "ORC", "count": 6, "hp": 110.0, "atk": 13.0, "def": 1.0, "aspd": 0.9, "rng": 240.0},
		{"name": "정예 오크", "race": "ORC", "count": 6, "hp": 230.0, "atk": 16.0, "def": 4.0, "aspd": 1.1, "rng": 46.0},
		{"name": "언데드 군단", "race": "UNDEAD", "count": 11, "hp": 160.0, "atk": 13.0, "def": 2.0, "aspd": 1.1, "rng": 46.0},
		{"name": "심연의 무리", "race": "UNDEAD", "count": 9, "hp": 300.0, "atk": 19.0, "def": 5.0, "aspd": 1.1, "rng": 46.0},
	]
	return tiers[mini(w, tiers.size() - 1)]

# ══════════════════════════════════════════════════════════
# 시작 덱 — 약하고 단순
# ══════════════════════════════════════════════════════════
static func start_deck() -> Array:
	var d: Array = []
	for i in 6:
		d.append("militia")
	d.append("archer")
	d.append("knight")
	d.append("b_atk")
	d.append("b_atk")
	d.append("b_hp")
	d.append("b_def")
	d.append("b_as")
	d.append("a_as")
	return d

# 편성 화면에서 제시할 수 있는 카드 풀
static func offer_pool() -> Array:
	var ids: Array = []
	for id in cards().keys():
		ids.append(id)
	return ids
