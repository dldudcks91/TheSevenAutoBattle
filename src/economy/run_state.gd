extends Node
# Autoload singleton — 덱빌딩 런의 가변 상태 facade.
# 책임은 Economy / DeckStore / DeploymentBoard / RunProgress / JokerStore 5개 모듈에 위임된다.
# 필드 read/write × phase 매트릭스는 docs/game_design/SCENES.md §B 참조.
#
# 덱빌딩 모델 전환(2026-07-29): 영구 그리드·골드 고용·리롤·유물 인벤토리는 폐기.
# 영구 자산 = 덱 · 조커 · 골드. 전장(배치판)은 매 전투 초기화된다.

const GRID_CELLS_TOTAL: int = DeploymentBoard.GRID_CELLS_TOTAL

var economy := Economy.new()
var decks := DeckStore.new()
var deployment := DeploymentBoard.new()
var progress := RunProgress.new()
var joker_store := JokerStore.new()

# PREP → BATTLE 커밋 산출물.
var deployed: Array = []            # [{card: Card, mods: Array, position: Vector2}]
var enemy_positions: Array = []     # [Vector2]
var last_battle_stats: Dictionary = {}
var discard_left: int = 0

# ─── Lifecycle ────────────────────────────────────────────────────────────
func _ready() -> void:
	economy.load_balance()
	progress.load_rounds()
	deployment.reset(economy.DEPLOY_BUDGET)

func reset_run() -> void:
	economy.gold = economy.STARTING_GOLD
	progress.reset()
	joker_store.clear()
	joker_store.slot_count = economy.JOKER_SLOTS
	decks.clear()
	decks.rng.randomize()
	decks.seed_starter(_starter_deck())
	deployed.clear()
	enemy_positions.clear()
	last_battle_stats.clear()
	# 핸드 드로우/판 세팅은 PREP 진입(prep_phase._ready → begin_prep)에서 단일 지점으로 수행.

# 시작 덱 시드 — 확정 전까지 UnitDB 병사를 1장씩 담는 임시 시드 (GAME_DESIGN §12 미결).
func _starter_deck() -> Array[Card]:
	var out: Array[Card] = []
	for ud in UnitDB.all_player_units():
		out.append(Card.from_unit(ud))
	return out

# ─── PREP 진입 — 판 초기화 + 예산 리셋 + 덱 드로우 + 버리기 횟수 리셋 ───
func begin_prep() -> void:
	deployment.reset(current_deploy_budget())
	decks.draw_hand(economy.HAND_DRAW_COUNT)
	discard_left = economy.DISCARD_LIMIT

func current_deploy_budget() -> int:
	# 예산 성장 곡선은 후속 슬라이스 (GAME_DESIGN §5·§12).
	return economy.DEPLOY_BUDGET

# ─── Facade: 상태 접근 (getter는 동일 참조 반환) ───────────────────────────
var gold: int:
	get: return economy.gold
	set(v): economy.gold = v

var deck: Array[Card]:
	get: return decks.deck

var discard: Array[Card]:
	get: return decks.discard

var hand: Array[Card]:
	get: return decks.hand

var jokers: Array[Joker]:
	get: return joker_store.jokers

var current_round: int:
	get: return progress.current_round
	set(v): progress.current_round = v

var rng: RandomNumberGenerator:
	get: return decks.rng

var budget_total: int:
	get: return deployment.budget_total

var budget_spent: int:
	get: return deployment.budget_spent

var TOTAL_ROUNDS: int:
	get: return progress.total_rounds()

var STARTING_GOLD: int:
	get: return economy.STARTING_GOLD

func budget_left() -> int:
	return deployment.budget_left()

func board_cells() -> Array:
	return deployment.cells

func soldier_count() -> int:
	return deployment.soldier_count()

# ─── PREP: 배치 (골드 무관 — 예산만 소모) ─────────────────────────────────
# 핸드 인덱스의 병사 카드를 빈 칸에 배치.
func place_soldier(cell_idx: int, hand_idx: int) -> bool:
	if hand_idx < 0 or hand_idx >= decks.hand.size():
		return false
	var c: Card = decks.hand[hand_idx]
	if not c.is_soldier():
		return false
	if not deployment.place_soldier(cell_idx, c):
		return false
	decks.hand.remove_at(hand_idx)
	return true

# 핸드 인덱스의 시한부 강화 카드를 배치된 병사에 부착.
func attach_mod(cell_idx: int, hand_idx: int) -> bool:
	if hand_idx < 0 or hand_idx >= decks.hand.size():
		return false
	var c: Card = decks.hand[hand_idx]
	if not c.is_mod():
		return false
	if not deployment.attach_mod(cell_idx, c):
		return false
	decks.hand.remove_at(hand_idx)
	return true

# 셀 회수 — 병사+강화 카드를 핸드로 되돌리고 예산 환급.
func remove_cell(cell_idx: int) -> void:
	var freed := deployment.remove_cell(cell_idx)
	for c in freed:
		decks.hand.append(c as Card)

# 버리기 — 선택 카드를 버림 더미로 보내고 재드로우. 횟수 제한.
func discard_and_redraw(indices: Array[int]) -> bool:
	if discard_left <= 0 or indices.is_empty():
		return false
	decks.discard_and_redraw(indices)
	discard_left -= 1
	return true

# ─── 커밋: PREP → BATTLE (골드 차감 없음) ─────────────────────────────────
func commit_deployment(deployed_entries: Array, enemy_pos: Array) -> void:
	deployed = deployed_entries
	enemy_positions = enemy_pos

# ─── 전투 종료 — 낸 카드 + 안 낸 핸드 전량 회수, 판 초기화 ─────────────────
func recall_after_battle() -> void:
	decks.recall(deployment.all_played_cards())
	decks.recall(decks.hand.duplicate())
	decks.hand.clear()
	deployment.reset(deployment.budget_total)

# ─── RESULT: 보상 (정액 + 이자) ───────────────────────────────────────────
func current_round_reward() -> int:
	return progress.current_round_reward(economy)

func interest_amount() -> int:
	return economy.interest_for(economy.gold)

func grant_round_reward() -> void:
	economy.gold += current_round_reward() + interest_amount()

func advance_round() -> void:
	# 라운드만 진행. 핸드 드로우/판 세팅은 다음 PREP 진입(begin_prep)에서 수행.
	progress.advance_round()

# ─── 라운드 조회 ──────────────────────────────────────────────────────────
func current_enemy_lineup() -> Array:
	return progress.current_enemy_lineup()

func current_tactic_key() -> StringName:
	return progress.current_tactic_key()

func is_last_round() -> bool:
	return progress.is_last_round()

# ─── 경제 헬퍼 ────────────────────────────────────────────────────────────
func can_afford(amount: int) -> bool:
	return economy.can_afford(amount)

func spend(amount: int) -> bool:
	return economy.spend(amount)

func refund(amount: int) -> void:
	economy.refund(amount)

# ─── SHOP: 편성 ───────────────────────────────────────────────────────────
func add_card(c: Card) -> void:
	decks.add_to_deck(c)

func remove_card(c: Card) -> bool:
	return decks.remove_from_deck(c)

func add_joker(j: Joker) -> bool:
	return joker_store.add(j)

func replace_joker(idx: int, j: Joker) -> Joker:
	return joker_store.replace(idx, j)

func jokers_full() -> bool:
	return joker_store.is_full()
