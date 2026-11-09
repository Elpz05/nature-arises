extends CanvasLayer

signal semilla_pulsada(indice: int, arrastre: bool)
signal ataque_pulsado(indice: int, arrastre: bool)
signal ronda_solicitada
signal desafio_solicitado
signal prioridad_solicitada
signal mejora_solicitada
signal pala_pulsada(arrastre: bool)
signal guia_solicitada
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")

const SEMILLAS := [
	{"nombre": "Natura", "costo": 1, "costos": [1, 2, 3], "rol": "Disparo rápido a un objetivo."},
	{"nombre": "Flamma", "costo": 3, "costos": [3, 4, 5], "rol": "40 de daño de área. 1 disparo/s. Área: 1 / 1.5 / 2 celdas."},
	{"nombre": "Aqua", "costo": 6, "costos": [6, 4, 6], "rol": "Aporta +0.06 / 0.12 / 0.18 gotas/s al pozo. Se planta en casillas azules."},
	{"nombre": "Terra", "costo": 3, "costos": [3, 6, 9], "rol": "Bloquea puestos marcados del camino y empuja 0.5 / 0.7 / 1 casilla. 1000 / 2000 / 3000 HP. Aqua lo atraviesa."},
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
@onready var fila_semillas: HBoxContainer = $Barra/Margen/Fila/Plantar/Semillas
@onready var fila_ataques: HBoxContainer = $Barra/Margen/Fila/Poderes/Ataques
@onready var label_gotas: Label = $PanelCombate/Columnas/Info/LabelGotas
@onready var label_ronda: Label = $PanelCombate/Columnas/Info/LabelRonda
@onready var label_vida: Label = $PanelCombate/Columnas/Info/LabelVida
@onready var panel_estado: PanelContainer = $PanelEstado
@onready var label_estado_basico: Label = $PanelEstado/Fila/Estado
@onready var label_terreno: Label = $PanelEstado/Fila/Terreno
@onready var panel_combate: PanelContainer = $PanelCombate
@onready var panel_preparacion: PanelContainer = $PanelPreparacion
@onready var label_preparacion: Label = $PanelPreparacion/Informe/Titulo
@onready var label_amenazas: Label = $PanelPreparacion/Informe/Amenazas
@onready var label_estado_combate: Label = $PanelCombate/Columnas/Datos/LabelEstado
@onready var label_restantes: Label = $PanelCombate/Columnas/Datos/LabelRestantes
@onready var label_entrantes: Label = $PanelCombate/Columnas/Datos/LabelEntrantes
@onready var detalles: VBoxContainer = $PanelCombate/Columnas/Detalles
@onready var acciones: VBoxContainer = $Barra/Margen/Fila/Acciones
var ultimo_resumen: Dictionary = {}
var produccion_agua := 0.0
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
	label_terreno.text = nombre
	label_terreno.show()
	if is_instance_valid(label_produccion):
		label_produccion.text = "%s · Pozo +%.3f/s en ronda" % [nombre, produccion]

func actualizar_pozo(cantidad: int):
	label_pozo.text = "Pozo %d/5" % cantidad
	_actualizar_estado_basico()

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
	label_estado_basico.tooltip_text = "\n".join(PackedStringArray([label_mision.text, consejo])).strip_edges()
var cargas_mostradas: Array[float] = []
var barras_recarga: Array[ProgressBar] = []
var tiempos_recarga: Array[float] = []
var plantas_disponibles: Array[int] = []
var grupo_seleccion := "semilla"
var indice_seleccion := 0

var botones_semilla: Array[Button] = []
var botones_ataque: Array[Button] = []
var boton_ronda: Button
var label_tipos_ola: Label
var boton_desafio: Button
var boton_prioridad: Button
var boton_mejorar: Button
var icono_mejorar: ControllerIconTexture
var boton_pala: Button
var boton_guia: Button
var panel_mejora: PanelContainer
var titulo_torre: Label
var resumen_torre: Label
var panel_aviso: PanelContainer
var aviso_colocacion: Label
var reloj_aviso: Timer
var fila_opciones: HBoxContainer
var preparando := false
var aviso_recompensa := ""
var opciones_presionadas := {}
var _estilo_seleccion: StyleBoxFlat

var SEMILLAS_ACTIVAS := [0]
var ATAQUES_ACTIVOS := [0]

func _ready():
	_estilo_seleccion = _estilo_boton(Color("#203e37"), Color("#edffe0"), 2)
	label_mision = _crear_detalle(17, 1)
	label_mision.hide()
	label_consejo = _crear_detalle(16, 2)
	label_consejo.hide()
	label_evento_clima = _crear_detalle(16, 1)
	label_produccion = Label.new()
	label_produccion.add_theme_font_size_override("font_size", 14)
	label_gotas.get_parent().add_child(label_produccion)
	label_pozo = Label.new()
	label_pozo.add_theme_font_size_override("font_size", 14)
	label_gotas.get_parent().add_child(label_pozo)
	actualizar_produccion(produccion_agua, "despejado")
	for l in [label_gotas, label_ronda, label_vida]:
		l.add_theme_font_size_override("font_size", 14)

	if Guardado.slot_actual >= 0:
		SEMILLAS_ACTIVAS = Guardado.plantas_activas()
		ATAQUES_ACTIVOS = Guardado.ataques_activos()
	
	for i in SEMILLAS.size():
		var costo: int = SEMILLAS[i].costo
		var b := _crear_boton("%s\n%d gota%s" % [SEMILLAS[i].nombre, costo, "" if costo == 1 else "s"])
		_agregar_glifo(b, ICONOS.ELEMENTOS[i])
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
		_agregar_glifo(b, ICONOS.ELEMENTOS[i])
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
	boton_ronda.custom_minimum_size = Vector2(0, 28)
	boton_ronda.focus_mode = Control.FOCUS_NONE
	boton_ronda.clip_text = true
	boton_ronda.add_theme_font_size_override("font_size", 16)
	_destacar_accion(boton_ronda)
	boton_ronda.pressed.connect(func(): ronda_solicitada.emit())
	var fila_ronda := HBoxContainer.new()
	acciones.add_child(fila_ronda)
	boton_ronda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_ronda.add_child(boton_ronda)
	label_tipos_ola = Label.new()
	label_tipos_ola.add_theme_font_size_override("font_size", 15)
	label_tipos_ola.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_tipos_ola.mouse_filter = Control.MOUSE_FILTER_STOP
	label_tipos_ola.hide()
	acciones.add_child(label_tipos_ola)
	fila_opciones = HBoxContainer.new()
	acciones.add_child(fila_opciones)
	boton_desafio = _crear_opcion("")
	boton_desafio.custom_minimum_size.y = 24
	boton_desafio.hide()
	fila_opciones.add_child(boton_desafio)
	boton_desafio.pressed.connect(func(): desafio_solicitado.emit())
	boton_guia = _crear_opcion("Guía")
	boton_guia.custom_minimum_size.y = 24
	boton_guia.tooltip_text = "Tutorial del nivel y fichas de bestias, árboles y poderes."
	fila_opciones.add_child(boton_guia)
	boton_guia.pressed.connect(func(): guia_solicitada.emit())
	_crear_paneles_del_tablero()
	ControlesManager.controles_cambiados.connect(actualizar_textos_controles)
	actualizar_textos_controles()

func _crear_opcion(titulo: String) -> Button:
	var boton := Button.new()
	boton.text = titulo
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size.y = 28
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", 15)
	return boton

func _crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(76, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 13)
	b.text = texto
	return b

func _agregar_glifo(boton: Button, id: String):
	var glifo := Control.new()
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(glifo)
	glifo.draw.connect(func(): ICONOS.dibujar(glifo, id, Vector2(13, 13), 0.85, false))

func _estilo_boton(fondo: Color, borde: Color, ancho: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(ancho)
	estilo.set_corner_radius_all(5)
	return estilo

func _destacar_accion(boton: Button):
	boton.add_theme_stylebox_override("normal", _estilo_boton(Color("#b9e38d"), Color("#d6f5b4"), 1))
	boton.add_theme_stylebox_override("hover", _estilo_boton(Color("#d6f5b4"), Color.WHITE, 1))
	boton.add_theme_stylebox_override("pressed", _estilo_boton(Color("#9cca71"), Color.WHITE, 1))
	for estado in ["font_color", "font_hover_color", "font_pressed_color"]:
		boton.add_theme_color_override(estado, Color("#14241d"))

func _panel_del_tablero(borde: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#14251e")
	estilo.border_color = borde
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", estilo)
	panel.hide()
	add_child(panel)
	return panel

func _crear_paneles_del_tablero():
	panel_mejora = _panel_del_tablero(Color("#87c68a"))
	panel_mejora.name = "FichaTorre"
	panel_mejora.custom_minimum_size.x = 222
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 4)
	panel_mejora.add_child(contenido)
	titulo_torre = Label.new()
	titulo_torre.add_theme_font_size_override("font_size", 21)
	titulo_torre.add_theme_color_override("font_color", Color("#e2ffb5"))
	contenido.add_child(titulo_torre)
	resumen_torre = Label.new()
	resumen_torre.add_theme_font_size_override("font_size", 17)
	contenido.add_child(resumen_torre)
	var acciones_torre := HBoxContainer.new()
	contenido.add_child(acciones_torre)
	boton_mejorar = _crear_opcion("Mejorar")
	boton_mejorar.add_theme_font_size_override("font_size", 16)
	boton_mejorar.add_theme_constant_override("icon_max_width", 24)
	boton_mejorar.custom_minimum_size.y = 40
	_destacar_accion(boton_mejorar)
	acciones_torre.add_child(boton_mejorar)
	boton_prioridad = _crear_opcion("")
	boton_prioridad.custom_minimum_size.x = 129
	boton_prioridad.add_theme_font_size_override("font_size", 14)
	acciones_torre.add_child(boton_prioridad)
	_agregar_glifo(boton_prioridad, "prioridad")
	boton_prioridad.hide()
	if DisplayServer.get_name() != "headless":
		icono_mejorar = ControllerIconTexture.new()

	panel_aviso = _panel_del_tablero(Color("#e7a175"))
	panel_aviso.name = "AvisoColocacion"
	panel_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_colocacion = Label.new()
	aviso_colocacion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso_colocacion.add_theme_font_size_override("font_size", 18)
	panel_aviso.add_child(aviso_colocacion)
	reloj_aviso = Timer.new()
	reloj_aviso.one_shot = true
	reloj_aviso.timeout.connect(panel_aviso.hide)
	add_child(reloj_aviso)

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

func mostrar_hud_debug(activo: bool):
	panel_combate.visible = activo
	panel_estado.visible = not activo
	panel_preparacion.visible = preparando and not activo

func mostrar_preparacion(numero: int, cantidad: int, tipos: PackedStringArray, amenazas: PackedStringArray, refuerzos: PackedStringArray, desafio: bool, extra: int, recompensa: int):
	preparando = true
	label_tipos_ola.text = " · ".join(tipos)
	label_tipos_ola.tooltip_text = label_tipos_ola.text
	label_tipos_ola.show()
	panel_preparacion.visible = not panel_combate.visible
	label_preparacion.text = "Próxima ronda %d · %d bestias" % [numero, cantidad]
	if recompensa > 0:
		label_preparacion.text += " · +%d gotas al superar" % recompensa
	if not refuerzos.is_empty():
		var estado := "Desafío elegido" if desafio else "Desafío opcional"
		label_preparacion.text += "    |    %s · +%d gotas extra · Refuerzos: %s" % [estado, extra, ", ".join(refuerzos)]
	label_preparacion.text += aviso_recompensa
	label_amenazas.text = "    •    ".join(amenazas)
	boton_desafio.visible = not refuerzos.is_empty()
	boton_desafio.text = "%sDesafío +%d" % ["✓ " if desafio else "", extra]
	boton_desafio.tooltip_text = "%s\n%s" % [ControlesManager.etiqueta_accion("Alternar Desafio"), label_preparacion.text]
	boton_desafio.modulate = Color(1.4, 1.4, 0.8) if desafio else Color.WHITE

func ocultar_preparacion():
	preparando = false
	aviso_recompensa = ""
	panel_preparacion.hide()
	label_tipos_ola.hide()
	boton_desafio.hide()

func anunciar_recompensa(cantidad: int, extra: int):
	aviso_recompensa = "    |    Ronda superada · +%d gotas" % cantidad
	if extra > 0:
		aviso_recompensa += " · Desafío superado: +%d gotas" % extra

func indicar_prioridad(modo: String):
	boton_prioridad.visible = not modo.is_empty()
	boton_prioridad.text = "Prioridad\n" + modo
	boton_prioridad.tooltip_text = "[%s] Cambiar prioridad · %s" % [ControlesManager.etiqueta_accion("Cambiar Prioridad"), modo]

func mostrar_mejora(nombre: String, nivel: int, costo: int, asequible: bool):
	boton_mejorar.visible = not nombre.is_empty()
	if nombre.is_empty():
		panel_mejora.hide()
		return
	titulo_torre.text = "%s · Nv. %d" % [nombre, nivel]
	boton_mejorar.disabled = costo < 0 or not asequible
	boton_mejorar.text = "Nivel máximo" if costo < 0 else "Mejorar %d gotas" % costo
	boton_mejorar.icon = icono_mejorar if costo >= 0 else null
	boton_mejorar.tooltip_text = "Nivel máximo" if costo < 0 else (
		"[%s] Mejorar por %d gotas" % [ControlesManager.etiqueta_accion("Mejorar Arbol"), costo] if asequible else "Agua insuficiente"
	)

func indicar_dispositivo(event: InputEvent):
	if icono_mejorar == null:
		return
	# El nivel consume los eventos de juego antes que el autoload de iconos.
	var tipo := icono_mejorar.force_type
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		tipo = ControllerIconTexture.ForceType.CONTROLLER
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventMouseMotion and not event.relative.is_zero_approx()):
		tipo = ControllerIconTexture.ForceType.KEYBOARD_MOUSE
	if tipo != icono_mejorar.force_type:
		icono_mejorar.force_type = tipo

func mostrar_ficha_torre(vida: int, maxima: int, dato: String, punto: Vector2, area_pozo: Rect2, cobertura: Callable):
	resumen_torre.text = "%d / %d HP\n%s" % [vida, maxima, dato]
	panel_mejora.show()
	var medida := panel_mejora.get_combined_minimum_size()
	panel_mejora.size = medida
	var limites := get_viewport().get_visible_rect().grow(-8.0)
	var y := clampf(punto.y - 28.0, _borde_del_hud() + 8.0, limites.end.y - medida.y)
	var x := clampf(punto.x - medida.x / 2.0, limites.position.x, limites.end.x - medida.x)
	var candidatos := [
		Vector2(punto.x + 39, y), Vector2(punto.x - medida.x - 39, y),
		Vector2(x, punto.y + 39), Vector2(x, punto.y - medida.y - 39),
	]
	limites = Rect2(Vector2(limites.position.x, _borde_del_hud() + 8), Vector2(limites.size.x, limites.end.y - _borde_del_hud() - 8))
	var mejor := INF
	for posicion in candidatos:
		var area := Rect2(posicion, medida)
		if not limites.encloses(area) or area.intersects(area_pozo):
			continue
		var cubierta: float = cobertura.call(area)
		if cubierta < mejor:
			mejor = cubierta
			panel_mejora.position = posicion
	panel_mejora.visible = mejor < INF

func mostrar_aviso_colocacion(texto: String, punto: Vector2):
	aviso_colocacion.text = texto
	panel_aviso.show()
	var medida := panel_aviso.get_combined_minimum_size()
	panel_aviso.size = medida
	var limites := get_viewport().get_visible_rect().grow(-8.0)
	panel_aviso.position = Vector2(
		clampf(punto.x - medida.x / 2.0, limites.position.x, limites.end.x - medida.x),
		clampf(punto.y + 38, _borde_del_hud() + 8.0, limites.end.y - medida.y)
	)
	reloj_aviso.start(1.5)

func ocultar_aviso_colocacion():
	reloj_aviso.stop()
	panel_aviso.hide()

func _borde_del_hud() -> float:
	var panel := panel_combate if panel_combate.visible else (panel_preparacion if panel_preparacion.visible else panel_estado)
	return panel.get_global_rect().end.y

func _actualizar_estado_basico():
	var datos := PackedStringArray([label_gotas.text, label_ronda.text, label_vida.text, label_pozo.text])
	if not label_mision.text.is_empty():
		datos.insert(0, label_mision.text)
	label_estado_basico.text = "    ·    ".join(datos)

# --- API para nivel.gd ---
func actualizar_gotas(n: int):
	label_gotas.text = "Gotas: %d" % n
	_actualizar_estado_basico()
	for i in botones_semilla.size():
		botones_semilla[i].disabled = not SEMILLAS_ACTIVAS.has(i) or SEMILLAS[i].costo > n

func actualizar_ronda(actual: int, total: int):
	label_ronda.text = "Ronda %d/%d" % [actual, total]
	_actualizar_estado_basico()

func actualizar_vida(actual: int, maxima: int):
	label_vida.text = "Árbol madre: %d / %d" % [actual, maxima]
	_actualizar_estado_basico()

func intervalo_recarga_ataque(i: int) -> float:
	return ATAQUES[i].get("recarga", RECARGA_BASE)

func actualizar_ataque(i: int, cargas: float, maxima: float, tiempo: float = -1.0):
	cargas_mostradas[i] = cargas
	if tiempo >= 0.0:
		tiempos_recarga[i] = tiempo
	var listas := clampi(floori(cargas), 0, int(maxima))
	var pips := "●".repeat(listas) + "○".repeat(int(maxima) - listas)
	botones_ataque[i].text = "[%s]\n%s\n%s" % [ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre), ATAQUES[i].nombre, pips]
	botones_ataque[i].disabled = not ATAQUES_ACTIVOS.has(i) or cargas < 1.0
	barras_recarga[i].visible = tiempos_recarga[i] > 0.0
	var intervalo := intervalo_recarga_ataque(i)
	barras_recarga[i].value = clampf(1.0 - tiempos_recarga[i] / intervalo, 0.0, 1.0) * 100.0
	botones_ataque[i].tooltip_text = "%s\nDaño: %d | Radio: %.1f casillas | Cargas: %d/%d\nRecupera 1 carga cada %s s. Próxima: %.1f s\n%s" % [ATAQUES[i].rol, ATAQUES[i].dano, ATAQUES[i].radio, listas, int(maxima), str(intervalo).trim_suffix(".0"), tiempos_recarga[i], ControlesManager.etiqueta_accion("Elemento " + ATAQUES[i].nombre)]

