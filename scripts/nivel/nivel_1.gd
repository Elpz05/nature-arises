extends "res://scripts/nivel/nivel_base.gd"

const CELDA_ARBOL_MADRE := Vector2i(1, 15)
const RUTA := [
	Vector2i(0, 4), Vector2i(26, 4), Vector2i(26, 7), Vector2i(3, 7),
	Vector2i(3, 10), Vector2i(26, 10), Vector2i(26, 13), Vector2i(3, 13),
	Vector2i(3, 15), Vector2i(2, 15),
]
const RUTA_FUEGO := [
	Vector2i(0, 4), Vector2i(26, 4), Vector2i(26, 13), Vector2i(3, 13),
	Vector2i(3, 15), Vector2i(2, 15),
]
func _configurar_nivel() -> void:
	puntos_ruta = RUTA
	celda_arbol_madre = CELDA_ARBOL_MADRE
	preload("res://scripts/nivel/campana.gd").configurar_progreso(self, 1)
	# La capa Atajo pertenece a la escena de este nivel.
	rutas_adicionales = [
		{"tipo": "flamma", "puntos": RUTA_FUEGO, "capa": "Atajo"},
	]
