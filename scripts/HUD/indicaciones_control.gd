extends RefCounted

static func icono(accion: String) -> ControllerIconTexture:
	if DisplayServer.get_name() == "headless":
		return null
	var recurso := ControllerIconTexture.new()
	recurso.path = accion
	return recurso

static func pista(fila: Container, accion: String, texto: String, tamano: int) -> ControllerIconTexture:
	var recurso := icono(accion)
	if recurso != null:
		var imagen := TextureRect.new()
		imagen.texture = recurso
		imagen.custom_minimum_size = Vector2(44, 40)
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(imagen)
		if texto.is_empty():
			return recurso
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.text = texto if recurso != null else "[%s] %s" % [ControlesManager.etiqueta_accion(accion), texto]
	fila.add_child(etiqueta)
	return recurso
