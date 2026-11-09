extends RefCounted

# Cada símbolo define color, nombre y trazos en un espacio de 16 × 16.
const ICONOS := {
	"candado": [Color("#cfceab"), "Bloqueado", [[-5,-1, 5,-1, 5,6, -5,6, -5,-1], [-3,-1, -3,-5, 0,-7, 3,-5, 3,-1], [0,2, 0,4]]],
	"pala": [Color("#e4d4af"), "Pala", [[3,-7, 6,-4, 3,-1, 0,-4, 3,-7], [2,-2, -2,2], [-1,0, 2,3, -3,7, -6,6, -7,3, -3,-1, -1,0]]],
	"escudo": [Color("#ffbd67"), "Escudo de Flamma", [[-5,-5, 5,-5, 5,0, 0,6, -5,0, -5,-5], [-2,0, 0,2, 3,-2]]],
	"proteccion_aqua": [Color("#91d8ff"), "Escudo de Aqua", [[-5,-5, 5,-5, 5,0, 0,6, -5,0, -5,-5], [-3,-1, -1,1, 1,-1, 3,1]]],
	"rayo": [Color("#ffe468"), "Aura eléctrica", [[1,-6, -4,1, 0,1, -1,6, 4,-1, 0,-1, 1,-6]]],
	"hielo": [Color("#a4eaff"), "Hielo", [[0,-6, 0,6], [-5,-3, 5,3], [-5,3, 5,-3]]],
	"veneno": [Color("#b4f59a"), "Toxicidad o veneno", [[0,-6, 5,1, 4,4, 0,6, -4,4, -5,1, 0,-6], [0,1, 0,3]]],
	"geiser": [Color("#ffad83"), "Bono de géiser", [[-4,2, 0,-2, 4,2], [-4,-2, 0,-6, 4,-2], [-5,6, 5,6]]],
	"divisor": [Color("#ffd76a"), "Natura divisor", [[0,-6, 6,0, 0,6, -6,0, 0,-6], [0,-3, 0,3]]],
	"armadura": [Color("#e8d8c4"), "Armadura de Terra", [[-5,-5, 5,-5, 6,0, 0,6, -6,0, -5,-5], [-3,-1, 3,-1]]],
	"raiz": [Color("#e5e294"), "Inmovilización", [[0,-6, 0,4], [-5,-2, 0,2, 5,-2], [-4,5, 4,5]]],
	"confusion": [Color("#92d6ff"), "Confusión", [[-4,-3, -2,-6, 2,-6, 4,-3, 0,0, 0,1], [0,4, 0,6]]],
	"mareo": [Color("#ffc88d"), "Mareo", [[-5,-4, 4,-4, 0,0, 4,4, -5,4]]],
	"retroceso": [Color("#ffee8a"), "Marcha inversa", [[5,0, -5,0, -1,-4], [-5,0, -1,4]]],
	"fuego": [Color("#ff9679"), "Quemadura", [[-4,5, -6,1, -3,-3, -1,0, 1,-6, 5,-1, 6,2, 3,6, -4,5]]],
	"marca": [Color("#efb3ff"), "Vulnerabilidad", [[-5,-5, 5,-5, 5,5, -5,5, -5,-5], [0,-3, 0,3], [-3,0, 3,0]]],
	"lento": [Color("#d6dbef"), "Ralentización", [[-5,-5, 5,-5, -5,5, 5,5, -5,-5]]],
	"viento": [Color("#ccf8ed"), "Bendición Ventus", [[-6,-3, 2,-3, 4,-5], [-6,0, 6,0], [-6,3, 2,3, 4,5]]],
	"renace": [Color("#ffd7a8"), "Renacimiento", [[-5,-5, 0,-5, 0,-2, 5,-2, 5,3, 2,3, 2,6, -2,6, -2,3, -5,3, -5,-5]]],
	"prioridad": [Color("#f7d589"), "Prioridad", [[0,-7, 0,7], [-7,0, 7,0], [0,-5, 4,-4, 5,0, 4,4, 0,5, -4,4, -5,0, -4,-4, 0,-5]]],
	"hoja": [Color("#b4ee87"), "Natura", [[-6,6, -5,-1, -1,-5, 6,-6, 5,1, 1,5, -4,5], [-6,6, 2,-2]]],
	"gota": [Color("#86dcff"), "Poza de Aqua", [[0,-7, 6,1, 5,5, 0,7, -5,5, -6,1, 0,-7]]],
	"parcela": [Color("#f2d6a1"), "Parcela seca", [[-6,-6, 6,-6, 6,6, -6,6, -6,-6]]],
	"puesto_terra": [Color("#f2d6a1"), "Puesto de Terra", [[-4,-6, -4,6], [4,-6, 4,6]]],
	"entrada": [Color("#f7d589"), "Entrada de bestias", [[-6,6, -6,-3, 0,-6, 6,-3, 6,6], [-2,-2, -2,6], [2,-2, 2,6]]],
	"meta": [Color("#c3f695"), "Árbol Madre", [[0,7, 0,3], [-5,3, -2,-1, -4,-1, 0,-7, 4,-1, 2,-1, 5,3, -5,3]]],
}

