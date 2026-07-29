# 유닛 디자인

> 최종 업데이트: 2026-07-29
> 종족·직업 **태그** → [SYNERGY_DESIGN.md](SYNERGY_DESIGN.md) (임계 시너지는 폐기, 태그는 조커 훅으로만 존속)
> 유닛 스킬 상세 → [SKILL_DESIGN.md](SKILL_DESIGN.md)
> 스탯·표시명 데이터 → [src/data/units/units.csv](../../src/data/units/units.csv) + [src/data/i18n/text.csv](../../src/data/i18n/text.csv)

---

## 1. 디자인 원칙

1. **Player fantasy first** — 정체성을 먼저 정하고, 그 정체성을 행동으로 옮기는 스킬을 설계한다. 메커닉에서 정체성을 역산하지 않는다.
2. **태그 두 축 (직업·종족)** — 모든 아군 유닛은 직업과 종족을 하나씩 가진다. 같은 종족 안에서 같은 직업이 두 번 나오지 않도록 매핑한다 → [SYNERGY_DESIGN.md §4](SYNERGY_DESIGN.md). 태그 자체에는 효과가 없고 **조커 조건의 훅**으로만 쓰인다.
3. **고정 1스킬** — 유닛마다 고유 스킬을 정확히 하나 가진다. 카드로 추가 부여하지 않는다.
5. **카드 코스트를 가진다** — 유닛은 곧 병사 카드이며, 파워에 비례하는 배치 코스트를 가진다 → [GAME_DESIGN.md §5](GAME_DESIGN.md). 싼 유닛은 도태되지 않고 "예산 효율 좋은 필러" 역할을 맡는다.
4. **에셋 기반** — 유닛 스프라이트·애니메이션은 minifolks 팩(아군 5종족) 및 minifolks 팩(적 3종족)을 사용한다.

---

## 2. 아군 — 5종족 / 35유닛

각 유닛은 종족 1 + 직업 1을 갖는다. 직업 카탈로그는 [SYNERGY_DESIGN.md §2](SYNERGY_DESIGN.md), 종족별 톤은 [SYNERGY_DESIGN.md §3](SYNERGY_DESIGN.md) 참조.

### 2.1 Humans — 정통 왕국군 (8유닛)

다재다능. 모든 핵심 직업을 한 명씩 보유한 표준 진영.

| 유닛 | 직업 | Player fantasy |
|---|---|---|
| ShieldMan | Knight | 방패로 전선을 지키는 정통 왕국 보병. |
| SwordMan | Warrior | 검과 깡으로 밀어붙이는 표준 보병. |
| SpearMan | Spearman | 길게 찌르는 창병. 기마 카운터. |
| CavalierMan | Rider | 갑주 두른 기사 기마. 라인 돌파의 상징. |
| ArcherMan | Archer | 후방의 든든한 직업 궁수. |
| Mage | Mage | 정통 학파 마법사. 안정적 마법 딜. |
| ArchMage | Priest | 신성과 학술의 경계에 있는 대마법사 — 아군 보호와 회복을 마법으로 수행한다. |
| KingMan | General | 왕의 명령 한 마디로 부대 전체가 움직인다. |

### 2.2 Vikings — 북방 광폭 전사단 (6유닛)

근접·기마·궁술의 전사 종족. 마법·치유 없음.

| 유닛 | 직업 | Player fantasy |
|---|---|---|
| VikingSwordman | Knight | 양손검의 묵직한 전선병. |
| VikingBerserker | Warrior | 광폭화로 자기 피해를 무시하고 휘두르는 광전사. |
| VikingSpearman | Spearman | 북방 창병. 방패벽과 함께 서는 전열. |
| VikingHorseman | Rider | 북방의 빠른 기마. 측면 돌파. |
| VikingArcher | Archer | 차가운 활시위로 멀리서 끊는 사수. |
| VikingJarl | General | 부족장. 함성으로 동족 전사를 폭주시킨다. |

### 2.3 Beastmen — 수인 야생 동맹 (8유닛)

종족별 동물 특성이 직업으로 직결되는 컨셉. 8명이 8직업을 모두 한 명씩 채운다 (가장 균형 잡힌 종족).

| 유닛 | 직업 | Player fantasy |
|---|---|---|
| BearWarrior | Knight | 곰의 두꺼운 가죽으로 전선을 막는다. 거대한 체구. |
| FoxSwordsman | Warrior | 여우의 민첩으로 기습과 회피를 섞은 검술. |
| PandaWarrior | Spearman | 판다의 권법과 장봉. 묵직한 리치. |
| WolfPathfinder | Archer | 늑대의 후각으로 적을 추적해 활로 끊는 정찰사수. |
| CatRobber | Assassin | 고양이의 그림자 도둑. 후방 침투 전문. |
| RabbitWizard | Mage | 토끼의 조심성과 빠른 영창. 정통 마법사. |
| DeerDruid | Priest | 자연의 사슴 사제. 식물 마법으로 치유. |
| LionKnight | General | 사자의 기백. 부대를 호령하는 야생의 군주. |

