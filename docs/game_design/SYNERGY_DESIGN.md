# 종족·직업 태그 디자인

> 최종 업데이트: 2026-07-29
> **상태: 2026-07-29 전면 개편.** 파일명은 링크 유지를 위해 그대로 두었으나, 내용은 **시너지 문서가 아니라 태그 카탈로그**다.
> **TFT식 임계 단계 시너지는 폐기되었다** → [GAME_DESIGN.md §7](GAME_DESIGN.md). 아래 §5에 폐기 내역과 이유를 남긴다.
> 유닛 식별·역할 정의 → [UNIT_DESIGN.md](UNIT_DESIGN.md) · 유닛 스킬 → [SKILL_DESIGN.md](SKILL_DESIGN.md)

---

## 1. 태그의 역할

1. **모든 아군 유닛은 직업(Class) 1 + 종족(Race) 1을 가진다.** 이 매핑은 유지된다.
2. **태그 자체는 아무 효과도 발생시키지 않는다.** 임계값도, 단계도, 자동 발동도 없다.
3. 태그의 용도는 **조커 조건의 훅**이다 — "Viking 처치 시…", "Knight 코스트 할인", "Mage가 3기 이상일 때…" 등 조커가 참조하는 분류 키.
4. 부차 용도: 카드 표기·필터·정보 가독성 (플레이어가 편성을 읽는 언어).
5. 적 진영은 태그 시스템에 참여하지 않는다 — 적은 "이 라운드 위협이 무엇인가"가 명확하기만 하면 된다.

> **왜 효과를 떼어냈나:** 뽑기 변주가 있는 덱빌딩에서는 "보드에 특정 종족 N종"을 안정적으로 맞출 수 없다.
> 임계 시너지는 편성을 통제할 수 있을 때만 성립하는 장치라, 드로우가 개입하는 순간 운 게임이 된다.
> 빌드 정체성은 **소유한 상시 조커**가 대신 짊어진다.

---

## 2. 직업 카탈로그 (9개)

| 직업 | 역할 키워드 | 메커닉 방향 |
|---|---|---|
| **Knight** | 탱커·방패 | 전선 흡수·도발·방어 강화 |
| **Warrior** | 전선 근접 | 안정적인 근접 딜·맷집 |
| **Spearman** | 장거리 근접 | 사거리 있는 근접·기마 카운터 |
| **Rider** | 기마 | 빠른 측면 침투·후방 노림 |
| **Archer** | 원거리 물리 | 안전한 후방 딜 |
| **Assassin** | 암살 | 후방 침투·고가치 처치 |
| **Mage** | 마법 딜 | 방어 무시·범위 |
| **Priest** | 치유·버프 | 아군 유지·강화 |
| **General** | 지휘관 | 주변 아군 강화·전체 명령 효과 |

> 이 "메커닉 방향"은 **유닛 고정 스킬**([SKILL_DESIGN.md](SKILL_DESIGN.md))로 구현된다. 태그 발동 효과가 아니다.

---

## 3. 종족 카탈로그 (5개)

| 종족 | 톤 | 컨셉 방향 |
|---|---|---|
| **Humans** | 정통 왕국군 | 다재다능 |
| **Vikings** | 북방 광폭 전사단 | 광폭화 — 피해 받을수록 강해지는 결투 컨셉 |
| **Beastmen** | 수인 야생 동맹 | 야성·기동 |
| **OrderOfTheFire** | 화염 광신 교단 | 화염 피해·지속 화상 |
| **DarkElves** | 어둠 마법·암살 도시 | 마법·암살·디버프 |

---

## 4. 직업 × 종족 매트릭스

