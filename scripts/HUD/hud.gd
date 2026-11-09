extends CanvasLayer

signal semilla_pulsada(indice: int, arrastre: bool)
signal ataque_pulsado(indice: int, arrastre: bool)
signal ronda_solicitada
signal desafio_solicitado
signal prioridad_solicitada
signal mejora_solicitada
signal pala_pulsada(arrastre: bool)
signal guia_solicitada
signal velocidad_solicitada
signal cerrar_seleccion_solicitada
signal cerrar_ficha_solicitada
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const INDICACIONES = preload("res://scripts/HUD/indicaciones_control.gd")
const RETRATOS = preload("res://scripts/HUD/retratos_unidad.gd")
const INTERFAZ = preload("res://fuentes/interfaz.tres")

const SEMILLAS := [
	{"nombre": "Natura", "costo": 1, "costos": [1, 2, 3], "rol": "Disparo rápido a un objetivo."},
	{"nombre": "Flamma", "costo": 3, "costos": [3, 4, 5], "rol": "40 de daño de área. 1 disparo/s. Área: 1 / 1.5 / 2 celdas."},
	{"nombre": "Aqua", "costo": 6, "costos": [6, 4, 6], "rol": "Aporta +0.06 / 0.12 / 0.18 gotas/s al pozo. Se planta en casillas azules."},
	{"nombre": "Terra", "costo": 3, "costos": [3, 6, 9], "rol": "Bloquea caminos secos y empuja 0.5 / 0.7 / 1 casilla. 1000 / 2000 / 3000 HP. Aqua lo atraviesa."},
	{"nombre": "Electricitas", "costo": 2, "costos": [2, 4, 8], "rol": "Descargas de 10 de daño, 3/s. Encadena 3 / 5 / 7 bestias en rango; salta hasta 2 casillas."},
	{"nombre": "Glacies", "costo": 3, "costos": [3, 5, 8], "rol": "Carámbanos penetrantes: 2 de daño, hasta 3 / 4 / 5 bestias y congelación de 2 s. 1 disparo/s."},
	{"nombre": "Venenum", "costo": 10, "costos": [10, 12, 14], "rol": "100 de daño, 0.3 disparos/s. Veneno: 1 / 2 / 3 HP/s y lentitud 25 / 27 / 30% por 6 s. Alcance: 4 / 5 / 6 casillas."},
]

const RECARGA_BASE := 3.0
const ATAQUES := [
	{"nombre": "Natura", "dano": 10, "radio": 2.5, "capacidad": 2, "rol": "Inmoviliza 0.5 s. Sin efecto contra Flamma y Venenum."},
	{"nombre": "Flamma", "dano": 20, "radio": 2.5, "capacidad": 3, "rol": "Quemadura: 10 HP/s por 3 s. Daño x2 a Glacies. Sin efecto contra Flamma y Aqua."},
	{"nombre": "Aqua", "dano": 30, "radio": 3.0, "capacidad": 2, "rol": "Confusión por 6 s: ignora atajos. 50% de natación visual de 0.5 s. Daño x2 a Flamma. Sin efecto contra Aqua."},
	{"nombre": "Terra", "dano": 50, "radio": 2.0, "capacidad": 2, "rol": "Mareo por 3 s: se detiene 0.5 s cada segundo. Sin efecto contra Terra."},
	{"nombre": "Electricitas", "dano": 40, "radio": 2.5, "capacidad": 2, "rol": "Invierte la marcha 0.5 s. Sin efecto contra Electricitas."},
	{"nombre": "Glacies", "dano": 10, "radio": 4.0, "capacidad": 3, "recarga": 6.0, "rol": "Congela 2 s. Daño x2 a Flamma y Aqua. Sin efecto contra Glacies."},
	{"nombre": "Venenum", "dano": 100, "radio": 2.5, "capacidad": 2, "recarga": 10.0, "rol": "Vulnerabilidad: +1 por proyectil durante 6 s. Ralentiza 25% a 3 bestias al azar. Elimina Natura pequeño. Sin efecto contra Venenum."},
]

@onready var barra: PanelContainer = $Barra
@onready var fila_semillas: HBoxContainer = $Barra/Fila/Plantar/Semillas
@onready var fila_ataques: HBoxContainer = $Barra/Fila/Poderes/Ataques
@onready var panel_estado: PanelContainer = $PanelEstado
@onready var contadores: HBoxContainer = $PanelEstado/Contadores
@onready var panel_ronda: PanelContainer = $PanelRonda
@onready var acciones: HBoxContainer = $PanelRonda/Acciones
@onready var panel_ola: PanelContainer = $PanelOla
@onready var informe: VBoxContainer = $PanelOla/Contenido/Informe
@onready var datos_ola: VBoxContainer = $PanelOla/Contenido/Datos
@onready var detalles: VBoxContainer = $PanelOla/Contenido/Detalles
var label_gotas: Label
var label_ronda: Label
var label_vida: Label
var label_preparacion: Label
var label_amenazas: Label
var label_estado_combate: Label
var label_restantes: Label
var label_entrantes: Label
var hud_debug := false
var leyenda_terreno := ""
var ultimo_resumen: Dictionary = {}
var label_produccion: Label
var label_pozo: Label
var label_evento_clima: Label
var label_mision: Label
var label_consejo: Label

