extends "res://scripts/balas/bala.gd"

var maximo_objetivos := 3
var candidatos: Array = []
var radio_salto := 128.0
var duracion_visual := 0.18
var puntos := PackedVector2Array()
var golpeados: Array = []

func _ready():
	super._ready()
	$Sprite2D.hide()

func _valido(bestia) -> bool:
	return is_instance_valid(bestia) and bestia.is_inside_tree() \
		and not bestia.is_queued_for_deletion() and not bestia.muerto \
		and not bestia.get_parent().is_queued_for_deletion()

func _physics_process(delta: float):
	if is_queued_for_deletion():
		return
	if not impacto:
		impacto = true
		_descargar()
		queue_redraw()
	else:
		duracion_visual -= delta / Engine.time_scale
		if duracion_visual <= 0.0:
			queue_free()

func _descargar():
	if not _valido(objetivo):
		queue_free()
		return
	# Se decide toda la cadena antes del daño: ni copias ni renacimientos
	# pueden recibir otro impacto de la misma descarga.
	var disponibles := candidatos.filter(_valido)
	var actual: Node2D = objetivo
	puntos.append(Vector2.ZERO)
	while actual != null and golpeados.size() < maximo_objetivos:
		golpeados.append(actual)
		puntos.append(to_local(actual.global_position))
		var siguiente: Node2D = null
		var menor := radio_salto * radio_salto
		for bestia in disponibles:
			if golpeados.has(bestia):
				continue
			var distancia: float = actual.global_position.distance_squared_to(bestia.global_position)
			if distancia <= menor:
				menor = distancia
				siguiente = bestia
		actual = siguiente
	var confirmados := PackedVector2Array()
	for i in golpeados.size():
		if _golpear(golpeados[i]):
			confirmados.append(to_global(puntos[i + 1]))
	if not confirmados.is_empty():
		_presentar_impacto(confirmados[0], confirmados)
	# El dibujo usa las posiciones capturadas, aunque una víctima desaparezca.
	candidatos.clear()

func _draw():
	for i in range(puntos.size() - 1):
		var desde := puntos[i]
		var hasta := puntos[i + 1]
		var normal := (hasta - desde).normalized().orthogonal() * 7.0
		var trazo := PackedVector2Array([desde, desde.lerp(hasta, 0.3) + normal, desde.lerp(hasta, 0.65) - normal, hasta])
		draw_polyline(trazo, color_bala, 4.0, true)
		draw_polyline(trazo, Color.WHITE, 1.5, true)
