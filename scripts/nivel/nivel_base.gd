class_name NivelBase
extends Node2D

@export var espiritu_escena: PackedScene
@export var bestias_escenas: Array[PackedScene]
@export var musica_nivel: AudioStream
@export var celdas_bloqueadas: Array[Vector2i] = []
@export var intervalos_spawn: Array[float] = [3.0, 2.6, 2.2, 1.8, 1.5]
@export var arbol_madre_escena: PackedScene
@export var hud_escena: PackedScene
@export var semillas_escenas: Array[PackedScene]
@export var pausa_escena: PackedScene
@export var numero_nivel := 0          # 0 en nivel_0, 1 en el siguiente, etc.
@export var victoria_escena: PackedScene
@export var desbloqueos: Array[int] = [1, 2]
@export var desbloqueos_ataques: Array[int] = [1]
@export var derrota_escena: PackedScene
@export var sonidos_ataque: Array[AudioStream] = []
@export var sonido_dano_arbol: AudioStream
@export var pozo_escena: PackedScene = preload("res://escenas/escenas_economia/pozo.tscn")
@export var celda_pozo := Vector2i(14, 8)
@export_enum("despejado", "lluvia", "tormenta", "volcan", "ventisca", "derrumbe", "radiacion") var clima := "despejado"
@export_enum("pequeno", "mediano", "grande") var intensidad_tormenta := "mediano"
@export var celdas_inundadas: Array[Vector2i] = []
@export var celdas_geiser: Array[Vector2i] = []
var gestor_clima: Node2D

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var capa_atajo := get_node_or_null("Atajo") as TileMapLayer
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles

const ANCHO := 30
const ALTO := 17
const TAM_CELDA := 64

const TAMANOS := ["pequeno", "mediano", "grande"]
const NOMBRES_TAMANO := ["pequeño", "mediano", "grande"]
const GOTAS_INICIALES := 3
@export var gotas_iniciales := GOTAS_INICIALES
@export var titulo_nivel := ""
@export_multiline var consejo_nivel := ""
var consejos_ronda: Array[String] = []
const RECARGA_ATAQUE := 3.0
const FILAS_BLOQUEADAS := 3
const TIPOS_BESTIA := ["natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum"]

# Los hijos rellenan estos datos en _configurar_nivel(), antes de generar el mapa.
var puntos_ruta: Array = []
var rondas: Array = []
var celda_arbol_madre := Vector2i.ZERO
var rutas_adicionales: Array = []
var rutas_enemigos: Dictionary = {}
var inicializado := false

var hud
var source_pasto: int
var source_camino: int
var celdas_ocupadas := {}
var arbol_meta

var gotas := GOTAS_INICIALES
var _tiempo_ventus := 0.0
var _contactos_aqua: Dictionary = {}
var _dano_aura_acumulado: Dictionary = {}
var _atajos: Dictionary = {}
var _distancias_por_ruta: Dictionary = {}
var pozo: Node2D
var _clic_gota_consumido := false
var datos_rango_colocacion: Dictionary = {}
var usar_cursor_tablero := false
var cursor_tablero := Vector2i(15, 8)
var _direccion_cursor := Vector2i.ZERO
var _espera_cursor := 0.0
var terminado := false

var ronda := 1
var ronda_activa := false
var cola_bestias: Array = []
var tipos_plantados := {}        # celda -> índice de semilla
var tamanos_plantados := {}      # celda -> 0 pequeño, 1 mediano, 2 grande
var tooltip: Label
var panel_torre: PanelContainer
var celda_torre_seleccionada := Vector2i(-1, -1)
var torre_informada: Node2D
var _acum_spawn := 0.0

var seleccion_tipo := ""          # "", "semilla" o "ataque"
var seleccion_indice := -1
var arrastrando := false

var cargas: Array[float] = []
var recarga: Array[float] = []
var vista: Node2D

var arboles_plantados := {}
var costos_plantados := {}

var pausa

var sfx_ataque: AudioStreamPlayer
var sfx_arbol: AudioStreamPlayer

# Punto de extensión: solo datos, sin duplicar _ready() ni llamar super.
func _configurar_nivel() -> void:
	pass

func _validar_configuracion() -> bool:
	if not preload("res://scripts/nivel/clima.gd").NOMBRES.has(clima) or not preload("res://scripts/nivel/clima.gd").RAYOS.has(intensidad_tormenta):
		push_error("Clima o intensidad de tormenta inválidos.")
		return false
	if rondas.is_empty() or rondas.size() > intervalos_spawn.size():
		push_error("El nivel necesita rondas e intervalos de aparición compatibles.")
		return false
	for intervalo in intervalos_spawn:
		if intervalo <= 0.0:
			push_error("Los intervalos de aparición deben ser positivos.")
			return false
	if suelo.tile_set == null or camino.tile_set == null:
		push_error("Asigna los TileSets del nivel en Suelo y Camino.")
		return false
	if suelo.tile_set.get_source_count() == 0 or camino.tile_set.get_source_count() == 0:
		push_error("Los TileSets necesitan al menos una fuente de tiles.")
		return false
	if hud_escena == null or arbol_madre_escena == null or pausa_escena == null \
			or victoria_escena == null or derrota_escena == null:
		push_error("Faltan escenas compartidas del nivel.")
		return false
	for receta in rondas:
		for clave in receta:
			var partes := String(clave).split(":")
			if partes.size() != 2 or not TIPOS_BESTIA.has(partes[0]) or not TAMANOS.has(partes[1]):
				push_error("Usa tipo:tamano en las recetas de ronda: %s" % clave)
				return false
			if _escena_para_tipo(partes[0]) == null:
				push_error("Falta la escena de la bestia de la ronda: %s" % partes[0])
				return false
	var recorridos: Array = [puntos_ruta]
	if not rutas_adicionales.is_empty():
		if capa_atajo == null or capa_atajo.tile_set == null or capa_atajo.tile_set.get_source_count() == 0:
			push_error("Falta la capa Atajo o su TileSet.")
			return false
		for datos in rutas_adicionales:
			recorridos.append(datos.tramo)
	for puntos in recorridos:
		if puntos.size() < 2:
			push_error("Cada ruta necesita al menos dos puntos.")
			return false
		for celda: Vector2i in puntos:
			if celda.x < 0 or celda.x >= ANCHO or celda.y < FILAS_BLOQUEADAS or celda.y >= ALTO:
				push_error("Las rutas deben permanecer en las filas jugables.")
				return false
		for i in range(puntos.size() - 1):
			var desde: Vector2i = puntos[i]
			var hasta: Vector2i = puntos[i + 1]
			if desde == hasta or (desde.x != hasta.x and desde.y != hasta.y):
				push_error("Las rutas del tablero deben usar tramos horizontales o verticales de longitud positiva.")
				return false
		var celdas := _celdas_de(puntos)
		if _distancias_de(celdas).size() != celdas.size():
			push_error("Un recorrido no puede repetir casillas.")
			return false
	if not _preparar_atajos():
		return false
	if pozo_escena == null or not _se_puede_plantar(celda_pozo) or celda_pozo == celda_arbol_madre or celdas_bloqueadas.has(celda_pozo):
		push_error("El pozo necesita una escena y una celda libre dentro del tablero.")
		return false
	for puntos in recorridos:
		if _celdas_de(puntos).has(celda_pozo):
			push_error("El pozo no puede ocupar un camino de enemigos.")
			return false
	if clima == "volcan":
		for celda in celdas_geiser:
			if not _se_puede_plantar(celda) or celda == celda_pozo or celdas_bloqueadas.has(celda):
				push_error("Los géiseres necesitan casillas libres dentro del tablero.")
				return false
			for puntos in recorridos:
				if _celdas_de(puntos).has(celda):
					push_error("Un géiser no puede ocupar un camino.")
					return false
	return true

