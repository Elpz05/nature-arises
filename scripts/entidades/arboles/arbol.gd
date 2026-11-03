class_name Arbol
extends Node2D

signal murio

const TAMANO_CELDA := 64
const DANO_BALA := 20
const BALAS_POR_SEGUNDO_BASE := 2.0
const DURACION_VENENO := 6.0
const ESCALA := {"pequeno": 1.0, "mediano": 1.25, "grande": 1.5}

# Todas las estadísticas en un solo lugar
const STATS := {
	"pequeno": {"vida": 100, "costo": 1, "radio": 2.0, "vel_ataque": 1.0},
	"mediano": {"vida": 200, "costo": 2, "radio": 2.5, "vel_ataque": 1.2},
	"grande":  {"vida": 300, "costo": 3, "radio": 3.0, "vel_ataque": 1.5},
}
const STATS_ELEMENTALES := {
	"venenum": {
		"pequeno": {"vida": 500, "radio": 4.0, "vel_ataque": 1.0, "veneno": 1.0, "lentitud": 0.75},
		"mediano": {"vida": 800, "radio": 5.0, "vel_ataque": 1.0, "veneno": 2.0, "lentitud": 0.73},
		"grande": {"vida": 1000, "radio": 6.0, "vel_ataque": 1.0, "veneno": 3.0, "lentitud": 0.7},
	},
	"electricitas": {
		"pequeno": {"vida": 200, "radio": 2.5, "vel_ataque": 1.0, "objetivos": 3},
		"mediano": {"vida": 400, "radio": 3.0, "vel_ataque": 1.0, "objetivos": 5},
		"grande": {"vida": 600, "radio": 3.5, "vel_ataque": 1.0, "objetivos": 7},
	},
	"glacies": {
		"pequeno": {"vida": 150, "radio": 3.0, "vel_ataque": 1.0, "objetivos": 3},
		"mediano": {"vida": 300, "radio": 3.5, "vel_ataque": 1.0, "objetivos": 4},
		"grande": {"vida": 600, "radio": 4.0, "vel_ataque": 1.0, "objetivos": 5},
	},
	"terra": {
		"pequeno": {"vida": 1000, "radio": 0.0, "vel_ataque": 1.0, "empuje": 0.5},
		"mediano": {"vida": 2000, "radio": 0.0, "vel_ataque": 1.0, "empuje": 0.7},
		"grande": {"vida": 3000, "radio": 0.0, "vel_ataque": 1.0, "empuje": 1.0},
	},
	"flamma": {
		"pequeno": {"vida": 250, "radio": 2.0, "vel_ataque": 1.0, "area": 1.0},
		"mediano": {"vida": 500, "radio": 3.0, "vel_ataque": 1.0, "area": 1.5},
		"grande": {"vida": 800, "radio": 4.0, "vel_ataque": 1.0, "area": 2.0},
	},
	"aqua": {
		"pequeno": {"vida": 100, "radio": 0.0, "vel_ataque": 1.0, "produccion": 0.1},
		"mediano": {"vida": 100, "radio": 0.0, "vel_ataque": 1.0, "produccion": 0.2},
		"grande": {"vida": 100, "radio": 0.0, "vel_ataque": 1.0, "produccion": 0.3},
	},
}

@export_enum("natura", "flamma", "aqua", "terra", "glacies", "electricitas", "venenum") var elemento := "natura"
var modificador_cadencia := 1.0
var modificador_dano := 0.0

func _datos(talla: String) -> Dictionary:
	return STATS_ELEMENTALES.get(elemento, STATS)[talla]

func obtener_produccion() -> float:
	return float(_datos(tamano).get("produccion", 0.0))

func obtener_empuje() -> float:
	return float(_datos(tamano).get("empuje", 0.0))

@export var semilla_escena: PackedScene
@export var dano_bala := DANO_BALA
@export var balas_por_segundo := BALAS_POR_SEGUNDO_BASE
@export var costos: Array[int] = [1, 2, 3]
@export var radio_explosion := 0.0
@export_range(0.1, 1.0) var factor_lentitud := 1.0
@export var duracion_lentitud := 0.0
@export var color_bala := Color(0.125, 1, 0)

var tamano := "pequeno"
var vida := 100
var enemigos_en_rango: Array = []
var escala_base := Vector2.ONE
var rango_visible := false
var congelado_por_aura := false
var intoxicado_por_aura := false
var nivel_congelacion := 0
var protegido_ventisca := false
var golpes_derrumbe := 0
var bono_geiser_restante := 0.0

func esta_congelado() -> bool:
	return congelado_por_aura or nivel_congelacion >= 3

func _actualizar_color_estado():
	sprite.self_modulate = Color(0.55, 0.8, 1.0) if esta_congelado() else (Color(0.7, 1.0, 0.65) if intoxicado_por_aura else Color.WHITE)
	queue_redraw()

func actualizar_clima(delta: float):
	if bono_geiser_restante <= 0.0:
		return
	bono_geiser_restante = maxf(0.0, bono_geiser_restante - delta)
	if bono_geiser_restante <= 0.000001:
		bono_geiser_restante = 0.0
		_actualizar_cadencia()

