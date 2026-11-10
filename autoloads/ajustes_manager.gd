# ajustes_manager.gd (Autoload)
extends Node

signal hud_debug_cambiado(activo: bool)
signal numeros_dano_cambiado(activo: bool)
signal escala_ui_cambiada(porcentaje: int)

const RUTA_CONFIG = "user://ajustes.cfg"
const ESCALAS_UI := [100, 125, 150]
var config = ConfigFile.new()

func _ready() -> void:
	cargar_ajustes()

func hud_debug_activo() -> bool:
	var activo: Variant = config.get_value("interfaz", "hud_debug", false)
	return activo is bool and activo

func establecer_hud_debug(activo: bool) -> void:
	config.set_value("interfaz", "hud_debug", activo)
	guardar_ajustes()
	hud_debug_cambiado.emit(activo)

func numeros_dano_activos() -> bool:
	var activo: Variant = config.get_value("interfaz", "numeros_dano", true)
	return activo if activo is bool else true

func establecer_numeros_dano(activo: bool) -> void:
	config.set_value("interfaz", "numeros_dano", activo)
	guardar_ajustes()
	numeros_dano_cambiado.emit(activo)

func escala_ui() -> int:
	var porcentaje: Variant = config.get_value("interfaz", "escala_ui", 100)
	return porcentaje if porcentaje is int and porcentaje in ESCALAS_UI else 100

func establecer_escala_ui(porcentaje: int) -> void:
	if porcentaje not in ESCALAS_UI or porcentaje == escala_ui():
		return
	config.set_value("interfaz", "escala_ui", porcentaje)
	guardar_ajustes()
	escala_ui_cambiada.emit(porcentaje)

func guardar_ajustes() -> void:
	config.set_value("audio", "master", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	config.set_value("audio", "music", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	config.set_value("audio", "sfx", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	config.set_value("audio", "ambience", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")))
	config.save(RUTA_CONFIG)

func cargar_ajustes() -> void:
	var err = config.load(RUTA_CONFIG)
	if err != OK:
		return  # no existe archivo todavía (primera vez que se abre el juego)

	var master_db = config.get_value("audio", "master", 0.0)
	var music_db = config.get_value("audio", "music", 0.0)
	var sfx_db = config.get_value("audio", "sfx", 0.0)
	var ambiente: Variant = config.get_value("audio", "ambience", 0.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"),
		clampf(float(ambiente), -80.0, 0.0) if ambiente is float or ambiente is int else 0.0)