### 2.4 OrderOfTheFire — 화염 광신 교단 (5유닛)

화염 마법 특화. 적은 수지만 모든 직업이 화염 정체성을 공유한다.

| 유닛 | 직업 | Player fantasy |
|---|---|---|
| FirePrince | Knight | 화염을 두른 왕자. 불타는 갑주로 전선을 지킨다. |
| FireWarrior | Warrior | 불을 입힌 검을 휘두르는 광신 전사. |
| FireMage | Mage | 교단의 정통 화염술사. 영창의 끝에 폭염을 띄운다. |
| FirePriestess | Priest | 신성한 화염으로 아군의 상처를 태워 봉합한다. |
| FirePrincess | General | 화염을 명령하는 공주. 부대 전체에 불의 가호를 내린다. |

### 2.5 DarkElves — 어둠 마법·암살 도시 (8유닛)

도시형 마법·암살 특화. 전사·기마·궁수와 마법 직업을 모두 보유한 정예 종족.

| 유닛 | 직업 | Player fantasy |
|---|---|---|
| DarkElfGuard | Knight | 도시의 호위병. 어둠 갑주로 전선을 지킨다. |
| DarkElfSwordsman | Warrior | 두 자루 검을 다루는 어둠의 검사. |
| DarkElfRider | Rider | 검은 짐승을 탄 어둠의 기마병. |
| DarkElfArcher | Archer | 마법이 깃든 활시위. 야간 전투의 정수. |
| DarkElfAssassin | Assassin | 그림자 도시의 살수. 단검과 독으로 후방을 지운다. |
| DarkElfWizard | Mage | 금단 학파의 흑마법사. 어둠의 정공 마법. |
| DarkElfSorceress | Priest | 어둠의 여사제. 어둠 의식으로 아군을 회복·강화한다. |
| DarkElfSpellstealer | General | 적 마법을 빼앗아 아군에게 돌리는 마법 군사. 어둠 도시의 사령관. |

---

## 3. 적 — 3종족 / 30유닛

> 적 유닛은 시너지 시스템에 참여하지 않는다 → [SYNERGY_DESIGN.md §7](SYNERGY_DESIGN.md).
> 웨이브별 등장 의도·학습 곡선 → [WAVE_DESIGN.md](WAVE_DESIGN.md)
> 적 라인업·카운트 데이터 → [src/data/rounds.csv](../../src/data/rounds.csv)

### 3.1 Orcs — 약탈 부족 (10유닛)

기초 학습 챕터. 숫자로 밀어붙이는 야만 부족.

| 유닛 | 방향성 | 카운터 힌트 |
|---|---|---|
| Goblin | 가장 약한 잡몹 — 숫자로 압박 | 광역기·범위 공격 |
| GoblinThief | 빠르게 후방 침투 | 전선 차단·도발 |
| Orc | 표준 근접 — 평균치 | 무엇으로든 처리 가능 |
| OrcWarrior | 정예 근접 — 두꺼운 맷집 | 방어 무시 마법·집중 화력 |
| OrcVeteran | 노련함 — 안정적 딜 | 빠른 처치 |
| OrcBerserker | 광폭화 — 체력 낮을수록 강해진다 | 임계 전 마무리 |
| OrcAxeThrower | 원거리 도끼 투척 | 후방도 안전하지 않다 — 전선 차단 |
| OrcWarChief | 부족 지휘관 — 주변 오크 강화 | 우선 처치 |
| WargRider | 빠른 기마 — 후방 직격 | 도발·전선 차단 |
| WolfRider | 또 다른 기마형 — 측면 침투 | 도발·전선 차단 |

### 3.2 Undead — 죽지 않는 군세 (10유닛)

원거리·부활·디버프 메카닉 도입.

| 유닛 | 방향성 | 카운터 힌트 |
|---|---|---|
| Skeleton | 약한 잡몹이지만 끊임없이 등장 | 광역기 |
| SkeletonArcher | 원거리 위협 첫 도입 | 전선 차단·암살 |
| Zombie | 느리지만 두껍다 — 전선 정체 | 마법·관통 |
| ZombieButcher | 정예 좀비 — 절단 공격 | 도발·집중 화력 |
| Ghost | 물리 저항 — 마법 외 안 통한다 | 마법 딜러 필수 |
| Reaper | 기동형 처형자 — 빈사 적 즉시 처치 | 회복 또는 빠른 격리 |
| Necromancer | 잡몹 부활 — 한 번 죽여도 또 일어선다 | 우선 처치 |
| Lich | 강력한 흑마법 — 광역 디버프 | 암살·고속 처치 |
| DeathKnight | 정예 기사 — 저주 공격 | 정화·고스펙 탱커 |
| DreadKnight | 보스급 기사 — 광역 공포 | 도발 카운터·집중 화력 |

