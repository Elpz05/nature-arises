extends CanvasLayer

signal cerrada

const CONTENIDO = preload("res://scripts/guia/contenido_guia.gd")
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const RETRATOS = preload("res://scripts/HUD/retratos_unidad.gd")
const INDICACIONES = preload("res://scripts/HUD/indicaciones_control.gd")
const ESCALA_UI = preload("res://scripts/HUD/escala_interfaz.gd")
const COLOR_ENCABEZADO := Color(0.68, 0.92, 0.65)

# Se asigna antes de agregar la guía al árbol. Vacío en el menú.
var fichas_nivel: Array = []
var plantas_visibles: Array = []
var ataques_visibles: Array = []
var pestana_actual := ""
var ficha_actual := 0
var _capitulos := {}
var _botones_pestana := {}
var _botones_ficha: Array[Button] = []

@onready var cerrar: Button = %Cerrar
@onready var pestanas: HBoxContainer = %Pestanas
@onready var indice: VBoxContainer = %Indice
@onready var lectura: ScrollContainer = %Lectura
@onready var detalle: VBoxContainer = %Detalle

func _ready():
	var panel: PanelContainer = $Centro/Panel
	var tema := panel.theme.duplicate() as Theme
	tema.default_font = _fuente_nitida(tema.default_font)
	tema.set_font("font", "Button", _fuente_nitida(tema.get_font("font", "Button")))
	tema.set_font("font", "TituloPixel", _fuente_nitida(tema.get_font("font", "TituloPixel")))
	panel.theme = tema
	panel.set_meta("minimo_ui_adaptativo", true)
	get_viewport().size_changed.connect(_ajustar_panel)
	_ajustar_panel()
	cerrar.pressed.connect(_cerrar)
	var pie: HBoxContainer = %Pie
	%EstadoPausa.visible = not fichas_nivel.is_empty()
	INDICACIONES.pista(pie, "Izquierda", "", 24)
	INDICACIONES.pista(pie, "Derecha", "Navegar", 24)
	INDICACIONES.pista(pie, "Confirmar", "Abrir", 24)
	INDICACIONES.pista(pie, "Atras", "Cerrar", 24)
	INDICACIONES.pista(pie, "Alternar Desafio", "", 24)
	INDICACIONES.pista(pie, "Mejorar Arbol", "Desplazar", 24)
	if not fichas_nivel.is_empty():
		_agregar_capitulo("nivel", "Nivel actual", fichas_nivel)
	_agregar_capitulo("jugar", "Cómo jugar", CONTENIDO.como_jugar())
	_agregar_capitulo("bestias", "Bestiario", CONTENIDO.bestias())
	_agregar_capitulo("arboles", "Árboles", CONTENIDO.arboles())
	_agregar_capitulo("poderes", "Poderes", CONTENIDO.poderes())
	_mostrar_capitulo("jugar" if fichas_nivel.is_empty() else "nivel")
	add_child(ESCALA_UI.new())
	_botones_pestana[pestana_actual].grab_focus()

func _fuente_nitida(original: FontFile) -> FontFile:
	var fuente := original.duplicate() as FontFile
	fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return fuente

func _ajustar_panel():
	$Centro/Panel.custom_minimum_size = get_viewport().get_visible_rect().size - Vector2(64, 48)

func _agregar_capitulo(id: String, texto: String, fichas: Array):
	_capitulos[id] = fichas
	var boton := _boton(texto, 60, 34)
	pestanas.add_child(boton)
	_botones_pestana[id] = boton
	boton.pressed.connect(_mostrar_capitulo.bind(id))

func _mostrar_capitulo(id: String):
	if pestana_actual == id:
		return
	pestana_actual = id
	for clave in _botones_pestana:
		_destacar(_botones_pestana[clave], clave == id)
	_vaciar(indice)
	_botones_ficha.clear()
	var fichas: Array = _capitulos[id]
	for i in fichas.size():
		var texto: String = fichas[i].get("indice", fichas[i].titulo)
		var boton := _boton(texto if _descubierta(i) else "Bloqueado", 56, 34)
		indice.add_child(boton)
		_botones_ficha.append(boton)
		boton.focus_entered.connect(_mostrar_ficha.bind(i))
		boton.pressed.connect(_mostrar_ficha.bind(i))
	_actualizar_foco()
	ESCALA_UI.aplicar(indice, Ajustes.escala_ui())
	_mostrar_ficha(0)

