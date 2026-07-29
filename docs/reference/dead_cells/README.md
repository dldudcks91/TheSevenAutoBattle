# Dead Cells 뮤테이션(Mutation) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 조커 계층(런 지속 빌드어라운드 픽) 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 전술카드 — 빌드 엔진](../../game_design/GAME_DESIGN.md)

우리 게임의 **조커(=전술카드) 계층**을 설계할 때 참고하는 외부 코퍼스다.
Dead Cells의 뮤테이션은 "런 내내 유지되며 스탯 스케일링에 얹혀 빌드를 규정하는 패시브 픽"이라는 점에서
우리 조커와 같은 자리다. 스탯 스케일링·조건 훅(처치/패링/구르기/원거리)·해금 경제(셀 비용)를 여기서 캔다.

## 파일

| 파일 | 내용 |
|---|---|
| `mutations.csv` | 현행(비삭제) 뮤테이션 53종. 컬럼: `name, stat, effect, unlock` |

- `stat`: 스케일 스탯 — `Brutality`(11) / `Tactics`(12) / `Survival`(12) / `Any`(18, 무색·고정효과).
  - 원본 `Scaling` 코드 `brut/tact/surv`를 매핑. `''`(무색)·`none`(Combo, 콤보 스케일)·`power`(Frostbite, 최고 스탯 스케일)는 모두 `Any`로 묶었다.
- `effect`: 효과 텍스트. 원본의 `<span>` 색상 태그·위키 링크·볼드 마크업을 제거. `[x base, y max]` 수치 표기는 설계 참고용이라 그대로 남겼다.
- `unlock`: 청사진 해금에 드는 셀(Cell) 비용. 기본 해금 뮤테이션 11종은 공란(비용 없음).

## 스케일링 메커니즘 (원문 요약)

- 대부분의 뮤테이션은 특정 스탯 1종에 연동. 기본 데미지/힐량이 `1.15^(n-1)` 배로 곱해진다 (`n` = 해당 스탯 레벨).
- 무색(`Any`) 뮤테이션은 스탯 무관 고정 효과 (예외: Instinct of the Master of Arms, Frostbite는 최고 스탯 스케일).
- 런당 뮤테이션 슬롯은 지역 클리어마다 +1, 최대 11개. 골드로 전체 리셋 가능(1,000골드 시작, 리셋마다 2배, 8,000골드 상한).

## 출처

- **Dead Cells Fandom Wiki — Mutations** 페이지: `https://deadcells.fandom.com/wiki/Mutations`
  - 페이지 본문은 Cargo 쿼리로 렌더링돼 위키텍스트에 수치가 없다. 데이터는 Cargo 테이블 `Mutations`에 있다.
- 실제 데이터 소스: Fandom **Cargo API**
  `https://deadcells.fandom.com/api.php?action=cargoquery&tables=Mutations&fields=Name,Description,BlueprintLocation,BlueprintCost,Scaling,RemoveVersion,Id&where=RemoveVersion IS NULL&order_by=Id&limit=500&format=json`
- GitHub 데이터 덤프는 확보 실패(코드 검색 API는 인증 필요, 공개 뮤테이션 JSON 덤프 미발견). Fandom Cargo가 사실상 최선의 정형 소스.

## 재생성 방법

```bash
curl -s "https://deadcells.fandom.com/api.php?action=cargoquery&tables=Mutations&fields=Name,Description,BlueprintLocation,BlueprintCost,Scaling,RemoveVersion,Id&where=RemoveVersion%20IS%20NULL&order_by=Id&limit=500&format=json" -o cargo.json
# 그 뒤 Scaling(brut/tact/surv → 스탯, 그 외 → Any) 매핑,
# Description의 <span>/[[링크]]/'' 마크업 제거, BlueprintCost → unlock.
```

## 수집 결과 및 공백

- **총 53종**(RemoveVersion IS NULL, 즉 현행 유지 뮤테이션만). 삭제/알파베타 뮤테이션은 제외.
- Brutality 11 · Tactics 12 · Survival 12 · Any(무색) 18.
- 해금 셀 비용 보유 42종, 기본 해금(비용 공란) 11종.
- **공백:**
  - Legendary/Affix(전설 장비·접사) 효과는 별도 페이지(`Affixes`)라 이번엔 미수집 — 필요 시 추가 확보.
  - 청사진 드롭 위치/확률(`BlueprintLocation`, `BlueprintChance`)은 우리 설계와 무관해 CSV에서 제외.
  - 삭제된 뮤테이션(구버전 밸런스 히스토리)은 제외.
