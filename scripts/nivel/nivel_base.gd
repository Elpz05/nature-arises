class_name NivelBase
extends Node2D

@export var espiritu_escena: PackedScene
@export var bestias_escenas: Array[PackedScene]
@export var musica_nivel: AudioStream
@export var celdas_bloqueadas: Array[Vector2i] = []
@export var limitar_plantado := false
@export var parcelas_secano: Array[Vector2i] = []
@export var puestos_terra: Array[Vector2i] = []
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
var numeros_dano: Node2D

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var capa_atajo := get_node_or_null("Atajo") as TileMapLayer
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles

const ANCHO := 30
const ALTO := 17
const TAM_CELDA := 64
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const RETRATOS = preload("res://scripts/HUD/retratos_unidad.gd")

const TAMANOS := ["pequeno", "mediano", "grande"]
const GOTAS_INICIALES := 3
@export var gotas_iniciales := GOTAS_INICIALES
@export var titulo_nivel := ""
@export_multiline var consejo_nivel := ""
var consejos_ronda: Array[String] = []
const RECOMPENSA_RONDA := 2
const RECOMPENSA_DESAFIO := 3
const AMENAZAS := {
	"aqua": "atraviesa Terra e ignora el fuego",
	"glacies": "congela árboles cercanos",
	"flamma": "renace una vez",
	"electricitas": "daña árboles cercanos",
	"venenum": "debilita los disparos cercanos",
	"terra": "puede bloquear impactos",
	"natura": "avanza por el camino principal",
}
const FILAS_BLOQUEADAS := 3
const VECINOS_ORTOGONALES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIRECCIONES_CURSOR := {"Izquierda": Vector2i.LEFT, "Derecha": Vector2i.RIGHT, "Arriba": Vector2i.UP, "Abajo": Vector2i.DOWN}
const AGUA_BASE := 0.085
const AGUA_POR_CLIMA := {"lluvia": 0.11, "tormenta": 0.14, "volcan": 0.07}
const TIPOS_BESTIA := ["natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum"]
const CONTENIDO_GUIA = preload("res://scripts/guia/contenido_guia.gd")
const ESCENA_GUIA = preload("res://escenas/escenas_menu/guia_juego.tscn")
static var _informes_vistos := {}

# Los hijos rellenan estos datos en _configurar_nivel(), antes de generar el mapa.
var puntos_ruta: Array = []
var rondas: Array = []
var desafios_ronda: Dictionary = {}
var desafio_elegido := false
var celda_arbol_madre := Vector2i.ZERO
var rutas_adicionales: Array = []
var rutas_enemigos: Dictionary = {}
var inicializado := false

var hud
var source_pasto: int
var source_camino: int
var celdas_camino := {}
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
var _cursor_visual := Vector2.INF
var terminado := false

var ronda := 1
var ronda_activa := false
const VELOCIDADES := [1.0, 2.0, 4.0, 8.0]
const PASOS_VELOCIDAD := [8, 8, 16, 32]
const REFUERZOS_FINALES := ["electricitas", "terra", "venenum", "aqua", "electricitas"]
var velocidad_partida := 1.0
var ajustes_campana_activos := true
var _reloj_ui := -1.0
var _bumper_pendiente: InputEventJoypadButton
var _plazo_bumper := 0
var _bumpers := {}
var _acorde_consumido := false
var _reproduciendo_bumper := false
var cola_bestias: Array = []
var tipos_plantados := {}        # celda -> índice de semilla
var tamanos_plantados := {}      # celda -> 0 pequeño, 1 mediano, 2 grande
var celda_torre_seleccionada := Vector2i(-1, -1)
var torre_informada: Arbol
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
var guia: CanvasLayer

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
		if not _validar_receta(receta):
			return false
	for numero in desafios_ronda:
		if not numero is int or numero < 1 or numero >= rondas.size() or not _validar_receta(desafios_ronda[numero]):
			push_error("Los desafíos deben tener refuerzos válidos y preceder a la última ronda.")
			return false
	var recorridos: Array = [puntos_ruta]
	celdas_camino.clear()
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
		for celda in celdas:
			celdas_camino[celda] = true
	if not _preparar_atajos():
		return false
	if pozo_escena == null or not _celda_valida_terreno(celda_pozo) or _es_camino(celda_pozo) or _esta_inundada(celda_pozo):
		push_error("El pozo necesita una escena y una casilla seca fuera del camino.")
		return false
	if clima == "volcan":
		for celda in celdas_geiser:
			if not _celda_valida_terreno(celda) or celda == celda_pozo or _es_camino(celda):
				push_error("Los géiseres necesitan casillas libres dentro del tablero.")
				return false
	if limitar_plantado:
		for celda in parcelas_secano + puestos_terra + celdas_inundadas:
			if not _celda_valida_terreno(celda) or _reserva_terreno(celda):
				push_error("La parcela %s coincide con terreno reservado." % str(celda))
				return false
		for celda in parcelas_secano:
			if _es_camino(celda) or _esta_inundada(celda):
				push_error("La parcela seca %s debe estar fuera del camino y del agua." % str(celda))
				return false
		for celda in puestos_terra:
			if not _es_camino(celda) or _esta_inundada(celda):
				push_error("El puesto Terra %s debe estar en un camino seco." % str(celda))
				return false
		for celda in celdas_inundadas:
			if not _esta_inundada(celda):
				push_error("Las pozas requieren lluvia, tormenta o radiación.")
				return false
	return true

func _validar_receta(receta: Variant) -> bool:
	var grupos: Array = receta if receta is Array else [receta]
	if grupos.is_empty():
		push_error("La ronda necesita al menos un grupo de bestias.")
		return false
	for grupo in grupos:
		if not grupo is Dictionary or grupo.is_empty():
			push_error("Cada grupo debe declarar sus bestias y cantidades.")
			return false
		for clave in grupo:
			var partes := String(clave).split(":")
			var divisor_valido := partes.size() == 3 and partes[0] == "natura" and partes[2] == "divisor"
			if (partes.size() != 2 and not divisor_valido) or not TIPOS_BESTIA.has(partes[0]) or not TAMANOS.has(partes[1]) \
					or not grupo[clave] is int or grupo[clave] <= 0 or _escena_para_tipo(partes[0]) == null:
				push_error("Receta de bestias inválida: %s" % clave)
				return false
	return true

func _puede_jugar() -> bool:
	return inicializado and not terminado and not get_tree().paused

