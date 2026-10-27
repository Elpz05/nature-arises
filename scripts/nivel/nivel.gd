extends Node2D

@export var espiritu_escena: PackedScene
@export var arbol_madre_escena: PackedScene
@export var hud_escena: PackedScene
@export var semillas_escenas: Array[PackedScene]
@export var pausa_escena: PackedScene
@export var numero_nivel := 0          # 0 en nivel_0, 1 en el siguiente, etc.
@export var victoria_escena: PackedScene
@export var desbloqueos: Array[int] = [1, 2]
@export var desbloqueos_ataques: Array[int] = [1]
@export var derrota_escena: PackedScene

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles
#@onready var label_derrota: Label = $Interfaz/LabelDerrota

const ANCHO := 30
const ALTO := 17
const TAM_CELDA := 64
const CELDA_ARBOL_MADRE := Vector2i(25, 14)

const TOTAL_RONDAS := 5
const TAMANOS := ["pequeno", "mediano", "grande"]
const NOMBRES_TAMANO := ["pequeño", "mediano", "grande"]
const RONDAS := [
	{"pequeno": 4},                       # 800
	{"pequeno": 4, "mediano": 2},         # 1800
	{"pequeno": 3, "mediano": 4},         # 2600
	{"mediano": 4, "grande": 2},          # 4000
	{"grande": 6},                        # 6000       # ronda 5
]
const INTERVALOS_SPAWN := [3.0, 2.6, 2.2, 1.8, 1.5]
const GOTAS_INICIALES := 3
const INTERVALO_GOTAS := 4.0        # 1 gota cada 4 s
const RECARGA_ATAQUE := 3.0

const RUTA := [
	Vector2i(0, 3), Vector2i(5, 3), Vector2i(5, 12), Vector2i(10, 12),
	Vector2i(10, 3), Vector2i(15, 3), Vector2i(15, 12), Vector2i(20, 12),
	Vector2i(20, 3), Vector2i(25, 3), Vector2i(25, 13),
]

const FILAS_BLOQUEADAS := 3 

var hud
var source_pasto: int
var source_camino: int
var celdas_ocupadas := {}
var arbol_meta

var gotas := GOTAS_INICIALES
var _acum_gotas := 0.0
var terminado := false

var ronda := 1
var ronda_activa := false
var cola_bestias: Array = []
var tipos_plantados := {}        # celda -> índice de semilla
var tamanos_plantados := {}      # celda -> 0 pequeño, 1 mediano, 2 grande
var tooltip: Label
var _acum_spawn := 0.0

var seleccion_tipo := ""          # "", "semilla" o "ataque"
var seleccion_indice := -1
var arrastrando := false

var cargas: Array[int] = []
var recarga: Array[float] = []
var vista: Node2D

var arboles_plantados := {}
var costos_plantados := {} 

var pausa

func _ready():
	source_pasto = suelo.tile_set.get_source_id(0)
	source_camino = camino.tile_set.get_source_id(0)

	_crear_hud()
	_generar_tablero()
	_generar_camino()
	_generar_curva()
	_crear_arbol_madre()
	_crear_vista()
	_crear_tooltip()
	MusicaManager.reproducir(preload("res://audios/nivel_musica/Forest 03.ogg"))
	#label_derrota.hide()

	for i in hud.ATAQUES.size():
		cargas.append(hud.ATAQUES[i].capacidad)
		recarga.append(0.0)

	hud.actualizar_gotas(gotas)
	hud.actualizar_ronda(ronda, TOTAL_RONDAS)
	hud.mostrar_boton_ronda("Iniciar ronda %d" % ronda, true)

# ---------------- HUD ----------------
func _crear_hud():
	hud = hud_escena.instantiate()
	add_child(hud)
	hud.semilla_pulsada.connect(_on_semilla_pulsada)
	hud.ataque_pulsado.connect(_on_ataque_pulsado)
	hud.ronda_solicitada.connect(_iniciar_ronda)
	hud.pala_pulsada.connect(_on_pala_pulsada)

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

# ---------------- Rondas ----------------
func _iniciar_ronda():
	if ronda_activa or terminado:
		return
	ronda_activa = true
	cola_bestias.clear()
	var receta: Dictionary = RONDAS[ronda - 1]
	for tam in receta:
		for k in receta[tam]:
			cola_bestias.append(tam)
	cola_bestias.shuffle()
	_acum_spawn = INTERVALOS_SPAWN[ronda - 1]
	hud.mostrar_boton_ronda("Ronda %d en curso" % ronda, false)

