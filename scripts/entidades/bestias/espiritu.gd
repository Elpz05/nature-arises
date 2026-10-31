extends CharacterBody2D

signal llego_a_meta(dano: int)
signal invocar_copia(tipo: String, tamano: String, progreso: float)

const TAMANO_CELDA := 64
const PROBABILIDAD_INVOCAR := 0.3          # solo Natura

const STATS := {
	"natura": {"vida": {"pequeno": 200, "mediano": 500, "grande": 1000},
			"vel": 0.4, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"flamma": {"vida": {"pequeno": 150, "mediano": 450, "grande": 800},
			"vel": 0.3, "dano": {"pequeno": 3, "mediano": 4, "grande": 6}},
	"aqua":   {"vida": {"pequeno": 200, "mediano": 500, "grande": 1000},
			"vel": 0.5, "dano": {"pequeno": 1, "mediano": 2, "grande": 3}},
}
const ESCALA := {"pequeno": 1.0, "mediano": 1.3, "grande": 1.6}

@export var textura_pequeno: Texture2D
@export var textura_mediano: Texture2D
@export var textura_grande: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var colision: CollisionShape2D = $CollisionShape2D

var tipo := "natura"                       # el nivel lo asigna antes de agregarla
var tamano := "pequeno"                    # el nivel lo asigna antes de agregarla
var vida := 200
var velocidad := 25.6
var muerto := false
var detenido := 0.0
var renacio := false
var escala_sprite_base := Vector2.ONE

func _ready():
	add_to_group("enemigo")
	add_to_group("bestias")
	var datos: Dictionary = STATS[tipo]
	vida = datos["vida"][tamano]
	velocidad = datos["vel"] * TAMANO_CELDA
	escala_sprite_base = sprite.scale
	_aplicar_sprite()

func _aplicar_sprite():
	var texturas := {
		"pequeno": textura_pequeno,
		"mediano": textura_mediano,
		"grande": textura_grande,
	}
	var tex: Texture2D = texturas[tamano]
	var escala: Vector2 = Vector2.ONE * ESCALA[tamano]
	colision.scale = escala
	if tex != null:
		sprite.texture = tex
		sprite.scale = escala_sprite_base
	else:
		sprite.scale = escala_sprite_base * escala

func _process(delta):
	if muerto:
		return
	if detenido > 0.0:
		detenido -= delta
		return
	var seguidor := get_parent() as PathFollow2D
	seguidor.progress += velocidad * delta
	if seguidor.progress_ratio >= 1.0:
		muerto = true
		llego_a_meta.emit(STATS[tipo]["dano"][tamano])
		seguidor.queue_free()

func recibir_dano(cantidad: int):
	if muerto:
		return
	vida -= cantidad
	if vida <= 0:
		_morir()

func _morir():
	# Flamma renace una vez, en el mismo punto, y se queda 3 s quieta
	if tipo == "flamma" and not renacio:
		renacio = true
		vida = STATS[tipo]["vida"][tamano]
		detenido = 3.0
		return
	muerto = true
	if tipo == "natura" and randf() < PROBABILIDAD_INVOCAR:
		invocar_copia.emit(tipo, tamano, (get_parent() as PathFollow2D).progress)
	get_parent().queue_free()

func aplicar_ataque_elemental(elemento: String, dano: int):
	var mult := 1.0
	match elemento:
		"Flamma":
			if tipo == "flamma" or tipo == "aqua":
				mult = 0.0
		"Aqua":
			if tipo == "aqua":
				mult = 0.0
			elif tipo == "flamma":
				mult = 2.0
	recibir_dano(int(dano * mult))
	if elemento == "Natura" and tipo != "flamma" and not muerto:
		detenido = 0.5
