extends Control

@onready var container: VBoxContainer = %KeybindsContainer
@onready var boton_volver: Button = %Volver

var accion_esperando: String = ""
var tipo_esperando: ControlesManager.Tipo = ControlesManager.Tipo.TECLADO_MOUSE
var boton_esperando: Button = null

func _ready() -> void:
	set_process_input(false)
	crear_encabezado()
	for accion in ControlesManager.acciones_configurables:
		crear_fila(accion)
	UIInputManager.inicializar(boton_volver)
	
	print("Mouse mode al entrar a Ajustes: ", Input.mouse_mode)
	print("Mandos conectados: ", Input.get_connected_joypads())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("Mouse motion en _unhandled_input")
	UIInputManager.manejar_input(event, get_viewport(), boton_volver)

func crear_encabezado() -> void:
	var fila := HBoxContainer.new()

	var espacio := Label.new()
	espacio.custom_minimum_size.x = 150
	fila.add_child(espacio)

	var label_teclado := Label.new()
	label_teclado.text = "Teclado"
	label_teclado.custom_minimum_size.x = 140
	label_teclado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(label_teclado)

	var label_mando := Label.new()
	label_mando.text = "Mando"
	label_mando.custom_minimum_size.x = 140
	label_mando.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(label_mando)

	container.add_child(fila)

func crear_fila(accion: String) -> void:
	var fila := HBoxContainer.new()
	fila.set_meta("accion", accion)

	var label := Label.new()
	label.text = accion.capitalize()
	label.custom_minimum_size.x = 150
	fila.add_child(label)

	fila.add_child(crear_boton(accion, ControlesManager.Tipo.TECLADO_MOUSE))
	fila.add_child(crear_boton(accion, ControlesManager.Tipo.MANDO))

	container.add_child(fila)

func crear_boton(accion: String, tipo: ControlesManager.Tipo) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size.x = 140
	boton.text = ControlesManager.texto_actual(accion, tipo)
	boton.pressed.connect(_on_boton_reasignar.bind(boton, accion, tipo))
	return boton

func terminar_captura() -> void:
	accion_esperando = ""
	boton_esperando = null
	set_process_input(false)
	get_viewport().set_input_as_handled()

func _on_boton_reasignar(boton: Button, accion: String, tipo: ControlesManager.Tipo) -> void:
	boton.text = "Presiona..."
	%LabelConflicto.text = ""
	accion_esperando = accion
	tipo_esperando = tipo
	boton_esperando = boton
	await get_tree().process_frame
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		print("Mouse motion detectado en settings")
	UIInputManager.manejar_input(event, get_viewport(), boton_volver)
	
	if accion_esperando == "":
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		boton_esperando.text = ControlesManager.texto_actual(accion_esperando, tipo_esperando)
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
		return  # no asignamos, seguimos esperando otra tecla

	%LabelConflicto.text = ""
	ControlesManager.borrar_eventos_del_tipo(accion_esperando, tipo_esperando)
	InputMap.action_add_event(accion_esperando, event)
	boton_esperando.text = event.as_text()
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
		boton_mando.text = ControlesManager.texto_actual(accion, ControlesManager.Tipo.MANDO)

#func _on_restablecer_pressed() -> void:
	#ControlesManager.restablecer_todo()
	#actualizar_textos_botones()

func _on_restablecer_pressed() -> void:
	ControlesManager.restablecer_todo()
	actualizar_textos_botones()


func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas_menu/menu.tscn")
