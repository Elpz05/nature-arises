extends "res://demo/mecanicas_lluvia.gd"

func _configurar_nivel():
	super._configurar_nivel()
	puntos_ruta = [
		Vector2i(4, 3), Vector2i(4, 15), Vector2i(8, 15), Vector2i(8, 3),
		Vector2i(12, 3), Vector2i(12, 15), Vector2i(16, 15), Vector2i(16, 3),
		Vector2i(20, 3), Vector2i(20, 15), Vector2i(24, 15), Vector2i(24, 4), Vector2i(25, 4),
	]
	celda_arbol_madre = Vector2i(26, 4)
	rutas_adicionales = []
