extends CanvasLayer

signal semilla_pulsada(indice: int, arrastre: bool)
signal ataque_pulsado(indice: int, arrastre: bool)
signal ronda_solicitada
signal pala_pulsada(arrastre: bool)

const SEMILLAS := [
	{"nombre": "Natura", "costo": 1, "costos": [1, 2, 3], "rol": "Disparo rápido a un objetivo."},
	{"nombre": "Flamma", "costo": 3, "costos": [3, 4, 5], "rol": "40 de daño de área. 1 disparo/s. Área: 1 / 1.5 / 2 celdas."},
	{"nombre": "Aqua", "costo": 6, "costos": [6, 8, 10], "rol": "Aporta +0.1 / 0.2 / 0.3 gotas/s al pozo. Se planta en casillas inundadas."},
	{"nombre": "Terra", "costo": 3, "costos": [3, 6, 9], "rol": "Bloquea caminos secos y empuja 0.5 / 0.7 / 1 casilla. 1000 / 2000 / 3000 HP. Aqua lo atraviesa."},
	{"nombre": "Electricitas", "costo": 2, "costos": [2, 4, 8], "rol": "Descargas de 10 de daño, 3/s. Encadena 3 / 5 / 7 bestias en rango; salta hasta 2 casillas."},
	{"nombre": "Glacies", "costo": 3, "costos": [3, 5, 8], "rol": "Carámbanos penetrantes: 2 de daño, hasta 3 / 4 / 5 bestias y congelación de 2 s. 1 disparo/s."},
	{"nombre": "Venenum", "costo": 10, "costos": [10, 12, 14], "rol": "100 de daño, 0.3 disparos/s. Veneno: 1 / 2 / 3 HP/s y lentitud 25 / 27 / 30% por 6 s. Alcance: 4 / 5 / 6 casillas."},
]

const ATAQUES := [
	{"nombre": "Natura", "dano": 10, "radio": 2.5, "capacidad": 2, "rol": "Inmoviliza 0.5 s. Sin efecto contra Flamma y Venenum."},
	{"nombre": "Flamma", "dano": 20, "radio": 2.5, "capacidad": 3, "rol": "Quemadura: 10 HP/s por 3 s. Daño x2 a Glacies. Sin efecto contra Flamma y Aqua."},
	{"nombre": "Aqua", "dano": 30, "radio": 3.0, "capacidad": 2, "rol": "Confusión por 6 s: ignora atajos. 50% de natación visual de 0.5 s. Daño x2 a Flamma. Sin efecto contra Aqua."},
	{"nombre": "Terra", "dano": 50, "radio": 2.0, "capacidad": 2, "rol": "Mareo por 3 s: se detiene 0.5 s cada segundo. Sin efecto contra Terra."},
	{"nombre": "Electricitas", "dano": 40, "radio": 2.5, "capacidad": 2, "rol": "Invierte la marcha 0.5 s. Sin efecto contra Electricitas."},
	{"nombre": "Glacies", "dano": 10, "radio": 4.0, "capacidad": 3, "rol": "Congela 2 s. Daño x2 a Flamma y Aqua. Sin efecto contra Glacies."},
	{"nombre": "Venenum", "dano": 100, "radio": 2.5, "capacidad": 2.5, "rol": "Vulnerabilidad: +1 por proyectil durante 6 s. Ralentiza 25% a 3 bestias al azar. Elimina Natura pequeño. Sin efecto contra Venenum."},
]

