extends Node2D

signal agua_recogida(cantidad: int)
signal reserva_cambiada(cantidad: int)

const CAPACIDAD := 5
const RADIO := 30.0
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")

var generando := false
var reserva := 0
var _fraccion := 0.0

func activar_generacion(activa: bool):
	generando = activa

func acumular(delta: float, produccion: float):
	if not generando or reserva >= CAPACIDAD or delta <= 0.0:
		return
	_fraccion += produccion * delta
	var completas := floori(_fraccion + 0.000001)
	if completas == 0:
		return
	reserva = mini(CAPACIDAD, reserva + completas)
	_fraccion = 0.0 if reserva == CAPACIDAD else maxf(0.0, _fraccion - completas)
	reserva_cambiada.emit(reserva)
	queue_redraw()

func contiene_punto(punto_global: Vector2) -> bool:
	return to_local(punto_global).length_squared() <= RADIO * RADIO

func recoger() -> bool:
	if reserva == 0:
		return false
	var cantidad := reserva
	reserva = 0
	reserva_cambiada.emit(reserva)
	queue_redraw()
	agua_recogida.emit(cantidad)
	return true

func _draw():
	draw_circle(Vector2.ZERO, RADIO, Color(0.18, 0.19, 0.17))
	draw_circle(Vector2.ZERO, 26.0, Color("#b5ebff") if reserva > 0 else Color("#819da7"))
	draw_circle(Vector2.ZERO, 22.0, Color("#173b51"))
	ICONOS.dibujar(self, "gota", Vector2(0, -8), 1.25, false, reserva > 0)
	var texto := "%d/%d" % [reserva, CAPACIDAD]
	var fuente := ThemeDB.fallback_font
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(fuente, Vector2(-ancho / 2.0, 16), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
