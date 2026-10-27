extends CanvasLayer

@export var sonido_hover: AudioStream

const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"   # ajusta a tu ruta real

var numero_nivel := 0
var desbloqueos: Array = []          # nombres de plantas, los asigna el nivel
var desbloqueos_ataques: Array = [] 
var contenedor: VBoxContainer
var hover_boton: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.1, 0.25, 0.1, 0.95)
	estilo.border_color = Color(0.5, 0.8, 0.4)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	contenedor = VBoxContainer.new()
	contenedor.add_theme_constant_override("separation", 16)
	panel.add_child(contenedor)
	
	hover_boton = AudioStreamPlayer.new()
	hover_boton.stream = sonido_hover
	hover_boton.bus = "SFX"
	add_child(hover_boton)
	
	_mostrar_victoria()

func _limpiar() -> void:
	for c in contenedor.get_children():
		contenedor.remove_child(c)
		c.queue_free()

func _titulo(texto: String, tam := 36) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	contenedor.add_child(l)
	return l

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(260, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(accion)
	b.mouse_entered.connect(_on_hover)
	contenedor.add_child(b)
	return b

func _mostrar_victoria() -> void:
	_limpiar()
	_titulo("¡Nivel %d superado!" % (numero_nivel + 1))
	var siguiente := _boton("Siguiente nivel", _siguiente)
	_boton("Salir", _salir)

func _siguiente() -> void:
	if desbloqueos.is_empty() and desbloqueos_ataques.is_empty():
		_ir_al_siguiente_nivel()
	else:
		_mostrar_desbloqueo()

func _mostrar_desbloqueo() -> void:
	_limpiar()
	_titulo("¡Nuevos desbloqueos!", 32)
	if not desbloqueos.is_empty():
		_titulo("Plantas", 22)
		for nombre in desbloqueos:
			_titulo("🌱 " + str(nombre), 28)
	if not desbloqueos_ataques.is_empty():
		_titulo("Ataques elementales", 22)
		for nombre in desbloqueos_ataques:
			_titulo("✨ " + str(nombre), 28)
	_boton("Continuar", _ir_al_siguiente_nivel)

func _ir_al_siguiente_nivel() -> void:
	get_tree().paused = false
	Guardado.ir_a_nivel(numero_nivel + 1)

func _salir() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_SLOTS)

func _on_hover() -> void:
	if sonido_hover != null:
		hover_boton.play()
