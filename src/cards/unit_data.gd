class_name UnitData
extends RefCounted

var id: StringName
var name_key: String
var is_player: bool = false
var max_hp: float = 100.0
var attack: float = 10.0
var attack_range: int = 1
var attack_speed: float = 1.0
var move_speed: float = 60.0
var defense: float = 0.0
var cost: int = 1
var is_ranged: bool = false
var body_radius: float = 22.0
var hit_frame_ratio: float = 0.4  # damage applies at this fraction through the attack animation
var job: GameEnums.Job = GameEnums.Job.SOLDIER

# Sprite folder name under res://assets/units/. Animations expected:
# Idle, Walk, Attack01, Hurt, Death (frames named "{sprite_dir}-{Anim}_NN.png")
var sprite_dir: String = "Soldier"
var sprite_scale: float = 2.0

# units.csv 의 default_skill_id 컬럼. 빈 문자열이면 기본 스킬 없음. 실 데이터는 SkillDB에서 조회.
var default_skill_id: StringName = &""

static func from_row(row: Dictionary) -> UnitData:
	var d := UnitData.new()
	d.id = StringName(row["id"])
	d.name_key = row["name_key"]
	d.is_player = String(row.get("is_player", "false")).strip_edges().to_lower() == "true"
	d.max_hp = float(row["max_hp"])
	d.attack = float(row["attack"])
	d.attack_range = int(row["attack_range"])
	d.attack_speed = float(row["attack_speed"])
	d.move_speed = float(row["move_speed"])
	d.defense = float(row["defense"])
	d.cost = int(row["cost"])
	d.is_ranged = String(row["is_ranged"]).strip_edges().to_lower() == "true"
	d.body_radius = float(row["body_radius"])
	d.hit_frame_ratio = float(row["hit_frame_ratio"])
	d.job = GameEnums.Job[row["job"]]
	d.sprite_dir = row["sprite_dir"]
	d.sprite_scale = float(row["sprite_scale"])
	var skill_id: String = String(row.get("default_skill_id", "")).strip_edges()
	d.default_skill_id = StringName(skill_id) if skill_id != "" else &""
	return d
