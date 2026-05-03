extends Button
class_name HandCard

var slot_idx: int = -1
var preview_unit_name: String = ""
var preview_unit_data: UnitData = null
var preview_icon: Texture2D = null
# 영웅 카드만 그리드 드래그를 허용. 더미 카드는 클릭으로 소모.
var draggable: bool = true

func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled or not draggable:
		return null
	var preview: Control = _build_sprite_preview()
	if preview == null:
		preview = _build_icon_preview()
	if preview == null:
		preview = _build_label_preview()
	set_drag_preview(preview)
	return {"hand_slot": slot_idx}

func _build_sprite_preview() -> Control:
	if preview_unit_data == null:
		return null
	# Godot 드래그 프리뷰는 Control 좌상단을 커서 위치에 둔다.
	# AnimatedSprite2D 는 centered=true 라 노드 위치 기준으로 중앙 정렬되므로,
	# 노드를 (0,0)에 두면 sprite 중심이 커서에 정확히 붙는다.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node := Node2D.new()
	node.position = Vector2.ZERO
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrameLoader.build(preview_unit_data.sprite_dir)
	sprite.scale = Vector2.ONE * preview_unit_data.sprite_scale * 0.75
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")
	node.add_child(sprite)
	holder.add_child(node)
	return holder

func _build_icon_preview() -> Control:
	if preview_icon == null:
		return null
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_rect := TextureRect.new()
	tex_rect.texture = preview_icon
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(64, 64)
	tex_rect.size = Vector2(64, 64)
	tex_rect.modulate.a = 0.9
	holder.add_child(tex_rect)
	return holder

func _build_label_preview() -> Control:
	var lbl := Label.new()
	lbl.text = preview_unit_name
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	lbl.modulate.a = 0.9
	return lbl
