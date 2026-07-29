class_name CardCatalog

# 구매 가능한 카드 풀 (병사 + 시한부 강화). 병사는 UnitDB에서, 나머지는 여기 정의.
#
# ⚠ "빠르게" 코드 카탈로그. CLAUDE.md 규칙상 최종적으로 src/data/ CSV + i18n text.csv 로 이관해야 한다.
#    지금은 name_key/desc_key에 표시 문자열을 직접 넣어(tr()가 키 부재 시 원문 반환) 속도를 낸다.

static func _mod(id: String, disp: String, cost: int, stat: String, amount: float) -> Card:
	var c := Card.new()
	c.id = StringName(id)
	c.kind = GameEnums.CardType.MOD
	c.cost = cost
	c.name_key = disp
	c.desc_key = "%s +%d (이번 전투)" % [stat, int(amount)]
	c.mod_stat = StringName(stat)
	c.mod_amount = amount
	return c

static func mod_pool() -> Array[Card]:
	return [
		_mod("mod_atk", "예리함", 2, "atk", 8.0),
		_mod("mod_hp", "가죽갑옷", 2, "hp", 40.0),
		_mod("mod_def", "방패", 2, "defense", 3.0),
		_mod("mod_aspd", "속공", 3, "attack_speed", 0.4),
	]

static func soldier_pool() -> Array[Card]:
	var out: Array[Card] = []
	for ud in UnitDB.all_player_units():
		out.append(Card.from_unit(ud))
	return out

# 상점 오퍼 — 병사 + 강화 혼합에서 n장 랜덤. 각 오퍼는 독립 인스턴스.
static func random_offers(rng: RandomNumberGenerator, n: int) -> Array[Card]:
	var pool: Array[Card] = []
	pool.append_array(soldier_pool())
	pool.append_array(mod_pool())
	var out: Array[Card] = []
	for _i in n:
		if pool.is_empty():
			break
		out.append(_fresh(pool[rng.randi_range(0, pool.size() - 1)]))
	return out

static func _fresh(src: Card) -> Card:
	var c := Card.new()
	c.id = src.id
	c.kind = src.kind
	c.cost = src.cost
	c.name_key = src.name_key
	c.desc_key = src.desc_key
	c.unit_data = src.unit_data
	c.mod_stat = src.mod_stat
	c.mod_amount = src.mod_amount
	c.mod_keyword = src.mod_keyword
	c.effect = src.effect.duplicate()
	return c

# 골드 구매가 — 배치 코스트에 비례 (상점 가격 구조는 GAME_DESIGN §12 미결, 임시 계수).
static func gold_price(c: Card) -> int:
	return maxi(2, c.cost * 3)

static func remove_price() -> int:
	return 3  # 카드 제거 비용 — 경로 미결(GAME_DESIGN §12), 임시값
