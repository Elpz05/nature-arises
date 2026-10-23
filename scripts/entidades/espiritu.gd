extends CharacterBody2D

signal llego_a_meta(dano: int)
signal invocar_copia(tamano: String, progreso: float)

const TAMANO_CELDA := 64
const VELOCIDAD_CASILLAS := 0.4            # casillas por segundo
const DANO := {"pequeno": 2, "mediano": 3, "grande": 5}
const PROBABILIDAD_INVOCAR := 0.3          # 30%

const VIDA := {"pequeno": 200, "mediano": 500, "grande": 1000}

const ESCALA := {"pequeno": 1.0, "mediano": 1.3, "grande": 1.6}
@export var textura_pequeno: Texture2D
@export var textura_mediano: Texture2D
@export var textura_grande: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var colision: CollisionShape2D = $CollisionShape2D

var escala_sprite_base := Vector2.ONE

var tamano := "pequeno"                    # el nivel lo asigna antes de agregarlo
var vida := 200
var velocidad := VELOCIDAD_CASILLAS * TAMANO_CELDA   # 25.6 px/s
var muerto := false
var detenido := 0.0

func _ready():
	add_to_group("enemigo")
	add_to_group("bestias")
	vida = VIDA[tamano]
	escala_sprite_base = sprite.scale
	_aplicar_sprite()

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
		llego_a_meta.emit(DANO[tamano])
		seguidor.queue_free()

func recibir_dano(cantidad: int):
	if muerto:
		return
	vida -= cantidad
	print("Vida espíritu: ", vida)
	if vida <= 0:
		_morir()

func _morir():
	muerto = true
	if randf() < PROBABILIDAD_INVOCAR:
		invocar_copia.emit(tamano, (get_parent() as PathFollow2D).progress)
	get_parent().queue_free()

func aplicar_ataque_elemental(elemento: String, dano: int):
	recibir_dano(dano)
	if elemento == "Natura" and not muerto:
		detenido = 0.5

func _aplicar_sprite():
	var texturas := {
		"pequeno": textura_pequeno,
		"mediano": textura_mediano,
		"grande": textura_grande,
	}
	var tex: Texture2D = texturas[tamano]
	var escala = Vector2.ONE * ESCALA[tamano]

	colision.scale = escala              # la colisión siempre crece
	if tex != null:
		sprite.texture = tex             # dibujo propio: sin escalar
		sprite.scale = escala_sprite_base
	else:
		sprite.scale = escala_sprite_base * escala   # respaldo