const ELEMENTOS := ["hoja", "fuego", "gota", "puesto_terra", "rayo", "hielo", "veneno"]

static func dibujar(lienzo: CanvasItem, id: String, centro: Vector2, escala := 1.0, medallon := true, destacado := false):
	var datos: Array = ICONOS[id]
	var color: Color = Color.WHITE if destacado else datos[0]
	if medallon:
		lienzo.draw_circle(centro, 8.3 * escala, Color("#102019"), true, -1.0, true)
		lienzo.draw_arc(centro, 7.7 * escala, 0.0, TAU, 20, Color(color, 0.8), escala, true)
	for trazo in datos[2]:
		var puntos := _puntos(trazo, centro, escala)
		if id == "gota" and destacado:
			lienzo.draw_colored_polygon(puntos, datos[0])
		lienzo.draw_polyline(puntos, color, clampf(1.55 * escala, 1.0, 4.0), true)

static func _puntos(trazo: Array, centro: Vector2, escala: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in range(0, trazo.size(), 2):
		puntos.append(centro + Vector2(trazo[i], trazo[i + 1]) * escala)
	return puntos

static func dibujar_vida(lienzo: CanvasItem, centro: Vector2, ancho: float, vida: float):
	var barra := Rect2(centro - Vector2(ancho / 2.0, 2.5), Vector2(ancho, 5.0))
	lienzo.draw_rect(barra.grow(1.0), Color("#0b1614"))
	lienzo.draw_rect(barra, Color("#53343a"))
	var color := Color("#f18877") if vida <= 0.25 else (Color("#f2bb6d") if vida <= 0.5 else Color("#a7e87a"))
	barra.size.x *= clampf(vida, 0.0, 1.0)
	lienzo.draw_rect(barra, color)

static func dibujar_fila(lienzo: CanvasItem, estados: Array[String], centro: Vector2, ancho: float, escarcha := 0):
	if estados.is_empty():
		return
	var paso := minf(20.0, ancho / estados.size())
	var inicio := centro.x - paso * (estados.size() - 1) / 2.0
	for i in estados.size():
		var posicion := Vector2(inicio + i * paso, centro.y)
		dibujar(lienzo, estados[i], posicion, minf(1.0, paso / 17.0))
		if estados[i] == "hielo" and escarcha > 0:
			for p in 3:
				var pip := posicion + Vector2((p - 1) * 5, 10)
				lienzo.draw_circle(pip, 2.5, Color("#102019"))
				lienzo.draw_circle(pip, 1.8, Color("#a4eaff") if p < escarcha else Color("#526b76"))
