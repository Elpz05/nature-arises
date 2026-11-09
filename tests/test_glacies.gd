extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String, progress: float):
	level._crear_espiritu(tipo, "mediano", progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _icicle(level, enemies: Array, cap: int):
	var bullet = load("res://escenas/escenas_balas/carambano.tscn").instantiate()
	bullet.elemento = "glacies"
	bullet.dano = 2
	bullet.duracion_congelacion = 2.0
	bullet.maximo_objetivos = cap
	bullet.distancia_maxima = 256.0
	bullet.objetivo = enemies[0]
	level.arboles.add_child(bullet)
	bullet.global_position = level.ruta.to_global(level.ruta.curve.sample_baked(0.0))
	bullet.set_process(false)
	return bullet

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	_check(level.hud.SEMILLAS_ACTIVAS.has(5), "Laboratory enables Glacies without changing unlock IDs")
	level.clima = "despejado"
	level.gotas = 16
	level.hud.actualizar_gotas(16)
	level._on_semilla_pulsada(5, false)
	_check(level.datos_rango_colocacion.radio == 192.0, "Glacies preview has three-cell range")
	var cell := Vector2i(0, 3)
	level._confirmar(level.suelo.map_to_local(cell))
	var tower = level.arboles_plantados[cell]
	tower.temporizador.stop()
	_check(level.gotas == 13 and tower.vida == 150, "Small Glacies costs 3 and has 150 HP")
	_check(tower.obtener_estadisticas().disparos_segundo == 1.0, "Base cadence is one icicle/s")
	level._mejorar_arbol(cell)
	_check(level.gotas == 8 and tower.vida == 300 and tower.obtener_estadisticas().radio == 224.0 and tower.obtener_estadisticas().objetivos == 4, "Medium Glacies costs 5 with 300 HP, 3.5 range and four victims")
	level._mejorar_arbol(cell)
	_check(level.gotas == 0 and tower.vida == 600 and tower.obtener_estadisticas().radio == 256.0 and tower.obtener_estadisticas().objetivos == 5, "Large Glacies costs 8 with 600 HP, four-cell range and five victims")
	tower.temporizador.stop()
	level._mostrar_info_torre(cell)
	_check(level.tooltip.text.contains("Penetra hasta 5 bestias") and level.tooltip.text.contains("Congela 2.0 s"), "Inspection describes penetration and freeze")
	_check(not level._plantar(Vector2i(6, 4), 5), "Glacies cannot plant on roads")
	for cap in [3, 4, 5]:
		var enemies: Array = []
		# Reverse spawn order verifies sorting by collision distance.
		for progress in [160.0, 144.0, 128.0, 112.0, 96.0, 80.0]:
			enemies.append(_enemy(level, "aqua", progress))
		var bullet = _icicle(level, enemies, cap)
		bullet._physics_process(1.0)
		var hit := 0
		for enemy in enemies:
			if enemy.congelacion_restante > 0.0:
				hit += 1
				_check(is_equal_approx(enemy.vida, 497.8), "Aqua receives exactly 2.2 fractional damage")
		_check(hit == cap and bullet.is_queued_for_deletion(), "A long frame hits at most the size-specific limit")
		_check(enemies[5].congelacion_restante == 2.0 and enemies[0].congelacion_restante == 0.0, "The nearest intersections are hit first")
		bullet._physics_process(1.0)
		_check(is_equal_approx(enemies[5].vida, 497.8), "Queued icicles cannot hit twice")
		for enemy in enemies:
			enemy.get_parent().queue_free()
		await process_frame
	# A non-collinear enemy must not receive area damage.
	var near = _enemy(level, "aqua", 80.0)
	var off_line = _enemy(level, "aqua", 80.0)
	off_line.position.y += 40.0
	var shot = _icicle(level, [near], 3)
	shot._physics_process(0.21)
	_check(is_equal_approx(near.vida, 497.8) and off_line.vida == 500.0, "Icicles penetrate a line rather than an explosion")
	shot._physics_process(0.01)
	_check(is_equal_approx(near.vida, 497.8), "One icicle never hits the same enemy in consecutive segments")
	shot._physics_process(5.0)
	_check(shot.is_queued_for_deletion(), "Icicles expire at their maximum travel range")
	var before: float = near.get_parent().progress
	near._physics_process(1.0)
	_check(near.get_parent().progress == before and near.obtener_estado_combate().contains("Congelado"), "Frozen beasts cannot advance")
	paused = true
	near._physics_process(10.0)
	_check(near.congelacion_restante == 1.0, "Pause freezes the freeze timer")
	paused = false
	near.aplicar_congelacion(2.0)
	near.aplicar_congelacion(2.0)
	_check(near.congelacion_restante == 2.0, "Repeated freezes refresh without adding durations")
	near._physics_process(2.5)
	_check(is_equal_approx(near.get_parent().progress - before, near.velocidad * 0.5) and near.congelacion_restante == 0.0, "Movement resumes for the unfrozen fraction of a long frame")
	var fire = _enemy(level, "flamma", 300.0)
	shot._golpear(fire)
	_check(is_equal_approx(fire.vida, 447.7), "Flamma receives 2.3 damage from Glacies")
	var future_ice = _enemy(level, "aqua", 400.0)
	future_ice.tipo = "glacies"
	shot._golpear(future_ice)
	_check(is_equal_approx(future_ice.vida, 498.2), "Glacies damage resistance retains 1.8 fractional damage")
	var flame = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	flame.elemento = "flamma"
	flame.dano = 40
	level.arboles.add_child(flame)
	flame.set_process(false)
	near.aplicar_congelacion(2.0)
	var hp: float = near.vida
	flame._golpear(near)
	_check(near.congelacion_restante == 0.0 and near.vida == hp, "Flamma thaws even an Aqua beast immune to its damage")
	fire.recibir_dano(1000.0)
	fire.aplicar_congelacion(2.0)
	flame._golpear(fire)
	_check(fire.congelacion_restante == 0.0 and fire.detenido == 3.0, "Thaw does not cancel Flamma's resurrection delay")
	# Real tower targeting and projectile configuration through Area2D physics.
	for enemy in level._bestias_vivas():
		enemy.get_parent().queue_free()
	await process_frame
	var target = _enemy(level, "aqua", 100.0)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(tower.enemigos_en_rango.has(target), "Glacies detects beasts through its actual physics range")
	tower._disparar()
	var actual = level.arboles.get_child(level.arboles.get_child_count() - 1)
	actual.set_process(false)
	_check(actual.objetivo == target and actual.maximo_objetivos == 5 and actual.duracion_congelacion == 2.0, "Tower emits a size-configured icicle")
	actual._physics_process(1.0)
	_check(target.congelacion_restante == 2.0, "A tower-fired icicle freezes its target on impact")
	level._quitar_arbol(cell)
	_check(level.gotas == 0 and not level.arboles_plantados.has(cell), "Glacies shovel does not refund water")
	level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Glacies checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
