# TFT 증강체(Augment) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 조커 등급 체계(특히 **Normal** 등급) 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 조커 계층 · 등급 체계](../../game_design/GAME_DESIGN.md)

우리 게임의 **조커(=전술카드/증강체) 계층**을 설계할 때 참고하는 외부 코퍼스다.
TFT 증강체는 "런 내내 유지되며 빌드를 규정하는 선택지"라는 점에서 우리 조커와 같은 자리이므로,
Normal/Magic/Rare 등급의 어휘·조건 훅·경제 설계를 여기서 캔다.

## 파일

| 파일 | 내용 |
|---|---|
| `all_augments.csv` | 전 셋 증강체 1,679종. 컬럼: `set, tier, name, traits, apiName, desc` |
| `silver_augments.csv` | 실버(tier I) 254종 슬라이스 — **우리 Normal에 가장 가까운 등급** |

- `tier`: `1-Silver / 2-Gold / 3-Prismatic` (아이콘 경로의 `-I/-II/-III` 접미사에서 파싱). `?`는 아이콘이 placeholder(`Missing`)라 판별 불가.
- `desc`: 원본 `@Variable@` 플레이스홀더를 `effects` 값으로 치환. 미해결 변수는 `[변수명]`으로 남김. HTML 태그 제거.
- `traits`: 연계 특성 apiName(우리로 치면 태그 훅에 해당).

## 출처

- **Community Dragon** 전체 TFT JSON (25MB): `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json`
  - 최신 CDN이라 **셋 1·2·3·12는 유실**됐다. "전 시즌"은 부분 복원만 가능.
- 공식 Riot Data Dragon `tft-augment.json`은 신버전(16.x)에서 **AccessDenied** — 사용 불가.

## 재생성 방법

```bash
curl -s "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json" -o cdragon_tft_latest.json
# 그 뒤 items[] 중 apiName에 "Augment" 포함 항목 추출,
# tier = 아이콘 경로 [-_](III|II|I) 접미사, desc의 @var@ 를 effects 로 치환.
```

## Normal 설계에 쓸 핵심 발견 (2026-07-29 분석)

실버 225종(중복 제거) 아키타입 분류:

| 아키타입 | 대략 개수 | 우리 매핑 |
|---|---|---|
| 경제/골드 | ~80 | **자원 장르** — 최대 버킷 |
| 아이템 부품 보상 | ~61 | 사장 (우리는 아이템 없음, 조커에 흡수) |
| 위치/전투 버프 (전열/후열) | ~97 | **강화 장르** — 대부분 열 조건부 |
| 태그 조건부 | ~19 | 태그 훅 |
| 전투 이벤트(처치/사망/체력) | ~11 | 이벤트 매개 |
| 순수 정액 스탯 | ~13 | 거의 없음 |

1. **최하 등급(실버)조차 순수 정액 스탯은 13종뿐.** 나머지는 위치·태그·이벤트·경제 조건이 붙는다.
   → "Normal도 반드시 조건 훅을 단다" 규칙이 업계 최저 등급 설계와 일치한다.
2. **위치 버프가 실버의 큰 축**(전열 체력↑, 후열 공속↑ 등) → 우리 그리드 열에 이식 가능.
3. **재배치(움직임) 증강체는 TFT에 없다** — TFT는 전투 중 재배치 불가. 우리 움직임 장르는 원본 없는 자체 발명 영역.

## 다른 덱빌딩 게임 데이터 (미수집, 필요 시 확보)

| 게임 | 유사 개념 | 소스 |
|---|---|---|
| Slay the Spire | 유물(Relic) | github.com/nkhoit/spire-archive (JSON, 다국어) |
| Balatro | 조커 | github.com/jie65535/awesome-balatro |
| Monster Train | 유물 + 클랜 시너지 | Fandom 위키 |
