extends Node

@onready var player_hover: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var player_click: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player_hover)
	add_child(player_click)
	player_hover.bus = "SFX"
	player_click.bus = "SFX"

func reproducir_hover(sonido: AudioStream) -> void:
	if sonido:
		player_hover.stream = sonido
		player_hover.play()

func reproducir_click(sonido: AudioStream) -> void:
	if sonido:
		player_click.stream = sonido
		player_click.play()

func _esperar_sonido(sonido: AudioStream) -> void:
	if sonido:
		await get_tree().create_timer(sonido.get_length()).timeout
