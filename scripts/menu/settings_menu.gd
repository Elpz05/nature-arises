extends Control

signal cerrada

const ANCHO_ACCION := 350
const ANCHO_CONTROL := 320
const ESCALA_UI = preload("res://scripts/HUD/escala_interfaz.gd")

@onready var container: VBoxContainer = %KeybindsContainer
@onready var boton_volver: Button = %Volver
@onready var boton_hud_debug: CheckButton = %HUDDebug
@onready var boton_numeros_dano: CheckButton = %NumerosDano
var selector_escala: OptionButton

var accion_esperando: String = ""
var tipo_esperando: ControlesManager.Tipo = ControlesManager.Tipo.TECLADO_MOUSE
var boton_esperando: Button = null
var en_partida := false

func _ready() -> void:
	set_process_input(en_partida)
	if en_partida:
		$FondoSettings.hide()
		$Particulas.hide()
	boton_hud_debug.set_pressed_no_signal(Ajustes.hud_debug_activo())
	boton_hud_debug.toggled.connect(Ajustes.establecer_hud_debug)
	boton_numeros_dano.set_pressed_no_signal(Ajustes.numeros_dano_activos())
	boton_numeros_dano.toggled.connect(Ajustes.establecer_numeros_dano)
	_crear_control_ambiente()
	crear_encabezado()
	for accion in ControlesManager.acciones_configurables:
		crear_fila(accion)
	var fila := HBoxContainer.new()
	var etiqueta := Label.new()
	etiqueta.text = "Tamaño de interfaz"
	etiqueta.add_theme_color_override("font_color", Color("#18120c"))
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)
	selector_escala = OptionButton.new()
	selector_escala.accessibility_name = etiqueta.text
	for porcentaje in Ajustes.ESCALAS_UI:
		selector_escala.add_item("%d%%" % porcentaje, porcentaje)
	selector_escala.item_selected.connect(_seleccionar_escala)
	fila.add_child(selector_escala)
	var opciones := boton_numeros_dano.get_parent()
	opciones.add_child(fila)
	opciones.move_child(fila, boton_numeros_dano.get_index() + 1)
	Ajustes.escala_ui_cambiada.connect(_actualizar_escala)
	resized.connect(_ajustar_ancho)
	_actualizar_escala(Ajustes.escala_ui())
	UIInputManager.inicializar(boton_volver)

func _crear_control_ambiente():
	var fila_sfx := boton_numeros_dano.get_parent().get_node("FilaSonidos") as HBoxContainer
	var fila := fila_sfx.duplicate(0) as HBoxContainer
	fila.name = "FilaAmbiente"
	var nombre := fila.get_child(0) as Label
	nombre.text = "Ambiente"
	var volumen := fila.get_child(1) as HSlider
	var porcentaje := fila.get_child(2) as Label
	volumen.accessibility_name = nombre.text
	var bus := AudioServer.get_bus_index("Ambience")
	volumen.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(bus)))
	porcentaje.text = "%d%%" % roundi(volumen.value * 100)
	volumen.value_changed.connect(func(valor: float):
		AudioServer.set_bus_volume_db(bus, linear_to_db(valor) if valor > 0.0 else -80.0)
		porcentaje.text = "%d%%" % roundi(valor * 100)
		Ajustes.guardar_ajustes()
	)
	fila_sfx.add_sibling(fila)

func _seleccionar_escala(indice: int):
	Ajustes.establecer_escala_ui(selector_escala.get_item_id(indice))

func _actualizar_escala(porcentaje: int):
	selector_escala.select(selector_escala.get_item_index(porcentaje))
	ESCALA_UI.aplicar(self, porcentaje)
	selector_escala.get_popup().add_theme_font_size_override("font_size", roundi(0.30 * porcentaje))
	_ajustar_ancho()

func _ajustar_ancho():
	var mitad := minf(560.0 * Ajustes.escala_ui() / 100.0, size.x / 2.0 - 24.0)
	$ContenedorAjustes.offset_left = -mitad
	$ContenedorAjustes.offset_right = mitad

func _unhandled_input(event: InputEvent) -> void:
	if en_partida:
		return
	if accion_esperando.is_empty() and event.is_action_pressed("Atras", false, true):
		get_viewport().set_input_as_handled()
		_on_volver_pressed()
		return
	UIInputManager.manejar_input(event, get_viewport(), boton_volver)

func crear_encabezado() -> void:
	var fila := HBoxContainer.new()

	var espacio := Label.new()
	espacio.text = "Acción"
	espacio.add_theme_color_override("font_color", Color("#19291e"))
	espacio.custom_minimum_size.x = ANCHO_ACCION
	fila.add_child(espacio)

	var label_teclado := Label.new()
	label_teclado.text = "Teclado"
	label_teclado.custom_minimum_size.x = ANCHO_CONTROL
	label_teclado.add_theme_color_override("font_color", Color("#19291e"))
	label_teclado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(label_teclado)

	var label_mando := Label.new()
	label_mando.text = "Mando"
	label_mando.custom_minimum_size.x = ANCHO_CONTROL
	label_mando.add_theme_color_override("font_color", Color("#19291e"))
	label_mando.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(label_mando)

	container.add_child(fila)

