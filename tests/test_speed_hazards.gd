extends SceneTree

const LAB := "res://demo/mecanicas_lluvia.tscn"
const LEVEL := "res://escenas/escenas_niveles/nivel_0.tscn"
const WEATHER := {
	"geiser": "volcan", "erupcion": "volcan", "rayo": "tormenta",
	"derrumbe": "derrumbe", "ventisca": "ventisca", "radiacion": "radiacion",
}
const CELL := Vector2i(5, 3)
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
var failures := 0

class ControlledWeather extends "res://scripts/nivel/clima.gd":
	func _azar() -> float: return 0.0
	func _celda_aleatoria() -> Vector2i: return CELL
	func _columna_aleatoria() -> int: return CELL.x
	func _indice_aleatorio(_cantidad: int) -> int: return 0

func _initialize():
	call_deferred("_run")

func _check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)

func _pad(level, button: JoyButton, pressed: bool):
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	level._input(event)

func _speed_checks():
	var level = load(LEVEL).instantiate()
	root.add_child(level)
	await process_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	key.pressed = true
	level._input(key)
	_check(Engine.time_scale == 2.0 and Engine.physics_ticks_per_second == 120, "V selects 2x")
	level._on_semilla_pulsada(0, false)
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(level._bumper_pendiente != null, "First bumper waits for a chord")
	_pad(level, JOY_BUTTON_LEFT_SHOULDER, true)
	_check(Engine.time_scale == 4.0 and Engine.max_physics_steps_per_frame == 16 and level.seleccion_indice == 0, "Chord consumes navigation at 4x")
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, false)
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(Engine.time_scale == 4.0, "Chord must rearm only after both releases")
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, false)
	_pad(level, JOY_BUTTON_LEFT_SHOULDER, false)
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, true)
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, false)
	_check(level._bumper_pendiente == null and Engine.time_scale == 4.0, "A lone release dispatches its navigation without changing speed")
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, true)
	level._plazo_bumper = 0
	level._process(0.0)
	_check(level._bumper_pendiente == null and Engine.time_scale == 4.0, "A lone press dispatches after the chord deadline")
	_pad(level, JOY_BUTTON_RIGHT_SHOULDER, false)
	level.hud.boton_velocidad.pressed.emit()
	_check(Engine.time_scale == 8.0 and Engine.physics_ticks_per_second == 480 and Engine.max_physics_steps_per_frame == 32, "HUD selects 8x with sufficient physics steps")
	level._abrir_pausa()
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60 and Engine.max_physics_steps_per_frame == 8, "Pause normalizes engine timing")
	level.pausa._continuar()
	await process_frame
	_check(Engine.time_scale == 8.0, "Resume restores the selected speed")
	level._input(key)
	_check(Engine.time_scale == 1.0, "8x wraps back to 1x")
	level._input(key)
	level.free()
	_check(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Level exit normalizes timing")

func _weather_check(tipo: String, speed: float):
	var level = load(LAB).instantiate()
	level.clima = WEATHER[tipo]
	if level.clima == "volcan":
		level.celdas_geiser.assign([Vector2i(6, 3)])
	root.add_child(level)
	level.gestor_clima.free()
	var climate := ControlledWeather.new()
	climate.nivel = level
	level.gestor_clima = climate
	level.add_child(climate)
	level._aplicar_tiempo(speed)
	_check(level._plantar(CELL, 0), "Hazard test must plant a valid tower")
	var tower = level.arboles_plantados[CELL]
	var label := "%s at %sx" % [tipo, speed]
	climate.actualizar(100.0)
	_check(climate.tiempo == 0.0 and climate.avisos.is_empty() and tower.vida == 100, label + " is inert during setup")
	level._iniciar_ronda()
	var event := "aviso_" + tipo if tipo in ["rayo", "derrumbe"] else tipo
	var deadline: float = climate.proximos[event]
	climate.proximos = {event: deadline}
	climate.actualizar(deadline)
	var minimum: float = climate.MINIMO_VISIBLE[tipo]
	climate.presentar_avisos(minimum)
	climate.actualizar(minimum * speed)
	_check(climate.conteos.get(tipo, 0) == 0, label + " cannot count time before its first presentation")
	climate.presentar_avisos(minimum * 0.5)
	climate.ocultar_avisos(false)
	paused = true
	climate.presentar_avisos(minimum * 10)
	climate.actualizar(minimum * speed * 10)
	paused = false
	_check(is_equal_approx(climate.avisos[tipo].visible, minimum * 0.5), label + " excludes paused time")
	level.ronda_activa = false
	climate.ocultar_avisos(true)
	climate.actualizar(100.0)
	_check(climate.avisos[tipo].visible == 0.0 and tower.vida == 100, label + " is inert between waves")
	level.ronda_activa = true
	climate.presentar_avisos(0.0)
	climate.presentar_avisos(minimum - 0.01)
	climate.actualizar(0.0)
	_check(climate.conteos.get(tipo, 0) == 0, label + " reissues its full warning")
	climate.presentar_avisos(0.01)
	climate.actualizar(0.0)
	climate.actualizar(0.0)
	_check(climate.conteos.get(tipo, 0) == 1 and not climate.avisos.has(tipo), label + " resolves once")
	if tipo == "erupcion":
		climate.actualizar(climate.proximos[event] - climate.tiempo)
		_check(level._plantar(CELL, 0), "A struck cell can be replanted")
		# Issue the next warning with a live target, then replace that exact tree.
		climate.proximos[event] = climate.tiempo
		climate.actualizar(0.0)
		level._quitar_arbol(CELL)
		_check(level._plantar(CELL, 0), "The pending target can be replaced")
		climate.presentar_avisos(0.0)
		climate.presentar_avisos(minimum)
		climate.actualizar(minimum * speed)
		_check(climate.conteos.get(tipo, 0) == 1 and level.arboles_plantados[CELL].vida == 100, label + " cancels a replaced eruption target")
	level.free()

func _run():
	var save = root.get_node("Guardado")
	save.slot_actual = -1
	await _speed_checks()
	for tipo in WEATHER:
		for speed in SPEEDS:
			_weather_check(tipo, speed)
	print("Speed and hazard checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
