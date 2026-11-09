extends RefCounted

const ESCENAS := [
	"res://escenas/escenas_niveles/nivel_0.tscn", "res://escenas/escenas_niveles/nivel_1.tscn",
	"res://escenas/escenas_niveles/nivel_2.tscn", "res://escenas/escenas_niveles/nivel_3.tscn",
	"res://escenas/escenas_niveles/nivel_4.tscn", "res://escenas/escenas_niveles/nivel_5.tscn",
	"res://escenas/escenas_niveles/nivel_6.tscn", "res://escenas/escenas_niveles/nivel_7.tscn",
]

const RUTA_HORIZONTAL := [
	Vector2i(0, 4), Vector2i(26, 4), Vector2i(26, 7), Vector2i(3, 7), Vector2i(3, 10),
	Vector2i(26, 10), Vector2i(26, 13), Vector2i(3, 13), Vector2i(3, 15), Vector2i(2, 15),
]
const ATAJO_FLAMMA := {"tipo": "flamma", "tramo": [Vector2i(26, 7), Vector2i(26, 13)], "salidas": [Vector2i(26, 10)], "color": Color(1.0, 0.55, 0.23)}
const ATAJO_ELECTRICITAS := {"tipo": "electricitas", "tramo": [Vector2i(18, 7), Vector2i(18, 10)], "color": Color(1.0, 0.92, 0.42)}
const POZAS_RADIACION := [Vector2i(7, 5), Vector2i(8, 5), Vector2i(19, 9), Vector2i(20, 9)]

const DESAFIOS := [
	{3: {"natura:mediano:divisor": 1, "natura:pequeno": 2}},
	{3: {"flamma:mediano": 1, "aqua:mediano": 1}},
	{3: {"terra:mediano": 1, "aqua:mediano": 1}},
	{4: {"electricitas:mediano": 1, "flamma:mediano": 2}},
	{3: {"glacies:mediano": 1, "electricitas:mediano": 1}},
	{3: {"venenum:mediano": 1, "flamma:mediano": 1}},
	{3: {"terra:mediano": 1, "aqua:mediano": 2}},
	{3: {"electricitas:grande": 1, "glacies:mediano": 1}},
]

const RUTA_VERTICAL := [
	Vector2i(4, 3), Vector2i(4, 15), Vector2i(8, 15), Vector2i(8, 3), Vector2i(12, 3),
	Vector2i(12, 15), Vector2i(16, 15), Vector2i(16, 3), Vector2i(20, 3), Vector2i(20, 15),
	Vector2i(24, 15), Vector2i(24, 4), Vector2i(25, 4),
]

const TERRENOS := [
	{
		"secano": [Vector2i(0, 4), Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(4, 7),
			Vector2i(6, 8), Vector2i(4, 10), Vector2i(9, 11), Vector2i(16, 11), Vector2i(24, 12)],
	},
	{
		"secano": [Vector2i(1, 3), Vector2i(4, 3), Vector2i(6, 3), Vector2i(9, 3), Vector2i(12, 5),
			Vector2i(16, 6), Vector2i(24, 6), Vector2i(24, 9), Vector2i(10, 11), Vector2i(2, 14)],
		"agua": [Vector2i(7, 4), Vector2i(10, 5)],
	},
	{
		"secano": [Vector2i(3, 4), Vector2i(3, 7), Vector2i(3, 10), Vector2i(5, 6), Vector2i(6, 12),
			Vector2i(7, 10), Vector2i(10, 4), Vector2i(13, 14), Vector2i(19, 7), Vector2i(23, 4)],
		"terra": [Vector2i(4, 8), Vector2i(8, 11), Vector2i(16, 7)],
	},
	{
		"secano": [Vector2i(1, 3), Vector2i(4, 3), Vector2i(7, 3), Vector2i(10, 3), Vector2i(13, 5),
			Vector2i(18, 5), Vector2i(25, 6), Vector2i(25, 9), Vector2i(9, 11), Vector2i(4, 14)],
		"terra": [Vector2i(10, 7), Vector2i(26, 9), Vector2i(21, 13)],
		"agua": [Vector2i(8, 4), Vector2i(10, 5)],
	},
	{
		"secano": [Vector2i(1, 3), Vector2i(4, 3), Vector2i(5, 5), Vector2i(7, 5), Vector2i(9, 3),
			Vector2i(12, 5), Vector2i(16, 6), Vector2i(18, 8), Vector2i(22, 11), Vector2i(4, 14)],
		"terra": [Vector2i(11, 7), Vector2i(6, 13)],
	},
	{
		"secano": [Vector2i(3, 4), Vector2i(5, 4), Vector2i(3, 6), Vector2i(5, 7), Vector2i(3, 9),
			Vector2i(5, 9), Vector2i(7, 13), Vector2i(10, 4), Vector2i(15, 8), Vector2i(21, 14)],
		"terra": [Vector2i(4, 9), Vector2i(8, 12), Vector2i(20, 9)],
	},
	{
		"secano": [Vector2i(3, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(5, 4), Vector2i(6, 5),
			Vector2i(3, 7), Vector2i(5, 9), Vector2i(7, 12), Vector2i(9, 5), Vector2i(15, 9),
			Vector2i(19, 11), Vector2i(23, 6)],
		"terra": [Vector2i(4, 3), Vector2i(8, 4), Vector2i(12, 5), Vector2i(20, 4), Vector2i(24, 4)],
	},
	{
		"secano": [Vector2i(8, 6), Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 6), Vector2i(16, 5),
			Vector2i(25, 11), Vector2i(25, 9), Vector2i(23, 11), Vector2i(4, 14), Vector2i(20, 5), Vector2i(21, 8)],
		"terra": [Vector2i(18, 9), Vector2i(26, 11), Vector2i(12, 13)],
		"agua": [Vector2i(8, 5), Vector2i(19, 9)],
	},
]