func _ready():
	$CamaraTablero.force_update_scroll()
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
	_marcar_terreno()
	_generar_curva()
	_crear_numeros_dano()
	_crear_arbol_madre()
	_crear_pozo()
	_crear_vista()
	hud.mostrar_hud_debug(Ajustes.hud_debug_activo())
	Ajustes.hud_debug_cambiado.connect(_on_hud_debug_cambiado)
	if musica_nivel != null:
		MusicaManager.reproducir(musica_nivel)

	for i in hud.ATAQUES.size():
		cargas.append(hud.ATAQUES[i].capacidad)
		recarga.append(0.0)
		hud.actualizar_ataque(i, cargas[i], hud.ATAQUES[i].capacidad)

	_actualizar_gotas_hud()
	_actualizar_ronda_hud()
	hud.mostrar_boton_ronda("Iniciar ronda", true)

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
	_mostrar_informe_inicial.call_deferred()

func _exit_tree():
	_aplicar_tiempo(1.0)

func _aplicar_tiempo(velocidad: float):
	Engine.time_scale = velocidad
	Engine.physics_ticks_per_second = int(60 * velocidad)
	Engine.max_physics_steps_per_frame = PASOS_VELOCIDAD[VELOCIDADES.find(velocidad)]
	_reloj_ui = -1.0

func _alternar_velocidad():
	if _puede_jugar():
		velocidad_partida = VELOCIDADES[(VELOCIDADES.find(velocidad_partida) + 1) % VELOCIDADES.size()]
		_aplicar_tiempo(velocidad_partida)
		hud.mostrar_velocidad(int(velocidad_partida))

func _procesar_bumper(evento: InputEventJoypadButton) -> bool:
	if _reproduciendo_bumper or evento.button_index not in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		return false
	var ahora := Time.get_ticks_msec()
	if _bumper_pendiente != null and ahora > _plazo_bumper:
		_emitir_bumper()
	var clave := Vector2i(evento.device, evento.button_index)
	if evento.pressed:
		if _bumpers.has(clave):
			return true
		_bumpers[clave] = true
		if _acorde_consumido:
			return true
		if _bumper_pendiente != null:
			if _bumper_pendiente.device == evento.device and _bumper_pendiente.button_index != evento.button_index:
				_bumper_pendiente = null
				_acorde_consumido = true
				_alternar_velocidad()
				return true
			_emitir_bumper()
		_bumper_pendiente = evento.duplicate()
		_plazo_bumper = ahora + 100
	else:
		_bumpers.erase(clave)
		if _bumper_pendiente != null and _bumper_pendiente.device == evento.device and _bumper_pendiente.button_index == evento.button_index:
			_emitir_bumper()
		if _bumpers.is_empty():
			_acorde_consumido = false
	return true

func _emitir_bumper():
	var evento := _bumper_pendiente
	_bumper_pendiente = null
	_reproduciendo_bumper = true
	_input(evento)
	_reproduciendo_bumper = false

func _suspender_tiempo():
	_aplicar_tiempo(1.0)
	_bumper_pendiente = null
	_bumpers.clear()
	_acorde_consumido = false
	if is_instance_valid(gestor_clima):
		gestor_clima.ocultar_avisos(false)
# ---------------- HUD ----------------
func _crear_hud():
	hud = hud_escena.instantiate()
	add_child(hud)
	hud.barra.resized.connect(_solicitar_ajuste_camara)
	hud.panel_ronda.resized.connect(_solicitar_ajuste_camara)
	hud.panel_estado.resized.connect(_solicitar_ajuste_camara)
	get_viewport().size_changed.connect(_solicitar_ajuste_camara)
	_solicitar_ajuste_camara()
	hud.configurar_retratos_semillas(semillas_escenas)
	if limitar_plantado:
		var leyenda := "Cuadros: árboles"
		if not puestos_terra.is_empty():
			leyenda += " · Barras: Terra"
		if not celdas_inundadas.is_empty():
			leyenda += " · Gotas: Aqua"
		hud.leyenda_terreno = leyenda
	if not titulo_nivel.is_empty():
		hud.mostrar_mision("%d/%d · %s" % [numero_nivel + 1, Guardado.NIVELES.size(), titulo_nivel], consejo_nivel)
	if Guardado.todo_desbloqueado():
		hud.SEMILLAS_ACTIVAS = Guardado.plantas_activas()
		hud.ATAQUES_ACTIVOS = Guardado.ataques_activos()
	elif Guardado.slot_actual < 0:
		var disponibles: Dictionary = preload("res://scripts/nivel/campana.gd").disponibles_para_nivel(numero_nivel)
		hud.SEMILLAS_ACTIVAS = disponibles.plantas
		hud.ATAQUES_ACTIVOS = disponibles.ataques
	hud.semilla_pulsada.connect(_on_semilla_pulsada)
	hud.ataque_pulsado.connect(_on_ataque_pulsado)
	hud.ronda_solicitada.connect(_iniciar_ronda)
	hud.desafio_solicitado.connect(_alternar_desafio)
	hud.prioridad_solicitada.connect(_cambiar_prioridad_seleccion)
	hud.mejora_solicitada.connect(_mejorar_seleccion)
	hud.pala_pulsada.connect(_on_pala_pulsada)
	hud.guia_solicitada.connect(_abrir_guia)
	hud.velocidad_solicitada.connect(_alternar_velocidad)
	hud.cerrar_seleccion_solicitada.connect(_deseleccionar)
	hud.cerrar_ficha_solicitada.connect(_limpiar_inspeccion)
	for i in semillas_escenas.size():
		if semillas_escenas[i] != null:
			hud.plantas_disponibles.append(i)

func _solicitar_ajuste_camara():
	_ajustar_camara.call_deferred()

func _ajustar_camara():
	if not is_inside_tree() or not inicializado:
		return
	var area: Rect2 = hud.espacio_camara()
	if not area.has_area():
		return
	var tamano := Vector2(ANCHO, ALTO - FILAS_BLOQUEADAS) * TAM_CELDA
	var centro := suelo.to_global(Vector2(0, FILAS_BLOQUEADAS * TAM_CELDA) + tamano / 2.0)
	var zoom := minf(0.9, minf(area.size.x / tamano.x, area.size.y / tamano.y))
	var camara: Camera2D = $CamaraTablero
	camara.zoom = Vector2.ONE * zoom
	camara.global_position = centro + (get_viewport_rect().get_center() - area.get_center()) / zoom
	camara.force_update_scroll()
	hud.posicionar_previa(suelo.get_global_transform_with_canvas() * suelo.map_to_local(puntos_ruta[0]))

