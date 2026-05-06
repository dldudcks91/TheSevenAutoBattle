class_name GameEnums

const CELL_SIZE: int = 48
const GRID_PIXEL: int = 12

# 기존 Job: legacy 매핑용으로 보존. UI 라벨·sprite 일부 코드가 참조.
enum Job { SOLDIER, AXEMAN, SWORDSMAN, KNIGHT, TEMPLAR, LANCER, ARCHER, PRIEST, WIZARD }

# 시너지 시스템의 직업 (9종) — units.csv 의 class 컬럼.
enum Class { KNIGHT, WARRIOR, SPEARMAN, RIDER, ARCHER, ASSASSIN, MAGE, PRIEST, GENERAL }

# 시너지 시스템의 종족 (8종: 아군 5 + 적 3) — units.csv 의 race 컬럼.
enum Race { HUMANS, VIKINGS, BEASTMEN, ORDER_OF_THE_FIRE, DARK_ELVES, ORCS, UNDEAD, DEMONS }

enum SynergyType { CLASS, RACE }

enum Team { PLAYER, ENEMY }
# 핸드 카드 종류. HERO는 그리드에 드래그 배치, 나머지는 영웅 셀에 드래그해 사용.
# SKILL은 폐지되었으나 enum 값은 호환을 위해 보존 (런타임에서 더 이상 발생하지 않음).
enum CardKind { HERO, UPGRADE, SKILL, ITEM }
