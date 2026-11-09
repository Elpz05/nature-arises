extends RefCounted

static func bestia(escena: PackedScene, tamano: String) -> Dictionary:
	if escena == null:
		return {}
	var unidad := escena.instantiate()
	var sprite := unidad.get_node("Sprite2D") as Sprite2D
	var textura: Texture2D = unidad.get("textura_" + tamano)
	var retrato := {"textura": textura if textura != null else sprite.texture, "tinte": sprite.modulate * sprite.self_modulate}
	unidad.free()
	return retrato

static func arbol(escena: PackedScene, animacion: StringName, ajustar := false) -> Dictionary:
	var unidad := escena.instantiate()
	var sprite := unidad.get_node("Arbol") as AnimatedSprite2D
	var textura := sprite.sprite_frames.get_frame_texture(animacion, 0)
	if ajustar and textura != null:
		var imagen := textura.get_image()
		if imagen != null and not imagen.is_empty():
			var recorte := imagen.get_used_rect()
			if recorte.has_area():
				var limites := Rect2i(Vector2i.ZERO, imagen.get_size())
				textura = ImageTexture.create_from_image(imagen.get_region(recorte.grow(1).intersection(limites)))
	var retrato := {"textura": textura, "tinte": sprite.modulate * sprite.self_modulate}
	unidad.free()
	return retrato

static func crear(retrato: Dictionary, lado: float) -> TextureRect:
	var imagen := TextureRect.new()
	imagen.texture = retrato.get("textura")
	imagen.self_modulate = retrato.get("tinte", Color.WHITE)
	imagen.custom_minimum_size = Vector2.ONE * lado
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return imagen
