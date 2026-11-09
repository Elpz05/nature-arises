extends Node2D

const DURACION := 0.72
const INTERVALO_PERIODICO := 0.45
const VENTANA_IMPACTOS := 0.13
const LIMITE_IMPACTOS := 48

var activo := true
var tablero: Rect2
var impactos: Array[Dictionary] = []
var _periodicos := {}
var _secuencia := 0

func _ready():
	z_index = 16
	set_process(false)

func establecer_activo(valor: bool):
	activo = valor
	if not activo:
		limpiar()

func registrar(cantidad: float, periodico: bool, unidad: Node2D, aliada: bool):
	if not activo or cantidad <= 0.0:
		return
	var punto := to_local(unidad.global_position)
	var id := unidad.get_instance_id()
	if not periodico:
		_mostrar(cantidad, punto, id, aliada)
	else:
		if not _periodicos.has(id):
			_periodicos[id] = {"cantidad": 0.0, "restante": INTERVALO_PERIODICO, "aliada": aliada}
		var pendiente: Dictionary = _periodicos[id]
		pendiente.cantidad += cantidad
		pendiente.punto = punto
	set_process(true)

func _mostrar(cantidad: float, punto: Vector2, id: int, aliada: bool):
	for i in range(impactos.size() - 1, -1, -1):
		var anterior := impactos[i]
		if anterior.id != id:
			continue
		if anterior.edad < VENTANA_IMPACTOS:
			anterior.cantidad += cantidad
			anterior.texto = _formato(anterior.cantidad)
			queue_redraw()
			return
		impactos.remove_at(i)
		break
	if impactos.size() >= LIMITE_IMPACTOS:
		impactos.pop_front()
	# Alterna el desplazamiento sin alterar el azar del combate.
	var lateral := float((_secuencia % 3) - 1) * 10.0
	_secuencia += 1
	impactos.append({
		"id": id, "cantidad": cantidad, "texto": _formato(cantidad),
		"punto": punto + Vector2(lateral, 11.0 if aliada else 4.0),
		"subida": 12.0 if aliada else 36.0,
		"color": Color("#ff9e86") if aliada else Color("#fff1ae"), "edad": 0.0,
	})
	queue_redraw()

func _formato(cantidad: float) -> String:
	return "−" + String.num(cantidad, 1).trim_suffix(".0") if cantidad >= 0.05 else "<0.1"

func _process(delta: float):
	for i in range(impactos.size() - 1, -1, -1):
		impactos[i].edad += delta
		if impactos[i].edad >= DURACION:
			impactos.remove_at(i)
	for id in _periodicos.keys():
		var pendiente: Dictionary = _periodicos[id]
		pendiente.restante -= delta
		if pendiente.restante <= 0.0:
			_mostrar(pendiente.cantidad, pendiente.punto, id, pendiente.aliada)
			_periodicos.erase(id)
	queue_redraw()
	if impactos.is_empty() and _periodicos.is_empty():
		set_process(false)

func _draw():
	var fuente := ThemeDB.fallback_font
	for impacto in impactos:
		var fraccion := clampf(float(impacto.edad) / DURACION, 0.0, 1.0)
		var alpha := 1.0 - smoothstep(0.4, 1.0, fraccion)
		var punto: Vector2 = impacto.punto - Vector2(0, fraccion * impacto.subida)
		var texto: String = impacto.texto
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		punto.x = clampf(punto.x - ancho / 2.0, tablero.position.x + 4.0, tablero.end.x - ancho - 4.0)
		punto.y = maxf(punto.y, tablero.position.y + 25.0)
		draw_string_outline(fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0.05, 0.04, 0.02, alpha))
		draw_string(fuente, punto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(impacto.color, alpha))

func limpiar():
	impactos.clear()
	_periodicos.clear()
	set_process(false)
	queue_redraw()
