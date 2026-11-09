extends CanvasLayer

signal cerrada

const CONTENIDO = preload("res://scripts/guia/contenido_guia.gd")
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const COLOR_ENCABEZADO := Color(0.68, 0.92, 0.65)

# Se asigna antes de agregar la guía al árbol. Vacío en el menú.
var fichas_nivel: Array = []
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
	cerrar.pressed.connect(_cerrar)
	var navegacion := "Dirección para navegar · Confirmar para abrir · Atrás para cerrar"
	%Pie.text = navegacion if fichas_nivel.is_empty() else "Partida en pausa · " + navegacion
	if not fichas_nivel.is_empty():
		_agregar_capitulo("nivel", "Nivel actual", fichas_nivel)
	_agregar_capitulo("jugar", "Cómo jugar", CONTENIDO.como_jugar())
	_agregar_capitulo("bestias", "Bestias", CONTENIDO.bestias())
	_agregar_capitulo("arboles", "Árboles", CONTENIDO.arboles())
	_agregar_capitulo("poderes", "Poderes", CONTENIDO.poderes())
	_mostrar_capitulo("jugar" if fichas_nivel.is_empty() else "nivel")
	_botones_pestana[pestana_actual].grab_focus()

func _agregar_capitulo(id: String, texto: String, fichas: Array):
	_capitulos[id] = fichas
	var boton := _boton(texto, 50, 22)
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
		var boton := _boton(texto, 48, 21)
		indice.add_child(boton)
		_botones_ficha.append(boton)
		boton.focus_entered.connect(_mostrar_ficha.bind(i))
		boton.pressed.connect(_mostrar_ficha.bind(i))
	_actualizar_foco()
	_mostrar_ficha(0)

func _mostrar_ficha(i: int):
	ficha_actual = i
	for j in _botones_ficha.size():
		_destacar(_botones_ficha[j], j == i)
	var ficha: Dictionary = _capitulos[pestana_actual][i]
	_vaciar(detalle)
	detalle.add_child(_etiqueta(ficha.titulo, 32, Color.WHITE))
	for seccion in ficha.secciones:
		var destino: Container = detalle
		if seccion.size() > 2:
			var fila := HBoxContainer.new()
			fila.add_theme_constant_override("separation", 12)
			detalle.add_child(fila)
			var icono := Control.new()
			var id: String = seccion[2]
			var lleno: bool = seccion.size() > 3 and seccion[3]
			icono.custom_minimum_size.x = 28
			fila.add_child(icono)
			icono.draw.connect(func(): ICONOS.dibujar(icono, id, Vector2(14, 15), 1.5, true, lleno))
			destino = fila
		var bloque := VBoxContainer.new()
		bloque.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bloque.add_theme_constant_override("separation", 4)
		destino.add_child(bloque)
		bloque.add_child(_etiqueta(seccion[0], 22, COLOR_ENCABEZADO))
		bloque.add_child(_etiqueta(seccion[1], 22, Color(0.91, 0.95, 0.92)))
	lectura.scroll_vertical = 0

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
	elif event.is_action_pressed("Atras", false, true) or event.is_action_pressed("Pausa", false, true):
		get_viewport().set_input_as_handled()
		_cerrar()

func _cerrar():
	if is_queued_for_deletion():
		return
	set_process_input(false)
	hide()
	queue_free()
	cerrada.emit()
