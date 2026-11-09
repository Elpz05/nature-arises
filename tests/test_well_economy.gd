extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _mouse(point: Vector2, pressed: bool):
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	root.push_input(event, true)

func _run():
	var save = root.get_node("Guardado")
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level.set_process(false)
		await process_frame
		var well = level.pozo
		var point: Vector2 = well.get_global_transform_with_canvas().origin
		var per_drop: float = 1.0 / level.obtener_produccion_agua()
		_check(not level._se_puede_plantar(level.celda_pozo) and per_drop > 3.0, "Central well reserves its cell and produces at a reduced rate")
		level._actualizar_recursos(100.0)
		_check(well.reserva == 0 and level.gotas == 3, "No resources generate before the round")
		level._iniciar_ronda()
		level._actualizar_recursos(per_drop - 0.1)
		_check(well.reserva == 0, "A partial drop cannot be collected")
		level._actualizar_recursos(0.1)
		level._actualizar_recursos(per_drop * 8.0)
		_check(well.reserva == 5 and level.gotas == 3, "Generation caps at five and never credits the wallet directly")
		_check(level.hud.label_pozo.text.begins_with("Pozo 5/5"), "HUD shows the current well reserve")
		level._on_semilla_pulsada(0, false)
		_check(is_equal_approx(level.datos_rango_colocacion.radio, 128.0), "Plant selection must prepare its initial range")
		_mouse(point + Vector2(40, 0), true)
		_mouse(point + Vector2(40, 0), false)
		_check(well.reserva == 5, "A click outside the well cannot collect it")
		level._on_semilla_pulsada(0, false)
		var planted: int = level.arboles_plantados.size()
		var before: int = level.gotas
		_mouse(point, true)
		_mouse(point, false)
		_check(level.gotas == before + 5 and well.reserva == 0 and level.arboles_plantados.size() == planted, "Clicking the well collects all five without planting")
		_check(not well.recoger() and level.hud.label_gotas.text == "Gotas: %d" % (before + 5), "Collection updates the HUD and cannot be repeated")
		level._actualizar_recursos(per_drop * 0.5)
		_check(well.reserva == 0, "Time spent full does not bank overflow")
		level._actualizar_recursos(per_drop * 2.5)
		level._on_ataque_pulsado(0, false)
		var charges: float = level.cargas[0]
		level._abrir_pausa()
		level._actualizar_recursos(100.0)
		_mouse(point, true)
		_mouse(point, false)
		_check(well.reserva == 3, "Pause freezes the reserve and blocks pickup")
		level.pausa._continuar()
		await process_frame
		level.cola_bestias.clear()
		level._terminar_ronda()
		level._actualizar_recursos(100.0)
		_check(not well.generando and well.reserva == 3, "Between rounds the reserve is retained without generating more")
		before = level.gotas
		_mouse(point, true)
		_mouse(point, false)
		_check(level.cargas[0] == charges and level.gotas == before + 3, "Between-round pickup does not cast a selected ability")
		level._iniciar_ronda()
		level._actualizar_recursos(per_drop * 2.0)
		level._on_semilla_pulsada(0, true)
		before = level.gotas
		_mouse(point, false)
		_check(level.gotas == before + 2 and not level.arrastrando, "Dropping a dragged selection on the well collects the reserve")
		level._actualizar_recursos(per_drop)
		level._on_espiritu_llego(level.arbol_meta.vida)
		_check(not well.generando and not level._recoger_en_objetivo(well.position), "Outcome stops generation and blocks collection")
		paused = false
		level.free()
	save.slot_actual = original_slot
	await process_frame
	print("Well economy checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
