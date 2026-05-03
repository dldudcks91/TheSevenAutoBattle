# 리팩토링 회귀 스모크 테스트

Godot 공식 패턴 리팩토링(plan: `~/.claude/plans/godot-pure-garden.md`) 진행 중 매 단계 종료 시 통과해야 하는 수동 회귀 시나리오.

베이스라인: `git tag refactor/baseline` (S0 시점)

---

## 6 코어 시나리오

매 단계(S1~S9) 종료 시 다음 6가지를 모두 통과해야 한다.

### 1. 풀 클리어
- 메인메뉴 → 시작
- 1라운드부터 마지막 라운드까지 전부 클리어
- 라운드별 골드 보상이 1회씩만 가산되는지 확인 (`current_round_reward()` 공식대로)
- 마지막 라운드 클리어 후 결과 화면 → 메뉴 복귀 정상

### 2. 패배
- 2라운드를 의도적으로 패배(영웅 1명만 배치 등)
- 결과 화면이 패배 메시지 표시
- 메뉴 복귀 후 다시 시작 → reset_run 정상 (골드/라운드/그리드 초기화)

### 3. 핸드 리롤
- PREP 진입 → 카드 일부를 그리드에 배치(unpaid 상태)
- 리롤 버튼 클릭 (3골드 차감)
- 핸드 갱신, 그리드의 unpaid entry는 그대로 보존되되 hand_idx는 -1로 무효화
- 리롤 후 새 핸드 카드 클릭으로 같은 셀에 추가 가능

### 4. 더미카드 사용
- 강화/스킬/아이템 카드 클릭 → CardInfoPopup 노출
- 사용 버튼 클릭 → 핸드에서 제거, 골드 차감
- 팝업 닫기 시 ModalLayer 정리 정상

### 5. 그리드 스왑
- 셀A에 영웅 배치 (paid 상태로 만들기 위해 1라운드 진행)
- 다음 라운드 PREP에서 셀A→셀B 드래그 (스왑)
- paid 상태 보존, 동일 카드 종류만 같은 셀에 누적 가능 규칙 유지
- 스왑 직후 토큰 표시 정상 (visible 복구)

### 6. 메뉴 복귀
- 결과 화면에서 "메인 메뉴" 버튼
- 메인메뉴 진입 시 Engine.time_scale = 1.0 복구
- 다시 시작 → 새 런 정상

---

## 단계별 추가 검증

### S1 (Scene Unique Names)
- `grep -n '@onready var .* = \$' src/ui/arena_root.gd` → 결과 0건
- 콘솔에 `Cannot find node` 0건

### S2 (BattleSimulator public API)
- `BattleSimulator.get_players()`, `get_enemies()` 정의 존재
- HUD 갱신은 아직 옛 reflection 경로 (S5에서 교체)

### S3 (RunState facade)
- `RunState.economy`, `RunState.roster_store`, `RunState.deployment`, `RunState.progress` 4 모듈 존재
- 외부 호출처(`RunState.gold` / `RunState.hand[i]` / `RunState.grid_cells[i]` 등) 수정 없이 동작
- typed array 보존 PoC: `RunState.hand` 가 `Array[RosterSlot]` 으로 사용 가능한지

### S4 (Phase DTO)
- `BattlePlan`/`BattleResult` 클래스 존재
- 라운드 보상 골드 가산 1회만 (이중 가산 회피 — battle_phase 한 곳만 호출)
- 마지막 라운드 클리어 시 `advance_round()` 호출 안 함

### S5 (UnitInfoHud)
- `_battle.get("_players")` 검색 결과 0건
- 전투 중 HUD 행 갱신 정상

### S6 (Resource 부분 도입)
- `FormationDef.tres` 로드 정상
- 진형이 prep 화면에 정확히 표시

### S7 (prep_phase 분해 a~d)
- 드래그&드롭 모든 케이스 (셀↔셀, 핸드→셀, 셀→핸드(우클릭))
- PlacementZone Callable 3개 (`get_cell_has_unit`, `build_drag_preview`, `can_drop_hand_card`) 정상 연결
- 더미카드 → CardInfoPopup, 영웅카드 → HeroInfoPopup 라우팅
- 같은 셀에 영웅 4명 누적 후 5번째 거부

### S9 (마무리)
- `RunState.deployed`, `enemy_positions`, `last_battle_stats` 필드 grep 0건
- 신규 API(`RunState.economy.gold` 등)로 이행된 호출처 정상

---

## 베이스라인 로그

S0 시점 BattleSimulator의 `[Battle]` 로그 — 단계마다 비교.

캡처 방법: 풀 클리어 1회 실행, 콘솔의 `[Battle] round X/Y start — player=A enemy=B`, `[Battle] end won=true kills=K losses=L gold=+G` 라인 전체를 `docs/baseline_battle_log.txt`로 저장.

비교 기준:
- 라운드별 player/enemy 카운트 일치
- kills/losses 일치
- gold_earned 누적값 일치