func actualizar_produccion(produccion: float, clima: String):
	var nombre: String = preload("res://scripts/nivel/clima.gd").NOMBRES.get(clima, clima.capitalize())
	label_produccion.text = "%s · Pozo +%.3f gotas/s en ronda" % [nombre, produccion]
	label_produccion.tooltip_text = leyenda_terreno

func actualizar_pozo(cantidad: int):
	label_pozo.text = "Reserva del pozo: %d/5" % cantidad

func actualizar_evento_clima(texto: String):
	label_evento_clima.text = texto
	label_evento_clima.tooltip_text = texto
	label_evento_clima.visible = not texto.is_empty()

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
var _texto_ronda := "Iniciar ronda"
var boton_ola: Button
var boton_desafio: Button
var boton_prioridad: Button
var boton_mejorar: Button
var boton_pala: Button
var boton_guia: Button
var boton_velocidad: Button
var _velocidad := 1
var panel_avisos_clima: PanelContainer
var texto_avisos_clima: Label
var boton_cerrar_seleccion: Button
var boton_cerrar_ficha: Button
var botones_laboratorio: Array[Button] = []
var panel_mejora: PanelContainer
var titulo_torre: Label
var resumen_torre: Label
var panel_aviso: PanelContainer
var aviso_colocacion: Label
var reloj_aviso: Timer
var previa_ronda: PanelContainer
var _fila_retratos: HBoxContainer
var _entrada_previa := Vector2.ZERO
var _cobertura_previa: Callable
var _iconos_accion := {}
var _pistas_mando: HBoxContainer
var _mando := false
var aviso_recompensa := ""
var opciones_presionadas := {}
var _estilo_seleccion: StyleBoxFlat
var _estilos_casilla: Dictionary

var SEMILLAS_ACTIVAS := [0]
var ATAQUES_ACTIVOS := [0]

func _ready():
	_estilo_seleccion = _estilo_boton(Color("#3c5436"), Color("#fff06b"), 3)
	_estilos_casilla = {
		"normal": _estilo_boton(Color("#1b3126"), Color("#496452"), 1),
		"hover": _estilo_boton(Color("#2a4b3a"), Color("#81ae86"), 1),
		"pressed": _estilo_seleccion,
		"disabled": _estilo_boton(Color("#12231d"), Color("#263a31"), 1),
	}
	label_gotas = _crear_contador("gota", "Gotas disponibles")
	label_vida = _crear_contador("meta", "Vida del Árbol Madre")
	label_ronda = _crear_contador("entrada", "Ronda actual")
	label_preparacion = _crear_detalle(informe, 26, 4)
	label_preparacion.add_theme_color_override("font_color", Color("#d7f5ad"))
	label_amenazas = _crear_detalle(informe, 22, 5)
	label_estado_combate = _crear_detalle(datos_ola, 26, 2)
	label_estado_combate.add_theme_color_override("font_color", Color("#d7f5ad"))
	label_restantes = _crear_detalle(datos_ola, 23, 2)
	label_entrantes = _crear_detalle(datos_ola, 22, 5)
	label_mision = _crear_detalle(detalles, 24, 2)
	label_mision.hide()
	label_consejo = _crear_detalle(detalles, 22, 4)
	label_consejo.hide()
	label_produccion = _crear_detalle(detalles, 22, 2)
	label_pozo = _crear_detalle(detalles, 22, 1)
	label_evento_clima = _crear_detalle(detalles, 22, 2)
	label_evento_clima.hide()

	if Guardado.slot_actual >= 0:
		SEMILLAS_ACTIVAS = Guardado.plantas_activas()
		ATAQUES_ACTIVOS = Guardado.ataques_activos()
	
	for i in SEMILLAS.size():
		var b := _crear_boton(SEMILLAS[i].nombre, ICONOS.ELEMENTOS[i], RETRATOS.crear({}, 58))
		var costo: Label = b.get_node("Valor")
		costo.text = str(SEMILLAS[i].costo)
		costo.offset_left = 22.0
		costo.add_theme_color_override("font_color", Color("#86dcff"))
		var gota := _glifo("gota", 1.05)
		gota.name = "Gota"
		gota.position = Vector2(27, 94)
		gota.size = Vector2(20, 20)
		b.add_child(gota)
		b.button_down.connect(func(): semilla_pulsada.emit(i, Input.is_action_pressed("Clic Izquierdo")))
		fila_semillas.add_child(b)
		botones_semilla.append(b)

	boton_pala = _crear_boton("Pala", "pala", _glifo("pala", 2.6))
	boton_pala.get_node("Valor").text = "Pala"
	boton_pala.tooltip_text = "Retira un árbol sin devolver el agua invertida."
	boton_pala.button_down.connect(func(): pala_pulsada.emit(Input.is_action_pressed("Clic Izquierdo")))
	fila_semillas.add_child(boton_pala)

	for i in ATAQUES.size():
		var id: String = ICONOS.ELEMENTOS[i]
		var b := _crear_boton(ATAQUES[i].nombre, id, _glifo(id, 2.65))
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

	boton_ronda = _crear_opcion("Iniciar ronda")
	_destacar_accion(boton_ronda)
	boton_ronda.pressed.connect(func(): ronda_solicitada.emit())
	acciones.add_child(boton_ronda)
	boton_desafio = _crear_opcion("")
	boton_desafio.hide()
	acciones.add_child(boton_desafio)
	boton_desafio.pressed.connect(func(): desafio_solicitado.emit())
	boton_ola = _crear_opcion("Detalles +")
	acciones.add_child(boton_ola)
	boton_ola.pressed.connect(func():
		panel_ola.visible = not panel_ola.visible
		boton_ola.text = "Detalles −" if panel_ola.visible else "Detalles +"
	)
	boton_guia = _crear_opcion("Códice")
	boton_guia.tooltip_text = "Tutorial del nivel y fichas de bestias, árboles y poderes."
	acciones.add_child(boton_guia)
	boton_guia.pressed.connect(func(): guia_solicitada.emit())
	boton_velocidad = _crear_opcion("1×")
	boton_velocidad.custom_minimum_size.x = 72
	boton_velocidad.tooltip_text = "Alternar velocidad: 1× / 2× / 4× / 8×"
	boton_velocidad.pressed.connect(func(): velocidad_solicitada.emit())
	acciones.add_child(boton_velocidad)
	boton_cerrar_seleccion = _crear_opcion("× Cancelar selección")
	boton_cerrar_seleccion.custom_minimum_size.y = 30
	boton_cerrar_seleccion.add_theme_font_size_override("font_size", 22)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var estilo := INTERFAZ.get_stylebox(estado, "Button").duplicate() as StyleBoxFlat
		estilo.content_margin_top = 2.0
		estilo.content_margin_bottom = 2.0
		boton_cerrar_seleccion.add_theme_stylebox_override(estado, estilo)
	boton_cerrar_seleccion.hide()
	boton_cerrar_seleccion.pressed.connect(func(): cerrar_seleccion_solicitada.emit())
	$Barra/Fila/Plantar/Cabecera.add_child(boton_cerrar_seleccion)
	_crear_paneles_del_tablero()
	panel_avisos_clima = _panel_del_tablero(Color("#ffcf72"))
	panel_avisos_clima.anchor_left = 0.5
	panel_avisos_clima.anchor_right = 0.5
	panel_avisos_clima.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_avisos_clima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto_avisos_clima = Label.new()
	texto_avisos_clima.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_avisos_clima.add_theme_color_override("font_color", Color("#ffda88"))
	panel_avisos_clima.add_child(texto_avisos_clima)
	_crear_indicaciones()
	get_viewport().size_changed.connect(_ubicar_previa_ronda)
	ControlesManager.controles_cambiados.connect(actualizar_textos_controles)
	actualizar_textos_controles()

