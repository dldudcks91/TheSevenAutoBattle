# 스컬(Skul: The Hero Slayer) 아이템·정수 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 조커 계층(런 지속형 패시브 장비)의 등급 체계·효과 어휘 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 조커 계층 · 등급 체계](../../game_design/GAME_DESIGN.md)

스컬은 한국(SouthPAW Games) 로그라이트 액션 플랫포머로, **런 내내 유지되며 빌드를 규정하는
패시브 장비**를 두 계열로 나눈다 — **아이템(Item, 다크 미러 상점 등에서 획득)**과
**정수(Quintessence, 정수)**. 두 계열 모두 우리 조커와 같은 자리(런 지속 · 등급별 희소도 · 조건부 발동)이므로,
등급 어휘·발동 조건 훅·효과 패턴을 여기서 캔다.

- **아이템**은 상시 패시브 스탯/트리거(피격·처치·대시·스왑 시 발동 등).
- **정수**는 능동 발동형에 가깝다 — 상시 스탯 + 쿨다운 후 강력한 액티브 효과 1회.

## 파일

| 파일 | 내용 |
|---|---|
| `items.csv` | 아이템 68종 + 정수 27종 = 95행. 컬럼: `name, category, rarity, effect` |

- `category`: `item` / `quintessence`
- `rarity`: `Common / Rare / Unique / Legendary` (스컬의 4단계 희소도)
- `effect`: 영문 효과 텍스트. CSV 파싱 안전을 위해 효과문 내부 쉼표는 제거(문장 분리는 마침표 유지).

### 등급별 분포

| 등급 | 아이템 | 정수 |
|---|---|---|
| Common | 12 | 8 |
| Rare | 37 | 11 |
| Unique | 17 | 5 |
| Legendary | 2 | 3 |
| 합계 | 68 | 27 |

## 출처

- **SteamAH — "Skul: The Hero Slayer Items and Quintessences Guide"** (주 출처, 구조화된 등급별 목록)
  - https://steamah.com/skul-the-hero-slayer-items-and-quintessences-guide/
  - https://steamah.com/skul-the-hero-slayer-items-and-quintessences-guide/2/
- 교차 확인용(자동 수집 불가 — 아래 "스크레이프 노트" 참고):
  - Fandom 위키 Equipment: https://skul.fandom.com/wiki/Equipment
  - Neoseeker 아이템 리스트: https://www.neoseeker.com/skul-the-hero-slayer/Item_List
  - 나무위키(스컬 아이템과 각인): https://namu.wiki/w/Skul:%20The%20Hero%20Slayer/아이템과%20각인

## 스크레이프 노트 (2026-07-29)

- **깨끗한 JSON 덤프 없음.** 위키 스크레이프가 유일한 경로 (게임 모드 리포지토리에도 공개 아이템 DB 없음).
- **Fandom(skul.fandom.com)은 HTTP 402, Neoseeker·나무위키·steamah/2페이지 일부는 HTTP 403** — WebFetch 자동 수집 차단. steamah 본문 페이지만 정상 응답.
- Legendary 아이템 `Raven Monarch's Father`, `Sylphid Wings`는 출처 1페이지에서 Unique로, 2페이지에서 Legendary로 표기 — **2페이지(더 명시적)를 따라 Legendary로 분류**.
- 한글 이름은 자동 수집 소스(영문 steamah)에 없어 **미포함**. 필요 시 나무위키 수동 대조로 보강.

## 데이터 완전성 (GAP)

- **이 CSV는 전수(全數)가 아니다.** 스컬은 패치 1.7+ 기준 아이템만 225종+ (신화 DLC 20종 추가) 존재하나,
  자동 수집 가능했던 steamah 가이드는 **대표 68종**만 커버(특히 Rare 이하 상당수 · Legendary 다수 누락).
- 정수 27종은 **거의 전량**으로 보이나 최신 패치 신규 정수는 누락 가능.
- **용도상 충분:** 이 레퍼런스의 목적은 조커 설계용 어휘·조건 훅·등급 곡선 채굴이지 완전한 게임 DB 복제가 아니다.
  전수 목록이 필요해지면 나무위키 각 등급 하위 페이지를 수동 수집해 보강할 것.

## 조커 설계에 쓸 핵심 관찰

1. **정수 = "상시 스탯 + 액티브 1회"의 이중 구조.** 순수 패시브(아이템)와 능동 발동(정수)을 등급이 아니라
   *계열*로 나눈 점이 우리 조커 계열 분리에 참고가 된다.
2. **발동 훅이 행동에 묶인다** — 피격 시 / 처치 시 / 대시 시 / 스왑(교체) 시 / N초마다.
   우리는 스왑 대신 배치·라운드 이벤트로 치환 가능.
3. **Legendary는 극소수**(아이템 2·정수 3) — 최상위 희소도를 의도적으로 얇게 유지. 등급 곡선 참고.
4. **"성공한 정수 공격 시 / 성공한 아이템 공격 시" 상호 참조 효과**(Diorite Circlet, Rear Blast)처럼
   *다른 계열의 발동을 조건으로 삼는* 크로스-시너지가 존재 — 조커 간 연쇄 설계 아이디어.
