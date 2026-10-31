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

var tamano := "pequeno"
var vida := 100
var enemigos_en_rango: Array = []
var escala_base := Vector2.ONE

@onready var rango: Area2D = $Arbol/Rango
@onready var forma: CollisionShape2D = $Arbol/Rango/CollisionShape2D
@onready var temporizador: Timer = $TemporizadorDisparo
@onready var sprite: AnimatedSprite2D = $Arbol


func _ready():
	escala_base = sprite.scale
	rango.body_entered.connect(_on_body_entered)
	rango.body_exited.connect(_on_body_exited)
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

	temporizador.wait_time = 1.0 / (BALAS_POR_SEGUNDO_BASE * datos["vel_ataque"])
	temporizador.start()


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
	return STATS[tamano]["costo"]


func recibir_dano(cantidad: int):
	vida -= cantidad
	if vida <= 0:
		murio.emit()
		queue_free()


func _on_body_entered(body):
	if body.is_in_group("enemigo") and not enemigos_en_rango.has(body):
		enemigos_en_rango.append(body)
		print("Enemigo entró al rango: ", body.name)


func _on_body_exited(body):
	if enemigos_en_rango.has(body):
		enemigos_en_rango.erase(body)


func _disparar():
	_limpiar_enemigos_muertos()
	if enemigos_en_rango.is_empty():
		return

	# El primero que entró suele ser el más adelantado en el camino
	var objetivo = _mas_adelantada()
	var semilla = semilla_escena.instantiate()
	semilla.global_position = global_position
	semilla.objetivo = objetivo
	semilla.dano = DANO_BALA
	get_parent().add_child(semilla)


func _limpiar_enemigos_muertos():
	enemigos_en_rango = enemigos_en_rango.filter(
		func(enemigo): return is_instance_valid(enemigo)
	)

func _mas_adelantada():
	var mejor = null
	var menor := INF
	for e in enemigos_en_rango:
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
		sprite.play("idle")
