extends Node2D

var objetivo: Node2D
var dano := 0
var velocidad := 400.0


func _process(delta):
	# Si el objetivo murió o desapareció, la semilla se destruye
	if not is_instance_valid(objetivo):
		queue_free()
		return

	# Teledirigida: recalcula la dirección en cada fotograma
	var direccion := (objetivo.global_position - global_position).normalized()
	global_position += direccion * velocidad * delta

	# Impacto
	if global_position.distance_to(objetivo.global_position) < 10.0:
		if objetivo.has_method("recibir_dano"):
			objetivo.recibir_dano(dano)
		queue_free()
