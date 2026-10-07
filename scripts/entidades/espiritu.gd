extends CharacterBody2D

signal llego_a_meta

var vida := 100
var velocidad := 80.0

func _ready():
	add_to_group("enemigo")

func _process(delta):
	var seguidor := get_parent() as PathFollow2D
	seguidor.progress += velocidad * delta
	if seguidor.progress_ratio >= 1.0:
		llego_a_meta.emit()
		seguidor.queue_free()

func recibir_dano(cantidad: int):
	vida -= cantidad
	print("Vida espíritu: ", vida)
	if vida <= 0:
		get_parent().queue_free()
