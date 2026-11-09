extends SceneTree

# Real combat with legal purchases and earned tools. Comparison modes can omit
# towers or restore the old three-second cooldown in a temporary HUD instance.
const CAMPAIGN = preload("res://scripts/nivel/campana.gd")
const STEP := 1.0 / 60.0
var failures := 0
var results: Array = []
var run_seed := 20261102
var without_defense := false
var accept_challenges := false
var spells_only := false
var towers_only := false
var fast_recharge := false
var baseline := false
var speed := 1.0
var report_tag := ""

func _initialize():
	call_deferred("_run")

func _plan(index: int) -> Array:
	match index:
		0:
			return [[Vector2i(0, 4), 0], [Vector2i(2, 4), 0], [Vector2i(4, 4), 0],
				[Vector2i(6, 4), 0], [Vector2i(4, 7), 0], [Vector2i(6, 8), 0]]
		1:
			return [[Vector2i(1, 3), 0], [Vector2i(4, 3), 0], [Vector2i(6, 3), 0],
				[Vector2i(9, 3), 1], [Vector2i(10, 5), 2], [Vector2i(16, 6), 0], [Vector2i(24, 6), 1]]
		2:
			return [[Vector2i(4, 8), 3], [Vector2i(3, 7), 1], [Vector2i(3, 4), 0],
				[Vector2i(5, 6), 0], [Vector2i(3, 10), 1], [Vector2i(7, 10), 0], [Vector2i(6, 12), 1]]
		3:
			return [[Vector2i(1, 3), 4], [Vector2i(4, 3), 0], [Vector2i(7, 3), 4],
				[Vector2i(10, 3), 0], [Vector2i(25, 9), 4], [Vector2i(13, 5), 0],
				[Vector2i(26, 9), 3], [Vector2i(18, 5), 4]]
		4:
			return [[Vector2i(1, 3), 4], [Vector2i(4, 3), 1], [Vector2i(7, 5), 1],
				[Vector2i(9, 3), 4], [Vector2i(12, 5), 4], [Vector2i(11, 7), 3], [Vector2i(5, 5), 0]]
		5:
			return [[Vector2i(4, 9), 3], [Vector2i(3, 4), 1], [Vector2i(5, 4), 5],
				[Vector2i(5, 7), 1], [Vector2i(3, 6), 0], [Vector2i(5, 9), 5], [Vector2i(7, 13), 1]]
		6:
			return [[Vector2i(3, 3), 3], [Vector2i(5, 3), 3], [Vector2i(4, 3), 3],
				[Vector2i(3, 4), 1], [Vector2i(5, 4), 4], [Vector2i(3, 7), 0],
				[Vector2i(5, 9), 4], [Vector2i(7, 12), 5]]
		_:
			return [[Vector2i(8, 5), 2], [Vector2i(18, 9), 3], [Vector2i(15, 6), 5],
				[Vector2i(14, 5), 4], [Vector2i(13, 5), 1], [Vector2i(8, 6), 0],
				[Vector2i(16, 5), 6], [Vector2i(26, 11), 3], [Vector2i(25, 11), 1],
				[Vector2i(25, 9), 4], [Vector2i(23, 11), 0], [Vector2i(19, 9), 2]]

func _buy(level, plan: Array, metrics: Dictionary):
	for entry in plan:
		var cell: Vector2i = entry[0]
		var type: int = entry[1]
		if level.arboles_plantados.has(cell): continue
		if level.gotas < level.hud.SEMILLAS[type].costo: break
		var before: int = level.gotas
		level._on_semilla_pulsada(type, false)
		level._confirmar(level.suelo.map_to_local(cell))
		if not level.arboles_plantados.has(cell) or level.gotas >= before:
			push_error("Purchase did not spend water or place unlocked tree")
			failures += 1
			break
		metrics.purchases += 1
		metrics.spent += before - level.gotas
		var name: String = level.hud.SEMILLAS[type].nombre
		metrics.roster[name] = metrics.roster.get(name, 0) + 1
	if level.arboles_plantados.size() < plan.size(): return
	for entry in plan:
		var cell: Vector2i = entry[0]
		# Preserve the three-hit rock shield instead of spending on its HP.
		if entry[1] == 3: continue
		if level.tamanos_plantados[cell] < 2 and level.gotas >= level._costo_mejora(cell):
			var before: int = level.gotas
			level._mejorar_arbol(cell)
			metrics.upgrades += 1
			metrics.spent += before - level.gotas

