extends SceneTree

const VOLCANO := "res://escenas/escenas_niveles/nivel_4.tscn"
const SEEDS := "res://escenas/escenas_balas/"
const NATURA := preload("res://sprites/trees/natura/little/idle/tree_natura_little_idle.png")

class Target extends Node2D:
	var tipo := "natura"
	var muerto := false
	var bloquea := false
	var vida := 100.0

	func recibir_proyectil(cantidad: float) -> bool:
		if bloquea:
			return false
		vida -= cantidad
		muerto = vida <= 0.0
		return true

	func recibir_dano(cantidad: float) -> bool:
		return recibir_proyectil(cantidad)

class ReviewWeather extends "res://scripts/nivel/clima.gd":
	func _indice_aleatorio(_cantidad: int) -> int: return 0

var _errores := 0
var _eventos: Array[Dictionary] = []

func _initialize():
	call_deferred("_run")

func _check(ok: bool, mensaje: String):
	if not ok:
		_errores += 1
		push_error(mensaje)

func _level():
	var nivel = load(VOLCANO).instantiate()
	root.add_child(nivel)
	nivel.set_process(false)
	nivel.set_physics_process(false)
	nivel.presentacion.evento.connect(func(tipo, elemento, posiciones):
		_eventos.append({"tipo": tipo, "elemento": elemento, "pos": posiciones})
	)
	return nivel

func _target(punto: Vector2, tipo := "natura", bloqueo := false) -> Target:
	var victima := Target.new()
	victima.position = punto
	victima.tipo = tipo
	victima.bloquea = bloqueo
	victima.add_to_group("bestias")
	root.add_child(victima)
	return victima

func _bala(nivel, escena: String, elemento: String, objetivo: Target):
	var bala = load(SEEDS + escena + ".tscn").instantiate()
	bala.elemento = elemento
	bala.presentacion = nivel.presentacion
	bala.objetivo = objetivo
	bala.dano = 120
	bala.position = Vector2(100, 100)
	nivel.arboles.add_child(bala)
	bala.set_physics_process(false)
	return bala

func _de(tipo: String, elemento: String) -> Array:
	return _eventos.filter(func(e): return e.tipo == tipo and e.elemento == elemento)

func _proyectiles(activo: bool) -> Array:
	seed(812)
	_eventos.clear()
	var nivel = _level()
	nivel.presentacion.activo = activo
	var inmune := _target(Vector2(100, 100), "aqua")
	var armadura := _target(Vector2(107, 100), "terra", true)
	var primero := _target(Vector2(120, 100))
	var segundo := _target(Vector2(150, 100))
	var bala = _bala(nivel, "bala_flamma", "flamma", inmune)
	bala.radio_explosion = 55.0
	_check(_de("impacto", "flamma").is_empty(), "Spawn cannot announce an impact")
	bala._physics_process(0.01)
	_check(_de("lanzamiento", "flamma").size() == int(activo), "Flamma launches once")
	if activo:
		var impactos := _de("impacto", "flamma")
		_check(impactos.size() == 1 and impactos[0].pos == PackedVector2Array([primero.position, segundo.position]),
			"One Flamma splash reports both lethal hits, excluding armor and Aqua")
	var sin_dano = _bala(nivel, "bala_flamma", "flamma", inmune)
	sin_dano._physics_process(0.01)
	var bloqueada = _bala(nivel, "bala", "natura", armadura)
	bloqueada._physics_process(0.04)
	var fuera = _bala(nivel, "bala", "natura", null)
	fuera._physics_process(0.04)
	_check(_de("impacto", "flamma").size() == int(activo) and _de("impacto", "natura").is_empty(),
		"Immune, blocked, and missing targets yield no damaging impact")
	var resultados := [inmune.vida, armadura.vida, primero.vida, segundo.vida, randf()]
	for victima in [inmune, armadura, primero, segundo]:
		victima.free()

	var hielo_a := _target(Vector2(130, 100))
	var hielo_b := _target(Vector2(157, 100))
	var hielo = _bala(nivel, "carambano", "glacies", hielo_a)
	hielo._physics_process(0.16)
	if activo:
		var impactos := _de("impacto", "glacies")
		_check(impactos.size() == 1 and impactos[0].pos == PackedVector2Array([hielo_a.position, hielo_b.position]),
			"Glacies reports each confirmed piercing hit in spatial order")
	resultados.append_array([hielo_a.vida, hielo_b.vida])
	hielo_a.free()
	hielo_b.free()

	var chispa_a := _target(Vector2(140, 100))
	var chispa_b := _target(Vector2(180, 100), "terra", true)
	var chispa_c := _target(Vector2(211, 100))
	var cadena = _bala(nivel, "descarga", "electricitas", chispa_a)
	cadena.candidatos = [chispa_a, chispa_b, chispa_c]
	cadena._physics_process(0.02)
	if activo:
		var impactos := _de("impacto", "electricitas")
		_check(cadena.puntos.size() == 4 and impactos.size() == 1
			and impactos[0].pos == PackedVector2Array([chispa_a.position, chispa_c.position]),
			"Electricitas keeps its chain path and reports confirmed endpoints once")
	resultados.append_array([chispa_a.vida, chispa_b.vida, chispa_c.vida])
	for victima in [chispa_a, chispa_b, chispa_c]:
		victima.free()
	nivel.free()
	return resultados

