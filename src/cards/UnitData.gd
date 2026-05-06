class_name UnitData
extends Resource

enum Team { ALLY = 0, ENEMY = 1 }

@export var id: StringName
@export var display_name: String
@export var sprite_frames: SpriteFrames

@export_group("Stats")
@export var max_hp: int = 100
@export var attack: int = 10
@export var attack_range: float = 30.0
@export var move_speed: float = 80.0
@export var attack_interval: float = 1.0  # 초당 공격 횟수의 역수 (1.0 = 1초마다)

@export_group("Economy")
@export var cost: int = 2     # 출전 코스트 (아군 전용)
@export var price: int = 3    # 상점 가격 (아군 전용)

@export_group("Meta")
@export var team: Team = Team.ALLY