func _crear_pozo():
	pozo = pozo_escena.instantiate()
	pozo.position = suelo.map_to_local(celda_pozo)
	pozo.agua_recogida.connect(_recoger_gotas)
	pozo.reserva_cambiada.connect(hud.actualizar_pozo)
	add_child(pozo)
	hud.actualizar_pozo(0)

func _recoger_gotas(cantidad: int):
	if not _puede_jugar() or cantidad <= 0:
		return
	gotas += cantidad
	_actualizar_gotas_hud()

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
	if vector.is_zero_approx():
		_direccion_cursor = Vector2i.ZERO
		return
	usar_cursor_tablero = true
	var direccion := _direccion_cursor
	if vector.dot(Vector2(direccion)) <= 0.0:
		direccion = Vector2i(signf(vector.x), 0) if absf(vector.x) >= absf(vector.y) else Vector2i(0, signf(vector.y))
	_espera_cursor -= delta
	if direccion != _direccion_cursor or _espera_cursor <= 0.0:
		_mover_cursor(direccion)
		_espera_cursor = 0.28 if direccion != _direccion_cursor else 0.11
		_direccion_cursor = direccion

func _celda_navegable(celda: Vector2i) -> bool:
	if celda == celda_pozo and pozo.reserva > 0:
		return true
	match seleccion_tipo:
		"semilla":
			return _se_puede_plantar(celda, seleccion_indice)
		"ataque":
			return _es_camino(celda)
		"pala":
			return arboles_plantados.has(celda)
	if celda == celda_pozo or arboles_plantados.has(celda):
		return true
	for tipo: int in hud.SEMILLAS_ACTIVAS:
		if hud.plantas_disponibles.has(tipo) and _se_puede_plantar(celda, tipo):
			return true
	return false

func _mover_cursor(direccion := Vector2i.ZERO):
	var destino := cursor_tablero
	var mejor := INF
	var mejor_desvio := INF
	for y in range(FILAS_BLOQUEADAS, ALTO):
		for x in ANCHO:
			var celda := Vector2i(x, y)
			var diferencia := celda - cursor_tablero
			if direccion != Vector2i.ZERO and diferencia.x * direccion.x + diferencia.y * direccion.y <= 0:
				continue
			var desvio := absi(diferencia.x * direccion.y - diferencia.y * direccion.x)
			var distancia := diferencia.length_squared()
			if (desvio < mejor_desvio or (desvio == mejor_desvio and distancia < mejor)) and _celda_navegable(celda):
				mejor = distancia
				mejor_desvio = desvio
				destino = celda
	cursor_tablero = destino

func _ajustar_cursor():
	if usar_cursor_tablero and not _celda_navegable(cursor_tablero):
		_mover_cursor()

func _generar_tablero():
	var fuente := suelo.tile_set.get_source(source_pasto) as TileSetAtlasSource
	var hay_variante := fuente.has_tile(Vector2i(1, 0))
	for x in ANCHO:
		for y in ALTO:
			var coords := Vector2i(0, 0)
			if hay_variante and (x + y) % 2 == 1:
				coords = Vector2i(1, 0)
			suelo.set_cell(Vector2i(x, y), source_pasto, coords)
	if clima == "ventisca":
		var velo := Node2D.new()
		velo.name = "Nieve"
		var origen := suelo.map_to_local(Vector2i(0, FILAS_BLOQUEADAS)) - Vector2.ONE * TAM_CELDA / 2.0
		var terreno := Rect2(origen, Vector2(ANCHO, ALTO - FILAS_BLOQUEADAS) * TAM_CELDA)
		velo.draw.connect(func(): velo.draw_rect(terreno, Color(Color("#c6d8e2"), 0.58)))
		suelo.add_child(velo)

func _generar_camino():
	for celda in _celdas_de(puntos_ruta):
		camino.set_cell(celda, source_camino, Vector2i.ZERO)
	if not _atajos.is_empty():
		if capa_atajo.get_index() > arboles.get_index():
			move_child(capa_atajo, arboles.get_index())
		var source := capa_atajo.tile_set.get_source_id(0)
		for datos in _atajos.values():
			for celda in datos.tramo:
				if camino.get_cell_source_id(celda) == -1:
					capa_atajo.set_cell(celda, source, Vector2i.ZERO)
		_marcar_atajos()

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

func _es_camino(celda: Vector2i) -> bool:
	return celdas_camino.has(celda)

func _esta_inundada(celda: Vector2i) -> bool:
	return clima in ["lluvia", "tormenta", "radiacion"] and celdas_inundadas.has(celda)

func _marcar_terreno():
	var marcas := Node2D.new()
	marcas.name = "Parcelas"
	marcas.draw.connect(func():
		_dibujar_ruta_principal(marcas)
		for celda in celdas_inundadas:
			if _esta_inundada(celda):
				_dibujar_parcela(marcas, celda, "gota")
		if limitar_plantado:
			for celda in parcelas_secano:
				_dibujar_parcela(marcas, celda, "parcela")
			for celda in puestos_terra:
				_dibujar_parcela(marcas, celda, "puesto_terra")
	)
	add_child(marcas)
	move_child(marcas, arboles.get_index())

func _dibujar_parcela(lienzo: Node2D, celda: Vector2i, id: String, destacada := false):
	var centro := lienzo.to_local(suelo.to_global(suelo.map_to_local(celda)))
	var parcela := Rect2(centro - Vector2.ONE * 24, Vector2.ONE * 48)
	var fondo := Color(0.10, 0.18, 0.18, 0.68) if id == "gota" else Color(0.12, 0.14, 0.13, 0.62)
	if destacada:
		fondo = Color(0.16, 0.46, 0.35, 0.85)
	lienzo.draw_rect(parcela, fondo)
	ICONOS.dibujar(lienzo, id, centro, 3.1, false, destacada)

func _dibujar_ruta_principal(lienzo: Node2D):
	var celdas := _celdas_de(puntos_ruta)
	for i in range(3, celdas.size() - 1, 6):
		var celda := celdas[i]
		if puestos_terra.has(celda) or _esta_inundada(celda):
			continue
		var centro := lienzo.to_local(suelo.to_global(suelo.map_to_local(celda)))
		var direccion := Vector2(celdas[i + 1] - celda)
		var lado := direccion.orthogonal() * 9.0
		var punta := centro + direccion * 6.0
		var cola := centro - direccion * 5.0
		lienzo.draw_polyline(PackedVector2Array([cola + lado, punta, cola - lado]), Color(0.07, 0.14, 0.17, 0.52), 4.0, true)
	var entrada := lienzo.to_local(suelo.to_global(suelo.map_to_local(celdas[0])))
	ICONOS.dibujar(lienzo, "entrada", entrada, 2.9)

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

