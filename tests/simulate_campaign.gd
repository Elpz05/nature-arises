extends SceneTree

# Real combat with legal purchases and earned tools. No save writes, stat changes,
# enemy removal or manual wave completion. This is a smoke test, not human balance.
const CAMPAIGN = preload("res://scripts/nivel/campana.gd")
const STEP := 8.0 / 240.0
var failures := 0
var results: Array = []
var run_seed := 20261102
var without_defense := false

func _initialize():
	call_deferred("_run")

func _plan(index: int) -> Array:
	var plan: Array = []
	if index == 0:
		for cell in [Vector2i(0, 4), Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(4, 6), Vector2i(6, 6), Vector2i(4, 8), Vector2i(6, 8), Vector2i(4, 10), Vector2i(6, 10), Vector2i(8, 11), Vector2i(8, 13)]:
			plan.append([cell, 0])
	elif index in [2, 5, 6]:
		# Defend both sides of the first vertical corridor; later rows cover its turn.
		if index == 6:
			for x in [3, 5, 6, 7, 9]:
				plan.append([Vector2i(x, 3), 3])
		plan.append([Vector2i(4, 9), 3])
		for y in [4, 6, 8, 10, 12, 14]:
			plan.append([Vector2i(3, y), 1 if y % 4 == 0 else 0])
			plan.append([Vector2i(6, y), 5 if index >= 5 and y % 4 == 0 else 0])
	elif index == 7:
		# Aqua funds upgrades; Terra catches shortcut runners for the damage/control line.
		plan = [[Vector2i(7, 5), 2], [Vector2i(18, 9), 3], [Vector2i(15, 6), 5],
			[Vector2i(14, 5), 4], [Vector2i(13, 5), 1], [Vector2i(16, 5), 6],
			[Vector2i(8, 6), 0], [Vector2i(26, 11), 3], [Vector2i(25, 11), 1],
			[Vector2i(25, 9), 4], [Vector2i(23, 11), 0], [Vector2i(19, 9), 2]]
	else:
		if index == 1:
			plan.append([Vector2i(7, 4), 2])
		for x in range(0, 24, 2):
			var type := 0
			if index == 3: type = 4 if x % 4 == 0 else 0
			if index == 4: type = 1 if x % 4 == 0 else 4
			plan.append([Vector2i(x, 3), type])
	return plan

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
	if not target.efecto_elemental.elemento.is_empty(): return
	var priority: Array = {
		"flamma": [2, 5, 3, 4], "aqua": [4, 5, 3, 0],
		"glacies": [1, 6, 3, 4, 0], "terra": [6, 4, 1, 0],
		"electricitas": [6, 3, 1, 0], "venenum": [3, 1, 4, 5, 2],
	}.get(target.tipo, [6, 1, 3, 4, 0])
	for type in priority:
		if level.hud.ATAQUES_ACTIVOS.has(type) and level.cargas[type] >= 1.0:
			if level._lanzar_ataque(level.to_local(target.global_position), type):
				metrics.casts += 1
			break

func _run():
	var first := 0
	var last := 7
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--from="): first = clampi(argument.trim_prefix("--from=").to_int(), 0, 7)
		if argument.begins_with("--to="): last = clampi(argument.trim_prefix("--to=").to_int(), first, 7)
		if argument.begins_with("--seed="): run_seed = argument.trim_prefix("--seed=").to_int()
		if argument == "--without-defense": without_defense = true
	last = clampi(last, first, 7)
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	var previous_scale := Engine.time_scale
	var previous_ticks := Engine.physics_ticks_per_second
	save.slot_actual = -1
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 240
	for index in range(first, last + 1):
		seed(run_seed + index)
		var level = load(CAMPAIGN.ESCENAS[index]).instantiate()
		root.add_child(level)
		var metrics := {"level": index + 1, "seed": run_seed + index, "purchases": 0, "upgrades": 0, "spent": 0, "casts": 0,
			"without_defense": without_defense, "roster": {}, "shots": {}}
		level.arboles.child_entered_tree.connect(func(node):
			if "objetivo" in node and "elemento" in node:
				var element: String = node.elemento
				metrics.shots[element] = metrics.shots.get(element, 0) + 1
		)
		var elapsed := 0.0
		var decision := 0.0
		var plan: Array = [] if without_defense else _plan(index)
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
					_cast(level, metrics)
				if not level.ronda_activa: level._iniciar_ronda()
				decision = 0.5
			await physics_frame
			elapsed += STEP
			decision -= STEP
		metrics.won = level.terminado and level.arbol_meta.vida > 0
		metrics.seconds = snappedf(elapsed, 0.1)
		metrics.mother_hp = level.arbol_meta.vida
		metrics.round = level.ronda
		metrics.trees = level.arboles_plantados.size()
		metrics.weather_events = level.gestor_clima.conteos.duplicate()
		var expected_result: bool = level.terminado and (not metrics.won if without_defense else metrics.won)
		if index == 7 and not without_defense:
			expected_result = expected_result and metrics.roster.size() == 7 and metrics.shots.size() == 5
		if not expected_result: failures += 1
		results.append(metrics)
		print("Campaign combat: " + JSON.stringify(metrics))
		paused = false
		level.free()
		await process_frame
	save.slot_actual = previous_slot
	Engine.time_scale = previous_scale
	Engine.physics_ticks_per_second = previous_ticks
	var report = FileAccess.open("res://.godot/campaign_combat_%d%s.json" % [run_seed, "_without_defense" if without_defense else ""], FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify(results, "\t"))
	print("Campaign combat simulation: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