func mostrar_boton_ronda(texto: String, habilitado: bool):
	boton_ronda.text = texto
	boton_ronda.tooltip_text = ControlesManager.etiqueta_accion("Iniciar Ronda")
	boton_ronda.disabled = not habilitado

func resaltar(tipo: String, indice: int):
	if tipo in ["semilla", "ataque"]:
		grupo_seleccion = tipo
		indice_seleccion = indice
	for i in botones_semilla.size():
		_resaltar_boton(botones_semilla[i], tipo == "semilla" and i == indice)
	for i in botones_ataque.size():
		_resaltar_boton(botones_ataque[i], tipo == "ataque" and i == indice)
	_resaltar_boton(boton_pala, tipo == "pala")

func _resaltar_boton(boton: Button, seleccionado: bool):
	for estado in ["normal", "hover", "pressed", "disabled"]:
		if seleccionado:
			boton.add_theme_stylebox_override(estado, _estilo_seleccion)
		else:
			boton.remove_theme_stylebox_override(estado)

func punto_sobre_hud(p: Vector2) -> bool:
	var panel := panel_combate if panel_combate.visible else panel_estado
	return barra.get_global_rect().has_point(p) or panel.get_global_rect().has_point(p) \
		or (panel_preparacion.visible and panel_preparacion.get_global_rect().has_point(p)) \
		or (panel_mejora.visible and panel_mejora.get_global_rect().has_point(p))

