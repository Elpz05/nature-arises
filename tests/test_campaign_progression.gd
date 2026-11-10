extends SceneTree

class SaveHarness extends "res://scripts/menu/guardado.gd":
	var writes := 0
	func guardar():
		writes += 1
		return true

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _clear(level):
	for path in [level.ruta] + level.rutas_enemigos.values():
		for follower in path.get_children():
			follower.free()

func _victory(level):
	for child in level.get_children():
		if child is CanvasLayer and child.get_script() == load("res://scripts/nivel/victoria.gd"):
			return child
	return null

func _probar_transicion_en_disco(save, temp_path: String):
	var slot := -1
	for index in save.TOTAL_SLOTS:
		if not save.existe(index):
			slot = index
			break
	_check(slot >= 0, "Disk regression requires an unused slot")
	if slot < 0:
		return
	save._ruta_codice = temp_path + ".disco"
	save._codice = ConfigFile.new()
	save._codice_pendiente = false
	for fixture in [{"version": 2, "nivel_actual": 1}, {"version": 1, "nivel_actual": 1, "plantas": [0, 1], "ataques": [0, 1]}]:
		var archivo := FileAccess.open(save._ruta(slot), FileAccess.WRITE)
		_check(archivo != null, "Write a new isolated save fixture")
		if archivo == null:
			return
		archivo.store_string(JSON.stringify(fixture))
		archivo.close()
		save.entrar(slot)
		await scene_changed
		var nivel = current_scene
		_check(nivel.numero_nivel == 1 and nivel.hud.SEMILLAS_ACTIVAS.has(2), "Level 2 has Aqua before the first clear")
		nivel._ganar_nivel()
		var victoria = _victory(nivel)
		_check(victoria.guardado_correcto and victoria.desbloqueos.size() == 1 and victoria.desbloqueos[0].nombre == "Terra" and victoria.desbloqueos_ataques == [3], "The victory writes the slot and announces only Terra")
		victoria._siguiente()
		var etiquetas: Array[Node] = victoria.contenedor.find_children("*", "Label", true, false)
		_check(etiquetas.filter(func(etiqueta): return etiqueta.text.begins_with("Terra")).size() == 1, "The Terra plant and power share one visible reward")
		victoria._ir_al_siguiente_nivel()
		await scene_changed
		_check(current_scene.numero_nivel == 2 and current_scene.hud.SEMILLAS_ACTIVAS == [0, 1, 2, 3], "Next stage still owns Aqua and Terra")
		_check(current_scene.hud.botones_semilla[2].tooltip_text.contains("Requiere una poza"), "Unavailable terrain has a reason distinct from a lock")
		save.entrar(slot)
		await scene_changed
		_check(current_scene.numero_nivel == 2 and current_scene.hud.ATAQUES_ACTIVOS == [0, 1, 2, 3] and current_scene.hud.SEMILLAS_ACTIVAS == [0, 1, 2, 3], "Reload preserves both tools")
		save.ir_a_nivel(1)
		await scene_changed
		current_scene._ganar_nivel()
		victoria = _victory(current_scene)
		_check(victoria.desbloqueos.is_empty() and victoria.desbloqueos_ataques.is_empty(), "Replay does not announce an earned unlock")

	# Force an I/O failure, then retry through the real victory overlay.
	var ruta_correcta: String = save._ruta_codice
	save._ruta_codice = temp_path.path_join("no-existe/codice.cfg")
	save.ir_a_nivel(7)
	await scene_changed
	current_scene._ganar_nivel()
	var final = _victory(current_scene)
	_check(not final.guardado_correcto and save.todo_desbloqueado(), "Failed profile write keeps the session unlock and exposes retry")
	_check(save.leer(slot).campana_completada, "Slot completion persists independently")
	save._ruta_codice = ruta_correcta
	for boton in final.contenedor.find_children("*", "Button", true, false):
		if boton.text == "Reintentar guardado":
			boton.pressed.emit()
			break
	_check(final.guardado_correcto, "Retry verifies the completed profile")
	save.borrar(slot)
	save._codice = ConfigFile.new()
	save._ready()
	_check(save.todo_desbloqueado(), "A profile reload survives deletion of the completed slot")
	save.entrar(slot)
	await scene_changed
	_check(current_scene.numero_nivel == 0 and current_scene.hud.SEMILLAS_ACTIVAS == range(7) and current_scene.hud.ATAQUES_ACTIVOS == range(7), "A genuinely new slot starts at Level 1 with all tools")
	for especie in ["natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum"]:
		_check(save.entrada_descubierta("bestias", especie), "The reloaded profile reveals every bestiary entry")
	save.borrar(slot)
	paused = false
	unload_current_scene()
	DirAccess.remove_absolute(ruta_correcta)

