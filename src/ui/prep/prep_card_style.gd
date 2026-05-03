class_name PrepCardStyle
extends RefCounted

# PREP phase 카드 종류별 색상 토큰. 추후 ItemInventoryView/HandPanel 분리 시 공유.
# Theme 파일로 빼지 않고 코드 const로 둔 이유: 게임 디자이너가 단일 위치에서 가시적으로 편집하기 위함.

const ACCENT_HERO := Color(0.40, 0.78, 1.00)       # cyan
const ACCENT_UPGRADE := Color(1.00, 0.78, 0.30)    # gold
const ACCENT_SKILL := Color(0.78, 0.55, 0.95)      # purple
const ACCENT_ITEM := Color(0.55, 0.85, 0.65)       # teal-green

static func accent_for(kind: int) -> Color:
	match kind:
		GameEnums.CardKind.HERO:    return ACCENT_HERO
		GameEnums.CardKind.UPGRADE: return ACCENT_UPGRADE
		GameEnums.CardKind.SKILL:   return ACCENT_SKILL
		GameEnums.CardKind.ITEM:    return ACCENT_ITEM
	return Color.WHITE
