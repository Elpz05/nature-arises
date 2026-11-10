extends Node2D

# Paletas de suelo, sombra, luz, borde de camino, piso de camino y adoquín.
const PALETAS := {
	"volcan": ["#362b36", "#231e29", "#60404a", "#1e1b25", "#6d5054", "#88645e"],
	"ventisca": ["#a3b9c4", "#748f9f", "#d6e3e2", "#4b687b", "#7b99a9", "#a1b7bf"],
	"tormenta": ["#3b4c57", "#273845", "#65747a", "#20313e", "#536972", "#6b8186"],
}
const DIRECCIONES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const FIGURAS := {
	"volcan": {
		"basalto": [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 9), Vector2i(28, 5),
			Vector2i(29, 6), Vector2i(28, 7), Vector2i(29, 8), Vector2i(27, 9), Vector2i(28, 10),
			Vector2i(13, 11), Vector2i(14, 11), Vector2i(14, 12), Vector2i(15, 12)],
		"grieta": [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(5, 8), Vector2i(6, 8),
			Vector2i(7, 9), Vector2i(10, 12), Vector2i(11, 12), Vector2i(20, 6), Vector2i(21, 6), Vector2i(22, 6)],
	},
	"ventisca": {
		"abeto": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(1, 4),
			Vector2i(2, 5), Vector2i(3, 5), Vector2i(1, 6), Vector2i(2, 6), Vector2i(0, 7),
			Vector2i(27, 3), Vector2i(28, 4), Vector2i(29, 4), Vector2i(28, 5)],
		"hielo": [Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7), Vector2i(9, 8), Vector2i(10, 8),
			Vector2i(11, 8), Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 10),
			Vector2i(17, 10), Vector2i(18, 10), Vector2i(18, 11), Vector2i(19, 11)],
		"farol": [Vector2i(23, 5), Vector2i(25, 3), Vector2i(26, 3), Vector2i(26, 5), Vector2i(27, 4)],
	},
	"tormenta": {
		"cresta": [Vector2i(28, 3), Vector2i(29, 3), Vector2i(28, 4), Vector2i(29, 5),
			Vector2i(28, 6), Vector2i(29, 7), Vector2i(28, 8), Vector2i(29, 9), Vector2i(28, 10)],
		"charco": [Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(11, 9),
			Vector2i(18, 11), Vector2i(19, 11), Vector2i(19, 12), Vector2i(20, 12)],
		"junco": [Vector2i(1, 6), Vector2i(2, 6), Vector2i(1, 7), Vector2i(2, 8),
			Vector2i(8, 5), Vector2i(6, 6), Vector2i(17, 11), Vector2i(21, 12), Vector2i(22, 12)],
	},
}

var nivel
var _paleta: Array[Color] = []
var _ruta: Dictionary = {}
var _atajos: Dictionary = {}
var _reservadas: Dictionary = {}
var _atmosfera: Node2D
var _pulso := 0.0
var _proximo_brillo := 0.0

func _ready():
	name = "DecoracionBioma"
	for tono in PALETAS[nivel.clima]:
		_paleta.append(Color(tono))
	_conectar(nivel._celdas_de(nivel.puntos_ruta), _ruta)
	for datos in nivel._atajos.values():
		_conectar(datos.tramo, _atajos)
	var reservas: Array = [nivel.celda_arbol_madre, nivel.celda_pozo]
	reservas.append_array(nivel.parcelas_secano)
	reservas.append_array(nivel.puestos_terra)
	reservas.append_array(nivel.celdas_inundadas)
	reservas.append_array(nivel.celdas_geiser)
	for celda in reservas:
		_reservadas[celda] = true
	_atmosfera = Node2D.new()
	_atmosfera.name = "Atmosfera"
	_atmosfera.draw.connect(_dibujar_atmosfera.bind(_atmosfera))
	add_child(_atmosfera)

func _process(delta: float):
	_pulso += delta / Engine.time_scale
	if _pulso >= _proximo_brillo:
		_proximo_brillo = _pulso + 0.05
		_atmosfera.queue_redraw()

