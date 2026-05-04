# 유닛/몬스터 능력치 결정 프로세스 (업계 레퍼런스)

> 출처는 문서 하단 참고. 본 문서는 외부 자료를 정리한 레퍼런스이며, 우리 프로젝트의 현재 상태 및 다음 액션을 함께 매핑한다.

---

## 1. 표준 6단계 프로세스

### 1단계 — 역할(Role)과 페르소나 먼저, 숫자는 나중

스탯 표를 채우기 전에 **"이 유닛은 무엇을 가르치는 적인가"** 를 한 줄로 정의한다.

- "armored_orc는 *방어력 개념*을 가르치는 적"
- "skeleton_archer는 *후방도 안전하지 않다*를 가르치는 적"
- "werebear는 *단일 위협의 무게감*을 가르치는 보스"

### 2단계 — 기준(Vanilla) 유닛 정하기

밸런스의 **원점**을 하나 박아둔다. 보통 "레벨1 기본 적"이 power 1.0.

- 모든 다른 유닛은 "기준의 X배"로 표현
- 디자이너 어휘가 "이 적은 기본 적의 1.5배 강함"으로 통일됨

### 3단계 — Power Score 공식 만들기

```
DPS   = ATK / INT
EHP   = HP × (1 + ARM × k)         k = 방어 1당 EHP 증가율 (0.05~0.15)
POWER = DPS × EHP × ROLE_MULT
```

- **ROLE_MULT**가 핵심: 원거리 ×1.2, 기동 ×1.15, 메카닉 ×1.2~1.4 같은 곱셈 보정
- 공식 한 번이면 "이 적은 다른 적의 N배" 가 자연스럽게 표현됨
- DPS / EHP는 업계 표준 metric (검색 결과 기준 다수 RPG·MMO에서 동일 공식)

### 4단계 — Designer-Facing 변수로 역설계

업계 핵심 원칙: **공식의 입력이 디자이너가 이해할 수 있는 단위**여야 한다.

- 코드는 `hp`, `atk` 같은 raw 값을 쓰더라도
- 디자이너 테이블은 `tier`, `archetype`, `mechanic_tag` 같은 의미 있는 변수로
- 공식이 그걸 raw 스탯으로 변환

예시:
```
tier      = {weak: 0.7, normal: 1.0, elite: 1.4, miniboss: 1.8, boss: 2.5}
archetype = {tank: HP×1.5 ATK×0.7, dps: HP×0.8 ATK×1.4, range: HP×0.7 RNG=4, ...}
```
→ `werebear = boss_tier + tank_archetype` 으로 "공식이 스탯을 뱉음"

이렇게 하면 패치 시 "tier 하나 올리면 끝" 이라 유지보수가 쉬움.

### 5단계 — 진행 곡선(Progression Curve)에 맞추기

핵심 곡선 3가지:

| 곡선 | 식 | 특징 | 쓰임 |
|---|---|---|---|
| **선형** | Y = aX + b | 후반에 단조로움 | 보상·자원 곡선 |
| **2차** | Y = aX² | 후반에 폭발적 | 적 위협 곡선 |
| **로그** | Y = log_b X | 전반 큰 보너스, 후반 완만 | 스탯 다이미니싱 리턴 |

**중요한 구분:**
- 적 power 자체는 **선형 또는 약한 지수**로 짠다 (감각이 아니라 객체적 위협)
- 그걸 **log 변환해서 보는 것**이 디자이너의 perception axis (리히터 척도 방식)
- 즉, "log 곡선으로 디자인"이 아니라 "log 축으로 검토"

일반적 비율: W1=1.0 → W_final = 8~16배 (지수 0.15~0.20).

### 6단계 — 플레이테스트로 망치질

공식으로 "이론값"을 깐 후 측정할 핵심 metric:

- **TTK (Time-to-Kill)** — 플레이어 1유닛이 적 1마리 잡는 데 몇 초?
- **TTD (Time-to-Die)** — 플레이어가 죽기까지 몇 초?
- 의도 비율(예: 보스 TTK 30초 / 잡몹 5초)과 어긋나면 ROLE_MULT 조정
- "feel" 안 맞으면 raw 스탯 미세조정 (단, **큰 변화부터** — 5%씩은 의미 없음)

---

## 2. 추가 원칙 (검색 결과 종합)

### Designer-Facing 변수 명명

- 변수 방향 일관성 유지: 항상 "값이 클수록 좋다" 또는 "값이 작을수록 좋다" 중 하나로 통일
- 의미 있는 이름: `Fatigue` → `Energy`, `ItemUseCount` → `ItemDurability`
- 코드와 디자이너 테이블이 다르면 코드가 변환하도록 (디자이너가 변환하지 않게)

