extends Node2D

@export var espiritu_escena: PackedScene
@export var arbol_madre_escena: PackedScene
@export var semillas_escenas: Array[PackedScene]
@export var hud_escena: PackedScene

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles
#@onready var label_derrota: Label = $Interfaz/LabelDerrota

var hud

const ANCHO := 30
const ALTO := 17
const TAM_CELDA := 64
const CELDA_ARBOL_MADRE := Vector2i(25, 14)

const TOTAL_RONDAS := 5
const DURACION_NIVEL := 240.0            # 4 min x 5 niveles = 20 min
const ESPIRITUS_POR_RONDA := [4, 6, 8, 10, 12]
const INTERVALO_GOTAS := 2.0             # 0.5 gotas por segundo
const RECARGA_ATAQUE := 3.0

const RUTA := [
	Vector2i(0, 3), Vector2i(5, 3), Vector2i(5, 12), Vector2i(10, 12),
	Vector2i(10, 3), Vector2i(15, 3), Vector2i(15, 12), Vector2i(20, 12),
	Vector2i(20, 3), Vector2i(25, 3), Vector2i(25, 13),
]

var source_pasto: int
var source_camino: int
var celdas_ocupadas := {}
var arbol_meta

var gotas := 5
var _acum_gotas := 0.0
var tiempo := 0.0
var ronda := 0
var horario: Array[float] = []
var indice_horario := 0
var terminado := false

var seleccion_tipo := ""          # "", "semilla" o "ataque"
var seleccion_indice := -1
var arrastrando := false

var cargas: Array[int] = []
var recarga: Array[float] = []
var vista: Node2D

func _ready():
	source_pasto = suelo.tile_set.get_source_id(0)
	source_camino = camino.tile_set.get_source_id(0)

	_crear_hud()
	_generar_tablero()
	_generar_camino()
	_generar_curva()
	_crear_arbol_madre()
	_crear_vista()
	#label_derrota.hide()

	for i in hud.ATAQUES.size():
		cargas.append(hud.ATAQUES[i].capacidad)
		recarga.append(0.0)

	_generar_horario()
	hud.actualizar_gotas(gotas)
	hud.actualizar_ronda(1, TOTAL_RONDAS)

# ---------------- Tablero y camino ----------------
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
	for i in range(RUTA.size() - 1):
		var desde: Vector2i = RUTA[i]
		var hasta: Vector2i = RUTA[i + 1]
		var paso: Vector2i = (hasta - desde).sign()
		var celda := desde
		while celda != hasta:
			_pintar_camino(celda)
			celda += paso
		_pintar_camino(hasta)

func _pintar_camino(celda: Vector2i):
	camino.set_cell(celda, source_camino, Vector2i(0, 0))
	celdas_ocupadas[celda] = true

func _generar_curva():
	var curva := Curve2D.new()
	for celda in RUTA:
		curva.add_point(suelo.map_to_local(celda))
	ruta.curve = curva

# ---------------- Árbol madre y espíritus ----------------
func _crear_arbol_madre():
	arbol_meta = arbol_madre_escena.instantiate()
	arbol_meta.position = suelo.map_to_local(CELDA_ARBOL_MADRE)
	add_child(arbol_meta)
	celdas_ocupadas[CELDA_ARBOL_MADRE] = true
	arbol_meta.vida_cambiada.connect(_on_vida_arbol_cambiada)
	arbol_meta.murio.connect(_perder_nivel)
	_on_vida_arbol_cambiada(arbol_meta.vida, arbol_meta.vida_maxima)

func _crear_espiritu(tamano := "pequeno", progreso := 0.0):
	var seguidor := PathFollow2D.new()
	seguidor.loop = false
	seguidor.rotates = false
	ruta.add_child(seguidor)
	seguidor.progress = progreso

	var espiritu = espiritu_escena.instantiate()
	espiritu.tamano = tamano
	seguidor.add_child(espiritu)
	espiritu.llego_a_meta.connect(_on_espiritu_llego)
	espiritu.invocar_copia.connect(_crear_espiritu)

func _on_espiritu_llego(dano: int):
	arbol_meta.recibir_dano(dano)

func _on_vida_arbol_cambiada(actual: int, maxima: int):
	hud.actualizar_vida(actual, maxima)

# ---------------- Tiempo, rondas, gotas ----------------
func _process(delta):
	if terminado:
		return
	tiempo += delta

	var dur_ronda := DURACION_NIVEL / TOTAL_RONDAS
	var nueva := mini(int(tiempo / dur_ronda) + 1, TOTAL_RONDAS)
	if nueva != ronda:
		ronda = nueva
		hud.actualizar_ronda(ronda, TOTAL_RONDAS)

	while indice_horario < horario.size() and tiempo >= horario[indice_horario]:
		_crear_espiritu()
		indice_horario += 1

	_acum_gotas += delta
	if _acum_gotas >= INTERVALO_GOTAS:
		_acum_gotas -= INTERVALO_GOTAS
		gotas += 1
		hud.actualizar_gotas(gotas)

	for i in cargas.size():
		if recarga[i] > 0.0:
			recarga[i] -= delta
			if recarga[i] <= 0.0:
				recarga[i] = 0.0
				cargas[i] = hud.ATAQUES[i].capacidad
				hud.actualizar_ataque(i, cargas[i], cargas[i])

	if seleccion_tipo != "":
		vista.queue_redraw()

	if tiempo >= DURACION_NIVEL and indice_horario >= horario.size() \
			and ruta.get_child_count() == 0:
		_ganar_nivel()

