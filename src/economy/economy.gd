class_name Economy
extends RefCounted

# 골드(전투 밖 자원)와 밸런스 상수. 덱빌딩 모델:
# 골드는 전투에 관여하지 않는다 — 편성은 배치 코스트 예산으로만 한다 (GAME_DESIGN §5·§6).
# 골드 획득처 = 클리어 정액 + 이자 + 조커. 고용가/리롤은 폐기.

var STARTING_GOLD: int = 10
var REWARD_PER_ROUND: int = 15
var REWARD_GROWTH_PER_ROUND: int = 2
var INTEREST_PER: int = 5          # 보유 골드 INTEREST_PER 마다 이자 +1
var INTEREST_MAX: int = 5          # 이자 상한
var DEPLOY_BUDGET: int = 10        # 기본 배치 예산 (성장 곡선은 후속 슬라이스)
var DISCARD_LIMIT: int = 2         # 버리기 횟수 — 체감 난이도 최상위 레버 (GAME_DESIGN §6)
var HAND_DRAW_COUNT: int = 5       # 매 전투 드로우 수
var JOKER_SLOTS: int = 5           # 시작 조커 슬롯 수

var gold: int = 0

func load_balance() -> void:
	var rows := CsvLoader.load_table("res://src/data/balance.csv")
	for row in rows:
		match row["key"]:
			"starting_gold":           STARTING_GOLD = int(row["value"])
			"reward_per_round":        REWARD_PER_ROUND = int(row["value"])
			"reward_growth_per_round": REWARD_GROWTH_PER_ROUND = int(row["value"])
			"interest_per":            INTEREST_PER = int(row["value"])
			"interest_max":            INTEREST_MAX = int(row["value"])
			"deploy_budget":           DEPLOY_BUDGET = int(row["value"])
			"discard_limit":           DISCARD_LIMIT = int(row["value"])
			"hand_draw_count":         HAND_DRAW_COUNT = int(row["value"])
			"joker_slots":             JOKER_SLOTS = int(row["value"])

func can_afford(amount: int) -> bool:
	return gold >= amount

func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	gold -= amount
	return true

func refund(amount: int) -> void:
	gold += amount

# 보유 골드에 비례한 이자 (상한 있음). 안 쓰면 불어난다 (GAME_DESIGN §6).
func interest_for(current_gold: int) -> int:
	if INTEREST_PER <= 0:
		return 0
	return mini(current_gold / INTEREST_PER, INTEREST_MAX)
