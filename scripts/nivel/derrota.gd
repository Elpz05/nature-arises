extends CanvasLayer

const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"   # ajusta a tu ruta real

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.25, 0.1, 0.1, 0.95)
	estilo.border_color = Color(0.8, 0.4, 0.4)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)

	var titulo := Label.new()
	titulo.text = "¡Has perdido!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 36)
	caja.add_child(titulo)

	var reiniciar := _boton("Reiniciar Nivel", _reiniciar)
	caja.add_child(reiniciar)
	caja.add_child(_boton("Volver al Menú", _volver))
	reiniciar

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(260, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(accion)
	return b

func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _volver() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_SLOTS)
