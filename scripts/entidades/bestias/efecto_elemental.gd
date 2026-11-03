extends RefCounted

const DURACIONES := {"natura": 0.5, "flamma": 3.0, "aqua": 6.0, "terra": 3.0, "electricitas": 0.5, "glacies": 2.0, "venenum": 6.0}
const COLORES := {"natura": Color(0.25, 1, 0.3), "flamma": Color(1, 0.35, 0.1), "aqua": Color(0.2, 0.65, 1), "terra": Color(0.7, 0.5, 0.25), "electricitas": Color(1, 0.9, 0.15), "glacies": Color(0.6, 0.95, 1), "venenum": Color(0.8, 0.3, 1)}

var elemento := ""
var restante := 0.0
var edad := 0.0
var ralentizado := false
var nadando := false

func aplicar(nuevo: String, lento: bool = false, nada: bool = false):
	elemento = nuevo
	restante = DURACIONES[nuevo]
	edad = 0.0
	ralentizado = lento
	nadando = nada

func limpiar():
	elemento = ""
	restante = 0.0
	edad = 0.0
	ralentizado = false
	nadando = false

func actualizar(delta: float):
	if elemento.is_empty():
		return
	edad += delta
	restante = maxf(0.0, restante - delta)
	if restante <= 0.000001:
		limpiar()

func cortes(delta: float) -> Array[float]:
	var resultado: Array[float] = [minf(delta, restante)]
	if elemento == "terra":
		var siguiente := (floorf(edad * 2.0 + 0.000001) + 1.0) * 0.5 - edad
		while siguiente < minf(delta, restante):
			if siguiente > 0.0:
				resultado.append(siguiente)
			siguiente += 0.5
	return resultado

func factor_movimiento(tiempo: float) -> float:
	if elemento.is_empty() or tiempo >= restante:
		return 1.0
	match elemento:
		"natura", "glacies": return 0.0
		"electricitas": return -1.0
		"terra": return 0.0 if int(floorf((edad + tiempo) * 2.0 + 0.000001)) % 2 == 0 else 1.0
		"venenum": return 0.75 if ralentizado else 1.0
	return 1.0

func dano_periodico(delta: float) -> float:
	return 10.0 * minf(delta, restante) if elemento == "flamma" else 0.0

func descripcion() -> String:
	match elemento:
		"natura": return "Detenido"
		"flamma": return "Quemadura 10 HP/s"
		"aqua": return "Confundido | Nadando" if nadando and edad < 0.5 else "Confundido"
		"terra": return "Mareado"
		"electricitas": return "Marcha inversa"
		"glacies": return "Congelado elemental"
		"venenum": return "Vulnerable +1 | Lento 25%" if ralentizado else "Vulnerable +1"
	return ""
