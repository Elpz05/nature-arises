extends Node

const NIVEL_0 := "res://escenas/escenas_niveles/nivel_0.tscn"
const TOTAL_SLOTS := 3

# Rutas de tus niveles, en orden. Agrega los demás conforme los hagas.
const NIVELES := [
	"res://escenas/escenas_niveles/nivel_0.tscn",
]
const ESCENA_SLOTS := "res://escenas/escenas_menu/file_menu.tscn"   # ajusta a tu ruta real

var slot_actual := -1
var datos := {}

func _ruta(i: int) -> String:
	return "user://partida_%d.json" % (i + 1)

func existe(i: int) -> bool:
	return FileAccess.file_exists(_ruta(i))

func leer(i: int) -> Dictionary:
	if not existe(i):
		return {}
	var f := FileAccess.open(_ruta(i), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func guardar():
	if slot_actual < 0:
		return
	var f := FileAccess.open(_ruta(slot_actual), FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))

func borrar(i: int):
	if existe(i):
		DirAccess.remove_absolute(_ruta(i))

# Elige un slot: si está vacío crea la partida, si no la carga
func entrar(i: int):
	slot_actual = i
	if existe(i):
		datos = leer(i)
	else:
		datos = {"nivel_actual": 0, "niveles_completados": []}
		guardar()
	get_tree().paused = false
	get_tree().change_scene_to_file(NIVEL_0)

func completar_nivel(n: int):
	if not datos.get("niveles_completados", []).has(n):
		datos["niveles_completados"].append(n)
	datos["nivel_actual"] = n + 1
	guardar()

func ir_a_nivel(n: int) -> void:
	get_tree().paused = false
	if n < NIVELES.size():
		get_tree().change_scene_to_file(NIVELES[n])
	else:
		get_tree().change_scene_to_file(ESCENA_SLOTS)   # aún no existe ese nivel

func plantas_activas() -> Array:
	var lista: Array = [0]                              # Natura siempre
	for i in datos.get("plantas", []):
		if not lista.has(int(i)):
			lista.append(int(i))
	return lista

func desbloquear(indices: Array) -> void:
	var actuales: Array = plantas_activas()
	for i in indices:
		if not actuales.has(i):
			actuales.append(i)
	datos["plantas"] = actuales
	guardar()

func ataques_activos() -> Array:
	var lista: Array = [0]                              # Natura siempre
	for i in datos.get("ataques", []):
		if not lista.has(int(i)):
			lista.append(int(i))
	return lista

func desbloquear_ataques(indices: Array) -> void:
	var actuales: Array = ataques_activos()
	for i in indices:
		if not actuales.has(i):
			actuales.append(i)
	datos["ataques"] = actuales
	guardar()
