class_name JokerCatalog

# 조커 풀 (직결형 + 버스형 최소 세트). JokerEngine이 effect 딕셔너리를 해석한다.
#
# ⚠ "빠르게" 코드 카탈로그. 추후 CSV + i18n 이관 대상 (CLAUDE.md). 지금은 표시 문자열 직접 삽입.

static func _direct(id: String, disp: String, desc: String, trigger: int, buff_atk: float) -> Joker:
	var j := Joker.new()
	j.id = StringName(id)
	j.name_key = disp
	j.desc_key = desc
	j.trigger = trigger
	j.link = GameEnums.JokerLink.DIRECT
	j.effect = {"buff_atk": buff_atk}
	return j

static func _bus_producer(id: String, disp: String, desc: String, trigger: int, produce: int) -> Joker:
	var j := Joker.new()
	j.id = StringName(id)
	j.name_key = disp
	j.desc_key = desc
	j.trigger = trigger
	j.link = GameEnums.JokerLink.BUS
	j.effect = {"produce": produce}
	return j

static func _bus_payoff(id: String, disp: String, desc: String, trigger: int, per: int, atk: float) -> Joker:
	var j := Joker.new()
	j.id = StringName(id)
	j.name_key = disp
	j.desc_key = desc
	j.trigger = trigger
	j.link = GameEnums.JokerLink.BUS
	j.effect = {"payoff_per": per, "payoff_atk": atk}
	return j

static func pool() -> Array[Joker]:
	return [
		_direct("j_bloodlust", "피의 갈증", "적 처치 시 아군 전체 공격력 +2", GameEnums.BattleEvent.KILL, 2.0),
		_direct("j_vengeance", "복수심", "아군 사망 시 남은 아군 공격력 +3", GameEnums.BattleEvent.ALLY_DEATH, 3.0),
		_bus_producer("j_mom_kill", "기세: 처치", "처치마다 기세 +1", GameEnums.BattleEvent.KILL, 1),
		_bus_payoff("j_surge", "기세 폭발", "기세 5마다 아군 공격력 +2", GameEnums.BattleEvent.KILL, 5, 2.0),
	]

static func random_offers(rng: RandomNumberGenerator, n: int) -> Array[Joker]:
	var src := pool()
	# Fisher-Yates 부분 셔플로 중복 없이 n개.
	for i in range(src.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Joker = src[i]
		src[i] = src[j]
		src[j] = tmp
	var out: Array[Joker] = []
	for i in mini(n, src.size()):
		out.append(src[i])
	return out

static func gold_price() -> int:
	return 6