func aplicar_geiser():
	if elemento == "flamma" or vida <= 0 or is_queued_for_deletion():
		return
	recibir_dano(25)
	if vida > 0:
		bono_geiser_restante = 7.0
		_actualizar_cadencia()

func aplicar_ventisca():
	if elemento in ["flamma", "glacies"] or vida <= 0 or is_queued_for_deletion():
		return
	if not protegido_ventisca:
		nivel_congelacion = mini(3, nivel_congelacion + 1)
	recibir_dano(25)
	_actualizar_cadencia()
	_actualizar_color_estado()

func calentar_ventisca(protegido: bool, reducir: bool = false):
	if protegido_ventisca == protegido and not reducir:
		return
	protegido_ventisca = protegido
	if reducir and protegido:
		nivel_congelacion = maxi(0, nivel_congelacion - 1)
	_actualizar_cadencia()
	_actualizar_color_estado()

func recibir_roca():
	if elemento == "terra":
		golpes_derrumbe += 1
		queue_redraw()
		if golpes_derrumbe < 3:
			return
	recibir_dano(vida)

func aplicar_auras(congelado: bool, intoxicado: bool):
	if congelado_por_aura == congelado and intoxicado_por_aura == intoxicado:
		return
	congelado_por_aura = congelado
	intoxicado_por_aura = intoxicado
	_actualizar_cadencia()
	_actualizar_color_estado()

func _actualizar_cadencia():
	temporizador.paused = esta_congelado()
	if elemento in ["aqua", "terra"]:
		return
	var factor_toxico := 0.7 if intoxicado_por_aura else 1.0
	var factor_geiser := 1.25 if bono_geiser_restante > 0.0 else 1.0
	temporizador.wait_time = 1.0 / (balas_por_segundo * _datos(tamano).vel_ataque * modificador_cadencia * factor_toxico * factor_geiser)

func _tirada_fallo() -> float:
	return randf()

@onready var rango: Area2D = $Arbol/Rango
@onready var forma: CollisionShape2D = $Arbol/Rango/CollisionShape2D
@onready var temporizador: Timer = $TemporizadorDisparo
@onready var sprite: AnimatedSprite2D = $Arbol


func _ready():
	escala_base = sprite.scale
	temporizador.process_callback = Timer.TIMER_PROCESS_PHYSICS
	temporizador.timeout.connect(_disparar)
	_aplicar_tamano("pequeno")

func _aplicar_tamano(nuevo: String):
	tamano = nuevo
	var datos: Dictionary = _datos(tamano)
	vida = datos["vida"]
	if elemento == "flamma":
		radio_explosion = datos.area * TAMANO_CELDA
	elif elemento == "venenum":
		factor_lentitud = datos.lentitud
	_actualizar_sprite()

	var circulo := CircleShape2D.new()
	circulo.radius = datos["radio"] * TAMANO_CELDA / sprite.scale.x
	forma.shape = circulo

	if elemento in ["aqua", "terra"]:
		temporizador.stop()
	else:
		_actualizar_cadencia()
		temporizador.start()
	queue_redraw()

func obtener_estadisticas() -> Dictionary:
	return {
		"dano": dano_bala,
		"disparos_segundo": 0.0 if elemento in ["aqua", "terra"] or esta_congelado() else 1.0 / temporizador.wait_time,
		"nivel_congelacion": nivel_congelacion,
		"protegido_ventisca": protegido_ventisca,
		"golpes_derrumbe": golpes_derrumbe,
		"bono_geiser": bono_geiser_restante,
		"congelado_por_aura": congelado_por_aura,
		"intoxicado_por_aura": intoxicado_por_aura,
		"empuje": obtener_empuje(),
		"objetivos": int(_datos(tamano).get("objetivos", 1)),
		"congelacion": 2.0 if elemento == "glacies" else 0.0,
		"veneno_segundo": float(_datos(tamano).get("veneno", 0.0)),
		"duracion_veneno": DURACION_VENENO if elemento == "venenum" else 0.0,
		"radio": float(_datos(tamano).radio) * TAMANO_CELDA,
		"produccion": obtener_produccion(),
		"radio_explosion": radio_explosion,
		"factor_lentitud": factor_lentitud,
		"duracion_lentitud": duracion_lentitud,
	}

# Consulta antes de _ready(): la vista previa no activa timers ni dispara.
func obtener_datos_colocacion() -> Dictionary:
	var visual: Node2D = get_node("Arbol")
	var area: Node2D = get_node("Arbol/Rango")
	var colision: Node2D = get_node("Arbol/Rango/CollisionShape2D")
	return {
		"radio": float(_datos("pequeno").radio) * TAMANO_CELDA,
		"centro": visual.transform * (area.transform * colision.position),
	}

func mostrar_rango(mostrar: bool):
	if rango_visible != mostrar:
		rango_visible = mostrar
		queue_redraw()

