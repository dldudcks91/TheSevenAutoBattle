# Monster Train 아티팩트(Artifact/Relic) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: **조커 계층**(런 내내 유지되는 빌드 규정 픽) 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 조커 계층 · 등급 체계](../../game_design/GAME_DESIGN.md)

우리 게임의 **조커 계층**을 설계할 때 참고하는 외부 코퍼스다.
Monster Train의 아티팩트(수집형 유물, Collectable Relic)는 "런 내내 유지되며 빌드를 규정하는 수동 픽"이라는 점에서
우리 조커와 정확히 같은 자리다. 특히 **클랜(진영) 귀속 아티팩트 vs. 범용(General) 아티팩트** 구분이
우리 "태그/진영 훅을 단 조커 vs. 무조건 조커" 설계와 대응하므로, 조건 훅·희귀도별 어휘·클랜 시너지 설계를 여기서 캔다.

## 파일

| 파일 | 내용 |
|---|---|
| `artifacts.csv` | 수집형 아티팩트 157종. 컬럼: `name, clan_or_source, rarity, effect` |

- `name`: 아티팩트 이름. `Divine <이름>`은 이벤트로 강화된 신성(Divine) 변형이며 대개 "1전투 후 제거" 페널티가 붙는다.
- `clan_or_source`: 귀속 클랜(`linkedClass`에서 매핑). 클랜 없는 것은 `General`(어느 클랜으로든 획득 가능). `[Hellforged DLC]`는 The Last Divinity DLC 콘텐츠(Wurmkin 클랜 + 추가 범용 유물).
  - 매핑: `ClassStygian`→Stygian Guard, `ClassHellhorned`→Hellhorned, `ClassWurm`→Wurmkin, `ClassUmbra`→Umbra, `ClassAwoken`→Awoken, `ClassRemnant`→Melting Remnant.
- `rarity`: `Common / Uncommon / Rare / Champion / Starter`.
- `effect`: 원본 `description`. `[effectN.power]`·`[effectN.statusM.power]`·`[effectN.upgrade.*]` 같은 수치 플레이스홀더는 `effects[]` 실제 값으로 치환. `[ember]`·`[corrupt]`·`[damageshield]` 등 **게임 키워드 태그와 `[magicpower]`(유닛 스탯 변수)는 원문 그대로 대괄호 유지**. HTML 태그(`<b>`, `<br>`) 제거.

## 구성 (157종)

| 출처 | 개수 | | 희귀도 | 개수 |
|---|---|---|---|---|
| General | 57 | | Common | 88 |
| General [Hellforged DLC] | 23 | | Uncommon | 56 |
| Stygian Guard | 14 | | Champion | 8 |
| Hellhorned | 14 | | Rare | 4 |
| Wurmkin [Hellforged DLC] | 13 | | Starter | 1 |
| Umbra | 12 | | | |
| Awoken | 12 | | | |
| Melting Remnant | 12 | | | |

## 출처

- **brandonandzeus / MonsterTrainGameData** (게임 에셋 덤프, GitHub):
  `https://github.com/brandonandzeus/MonsterTrainGameData` → `CollectableRelicData/` 폴더의 개별 JSON 157개.
  - raw 예: `https://raw.githubusercontent.com/brandonandzeus/MonsterTrainGameData/main/CollectableRelicData/<이름>.json`
  - 각 JSON 필드: `name`, `description`, `linkedClass`, `rarity`, `requiredDLC`, `effects[]`(수치·상태이상·트리거).
- (미채택) `zakpruitt/mt-api` — Spring 기반 REST API. 데이터는 인증 토큰이 필요한 사설 AWS API Gateway에서 로드하므로 무인증 접근 불가.
- (미채택) Monster Train Fandom 위키 — 위 JSON 덤프가 구조화·완전해서 스크레이프 불필요.

원본 JSON 157개(총 ~700KB)는 리포에 커밋하지 않는다. 재수집은 아래 스크립트로 언제든 가능하므로 URL만 문서화한다.

## 재생성 방법

```bash
REPO=brandonandzeus/MonsterTrainGameData
# 1) CollectableRelicData/ 하위 .json 목록 확보
curl -s "https://api.github.com/repos/$REPO/git/trees/main?recursive=1" \
  | python -c "import sys,json,urllib.parse;
[print('https://raw.githubusercontent.com/brandonandzeus/MonsterTrainGameData/main/'+urllib.parse.quote(x['path']))
 for x in json.load(sys.stdin)['tree']
 if x['path'].startswith('CollectableRelicData/') and x['path'].endswith('.json')]" > urls.txt
# 2) 전체 다운로드 (병렬)
mkdir -p relics && cat urls.txt | xargs -P8 -I{} sh -c 'curl -s "{}" -o "relics/$(basename "{}" | python -c "import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read().strip()))")"'
# 3) name / linkedClass→clan / rarity / description(플레이스홀더 치환·HTML 제거) 를 CSV로 추출
```

플레이스홀더 치환 규칙:
- `[effectN.power]` → `effects[N].paramInt`
- `[effectN.statusM.power]` → `effects[N].paramStatusEffects[M].count`
- `[effectN.upgrade.bonusdamage|bonushp]` → `effects[N].paramCardUpgradeData.bonusDamage|bonusHP`
- `[effectN.upgrade.statusM.power]` → `effects[N].paramCardUpgradeData.statusEffectUpgrades[M].count`
- 나머지 대괄호(`[ember]`, `[magicpower]` 등)는 키워드/변수이므로 유지.

## 조커 설계에 쓸 핵심 관찰

1. **클랜 귀속 77종 vs. 범용 80종**이 거의 반반.
   범용 유물은 대체로 자원/경제·구조적 효과(에너지·드로우·챔피언 조작),
   클랜 유물은 그 클랜의 메커니즘(Wurmkin `[corrupt]`, Umbra `[snack]`, Hellhorned `[summon]` 등)을 증폭한다.
   → 우리도 "무조건 조커(경제/구조)"와 "태그 훅 조커(진영 메커니즘 증폭)"를 나눠 설계하는 근거.
2. **희귀도가 낮을수록 조건 훅이 단순**(Common은 단일 트리거 1개), 높을수록 복합 조건.
   순수 정액 스탯만 주는 유물은 거의 없고 대부분 트리거·조건이 붙는다(TFT 실버 관찰과 동일).
3. **Divine(강화) 변형**은 같은 효과를 수치만 키우고 "1전투 후 제거" 페널티를 붙인 일회성 강화판 —
   우리 조커에 "고효율 소모형" 등급을 넣을지 검토할 때 참고.
