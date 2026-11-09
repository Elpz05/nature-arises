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

func _shot(level, target, candidates: Array, cap: int = 3):
	var shot = load("res://escenas/escenas_balas/descarga.tscn").instantiate()
	shot.elemento = "electricitas"
	shot.dano = 10
	shot.maximo_objetivos = cap
	shot.objetivo = target
	shot.candidatos = candidates.duplicate()
	level.arboles.add_child(shot)
	shot.global_position = Vector2(96, 224)
	shot.set_process(false)
	return shot

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	var locked = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(locked)
	locked._on_semilla_pulsada(4, false)
	_check(locked.seleccion_tipo == "", "Electricitas respects campaign unlocks")
	locked.free()
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	_check(level.hud.SEMILLAS_ACTIVAS.has(4), "Laboratory enables Electricitas")
	level.clima = "despejado"
	level.gotas = 14
	level.hud.actualizar_gotas(14)
	level._on_semilla_pulsada(4, false)
	_check(level.datos_rango_colocacion.radio == 160.0, "Placement preview has 2.5-cell range")
	var cell := Vector2i(1, 3)
	level._confirmar(level.suelo.map_to_local(cell))
	var tower = level.arboles_plantados[cell]
	tower.temporizador.stop()
	_check(level.gotas == 12 and tower.vida == 200 and is_equal_approx(tower.obtener_estadisticas().disparos_segundo, 3.0), "Small Electricitas costs 2, has 200 HP and fires three times/s")
	level._mejorar_arbol(cell)
	_check(level.gotas == 8 and tower.vida == 400 and tower.obtener_estadisticas().radio == 192.0 and tower.obtener_estadisticas().objetivos == 5, "Medium upgrade costs 4 with 400 HP, range 3 and five targets")
	level._mejorar_arbol(cell)
	_check(level.gotas == 0 and tower.vida == 600 and tower.obtener_estadisticas().radio == 224.0 and tower.obtener_estadisticas().objetivos == 7, "Large upgrade costs 8 with 600 HP, range 3.5 and seven targets")
	tower.temporizador.stop()
	level._mostrar_info_torre(cell)
	_check(level.tooltip.text.contains("Encadena hasta 7 bestias"), "Inspection describes chaining")
	_check(not level._plantar(Vector2i(6, 4), 4), "Electricitas cannot plant on roads")
	for size in ["pequeno", "mediano", "grande"]:
		tower._aplicar_tamano(size)
		tower.temporizador.stop()
		var enemies: Array = []
		for i in 8:
			enemies.append(_enemy(level, "aqua", 16.0 + i * 16.0))
		var distant = _enemy(level, "aqua", 900.0)
		await physics_frame
		await physics_frame
		await physics_frame
		_check(tower.enemigos_en_rango.has(enemies[7]) and not tower.enemigos_en_rango.has(distant), "Physics range supplies only nearby chain candidates")
		tower._disparar()
		var shot = level.arboles.get_child(level.arboles.get_child_count() - 1)
		shot.set_process(false)
		_check(shot.objetivo == enemies[7], "Chain begins at the beast closest to the mother tree")
		shot._physics_process(0.01)
		var cap: int = tower.obtener_estadisticas().objetivos
		_check(shot.golpeados.size() == cap, "Each size respects its 3/5/7 total target cap")
		for i in 8:
			_check(is_equal_approx(enemies[i].vida, 489.0 if i >= 8 - cap else 500.0), "Nearest-neighbor hops deal exactly 11 damage to Aqua, once per victim")
		_check(distant.vida == 500.0, "The chain cannot hit a beast outside tower detection")
		shot._physics_process(0.5)
		_check(shot.is_queued_for_deletion() and is_equal_approx(enemies[7].vida, 489.0), "The visual expires without repeating damage")
		for enemy in enemies + [distant]:
			enemy.get_parent().queue_free()
		await process_frame
	# A gap cannot be bridged, even when every target is in the supplied list.
	var a = _enemy(level, "aqua", 0.0)
	var b = _enemy(level, "aqua", 64.0)
	var c = _enemy(level, "aqua", 256.0)
	var gap_shot = _shot(level, a, [a, a, b, c, null])
	gap_shot._physics_process(0.0)
	_check(gap_shot.golpeados == [a, b] and c.vida == 500.0, "A chain skips duplicates and stops at a gap larger than two cells")
	var resistant = _enemy(level, "aqua", 400.0)
	resistant.tipo = "electricitas"
	gap_shot._golpear(resistant)
	_check(resistant.vida == 495.0, "Electricitas beast resistance reduces base damage by 50 percent")
	gap_shot.modificador_dano = 0.25
	gap_shot._golpear(resistant)
	_check(resistant.vida == 487.5, "Weather and resistance are additive: rain deals 7.5")
	gap_shot.modificador_dano = 0.35
	var hp: float = b.vida
	gap_shot._golpear(b)
	_check(is_equal_approx(hp - b.vida, 14.5), "Storm plus Aqua vulnerability deals 14.5 damage")
	var dead = _enemy(level, "aqua", 20.0)
	dead.get_parent().queue_free()
	var invalid = _shot(level, dead, [a, b])
	invalid._physics_process(0.0)
	_check(invalid.is_queued_for_deletion(), "A queued initial target cancels the shot safely")
	var fire = _enemy(level, "flamma", 20.0)
	fire.vida = 1.0
	var revival = _shot(level, fire, [fire, fire], 7)
	revival._physics_process(0.0)
	_check(fire.renacio and fire.vida == fire.vida_maxima and revival.golpeados.size() == 1, "A revived beast is not hit twice by the same chain")
	level._quitar_arbol(cell)
	_check(level.gotas == 0, "Shovel does not refund Electricitas")
	for weather in ["lluvia", "tormenta"]:
		level.clima = weather
		level._plantar(cell, 4)
		var wet_tower = level.arboles_plantados[cell]
		_check(is_equal_approx(wet_tower.obtener_estadisticas().disparos_segundo, 2.25 if weather == "lluvia" else 1.5), "Weather modifies cadence")
		_check(is_equal_approx(wet_tower.modificador_dano, 0.25 if weather == "lluvia" else 0.35), "Weather configures Electricitas damage bonus")
		wet_tower.temporizador.stop()
		level._quitar_arbol(cell)
	level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Electricitas checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
