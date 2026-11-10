extends CanvasLayer

@export var musica_derrota: AudioStream

const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"   # ajusta a tu ruta real
const INTERFAZ = preload("res://fuentes/interfaz.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	if musica_derrota != null:
		MusicaManager.reproducir(musica_derrota)
		
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.theme = INTERFAZ
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.theme_type_variation = &"TituloPixel"
	titulo.add_theme_color_override("font_color", Color("#ffa888"))
	titulo.text = "¡Has perdido!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 42)
	caja.add_child(titulo)

	var reiniciar := _boton("Reiniciar Nivel", _reiniciar)
	caja.add_child(reiniciar)
	caja.add_child(_boton("Volver al Menú", _volver))
	caja.add_child(preload("res://scripts/HUD/escala_interfaz.gd").new())
	reiniciar.grab_focus()

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(300, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(accion)
	return b

func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _volver() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_SLOTS)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("Atras"):
		get_viewport().set_input_as_handled()
		_volver()
