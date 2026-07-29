class_name JokerStore
extends RefCounted

# 상시 조커 슬롯. 슬롯 제한제 — 무엇을 넣고 뺄지가 커밋 압박 (GAME_DESIGN §7).
# 슬롯 확장 자체가 성장 축이므로 slot_count 는 런 중 늘어난다.

var jokers: Array[Joker] = []
var slot_count: int = 5

func clear() -> void:
	jokers.clear()

func is_full() -> bool:
	return jokers.size() >= slot_count

# 빈 슬롯이 있으면 추가. 만차면 false — 호출부가 교체 모달을 띄운다.
func add(j: Joker) -> bool:
	if is_full():
		return false
	jokers.append(j)
	return true

# idx 슬롯을 새 조커로 교체하고 밀려난 조커를 반환.
func replace(idx: int, j: Joker) -> Joker:
	if idx < 0 or idx >= jokers.size():
		return null
	var old: Joker = jokers[idx]
	jokers[idx] = j
	return old

func remove(idx: int) -> void:
	if idx >= 0 and idx < jokers.size():
		jokers.remove_at(idx)

func expand_slot(by: int = 1) -> void:
	slot_count += by