@onready var barra: PanelContainer = $Barra
@onready var fila_semillas: HBoxContainer = $Barra/Margen/Fila/Semillas
@onready var fila_ataques: HBoxContainer = $Barra/Margen/Fila/Ataques
@onready var label_gotas: Label = $PanelCombate/Columnas/Info/LabelGotas
@onready var label_ronda: Label = $PanelCombate/Columnas/Info/LabelRonda
@onready var label_vida: Label = $PanelCombate/Columnas/Info/LabelVida
@onready var panel_combate: PanelContainer = $PanelCombate
@onready var label_estado_combate: Label = $PanelCombate/Columnas/Datos/LabelEstado
@onready var label_restantes: Label = $PanelCombate/Columnas/Datos/LabelRestantes
@onready var label_entrantes: Label = $PanelCombate/Columnas/Datos/LabelEntrantes
@onready var detalles: VBoxContainer = $PanelCombate/Columnas/Detalles
@onready var acciones: VBoxContainer = $Barra/Margen/Fila/Acciones
var ultimo_resumen: Dictionary = {}
var produccion_agua := 0.2
var clima_actual := "despejado"
var label_produccion: Label
var label_pozo: Label
var label_evento_clima: Label
var label_mision: Label
var label_consejo: Label
var panel_laboratorio: Control
var botones_laboratorio: Array[Button] = []

func actualizar_produccion(produccion: float, clima: String):
	produccion_agua = produccion
	clima_actual = clima
	var nombre: String = preload("res://scripts/nivel/clima.gd").NOMBRES.get(clima, clima.capitalize())
	if is_instance_valid(label_produccion):
		label_produccion.text = "%s · Pozo +%.2f/s en ronda" % [nombre, produccion]

func actualizar_pozo(cantidad: int):
	label_pozo.text = "Pozo %d/5 · Recoger en el mapa" % cantidad

func actualizar_evento_clima(texto: String):
	if is_instance_valid(label_evento_clima):
		label_evento_clima.text = texto
		label_evento_clima.tooltip_text = texto

func mostrar_mision(titulo: String, consejo: String):
	label_mision.text = titulo
	label_mision.visible = not titulo.is_empty()
	mostrar_consejo(consejo)

func mostrar_consejo(consejo: String):
	label_consejo.text = consejo
	label_consejo.tooltip_text = consejo
	label_consejo.visible = not consejo.is_empty()
var cargas_mostradas: Array[float] = []
var barras_recarga: Array[ProgressBar] = []
var tiempos_recarga: Array[float] = []
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
	label_mision = _crear_detalle(19, 1)
	label_mision.hide()
	label_consejo = _crear_detalle(16, 2)
	label_consejo.hide()
	label_evento_clima = _crear_detalle(16, 1)
	label_produccion = Label.new()
	label_produccion.add_theme_font_size_override("font_size", 16)
	label_gotas.get_parent().add_child(label_produccion)
	label_pozo = Label.new()
	label_pozo.add_theme_font_size_override("font_size", 16)
	label_gotas.get_parent().add_child(label_pozo)
	actualizar_produccion(0.2, "despejado")
	for l in [label_gotas, label_ronda, label_vida]:
		l.add_theme_font_size_override("font_size", 18)

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
	boton_pala.tooltip_text = "Retira un árbol sin devolver el agua invertida."
	boton_pala.button_down.connect(func(): pala_pulsada.emit(Input.is_action_pressed("Clic Izquierdo")))
	fila_semillas.add_child(boton_pala)

	for i in ATAQUES.size():
		var b := _crear_boton("")
		b.button_down.connect(func(): ataque_pulsado.emit(i, Input.is_action_pressed("Clic Izquierdo")))
		fila_ataques.add_child(b)
		botones_ataque.append(b)
		var progreso := ProgressBar.new()
		progreso.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		progreso.offset_top = -5.0
		progreso.offset_bottom = -1.0
		progreso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progreso.show_percentage = false
		b.add_child(progreso)
		barras_recarga.append(progreso)
		cargas_mostradas.append(ATAQUES[i].capacidad)
		tiempos_recarga.append(0.0)
		actualizar_ataque(i, ATAQUES[i].capacidad, ATAQUES[i].capacidad)

	boton_ronda = Button.new()
	boton_ronda.custom_minimum_size = Vector2(0, 32)
	boton_ronda.focus_mode = Control.FOCUS_NONE
	boton_ronda.clip_text = true
	boton_ronda.add_theme_font_size_override("font_size", 16)
	boton_ronda.pressed.connect(func(): ronda_solicitada.emit())
	acciones.add_child(boton_ronda)
	ControlesManager.controles_cambiados.connect(actualizar_textos_controles)
	actualizar_textos_controles()

