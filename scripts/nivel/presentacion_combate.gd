extends Node2D

signal evento(tipo: String, elemento: String, posiciones: PackedVector2Array)

const EFECTOS = preload("res://scripts/nivel/efectos_combate.gd")
const SALIDA_SEMILLA = preload("res://audios/p2/salida_semilla.wav")
const SALIDA_ENERGIA = preload("res://audios/p2/salida_energia.wav")
const PLANTAR = preload("res://audios/p2/plantar.wav")
const AGUA = preload("res://audios/p2/agua.wav")
const IMPACTOS := {
	"natura": preload("res://audios/p2/impacto_semilla.wav"),
	"flamma": preload("res://audios/p2/impacto_flamma.wav"),
	"glacies": preload("res://audios/p2/impacto_glacies.wav"),
	"electricitas": preload("res://audios/p2/impacto_electricitas.wav"),
	"venenum": preload("res://audios/p2/impacto_venenum.wav"),
}
const ALERTAS := {
	"geiser": preload("res://audios/p2/aviso_geiser.wav"),
	"erupcion": preload("res://audios/p2/aviso_erupcion.wav"),
	"rayo": preload("res://audios/p2/aviso_rayo.wav"),
	"ventisca": preload("res://audios/p2/aviso_ventisca.wav"),
	"derrumbe": preload("res://audios/p2/aviso_derrumbe.wav"),
	"radiacion": preload("res://audios/p2/aviso_radiacion.wav"),
}
const AMBIENTES := {
	"tormenta": preload("res://audios/p2/ambiente_tormenta.ogg"),
	"volcan": preload("res://audios/p2/ambiente_volcan.ogg"),
	"ventisca": preload("res://audios/p2/ambiente_ventisca.ogg"),
}
const GANANCIA_AMBIENTE := {"tormenta": -19.0, "volcan": -19.0, "ventisca": -18.0}

var activo := true
var clima := ""
var efectos: Node2D
var pico_voces := 0
var pico_alertas := 0
var _voces: Array[AudioStreamPlayer2D] = []
var _alertas: Array[AudioStreamPlayer] = []
var _ambiente: AudioStreamPlayer
var _amplificadores: Array[AudioEffectAmplify] = []
var _ultimos: Dictionary = {}
var _duck_restante := 0.0
var _ganancia_duck := 0.0
var _reloj := 0.0

func _ready():
	name = "PresentacionCombate"
	efectos = EFECTOS.new()
	add_child(efectos)
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for i in range(10):
		var voz := AudioStreamPlayer2D.new()
		voz.bus = &"Combat"
		voz.max_distance = 2850.0
		voz.attenuation = 0.46
		voz.panning_strength = 0.48
		_voces.append(voz)
		add_child(voz)
	for i in range(2):
		var voz := AudioStreamPlayer.new()
		voz.bus = &"Alerts"
		voz.volume_db = -12.0
		_alertas.append(voz)
		add_child(voz)
	for bus in [&"Combat", &"Ambience"]:
		var indice := AudioServer.get_bus_index(bus)
		var efecto := AudioServer.get_bus_effect(indice, 0) as AudioEffectAmplify
		_amplificadores.append(efecto)
	if AMBIENTES.has(clima):
		var bucle: AudioStreamOggVorbis = AMBIENTES[clima].duplicate()
		bucle.loop = true
		_ambiente = AudioStreamPlayer.new()
		_ambiente.bus = &"Ambience"
		_ambiente.process_mode = Node.PROCESS_MODE_ALWAYS
		_ambiente.stream = bucle
		_ambiente.volume_db = -40.0
		add_child(_ambiente)
		_ambiente.play()

func lanzamiento(elemento: String, punto: Vector2, bala: Node2D):
	if not activo:
		return
	evento.emit("lanzamiento", elemento, PackedVector2Array([punto]))
	if elemento == "flamma":
		efectos.seguir(bala)
	var sonido := SALIDA_ENERGIA if elemento in ["electricitas", "glacies", "flamma"] else SALIDA_SEMILLA
	if _permitir("salida_" + elemento, 0.085):
		_reproducir(sonido, punto, -24.0, true)

