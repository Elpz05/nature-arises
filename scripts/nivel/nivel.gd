extends "res://scripts/nivel/nivel_base.gd"

const CELDA_ARBOL_MADRE := Vector2i(25, 14)
const RUTA := [
	Vector2i(0, 3), Vector2i(5, 3), Vector2i(5, 12), Vector2i(10, 12),
	Vector2i(10, 3), Vector2i(15, 3), Vector2i(15, 12), Vector2i(20, 12),
	Vector2i(20, 3), Vector2i(25, 3), Vector2i(25, 13),
]
func _configurar_nivel() -> void:
	puntos_ruta = RUTA
	celda_arbol_madre = CELDA_ARBOL_MADRE
	preload("res://scripts/nivel/campana.gd").configurar_progreso(self, 0)
	musica_nivel = preload("res://audios/nivel_musica/Forest 03.ogg")
