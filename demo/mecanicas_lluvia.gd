extends "res://scripts/nivel/nivel_1.gd"

const LABORATORIOS := [
	{"nombre": "Despejado", "clima": "despejado", "escena": "mecanicas_despejado"},
	{"nombre": "Lluvia", "clima": "lluvia", "escena": "mecanicas_lluvia"},
	{"nombre": "Tormenta pequeña", "clima": "tormenta", "intensidad": "pequeno", "escena": "mecanicas_tormenta_pequena"},
	{"nombre": "Tormenta mediana", "clima": "tormenta", "intensidad": "mediano", "escena": "mecanicas_tormenta"},
	{"nombre": "Tormenta grande", "clima": "tormenta", "intensidad": "grande", "escena": "mecanicas_tormenta_grande"},
	{"nombre": "Volcán", "clima": "volcan", "escena": "mecanicas_volcan"},
	{"nombre": "Ventisca", "clima": "ventisca", "escena": "mecanicas_ventisca"},
	{"nombre": "Derrumbe", "clima": "derrumbe", "escena": "mecanicas_derrumbe"},
	{"nombre": "Campo radiactivo", "clima": "radiacion", "escena": "mecanicas_radiacion"},
]

func _ready():
	super._ready()
	if not inicializado:
		return
	var indice := 0
	for i in LABORATORIOS.size():
		if LABORATORIOS[i].clima == clima and (clima != "tormenta" or LABORATORIOS[i].intensidad == intensidad_tormenta):
			indice = i
			break
	var fila := HBoxContainer.new()
	hud.acciones.add_child(fila)
	var anterior := Button.new()
	anterior.text = "<"
	anterior.custom_minimum_size = Vector2(28, 28)
	anterior.focus_mode = Control.FOCUS_NONE
	anterior.tooltip_text = "Reiniciar con el clima anterior"
	anterior.pressed.connect(_abrir_laboratorio.bind(posmod(indice - 1, LABORATORIOS.size())))
	fila.add_child(anterior)
	var titulo := Label.new()
	titulo.text = "Laboratorio · " + LABORATORIOS[indice].nombre
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.tooltip_text = titulo.text
	titulo.add_theme_font_size_override("font_size", 13)
	fila.add_child(titulo)
	var siguiente := Button.new()
	siguiente.text = ">"
	siguiente.custom_minimum_size = Vector2(28, 28)
	siguiente.focus_mode = Control.FOCUS_NONE
	siguiente.tooltip_text = "Reiniciar con el clima siguiente"
	siguiente.pressed.connect(_abrir_laboratorio.bind(posmod(indice + 1, LABORATORIOS.size())))
	fila.add_child(siguiente)
	hud.botones_laboratorio.assign([anterior, siguiente])

func _abrir_laboratorio(indice: int):
	if not _puede_jugar():
		return
	get_tree().change_scene_to_file.call_deferred("res://demo/" + LABORATORIOS[indice].escena + ".tscn")

# Laboratorio F6: habilita las siete plantas sin tocar partidas guardadas.
func _configurar_nivel():
	var agua_laboratorio := celdas_inundadas.duplicate()
	super._configurar_nivel()
	limitar_plantado = false
	desafios_ronda.clear()
	celdas_inundadas.assign(agua_laboratorio)
	if clima == "radiacion":
		var catalogo = preload("res://scripts/nivel/campana.gd")
		rutas_adicionales.append(catalogo.ATAJO_ELECTRICITAS)
		celdas_inundadas.assign(catalogo.POZAS_RADIACION)
	for i in rondas.size():
		rondas[i] = _contar_bestias(_expandir_receta(rondas[i]))
	rondas[0]["aqua:pequeno"] = 2
	for tipo in ["terra", "electricitas", "glacies", "venenum"]:
		rondas[0][tipo + ":pequeno"] = 1
		rondas[2][tipo + ":mediano"] = 1
		rondas[4][tipo + ":grande"] = 1

func _crear_hud():
	super._crear_hud()
	hud.SEMILLAS_ACTIVAS = [0, 1, 2, 3, 4, 5, 6]
	hud.ATAQUES_ACTIVOS = [0, 1, 2, 3, 4, 5, 6]
	hud.mostrar_mision("Laboratorio de mecánicas", "Prueba los siete árboles y ataques; cambia de clima con las flechas superiores.")
	hud.actualizar_gotas(gotas)

func _ganar_nivel():
	# La prueba no escribe progreso de campaña.
	terminado = true
	_suspender_tiempo()
	numeros_dano.limpiar()
	gestor_clima.cancelar_avisos()
	ronda_activa = false
	pozo.activar_generacion(false)
	_deseleccionar()
	_limpiar_inspeccion()
	_actualizar_combate_hud()
	hud.mostrar_boton_ronda("Prueba completada · F6 para reiniciar", false)