func _crear_numeros_dano():
	numeros_dano = preload("res://scripts/HUD/numeros_dano.gd").new()
	var esquina := suelo.map_to_local(Vector2i(0, FILAS_BLOQUEADAS)) - Vector2.ONE * TAM_CELDA / 2.0
	numeros_dano.tablero = Rect2(esquina, Vector2(ANCHO, ALTO - FILAS_BLOQUEADAS) * TAM_CELDA)
	add_child(numeros_dano)
	numeros_dano.establecer_activo(Ajustes.numeros_dano_activos())
	Ajustes.numeros_dano_cambiado.connect(numeros_dano.establecer_activo)

func _crear_arbol_madre():
	arbol_meta = arbol_madre_escena.instantiate()
	arbol_meta.position = suelo.map_to_local(celda_arbol_madre)
	add_child(arbol_meta)
	arbol_meta.vida_cambiada.connect(_on_vida_arbol_cambiada)
	arbol_meta.murio.connect(_perder_nivel)
	arbol_meta.dano_recibido.connect(numeros_dano.registrar.bind(arbol_meta, true))
	_on_vida_arbol_cambiada(arbol_meta.vida, arbol_meta.vida_maxima)

func _crear_espiritu(tipo: String = "natura", tamano: String = "pequeno", progreso: float = 0.0, recorrido: Path2D = null, divisor: bool = false):
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
	espiritu.es_divisor = divisor
	espiritu.resolver_avance = _resolver_avance_terra
	espiritu.puede_avanzar = _puede_jugar
	espiritu.cambiar_ruta = _ignorar_atajos
	espiritu.clima = clima
	var ajuste := _ajuste_ronda(ronda)
	espiritu.factor_vida_ronda = ajuste.x
	espiritu.factor_velocidad_ronda = ajuste.y
	espiritu.llego_a_meta.connect(_on_espiritu_llego)
	espiritu.dano_recibido.connect(numeros_dano.registrar.bind(espiritu, false))
	espiritu.invocar_copia.connect(func(tipo_copia: String, talla: String, avance: float):
		_crear_espiritu(tipo_copia, talla, avance, seguidor.get_parent() as Path2D)
	)
	seguidor.add_child(espiritu)
	if _es_escena_campana():
		Guardado.descubrir_bestia(tipo)
	_actualizar_combate_hud()

func _resumen_combate() -> Dictionary:
	var entrantes: Dictionary = {}
	if not terminado:
		entrantes = _contar_bestias(cola_bestias if ronda_activa else _plan_de_ronda(ronda, desafio_elegido))
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
	if inicializado and ronda_activa and hud.panel_ola.visible:
		hud.actualizar_combate(_resumen_combate())

func _on_hud_debug_cambiado(activo: bool):
	hud.mostrar_hud_debug(activo)
	_actualizar_combate_hud()

func _on_espiritu_llego(dano: int):
	if not _puede_jugar():
		return
	if sonido_dano_arbol != null:
		sfx_arbol.play()
	arbol_meta.recibir_dano(dano)

func _on_vida_arbol_cambiada(actual: int, maxima: int):
	hud.actualizar_vida(actual, maxima)

# ---------------- Rondas ----------------
func _expandir_receta(receta: Variant) -> Array[String]:
	var plan: Array[String] = []
	var grupos: Array = receta if receta is Array else [receta]
	for grupo: Dictionary in grupos:
		for clave in grupo:
			for i in grupo[clave]:
				plan.append(clave)
	return plan

func _ajuste_ronda(numero: int) -> Vector3:
	if not ajustes_campana_activos or not _es_escena_campana() or numero <= 1:
		return Vector3.ONE
	if numero_nivel == 0:
		return Vector3(1.10, 1.0, 1.0) if numero >= 3 else Vector3.ONE
	if numero_nivel <= 2:
		return Vector3(1.20, 1.0, 0.88)
	if numero_nivel <= 5:
		return Vector3(1.30, 1.08, 0.82)
	return Vector3(1.40, 1.10, 0.80)

func _intervalo_spawn() -> float:
	return intervalos_spawn[ronda - 1] * _ajuste_ronda(ronda).z

func _plan_de_ronda(numero: int, incluir_desafio: bool, mezclar: bool = false) -> Array[String]:
	var receta: Variant = rondas[numero - 1]
	var plan := _expandir_receta(receta)
	if mezclar and receta is Dictionary:
		plan.shuffle()
	if ajustes_campana_activos and _es_escena_campana() and numero == 5 and numero_nivel >= 3:
		plan.append(REFUERZOS_FINALES[numero_nivel - 3] + ":mediano")
	if incluir_desafio and desafios_ronda.has(numero):
		plan.append_array(_expandir_receta(desafios_ronda[numero]))
	return plan

func _contar_bestias(plan: Array) -> Dictionary:
	var conteo := {}
	for clave in plan:
		conteo[clave] = conteo.get(clave, 0) + 1
	return conteo

func _alternar_desafio():
	if not _puede_jugar() or ronda_activa or not desafios_ronda.has(ronda):
		return
	desafio_elegido = not desafio_elegido
	_actualizar_preparacion()
	_actualizar_combate_hud()

