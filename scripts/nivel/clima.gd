extends Node2D

const NOMBRES := {"despejado": "Despejado", "lluvia": "Lluvia", "tormenta": "Tormenta", "volcan": "Volcán", "ventisca": "Ventisca", "derrumbe": "Derrumbe", "radiacion": "Radiación"}
const RAYOS := {"pequeno": {"intervalo": 5.0, "probabilidad": 0.1}, "mediano": {"intervalo": 3.0, "probabilidad": 0.5}, "grande": {"intervalo": 1.0, "probabilidad": 0.9}}
const INTOXICACION := {"pequeno": 0.05, "mediano": 0.1, "grande": 0.15}

var nivel
var tiempo := 0.0
var intervalos: Dictionary = {}
var proximos: Dictionary = {}
var calor_activo := false
var ultimo_evento := ""
var conteos: Dictionary = {}
var visuales: Array = []

static func modificadores_arbol(clima: String, elemento: String) -> Dictionary:
	var cadencia := 1.0
	var dano := 0.0
	match clima:
		"lluvia", "tormenta":
			cadencia = 0.75 if clima == "lluvia" else 0.5
			if elemento == "flamma": dano = -0.25 if clima == "lluvia" else -0.5
			if elemento == "electricitas": dano = 0.25 if clima == "lluvia" else 0.35
		"volcan":
			if elemento == "flamma": dano = 0.2
			elif elemento == "glacies": dano = -0.2
			else: cadencia = 1.1
		"ventisca":
			if elemento == "glacies": cadencia = 1.2
			if elemento == "flamma": dano = 0.1
		"radiacion":
			if elemento != "venenum": cadencia = 1.05
	return {"cadencia": cadencia, "dano": dano}

static func factor_vida_bestia(clima: String, tipo: String) -> float:
	if tipo == "flamma" and clima in ["lluvia", "tormenta"]: return 0.5
	if tipo == "glacies" and clima == "volcan": return 0.5
	if tipo == "flamma" and clima == "ventisca": return 1.2
	if tipo == "venenum" and clima == "radiacion": return 1.3
	return 1.0

static func factor_velocidad_bestia(clima: String, tipo: String) -> float:
	return 1.2 if clima == "ventisca" and tipo == "glacies" else 1.0

func _ready():
	z_index = 8
	match nivel.clima:
		"tormenta": intervalos = {"rayo": RAYOS[nivel.intensidad_tormenta].intervalo}
		"volcan": intervalos = {"geiser": 10.0, "erupcion": 25.0}
		"ventisca": intervalos = {"calor": 20.0, "ventisca": 10.0}
		"derrumbe": intervalos = {"derrumbe": 15.0}
		"radiacion": intervalos = {"radiacion": 1.0}
	proximos = intervalos.duplicate()
	ultimo_evento = {"tormenta": "Rayos: intensidad " + nivel.intensidad_tormenta, "volcan": "Géiser: 10 s | Erupción: 25 s", "ventisca": "Ventisca: 10 s | Calor: 20 s", "derrumbe": "Caída de roca cada 15 s", "radiacion": "Radiación: 5 HP/s e intoxicación"}.get(nivel.clima, "Sin peligros climáticos")
	nivel.hud.actualizar_evento_clima(ultimo_evento)
	queue_redraw()

func _arboles() -> Array:
	return nivel.arboles_plantados.values().filter(func(arbol): return is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.vida > 0)

func _azar() -> float:
	return randf()

func _celda_aleatoria() -> Vector2i:
	return Vector2i(randi_range(0, nivel.ANCHO - 1), randi_range(nivel.FILAS_BLOQUEADAS, nivel.ALTO - 1))

func _columna_aleatoria() -> int:
	return randi_range(0, nivel.ANCHO - 1)

func _indice_aleatorio(cantidad: int) -> int:
	return randi_range(0, cantidad - 1)