func _puede_jugar() -> bool:
	return inicializado and not terminado and not get_tree().paused

func _ready():
	_configurar_nivel()
	gotas = gotas_iniciales
	if not _validar_configuracion():
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	source_pasto = suelo.tile_set.get_source_id(0)
	source_camino = camino.tile_set.get_source_id(0)

	_crear_hud()
	_generar_tablero()
	_generar_camino()
	if clima == "volcan":
		for celda in celdas_geiser:
			celdas_ocupadas[celda] = true
	_marcar_inundaciones()
	_generar_curva()
	_crear_arbol_madre()
	_crear_pozo()
	_crear_vista()
	_crear_tooltip()
	if musica_nivel != null:
		MusicaManager.reproducir(musica_nivel)

	for i in hud.ATAQUES.size():
		cargas.append(hud.ATAQUES[i].capacidad)
		recarga.append(0.0)
		hud.actualizar_ataque(i, cargas[i], hud.ATAQUES[i].capacidad)

	hud.actualizar_gotas(gotas)
	_actualizar_ronda_hud()
	hud.mostrar_boton_ronda("Iniciar ronda %d" % ronda, true)

	sfx_ataque = AudioStreamPlayer.new()
	sfx_ataque.bus = "SFX"
	add_child(sfx_ataque)

	sfx_arbol = AudioStreamPlayer.new()
	sfx_arbol.stream = sonido_dano_arbol
	sfx_arbol.bus = "SFX"
	add_child(sfx_arbol)
	inicializado = true
	gestor_clima = preload("res://scripts/nivel/clima.gd").new()
	gestor_clima.nivel = self
	add_child(gestor_clima)
	hud.actualizar_produccion(obtener_produccion_agua(), clima)
	_actualizar_combate_hud()
# ---------------- HUD ----------------
func _crear_hud():
	hud = hud_escena.instantiate()
	add_child(hud)
	if not titulo_nivel.is_empty():
		hud.mostrar_mision("%d/%d · %s" % [numero_nivel + 1, Guardado.NIVELES.size(), titulo_nivel], consejo_nivel)
	if Guardado.slot_actual < 0:
		var disponibles: Dictionary = preload("res://scripts/nivel/campana.gd").disponibles_para_nivel(numero_nivel)
		hud.SEMILLAS_ACTIVAS = disponibles.plantas
		hud.ATAQUES_ACTIVOS = disponibles.ataques
	hud.semilla_pulsada.connect(_on_semilla_pulsada)
	hud.ataque_pulsado.connect(_on_ataque_pulsado)
	hud.ronda_solicitada.connect(_iniciar_ronda)
	hud.pala_pulsada.connect(_on_pala_pulsada)
	for i in semillas_escenas.size():
		if semillas_escenas[i] != null:
			hud.plantas_disponibles.append(i)

func _crear_pozo():
	if pozo_escena == null or not _se_puede_plantar(celda_pozo):
		push_error("Asigna una escena de pozo y una celda libre para la economía del nivel.")
		return
	pozo = pozo_escena.instantiate()
	pozo.position = suelo.map_to_local(celda_pozo)
	pozo.agua_recogida.connect(_recoger_gotas)
	pozo.reserva_cambiada.connect(hud.actualizar_pozo)
	add_child(pozo)
	hud.actualizar_pozo(0)
	celdas_ocupadas[celda_pozo] = true

func _recoger_gotas(cantidad: int):
	if not _puede_jugar() or cantidad <= 0:
		return
	gotas += cantidad
	hud.actualizar_gotas(gotas)

func _recoger_en_objetivo(pos: Vector2) -> bool:
	if not _puede_jugar() or not is_instance_valid(pozo):
		return false
	if usar_cursor_tablero:
		return cursor_tablero == celda_pozo and pozo.recoger()
	return pozo.contiene_punto(to_global(pos)) and pozo.recoger()

func _punto_objetivo() -> Vector2:
	if usar_cursor_tablero:
		return to_local(suelo.to_global(suelo.map_to_local(cursor_tablero)))
	return get_local_mouse_position()

func _actualizar_cursor(delta: float):
	var vector := Input.get_vector("Izquierda", "Derecha", "Arriba", "Abajo")
	var direccion := Vector2i.ZERO
	if not vector.is_zero_approx():
		direccion = Vector2i(signf(vector.x), 0) if absf(vector.x) >= absf(vector.y) else Vector2i(0, signf(vector.y))
	if direccion == Vector2i.ZERO:
		_direccion_cursor = direccion
		_espera_cursor = 0.0
		return
	usar_cursor_tablero = true
	_espera_cursor -= delta
	if direccion != _direccion_cursor or _espera_cursor <= 0.0:
		cursor_tablero.x = clampi(cursor_tablero.x + direccion.x, 0, ANCHO - 1)
		cursor_tablero.y = clampi(cursor_tablero.y + direccion.y, FILAS_BLOQUEADAS, ALTO - 1)
		_espera_cursor = 0.3 if direccion != _direccion_cursor else 0.12
		_direccion_cursor = direccion

func _generar_tablero():
	var fuente := suelo.tile_set.get_source(source_pasto) as TileSetAtlasSource
	var hay_variante := fuente.has_tile(Vector2i(1, 0))
	for x in ANCHO:
		for y in ALTO:
			var coords := Vector2i(0, 0)
			if hay_variante and (x + y) % 2 == 1:
				coords = Vector2i(1, 0)
			suelo.set_cell(Vector2i(x, y), source_pasto, coords)

