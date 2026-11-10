extends Node

const MADERA = preload("res://audios/p2/madera.wav")

@onready var player_hover: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var player_click: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player_hover)
	add_child(player_click)
	player_hover.bus = "UI"
	player_hover.volume_db = -17.0
	player_click.bus = "UI"
	player_click.volume_db = -11.0

func reproducir_hover(sonido: AudioStream) -> void:
	if sonido:
		player_hover.stream = sonido
		player_hover.play()

func reproducir_click(sonido: AudioStream) -> void:
	if sonido:
		click_madera()

func click_madera() -> void:
	player_click.stream = MADERA
	player_click.play()

func _esperar_sonido(sonido: AudioStream) -> void:
	if sonido:
		await get_tree().create_timer(sonido.get_length()).timeout
