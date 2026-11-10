extends Node

const TOTAL_SLOTS := 3
const VERSION_GUARDADO := 2
const NIVELES_LEGACY := 2
const TOTAL_PLANTAS := 7
const TOTAL_ATAQUES := 7
const MAX_BYTES := 1048576
const NIVELES = preload("res://scripts/nivel/campana.gd").ESCENAS
const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"
const ESCENA_CAMPANA := "res://escenas/escenas_niveles/campana_completada.tscn"
const RUTA_CODEX := "user://codice.cfg"

var slot_actual := -1
var datos := {}
var _slots_reparados: Dictionary = {}
var _codice := ConfigFile.new()
var _ruta_codice := RUTA_CODEX
var _codice_pendiente := false

func _ready():
	_codice.load(_ruta_codice)
	for i in TOTAL_SLOTS:
		if existe(i):
			_registrar_descubrimientos(leer(i))

func todo_desbloqueado() -> bool:
	return _codice.get_value("progreso", "completada", false) == true

func descubrir_bestia(tipo: String):
	var vistas := _entradas_codice("bestias")
	if not todo_desbloqueado() and not vistas.has(tipo):
		vistas.append(tipo)
		_codice.set_value("progreso", "bestias", vistas)
		_guardar_codice()

func entrada_descubierta(categoria: String, especie: Variant) -> bool:
	if todo_desbloqueado():
		return true
	return _entradas_codice(categoria).has(especie)

func _entradas_codice(categoria: String) -> Array:
	var iniciales := [] if categoria == "bestias" else [0]
	var entradas: Variant = _codice.get_value("progreso", categoria, iniciales)
	return entradas if entradas is Array else iniciales

func _verificar_codice_completo(ruta: String) -> bool:
	var comprobacion := ConfigFile.new()
	return comprobacion.load(ruta) == OK and comprobacion.get_value("progreso", "completada", false) == true

func _guardar_codice() -> bool:
	_codice_pendiente = true
	var temporal := _ruta_codice + ".tmp"
	var verificar := todo_desbloqueado()
	if _codice.save(temporal) != OK \
			or (verificar and not _verificar_codice_completo(temporal)) \
			or DirAccess.rename_absolute(temporal, _ruta_codice) != OK \
			or (verificar and not _verificar_codice_completo(_ruta_codice)):
		push_warning("No se pudo guardar el progreso del Códice.")
		return false
	_codice_pendiente = false
	return true

func _registrar_descubrimientos(progreso: Dictionary) -> bool:
	if progreso.campana_completada and not todo_desbloqueado():
		_codice.set_value("progreso", "completada", true)
		_codice_pendiente = true
	for categoria in ["plantas", "ataques"]:
		var descubiertos := _entradas_codice(categoria)
		var limite := TOTAL_PLANTAS if categoria == "plantas" else TOTAL_ATAQUES
		var unidos := _lista_ids(descubiertos + progreso[categoria], limite, true)
		if unidos != descubiertos:
			_codice.set_value("progreso", categoria, unidos)
			_codice_pendiente = true
	return not _codice_pendiente or _guardar_codice()

func registrar_victoria(n: int) -> bool:
	if n < 0 or n >= NIVELES.size():
		return false
	# Una victoria final también repara un archivo perdido durante la sesión.
	if es_ultimo_nivel(n) and not _verificar_codice_completo(_ruta_codice):
		_codice_pendiente = true
	var perfil_guardado := _registrar_descubrimientos(validar_datos({"version": VERSION_GUARDADO, "nivel_actual": n + 1}))
	var partida_guardada := not _slot_valido(slot_actual) or completar_nivel(n)
	return perfil_guardado and partida_guardada

func _ruta(i: int) -> String:
	return "user://partida_%d.json" % (i + 1)

func _slot_valido(i: int) -> bool:
	return i >= 0 and i < TOTAL_SLOTS

func datos_nuevos() -> Dictionary:
	return {"version": VERSION_GUARDADO, "nivel_actual": 0, "niveles_completados": [], "plantas": [0], "ataques": [0], "campana_completada": false}

# JSON decodifica números como float; acepta enteros y cadenas numéricas de
# perfiles antiguos, sin convertir booleanos, fracciones, NaN ni objetos.
func _entero_seguro(valor: Variant, defecto: int = -1) -> int:
	if valor is int:
		return valor
	if valor is float and is_finite(valor) and valor == floor(valor) and absf(valor) <= 2147483647.0:
		return int(valor)
	if valor is String and valor.length() <= 10 and valor.is_valid_int():
		return valor.to_int()
	return defecto

func _lista_ids(valor: Variant, limite: int, incluir_cero: bool = false) -> Array:
	var salida: Array = [0] if incluir_cero else []
	if valor is Array:
		for entrada in valor:
			var indice := _entero_seguro(entrada)
			if indice >= 0 and indice < limite and not salida.has(indice):
				salida.append(indice)
	salida.sort()
	return salida