| 직업 \ 종족 | Humans | Vikings | Beastmen | OrderOfTheFire | DarkElves |
|---|---|---|---|---|---|
| **Knight** | ShieldMan | VikingSwordman | BearWarrior | FirePrince | DarkElfGuard |
| **Warrior** | SwordMan | VikingBerserker | FoxSwordsman | FireWarrior | DarkElfSwordsman |
| **Spearman** | SpearMan | VikingSpearman | PandaWarrior | — | — |
| **Rider** | CavalierMan | VikingHorseman | — | — | DarkElfRider |
| **Archer** | ArcherMan | VikingArcher | WolfPathfinder | — | DarkElfArcher |
| **Assassin** | — | — | CatRobber | — | DarkElfAssassin |
| **Mage** | Mage | — | RabbitWizard | FireMage | DarkElfWizard |
| **Priest** | ArchMage | — | DeerDruid | FirePriestess | DarkElfSorceress |
| **General** | KingMan | VikingJarl | LionKnight | FirePrincess | DarkElfSpellstealer |

**제약**
- 각 종족 안에서 같은 직업이 두 번 등장하지 않는다 (일대일 매핑).
- 유닛 추가/교체 시 표에 비대칭이 생길 수 있으나, 한 종족 안의 직업 중복은 만들지 않는 것을 원칙으로 둔다.

> 조커가 태그를 훅으로 쓰므로, **한 태그에 속한 유닛이 너무 적으면 그 태그를 노리는 조커가 죽은 카드가 된다.**
> 조커 카탈로그를 짤 때 위 표의 빈칸(—) 분포를 반드시 확인할 것.

---

## 5. 폐기된 임계 시너지 시스템 (2026-07-29)

아래는 **전부 무효**다. 코드·데이터에 잔재가 있으면 제거 대상이다.

| 폐기 항목 | 내용 | 대체 |
|---|---|---|
| 단계제 발동 | 임계 명수 도달 시 효과가 한 단계씩 강화 | **조커** ([GAME_DESIGN.md §7](GAME_DESIGN.md)) |
| 직업 임계값 표 | Knight 2/4/6, Warrior 2/4/6 등 | 없음 — 태그는 효과 없음 |
| 종족 임계값 표 | Humans 3/6/9 등 | 없음 |
| **General ==1 "대장" 규칙** | General 종류가 정확히 1일 때만 발동 | 없음 — 컨셉은 조커로 재활용 가능 |
| **Priest 1 OR 4 "Soloist" 분기** | 정확히 1 또는 4일 때만 발동 | 없음 — 컨셉은 조커로 재활용 가능 |
| **휘장(Emblem)** | 풀빌드 도달용 9번째 유닛 추가 획득 | 없음 — 풀빌드 개념 자체가 사라짐 |
| 종류 단위 카운트 규칙 | 같은 종류를 여러 셀에 둬도 카운트 1 | 없음 — 1칸 1유닛이라 누적 개념이 없음 |
| 시너지 패널 UI | 발동 단계 실시간 표시 | 조커 목록 + 전력 지표로 대체 |
| 배치 시점 스냅샷 규칙 | 전투 시작 시 카운트 고정 | 없음 |

**데이터 영향** — `src/data/synergies.csv` 의 `threshold_*` / `effect_*` 컬럼은 무효다.
`type`(CLASS/RACE)과 `key`(태그 식별자), 표시명 키만 유효하며, 조커 조건이 참조하는 태그 사전으로만 남는다.

> General·Priest의 특수 규칙은 **버려진 것이 아니라 갈 곳이 바뀐 것**이다.
> "지휘관은 한 명일 때 강하다", "사제는 혼자거나 넷일 때 의미가 있다" 같은 컨셉은
> 조커 조건("General 태그가 정확히 1기일 때…")으로 그대로 이식할 수 있다. 조커 카탈로그 작업 시 후보로 검토.

---

## 6. 미결 항목

| 항목 | 상태 |
|---|---|
| 태그별 유닛 수 균형 | 미결 — 조커 훅이 죽은 카드가 되지 않도록 §4 빈칸 분포 점검 필요 |
| 조커가 참조할 태그 조건 문법 | 미결 — 조커 카탈로그 설계와 함께 |
| General·Priest 특수 컨셉의 조커 이식 | 미결 — §5 하단 |
| `synergies.csv` 스키마 정리 | 미결 — 무효 컬럼 제거 |
| 적 진영 태그 노출 여부 | 미결 — 카운터 픽 가독성 목적으로만 표기할지 |