func _mostrar_ficha(i: int):
	ficha_actual = i
	for j in _botones_ficha.size():
		_destacar(_botones_ficha[j], j == i)
	var ficha: Dictionary = _capitulos[pestana_actual][i]
	_vaciar(detalle)
	if not _descubierta(i):
		detalle.add_child(_etiqueta("Entrada bloqueada", 40, COLOR_ENCABEZADO))
		detalle.add_child(_etiqueta("Encuentra esta bestia o consigue el desbloqueo en la campaña.", 28, Color.WHITE))
		ESCALA_UI.aplicar(detalle, Ajustes.escala_ui())
		lectura.scroll_vertical = 0
		return
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 14)
	detalle.add_child(cabecera)
	if ficha.has("especie"):
		cabecera.add_child(RETRATOS.crear(_retrato(ficha.especie), 88))
	var titulo := _etiqueta(ficha.titulo, 42, Color.WHITE)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cabecera.add_child(titulo)
	for seccion in ficha.secciones:
		var destino: Container = detalle
		if seccion.size() > 2:
			var fila := HBoxContainer.new()
			fila.add_theme_constant_override("separation", 12)
			detalle.add_child(fila)
			var icono := Control.new()
			var id: String = seccion[2]
			var lleno: bool = seccion.size() > 3 and seccion[3]
			icono.custom_minimum_size = Vector2(45, 45)
			fila.add_child(icono)
			icono.resized.connect(icono.queue_redraw)
			icono.draw.connect(func():
				var lado := icono.custom_minimum_size.x
				ICONOS.dibujar(icono, id, Vector2.ONE * lado / 2.0, lado / 17.0, true, lleno)
			)
			destino = fila
		var bloque := VBoxContainer.new()
		bloque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloque.add_theme_constant_override("separation", 4)
		destino.add_child(bloque)
		bloque.add_child(_etiqueta(seccion[0], 30, COLOR_ENCABEZADO))
		bloque.add_child(_etiqueta(seccion[1], 30, Color(0.91, 0.95, 0.92)))
	lectura.scroll_vertical = 0
	ESCALA_UI.aplicar(detalle, Ajustes.escala_ui())

func _descubierta(i: int) -> bool:
	match pestana_actual:
		"bestias":
			return Guardado.entrada_descubierta("bestias", _capitulos[pestana_actual][i].especie)
		"arboles":
			return _capitulos[pestana_actual][i].especie == "madre" or plantas_visibles.has(i) or Guardado.entrada_descubierta("plantas", i)
		"poderes":
			return ataques_visibles.has(i) or Guardado.entrada_descubierta("ataques", i)
	return true

func _retrato(especie: String) -> Dictionary:
	if pestana_actual == "bestias":
		var archivo := "prueba" if especie == "natura" else especie
		return RETRATOS.bestia(load("res://escenas/escenas_espiritu/espiritu_%s.tscn" % archivo), "pequeno")
	var archivo := "base" if especie == "natura" else especie
	var animacion := &"idle" if especie == "madre" else &"idle_pequeno"
	return RETRATOS.arbol(load("res://escenas/escenas_arboles/arbol_%s.tscn" % archivo), animacion, true)

func _boton(texto: String, alto: float, tamano: int) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size.y = alto
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", tamano)
	return boton

func _etiqueta(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta

func _destacar(boton: Button, activo: bool):
	if activo:
		boton.add_theme_color_override("font_color", COLOR_ENCABEZADO)
	else:
		boton.remove_theme_color_override("font_color")

func _vaciar(contenedor: Container):
	for hijo in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()

func _actualizar_foco():
	# Evita que la navegación del mando salga a controles detrás del panel.
	var fila: Array = _botones_pestana.values()
	fila.append(cerrar)
	for i in fila.size():
		var boton: Button = fila[i]
		boton.focus_neighbor_left = boton.get_path_to(fila[posmod(i - 1, fila.size())])
		boton.focus_neighbor_right = boton.get_path_to(fila[(i + 1) % fila.size()])
		boton.focus_neighbor_top = NodePath(".")
		boton.focus_neighbor_bottom = boton.get_path_to(_botones_ficha[0])
	for i in _botones_ficha.size():
		var boton: Button = _botones_ficha[i]
		boton.focus_neighbor_top = boton.get_path_to(_botones_ficha[i - 1] if i > 0 else _botones_pestana[pestana_actual])
		boton.focus_neighbor_bottom = boton.get_path_to(_botones_ficha[mini(i + 1, _botones_ficha.size() - 1)])
		boton.focus_neighbor_left = NodePath(".")
		boton.focus_neighbor_right = NodePath(".")

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not event.is_echo() and (event.is_action_pressed("Atras", false, true) or event.is_action_pressed("Pausa", false, true) or event.is_action_pressed("Abrir Codice", false, true)):
		get_viewport().set_input_as_handled()
		_cerrar()
	elif event.is_action_pressed("Alternar Desafio", true, true):
		lectura.scroll_vertical -= 180
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Mejorar Arbol", true, true):
		lectura.scroll_vertical += 180
		get_viewport().set_input_as_handled()

func _cerrar():
	if is_queued_for_deletion():
		return
	set_process_input(false)
	hide()
	queue_free()
	cerrada.emit()
