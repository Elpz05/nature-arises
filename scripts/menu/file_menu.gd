extends Control

@onready var slot1: Button = %Slot1
@onready var slot2: Button = %Slot2
@onready var slot3: Button = %Slot3
@onready var boton_volver: Button = %Volver
@onready var boton_seleccionar: Button = %Seleccionar
@onready var boton_eliminar: Button = %EliminarFile

@onready var estados: Array[Label] = [
	$ContenedorSlots/Slot1/Label,
	$ContenedorSlots/Slot2/Label,
	$ContenedorSlots/Slot3/Label,
]

var slots: Array[Button]
var slot_seleccionado: Button = null
var dialogo: ConfirmationDialog

func _ready() -> void:
	slots = [slot1, slot2, slot3]

	for slot in slots:
		slot.toggle_mode = true
		slot.toggled.connect(_on_slot_toggled.bind(slot))

	boton_seleccionar.pressed.connect(_on_seleccionar_pressed)
	boton_eliminar.pressed.connect(_on_eliminar_pressed)

	dialogo = ConfirmationDialog.new()
	dialogo.dialog_text = "¿Eliminar este archivo? No se puede deshacer."
	dialogo.confirmed.connect(_borrar_confirmado)
	add_child(dialogo)

	_refrescar()
	UIInputManager.inicializar(slot1)

func _input(event: InputEvent) -> void:
	UIInputManager.manejar_input(event, get_viewport(), slot1)

func _refrescar() -> void:
	for i in slots.size():
		if Guardado.existe(i):
			var d: Dictionary = Guardado.leer(i)
			var hechos: int = d.get("niveles_completados", []).size()
			slots[i].text = "Niveles\n%d/5" % hechos
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
	get_tree().change_scene_to_file("res://escenas_menu/menu.tscn")
