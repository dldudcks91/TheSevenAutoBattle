class_name FormationLibrary
extends RefCounted

# 라운드별 적 진형(전술) 카탈로그.
# prep_phase에 const Dictionary로 살던 데이터를 분리. 추후 .tres FormationDef 묶음으로 옮길 수 있다.

# 적 EnemyZone 좌측 상단을 (0,0)으로, 우측 하단을 (1,1)로 두는 정규화 좌표.
const _NORMALIZED_POSITIONS: Dictionary = {
	&"crane_wing": [   # W1: 4 — 학익진·U형 포위호
		Vector2(0.10, 0.40), Vector2(0.90, 0.40),
		Vector2(0.30, 0.70), Vector2(0.70, 0.70),
		Vector2(0.50, 0.20), Vector2(0.20, 0.55), Vector2(0.80, 0.55),
		Vector2(0.50, 0.85), Vector2(0.15, 0.80), Vector2(0.85, 0.80),
		Vector2(0.10, 0.65), Vector2(0.90, 0.65),
	],
	&"lure_ambush": [  # W2: 5 — 청야유인·소수 미끼(위) + 주력 매복(아래)
		Vector2(0.30, 0.18), Vector2(0.70, 0.18),
		Vector2(0.20, 0.70), Vector2(0.50, 0.75), Vector2(0.80, 0.70),
		Vector2(0.35, 0.50), Vector2(0.65, 0.50),
		Vector2(0.15, 0.88), Vector2(0.50, 0.88), Vector2(0.85, 0.88),
		Vector2(0.10, 0.30), Vector2(0.90, 0.30),
	],
	&"ambush_sides": [ # W3: 6 — 매복기병·중앙 얇은 전선 + 양측 복병
		Vector2(0.50, 0.15),
		Vector2(0.20, 0.42), Vector2(0.50, 0.48), Vector2(0.80, 0.42),
		Vector2(0.15, 0.78), Vector2(0.85, 0.78),
		Vector2(0.50, 0.78), Vector2(0.10, 0.60), Vector2(0.90, 0.60),
		Vector2(0.35, 0.90), Vector2(0.65, 0.90), Vector2(0.50, 0.65),
	],
	&"defensive_box": [# W4: 6 — 거점방어진·3×2 방어 사각형
		Vector2(0.25, 0.30), Vector2(0.50, 0.30), Vector2(0.75, 0.30),
		Vector2(0.25, 0.65), Vector2(0.50, 0.65), Vector2(0.75, 0.65),
		Vector2(0.10, 0.48), Vector2(0.90, 0.48),
		Vector2(0.15, 0.20), Vector2(0.85, 0.20),
		Vector2(0.15, 0.80), Vector2(0.85, 0.80),
	],
	&"chain_link": [   # W5: 7 — 화공연환·지그재그 연쇄
		Vector2(0.12, 0.30), Vector2(0.35, 0.30), Vector2(0.62, 0.30), Vector2(0.87, 0.30),
		Vector2(0.24, 0.65), Vector2(0.50, 0.65), Vector2(0.75, 0.65),
		Vector2(0.12, 0.65), Vector2(0.87, 0.65),
		Vector2(0.50, 0.10), Vector2(0.50, 0.88), Vector2(0.50, 0.50),
	],
	&"raid_split": [   # W6: 8 — 기습치중·선봉(좌) + 집결 본대(우)
		Vector2(0.10, 0.35), Vector2(0.10, 0.65),
		Vector2(0.55, 0.22), Vector2(0.72, 0.22), Vector2(0.88, 0.22),
		Vector2(0.55, 0.55), Vector2(0.72, 0.55), Vector2(0.88, 0.55),
		Vector2(0.35, 0.50), Vector2(0.35, 0.78),
		Vector2(0.20, 0.78), Vector2(0.72, 0.80),
	],
	&"diminishing": [  # W7: 10 — 감조유인·넓게 흩어진 위장 후퇴
		Vector2(0.10, 0.18), Vector2(0.35, 0.18), Vector2(0.65, 0.18), Vector2(0.90, 0.18),
		Vector2(0.20, 0.50), Vector2(0.45, 0.50), Vector2(0.55, 0.50), Vector2(0.80, 0.50),
		Vector2(0.35, 0.80), Vector2(0.65, 0.80),
		Vector2(0.50, 0.88), Vector2(0.20, 0.88),
	],
	&"pincer": [       # W8: 10 — 퉁마크·양익 열 + 중앙 미끼
		Vector2(0.10, 0.20), Vector2(0.10, 0.40), Vector2(0.10, 0.60), Vector2(0.10, 0.80),
		Vector2(0.38, 0.50), Vector2(0.62, 0.50),
		Vector2(0.90, 0.20), Vector2(0.90, 0.40), Vector2(0.90, 0.60), Vector2(0.90, 0.80),
		Vector2(0.50, 0.50), Vector2(0.50, 0.25),
	],
	&"shock_front": [  # W9: 12 — 폭풍기습·4×3 밀집 돌격
		Vector2(0.25, 0.22), Vector2(0.42, 0.22), Vector2(0.58, 0.22), Vector2(0.75, 0.22),
		Vector2(0.20, 0.52), Vector2(0.38, 0.52), Vector2(0.62, 0.52), Vector2(0.80, 0.52),
		Vector2(0.25, 0.78), Vector2(0.42, 0.78), Vector2(0.58, 0.78), Vector2(0.75, 0.78),
	],
	&"volley_rows": [  # W10: 10 — 삼단철포·전/중/후 3열
		Vector2(0.25, 0.18), Vector2(0.50, 0.18), Vector2(0.75, 0.18),
		Vector2(0.25, 0.50), Vector2(0.50, 0.50), Vector2(0.75, 0.50),
		Vector2(0.15, 0.82), Vector2(0.38, 0.82), Vector2(0.62, 0.82), Vector2(0.85, 0.82),
		Vector2(0.50, 0.35), Vector2(0.50, 0.68),
	],
}

