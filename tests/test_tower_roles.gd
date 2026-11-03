extends SceneTree

# Godot --headless --path . --script res://tests/test_tower_roles.gd
# Player saves are not written. Unlock data is supplied in memory.
var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	var previous_data: Dictionary = save.datos.duplicate(true)
	save.slot_actual = -1
	var locked = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(locked)
	locked._on_semilla_pulsada(1, false)
	_check(locked.seleccion_tipo == "", "Flamma must remain locked for a new player")
	locked._on_semilla_pulsada(2, false)
	_check(locked.seleccion_tipo == "", "Aqua must remain locked for a new player")
	locked.free()
	save.slot_actual = 0
	save.datos = {"plantas": [0, 1, 2], "ataques": [0]}

	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level.set_process(false)
		var row := 4 if index == 0 else 3
		var fire_cell := Vector2i(0, row)
		var water_cell := Vector2i(1, row)
		level.gotas = 40
		level.hud.actualizar_gotas(level.gotas)
		for entry in [[1, fire_cell], [2, water_cell]]:
			level._on_semilla_pulsada(entry[0], false)
			level._confirmar(level.suelo.map_to_local(entry[1]))
		_check(level.arboles_plantados.size() == 2, "Unlocked towers must plant in level %d" % index)
		_check(level.gotas == 31, "Planting must charge 3 + 6 drops")
		var fire = level.arboles_plantados[fire_cell]
		var water = level.arboles_plantados[water_cell]
		_check(fire.get_node("Arbol/Placeholder").color.r > 0.9, "Flamma must use its orange placeholder")
		_check(water.get_node("Arbol/Placeholder").color.b > 0.9, "Aqua must use its blue placeholder")
		for progress in [96.0, 128.0, 300.0]:
			level._crear_espiritu("natura", "mediano", progress)
		var target = level.ruta.get_child(0).get_child(0)
		var nearby = level.ruta.get_child(1).get_child(0)
		var distant = level.ruta.get_child(2).get_child(0)
		for enemy in [target, nearby, distant]:
			enemy.set_physics_process(false)
		await physics_frame
		await physics_frame
		_check(fire.enemigos_en_rango.has(target), "Actual Area2D must detect enemies for Flamma")
		_check(water.enemigos_en_rango.has(target), "Actual Area2D must detect enemies for Aqua")
		fire.enemigos_en_rango = [target]
		fire._disparar()
		var fire_bullet = level.arboles.get_child(level.arboles.get_child_count() - 1)
		fire_bullet._process(2.0)
		_check(target.vida == 470 and nearby.vida == 470, "Flamma must splash both nearby enemies exactly once")
		_check(distant.vida == 500, "Flamma must not damage enemies outside its splash radius")
		fire_bullet._process(2.0)
		_check(target.vida == 470, "Queued projectiles must not hit twice")
		water.enemigos_en_rango = [target]
		water._disparar()
		var water_bullet = level.arboles.get_child(level.arboles.get_child_count() - 1)
		water_bullet._process(2.0)
		_check(target.vida == 460 and nearby.vida == 470, "Aqua must damage only its target")
		_check(is_equal_approx(target.factor_lentitud, 0.6), "Aqua must apply 40% slow")
		var before: float = target.get_parent().progress
		target._physics_process(0.5)
		_check(is_equal_approx(target.get_parent().progress - before, target.velocidad * 0.6 * 0.5), "Slow must reduce actual path movement")
		target.aplicar_lentitud(0.6, 2.0)
		_check(is_equal_approx(target.factor_lentitud, 0.6) and is_equal_approx(target.lentitud_restante, 2.0), "Repeated slows must refresh without stacking")
		target._physics_process(3.0)
		_check(is_equal_approx(target.factor_lentitud, 1.0) and target.lentitud_restante == 0.0, "Slow must expire and restore normal speed")
		for cell in [fire_cell, water_cell]:
			level._mejorar_arbol(cell)
			level._mejorar_arbol(cell)
			_check(level.arboles_plantados[cell].tamano == "grande", "Both towers must support all upgrade sizes")
		_check(level.gotas == 4, "Upgrades must charge 4 + 5 + 8 + 10 drops")
		level._quitar_arbol(fire_cell)
		level._quitar_arbol(water_cell)
		_check(level.gotas == 40 and level.arboles_plantados.is_empty(), "Shovel must refund all investment and free occupied cells")
		level.free()

	save.slot_actual = previous_slot
	save.datos = previous_data
	await process_frame
	print("Tower role checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
