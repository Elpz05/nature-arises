extends SceneTree

const FORMACION := [
	Vector2i(8, 6), Vector2i(13, 5), Vector2i(8, 5), Vector2i(18, 9),
	Vector2i(14, 5), Vector2i(15, 6), Vector2i(16, 5),
]

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _run():
	var save = root.get_node("Guardado")
	var settings = root.get_node("Ajustes")
	var original_config: ConfigFile = settings.config
	settings.config = ConfigFile.new()
	settings.config.set_value("interfaz", "hud_debug", true)
	var original_slot: int = save.slot_actual
	save.slot_actual = -1
	var level = load("res://escenas/escenas_niveles/nivel_7.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	for i in FORMACION.size() - 1:
		level._on_semilla_pulsada(i, false)
		level._confirmar(level.suelo.map_to_local(FORMACION[i]))
	_check(level.arboles_plantados.size() == 6 and level.gotas == 6, "Finale funding requires choosing which trees to start with")
	level._iniciar_ronda()
	level._actualizar_recursos(28.0)
	_check(level.pozo.reserva == 4 and level.gotas == 6, "Aqua speeds up the well without crediting the wallet")
	level._recoger_en_objetivo(level.suelo.map_to_local(level.celda_pozo))
	level._on_semilla_pulsada(6, false)
	level._confirmar(level.suelo.map_to_local(FORMACION[6]))
	_check(level.arboles_plantados.size() == 7 and level.gotas == 0, "All seven elements fit after earning and collecting the remaining water")
	var aqua = level.arboles_plantados[FORMACION[2]]
	var natura = level.arboles_plantados[FORMACION[0]]
	var venenum = level.arboles_plantados[FORMACION[6]]
	var weather = level.gestor_clima
	_check(not level._es_camino(FORMACION[2]) and not level._se_puede_plantar(Vector2i(7, 5), 0), "Aqua can use safe cisterns away from enemy traffic and dry-land trees cannot occupy them")
	_check(natura.obtener_iconos_combate().has("proteccion_aqua") and not aqua.obtener_iconos_combate().has("proteccion_aqua"), "The Aqua badge marks orthogonal allies that receive protection")
	weather.actualizar(8.0)
	_check(aqua.vida == 94 and natura.vida == 97 and venenum.vida == 500, "Radiation chips Aqua, its orthogonal neighbors take half, and Venenum is immune")
	level._quitar_arbol(FORMACION[2])
	_check(not natura.obtener_iconos_combate().has("proteccion_aqua"), "Removing Aqua clears its shield before the next pulse")
	weather.actualizar(8.0)
	_check(natura.vida == 91, "Aqua protection ends when the supporting tree is removed")

	var electrical: Path2D = level._ruta_para_tipo("electricitas")
	var main: Path2D = level.ruta
	var join: Vector2 = level._atajos.electricitas.union
	_check(level._ruta_para_tipo("flamma") != electrical and level._ruta_para_tipo("terra") == main, "Each elemental shortcut serves its own enemies")
	_check(main.curve.get_baked_length() > electrical.curve.get_baked_length(), "Electricitas uses a genuinely shorter branch")
	_check(electrical.curve.sample_baked(join.x).is_equal_approx(main.curve.sample_baked(join.y)), "Route offsets coincide exactly at the authored merge")
	level._crear_espiritu("electricitas", "pequeno", join.x - 96.0)
	var follower := electrical.get_child(0) as PathFollow2D
	var enemy = follower.get_child(0)
	enemy.set_physics_process(false)
	var terra = level.arboles_plantados[FORMACION[3]]
	var origin := follower.progress
	var stop: float = level._resolver_avance_terra(enemy, origin, join.x + 48.0)
	_check(follower.get_parent() == electrical and stop < origin and terra.vida == 938, "Terra on the exclusive leg stops a large step before the merge")
	level._quitar_arbol(FORMACION[3])
	var end: float = level._resolver_avance_terra(enemy, origin, join.x + 48.0)
	_check(follower.get_parent() == main and is_equal_approx(end, join.y + 48.0), "Merging transfers the follower and preserves its unused travel")
	_check(level._bestias_en_camino() == 1, "Merged enemies count once")
	follower.free()

	level.celda_torre_seleccionada = FORMACION[6]
	level._actualizar_tooltip()
	await process_frame
	await process_frame
	var board_top: int = level.FILAS_BLOQUEADAS * level.TAM_CELDA
	var viewport := root.get_visible_rect()
	for panel in [level.hud.barra, level.hud.panel_combate, level.panel_torre]:
		var bounds: Rect2 = panel.get_global_rect()
		_check(viewport.encloses(bounds) and bounds.end.y <= board_top + 0.01, "HUD panels fit entirely in the reserved top rows: %s" % bounds)
	_check(level.panel_torre.visible and level.tooltip.text.contains("Venenum"), "Tower inspection stays visible in the dock")
	_check(not level.hud.punto_sobre_hud(level.suelo.map_to_local(level.celda_pozo)), "HUD never intercepts the central well")
	_check(not level.hud.punto_sobre_hud(level.suelo.map_to_local(Vector2i(0, 16))) and not level.hud.punto_sobre_hud(level.suelo.map_to_local(Vector2i(29, 16))), "Both lower board corners remain unobstructed")
	if OS.get_cmdline_user_args().has("--capture-ui"):
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://.godot/finale-dock.png") == OK, "Render capture succeeds")
	level._limpiar_inspeccion()
	level.ronda = 5
	level._actualizar_ronda_hud()
	level._actualizar_combate_hud()
	await process_frame
	await process_frame
	_check(level.hud.label_consejo.visible and level.hud.label_consejo.text.contains("Venenum"), "Finale shows a different tactical tip for later waves")
	_check(level.hud.panel_combate.get_global_rect().end.y <= board_top + 0.01, "Wave and mission text stay above the playable map")
	level.free()
	settings.config = original_config
	save.slot_actual = original_slot
	print("Finale routing, roles and HUD checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
