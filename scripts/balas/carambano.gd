extends "res://scripts/balas/bala.gd"

var maximo_objetivos := 3
var distancia_maxima := 192.0
var direccion := Vector2.ZERO
var distancia_recorrida := 0.0
var golpeados: Dictionary = {}
const RADIO_IMPACTO := 16.0

func _ready():
	super._ready()
	$Sprite2D.hide()
	queue_redraw()

func _draw():
	draw_colored_polygon(PackedVector2Array([Vector2(17, 0), Vector2(-11, -5), Vector2(-6, 0), Vector2(-11, 5)]), color_bala)

func _physics_process(delta: float):
	if impacto or is_queued_for_deletion() or delta <= 0.0:
		return
	if direccion == Vector2.ZERO:
		if not is_instance_valid(objetivo) or objetivo.is_queued_for_deletion() or objetivo.get("muerto") == true:
			queue_free()
			return
		direccion = global_position.direction_to(objetivo.global_position)
		if direccion == Vector2.ZERO:
			direccion = Vector2.RIGHT
		rotation = direccion.angle()
	var paso := minf(velocidad * delta, distancia_maxima - distancia_recorrida)
	var inicio := global_position
	var fin := inicio + direccion * paso
	var victimas: Array = []
	for bestia in get_tree().get_nodes_in_group("bestias"):
		if bestia.is_queued_for_deletion() or bestia.muerto or bestia.get_parent().is_queued_for_deletion() or golpeados.has(bestia.get_instance_id()):
			continue
		var cercano := Geometry2D.get_closest_point_to_segment(bestia.global_position, inicio, fin)
		if cercano.distance_squared_to(bestia.global_position) <= RADIO_IMPACTO * RADIO_IMPACTO:
			victimas.append(bestia)
	# El impacto sigue el orden espacial aunque los enemigos nacieran en otro orden.
	victimas.sort_custom(func(a, b): return (a.global_position - inicio).dot(direccion) < (b.global_position - inicio).dot(direccion))
	var confirmados := PackedVector2Array()
	for bestia in victimas:
		golpeados[bestia.get_instance_id()] = true
		var punto: Vector2 = bestia.global_position
		if _golpear(bestia):
			confirmados.append(punto)
		if golpeados.size() >= maximo_objetivos:
			impacto = true
			break
	if not confirmados.is_empty():
		_presentar_impacto(confirmados[0], confirmados)
	global_position = fin
	distancia_recorrida += paso
	if impacto or distancia_recorrida >= distancia_maxima:
		queue_free()