func _generar_camino():
	for celda in _celdas_de(puntos_ruta):
		_pintar_camino(celda)
	if not _atajos.is_empty():
		var source := capa_atajo.tile_set.get_source_id(0)
		for datos in _atajos.values():
			for celda in datos.tramo:
				if not celdas_ocupadas.has(celda):
					capa_atajo.set_cell(celda, source, Vector2i.ZERO)
				celdas_ocupadas[celda] = true
		_marcar_atajos()
	for celda in celdas_bloqueadas:
		celdas_ocupadas[celda] = true

func _celdas_de(puntos: Array) -> Array[Vector2i]:
	var celdas: Array[Vector2i] = []
	for i in range(puntos.size() - 1):
		var desde: Vector2i = puntos[i]
		var hasta: Vector2i = puntos[i + 1]
		var paso := (hasta - desde).sign()
		var celda := desde
		while celda != hasta:
			celdas.append(celda)
			celda += paso
	celdas.append(puntos[-1])
	return celdas

func _pintar_camino(celda: Vector2i):
	camino.set_cell(celda, source_camino, Vector2i(0, 0))
	celdas_ocupadas[celda] = true

func _es_camino(celda: Vector2i) -> bool:
	return camino.get_cell_source_id(celda) != -1 or (capa_atajo != null and capa_atajo.get_cell_source_id(celda) != -1)

func _esta_inundada(celda: Vector2i) -> bool:
	return celdas_inundadas.has(celda) and (clima == "radiacion" or (clima in ["lluvia", "tormenta"] and _es_camino(celda)))

func _marcar_inundaciones():
	var agua := Node2D.new()
	agua.name = "Inundaciones"
	agua.draw.connect(func():
		for celda in celdas_inundadas:
			if _esta_inundada(celda):
				var centro := agua.to_local(suelo.to_global(suelo.map_to_local(celda)))
				agua.draw_rect(Rect2(centro - Vector2.ONE * 32, Vector2.ONE * 64), Color(0.1, 0.55, 0.95, 0.5))
	)
	add_child(agua)
	move_child(agua, arboles.get_index())

func _generar_curva():
	ruta.curve = _curva_de(puntos_ruta, ruta)
	_distancias_por_ruta[ruta] = _distancias_de(_celdas_de(puntos_ruta))
	for tipo in _atajos:
		var datos: Dictionary = _atajos[tipo]
		var adicional := Path2D.new()
		adicional.name = "Ruta_" + tipo
		add_child(adicional)
		adicional.curve = _curva_de(datos.puntos, adicional)
		rutas_enemigos[tipo] = adicional
		_distancias_por_ruta[adicional] = _distancias_de(datos.puntos)

func _distancias_de(celdas: Array) -> Dictionary:
	var distancias := {}
	for i in celdas.size():
		distancias[celdas[i]] = float(i * TAM_CELDA)
	return distancias

func _preparar_atajos() -> bool:
	var principal := _celdas_de(puntos_ruta)
	for datos in rutas_adicionales:
		var tramo := _celdas_de(datos.tramo)
		var entrada := principal.find(tramo[0])
		var salida := principal.find(tramo[-1])
		if not TIPOS_BESTIA.has(datos.tipo) or _atajos.has(datos.tipo) or entrada < 0 or salida <= entrada or tramo.size() - 1 >= salida - entrada:
			push_error("El atajo %s debe acortar el camino entre dos casillas en orden de marcha." % datos.tipo)
			return false
		var enlaces: Array[Vector2] = []
		var anterior := entrada
		for celda in datos.get("salidas", []):
			var en_tramo := tramo.find(celda)
			var en_principal := principal.find(celda)
			var desordenado := not enlaces.is_empty() and (entrada + en_tramo) * TAM_CELDA <= enlaces[-1].x
			if en_tramo <= 0 or en_tramo >= tramo.size() - 1 or en_principal <= anterior or en_principal >= salida or desordenado:
				push_error("Salida intermedia inválida en el atajo %s." % datos.tipo)
				return false
			enlaces.append(Vector2((entrada + en_tramo) * TAM_CELDA, en_principal * TAM_CELDA))
			anterior = en_principal
		var puntos := principal.slice(0, entrada)
		puntos.append_array(tramo)
		puntos.append_array(principal.slice(salida + 1))
		if _distancias_de(puntos).size() != puntos.size():
			push_error("El atajo %s repite una casilla de su recorrido." % datos.tipo)
			return false
		_atajos[datos.tipo] = {
			"puntos": puntos, "tramo": tramo, "color": datos.color, "enlaces": enlaces,
			"bifurcacion": float(entrada * TAM_CELDA),
			"union": Vector2((entrada + tramo.size() - 1) * TAM_CELDA, salida * TAM_CELDA),
		}
	return true