func _terminar_ronda():
	ronda_activa = false
	if ronda >= TOTAL_RONDAS:
		_ganar_nivel()
		return
	ronda += 1
	hud.actualizar_ronda(ronda, TOTAL_RONDAS)
	hud.mostrar_boton_ronda("Iniciar ronda %d" % ronda, true)

func _process(delta):
	if terminado:
		return

	# Recarga de ataques elementales
	for i in cargas.size():
		if recarga[i] > 0.0:
			recarga[i] -= delta
			if recarga[i] <= 0.0:
				recarga[i] = 0.0
				cargas[i] = hud.ATAQUES[i].capacidad
				hud.actualizar_ataque(i, cargas[i], cargas[i])

	if ronda_activa:
		# Gotas: solo mientras hay ronda en curso
		_acum_gotas += delta
		if _acum_gotas >= INTERVALO_GOTAS:
			_acum_gotas -= INTERVALO_GOTAS
			gotas += 1
			hud.actualizar_gotas(gotas)

		# Salida de bestias
		if cola_bestias.size() > 0:
			_acum_spawn += delta
		if _acum_spawn >= INTERVALOS_SPAWN[ronda - 1]:
				_acum_spawn = 0.0
				_crear_espiritu(cola_bestias.pop_front())
		elif ruta.get_child_count() == 0:
			_terminar_ronda()

	_actualizar_tooltip()
	if seleccion_tipo != "":
		vista.queue_redraw()

func _perder_nivel():
	if terminado:
		return
	terminado = true
	if derrota_escena == null:
		push_error("Falta asignar Derrota Escena en el Inspector de Nivel0")
		get_tree().paused = true
		return
	var d = derrota_escena.instantiate()
	add_child(d)
	get_tree().paused = true

func _ganar_nivel():
	terminado = true
	print("Ganaste el nivel, creando ventana de victoria")
	if Guardado.slot_actual >= 0:
		Guardado.completar_nivel(numero_nivel)
		Guardado.desbloquear(desbloqueos)
		Guardado.desbloquear_ataques(desbloqueos_ataques)

	if victoria_escena == null:
		push_error("Falta asignar Victoria Escena en el Inspector de Nivel0")
		return
	
	var nombres: Array = []
	for i in desbloqueos:
		nombres.append(hud.SEMILLAS[i].nombre)

	var nombres_ataques: Array = []
	for i in desbloqueos_ataques:
		nombres_ataques.append(hud.ATAQUES[i].nombre)

	var v = victoria_escena.instantiate()
	v.numero_nivel = numero_nivel
	v.desbloqueos = nombres
	v.desbloqueos_ataques = nombres_ataques
	add_child(v)
	get_tree().paused = true

# ---------------- Selección (arrastrar o clic + clic) ----------------
func _on_semilla_pulsada(i: int, arrastre: bool):
	if not hud.SEMILLAS_ACTIVAS.has(i):
		return
	seleccion_tipo = "semilla"
	seleccion_indice = i
	arrastrando = arrastre
	hud.resaltar("semilla", i)

func _on_ataque_pulsado(i: int, arrastre: bool):
	if not hud.ATAQUES_ACTIVOS.has(i) or cargas[i] <= 0:
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
	if event.is_action_pressed("ui_cancel"):
		if seleccion_tipo != "":
			_deseleccionar()
		else:
			_abrir_pausa()
		get_viewport().set_input_as_handled()   # evita que la pausa se cierre con el mismo Esc
		return

	if seleccion_tipo == "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and arrastrando:
		if not hud.punto_sobre_hud(get_viewport().get_mouse_position()):
			_confirmar(vista.get_local_mouse_position())
			_deseleccionar()
		else:
			arrastrando = false
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_deseleccionar()

func _unhandled_input(event):
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos := vista.get_local_mouse_position()
	if seleccion_tipo == "":
		_mejorar_arbol(suelo.local_to_map(pos))
	elif not arrastrando:
		_confirmar(pos)

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
	elif seleccion_tipo == "pala":
		_quitar_arbol(suelo.local_to_map(pos))
		_deseleccionar()

func _se_puede_plantar(celda: Vector2i) -> bool:
	if celda.x < 0 or celda.x >= ANCHO or celda.y < FILAS_BLOQUEADAS or celda.y >= ALTO:
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
	arboles_plantados[celda] = arbol
	tipos_plantados[celda] = tipo
	tamanos_plantados[celda] = 0
	costos_plantados[celda] = hud.SEMILLAS[tipo].costos[0]
	arbol.murio.connect(liberar_celda.bind(celda))
	return true

