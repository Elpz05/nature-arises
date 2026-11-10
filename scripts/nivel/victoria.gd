extends CanvasLayer

@export var sonido_hover: AudioStream
@export var musica_victoria: AudioStream
@export var campana_finalizada := false

const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"   # ajusta a tu ruta real
const INTERFAZ = preload("res://fuentes/interfaz.tres")
const RETRATOS = preload("res://scripts/HUD/retratos_unidad.gd")
const HUD = preload("res://scripts/HUD/hud.gd")
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const ESCALA_UI = preload("res://scripts/HUD/escala_interfaz.gd")

var numero_nivel := 0
var guardado_correcto := true
var desbloqueos: Array = []          # nombres de plantas, los asigna el nivel
var desbloqueos_ataques: Array = [] 
var contenedor: VBoxContainer
var hover_boton: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	if musica_victoria != null:
		MusicaManager.reproducir(musica_victoria)
		
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	panel.theme = INTERFAZ
	centro.add_child(panel)

	contenedor = VBoxContainer.new()
	contenedor.add_theme_constant_override("separation", 16)
	panel.add_child(contenedor)
	
	hover_boton = AudioStreamPlayer.new()
	hover_boton.stream = sonido_hover
	hover_boton.bus = "UI"
	add_child(hover_boton)
	
	_mostrar_victoria()

func _limpiar() -> void:
	for c in contenedor.get_children():
		contenedor.remove_child(c)
		c.queue_free()

func _titulo(texto: String, tam := 42) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"TituloPixel"
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	contenedor.add_child(l)
	ESCALA_UI.aplicar(l, Ajustes.escala_ui())
	return l

func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(300, 64)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(accion)
	b.mouse_entered.connect(_on_hover)
	contenedor.add_child(b)
	ESCALA_UI.aplicar(b, Ajustes.escala_ui())
	return b

func _mostrar_victoria() -> void:
	if campana_finalizada or Guardado.es_ultimo_nivel(numero_nivel):
		_mostrar_final_campana()
		return
	_limpiar()
	_titulo("¡Nivel %d superado!" % (numero_nivel + 1))
	_mostrar_estado_guardado(_mostrar_victoria)
	var siguiente := _boton("Siguiente nivel", _siguiente)
	siguiente.grab_focus()
	_boton("Salir", _salir)

func _siguiente() -> void:
	if campana_finalizada or Guardado.es_ultimo_nivel(numero_nivel):
		_mostrar_final_campana()
		return
	if desbloqueos.is_empty() and desbloqueos_ataques.is_empty():
		_ir_al_siguiente_nivel()
	else:
		_mostrar_desbloqueo()

func _mostrar_desbloqueo() -> void:
	_limpiar()
	_titulo("¡Nuevos desbloqueos!", 32)
	var poderes_restantes := desbloqueos_ataques.duplicate()
	if not desbloqueos.is_empty():
		_titulo("Plantas", 22)
		for planta: Dictionary in desbloqueos:
			var fila := HBoxContainer.new()
			fila.alignment = BoxContainer.ALIGNMENT_CENTER
			fila.add_theme_constant_override("separation", 12)
			contenedor.add_child(fila)
			fila.add_child(RETRATOS.crear(planta.retrato, 52))
			var nombre := Label.new()
			nombre.text = planta.nombre
			nombre.add_theme_font_size_override("font_size", 30)
			fila.add_child(nombre)
			if poderes_restantes.has(planta.get("indice", -1)):
				poderes_restantes.erase(planta.indice)
				nombre.text += " · Planta y poder"
	if not poderes_restantes.is_empty():
		_titulo("Ataques elementales", 22)
		for indice: int in poderes_restantes:
			var nombre := _titulo(HUD.ATAQUES[indice].nombre, 28)
			nombre.add_theme_color_override("font_color", ICONOS.ICONOS[ICONOS.ELEMENTOS[indice]][0])
	_mostrar_estado_guardado(_mostrar_desbloqueo)
	ESCALA_UI.aplicar(contenedor, Ajustes.escala_ui())
	_boton("Continuar", _ir_al_siguiente_nivel).grab_focus()

func _ir_al_siguiente_nivel() -> void:
	if campana_finalizada or Guardado.es_ultimo_nivel(numero_nivel):
		_mostrar_final_campana()
		return
	get_tree().paused = false
	Guardado.ir_a_nivel(numero_nivel + 1)

func _mostrar_final_campana():
	campana_finalizada = true
	_limpiar()
	_titulo("¡Campaña completada!", 36)
	_titulo("Has protegido el bosque.\n¡Gracias por jugar!", 24)
	_mostrar_estado_guardado(_mostrar_final_campana)
	_boton("Volver a partidas", _salir).grab_focus()
	_boton("Menú principal", _ir_al_menu)

func _mostrar_estado_guardado(redibujar: Callable) -> void:
	if guardado_correcto:
		return
	_titulo("No se pudo guardar el progreso.", 24)
	_boton("Reintentar guardado", func():
		if Guardado.registrar_victoria(numero_nivel):
			guardado_correcto = true
			redibujar.call()
	)

func _ir_al_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/escenas_menu/menu.tscn")

func _salir() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(ESCENA_SLOTS)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("Atras"):
		get_viewport().set_input_as_handled()
		_salir()

func _on_hover() -> void:
	if sonido_hover != null:
		hover_boton.play()