func _marcar_atajos():
	var marcas := Node2D.new()
	marcas.name = "MarcasAtajos"
	marcas.z_index = 2
	marcas.draw.connect(func():
		for tipo in _atajos:
			var datos: Dictionary = _atajos[tipo]
			var color: Color = datos.color
			for i in range(1, datos.tramo.size() - 1):
				var centro := marcas.to_local(suelo.to_global(suelo.map_to_local(datos.tramo[i])))
				var direccion := Vector2(datos.tramo[i + 1] - datos.tramo[i])
				var lado := direccion.orthogonal() * 8.0
				var flecha := PackedVector2Array([centro - lado - direccion * 6.0, centro + direccion * 6.0, centro + lado - direccion * 6.0])
				marcas.draw_polyline(flecha, Color(0.12, 0.10, 0.09), 7.0, true)
				marcas.draw_polyline(flecha, color, 3.0, true)
			var entrada := marcas.to_local(suelo.to_global(suelo.map_to_local(datos.tramo[0]))) + Vector2(-18, -9)
			marcas.draw_string_outline(ThemeDB.fallback_font, entrada, tipo.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color.BLACK)
			marcas.draw_string(ThemeDB.fallback_font, entrada, tipo.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
	)
	add_child(marcas)

func _curva_de(puntos: Array, destino: Path2D) -> Curve2D:
	var curva := Curve2D.new()
	for celda in puntos:
		curva.add_point(destino.to_local(suelo.to_global(suelo.map_to_local(celda))))
	return curva

func _ruta_para_tipo(tipo: String) -> Path2D:
	return rutas_enemigos.get(tipo, ruta)

func _escena_para_tipo(tipo: String) -> PackedScene:
	var indice := TIPOS_BESTIA.find(tipo)
	if indice >= 0 and indice < bestias_escenas.size() and bestias_escenas[indice] != null:
		return bestias_escenas[indice]
	if tipo == "natura":
		return espiritu_escena
	return null

func _bestias_en_camino() -> int:
	var total := ruta.get_child_count()
	for adicional in rutas_enemigos.values():
		total += adicional.get_child_count()
	return total

func _crear_arbol_madre():
	arbol_meta = arbol_madre_escena.instantiate()
	arbol_meta.position = suelo.map_to_local(celda_arbol_madre)
	add_child(arbol_meta)
	celdas_ocupadas[celda_arbol_madre] = true
	arbol_meta.vida_cambiada.connect(_on_vida_arbol_cambiada)
	arbol_meta.murio.connect(_perder_nivel)
	_on_vida_arbol_cambiada(arbol_meta.vida, arbol_meta.vida_maxima)

func _crear_espiritu(tipo: String = "natura", tamano: String = "pequeno", progreso: float = 0.0, recorrido: Path2D = null):
	if not _puede_jugar():
		return
	var escena := _escena_para_tipo(tipo)
	if escena == null:
		push_error("Falta la escena de la bestia '%s'." % tipo)
		return
	var seguidor := PathFollow2D.new()
	seguidor.loop = false
	seguidor.rotates = false
	seguidor.cubic_interp = false
	var destino := _ruta_para_tipo(tipo) if recorrido == null else recorrido
	destino.add_child(seguidor)
	seguidor.progress = progreso
	var espiritu = escena.instantiate()
	espiritu.tipo = tipo
	espiritu.tamano = tamano
	espiritu.resolver_avance = _resolver_avance_terra
	espiritu.puede_avanzar = _puede_jugar
	espiritu.cambiar_ruta = _ignorar_atajos
	espiritu.clima = clima
	espiritu.llego_a_meta.connect(_on_espiritu_llego)
	espiritu.invocar_copia.connect(func(tipo_copia: String, talla: String, avance: float):
		_crear_espiritu(tipo_copia, talla, avance, seguidor.get_parent() as Path2D)
	)
	seguidor.add_child(espiritu)
	_actualizar_combate_hud()

func _resumen_combate() -> Dictionary:
	var entrantes: Dictionary = {}
	if not terminado:
		if ronda_activa:
			for clave in cola_bestias:
				entrantes[clave] = entrantes.get(clave, 0) + 1
		else:
			entrantes = rondas[ronda - 1].duplicate()
	var pendientes := 0
	for cantidad in entrantes.values():
		pendientes += int(cantidad)
	var activos := 0
	for recorrido in [ruta] + rutas_enemigos.values():
		for seguidor in recorrido.get_children():
			if seguidor.is_queued_for_deletion():
				continue
			for bestia in seguidor.get_children():
				if bestia.is_in_group("bestias") and not bestia.muerto and not bestia.is_queued_for_deletion():
					activos += 1
	var estado := "Ronda %d en curso" % ronda if ronda_activa else "Próxima ronda %d" % ronda
	if terminado:
		estado = "Derrota" if arbol_meta.vida <= 0 else "Victoria"
	return {"estado": estado, "entrantes": entrantes, "por_aparecer": pendientes, "activos": activos, "restantes": pendientes + activos}

func _actualizar_combate_hud():
	if inicializado:
		hud.actualizar_combate(_resumen_combate())

func _on_espiritu_llego(dano: int):
	if not _puede_jugar():
		return
	if sonido_dano_arbol != null:
		sfx_arbol.play()
	arbol_meta.recibir_dano(dano)

func _on_vida_arbol_cambiada(actual: int, maxima: int):
	hud.actualizar_vida(actual, maxima)

# ---------------- Rondas ----------------
func _iniciar_ronda():
	if ronda_activa or not _puede_jugar():
		return
	ronda_activa = true
	if is_instance_valid(pozo):
		pozo.activar_generacion(true)
	cola_bestias.clear()
	var receta: Dictionary = rondas[ronda - 1]
	for tam in receta:
		for k in receta[tam]:
			cola_bestias.append(tam)
	cola_bestias.shuffle()
	_acum_spawn = intervalos_spawn[ronda - 1]
	hud.mostrar_boton_ronda("Ronda %d en curso" % ronda, false)
	_actualizar_combate_hud()

func _terminar_ronda():
	if not ronda_activa or not _puede_jugar():
		return
	ronda_activa = false
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	if ronda >= rondas.size():
		_ganar_nivel()
		return
	ronda += 1
	_actualizar_ronda_hud()
	hud.mostrar_boton_ronda("Iniciar ronda %d" % ronda, true)
	_actualizar_combate_hud()

func _actualizar_ronda_hud():
	hud.actualizar_ronda(ronda, rondas.size())
	if ronda <= consejos_ronda.size():
		hud.mostrar_consejo(consejos_ronda[ronda - 1])

func _physics_process(delta: float):
	_actualizar_auras_bestias(delta)
	if is_instance_valid(gestor_clima):
		gestor_clima.actualizar(delta)

func _actualizar_auras_bestias(delta: float):
	if not _puede_jugar():
		return
	var auras: Dictionary = {}
	for bestia in _bestias_vivas():
		if bestia.tipo not in ["electricitas", "glacies", "venenum"]:
			continue
		var celda := suelo.local_to_map(suelo.to_local(bestia.global_position))
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue
				var vecina := celda + Vector2i(x, y)
				if not auras.has(vecina):
					auras[vecina] = {"electricitas": 0, "glacies": 0, "venenum": 0}
				auras[vecina][bestia.tipo] += 1
	var llamas: Array = arboles_plantados.values().filter(func(arbol):
		return is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.vida > 0 and arbol.elemento == "flamma"
	)
	var acumulados: Dictionary = {}
	# La muerte por aura puede liberar una celda: se itera una copia de las claves.
	for celda in arboles_plantados.keys():
		var arbol = arboles_plantados[celda]
		if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.vida <= 0:
			continue
		var efectos: Dictionary = auras.get(celda, {})
		var protegido: bool = arbol.elemento == "glacies"
		for flamma in llamas:
			if not is_instance_valid(flamma) or flamma.is_queued_for_deletion() or flamma.vida <= 0:
				continue
			var radio: float = flamma.obtener_estadisticas().radio
			if flamma.forma.global_position.distance_squared_to(arbol.global_position) <= radio * radio:
				protegido = true
				break
		arbol.aplicar_auras(efectos.get("glacies", 0) > 0 and not protegido, efectos.get("venenum", 0) > 0)
		var id: int = arbol.get_instance_id()
		var dosis: float = _dano_aura_acumulado.get(id, 0.0) + efectos.get("electricitas", 0) * maxf(0.0, delta)
		var dano := floori(dosis + 0.000001)
		if dano > 0:
			arbol.recibir_dano(dano)
		if arbol.vida > 0:
			acumulados[id] = maxf(0.0, dosis - dano)
	_dano_aura_acumulado = acumulados

func _process(delta):
	if not _puede_jugar():
		return
	_actualizar_cursor(delta)
	_actualizar_recursos(delta)
	_actualizar_ventus(delta)
	_actualizar_contactos_aqua()

	_actualizar_recargas(delta)

	if ronda_activa:
		# Salida de bestias
		if cola_bestias.size() > 0:
			_acum_spawn += delta
			if _acum_spawn >= intervalos_spawn[ronda - 1]:
				_acum_spawn = 0.0
				var partes := String(cola_bestias.pop_front()).split(":")
				_crear_espiritu(partes[0], partes[1])
		elif _bestias_en_camino() == 0:
			_terminar_ronda()

	_actualizar_combate_hud()
	_actualizar_tooltip()
	if seleccion_tipo != "" or usar_cursor_tablero:
		vista.queue_redraw()

func obtener_produccion_agua() -> float:
	var produccion: float = {"lluvia": 0.3, "tormenta": 0.4, "volcan": 0.15}.get(clima, 0.2)
	for arbol in arboles_plantados.values():
		if is_instance_valid(arbol) and not arbol.is_queued_for_deletion() and arbol.vida > 0:
			produccion += arbol.obtener_produccion()
	return produccion

func _actualizar_recursos(delta: float):
	if _puede_jugar() and ronda_activa:
		pozo.acumular(delta, obtener_produccion_agua())

func _bestias_vivas() -> Array:
	var bestias: Array = []
	for recorrido in [ruta] + rutas_enemigos.values():
		for seguidor in recorrido.get_children():
			if seguidor.is_queued_for_deletion():
				continue
			for bestia in seguidor.get_children():
				if bestia.is_in_group("bestias") and not bestia.muerto and not bestia.is_queued_for_deletion():
					bestias.append(bestia)
	return bestias

func _actualizar_ventus(delta: float):
	_tiempo_ventus += delta
	while _tiempo_ventus >= 20.0:
		_tiempo_ventus -= 20.0
		var candidatas := _bestias_vivas()
		if not candidatas.is_empty():
			candidatas.pick_random().bendecir_ventus()

func _resolver_avance_terra(bestia, desde: float, hasta: float) -> float:
	if not _puede_jugar():
		return desde
	if bestia.efecto_elemental.elemento == "electricitas" and hasta <= desde:
		return hasta
	if hasta < desde:
		return hasta
	var seguidor := bestia.get_parent() as PathFollow2D
	if seguidor.get_parent() != ruta:
		var limite := minf(hasta, bestia.limite_confusion) if bestia.efecto_elemental.elemento == "aqua" else -INF
		var cambio := _resolver_atajo(bestia, desde, hasta, limite)
		desde = cambio.x
		hasta = cambio.y
	if bestia.tipo == "aqua":
		return hasta
	var recorrido := seguidor.get_parent() as Path2D
	var barrera := _primera_barrera(recorrido, desde, hasta)
	if barrera.is_empty():
		return hasta
	var entrada: float = barrera.entrada
	if bestia.recarga_contacto > 0.0:
		return entrada
	bestia.recarga_contacto = bestia.INTERVALO_CONTACTO
	var bloqueo: Arbol = barrera.arbol
	var empuje := bloqueo.obtener_empuje() * TAM_CELDA
	bloqueo.recibir_dano(bestia.DANO_CONTACTO.get(bestia.tipo, 0))
	return maxf(0.0, entrada - empuje)

func _primera_barrera(recorrido: Path2D, desde: float, hasta: float) -> Dictionary:
	var distancias: Dictionary = _distancias_por_ruta[recorrido]
	var primera_entrada := INF
	var bloqueo: Arbol = null
	for celda in arboles_plantados:
		var arbol = arboles_plantados[celda]
		if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.vida <= 0 or arbol.elemento != "terra":
			continue
		if not distancias.has(celda):
			continue
		var offset: float = distancias[celda]
		var entrada := maxf(0.0, offset - TAM_CELDA * 0.5)
		var salida := offset + TAM_CELDA * 0.5
		# Comprueba todo el tramo, para no atravesar Terra con un delta grande.
		if desde > salida or hasta < entrada:
			continue
		if entrada < primera_entrada:
			primera_entrada = entrada
			bloqueo = arbol
	return {} if bloqueo == null else {"entrada": primera_entrada, "arbol": bloqueo}

func _ignorar_atajos(bestia):
	var seguidor := bestia.get_parent() as PathFollow2D
	_resolver_atajo(bestia, seguidor.progress, seguidor.progress, seguidor.progress)

func _resolver_atajo(bestia, desde: float, hasta: float, limite_confusion: float) -> Vector2:
	var seguidor := bestia.get_parent() as PathFollow2D
	var actual := seguidor.get_parent() as Path2D
	if actual == ruta or not _atajos.has(bestia.tipo):
		return Vector2(desde, hasta)
	var datos: Dictionary = _atajos[bestia.tipo]
	var enlace: Vector2 = datos.union
	if desde >= enlace.x:
		enlace += Vector2.ONE * (desde - enlace.x)
	elif limite_confusion >= desde:
		if desde <= datos.bifurcacion:
			enlace = Vector2(desde, desde)
		else:
			for salida: Vector2 in datos.enlaces:
				if salida.x >= desde and salida.x <= limite_confusion:
					enlace = salida
					break
	if enlace.x > hasta:
		return Vector2(desde, hasta)
	# Antes de cambiar de ruta debe respetar los bloqueos del tramo antiguo.
	if enlace.x > desde and bestia.tipo != "aqua" and not _primera_barrera(actual, desde, enlace.x).is_empty():
		return Vector2(desde, hasta)
	seguidor.reparent(ruta, false)
	seguidor.progress = enlace.y
	# Se conserva el recorrido restante del fotograma sobre el camino normal.
	return Vector2(enlace.y, enlace.y + hasta - enlace.x)

func _actualizar_contactos_aqua():
	var actuales: Dictionary = {}
	for bestia in _bestias_vivas():
		var celda := suelo.local_to_map(suelo.to_local(bestia.global_position))
		var arbol = arboles_plantados.get(celda)
		if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.elemento != "aqua":
			continue
		var clave := "%s:%s" % [bestia.get_instance_id(), arbol.get_instance_id()]
		actuales[clave] = true
		if _contactos_aqua.has(clave) or bestia.tipo == "aqua":
			continue
		if bestia.tipo == "flamma":
			arbol.recibir_dano(25)
			bestia.recibir_dano(100)
		else:
			arbol.recibir_dano(arbol.vida)
	_contactos_aqua = actuales

func _perder_nivel():
	if terminado:
		return
	terminado = true
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	ronda_activa = false
	cola_bestias.clear()
	_deseleccionar()
	tooltip.hide()
	_limpiar_inspeccion()
	_actualizar_combate_hud()
	if derrota_escena == null:
		push_error("Falta asignar Derrota Escena en el Inspector del nivel")
		get_tree().paused = true
		return
	if has_node("MusicaNivel"):
		$MusicaNivel.stop()

	var d = derrota_escena.instantiate()
	add_child(d)
	get_tree().paused = true

func _ganar_nivel():
	if terminado:
		return
	terminado = true
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	ronda_activa = false
	cola_bestias.clear()
	_deseleccionar()
	tooltip.hide()
	_limpiar_inspeccion()
	_actualizar_combate_hud()

	if Guardado.slot_actual >= 0:
		Guardado.completar_nivel(numero_nivel)

	if victoria_escena == null:
		push_error("Falta asignar Victoria Escena en el Inspector del nivel")
		return

	var nombres: Array = []
	for i in desbloqueos:
		nombres.append(hud.SEMILLAS[i].nombre)

	var nombres_ataques: Array = []
	for i in desbloqueos_ataques:
		nombres_ataques.append(hud.ATAQUES[i].nombre)

	if has_node("MusicaNivel"):
		$MusicaNivel.stop()

	var v = victoria_escena.instantiate()
	v.numero_nivel = numero_nivel
	v.campana_finalizada = Guardado.es_ultimo_nivel(numero_nivel)
	v.desbloqueos = nombres
	v.desbloqueos_ataques = nombres_ataques
	add_child(v)
	get_tree().paused = true

# ---------------- Selección (arrastrar o clic + clic) ----------------
func _on_semilla_pulsada(i: int, arrastre: bool):
	if not _puede_jugar():
		return
	if not hud.SEMILLAS_ACTIVAS.has(i):
		return
	if i < 0 or i >= semillas_escenas.size() or semillas_escenas[i] == null:
		return
	var prototipo = semillas_escenas[i].instantiate()
	datos_rango_colocacion = prototipo.obtener_datos_colocacion()
	prototipo.free()
	seleccion_tipo = "semilla"
	seleccion_indice = i
	arrastrando = arrastre
	hud.resaltar("semilla", i)

func _on_ataque_pulsado(i: int, arrastre: bool):
	if not _puede_jugar():
		return
	if i < 0 or i >= cargas.size() or not hud.ATAQUES_ACTIVOS.has(i) or cargas[i] < 1.0:
		return
	seleccion_tipo = "ataque"
	seleccion_indice = i
	arrastrando = arrastre
	hud.resaltar("ataque", i)

func _deseleccionar():
	seleccion_tipo = ""
	seleccion_indice = -1
	arrastrando = false
	datos_rango_colocacion.clear()
	hud.resaltar("", -1)
	vista.queue_redraw()

func _input(event: InputEvent):
	if not _puede_jugar() or event.is_echo():
		return
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 0.0:
			usar_cursor_tablero = false
			vista.queue_redraw()
		return
	if event.is_action_pressed("Pausa", false, true):
		get_viewport().set_input_as_handled()
		_abrir_pausa()
		return
	if event.is_action_pressed("Atras", false, true) or event.is_action_pressed("Clic Derecho", false, true):
		get_viewport().set_input_as_handled()
		if seleccion_tipo != "":
			_deseleccionar()
		elif celda_torre_seleccionada != Vector2i(-1, -1):
			_limpiar_inspeccion()
		elif event.is_action_pressed("Atras", false, true):
			_abrir_pausa()
		return
	for accion in ["Izquierda", "Derecha", "Arriba", "Abajo"]:
		if event.is_action_pressed(accion, false, true):
			usar_cursor_tablero = true
			get_viewport().set_input_as_handled()
			return
	if hud.manejar_accion(event):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			usar_cursor_tablero = true
		get_viewport().set_input_as_handled()
		return
	var confirma := event.is_action_pressed("Clic Izquierdo", false, true) or event.is_action_pressed("Confirmar", false, true) or event.is_action_pressed("Usar Elemento", false, true)
	var suelta := event.is_action_released("Clic Izquierdo", true)
	if suelta and _clic_gota_consumido:
		_clic_gota_consumido = false
		get_viewport().set_input_as_handled()
		return
	if not confirma and not (suelta and arrastrando):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		usar_cursor_tablero = true
	var pos := _punto_objetivo()
	if event is InputEventMouseButton:
		usar_cursor_tablero = false
		pos = get_global_transform_with_canvas().affine_inverse() * event.position
	var pantalla := get_global_transform_with_canvas() * pos
	get_viewport().set_input_as_handled()
	if not usar_cursor_tablero and hud.punto_sobre_hud(pantalla):
		if confirma:
			hud.activar_en_punto(pantalla, event is InputEventMouseButton and event.is_action_pressed("Clic Izquierdo", false, true))
		else:
			arrastrando = false
		return
	if _recoger_en_objetivo(pos):
		_clic_gota_consumido = event.is_action_pressed("Clic Izquierdo", false, true)
		arrastrando = false
		return
	if confirma and arrastrando:
		return
	if event.is_action_pressed("Usar Elemento", false, true) and seleccion_tipo != "ataque":
		hud.seleccionar_grupo("ataque")
		if seleccion_tipo != "ataque":
			return
	if seleccion_tipo == "":
		var celda := suelo.local_to_map(suelo.to_local(to_global(pos)))
		celda_torre_seleccionada = celda if arboles_plantados.has(celda) else Vector2i(-1, -1)
		_mejorar_arbol(celda)
		_actualizar_tooltip()
	else:
		_confirmar(pos)
		if suelta:
			arrastrando = false



func _confirmar(pos: Vector2):
	if not _puede_jugar():
		return
	if seleccion_tipo == "semilla":
		var celda := suelo.local_to_map(pos)
		var costo: int = hud.SEMILLAS[seleccion_indice].costo
		if _se_puede_plantar(celda, seleccion_indice) and gotas >= costo and _plantar(celda, seleccion_indice):
			gotas -= costo
			hud.actualizar_gotas(gotas)
			_deseleccionar()
	elif seleccion_tipo == "ataque":
		_lanzar_ataque(pos, seleccion_indice)
		_deseleccionar()
	elif seleccion_tipo == "pala":
		_quitar_arbol(suelo.local_to_map(pos))
		_deseleccionar()

func _se_puede_plantar(celda: Vector2i, tipo: int = -1) -> bool:
	if celda.x < 0 or celda.x >= ANCHO or celda.y < FILAS_BLOQUEADAS or celda.y >= ALTO:
		return false
	if arboles_plantados.has(celda) or celda == celda_arbol_madre or celdas_bloqueadas.has(celda):
		return false
	if tipo == 2:
		return _esta_inundada(celda)
	if _esta_inundada(celda):
		return false
	if tipo == 3:
		return _es_camino(celda) or not celdas_ocupadas.has(celda)
	return not celdas_ocupadas.has(celda)

func _plantar(celda: Vector2i, tipo: int) -> bool:
	if not _puede_jugar() or not _se_puede_plantar(celda, tipo) or tipo < 0:
		return false
	if tipo >= semillas_escenas.size() or semillas_escenas[tipo] == null:
		push_warning("Falta la escena de la semilla %d en Semillas Escenas" % tipo)
		return false
	var arbol = semillas_escenas[tipo].instantiate()
	var modificadores: Dictionary = preload("res://scripts/nivel/clima.gd").modificadores_arbol(clima, arbol.elemento)
	arbol.modificador_cadencia = modificadores.cadencia
	arbol.modificador_dano = modificadores.dano
	arbol.position = suelo.map_to_local(celda)
	arboles.add_child(arbol)
	celdas_ocupadas[celda] = true
	arboles_plantados[celda] = arbol
	tipos_plantados[celda] = tipo
	tamanos_plantados[celda] = 0
	costos_plantados[celda] = hud.SEMILLAS[tipo].costos[0]
	arbol.murio.connect(liberar_celda.bind(celda))
	if is_instance_valid(gestor_clima):
		gestor_clima.actualizar_proteccion()
	hud.actualizar_produccion(obtener_produccion_agua(), clima)
	return true

func _actualizar_recargas(delta: float):
	for i in cargas.size():
		if recarga[i] <= 0.0:
			continue
		recarga[i] -= delta
		var maxima: float = hud.ATAQUES[i].capacidad
		while recarga[i] <= 0.000001:
			cargas[i] = minf(maxima, cargas[i] + 1.0)
			if cargas[i] >= maxima:
				recarga[i] = 0.0
				break
			recarga[i] += RECARGA_ATAQUE
		hud.actualizar_ataque(i, cargas[i], maxima, recarga[i])

func _lanzar_ataque(pos: Vector2, i: int) -> bool:
	if not _puede_jugar() or i < 0 or i >= cargas.size() or not hud.ATAQUES_ACTIVOS.has(i) or cargas[i] < 1.0:
		return false
	var datos: Dictionary = hud.ATAQUES[i]
	cargas[i] -= 1.0
	if recarga[i] == 0.0:
		recarga[i] = RECARGA_ATAQUE
	hud.actualizar_ataque(i, cargas[i], datos.capacidad, recarga[i])
	if i < sonidos_ataque.size() and sonidos_ataque[i] != null:
		sfx_ataque.stream = sonidos_ataque[i]
		sfx_ataque.play()
	var centro := to_global(pos)
	var radio: float = datos.radio * TAM_CELDA
	var victimas: Array = _bestias_vivas().filter(func(bestia): return bestia.global_position.distance_squared_to(centro) <= radio * radio)
	var lentas: Array = []
	if datos.nombre == "Venenum":
		lentas = victimas.filter(func(bestia): return bestia.tipo != "venenum" and not (bestia.tipo == "natura" and bestia.tamano == "pequeno"))
		lentas.shuffle()
		lentas.resize(mini(3, lentas.size()))
	for bestia in victimas:
		bestia.aplicar_ataque_elemental(datos.nombre, datos.dano, lentas.has(bestia))
	var visual = preload("res://scripts/nivel/efecto_ataque.gd").new()
	visual.radio = radio
	visual.color = preload("res://scripts/entidades/bestias/efecto_elemental.gd").COLORES[datos.nombre.to_lower()]
	visual.position = pos
	add_child(visual)
	return true

# ---------------- Vista previa ----------------
func _crear_vista():
	vista = Node2D.new()
	vista.z_index = 10
	vista.draw.connect(_dibujar_vista)
	add_child(vista)

func _dibujar_vista():
	if usar_cursor_tablero:
		var punto := _punto_objetivo() - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		vista.draw_rect(Rect2(punto, Vector2(TAM_CELDA, TAM_CELDA)), Color.WHITE, false, 2.0)
	if seleccion_tipo == "":
		return
	if not usar_cursor_tablero and hud.punto_sobre_hud(get_viewport().get_mouse_position()):
		return
	var pos := _punto_objetivo()
	if seleccion_tipo == "semilla":
		var celda := suelo.local_to_map(pos)
		var costo: int = hud.SEMILLAS[seleccion_indice].costo
		var ok := _se_puede_plantar(celda, seleccion_indice) and gotas >= costo
		var color := Color(0, 1, 0, 0.4) if ok else Color(1, 0, 0, 0.4)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		if not datos_rango_colocacion.is_empty():
			var centro: Vector2 = suelo.map_to_local(celda) + datos_rango_colocacion.centro
			var radio: float = datos_rango_colocacion.radio
			vista.draw_circle(centro, radio, Color(color.r, color.g, color.b, 0.12))
			vista.draw_arc(centro, radio, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.65), 2.0, true)
		vista.draw_rect(Rect2(origen, Vector2(TAM_CELDA, TAM_CELDA)), color)
	elif seleccion_tipo == "pala":
		var celda := suelo.local_to_map(pos)
		var color := Color(1, 0.6, 0, 0.5) if arboles_plantados.has(celda) else Color(1, 0, 0, 0.25)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		vista.draw_rect(Rect2(origen, Vector2(TAM_CELDA, TAM_CELDA)), color)
	elif seleccion_tipo == "ataque":
		var radio: float = hud.ATAQUES[seleccion_indice].radio * TAM_CELDA
		vista.draw_circle(pos, radio, Color(1, 1, 1, 0.25))

