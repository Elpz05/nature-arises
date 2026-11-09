extends "res://scripts/nivel/nivel_base.gd"

func _configurar_nivel():
	var catalogo = preload("res://scripts/nivel/campana.gd")
	catalogo.configurar_progreso(self, numero_nivel)
	var datos: Dictionary = catalogo.ETAPAS[numero_nivel]
	clima = datos.clima
	var vertical: bool = datos.get("vertical", false)
	puntos_ruta = catalogo.RUTA_VERTICAL.duplicate() if vertical else catalogo.RUTA_HORIZONTAL.duplicate()
	celda_arbol_madre = Vector2i(26, 4) if vertical else Vector2i(1, 15)
	rutas_adicionales = [catalogo.ATAJO_FLAMMA] if datos.get("atajo", false) else []
	if clima == "radiacion":
		rutas_adicionales.append(catalogo.ATAJO_ELECTRICITAS)
	intensidad_tormenta = "mediano"
	celdas_geiser.assign([Vector2i(6, 5), Vector2i(17, 8)] if clima == "volcan" else [])
