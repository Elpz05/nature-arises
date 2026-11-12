extends Node2D

const NOMBRES := {"despejado": "Despejado", "lluvia": "Lluvia", "tormenta": "Tormenta", "volcan": "Volcán", "ventisca": "Ventisca", "derrumbe": "Derrumbe", "radiacion": "Radiación"}
const RAYOS := {"pequeno": {"intervalo": 5.0, "probabilidad": 0.1}, "mediano": {"intervalo": 3.0, "probabilidad": 0.5}, "grande": {"intervalo": 1.0, "probabilidad": 0.9}}
const INTERVALO_RADIACION := 8.0
const DANO_RADIACION := 6
const AVISO_RAYO := 1.2
const AVISO_DERRUMBE := 2.5
const MINIMO_VISIBLE := {"geiser": 1.5, "erupcion": 2.0, "rayo": 1.2, "derrumbe": 2.5, "ventisca": 2.0, "radiacion": 1.5}
const NOMBRES_AVISO := {"geiser": "Géiser", "erupcion": "Erupción", "rayo": "Rayo", "derrumbe": "Derrumbe", "ventisca": "Ventisca", "radiacion": "Radiación"}

var nivel
var tiempo := 0.0
var intervalos: Dictionary = {}
var proximos: Dictionary = {}
var anticipaciones: Dictionary = {}
var avisos: Dictionary = {}
var _ultimo_reloj := -1.0
var calor_activo := false
var ultimo_evento := ""
var conteos: Dictionary = {}
var bajas_arboles: Dictionary = {}
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
	return 1.0

static func factor_velocidad_bestia(clima: String, tipo: String) -> float:
	return 1.2 if clima == "ventisca" and tipo == "glacies" else 1.0

func _ready():
	z_index = 8
	match nivel.clima:
		"tormenta":
			var intervalo: float = RAYOS[nivel.intensidad_tormenta].intervalo
			intervalos = {"aviso_rayo": intervalo}
			anticipaciones["rayo"] = minf(AVISO_RAYO, intervalo * 0.8)
		"volcan": intervalos = {"geiser": 10.0, "erupcion": 25.0}
		"ventisca": intervalos = {"calor": 20.0, "ventisca": 10.0}
		"derrumbe":
			intervalos = {"aviso_derrumbe": 15.0}
			anticipaciones["derrumbe"] = AVISO_DERRUMBE
		"radiacion": intervalos = {"radiacion": INTERVALO_RADIACION}
	for tipo in MINIMO_VISIBLE:
		if not anticipaciones.has(tipo):
			anticipaciones[tipo] = MINIMO_VISIBLE[tipo]
	for evento in intervalos:
		var tipo: String = evento.trim_prefix("aviso_")
		proximos[evento] = intervalos[evento] - (anticipaciones[tipo] if MINIMO_VISIBLE.has(tipo) else 0.0)
	ultimo_evento = {"tormenta": "Rayos: intensidad " + nivel.intensidad_tormenta, "volcan": "Géiser: 10 s | Erupción: 25 s", "ventisca": "Ventisca: 10 s | Calor: 20 s", "derrumbe": "Caída de roca cada 15 s", "radiacion": "Radiación: -6 HP cada 8 s en ronda. Aqua protege sus vecinas; Venenum es inmune."}.get(nivel.clima, "Sin peligros climáticos")
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
	if not _en_ronda() or delta < 0.0:
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
		proximos.erase(evento)
		if evento == "calor":
			proximos[evento] = tiempo + intervalos[evento]
			calor_activo = true
			actualizar_proteccion(true)
			_registrar("Calor de Flamma: deshielo y protección", "calor")
		else:
			_anunciar(evento)
	_avanzar(maxf(0.0, destino - tiempo))
	tiempo = destino
	for tipo in avisos.keys():
		_resolver_aviso(tipo, avisos[tipo])
	queue_redraw()

func _en_ronda() -> bool:
	return nivel.ronda_activa and nivel._puede_jugar()

