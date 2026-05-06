@tool
extends EditorScript

# Godot 에디터에서 1회 실행:
#   File → Run Script → tools/build_sprite_frames.gd
# `assets/sprites/<unit>/<anim>/*.png`를 스캔해 SpriteFrames Resource를 생성하고
# `assets/data/units/<team>/<unit>_frames.tres`에 저장한다.

const SPRITES_ROOT := "res://assets/sprites"
const DATA_ROOT := "res://assets/data/units"

const ANIMS := ["idle", "walk", "attack", "hurt", "death"]

const UNITS := {
	"soldier": {"team": "allies"},
	"knight":  {"team": "allies"},
	"archer":  {"team": "allies"},
	"priest":  {"team": "allies"},
	"orc":     {"team": "enemies"},
}

const ANIM_FPS := {
	"idle": 8.0,
	"walk": 12.0,
	"attack": 12.0,
	"hurt": 10.0,
	"death": 8.0,
}


func _run() -> void:
	var built: int = 0
	for unit_name in UNITS.keys():
		var team: String = UNITS[unit_name].team
		var sf := SpriteFrames.new()
		# 기본 "default" 애니메이션 제거 (우리가 직접 채움)
		if sf.has_animation(&"default"):
			sf.remove_animation(&"default")

		var any_added := false
		for anim in ANIMS:
			var dir_path := "%s/%s/%s" % [SPRITES_ROOT, unit_name, anim]
			var textures := _load_frames_in(dir_path)
			if textures.is_empty():
				push_warning("No PNG frames at %s" % dir_path)
				continue
			sf.add_animation(anim)
			sf.set_animation_speed(anim, ANIM_FPS.get(anim, 10.0))
			sf.set_animation_loop(anim, anim != "death")
			for tex in textures:
				sf.add_frame(anim, tex)
			any_added = true

		if not any_added:
			push_error("No animations built for %s" % unit_name)
			continue

		var out_path := "%s/%s/%s_frames.tres" % [DATA_ROOT, team, unit_name]
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir().replace("res://", ProjectSettings.globalize_path("res://")))
		var err := ResourceSaver.save(sf, out_path)
		if err != OK:
			push_error("ResourceSaver.save failed for %s (err=%d)" % [out_path, err])
		else:
			print("[build_sprite_frames] saved %s" % out_path)
			built += 1

	print("[build_sprite_frames] done, %d/%d unit SpriteFrames built" % [built, UNITS.size()])


func _load_frames_in(dir_path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	var files: Array = []
	dir.list_dir_begin()
	while true:
		var fname := dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir():
			continue
		if fname.to_lower().ends_with(".png"):
			files.append(fname)
	dir.list_dir_end()
	files.sort()
	for f in files:
		var path := "%s/%s" % [dir_path, f]
		var tex: Texture2D = load(path)
		if tex == null:
			push_warning("load failed: %s" % path)
			continue
		result.append(tex)
	return result
