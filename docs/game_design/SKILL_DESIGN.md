# 유닛 스킬 설계

> 최종 업데이트: 2026-07-29
> 유닛 식별·역할 → [UNIT_DESIGN.md](UNIT_DESIGN.md)
> 종족·직업 태그 → [SYNERGY_DESIGN.md](SYNERGY_DESIGN.md)
>
> **2026-07-29 개편 영향:** 이 문서의 설계 원칙과 스킬 구조는 그대로 유효하다.
> 다만 스킬이 발행하는 이벤트(처치·상태이상 부여 등)가 이제 **조커 엔진의 생산처**를 겸한다 → [BATTLE_DESIGN.md §9](BATTLE_DESIGN.md).
> 스킬 어휘를 늘릴 때는 "이 스킬이 어떤 조커와 맞물리는가"를 함께 본다.

---

## 1. 디자인 원칙

1. **유닛당 고정 1스킬** — 모든 유닛은 정확히 하나의 고유 스킬을 가진다. 카드로 추가 부여하지 않으며, 카드로 교체하지도 않는다.
2. **Trigger = 정체성의 행동** — "이 유닛이라면 이 순간에 무언가를 한다"가 자연스럽게 느껴지는 트리거를 고른다. 메커닉에서 트리거를 역산하지 않는다.
3. **조커 계층과 분리** — 유닛 스킬은 그 유닛 단독의 행동만 정의한다. 빌드 정체성을 만드는 상시 효과는 조커가 담당한다 → [GAME_DESIGN.md §7](GAME_DESIGN.md). (직업·종족 태그에는 자체 효과가 없다)
4. **PvE 카운터 픽 가시화** — 적 스킬은 "어떤 아군을 쓰면 쉬워지는가"가 플레이어 눈에 보여야 한다.

---

## 2. 스킬 구성 구조

스킬 하나를 완전히 서술하는 6개 축.

| 축 | 정의 |
|---|---|
| **Trigger** | 언제 발동하는가 |
| **Subject** | 누가 이 트리거를 감지하는가 (Self / 아군 전체 / 전 유닛) |
| **Condition** | 트리거 외 추가 조건 (없으면 —) |
| **Effect** | 무엇을 하는가 (키워드 또는 직접 서술) |
| **Target** | 누구에게 적용되는가 |
| **Duration** | 얼마나 지속되는가 |

---

## 3. 트리거 어휘

트리거는 성격에 따라 세 종류로 나뉜다. 실행 모델이 다르므로 구현 시 주의.

| 종류 | 트리거 | 시점 |
|---|---|---|
| **이벤트형** | **On-Deploy** | 배치 직후 1회 |
| 이벤트형 | **On-Attack** | 공격 발생 시 (피해 적용 포함) |
| 이벤트형 | **On-Kill** | 적 처치 직후 |
| 이벤트형 | **On-Ally-Death** | 아군 사망 직후 |
| 이벤트형 | **On-Death** | 자기 사망 직후 (1회) |
| **임계형** | **On-Damaged-Below-X%** | 자기 체력이 임계치 아래로 떨어지는 순간 1회 |
| **지속형** | **Aura** | 매 틱 지속 적용 |
| 지속형 | **Periodic** | 일정 간격마다 반복 |

---

## 4. 키워드 라이브러리

### 기본 키워드

| 키워드 | 정의 |
|---|---|
| **Strike** | 단일 대상에게 피해 |
| **Cleave** | 범위 내 대상에게 피해 |
| **Heal** | 대상 체력 회복 |
| **Lifesteal** | 가한 피해의 일부만큼 자신 체력 회복 |
| **Buff ATK** | 공격력 증가 |
| **Buff Armor** | 방어력 증가 |
| **Taunt** | 적이 이 유닛을 우선 타겟으로 삼음 |

### 상태이상

| 키워드 | 정의 |
|---|---|
| **Stun** | 행동 불가 |
| **Freeze** | 이동 속도 감소 |
| **Poison** | 매 틱 지속 피해 |
| **Burn** | 피격 시 추가 피해 |

> 키워드의 구체 수치(피해량·회복량·지속·간격)는 모두 데이터 파일에서 관리. 본 문서는 의도만 다룬다.

---

