extends Node2D

signal vida_cambiada(actual: int, maxima: int)
signal murio

@export var vida_maxima := 20
var vida: int

func _ready():
	vida = vida_maxima
	vida_cambiada.emit(vida, vida_maxima)

func recibir_dano(cantidad: int):
	if vida <= 0:
		return
	vida = max(vida - cantidad, 0)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		murio.emit()
