extends Node2D

signal vida_cambiada(actual: int, maxima: int)
signal murio
signal dano_recibido(cantidad: float, periodico: bool)
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")

@export var vida_maxima := 20
var vida: int

func _ready():
	vida = vida_maxima
	vida_cambiada.emit(vida, vida_maxima)

func _draw():
	ICONOS.dibujar(self, "meta", Vector2.ZERO, 3.25)

func recibir_dano(cantidad: int):
	if vida <= 0 or cantidad <= 0:
		return
	var aplicado := mini(cantidad, vida)
	vida -= aplicado
	dano_recibido.emit(aplicado, false)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		murio.emit()
