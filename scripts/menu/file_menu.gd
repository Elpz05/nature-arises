extends Control

const ESCALA_UI = preload("res://scripts/HUD/escala_interfaz.gd")

@onready var slot1: Button = %Slot1
@onready var slot2: Button = %Slot2
@onready var slot3: Button = %Slot3
@onready var boton_volver: Button = %Volver
@onready var boton_seleccionar: Button = %Seleccionar
@onready var boton_eliminar: Button = %EliminarFile

@onready var estados: Array[Label] = [
	$ContenedorSlots/Slot1/labelArchivo1,
	$ContenedorSlots/Slot2/labelArchivo2,
	$ContenedorSlots/Slot3/labelArchivo3,
]

var slots: Array[Button]
var slot_seleccionado: Button = null
var dialogo: ConfirmationDialog

func _ready() -> void:
	slots = [slot1, slot2, slot3]

	for slot in slots:
		slot.toggle_mode = true
		slot.toggled.connect(_on_slot_toggled.bind(slot))
		for estado in ["font_focus_color", "font_hover_color", "font_pressed_color"]:
			slot.add_theme_color_override(estado, Color.BLACK)

	boton_seleccionar.pressed.connect(_on_seleccionar_pressed)
	boton_eliminar.pressed.connect(_on_eliminar_pressed)

	dialogo = ConfirmationDialog.new()
	dialogo.dialog_text = "¿Eliminar este archivo? No se puede deshacer."
	dialogo.theme = preload("res://fuentes/interfaz.tres")
	dialogo.confirmed.connect(_borrar_confirmado)
	add_child(dialogo)
	for control in [dialogo.get_label(), dialogo.get_ok_button(), dialogo.get_cancel_button()]:
		ESCALA_UI.aplicar(control, Ajustes.escala_ui())

	_refrescar()
	$Acciones.move_child(boton_eliminar, 1)
	add_child(ESCALA_UI.new())
	UIInputManager.inicializar(slot1)
	
	MusicaManager.reproducir(preload("res://audios/menu_musica/Forest 01.ogg"))

func _input(event: InputEvent) -> void:
	UIInputManager.manejar_input(event, get_viewport(), slot1)

func _refrescar() -> void:
	for i in slots.size():
		if Guardado.existe(i):
			var d: Dictionary = Guardado.leer(i)
			var actual: int = d.get("nivel_actual", 0)
			slots[i].text = "Campaña\nCompletada" if Guardado.campana_completada(d) else "Nivel Actual\n%d/%d" % [mini(actual + 1, Guardado.NIVELES.size()), Guardado.NIVELES.size()]
		else:
			slots[i].text = "Nueva\nPartida"

func _on_slot_toggled(presionado: bool, slot: Button) -> void:
	if presionado:
		for otro in slots:
			if otro != slot:
				otro.button_pressed = false
		slot_seleccionado = slot
		boton_seleccionar.grab_focus()
	elif slot_seleccionado == slot:
		slot_seleccionado = null

func _on_seleccionar_pressed() -> void:
	if slot_seleccionado == null:
		return
	Guardado.entrar(slots.find(slot_seleccionado))

func _on_eliminar_pressed() -> void:
	if slot_seleccionado == null:
		return
	if not Guardado.existe(slots.find(slot_seleccionado)):
		return
	dialogo.popup_centered()

func _borrar_confirmado() -> void:
	var i := slots.find(slot_seleccionado)
	Guardado.borrar(i)
	slot_seleccionado.button_pressed = false
	slot_seleccionado = null
	_refrescar()

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/escenas_menu/menu.tscn")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("Atras"):
		get_viewport().set_input_as_handled()
		if dialogo.visible:
			dialogo.hide()
		else:
			_on_volver_pressed()