func _crear_opcion(titulo: String) -> Button:
	var boton := Button.new()
	boton.text = titulo
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size.y = 52
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return boton

func _crear_boton(nombre: String, id: String, arte: Control) -> Button:
	var b := Button.new()
	b.name = nombre
	b.custom_minimum_size = Vector2(102, 118)
	b.focus_mode = Control.FOCUS_NONE
	b.accessibility_name = nombre
	_resaltar_boton(b, false)
	var color: Color = ICONOS.ICONOS[id][0]
	var borde := ColorRect.new()
	borde.name = "Acento"
	borde.color = color
	borde.position = Vector2(3, 9)
	borde.size = Vector2(3, 100)
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(borde)
	arte.name = "Arte"
	arte.position = Vector2(18, 21)
	arte.size = Vector2(66, 66)
	b.add_child(arte)
	if id != "pala":
		var candado := _glifo("candado", 2.8)
		candado.name = "Candado"
		candado.position = arte.position
		candado.size = arte.size
		candado.hide()
		b.add_child(candado)
	var atajo := _etiqueta_casilla("Atajo", 20, Color("#edf0d1"))
	atajo.position = Vector2(9, 3)
	atajo.size.x = 77
	atajo.clip_text = true
	b.add_child(atajo)
	var valor := _etiqueta_casilla("Valor", 24, color)
	valor.position = Vector2(8, 89)
	valor.size.x = 86
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(valor)
	return b

