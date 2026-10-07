class_name Arbol
extends Node2D

const TAMANO_CELDA := 64
const DANO_BALA := 20
const BALAS_POR_SEGUNDO_BASE := 2.0

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

@onready var rango: Area2D = $Arbol/Rango
@onready var forma: CollisionShape2D = $Arbol/Rango/CollisionShape2D
@onready var temporizador: Timer = $TemporizadorDisparo


func _ready():
	rango.body_entered.connect(_on_body_entered)
	rango.body_exited.connect(_on_body_exited)
	temporizador.timeout.connect(_disparar)
	_aplicar_tamano("pequeno")


func _aplicar_tamano(nuevo: String):
	tamano = nuevo
	var datos: Dictionary = STATS[tamano]
	vida = datos["vida"]

	# Forma nueva para que no se comparta entre árboles
	var circulo := CircleShape2D.new()
	circulo.radius = datos["radio"] * TAMANO_CELDA
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
	var objetivo = enemigos_en_rango[0]
	var semilla = semilla_escena.instantiate()
	semilla.global_position = global_position
	semilla.objetivo = objetivo
	semilla.dano = DANO_BALA
	get_parent().add_child(semilla)


func _limpiar_enemigos_muertos():
	enemigos_en_rango = enemigos_en_rango.filter(
		func(enemigo): return is_instance_valid(enemigo)
	)