func _actualizar_preparacion():
	if ronda_activa or terminado:
		hud.ocultar_preparacion()
		hud.previa_ronda.hide()
		return
	var plan := _plan_de_ronda(ronda, desafio_elegido)
	var conteo_tipos := {}
	var grandes := {}
	var tallas := {}
	var divisores := 0
	for clave in plan:
		var tipo := clave.get_slice(":", 0)
		if clave.ends_with(":divisor"):
			divisores += 1
		conteo_tipos[tipo] = conteo_tipos.get(tipo, 0) + 1
		var talla := clave.get_slice(":", 1)
		if not tallas.has(tipo) or TAMANOS.find(talla) > TAMANOS.find(tallas[tipo]):
			tallas[tipo] = talla
		if talla == "grande":
			grandes[tipo] = grandes.get(tipo, 0) + 1
	var avisos := PackedStringArray()
	var retratos: Array[Dictionary] = []
	for tipo in TIPOS_BESTIA:
		if conteo_tipos.has(tipo):
			retratos.append({
				"nombre": tipo.capitalize(), "cantidad": conteo_tipos[tipo],
				"retrato": RETRATOS.bestia(_escena_para_tipo(tipo), tallas[tipo]),
			})
	var entrada := suelo.get_global_transform_with_canvas() * suelo.map_to_local(puntos_ruta[0])
	hud.mostrar_previa_ronda(retratos, entrada, _cobertura_previa)
	if divisores > 0:
		avisos.append("Natura divisor ×%d: deja una copia al caer" % divisores)
	for tipo in AMENAZAS:
		if not conteo_tipos.has(tipo) or (tipo == "natura" and divisores > 0 and not grandes.has(tipo)):
			continue
		var aviso: String = AMENAZAS[tipo]
		if tipo == "natura" and grandes.has(tipo):
			aviso = "los grandes resisten más daño"
		if rutas_enemigos.has(tipo):
			aviso = "toma el atajo y " + aviso
		var talla := " (%d grandes)" % grandes[tipo] if grandes.has(tipo) else ""
		avisos.append("%s ×%d%s: %s" % [tipo.capitalize(), conteo_tipos[tipo], talla, aviso])
		if avisos.size() == 3:
			break
	var refuerzos := PackedStringArray()
	if desafios_ronda.has(ronda):
		var extras := _contar_bestias(_expandir_receta(desafios_ronda[ronda]))
		for clave in extras:
			var partes := String(clave).split(":")
			var variante := " divisor" if partes.size() == 3 else ""
			refuerzos.append("%s %s%s ×%d" % [partes[0].capitalize(), partes[1].replace("pequeno", "pequeño"), variante, extras[clave]])
	var recompensa := RECOMPENSA_RONDA if ronda < rondas.size() else 0
	hud.mostrar_preparacion(ronda, plan.size(), avisos, refuerzos, desafio_elegido, RECOMPENSA_DESAFIO, recompensa)

func _iniciar_ronda():
	if ronda_activa or not _puede_jugar():
		return
	ronda_activa = true
	if is_instance_valid(pozo):
		pozo.activar_generacion(true)
	cola_bestias.assign(_plan_de_ronda(ronda, desafio_elegido, true))
	_acum_spawn = _intervalo_spawn()
	_actualizar_preparacion()
	hud.mostrar_boton_ronda("En curso", false)
	_actualizar_combate_hud()

func _terminar_ronda():
	if not ronda_activa or not _puede_jugar() or not cola_bestias.is_empty() or _bestias_en_camino() > 0:
		return
	ronda_activa = false
	gestor_clima.ocultar_avisos(true)
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	if ronda >= rondas.size():
		_ganar_nivel()
		return
	var extra := RECOMPENSA_DESAFIO if desafio_elegido else 0
	desafio_elegido = false
	_recoger_gotas(RECOMPENSA_RONDA + extra)
	hud.anunciar_recompensa(RECOMPENSA_RONDA, extra)
	ronda += 1
	_actualizar_ronda_hud()
	hud.mostrar_boton_ronda("Iniciar ronda", true)
	_actualizar_combate_hud()

func _actualizar_ronda_hud():
	hud.actualizar_ronda(ronda, rondas.size())
	if ronda <= consejos_ronda.size():
		hud.mostrar_consejo(consejos_ronda[ronda - 1])
	_actualizar_preparacion()

func _physics_process(delta: float):
	_actualizar_spawn(delta)
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
		var protegido_flamma := false
		for flamma in llamas:
			if not is_instance_valid(flamma) or flamma.is_queued_for_deletion() or flamma.vida <= 0:
				continue
			var radio: float = flamma.obtener_estadisticas().radio
			if flamma.forma.global_position.distance_squared_to(arbol.global_position) <= radio * radio:
				protegido_flamma = true
				break
		var inmune_al_hielo: bool = arbol.elemento == "glacies"
		var fuentes_electricas: int = efectos.get("electricitas", 0)
		arbol.aplicar_auras(
			efectos.get("glacies", 0) > 0 and not inmune_al_hielo and not protegido_flamma,
			efectos.get("venenum", 0) > 0, fuentes_electricas > 0, protegido_flamma and not inmune_al_hielo
		)
		var id: int = arbol.get_instance_id()
		var dosis: float = _dano_aura_acumulado.get(id, 0.0) + fuentes_electricas * maxf(0.0, delta)
		var dano := floori(dosis + 0.000001)
		if dano > 0:
			arbol.recibir_dano(dano)
		if arbol.vida > 0:
			acumulados[id] = maxf(0.0, dosis - dano)
	_dano_aura_acumulado = acumulados

func _actualizar_spawn(delta: float):
	if not ronda_activa or not _puede_jugar():
		return
	if cola_bestias.is_empty():
		_terminar_ronda()
		return
	var intervalo := _intervalo_spawn()
	_acum_spawn += delta
	while _acum_spawn >= intervalo and not cola_bestias.is_empty():
		_acum_spawn -= intervalo
		var partes := String(cola_bestias.pop_front()).split(":")
		_crear_espiritu(partes[0], partes[1], 0.0, null, partes.size() == 3)

func _process(delta):
	if not _puede_jugar():
		return
	var ahora := Time.get_ticks_usec() / 1000000.0
	var delta_ui: float = delta / Engine.time_scale if _reloj_ui < 0.0 else ahora - _reloj_ui
	_reloj_ui = ahora
	if _bumper_pendiente != null and Time.get_ticks_msec() >= _plazo_bumper:
		_emitir_bumper()
	_actualizar_cursor(delta_ui)
	if usar_cursor_tablero:
		var destino := _punto_objetivo()
		_cursor_visual = destino if _cursor_visual == Vector2.INF else _cursor_visual.lerp(destino, 1.0 - exp(-28.0 * delta_ui))
	else:
		_cursor_visual = Vector2.INF
	_actualizar_recursos(delta)
	_actualizar_ventus(delta)
	_actualizar_contactos_aqua()

	_actualizar_recargas(delta)

	_actualizar_combate_hud()
	_actualizar_inspeccion()
	if seleccion_tipo != "" or usar_cursor_tablero:
		vista.queue_redraw()