func _cast(level, metrics: Dictionary):
	var enemies: Array = level._bestias_vivas()
	if enemies.is_empty(): return
	# Prefer the beast nearest the goal, including elemental shortcuts.
	enemies.sort_custom(func(a, b):
		return a.get_parent().get_parent().curve.get_baked_length() - a.get_parent().progress < b.get_parent().get_parent().curve.get_baked_length() - b.get_parent().progress
	)
	var target = enemies[0]
	# Let existing burn, confusion and control finish before replacing them.
	if not target.efecto_movimiento.elemento.is_empty() or not target.efecto_dano.elemento.is_empty(): return
	var priority: Array = {
		"flamma": [2, 5, 3, 4], "aqua": [4, 5, 3, 0],
		"glacies": [1, 6, 3, 4, 0], "terra": [6, 4, 1, 0],
		"electricitas": [6, 3, 1, 0], "venenum": [3, 1, 4, 5, 2],
	}.get(target.tipo, [6, 1, 3, 4, 0])
	for type in priority:
		if level.hud.ATAQUES_ACTIVOS.has(type) and level.cargas[type] >= 1.0:
			if level._lanzar_ataque(level.to_local(target.global_position), type):
				metrics.casts += 1
				var name: String = level.hud.ATAQUES[type].nombre
				metrics.casts_by_type[name] = metrics.casts_by_type.get(name, 0) + 1
			break

func _hud_con_recarga_rapida(original: PackedScene) -> PackedScene:
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/HUD/hud.gd"\nfunc intervalo_recarga_ataque(_i: int) -> float:\n\treturn 3.0\n'
	if script.reload() != OK:
		return null
	var hud := original.instantiate()
	hud.set_script(script)
	var escena := PackedScene.new()
	var error := escena.pack(hud)
	hud.free()
	return escena if error == OK else null

