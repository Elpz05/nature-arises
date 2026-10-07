extends VBoxContainer

@onready var boton_jugar: Button = $Play
@onready var boton_ajustes: Button = $Options
@onready var boton_salir: Button = $Quit

@export var musica_menu: AudioStream

func _ready() -> void:
	MusicaManager.reproducir(musica_menu)
	UIInputManager.inicializar(boton_jugar)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas_menu/file_menu.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas_menu/settings_menu.tscn")

func _input(event: InputEvent) -> void:
	UIInputManager.manejar_input(event, get_viewport(), boton_jugar)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()