func obtener_produccion_agua() -> float:
	var produccion: float = AGUA_POR_CLIMA.get(clima, AGUA_BASE)
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
	if bestia.efecto_movimiento.elemento == "electricitas" and hasta <= desde:
		return hasta
	if hasta < desde:
		return hasta
	var seguidor := bestia.get_parent() as PathFollow2D
	if seguidor.get_parent() != ruta:
		var limite := minf(hasta, bestia.limite_confusion) if bestia.efecto_movimiento.elemento == "aqua" else -INF
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
	_suspender_tiempo()
	numeros_dano.limpiar()
	if is_instance_valid(gestor_clima):
		gestor_clima.cancelar_avisos()
	desafio_elegido = false
	_actualizar_preparacion()
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	ronda_activa = false
	cola_bestias.clear()
	_deseleccionar()
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
	_suspender_tiempo()
	numeros_dano.limpiar()
	if is_instance_valid(gestor_clima):
		gestor_clima.cancelar_avisos()
	desafio_elegido = false
	_actualizar_preparacion()
	if is_instance_valid(pozo):
		pozo.activar_generacion(false)
	ronda_activa = false
	cola_bestias.clear()
	_deseleccionar()
	_limpiar_inspeccion()
	_actualizar_combate_hud()

	if _es_escena_campana():
		Guardado.registrar_victoria(numero_nivel)

	if victoria_escena == null:
		push_error("Falta asignar Victoria Escena en el Inspector del nivel")
		return

	var nombres: Array = []
	for i in desbloqueos:
		if not hud.SEMILLAS_ACTIVAS.has(i) and i < semillas_escenas.size() and semillas_escenas[i] != null:
			nombres.append({"nombre": hud.SEMILLAS[i].nombre, "retrato": RETRATOS.arbol(semillas_escenas[i], &"idle_pequeno", true)})

	var nombres_ataques: Array = []
	for i in desbloqueos_ataques:
		if not hud.ATAQUES_ACTIVOS.has(i):
			nombres_ataques.append(i)

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
	if arrastre and seleccion_tipo == "semilla" and seleccion_indice == i:
		_deseleccionar()
		return
	_limpiar_inspeccion()
	hud.ocultar_aviso_colocacion()
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
	if arrastre and seleccion_tipo == "ataque" and seleccion_indice == i:
		_deseleccionar()
		return
	_limpiar_inspeccion()
	hud.ocultar_aviso_colocacion()
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
	hud.ocultar_aviso_colocacion()
	vista.queue_redraw()

func _input(event: InputEvent):
	if not _puede_jugar() or event.is_echo():
		return
	hud.indicar_dispositivo(event)
	if event is InputEventJoypadButton and _procesar_bumper(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE) \
			and not (event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed):
		get_viewport().set_input_as_handled()
		_iniciar_ronda()
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
	for accion in DIRECCIONES_CURSOR:
		if event.is_action_pressed(accion, false, true):
			usar_cursor_tablero = true
			var direccion: Vector2i = DIRECCIONES_CURSOR[accion]
			if not event is InputEventJoypadMotion or direccion != _direccion_cursor:
				_mover_cursor(direccion)
				_direccion_cursor = direccion
				_espera_cursor = 0.28
			vista.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if not ronda_activa and seleccion_tipo.is_empty() and event is InputEventKey \
			and (event.physical_keycode == KEY_ENTER or event.keycode == KEY_ENTER) \
			and event.is_action_pressed("Confirmar", false, true):
		get_viewport().set_input_as_handled()
		_iniciar_ronda()
		return
	if hud.manejar_accion(event):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			usar_cursor_tablero = true
		_ajustar_cursor()
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
	if not event is InputEventMouseButton:
		_ajustar_cursor()
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
		_ajustar_cursor()
		pos = _punto_objetivo()
	if usar_cursor_tablero and not _celda_navegable(cursor_tablero):
		return
	if seleccion_tipo == "":
		var celda := suelo.local_to_map(suelo.to_local(to_global(pos)))
		celda_torre_seleccionada = celda if arboles_plantados.has(celda) else Vector2i(-1, -1)
		vista.queue_redraw()
		_actualizar_inspeccion()
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
		var impedimento := _impedimento_plantado(celda, seleccion_indice)
		if impedimento.is_empty() and gotas < costo:
			impedimento = "Faltan gotas · %d/%d" % [gotas, costo]
		if not impedimento.is_empty():
			hud.mostrar_aviso_colocacion(impedimento, get_global_transform_with_canvas() * pos)
		elif _plantar(celda, seleccion_indice):
			gotas -= costo
			_actualizar_gotas_hud()
			_deseleccionar()
	elif seleccion_tipo == "ataque":
		_lanzar_ataque(pos, seleccion_indice)
		_deseleccionar()
	elif seleccion_tipo == "pala":
		_quitar_arbol(suelo.local_to_map(pos))
		_deseleccionar()

func _celda_valida_terreno(celda: Vector2i) -> bool:
	return celda.x >= 0 and celda.x < ANCHO and celda.y >= FILAS_BLOQUEADAS and celda.y < ALTO \
		and celda != celda_arbol_madre and not celdas_bloqueadas.has(celda)

func _reserva_terreno(celda: Vector2i) -> bool:
	return celda == celda_pozo or (clima == "volcan" and celdas_geiser.has(celda))

func _se_puede_plantar(celda: Vector2i, tipo: int = -1) -> bool:
	return _impedimento_plantado(celda, tipo).is_empty()

func _impedimento_plantado(celda: Vector2i, tipo: int) -> String:
	if not _celda_valida_terreno(celda):
		return "Casilla fuera del área de plantado"
	if _reserva_terreno(celda):
		return "Casilla reservada"
	if arboles_plantados.has(celda):
		return "Casilla ocupada"
	if tipo == 2:
		return "" if _esta_inundada(celda) else "Aqua necesita una poza azul"
	if _esta_inundada(celda):
		return "Aquí solo se planta Aqua"
	if tipo == 3:
		if _es_camino(celda):
			return ""
		if not VECINOS_ORTOGONALES.any(func(vecino: Vector2i): return _es_camino(celda + vecino)):
			return "Terra necesita una casilla junto al camino"
	if _es_camino(celda):
		return "Elige un cuadro fuera del camino"
	return "" if not limitar_plantado or parcelas_secano.has(celda) else "Elige un cuadro de tierra marcado"

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
	arboles_plantados[celda] = arbol
	tipos_plantados[celda] = tipo
	tamanos_plantados[celda] = 0
	costos_plantados[celda] = hud.SEMILLAS[tipo].costos[0]
	arbol.murio.connect(liberar_celda.bind(celda))
	arbol.dano_recibido.connect(numeros_dano.registrar.bind(arbol, true))
	if is_instance_valid(gestor_clima):
		gestor_clima.actualizar_proteccion()
		if clima == "radiacion":
			gestor_clima.actualizar_indicadores_radiacion()
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
			recarga[i] += hud.intervalo_recarga_ataque(i)
		hud.actualizar_ataque(i, cargas[i], maxima, recarga[i])

