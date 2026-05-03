extends Node
# Autoload singleton — facade for the live run's mutable state.
# 실제 책임은 Economy/RosterStore/DeploymentBoard/RunProgress 4개 모듈에 위임된다.
# 외부 호출처(prep_phase / battle_simulator / arena_root / result_phase / main_menu)는
# 기존 API 서명을 그대로 유지하기 위해 facade getter/메서드를 통해 동일하게 접근한다.

const GRID_CELLS_TOTAL: int = DeploymentBoard.GRID_CELLS_TOTAL

var economy := Economy.new()
var roster_store := RosterStore.new()
var deployment := DeploymentBoard.new()
var progress := RunProgress.new()

# ─── Lifecycle ────────────────────────────────────────────────────────────
func _ready() -> void:
	economy.load_balance()
	progress.load_rounds()
	deployment.ensure_grid()

func reset_run() -> void:
	economy.gold = economy.STARTING_GOLD
	roster_store.clear()
	progress.reset()
	deployment.clear()
	roster_store.rng.randomize()
	roll_hand()

# ─── Facade: balance constants ────────────────────────────────────────────
var STARTING_GOLD: int:
	get: return economy.STARTING_GOLD
var REWARD_PER_ROUND: int:
	get: return economy.REWARD_PER_ROUND
var REWARD_GROWTH_PER_ROUND: int:
	get: return economy.REWARD_GROWTH_PER_ROUND
var HIRE_PRICE_PER_COST: int:
	get: return economy.HIRE_PRICE_PER_COST
var REROLL_COST: int:
	get: return economy.REROLL_COST
var SHOP_ITEM_OFFER_COUNT: int:
	get: return economy.SHOP_ITEM_OFFER_COUNT
var HAND_OFFER_COUNT: int:
	get: return economy.HAND_OFFER_COUNT

var TOTAL_ROUNDS: int:
	get: return progress.total_rounds()

# ─── Facade: state (getter는 동일 참조 반환 — 외부 인덱스 mutate 그대로 통과) ──
var gold: int:
	get: return economy.gold
	set(v): economy.gold = v

var roster: Array[RosterSlot]:
	get: return roster_store.roster

var hand: Array[RosterSlot]:
	get: return roster_store.hand

var inventory: Array[ItemData]:
	get: return roster_store.inventory

var grid_cells: Array:
	get: return deployment.grid_cells

var current_round: int:
	get: return progress.current_round
	set(v): progress.current_round = v

var rng: RandomNumberGenerator:
	get: return roster_store.rng

# ─── Facade: hand / shop ──────────────────────────────────────────────────
func roll_hand() -> void:
	roster_store.roll_hand(UnitDB.all_player_units(), economy.HAND_OFFER_COUNT, _get_grid_unit_types())

func _get_grid_unit_types() -> Array[UnitData]:
	var seen: Dictionary = {}
	var result: Array[UnitData] = []
	for i in DeploymentBoard.GRID_CELLS_TOTAL:
		var entries: Array = deployment.grid_cells[i]
		for entry in entries:
			var ud: UnitData = ((entry as Dictionary)["slot"] as RosterSlot).unit_data
			if not seen.has(ud.id):
				seen[ud.id] = true
				result.append(ud)
	return result

func reroll_hand() -> bool:
	if not economy.spend(economy.REROLL_COST):
		return false
	roll_hand()
	return true

func roll_shop_item_offers() -> Array[ItemData]:
	return ItemDB.random_offers(roster_store.rng, economy.SHOP_ITEM_OFFER_COUNT)

func reroll_items() -> Array[ItemData]:
	if not economy.spend(economy.REROLL_COST):
		return []
	return roll_shop_item_offers()

# ─── Facade: economy ──────────────────────────────────────────────────────
func can_afford(amount: int) -> bool:
	return economy.can_afford(amount)

func spend(amount: int) -> bool:
	return economy.spend(amount)

func refund(amount: int) -> void:
	economy.refund(amount)

func buy_item(it: ItemData) -> bool:
	return economy.buy_item(it, roster_store.inventory)

func hire_price_for(unit: UnitData) -> int:
	return economy.hire_price_for(unit)

func equip_item(slot_idx: int, inventory_idx: int) -> bool:
	return roster_store.equip_item(slot_idx, inventory_idx)

func unequip_item(slot_idx: int, item_idx: int) -> bool:
	return roster_store.unequip_item(slot_idx, item_idx)

# ─── Facade: deployment grid ──────────────────────────────────────────────
func _ensure_grid() -> void:
	deployment.ensure_grid()

func grid_total_count() -> int:
	return deployment.total_count()

func grid_unpaid_cost() -> int:
	return deployment.unpaid_cost(Callable(economy, "hire_price_for"))

func grid_unpaid_count() -> int:
	return deployment.unpaid_count()

func grid_commit_paid() -> void:
	deployment.commit_paid()

func grid_invalidate_unpaid_hand_indices() -> void:
	deployment.invalidate_unpaid_hand_indices()

# 셀의 총 업그레이드 횟수 (별 표시용).
func grid_get_upgrade(cell_idx: int) -> int:
	return deployment.get_cell_boost_count(cell_idx)

# 셀의 스탯별 업그레이드 카운트 Dictionary 반환.
func grid_get_boosts(cell_idx: int) -> Dictionary:
	return deployment.get_cell_boosts(cell_idx)

# stat 스탯에 업그레이드 1회 추가 (MAX_UPGRADE_LEVEL 초과 시 false 반환).
func grid_add_boost(cell_idx: int, stat: String) -> bool:
	return deployment.add_cell_boost(cell_idx, stat)

# 셀 업그레이드 전부 초기화.
func grid_reset_upgrade(cell_idx: int) -> void:
	deployment.clear_cell_boosts(cell_idx)

# 두 셀의 업그레이드 보정값을 교환 (드래그 스왑 시 호출).
func grid_swap_boosts(idx_a: int, idx_b: int) -> void:
	deployment.swap_cell_boosts(idx_a, idx_b)

var MAX_UPGRADE_LEVEL: int:
	get: return DeploymentBoard.MAX_UPGRADE_LEVEL

# ─── Facade: round progress ───────────────────────────────────────────────
func current_tactic_key() -> StringName:
	return progress.current_tactic_key()

func current_enemy_lineup() -> Array:
	return progress.current_enemy_lineup()

func is_last_round() -> bool:
	return progress.is_last_round()

func current_round_reward() -> int:
	return progress.current_round_reward(economy)

func grant_round_reward() -> void:
	progress.grant_round_reward(economy)

func advance_round() -> void:
	progress.advance_round()
	roll_hand()