func _natura_y_veneno():
	var nivel = _level()
	_check(nivel._plantar(Vector2i(5, 5), 0), "Natura fixture must plant")
	var arbol = nivel.arboles_plantados[Vector2i(5, 5)]
	var imagen := NATURA.get_image()
	for i in range(5):
		var original := imagen.get_region(Rect2i(i * 32, 0, 32, 32))
		var nuevo: Image = arbol.sprite.sprite_frames.get_frame_texture("idle_pequeno", i).get_image()
		var corona := Rect2i(0, 0, 32, 16)
		var ancho: int = nuevo.get_region(corona).get_used_rect().size.x
		var anterior := original.get_region(corona).get_used_rect().size.x
		_check(float(ancho) / anterior >= 0.80 and float(ancho) / anterior <= 0.85,
			"Natura canopy width must shrink by 15–20%% in cel %d" % i)
		_check(nuevo.get_used_rect().end.y == original.get_used_rect().end.y,
			"Natura's trunk must retain its frame anchor")
	for tamano in ["pequeno", "mediano", "grande"]:
		arbol._aplicar_tamano(tamano)
		var esperado: float = arbol._datos(tamano).radio * nivel.TAM_CELDA
		_check(is_equal_approx(arbol.forma.shape.radius * arbol.forma.global_scale.x, esperado)
			and arbol.global_position == nivel.suelo.map_to_local(Vector2i(5, 5)),
			"Natura physics range and shot origin must match the board anchor for " + tamano)
	nivel._crear_espiritu("natura", "pequeno", 100.0)
	var bestia = nivel.ruta.get_child(0).get_child(0)
	bestia.aplicar_veneno(2.0, 0.75, 2.0)
	_check(bestia.tiene_marca_veneno(), "Real poison starts the persistent marker")
	bestia._limpiar_veneno()
	_check(not bestia.tiene_marca_veneno(), "Clearing poison also clears its marker")
	bestia.aplicar_veneno(2.0, 0.75, 2.0)
	bestia.recibir_dano(100000.0)
	_check(not bestia.tiene_marca_veneno(), "Death immediately removes the marker")
	nivel.free()

func _clima():
	_eventos.clear()
	var nivel = _level()
	nivel.gestor_clima.free()
	var gestor := ReviewWeather.new()
	gestor.nivel = nivel
	nivel.gestor_clima = gestor
	nivel.add_child(gestor)
	var celda := Vector2i(9, 3)
	nivel._plantar(celda, 0)
	gestor._anunciar("geiser")
	gestor.presentar_avisos(20.0)
	_check(_de("aviso", "geiser").is_empty(), "Preparation is silent")
	nivel._iniciar_ronda()
	nivel.velocidad_partida = 8.0
	nivel._aplicar_tiempo(8.0)
	gestor._anunciar("geiser")
	gestor._anunciar("erupcion")
	gestor.presentar_avisos(0.0)
	gestor.presentar_avisos(0.30)
	var id: int = gestor.avisos.erupcion.objetivo
	nivel._abrir_pausa()
	nivel.pausa._abrir_ajustes()
	gestor.presentar_avisos(20.0)
	gestor.actualizar(100.0)
	_check(gestor.avisos.erupcion.objetivo == id and is_equal_approx(gestor.avisos.erupcion.visible, 0.30),
		"Settings freezes the target and warning time")
	nivel.pausa.ajustes._on_volver_pressed()
	nivel.pausa._continuar()
	_check(Engine.time_scale == 8.0 and _de("aviso", "geiser").size() == 1 and _de("aviso", "erupcion").size() == 1,
		"8x Settings resume preserves both one-shot alert events")
	nivel._quitar_arbol(celda)
	nivel._plantar(celda, 0)
	gestor.presentar_avisos(2.0)
	gestor.actualizar(2.0)
	_check(_de("clima", "geiser").size() == 2 and _de("clima", "erupcion").is_empty(),
		"Both vents resolve after warning; a removed eruption target emits no hit on its replacement")
	nivel.cola_bestias.clear()
	nivel._terminar_ronda()
	gestor._anunciar("geiser")
	gestor.presentar_avisos(20.0)
	_check(_de("aviso", "geiser").size() == 1, "Break is silent")
	nivel.free()

func _run():
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == &"Master", "Ambience is independent of SFX")
	for bus in ["UI", "Combat", "Alerts"]:
		_check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"SFX", bus + " honors SFX volume")
	var con_fx := _proyectiles(true)
	_check(con_fx == _proyectiles(false), "Presentation toggle preserves same-seed damage and RNG")
	_natura_y_veneno()
	_clima()
	root.get_node("MusicaManager").player.stop()
	await process_frame
	print("P2 presentation: " + ("PASS" if _errores == 0 else "FAIL (%d)" % _errores))
	quit(_errores)
