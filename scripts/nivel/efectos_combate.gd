extends Node2D

# Cantidades máximas por emisor, separadas para no silenciar el clima en un tablero lleno.
const PRESUPUESTO_COMBATE := 160
const PRESUPUESTO_CLIMA := 96
const RECETAS := {
	"ascuas": [4, 0.23, "#ffbf65", "#af401c", Vector2(0, -32), 55.0, 1.0],
	"flamma": [20, 0.46, "#fff3b2", "#ee5d29", Vector2(0, 175), 180.0, 2.1],
	"glacies": [9, 0.38, "#e4faff", "#4cb4e7", Vector2(0, 155), 128.0, 1.5],
	"electricitas": [7, 0.23, "#f5f8ff", "#978cff", Vector2.ZERO, 228.0, 1.2],
	"geiser": [18, 0.73, "#dceeed", "#889f9c", Vector2(0, -36), 120.0, 3.6],
	"erupcion": [42, 0.78, "#fff0a1", "#ce491a", Vector2(0, 450), 305.0, 2.6],
	"ventisca": [66, 0.92, "#f2fcff", "#88bfd5", Vector2(370, 70), 280.0, 1.2],
	"rayo": [24, 0.41, "#f6f7ff", "#9381ff", Vector2(0, 90), 235.0, 1.7],
}

var _libres: Dictionary = {}
var _activos: Array[Dictionary] = []
var _estelas: Dictionary = {}
var _rayos: Array[Dictionary] = []
var _reloj := 0.0
var _textura: Texture2D
var _grafico := false
var pico_combate := 0
var pico_clima := 0

func _ready():
	name = "EfectosCombate"
	_grafico = DisplayServer.get_name() != "headless"
	if not _grafico:
		set_process(false)
		return
	var imagen := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	for y in range(7):
		for x in range(7):
			var distancia := absf(x - 3) + absf(y - 3) * 0.65
			if distancia <= 3.8:
				imagen.set_pixel(x, y, Color(1, 1, 1, 1.0 if distancia <= 2.6 else 0.6))
	_textura = ImageTexture.create_from_image(imagen)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func seguir(bala: Node2D):
	if _grafico:
		_estelas[bala.get_instance_id()] = {"bala": weakref(bala), "proximo": _reloj + 0.035}

func emitir(tipo: String, punto: Vector2, clima := false, area := Vector2.ZERO):
	if not _grafico:
		return
	var datos: Array = RECETAS[tipo]
	var cantidad: int = datos[0]
	var usados := _usados(clima)
	var presupuesto := PRESUPUESTO_CLIMA if clima else PRESUPUESTO_COMBATE
	# Guardar espacio para los impactos incluso si todas las torres son Flamma.
	if tipo == "ascuas":
		presupuesto -= 48
	elif tipo == "flamma" and usados + cantidad > presupuesto:
		for i in range(_activos.size() - 1, -1, -1):
			if _activos[i].tipo in ["ascuas", "electricitas"]:
				usados -= _activos[i].emisor.amount
				_liberar(i)
			if usados + cantidad <= presupuesto:
				break
	if usados + cantidad > presupuesto:
		return
	var libres: Array = _libres.get_or_add(tipo, [])
	var emisor: GPUParticles2D = _crear(tipo, datos) if libres.is_empty() else libres.pop_back()
	emisor.position = to_local(punto)
	emisor.visibility_rect = Rect2(-area - Vector2(320, 420), (area + Vector2(320, 420)) * 2.0)
	var material := emisor.process_material as ParticleProcessMaterial
	if tipo == "ventisca":
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		material.emission_box_extents = Vector3(area.x, area.y, 1)
	emisor.speed_scale = 1.0 / Engine.time_scale
	emisor.show()
	emisor.restart()
	var fin := _reloj + (2.0 - emisor.explosiveness) * emisor.lifetime + 0.06
	_activos.append({"emisor": emisor, "tipo": tipo, "fin": fin, "clima": clima})
	if clima:
		pico_clima = maxi(pico_clima, usados + cantidad)
	else:
		pico_combate = maxi(pico_combate, usados + cantidad)
	if tipo == "rayo":
		_rayos.append({"pos": emisor.position, "fin": _reloj + 0.17})
		queue_redraw()

