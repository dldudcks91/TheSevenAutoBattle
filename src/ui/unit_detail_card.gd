class_name UnitDetailCard
extends PanelContainer

# 단일 아군 유닛 상세 카드 — BATTLE phase 좌상단(필드 안쪽)에 표시.
# 클릭으로 바운드되며, 매 프레임 stat 갱신. 유닛 사망/invalid 시 자동 hide.

const PORTRAIT_SIZE := Vector2(96, 96)
const NAME_FONT_SIZE := 18
const STAT_FONT_SIZE := 14
const HP_BAR_WIDTH := 200
const HP_BAR_HEIGHT := 10
const HP_BG_COLOR := Color(0.12, 0.13, 0.18)
const HP_FG_COLOR := Color(0.3, 0.85, 0.4)

@onready var _portrait: TextureRect = $Margin/HBox/Portrait
@onready var _name_lbl: Label = $Margin/HBox/Info/NameLabel
@onready var _hp_bar_bg: ColorRect = $Margin/HBox/Info/HpBarBg
@onready var _hp_bar_fg: ColorRect = $Margin/HBox/Info/HpBarBg/HpBarFg
@onready var _hp_lbl: Label = $Margin/HBox/Info/HpLabel
@onready var _atk_lbl: Label = $Margin/HBox/Info/AtkLabel
@onready var _defense_lbl: Label = $Margin/HBox/Info/DefenseLabel
@onready var _spd_lbl: Label = $Margin/HBox/Info/SpdLabel

var _unit: Unit = null
# sprite_dir → idle 첫 프레임 텍스처 캐시
static var _portrait_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func bind_unit(u: Unit) -> void:
	if u == null or not is_instance_valid(u) or u.data == null:
		clear()
		return
	_unit = u
	_portrait.texture = _get_portrait(u.data.sprite_dir)
	_name_lbl.text = tr(u.data.name_key)
	visible = true
	_refresh()

func clear() -> void:
	_unit = null
	visible = false

func _process(_delta: float) -> void:
	if _unit == null:
		return
	if not is_instance_valid(_unit) or _unit.is_dead():
		clear()
		return
	_refresh()

func _refresh() -> void:
	var max_hp: float = max(_unit.stats.max_hp, 1.0)
	var ratio: float = clampf(_unit.hp / max_hp, 0.0, 1.0)
	_hp_bar_fg.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	_hp_lbl.text = "%s: %d / %d" % [tr("STAT_HP"), int(ceil(_unit.hp)), int(_unit.stats.max_hp)]
	_atk_lbl.text = "%s: %d" % [tr("STAT_ATK"), int(round(_unit.current_attack()))]
	_defense_lbl.text = "%s: %d" % [tr("STAT_DEFENSE"), int(round(_unit.current_defense()))]
	_spd_lbl.text = "%s: %.2fs" % [tr("STAT_ATTACK_SPEED"), _unit.stats.attack_speed]

static func _get_portrait(sprite_dir: String) -> Texture2D:
	if _portrait_cache.has(sprite_dir):
		return _portrait_cache[sprite_dir]
	var frames: SpriteFrames = SpriteFrameLoader.build(sprite_dir)
	var tex: Texture2D = null
	if frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
		tex = frames.get_frame_texture(&"idle", 0)
	_portrait_cache[sprite_dir] = tex
	return tex
