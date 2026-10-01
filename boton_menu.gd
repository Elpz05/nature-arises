extends Button

@export var escala_hover: float = 1.15
@export var duracion: float = 0.1
@export var sonido_hover: AudioStream
@export var sonido_click: AudioStream

var escala_original: Vector2
var con_hover: bool = false
var con_focus: bool = false

func _ready() -> void:
	escala_original = scale
	pivot_offset = size / 2

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)

func _on_mouse_entered() -> void:
	con_hover = true
	UIInputManager.boton_con_hover = self
	_actualizar_visual()
	AudioUI.reproducir_hover(sonido_hover)

func _on_mouse_exited() -> void:
	con_hover = false
	if UIInputManager.boton_con_hover == self:
		UIInputManager.boton_con_hover = null
	_actualizar_visual()

func _on_focus_entered() -> void:
	con_focus = true
	_actualizar_visual()
	AudioUI.reproducir_hover(sonido_hover)

func _on_focus_exited() -> void:
	con_focus = false
	_actualizar_visual()

func _forzar_normal() -> void:
	con_hover = false
	if UIInputManager.boton_con_hover == self:
		UIInputManager.boton_con_hover = null
	_actualizar_visual()

func _actualizar_visual() -> void:
	var tween := create_tween()
	if con_hover or con_focus:
		tween.tween_property(self, "scale", escala_original * escala_hover, duracion)
	else:
		tween.tween_property(self, "scale", escala_original, duracion)

func _on_pressed() -> void:
	print("Click en: ", name, " | sonido: ", sonido_click)
	AudioUI.reproducir_click(sonido_click)

func _forzar_salida_mouse() -> void:
	if not con_hover:
		return
	var filtro_original := mouse_filter
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = filtro_original
