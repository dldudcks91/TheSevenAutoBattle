# 씬 구조와 전환 계약 (개발 문서)

> 이 문서는 **엔지니어링 레퍼런스**다. 어떤 씬이 어떤 상태를 읽고/쓰며 어떻게 전환되는지 정의한다.
> 게임 디자인 의도는 `GAME_DESIGN.md` 참고.
> **수치(밸런스 값)는 본 문서에 적지 않는다** — 데이터 파일/`RunState` 상수에서만 관리.

---

## 핵심 모델 — 영구 셸 + Phase 서브씬

인게임은 **단 하나의 루트 씬** `src/ui/arena_root.tscn` 위에서 진행된다. 사용자 시점에서는 한 화면이 계속 유지되고, 내부 컨텐츠만 SHOP → BATTLE → RESULT 로 갈린다.

```
MainMenu (src/ui/main_menu.tscn)
   │  "게임 시작" → RunState.reset_run() → change_scene_to_file(arena_root)
   ▼
ArenaRoot (src/ui/arena_root.tscn)
   ├─ 영구 셸 — 게임 종료까지 한 번도 destroy 되지 않음
   │   (Backdrop / TopBar / FieldFrame / Divider / 진영 라벨 /
   │    PlayerZone / EnemyZone / BattleLayer / HandSlot / BottomBar /
   │    ModalLayer / HudLayer + UnitInfoHud)
   │
   └─ PhaseContainer
         └─ 현재 phase 씬 1개만 살아있음 (instantiate ↔ queue_free 로 갈림)
              ├─ ShopPhase   (src/ui/phases/shop_phase.tscn)
              ├─ BattlePhase (src/ui/phases/battle_phase.tscn)
              └─ ResultPhase (src/ui/phases/result_phase.tscn)

   ※ "메인 메뉴로" 또는 RUN CLEAR/DEFEAT → change_scene_to_file(main_menu)
```

`change_scene_to_file`은 **메인 메뉴 ↔ ArenaRoot** 사이에서만 호출한다. SHOP/BATTLE/RESULT 사이에서는 절대 호출하지 않는다 (`PhaseContainer` 자식 갈아끼움 + 셸 슬롯 자식 갈아끼움으로 처리).

---

## 영구 셸이 절대 깨지지 않는 규칙

1. **셸 노드는 phase 진입/탈출 시점에 destroy/free 되지 않는다.** 자식만 add/clear 된다.
2. **셸 노드의 위치·크기는 phase가 바꾸지 않는다.** 좌표/스타일은 `arena_root.tscn`에서만 정의.
3. **phase가 추가하는 자식은 자기가 만든 것뿐.** 셸의 영구 자식(ColorRect / Divider / Label 등)은 건드리지 않는다.
4. **phase 전환 직후 한 프레임이라도 "빈 화면"이 보이면 안 된다.** 셸이 그대로 남으므로 자연스러운 페이드/슬라이드 추가도 가능.

이 규칙을 따르면 사용자 시점에서 화면 골격은 절대 깜박이지 않는다.

---

## 셸 노드 트리 — `arena_root.tscn`

```
ArenaRoot (Control, script: arena_root.gd)
├─ Backdrop (ColorRect)                       [SHELL · 항상 표시]
├─ TopBar (HBoxContainer)                     [SHELL · 항상 표시]
│  ├─ RoundLabel
│  ├─ GoldLabel
│  └─ PhaseHintLabel
│
├─ ArenaCanvas (Control)                      [SHELL · 항상 표시]
│  ├─ FieldBackground (ColorRect)             [SHELL]
│  ├─ FieldBorder (ReferenceRect)             [SHELL]
│  ├─ Divider (ColorRect)                     [SHELL]
│  ├─ PlayerLabel / EnemyLabel (Label)        [SHELL]
│  ├─ PlayerZone (PlacementZone)              [SHELL · 컨테이너만, phase가 자식 채움]
│  ├─ EnemyZone (Control)                     [SHELL · 컨테이너만, phase가 자식 채움]
│  └─ BattleLayer (Node2D)                    [SHELL · 컨테이너만, BATTLE에서 시뮬레이터 add_child]
│
├─ HandSlot (Control)                         [SHELL · 항상 위치 고정]
│  └─ <SHOP 진입 시에만 핸드 컨텐츠 채움>
│
├─ BottomBar (HBoxContainer)                  [SHELL · 항상 위치 고정]
│  └─ <phase가 자기 버튼들 채움>
│
├─ PhaseContainer (Control)                   [phase 인스턴스 부모]
│  └─ <현재 phase의 .tscn 인스턴스 1개>
│
├─ ModalLayer (CanvasLayer, layer=8)
│  └─ <phase가 띄우는 모달 (상점 오퍼 / 결과 모달)>
│
└─ HudLayer (CanvasLayer, layer=10)
   └─ UnitInfoHud (instance, visible=false → BATTLE에서만 true)
```

