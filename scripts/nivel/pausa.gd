extends CanvasLayer

signal guia_solicitada
signal reanudar_solicitado

const ESCENA_AJUSTES = preload("res://escenas/escenas_menu/settings_menu.tscn")

@export_file("*.tscn") var escena_salida: String
@export var sonido_hover: AudioStream
@export var sonido_abrir: AudioStream

var numero_nivel := 0
var ajustes
var hover_boton: AudioStreamPlayer

@onready var panel_principal: Control = %PanelPrincipal
@onready var boton_continuar: Button = %Continuar
@onready var boton_guia: Button = %Guia
@onready var boton_ajustes: Button = %Ajustes
@onready var boton_salir: Button = %Salir

func _ready() -> void:
	boton_continuar.pressed.connect(_continuar)
	boton_guia.pressed.connect(func(): guia_solicitada.emit())
	boton_ajustes.pressed.connect(_abrir_ajustes)
	boton_salir.pressed.connect(_salir)
	panel_principal.add_child(preload("res://scripts/HUD/escala_interfaz.gd").new())
	hover_boton = AudioStreamPlayer.new()
	hover_boton.stream = sonido_hover
	hover_boton.bus = "UI"
	add_child(hover_boton)
	for boton in [boton_continuar, boton_guia, boton_ajustes, boton_salir]:
		boton.mouse_entered.connect(_on_hover)
		boton.pressed.connect(AudioUI.click_madera)
	if sonido_abrir != null:
		var abrir := AudioStreamPlayer.new()
		abrir.stream = sonido_abrir
		abrir.bus = "UI"
		add_child(abrir)
		abrir.play()
	boton_continuar.grab_focus()

func _abrir_ajustes() -> void:
	if is_instance_valid(ajustes):
		return
	ajustes = ESCENA_AJUSTES.instantiate()
	ajustes.en_partida = true
	ajustes.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel_principal.hide()
	add_child(ajustes)
	ajustes.cerrada.connect(func():
		ajustes = null
		panel_principal.show()
		boton_ajustes.grab_focus()
	)

func _input(event: InputEvent) -> void:
	if not visible or is_instance_valid(ajustes) or event.is_echo():
		return
	if event.is_action_pressed("Abrir Codice", false, true):
		get_viewport().set_input_as_handled()
		guia_solicitada.emit()
		return
	if event.is_action_pressed("Pausa", false, true) or event.is_action_pressed("Atras", false, true):
		get_viewport().set_input_as_handled()
		_continuar()

func _continuar() -> void:
	if not visible or is_instance_valid(ajustes) or is_queued_for_deletion():
		return
	hide()
	set_process_input(false)
	queue_free()
	reanudar_solicitado.emit()

func _salir() -> void:
	if Guardado.slot_actual >= 0:
		var actual: int = Guardado.datos.get("nivel_actual", 0)
		Guardado.datos["nivel_actual"] = maxi(actual, numero_nivel)
		Guardado.guardar()
	get_tree().paused = false
	if escena_salida != "":
		get_tree().change_scene_to_file(escena_salida)

func _on_hover() -> void:
	if sonido_hover != null:
		hover_boton.play()