func _etiqueta_casilla(nombre: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.name = nombre
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta

func _glifo(id: String, escala: float) -> Control:
	var glifo := Control.new()
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glifo.draw.connect(func(): ICONOS.dibujar(glifo, id, glifo.size / 2.0, escala, false, id == "gota"))
	return glifo

func configurar_retratos_semillas(escenas: Array[PackedScene]):
	for i in mini(escenas.size(), botones_semilla.size()):
		if escenas[i] != null:
			var retrato := RETRATOS.arbol(escenas[i], &"idle_pequeno", true)
			var imagen: TextureRect = botones_semilla[i].get_node("Arte")
			imagen.texture = retrato.get("textura")
			imagen.self_modulate = retrato.get("tinte", Color.WHITE)

func _crear_contador(id: String, descripcion: String) -> Label:
	var grupo := HBoxContainer.new()
	grupo.tooltip_text = descripcion
	contadores.add_child(grupo)
	var glifo := Control.new()
	glifo.custom_minimum_size = Vector2(29, 36)
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glifo.draw.connect(func(): ICONOS.dibujar(glifo, id, glifo.size / 2.0, 1.65, false))
	glifo.resized.connect(glifo.queue_redraw)
	grupo.add_child(glifo)
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", 38)
	etiqueta.add_theme_color_override("font_color", ICONOS.ICONOS[id][0])
	grupo.add_child(etiqueta)
	return etiqueta

func _estilo_boton(fondo: Color, borde: Color, ancho: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(ancho)
	estilo.set_corner_radius_all(2)
	return estilo

func _destacar_accion(boton: Button):
	boton.add_theme_stylebox_override("normal", _estilo_boton(Color("#b9e38d"), Color("#d6f5b4"), 1))
	boton.add_theme_stylebox_override("hover", _estilo_boton(Color("#d6f5b4"), Color.WHITE, 1))
	boton.add_theme_stylebox_override("pressed", _estilo_boton(Color("#9cca71"), Color.WHITE, 1))
	for estado in ["font_color", "font_hover_color", "font_pressed_color"]:
		boton.add_theme_color_override(estado, Color("#14241d"))

func _panel_del_tablero(borde: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = INTERFAZ
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#19291e")
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(2)
	estilo.set_content_margin_all(14)
	estilo.shadow_color = Color(0, 0, 0, 0.4)
	estilo.shadow_size = 5
	panel.add_theme_stylebox_override("panel", estilo)
	panel.hide()
	add_child(panel)
	return panel

func _crear_paneles_del_tablero():
	previa_ronda = _panel_del_tablero(Color("#8aa777"))
	previa_ronda.name = "PreviaRonda"
	previa_ronda.mouse_filter = Control.MOUSE_FILTER_PASS
	var previa := VBoxContainer.new()
	previa_ronda.add_child(previa)
	var titulo := Label.new()
	titulo.text = "PRÓXIMA RONDA"
	titulo.theme_type_variation = &"TituloPixel"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", Color("#d7f5ad"))
	previa.add_child(titulo)
	_fila_retratos = HBoxContainer.new()
	_fila_retratos.add_theme_constant_override("separation", 9)
	previa.add_child(_fila_retratos)

	panel_mejora = _panel_del_tablero(Color("#87c68a"))
	panel_mejora.name = "FichaTorre"
	panel_mejora.custom_minimum_size.x = 394
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 4)
	panel_mejora.add_child(contenido)
	var cabecera := HBoxContainer.new()
	contenido.add_child(cabecera)
	titulo_torre = Label.new()
	titulo_torre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo_torre.theme_type_variation = &"TituloPixel"
	titulo_torre.add_theme_font_size_override("font_size", 30)
	titulo_torre.add_theme_color_override("font_color", Color("#e2ffb5"))
	cabecera.add_child(titulo_torre)
	boton_cerrar_ficha = _crear_opcion("×")
	boton_cerrar_ficha.size_flags_horizontal = Control.SIZE_FILL
	boton_cerrar_ficha.custom_minimum_size.x = 48
	boton_cerrar_ficha.tooltip_text = "Cerrar ficha"
	boton_cerrar_ficha.pressed.connect(func(): cerrar_ficha_solicitada.emit())
	cabecera.add_child(boton_cerrar_ficha)
	resumen_torre = _crear_detalle(contenido, 26, 5)
	boton_mejorar = _crear_opcion("Mejorar")
	boton_mejorar.custom_minimum_size.y = 52
	_destacar_accion(boton_mejorar)
	contenido.add_child(boton_mejorar)
	boton_prioridad = _crear_opcion("")
	contenido.add_child(boton_prioridad)
	boton_prioridad.hide()

	panel_aviso = _panel_del_tablero(Color("#e7a175"))
	panel_aviso.name = "AvisoColocacion"
	panel_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_colocacion = Label.new()
	aviso_colocacion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_colocacion.add_theme_font_size_override("font_size", 24)
	panel_aviso.add_child(aviso_colocacion)
	reloj_aviso = Timer.new()
	reloj_aviso.one_shot = true
	reloj_aviso.timeout.connect(panel_aviso.hide)
	add_child(reloj_aviso)

func mostrar_previa_ronda(entrantes: Array[Dictionary], entrada: Vector2, cobertura: Callable):
	for hijo in _fila_retratos.get_children():
		_fila_retratos.remove_child(hijo)
		hijo.queue_free()
	for grupo in entrantes:
		var ficha := HBoxContainer.new()
		ficha.tooltip_text = "%s ×%d" % [grupo.nombre, grupo.cantidad]
		ficha.add_child(RETRATOS.crear(grupo.retrato, 40))
		var cantidad := Label.new()
		cantidad.text = "×%d" % grupo.cantidad
		cantidad.add_theme_font_size_override("font_size", 24)
		cantidad.add_theme_color_override("font_color", Color("#fff1ae"))
		ficha.add_child(cantidad)
		_fila_retratos.add_child(ficha)
	_entrada_previa = entrada
	_cobertura_previa = cobertura
	previa_ronda.visible = not entrantes.is_empty()
	_ubicar_previa_ronda.call_deferred()

func _ubicar_previa_ronda():
	if not previa_ronda.visible:
		return
	var medida := previa_ronda.get_combined_minimum_size()
	previa_ronda.size = medida
	var espacio := _espacio_tablero()
	var maximo := (espacio.end - medida).max(espacio.position)
	var origen := _entrada_previa
	var candidatos := [
		origen - Vector2(medida.x / 2.0, medida.y + 37.0),
		origen + Vector2(37.0, -medida.y / 2.0),
		origen - Vector2(medida.x + 37.0, medida.y / 2.0),
		origen + Vector2(-medida.x / 2.0, 37.0),
	]
	var casilla := Rect2(origen - Vector2.ONE * 30.0, Vector2.ONE * 60.0)
	var menor := INF
	for candidato: Vector2 in candidatos:
		var posicion := candidato.clamp(espacio.position, maximo)
		var area := Rect2(posicion, medida)
		var costo: float = _cobertura_previa.call(area) + area.intersection(casilla).get_area() * 10.0
		if costo < menor:
			menor = costo
			previa_ronda.position = posicion

func posicionar_previa(entrada: Vector2):
	_entrada_previa = entrada
	_ubicar_previa_ronda()

func _crear_indicaciones():
	var acciones_boton := {
		boton_ronda: "Iniciar Ronda", boton_desafio: "Alternar Desafio", boton_ola: "Detalles de Ronda",
		boton_mejorar: "Mejorar Arbol", boton_prioridad: "Cambiar Prioridad", boton_guia: "Abrir Codice",
		boton_cerrar_seleccion: "Atras", boton_cerrar_ficha: "Atras",
	}
	for boton: Button in acciones_boton:
		var accion: String = acciones_boton[boton]
		if not _iconos_accion.has(accion):
			_iconos_accion[accion] = INDICACIONES.icono(accion)
		boton.icon = _iconos_accion[accion]
		boton.add_theme_constant_override("icon_max_width", 40)
		boton.expand_icon = true
	boton_cerrar_seleccion.add_theme_constant_override("icon_max_width", 24)
	_pistas_mando = HBoxContainer.new()
	_pistas_mando.add_theme_constant_override("separation", 5)
	$Barra/Fila/Poderes/Cabecera.add_child(_pistas_mando)
	for pista in [["Cambiar Casilla Izquierda", ""], ["Cambiar Casilla Derecha", "Casilla"],
			["Alternar Elemento o Planta", "Grupo"], ["Confirmar", "Confirmar"], ["Pala", "Pala"]]:
		_iconos_accion[pista[0]] = INDICACIONES.pista(_pistas_mando, pista[0], pista[1], 20)
	_mando = ControllerIcons.get_last_input_type() == ControllerIcons.InputType.CONTROLLER
	_pistas_mando.visible = _mando

func _crear_detalle(contenedor: Container, tamano: int, lineas: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.max_lines_visible = lineas
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.mouse_filter = Control.MOUSE_FILTER_PASS
	contenedor.add_child(etiqueta)
	return etiqueta

func mostrar_hud_debug(activo: bool):
	hud_debug = activo
	label_entrantes.visible = activo
	ultimo_resumen.clear()

func mostrar_preparacion(numero: int, cantidad: int, amenazas: PackedStringArray, refuerzos: PackedStringArray, desafio: bool, extra: int, recompensa: int):
	informe.show()
	datos_ola.hide()
	label_preparacion.text = "Próxima ronda %d · %d bestias" % [numero, cantidad]
	if recompensa > 0:
		label_preparacion.text += " · +%d gotas al superar" % recompensa
	if not refuerzos.is_empty():
		var estado := "Desafío elegido" if desafio else "Desafío opcional"
		label_preparacion.text += "\n%s · +%d gotas extra\nRefuerzos: %s" % [estado, extra, ", ".join(refuerzos)]
	label_preparacion.text += aviso_recompensa
	label_preparacion.tooltip_text = label_preparacion.text
	label_amenazas.text = "\n".join(amenazas)
	label_amenazas.tooltip_text = label_amenazas.text
	boton_desafio.visible = not refuerzos.is_empty()
	boton_desafio.text = "%sDesafío +%d" % ["✓ " if desafio else "", extra]
	boton_desafio.tooltip_text = "%s\n%s" % [ControlesManager.etiqueta_accion("Alternar Desafio"), label_preparacion.text]
	boton_desafio.modulate = Color(1.4, 1.4, 0.8) if desafio else Color.WHITE

func ocultar_preparacion():
	aviso_recompensa = ""
	informe.hide()
	datos_ola.show()
	boton_desafio.hide()

func anunciar_recompensa(cantidad: int, extra: int):
	aviso_recompensa = "\nRonda superada · +%d gotas" % cantidad
	if extra > 0:
		aviso_recompensa += " · Desafío superado: +%d gotas" % extra

func indicar_prioridad(modo: String):
	boton_prioridad.visible = not modo.is_empty()
	boton_prioridad.text = "Prioridad · " + modo
	boton_prioridad.tooltip_text = "[%s] Cambiar prioridad · %s" % [ControlesManager.etiqueta_accion("Cambiar Prioridad"), modo]

func mostrar_mejora(indice: int, nivel: int, costo: int, asequible: bool):
	titulo_torre.text = "%s · Nv. %d" % [SEMILLAS[indice].nombre, nivel]
	titulo_torre.add_theme_color_override("font_color", ICONOS.ICONOS[ICONOS.ELEMENTOS[indice]][0])
	boton_mejorar.disabled = costo < 0 or not asequible
	boton_mejorar.text = "Nivel máximo" if costo < 0 else "Mejorar %d gotas" % costo
	boton_mejorar.icon = _iconos_accion.get("Mejorar Arbol") if costo >= 0 else null
	boton_mejorar.tooltip_text = "Nivel máximo" if costo < 0 else (
		"[%s] Mejorar por %d gotas" % [ControlesManager.etiqueta_accion("Mejorar Arbol"), costo] if asequible else "Agua insuficiente"
	)

func indicar_dispositivo(event: InputEvent):
	# El nivel consume los eventos de juego antes que el autoload de iconos.
	var mando := _mando
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		mando = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventMouseMotion and not event.relative.is_zero_approx()):
		mando = false
	if mando != _mando:
		_mando = mando
		_pistas_mando.visible = mando
		actualizar_textos_controles()

func mostrar_ficha_torre(vida: int, maxima: int, stats: String, extras: String, punto: Vector2, area_pozo: Rect2, cobertura: Callable):
	resumen_torre.text = "%d / %d HP\n%s" % [vida, maxima, stats]
	resumen_torre.tooltip_text = (resumen_torre.text + "\n" + extras).strip_edges()
	panel_mejora.show()
	var medida := panel_mejora.get_combined_minimum_size()
	panel_mejora.size = medida
	var limites := _espacio_tablero()
	var posicion_maxima := (limites.end - medida).max(limites.position)
	var candidatos := [
		punto + Vector2(40, -28), punto - Vector2(medida.x + 40, 28),
		punto + Vector2(-medida.x / 2.0, 40), punto - Vector2(medida.x / 2.0, medida.y + 40),
	]
	var area_torre := Rect2(punto - Vector2.ONE * 32.0, Vector2.ONE * 64.0)
	var mejor := INF
	for candidato: Vector2 in candidatos:
		var posicion := candidato.clamp(limites.position, posicion_maxima)
		var area := Rect2(posicion, medida)
		var oclusion := area.intersection(area_torre).get_area() * 100.0
		oclusion += area.intersection(area_pozo).get_area() * 20.0
		if panel_ola.visible:
			oclusion += area.intersection(panel_ola.get_global_rect()).get_area() * 20.0
		if previa_ronda.visible:
			oclusion += area.intersection(previa_ronda.get_global_rect()).get_area() * 20.0
		var cubierta: float = cobertura.call(area) + oclusion
		if cubierta < mejor:
			mejor = cubierta
			panel_mejora.position = posicion

func mostrar_aviso_colocacion(texto: String, punto: Vector2):
	aviso_colocacion.text = texto
	panel_aviso.show()
	var medida := panel_aviso.get_combined_minimum_size()
	panel_aviso.size = medida
	var limites := _espacio_tablero()
	panel_aviso.position = Vector2(
		clampf(punto.x - medida.x / 2.0, limites.position.x, limites.end.x - medida.x),
		clampf(punto.y + 38, limites.position.y, limites.end.y - medida.y)
	)
	reloj_aviso.start(1.5)

func ocultar_aviso_colocacion():
	reloj_aviso.stop()
	panel_aviso.hide()

func _espacio_tablero() -> Rect2:
	var area := get_viewport().get_visible_rect().grow(-8.0)
	area.position.y = maxf(panel_estado.get_global_rect().end.y, panel_ronda.get_global_rect().end.y) + 8.0
	area.size.y = barra.get_global_rect().position.y - 8.0 - area.position.y
	return area

func espacio_camara() -> Rect2:
	var area := _espacio_tablero()
	area.position.y += 62.0
	area.size.y -= 70.0
	return area.grow(-4.0)

func mostrar_avisos_clima(texto: String):
	if texto == texto_avisos_clima.text and panel_avisos_clima.visible == (not texto.is_empty()):
		return
	texto_avisos_clima.text = texto
	panel_avisos_clima.offset_top = maxf(panel_estado.get_global_rect().end.y, panel_ronda.get_global_rect().end.y) + 4.0
	panel_avisos_clima.reset_size()
	var medida := panel_avisos_clima.get_combined_minimum_size()
	panel_avisos_clima.offset_left = -medida.x / 2.0
	panel_avisos_clima.offset_right = medida.x / 2.0
	panel_avisos_clima.visible = not texto.is_empty()

# --- API para nivel.gd ---
func actualizar_gotas(n: int):
	label_gotas.text = str(n)
	for i in botones_semilla.size():
		var boton := botones_semilla[i]
		var desbloqueada := SEMILLAS_ACTIVAS.has(i) and plantas_disponibles.has(i)
		boton.disabled = not desbloqueada or SEMILLAS[i].costo > n
		if desbloqueada:
			boton.tooltip_text = "%s · %d gotas\n%s\n%s" % [SEMILLAS[i].nombre, SEMILLAS[i].costo, SEMILLAS[i].rol, ControlesManager.etiqueta_accion("Casilla Planta %d" % i)]
		_mostrar_bloqueo(boton, desbloqueada, SEMILLAS[i].nombre)

func _mostrar_bloqueo(boton: Button, desbloqueado: bool, nombre: String):
	boton.get_node("Arte").visible = desbloqueado
	boton.get_node("Acento").visible = desbloqueado
	boton.get_node("Arte").modulate.a = 0.5 if boton.disabled else 1.0
	boton.get_node("Candado").visible = not desbloqueado
	boton.get_node("Valor").visible = desbloqueado
	boton.get_node("Atajo").visible = desbloqueado
	if boton.has_node("Gota"):
		boton.get_node("Gota").visible = desbloqueado
	boton.accessibility_name = nombre if desbloqueado else "Bloqueado"
	if not desbloqueado:
		boton.tooltip_text = "Bloqueado · Avanza en la campaña para desbloquear"

func actualizar_ronda(actual: int, total: int):
	label_ronda.text = "%d/%d" % [actual, total]

func actualizar_vida(actual: int, maxima: int):
	label_vida.text = "%d/%d" % [actual, maxima]

func intervalo_recarga_ataque(i: int) -> float:
	return ATAQUES[i].get("recarga", RECARGA_BASE)

func actualizar_ataque(i: int, cargas: float, maxima: float, tiempo: float = -1.0):
	cargas_mostradas[i] = cargas
	if tiempo >= 0.0:
		tiempos_recarga[i] = tiempo
	var listas := clampi(floori(cargas), 0, int(maxima))
	var accion: String = "Elemento " + ATAQUES[i].nombre
	_actualizar_atajo_casilla(botones_ataque[i], ControlesManager.etiqueta_accion(accion))
	botones_ataque[i].get_node("Valor").text = "%d/%d" % [listas, int(maxima)]
	botones_ataque[i].disabled = not ATAQUES_ACTIVOS.has(i) or cargas < 1.0
	botones_ataque[i].get_node("Arte").modulate.a = 0.45 if botones_ataque[i].disabled else 1.0
	barras_recarga[i].visible = tiempos_recarga[i] > 0.0
	var intervalo := intervalo_recarga_ataque(i)
	barras_recarga[i].value = clampf(1.0 - tiempos_recarga[i] / intervalo, 0.0, 1.0) * 100.0
	botones_ataque[i].tooltip_text = "%s\n%s\nDaño: %d · Radio: %.1f casillas · Cargas: %d/%d\nRecupera 1 carga cada %s s. Próxima: %.1f s\n%s" % [ATAQUES[i].nombre, ATAQUES[i].rol, ATAQUES[i].dano, ATAQUES[i].radio, listas, int(maxima), str(intervalo).trim_suffix(".0"), tiempos_recarga[i], ControlesManager.etiqueta_accion(accion)]
	_mostrar_bloqueo(botones_ataque[i], ATAQUES_ACTIVOS.has(i), ATAQUES[i].nombre)

func mostrar_boton_ronda(texto: String, habilitado: bool):
	_texto_ronda = texto
	boton_ronda.disabled = not habilitado
	_actualizar_atajo_ronda()

func resaltar(tipo: String, indice: int):
	boton_cerrar_seleccion.visible = not tipo.is_empty()
	_actualizar_atajo_ronda()
	if tipo in ["semilla", "ataque"]:
		grupo_seleccion = tipo
		indice_seleccion = indice
	for i in botones_semilla.size():
		_resaltar_boton(botones_semilla[i], tipo == "semilla" and i == indice)
	for i in botones_ataque.size():
		_resaltar_boton(botones_ataque[i], tipo == "ataque" and i == indice)
	_resaltar_boton(boton_pala, tipo == "pala")

func _resaltar_boton(boton: Button, seleccionado: bool):
	for estado in _estilos_casilla:
		boton.add_theme_stylebox_override(estado, _estilo_seleccion if seleccionado else _estilos_casilla[estado])

func punto_sobre_hud(p: Vector2) -> bool:
	for panel in [barra, panel_estado, panel_ronda, panel_ola, panel_mejora]:
		if panel.visible and panel.get_global_rect().has_point(p):
			return true
	return false

func actualizar_combate(resumen: Dictionary):
	if resumen == ultimo_resumen:
		return
	ultimo_resumen = resumen.duplicate(true)
	label_estado_combate.text = resumen.estado + aviso_recompensa
	label_restantes.text = "Bestias restantes: %d" % resumen.restantes
	if not hud_debug:
		return
	label_restantes.text += " · %d en camino · %d por aparecer" % [resumen.activos, resumen.por_aparecer]
	var grupos: PackedStringArray = []
	var claves: Array = resumen.entrantes.keys()
	claves.sort()
	for clave in claves:
		var partes := String(clave).split(":")
		var tamano: String = {"pequeno": "pequeño", "mediano": "mediano", "grande": "grande"}.get(partes[1], partes[1])
		var variante := " divisor" if partes.size() == 3 else ""
		grupos.append("%s %s%s: %d" % [partes[0].capitalize(), tamano, variante, resumen.entrantes[clave]])
	label_entrantes.text = "Entrantes: " + " · ".join(grupos) if not grupos.is_empty() else "Entrantes: ninguno"
	label_entrantes.tooltip_text = "\n".join(grupos)

# El nivel despacha estas acciones antes de confirmar una acción de tablero.
func manejar_accion(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed("Cambiar Velocidad", false, true):
		velocidad_solicitada.emit()
		return true
	if event.is_action_pressed("Pala", false, true):
		pala_pulsada.emit(false)
		return true
	if event.is_action_pressed("Iniciar Ronda", false, true):
		if not boton_ronda.disabled:
			ronda_solicitada.emit()
		return true
	if event.is_action_pressed("Detalles de Ronda", false, true):
		boton_ola.pressed.emit()
		return true
	if event.is_action_pressed("Abrir Codice", false, true):
		guia_solicitada.emit()
		return true
	if _pulso_opcion(event, "Alternar Desafio"):
		if boton_desafio.visible:
			desafio_solicitado.emit()
		return true
	if _pulso_opcion(event, "Cambiar Prioridad"):
		if panel_mejora.visible and boton_prioridad.visible:
			prioridad_solicitada.emit()
		elif not panel_mejora.visible and event is InputEventJoypadButton:
			guia_solicitada.emit()
		return true
	if _pulso_opcion(event, "Mejorar Arbol") and panel_mejora.visible:
		if not boton_mejorar.disabled:
			mejora_solicitada.emit()
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

func _pulso_opcion(event: InputEvent, accion: String) -> bool:
	var presionado := event.is_action_pressed(accion, false, true)
	if not event is InputEventJoypadMotion:
		return presionado
	for enlace in InputMap.action_get_events(accion):
		if not enlace is InputEventJoypadMotion or enlace.axis != event.axis or (enlace.device != -1 and enlace.device != event.device):
			continue
		var clave := "%s:%d:%d" % [accion, event.device, event.axis]
		if not presionado:
			opciones_presionadas.erase(clave)
			return false
		if opciones_presionadas.has(clave):
			return false
		opciones_presionadas[clave] = true
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
	var tipo := ControllerIconTexture.ForceType.CONTROLLER if _mando else ControllerIconTexture.ForceType.KEYBOARD_MOUSE
	for accion in _iconos_accion:
		var recurso: ControllerIconTexture = _iconos_accion[accion]
		if recurso != null:
			recurso.force_type = tipo
			recurso.path = "key/space" if accion == "Iniciar Ronda" and not _mando else accion
	for i in botones_semilla.size():
		var costo: int = SEMILLAS[i].costo
		var atajo := ControlesManager.etiqueta_accion("Casilla Planta %d" % i)
		_actualizar_atajo_casilla(botones_semilla[i], atajo)
		botones_semilla[i].tooltip_text = "%s · %d gotas\n%s\n%s" % [SEMILLAS[i].nombre, costo, SEMILLAS[i].rol, atajo]
		_mostrar_bloqueo(botones_semilla[i], SEMILLAS_ACTIVAS.has(i) and plantas_disponibles.has(i), SEMILLAS[i].nombre)
	for i in botones_ataque.size():
		actualizar_ataque(i, cargas_mostradas[i], ATAQUES[i].capacidad)
	_actualizar_atajo_casilla(boton_pala, ControlesManager.etiqueta_accion("Pala"))
	boton_ola.tooltip_text = "[%s] Detalles de la ronda, misión y clima." % ControlesManager.etiqueta_accion("Detalles de Ronda")
	boton_guia.tooltip_text = "[%s] Abrir Códice. En mando, pulsa el stick derecho con la ficha de torre cerrada." % ControlesManager.etiqueta_accion("Abrir Codice")
	var mando_codice := InputMap.action_get_events("Abrir Codice").any(func(evento): return ControlesManager.es_del_tipo(evento, ControlesManager.Tipo.MANDO))
	boton_guia.icon = _iconos_accion.get("Cambiar Prioridad" if _mando and not mando_codice else "Abrir Codice")
	mostrar_velocidad(_velocidad)
	if boton_ronda != null:
		_actualizar_atajo_ronda()
		boton_desafio.tooltip_text = "%s\n%s" % [ControlesManager.etiqueta_accion("Alternar Desafio"), label_preparacion.text]

func _actualizar_atajo_casilla(boton: Button, atajo: String):
	boton.get_node("Atajo").text = "" if _mando else atajo

func mostrar_velocidad(velocidad: int):
	_velocidad = velocidad
	var atajo := "LB+RB" if _mando else ControlesManager.etiqueta_accion("Cambiar Velocidad")
	boton_velocidad.text = "%d×  %s" % [velocidad, atajo]

func _actualizar_atajo_ronda():
	var enter := InputEventKey.new()
	enter.physical_keycode = KEY_ENTER
	var puede_usar_enter := InputMap.event_is_action(enter, "Confirmar", true)
	boton_ronda.text = _texto_ronda
	if not _mando and not boton_ronda.disabled and puede_usar_enter and not boton_cerrar_seleccion.visible:
		boton_ronda.text += " [Enter]"
	boton_ronda.tooltip_text = "Espacio · Iniciar ronda"
	if puede_usar_enter:
		boton_ronda.tooltip_text += "\nEnter también inicia si no hay una herramienta seleccionada."

func activar_en_punto(punto: Vector2, arrastre: bool):
	if boton_cerrar_seleccion.visible and boton_cerrar_seleccion.get_global_rect().has_point(punto):
		cerrar_seleccion_solicitada.emit()
		return
	if panel_mejora.visible and panel_mejora.get_global_rect().has_point(punto):
		if boton_cerrar_ficha.get_global_rect().has_point(punto):
			cerrar_ficha_solicitada.emit()
		elif boton_prioridad.visible and boton_prioridad.get_global_rect().has_point(punto):
			prioridad_solicitada.emit()
		elif not boton_mejorar.disabled and boton_mejorar.get_global_rect().has_point(punto):
			mejora_solicitada.emit()
		return
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
	elif boton_desafio.visible and boton_desafio.get_global_rect().has_point(punto):
		desafio_solicitado.emit()
	elif boton_ola.get_global_rect().has_point(punto):
		boton_ola.pressed.emit()
	elif boton_guia.get_global_rect().has_point(punto):
		guia_solicitada.emit()
	elif boton_velocidad.get_global_rect().has_point(punto):
		velocidad_solicitada.emit()
