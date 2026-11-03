class_name Arbol
extends Node2D

signal murio

const TAMANO_CELDA := 64
const DANO_BALA := 20
const BALAS_POR_SEGUNDO_BASE := 2.0
const ESCALA := {"pequeno": 1.0, "mediano": 1.25, "grande": 1.5}

# Todas las estadísticas en un solo lugar
const STATS := {
	"pequeno": {"vida": 100, "costo": 1, "radio": 2.0, "vel_ataque": 1.0},
	"mediano": {"vida": 200, "costo": 2, "radio": 2.5, "vel_ataque": 1.2},
	"grande":  {"vida": 300, "costo": 3, "radio": 3.0, "vel_ataque": 1.5},
}

@export var semilla_escena: PackedScene
@export var dano_bala := DANO_BALA
@export var balas_por_segundo := BALAS_POR_SEGUNDO_BASE
@export var costos: Array[int] = [1, 2, 3]
@export var radio_explosion := 0.0
@export_range(0.1, 1.0) var factor_lentitud := 1.0
@export var duracion_lentitud := 0.0
@export var color_bala := Color(0.125, 1, 0)

var tamano := "pequeno"
var vida := 100
var enemigos_en_rango: Array = []
var escala_base := Vector2.ONE
var rango_visible := false

@onready var rango: Area2D = $Arbol/Rango
@onready var forma: CollisionShape2D = $Arbol/Rango/CollisionShape2D
@onready var temporizador: Timer = $TemporizadorDisparo
@onready var sprite: AnimatedSprite2D = $Arbol


func _ready():
	escala_base = sprite.scale
	temporizador.process_callback = Timer.TIMER_PROCESS_PHYSICS
	temporizador.timeout.connect(_disparar)
	_aplicar_tamano("pequeno")

func _aplicar_tamano(nuevo: String):
	tamano = nuevo
	var datos: Dictionary = STATS[tamano]
	vida = datos["vida"]
	_actualizar_sprite()

	var circulo := CircleShape2D.new()
	circulo.radius = datos["radio"] * TAMANO_CELDA / sprite.scale.x
	forma.shape = circulo

	temporizador.wait_time = 1.0 / (balas_por_segundo * datos["vel_ataque"])
	temporizador.start()
	queue_redraw()

func obtener_estadisticas() -> Dictionary:
	return {
		"dano": dano_bala,
		"disparos_segundo": 1.0 / temporizador.wait_time,
		"radio": float(STATS[tamano].radio) * TAMANO_CELDA,
		"radio_explosion": radio_explosion,
		"factor_lentitud": factor_lentitud,
		"duracion_lentitud": duracion_lentitud,
	}

# Consulta antes de _ready(): la vista previa no activa timers ni dispara.
func obtener_datos_colocacion() -> Dictionary:
	var visual: Node2D = get_node("Arbol")
	var area: Node2D = get_node("Arbol/Rango")
	var colision: Node2D = get_node("Arbol/Rango/CollisionShape2D")
	return {
		"radio": float(STATS["pequeno"].radio) * TAMANO_CELDA,
		"centro": visual.transform * (area.transform * colision.position),
	}

func mostrar_rango(mostrar: bool):
	if rango_visible != mostrar:
		rango_visible = mostrar
		queue_redraw()

func _draw():
	if not rango_visible or not is_instance_valid(forma) or forma.shape == null:
		return
	var centro := to_local(forma.global_position)
	var radio: float = forma.shape.radius * absf(forma.global_scale.x / global_scale.x)
	draw_circle(centro, radio, Color(0.2, 0.8, 1.0, 0.12))
	draw_arc(centro, radio, 0.0, TAU, 64, Color(0.3, 0.9, 1.0, 0.8), 2.0, true)


# Sube al siguiente tamaño (pequeno -> mediano -> grande)
func mejorar() -> bool:
	if tamano == "pequeno":
		_aplicar_tamano("mediano")
		return true
	if tamano == "mediano":
		_aplicar_tamano("grande")
		return true
	return false   # ya está al máximo


func obtener_costo() -> int:
	return costos[["pequeno", "mediano", "grande"].find(tamano)]


func recibir_dano(cantidad: int):
	vida -= cantidad
	if vida <= 0:
		murio.emit()
		queue_free()


func _physics_process(_delta: float):
	# Area2D ya calcula solapamientos en física. Usa su lista en caché,
	# sin escanear todos los enemigos ni conservar referencias obsoletas.
	enemigos_en_rango = rango.get_overlapping_bodies().filter(_es_objetivo_valido)

func _es_objetivo_valido(enemigo) -> bool:
	if not is_instance_valid(enemigo) or not enemigo.is_inside_tree() or enemigo.is_queued_for_deletion():
		return false
	if not enemigo.is_in_group("enemigo") or enemigo.muerto:
		return false
	var seguidor := enemigo.get_parent() as PathFollow2D
	if seguidor == null or seguidor.is_queued_for_deletion():
		return false
	var recorrido := seguidor.get_parent() as Path2D
	return recorrido != null and not recorrido.is_queued_for_deletion() and recorrido.curve != null


func _disparar():
	_limpiar_enemigos_muertos()
	if enemigos_en_rango.is_empty():
		return

	# El primero que entró suele ser el más adelantado en el camino
	var objetivo = _mas_adelantada()
	if not _es_objetivo_valido(objetivo) or semilla_escena == null or not rango.overlaps_body(objetivo):
		return
	var semilla = semilla_escena.instantiate()
	semilla.objetivo = objetivo
	semilla.dano = dano_bala
	semilla.radio_explosion = radio_explosion
	semilla.factor_lentitud = factor_lentitud
	semilla.duracion_lentitud = duracion_lentitud
	semilla.color_bala = color_bala
	get_parent().add_child(semilla)
	semilla.global_position = global_position


func _limpiar_enemigos_muertos():
	enemigos_en_rango = enemigos_en_rango.filter(_es_objetivo_valido)

func _mas_adelantada():
	var mejor = null
	var menor := INF
	for e in enemigos_en_rango:
		if not _es_objetivo_valido(e):
			continue
		var seg := e.get_parent() as PathFollow2D
		var largo: float = (seg.get_parent() as Path2D).curve.get_baked_length()
		var faltante: float = largo - seg.progress
		if faltante < menor:
			menor = faltante
			mejor = e
	return mejor

func _actualizar_sprite():
	var anim := "idle_" + tamano
	if sprite.sprite_frames.has_animation(anim):
		# Dibujo propio para este tamaño: no hace falta escalarlo
		sprite.scale = escala_base
		sprite.play(anim)
	else:
		# Respaldo: la animación "idle" agrandada
		sprite.scale = escala_base * ESCALA[tamano]
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