func _anunciar(evento: String):
	var tipo := evento.trim_prefix("aviso_")
	if not _en_ronda() or avisos.has(tipo):
		return
	var celda := Vector2i(-1, -1)
	var objetivo := 0
	match tipo:
		"rayo":
			if _azar() >= RAYOS[nivel.intensidad_tormenta].probabilidad:
				proximos[evento] = tiempo + intervalos[evento]
				return
			celda = _celda_aleatoria()
		"derrumbe":
			celda = Vector2i(_columna_aleatoria(), nivel.FILAS_BLOQUEADAS)
		"erupcion":
			var arboles := _arboles()
			if arboles.is_empty():
				proximos[evento] = tiempo + intervalos[evento]
				return
			var arbol: Node2D = arboles[_indice_aleatorio(arboles.size())]
			objetivo = arbol.get_instance_id()
			celda = nivel.suelo.local_to_map(nivel.suelo.to_local(arbol.global_position))
	avisos[tipo] = {"evento": evento, "celda": celda, "objetivo": objetivo, "impacto": tiempo + anticipaciones[tipo], "visible": 0.0, "presentado": false}

func _resolver_aviso(tipo: String, aviso: Dictionary):
	if not _en_ronda() or not aviso.presentado or tiempo + 0.000001 < aviso.impacto \
			or aviso.visible + 0.000001 < MINIMO_VISIBLE[tipo]:
		return
	avisos.erase(tipo)
	proximos[aviso.evento] = tiempo + intervalos[aviso.evento] - anticipaciones[tipo]
	var arboles_antes: int = nivel.arboles_plantados.size()
	match tipo:
		"rayo": rayo_en(aviso.celda)
		"derrumbe": derrumbe_en(aviso.celda.x)
		"geiser": emitir_geiseres()
		"erupcion":
			var arbol = nivel.arboles_plantados.get(aviso.celda)
			if is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.get_instance_id() == aviso.objetivo:
				_impactar_erupcion(arbol, aviso.celda)
				_emitir_particulas(tipo, aviso.celda)
		"ventisca": barrer_ventisca()
		"radiacion": radiacion()
	var bajas: int = arboles_antes - nivel.arboles_plantados.size()
	if bajas > 0:
		bajas_arboles[tipo] = bajas_arboles.get(tipo, 0) + bajas
	if tipo != "erupcion":
		_emitir_particulas(tipo, aviso.celda)

func _process(_delta: float):
	var ahora := Time.get_ticks_usec() / 1000000.0
	var real := 0.0 if _ultimo_reloj < 0.0 else ahora - _ultimo_reloj
	_ultimo_reloj = ahora
	presentar_avisos(real)

func presentar_avisos(delta_real: float):
	if not _en_ronda():
		return
	var textos := PackedStringArray()
	for tipo in avisos:
		var aviso: Dictionary = avisos[tipo]
		if aviso.presentado:
			aviso.visible += delta_real
		else:
			aviso.presentado = true
			nivel.presentacion.alerta(tipo)
		var restante := ceilf(_restante(tipo, aviso) * 10.0) / 10.0
		var texto := "%s %.1f s" % [NOMBRES_AVISO[tipo], restante]
		if tipo == "ventisca":
			texto += "   ·   + daño y escarcha   ·   − solo daño"
		textos.append(texto)
	nivel.hud.mostrar_avisos_clima("  ·  ".join(textos))

func _restante(tipo: String, aviso: Dictionary) -> float:
	return maxf(0.0, maxf(MINIMO_VISIBLE[tipo] - aviso.visible, (aviso.impacto - tiempo) / Engine.time_scale))

func ocultar_avisos():
	_ultimo_reloj = -1.0
	visuales.clear()
	nivel.hud.mostrar_avisos_clima("")
	queue_redraw()

func cancelar_avisos():
	avisos.clear()
	nivel.presentacion.cerrar_clima()
	ocultar_avisos()

func cerrar_ronda():
	for tipo in avisos:
		var evento: String = avisos[tipo].evento
		proximos[evento] = tiempo + intervalos[evento] - anticipaciones[tipo]
	cancelar_avisos()