func actualizar_combate(resumen: Dictionary):
	if resumen == ultimo_resumen:
		return
	ultimo_resumen = resumen.duplicate(true)
	label_estado_combate.text = resumen.estado + aviso_recompensa
	label_restantes.text = "Restantes: %d | En camino: %d | Por aparecer: %d" % [resumen.restantes, resumen.activos, resumen.por_aparecer]
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
	if event.is_action_pressed("Pala", false, true):
		pala_pulsada.emit(false)
		return true
	if event.is_action_pressed("Iniciar Ronda", false, true):
		if not boton_ronda.disabled:
			ronda_solicitada.emit()
		return true
	if _pulso_opcion(event, "Alternar Desafio"):
		if boton_desafio.visible:
			desafio_solicitado.emit()
		return true
	if _pulso_opcion(event, "Cambiar Prioridad"):
		if panel_mejora.visible and boton_prioridad.visible:
			prioridad_solicitada.emit()
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
	if icono_mejorar != null:
		icono_mejorar.path = "Mejorar Arbol"
	for i in botones_semilla.size():
		var costo: int = SEMILLAS[i].costo
		botones_semilla[i].text = "[%s]\n%s\n%d gota%s" % [ControlesManager.etiqueta_accion("Casilla Planta %d" % i), SEMILLAS[i].nombre, costo, "" if costo == 1 else "s"]
		botones_semilla[i].tooltip_text = SEMILLAS[i].get("rol", "") + "\n" + ControlesManager.etiqueta_accion("Casilla Planta %d" % i)
	for i in botones_ataque.size():
		actualizar_ataque(i, cargas_mostradas[i], ATAQUES[i].capacidad)
	boton_pala.text = "[%s]\nPala" % ControlesManager.etiqueta_accion("Pala")
	if boton_ronda != null:
		boton_ronda.tooltip_text = ControlesManager.etiqueta_accion("Iniciar Ronda")
		boton_desafio.tooltip_text = "%s\n%s" % [ControlesManager.etiqueta_accion("Alternar Desafio"), label_preparacion.text]

func activar_en_punto(punto: Vector2, arrastre: bool):
	if panel_mejora.visible and panel_mejora.get_global_rect().has_point(punto):
		if boton_prioridad.visible and boton_prioridad.get_global_rect().has_point(punto):
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
	elif boton_guia.get_global_rect().has_point(punto):
		guia_solicitada.emit()