func actualizar(delta: float):
	if not nivel._puede_jugar() or delta < 0.0:
		return
	actualizar_proteccion()
	var destino := tiempo + delta
	while true:
		var evento := ""
		var siguiente := INF
		for clave in proximos:
			if proximos[clave] < siguiente:
				siguiente = proximos[clave]
				evento = clave
		if evento.is_empty() or siguiente > destino + 0.000001:
			break
		_avanzar(maxf(0.0, siguiente - tiempo))
		tiempo = siguiente
		match evento:
			"rayo":
				if _azar() < RAYOS[nivel.intensidad_tormenta].probabilidad:
					rayo_en(_celda_aleatoria())
			"geiser": emitir_geiseres()
			"erupcion": erupcion()
			"calor":
				calor_activo = true
				actualizar_proteccion(true)
				_registrar("Calor de Flamma: deshielo y protección", "calor")
			"ventisca": barrer_ventisca()
			"derrumbe": derrumbe_en(_columna_aleatoria())
			"radiacion": radiacion()
		proximos[evento] += intervalos[evento]
		actualizar_proteccion()
	_avanzar(maxf(0.0, destino - tiempo))
	tiempo = destino
	queue_redraw()

func _avanzar(delta: float):
	for arbol in _arboles():
		arbol.actualizar_clima(delta)
	for visual in visuales:
		visual.restante -= delta
	visuales = visuales.filter(func(visual): return visual.restante > 0.0)

func _registrar(texto: String, tipo: String, celda := Vector2i(-1, -1)):
	ultimo_evento = texto
	conteos[tipo] = conteos.get(tipo, 0) + 1
	visuales.append({"tipo": tipo, "celda": celda, "restante": 0.8})
	nivel.hud.actualizar_evento_clima(texto)
	queue_redraw()

func rayo_en(celda: Vector2i):
	var arbol = nivel.arboles_plantados.get(celda)
	if is_instance_valid(arbol) and arbol.elemento != "electricitas":
		arbol.recibir_dano(arbol.vida)
	for bestia in nivel._bestias_vivas():
		if bestia.tipo != "electricitas" and nivel.suelo.local_to_map(nivel.suelo.to_local(bestia.global_position)) == celda:
			bestia.destruir_por_entorno()
	_registrar("Rayo en casilla %d, %d" % [celda.x, celda.y], "rayo", celda)

func emitir_geiseres():
	for celda in nivel.celdas_geiser:
		for vecina in nivel.arboles_plantados.keys():
			if vecina != celda and absi(vecina.x - celda.x) <= 1 and absi(vecina.y - celda.y) <= 1:
				var arbol = nivel.arboles_plantados[vecina]
				if is_instance_valid(arbol) and not arbol.is_queued_for_deletion():
					arbol.aplicar_geiser()
		_registrar("Géiser: 25 de daño y cadencia +25% por 7 s", "geiser", celda)

func erupcion():
	var arboles := _arboles()
	if arboles.is_empty():
		_registrar("Erupción: no hay árboles expuestos", "erupcion")
		return
	var arbol = arboles[_indice_aleatorio(arboles.size())]
	var celda: Vector2i = nivel.suelo.local_to_map(nivel.suelo.to_local(arbol.global_position))
	if arbol.elemento != "flamma":
		arbol.recibir_dano(arbol.vida)
	_registrar("Erupción: Flamma resistió" if arbol.elemento == "flamma" else "Erupción: árbol destruido", "erupcion", celda)

func actualizar_proteccion(reducir: bool = false):
	if nivel.clima != "ventisca":
		return
	var llamas: Array = []
	if calor_activo:
		for celda in nivel.arboles_plantados:
			var arbol = nivel.arboles_plantados[celda]
			if is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.vida > 0 and arbol.elemento == "flamma":
				llamas.append(celda)
	for celda in nivel.arboles_plantados:
		var arbol = nivel.arboles_plantados[celda]
		if not is_instance_valid(arbol) or arbol.is_queued_for_deletion():
			continue
		var protegido := false
		for llama in llamas:
			if absi(llama.x - celda.x) <= 1 and absi(llama.y - celda.y) <= 1:
				protegido = true
				break
		arbol.calentar_ventisca(protegido, reducir)

func barrer_ventisca():
	for arbol in _arboles():
		arbol.aplicar_ventisca()
	_registrar("Ventisca: -25 HP y +1 congelación; nivel 3 detiene disparos", "ventisca")

