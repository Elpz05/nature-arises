extends VBoxContainer

@onready var boton_jugar: Button = $Play
@onready var boton_ajustes: Button = $Options
@onready var boton_guia: Button = $Guia
@onready var boton_salir: Button = $Quit

@export var musica_menu: AudioStream

func _ready() -> void:
	MusicaManager.reproducir(musica_menu)
	UIInputManager.inicializar(boton_jugar)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/escenas_menu/file_menu.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/escenas_menu/settings_menu.tscn")

func _on_guia_pressed() -> void:
	var guia := preload("res://escenas/escenas_menu/guia_juego.tscn").instantiate()
	hide()
	get_parent().add_child(guia)
	guia.cerrada.connect(func():
		show()
		boton_guia.grab_focus()
	)

func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("Abrir Codice", false, true):
			get_viewport().set_input_as_handled()
			_on_guia_pressed()
			return
		UIInputManager.manejar_input(event, get_viewport(), boton_jugar)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()
