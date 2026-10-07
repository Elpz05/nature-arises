extends Node2D

@onready var suelo: TileMapLayer = $Suelo
@onready var camino: TileMapLayer = $Camino

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

func _ready():
	_generar_tablero()
	_generar_camino()
	
	for i in suelo.tile_set.get_source_count():
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
			camino.set_cell(celda, 0, Vector2i(0, 0))
			celdas_ocupadas[celda] = true
			celda += paso

		# La última celda del tramo (la esquina)
		var extra := Vector2i(0, 1) if paso.x != 0 else Vector2i(1, 0)
		camino.set_cell(hasta, 1, Vector2i(0, 0))
		celdas_ocupadas[hasta] = true

	print("Celdas de camino: ", celdas_ocupadas.size())
	print("Celdas en la capa: ", camino.get_used_cells().size())
	print("TileSet: ", camino.tile_set)
	if camino.tile_set:
		print("Sources: ", camino.tile_set.get_source_count())
		print("ID del source 0: ", camino.tile_set.get_source_id(0))