func _dibujar_atmosfera(lienzo: Node2D):
	# Detalle ambiental al borde del tablero, fuera de la lectura de combate.
	var ancla := _centro(Vector2i(28, 15))
	var tono := Color("#c17545") if nivel.clima == "volcan" else Color("#9bc9cc")
	for i in range(18):
		var avance := fposmod(i * 0.19 + _pulso * 0.14, 1.0)
		var lado := Vector2(-((i * 71) % 570), ((i * 17) % 45) - avance * 26.0)
		if nivel.clima == "tormenta":
			lado.x *= 0.58
			lado.y += avance * 32.0
		var punto := (ancla + lado).snapped(Vector2.ONE * 3.0)
		lienzo.draw_rect(Rect2(punto, Vector2(6, 3)), Color(tono, sin(avance * PI) * 0.22))

func _conectar(celdas: Array, mapa: Dictionary):
	for i in celdas.size():
		var celda: Vector2i = celdas[i]
		var conexiones: int = mapa.get(celda, 0)
		if i > 0:
			conexiones |= 1 << DIRECCIONES.find(celdas[i - 1] - celda)
		if i + 1 < celdas.size():
			conexiones |= 1 << DIRECCIONES.find(celdas[i + 1] - celda)
		mapa[celda] = conexiones

func _centro(celda: Vector2i) -> Vector2:
	return to_local(nivel.suelo.to_global(nivel.suelo.map_to_local(celda)))

func _mezcla(celda: Vector2i, sal := 0) -> int:
	var base: int = celda.x * 151 + celda.y * 293 + sal * 37 + nivel.numero_nivel * 17
	return ((base ^ (base << 5)) * 1741) & 65535

func _draw():
	for y in range(nivel.FILAS_BLOQUEADAS, nivel.ALTO):
		for x in range(nivel.ANCHO):
			_suelo(Vector2i(x, y))
	_relieve()
	_camino(_atajos, Color("#34313b"), Color("#725548"), Color("#97725a"), 16.0)
	_camino(_ruta, _paleta[3], _paleta[4], _paleta[5], 23.0)
	for tipo in FIGURAS[nivel.clima]:
		for celda in FIGURAS[nivel.clima][tipo]:
			if not _reservadas.has(celda) and not _ruta.has(celda) and not _atajos.has(celda):
				_figura(tipo, _centro(celda), _mezcla(celda))
	for celda in nivel.celdas_geiser:
		_ventila(_centro(celda))
	var origen := _centro(Vector2i(0, nivel.FILAS_BLOQUEADAS)) - Vector2.ONE * 32
	var ancho: float = nivel.ANCHO * 64
	var alto: float = (nivel.ALTO - nivel.FILAS_BLOQUEADAS) * 64
	var canto := Color(_paleta[1], 0.82)
	draw_rect(Rect2(origen + Vector2(0, alto - 5), Vector2(ancho, 5)), canto)
	draw_rect(Rect2(origen + Vector2(ancho - 5, 0), Vector2(5, alto)), canto)

func _suelo(celda: Vector2i):
	var esquina := _centro(celda) - Vector2.ONE * 32
	var variante := _mezcla(celda) % 6
	var banda := clampf((sin(celda.x * 0.38 + celda.y * 0.27) + 1.0) * 0.12, 0.0, 0.24)
	var base := _paleta[0].lerp(_paleta[1], banda)
	base = base.lerp(_paleta[2], variante * 0.023)
	draw_rect(Rect2(esquina, Vector2.ONE * 64), base)
	var cota := Color(_paleta[1], 0.33)
	var brizna := Color(_paleta[2], 0.36)
	for i in range(4):
		var marca := _mezcla(celda, i + 1)
		var punto := esquina + Vector2(4 + 4 * (marca % 13), 4 + 4 * ((marca >> 4) % 13))
		draw_rect(Rect2(punto, Vector2(4 + 4 * ((marca >> 9) % 3), 4)), cota if i % 2 == 0 else brizna)
	if variante == 1 and not _reservadas.has(celda):
		_faceta(esquina + Vector2(35, 40), [Vector2(-19, 2), Vector2(0, -9), Vector2(16, -7),
			Vector2(23, 4), Vector2(10, 10), Vector2(-13, 10)], Color(_paleta[2], 0.13))

