extends Node

const NIVEL_0 := "res://escenas/escenas_niveles/nivel_0.tscn"
const TOTAL_SLOTS := 3

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