## 5. 아군 유닛별 스킬 (35종)

> 모든 아군 유닛은 고유 스킬을 정확히 1개 가진다. 표는 정체성을 짧게 명시하는 자리이며, 발동 트리거·효과의 구체 수치는 데이터 파일에서 관리한다.

### 5.1 Humans

| 유닛 | 직업 | 스킬 정체성 (TBD) |
|---|---|---|
| ShieldMan | Knight | 방패 막기 — 피격 시 일부 피해 흡수 |
| SwordMan | Warrior | TBD |
| SpearMan | Spearman | TBD |
| CavalierMan | Rider | TBD |
| ArcherMan | Archer | TBD |
| Mage | Mage | TBD |
| ArchMage | Priest | 신성+학술 마법 — 회복 또는 보호 |
| KingMan | General | 왕의 명령 — 주변 아군 전체 강화 |

### 5.2 Vikings

| 유닛 | 직업 | 스킬 정체성 (TBD) |
|---|---|---|
| VikingSwordman | Knight | TBD |
| VikingBerserker | Warrior | 광폭화 — 체력 임계 이하에서 공격 폭증 |
| VikingSpearman | Spearman | TBD |
| VikingHorseman | Rider | TBD |
| VikingArcher | Archer | TBD |
| VikingJarl | General | 함성 — 주변 아군 광폭화 |

### 5.3 Beastmen

| 유닛 | 직업 | 스킬 정체성 (TBD) |
|---|---|---|
| BearWarrior | Knight | 곰 가죽 — 받는 피해 감소 |
| FoxSwordsman | Warrior | TBD |
| PandaWarrior | Spearman | TBD |
| WolfPathfinder | Archer | TBD |
| CatRobber | Assassin | 그림자 침투 — 후방 타겟팅 또는 처치 시 강화 |
| RabbitWizard | Mage | TBD |
| DeerDruid | Priest | 자연의 가호 — 아군 회복 |
| LionKnight | General | 사자의 기백 — 주변 아군 공격력 강화 |

### 5.4 OrderOfTheFire

| 유닛 | 직업 | 스킬 정체성 (TBD) |
|---|---|---|
| FirePrince | Knight | 불의 갑주 — Taunt + 화상 반사 |
| FireWarrior | Warrior | TBD |
| FireMage | Mage | 화염구 — 주기적 마법 피해 |
| FirePriestess | Priest | 신성한 화염 — 아군 회복 + 적 화상 |
| FirePrincess | General | 불의 명령 — 주변 아군 공격에 화상 부여 |

### 5.5 DarkElves

| 유닛 | 직업 | 스킬 정체성 (TBD) |
|---|---|---|
| DarkElfGuard | Knight | TBD |
| DarkElfSwordsman | Warrior | TBD |
| DarkElfRider | Rider | TBD |
| DarkElfArcher | Archer | TBD |
| DarkElfAssassin | Assassin | 단검·독 — 후방 침투, 지속 피해 |
| DarkElfWizard | Mage | TBD |
| DarkElfSorceress | Priest | 어둠 의식 — 아군 회복·강화 |
| DarkElfSpellstealer | General | 마법 강탈 — 적 마법을 빼앗아 아군 부여 |

> 위 표의 "TBD" 표기 유닛은 정체성 한 줄과 트리거·효과의 구체 명세가 미결이다. §6 미결 항목 참조.

---

## 6. 미결 항목

| 항목 | 상태 |
|---|---|
| 35아군 유닛 모두의 스킬 명세 (정체성·트리거·효과) | 미결 — 본 문서의 표는 정체성만 짧게 표시. 데이터 파일 채우기는 별도 라운드 |
| 30적 유닛 스킬 명세 | 미결 → [UNIT_DESIGN.md §3](UNIT_DESIGN.md)의 카운터 힌트 컬럼이 의도. 실효 스킬은 별도 작업 |
| 보스 전용 스킬 (BigMonsters 풀) | 미결 — 페이즈 전환·광폭화 등 |
| 동일 직업이지만 종족이 다른 유닛의 스킬 차별화 방향 | 미결 — 예: 모든 Knight가 Taunt를 갖는다면 시너지 발동 시 단조롭다 |
| 스킬 발동 시각 효과·사운드 | 미결 |