func _crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	b.text = texto
	return b

func _crear_detalle(tamano: int, lineas: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.max_lines_visible = lineas
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.mouse_filter = Control.MOUSE_FILTER_PASS
	detalles.add_child(etiqueta)
	return etiqueta

func mostrar_inspeccion(activa: bool):
	label_mision.visible = not activa and not label_mision.text.is_empty()
	label_consejo.visible = not activa and not label_consejo.text.is_empty()
	label_evento_clima.visible = not activa

# --- API para nivel.gd ---
func actualizar_gotas(n: int):
	label_gotas.text = "Gotas: %d" % n
	for i in botones_semilla.size():
		botones_semilla[i].disabled = not SEMILLAS_ACTIVAS.has(i) or SEMILLAS[i].costo > n

func actualizar_ronda(actual: int, total: int):
	label_ronda.text = "Ronda %d/%d" % [actual, total]

func actualizar_vida(actual: int, maxima: int):
	label_vida.text = "Árbol madre: %d / %d" % [actual, maxima]

func actualizar_ataque(i: int, cargas: float, maxima: float, tiempo: float = -1.0):
	cargas_mostradas[i] = cargas
	if tiempo >= 0.0:
		tiempos_recarga[i] = tiempo
	botones_ataque[i].text = "[%s]\n%s\n%s/%s" % [ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre), ATAQUES[i].nombre, str(cargas).trim_suffix(".0"), str(maxima).trim_suffix(".0")]
	botones_ataque[i].disabled = not ATAQUES_ACTIVOS.has(i) or cargas < 1.0
	barras_recarga[i].visible = tiempos_recarga[i] > 0.0
	barras_recarga[i].value = clampf(1.0 - tiempos_recarga[i] / 3.0, 0.0, 1.0) * 100.0
	botones_ataque[i].tooltip_text = "%s\nDaño: %d | Radio: %.1f casillas\nRecupera 1 carga cada 3 s. Próxima: %.1f s\n%s" % [ATAQUES[i].rol, ATAQUES[i].dano, ATAQUES[i].radio, tiempos_recarga[i], ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre)]

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
	label_restantes.text = "Restantes: %d | En camino: %d | Por aparecer: %d" % [resumen.restantes, resumen.activos, resumen.por_aparecer]
	var grupos: PackedStringArray = []
	var claves: Array = resumen.entrantes.keys()
	claves.sort()
	for clave in claves:
		var partes := String(clave).split(":")
		var tamano: String = {"pequeno": "pequeño", "mediano": "mediano", "grande": "grande"}.get(partes[1], partes[1])
		grupos.append("%s %s: %d" % [partes[0].capitalize(), tamano, resumen.entrantes[clave]])
	label_entrantes.text = "Entrantes: " + " · ".join(grupos) if not grupos.is_empty() else "Entrantes: ninguno"
	label_entrantes.tooltip_text = "\n".join(grupos)

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
			if ATAQUES_ACTIVOS.has(i) and cargas_mostradas[i] >= 1.0:
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
			if i >= 0 and i < cargas_mostradas.size() and cargas_mostradas[i] >= 1.0:
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
	boton_pala.text = "[%s]\nPala" % ControlesManager.etiqueta_accion("Pala")
	if boton_ronda != null:
		boton_ronda.tooltip_text = ControlesManager.etiqueta_accion("Iniciar Ronda")

func activar_en_punto(punto: Vector2, arrastre: bool):
	for boton in botones_laboratorio:
		if boton.get_global_rect().has_point(punto):
			boton.pressed.emit()
			return
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