---

## Phase 통신 + 슬롯 주입 계약

루트는 phase 인스턴스를 만들 때 셸 슬롯들의 참조를 `bind_shell()`로 주입한다.

```gdscript
# arena_root.gd
enum PhaseId { SHOP, BATTLE, RESULT }

func _set_phase(next: int) -> void:
    _clear_shell_slots()  # PlayerZone/EnemyZone/BattleLayer/HandSlot/BottomBar/ModalLayer 자식 비움
    for c in _phase_container.get_children():
        c.queue_free()
    var inst := _scene_for_phase(next).instantiate()
    inst.bind_shell({
        "player_zone": _player_zone, "enemy_zone": _enemy_zone, "battle_layer": _battle_layer,
        "hand_slot": _hand_slot, "bottom_bar": _bottom_bar, "modal_layer": _modal_layer,
        "info_hud": _info_hud, "top_bar": self,
    })
    inst.transition_requested.connect(_set_phase)
    inst.main_menu_requested.connect(_to_main_menu)
    _phase_container.add_child(inst)
```

phase 공통 인터페이스:

```gdscript
# phases/*.gd 가 모두 따르는 형태
signal transition_requested(next: int)   # PhaseId
signal main_menu_requested

var shell: Dictionary
func bind_shell(s: Dictionary) -> void:
    shell = s
```

phase는 자기 노드 트리에 거의 아무것도 안 가지고, 셸 슬롯을 **빌려서** 채운다. phase 종료 시 셸 슬롯 자식은 루트의 `_clear_shell_slots()`가 일괄 정리한다.

---

## 데이터 모델 — 3×3 영구 그리드

플레이어는 **3×3 그리드에 배치된 병사를 런 전체에 걸쳐 소유한다.** 영구 자산은 골드, 아이템 인벤토리, **그리드(배치된 병사 + 레벨)**다.

`RosterSlot`은 **"이 종류의 병사가 게임에 등장 가능하다 + 이 아이템들이 부착돼 있다"** 의 의미.

### `RosterSlot` (`src/cards/roster_slot.gd`)
| 필드 | 의미 |
|------|------|
| `unit_data: UnitData` | 종류 정의 (HERO 카드만 의미 있음) |
| `items: Array[ItemData]` | 종류에 부착된 아이템 (max `MAX_ITEMS = 3`). 그 종류로 고용된 모든 인스턴스에 일괄 적용 |
| `kind: int` (`GameEnums.CardKind`) | 핸드 슬롯의 카드 종류 — `HERO` / `UPGRADE` / `SKILL` / `ITEM`. HERO 만 그리드 배치 가능, 나머지는 클릭 1회 소모 (현재 더미). |
| `dummy_price: int` | HERO 외 카드의 가격. HERO는 `RunState.hire_price_for()` 사용. |
| `dummy_name: String` | HERO 외 카드의 표시명. UPGRADE는 `tr(unit_data.name_key)` 로 현재 로케일에 맞춰 조립. SKILL/ITEM 더미는 현재 한글 풀 직삽 — 실효 도입 시 i18n 키로 교체 예정. |