### Power Curve 비교의 가치

- **플레이어 power 곡선** vs **적 위협 곡선**을 같은 그래프에 겹쳐 보는 게 핵심
- 두 곡선의 간극 = 난이도
- 간극이 일정하면 flow state 유지, 벌어지면 좌절·줄어들면 지루함

### Risk 분석 / Base-case

- 밸런스 검증 시 "기준 시나리오"를 먼저 정의 (예: tier 평균 플레이어가 권장 적과 싸울 때)
- 모든 변동은 base-case 대비 ±X% 로 측정

### Enemy Scaling 기법

- 기본은 **티어 매트릭스 + 곱셈 보정** (개별 적 raw 값을 일일이 만지지 않음)
- 보스는 ×3.0, 잡몹은 ×0.1 같은 멀티플라이어로 톱니 조정
- 큰 변화부터, 작은 미세조정은 마지막

---

## 3. 우리 프로젝트(TheSevenAutoBattle) 매핑

| 단계 | 상태 | 비고 |
|---|---|---|
| 1. 역할 정의 | ✅ 있음 | [WAVE_DESIGN.md](../game_design/WAVE_DESIGN.md) 챕터별 학습 포인트 |
| 2. 기준 유닛 | ⚠ 미정 | `orc` = power 1.0 으로 박을지 결정 필요 |
| 3. Power 공식 | ❌ 없음 | DPS × EHP × ROLE_MULT 도입 필요. k_arm = 0.1 잠정 |
| 4. Designer-Facing 변수 | ❌ 없음 | tier × archetype 매트릭스 미설계 — 현재는 raw 스탯만 |
| 5. 진행 곡선 | ⚠ 부분 | 보상 곡선만 결정(선형). 적 위협 곡선 목표 미정 |
| 6. 플레이테스트 | ❌ 없음 | TTK/TTD metric 측정 도구·기준 미정 |

### 현재 빈 곳

- 3~4단계가 비어 있어 "감"으로 raw 스탯을 조정하게 되는 상태
- 11종 적의 raw 스탯은 있으나, 그걸 만든 공식이 없음 → 패치할 때 일관성 깨지기 쉬움

### 제안 다음 액션

1. **기준 유닛 못박기**: `orc` = power 1.0
2. **k_arm 결정**: 0.1 (방어 1당 EHP +10%)
3. **ROLE_MULT 표 작성**:
   - 원거리 ×1.2
   - 기동(SPD≥150) ×1.15
   - 부활 ×1.3
   - 디버프(공깎/공감) ×1.2
   - 분열·사망강화 ×1.3
   - 스노우볼 ×1.2
   - 미니보스 ×1.4 / 보스 ×1.8 / 최종보스 ×2.5
4. **tier × archetype 매트릭스** 설계
5. 11종을 매트릭스에 분류 → 공식이 raw HP/ATK 뱉도록
6. 결과를 `units.csv` 에 반영 → W1~W20 power 곡선 그래프로 검증
7. 안 맞으면 **ROLE_MULT부터 조정** (raw 값 X), 그 다음 raw 값 미세조정

---

## 출처

- [Balancing a Game the Right Way: Make Stats Designer-Facing (Game Developer)](https://www.gamedeveloper.com/design/balancing-a-game-the-right-way-make-stats-designer-facing)
- [Tracking Power Curves Through Progression in Game Design (Game Wisdom)](https://game-wisdom.com/critical/power-curves-game-design)
- [Video Game Balance: A Definitive Guide (Game Design Skills)](https://gamedesignskills.com/game-design/game-balance/)
- [Balancing Stats and Progression in RPG Game Design](https://multigamedev.blogspot.com/2025/02/balancing-stats-and-progression-in-rpg.html)
- [Difficulty curves: how to get the right balance (Game Developer)](https://www.gamedeveloper.com/design/difficulty-curves-how-to-get-the-right-balance-)
- [The Damage Is Too Damn High — Achieving the Perfect Balance](https://medium.com/@a.mstv/the-damage-is-too-damn-high-or-achieving-the-perfect-balance-3ccccbe70756)
- [Enemy design — The Level Design Book](https://book.leveldesignbook.com/process/combat/enemy)
- [My Favorite Enemy Scaling Techniques in Video Games](https://medium.com/@dalemensik413/my-favorite-enemy-scaling-techniques-in-video-games-be27f1bf22ed)
- [Applying Risk Analysis To Play-Balance RPGs (Game Developer)](https://www.gamedeveloper.com/design/applying-risk-analysis-to-play-balance-rpgs)
- [Level 7: Advancement, Progression and Pacing (Game Balance Concepts)](https://gamebalanceconcepts.wordpress.com/2010/08/18/level-7-advancement-progression-and-pacing/)
