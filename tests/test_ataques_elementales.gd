extends SceneTree

class NatacionControlada extends "res://scripts/entidades/bestias/espiritu.gd":
	var tirada := 0.0
	func _tirada_natacion() -> float:
		return tirada

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _enemy(level, tipo: String = "natura", progress: float = 500.0, size: String = "mediano"):
	level._crear_espiritu(tipo, size, progress)
	var path = level._ruta_para_tipo(tipo)
	var enemy = path.get_child(path.get_child_count() - 1).get_child(0)
	enemy.set_physics_process(false)
	return enemy

func _clear(level):
	for path in [level.ruta] + level.rutas_enemigos.values():
		for follower in path.get_children():
			follower.free()

func _run():
	var save = root.get_node("Guardado")
	var old_slot: int = save.slot_actual
	save.slot_actual = -1
	var level = load("res://demo/mecanicas_lluvia.tscn").instantiate()
	root.add_child(level)
	level.set_process(false)
	level.set_physics_process(false)
	level.clima = "despejado"
	_check(level.hud.ATAQUES_ACTIVOS.size() == 7 and level.cargas[6] == 2, "Lab enables seven spells and gives Venenum two whole charges")
	_check(level.hud.botones_ataque[6].text.contains("●●") and level.hud.botones_ataque[6].tooltip_text.contains("2/2"), "HUD displays whole Venenum charges as pips")
	var immune := {"Natura": ["flamma", "venenum"], "Flamma": ["flamma", "aqua"], "Aqua": ["aqua"], "Terra": ["terra"], "Electricitas": ["electricitas"], "Glacies": ["glacies"], "Venenum": ["venenum"]}
	for spell in immune:
		for tipo in immune[spell]:
			var enemy = _enemy(level, tipo)
			var hp: float = enemy.vida
			_check(not enemy.aplicar_ataque_elemental(spell, 100.0) and enemy.vida == hp and enemy.efecto_movimiento.elemento == "" and enemy.efecto_dano.elemento == "", "Immune targets receive neither spell damage nor status: " + spell + " / " + tipo)
	_clear(level)
	for entry in [["Flamma", "glacies", 20.0], ["Aqua", "flamma", 30.0], ["Glacies", "flamma", 10.0], ["Glacies", "aqua", 10.0]]:
		var enemy = _enemy(level, entry[1])
		var hp: float = enemy.vida
		enemy.aplicar_ataque_elemental(entry[0], entry[2])
		_check(is_equal_approx(hp - enemy.vida, entry[2] * 2.0), "Spell elemental advantage doubles direct damage")
	_clear(level)
	var nature = _enemy(level)
	nature.aplicar_ataque_elemental("Natura", 10.0)
	var start: float = nature.get_parent().progress
	nature._physics_process(0.25)
	_check(nature.vida == 490.0 and nature.get_parent().progress == start, "Natura stops movement and deals ten damage")
	nature._physics_process(0.5)
	_check(is_equal_approx(nature.get_parent().progress - start, nature.velocidad * 0.25), "Natura movement resumes at the exact expiry time")
	var burned = _enemy(level)
	burned.aplicar_ataque_elemental("Flamma", 20.0)
	burned._physics_process(4.0)
	_check(burned.vida == 450.0 and burned.efecto_dano.elemento == "", "Flamma adds precisely thirty burn damage over three seconds")
	var changed = _enemy(level)
	changed.aplicar_ataque_elemental("Flamma", 20.0)
	changed.aplicar_ataque_elemental("Glacies", 10.0)
	var congelado_en: float = changed.get_parent().progress
	changed._physics_process(1.0)
	_check(changed.vida == 460.0 and changed.get_parent().progress == congelado_en and changed.obtener_estado_combate().contains("Quemadura"), "Burn continues ticking while Glacies stops movement")
	changed.aplicar_ataque_elemental("Glacies", 0.0)
	_check(changed.efecto_movimiento.restante == 2.0 and changed.efecto_dano.restante == 2.0, "A second freeze refreshes a single movement slot without resetting the burn")
	changed.aplicar_veneno(2.0, 0.73, 6.0)
	changed.aplicar_ataque_elemental("Terra", 0.0)
	changed._physics_process(1.0)
	_check(changed.vida == 448.0 and changed.veneno_restante > 0.0 and changed.efecto_movimiento.elemento == "terra", "A different movement spell replaces freeze but preserves burn and tree poison")
	var immune_change = _enemy(level, "aqua")
	immune_change.aplicar_ataque_elemental("Glacies", 0.0)
	immune_change.aplicar_ataque_elemental("Flamma", 20.0)
	_check(immune_change.efecto_movimiento.elemento == "glacies", "An ineffective immune spell does not cleanse an existing effect")
	var thaw = _enemy(level)
	thaw.aplicar_ataque_elemental("Glacies", 0.0)
	thaw.aplicar_ataque_elemental("Venenum", 0.0, true)
	thaw.remover_congelacion()
	_check(thaw.efecto_movimiento.elemento == "" and thaw.efecto_dano.elemento == "venenum", "Thaw clears freeze and retains vulnerability")
	# Dizziness integrates each half-second, independent of frame size.
	var dizzy = _enemy(level)
	dizzy.aplicar_ataque_elemental("Terra", 50.0)
	start = dizzy.get_parent().progress
	dizzy._physics_process(0.5)
	_check(dizzy.get_parent().progress == start, "Terra stops the first half-second")
	dizzy._physics_process(0.5)
	_check(is_equal_approx(dizzy.get_parent().progress - start, dizzy.velocidad * 0.5), "Terra permits the second half-second")
	var dizzy_large = _enemy(level)
	var dizzy_small = _enemy(level)
	for enemy in [dizzy_large, dizzy_small]:
		enemy.aplicar_ataque_elemental("Terra", 0.0)
	dizzy_large._physics_process(4.0)
	for i in 40:
		dizzy_small._physics_process(0.1)
	_check(is_equal_approx(dizzy_large.get_parent().progress, dizzy_small.get_parent().progress) and is_equal_approx(dizzy_large.get_parent().progress - 500.0, dizzy_large.velocidad * 2.5), "Dizziness timing is independent of frame size, including expiry")
	var reversed = _enemy(level)
	reversed.aplicar_ataque_elemental("Electricitas", 40.0)
	start = reversed.get_parent().progress
	reversed._physics_process(0.5)
	_check(is_equal_approx(reversed.get_parent().progress, start - reversed.velocidad * 0.5) and reversed.vida == 460.0, "Electricitas moves backwards for half a second")
	var at_spawn = _enemy(level, "natura", 0.0)
	at_spawn.aplicar_ataque_elemental("Electricitas", 0.0)
	at_spawn._physics_process(1.0)
	_check(is_equal_approx(at_spawn.get_parent().progress, at_spawn.velocidad * 0.5), "Reversal clamps at route start and still resumes forward movement within a long frame")
	var ice = _enemy(level)
	ice.aplicar_ataque_elemental("Glacies", 10.0)
	start = ice.get_parent().progress
	ice._physics_process(2.5)
	_check(is_equal_approx(ice.get_parent().progress - start, ice.velocidad * 0.5), "Glacies spell freezes precisely two seconds")
	_clear(level)
	# Confusion switches on a common road without a position jump.
	var fire = _enemy(level, "flamma", 500.0)
	var position: Vector2 = fire.global_position
	fire.aplicar_ataque_elemental("Aqua", 30.0)
	_check(fire.get_parent().get_parent() == level.ruta and fire.global_position.is_equal_approx(position), "Aqua immediately ignores a shortcut when still on the shared road")
	var exclusive = _enemy(level, "flamma", 2000.0)
	position = exclusive.global_position
	exclusive.aplicar_ataque_elemental("Aqua", 0.0)
	_check(exclusive.get_parent().get_parent() != level.ruta and exclusive.global_position.is_equal_approx(position), "Aqua never teleports off an exclusive shortcut segment")
	exclusive.aplicar_ataque_elemental("Venenum", 0.0)
	exclusive._physics_process(3.0)
	_check(exclusive.get_parent().get_parent() == level.ruta and exclusive.efecto_dano.elemento == "venenum", "Confusion reroutes at the next junction while vulnerability stays active")
	level._plantar(Vector2i(26, 9), 3)
	var barrier = level.arboles_plantados[Vector2i(26, 9)]
	var blocked = _enemy(level, "flamma", 1940.0)
	blocked.aplicar_ataque_elemental("Aqua", 0.0)
	blocked._physics_process(6.0)
	_check(barrier.vida == 900 and blocked.get_parent().get_parent() != level.ruta and blocked.get_parent().progress < 1952.0, "Confusion cannot skip a Terra blocker before a route junction")
	level._quitar_arbol(Vector2i(26, 9))
	var swimmer = load("res://escenas/escenas_espiritu/espiritu_prueba.tscn").instantiate()
	swimmer.set_script(NatacionControlada)
	var follow := PathFollow2D.new()
	follow.loop = false
	level.ruta.add_child(follow)
	follow.progress = 200.0
	follow.add_child(swimmer)
	swimmer.set_physics_process(false)
	swimmer.aplicar_ataque_elemental("Aqua", 0.0)
	swimmer._physics_process(0.1)
	_check(swimmer.efecto_movimiento.nadando and absf(swimmer.sprite.rotation) > 0.01, "Aqua swimming roll triggers a visible half-second animation")
	swimmer._physics_process(0.5)
	_check(is_zero_approx(swimmer.sprite.rotation), "Swimming animation ends independently of confusion")
	swimmer.tirada = 0.5
	swimmer.aplicar_ataque_elemental("Aqua", 0.0)
	_check(not swimmer.efecto_movimiento.nadando, "Swimming probability uses the fifty-percent boundary")
	_clear(level)
	# Area vulnerability affects all eligible victims, slow affects three distinct ones.
	var victims: Array = []
	for i in 5:
		victims.append(_enemy(level, "aqua", 100.0 + i * 10.0))
	var immune_venom = _enemy(level, "venenum", 100.0)
	var tiny = _enemy(level, "natura", 100.0, "pequeno")
	var distant = _enemy(level, "aqua", 1000.0)
	var center: Vector2 = level.to_local(victims[0].global_position)
	_check(level._lanzar_ataque(center, 6), "Venenum casts from the actual level API")
	var slowed := 0
	for enemy in victims:
		_check(enemy.vida == 400.0 and enemy.efecto_dano.elemento == "venenum", "Venenum area applies damage and vulnerability to each eligible victim")
		if enemy.efecto_dano.ralentizado:
			slowed += 1
	_check(slowed == 3 and immune_venom.vida == 600.0 and distant.vida == 500.0 and tiny.muerto, "Venenum slows three distinct victims, respects immunity/radius and kills small Natura")
	var projectile = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	projectile.dano = 20
	level.arboles.add_child(projectile)
	projectile.set_process(false)
	projectile._golpear(victims[0])
	_check(victims[0].vida == 379.0, "Vulnerability adds exactly one damage to a tree projectile")
	victims[0].recibir_dano(2.0, false)
	_check(victims[0].vida == 377.0, "Vulnerability does not add damage to periodic damage")
	victims[0].aplicar_ataque_elemental("Natura", 0.0)
	projectile._golpear(victims[0])
	_check(victims[0].vida == 356.0, "Adding movement control retains the vulnerability bonus")
	var replace_damage = _enemy(level)
	replace_damage.aplicar_ataque_elemental("Natura", 0.0)
	replace_damage.aplicar_ataque_elemental("Venenum", 0.0, true)
	replace_damage.aplicar_ataque_elemental("Flamma", 0.0)
	_check(replace_damage.efecto_dano.elemento == "flamma" and replace_damage.efecto_movimiento.elemento == "natura", "A damage spell can replace a damage effect independently")
	# Whole charges, no overspending, one recovered charge per three seconds.
	_check(level.cargas[6] == 1 and level._lanzar_ataque(Vector2(1800, 1000), 6), "Venenum consumes one charge at a time")
	_check(level.cargas[6] == 0 and not level._lanzar_ataque(center, 6) and level.hud.botones_ataque[6].disabled, "Empty charges cannot cast or go negative")
	level._actualizar_recargas(5.0)
	_check(level.cargas[6] == 0 and level.recarga[6] == 5.0 and level.hud.barras_recarga[6].value == 50.0 and level.hud.botones_ataque[6].tooltip_text.contains("cada 10 s"), "Venenum's ten-second timer and HUD stay in sync")
	level._actualizar_recargas(5.0)
	_check(level.cargas[6] == 1 and level.recarga[6] == 10.0, "First recharge restores one whole charge")
	level._actualizar_recargas(12.0)
	_check(level.cargas[6] == 2 and level.recarga[6] == 0.0, "Long recharge steps cap at two charges")
	level._lanzar_ataque(Vector2(1800, 1000), 5)
	level._lanzar_ataque(Vector2(1800, 1000), 5)
	level._actualizar_recargas(3.0)
	_check(level.cargas[5] == 1 and level.recarga[5] == 3.0 and level.hud.barras_recarga[5].value == 50.0, "Glacies stays spent for six seconds")
	level._actualizar_recargas(9.0)
	_check(level.cargas[5] == 3 and level.recarga[5] == 0.0, "Glacies restores each charge on its own interval")
	level._lanzar_ataque(Vector2(1800, 1000), 1)
	level._lanzar_ataque(Vector2(1800, 1000), 1)
	level._actualizar_recargas(3.0)
	_check(level.cargas[1] == 2.0 and level.hud.barras_recarga[1].visible, "Multi-charge abilities recharge gradually rather than refill instantly")
	_check(not level._lanzar_ataque(center, -1) and not level._lanzar_ataque(center, 7), "Invalid spell indices are rejected safely")
	var paused_enemy = _enemy(level)
	paused_enemy.aplicar_ataque_elemental("Flamma", 0.0)
	var hp: float = paused_enemy.vida
	paused = true
	paused_enemy._physics_process(10.0)
	level._process(10.0)
	_check(paused_enemy.vida == hp and paused_enemy.efecto_dano.restante == 3.0 and level.cargas[1] == 2.0, "Pause freezes burn, spell timers and recharge")
	paused = false
	level.terminado = true
	paused_enemy._physics_process(10.0)
	_check(paused_enemy.vida == hp and not level._lanzar_ataque(center, 0), "Outcome freezes effects and prevents casting")
	level.free()
	save.slot_actual = old_slot
	await process_frame
	print("Elemental ability checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