const ETAPAS := [
	{
		"nombre": "Primeras raíces", "clima": "despejado", "agua": 3,
		"consejo": "Planta Natura en los cuadros marcados. Elige los que cubren varios tramos y mejora tus árboles cuando se agote el espacio.",
		"plantas": [1, 2], "ataques": [1], "intervalos": [3.0, 2.8, 2.6, 2.4, 2.2],
		"rondas": [{"natura:pequeno": 4}, {"natura:pequeno": 4, "natura:mediano:divisor": 1},
			{"natura:pequeno": 2, "natura:pequeno:divisor": 1, "natura:mediano": 2},
			{"natura:mediano": 2, "natura:mediano:divisor": 1, "natura:grande": 1},
			{"natura:mediano": 1, "natura:mediano:divisor": 1, "natura:grande": 2}],
	},
	{
		"nombre": "Agua y fuego", "clima": "lluvia", "agua": 3,
		"consejo": "Aqua produce agua en casillas azules. Combina Natura y Flamma: las bestias Aqua son inmunes al fuego.",
		"plantas": [3], "ataques": [2, 3], "intervalos": [3.0, 2.8, 2.5, 2.3, 2.1],
		"rondas": [{"natura:pequeno": 4, "flamma:pequeno": 2},
			[{"natura:pequeno": 3, "natura:pequeno:divisor": 1}, {"flamma:pequeno": 2}, {"aqua:pequeno": 2}],
			[{"natura:mediano": 2}, {"flamma:pequeno": 2, "aqua:pequeno": 2}],
			{"natura:mediano": 2, "flamma:mediano": 1, "aqua:mediano": 1},
			{"natura:grande:divisor": 1, "flamma:mediano": 2, "aqua:mediano": 2}],
	},
	{
		"nombre": "La muralla", "clima": "despejado", "agua": 8, "vertical": true,
		"consejo": "Planta Terra sobre el camino seco para ganar tiempo. Las bestias Terra pueden bloquear impactos; Aqua atraviesa las barreras.",
		"plantas": [4], "ataques": [4], "intervalos": [3.0, 2.8, 2.5, 2.2, 2.0],
		"rondas": [[{"terra:pequeno": 2}, {"natura:pequeno": 4}],
			{"natura:mediano": 2, "terra:pequeno": 3},
			[{"terra:mediano": 2}, {"aqua:pequeno": 4}],
			[{"terra:mediano": 2}, {"flamma:mediano": 2}],
			{"terra:grande": 1, "natura:grande": 2, "aqua:mediano": 2}],
	},
	{
		"nombre": "Cielo dividido", "clima": "tormenta", "agua": 10, "atajo": true,
		"consejo": "Electricitas encadena enemigos y resiste los rayos. Su daño mejora con la tormenta; evita agrupar árboles junto a bestias eléctricas.",
		"plantas": [5], "ataques": [5], "intervalos": [2.8, 2.6, 2.4, 2.1, 1.9],
		"rondas": [{"aqua:pequeno": 4, "electricitas:pequeno": 2}, {"natura:mediano": 2, "electricitas:pequeno": 3},
			[{"electricitas:mediano": 2}, {"flamma:pequeno": 4}],
			[{"terra:mediano": 2}, {"electricitas:mediano": 3}],
			{"electricitas:grande": 1, "aqua:grande": 2, "flamma:mediano": 2}],
	},
	{
		"nombre": "Corazón volcánico", "clima": "volcan", "agua": 12,
		"consejo": "Flamma resiste géiseres y erupciones. Los géiseres dañan y aceleran a sus vecinos; Glacies puede frenar a los grupos.",
		"plantas": [6], "ataques": [6], "intervalos": [2.8, 2.6, 2.3, 2.1, 1.9],
		"rondas": [{"glacies:pequeno": 4, "natura:pequeno": 3},
			[{"terra:pequeno": 3}, {"glacies:mediano": 2}],
			{"glacies:mediano": 3, "electricitas:pequeno": 3}, {"glacies:grande": 1, "flamma:mediano": 3},
			[{"terra:mediano": 2}, {"glacies:grande": 2}, {"aqua:mediano": 2}]],
	},
	{
		"nombre": "El bosque helado", "clima": "ventisca", "agua": 14, "vertical": true,
		"consejo": "Alterna Flamma y Glacies para resistir el frío. Protege tus defensas de las auras tóxicas y aprovecha el alcance de Venenum.",
		"plantas": [], "ataques": [], "intervalos": [2.7, 2.5, 2.3, 2.0, 1.8],
		"rondas": [{"glacies:pequeno": 3, "venenum:pequeno": 2}, {"glacies:mediano": 2, "venenum:pequeno": 3},
			[{"venenum:mediano": 2}, {"flamma:mediano": 2}],
			{"glacies:grande": 1, "venenum:mediano": 3, "aqua:mediano": 2},
			[{"glacies:grande": 2}, {"venenum:grande": 1}, {"flamma:grande": 1}]],
	},
	{
		"nombre": "El desfiladero", "clima": "derrumbe", "agua": 16, "vertical": true,
		"consejo": "Terra detiene tres rocas por columna. Coloca tus atacantes detrás de la barrera y repón las defensas que caigan.",
		"plantas": [], "ataques": [], "intervalos": [2.6, 2.4, 2.2, 2.0, 1.8],
		"rondas": [[{"terra:pequeno": 3}, {"natura:mediano": 2}],
			{"electricitas:mediano": 2, "aqua:mediano": 3},
			[{"terra:mediano": 2}, {"glacies:mediano": 2}, {"venenum:pequeno": 2}],
			{"flamma:grande": 1, "terra:grande": 1, "venenum:mediano": 2},
			{"terra:grande": 2, "electricitas:grande": 1, "glacies:grande": 1, "aqua:grande": 1}],
	},
	{
		"nombre": "El último brote", "clima": "radiacion", "agua": 24, "atajo": true,
		"consejo": "Aqua abastece el pozo desde las pozas azules. Bloquea los atajos con Terra y combina Flamma y Electricitas contra grupos, Glacies y Venenum para frenarlos y Natura para cubrir huecos.",
		"consejos_ronda": [
			"Aqua produce agua y protege a sus vecinos del pulso. Natura cubre el primer tramo con poca inversión.",
			"Flamma golpea a grupos y protege del aura gélida. Glacies frena a las bestias que sobreviven.",
			"Terra puede bloquear el atajo eléctrico. Coloca Venenum detrás para ralentizar a las bestias blindadas.",
			"Aqua atraviesa las barreras de Terra. Congélalas con Glacies y encadena al grupo con Electricitas.",
			"Venenum resiste la radiación y cubre varios carriles. Refuerza el atajo de Flamma antes de que lleguen los grandes.",
		],
		"plantas": [], "ataques": [], "intervalos": [1.25, 1.1, 1.6, 1.0, 1.4],
		"rondas": [
			{"natura:pequeno": 7, "natura:pequeno:divisor": 1, "aqua:pequeno": 3},
			{"flamma:pequeno": 4, "glacies:pequeno": 4, "natura:mediano": 2},
			[{"terra:mediano": 2}, {"venenum:mediano": 2}, {"electricitas:mediano": 3}],
			[{"glacies:mediano": 2}, {"aqua:mediano": 5}, {"electricitas:mediano": 4}],
			{"flamma:grande": 1, "terra:grande": 1, "venenum:grande": 1, "glacies:mediano": 2, "electricitas:mediano": 2, "aqua:mediano": 2},
		],
	},
]

