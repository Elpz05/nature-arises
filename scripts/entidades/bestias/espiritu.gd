extends CharacterBody2D

signal llego_a_meta(dano: int)
signal invocar_copia(tipo: String, tamano: String, progreso: float)
signal dano_recibido(cantidad: float, periodico: bool)

const TAMANO_CELDA := 64
const EfectoElemental = preload("res://scripts/entidades/bestias/efecto_elemental.gd")
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const ICONO_AURA := {"terra": "armadura", "electricitas": "rayo", "glacies": "hielo", "venenum": "veneno"}
const ICONO_MOVIMIENTO := {"natura": "raiz", "aqua": "confusion", "terra": "mareo", "electricitas": "retroceso", "glacies": "hielo"}
const DANO_CONTACTO := {"natura": 50, "flamma": 100, "aqua": 0, "terra": 100, "electricitas": 50, "glacies": 75, "venenum": 150}
const INTERVALO_CONTACTO := 1.0

const STATS := {
	"terra": {"vida": {"pequeno": 500, "mediano": 900, "grande": 1500},
			"vel": 0.2, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"electricitas": {"vida": {"pequeno": 300, "mediano": 500, "grande": 1000},
			"vel": 0.6, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"glacies": {"vida": {"pequeno": 350, "mediano": 550, "grande": 1050},
			"vel": 0.3, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"venenum": {"vida": {"pequeno": 300, "mediano": 600, "grande": 900},
			"vel": 0.6, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"natura": {"vida": {"pequeno": 200, "mediano": 500, "grande": 1000},
			"vel": 0.4, "dano": {"pequeno": 2, "mediano": 3, "grande": 5}},
	"flamma": {"vida": {"pequeno": 150, "mediano": 450, "grande": 800},
			"vel": 0.3, "dano": {"pequeno": 3, "mediano": 4, "grande": 6}},
	"aqua":   {"vida": {"pequeno": 200, "mediano": 500, "grande": 1000},
			"vel": 0.5, "dano": {"pequeno": 1, "mediano": 2, "grande": 3}},
}
const ESCALA := {"pequeno": 1.0, "mediano": 1.3, "grande": 1.6}

const SPRITES_PEQUENOS := {
	"natura": preload("res://sprites/beasts/natura/little/idle/beast_natura_little_idle.png"),
	"aqua": preload("res://sprites/beasts/aqua/little/idle/beast_aqua_little_idle.png"),
	"electricitas": preload("res://sprites/beasts/electricitas/little/idle/beast_electricitas_little_idle.png"),
	"flamma": preload("res://sprites/beasts/flamma/little/idle/beast_flamma_little_idle.png"),
	"glacies": preload("res://sprites/beasts/glacies/little/idle/beast_glacies_little_idle.png"),
	"terra": preload("res://sprites/beasts/terra/little/idle/beast_terra_little_idle.png"),
	"venenum": preload("res://sprites/beasts/venenum/little/idle/beast_venenum_little_idle.png"),
}
const SPRITE_FLAMMA_GRANDE = preload("res://sprites/beasts/flamma/big/idle/beast_flamma_big_idle.png")
const DURACION_FOTOGRAMA := 0.25
const ESCALA_SPRITE_ANIMADO := 2.0

var tiempo_animacion := 0.0

@export var textura_pequeno: Texture2D
@export var textura_mediano: Texture2D
@export var textura_grande: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var colision: CollisionShape2D = $CollisionShape2D

@export_enum("natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum") var tipo := "natura"
@export_enum("pequeno", "mediano", "grande") var tamano := "pequeno"
@export var es_divisor := false
var vida := 200.0
var vida_maxima := 200.0
var velocidad := 25.6
var muerto := false
var detenido := 0.0
var renacio := false
var clima := "despejado"
var factor_vida_ronda := 1.0
var factor_velocidad_ronda := 1.0
var bono_ventus := 0.0
var escala_sprite_base := Vector2.ONE
var factor_lentitud := 1.0
var lentitud_restante := 0.0
var resolver_avance: Callable
var puede_avanzar: Callable
var recarga_contacto := 0.0
var congelacion_restante := 0.0
var veneno_restante := 0.0
var veneno_por_segundo := 0.0
var factor_lentitud_veneno := 1.0
var efecto_movimiento := EfectoElemental.new()
var efecto_dano := EfectoElemental.new()
var cambiar_ruta: Callable
var limite_confusion := INF
var rotacion_sprite_base := 0.0

func aplicar_veneno(dano_segundo: float, factor: float, duracion: float):
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion() or duracion <= 0.0:
		return
	dano_segundo = 0.0 if tipo == "venenum" else maxf(0.0, dano_segundo)
	factor = clampf(factor, 0.1, 1.0)
	if veneno_restante > 0.0 and (dano_segundo < veneno_por_segundo or factor > factor_lentitud_veneno):
		return
	veneno_restante = maxf(veneno_restante, duracion) if is_equal_approx(dano_segundo, veneno_por_segundo) and is_equal_approx(factor, factor_lentitud_veneno) else duracion
	veneno_por_segundo = dano_segundo
	factor_lentitud_veneno = factor
	queue_redraw()

func _limpiar_veneno():
	veneno_restante = 0.0
	veneno_por_segundo = 0.0
	factor_lentitud_veneno = 1.0

func _calcular_avance(delta: float) -> float:
	if congelacion_restante <= 0.0 and lentitud_restante <= 0.0 and veneno_restante <= 0.0 \
			and efecto_movimiento.elemento.is_empty() and not efecto_dano.ralentizado:
		return (velocidad + bono_ventus * TAMANO_CELDA) * delta
	# Integra cada expiración sin multiplicar ralentizaciones simultáneas.
	var cortes: Array[float] = [0.0, delta, minf(delta, congelacion_restante), minf(delta, lentitud_restante), minf(delta, veneno_restante)]
	cortes.append_array(efecto_movimiento.cortes(delta))
	if efecto_dano.ralentizado:
		cortes.append(minf(delta, efecto_dano.restante))
	cortes.sort()
	var desplazamiento := 0.0
	var rapidez := velocidad + bono_ventus * TAMANO_CELDA
	var progreso: float = (get_parent() as PathFollow2D).progress
	for i in range(cortes.size() - 1):
		var inicio := cortes[i]
		if inicio < congelacion_restante:
			continue
		var factor := factor_lentitud if inicio < lentitud_restante else 1.0
		if inicio < veneno_restante:
			factor = minf(factor, factor_lentitud_veneno)
		factor = minf(factor, efecto_dano.factor_movimiento(inicio))
		var elemental: float = efecto_movimiento.factor_movimiento(inicio)
		factor = -factor if elemental < 0.0 else minf(factor, elemental)
		desplazamiento = maxf(-progreso, desplazamiento + (cortes[i + 1] - inicio) * factor * rapidez)
	return desplazamiento

func aplicar_congelacion(duracion: float):
	if muerto or is_queued_for_deletion() or duracion <= 0.0:
		return
	congelacion_restante = maxf(congelacion_restante, duracion)
	queue_redraw()

func remover_congelacion():
	congelacion_restante = 0.0
	if efecto_movimiento.elemento == "glacies":
		efecto_movimiento.limpiar()
	queue_redraw()

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
	var entorno = preload("res://scripts/nivel/clima.gd")
	vida = roundi(datos["vida"][tamano] * entorno.factor_vida_bestia(clima, tipo) * factor_vida_ronda)
	vida_maxima = vida
	velocidad = datos["vel"] * TAMANO_CELDA * entorno.factor_velocidad_bestia(clima, tipo) * factor_velocidad_ronda
	escala_sprite_base = sprite.scale
	rotacion_sprite_base = sprite.rotation
	_aplicar_sprite()
	queue_redraw()

func obtener_porcentaje_vida() -> float:
	return clampf(float(vida) / float(vida_maxima), 0.0, 1.0)

func obtener_estado_combate() -> String:
	var estados: PackedStringArray = []
	if es_divisor and tipo == "natura":
		estados.append("Se divide")
	if not efecto_movimiento.elemento.is_empty():
		estados.append(efecto_movimiento.descripcion())
	if not efecto_dano.elemento.is_empty():
		estados.append(efecto_dano.descripcion())
	if tipo in ["terra", "electricitas", "glacies", "venenum"]:
		estados.append({"terra": "Terra | Bloqueo 10%", "electricitas": "Electricitas | Aura eléctrica", "glacies": "Glacies | Aura gélida", "venenum": "Venenum | Aura tóxica"}[tipo])
	if bono_ventus > 0.0:
		estados.append("Ventus +0.5")
	if congelacion_restante > 0.0:
		estados.append("Congelado")
	if veneno_restante > 0.0 and veneno_por_segundo > 0.0:
		estados.append("Veneno %.0f HP/s" % veneno_por_segundo)
	var factor_actual := factor_lentitud if lentitud_restante > 0.0 else 1.0
	if veneno_restante > 0.0:
		factor_actual = minf(factor_actual, factor_lentitud_veneno)
	if factor_actual < 1.0:
		estados.append("Lento %d%%" % roundi((1.0 - factor_actual) * 100.0))
	if detenido > 0.0:
		estados.append("Renaciendo" if tipo == "flamma" and renacio else "Detenido")
	return " | ".join(estados)

func obtener_iconos_combate() -> Array[String]:
	var estados: Array[String] = []
	if es_divisor and tipo == "natura":
		estados.append("divisor")
	if ICONO_AURA.has(tipo):
		estados.append(ICONO_AURA[tipo])
	if not efecto_movimiento.elemento.is_empty():
		var icono: String = ICONO_MOVIMIENTO[efecto_movimiento.elemento]
		if not estados.has(icono):
			estados.append(icono)
	if efecto_dano.elemento == "flamma":
		estados.append("fuego")
	elif efecto_dano.elemento == "venenum":
		estados.append("marca")
	if congelacion_restante > 0.0 and not estados.has("hielo"):
		estados.append("hielo")
	if veneno_restante > 0.0 and veneno_por_segundo > 0.0 and not estados.has("veneno"):
		estados.append("veneno")
	if lentitud_restante > 0.0 or veneno_restante > 0.0 or efecto_dano.ralentizado:
		estados.append("lento")
	if bono_ventus > 0.0:
		estados.append("viento")
	if detenido > 0.0:
		var icono := "renace" if tipo == "flamma" and renacio else "raiz"
		if not estados.has(icono):
			estados.append(icono)
	return estados

func tiene_marca_veneno() -> bool:
	return not muerto and veneno_restante > 0.0 and veneno_por_segundo > 0.0

func _draw():
	if muerto or not is_instance_valid(colision) or colision.shape == null:
		return
	var radio: float = colision.shape.radius * colision.scale.x + 5.0
	if tiene_marca_veneno():
		var escoria := Color("#b4c568a0")
		draw_arc(Vector2.ZERO, radio, 0.22 * PI, 0.78 * PI, 12, escoria, 2.5, true)
		draw_circle(Vector2(0, radio + 3.0), 2.5, escoria)
	if not efecto_movimiento.elemento.is_empty():
		draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, EfectoElemental.COLORES[efecto_movimiento.elemento], 2.0, true)
	if not efecto_dano.elemento.is_empty():
		draw_arc(Vector2.ZERO, radio + 4.0, 0.0, TAU, 32, EfectoElemental.COLORES[efecto_dano.elemento], 2.0, true)
	var y: float = -colision.shape.radius * colision.scale.y - 11.0
	ICONOS.dibujar_vida(self, Vector2(0, y), 38.0, obtener_porcentaje_vida())
	ICONOS.dibujar_fila(self, obtener_iconos_combate(), Vector2(0, y - 13), 76.0)

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
		var tira: Texture2D = SPRITES_PEQUENOS.get(tipo)
		if tipo == "flamma" and tamano == "grande":
			tira = SPRITE_FLAMMA_GRANDE
		if tira != null:
			sprite.texture = tira
			sprite.hframes = tira.get_width() / 32
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.modulate = Color.WHITE
			sprite.scale = escala * ESCALA_SPRITE_ANIMADO
		else:
			sprite.scale = escala_sprite_base * escala

func _physics_process(delta: float):
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return
	if get_tree().paused:
		return
	# El nivel controla pausa, derrota y victoria también para el movimiento.
	if puede_avanzar.is_valid() and not puede_avanzar.call():
		return
	if sprite.hframes > 1:
		tiempo_animacion = fposmod(tiempo_animacion + delta, DURACION_FOTOGRAMA * sprite.hframes)
		sprite.frame = int(tiempo_animacion / DURACION_FOTOGRAMA)
	recarga_contacto = maxf(0.0, recarga_contacto - delta)
	var estado_anterior := obtener_iconos_combate()
	var avance := _calcular_avance(delta)
	limite_confusion = (get_parent() as PathFollow2D).progress + _calcular_avance(minf(delta, efecto_movimiento.restante)) if efecto_movimiento.elemento == "aqua" else INF
	var interrumpido: bool = is_zero_approx(avance) and is_zero_approx(efecto_movimiento.factor_movimiento(0.0))
	var dano_periodico: float = efecto_dano.dano_periodico(delta)
	if veneno_restante > 0.0:
		dano_periodico += veneno_por_segundo * minf(delta, veneno_restante)
		veneno_restante = maxf(0.0, veneno_restante - delta)
		if veneno_restante == 0.0:
			_limpiar_veneno()
	var ya_renacio := renacio
	if dano_periodico > 0.0:
		recibir_dano(dano_periodico, false)
	if muerto or get_parent().is_queued_for_deletion() or renacio != ya_renacio:
		return
	var tiempo_congelado := minf(delta, congelacion_restante)
	congelacion_restante = maxf(0.0, congelacion_restante - delta)
	lentitud_restante = maxf(0.0, lentitud_restante - delta)
	if lentitud_restante == 0.0:
		factor_lentitud = 1.0
	if detenido > 0.0:
		detenido = maxf(0.0, detenido - delta)
		_finalizar_efecto(delta, estado_anterior)
		return
	if interrumpido or (tiempo_congelado >= delta and tiempo_congelado > 0.0):
		_finalizar_efecto(delta, estado_anterior)
		return
	var seguidor := get_parent() as PathFollow2D
	var siguiente: float = seguidor.progress + avance
	if resolver_avance.is_valid():
		siguiente = resolver_avance.call(self, seguidor.progress, siguiente)
	seguidor.progress = maxf(0.0, siguiente)
	_finalizar_efecto(delta, estado_anterior)
	if seguidor.progress_ratio >= 1.0:
		muerto = true
		queue_redraw()
		llego_a_meta.emit(STATS[tipo]["dano"][tamano])
		seguidor.queue_free()

func _finalizar_efecto(delta: float, estado_anterior: Array[String]):
	var movimiento_anterior: String = efecto_movimiento.elemento
	efecto_movimiento.actualizar(delta)
	efecto_dano.actualizar(delta)
	_actualizar_visual_elemental()
	if movimiento_anterior != efecto_movimiento.elemento or estado_anterior != obtener_iconos_combate():
		queue_redraw()

func _actualizar_visual_elemental():
	var nadando: bool = efecto_movimiento.elemento == "aqua" and efecto_movimiento.nadando and efecto_movimiento.edad < 0.5
	sprite.rotation = rotacion_sprite_base + (sin(efecto_movimiento.edad * TAU * 4.0) * 0.2 if nadando else 0.0)

func recibir_proyectil(cantidad: float) -> bool:
	var extra := 1.0 if efecto_dano.elemento == "venenum" else 0.0
	return recibir_dano(cantidad + extra)

func _tirada_defensa() -> float:
	return randf()

func recibir_dano(cantidad: float, es_impacto: bool = true) -> bool:
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return false
	if cantidad <= 0.0:
		return false
	if tipo == "terra" and es_impacto and _tirada_defensa() < 0.1:
		return false
	var aplicado := minf(vida, cantidad)
	vida -= aplicado
	dano_recibido.emit(aplicado, not es_impacto)
	if vida <= 0:
		_morir()
	queue_redraw()
	return true

func _morir():
	_limpiar_veneno()
	efecto_movimiento.limpiar()
	efecto_dano.limpiar()
	_actualizar_visual_elemental()
	# Flamma renace una vez, en el mismo punto, y se queda 3 s quieta
	if tipo == "flamma" and not renacio:
		renacio = true
		vida = vida_maxima
		detenido = 3.0
		return
	muerto = true
	if tipo == "natura" and es_divisor:
		invocar_copia.emit(tipo, tamano, (get_parent() as PathFollow2D).progress)
	get_parent().queue_free()

func destruir_por_entorno():
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return
	var aplicado := vida
	vida = 0.0
	dano_recibido.emit(aplicado, false)
	muerto = true
	_limpiar_veneno()
	efecto_movimiento.limpiar()
	efecto_dano.limpiar()
	queue_redraw()
	get_parent().queue_free()

func bendecir_ventus():
	# El documento no define acumulación: renovar la bendición conserva +0.5.
	bono_ventus = 0.5
	queue_redraw()

func _tirada_natacion() -> float:
	return randf()

func aplicar_ataque_elemental(elemento: String, dano: float, ralentizar_venenum: bool = false) -> bool:
	if muerto or is_queued_for_deletion() or get_parent().is_queued_for_deletion():
		return false
	elemento = elemento.to_lower()
	if not EfectoElemental.DURACIONES.has(elemento):
		return false
	var inmunidades := {"natura": ["flamma", "venenum"], "flamma": ["flamma", "aqua"], "aqua": ["aqua"], "terra": ["terra"], "electricitas": ["electricitas"], "glacies": ["glacies"], "venenum": ["venenum"]}
	if tipo in inmunidades[elemento]:
		return false
	var multiplicador := 1.0
	if (elemento == "flamma" and tipo == "glacies") or (elemento == "aqua" and tipo == "flamma") or (elemento == "glacies" and tipo in ["flamma", "aqua"]):
		multiplicador = 2.0
	var dano_final := vida if elemento == "venenum" and tipo == "natura" and tamano == "pequeno" else dano * multiplicador
	recibir_dano(dano_final)
	if muerto or get_parent().is_queued_for_deletion():
		return true
	var efecto := efecto_dano if elemento in ["flamma", "venenum"] else efecto_movimiento
	efecto.aplicar(elemento, ralentizar_venenum, elemento == "aqua" and _tirada_natacion() < 0.5)
	if elemento == "aqua" and cambiar_ruta.is_valid():
		cambiar_ruta.call(self)
	_actualizar_visual_elemental()
	queue_redraw()
	return true