func validar_datos(entrada: Variant) -> Dictionary:
	var resultado: Dictionary = entrada.duplicate(true) if entrada is Dictionary else {}
	# Una campaña v1 terminada significaba dos niveles, no los ocho actuales.
	var legado := _entero_seguro(resultado.get("version"), 1) < VERSION_GUARDADO
	var limite := NIVELES_LEGACY if legado else NIVELES.size()
	var progreso := clampi(_entero_seguro(resultado.get("nivel_actual"), 0), 0, limite)
	var completados := _lista_ids(resultado.get("niveles_completados"), limite)
	for n in completados:
		progreso = maxi(progreso, n + 1)
	var finalizada: bool = resultado.get("campana_completada") is bool and resultado.get("campana_completada") == true
	if finalizada:
		progreso = limite
	# Recupera listas ausentes en partidas antiguas que solo guardaban progreso.
	for n in progreso:
		if not completados.has(n):
			completados.append(n)
	completados.sort()
	var plantas := _lista_ids(resultado.get("plantas"), TOTAL_PLANTAS, true)
	var ataques := _lista_ids(resultado.get("ataques"), TOTAL_ATAQUES, true)
	var ganados: Dictionary = preload("res://scripts/nivel/campana.gd").disponibles_para_nivel(progreso)
	plantas = _lista_ids(plantas + ganados.plantas, TOTAL_PLANTAS, true)
	ataques = _lista_ids(ataques + ganados.ataques, TOTAL_ATAQUES, true)
	plantas.sort()
	ataques.sort()
	resultado["version"] = VERSION_GUARDADO
	resultado["nivel_actual"] = progreso
	resultado["niveles_completados"] = completados
	resultado["plantas"] = plantas
	resultado["ataques"] = ataques
	resultado["campana_completada"] = progreso >= NIVELES.size()
	return resultado

func campana_completada(entrada: Variant = null) -> bool:
	return validar_datos(datos if entrada == null else entrada).campana_completada

func es_ultimo_nivel(n: int) -> bool:
	return n == NIVELES.size() - 1

func existe(i: int) -> bool:
	return _slot_valido(i) and FileAccess.file_exists(_ruta(i))

func leer(i: int) -> Dictionary:
	if not existe(i):
		return datos_nuevos()
	var archivo := FileAccess.open(_ruta(i), FileAccess.READ)
	if archivo == null:
		_slots_reparados[i] = true
		push_warning("No se pudo leer la partida; se usarán datos seguros.")
		return datos_nuevos()
	if archivo.get_length() > MAX_BYTES:
		_slots_reparados[i] = true
		push_warning("La partida supera el tamaño permitido; se usarán datos seguros.")
		return datos_nuevos()
	var parser := JSON.new()
	var error := parser.parse(archivo.get_as_text())
	archivo.close()
	if error != OK or not parser.data is Dictionary:
		_slots_reparados[i] = true
		push_warning("Partida inválida; se usarán datos seguros sin borrar el original.")
		return datos_nuevos()
	var normalizados := validar_datos(parser.data)
	if normalizados != parser.data:
		_slots_reparados[i] = true
	return normalizados

func guardar():
	if not _slot_valido(slot_actual):
		return false
	datos = validar_datos(datos)
	var ruta := _ruta(slot_actual)
	if _slots_reparados.has(slot_actual) and FileAccess.file_exists(ruta) and not FileAccess.file_exists(ruta + ".bak"):
		if DirAccess.copy_absolute(ruta, ruta + ".bak") != OK:
			push_warning("No se pudo respaldar la partida original; no se sobrescribirá.")
			return false
	var temporal := ruta + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se pudo abrir la partida temporal para guardar.")
		return false
	archivo.store_string(JSON.stringify(datos))
	archivo.flush()
	var error := archivo.get_error()
	archivo.close()
	if error != OK or DirAccess.rename_absolute(temporal, ruta) != OK:
		push_warning("No se pudo reemplazar la partida; el archivo anterior se conserva.")
		return false
	_slots_reparados.erase(slot_actual)
	return true

func borrar(i: int):
	if not _slot_valido(i):
		return
	# Solo los archivos del slot solicitado, incluidos sus datos de recuperación.
	for sufijo in ["", ".tmp", ".bak"]:
		var ruta: String = _ruta(i) + sufijo
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ruta)
	_slots_reparados.erase(i)

func entrar(i: int):
	if not _slot_valido(i):
		return
	slot_actual = i
	if existe(i):
		datos = validar_datos(leer(i))
	else:
		datos = datos_nuevos()
		guardar()
	ir_a_nivel(datos.nivel_actual)

func completar_nivel(n: int) -> bool:
	if n < 0 or n >= NIVELES.size():
		return false
	datos = validar_datos(datos)
	if not datos.niveles_completados.has(n):
		datos.niveles_completados.append(n)
	datos.nivel_actual = maxi(datos.nivel_actual, n + 1)
	datos = validar_datos(datos)
	return guardar() == true

func ir_a_nivel(n: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(escena_para_nivel(n))

func escena_para_nivel(n: int) -> String:
	if n >= NIVELES.size():
		return ESCENA_CAMPANA
	elif n >= 0:
		return NIVELES[n]
	return ESCENA_SLOTS

func plantas_activas() -> Array:
	if todo_desbloqueado():
		return range(TOTAL_PLANTAS)
	datos = validar_datos(datos)
	return datos.plantas.duplicate()

func desbloquear(indices: Array) -> void:
	datos = validar_datos(datos)
	datos.plantas = _lista_ids(datos.plantas + _lista_ids(indices, TOTAL_PLANTAS), TOTAL_PLANTAS, true)
	guardar()

func ataques_activos() -> Array:
	if todo_desbloqueado():
		return range(TOTAL_ATAQUES)
	datos = validar_datos(datos)
	return datos.ataques.duplicate()

func desbloquear_ataques(indices: Array) -> void:
	datos = validar_datos(datos)
	datos.ataques = _lista_ids(datos.ataques + _lista_ids(indices, TOTAL_ATAQUES), TOTAL_ATAQUES, true)
	guardar()
