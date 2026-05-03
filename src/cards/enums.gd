class_name GameEnums

const CELL_SIZE: int = 48
const GRID_PIXEL: int = 12

enum Job { SOLDIER, AXEMAN, SWORDSMAN, KNIGHT, TEMPLAR, LANCER, ARCHER, PRIEST, WIZARD }
enum Team { PLAYER, ENEMY }
# 핸드 카드 종류. HERO는 그리드에 드래그 배치, 나머지는 영웅 셀에 드래그해 사용.
enum CardKind { HERO, UPGRADE, SKILL, ITEM }
