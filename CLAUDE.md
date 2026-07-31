# TheSevenAutoBattle

## 프로젝트 개요

> 이 파일은 Claude와의 **협업 규칙 + 문서 지도("어디를 봐야 하는지")**만 담는다.
> **게임 디자인·시스템 규칙·수치는 여기에 적지 않는다** — 단일 출처는 [docs/game_design/GAME_DESIGN.md](docs/game_design/GAME_DESIGN.md) 다.

---

## 작업 규칙

- **모든 개발 작업 진행 전 `docs/` 폴더의 관련 기획 문서를 확인한다.**
- 코드 변경 전 반드시 현재 파일을 Read한 후 Edit한다.
- 커밋은 사용자가 명시적으로 요청할 때만 생성한다.
- **유닛·몬스터 스탯 데이터는 반드시 `src/data/` 폴더의 CSV 파일로 저장한다. MD 파일에 스탯 표를 작성하지 않는다.**
- **표시 텍스트(이름·설명 등)는 `src/data/i18n/text.csv`에 모은다.** 데이터 CSV의 텍스트 컬럼은 `*_key` 형식의 번역 키(`UNIT_SOLDIER`, `ITEM_BOOTS_BASIC` 등)만 담고, 코드에서 `tr(key)`로 꺼내 쓴다. 데이터 CSV의 `.import`는 `importer="keep"`으로 두어 Godot의 csv_translation 임포터를 거치지 않게 한다(컬럼명이 로케일로 오인됨).

### 문서 단일 출처 (Single Source of Truth)

- **하나의 결정은 한 곳에만 적는다.** 같은 내용이 두 파일에 있으면, 한쪽만 고쳐졌을 때 어느 쪽이 진실인지 알 수 없게 된다.
- 책임 분리:
  | 무엇 | 어디 |
  |---|---|
  | 수치 (스탯·가격·코스트·확률) | `src/data/**.csv` 또는 코드 상수 |
  | 게임 시스템 규칙·의도·미결 항목 | `docs/game_design/*.md` |
  | 작업 규칙·컨벤션 | `.claude/skills/<skill-name>/SKILL.md` |
  | 협업 규칙 + 문서 지도 | `CLAUDE.md` (이 파일) |
- **CLAUDE.md에 기획 세부를 옮겨 적지 않는다.** 여기에는 방향 감각과 "어디를 봐야 하는지"만 둔다.
- 설계가 바뀌면 **단일 출처 문서를 고치고, 다른 문서의 상충 서술은 그 자리에서 지운다.** 낡은 서술을 남겨두지 않는다.

### 규칙 저장 위치

- **프로젝트 규칙·컨벤션은 항상 `.claude/skills/<skill-name>/SKILL.md` 에 작성한다.**
- 메모리(`memory/`)에는 규칙을 넣지 않는다 — 규칙은 휘발되면 안 되고 프로젝트와 함께 버전 관리되어야 하므로 skills가 정확한 위치다.
- 메모리는 사용자 정보·작업 컨텍스트·일시적 사실 등 비-규칙성 메모에만 사용한다.
- 새 규칙이 정해지면: skill 파일을 만들고, 필요하면 CLAUDE.md 또는 기존 skill에서 참조한다.

---

## 문서 지도 (어디를 봐야 하는지)

> 게임 디자인의 단일 출처는 [GAME_DESIGN.md](docs/game_design/GAME_DESIGN.md) 다. 아래는 주제별 진입점만 둔다.

| 주제 | 문서 |
|---|---|
| **게임 전체 설계** (루프·코스트 경제·전술카드·즉사) — 기획 단일 출처 | [GAME_DESIGN.md](docs/game_design/GAME_DESIGN.md) |
| 전투 규칙·AI·이벤트 | [BATTLE_DESIGN.md](docs/game_design/BATTLE_DESIGN.md) |
| 종족·직업 태그 카탈로그 | [SYNERGY_DESIGN.md](docs/game_design/SYNERGY_DESIGN.md) |
| 유닛 / 스킬 / 웨이브 | [UNIT_DESIGN.md](docs/game_design/UNIT_DESIGN.md) · [SKILL_DESIGN.md](docs/game_design/SKILL_DESIGN.md) · [WAVE_DESIGN.md](docs/game_design/WAVE_DESIGN.md) |
| 아이템/유물 → 전술카드 통합 내역 | [ITEM_DESIGN.md](docs/game_design/ITEM_DESIGN.md) |
| **씬 구조·전환 계약 + 구현 설계 단일 출처**(화면 구성·상태 read/write·씬 계약) | [SCENES.md](docs/game_design/SCENES.md) |
| 의사결정 로그 (왜 그렇게 정했나) | [prototypes/deck_draft_battle/DESIGN_NOTES.md](prototypes/deck_draft_battle/DESIGN_NOTES.md) |

> **주의:** `src/` 프로덕션 코드와 `prototypes/` 는 모두 **폐기된 옛 모델**(누적 그리드 / 덱빌딩 드로우 / 골드 이코노미) 기준이다.
> 현행 **무통화 코스트제 오토체스 육성 모델**은 아직 문서에만 있다. 재설계 범위 → [SCENES.md](docs/game_design/SCENES.md) · 폐기 내역 → [GAME_DESIGN.md §12](docs/game_design/GAME_DESIGN.md)

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
  economy/      # 코스트·업그레이드 시스템
  ui/           # 메인 메뉴 + 영구 셸 (arena_root) + 공용 위젯
    phases/     # (구모델 잔재) phase 서브씬 — 신 모델은 팝업 구조로 대체 예정
  data/         # 밸런스 데이터 (CSV) + i18n 텍스트
    i18n/       # 번역 CSV (keys,ko,en) — Godot이 .translation 파일로 자동 임포트
prototypes/     # 검증용 프로토타입 (프로덕션과 분리)
docs/
  game_design/  # 게임 디자인 문서 (기획 단일 출처)
  reference/    # 레퍼런스 자료
```

> **씬 구조·구현 설계의 단일 출처는 [SCENES.md](docs/game_design/SCENES.md) 다.** 여기에 중복 기술하지 않는다.
