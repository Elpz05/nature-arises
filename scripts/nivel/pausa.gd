extends CanvasLayer

@export_file("*.tscn") var escena_salida: String   # menú de slots o menú principal
var numero_nivel := 0                          # lo asigna el nivel
@export var sonido_hover: AudioStream
@export var sonido_abrir: AudioStream

@onready var panel_principal: Control = %PanelPrincipal
@onready var panel_sonido: Control = %PanelSonido
@onready var boton_continuar: Button = %Continuar
@onready var boton_sonido: Button = %Sonido
@onready var boton_salir: Button = %Salir
@onready var check_musica: CheckBox = %CheckMusica
@onready var check_efectos: CheckBox = %CheckEfectos
@onready var boton_atras: Button = %Atras

var hover_boton: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	check_musica.button_pressed = not _bus_silenciado("Music")
	check_efectos.button_pressed = not _bus_silenciado("SFX")

	boton_continuar.pressed.connect(_continuar)
	boton_sonido.pressed.connect(_mostrar_sonido.bind(true))
	boton_atras.pressed.connect(_mostrar_sonido.bind(false))
	boton_salir.pressed.connect(_salir)
	check_musica.toggled.connect(func(on: bool): _silenciar_bus("Music", not on))
	check_efectos.toggled.connect(func(on: bool): _silenciar_bus("SFX", not on))

	hover_boton = AudioStreamPlayer.new()
	hover_boton.stream = sonido_hover
	hover_boton.bus = "SFX"
	add_child(hover_boton)
	
	if sonido_abrir != null:
		var abrir := AudioStreamPlayer.new()
		abrir.stream = sonido_abrir
		abrir.bus = "SFX"
		add_child(abrir)
		abrir.play()
		
	for c in [boton_continuar, boton_sonido, boton_salir, boton_atras, check_musica, check_efectos]:
		c.mouse_entered.connect(_on_hover)
	
	_mostrar_sonido(false)
	
	$Fondo.color = Color(0, 0, 0, 0.55)

	# Ventana pequeña y centrada
	for p in [panel_principal, panel_sonido]:
		p.custom_minimum_size = Vector2(340, 0)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.1, 0.25, 0.1, 0.95)
		estilo.border_color = Color(0.5, 0.8, 0.4)
		estilo.set_border_width_all(3)
		estilo.set_corner_radius_all(12)
		estilo.set_content_margin_all(24)
		p.add_theme_stylebox_override("panel", estilo)

		p.get_child(0).add_theme_constant_override("separation", 14)

	for b in [boton_continuar, boton_sonido, boton_salir, boton_atras]:
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(260, 56)
		b.add_theme_font_size_override("font_size", 24)
	check_musica.add_theme_font_size_override("font_size", 24)
	check_efectos.add_theme_font_size_override("font_size", 24)

func _mostrar_sonido(ver: bool) -> void:
	panel_principal.visible = not ver
	panel_sonido.visible = ver
	if ver:
		check_musica.grab_focus()
	else:
		boton_continuar.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Pausa"):
		if panel_sonido.visible:
			_mostrar_sonido(false)
		else:
			_continuar()
		get_viewport().set_input_as_handled()

func _continuar() -> void:
	get_tree().paused = false
	queue_free()

func _salir() -> void:
	if Guardado.slot_actual >= 0:
		var actual: int = Guardado.datos.get("nivel_actual", 0)
		Guardado.datos["nivel_actual"] = maxi(actual, numero_nivel)
		Guardado.guardar()
	get_tree().paused = false
	if escena_salida != "":
		get_tree().change_scene_to_file(escena_salida)

func _bus_silenciado(nombre: String) -> bool:
	var idx: int = AudioServer.get_bus_index(nombre)
	return idx >= 0 and AudioServer.is_bus_mute(idx)

func _silenciar_bus(nombre: String, silenciar: bool) -> void:
	var idx: int = AudioServer.get_bus_index(nombre)
	if idx < 0:
		push_warning("No existe el bus '%s' en el panel Audio" % nombre)
		return
	AudioServer.set_bus_mute(idx, silenciar)

func _on_hover() -> void:
	if sonido_hover != null:
		hover_boton.play()