func _on_pala_pulsada(arrastre: bool):
	if not _puede_jugar():
		return
	seleccion_tipo = "pala"
	seleccion_indice = 0
	arrastrando = arrastre
	hud.resaltar("pala", 0)

func _quitar_arbol(celda: Vector2i):
	if not _puede_jugar():
		return
	if not arboles_plantados.has(celda):
		return
	var arbol = arboles_plantados[celda]
	if is_instance_valid(arbol):
		arbol.queue_free()

	liberar_celda(celda)

func liberar_celda(celda: Vector2i):
	if arboles_plantados.get(celda) == torre_informada or celda == celda_torre_seleccionada:
		_limpiar_inspeccion()
	arboles_plantados.erase(celda)
	costos_plantados.erase(celda)
	tipos_plantados.erase(celda)
	tamanos_plantados.erase(celda)
	if not _es_camino(celda):
		celdas_ocupadas.erase(celda)
	hud.actualizar_produccion(obtener_produccion_agua(), clima)

func _costo_mejora(celda: Vector2i) -> int:
	var tipo: int = tipos_plantados[celda]
	var t: int = tamanos_plantados[celda]
	return hud.SEMILLAS[tipo].costos[t + 1]

func _mejorar_arbol(celda: Vector2i):
	if not _puede_jugar():
		return
	if not arboles_plantados.has(celda):
		return
	var t: int = tamanos_plantados[celda]
	if t >= TAMANOS.size() - 1:
		return
	var costo := _costo_mejora(celda)
	if gotas < costo:
		print("No te alcanzan las gotas para mejorar (%d)" % costo)
		return

	var arbol = arboles_plantados[celda]
	if not arbol.mejorar():       # solo cobra si el árbol sí subió de tamaño
		return

	gotas -= costo
	costos_plantados[celda] += costo
	tamanos_plantados[celda] = t + 1
	hud.actualizar_gotas(gotas)
	hud.actualizar_produccion(obtener_produccion_agua(), clima)

