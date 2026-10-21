extends CanvasLayer

signal semilla_pulsada(indice: int, arrastre: bool)
signal ataque_pulsado(indice: int, arrastre: bool)

const SEMILLAS := [
	{"nombre": "Natura", "costo": 1},
	{"nombre": "Flamma", "costo": 3},
	{"nombre": "Aqua", "costo": 6},
	{"nombre": "Terra", "costo": 3},
	{"nombre": "Electricitas", "costo": 2},
	{"nombre": "Glacies", "costo": 3},
	{"nombre": "Venenum", "costo": 10},
]

const ATAQUES := [
	{"nombre": "Natura", "dano": 10, "radio": 2.5, "capacidad": 2},
	{"nombre": "Flamma", "dano": 20, "radio": 2.5, "capacidad": 3},
	{"nombre": "Aqua", "dano": 30, "radio": 3.0, "capacidad": 2},
	{"nombre": "Terra", "dano": 50, "radio": 2.0, "capacidad": 2},
	{"nombre": "Electricitas", "dano": 40, "radio": 2.5, "capacidad": 2},
	{"nombre": "Glacies", "dano": 10, "radio": 4.0, "capacidad": 3},
	{"nombre": "Venenum", "dano": 100, "radio": 2.5, "capacidad": 2},
]

@onready var barra: PanelContainer = $Barra
@onready var fila_semillas: HBoxContainer = $Barra/Margen/Fila/Semillas
@onready var fila_ataques: HBoxContainer = $Barra/Margen/Fila/Ataques
@onready var label_gotas: Label = $Barra/Margen/Fila/Info/LabelGotas
@onready var label_ronda: Label = $Barra/Margen/Fila/Info/LabelRonda
@onready var label_vida: Label = $Barra/Margen/Fila/Info/LabelVida

var botones_semilla: Array[Button] = []
var botones_ataque: Array[Button] = []

func _ready():
	for l in [label_gotas, label_ronda, label_vida]:
		l.add_theme_font_size_override("font_size", 26)

	for i in SEMILLAS.size():
		var costo: int = SEMILLAS[i].costo
		var b := _crear_boton("%s\n%d gota%s" % [SEMILLAS[i].nombre, costo, "" if costo == 1 else "s"])
		b.button_down.connect(func(): semilla_pulsada.emit(i, true))
		fila_semillas.add_child(b)
		botones_semilla.append(b)

	for i in ATAQUES.size():
		var b := _crear_boton("")
		b.button_down.connect(func(): ataque_pulsado.emit(i, true))
		fila_ataques.add_child(b)
		botones_ataque.append(b)
		actualizar_ataque(i, ATAQUES[i].capacidad, ATAQUES[i].capacidad)

func _crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 88)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.text = texto
	return b

# --- API para nivel.gd ---
func actualizar_gotas(n: int):
	label_gotas.text = "Gotas: %d" % n
	for i in botones_semilla.size():
		botones_semilla[i].disabled = SEMILLAS[i].costo > n

func actualizar_ronda(actual: int, total: int):
	label_ronda.text = "%d/%d" % [actual, total]

func actualizar_vida(actual: int, maxima: int):
	label_vida.text = "Árbol madre: %d / %d" % [actual, maxima]

func actualizar_ataque(i: int, cargas: int, maxima: int):
	botones_ataque[i].text = "[%d] %s\n%d/%d" % [i + 1, ATAQUES[i].nombre, cargas, maxima]
	botones_ataque[i].disabled = cargas <= 0

func resaltar(tipo: String, indice: int):
	for i in botones_semilla.size():
		botones_semilla[i].modulate = Color(1.4, 1.4, 0.8) if tipo == "semilla" and i == indice else Color.WHITE
	for i in botones_ataque.size():
		botones_ataque[i].modulate = Color(1.4, 1.4, 0.8) if tipo == "ataque" and i == indice else Color.WHITE

func punto_sobre_hud(p: Vector2) -> bool:
	return barra.get_global_rect().has_point(p)

# Teclas 1..7 seleccionan el ataque correspondiente
func _unhandled_key_input(event):
	if event.pressed and not event.echo:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < ATAQUES.size():
			ataque_pulsado.emit(i, false)
