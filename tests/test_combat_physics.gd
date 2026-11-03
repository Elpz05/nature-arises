extends SceneTree

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
	save.slot_actual = -1
	var level = load("res://escenas/escenas_niveles/nivel_0.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level._plantar(Vector2i(0, 4), 0)
	var tower = level.arboles_plantados[Vector2i(0, 4)]
	tower.temporizador.stop()
	_check(tower.temporizador.process_callback == Timer.TIMER_PROCESS_PHYSICS, "Firing timer must use physics updates")
	for progress in [96.0, 104.0, 112.0, 120.0, 128.0]:
		level._crear_espiritu("natura", "pequeno", progress)
	var live = level.ruta.get_child(0).get_child(0)
	var initial: float = live.get_parent().progress
	await physics_frame
	await physics_frame
	await physics_frame
	_check(live.get_parent().progress > initial, "Enemies must move through actual physics ticks")
	_check(tower.enemigos_en_rango.has(live), "Physics overlap cache must detect enemies")
	for follower in level.ruta.get_children():
		follower.get_child(0).set_physics_process(false)
	var dead = level.ruta.get_child(1).get_child(0)
	var queued_path = level.ruta.get_child(2).get_child(0)
	var queued_body = level.ruta.get_child(3).get_child(0)
	var freed = level.ruta.get_child(4).get_child(0)
	dead.muerto = true
	queued_path.get_parent().queue_free()
	queued_body.queue_free()
	tower.enemigos_en_rango = [freed, dead, queued_path, queued_body, live]
	freed.get_parent().free()
	_check(tower._mas_adelantada() == live, "Target selection must skip freed, dead, queued-body and queued-path enemies")
	tower._limpiar_enemigos_muertos()
	_check(tower.enemigos_en_rango == [live], "Cleanup must retain only valid live targets")
	tower._disparar()
	_check(level.arboles.get_child_count() == 2, "A valid physics-detected target must receive a projectile")
	var bullet = level.arboles.get_child(1)
	_check(bullet.objetivo == live, "The projectile must target the surviving enemy")
	bullet.set_process(false)
	live.get_parent().progress = 1000.0
	await physics_frame
	await physics_frame
	await physics_frame
	_check(tower.enemigos_en_rango.is_empty(), "Leaving the physics range must clear cached targets")
	var count: int = level.arboles.get_child_count()
	tower._disparar()
	_check(level.arboles.get_child_count() == count, "A tower must not shoot stale out-of-range targets")
	level.free()
	save.slot_actual = previous_slot
	await process_frame
	print("Combat physics checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
