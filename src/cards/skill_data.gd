class_name SkillData
extends RefCounted

# 스킬 한 개를 서술하는 데이터. docs/game_design/SKILL_DESIGN.md의 6축(Trigger / Subject / Condition /
# Effect / Target / Duration)을 CSV 행 1개로 표현한다. 런타임 실행은 SkillRuntime이 담당.

enum Trigger {
	NONE,
	ON_DEPLOY,
	ON_ATTACK,
	ON_KILL,
	ON_ALLY_DEATH,
	ON_DEATH,
	ON_DAMAGED_BELOW,
	AURA,
	PERIODIC,
}

enum Effect {
	NONE,
	STRIKE,       # 단일 대상에 즉시 피해(원거리 시전자는 발사체)
	CLEAVE,       # 반경 내 적에게 피해
	HEAL,         # 대상 체력 회복
	LIFESTEAL,    # 자신을 가한 피해의 value 비율만큼 회복
	BUFF_ATK,     # 대상 공격력 증가 (duration=0 → 영구)
	BUFF_ARMOR,   # 대상 방어력 증가 (duration=0 → 영구)
	TAUNT,        # 대상이 시전자를 우선 타겟으로 삼게 함
	STUN,         # 대상 행동 불가
	FREEZE,       # 대상 이동 속도 감소 (50%)
	POISON,       # 대상 매 1초 value 피해
	BURN,         # 대상 피격 시 value 추가 피해
}

enum TargetSel {
	SELF,
	CURRENT_TARGET,       # 트리거가 가리키는 대상 (공격 대상 / 처치한 적 등)
	NEAREST_ENEMY,
	LOWEST_HP_ALLY,
	ENEMIES_IN_RADIUS,
	ALLIES_IN_RADIUS,
}

var id: StringName
var name_key: String
var desc_key: String
var trigger: int = Trigger.NONE
var effect: int = Effect.NONE
var target: int = TargetSel.SELF

# 효과 1차 수치. STRIKE/CLEAVE = 시전자 attack 배율, HEAL/POISON/BURN/BUFF_* = 절대치, LIFESTEAL = 비율(0~1).
var value: float = 0.0
var value2: float = 0.0
var chance: float = 1.0
var radius_cells: float = 0.0
var duration: float = 0.0      # 상태이상/버프 지속(s). 0 = 영구 또는 즉발.
var interval: float = 0.0      # PERIODIC 트리거의 발동 주기(s).
var threshold: float = 0.0     # ON_DAMAGED_BELOW 트리거 임계 비율(0~1).

static func from_row(row: Dictionary) -> SkillData:
	var s := SkillData.new()
	s.id = StringName(row["id"])
	s.name_key = row.get("name_key", "")
	s.desc_key = row.get("desc_key", "")
	s.trigger = _parse_enum(Trigger, row.get("trigger", ""), Trigger.NONE)
	s.effect = _parse_enum(Effect, row.get("effect", ""), Effect.NONE)
	s.target = _parse_enum(TargetSel, row.get("target", ""), TargetSel.SELF)
	s.value = _to_float(row.get("value", "0"))
	s.value2 = _to_float(row.get("value2", "0"))
	s.chance = _to_float(row.get("chance", "1"))
	s.radius_cells = _to_float(row.get("radius_cells", "0"))
	s.duration = _to_float(row.get("duration", "0"))
	s.interval = _to_float(row.get("interval", "0"))
	s.threshold = _to_float(row.get("threshold", "0"))
	return s

static func _parse_enum(enum_dict, raw: String, fallback: int) -> int:
	var key := raw.strip_edges()
	if key == "":
		return fallback
	if enum_dict.has(key):
		return int(enum_dict[key])
	push_warning("SkillData: unknown enum value '%s'" % key)
	return fallback

static func _to_float(raw: String) -> float:
	var s := raw.strip_edges()
	if s == "":
		return 0.0
	return s.to_float()
