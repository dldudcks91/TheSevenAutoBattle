class_name Joker
extends RefCounted

# 상시 슬롯 계층. 덱과 분리되어 뽑기에 안 섞이고 항상 켜져 있다 (GAME_DESIGN §7).
# 전투 이벤트를 구독해 생산/소비 체인을 만든다 — 엔진 연결은 슬라이스 4.
# 사용 비용이 없으므로 밸런스는 획득 게이팅으로만 잡는다.

var id: StringName
var name_key: String = ""
var desc_key: String = ""

# 구독하는 전투 이벤트 (GameEnums.BattleEvent). 생산/소비 측 모두 이 훅을 쓴다.
var trigger: GameEnums.BattleEvent = GameEnums.BattleEvent.KILL
# 결선 방식 — 직결형(이벤트→효과) / 버스형(기세 생산·소비).
var link: GameEnums.JokerLink = GameEnums.JokerLink.DIRECT

# 효과 파라미터 (생산량 / 페이오프 임계 등). 슬라이스 4 엔진이 해석.
var effect: Dictionary = {}
# 단점형(강효과+대가) 페널티. 없으면 비어있음.
var downside: Dictionary = {}
# 태그 빌드어라운드 조건 {race:..., class:...}. 없으면 비어있음.
var tag_hook: Dictionary = {}

func has_downside() -> bool:
	return not downside.is_empty()