### `RunState` 핵심 필드
| 필드 | 타입 | 책임 phase (write) | 소비 phase (read) |
|------|------|----------------|---------------|
| `gold` | `int` | SHOP(고용 결제·리롤·더미 카드 사용), BATTLE(보상) | 모든 phase |
| `roster` | `Array[RosterSlot]` | (예약 — 평면 인덱스가 필요해질 때 사용. 현재는 `grid_cells` 가 영구 군대를 보관) | 모든 phase |
| `grid_cells` | `Array[Array[{slot, paid, hand_idx}]]` (길이 9) | SHOP(배치/스왑/회수/`grid_commit_paid`), `reset_run` | SHOP, BATTLE(간접: `deployed` 경유) |
| `hand` | `Array[RosterSlot]` | `roll_hand()`(런 시작·라운드 전환·리롤) | SHOP |
| `inventory` | `Array[ItemData]` | SHOP | SHOP |
| `deployed` | `Array[{slot, positions}]` | SHOP | BATTLE |
| `enemy_positions` | `Array[Vector2]` | SHOP | BATTLE |
| `last_battle_stats` | `Dictionary` | BATTLE | RESULT |

### 핸드 시스템

매 라운드 진입 시 `RunState.roll_hand()` 가 `HAND_OFFER_COUNT` 장(기본 5)을 추첨해 `RunState.hand` 에 채운다.

**카드 종류 (랜덤 가중치):**
| Kind | 비율 | 동작 |
|------|------|------|
| HERO | 60% | `UnitDB.all_player_units()` 에서 1종 추첨. SHOP에서 그리드 셀에 드래그 → 전투 시작 시 일괄 결제. |
| UPGRADE | 14% | 더미 — 랜덤 영웅 강화 표시. 클릭 1회 소모(즉시 결제). |
| SKILL | 13% | 더미 — 스킬명 풀에서 1개. 클릭 1회 소모. |
| ITEM | 13% | 더미 — 아이템명 풀에서 1개. 클릭 1회 소모. |

**리롤:** SHOP 의 핸드 좌측 리롤 버튼 → `RunState.reroll_hand()` (REROLL_COST 차감 후 `roll_hand()`).
- 리롤은 **카드만 갱신**한다 — 그리드에 이미 배치된 병사는 유지된다 (셀이 RosterSlot 참조를 캡처).
- 리롤 직후 shop_phase는 `RunState.grid_invalidate_unpaid_hand_indices()` 를 호출해 unpaid entry의 `hand_idx`를 모두 -1로 무효화한다.
- 리롤 후 그리드에서 우클릭으로 빼낸 unpaid 카드는 핸드로 복귀하지 않고 폐기된다.

**1회용 규칙:** 한 번 셀에 올리거나 클릭으로 사용한 카드는 핸드에서 사라진다.
HERO는 셀 우클릭 시 같은 라운드 내(리롤 전)라면 핸드로 복귀, 그 외엔 폐기.

`last_battle_stats` 키: `won, kills, losses, gold_earned, round_index, was_last_round`

### 고용 가격
- `RunState.hire_price_for(unit_data) = unit_data.cost × HIRE_PRICE_PER_COST` — 종류별 차등.
- `unit_data.cost` 는 [src/data/units/units.csv](../src/data/units/units.csv) 의 `cost` 컬럼.
- `HIRE_PRICE_PER_COST` 값은 [src/data/balance.csv](../src/data/balance.csv) 에서 관리.

phase 간 데이터 전달은 **`RunState` 오토로드 한 곳을 통해서만** 이뤄진다. phase끼리 직접 참조하지 않는다.

---

## Phase별 계약

### 1. ShopPhase (`src/ui/phases/shop_phase.tscn`)

**목적:** 적 편성을 보고 핸드(랜덤 5장)에서 카드를 골라 그리드를 채우고 전투를 시작.

**셸 슬롯 사용:**
| 슬롯 | 컨텐츠 |
|------|--------|
| `player_zone` | 3×3 셀 배경 + 배치된 토큰. PlacementZone 시그널(`place_requested`/`remove_requested`/`swap_requested`/`drag_started`/`drag_ended`)을 phase가 connect |
| `enemy_zone` | 적 프리뷰 토큰 (이번 라운드 적군) |
| `hand_slot` | 좌측 리롤 버튼 + 핸드카드 5장 (HERO 드래그 / UPGRADE·SKILL·ITEM 클릭 소모) |
| `bottom_bar` | [요약 라벨] [전투 시작] |
| `modal_layer` | 비움 |

