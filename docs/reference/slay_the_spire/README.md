# Slay the Spire 유물(Relic) 레퍼런스 데이터

> 수집일: 2026-07-29 · 목적: 조커(런 지속 빌드어라운드 픽) 계층 설계 참고
> 관련 설계 → [GAME_DESIGN.md §7 전술카드 — 빌드 엔진](../../game_design/GAME_DESIGN.md)

우리 게임의 **조커(=런 내내 유지되는 패시브 픽)** 계층을 설계할 때 참고하는 외부 코퍼스다.
Slay the Spire 유물은 "런 시작부터 끝까지 유지되며 빌드 방향을 규정하는 패시브 아이템"이라는 점에서
우리 조커와 정확히 같은 자리다. 등급 체계(Common→Boss)·조건 훅·획득 경로(상점/이벤트/보스)의
어휘와 경제 설계를 여기서 캔다.

## 파일

| 파일 | 내용 |
|---|---|
| `relics.csv` | Slay the Spire 1 유물 전 193종. 컬럼: `name, rarity, character, description, flavor` |

- `rarity`: `Starter / Common / Uncommon / Rare / Boss / Shop / Event / Special / Blight`.
  - 코어 세트 178종 = Starter 4 · Common 36 · Uncommon 36 · Rare 34 · Boss 30 · Shop 20 · Event 18.
  - 그 외 `Special` 2종(Circlet / Red Circlet, 유물 소진 시 나오는 플레이스홀더), `Blight` 13종(음성 유물).
- `character`: 사용 캐릭터 제한. `Any`(153) = 공용, 나머지는 직업 전용(Ironclad 11 · Silent 11 · Defect 9 · Watcher 9).
- `description`: 수치가 채워진 최종 설명문(위키 렌더 결과). 게임 원본 로컬라이즈 문자열의 `#b` 색상/숫자 플레이스홀더가 아니라 실제 값이 들어가 있다.
- `flavor`: 플레이버 텍스트. 원문 그대로 유지(예: Emotion Chip의 `...<3...?`는 하트 이모티콘으로 의도된 표기).

## 출처

- **공식 위키(slay the spire wiki.gg)의 "Relics List" 렌더 HTML**: `https://slaythespire.wiki.gg/wiki/Relics_List`
  - 각 유물은 `<div class="relic-box" data-rarity data-character data-sequel>` 카드로 렌더된다.
  - `data-sequel="1"` 필터로 Slay the Spire **1편** 유물만 추출(2편 Regent/Necrobinder, 보드게임판 제외).
- 시도했으나 부적합했던 소스:
  - `github.com/nkhoit/spire-archive` relics.json → **404**(경로 소실).
  - `github.com/VincentOostelbos/Slay-the-Spire-EO` relics.json → 200이지만 **rarity 없음** + 설명의 숫자가 `#b` 플레이스홀더로 비어 있어 부적합.
  - wiki.gg Cargo `Relics` 테이블(`api.php?action=cargoquery`) → STS1 데이터 미이관, 14행(대부분 보드게임)만 존재 → 부적합.

## 재생성 방법

```bash
# 1. Relics List 렌더 HTML 다운로드
curl -sL "https://slaythespire.wiki.gg/wiki/Relics_List" -o relics_list.html

# 2. relic-box 카드 파싱 → CSV
#    - data-rarity / data-character 를 컬럼으로
#    - relic-desc 내부 텍스트에서 태그 제거, relic-flavor 분리
#    - data-sequel="1" 만 채택 (전부 1편이지만 방어적으로 필터)
python parse.py   # 본 폴더 재생성 시 사용한 파서
```

## 유물 수

**193종** (코어 178 + Special 2 + Blight 13). 전 등급·전 캐릭터 커버, 결측 없음.

## 갭 / 주의

- **Blight 13종**은 정식 런의 획득 가능 유물이 아니라 음성 유물이다. 등급 어휘 참고용으로만 포함했고,
  조커 등급 설계 시에는 코어 178종 위주로 볼 것.
- `Special` 2종은 실제 효과가 없는 이스터에그성 플레이스홀더다.
- 등급 간 획득 확률·상점 가격 같은 **수치**는 이 CSV에 없다(위키 본문 별도 표). 필요 시 `Relics` 본문 페이지에서 추가 확보.
