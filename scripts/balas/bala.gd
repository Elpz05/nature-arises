extends Node2D

var objetivo: Node2D
var dano := 0
var elemento := "natura"
var modificador_dano := 0.0
var velocidad := 400.0
var radio_explosion := 0.0
var factor_lentitud := 1.0
var duracion_lentitud := 0.0
var duracion_congelacion := 0.0
var dano_veneno := 0.0
var duracion_veneno := 0.0
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
		var modificador := modificador_dano
		if elemento == "flamma":
			if bestia.has_method("remover_congelacion"):
				bestia.remover_congelacion()
			# La inmunidad Aqua prevalece sobre los bonos de entorno.
			if bestia.tipo == "aqua":
				return
			modificador += {"flamma": -0.25, "glacies": 0.25, "natura": 0.05}.get(bestia.tipo, 0.0)
		elif elemento == "glacies":
			modificador += {"glacies": -0.1, "aqua": 0.1, "flamma": 0.15}.get(bestia.tipo, 0.0)
		elif elemento == "electricitas":
			modificador += {"electricitas": -0.5, "aqua": 0.1}.get(bestia.tipo, 0.0)
		elif elemento == "venenum":
			modificador += {"venenum": -0.3, "natura": 0.1}.get(bestia.tipo, 0.0)
		var cantidad := dano * maxf(0.0, 1.0 + modificador)
		if bestia.has_method("recibir_proyectil"):
			bestia.recibir_proyectil(cantidad)
		else:
			bestia.recibir_dano(cantidad)
	if duracion_congelacion > 0.0 and bestia.has_method("aplicar_congelacion"):
		bestia.aplicar_congelacion(duracion_congelacion)
	if duracion_lentitud > 0.0 and bestia.has_method("aplicar_lentitud"):
		bestia.aplicar_lentitud(factor_lentitud, duracion_lentitud)
	if duracion_veneno > 0.0 and bestia.has_method("aplicar_veneno"):
		bestia.aplicar_veneno(dano_veneno, factor_lentitud, duracion_veneno)