**읽음:** `RunState.gold`, `RunState.hand`, `RunState.current_enemy_lineup()`
**씀(즉시):** `gold` (리롤 비용, 더미 카드 사용 비용), `hand` (리롤로 재추첨)
**TopBar 연동:** 배치 변경마다 `shell.top_bar.set_gold_preview(spent)` 호출 → "Gold: G  (예정 −S → 잔여 R)" 표시. 리롤·더미 사용 후 `refresh_gold()`.

**셀 상태 모델 (영구 그리드 — 라운드 간 보존):**
- `RunState.grid_cells[i]: Array[Dictionary]` — `{slot: RosterSlot, paid: bool, hand_idx: int}` 엔트리 리스트.
- `slot` 은 배치 시점의 RosterSlot 참조. `hand` 갱신·라운드 전환과 무관하게 유지.
- `paid==true` 는 이전 라운드들에서 비용 차감 완료된 영구 자산. 라운드 사이 보존되며 우클릭 회수 불가.
- `paid==false` 는 이번 SHOP에 갓 추가된 미결제 — 우클릭 회수 가능, "전투 시작" 시 일괄 spend 후 paid로 확정.
- `hand_idx` 는 unpaid entry 의 hand 슬롯 인덱스 (paid는 -1). 회수 시 hand의 같은 RosterSlot을 가리킬 때만 카드 핸드 복귀.
- 시각: 셀에 unpaid entry가 1개 이상 있으면 외곽선 골드, 모두 paid면 회색.
- `_card_to_cell[hand_idx]`: -1=대기, ≥0=배치된 셀, -2=더미 사용 후 영구 소모. unpaid entry만 등록됨 (paid는 hand_idx=-1 이라 자동 제외).

**커밋 시점에만 (전투 시작 누르는 순간):**
1. `RunState.spend(unpaid_total)` — 이번 라운드 신규(unpaid) 배치 비용만 차감. paid 영구 자산은 재차감 없음.
2. `RunState.grid_commit_paid()` — 모든 unpaid entry를 `paid=true`로 마킹, `hand_idx=-1`로 초기화.
3. `RunState.deployed = [{slot, positions}, ...]` — 셀별 RosterSlot + 배틀 좌표 (paid/unpaid 무관 모든 entry 출전).
4. `RunState.enemy_positions = [Vector2, ...]` — 적 프리뷰 토큰의 글로벌 좌표 (BATTLE에서 그대로 스폰)
5. `transition_requested.emit(PhaseId.BATTLE)`

**좌표 매핑 규칙 (SHOP ↔ Battle 일치):**
- 플레이어 시작 좌표 = `shell.player_zone.global_position + cell_center + stack_offset` (PlayerZone 안의 토큰 글로벌 좌표 그대로).
- 적 시작 좌표 = EnemyZone 프리뷰 토큰의 글로벌 좌표 그대로 (`_collect_enemy_positions()`).
- **SHOP 화면에서 보이던 위치에서 곧바로 전투가 시작된다** — 별도의 BATTLE 좌표계로 리매핑하지 않는다.
- 토큰/유닛 sprite 스케일은 모두 `unit_data.sprite_scale * 0.75` 로 통일 (핸드 초상화 / 드래그 프리뷰 / 필드 토큰 / 전투 유닛 동일).

**되돌아가기 안전성:** HERO 배치/제거는 SHOP 안에서만 카운터 조작 — `gold` 차감 없음. 단 리롤·더미 카드 사용은 즉시 차감.

---

### 2. BattlePhase (`src/ui/phases/battle_phase.tscn`)

**목적:** 전투 시뮬레이션만. UI는 거의 없음.

**셸 슬롯 사용:**
| 슬롯 | 컨텐츠 |
|------|--------|
| `battle_layer` | `BattleSimulator` 인스턴스 (시뮬레이터가 자기 유닛/투사체를 자식으로 스폰) |
| `info_hud` | `visible = true` 로 켜고 시뮬레이터에 ref 주입 |
| 그 외 슬롯 | 비움 |

