class_name SynergyDef
extends RefCounted

# synergies.csv 의 한 행. 직업 또는 종족 시너지 정의.

var id: StringName
var type: GameEnums.SynergyType
var type_key: int                # GameEnums.Class 또는 GameEnums.Race 값
var key_str: String              # "KNIGHT" 등 — 디버그·키 매핑용
var name_key: StringName
var desc_key: StringName
var thresholds: Array[int] = []  # 오름차순 임계값 (빈 단계 제외)

static func from_row(row: Dictionary) -> SynergyDef:
	var d := SynergyDef.new()
	d.id = StringName(row["id"])
	var type_str: String = String(row["type"]).strip_edges()
	d.type = GameEnums.SynergyType[type_str]
	d.key_str = String(row["key"]).strip_edges()
	if d.type == GameEnums.SynergyType.CLASS:
		d.type_key = GameEnums.Class[d.key_str]
	else:
		d.type_key = GameEnums.Race[d.key_str]
	d.name_key = StringName(row["name_key"])
	d.desc_key = StringName(row["desc_key"])
	for i in range(1, 4):
		var t_str: String = String(row.get("threshold_%d" % i, "")).strip_edges()
		if t_str != "":
			d.thresholds.append(int(t_str))
	return d

# 카운트 → 발동 단계(1-based). 미달이면 0.
func step_for_count(count: int) -> int:
	var step: int = 0
	for t in thresholds:
		if count >= t:
			step += 1
		else:
			break
	return step

# 다음 단계 임계값 반환. 더 없으면 -1.
func next_threshold(count: int) -> int:
	for t in thresholds:
		if count < t:
			return t
	return -1

func max_step() -> int:
	return thresholds.size()
