extends SceneTree

# Run with: Godot --headless --path . --script res://tests/test_critical_fixes.gd
# Save tests use memory only; existing player saves are never touched.
class SaveHarness extends "res://scripts/menu/guardado.gd":
	var saved_data: Dictionary = {}
	var has_save := false
	var loaded_level := -1

	func existe(_i: int) -> bool:
		return has_save

	func leer(_i: int) -> Dictionary:
		return saved_data.duplicate(true)

	func guardar():
		saved_data = datos.duplicate(true)

	func ir_a_nivel(n: int) -> void:
		loaded_level = n

class Target extends Node2D:
	var damage_taken := 0

	func recibir_dano(amount: int):
		damage_taken += amount

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _run():
	var save := SaveHarness.new()
	save.entrar(0)
	_check(save.loaded_level == 0, "New saves must start at level 0")
	save.has_save = true
	save.saved_data = {"nivel_actual": 1, "niveles_completados": [0]}
	save.entrar(0)
	_check(save.loaded_level == 1, "Existing saves must resume level 1")
	_check(save.NIVELES.size() == 8 and ResourceLoader.exists(save.NIVELES[1]), "Level 1 must be registered")
	save.completar_nivel(1)
	save.completar_nivel(0)
	_check(save.datos.nivel_actual == 2, "Replaying level 0 must preserve campaign completion")
	for n in range(2, save.NIVELES.size()):
		save.completar_nivel(n)
	save.entrar(0)
	_check(save.loaded_level == save.NIVELES.size(), "Completed saves must route to the campaign outcome")
	save.saved_data = {"nivel_actual": -5}
	save.entrar(0)
	_check(save.loaded_level == 0, "Negative saved progress must be clamped")
	save.saved_data = {"nivel_actual": "invalid"}
	save.entrar(0)
	_check(save.loaded_level == 0 and save.datos.niveles_completados == [], "Malformed progress must fall back safely")
	save.free()

	for scene_path in ["res://escenas/escenas_niveles/nivel_0.tscn", "res://escenas/escenas_niveles/nivel_1.tscn"]:
		var level = load(scene_path).instantiate()
		root.add_child(level)
		level.set_process(false)
		level._crear_espiritu("natura", "mediano", 128.0)
		var source = level.ruta.get_child(0).get_child(0)
		source.invocar_copia.emit(source.tipo, source.tamano, source.get_parent().progress)
		_check(level.ruta.get_child_count() == 2, "Natura copy must spawn in " + scene_path)
		var copy = level.ruta.get_child(1).get_child(0)
		_check(copy.tipo == "natura" and copy.tamano == "mediano", "Copy must preserve type and size")
		_check(is_equal_approx(copy.get_parent().progress, 128.0), "Copy must preserve path progress")
		level._iniciar_ronda()
		level._actualizar_spawn(0.01)
		_check(level._bestias_en_camino() == 3, "Wave spawning must use the standardized signature")
		level.free()

	var target := Target.new()
	root.add_child(target)
	target.position = Vector2(100, 0)
	var bullet = load("res://escenas/escenas_balas/bala.tscn").instantiate()
	bullet.objetivo = target
	bullet.dano = 20
	root.add_child(bullet)
	bullet._physics_process(0.5)
	_check(bullet.global_position == target.global_position, "Large movement steps must stop at the target")
	_check(target.damage_taken == 20 and bullet.is_queued_for_deletion(), "Projectile must damage once and queue deletion")
	await process_frame
	target.free()
	print("Critical fix checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