static func disponibles_para_nivel(numero: int) -> Dictionary:
	var plantas: Array = [0]
	var ataques: Array = [0]
	for i in clampi(numero, 0, ETAPAS.size()):
		for id in ETAPAS[i].plantas:
			if not plantas.has(id): plantas.append(id)
		for id in ETAPAS[i].ataques:
			if not ataques.has(id): ataques.append(id)
	plantas.sort()
	ataques.sort()
	return {"plantas": plantas, "ataques": ataques}

static func configurar_progreso(nivel, numero: int):
	var datos: Dictionary = ETAPAS[numero]
	var terreno: Dictionary = TERRENOS[numero]
	nivel.limitar_plantado = true
	nivel.parcelas_secano.assign(terreno.secano)
	nivel.puestos_terra.assign(terreno.get("terra", []))
	nivel.celdas_inundadas.assign(terreno.get("agua", []))
	nivel.titulo_nivel = datos.nombre
	nivel.consejo_nivel = datos.consejo
	nivel.consejos_ronda.assign(datos.get("consejos_ronda", []))
	nivel.gotas_iniciales = datos.agua
	nivel.desbloqueos.assign(datos.plantas)
	nivel.desbloqueos_ataques.assign(datos.ataques)
	nivel.intervalos_spawn.assign(datos.intervalos)
	nivel.rondas = datos.rondas.duplicate(true)
	nivel.desafios_ronda = DESAFIOS[numero].duplicate(true)