func _lanzar_ataque(pos: Vector2, i: int) -> bool:
	if not _puede_jugar() or i < 0 or i >= cargas.size() or not hud.ATAQUES_ACTIVOS.has(i) or cargas[i] < 1.0:
		return false
	var datos: Dictionary = hud.ATAQUES[i]
	cargas[i] -= 1.0
	if recarga[i] == 0.0:
		recarga[i] = hud.intervalo_recarga_ataque(i)
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
	if arboles_plantados.has(celda_torre_seleccionada):
		var origen := suelo.map_to_local(celda_torre_seleccionada) - Vector2.ONE * 29.0
		vista.draw_rect(Rect2(origen, Vector2.ONE * 58.0), Color(0.65, 0.95, 1.0), false, 3.0)
	if seleccion_tipo.is_empty() and usar_cursor_tablero and _celda_navegable(cursor_tablero):
		var centro := _punto_objetivo() if _cursor_visual == Vector2.INF else _cursor_visual
		var punto := centro - Vector2.ONE * 30.0
		vista.draw_rect(Rect2(punto, Vector2.ONE * 60.0), Color("#fff08a"), false, 3.0)
	if seleccion_tipo == "":
		return
	if usar_cursor_tablero and not _celda_navegable(cursor_tablero):
		return
	if seleccion_tipo == "semilla" and limitar_plantado:
		for parcela in parcelas_secano + puestos_terra + celdas_inundadas:
			if _se_puede_plantar(parcela, seleccion_indice):
				var icono := "gota" if _esta_inundada(parcela) else ("puesto_terra" if _es_camino(parcela) else "parcela")
				_dibujar_parcela(vista, parcela, icono, true)
	if not usar_cursor_tablero and hud.punto_sobre_hud(get_viewport().get_mouse_position()):
		return
	var pos := _punto_objetivo()
	if seleccion_tipo == "semilla":
		var celda := suelo.local_to_map(pos)
		var costo: int = hud.SEMILLAS[seleccion_indice].costo
		var ok := _se_puede_plantar(celda, seleccion_indice) and gotas >= costo
		var color := Color(0.53, 1, 0.72, 0.88) if ok else Color(1, 0.39, 0.36, 0.88)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		if not datos_rango_colocacion.is_empty():
			var centro: Vector2 = suelo.map_to_local(celda) + datos_rango_colocacion.centro
			var radio: float = datos_rango_colocacion.radio
			vista.draw_circle(centro, radio, Color(color, 0.07))
			vista.draw_arc(centro, radio, 0.0, TAU, 64, Color(color, 0.65), 2.0, true)
		vista.draw_rect(Rect2(origen + Vector2.ONE * 2, Vector2.ONE * (TAM_CELDA - 4)), color, false, 3.0)
	elif seleccion_tipo == "pala":
		var celda := suelo.local_to_map(pos)
		var color := Color(1, 0.6, 0, 0.5) if arboles_plantados.has(celda) else Color(1, 0, 0, 0.25)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		vista.draw_rect(Rect2(origen, Vector2(TAM_CELDA, TAM_CELDA)), color)
	elif seleccion_tipo == "ataque":
		var radio: float = hud.ATAQUES[seleccion_indice].radio * TAM_CELDA
		vista.draw_circle(pos, radio, Color(1, 1, 1, 0.25))
func _cambiar_prioridad_seleccion():
	if not _puede_jugar() or seleccion_tipo != "":
		return
	var arbol := arboles_plantados.get(celda_torre_seleccionada) as Arbol
	if is_instance_valid(arbol) and arbol.puede_elegir_objetivo():
		hud.indicar_prioridad(arbol.cambiar_prioridad())

func _on_pala_pulsada(arrastre: bool):
	if not _puede_jugar():
		return
	if arrastre and seleccion_tipo == "pala":
		_deseleccionar()
		return
	_limpiar_inspeccion()
	hud.ocultar_aviso_colocacion()
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
	if clima == "radiacion" and is_instance_valid(gestor_clima):
		gestor_clima.actualizar_indicadores_radiacion()
	hud.actualizar_produccion(obtener_produccion_agua(), clima)

func _costo_mejora(celda: Vector2i) -> int:
	var tipo: int = tipos_plantados[celda]
	var t: int = tamanos_plantados[celda]
	return hud.SEMILLAS[tipo].costos[t + 1]

func _actualizar_gotas_hud():
	hud.actualizar_gotas(gotas)
	if hud.panel_mejora.visible:
		_actualizar_inspeccion()

func _mejorar_seleccion():
	_mejorar_arbol(celda_torre_seleccionada)

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
		return

	var arbol = arboles_plantados[celda]
	if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.vida <= 0 or not arbol.mejorar():
		return

	gotas -= costo
	costos_plantados[celda] += costo
	tamanos_plantados[celda] = t + 1
	_actualizar_gotas_hud()
	hud.actualizar_produccion(obtener_produccion_agua(), clima)

func _ocultar_info_torre():
	if is_instance_valid(torre_informada):
		torre_informada.mostrar_rango(false)
	torre_informada = null
	hud.panel_mejora.hide()

func _limpiar_inspeccion():
	celda_torre_seleccionada = Vector2i(-1, -1)
	_ocultar_info_torre()
	vista.queue_redraw()

