extends SceneTree

class TerraControlada extends "res://scripts/entidades/bestias/espiritu.gd":
	var tirada := 0.0
	func _tirada_defensa() -> float:
		return tirada

class ArbolControlado extends "res://scripts/entidades/arboles/arbol.gd":
	var tirada := 0.0
	func _tirada_fallo() -> float:
		return tirada

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String, progress: float = 384.0, size: String = "pequeno"):
	level._crear_espiritu(tipo, size, progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	var expected := {
		"terra": {"hp": [500, 900, 1500], "vel": 0.2, "contacto": 100},
		"electricitas": {"hp": [300, 500, 1000], "vel": 0.6, "contacto": 50},
		"glacies": {"hp": [350, 550, 1050], "vel": 0.3, "contacto": 75},
		"venenum": {"hp": [300, 600, 900], "vel": 0.6, "contacto": 150},
	}
	for index in 2:
		var stage = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(stage)
		stage.set_process(false)
		stage.set_physics_process(false)
		_check(stage.inicializado and stage.TIPOS_BESTIA.size() == 7, "Both levels initialize with seven beast scene assignments")
		for tipo in expected:
			for size_index in 3:
				var enemy = _enemy(stage, tipo, 50.0, stage.TAMANOS[size_index])
				_check(enemy.vida == expected[tipo].hp[size_index] and enemy.vida_maxima == enemy.vida, "Every new beast size gets its exact maximum HP")
				_check(is_equal_approx(enemy.velocidad, expected[tipo].vel * 64.0) and enemy.DANO_CONTACTO[tipo] == expected[tipo].contacto, "Each type gets its specified speed and contact damage")
				_check(enemy.get_parent().get_parent() == stage.ruta, "New beasts use the normal road, not Flamma shortcuts")
				enemy._physics_process(1.0)
				_check(is_equal_approx(enemy.get_parent().progress, 50.0 + expected[tipo].vel * 64.0), "New beasts advance through real path movement")
				enemy.get_parent().queue_free()
		stage.free()
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.clima = "despejado"
	for tipo in expected:
		_check(level.rondas[0].has(tipo + ":pequeno") and level.rondas[2].has(tipo + ":mediano") and level.rondas[4].has(tipo + ":grande"), "Laboratory schedules every missing beast in all three sizes")
	# Force both sides of Terra's probability threshold without random tests.
	var armor = load("res://escenas/escenas_espiritu/espiritu_terra.tscn").instantiate()
	armor.set_script(TerraControlada)
	armor.tipo = "terra"
	var follower := PathFollow2D.new()
	follower.loop = false
	level.ruta.add_child(follower)
	follower.add_child(armor)
	armor.set_physics_process(false)
	armor.tirada = 0.099
	_check(not armor.recibir_dano(100.0) and armor.vida == 500.0, "Terra nullifies a hit below the ten-percent threshold")
	armor.tirada = 0.1
	_check(armor.recibir_dano(100.0) and armor.vida == 400.0, "The ten-percent threshold is exclusive")
	armor.tirada = 0.0
	armor.aplicar_veneno(2.0, 0.75, 6.0)
	armor._physics_process(1.0)
	_check(armor.vida == 398.0, "Terra cannot roll armor against each poison frame")
	follower.queue_free()
	# A controlled Natura tower provides deterministic miss checks.
	var cell := Vector2i(6, 3)
	var tower = load("res://escenas/escenas_arboles/arbol_base.tscn").instantiate()
	tower.set_script(ArbolControlado)
	tower.semilla_escena = load("res://escenas/escenas_balas/bala.tscn")
	tower.position = level.suelo.map_to_local(cell)
	level.arboles.add_child(tower)
	tower.temporizador.stop()
	level.arboles_plantados[cell] = tower
	level.tipos_plantados[cell] = 0
	level.tamanos_plantados[cell] = 0
	level.costos_plantados[cell] = 1
	tower.murio.connect(level.liberar_celda.bind(cell))
	var electric = _enemy(level, "electricitas")
	level._actualizar_auras_bestias(0.5)
	_check(tower.vida == 100, "Electric aura preserves fractional exposure")
	level._actualizar_auras_bestias(0.5)
	_check(tower.vida == 99, "Electric aura deals one HP per second")
	var electric2 = _enemy(level, "electricitas")
	level._actualizar_auras_bestias(1.0)
	_check(tower.vida == 97, "Each adjacent Electricitas contributes its own one HP per second")
	electric.get_parent().progress = 800.0
	electric2.get_parent().progress = 800.0
	level._actualizar_auras_bestias(10.0)
	_check(tower.vida == 97, "Electric aura stops damaging after leaving adjacency")
	var ice = _enemy(level, "glacies")
	level._actualizar_auras_bestias(0.0)
	_check(tower.congelado_por_aura and tower.temporizador.paused and tower.obtener_estadisticas().disparos_segundo == 0.0, "Glacies immediately freezes adjacent attack timers")
	level._plantar(Vector2i(7, 3), 5)
	var ice_tree = level.arboles_plantados[Vector2i(7, 3)]
	ice_tree.temporizador.stop()
	level._actualizar_auras_bestias(0.0)
	_check(not ice_tree.congelado_por_aura, "Glacies trees are immune even on a diagonal adjacent cell")
	level._plantar(Vector2i(9, 3), 1)
	var flame = level.arboles_plantados[Vector2i(9, 3)]
	flame.temporizador.stop()
	level._actualizar_auras_bestias(0.0)
	_check(tower.congelado_por_aura, "Flamma does not protect a tree beyond its range")
	flame._aplicar_tamano("mediano")
	flame.temporizador.stop()
	level._actualizar_auras_bestias(0.0)
	_check(not tower.congelado_por_aura, "Upgrading Flamma extends its protection to the edge of its new range")
	level._quitar_arbol(Vector2i(9, 3))
	level._actualizar_auras_bestias(0.0)
	_check(tower.congelado_por_aura, "Removing Flamma removes its protection")
	ice.get_parent().progress = 800.0
	level._actualizar_auras_bestias(0.0)
	_check(not tower.congelado_por_aura and not tower.temporizador.paused, "Leaving Glacies aura immediately thaws trees")
	var venom = _enemy(level, "venenum")
	var venom2 = _enemy(level, "venenum")
	level._actualizar_auras_bestias(0.0)
	_check(tower.intoxicado_por_aura and is_equal_approx(tower.obtener_estadisticas().disparos_segundo, 1.4), "Multiple toxic auras apply a single thirty-percent cadence penalty")
	await physics_frame
	await physics_frame
	await physics_frame
	var count: int = level.arboles.get_child_count()
	tower.tirada = 0.299
	tower._disparar()
	_check(level.arboles.get_child_count() == count, "A roll below thirty percent consumes the shot without a projectile")
	tower.tirada = 0.3
	tower._disparar()
	_check(level.arboles.get_child_count() == count + 1, "A roll at the boundary fires normally")
	level.arboles.get_child(level.arboles.get_child_count() - 1).queue_free()
	venom.get_parent().progress = 800.0
	venom2.get_parent().progress = 800.0
	level._actualizar_auras_bestias(0.0)
	_check(not tower.intoxicado_por_aura and tower.obtener_estadisticas().disparos_segundo == 2.0, "Leaving toxic aura restores cadence")
	tower.tirada = 0.0
	count = level.arboles.get_child_count()
	tower._disparar()
	_check(level.arboles.get_child_count() == count + 1, "No miss roll is applied without toxic aura")
	# Fresh sources disappear on death, pause and outcomes never advance damage.
	electric.get_parent().progress = 384.0
	venom.get_parent().progress = 384.0
	level._actualizar_auras_bestias(0.0)
	var hp: int = tower.vida
	paused = true
	level._actualizar_auras_bestias(10.0)
	_check(tower.vida == hp, "Pause freezes aura damage")
	paused = false
	level.terminado = true
	level._actualizar_auras_bestias(10.0)
	_check(tower.vida == hp, "Outcome freezes aura damage")
	level.terminado = false
	electric.recibir_dano(10000.0)
	venom.recibir_dano(10000.0)
	level._actualizar_auras_bestias(1.0)
	_check(tower.vida == hp and not tower.intoxicado_por_aura, "Dead or queued beasts cannot maintain auras")
	# All four new contact attacks share Terra's blocking integration.
	var barrier_cell := Vector2i(12, 4)
	level._plantar(barrier_cell, 3)
	var barrier = level.arboles_plantados[barrier_cell]
	for tipo in expected:
		barrier.vida = 1000
		var attacker = _enemy(level, tipo, 735.0)
		attacker._physics_process(0.1)
		_check(barrier.vida == 1000 - expected[tipo].contacto and attacker.get_parent().progress < 736.0, "New beast contact deals its exact damage and receives Terra knockback")
		attacker.get_parent().queue_free()
	# Killing a tree with an aura frees its occupied cell exactly once.
	var victim_cell := Vector2i(18, 3)
	level._plantar(victim_cell, 0)
	var victim = level.arboles_plantados[victim_cell]
	victim.temporizador.stop()
	victim.vida = 1
	_enemy(level, "electricitas", 18.0 * 64.0)
	level._actualizar_auras_bestias(1.0)
	_check(not level.arboles_plantados.has(victim_cell) and victim.is_queued_for_deletion(), "Aura deaths free the board cell safely")
	level.free()
	# Exercise the level's automatic physics callback, not only direct calls.
	var live_level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(live_level)
	live_level.set_process(false)
	live_level._plantar(Vector2i(6, 3), 0)
	var live_tree = live_level.arboles_plantados[Vector2i(6, 3)]
	live_tree.temporizador.stop()
	var live_electric = _enemy(live_level, "electricitas")
	for i in Engine.physics_ticks_per_second + 3:
		await physics_frame
	_check(live_tree.vida == 99, "Actual physics ticks apply electric aura damage once per elapsed second")
	live_electric.get_parent().queue_free()
	_enemy(live_level, "glacies")
	await physics_frame
	await physics_frame
	_check(live_tree.congelado_por_aura, "Actual physics ticks automatically apply cold aura")
	live_level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Beast completion checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
