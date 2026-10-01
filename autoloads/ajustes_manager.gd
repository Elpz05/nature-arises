# ajustes_manager.gd (Autoload)
extends Node

const RUTA_CONFIG = "user://ajustes.cfg"
var config = ConfigFile.new()

func _ready() -> void:
	cargar_ajustes()

func guardar_ajustes() -> void:
	config.set_value("audio", "master", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	config.set_value("audio", "music", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	config.set_value("audio", "sfx", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	config.save(RUTA_CONFIG)

func cargar_ajustes() -> void:
	var err = config.load(RUTA_CONFIG)
	if err != OK:
		return  # no existe archivo todavía (primera vez que se abre el juego)

	var master_db = config.get_value("audio", "master", 0.0)
	var music_db = config.get_value("audio", "music", 0.0)
	var sfx_db = config.get_value("audio", "sfx", 0.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), music_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), sfx_db)
