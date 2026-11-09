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
	if vida_maxima > 0:
		ICONOS.dibujar_vida(self, Vector2(0, -37), 46.0, float(vida) / vida_maxima)

func recibir_dano(cantidad: int):
	if vida <= 0 or cantidad <= 0:
		return
	var aplicado := mini(cantidad, vida)
	vida -= aplicado
	queue_redraw()
	dano_recibido.emit(aplicado, false)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		murio.emit()
