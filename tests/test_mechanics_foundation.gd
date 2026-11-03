extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String, progreso: float):
	level._crear_espiritu(tipo, "pequeno", progreso)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _run():
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	_check(level.inicializado, "Rain laboratory must initialize")
	var wet := Vector2i(6, 4)
	var grass := Vector2i(6, 3)
	_check(not level._plantar(grass, 2), "Aqua cannot grow on grass")
	level.clima = "despejado"
	_check(not level._plantar(wet, 2), "Aqua cannot grow in dry weather")
	level.clima = "lluvia"
	_check(level._plantar(wet, 2), "Aqua can grow on an authored flooded road")
	_check(not level._plantar(wet, 2) and not level._plantar(wet, 0), "A cell accepts one tree only")
	var aqua = level.arboles_plantados[wet]
	_check(aqua.vida == 100 and aqua.temporizador.is_stopped(), "Aqua supports production without attacks")
	_check(is_equal_approx(level.obtener_produccion_agua(), 0.85), "Rain and Aqua add to base production")
	level.gotas = 20
	level._mejorar_arbol(wet)
	_check(aqua.vida == 100 and is_equal_approx(level.obtener_produccion_agua(), 0.95), "Medium Aqua produces 0.2/s")
	level._mejorar_arbol(wet)
	_check(aqua.vida == 100 and is_equal_approx(level.obtener_produccion_agua(), 1.05), "Large Aqua produces 0.3/s")
	var invested: int = level.gotas
	level._quitar_arbol(wet)
	_check(level.gotas == invested and not level._se_puede_plantar(wet, 0), "Shovel grants no refund and leaves the road reserved")
	level.clima = "despejado"
	level.gotas = 0
	level._process(1.0)
	_check(level.gotas == 0, "Fractional production is saved")
	level._process(1.0)
	_check(level.gotas == 1, "Two seconds produce one base drop without collecting")
	level._process(6.0)
	_check(level.gotas == 4, "Long frames preserve every completed drop")
	paused = true
	level._process(100.0)
	_check(level.gotas == 4, "Pause blocks passive income")
	paused = false
	level.clima = "lluvia"
	level._plantar(wet, 2)
	aqua = level.arboles_plantados[wet]
	# Both routes share their first horizontal segment.
	var progress: float = 6.0 * 64.0
	var water = _enemy(level, "aqua", progress)
	level._actualizar_contactos_aqua()
	_check(aqua.vida == 100 and water.vida == 200, "Aqua beasts pass through Aqua trees harmlessly")
	var fire = _enemy(level, "flamma", progress)
	fire.tamano = "mediano"
	fire.vida = 400
	level._actualizar_contactos_aqua()
	_check(aqua.vida == 75 and fire.vida == 300, "Flamma contact deals 25 to Aqua and 100 to the beast")
	level._actualizar_contactos_aqua()
	_check(aqua.vida == 75 and fire.vida == 300, "Contact applies once per passage, not every frame")
	fire.get_parent().progress += 64.0
	level._actualizar_contactos_aqua()
	fire.get_parent().progress = progress
	level._actualizar_contactos_aqua()
	_check(aqua.vida == 50 and fire.vida == 200, "A new passage can trigger contact again")
	_enemy(level, "natura", progress)
	level._actualizar_contactos_aqua()
	_check(aqua.vida <= 0 and not level.arboles_plantados.has(wet), "Other beasts instantly destroy Aqua and free its slot")
	_check(is_equal_approx(level.obtener_produccion_agua(), 0.75), "Destroyed Aqua stops producing immediately")
	for enemy in level._bestias_vivas():
		enemy.get_parent().queue_free()
	await process_frame
	var target = _enemy(level, "aqua", 100.0)
	level._tiempo_ventus = 0.0
	level._actualizar_ventus(19.9)
	_check(target.bono_ventus == 0.0, "Ventus waits twenty seconds")
	level._actualizar_ventus(0.1)
	var before: float = target.get_parent().progress
	target._physics_process(1.0)
	_check(is_equal_approx(target.get_parent().progress - before, 64.0), "Ventus adds 0.5 cells/s to actual movement")
	level._actualizar_ventus(20.0)
	_check(target.bono_ventus == 0.5, "Repeated blessing does not stack")
	level._plantar(grass, 1)
	var tower = level.arboles_plantados[grass]
	_check(tower.vida == 250 and is_equal_approx(tower.obtener_estadisticas().disparos_segundo, 0.75), "Small Flamma has 250 HP and rain cadence")
	tower._aplicar_tamano("mediano")
	_check(tower.vida == 500 and tower.radio_explosion == 96.0 and tower.obtener_estadisticas().radio == 192.0, "Medium Flamma scales health, range and splash")
	tower._aplicar_tamano("grande")
	_check(tower.vida == 800 and tower.radio_explosion == 128.0, "Large Flamma has 800 HP and two-cell splash")
	var bullet = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	bullet.elemento = "flamma"
	bullet.dano = 40
	bullet.modificador_dano = -0.25
	root.add_child(bullet)
	bullet.set_process(false)
	var hp: int = target.vida
	bullet._golpear(target)
	_check(target.vida == hp, "Aqua is immune to Flamma projectiles")
	var nature = _enemy(level, "natura", 0.0)
	bullet._golpear(nature)
	_check(nature.vida == 168, "Element and weather modifiers add: 40 * (1 + .05 - .25) = 32")
	var revived = _enemy(level, "flamma", 0.0)
	revived.recibir_dano(1000)
	_check(revived.vida == 75 and revived.detenido == 3.0, "Rain Flamma revives at its adjusted maximum HP")
	bullet.free()
	level.terminado = true
	var amount: int = level.gotas
	level._process(100.0)
	_check(level.gotas == amount, "Outcome blocks income and global events")
	level.free()
	await process_frame
	print("Mechanics foundation checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
