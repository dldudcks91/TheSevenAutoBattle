class_name JokerEngine
extends RefCounted

# 전투 이벤트 → 조커 효과 (SCENES.md §D, GAME_DESIGN §7). "빠르게" 최소 구현.
#  · 직결형(DIRECT): 트리거 이벤트에 즉시 효과.
#  · 버스형(BUS): 공용 자원 '기세'를 생산 조커가 쌓고 페이오프 조커가 소비.
# 조커가 없으면 이 엔진은 잠들어 있다 (기세도 존재하지 않는다 — 시작 상태).
#
# 조커 effect 딕셔너리(카탈로그가 정의) 예:
#  직결형  {"buff_atk": 3}                     — 트리거 시 아군 전체 공격력 +3
#  버스생산 {"produce": 1}                      — 트리거 시 기세 +1
#  버스소비 {"payoff_per": 5, "payoff_atk": 2}  — 기세 5마다 소비해 아군 공격력 +2

var jokers: Array = []            # Array[Joker]
var momentum: int = 0
var _log: Callable = Callable()   # (text: String) -> void, 선택

func setup(joker_list: Array, log_cb: Callable = Callable()) -> void:
	jokers = joker_list
	momentum = 0
	_log = log_cb

func has_bus_joker() -> bool:
	for j in jokers:
		if (j as Joker) != null and (j as Joker).link == GameEnums.JokerLink.BUS:
			return true
	return false

# ctx = { "allies": Array[Unit], "enemies": Array[Unit], "subject": Unit }
func on_event(ev: int, ctx: Dictionary) -> void:
	for j in jokers:
		var jk := j as Joker
		if jk == null or int(jk.trigger) != ev:
			continue
		match jk.link:
			GameEnums.JokerLink.DIRECT: _apply_direct(jk, ctx)
			GameEnums.JokerLink.BUS:    _apply_bus(jk, ctx)

func _apply_direct(jk: Joker, ctx: Dictionary) -> void:
	if jk.effect.has("buff_atk"):
		var amt := float(jk.effect["buff_atk"])
		_buff_allies_atk(ctx, amt)
		_emit_log("%s → 아군 공격력 +%d" % [_name(jk), int(amt)])

func _apply_bus(jk: Joker, ctx: Dictionary) -> void:
	if jk.effect.has("produce"):
		momentum += int(jk.effect["produce"])
		_emit_log("기세 +%d (=%d)" % [int(jk.effect["produce"]), momentum])
	if jk.effect.has("payoff_per") and jk.effect.has("payoff_atk"):
		var per := int(jk.effect["payoff_per"])
		if per > 0 and momentum >= per:
			var times := momentum / per
			momentum -= times * per
			_buff_allies_atk(ctx, float(times) * float(jk.effect["payoff_atk"]))
			_emit_log("기세 소비 → 아군 공격력 +%d" % int(times * int(jk.effect["payoff_atk"])))

func _buff_allies_atk(ctx: Dictionary, amount: float) -> void:
	for u in ctx.get("allies", []):
		if is_instance_valid(u) and u.stats != null:
			u.stats.attack += amount

func _name(jk: Joker) -> String:
	return tr(jk.name_key) if jk.name_key != "" else String(jk.id)

func _emit_log(t: String) -> void:
	if _log.is_valid():
		_log.call(t)
	else:
		print("[Joker] %s" % t)
