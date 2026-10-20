extends Node2D

@export var arbol_escena: PackedScene
@export var espiritu_escena: PackedScene
@export var arbol_madre_escena: PackedScene

var arbol_meta

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles

@onready var label_vida: Label = $Interfaz/LabelVida
@onready var label_derrota: Label = $Interfaz/LabelDerrota

var celdas_ocupadas := {}

const ANCHO := 30
const ALTO := 17
const CELDA_ARBOL_MADRE := Vector2i(25, 14)

const RUTA := [
	Vector2i(0, 3),
	Vector2i(5, 3),
	Vector2i(5, 12),
	Vector2i(10, 12),
	Vector2i(10, 3),
	Vector2i(15, 3),
	Vector2i(15, 12),
	Vector2i(20, 12),
	Vector2i(20, 3),
	Vector2i(25, 3),
	Vector2i(25, 13),   # aquí va el árbol meta
]

const SOURCE_PASTO := 1     # los IDs que imprime tu _ready()
const SOURCE_CAMINO := 0    # pon aquí el ID real del camino

func _ready():
	_generar_tablero()
	_generar_camino()
	_generar_curva()
	_crear_espiritu()
	_crear_arbol_madre()
	
	for i in suelo.tile_set.get_source_count():
		print("Source ID existente: ", suelo.tile_set.get_source_id(i))
		var id := suelo.tile_set.get_source_id(i)
		print("Source ID existente: ", id)

func _generar_tablero():
	for x in ANCHO:
		for y in ALTO:
			var celda := Vector2i(x, y)
			var coords_atlas := Vector2i(0, 0)
			if (x + y) % 2 == 1:
				coords_atlas = Vector2i(1, 0)
			suelo.set_cell(celda, 1, coords_atlas)   # cambia el 0 si tu source tiene otro ID

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

	print("Celdas de camino: ", celdas_ocupadas.size())
	print("Celdas en la capa: ", camino.get_used_cells().size())
	print("TileSet: ", camino.tile_set)
	if camino.tile_set:
		print("Sources: ", camino.tile_set.get_source_count())
		print("ID del source 0: ", camino.tile_set.get_source_id(0))

func _pintar_camino(celda: Vector2i):
	camino.set_cell(celda, SOURCE_CAMINO, Vector2i(0, 0))
	celdas_ocupadas[celda] = true

func _generar_curva():
	var curva := Curve2D.new()
	for celda in RUTA:
		curva.add_point(suelo.map_to_local(celda))
	ruta.curve = curva

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
	print("¡Un espíritu llegó al árbol meta! Daño: ", dano)
	arbol_meta.recibir_dano(dano)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var celda: Vector2i = suelo.local_to_map(suelo.get_local_mouse_position())
		_intentar_plantar(celda)

func _intentar_plantar(celda: Vector2i):
	# Fuera del tablero
	if celda.x < 0 or celda.x >= ANCHO or celda.y < 0 or celda.y >= ALTO:
		return
	# Camino u otro árbol encima
	if celdas_ocupadas.has(celda):
		print("No puedes plantar aquí")
		return

	var arbol = arbol_escena.instantiate()
	arbol.position = suelo.map_to_local(celda)
	arboles.add_child(arbol)
	celdas_ocupadas[celda] = true
	print("Árbol plantado en ", celda)

func _crear_arbol_madre():
	arbol_meta = arbol_madre_escena.instantiate()
	arbol_meta.position = suelo.map_to_local(CELDA_ARBOL_MADRE)
	add_child(arbol_meta)
	celdas_ocupadas[CELDA_ARBOL_MADRE] = true
	arbol_meta.vida_cambiada.connect(_on_vida_arbol_cambiada)
	arbol_meta.murio.connect(_perder_nivel)
	_on_vida_arbol_cambiada(arbol_meta.vida, arbol_meta.vida_maxima)
	print("Arbol madre en: ", arbol_meta.position, " visible: ", arbol_meta.visible)

func _on_vida_arbol_cambiada(actual: int, maxima: int):
	label_vida.text = "Árbol madre: %d / %d" % [actual, maxima]

func _perder_nivel():
	label_derrota.show()
	get_tree().paused = true