func _usados(clima: bool) -> int:
	var total := 0
	for ficha in _activos:
		if ficha.clima == clima:
			total += ficha.emisor.amount
	return total

func _crear(tipo: String, datos: Array) -> GPUParticles2D:
	var emisor := GPUParticles2D.new()
	emisor.name = tipo
	emisor.emitting = false
	emisor.texture = _textura
	emisor.amount = datos[0]
	emisor.lifetime = datos[1]
	emisor.one_shot = true
	emisor.local_coords = false
	emisor.explosiveness = 0.86
	var material := ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.gravity = Vector3(datos[4].x, datos[4].y, 0)
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	match tipo:
		"geiser":
			material.spread = 21.0
			emisor.explosiveness = 0.44
		"erupcion": material.spread = 47.0
		"ventisca":
			material.direction = Vector3(1, 0.26, 0)
			material.spread = 14.0
			emisor.explosiveness = 0.44
		"ascuas": material.spread = 45.0
	material.initial_velocity_min = datos[5] * 0.36
	material.initial_velocity_max = datos[5]
	material.scale_min = datos[6] * 0.45
	material.scale_max = datos[6]
	material.angle_min = -180.0
	material.angle_max = 180.0
	var colores := Gradient.new()
	colores.offsets = PackedFloat32Array([0.0, 0.39, 1.0])
	var borde := Color(datos[3])
	colores.colors = PackedColorArray([Color(datos[2]), Color(borde, 0.75), Color(borde, 0)])
	var rampa := GradientTexture1D.new()
	rampa.gradient = colores
	material.color_ramp = rampa
	emisor.process_material = material
	add_child(emisor)
	return emisor

func _process(delta: float):
	_reloj += delta / Engine.time_scale
	for i in range(_activos.size() - 1, -1, -1):
		var ficha := _activos[i]
		if ficha.fin <= _reloj:
			_liberar(i)
		else:
			ficha.emisor.speed_scale = 1.0 / Engine.time_scale
	for id in _estelas.keys():
		var ficha: Dictionary = _estelas[id]
		var bala: Node2D = ficha.bala.get_ref()
		if not is_instance_valid(bala) or bala.is_queued_for_deletion():
			_estelas.erase(id)
		elif _reloj >= ficha.proximo:
			emitir("ascuas", bala.global_position)
			ficha.proximo = _reloj + 0.05
	if not _rayos.is_empty():
		_rayos = _rayos.filter(func(rayo): return rayo.fin > _reloj)
		queue_redraw()

func _notification(what: int):
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		for ficha in _activos:
			ficha.emisor.speed_scale = 0.0 if what == NOTIFICATION_PAUSED else 1.0 / Engine.time_scale

func _liberar(indice: int):
	var ficha := _activos[indice]
	ficha.emisor.emitting = false
	ficha.emisor.hide()
	_libres[ficha.tipo].append(ficha.emisor)
	_activos.remove_at(indice)

func cerrar_clima():
	for i in range(_activos.size() - 1, -1, -1):
		if _activos[i].clima:
			_liberar(i)
	_rayos.clear()
	queue_redraw()

func _draw():
	for rayo in _rayos:
		var punto: Vector2 = rayo.pos
		var opacidad := clampf((rayo.fin - _reloj) / 0.17, 0.0, 1.0)
		var trazo := PackedVector2Array([
			punto + Vector2(-48, -235), punto + Vector2(-11, -145),
			punto + Vector2(-24, -118), punto + Vector2(11, -56), punto])
		draw_polyline(trazo, Color(0.49, 0.55, 0.95, opacidad * 0.65), 9.0, true)
		draw_polyline(trazo, Color(0.89, 0.95, 1.0, opacidad), 3.0, true)