const _LABELS: Dictionary = {
	&"crane_wing":    "학익진 (鶴翼陣) — 양익을 넓게 펼쳐 포위·집중 포격",
	&"lure_ambush":   "청야유인 (淸野誘引) — 미끼로 유인, 퇴로 차단 후 섬멸",
	&"ambush_sides":  "매복기병 역습 — 중앙 얇은 전선 + 양측 기습 협격",
	&"defensive_box": "거점 방어진 — 목책·화차 집중 배치, 다층 종심 방어",
	&"chain_link":    "화공연환 (火攻連環) — 함선 연결 후 화선 돌격, 연쇄 소각",
	&"raid_split":    "기습 치중 소각 — 소수 정예로 보급 기지 야간 강습·소각",
	&"diminishing":   "감조유인 (減竈誘引) — 화덕 수를 줄여 위장 후퇴, 매복 섬멸",
	&"pincer":        "퉁마크 — 전위 교전 후 도주, 양익 기병이 집게 포위",
	&"shock_front":   "폭풍 기습 — 폭우·안개 속 소수 병력 집중 돌격, 장수 직격",
	&"volley_rows":   "삼단 철포 (三段撃ち) — 3열 교대 사격으로 기마 돌격 저지",
}

# 전술 키에 해당하는 라벨 텍스트. 없으면 빈 문자열.
static func label_for(tactic_key: StringName) -> String:
	return String(_LABELS.get(tactic_key, ""))

# 전술 키와 zone 크기를 받아 실제 좌표 배열로 변환한다.
# n이 정규화 좌표 개수보다 많으면 부족분을 균등 분포 폴백으로 채운다.
static func positions_for(tactic_key: StringName, n: int, zone_w: float, zone_h: float) -> Array:
	var norm: Array = _NORMALIZED_POSITIONS.get(tactic_key, [])
	var result: Array = []
	var gap: float = clampf(zone_h / float(max(n, 1)), 40.0, 100.0)
	var top: float = (zone_h - gap * float(n - 1)) * 0.5
	for i in n:
		if i < norm.size():
			result.append(Vector2(norm[i].x * zone_w, norm[i].y * zone_h))
		else:
			result.append(Vector2(zone_w * 0.5, top + gap * float(i)))
	return result