func _camino(mapa: Dictionary, borde: Color, piso: Color, losa: Color, radio: float):
	# Dos pasadas para que los brazos se unan sin líneas oscuras en cada casilla.
	for celda in mapa:
		_tramo(_centro(celda), mapa[celda], radio + 4.0, borde)
	for celda in mapa:
		var punto := _centro(celda)
		_tramo(punto, mapa[celda], radio, piso)
	for celda in mapa:
		var punto := _centro(celda)
		var variante := _mezcla(celda)
		var offset := Vector2(-12, -12) + Vector2(variante % 4, (variante >> 4) % 4) * 6
		draw_rect(Rect2(punto + offset, Vector2(7 + 4 * (variante % 4), 4)), Color(losa, 0.56))
		if variante % 3 == 0:
			draw_rect(Rect2(punto + Vector2(2, 10), Vector2(10, 4)), Color(borde, 0.28))

func _relieve():
	# Masas grandes, compuestas en el perímetro para romper las repeticiones de celdas.
	var ancla := _centro(Vector2i(29, 16)) + Vector2(30, 30)
	var vertiente := [Vector2(-1070, 0), Vector2(-1000, -24), Vector2(-916, -19),
		Vector2(-812, -51), Vector2(-704, -42), Vector2(-610, -92), Vector2(-461, -85),
		Vector2(-371, -139), Vector2(-255, -111), Vector2(-155, -173), Vector2(0, -166), Vector2.ZERO]
	_faceta(ancla, vertiente, _paleta[0].lerp(_paleta[1], 0.65))
	var falda := [Vector2(-895, 0), Vector2(-764, -29), Vector2(-629, -17), Vector2(-554, -52),
		Vector2(-398, -42), Vector2(-307, -94), Vector2(-234, -74), Vector2(-138, -115),
		Vector2(0, -127), Vector2.ZERO]
	_faceta(ancla, falda, _paleta[1])
	var estrato := PackedVector2Array([
		ancla + Vector2(-768, -12), ancla + Vector2(-617, -8), ancla + Vector2(-552, -39),
		ancla + Vector2(-401, -28), ancla + Vector2(-316, -75), ancla + Vector2(-240, -60),
		ancla + Vector2(-137, -99), ancla + Vector2(0, -105)])
	var ribete := Color("#9d513b") if nivel.clima == "volcan" else _paleta[2].lerp(_paleta[1], 0.37)
	draw_polyline(estrato, Color(ribete, 0.63), 5.0)

func _tramo(punto: Vector2, conexiones: int, ancho: float, color: Color):
	draw_rect(Rect2(punto - Vector2.ONE * ancho, Vector2.ONE * ancho * 2.0), color)
	for i in DIRECCIONES.size():
		if (conexiones & (1 << i)) != 0:
			var dir := Vector2(DIRECCIONES[i])
			var medida := Vector2(32.0, ancho * 2) if dir.x != 0 else Vector2(ancho * 2, 32.0)
			draw_rect(Rect2(punto + dir * 16.0 - medida * 0.5, medida), color)

func _faceta(centro: Vector2, offsets: Array, color: Color):
	var puntos := PackedVector2Array()
	for offset: Vector2 in offsets:
		puntos.append(centro + offset)
	draw_colored_polygon(puntos, color)

