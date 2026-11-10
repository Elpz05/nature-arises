extends SceneTree

# All file tests use a newly created private directory under tests/.
class SaveHarness extends "res://scripts/menu/guardado.gd":
	var directory := ""
	var loaded_level := -1
	func _ruta(i: int) -> String:
		return directory.path_join("slot_%d.json" % i)
	func ir_a_nivel(n: int):
		loaded_level = n

var failures := 0

func _initialize():
	call_deferred("_run")

func _check(condition: bool, message: String):
	if not condition:
		failures += 1
		push_error(message)

func _write(path: String, content: String):
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Test fixture must open")
	if file != null:
		file.store_string(content)
		file.close()

func _run():
	var save := SaveHarness.new()
	save.directory = "res://tests/.save_validation_%d" % Time.get_ticks_usec()
	_check(DirAccess.make_dir_absolute(save.directory) == OK, "Private fixture directory must be created")
	for invalid in [null, [], "invalid", 7, true]:
		_check(save.validar_datos(invalid) == save.datos_nuevos(), "Invalid save roots must normalize to safe defaults")
	for invalid in [true, false, NAN, INF, 0.5, {}, [], "bad"]:
		_check(save.validar_datos({"nivel_actual": invalid}).nivel_actual == 0, "Invalid progress fields must fall back safely")
	var legacy := save.validar_datos({"nivel_actual": "1", "niveles_completados": null, "plantas": [2, 2, -1, 999, "1", false, {}, 1.5], "ataques": "invalid", "nota": "preservar"})
	_check(legacy.nivel_actual == 1 and legacy.niveles_completados == [0], "Legacy progress must recover completed levels")
	_check(legacy.plantas == [0, 1, 2] and legacy.ataques == [0, 1, 2], "Unlock lists must be deduplicated and restore the Aqua power earned after Level 1")
	_check(legacy.nota == "preservar" and save.validar_datos(legacy) == legacy, "Validation must preserve extra JSON fields and be idempotent")
	for content in ["", "{bad", "[]", "null", "true"]:
		_write(save._ruta(0), content)
		_check(save.leer(0) == save.datos_nuevos(), "Malformed JSON fixtures must load without script errors")
		_check(FileAccess.get_file_as_string(save._ruta(0)) == content, "Reading a broken save must not overwrite it")
	var broken := "{keep this original"
	_write(save._ruta(0), broken)
	save.entrar(0)
	_check(save.loaded_level == 0, "Broken saves must load the first level safely")
	save.datos = legacy
	_check(save.guardar() == true, "Repaired save must write successfully")
	_check(FileAccess.get_file_as_string(save._ruta(0) + ".bak") == broken, "First repair must preserve original bytes in a backup")
	_check(save.leer(0).nivel_actual == 1 and not FileAccess.file_exists(save._ruta(0) + ".tmp"), "Successful save must replace the destination and leave no temp file")
	save.completar_nivel(1)
	_check(not save.leer(0).campana_completada and save.datos.nivel_actual == 2, "Second victory must unlock the expanded campaign")
	for n in range(2, save.NIVELES.size()):
		save.completar_nivel(n)
	_check(save.leer(0).campana_completada and save.datos.nivel_actual == save.NIVELES.size(), "Final victory must persist completion")
	save.completar_nivel(0)
	_check(save.datos.nivel_actual == save.NIVELES.size(), "Replaying earlier levels must preserve completion")
	save.entrar(0)
	_check(save.loaded_level == save.NIVELES.size() and save.escena_para_nivel(save.loaded_level) == save.ESCENA_CAMPANA, "Completed saves must route to the final screen, never level 0")
	_check(save.escena_para_nivel(1) == save.NIVELES[1], "Level 0 victory must still lead to level 1")
	_check(not save.validar_datos({"nivel_actual": 2}).campana_completada and save.validar_datos({"nivel_actual": 2}).nivel_actual == 2, "Legacy completion must resume at the first new level")
	var valid_bytes := FileAccess.get_file_as_string(save._ruta(0))
	var fixture_dir: String = save.directory
	save.directory = fixture_dir.path_join("missing/directory")
	_check(save.guardar() == false, "Failed writes must return safely")
	save.directory = fixture_dir
	_check(FileAccess.get_file_as_string(save._ruta(0)) == valid_bytes, "Failed writes must preserve the prior save")
	_write(save._ruta(1), " ".repeat(save.MAX_BYTES + 1))
	_check(save.leer(1) == save.datos_nuevos(), "Oversized saves must fall back without parsing")
	_check(save.leer(-1) == save.datos_nuevos() and not save.existe(99), "Invalid slot IDs must be harmless")
	save.slot_actual = -1
	_check(save.guardar() == false, "No selected slot must not write a file")
	for index in 3:
		save.borrar(index)
	_check(DirAccess.remove_absolute(fixture_dir) == OK, "Only the private fixture directory must be cleaned")
	save.free()
	var singleton = root.get_node("Guardado")
	var original_slot: int = singleton.slot_actual
	singleton.slot_actual = -1
	for index in singleton.NIVELES.size():
		var level = load("res://escenas/escenas_niveles/nivel_%d.tscn" % index).instantiate()
		root.add_child(level)
		level._ganar_nivel()
		var victory = null
		for child in level.get_children():
			if child is CanvasLayer and child.get_script() == load("res://scripts/nivel/victoria.gd"):
				victory = child
		_check(victory != null, "Both levels must create a victory overlay")
		var texts: Array = []
		for child in victory.contenedor.get_children():
			texts.append(child.text)
		_check(victory.campana_finalizada == (index == singleton.NIVELES.size() - 1), "Only the final level must display campaign completion")
		_check(texts.has("Siguiente nivel") == (index < singleton.NIVELES.size() - 1), "The final screen must not offer another level")
		if index == singleton.NIVELES.size() - 1:
			_check(texts.has("¡Campaña completada!") and texts.has("Menú principal"), "Final victory must have explicit completion and menu actions")
			victory._siguiente()
			victory._ir_al_siguiente_nivel()
			_check(paused and victory.campana_finalizada, "Stale next-level calls must stay on the final outcome")
		paused = false
		level.free()
	var final_scene = load(singleton.ESCENA_CAMPANA).instantiate()
	root.add_child(final_scene)
	_check(final_scene.campana_finalizada and root.gui_get_focus_owner() != null, "Completed saves must have a standalone accessible final screen")
	if OS.get_cmdline_user_args().has("--capture-ui"):
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://tests/campaign_preview.png") == OK, "Final campaign screen must render")
	final_scene.free()
	singleton.slot_actual = original_slot
	await process_frame
	print("Campaign and save safety checks: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
