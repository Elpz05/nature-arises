extends Node2D

@export var arbol_escena: PackedScene
@export var espiritu_escena: PackedScene

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino
@onready var ruta: Path2D = $RutaEspiritu
@onready var arboles: Node2D = $Arboles

var celdas_ocupadas := {}

const ANCHO := 30
const ALTO := 17

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

const SOURCE_PASTO := 5     # los IDs que imprime tu _ready()
const SOURCE_CAMINO := 0    # pon aquí el ID real del camino

func _ready():
	_generar_tablero()
	_generar_camino()
	_generar_curva()
	_crear_espiritu()
	
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
			suelo.set_cell(celda, 5, coords_atlas)   # cambia el 0 si tu source tiene otro ID

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

func _crear_espiritu():
	var seguidor := PathFollow2D.new()
	seguidor.loop = false
	seguidor.rotates = false
	ruta.add_child(seguidor)

	var espiritu = espiritu_escena.instantiate()
	seguidor.add_child(espiritu)
	espiritu.llego_a_meta.connect(_on_espiritu_llego)

func _on_espiritu_llego():
	print("¡Un espíritu llegó al árbol meta!")

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
