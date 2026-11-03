extends CanvasLayer

signal semilla_pulsada(indice: int, arrastre: bool)
signal ataque_pulsado(indice: int, arrastre: bool)
signal ronda_solicitada
signal pala_pulsada(arrastre: bool)

const SEMILLAS := [
	{"nombre": "Natura", "costo": 1, "costos": [1, 2, 3], "rol": "Disparo rápido a un objetivo."},
	{"nombre": "Flamma", "costo": 3, "costos": [3, 4, 5], "rol": "30 de daño en un radio de 1 celda. 0.8 disparos/s."},
	{"nombre": "Aqua", "costo": 6, "costos": [6, 8, 10], "rol": "10 de daño y 40% de lentitud durante 2 s. 1 disparo/s."},
	{"nombre": "Terra", "costo": 3, "costos": [3, 6, 9]},
	{"nombre": "Electricitas", "costo": 2, "costos": [2, 4, 8]},
	{"nombre": "Glacies", "costo": 3, "costos": [3, 5, 8]},
	{"nombre": "Venenum", "costo": 10, "costos": [10, 12, 14]},
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
@onready var panel_combate: PanelContainer = $PanelCombate
@onready var label_estado_combate: Label = $PanelCombate/Datos/LabelEstado
@onready var label_restantes: Label = $PanelCombate/Datos/LabelRestantes
@onready var label_entrantes: Label = $PanelCombate/Datos/LabelEntrantes
var ultimo_resumen: Dictionary = {}
var cargas_mostradas: Array[int] = []
var plantas_disponibles: Array[int] = []
var grupo_seleccion := "semilla"
var indice_seleccion := 0

var botones_semilla: Array[Button] = []
var botones_ataque: Array[Button] = []
var boton_ronda: Button
var boton_pala: Button

var SEMILLAS_ACTIVAS := [0]
var ATAQUES_ACTIVOS := [0]

func _ready():
	for l in [label_gotas, label_ronda, label_vida]:
		l.add_theme_font_size_override("font_size", 26)

	if Guardado.slot_actual >= 0:
		SEMILLAS_ACTIVAS = Guardado.plantas_activas()
		ATAQUES_ACTIVOS = Guardado.ataques_activos()
	
	for i in SEMILLAS.size():
		var costo: int = SEMILLAS[i].costo
		var b := _crear_boton("%s\n%d gota%s" % [SEMILLAS[i].nombre, costo, "" if costo == 1 else "s"])
		b.tooltip_text = SEMILLAS[i].get("rol", "")
		b.button_down.connect(func(): semilla_pulsada.emit(i, Input.is_action_pressed("Clic Izquierdo")))
		fila_semillas.add_child(b)
		botones_semilla.append(b)

	boton_pala = _crear_boton("Pala")
	boton_pala.button_down.connect(func(): pala_pulsada.emit(Input.is_action_pressed("Clic Izquierdo")))
	fila_semillas.add_child(boton_pala)

	for i in ATAQUES.size():
		var b := _crear_boton("")
		b.button_down.connect(func(): ataque_pulsado.emit(i, Input.is_action_pressed("Clic Izquierdo")))
		fila_ataques.add_child(b)
		botones_ataque.append(b)
		cargas_mostradas.append(ATAQUES[i].capacidad)
		actualizar_ataque(i, ATAQUES[i].capacidad, ATAQUES[i].capacidad)

	boton_ronda = Button.new()
	boton_ronda.custom_minimum_size = Vector2(0, 44)
	boton_ronda.focus_mode = Control.FOCUS_NONE
	boton_ronda.add_theme_font_size_override("font_size", 20)
	boton_ronda.pressed.connect(func(): ronda_solicitada.emit())
	label_ronda.get_parent().add_child(boton_ronda)
	ControlesManager.controles_cambiados.connect(actualizar_textos_controles)
	actualizar_textos_controles()

func _crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 88)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.text = texto
	return b

# --- API para nivel.gd ---
func actualizar_gotas(n: int):
	label_gotas.text = "Gotas: %d" % n
	for i in botones_semilla.size():
		botones_semilla[i].disabled = not SEMILLAS_ACTIVAS.has(i) or SEMILLAS[i].costo > n

func actualizar_ronda(actual: int, total: int):
	label_ronda.text = "Ronda %d/%d" % [actual, total]

func actualizar_vida(actual: int, maxima: int):
	label_vida.text = "Árbol madre: %d / %d" % [actual, maxima]

func actualizar_ataque(i: int, cargas: int, maxima: int):
	cargas_mostradas[i] = cargas
	botones_ataque[i].text = "[%s]\n%s\n%d/%d" % [ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre), ATAQUES[i].nombre, cargas, maxima]
	botones_ataque[i].disabled = not ATAQUES_ACTIVOS.has(i) or cargas <= 0

func mostrar_boton_ronda(texto: String, habilitado: bool):
	boton_ronda.text = texto
	boton_ronda.tooltip_text = ControlesManager.etiqueta_accion("Iniciar Ronda")
	boton_ronda.disabled = not habilitado

func resaltar(tipo: String, indice: int):
	if tipo in ["semilla", "ataque"]:
		grupo_seleccion = tipo
		indice_seleccion = indice
	for i in botones_semilla.size():
		botones_semilla[i].modulate = Color(1.4, 1.4, 0.8) if tipo == "semilla" and i == indice else Color.WHITE
	for i in botones_ataque.size():
		botones_ataque[i].modulate = Color(1.4, 1.4, 0.8) if tipo == "ataque" and i == indice else Color.WHITE
	boton_pala.modulate = Color(1.4, 1.4, 0.8) if tipo == "pala" else Color.WHITE

