extends Control

@onready var slot1: Button = %Slot1
@onready var slot2: Button = %Slot2
@onready var slot3: Button = %Slot3
@onready var boton_volver: Button = %Volver
@onready var boton_seleccionar: Button = %Seleccionar
@onready var boton_eliminar: Button = %EliminarFile

var slots: Array[Button]
var slot_seleccionado: Button = null

func _ready() -> void:
	slots = [slot1, slot2, slot3]

	for slot in slots:
		slot.toggle_mode = true
		slot.toggled.connect(_on_slot_toggled.bind(slot))

	boton_seleccionar.pressed.connect(_on_seleccionar_pressed)

	UIInputManager.inicializar(slot1)

func _input(event: InputEvent) -> void:
	UIInputManager.manejar_input(event, get_viewport(), slot1)

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

	print("Cargando partida: ", slot_seleccionado.name)
	# Aquí va tu lógica real de cargar el slot

	slot_seleccionado.button_pressed = false
	slot_seleccionado = null

func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/menu.tscn")
