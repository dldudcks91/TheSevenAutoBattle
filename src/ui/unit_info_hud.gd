class_name UnitInfoHud
extends PanelContainer

# 양 진영 라이브 로스터 HUD. 좌측에 아군, 우측에 적군의 [이름 · HP바 · HP텍스트] 행을 표시한다.
# BattleSimulator가 bind_battle()로 자기 자신을 주입하면 매 프레임 _players/_enemies 를 폴링한다.

const ROW_HEIGHT := 22
const HP_BAR_WIDTH := 220
const HP_BAR_HEIGHT := 12
const NAME_FONT_SIZE := 16
const HP_FONT_SIZE := 14
const PLAYER_HP_COLOR := Color(0.3, 0.85, 0.4)
const ENEMY_HP_COLOR := Color(0.95, 0.35, 0.35)
const HP_BG_COLOR := Color(0.12, 0.13, 0.18)
const DEAD_COLOR := Color(0.55, 0.55, 0.6)

@onready var _left_rows: VBoxContainer = $Margin/HBox/LeftPanel/LeftRows
@onready var _right_rows: VBoxContainer = $Margin/HBox/RightPanel/RightRows

var _battle: BattleSimulator = null
# unit -> Dictionary{ row, name_lbl, hp_fg, hp_lbl }
var _player_rows: Dictionary = {}
var _enemy_rows: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func bind_battle(sim: BattleSimulator) -> void:
	_clear_visuals()
	_battle = sim

func clear() -> void:
	_battle = null
	_clear_visuals()

func _clear_visuals() -> void:
	_clear_rows(_left_rows, _player_rows)
	_clear_rows(_right_rows, _enemy_rows)

func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	_sync_side(_battle.get_players(), _left_rows, _player_rows, GameEnums.Team.PLAYER, true)
	_sync_side(_battle.get_enemies(), _right_rows, _enemy_rows, GameEnums.Team.ENEMY, false)

# ─── per-side sync ────────────────────────────────────────────────────────
func _sync_side(units: Array, container: VBoxContainer, rows: Dictionary, team: int, align_left: bool) -> void:
	# 1) 새로운 유닛은 행 생성 (현재 살아있는 것만 — DEAD 상태도 잠시 표시 유지)
	var seen: Dictionary = {}
	for u in units:
		if not is_instance_valid(u):
			continue
		seen[u] = true
		var row: Dictionary = rows.get(u, {})
		if row.is_empty():
			row = _make_row(team, align_left)
			container.add_child(row.row)
			rows[u] = row
		_paint_row(row, u, team)

	# 2) 시뮬레이터 배열에서 사라진 유닛(이미 filter된 사망자)은 행 제거
	var to_drop: Array = []
	for u in rows.keys():
		if not seen.has(u):
			to_drop.append(u)
	for u in to_drop:
		var row_dict: Dictionary = rows[u]
		if row_dict.has("row") and is_instance_valid(row_dict.row):
			row_dict.row.queue_free()
		rows.erase(u)

func _make_row(team: int, align_left: bool) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 12)
	if not align_left:
		row.alignment = BoxContainer.ALIGNMENT_END

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_lbl.custom_minimum_size = Vector2(160, ROW_HEIGHT)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not align_left:
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var hp_bar_bg := ColorRect.new()
	hp_bar_bg.color = HP_BG_COLOR
	hp_bar_bg.custom_minimum_size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var hp_fg := ColorRect.new()
	hp_fg.color = PLAYER_HP_COLOR if team == GameEnums.Team.PLAYER else ENEMY_HP_COLOR
	hp_fg.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	hp_fg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_bg.add_child(hp_fg)

	var hp_lbl := Label.new()
	hp_lbl.add_theme_font_size_override("font_size", HP_FONT_SIZE)
	hp_lbl.custom_minimum_size = Vector2(90, ROW_HEIGHT)
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 좌측 진영: [이름 | HP바 | HP텍스트], 우측 진영: [HP텍스트 | HP바 | 이름] 으로 미러링
	if align_left:
		row.add_child(name_lbl)
		row.add_child(hp_bar_bg)
		row.add_child(hp_lbl)
	else:
		row.add_child(hp_lbl)
		row.add_child(hp_bar_bg)
		row.add_child(name_lbl)

	return {
		"row": row,
		"name_lbl": name_lbl,
		"hp_fg": hp_fg,
		"hp_lbl": hp_lbl,
	}

func _paint_row(row: Dictionary, u: Object, team: int) -> void:
	var unit := u as Unit
	if unit == null or not is_instance_valid(unit) or unit.data == null:
		return
	row.name_lbl.text = tr(unit.data.name_key)
	var max_hp: float = max(unit.stats.max_hp, 1.0)
	var ratio: float = clampf(unit.hp / max_hp, 0.0, 1.0)
	row.hp_fg.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	row.hp_lbl.text = "%d / %d" % [int(ceil(unit.hp)), int(unit.stats.max_hp)]
	if unit.state == Unit.State.DEAD:
		row.hp_fg.color = DEAD_COLOR
		row.row.modulate = Color(1, 1, 1, 0.45)
	else:
		row.hp_fg.color = PLAYER_HP_COLOR if team == GameEnums.Team.PLAYER else ENEMY_HP_COLOR
		row.row.modulate = Color(1, 1, 1, 1)

func _clear_rows(container: VBoxContainer, rows: Dictionary) -> void:
	for c in container.get_children():
		c.queue_free()
	rows.clear()