func _generar_horario():
	var dur_ronda := DURACION_NIVEL / TOTAL_RONDAS
	for r in TOTAL_RONDAS:
		var n: int = ESPIRITUS_POR_RONDA[r]
		for k in n:
			horario.append(r * dur_ronda + dur_ronda * k / n)

func _perder_nivel():
	terminado = true
	#label_derrota.text = "¡Nivel perdido!"
	#label_derrota.show()
	get_tree().paused = true

func _ganar_nivel():
	terminado = true
	#label_derrota.text = "¡Nivel superado!"
	#label_derrota.show()
	get_tree().paused = true

# ---------------- Selección (arrastrar o clic + clic) ----------------
func _on_semilla_pulsada(i: int, arrastre: bool):
	seleccion_tipo = "semilla"
	seleccion_indice = i
	arrastrando = arrastre
	hud.resaltar("semilla", i)

func _on_ataque_pulsado(i: int, arrastre: bool):
	if cargas[i] <= 0:
		return
	seleccion_tipo = "ataque"
	seleccion_indice = i
	arrastrando = arrastre
	hud.resaltar("ataque", i)

func _deseleccionar():
	seleccion_tipo = ""
	seleccion_indice = -1
	arrastrando = false
	hud.resaltar("", -1)
	vista.queue_redraw()

func _input(event):
	if seleccion_tipo == "":
		return
	# Soltar después de arrastrar
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and arrastrando:
		if not hud.punto_sobre_hud(get_viewport().get_mouse_position()):
			_confirmar(vista.get_local_mouse_position())
			_deseleccionar()
		else:
			arrastrando = false   # fue un clic en el botón: queda seleccionado
	# Cancelar
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_deseleccionar()

func _unhandled_input(event):
	# Modo clic: ya hay algo seleccionado y haces clic en el tablero
	if seleccion_tipo == "" or arrastrando:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_confirmar(vista.get_local_mouse_position())

func _confirmar(pos: Vector2):
	if seleccion_tipo == "semilla":
		var celda := suelo.local_to_map(pos)
		var costo: int = hud.SEMILLAS[seleccion_indice].costo
		if _se_puede_plantar(celda) and gotas >= costo and _plantar(celda, seleccion_indice):
			gotas -= costo
			hud.actualizar_gotas(gotas)
			_deseleccionar()
	elif seleccion_tipo == "ataque":
		_lanzar_ataque(pos, seleccion_indice)
		_deseleccionar()

func _se_puede_plantar(celda: Vector2i) -> bool:
	if celda.x < 0 or celda.x >= ANCHO or celda.y < 0 or celda.y >= ALTO:
		return false
	return not celdas_ocupadas.has(celda)

func _plantar(celda: Vector2i, tipo: int) -> bool:
	if tipo >= semillas_escenas.size() or semillas_escenas[tipo] == null:
		push_warning("Falta la escena de la semilla %d en Semillas Escenas" % tipo)
		return false
	var arbol = semillas_escenas[tipo].instantiate()
	arbol.position = suelo.map_to_local(celda)
	arboles.add_child(arbol)
	celdas_ocupadas[celda] = true
	return true

func _lanzar_ataque(pos: Vector2, i: int):
	var datos = hud.ATAQUES[i]
	cargas[i] -= 1
	if recarga[i] == 0.0:
		recarga[i] = RECARGA_ATAQUE
	hud.actualizar_ataque(i, cargas[i], datos.capacidad)

	var centro := to_global(pos)
	var radio: float = datos.radio * TAM_CELDA
	for bestia in get_tree().get_nodes_in_group("bestias"):
		if bestia.global_position.distance_to(centro) > radio:
			continue
		if bestia.has_method("aplicar_ataque_elemental"):
			bestia.aplicar_ataque_elemental(datos.nombre, datos.dano)
		elif bestia.has_method("recibir_dano"):
			bestia.recibir_dano(datos.dano)

# ---------------- Vista previa ----------------
func _crear_vista():
	vista = Node2D.new()
	vista.z_index = 10
	vista.draw.connect(_dibujar_vista)
	add_child(vista)

func _dibujar_vista():
	if seleccion_tipo == "":
		return
	var pos := vista.get_local_mouse_position()
	if seleccion_tipo == "semilla":
		var celda := suelo.local_to_map(pos)
		var costo: int = hud.SEMILLAS[seleccion_indice].costo
		var ok := _se_puede_plantar(celda) and gotas >= costo
		var color := Color(0, 1, 0, 0.4) if ok else Color(1, 0, 0, 0.4)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		vista.draw_rect(Rect2(origen, Vector2(TAM_CELDA, TAM_CELDA)), color)
	else:
		var radio: float = hud.ATAQUES[seleccion_indice].radio * TAM_CELDA
		vista.draw_circle(pos, radio, Color(1, 1, 1, 0.25))

func _crear_hud():
	hud = hud_escena.instantiate()
	add_child(hud)
	hud.semilla_pulsada.connect(_on_semilla_pulsada)
	hud.ataque_pulsado.connect(_on_ataque_pulsado)