func _draw():
	if elemento == "terra" and vida > 0:
		var barra := Rect2(-24, -38 * sprite.scale.y, 48, 6)
		draw_rect(barra.grow(1), Color.BLACK)
		draw_rect(barra, Color(0.4, 0.1, 0.1))
		var proporcion := clampf(float(vida) / float(_datos(tamano).vida), 0.0, 1.0)
		draw_rect(Rect2(barra.position, Vector2(48 * proporcion, 6)), Color(0.45, 0.8, 0.25))
	if not rango_visible or not is_instance_valid(forma) or forma.shape == null:
		return
	var centro := to_local(forma.global_position)
	var radio: float = forma.shape.radius * absf(forma.global_scale.x / global_scale.x)
	draw_circle(centro, radio, Color(0.2, 0.8, 1.0, 0.12))
	draw_arc(centro, radio, 0.0, TAU, 64, Color(0.3, 0.9, 1.0, 0.8), 2.0, true)


# Sube al siguiente tamaño (pequeno -> mediano -> grande)
func mejorar() -> bool:
	if tamano == "pequeno":
		_aplicar_tamano("mediano")
		return true
	if tamano == "mediano":
		_aplicar_tamano("grande")
		return true
	return false   # ya está al máximo


func obtener_costo() -> int:
	return costos[["pequeno", "mediano", "grande"].find(tamano)]


func recibir_dano(cantidad: int):
	if vida <= 0 or is_queued_for_deletion():
		return
	vida -= cantidad
	queue_redraw()
	if vida <= 0:
		murio.emit()
		queue_free()


func _physics_process(_delta: float):
	# Area2D ya calcula solapamientos en física. Usa su lista en caché,
	# sin escanear todos los enemigos ni conservar referencias obsoletas.
	enemigos_en_rango = rango.get_overlapping_bodies().filter(_es_objetivo_valido)

func _es_objetivo_valido(enemigo) -> bool:
	if not is_instance_valid(enemigo) or not enemigo.is_inside_tree() or enemigo.is_queued_for_deletion():
		return false
	if not enemigo.is_in_group("enemigo") or enemigo.muerto:
		return false
	var seguidor := enemigo.get_parent() as PathFollow2D
	if seguidor == null or seguidor.is_queued_for_deletion():
		return false
	var recorrido := seguidor.get_parent() as Path2D
	return recorrido != null and not recorrido.is_queued_for_deletion() and recorrido.curve != null


func _disparar():
	if elemento in ["aqua", "terra"] or esta_congelado() or vida <= 0 or is_queued_for_deletion():
		return
	_limpiar_enemigos_muertos()
	if enemigos_en_rango.is_empty():
		return

	# El primero que entró suele ser el más adelantado en el camino
	var objetivo = _mas_adelantada()
	if not _es_objetivo_valido(objetivo) or semilla_escena == null or not rango.overlaps_body(objetivo):
		return
	if intoxicado_por_aura and _tirada_fallo() < 0.3:
		return  # El intento consume su intervalo, pero el proyectil se desvanece.
	var semilla = semilla_escena.instantiate()
	semilla.objetivo = objetivo
	semilla.dano = dano_bala
	semilla.elemento = elemento
	semilla.modificador_dano = modificador_dano
	semilla.radio_explosion = radio_explosion
	semilla.factor_lentitud = factor_lentitud
	semilla.duracion_lentitud = duracion_lentitud
	semilla.color_bala = color_bala
	if elemento == "glacies":
		semilla.maximo_objetivos = int(_datos(tamano).objetivos)
		semilla.distancia_maxima = float(_datos(tamano).radio) * TAMANO_CELDA
		semilla.duracion_congelacion = 2.0
	elif elemento == "electricitas":
		semilla.maximo_objetivos = int(_datos(tamano).objetivos)
		# La cadena solo puede elegir bestias detectadas por esta torre.
		semilla.candidatos = enemigos_en_rango.duplicate()
	elif elemento == "venenum":
		semilla.dano_veneno = float(_datos(tamano).veneno)
		semilla.duracion_veneno = DURACION_VENENO
	get_parent().add_child(semilla)
	semilla.global_position = global_position


func _limpiar_enemigos_muertos():
	enemigos_en_rango = enemigos_en_rango.filter(_es_objetivo_valido)

func _mas_adelantada():
	var mejor = null
	var menor := INF
	for e in enemigos_en_rango:
		if not _es_objetivo_valido(e):
			continue
		var seg := e.get_parent() as PathFollow2D
		var largo: float = (seg.get_parent() as Path2D).curve.get_baked_length()
		var faltante: float = largo - seg.progress
		if faltante < menor:
			menor = faltante
			mejor = e
	return mejor

func _actualizar_sprite():
	var anim := "idle_" + tamano
	if sprite.sprite_frames.has_animation(anim):
		# Dibujo propio para este tamaño: no hace falta escalarlo
		sprite.scale = escala_base
		sprite.play(anim)
	else:
		# Respaldo: la animación "idle" agrandada
		sprite.scale = escala_base * ESCALA[tamano]
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
