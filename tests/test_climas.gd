extends SceneTree

class ClimaControlado extends "res://scripts/nivel/clima.gd":
	var tirada := 1.0
	var celda_fija := Vector2i(5, 3)
	var columna_fija := 4
	var indice_fijo := 0
	func _azar() -> float: return tirada
	func _celda_aleatoria() -> Vector2i: return celda_fija
	func _columna_aleatoria() -> int: return columna_fija
	func _indice_aleatorio(cantidad: int) -> int: return mini(indice_fijo, cantidad - 1)

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _level(weather: String, intensity: String = "mediano"):
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	level.clima = weather
	level.intensidad_tormenta = intensity
	if weather == "volcan":
		level.celdas_geiser.assign([Vector2i(6, 5)])
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.gestor_clima.free()
	var controller := ClimaControlado.new()
	controller.nivel = level
	level.gestor_clima = controller
	level.add_child(controller)
	_check(level.inicializado, "Every weather laboratory must initialize")
	return level

func _plant(level, cell: Vector2i, tipo: int):
	_check(level._plantar(cell, tipo), "Weather test tree must plant on valid terrain")
	var tree = level.arboles_plantados[cell]
	tree.temporizador.stop()
	return tree

func _enemy(level, tipo: String, progress: float = 256.0, size: String = "mediano"):
	level._crear_espiritu(tipo, size, progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _run():
	var save = root.get_node("Guardado")
	var old_slot: int = save.slot_actual
	save.slot_actual = -1
	# Intensity changes both interval and probability, with exact boundaries.
	for data in [["pequeno", 5.0, 0.1], ["mediano", 3.0, 0.5], ["grande", 1.0, 0.9]]:
		var level = _level("tormenta", data[0])
		var weather = level.gestor_clima
		weather.tirada = 0.0
		var aviso: float = weather.anticipaciones.rayo
		weather.actualizar(data[1] - aviso - 0.01)
		_check(weather.avisos.is_empty() and weather.conteos.get("rayo", 0) == 0, "Lightning stays quiet before the warning window")
		weather.actualizar(0.01)
		_check(weather.avisos.get("rayo") == weather.celda_fija and weather.conteos.get("rayo", 0) == 0, "Lightning marks the exact tile before damage")
		weather.actualizar(aviso - 0.01)
		_check(weather.conteos.get("rayo", 0) == 0, "The warning lasts its full intensity-specific duration")
		weather.actualizar(0.01)
		_check(weather.conteos.get("rayo", 0) == 1 and weather.avisos.is_empty(), "Lightning impacts at the original interval boundary")
		weather.tirada = data[2]
		weather.actualizar(data[1])
		_check(weather.conteos.rayo == 1 and weather.avisos.is_empty(), "A failed lightning roll creates neither a warning nor an impact")
		level.free()
	var response = _level("tormenta")
	var warning = response.gestor_clima
	warning.tirada = 0.0
	warning.actualizar(3.0 - warning.anticipaciones.rayo)
	var immune = _plant(response, Vector2i(5, 3), 4)
	var neighbor = _plant(response, Vector2i(4, 3), 0)
	warning.celda_fija = Vector2i(4, 3)
	warning.actualizar(warning.anticipaciones.rayo)
	_check(immune.vida == 200 and neighbor.vida == 100 and warning.conteos.rayo == 1, "Electricitas can be planted in response and the scheduled tile is never rerolled")
	response.free()
	var storm = _level("tormenta")
	var weather = storm.gestor_clima
	var shield = _plant(storm, Vector2i(4, 3), 4)
	var exposed = _plant(storm, Vector2i(5, 3), 0)
	var water: int = storm.gotas
	weather.rayo_en(Vector2i(5, 3))
	weather.rayo_en(Vector2i(4, 3))
	_check(exposed.is_queued_for_deletion() and not storm.arboles_plantados.has(Vector2i(5, 3)) and storm.gotas == water, "Lightning destroys a tree without refund and frees its cell")
	_check(shield.vida == 200, "Electricitas trees are immune to lightning")
	var electric = _enemy(storm, "electricitas")
	var phoenix = _enemy(storm, "flamma")
	weather.rayo_en(Vector2i(4, 4))
	_check(electric.vida == 500.0 and phoenix.muerto and not phoenix.renacio, "Lightning spares Electricitas beasts and environmental destruction bypasses resurrection")
	_check(is_equal_approx(storm.obtener_produccion_agua(), 0.14), "Storm adds 0.14 drops/s to the well")
	storm.free()
	# Geyser's seven-second bonus has an independent timer and does not stack.
	var volcano = _level("volcan")
	weather = volcano.gestor_clima
	_check(not volcano._se_puede_plantar(Vector2i(6, 5), 0), "Geyser cells reserve terrain")
	var nature = _plant(volcano, Vector2i(5, 5), 0)
	var flame = _plant(volcano, Vector2i(7, 5), 1)
	var ice = _plant(volcano, Vector2i(8, 5), 5)
	_check(is_equal_approx(nature.obtener_estadisticas().disparos_segundo, 2.2) and flame.obtener_estadisticas().disparos_segundo == 1.0 and ice.obtener_estadisticas().disparos_segundo == 1.0, "Volcano cadence bonus applies only to the other elements")
	_check(flame.modificador_dano == 0.2 and ice.modificador_dano == -0.2 and volcano.obtener_produccion_agua() == 0.07, "Volcano configures damage and reduced water production")
	var ice_beast = _enemy(volcano, "glacies")
	_check(ice_beast.vida_maxima == 275.0, "Volcano halves base Glacies beast HP")
	weather.actualizar(9.0)
	_check(nature.vida == 100, "Geyser waits ten seconds")
	weather.actualizar(1.0)
	_check(nature.vida == 75 and is_equal_approx(nature.obtener_estadisticas().disparos_segundo, 2.75) and nature.bono_geiser_restante == 7.0, "Geyser deals 25 and boosts cadence by twenty-five percent")
	_check(flame.vida == 250 and flame.bono_geiser_restante == 0.0 and ice.vida == 150, "Flamma is immune to both geyser effects; non-adjacent trees are unaffected")
	weather.actualizar(7.0)
	_check(nature.bono_geiser_restante == 0.0 and is_equal_approx(nature.obtener_estadisticas().disparos_segundo, 2.2), "Geyser cadence returns to climate baseline after seven seconds")
	weather.actualizar(8.0)
	_check(weather.conteos.get("geiser", 0) == 2 and weather.conteos.get("erupcion", 0) == 1 and nature.is_queued_for_deletion(), "Long updates apply geyser and eruption in chronological order")
	weather.indice_fijo = 0
	weather.erupcion()
	_check(flame.vida == 250, "An eruption selecting Flamma respects immunity")
	var fire_beast = _enemy(volcano, "flamma")
	var bullet = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	bullet.elemento = "flamma"
	bullet.dano = 40
	bullet.modificador_dano = 0.2
	volcano.arboles.add_child(bullet)
	bullet.set_process(false)
	bullet._golpear(fire_beast)
	_check(is_equal_approx(fire_beast.vida, 412.0), "Volcano damage adds to elemental resistance: 40 * (1 -.25 + .20) = 38")
	volcano.free()
	# Blizzard stages persist through upgrades and combine with independent auras.
	var snow = _level("ventisca")
	weather = snow.gestor_clima
	var frozen = _plant(snow, Vector2i(6, 3), 0)
	var warm = _plant(snow, Vector2i(0, 3), 1)
	var immune_ice = _plant(snow, Vector2i(10, 3), 5)
	_check(is_equal_approx(immune_ice.obtener_estadisticas().disparos_segundo, 1.2) and warm.modificador_dano == 0.1, "Blizzard configures Glacies cadence and Flamma damage")
	_check(_enemy(snow, "glacies").velocidad == 0.3 * 64.0 * 1.2 and _enemy(snow, "flamma").vida_maxima == 540.0, "Blizzard modifies beast speed and HP")
	weather.actualizar(10.0)
	_check(frozen.vida == 75 and frozen.nivel_congelacion == 1, "First sweep deals 25 HP and one freeze level")
	_check(warm.vida == 250 and immune_ice.vida == 150, "Flamma and Glacies trees are immune to climate freezing damage")
	weather.actualizar(20.0)
	_check(frozen.vida == 25 and frozen.nivel_congelacion == 3 and frozen.temporizador.paused and frozen.obtener_estadisticas().disparos_segundo == 0.0, "Third sweep fully disables the attack timer")
	frozen._aplicar_tamano("mediano")
	frozen.temporizador.stop()
	_check(frozen.nivel_congelacion == 3 and frozen.temporizador.paused, "Upgrading cannot reset climate freeze levels")
	var local_fire = _plant(snow, Vector2i(7, 3), 1)
	weather.actualizar(10.0)
	_check(frozen.nivel_congelacion == 2 and frozen.protegido_ventisca and not frozen.temporizador.paused, "Warm pulse reduces one level and prevents the simultaneous new freeze")
	var hp: int = frozen.vida
	weather.actualizar(10.0)
	_check(frozen.nivel_congelacion == 2 and frozen.vida == hp - 25, "Warm protection blocks new levels but not blizzard HP damage")
	snow._quitar_arbol(Vector2i(7, 3))
	weather.actualizar(0.0)
	_check(not frozen.protegido_ventisca, "Removing Flamma immediately removes climate protection on update")
	snow.free()
	# Falling rock travels downward and Terra absorbs exactly three impacts.
	var collapse = load("res://demo/mecanicas_derrumbe.tscn").instantiate()
	root.add_child(collapse)
	collapse.set_process(false)
	collapse.set_physics_process(false)
	_check(collapse.inicializado and collapse.rutas_adicionales.is_empty() and collapse.puntos_ruta[1].y - collapse.puntos_ruta[0].y == 12, "Collapse laboratory uses a long vertical route")
	var barrier = _plant(collapse, Vector2i(4, 8), 3)
	var above = _plant(collapse, Vector2i(5, 3), 0)
	# Free grass in the same column below the road is unavailable; protected beasts exercise shielding.
	var behind = _enemy(collapse, "flamma", 7.0 * 64.0)
	var ahead = _enemy(collapse, "flamma", 2.0 * 64.0)
	var armor_beast = _enemy(collapse, "terra", 1.0 * 64.0)
	weather = collapse.gestor_clima
	weather.derrumbe_en(4)
	_check(barrier.golpes_derrumbe == 1 and barrier.vida == 1000 and not behind.muerto and ahead.muerto and armor_beast.muerto, "Terra stops the rock; beasts above it are destroyed without armor or resurrection")
	barrier._aplicar_tamano("mediano")
	weather.derrumbe_en(4)
	_check(barrier.golpes_derrumbe == 2 and barrier.vida == 2000, "Terra upgrades do not reset accumulated rock impacts")
	weather.derrumbe_en(4)
	_check(barrier.is_queued_for_deletion() and not behind.muerto, "Third rock destroys Terra but is still absorbed")
	weather.derrumbe_en(4)
	_check(behind.muerto and above.vida == 100, "Subsequent rocks continue down the column; adjacent columns remain safe")
	_check(not collapse._se_puede_plantar(Vector2i(4, 8), 0), "Destroyed road Terra leaves the road reserved")
	collapse.free()
	var fall = _level("derrumbe")
	weather = fall.gestor_clima
	var protected = _plant(fall, Vector2i(4, 6), 0)
	weather.actualizar(12.5)
	_check(weather.avisos.get("derrumbe") == Vector2i(4, fall.FILAS_BLOQUEADAS) and protected.vida == 100, "Rockfall marks its column 2.5 seconds before impact")
	paused = true
	weather.actualizar(8.0)
	_check(weather.tiempo == 12.5 and weather.avisos.has("derrumbe"), "Pause freezes a pending warning")
	paused = false
	var response_terra = _plant(fall, Vector2i(4, 5), 3)
	weather.columna_fija = 10
	weather.actualizar(2.49)
	_check(response_terra.golpes_derrumbe == 0, "Rockfall waits until the full warning elapses")
	weather.actualizar(0.01)
	_check(response_terra.golpes_derrumbe == 1 and protected.vida == 100 and weather.avisos.is_empty(), "A Terra planted during the warning shields the original column")
	weather.actualizar(12.5)
	fall._on_espiritu_llego(fall.arbol_meta.vida)
	weather.actualizar(100.0)
	_check(weather.avisos.is_empty() and weather.conteos.derrumbe == 1, "Defeat cancels pending warnings and their damage")
	paused = false
	fall.free()
	# Radiation only pulses during a wave and has no instant-death roll.
	var radioactive = _level("radiacion")
	weather = radioactive.gestor_clima
	var vulnerable = _plant(radioactive, Vector2i(0, 3), 0)
	var poison = _plant(radioactive, Vector2i(1, 3), 6)
	_check(is_equal_approx(vulnerable.obtener_estadisticas().disparos_segundo, 2.1) and is_equal_approx(poison.obtener_estadisticas().disparos_segundo, 0.3), "Radiation boosts cadence except Venenum")
	_check(_enemy(radioactive, "venenum").vida_maxima == 600.0, "Radiation no longer buffs Venenum beast HP")
	weather.actualizar(30.0)
	_check(weather.tiempo == 0.0 and vulnerable.vida == 100, "Radiation does not punish setup time")
	radioactive._iniciar_ronda()
	weather.actualizar(7.99)
	_check(vulnerable.vida == 100, "Radiation waits eight seconds before the first pulse")
	weather.tirada = 0.0
	weather.actualizar(0.01)
	_check(vulnerable.vida == 94 and poison.vida == 500 and weather.conteos.radiacion == 1, "Radiation chips six HP per pulse and never damages Venenum")
	weather.actualizar(16.0)
	_check(vulnerable.vida == 82 and weather.conteos.radiacion == 3, "Even the lowest random roll never causes instant death")
	var clock: float = weather.tiempo
	paused = true
	weather.actualizar(100.0)
	_check(weather.tiempo == clock and poison.vida == 500, "Pause freezes all weather timers and damage")
	paused = false
	radioactive.terminado = true
	weather.actualizar(100.0)
	_check(weather.tiempo == clock, "Outcomes freeze climate hazards")
	radioactive.free()
	# Every selector destination is a loadable, initialized scene.
	var catalog = load("res://demo/mecanicas_lluvia.gd").LABORATORIOS
	for entry in catalog:
		var lab = load("res://demo/" + entry.escena + ".tscn").instantiate()
		root.add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		await process_frame
		_check(lab.inicializado and lab.clima == entry.clima and lab.hud.botones_laboratorio.size() == 2, "Every climate selector destination initializes with navigation")
		var rect: Rect2 = lab.hud.panel_laboratorio.get_global_rect()
		_check(root.get_visible_rect().encloses(rect) and lab.hud.punto_sobre_hud(rect.get_center()), "Selector fits the viewport and blocks planting through it")
		lab.free()
	var live = _level("radiacion")
	var live_tree = _plant(live, Vector2i(6, 3), 0)
	live._iniciar_ronda()
	live.gestor_clima.tiempo = 7.0
	live.set_physics_process(true)
	for i in Engine.physics_ticks_per_second + 3:
		await physics_frame
	_check(live_tree.vida == 94 and live.gestor_clima.conteos.radiacion == 1, "Actual level physics advances weather hazards")
	live.free()
	var navigation = load("res://demo/mecanicas_despejado.tscn").instantiate()
	root.add_child(navigation)
	current_scene = navigation
	navigation.set_process(false)
	navigation.set_physics_process(false)
	await process_frame
	navigation._on_semilla_pulsada(0, false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = navigation.hud.botones_laboratorio[1].get_global_rect().get_center()
	root.push_input(click, true)
	await process_frame
	await process_frame
	await process_frame
	_check(is_instance_valid(current_scene) and current_scene.clima == "lluvia" and current_scene.arboles_plantados.is_empty(), "Clicking the selector restarts the requested laboratory without planting underneath")
	var replacement = current_scene
	current_scene = null
	replacement.free()
	save.slot_actual = old_slot
	await process_frame
	print("Advanced weather checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