func _lanzar_ataque(pos: Vector2, i: int):
	var datos = hud.ATAQUES[i]
	cargas[i] -= 1
	if recarga[i] == 0.0:
		recarga[i] = RECARGA_ATAQUE
	hud.actualizar_ataque(i, cargas[i], datos.capacidad)

	var centro := to_global(pos)
	var radio: float = datos.radio * TAM_CELDA
	var golpeadas := 0
	for bestia in get_tree().get_nodes_in_group("bestias"):
		if bestia.global_position.distance_to(centro) > radio:
			continue
		golpeadas += 1
		if bestia.has_method("aplicar_ataque_elemental"):
			bestia.aplicar_ataque_elemental(datos.nombre, datos.dano)
		elif bestia.has_method("recibir_dano"):
			bestia.recibir_dano(datos.dano)
		else:
			push_warning("La bestia no tiene recibir_dano() ni aplicar_ataque_elemental()")
	print("Ataque %s: %d bestias golpeadas" % [datos.nombre, golpeadas])

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
	elif seleccion_tipo == "pala":
		var celda := suelo.local_to_map(pos)
		var color := Color(1, 0.6, 0, 0.5) if arboles_plantados.has(celda) else Color(1, 0, 0, 0.25)
		var origen := suelo.map_to_local(celda) - Vector2(TAM_CELDA, TAM_CELDA) / 2.0
		vista.draw_rect(Rect2(origen, Vector2(TAM_CELDA, TAM_CELDA)), color)
	elif seleccion_tipo == "ataque":
		var radio: float = hud.ATAQUES[seleccion_indice].radio * TAM_CELDA
		vista.draw_circle(pos, radio, Color(1, 1, 1, 0.25))

func _on_pala_pulsada(arrastre: bool):
	seleccion_tipo = "pala"
	seleccion_indice = 0
	arrastrando = arrastre
	hud.resaltar("pala", 0)

func _quitar_arbol(celda: Vector2i):
	if not arboles_plantados.has(celda):
		return
	var arbol = arboles_plantados[celda]
	if is_instance_valid(arbol):
		arbol.queue_free()

	gotas += costos_plantados.get(celda, 0)
	hud.actualizar_gotas(gotas)

	liberar_celda(celda)

func liberar_celda(celda: Vector2i):
	arboles_plantados.erase(celda)
	costos_plantados.erase(celda)
	tipos_plantados.erase(celda)
	tamanos_plantados.erase(celda)
	celdas_ocupadas.erase(celda)

func _costo_mejora(celda: Vector2i) -> int:
	var tipo: int = tipos_plantados[celda]
	var t: int = tamanos_plantados[celda]
	return hud.SEMILLAS[tipo].costos[t + 1]

func _mejorar_arbol(celda: Vector2i):
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
	costos_plantados[celda] += costo        # la pala devuelve todo lo invertido
	tamanos_plantados[celda] = t + 1
	hud.actualizar_gotas(gotas)

func _crear_tooltip():
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	tooltip = Label.new()
	tooltip.add_theme_font_size_override("font_size", 22)
	tooltip.add_theme_constant_override("outline_size", 8)
	tooltip.add_theme_color_override("font_outline_color", Color.BLACK)
	tooltip.hide()
	capa.add_child(tooltip)

func _actualizar_tooltip():
	var pos_pantalla := get_viewport().get_mouse_position()
	var celda := suelo.local_to_map(suelo.get_local_mouse_position())
	if seleccion_tipo != "" or hud.punto_sobre_hud(pos_pantalla) \
			or not arboles_plantados.has(celda):
		tooltip.hide()
		return

	var tipo: int = tipos_plantados[celda]
	var t: int = tamanos_plantados[celda]
	var texto := "%s (%s)" % [hud.SEMILLAS[tipo].nombre, NOMBRES_TAMANO[t]]
	if t >= TAMANOS.size() - 1:
		texto += "\nTamaño máximo"
		tooltip.modulate = Color.WHITE
	else:
		var costo := _costo_mejora(celda)
		texto += "\nMejorar a %s: %d gotas (clic)" % [NOMBRES_TAMANO[t + 1], costo]
		tooltip.modulate = Color.WHITE if gotas >= costo else Color(1, 0.5, 0.5)
	tooltip.text = texto
	tooltip.position = pos_pantalla + Vector2(18, 18)
	tooltip.show()

func _abrir_pausa():
	if pausa != null or terminado:
		return
	pausa = pausa_escena.instantiate()
	pausa.numero_nivel = numero_nivel
	add_child(pausa)
	pausa.tree_exited.connect(func(): pausa = null)
	get_tree().paused = true
