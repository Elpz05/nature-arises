extends SceneTree

# No saves are written. Optional --capture-ui captures a rendered preview.
var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _run():
	var save = root.get_node("Guardado")
	var settings = root.get_node("Ajustes")
	var original_config: ConfigFile = settings.config
	settings.config = ConfigFile.new()
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level.set_process(false)
		_check(not level.hud.panel_combate.visible and level.hud.panel_estado.visible, "The debug HUD must default to off")
		_check(level.hud.label_estado_basico.text.contains("Gotas: 3") and level.hud.label_estado_basico.text.contains("Pozo 0/5"), "The compact HUD must show essential economy information")
		await process_frame
		_check(level.hud.panel_preparacion.visible and level.hud.punto_sobre_hud(Vector2(640, 150)), "The pre-wave briefing must be visible and intercept clicks with debug off")
		settings.hud_debug_cambiado.emit(true)
		var expected := 4 if index == 0 else 6
		_check(level.hud.ultimo_resumen.restantes == expected, "HUD must preview the next wave")
		_check(level.hud.label_entrantes.text.contains("Natura pequeño: 4"), "Preview must name incoming sizes and counts")
		level._iniciar_ronda()
		level._process(0.0)
		_check(level.hud.ultimo_resumen.por_aparecer == expected - 1, "Spawning must reduce pending count")
		_check(level.hud.ultimo_resumen.activos == 1 and level.hud.ultimo_resumen.restantes == expected, "Spawned enemies must move from pending to active")
		# Add a marked splitter at a known position.
		level._crear_espiritu("natura", "mediano", 160.0, null, true)
		var source = level.ruta.get_child(level.ruta.get_child_count() - 1).get_child(0)
		_check(source.obtener_estado_combate().contains("Se divide"), "A splitter visibly warns the player while alive")
		source.recibir_dano(source.vida)
		level._actualizar_combate_hud()
		_check(level.hud.ultimo_resumen.activos == 2, "Copies must count while their dying source is excluded")
		var copy = level.ruta.get_child(level.ruta.get_child_count() - 1).get_child(0)
		_check(copy.vida_maxima == 500 and is_equal_approx(copy.obtener_porcentaje_vida(), 1.0) and not copy.es_divisor, "Copies retain size and health without inheriting the trait")
		copy.recibir_dano(125)
		_check(is_equal_approx(copy.obtener_porcentaje_vida(), 0.75), "Damage must update the health fraction")
		copy.aplicar_lentitud(0.6, 2.0)
		_check(copy.obtener_estado_combate() == "Lento 40%", "Slow status must identify its strength")
		copy._physics_process(3.0)
		_check(copy.obtener_estado_combate().is_empty(), "Expired slow status must disappear")
		copy.aplicar_ataque_elemental("Natura", 0)
		_check(copy.obtener_estado_combate() == "Detenido", "Natura stun must show combat status")
		copy._physics_process(0.6)
		_check(copy.obtener_estado_combate().is_empty(), "Expired stun status must disappear")
		copy.get_parent().progress_ratio = 1.0
		copy._physics_process(0.0)
		level._actualizar_combate_hud()
		_check(level.hud.ultimo_resumen.activos == 1, "Escaped enemies must leave the active count")
		level._crear_espiritu("natura", "mediano", 170.0, null, true)
		var splitter = level.ruta.get_child(level.ruta.get_child_count() - 1).get_child(0)
		splitter.recibir_dano(splitter.vida)
		var normal = level.ruta.get_child(level.ruta.get_child_count() - 1).get_child(0)
		var before_death: int = level.ruta.get_child_count()
		normal.recibir_dano(normal.vida)
		_check(level.ruta.get_child_count() == before_death, "An unmarked Natura clone never splits")
		if index == 1:
			level._crear_espiritu("flamma", "pequeno", 200.0)
			var fire_path = level._ruta_para_tipo("flamma")
			var fire = fire_path.get_child(fire_path.get_child_count() - 1).get_child(0)
			var count: int = level._resumen_combate().activos
			fire.recibir_dano(150)
			_check(is_equal_approx(fire.obtener_porcentaje_vida(), 1.0) and fire.obtener_estado_combate() == "Renaciendo", "Flamma revival must refill its bar and show status")
			_check(level._resumen_combate().activos == count, "Reviving Flamma must remain in the active count")
			fire.recibir_dano(150)
			_check(level._resumen_combate().activos == count - 1, "Dead shortcut enemies must leave the active count immediately")
			_check(fire.obtener_porcentaje_vida() == 0.0, "Lethal damage must clamp the health fraction")
		level.gotas = 100
		var cells: Array = level.parcelas_secano.slice(0, 2)
		for type in 2:
			var cell: Vector2i = cells[type]
			_check(level._plantar(cell, type), "All tower scenes must support inspection")
			var tower = level.arboles_plantados[cell]
			var drops: int = level.gotas
			level._mostrar_info_torre(cell)
			_check(level.gotas == drops, "Hover inspection must not spend drops")
			level.celda_torre_seleccionada = cell
			level._actualizar_tooltip()
			_check(level.torre_informada == tower, "Selected tower info must remain when the cursor leaves the tower")
			_check(tower.rango_visible and level.panel_torre.visible, "Inspection must show range and stats")
			_check(level.tooltip.text.contains("Nivel 1/3") and level.tooltip.text.contains("Disparos/s:"), "Overlay must show level and actual attack rate")
			_check(level.tooltip.text.contains("Daño: %d" % tower.dano_bala), "Overlay must use tower damage data")
			_check(level.tooltip.text.contains("%d gotas" % level._costo_mejora(cell)), "Overlay must show the charged upgrade cost")
			level._mejorar_arbol(cell)
			level._mostrar_info_torre(cell)
			_check(level.tooltip.text.contains("Nivel 2/3"), "Inspection must update after an upgrade")
			_check(is_equal_approx(tower.obtener_estadisticas().radio, 160.0 if type == 0 else 192.0), "Inspected range must update with upgrades")
			level._mejorar_arbol(cell)
			level._mostrar_info_torre(cell)
			_check(level.tooltip.text.contains("Tamaño máximo"), "Max-level towers must not display a nonexistent upgrade")
			level._quitar_arbol(cell)
			_check(not level.panel_torre.visible and not tower.rango_visible, "Selling the inspected tower must clear its overlay and range")
		level._mostrar_info_torre(Vector2i(29, 16))
		_check(not level.panel_torre.visible, "Empty cells must not leave stale info visible")
		level._plantar(cells[0], 0)
		var inspected = level.arboles_plantados[cells[0]]
		level._mostrar_info_torre(cells[0])
		level._abrir_pausa()
		_check(not level.panel_torre.visible and not inspected.rango_visible, "Pause must hide tower info and its range")
		level.pausa._continuar()
		await process_frame
		var rect: Rect2 = level.hud.panel_combate.get_global_rect()
		_check(root.get_visible_rect().encloses(rect), "Wave panel must fit inside the viewport")
		_check(level.hud.punto_sobre_hud(rect.get_center()), "The combat panel must block placement behind it")
		level._mostrar_info_torre(cells[0])
		settings.hud_debug_cambiado.emit(false)
		_check(not level.hud.panel_combate.visible and level.hud.panel_estado.visible and not inspected.rango_visible, "Disabling debug must clear the current tower range")
		level.free()
	var tutorial = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(tutorial)
	tutorial.set_process(false)
	tutorial.ronda = 2
	tutorial._actualizar_ronda_hud()
	_check(tutorial.hud.label_amenazas.text.contains("Natura divisor ×1"), "The normal briefing announces the authored splitter")
	tutorial._iniciar_ronda()
	for i in 5:
		tutorial._actualizar_spawn(tutorial._intervalo_spawn())
	var marked: Array = tutorial._bestias_vivas().filter(func(enemy): return enemy.es_divisor)
	_check(marked.size() == 1 and marked[0].tamano == "mediano", "The campaign recipe spawns exactly the marked Natura")
	tutorial.free()
	if OS.get_cmdline_user_args().has("--capture-ui"):
		settings.config.set_value("interfaz", "hud_debug", true)
		await _capture_preview()
	settings.config = original_config
	save.slot_actual = original_slot
	await process_frame
	print("Combat feedback checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)

func _capture_preview():
	var level = load("res://escenas/escenas_niveles/nivel_1.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level.hud.SEMILLAS_ACTIVAS = [0, 1, 2]
	level.hud.ATAQUES_ACTIVOS = [0, 1, 2]
	level.gotas = 20
	level.hud.actualizar_gotas(20)
	for type in 2:
		level._plantar(level.parcelas_secano[type + 1], type)
	for entry in [["natura", 350.0], ["natura", 500.0], ["flamma", 680.0], ["aqua", 860.0]]:
		level._crear_espiritu(entry[0], "mediano", entry[1])
		var path = level._ruta_para_tipo(entry[0])
		var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
		enemy.recibir_dano(100)
		if entry[0] == "aqua":
			enemy.aplicar_lentitud(0.6, 2.0)
		if entry[0] == "flamma":
			enemy.recibir_dano(1000)
		enemy.set_physics_process(false)
	level._iniciar_ronda()
	level._actualizar_combate_hud()
	level._mostrar_info_torre(Vector2i(11, 3))
	for tower in level.arboles_plantados.values():
		tower.temporizador.stop()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://tests/combat_feedback_preview.png")
	_check(error == OK, "Rendered feedback preview must save")
	level.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