func _emitir_particulas(tipo: String, celda: Vector2i):
	if tipo == "geiser":
		for centro: Vector2i in nivel.celdas_geiser:
			nivel.presentacion.clima_resuelto(tipo, to_global(_punto(centro)))
	elif tipo == "ventisca":
		var mitad := Vector2(nivel.ANCHO, nivel.ALTO - nivel.FILAS_BLOQUEADAS) * 32.0
		var origen := _punto(Vector2i(0, nivel.FILAS_BLOQUEADAS)) - Vector2.ONE * 32.0
		nivel.presentacion.clima_resuelto(tipo, to_global(origen + mitad), mitad)
	else:
		nivel.presentacion.clima_resuelto(tipo, to_global(_punto(celda)))

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
	if not _en_ronda():
		return
	var arbol = nivel.arboles_plantados.get(celda)
	if is_instance_valid(arbol) and arbol.elemento != "electricitas":
		arbol.recibir_dano(arbol.vida)
	for bestia in nivel._bestias_vivas():
		if bestia.tipo != "electricitas" and nivel.suelo.local_to_map(nivel.suelo.to_local(bestia.global_position)) == celda:
			bestia.destruir_por_entorno()
	_registrar("Rayo en casilla %d, %d" % [celda.x, celda.y], "rayo", celda)

func _vecinas_geiser(centro: Vector2i) -> Array[Vector2i]:
	var vecinas: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var celda := centro + Vector2i(x, y)
			if celda != centro and nivel._celda_valida_terreno(celda) and not nivel._reserva_terreno(celda):
				vecinas.append(celda)
	return vecinas

func emitir_geiseres():
	if not _en_ronda():
		return
	for celda: Vector2i in nivel.celdas_geiser:
		for vecina in _vecinas_geiser(celda):
			var arbol = nivel.arboles_plantados.get(vecina)
			if is_instance_valid(arbol) and not arbol.is_queued_for_deletion():
				arbol.aplicar_geiser()
		_registrar("Géiser: 25 de daño y cadencia +25% por 7 s", "geiser", celda)

func erupcion():
	if not _en_ronda():
		return
	var arboles := _arboles()
	if arboles.is_empty():
		_registrar("Erupción: no hay árboles expuestos", "erupcion")
		return
	var arbol = arboles[_indice_aleatorio(arboles.size())]
	var celda: Vector2i = nivel.suelo.local_to_map(nivel.suelo.to_local(arbol.global_position))
	_impactar_erupcion(arbol, celda)

func _impactar_erupcion(arbol, celda: Vector2i):
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
	if not _en_ronda():
		return
	for arbol in _arboles():
		arbol.aplicar_ventisca()
	_registrar("Ventisca: -25 HP y +1 congelación; nivel 3 detiene disparos", "ventisca")

func derrumbe_en(columna: int):
	if not _en_ronda():
		return
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

func _celdas_protegidas_radiacion() -> Dictionary:
	var protegidas := {}
	for celda in nivel.arboles_plantados:
		var aqua = nivel.arboles_plantados[celda]
		if is_instance_valid(aqua) and not aqua.is_queued_for_deletion() and aqua.vida > 0 and aqua.elemento == "aqua":
			for direccion in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				protegidas[celda + direccion] = true
	return protegidas

func actualizar_indicadores_radiacion():
	var protegidas := _celdas_protegidas_radiacion()
	for celda in nivel.arboles_plantados:
		var arbol = nivel.arboles_plantados[celda]
		if is_instance_valid(arbol) and not arbol.is_queued_for_deletion():
			arbol.indicar_proteccion_radiacion(protegidas.has(celda) and arbol.elemento != "venenum")

func radiacion():
	if not _en_ronda():
		return
	var protegidas := _celdas_protegidas_radiacion()
	for celda in nivel.arboles_plantados.keys():
		var arbol = nivel.arboles_plantados.get(celda)
		if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.vida <= 0 or arbol.elemento == "venenum":
			continue
		arbol.recibir_dano(DANO_RADIACION / 2 if protegidas.has(celda) else DANO_RADIACION)
	_registrar("Pulso radiactivo: -6 HP · Junto a Aqua: -3 HP · Venenum inmune", "radiacion")

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
			_dibujar_geiser(_punto(celda))
	for visual in visuales:
		var alpha: float = clampf(visual.restante / 0.8, 0.0, 1.0)
		var punto := _punto(visual.celda)
		match visual.tipo:
			"rayo":
				var origen := Vector2(punto.x - 25.0, tablero.position.y)
				draw_polyline(PackedVector2Array([origen, origen.lerp(punto, 0.4) + Vector2(25, 0), origen.lerp(punto, 0.6) - Vector2(20, 0), punto]), Color(1, 0.95, 0.4, alpha), 5.0, true)
			"geiser":
				draw_rect(_area_geiser(punto, tablero), Color(1, 0.4, 0.1, alpha * 0.25))
			"erupcion":
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
	if nivel.ronda_activa and nivel._puede_jugar():
		for tipo in avisos:
			_dibujar_aviso(tipo, avisos[tipo], tablero)

