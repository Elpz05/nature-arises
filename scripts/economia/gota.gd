extends Node2D

signal recogida(cantidad: int)

@export_range(1, 100) var valor := 1
@export_range(1.0, 120.0) var duracion := 20.0
var puede_recoger: Callable
var procesada := false
var casilla_pozo := -1

@onready var expiracion: Timer = $Expiracion

func _ready():
	expiracion.wait_time = duracion
	expiracion.timeout.connect(_expirar)
	expiracion.start()
	queue_redraw()

func _draw():
	var puntos := PackedVector2Array([Vector2(0, -23), Vector2(15, -2), Vector2(17, 9), Vector2(10, 20), Vector2(-10, 20), Vector2(-17, 9), Vector2(-15, -2)])
	draw_colored_polygon(puntos, Color(0.1, 0.65, 1.0, 0.95))
	var borde := puntos.duplicate()
	borde.append(puntos[0])
	draw_polyline(borde, Color(0.7, 0.95, 1.0), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-10, 8), "+%d" % valor, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func contiene_punto(punto_global: Vector2) -> bool:
	return not procesada and not is_queued_for_deletion() and to_local(punto_global).length_squared() <= 26.0 * 26.0

func intentar_recoger() -> bool:
	if procesada or is_queued_for_deletion() or get_tree().paused:
		return false
	if puede_recoger.is_valid() and not puede_recoger.call():
		return false
	procesada = true
	expiracion.stop()
	hide()
	recogida.emit(valor)
	queue_free()
	return true

func _expirar():
	if procesada:
		return
	procesada = true
	hide()
	queue_free()

# Permite usar la escena por separado. En los niveles, el padre intercepta
# el clic antes de la colocación y consume también la liberación del botón.
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("Clic Izquierdo", false, true) or event.is_action_pressed("Confirmar", false, true):
		var punto := get_global_mouse_position()
		if event is InputEventMouseButton:
			punto = to_global(get_global_transform_with_canvas().affine_inverse() * event.position)
		if contiene_punto(punto) and intentar_recoger():
			get_viewport().set_input_as_handled()
