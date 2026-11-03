extends Node2D

var radio := 160.0
var color := Color.WHITE
var restante := 0.4

func _ready():
	z_index = 9
	queue_redraw()

func _process(delta: float):
	restante -= delta
	if restante <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw():
	var alpha := clampf(restante / 0.4, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radio, Color(color, alpha * 0.12))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 64, Color(color, alpha * 0.85), 3.0, true)
