extends SceneTree

# No saves are written. Uses actual input dispatch for collection conflicts.
var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _pending(well) -> Array:
	return well.gotas.get_children().filter(func(drop): return not drop.procesada and not drop.is_queued_for_deletion())

func _mouse(drop, pressed: bool):
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = drop.get_global_transform_with_canvas().origin
	root.push_input(event, true)

func _run():
	var save = root.get_node("Guardado")
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level.set_process(false)
		var well = level.pozo
		_check(is_instance_valid(well) and not level._se_puede_plantar(level.celda_pozo), "Each level must reserve a functional well cell")
		well._generar_gota()
		_check(_pending(well).is_empty(), "Wells must not generate between waves")
		level._iniciar_ronda()
		well.temporizador.start(0.05)
		await create_timer(0.07).timeout
		_check(not _pending(well).is_empty(), "A running Timer must actually produce a drop")
		well.temporizador.start(well.intervalo_generacion)
		for item in _pending(well):
			item.expiracion.start(0.04)
		await create_timer(0.06).timeout
		_check(_pending(well).is_empty() and level.gotas == 3, "Actual item timers must expire drops without currency")
		level._process(4.0)
		_check(level.gotas == 3, "Elapsed time alone must never grant currency")
		well.temporizador.timeout.emit()
		_check(_pending(well).size() == 1 and level.gotas == 3, "Timer must spawn an item instead of currency")
		var drop = _pending(well)[0]
		level._on_semilla_pulsada(0, false)
		_check(is_equal_approx(level.datos_rango_colocacion.radio, 128.0), "Plant selection must prepare its initial range")
		_mouse(drop, true)
		_mouse(drop, false)
		_check(level.gotas == 4 and level.arboles_plantados.is_empty(), "Collecting while planting must grant currency without planting underneath")
		_check(not drop.intentar_recoger() and level.gotas == 4, "Collected items must never grant currency twice")
		_check(level.hud.label_gotas.text == "Gotas: 4", "Collection must update HUD affordability immediately")
		well._generar_gota()
		drop = _pending(well)[0]
		level._on_ataque_pulsado(0, false)
		var charges: int = level.cargas[0]
		_mouse(drop, true)
		_mouse(drop, false)
		_check(level.cargas[0] == charges and level.gotas == 5, "Collection must not cast a selected ability")
		well._generar_gota()
		drop = _pending(well)[0]
		level._on_semilla_pulsada(0, true)
		_mouse(drop, false)
		_check(level.gotas == 6 and level.arboles_plantados.is_empty(), "Dragging a plant onto a drop must collect without planting")
		level._deseleccionar()
		for unused in 8:
			well._generar_gota()
		_check(_pending(well).size() == 5, "The well must cap uncollected items")
		drop = _pending(well)[0]
		var amount: int = level.gotas
		drop._expirar()
		_check(level.gotas == amount and not drop.intentar_recoger(), "Expired items must grant no currency")
		well._generar_gota()
		_check(_pending(well).size() == 5, "Expiration must free a spawn slot")
		drop = _pending(well)[0]
		level._abrir_pausa()
		var time_left: float = drop.expiracion.time_left
		await process_frame
		await process_frame
		well._generar_gota()
		_check(not drop.intentar_recoger() and level.gotas == amount, "Paused items must not be collectible")
		_check(is_equal_approx(drop.expiracion.time_left, time_left), "Pause must freeze item expiration")
		level.pausa._continuar()
		await process_frame
		level.cola_bestias.clear()
		for path in [level.ruta] + level.rutas_enemigos.values():
			for follower in path.get_children():
				follower.free()
		level._terminar_ronda()
		_check(well.temporizador.paused, "Wave completion must pause well generation")
		_check(drop.intentar_recoger() and level.gotas == amount + 1, "Existing drops must remain collectible between waves")
		for type in 3:
			level.hud.SEMILLAS_ACTIVAS = [0, 1, 2]
			level._on_semilla_pulsada(type, false)
			var data: Dictionary = level.datos_rango_colocacion.duplicate()
			var row := 4 if index == 0 else 3
			var cell := Vector2i(type, row)
			level._plantar(cell, type)
			var tower = level.arboles_plantados[cell]
			var actual_radius: float = tower.forma.shape.radius * tower.forma.global_scale.x
			_check(is_equal_approx(data.radio, actual_radius), "Preview radius must match the placed tower's actual range")
			_check(data.centro.is_equal_approx(tower.to_local(tower.forma.global_position)), "Preview must include the collision shape offset")
			level._deseleccionar()
			_check(level.datos_rango_colocacion.is_empty(), "Canceling placement must clear range preview state")
		level._iniciar_ronda()
		well._generar_gota()
		level._on_espiritu_llego(level.arbol_meta.vida)
		_check(well.temporizador.paused, "Defeat must stop generation")
		for item in _pending(well):
			_check(not item.intentar_recoger(), "Outcome screens must block collection")
		paused = false
		level.free()
	if OS.get_cmdline_user_args().has("--capture-ui"):
		await _capture_preview()
	save.slot_actual = original_slot
	await process_frame
	print("Well economy checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)

func _capture_preview():
	var level = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level._iniciar_ronda()
	for unused in 4:
		level.pozo._generar_gota()
	level._on_semilla_pulsada(0, false)
	root.warp_mouse(Vector2(544, 352))
	await process_frame
	await process_frame
	level.vista.queue_redraw()
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://tests/well_preview.png")
	_check(error == OK, "Well and placement preview must render")
	level.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
