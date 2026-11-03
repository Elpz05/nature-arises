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
var vida_maxima := 200
var velocidad := 25.6
var muerto := false
var detenido := 0.0
var renacio := false
var escala_sprite_base := Vector2.ONE
var factor_lentitud := 1.0
var lentitud_restante := 0.0

# Los impactos renuevan el efecto sin multiplicar la reducción de velocidad.
# Un efecto más débil no reemplaza uno más fuerte que sigue activo.
func aplicar_lentitud(factor: float, duracion: float):
	if muerto or is_queued_for_deletion() or duracion <= 0.0:
		return
	factor = clampf(factor, 0.1, 1.0)
	if lentitud_restante > 0.0 and factor > factor_lentitud:
		return
	lentitud_restante = maxf(lentitud_restante, duracion) if is_equal_approx(factor, factor_lentitud) else duracion
	factor_lentitud = factor
	queue_redraw()

func _ready():
	add_to_group("enemigo")
	add_to_group("bestias")
	var datos: Dictionary = STATS[tipo]
	vida = datos["vida"][tamano]
	vida_maxima = vida
	velocidad = datos["vel"] * TAMANO_CELDA
	escala_sprite_base = sprite.scale
	_aplicar_sprite()
	queue_redraw()

func obtener_porcentaje_vida() -> float:
	return clampf(float(vida) / float(vida_maxima), 0.0, 1.0)

func obtener_estado_combate() -> String:
	var estados: PackedStringArray = []
	if lentitud_restante > 0.0 and factor_lentitud < 1.0:
		estados.append("Lento %d%%" % roundi((1.0 - factor_lentitud) * 100.0))
	if detenido > 0.0:
		estados.append("Renaciendo" if tipo == "flamma" and renacio else "Detenido")
	return " | ".join(estados)

func _draw():
	if muerto or not is_instance_valid(colision) or colision.shape == null:
		return
	var y: float = -colision.shape.radius * colision.scale.y - 14.0
	var fondo := Rect2(-24.0, y, 48.0, 7.0)
	draw_rect(fondo.grow(1.0), Color(0.05, 0.05, 0.05, 0.95))
	draw_rect(fondo, Color(0.45, 0.1, 0.1))
	draw_rect(Rect2(fondo.position, Vector2(48.0 * obtener_porcentaje_vida(), 7.0)), Color(0.2, 0.9, 0.35))
	var estado := obtener_estado_combate()
	if not estado.is_empty():
		var font := ThemeDB.fallback_font
		var ancho := font.get_string_size(estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var posicion := Vector2(-ancho / 2.0, y - 4.0)
		draw_string_outline(font, posicion, estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
		draw_string(font, posicion, estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.9, 1.0))

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

func _physics_process(delta: float):
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return
	var estado_anterior := obtener_estado_combate()
	var tiempo_lento := minf(delta, lentitud_restante)
	var avance: float = velocidad * (tiempo_lento * factor_lentitud + delta - tiempo_lento)
	lentitud_restante = maxf(0.0, lentitud_restante - delta)
	if lentitud_restante == 0.0:
		factor_lentitud = 1.0
	if detenido > 0.0:
		detenido = maxf(0.0, detenido - delta)
		if estado_anterior != obtener_estado_combate():
			queue_redraw()
		return
	if estado_anterior != obtener_estado_combate():
		queue_redraw()
	var seguidor := get_parent() as PathFollow2D
	seguidor.progress += avance
	if seguidor.progress_ratio >= 1.0:
		muerto = true
		queue_redraw()
		llego_a_meta.emit(STATS[tipo]["dano"][tamano])
		seguidor.queue_free()

func recibir_dano(cantidad: int):
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return
	vida = maxi(0, vida - cantidad)
	if vida <= 0:
		_morir()
	queue_redraw()

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
	queue_redraw()
