extends Control

const ARENA_SCENE := "res://src/ui/arena_root.tscn"

@onready var _start_btn: Button = $Center/VBox/StartButton
@onready var _quit_btn: Button = $Center/VBox/QuitButton

func _ready() -> void:
	_start_btn.pressed.connect(_on_start)
	_quit_btn.pressed.connect(_on_quit)
	_start_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start()
	elif event.is_action_pressed("ui_cancel"):
		_on_quit()

func _on_start() -> void:
	RunState.reset_run()
	get_tree().change_scene_to_file(ARENA_SCENE)

func _on_quit() -> void:
	get_tree().quit()