func impacto(elemento: String, centro: Vector2, puntos: PackedVector2Array):
	if not activo:
		return
	evento.emit("impacto", elemento, puntos)
	match elemento:
		"flamma": efectos.emitir(elemento, centro)
		"glacies", "electricitas":
			for punto in puntos:
				efectos.emitir(elemento, punto)
	if elemento != "glacies" or _permitir("impacto_glacies", 0.072):
		_reproducir(IMPACTOS.get(elemento, IMPACTOS.natura), centro, -14.0 if elemento == "flamma" else -17.0)

func plantar(punto: Vector2):
	if activo:
		evento.emit("plantar", "", PackedVector2Array([punto]))
		_reproducir(PLANTAR, punto, -11.0)

func agua(punto: Vector2):
	if activo:
		evento.emit("agua", "", PackedVector2Array([punto]))
		_reproducir(AGUA, punto, -13.0)

func cue_combate(sonido: AudioStream, punto: Vector2, volumen: float):
	if activo:
		_reproducir(sonido, punto, volumen)

func alerta(tipo: String):
	if not activo:
		return
	evento.emit("aviso", tipo, PackedVector2Array())
	for voz in _alertas:
		if not voz.playing:
			voz.stream = ALERTAS[tipo]
			voz.play()
			_duck_restante = maxf(_duck_restante, voz.stream.get_length() + 0.12)
			pico_alertas = maxi(pico_alertas, _alertas.filter(func(a): return a.playing).size())
			return

func clima_resuelto(tipo: String, punto: Vector2, area := Vector2.ZERO):
	if not activo:
		return
	evento.emit("clima", tipo, PackedVector2Array([punto]))
	if EFECTOS.RECETAS.has(tipo):
		efectos.emitir(tipo, punto, true, area)
		if _permitir("clima_" + tipo, 0.10):
			var cue: AudioStream = {
				"geiser": SALIDA_ENERGIA, "erupcion": IMPACTOS.flamma,
				"ventisca": IMPACTOS.glacies, "rayo": IMPACTOS.electricitas,
			}[tipo]
			_reproducir(cue, punto, -15.0)

func cerrar_clima():
	efectos.cerrar_clima()
	for voz in _alertas:
		voz.stop()
	_duck_restante = 0.0

func _permitir(clave: String, intervalo: float) -> bool:
	if _reloj < _ultimos.get(clave, -1.0):
		return false
	_ultimos[clave] = _reloj + intervalo
	return true

func _reproducir(sonido: AudioStream, punto: Vector2, volumen: float, es_salida := false):
	var elegida: AudioStreamPlayer2D
	for voz in _voces:
		if not voz.playing:
			elegida = voz
			break
		if not es_salida and elegida == null and voz.get_meta("salida", false):
			elegida = voz
	if elegida == null:
		return
	elegida.stop()
	elegida.global_position = punto
	elegida.stream = sonido
	elegida.volume_db = volumen
	elegida.set_meta("salida", es_salida)
	elegida.play()
	pico_voces = maxi(pico_voces, _voces.filter(func(voz): return voz.playing).size())

func _process(delta: float):
	var real := delta / Engine.time_scale
	_reloj += real
	_duck_restante = maxf(0.0, _duck_restante - real)
	_ganancia_duck = move_toward(_ganancia_duck, -3.0 if _duck_restante > 0.0 else 0.0, real * (76.0 if _duck_restante > 0.0 else 18.0))
	for efecto in _amplificadores:
		efecto.volume_db = _ganancia_duck
	if is_instance_valid(_ambiente):
		_ambiente.volume_db = move_toward(_ambiente.volume_db, GANANCIA_AMBIENTE[clima], real * 36.0)

func _notification(what: int):
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		var pausado := what == NOTIFICATION_PAUSED
		for voz in _voces:
			voz.stream_paused = pausado
		for voz in _alertas:
			voz.stream_paused = pausado

func _exit_tree():
	for efecto in _amplificadores:
		efecto.volume_db = 0.0
