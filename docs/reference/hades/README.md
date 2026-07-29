# Hades 신의 축복(Boon) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 조커(전술카드) 계층 — 런 내내 유지되는 빌드 규정 픽 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 전술카드 — 빌드 엔진](../../game_design/GAME_DESIGN.md)

Supergiant의 로그라이트 **Hades**(1편)의 축복(Boon)은 런 내내 유지되며 빌드를 규정하는 신의 선물이다.
"조건이 맞물릴 때 폭발하는 빌드 어라운드 픽"이라는 점에서 우리 조커와 같은 자리이므로,
신별 어휘·조건 훅·듀오/레전더리 게이팅 설계를 여기서 캔다. 특히 **듀오(Duo) 축복**은
두 태그가 동시에 갖춰졌을 때만 열리는 시너지 픽이라 우리 조커 시너지 게이팅의 직접 레퍼런스다.

## 파일

| 파일 | 내용 |
|---|---|
| `boons.csv` | 축복 165종. 컬럼: `name, god, rarity, effect` |

- `god`: 단일 신(`Zeus`, `Poseidon` …) / 듀오는 `Duo:<A>+<B>` / 신 소속이 없는 노드는 `Misc`.
- `rarity`: 이 소스가 구분하는 3계층 + 기타.
  - `Core` — 일반 신 축복(122종). **주의:** Hades 원작의 Common/Rare/Epic/Heroic 등급은
    같은 축복의 **수치 스케일링 단계**일 뿐이라 이 소스에는 담기지 않는다(아래 "스크레이프 노트" 참고).
  - `Legendary` — 단일 신 최상위 축복(11종). 해당 신 축복을 여럿 먼저 확보해야 열림.
  - `Duo` — 두 신의 조합으로만 열리는 듀오 축복(28종). `god`에 두 신이 함께 표기됨.
  - `Misc` — 무기 아스펙트/`Hades' Aid` 등 신 소속이 없는 요구 노드(4종).
- `effect`: 짧은 효과 설명(원작 요구 차트의 `short_descr`). 수치가 스케일링 변수인 자리는 `#`로 남아 있다.

## 출처

- **orlp/hades-boons** (인터랙티브 축복 요구 차트) 데이터 덤프:
  `https://raw.githubusercontent.com/orlp/hades-boons/master/trait_data.json` (HTTP 200, 113KB)
  - 필드: `name, short_descr, gods[], duo(bool), legendary(bool), prereq_data[], exclusive_with[]`.
  - GitHub raw JSON이라 `curl` 한 번으로 전량 확보. Fandom 위키 스크레이프는 불필요했다.
- 교차 확인용(미사용): Hades Wiki(Fandom) `https://hades.fandom.com/wiki/Boons`.

## 재생성 방법

```bash
curl -s -L "https://raw.githubusercontent.com/orlp/hades-boons/master/trait_data.json" -o trait_data.json
# 각 항목: duo=true → god="Duo:"+gods.join("+"), rarity="Duo"
#          duo=false & legendary=true → rarity="Legendary"
#          gods=[] → god="Misc", rarity="Misc"
#          그 외 → god=gods[0], rarity="Core"
# effect = short_descr
```

## 커버리지 (부분 수집)

- **신별 Core+Legendary:** Zeus 15 · Poseidon 17 · Athena 13 · Aphrodite 15 · Ares 15 ·
  Artemis 14 · Dionysus 14 · Demeter 13 · Hermes 17 — **9신 전원 확보**.
- **Duo 28종 전량 확보**, **단일신 Legendary 11종 전량 확보**.
- 총 **165종** (Core 122 · Legendary 11 · Duo 28 · Misc 4).

### 스크레이프 노트 / 한계

- 이 소스는 **요구 차트(prereq graph)에 등장하는 축복**을 담는다. 원작에는 있으나 다른 축복의
  전제조건이 아닌 순수 정액 강화 축복 일부는 차트에 없어 빠질 수 있다 → **전수 수집은 아님**.
- **Common/Rare/Epic/Heroic 희귀도 단계는 없다.** Hades에서 이 등급들은 별개 축복이 아니라
  하나의 축복이 갖는 수치 배율(예: +10% → +30%)이라, 요구 차트 데이터에는 이름 단위로만 존재한다.
  즉 우리가 참고할 것은 "어떤 조건 훅으로 어떤 효과가 열리는가"이지 "수치가 얼마인가"가 아니다.
- 대상은 **Hades 1편**. Hades 2의 축복(오르페우스/헤스티아/아폴로/헤파이스토스 등 신규 신)은 미포함.
- 수치 스케일 자리는 원본에서 `#` 플레이스홀더로 남아 있어 `effect`에 그대로 들어갔다.

## 조커 설계에 쓸 핵심 발견

1. **듀오 게이팅 = 시너지 픽의 교과서.** 28종 듀오 전부 "두 신의 축복을 각각 최소 하나씩 가진
   상태"에서만 등장한다. 우리 조커의 "태그 X + 태그 Y 동시 보유 시 해금" 구조에 그대로 이식 가능.
2. **Legendary는 단일 축(신) 몰빵 보상.** 한 신 축복을 여러 개 쌓아야 열림 → "한 색으로 깊게 파면
   최상위 픽 개방"이라는 축 보상 곡선.
3. **거의 모든 축복이 무기 행동(Attack/Cast/Dash/Call)에 조건을 건다.** 순수 스탯 축복은 드물다 →
   "조커도 반드시 행동·상태·조건 훅을 단다"는 TFT 실버 분석과 동일한 결론.