func crear_fila(accion: String) -> void:
	var fila := HBoxContainer.new()
	fila.set_meta("accion", accion)

	var label := Label.new()
	label.text = accion.capitalize()
	label.custom_minimum_size.x = ANCHO_ACCION
	label.add_theme_color_override("font_color", Color("#19291e"))
	fila.add_child(label)

	fila.add_child(crear_boton(accion, ControlesManager.Tipo.TECLADO_MOUSE))
	fila.add_child(crear_boton(accion, ControlesManager.Tipo.MANDO))

	container.add_child(fila)

func crear_boton(accion: String, tipo: ControlesManager.Tipo) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(ANCHO_CONTROL, 52)
	boton.clip_text = true
	boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	boton.text = ControlesManager.texto_actual(accion, tipo)
	if accion == "Iniciar Ronda" and tipo == ControlesManager.Tipo.TECLADO_MOUSE:
		boton.text = "Espacio"
		boton.disabled = true
	boton.tooltip_text = boton.text
	boton.pressed.connect(_on_boton_reasignar.bind(boton, accion, tipo))
	return boton

func terminar_captura() -> void:
	accion_esperando = ""
	boton_esperando = null
	set_process_input(en_partida)
	get_viewport().set_input_as_handled()

func _on_boton_reasignar(boton: Button, accion: String, tipo: ControlesManager.Tipo) -> void:
	boton.text = "Presiona..."
	%LabelConflicto.hide()
	accion_esperando = accion
	tipo_esperando = tipo
	boton_esperando = boton
	await get_tree().process_frame
	set_process_input(true)

func _input(event: InputEvent) -> void:
	UIInputManager.manejar_input(event, get_viewport(), boton_volver)
	
	if accion_esperando == "":
		if en_partida and not event.is_echo() and (event.is_action_pressed("Pausa", false, true) or event.is_action_pressed("Atras", false, true)):
			get_viewport().set_input_as_handled()
			_on_volver_pressed()
		return

	var cancelar: bool = event is InputEventKey and event.pressed and (event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE)
	cancelar = cancelar or (accion_esperando != "Atras" and event.is_action_pressed("Atras", false, true))
	cancelar = cancelar or (accion_esperando != "Pausa" and event.is_action_pressed("Pausa", false, true))
	if cancelar:
		boton_esperando.text = ControlesManager.texto_actual(accion_esperando, tipo_esperando)
		%LabelConflicto.hide()
		terminar_captura()
		return

	if not ControlesManager.es_del_tipo(event, tipo_esperando):
		return

	var valido := false
	if event is InputEventKey and event.pressed and not event.echo:
		valido = true
	elif event is InputEventMouseButton and event.pressed:
		valido = true
	elif event is InputEventJoypadButton and event.pressed:
		valido = true
	elif event is InputEventJoypadMotion and abs(event.axis_value) > 0.5:
		valido = true

	if not valido:
		return
		
	var conflicto := ControlesManager.buscar_conflicto(event, accion_esperando, tipo_esperando)
	if conflicto != "":
		%LabelConflicto.text = "Esa tecla ya está en uso en: " + conflicto.capitalize()
		%LabelConflicto.show()
		get_viewport().set_input_as_handled()
		return  # no asignamos, seguimos esperando otra tecla

	%LabelConflicto.hide()
	ControlesManager.borrar_eventos_del_tipo(accion_esperando, tipo_esperando)
	InputMap.action_add_event(accion_esperando, event)
	boton_esperando.text = event.as_text()
	boton_esperando.tooltip_text = boton_esperando.text
	ControlesManager.guardar_controles()
	terminar_captura()
	UIInputManager.manejar_input(event, get_viewport(), boton_volver)

func actualizar_textos_botones() -> void:
	for i in range(1, container.get_child_count()):
		var fila: HBoxContainer = container.get_child(i)
		var accion: String = fila.get_meta("accion")
		var boton_teclado: Button = fila.get_child(1)
		var boton_mando: Button = fila.get_child(2)
		boton_teclado.text = ControlesManager.texto_actual(accion, ControlesManager.Tipo.TECLADO_MOUSE)
		if accion == "Iniciar Ronda":
			boton_teclado.text = "Espacio"
		boton_mando.text = ControlesManager.texto_actual(accion, ControlesManager.Tipo.MANDO)
		boton_teclado.tooltip_text = boton_teclado.text
		boton_mando.tooltip_text = boton_mando.text

func _on_restablecer_pressed() -> void:
	ControlesManager.restablecer_todo()
	actualizar_textos_botones()


func _on_volver_pressed() -> void:
	if en_partida:
		if is_queued_for_deletion():
			return
		set_process_input(false)
		set_process_unhandled_input(false)
		hide()
		queue_free()
		cerrada.emit()
		return
	get_tree().change_scene_to_file("res://escenas/escenas_menu/menu.tscn")