func _run():
	var profile := SaveHarness.new()
	profile.datos = profile.datos_nuevos()
	_check(profile.NIVELES.size() == 8 and profile.VERSION_GUARDADO == 2, "Expanded campaign has eight levels and a versioned save migration")
	for legacy in [{"version": 1, "nivel_actual": 2, "campana_completada": true}, {"nivel_actual": 2}, {"version": 1, "campana_completada": true}]:
		var migrated: Dictionary = profile.validar_datos(legacy)
		_check(migrated.version == 2 and migrated.nivel_actual == 2 and migrated.niveles_completados == [0, 1] and not migrated.campana_completada, "Old two-level completion resumes at the first new stage without skipping content")
		_check(migrated.plantas == [0, 1, 2, 3] and migrated.ataques == [0, 1, 2, 3], "Migration grants the tools required for the next stage")
		_check(profile.validar_datos(migrated) == migrated, "Migration is idempotent")
	var extras: Dictionary = profile.validar_datos({"version": 1, "nivel_actual": 1, "plantas": [0, 6], "nota": "conservar"})
	_check(extras.nota == "conservar" and extras.plantas.has(6) and extras.nivel_actual == 1, "Migration preserves extra fields and already-owned units")
	var singleton = root.get_node("Guardado")
	var old_slot: int = singleton.slot_actual
	var old_data: Dictionary = singleton.datos.duplicate(true)
	var old_codice: ConfigFile = singleton._codice
	var old_path: String = singleton._ruta_codice
	var old_pending: bool = singleton._codice_pendiente
	var temp_path := OS.get_environment("TEMP").path_join("codice-campana-%d.cfg" % OS.get_process_id())
	singleton._codice = ConfigFile.new()
	singleton._codice_pendiente = false
	singleton._ruta_codice = temp_path
	var climates := ["despejado", "lluvia", "despejado", "tormenta", "volcan", "ventisca", "derrumbe", "radiacion"]
	var plants := [[0], [0, 1, 2], [0, 1, 2, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 4, 5, 6]]
	var spells := [[0], [0, 1, 2], [0, 1, 2, 3], [0, 1, 2, 3, 4], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 4, 5, 6]]
	var total_waves := 0
	for index in 8:
		_check(profile.datos.nivel_actual == index and not profile.datos.campana_completada, "Completing each stage advances to the next available stage")
		singleton.slot_actual = 0
		singleton.datos = profile.datos.duplicate(true)
		var level = load(profile.NIVELES[index]).instantiate()
		root.add_child(level)
		level.set_process(false)
		level.set_physics_process(false)
		_check(level.inicializado and level.numero_nivel == index and level.clima == climates[index], "Every registered campaign scene has the correct stage and climate")
		_check(level.hud.SEMILLAS_ACTIVAS == plants[index] and level.hud.ATAQUES_ACTIVOS == spells[index], "Actual HUD exposes exactly the earned tools before each stage")
		_check(not level.titulo_nivel.is_empty() and not level.consejo_nivel.is_empty() and level.hud.label_mision.text.contains("%d/8" % (index + 1)), "Every stage explains its objective in the HUD")
		_check(level.gotas == [3, 3, 8, 10, 12, 14, 16, 24][index] and level.rondas.size() == 5, "Initial economy and five-wave structure match the campaign pacing")
		var legal := 0
		for y in range(level.FILAS_BLOQUEADAS, level.ALTO):
			for x in level.ANCHO:
				var cell := Vector2i(x, y)
				var dry: bool = level._se_puede_plantar(cell, 0)
				var wet: bool = level._se_puede_plantar(cell, 2)
				var terra: bool = level._se_puede_plantar(cell, 3)
				_check(dry == level.parcelas_secano.has(cell) and wet == level.celdas_inundadas.has(cell), "Dry and wet planting must match authored plots")
				var junto_al_camino := false
				for direccion in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					junto_al_camino = junto_al_camino or level._es_camino(cell + direccion)
				var camino_seco: bool = level._celda_valida_terreno(cell) and level._es_camino(cell) and not wet
				var terra_esperada: bool = level.puestos_terra.has(cell) if index == 5 else camino_seco or (dry and junto_al_camino)
				_check(terra == terra_esperada, "Terra obeys the winter posts and the other stages' original rules")
				if dry or wet:
					legal += 1
		_check(level.limitar_plantado and legal >= 10 and legal <= 17, "Every campaign stage must have a small, finite number of build sites")
		for id in 7:
			if not plants[index].has(id):
				level._on_semilla_pulsada(id, false)
				_check(level.seleccion_tipo == "", "Future trees cannot be selected early")
			if not spells[index].has(id):
				level._on_ataque_pulsado(id, false)
				_check(level.seleccion_tipo == "", "Future spells cannot be selected early")
		if index == 1:
			_check(level._se_puede_plantar(Vector2i(7, 4), 2), "Rain stage makes its newly available Aqua plant usable")
		if index == 4:
			_check(level.celdas_geiser.size() == 2, "Volcano stage includes authored geysers")
		if index == 6:
			_check(level.rutas_adicionales.is_empty() and level.puntos_ruta[1].y - level.puntos_ruta[0].y == 12, "Collapse stage uses the intended vertical route")
		# All recipes can instantiate their actual enemy scenes.
		for number in range(1, level.rondas.size() + 1):
			for key in level._contar_bestias(level._plan_de_ronda(number, true)):
				var parts := String(key).split(":")
				level._crear_espiritu(parts[0], parts[1])
				_check(level._bestias_vivas().size() > 0, "Every wave recipe resolves to a configured enemy scene")
				_check(singleton.entrada_descubierta("bestias", parts[0]), "Spawning an enemy discovers its Codex entry")
		_clear(level)
		# Victory uses the real wave/outcome path. Saving is exercised separately
		# with the in-memory harness so player files are never written.
		singleton.slot_actual = -1
		for wave in 5:
			level._iniciar_ronda()
			var count := 0
			var expected: int = level._plan_de_ronda(wave + 1, false).size()
			while not level.cola_bestias.is_empty():
				level._actualizar_spawn(level._intervalo_spawn())
				count += level._bestias_vivas().size()
				_clear(level)
			_check(count == expected, "Real wave spawning preserves recipe counts")
			level._actualizar_spawn(0.0)
			total_waves += 1
		_check(level.terminado and paused, "Last wave opens a terminal victory overlay")
		var victory = _victory(level)
		_check(victory != null and victory.campana_finalizada == (index == 7), "Only the eighth stage displays final campaign completion")
		if index < 7:
			victory._mostrar_desbloqueo()
			_check(victory.desbloqueos.size() == level.desbloqueos.size() and victory.desbloqueos_ataques.size() == level.desbloqueos_ataques.size(), "Victory announces the exact stage rewards")
			if index == 1:
				_check(victory.desbloqueos[0].nombre == "Terra" and victory.desbloqueos[0].retrato.textura != null and victory.desbloqueos_ataques == [3], "Level 2 awards Terra with its sprite and does not re-award Aqua")
		paused = false
		level.free()
		profile.completar_nivel(index)
	_check(total_waves == 40 and profile.datos.nivel_actual == 8 and profile.datos.campana_completada and profile.writes == 8, "All forty waves lead to persistent final completion")
	var recargado := ConfigFile.new()
	_check(recargado.load(temp_path) == OK and recargado.get_value("progreso", "completada", false), "A slotless Level 8 win persists global completion")
	singleton._codice = recargado
	singleton.slot_actual = -1
	singleton.datos = singleton.datos_nuevos()
	_check(singleton.plantas_activas() == range(7) and singleton.ataques_activos() == range(7), "A fresh save inherits all tools after campaign completion")
	profile.completar_nivel(0)
	_check(profile.datos.nivel_actual == 8 and profile.datos.plantas == [0, 1, 2, 3, 4, 5, 6] and profile.datos.ataques == [0, 1, 2, 3, 4, 5, 6], "Replay cannot regress progress or duplicate earned rewards")
	_check(profile.escena_para_nivel(8) == profile.ESCENA_CAMPANA and profile.escena_para_nivel(2) == profile.NIVELES[2], "Resume routing reaches new content or the actual final outcome")
	await _probar_transicion_en_disco(singleton, temp_path)
	singleton.slot_actual = old_slot
	singleton.datos = old_data
	singleton._codice = old_codice
	singleton._ruta_codice = old_path
	singleton._codice_pendiente = old_pending
	DirAccess.remove_absolute(temp_path)
	profile.free()
	await process_frame
	print("Expanded campaign checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
