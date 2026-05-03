# TheSevenAutoBattle

## 프로젝트 개요

> 이 파일은 Claude와의 협업 규칙 및 프로젝트 컨텍스트를 담습니다.

---

## 작업 규칙

- **모든 개발 작업 진행 전 `docs/` 폴더의 관련 기획 문서를 확인한다.**
- 코드 변경 전 반드시 현재 파일을 Read한 후 Edit한다.
- 커밋은 사용자가 명시적으로 요청할 때만 생성한다.
- **유닛·몬스터 스탯 데이터는 반드시 `src/data/` 폴더의 CSV 파일로 저장한다. MD 파일에 스탯 표를 작성하지 않는다.**
- **표시 텍스트(이름·설명 등)는 `src/data/i18n/text.csv`에 모은다.** 데이터 CSV의 텍스트 컬럼은 `*_key` 형식의 번역 키(`UNIT_SOLDIER`, `ITEM_BOOTS_BASIC` 등)만 담고, 코드에서 `tr(key)`로 꺼내 쓴다. 데이터 CSV의 `.import`는 `importer="keep"`으로 두어 Godot의 csv_translation 임포터를 거치지 않게 한다(컬럼명이 로케일로 오인됨).

### 규칙 저장 위치

- **프로젝트 규칙·컨벤션은 항상 `.claude/skills/<skill-name>/SKILL.md` 에 작성한다.**
- 메모리(`memory/`)에는 규칙을 넣지 않는다 — 규칙은 휘발되면 안 되고 프로젝트와 함께 버전 관리되어야 하므로 skills가 정확한 위치다.
- 메모리는 사용자 정보·작업 컨텍스트·일시적 사실 등 비-규칙성 메모에만 사용한다.
- 새 규칙이 정해지면: skill 파일을 만들고, 필요하면 CLAUDE.md 또는 기존 skill에서 참조한다.

---

## 게임 개요

- 장르: 오토배틀 + 덱빌딩 (PvE, 스팀 출시 목표)
- 핵심 루프:
  1. 라운드 시작 → 재화 지급, 핸드 5장 추첨 (영웅 / 강화 / 스킬 / 아이템)
  2. 적 유닛 공개
  3. 영웅 카드를 그리드 셀에 드래그로 배치, 비-영웅 카드는 클릭으로 즉시 사용
  4. 필요시 리롤(재화 소모) — 카드만 갈리고 그리드 병사는 보존
  5. 오토배틀 → 클리어
  6. 남은 재화 → 다음 라운드의 핸드에서 활용
- 그리드 병사는 라운드 간 영구 보존 — 사망자 포함 모두 풀 HP로 부활, 비용은 신규 배치분(unpaid)만 차감 (`RunState.grid_cells` + `grid_commit_paid()`)
- 핵심 긴장감: 최소 재화로 클리어할수록 덱 강화 속도가 빨라짐
- 수익모델: 스팀 단일 구매 (인앱결제 없음)

---

## 기술 스택

- Engine: Godot 4 (GDScript)
- Platform: Steam (PC)

---

## 디렉토리 구조

```
src/
  battle/       # 오토배틀 로직
  cards/        # 카드/병사 데이터 및 시스템
  economy/      # 재화 및 업그레이드 시스템
  ui/           # 메인 메뉴 + 영구 셸 (arena_root) + 공용 위젯
    phases/     # SHOP / BATTLE / RESULT phase 서브씬 — 셸 슬롯에 컨텐츠를 채움
  data/         # 밸런스 데이터 (CSV) + i18n 텍스트
    i18n/       # 번역 CSV (keys,ko,en) — Godot이 .translation 파일로 자동 임포트
prototypes/     # 검증용 프로토타입 (프로덕션과 분리)
docs/
  game_design/  # 게임 디자인 문서
  reference/    # 레퍼런스 자료
```

씬 구조: 인게임은 `src/ui/arena_root.tscn`(영구 셸) 1개 + `src/ui/phases/*_phase.tscn` 3개로 분리.
셸이 TopBar / FieldFrame / Divider / 진영 라벨 / PlayerZone / EnemyZone / BattleLayer / HandSlot / BottomBar /
ModalLayer / HudLayer 를 소유하고, phase는 셸 슬롯에 컨텐츠를 add_child 해서 채운다.
`change_scene_to_file`은 메인 메뉴 ↔ ArenaRoot 전환에만 쓴다. 자세한 계약은 `docs/game_design/SCENES.md` 참고.

---

## 게임 디자인 핵심 방향

- 병사는 "교체 가능한 카드"로 취급 (개별 서사 없음)
- 재화 밸런싱이 게임 전체 난이도를 결정하는 핵심 변수
- 적 유닛 정보는 라운드 시작 시 완전 공개 (완전 정보 기반 의사결정)
- 이자 시스템 없음 — 재화는 단순 이월
