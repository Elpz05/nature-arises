extends SceneTree

# Smoke playthrough: actual waves, timers, Area2D, projectiles and legal spending.
# Does not write saves or change unit statistics. It is not a human balance test.
func _initialize():
	call_deferred("_run")

func _run():
	seed(20261102)
	Engine.time_scale = 16.0
	Engine.physics_ticks_per_second = 120
	var save = root.get_node("Guardado")
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	var victories := 0
	for index in 2:
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		var cells: Array = [Vector2i(0, 4), Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(4, 6), Vector2i(6, 6), Vector2i(4, 8), Vector2i(6, 8), Vector2i(4, 10), Vector2i(6, 10), Vector2i(8, 11), Vector2i(8, 13)]
		if index == 1:
			cells = []
			for x in range(0, 24, 2):
				cells.append(Vector2i(x, 3))
		var elapsed := 0.0
		while not level.terminado and elapsed < 900.0:
			level._recoger_en_objetivo(level.suelo.map_to_local(level.celda_pozo))
			for cell in cells:
				if level.gotas < 1:
					break
				if not level.arboles_plantados.has(cell):
					level._on_semilla_pulsada(0, false)
					level._confirmar(level.suelo.map_to_local(cell))
			if level.arboles_plantados.size() >= cells.size():
				for cell in cells:
					if level.tamanos_plantados[cell] < 2 and level.gotas >= level._costo_mejora(cell):
						level._mejorar_arbol(cell)
			var enemies: Array = level._bestias_vivas()
			if enemies.size() >= 2:
				var target = enemies[0]
				for enemy in enemies:
					if enemy.tipo == "natura":
						target = enemy
						break
				if target.tipo not in ["flamma", "venenum"]:
					if index == 1 and target.tipo == "natura" and level.cargas[1] >= 1.0:
						level._lanzar_ataque(level.to_local(target.global_position), 1)
					elif level.cargas[0] >= 1.0:
						level._lanzar_ataque(level.to_local(target.global_position), 0)
			if not level.ronda_activa:
				level._iniciar_ronda()
			await physics_frame
			elapsed += Engine.time_scale / float(Engine.physics_ticks_per_second)
		var won: bool = level.terminado and level.arbol_meta.vida > 0
		if won:
			victories += 1
		print("Opening level %d: %s | %.1f simulated seconds | mother HP %d | planted %d" % [index + 1, "WIN" if won else "LOSS/TIMEOUT", elapsed, level.arbol_meta.vida, level.arboles_plantados.size()])
		paused = false
		level.free()
	save.slot_actual = original_slot
	Engine.time_scale = 1.0
	print("Opening simulation: %s" % ("PASS" if victories == 2 else "FAIL"))
	quit(0 if victories == 2 else 1)
