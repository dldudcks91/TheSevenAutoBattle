class_name SpriteFrameLoader

# Builds a SpriteFrames at runtime by scanning res://assets/units/{sprite_dir}/{anim}/
# Frame files are expected to be named "{sprite_dir}-{anim}_NN.png" (00-based).
# Falls back gracefully if a folder is missing — leaves the animation empty.

const ANIMS := {
	"idle":   {"folder": "Idle",     "fps": 8.0,  "loop": true},
	"walk":   {"folder": "Walk",     "fps": 10.0, "loop": true},
	"attack": {"folder": "Attack01", "fps": 12.0, "loop": false},
	"hurt":   {"folder": "Hurt",     "fps": 12.0, "loop": false},
	"death":  {"folder": "Death",    "fps": 8.0,  "loop": false},
}

# Per-sprite folder overrides for assets that don't follow the standard layout.
# Schema: sprite_dir → { anim_name: folder_name }
const FOLDER_OVERRIDES := {
	"Wizard":           {"death":  "DEATH"},
	"Knight Templar":   {"walk":   "Walk01"},
	"Lancer":           {"walk":   "Walk01"},
	"Priest":           {"attack": "Attack"},
	"Skeleton Archer":  {"attack": "Attack"},
}

static func build(sprite_dir: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# SpriteFrames is created with a default "default" animation. Replace it.
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var overrides: Dictionary = FOLDER_OVERRIDES.get(sprite_dir, {})

	for anim_name in ANIMS.keys():
		var conf: Dictionary = ANIMS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, conf.fps)
		frames.set_animation_loop(anim_name, conf.loop)
		var folder: String = overrides.get(anim_name, conf.folder)
		_load_frames_into(frames, anim_name, sprite_dir, folder)

	return frames

static func _load_frames_into(frames: SpriteFrames, anim: StringName, sprite_dir: String, folder: String) -> void:
	var dir_path := "res://assets/units/%s/%s" % [sprite_dir, folder]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("SpriteFrameLoader: missing %s" % dir_path)
		return

	var pngs: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png"):
			pngs.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	pngs.sort()

	for f in pngs:
		var tex: Texture2D = load("%s/%s" % [dir_path, f])
		if tex != null:
			frames.add_frame(anim, tex)
