extends Node

var boton_con_hover: Button = null

func _ready() -> void:
	Input.joy_connection_changed.connect(_al_conectar_mando)

func _exit_tree() -> void:
	Input.joy_connection_changed.disconnect(_al_conectar_mando)

func _al_conectar_mando(_dispositivo: int, conectado: bool) -> void:
	if conectado:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func inicializar(boton_default: Button) -> void:
	if Input.get_connected_joypads().size() > 0:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		boton_default.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		boton_default.grab_focus()

func manejar_input(event: InputEvent, viewport: Viewport, boton_default: Button) -> void:
	if event is InputEventKey and (event.is_action_pressed("Confirmar") or event.is_action_pressed("Izquierda") or event.is_action_pressed("Derecha") or event.is_action_pressed("Arriba") or event.is_action_pressed("Abajo")):
		if not viewport.gui_get_focus_owner():
			boton_default.grab_focus()
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var enfocado := viewport.gui_get_focus_owner()
		if enfocado:
			enfocado.release_focus()
		return

	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.3):
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			if boton_con_hover:
				boton_con_hover._forzar_salida_mouse()
		if not viewport.gui_get_focus_owner():
			boton_default.grab_focus()

func _forzar_salida_de_hover(viewport: Viewport) -> void:
	var bajo_mouse: Control = viewport.gui_find_control(viewport.get_mouse_position())
	if bajo_mouse and bajo_mouse.has_method("_forzar_normal"):
		bajo_mouse._forzar_normal()
