extends SceneTree

# Godot --headless --path . --script res://tests/test_shared_levels.gd --quit-after 600
# No player saves are written: all levels run with slot_actual = -1.
var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _new_level(index: int):
	var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
	level.celdas_bloqueadas.assign([Vector2i(29, 16)])
	root.add_child(level)
	level.set_process(false)
	_check(level.inicializado, "Inherited level %d must initialize" % index)
	_check(level.get_script().get_base_script() == load("res://scripts/nivel/nivel_base.gd"), "Both level scripts must inherit the shared parent")
	return level

func _clear_enemies(level):
	for path in [level.ruta] + level.rutas_enemigos.values():
		for follower in path.get_children():
			follower.free()

func _check_terminal_actions(level):
	var drops: int = level.gotas
	var hp: int = level.arbol_meta.vida
	var count: int = level.get_child_count()
	level._on_semilla_pulsada(0, false)
	level._on_pala_pulsada(false)
	level._iniciar_ronda()
	level._crear_espiritu()
	level._on_espiritu_llego(1)
	level._process(10.0)
	_check(level.seleccion_tipo == "" and not level.ronda_activa, "Outcomes must block gameplay input and wave triggers")
	_check(level.gotas == drops and level.arbol_meta.vida == hp and level.get_child_count() == count, "Outcomes must freeze economy, base damage, and spawning")

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	for index in 2:
		var level = _new_level(index)
		_check(level.suelo.get_used_cells().size() == 30 * 17, "Shared board must contain 30 x 17 cells")
		_check(not level._se_puede_plantar(level.celda_arbol_madre), "Base cell must be blocked")
		_check(not level._se_puede_plantar(Vector2i(29, 16)), "Level-specific obstacle cells must be blocked by the parent")
		_check(not level._se_puede_plantar(Vector2i(-1, 4)) and not level._se_puede_plantar(Vector2i(0, 2)), "Bounds and HUD rows must be blocked")
		for cell in level._celdas_de(level.puntos_ruta):
			_check(not level._se_puede_plantar(cell), "Main road cells must be blocked")
		if index == 1:
			_check(not level._se_puede_plantar(Vector2i(26, 8)), "Flamma shortcut cells must be blocked")
			level._crear_espiritu("flamma", "pequeno", 50.0)
			_check(level._ruta_para_tipo("flamma") != level.ruta, "Flamma must use its level-specific shortcut")
			_check(level._bestias_en_camino() == 1 and level.ruta.get_child_count() == 0, "Enemy count must include alternate paths")
			level.ronda_activa = true
			level._process(0.0)
			_check(level.ronda == 1 and level.ronda_activa, "A shortcut enemy must prevent premature wave completion")
			level.ronda_activa = false
			_clear_enemies(level)
		var passive_gain := floori(level.obtener_produccion_agua() * 4.0)
		level._process(4.0)
		_check(level.gotas == 3 + passive_gain and level.pozo.temporizador.paused, "Well generation must stop between waves")
		level.hud.boton_ronda.pressed.emit()
		_check(level.ronda_activa, "HUD wave trigger must connect to the inherited handler")
		var queued: int = level.cola_bestias.size()
		level._iniciar_ronda()
		_check(level.cola_bestias.size() == queued, "Repeated starts must not duplicate a wave")
		level._process(4.0)
		_check(level.gotas == 3 + 2 * passive_gain and not level.pozo.temporizador.paused, "Waves must enable the well alongside passive income")
		level._lanzar_ataque(Vector2(1800, 1000), 0)
		_check(level.cargas[0] == 1, "Shared ability logic must consume one charge")
		level._abrir_pausa()
		var pause = level.pausa
		var drops: int = level.gotas
		var remaining: int = level.cola_bestias.size()
		level._process(10.0)
		level._on_semilla_pulsada(0, false)
		_check(paused and level.gotas == drops and level.cola_bestias.size() == remaining, "Pause must freeze income, spawning, and input")
		_check(level.cargas[0] == 1, "Pause must freeze ability recharge")
		pause._continuar()
		await process_frame
		_check(not paused and level.pausa == null, "Resume must clear the inherited pause reference")
		level._process(3.0)
		_check(level.cargas[0] == 2, "Ability recharge must resume after pause")
		level.cola_bestias.clear()
		level.ronda_activa = false
		_clear_enemies(level)
		for wave in range(1, 6):
			level._iniciar_ronda()
			var expected := 0
			for amount in level.rondas[wave - 1].values():
				expected += int(amount)
			var spawned := 0
			while not level.cola_bestias.is_empty():
				level._process(3.0)
				spawned += level._bestias_en_camino()
				_check(level.ronda == wave and not level.terminado, "Wave must wait for spawned enemies")
				_clear_enemies(level)
			_check(spawned == expected, "Wave recipes must preserve enemy counts in level %d wave %d" % [index, wave])
			level._process(0.0)
			if wave < 5:
				_check(level.ronda == wave + 1 and not level.ronda_activa, "Cleared waves must advance and wait for the next trigger")
		_check(level.terminado and paused, "The final wave must open victory and pause gameplay")
		_check_terminal_actions(level)
		var count: int = level.get_child_count()
		level._ganar_nivel()
		level._perder_nivel()
		_check(level.get_child_count() == count, "Repeated outcomes must not add duplicate overlays")
		paused = false
		level.free()
		level = _new_level(index)
		level._on_espiritu_llego(level.arbol_meta.vida)
		_check(level.arbol_meta.vida == 0 and level.terminado and paused, "Base death must open defeat in both levels")
		_check_terminal_actions(level)
		paused = false
		level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Shared level checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