func _run():
	var first := 0
	var last := 7
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from="): first = clampi(argument.trim_prefix("--from=").to_int(), 0, 7)
		if argument.begins_with("--to="): last = clampi(argument.trim_prefix("--to=").to_int(), first, 7)
		if argument.begins_with("--seed="): run_seed = argument.trim_prefix("--seed=").to_int()
		if argument == "--without-defense": without_defense = true
		if argument == "--challenge": accept_challenges = true
		if argument == "--spells-only": spells_only = true
		if argument == "--towers-only": towers_only = true
		if argument == "--fast-recharge": fast_recharge = true
		if argument == "--baseline": baseline = true
		if argument.begins_with("--report-tag="): report_tag = argument.trim_prefix("--report-tag=").validate_filename()
		if argument.begins_with("--speed="):
			var requested := argument.trim_prefix("--speed=").to_float()
			if requested in [1.0, 2.0, 4.0, 8.0]:
				speed = requested
	last = clampi(last, first, 7)
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	var previous_scale := Engine.time_scale
	var previous_ticks := Engine.physics_ticks_per_second
	var previous_steps := Engine.max_physics_steps_per_frame
	var previous_codice: ConfigFile = save._codice
	save._codice = ConfigFile.new()
	save._codice.set_value("progreso", "bestias", ["natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum"])
	var previous_path: String = save._ruta_codice
	save._ruta_codice = OS.get_environment("TEMP").path_join("nature-sim-%d.cfg" % OS.get_process_id())
	save.slot_actual = -1
	for index in range(first, last + 1):
		seed(run_seed + index)
		var level = load(CAMPAIGN.ESCENAS[index]).instantiate()
		level.ajustes_campana_activos = not baseline
		if fast_recharge:
			level.hud_escena = _hud_con_recarga_rapida(level.hud_escena)
			if level.hud_escena == null:
				push_error("Could not build the comparison HUD")
				level.free()
				quit(1)
				return
		root.add_child(level)
		level._aplicar_tiempo(speed)
		level.gestor_clima.set_process(false)
		if not level.inicializado:
			push_error("Campaign level %d failed to initialize" % (index + 1))
			quit(1)
			return
		var metrics := {"level": index + 1, "seed": run_seed + index, "purchases": 0, "upgrades": 0, "spent": 0, "casts": 0,
			"without_defense": without_defense, "spells_only": spells_only, "towers_only": towers_only, "fast_recharge": fast_recharge,
			"challenges": 0, "roster": {}, "shots": {}, "casts_by_type": {}}
		level.arboles.child_entered_tree.connect(func(node):
			if "objetivo" in node and "elemento" in node:
				var element: String = node.elemento
				metrics.shots[element] = metrics.shots.get(element, 0) + 1
		)
		var elapsed := 0.0
		var decision := 0.0
		var plan: Array = [] if without_defense or spells_only else _plan(index)
		var valid_plan := true
		for entry in plan:
			if not level._se_puede_plantar(entry[0], entry[1]) or not level.hud.SEMILLAS_ACTIVAS.has(entry[1]):
				push_error("Invalid strategy cell %s for tree %d" % [entry[0], entry[1]])
				failures += 1
				valid_plan = false
		while valid_plan and not level.terminado and elapsed < 900.0:
			if decision <= 0.0:
				level._recoger_en_objetivo(level.suelo.map_to_local(level.celda_pozo))
				if not without_defense:
					_buy(level, plan, metrics)
					if not towers_only:
						_cast(level, metrics)
				if not level.ronda_activa:
					if accept_challenges and level.desafios_ronda.has(level.ronda):
						level._alternar_desafio()
						metrics.challenges += 1
					level._iniciar_ronda()
				decision = 0.5
			await physics_frame
			level.gestor_clima.presentar_avisos(STEP / speed)
			elapsed += STEP
			decision -= STEP
		metrics.won = level.terminado and level.arbol_meta.vida > 0
		metrics.seconds = snappedf(elapsed, 0.1)
		metrics.mother_hp = level.arbol_meta.vida
		metrics.round = level.ronda
		metrics.trees = level.arboles_plantados.size()
		metrics.weather_events = level.gestor_clima.conteos.duplicate()
		var solo_control := spells_only or towers_only
		var expected_result: bool = level.terminado and (not metrics.won if without_defense else (solo_control or metrics.won))
		if index == 7 and not solo_control and not without_defense:
			expected_result = expected_result and metrics.roster.size() == 7 and metrics.shots.size() == 5
		if not expected_result: failures += 1
		results.append(metrics)
		print("Campaign combat: " + JSON.stringify(metrics))
		paused = false
		level.free()
		await process_frame
	save.slot_actual = previous_slot
	DirAccess.remove_absolute(save._ruta_codice)
	save._ruta_codice = previous_path
	save._codice = previous_codice
	Engine.time_scale = previous_scale
	Engine.physics_ticks_per_second = previous_ticks
	Engine.max_physics_steps_per_frame = previous_steps
	var suffix := "_without_defense" if without_defense else ""
	if spells_only:
		suffix += "_spells_only"
	if towers_only:
		suffix += "_towers_only"
	if fast_recharge:
		suffix += "_fast_recharge"
	if accept_challenges:
		suffix += "_challenge"
	if baseline:
		suffix += "_baseline"
	suffix += "_%d-%d_%dx" % [first, last, int(speed)]
	if not report_tag.is_empty():
		suffix += "_" + report_tag
	var report = FileAccess.open("res://.godot/campaign_combat_%d%s.json" % [run_seed, suffix], FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify(results, "\t"))
	print("Campaign combat simulation: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
