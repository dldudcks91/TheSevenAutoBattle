# Balatro 조커(Joker) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 우리 게임 **조커 계층**의 직계 원본(same-name) 참고
> 관련 설계 → [GAME_DESIGN.md §7 조커 계층 · 등급 체계](../../game_design/GAME_DESIGN.md)

Balatro의 조커는 "런 내내 유지되며 점수/규칙을 규정하는 패시브 카드"로,
우리 게임의 조커와 **개념·이름이 그대로 겹치는 최우선 레퍼런스**다.
등급 체계(Common~Legendary), 가격, 효과 어휘, 해금 조건 훅을 여기서 캔다.

## 파일

| 파일 | 내용 |
|---|---|
| `jokers.csv` | 바닐라 조커 **150종 전량**. 컬럼: `name, rarity, cost, effect, unlock` |

- `rarity`: `Common / Uncommon / Rare / Legendary` (원본 `rarity` 정수 1/2/3/4 매핑).
- `cost`: 상점 기본 구매가(달러). Legendary는 상점에 안 나오지만 내부값 20으로 표기됨.
- `effect`: 로컬라이제이션 텍스트를 줄 합쳐 정리. 색상/포맷 코드(`{C:..}`, `{X:..}`, `{}`)는 제거. 수치 플레이스홀더 `#1# #2#`는 원본 그대로 남김(실제 값은 조커별 `config`에 있어 미해결).
- `unlock`: 해금 조건 텍스트. **기본 해금 조커는 공란**(조건 없음). Legendary 5종의 `?????`는 원본 그대로 — The Soul(스펙트럴) 카드로만 등장해 게임 내에서도 조건이 숨겨져 있음.
- 정렬: 이름 오름차순.

## 등급 분포 (검증용)

| 등급 | 개수 |
|---|---|
| Common | 61 |
| Uncommon | 64 |
| Rare | 20 |
| Legendary | 5 |
| **합계** | **150** |

(공식 바닐라 조커 수 150종과 일치.)

## 출처

- **비공식 게임 소스 미러** `GladdonT/balatro-source-code` (GitHub):
  - 조커 정의(등급·가격·이름) → `game.lua`
    `https://raw.githubusercontent.com/GladdonT/balatro-source-code/main/game.lua` (약 237KB)
  - 효과·해금 텍스트 → `localization/en-us.lua`
    `https://raw.githubusercontent.com/GladdonT/balatro-source-code/main/localization/en-us.lua` (약 147KB)
- 두 파일 모두 5MB 미만이라 URL만 기록하고 원본은 리포에 커밋하지 않는다(스크래치패드에만 보관).
- 대안 소스: Balatro Wiki(balatrowiki.org) `Template:Joker data`, `jie65535/awesome-balatro` 툴 모음.

## 재생성 방법

```bash
# 1) 두 소스 파일 내려받기
curl -sL "https://raw.githubusercontent.com/GladdonT/balatro-source-code/main/game.lua" -o game.lua
curl -sL "https://raw.githubusercontent.com/GladdonT/balatro-source-code/main/localization/en-us.lua" -o en-us.lua

# 2) 파서 실행 (scratchpad/parse.py):
#    - game.lua: j_<key> 라인에서 rarity/cost/name 추출 (rarity 1234 -> Common/Uncommon/Rare/Legendary)
#    - en-us.lua: descriptions.Joker 블록에서 j_<key>별 text=/unlock= 문자열 추출,
#      {..} 포맷 코드 제거, #n# 플레이스홀더 유지, key로 병합
python parse.py   # -> jokers.csv (150행)
```

주의: 효과 텍스트 추출 시 `text=\{...\},` 정규식은 인용문 안의 `},`(예: `2{}, `)에서 오작동한다.
`text={` / `unlock={` 위치로 슬라이스한 뒤 인용 문자열만 뽑는 방식으로 파싱했다.

## 조커 설계에 쓸 핵심 발견 (2026-07-29)

1. **등급 피라미드가 완만하다** — Common 61 / Uncommon 64가 전체의 83%. Rare 20, Legendary 5.
   최상위는 극소수이고, 무게중심이 하위 두 등급에 몰려 있다.
2. **해금 조건은 절반 미만(45/150)에만 붙는다** — 나머지는 기본 제공. 조건은 대개
   플레이 누적(핸드/디스카드 횟수, 도달 앤티, 특정 족보 달성) 형태의 "메타 진행 언락"이며,
   전투 중 조건이 아니다. → 우리 조커 해금을 런 밖 진행 보상으로 둘지 판단 근거.
3. **효과 대부분이 조건부 곱연산(Xmult)·정액 가산(+Mult/+Chips)·경제(달러)·확률 트리거**로 구성.
   순수 무조건 스탯은 드물고, "무엇을 했을 때/무엇을 들고 있을 때" 훅이 기본값이다.
4. **Legendary는 판을 뒤집는 룰 변경**(보스 무효화, Negative 복제 등)에 집중 — 수치보다 규칙 파괴.