func _area_geiser(punto: Vector2, tablero: Rect2) -> Rect2:
	var lado: Vector2 = Vector2.ONE * nivel.TAM_CELDA * 3.0
	return Rect2(punto - lado / 2.0, lado).intersection(tablero)

func _dibujar_geiser(punto: Vector2):
	draw_circle(punto, 23.0, Color("#3f302c"))
	draw_circle(punto, 15.0, Color("#ac8067"), false, 3.0, true)
func _dibujar_aviso(tipo: String, aviso: Dictionary, tablero: Rect2):
	var color := Color("#ffdb62")
	if tipo == "ventisca":
		color = Color("#a8ebff")
	elif tipo == "radiacion":
		color = Color("#adf488")
	elif tipo in ["geiser", "erupcion", "derrumbe"]:
		color = Color("#ffa464")
	if tipo == "geiser":
		for centro: Vector2i in nivel.celdas_geiser:
			for celda in _vecinas_geiser(centro):
				var punto := _punto(celda)
				_dibujar_esquinas(Rect2(punto - Vector2.ONE * 28.0, Vector2.ONE * 56.0), color, 10.0)
				draw_polyline(PackedVector2Array([punto + Vector2(-8, 17), punto + Vector2(0, 10), punto + Vector2(8, 17)]), color, 3.0, true)
		return
	if tipo == "erupcion":
		var arbol = nivel.arboles_plantados.get(aviso.celda)
		if not is_instance_valid(arbol) or arbol.get_instance_id() != aviso.objetivo:
			return
		var punto := _punto(aviso.celda)
		var rojo := Color("#ff696d")
		draw_circle(punto, 31.0, Color("#2b1724"), false, 8.0, true)
		draw_circle(punto, 31.0, rojo, false, 4.0, true)
		for direccion in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(punto + direccion * 22.0, punto + direccion * 38.0, rojo, 4.0, true)
		return
	if tipo == "ventisca":
		_dibujar_esquinas(tablero.grow(-4.0), color, 44.0)
		for arbol in _arboles():
			if arbol.elemento in ["flamma", "glacies"]:
				continue
			var punto := to_local(arbol.global_position) + Vector2(18, -19)
			draw_circle(punto, 11.0, Color("#152630"))
			draw_line(punto + Vector2(-7, 0), punto + Vector2(7, 0), color, 2.5, true)
			# La protección evita acumular escarcha. El daño se sigue aplicando.
			if not arbol.protegido_ventisca:
				draw_line(punto + Vector2(0, -7), punto + Vector2(0, 7), color, 2.5, true)
		return
	var area := tablero
	if tipo not in ["ventisca", "radiacion"]:
		var centro := _punto(aviso.celda)
		area = Rect2(centro - Vector2.ONE * 32.0, Vector2.ONE * 64.0)
		if tipo == "derrumbe":
			area.size.y = tablero.size.y
	_marcar_aviso(area, color)

func _marcar_aviso(area: Rect2, color: Color):
	draw_rect(area.grow(-2.0), Color(color, 0.18))
	draw_rect(area.grow(-2.0), color, false, 5.0)

func _dibujar_esquinas(area: Rect2, color: Color, largo: float):
	for x in [0, 1]:
		for y in [0, 1]:
			var origen := area.position + area.size * Vector2(x, y)
			var brazos := PackedVector2Array([
				origen + Vector2(largo * (1 - 2 * x), 0), origen,
				origen + Vector2(0, largo * (1 - 2 * y)),
			])
			draw_polyline(brazos, Color("#17202a"), 7.0, true)
			draw_polyline(brazos, color, 4.0, true)