func punto_sobre_hud(p: Vector2) -> bool:
	return barra.get_global_rect().has_point(p) or panel_combate.get_global_rect().has_point(p)

func actualizar_combate(resumen: Dictionary):
	if resumen == ultimo_resumen:
		return
	ultimo_resumen = resumen.duplicate(true)
	label_estado_combate.text = resumen.estado
	label_restantes.text = "Restantes: %d\nEn camino: %d | Por aparecer: %d" % [resumen.restantes, resumen.activos, resumen.por_aparecer]
	var grupos: PackedStringArray = []
	var claves: Array = resumen.entrantes.keys()
	claves.sort()
	for clave in claves:
		var partes := String(clave).split(":")
		var tamano: String = {"pequeno": "pequeño", "mediano": "mediano", "grande": "grande"}.get(partes[1], partes[1])
		grupos.append("%s %s: %d" % [partes[0].capitalize(), tamano, resumen.entrantes[clave]])
	label_entrantes.text = "Entrantes:\n" + "\n".join(grupos) if not grupos.is_empty() else "Entrantes: ninguno"

# El nivel despacha estas acciones antes de confirmar una acción de tablero.
func manejar_accion(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("Pala", false, true):
		pala_pulsada.emit(false)
		return true
	if event.is_action_pressed("Iniciar Ronda", false, true):
		if not boton_ronda.disabled:
			ronda_solicitada.emit()
		return true
	for i in SEMILLAS.size():
		if event.is_action_pressed("Casilla Planta %d" % i, false, true):
			if SEMILLAS_ACTIVAS.has(i) and plantas_disponibles.has(i):
				semilla_pulsada.emit(i, false)
			return true
	for i in ATAQUES.size():
		if event.is_action_pressed("Elemento " + ATAQUES[i].nombre, false, true):
			if ATAQUES_ACTIVOS.has(i) and cargas_mostradas[i] > 0:
				ataque_pulsado.emit(i, false)
			return true
	if event.is_action_pressed("Alternar Elemento o Planta", false, true):
		seleccionar_grupo("ataque" if grupo_seleccion == "semilla" else "semilla")
		return true
	var paso := 0
	if event.is_action_pressed("Cambiar Casilla Izquierda", false, true):
		paso = -1
	elif event.is_action_pressed("Cambiar Casilla Derecha", false, true):
		paso = 1
	if paso != 0:
		var lista := _indices_seleccionables(grupo_seleccion)
		if not lista.is_empty():
			var actual := lista.find(indice_seleccion)
			_emitir_seleccion(grupo_seleccion, lista[posmod(actual + paso, lista.size())])
		return true
	return false

func _indices_seleccionables(grupo: String) -> Array[int]:
	var lista: Array[int] = []
	if grupo == "semilla":
		for i in SEMILLAS_ACTIVAS:
			if plantas_disponibles.has(i):
				lista.append(i)
	else:
		for i in ATAQUES_ACTIVOS:
			if i >= 0 and i < cargas_mostradas.size() and cargas_mostradas[i] > 0:
				lista.append(i)
	lista.sort()
	return lista

func seleccionar_grupo(grupo: String):
	var lista := _indices_seleccionables(grupo)
	if not lista.is_empty():
		_emitir_seleccion(grupo, lista[0])

func _emitir_seleccion(grupo: String, indice: int):
	if grupo == "semilla":
		semilla_pulsada.emit(indice, false)
	else:
		ataque_pulsado.emit(indice, false)

func actualizar_textos_controles():
	for i in botones_semilla.size():
		var costo: int = SEMILLAS[i].costo
		botones_semilla[i].text = "[%s]\n%s\n%d gota%s" % [ControlesManager.etiqueta_accion("Casilla Planta %d" % i), SEMILLAS[i].nombre, costo, "" if costo == 1 else "s"]
		botones_semilla[i].tooltip_text = SEMILLAS[i].get("rol", "") + "\n" + ControlesManager.etiqueta_accion("Casilla Planta %d" % i)
	for i in botones_ataque.size():
		actualizar_ataque(i, cargas_mostradas[i], ATAQUES[i].capacidad)
		botones_ataque[i].tooltip_text = ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre)
	boton_pala.text = "[%s]\nPala" % ControlesManager.etiqueta_accion("Pala")
	if boton_ronda != null:
		boton_ronda.tooltip_text = ControlesManager.etiqueta_accion("Iniciar Ronda")

func activar_en_punto(punto: Vector2, arrastre: bool):
	for i in botones_semilla.size():
		if botones_semilla[i].get_global_rect().has_point(punto):
			if not botones_semilla[i].disabled:
				semilla_pulsada.emit(i, arrastre)
			return
	for i in botones_ataque.size():
		if botones_ataque[i].get_global_rect().has_point(punto):
			if not botones_ataque[i].disabled:
				ataque_pulsado.emit(i, arrastre)
			return
	if boton_pala.get_global_rect().has_point(punto):
		pala_pulsada.emit(arrastre)
	elif boton_ronda.get_global_rect().has_point(punto) and not boton_ronda.disabled:
		ronda_solicitada.emit()
