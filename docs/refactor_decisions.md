# 리팩토링 의사결정 기록

Godot 공식 패턴 리팩토링(plan: `~/.claude/plans/godot-pure-garden.md`)에서 내려진 설계 결정.

---

## EventBus 도입: 보류

### 결정 (2026-05-03)

전역 EventBus(이벤트 라우터 Autoload)를 도입하지 않는다.

### 근거

1. **현재 통신 토폴로지가 이미 깔끔하다**
   - Phase 전환은 ArenaRoot 1군데로 집중되는 router 패턴 — Phase가 `transition_requested(next, payload)` emit, ArenaRoot가 받아 라우팅.
   - BattlePlan / BattleResult DTO 도입(S4)으로 PREP→BATTLE→RESULT 데이터 흐름이 명시화됨.
   - Unit → BattleSimulator → Phase 시그널 체인도 단방향(자식→부모 emit) 일관.

2. **EventBus의 가치는 다대다 비동기 통지에 있다**
   - 예: 도전과제 시스템이 30개 이벤트(KILL_ENEMY, BUY_ITEM, REROLL_HAND ...) 중 임의 셋을 구독.
   - 예: 사운드 매니저가 게임 로직과 무관하게 이벤트만 듣고 SFX 재생.
   - 현재 프로젝트엔 이런 사용 사례가 없다. 모든 통신이 일대일 또는 일대N(부모→자식)으로 자연스럽게 표현됨.

3. **God EventBus는 안티패턴**
   - 모든 이벤트를 한 Autoload(`EventBus.emit("any_event")`)로 라우팅하면 결국 RunState god-state와 같은 함정에 빠진다.
   - 도입한다면 도메인별 분리 EventBus(AchievementBus, AudioEventBus, TutorialEventBus)를 권장.

### 도입 트리거 (이 중 하나라도 발생하면 재검토)

- **도전과제 시스템 도입** → AchievementBus
  - 게임 진행 중 발생하는 이벤트(킬, 구매, 클리어)에 도전과제 모듈이 동적으로 구독해야 할 때
- **사운드 매니저 분리** → AudioEventBus
  - SFX/BGM 트리거를 게임 로직과 분리해 디자이너가 사운드 정책만 따로 손볼 수 있게 할 때
- **튜토리얼 시스템** → TutorialEventBus
  - 특정 액션 발생 시 튜토리얼 후크가 다음 단계를 활성화해야 할 때
- **분석/텔레메트리 수집**
  - 사용자 행동을 외부로 보내는 트래킹 모듈을 추가할 때(스팀 출시 후 고려)

각 트리거 발생 시: 해당 도메인 EventBus를 별도 Autoload로 추가하되, 이벤트 카탈로그를 enum/StringName으로 명시하고 RunState facade와 동일한 패턴(API 단일화)을 적용.

---

## RunState 분해: facade 우선 점진 마이그레이션 (S3)

### 결정

`RunState` 269줄 god autoload를 한 번에 `Economy`/`RosterStore`/`DeploymentBoard`/`RunProgress` 4 모듈로 갈아엎는 대신, 얇은 facade Autoload를 두고 호출처는 그대로 유지한다.

### 근거

- 외부 호출처 40+ 곳을 한 PR에서 모두 수정하면 머지 충돌 폭발 + 회귀 위험 폭증.
- GDScript의 typed array(`Array[RosterSlot]`)를 getter property로 노출 시 참조가 그대로 유지되므로 `RunState.grid_cells[i] = src` 같은 인덱스 mutate가 facade 너머로 통과.
- S9에서 호출처 단위 PR로 점진적으로 신규 API(`RunState.economy.gold`)로 이행.

---

## Phase 간 통신: DTO 우선 (S4)

### 결정

PREP→BATTLE→RESULT 데이터 전달은 RunState mutable 필드 경유 대신 BattlePlan / BattleResult DTO로 명시 전달.

### 근거

- Phase가 RunState의 `deployed`/`enemy_positions`/`last_battle_stats` 같은 임시 필드를 mutate하던 패턴은 SharedState 안티패턴.
- DTO는 단방향(immutable in spirit)이고 phase 간 인터페이스를 명시.
- `transition_requested(next: int, payload: Variant)` 시그니처 확장으로 ArenaRoot router가 payload를 해당 phase의 `set_payload()`로 주입.

---

## prep_phase 분해: 4단계 분할 권장 (S7)

### 결정

prep_phase 1060줄을 다음 순서로 분리하되 PR 단위를 강제로 나눈다.

| 단계 | 작업 | 위험 | 상태 |
|---|---|---|---|
| S7a | PrepCoordMapper (좌표 변환) | Low | 완료 |
| S7b | EnemyPreviewView, ItemInventoryView | Low | 완료 |
| S7c (부분) | PrepCardStyle (색상 토큰) | Low | 완료 |
| S7c (본격) | HandPanel 컴포넌트 분해 | **High** | **별도 PR로 이월** |
| S7d | GridDeploymentController, PopupRouter | **High** | **별도 PR로 이월** |

### 이월 사유

- HandPanel 분리는 PlacementZone에 주입되는 3개 Callable(`get_cell_has_unit`, `build_drag_preview`, `can_drop_hand_card`)의 와이어링을 깨뜨릴 위험이 매우 큼.
- 드래그&드롭 시그널은 PlacementZone(셸 소유) ↔ HandCard(HandPanel 소속) ↔ Controller 3자 통신이라 owner 분리 후 정상 동작 검증이 필수.
- 게임 실행 검증 없이는 안전 분리 어려움. 다음 PR에서 단계별 게임 실행 회귀 테스트와 함께 진행 권장.

### 후속 작업 가이드

S7c (본격) 시작 시:
1. HandPanel을 RefCounted helper가 아닌 Control Scene으로 분리 (씬이 곧 클래스).
2. PlacementZone Callable 3개를 HandPanel이 아닌 GridDeploymentController가 보유하게 함.
3. _card_to_cell 인덱스 동기화 로직(`_recompute_card_to_cell_from_grid`)을 GridDeploymentController로 이관 시 hand_idx 무효화 타이밍 보존 필수.
4. 매 PR마다 `docs/refactor_smoke.md`의 6 코어 시나리오 + S7 추가 시나리오 6개 통과 확인.
