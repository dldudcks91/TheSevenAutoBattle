class_name Card
extends RefCounted

# 덱빌딩 모델의 카드. 병사 / 시한부 강화 / 전술 주문 / 군단 오라 / 조건 발동을 하나로 표현한다.
# 전장은 임시이므로 카드 인스턴스는 전투 후 덱/버림 더미로 회수된다 (개별 유닛 영구 누적 없음).
# 수치(코스트·강화량)는 카탈로그 데이터에서 로드한다 — 여기 하드코딩 금지.

var id: StringName
var kind: GameEnums.CardType = GameEnums.CardType.SOLDIER
var cost: int = 1
var name_key: String = ""
var desc_key: String = ""

# SOLDIER 전용 — 배치될 유닛 정의. 종족·직업 태그는 unit_data 가 보유(조커 훅용).
var unit_data: UnitData = null

# MOD(시한부 강화) 전용 — 부착 시 적용할 스탯 또는 키워드.
var mod_stat: StringName = &""       # "atk"/"hp"/"defense"/"attack_speed" 등, 키워드형이면 &""
var mod_amount: float = 0.0
var mod_keyword: StringName = &""    # "multihit"/"shield"/"execute"/"taunt"/"lifesteal" 등, 없으면 &""

# SPELL / AURA / TRAP 전용 — 효과 파라미터 묶음. 슬라이스 3~4에서 해석한다.
var effect: Dictionary = {}

# 병사 카드를 유닛 정의에서 생성.
static func from_unit(ud: UnitData) -> Card:
	var c := Card.new()
	c.id = ud.id
	c.kind = GameEnums.CardType.SOLDIER
	c.cost = ud.cost
	c.name_key = ud.name_key
	c.unit_data = ud
	return c

func is_soldier() -> bool:
	return kind == GameEnums.CardType.SOLDIER

func is_mod() -> bool:
	return kind == GameEnums.CardType.MOD