func _figura(tipo: String, punto: Vector2, variante: int):
	match tipo:
		"basalto", "cresta":
			var altura := 31 + 4 * (variante % 5)
			_faceta(punto, [Vector2(-30, 24), Vector2(-27, 8), Vector2(-13, 1), Vector2(-10, -altura + 19),
				Vector2(6, -altura + 19), Vector2(13, -4), Vector2(25, -11), Vector2(31, 21), Vector2(20, 27)], _paleta[1])
			_faceta(punto, [Vector2(-10, -altura + 19), Vector2(6, -altura + 19),
				Vector2(9, -1), Vector2(3, 20), Vector2(-10, 18)], _paleta[2].lerp(_paleta[1], 0.35))
			draw_rect(Rect2(punto + Vector2(-25, 16), Vector2(9, 4)), _paleta[2].darkened(0.15))
		"grieta":
			var zig := PackedVector2Array([punto + Vector2(-31, 12), punto + Vector2(-15, 5), punto + Vector2(-9, -8),
				punto + Vector2(3, 0), punto + Vector2(13, -3), punto + Vector2(30, 9)])
			draw_polyline(zig, Color("#261e28"), 13)
			draw_polyline(zig, Color("#ab5539"), 5)
			draw_rect(Rect2(punto + Vector2(-11, -8), Vector2(5, 5)), Color("#d98651"))
		"abeto":
			_faceta(punto, [Vector2(-29, 23), Vector2(-8, 15), Vector2(24, 20), Vector2(29, 27), Vector2(-17, 29)], Color("#6e8794"))
			draw_rect(Rect2(punto + Vector2(-4, 1), Vector2(8, 24)), Color("#505867"))
			var copa := Color("#344c5b").lerp(Color("#426169"), (variante % 5) * 0.18)
			for i in range(3):
				var cima := -30.0 + i * 12.0 + float(variante % 3)
				var radio := 11.0 + i * 5.0
				_faceta(punto, [Vector2(0, cima), Vector2(radio, cima + 23), Vector2(-radio, cima + 23)], copa.lightened(i * 0.044))
				draw_rect(Rect2(punto + Vector2(-5 - i * 2, cima + 12), Vector2(13 + i * 3, 4)), Color("#a6c3ca"))
		"hielo", "charco":
			var escarcha := tipo == "hielo"
			var relleno := Color("#7399b1") if escarcha else Color("#263c49")
			var ribete := Color("#d2edf1") if escarcha else Color("#6e929b")
			_faceta(punto, [Vector2(-31, 5), Vector2(-19, -17), Vector2(14, -22),
				Vector2(30, -6), Vector2(28, 17), Vector2(4, 25), Vector2(-23, 19)], relleno)
			var grieta := PackedVector2Array([punto + Vector2(-23, 6), punto + Vector2(-5, -5),
				punto + Vector2(9, 3), punto + Vector2(24, -8)])
			draw_polyline(grieta, Color(ribete, 0.67), 3)
			draw_rect(Rect2(punto + Vector2(3, 12), Vector2(13, 3)), Color(ribete, 0.44))
		"junco":
			_faceta(punto, [Vector2(-24, 19), Vector2(-10, 8), Vector2(23, 14), Vector2(22, 25), Vector2(-16, 25)], Color("#304650"))
			for i in range(5):
				var pie := punto + Vector2(-14 + i * 5, 19)
				var rama := PackedVector2Array([pie, pie + Vector2(2, -17), pie + Vector2(8, -23 - (variante >> i) % 9)])
				draw_polyline(rama, Color("#84927d") if i % 2 == 0 else Color("#556d65"), 3)
		"farol":
			draw_rect(Rect2(punto - Vector2(19, 19), Vector2(38, 38)), Color("#f5c88835"))
			draw_rect(Rect2(punto + Vector2(-5, -4), Vector2(10, 27)), Color("#485a64"))
			draw_rect(Rect2(punto + Vector2(-10, -16), Vector2(20, 16)), Color("#4a4e5d"))
			draw_rect(Rect2(punto + Vector2(-6, -13), Vector2(12, 9)), Color("#ffdd9a"))
			draw_rect(Rect2(punto + Vector2(-12, -20), Vector2(24, 5)), Color("#d4e0df"))

func _ventila(punto: Vector2):
	var anillo := [Vector2(-28, -10), Vector2(-17, -23), Vector2(15, -23), Vector2(27, -10),
		Vector2(27, 12), Vector2(15, 22), Vector2(-17, 22), Vector2(-28, 12)]
	_faceta(punto, anillo, Color("#8e635c"))
	var interior: Array = anillo.map(func(p): return p * 0.78)
	_faceta(punto, interior, Color("#372631"))
	draw_rect(Rect2(punto + Vector2(-17, -22), Vector2(25, 4)), Color("#b58067"))