func derrumbe_en(columna: int):
	var fila_tope: int = nivel.ALTO
	for y in range(nivel.FILAS_BLOQUEADAS, nivel.ALTO):
		var arbol = nivel.arboles_plantados.get(Vector2i(columna, y))
		if is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.vida > 0 and arbol.elemento == "terra":
			fila_tope = y
			arbol.recibir_roca()
			break
	for celda in nivel.arboles_plantados.keys():
		if celda.x == columna and celda.y < fila_tope:
			var arbol = nivel.arboles_plantados[celda]
			if is_instance_valid(arbol) and not arbol.is_queued_for_deletion():
				arbol.recibir_dano(arbol.vida)
	for bestia in nivel._bestias_vivas():
		var celda: Vector2i = nivel.suelo.local_to_map(nivel.suelo.to_local(bestia.global_position))
		if celda.x == columna and celda.y < fila_tope:
			bestia.destruir_por_entorno()
	_registrar("Derrumbe en columna %d%s" % [columna, " · Terra bloqueó la roca" if fila_tope < nivel.ALTO else ""], "derrumbe", Vector2i(columna, fila_tope))

func radiacion():
	for arbol in _arboles():
		if arbol.elemento == "venenum":
			continue
		arbol.recibir_dano(5)
		if arbol.vida > 0 and _azar() < INTOXICACION[arbol.tamano]:
			arbol.recibir_dano(arbol.vida)
	_registrar("Radiación: -5 HP; intoxicación 5/10/15% según tamaño", "radiacion")

func _punto(celda: Vector2i) -> Vector2:
	return to_local(nivel.suelo.to_global(nivel.suelo.map_to_local(celda)))

func _draw():
	if not is_instance_valid(nivel):
		return
	var tablero := Rect2(_punto(Vector2i(0, nivel.FILAS_BLOQUEADAS)) - Vector2.ONE * 32.0, Vector2(nivel.ANCHO * 64.0, (nivel.ALTO - nivel.FILAS_BLOQUEADAS) * 64.0))
	var tinte: Color = {"tormenta": Color(0.1, 0.15, 0.4, 0.06), "volcan": Color(1, 0.25, 0.05, 0.05), "ventisca": Color(0.7, 0.9, 1, 0.08), "radiacion": Color(0.5, 1, 0.1, 0.06)}.get(nivel.clima, Color.TRANSPARENT)
	draw_rect(tablero, tinte)
	if nivel.clima == "volcan":
		for celda in nivel.celdas_geiser:
			var punto := _punto(celda)
			draw_circle(punto, 23.0, Color(0.3, 0.16, 0.08))
			draw_circle(punto, 13.0, Color(1, 0.4, 0.1))
			draw_string(ThemeDB.fallback_font, punto + Vector2(-22, 38), "Géiser", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for visual in visuales:
		var alpha: float = clampf(visual.restante / 0.8, 0.0, 1.0)
		var punto := _punto(visual.celda)
		match visual.tipo:
			"rayo":
				var origen := Vector2(punto.x - 25.0, tablero.position.y)
				draw_polyline(PackedVector2Array([origen, origen.lerp(punto, 0.4) + Vector2(25, 0), origen.lerp(punto, 0.6) - Vector2(20, 0), punto]), Color(1, 0.95, 0.4, alpha), 5.0, true)
			"geiser", "erupcion":
				if visual.celda.x >= 0:
					draw_circle(punto, 50.0 * (2.0 - alpha), Color(1, 0.4, 0.1, alpha * 0.35))
			"ventisca", "calor", "radiacion":
				var color := Color(0.7, 0.9, 1.0, alpha * 0.15)
				if visual.tipo == "calor": color = Color(1, 0.5, 0.1, alpha * 0.08)
				if visual.tipo == "radiacion": color = Color(0.6, 1, 0.1, alpha * 0.05)
				draw_rect(tablero, color)
			"derrumbe":
				var fin_y: float = minf(tablero.end.y, punto.y)
				draw_rect(Rect2(Vector2(punto.x - 30.0, tablero.position.y), Vector2(60.0, maxf(0.0, fin_y - tablero.position.y))), Color(0.6, 0.5, 0.35, alpha * 0.4))
				draw_circle(Vector2(punto.x, fin_y - 25.0), 25.0, Color(0.45, 0.4, 0.3, alpha))
