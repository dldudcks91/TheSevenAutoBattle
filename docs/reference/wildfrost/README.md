# Wildfrost 참 & 아이템 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 카드 부착형 강화(참) + 런 지속 아이템 어휘 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 전술카드 — 빌드 엔진](../../game_design/GAME_DESIGN.md)

우리 게임의 **전술카드(=조커/부착 계층)**를 설계할 때 참고하는 외부 코퍼스다.
Wildfrost는 덱빌딩 + 레인(전열/후열) 오토배틀 조합이라 우리 게임과 가장 가까운 구조이며,
특히 **Charm(참)**은 "한 카드에 영구 부착되어 그 카드의 동작을 바꾸는 강화"라는 점에서
우리 부착/조커 계층과 정확히 같은 자리다. **Item(아이템)**은 손에서 다른 카드에 즉시 적용되는
런 지속 소모/보조 카드로, 상호작용 통화(키워드) 어휘를 캐기에 좋다.

## 파일

| 파일 | 내용 |
|---|---|
| `charms_items.csv` | 참 51종 + 아이템 77종 = 128종. 컬럼: `name, type, effect` |

- `type`: `charm`(카드 영구 부착 강화) / `item`(손패에서 발동하는 런 지속 카드).
- `effect`: 위키 임베드의 **Effects** 필드 값. 없으면 설명(description)으로 폴백.
- 원본의 `<&Keyword&>` 아이콘 플레이스홀더는 키워드 텍스트로 치환(예: `<&Shell&>` → `Shell`).
  Discord 마크다운 볼드(`**`)·HTML 태그 제거.

## 출처

- **WildfrostBot** (Wildfrost 위키 미러 데이터): `github.com/SHA65536/WildfrostBot`
  - 경로: `Data/Content/Cards/Charms/*.json` (참 51개) · `Data/Content/Cards/Items/*.json` (아이템 77개)
  - 각 JSON은 `wildfrostwiki.com` 문서를 파싱한 Discord 임베드 구조 (`embed.fields[].name == "Effects"`).
- Fandom 위키(`wildfrost.fandom.com/wiki/Charms`, `/wiki/Items`)는 WebFetch에서 **HTTP 402**로 차단 → 사용 불가.
  GitHub 미러가 더 완전하고 파싱하기 쉬워 이쪽을 채택.

## 재생성 방법

```bash
# 1) 파일 목록
curl -s "https://api.github.com/repos/SHA65536/WildfrostBot/git/trees/main?recursive=1" \
  | grep -oE 'Data/Content/Cards/(Charms|Items)/[^"]+\.json'
# 2) 각 파일 raw 다운로드 (경로 URL 인코딩 필수 — 공백 포함)
#    base: https://raw.githubusercontent.com/SHA65536/WildfrostBot/main/<path>
# 3) embed.fields 중 name=="Effects" 의 value 추출 → name,type,effect CSV
```

- **주의:** `Data/Content/Cards/Items/gigi's cookie box.json` 은 리포 상 파일명에 **개행 문자**가
  박혀 있어 일괄 다운로드가 깨진다. 해당 파일만 `%0A` 포함 경로로 개별 재수집했다.

## 수집 결과

| type | 개수 |
|---|---|
| charm | 51 |
| item | 77 |
| **합계** | **128** |

- effect 빈 값 0건 (전 항목 효과 텍스트 확보).

## 갭 / 한계

- 위키 미러 기준이라 **DLC/업데이트 이후 신규 항목 반영 여부는 미검증** — 커밋 시점 스냅샷.
- 참의 **부족(Tribe) 전용 여부·해금 조건**은 CSV에 포함하지 않음(효과 어휘만 필요). 원본 JSON의
  `Unlock` 필드·`description`에 남아 있으니 필요 시 재추출.
- Wildfrost의 **Bell(전투 시작 트리거)·Clunker·Companion** 등 다른 카드 계층은 이번 수집 범위 밖.
