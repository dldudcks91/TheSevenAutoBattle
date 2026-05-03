class_name StatusEffect
extends RefCounted

# 유닛에 부착되는 시한부 상태(스턴/버프/도발/독 등). SkillRuntime이 생성하고 Unit이 들고 있으며,
# Unit.tick()에서 매 프레임 _decay()로 시간을 깎고, 만료된 효과는 제거된다.

enum Kind {
	STUN,
	FREEZE,
	BUFF_ATK,
	BUFF_ARMOR,
	POISON,
	BURN,
	TAUNT_TO,   # 이 유닛이 source 유닛을 우선 타겟으로 삼도록 강제한다.
}

var kind: int
var amount: float = 0.0
var time_left: float = 0.0       # > 0 이면 시한부, == INF 이면 영구.
var tick_interval: float = 0.0
var _tick_accum: float = 0.0
var source: Object = null        # Unit (도발/POISON 출처). 약참조 검증은 사용처에서.

static func make(kind_v: int, amount_v: float, duration: float, src: Object = null) -> StatusEffect:
	var e := StatusEffect.new()
	e.kind = kind_v
	e.amount = amount_v
	e.time_left = duration if duration > 0.0 else INF
	e.source = src
	return e

func is_expired() -> bool:
	return time_left <= 0.0

func decay(delta: float) -> void:
	if time_left == INF:
		return
	time_left = max(0.0, time_left - delta)

func refresh(duration: float) -> void:
	if duration <= 0.0:
		time_left = INF
	else:
		time_left = max(time_left, duration)
