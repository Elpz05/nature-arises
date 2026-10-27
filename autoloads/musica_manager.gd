extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player)
	player.bus = "Music"  # ajusta si tu bus de música se llama distinto, o bórralo si solo usas Master
	process_mode = Node.PROCESS_MODE_ALWAYS

func reproducir(cancion: AudioStream, volumen_db: float = 0.0) -> void:
	if player.stream == cancion and player.playing:
		return  # ya está sonando la misma canción, no la reinicies
	player.stream = cancion
	player.volume_db = volumen_db
	player.play()

func detener() -> void:
	player.stop()
