class_name DeckStore
extends RefCounted

# 덱빌딩 모델의 카드 컬렉션 — 덱·버림 더미·핸드 + 드로우/버리기/회수 로직.
# RosterStore(누적 모델의 전체 풀 랜덤 추첨)를 대체한다.
# 핸드는 "전체 유닛 풀"이 아니라 "내 덱"에서 드로우된다.

var deck: Array[Card] = []
var discard: Array[Card] = []
var hand: Array[Card] = []
var rng := RandomNumberGenerator.new()

func clear() -> void:
	deck.clear()
	discard.clear()
	hand.clear()

# 런 시작 시 시작 덱을 셋업.
func seed_starter(cards: Array[Card]) -> void:
	deck = cards.duplicate()
	discard.clear()
	hand.clear()
	shuffle_deck()

func shuffle_deck() -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

# 덱이 비면 버림 더미를 셔플해 덱으로 되돌린다.
func _reshuffle_discard() -> void:
	if discard.is_empty():
		return
	deck = discard.duplicate()
	discard.clear()
	shuffle_deck()

func _draw_one() -> Card:
	if deck.is_empty():
		_reshuffle_discard()
	if deck.is_empty():
		return null
	return deck.pop_back()

# 매 전투 준비 시 count 장 드로우 (핸드는 새로 채운다).
func draw_hand(count: int) -> void:
	hand.clear()
	for _i in count:
		var c := _draw_one()
		if c == null:
			break
		hand.append(c)

# 선택한 핸드 인덱스들을 버림 더미로 보내고 같은 수만큼 재드로우. (버리기)
func discard_and_redraw(indices: Array[int]) -> void:
	var sorted_idx := indices.duplicate()
	sorted_idx.sort()
	sorted_idx.reverse()
	var removed := 0
	for idx in sorted_idx:
		if idx < 0 or idx >= hand.size():
			continue
		discard.append(hand[idx])
		hand.remove_at(idx)
		removed += 1
	for _i in removed:
		var c := _draw_one()
		if c == null:
			break
		hand.append(c)

# 전투 후: 낸 카드(+안 낸 핸드)를 전부 버림 더미로 회수.
func recall(cards: Array) -> void:
	for c in cards:
		if c != null:
			discard.append(c as Card)

# ── 편성(SHOP) ──
func add_to_deck(c: Card) -> void:
	deck.append(c)

func remove_from_deck(c: Card) -> bool:
	var idx := deck.find(c)
	if idx == -1:
		return false
	deck.remove_at(idx)
	return true

func deck_size() -> int:
	return deck.size()
