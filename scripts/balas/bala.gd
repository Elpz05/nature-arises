extends Node2D

var objetivo: Node2D
var dano := 0
var velocidad := 400.0
var radio_explosion := 0.0
var factor_lentitud := 1.0
var duracion_lentitud := 0.0
var color_bala := Color(0.125, 1, 0)
var impacto := false

@onready var sonidoBala: AudioStreamPlayer = $SonidoBala

func _ready():
	$Sprite2D.modulate = color_bala
	sonidoBala.play()

func _process(delta):
	if impacto or is_queued_for_deletion():
		return
	# Si el objetivo murió o desapareció, la semilla se destruye
	if not is_instance_valid(objetivo) or objetivo.is_queued_for_deletion() \
			or (objetivo.get("muerto") == true):
		queue_free()
		return

	# Teledirigida: recalcula la dirección en cada fotograma
	global_position = global_position.move_toward(objetivo.global_position, velocidad * delta)

	# Impacto
	if global_position.distance_to(objetivo.global_position) < 10.0:
		impacto = true
		if radio_explosion > 0.0:
			# Captura las víctimas antes del daño: las copias nacidas de este
			# impacto no reciben un segundo golpe de la misma explosión.
			var victimas: Array[Node] = []
			for bestia in get_tree().get_nodes_in_group("bestias"):
				if bestia.global_position.distance_squared_to(objetivo.global_position) <= radio_explosion * radio_explosion:
					victimas.append(bestia)
			for bestia in victimas:
				_golpear(bestia)
		else:
			_golpear(objetivo)
		queue_free()

func _golpear(bestia: Node2D):
	if not is_instance_valid(bestia) or bestia.is_queued_for_deletion() or bestia.get("muerto") == true:
		return
	if bestia.has_method("recibir_dano"):
		bestia.recibir_dano(dano)
	if duracion_lentitud > 0.0 and bestia.has_method("aplicar_lentitud"):
		bestia.aplicar_lentitud(factor_lentitud, duracion_lentitud)