**읽음:** `RunState.deployed`, `RunState.enemy_positions`, `RunState.current_enemy_lineup()`
**씀:** 전투 종료 시 시뮬레이터가 `RunState.last_battle_stats` 기록, 승리 시 `grant_round_reward()` 후 `advance_round()` (마지막 라운드면 advance 안 함)

**Unit Info HUD:** 전투 중 유닛 클릭 → `shell.info_hud.set_unit(u)` 로 표시. 사망 후 1초 자동 닫힘.

**전환:** 시뮬레이터의 `battle_ended` → 1.2초 딜레이 → `transition_requested.emit(PhaseId.RESULT)`

핵심: **필드 프레임은 셸 소속이라 그대로 보이고, 그 위에서 시뮬레이터가 돈다.** 사용자 눈에는 SHOP에서 본 그 필드 위에서 전투가 자연스럽게 시작되는 모습.

---

### 3. ResultPhase (`src/ui/phases/result_phase.tscn`)

**목적:** 한 라운드의 결과·통계를 보여주고 다음 단계로 보낸다.

**셸 슬롯 사용:**
| 슬롯 | 컨텐츠 |
|------|--------|
| `modal_layer` | 결과 모달 (헤드라인 / 처치·손실 / 골드 / 버튼) |
| 그 외 슬롯 | 비움 |

**읽음:** `RunState.last_battle_stats`, `RunState.gold`, `RunState.current_round`
**씀:** 없음

**표시:**
- 헤드라인: "VICTORY" / "DEFEAT" / "RUN CLEAR"
- 라운드 N 통계: 처치 수, 손실 수, 획득 재화
- 현재 골드 합계
- 버튼: 승리 & 미종료 → [메인 메뉴] [다음 라운드] / 그 외 → [메인 메뉴]만

**전환:**
- "다음 라운드" → `transition_requested.emit(PhaseId.SHOP)` (승리 & 미종료)
- "메인 메뉴" → `main_menu_requested.emit()` (RUN CLEAR / DEFEAT 또는 도중 탈출)

---

## Phase 전환 매트릭스

| From → To | 트리거 | RunState 변경 |
|-----------|--------|---------------|
| MainMenu → ArenaRoot(SHOP) | "게임 시작" | `reset_run()` (안에서 `roll_hand()` + `grid_cells` 빈 9-length 초기화) |
| SHOP → BATTLE | "전투 시작" | `spend(unpaid_total)` + `grid_commit_paid()` + `deployed = [...]` + `enemy_positions = [...]` |
| BATTLE → RESULT | 전투 종료 + 1.2초 | 시뮬레이터가 `last_battle_stats=`, 승리 시 `grant_round_reward()`+`advance_round()` (안에서 `roll_hand()`) |
| RESULT → SHOP | "다음 라운드" (승리 & 미종료) | 없음 |
| RESULT → MainMenu | "메인 메뉴" (RUN CLEAR / DEFEAT) | 없음 (다음 진입 시 reset_run) |
| (모든 phase) → MainMenu | "메인 메뉴" | 없음 |

---

## 미결·다음 슬라이스로 미루는 것

- **출전 코스트 한도**: SHOP에 표시만, 강제 제한은 다음 슬라이스
- **전투 결과 디테일**: 유닛별 데미지·MVP 표시 등은 다음 슬라이스
- **아이템 구매 UI**: 아이템 구매 진입점 미결 (ShopPhase 내 모달 또는 별도 페이즈)
- **phase 전환 트랜지션 효과**: 영구 셸이 그대로 남으므로 페이드/슬라이드 인 가능. 지금은 즉시 교체
- **UPGRADE / SKILL / ITEM 카드 실제 효과**: 현재 더미(클릭 시 골드만 차감, 효과 없음). 실효 동작은 후속 슬라이스에서 구현.
- **셀 비우기/판매 (paid entry 처분)**: 영구 자산을 우클릭 회수하거나 판매·환불하는 동선 미구현. 현재는 추가 + 셀 간 스왑만 허용.
- **`RunState.roster` 평면 인덱스**: `grid_cells`(셀 단위)가 영구 군대를 보관. 평면 roster 가 필요한 시점(예: 글로벌 영웅 일괄 강화 UI)에 결정.