func _crear_tooltip():
	panel_torre = PanelContainer.new()
	panel_torre.name = "InfoTorre"
	hud.detalles.add_child(panel_torre)
	tooltip = Label.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip.add_theme_font_size_override("font_size", 17)
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.max_lines_visible = 4
	tooltip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel_torre.add_child(tooltip)
	panel_torre.hide()

func _ocultar_info_torre():
	if is_instance_valid(torre_informada):
		torre_informada.mostrar_rango(false)
	torre_informada = null
	panel_torre.hide()
	hud.mostrar_inspeccion(false)

func _limpiar_inspeccion():
	celda_torre_seleccionada = Vector2i(-1, -1)
	_ocultar_info_torre()

func _mostrar_info_torre(celda: Vector2i):
	var arbol = arboles_plantados.get(celda)
	if not is_instance_valid(arbol) or arbol.is_queued_for_deletion():
		_ocultar_info_torre()
		return
	if torre_informada != arbol:
		_ocultar_info_torre()
		torre_informada = arbol
	arbol.mostrar_rango(true)
	var tipo: int = tipos_plantados[celda]
	var t: int = tamanos_plantados[celda]
	var datos: Dictionary = arbol.obtener_estadisticas()
	var texto := "%s | Nivel %d/%d (%s)" % [hud.SEMILLAS[tipo].nombre, t + 1, TAMANOS.size(), NOMBRES_TAMANO[t]]
	texto += " · Vida: %d" % arbol.vida
	if t >= TAMANOS.size() - 1:
		texto += " · Tamaño máximo"
	else:
		var costo := _costo_mejora(celda)
		texto += " · Mejorar: %d gotas" % costo
		texto += " [%s]" % ControlesManager.etiqueta_accion("Confirmar") if gotas >= costo else " (sin agua)"
	texto += "\n"
	if datos.produccion > 0.0:
		texto += "Pozo: +%.1f gotas/s" % datos.produccion
	elif datos.empuje > 0.0:
		texto += "Bloqueo | Empuje: %.1f celdas · Aqua lo atraviesa." % datos.empuje
	else:
		texto += "Daño: %d | Disparos/s: %.2f | Alcance: %.1f celdas" % [datos.dano, datos.disparos_segundo, datos.radio / TAM_CELDA]
	if datos.nivel_congelacion > 0 or clima == "ventisca":
		texto += "\nCongelación climática: %d/3%s" % [datos.nivel_congelacion, " | Protegido por Flamma" if datos.protegido_ventisca else ""]
	if clima == "derrumbe" and arbol.elemento == "terra":
		texto += "\nRocas absorbidas: %d/3" % datos.golpes_derrumbe
	if datos.bono_geiser > 0.0:
		texto += "\nGéiser: cadencia +25%% por %.1f s" % datos.bono_geiser
	if datos.congelado_por_aura:
		texto += "\nCongelado por aura gélida: no dispara"
	if datos.intoxicado_por_aura:
		texto += "\nAura tóxica: cadencia -30% | Fallo 30%"
	if datos.radio_explosion > 0.0:
		texto += "\nExplosión: %.1f celdas" % (datos.radio_explosion / TAM_CELDA)
	if datos.congelacion > 0.0:
		texto += "\nPenetra hasta %d bestias | Congela %.1f s" % [datos.objetivos, datos.congelacion]
	elif arbol.elemento == "electricitas":
		texto += "\nEncadena hasta %d bestias | Salto máximo: 2 casillas" % datos.objetivos
	if datos.veneno_segundo > 0.0:
		texto += "\nVeneno: %.0f HP/s durante %.1f s" % [datos.veneno_segundo, datos.duracion_veneno]
		texto += "\nLentitud: %d%% mientras dure el veneno" % roundi((1.0 - datos.factor_lentitud) * 100)
	if datos.duracion_lentitud > 0.0:
		texto += "\nLentitud: %d%% durante %.1f s" % [roundi((1.0 - datos.factor_lentitud) * 100), datos.duracion_lentitud]
	tooltip.text = texto.replace("\n", " · ")
	tooltip.tooltip_text = texto
	hud.mostrar_inspeccion(true)
	panel_torre.show()

func _actualizar_tooltip():
	var pos_pantalla := get_viewport().get_mouse_position()
	var celda := cursor_tablero if usar_cursor_tablero else suelo.local_to_map(suelo.get_local_mouse_position())
	if not _puede_jugar() or seleccion_tipo != "":
		_ocultar_info_torre()
		return
	if (usar_cursor_tablero or not hud.punto_sobre_hud(pos_pantalla)) and arboles_plantados.has(celda):
		_mostrar_info_torre(celda)
	elif arboles_plantados.has(celda_torre_seleccionada):
		_mostrar_info_torre(celda_torre_seleccionada)
	else:
		_ocultar_info_torre()

func _abrir_pausa():
	if pausa != null or not _puede_jugar():
		return
	_ocultar_info_torre()
	pausa = pausa_escena.instantiate()
	pausa.numero_nivel = numero_nivel
	add_child(pausa)
	pausa.tree_exited.connect(func(): pausa = null)
	get_tree().paused = true