func _mostrar_info_torre(celda: Vector2i):
	var arbol := arboles_plantados.get(celda) as Arbol
	if not is_instance_valid(arbol) or arbol.is_queued_for_deletion() or arbol.vida <= 0:
		_limpiar_inspeccion()
		return
	if torre_informada != arbol:
		_ocultar_info_torre()
		torre_informada = arbol
		arbol.mostrar_rango(true)

	var datos := arbol.obtener_estadisticas()
	var estadisticas := PackedStringArray()
	var detalles := PackedStringArray()
	if datos.produccion > 0.0:
		estadisticas.append("Pozo +%.2f gotas/s" % datos.produccion)
	elif datos.empuje > 0.0:
		estadisticas.append("Bloqueo · Empuje %.1f casillas" % datos.empuje)
		detalles.append("Aqua atraviesa el bloqueo.")
	else:
		estadisticas.append("%d daño · %.2f disparos/s" % [datos.dano, datos.disparos_segundo])
		estadisticas.append("Alcance %.1f casillas" % (datos.radio / TAM_CELDA))
	if datos.radio_explosion > 0.0:
		estadisticas.append("Explosión %.1f casillas" % (datos.radio_explosion / TAM_CELDA))
	if datos.congelacion > 0.0:
		estadisticas.append("Congela %.1f s · Penetra %d" % [datos.congelacion, datos.objetivos])
	elif arbol.elemento == "electricitas":
		estadisticas.append("Encadena hasta %d bestias" % datos.objetivos)
		detalles.append("Salto máximo de 2 casillas.")
	if datos.veneno_segundo > 0.0:
		estadisticas.append("Veneno %.0f HP/s · %.1f s" % [datos.veneno_segundo, datos.duracion_veneno])
	if datos.factor_lentitud < 1.0:
		var lentitud := "Lentitud %d%%" % roundi((1.0 - datos.factor_lentitud) * 100.0)
		if datos.duracion_lentitud > 0.0:
			lentitud += " · %.1f s" % datos.duracion_lentitud
		estadisticas.append(lentitud)
	if datos.nivel_congelacion > 0 or clima == "ventisca":
		detalles.append("Escarcha %d/3%s" % [datos.nivel_congelacion, " · Protegido por Flamma" if datos.protegido_ventisca else ""])
	if clima == "derrumbe" and arbol.elemento == "terra":
		detalles.append("Rocas absorbidas %d/3" % datos.golpes_derrumbe)
	if datos.bono_geiser > 0.0:
		detalles.append("Géiser: cadencia +25%% por %.1f s" % datos.bono_geiser)
	if datos.congelado_por_aura:
		detalles.append("Congelado por aura: no dispara.")
	if datos.intoxicado_por_aura:
		detalles.append("Aura tóxica: cadencia −30% · Fallo 30%")

	var nivel := arbol.obtener_nivel()
	var costo := _costo_mejora(celda) if nivel < TAMANOS.size() else -1
	hud.mostrar_mejora(tipos_plantados[celda], nivel, costo, gotas >= costo)
	hud.indicar_prioridad(Arbol.NOMBRES_PRIORIDAD[arbol.prioridad] if arbol.puede_elegir_objetivo() else "")
	var punto := arbol.get_global_transform_with_canvas().origin
	var centro_pozo := pozo.get_global_transform_with_canvas().origin
	var area_pozo := Rect2(centro_pozo - Vector2.ONE * 33.0, Vector2.ONE * 66.0)
	hud.mostrar_ficha_torre(arbol.vida, arbol.vida_maxima, "\n".join(estadisticas), "\n".join(detalles), punto, area_pozo, _cobertura_camino)

func _cobertura_camino(area: Rect2) -> float:
	var region := suelo.get_global_transform_with_canvas().affine_inverse() * area
	var inicio := suelo.local_to_map(region.position)
	var fin := suelo.local_to_map(region.end)
	var cubierta := 0.0
	for y in range(inicio.y, fin.y + 1):
		for x in range(inicio.x, fin.x + 1):
			var celda := Vector2i(x, y)
			if _es_camino(celda):
				var tile := Rect2(suelo.map_to_local(celda) - Vector2.ONE * TAM_CELDA / 2.0, Vector2.ONE * TAM_CELDA)
				cubierta += region.intersection(tile).get_area()
	return cubierta

func _cobertura_previa(area: Rect2) -> float:
	var cubierta := _cobertura_camino(area)
	for celda: Vector2i in parcelas_secano + celdas_inundadas + [celda_pozo]:
		var centro := suelo.get_global_transform_with_canvas() * suelo.map_to_local(celda)
		var parcela := Rect2(centro - Vector2.ONE * 24.0, Vector2.ONE * 48.0)
		cubierta += area.intersection(parcela).get_area() * 2.0
	return cubierta

func _actualizar_inspeccion():
	if _puede_jugar() and seleccion_tipo.is_empty() and arboles_plantados.has(celda_torre_seleccionada):
		_mostrar_info_torre(celda_torre_seleccionada)
	elif hud.panel_mejora.visible:
		_ocultar_info_torre()

func _abrir_pausa():
	if pausa != null or not _puede_jugar():
		return
	_ocultar_info_torre()
	hud.ocultar_aviso_colocacion()
	hud.opciones_presionadas.clear()
	pausa = pausa_escena.instantiate()
	pausa.numero_nivel = numero_nivel
	add_child(pausa)
	pausa.guia_solicitada.connect(_abrir_guia)
	pausa.tree_exited.connect(func():
		pausa = null
		if is_inside_tree():
			_aplicar_tiempo(velocidad_partida if _puede_jugar() else 1.0)
	)
	_suspender_tiempo()
	get_tree().paused = true

func _es_escena_campana() -> bool:
	return scene_file_path == Guardado.escena_para_nivel(numero_nivel)

func _mostrar_informe_inicial():
	var clave := Vector2i(Guardado.slot_actual, numero_nivel)
	if get_tree().current_scene == self and _es_escena_campana() and not _informes_vistos.has(clave):
		_abrir_guia()

func _fichas_del_nivel() -> Array:
	var secciones: Array = []
	var titulo: String = hud.label_mision.text
	if _es_escena_campana():
		secciones.assign(CONTENIDO_GUIA.LECCIONES[numero_nivel])
	elif clima == "volcan":
		secciones.assign(CONTENIDO_GUIA.LECCION_VOLCAN)
	elif not consejo_nivel.is_empty():
		secciones.append(["Consejo", consejo_nivel])
	var nombre_clima: String = gestor_clima.NOMBRES[clima]
	secciones.push_front(["Preparación", "%s · Ronda %d/%d · %d gotas iniciales" % [nombre_clima, ronda, rondas.size(), gotas_iniciales]])
	var fichas := [{"titulo": titulo if not titulo.is_empty() else nombre_clima, "indice": "Informe y táctica", "secciones": secciones}]
	if ronda <= consejos_ronda.size():
		fichas.append({
			"titulo": "Ronda %d" % ronda, "indice": "Consejo de ronda",
			"secciones": [["Táctica sugerida", consejos_ronda[ronda - 1]]],
		})
	return fichas

func _abrir_guia():
	if not inicializado or terminado or is_instance_valid(guia):
		return
	var desde_pausa := is_instance_valid(pausa)
	if get_tree().paused and not desde_pausa:
		return
	_ocultar_info_torre()
	hud.ocultar_aviso_colocacion()
	arrastrando = false
	hud.opciones_presionadas.clear()
	if desde_pausa:
		pausa.hide()
	if _es_escena_campana():
		_informes_vistos[Vector2i(Guardado.slot_actual, numero_nivel)] = true
	guia = ESCENA_GUIA.instantiate()
	guia.fichas_nivel = _fichas_del_nivel()
	guia.plantas_visibles = hud.SEMILLAS_ACTIVAS
	guia.ataques_visibles = hud.ATAQUES_ACTIVOS
	_suspender_tiempo()
	get_tree().paused = true
	add_child(guia)
	guia.cerrada.connect(func():
		guia = null
		if desde_pausa:
			pausa.show()
			pausa.boton_guia.grab_focus()
		else:
			get_tree().paused = false
			_aplicar_tiempo(velocidad_partida)
	)
