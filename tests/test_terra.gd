extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String, progress: float):
	level._crear_espiritu(tipo, "pequeno", progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		level.bestias_escenas.assign([
			load("res://escenas/escenas_espiritu/espiritu_prueba.tscn"),
			load("res://escenas/escenas_espiritu/espiritu_flamma.tscn"),
			load("res://escenas/escenas_espiritu/espiritu_aqua.tscn"),
		])
		root.add_child(level)
		level.set_process(false)
		var road := Vector2i(4, level.puntos_ruta[0].y)
		var entry := 224.0
		level._on_semilla_pulsada(3, false)
		_check(level.seleccion_tipo == "", "Terra respects campaign unlocks")
		level.hud.SEMILLAS_ACTIVAS = [0, 1, 2, 3]
		level.gotas = 18
		level.hud.actualizar_gotas(18)
		level._on_semilla_pulsada(3, false)
		_check(level.seleccion_tipo == "semilla" and level.seleccion_indice == 3, "Terra can be selected when unlocked")
		level._confirmar(level.suelo.map_to_local(road))
		_check(level.gotas == 15 and level.arboles_plantados.has(road), "Terra costs 3 and can plant on a dry road")
		var terra = level.arboles_plantados[road]
		_check(terra.vida == 1000 and terra.temporizador.is_stopped(), "Small Terra has 1000 HP and no firing timer")
		var count: int = level.arboles.get_child_count()
		terra._disparar()
		_check(level.arboles.get_child_count() == count, "Terra emits no projectiles")
		_check(not level._plantar(road, 3) and not level._plantar(road, 0), "Terra reserves one entire cell")
		level._mostrar_info_torre(road)
		_check(level.tooltip.text.contains("Empuje: 0.5") and level.tooltip.text.contains("1000"), "Inspection explains Terra health and knockback")
		var nature = _enemy(level, "natura", entry - 1.0)
		nature._physics_process(0.1)
		_check(is_equal_approx(nature.get_parent().progress, entry - 32.0) and terra.vida == 950, "Natura deals 50 and is pushed back half a cell")
		nature.get_parent().progress = entry - 1.0
		nature._physics_process(0.1)
		_check(is_equal_approx(nature.get_parent().progress, entry) and terra.vida == 950, "Contact cooldown blocks without damage every physics tick")
		nature._physics_process(1.0)
		_check(terra.vida == 900 and nature.get_parent().progress < entry, "Contact can attack again after one second")
		var fire = _enemy(level, "flamma", entry - 1.0)
		fire._physics_process(0.1)
		_check(terra.vida == 800 and fire.get_parent().progress < entry, "Flamma independently deals 100 on the shared route")
		var water = _enemy(level, "aqua", entry - 1.0)
		water._physics_process(3.0)
		_check(water.get_parent().progress > entry + 64.0 and terra.vida == 800, "Aqua passes through Terra without contact damage")
		level._mejorar_arbol(road)
		_check(terra.vida == 2000 and level.gotas == 9, "Medium upgrade costs 6 and grants 2000 HP")
		nature.recarga_contacto = 0.0
		nature.get_parent().progress = entry - 1.0
		nature._physics_process(0.1)
		_check(is_equal_approx(nature.get_parent().progress, entry - 44.8), "Medium Terra pushes 0.7 cells")
		level._mejorar_arbol(road)
		_check(terra.vida == 3000 and level.gotas == 0, "Large upgrade costs 9 and grants 3000 HP")
		nature.recarga_contacto = 0.0
		nature.get_parent().progress = 0.0
		nature._physics_process(30.0)
		_check(is_equal_approx(nature.get_parent().progress, entry - 64.0) and terra.vida == 2950, "Swept movement cannot tunnel through Terra with a large delta")
		paused = true
		var before: float = nature.get_parent().progress
		nature._physics_process(10.0)
		_check(nature.get_parent().progress == before and terra.vida == 2950, "Pause freezes contact and movement")
		paused = false
		terra.vida = 50
		nature.get_parent().progress = entry - 1.0
		nature.recarga_contacto = 0.0
		nature._physics_process(0.1)
		_check(not level.arboles_plantados.has(road) and terra.is_queued_for_deletion(), "Lethal contact destroys Terra and immediately frees its slot")
		_check(not level._se_puede_plantar(road, 0), "Destroyed Terra leaves road terrain reserved")
		nature.get_parent().progress = entry - 1.0
		nature._physics_process(3.0)
		_check(nature.get_parent().progress > entry + 64.0, "Enemies resume their route after Terra dies")
		level._plantar(road, 3)
		level._quitar_arbol(road)
		_check(level.gotas == 0 and level._se_puede_plantar(road, 3), "Shovel removes Terra without refund and permits replacement")
		level.clima = "lluvia"
		level.celdas_inundadas.assign([road])
		_check(not level._plantar(road, 3), "Terra cannot plant on flooded roads")
		level._plantar(Vector2i(4, 3 if index == 1 else 4), 3)
		nature.get_parent().progress = entry - 1.0
		nature.recarga_contacto = 0.0
		nature._physics_process(3.0)
		_check(nature.get_parent().progress > entry + 64.0, "A grass Terra does not block an adjacent road")
		if index == 1:
			# Shortcut-only cell; compare against its actual route coordinates.
			var shortcut_cell := Vector2i(26, 8)
			_check(level._plantar(shortcut_cell, 3), "Terra also plants on a dry elemental shortcut")
			var blocker = level.arboles_plantados[shortcut_cell]
			var path = level._ruta_para_tipo("flamma")
			var offset: float = path.curve.get_closest_offset(path.to_local(blocker.global_position))
			fire.get_parent().progress = offset - 33.0
			fire.recarga_contacto = 0.0
			fire._physics_process(0.1)
			_check(blocker.vida == 900 and is_equal_approx(fire.get_parent().progress, offset - 64.0), "Blocking and knockback follow the shortcut's vertical segment")
		level.terminado = true
		before = nature.get_parent().progress
		nature._physics_process(10.0)
		_check(nature.get_parent().progress == before, "Outcome freezes enemy movement")
		level.free()
	save.slot_actual = previous_slot
	await process_frame
	var lab = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	_check(lab.hud.SEMILLAS_ACTIVAS.has(3) and lab.rondas[0].has("aqua:pequeno"), "F6 laboratory enables Terra and includes Aqua to exercise its bypass")
	lab._plantar(Vector2i(4, 4), 3)
	var live = _enemy(lab, "natura", 223.9)
	live.set_physics_process(true)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(lab.arboles_plantados[Vector2i(4, 4)].vida == 950 and live.get_parent().progress < 224.0, "Actual physics ticks trigger blocking and contact")
	lab.free()
	print("Terra checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
