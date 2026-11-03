extends Node2D

signal gota_recogida(cantidad: int)

@export var gota_escena: PackedScene
@export_range(0.1, 60.0) var intervalo_generacion := 4.0
@export_range(1, 100) var valor_gota := 1
@export_range(1.0, 120.0) var duracion_gota := 20.0
@export_range(1, 5) var maximo_gotas := 5

const POSICIONES := [Vector2(-52, 0), Vector2(-26, 46), Vector2(26, 46), Vector2(52, 0), Vector2(0, -52)]
var puede_generar: Callable
var puede_recoger: Callable
var generando := false
@onready var temporizador: Timer = $Temporizador
@onready var gotas: Node2D = $Gotas

func _ready():
	temporizador.wait_time = intervalo_generacion
	temporizador.timeout.connect(_generar_gota)
	temporizador.paused = true
	temporizador.start()

func _draw():
	draw_circle(Vector2.ZERO, 27, Color(0.35, 0.32, 0.28))
	draw_circle(Vector2(0, -4), 21, Color(0.7, 0.72, 0.73))
	draw_circle(Vector2(0, -4), 14, Color(0.05, 0.3, 0.5))
	draw_string_outline(ThemeDB.fallback_font, Vector2(-19, 43), "Pozo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-19, 43), "Pozo", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var ayuda := "Recoge gotas"
	var ancho := ThemeDB.fallback_font.get_string_size(ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(ThemeDB.fallback_font, Vector2(-ancho / 2.0, 80), ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-ancho / 2.0, 80), ayuda, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func activar_generacion(activa: bool):
	generando = activa
	temporizador.paused = not activa

func _generar_gota():
	if not generando or get_tree().paused or gota_escena == null:
		return
	if puede_generar.is_valid() and not puede_generar.call():
		return
	var ocupadas: Array[int] = []
	for gota in gotas.get_children():
		if not gota.procesada and not gota.is_queued_for_deletion():
			ocupadas.append(gota.casilla_pozo)
	if ocupadas.size() >= maximo_gotas:
		return
	for indice in POSICIONES.size():
		if ocupadas.has(indice):
			continue
		var gota = gota_escena.instantiate()
		gota.valor = valor_gota
		gota.duracion = duracion_gota
		gota.casilla_pozo = indice
		gota.puede_recoger = puede_recoger
		gota.position = POSICIONES[indice]
		gota.recogida.connect(_on_gota_recogida)
		gotas.add_child(gota)
		return

func recoger_en_punto(punto_global: Vector2) -> bool:
	for gota in gotas.get_children():
		if gota.contiene_punto(punto_global) and gota.intentar_recoger():
			return true
	return false

func _on_gota_recogida(cantidad: int):
	gota_recogida.emit(cantidad)
