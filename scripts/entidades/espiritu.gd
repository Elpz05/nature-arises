extends CharacterBody2D

signal llego_a_meta(dano: int)
signal invocar_copia(tamano: String, progreso: float)

const TAMANO_CELDA := 64
const VELOCIDAD_CASILLAS := 0.4            # casillas por segundo
const DANO_CONTACTO := 50
const PROBABILIDAD_INVOCAR := 0.3          # 30%

const VIDA := {"pequeno": 200, "mediano": 500, "grande": 1000}

var tamano := "pequeno"                    # el nivel lo asigna antes de agregarlo
var vida := 200
var velocidad := VELOCIDAD_CASILLAS * TAMANO_CELDA   # 25.6 px/s
var muerto := false

func _ready():
	add_to_group("enemigo")
	vida = VIDA[tamano]

func _process(delta):
	if muerto:
		return
	var seguidor := get_parent() as PathFollow2D
	seguidor.progress += velocidad * delta
	if seguidor.progress_ratio >= 1.0:
		muerto = true
		llego_a_meta.emit(DANO_CONTACTO)
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