### 3.3 Demons — 마계의 군세 (10유닛)

후반 챕터. 화염·매혹·정예 단일 위협.

| 유닛 | 방향성 | 카운터 힌트 |
|---|---|---|
| Imp | 잡몹 데몬 — 빠른 숫자 압박 | 광역기 |
| FireImp | 화염 잡몹 — 자폭/지속피해 위협 | 거리 두기·즉시 처치 |
| ClawedDemon | 표준 근접 데몬 | 무엇으로든 |
| Demoness | 마법형 — 디버프·약화 마법 | 암살·고속 처치 |
| Succubus | 매혹 — 아군 일시 적전환 (또는 공격 분산) | 우선 처치·정화 |
| DemonTormentor | 도발·피흡 — 전선 못 뚫게 잡아둔다 | 광역기로 우회 |
| DemonFireKeeper | 화염 영창 — 광역 화상 | 전선 차단·암살 |
| DemonFireThrower | 원거리 화염 투척 | 전선 차단·도발 |
| HighDemon | 정예 단일 위협 — 강한 단일딜 | 도발·집중 화력 |
| DemonLord | 보스급 — 광역 공포·강력한 단일 마법 | 도발 카운터·고스펙 마법 |

> 보스 라운드에 BigMonsters 팩의 거대 단일 유닛(예: GiantBear, BlackDragon, DemonLord 등)을 호위 없이 또는 데몬 호위와 함께 등장시킬 수 있다 → [WAVE_DESIGN.md](WAVE_DESIGN.md).

---

## 4. 배치 규칙

- 배치판은 **3×3 = 9칸이며 한 칸에 한 유닛**만 선다. 판은 매 전투 초기화된다 → [GAME_DESIGN.md §4](GAME_DESIGN.md).
- 같은 종류를 여러 칸에 두는 것은 자유다. 유리해지는 건 화력·맷집뿐이며 별도 보너스는 없다.
- 배치는 **예산 상한**과 **칸 상한** 두 제약을 동시에 받는다. 칸이 찼는데 예산이 남으면 잉여는 강화로 갈 수밖에 없다.
- 칸 위치는 초기 스폰 좌표와 접적 순서를 결정한다 → [BATTLE_DESIGN.md §8](BATTLE_DESIGN.md).

> **폐기:** 4×4 16칸 / 셀당 같은 종류 4명 누적 / 종류 단위 시너지 카운트 — 전부 누적 모델 전제였다.

---

## 5. 스킬·강화 부여 방식

- 유닛은 **고정 1스킬**을 가진다. 카드로 스킬을 추가 장착하지 않는다.
- 스킬 데이터·구조는 [SKILL_DESIGN.md](SKILL_DESIGN.md) 참조.
- **시한부 강화 카드**는 배치된 유닛에 부착되며 **그 전투에만** 유효하다. 전투가 끝나면 사라지고 카드는 덱으로 회수된다.
- 유닛에 영구히 누적되는 강화는 없다. 영구 성장은 **덱 카드 자체를 상향**하는 방식으로만 일어난다 → [GAME_DESIGN.md §3](GAME_DESIGN.md).

---

## 6. 미결 항목

| 항목 | 상태 |
|---|---|
| 35아군 유닛별 스킬 정의 | 미결 — [SKILL_DESIGN.md](SKILL_DESIGN.md) §6 |
| 30적 유닛별 스킬 정의 | 미결 — 카운터 힌트 컬럼은 의도. 실효 스킬은 별도 작업 |
| **유닛별 카드 코스트** | 미결 — 데이터. 파워 티어와 코스트 커브를 함께 잡아야 함 |
| **초기 덱에 들어갈 유닛** | 미결 — "약하고 단순한 시작 덱" 시드 구성 |
| 보스 전용 유닛 (BigMonsters) | 미결 — 보스로 무엇을 쓸지, 호위 구성 어떻게 할지 |
| ~~그리드 확장 여부~~ | **폐기 — 3×3 9칸, 1칸 1유닛으로 회귀** → [GAME_DESIGN.md §4](GAME_DESIGN.md) |
| ~~적 종족 시너지 도입~~ | **폐기 — 임계 시너지 자체가 사라짐** |
