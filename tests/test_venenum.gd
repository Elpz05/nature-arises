extends SceneTree

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String = "aqua", progress: float = 100.0):
	level._crear_espiritu(tipo, "mediano", progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _bullet(level):
	var bullet = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	bullet.elemento = "venenum"
	bullet.dano = 100
	bullet.dano_veneno = 1.0
	bullet.duracion_veneno = 6.0
	bullet.factor_lentitud = 0.75
	level.arboles.add_child(bullet)
	bullet.set_process(false)
	return bullet

func _run():
	var save = root.get_node("Guardado")
	var previous_slot: int = save.slot_actual
	save.slot_actual = -1
	var locked = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(locked)
	locked._on_semilla_pulsada(6, false)
	_check(locked.seleccion_tipo == "", "Venenum respects campaign unlocks")
	locked.free()
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	_check(level.hud.SEMILLAS_ACTIVAS.size() == 7, "Laboratory enables all seven trees")
	level.clima = "despejado"
	level.gotas = 36
	level.hud.actualizar_gotas(36)
	level._on_semilla_pulsada(6, false)
	_check(level.datos_rango_colocacion.radio == 256.0, "Small Venenum previews four-cell range")
	var cell := Vector2i(1, 3)
	level._confirmar(level.suelo.map_to_local(cell))
	var tower = level.arboles_plantados[cell]
	tower.temporizador.stop()
	_check(level.gotas == 26 and tower.vida == 500 and is_equal_approx(tower.obtener_estadisticas().disparos_segundo, 0.3), "Small Venenum costs 10, has 500 HP and fires at 0.3/s")
	level._mejorar_arbol(cell)
	_check(level.gotas == 14 and tower.vida == 800 and tower.obtener_estadisticas().radio == 320.0 and tower.factor_lentitud == 0.73 and tower.obtener_estadisticas().veneno_segundo == 2.0, "Medium costs 12 and supplies 800 HP, range 5, poison 2 and slow 27 percent")
	level._mejorar_arbol(cell)
	_check(level.gotas == 0 and tower.vida == 1000 and tower.obtener_estadisticas().radio == 384.0 and tower.factor_lentitud == 0.7 and tower.obtener_estadisticas().veneno_segundo == 3.0, "Large costs 14 and supplies 1000 HP, range 6, poison 3 and slow 30 percent")
	tower.temporizador.stop()
	level._mostrar_info_torre(cell)
	_check(level.tooltip.text.contains("Veneno: 3 HP/s durante 6.0 s") and level.tooltip.text.contains("Lentitud: 30%"), "Inspection describes both poison and slow")
	_check(not level._plantar(Vector2i(6, 4), 6), "Venenum cannot grow on roads")
	var target = _enemy(level, "aqua", 256.0)
	var nearby = _enemy(level, "aqua", 240.0)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(tower.enemigos_en_rango.has(target), "Physics range detects Venenum targets")
	tower._disparar()
	var actual = level.arboles.get_child(level.arboles.get_child_count() - 1)
	actual.set_process(false)
	_check(actual.objetivo == target and actual.dano_veneno == 3.0 and actual.duracion_veneno == 6.0, "Actual projectile carries size-specific poison")
	actual._physics_process(2.0)
	_check(target.vida == 400.0 and nearby.vida == 500.0 and target.veneno_por_segundo == 3.0, "Impact deals 100 and poisons a single target")
	actual._physics_process(2.0)
	_check(target.vida == 400.0, "Queued projectile cannot hit twice")
	var start: float = target.get_parent().progress
	target._physics_process(0.5)
	_check(is_equal_approx(target.vida, 398.5) and is_equal_approx(target.get_parent().progress - start, target.velocidad * 0.7 * 0.5), "Poison integrates fractional damage and actual slowed movement")
	target.aplicar_veneno(1.0, 0.75, 6.0)
	_check(target.veneno_por_segundo == 3.0 and target.veneno_restante == 5.5, "Weak poison cannot replace or refresh strong poison")
	target.aplicar_veneno(3.0, 0.7, 6.0)
	target.aplicar_veneno(3.0, 0.7, 6.0)
	_check(target.veneno_por_segundo == 3.0 and target.veneno_restante == 6.0, "Identical hits refresh rather than stack")
	paused = true
	target._physics_process(10.0)
	_check(target.veneno_restante == 6.0 and is_equal_approx(target.vida, 398.5), "Pause freezes damage and poison duration")
	paused = false
	start = target.get_parent().progress
	target._physics_process(7.0)
	_check(is_equal_approx(target.vida, 380.5) and target.veneno_restante == 0.0 and target.factor_lentitud_veneno == 1.0, "Long frames apply poison only for its remaining duration")
	_check(is_equal_approx(target.get_parent().progress - start, target.velocidad * (6.0 * 0.7 + 1.0)), "Movement recovers at the precise expiry time")
	_check(target.obtener_estado_combate().is_empty(), "Expired poison and slow disappear from feedback")
	var mixed = _enemy(level)
	mixed.aplicar_veneno(1.0, 0.75, 6.0)
	mixed.aplicar_lentitud(0.6, 8.0)
	start = mixed.get_parent().progress
	mixed._physics_process(7.0)
	_check(is_equal_approx(mixed.get_parent().progress - start, mixed.velocidad * 7.0 * 0.6) and mixed.factor_lentitud == 0.6, "Strongest slow wins without multiplication; poison expiry preserves an independent slow")
	var frozen = _enemy(level)
	frozen.aplicar_veneno(1.0, 0.75, 6.0)
	frozen.aplicar_congelacion(2.0)
	start = frozen.get_parent().progress
	frozen._physics_process(2.5)
	_check(is_equal_approx(frozen.vida, 497.5) and is_equal_approx(frozen.get_parent().progress - start, frozen.velocidad * 0.5 * 0.75), "Poison ticks while frozen and slow resumes after thaw")
	var bullet = _bullet(level)
	var nature = _enemy(level, "natura")
	bullet._golpear(nature)
	_check(is_equal_approx(nature.vida, 390.0) and nature.veneno_por_segundo == 1.0, "Natura receives 110 direct damage and normal poison")
	var immune = _enemy(level)
	immune.tipo = "venenum"
	bullet._golpear(immune)
	_check(immune.vida == 430.0 and immune.veneno_por_segundo == 0.0, "Venenum resists direct damage by 30 percent and is immune to poison damage")
	start = immune.get_parent().progress
	immune._physics_process(1.0)
	_check(immune.vida == 430.0 and is_equal_approx(immune.get_parent().progress - start, immune.velocidad * 0.75), "Poison immunity does not grant immunity to slow")
	var fire = _enemy(level, "flamma")
	fire.vida = 1.0
	fire.aplicar_veneno(3.0, 0.7, 6.0)
	fire._physics_process(1.0)
	_check(fire.renacio and fire.vida == fire.vida_maxima and fire.detenido == 3.0 and fire.veneno_restante == 0.0, "Poison death revives Flamma once, cleansing poison without shortening its revival")
	fire.vida = 1.0
	fire.aplicar_veneno(3.0, 0.7, 6.0)
	fire._physics_process(1.0)
	_check(fire.muerto and fire.get_parent().is_queued_for_deletion(), "A second poison death removes Flamma even while reviving")
	var large_step = _enemy(level)
	var small_steps = _enemy(level)
	for enemy in [large_step, small_steps]:
		enemy.aplicar_veneno(2.0, 0.73, 6.0)
	large_step._physics_process(7.0)
	for i in 70:
		small_steps._physics_process(0.1)
	_check(is_equal_approx(large_step.vida, small_steps.vida) and is_equal_approx(large_step.get_parent().progress, small_steps.get_parent().progress), "Poison damage and movement do not depend on frame size")
	level.terminado = true
	var hp: float = small_steps.vida
	small_steps.aplicar_veneno(3.0, 0.7, 6.0)
	small_steps._physics_process(20.0)
	_check(small_steps.vida == hp and small_steps.veneno_restante == 6.0, "Outcomes freeze poison updates")
	level.terminado = false
	level._quitar_arbol(cell)
	_check(level.gotas == 0 and not level.arboles_plantados.has(cell), "Shovel removes Venenum without refund")
	level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Venenum checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
