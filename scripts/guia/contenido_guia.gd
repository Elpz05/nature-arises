extends RefCounted

const HUD = preload("res://scripts/HUD/hud.gd")
const BESTIA = preload("res://scripts/entidades/bestias/espiritu.gd")
const ICONOS = preload("res://scripts/HUD/iconos_combate.gd")
const ELEMENTOS := ["natura", "flamma", "aqua", "terra", "electricitas", "glacies", "venenum"]
const TAMANOS := ["pequeno", "mediano", "grande"]
const LECCION_VOLCAN := [
	["Géiseres · cada 10 s", "Los círculos naranjas indican los géiseres. El borde marca sus ocho casillas vecinas, incluidas las diagonales. Cada pulso quita 25 HP a los árboles de esa zona y aumenta su cadencia un 25% durante 7 s. El centro queda reservado."],
	["Erupción · cada 25 s", "La erupción es un evento separado. Elige un árbol al azar y lo destruye si no es Flamma. Flamma también ignora el daño y el bono de los géiseres."],
	["Qué probar", "Planta un atacante dentro del borde naranja para ganar cadencia a cambio de vida. Coloca otro fuera del borde para comparar. Flamma es una buena defensa donde perder un árbol abriría el paso."],
]

const LECCIONES := [
	[
		["Tu primera defensa", "Coloca Natura en dos cuadros de tierra próximos al camino. Mira el círculo de alcance antes de confirmar. Busca una parcela que cubra más de un tramo."],
		["Empieza la ronda", "Pulsa Iniciar ronda y recoge agua del pozo central. Selecciona el poder Natura y confirma sobre un grupo para detenerlo brevemente. Al superar la ronda recibes dos gotas para reforzar la defensa."],
		["Prueba una mejora", "Selecciona un árbol plantado y elige Mejorar. Desde la segunda ronda, el rombo dorado marca a los Natura que dejan una copia al caer."],
	],
	[
		["Lluvia y pozas", "La lluvia acelera el pozo y reduce la cadencia de los árboles ofensivos. Planta Aqua en una casilla azul. En la poza lateral queda fuera del paso de las bestias."],
		["Fuego y agua", "Flamma golpea a grupos, pero su fuego no daña a Aqua. Mantén Natura cubriendo la misma ruta. Las bestias Flamma pueden revivir y tomar el atajo naranja."],
	],
	[
		["Puestos de Terra", "Las dos barras marcan puestos de Terra sobre el camino. Pon uno delante de los atacantes para mantener a las bestias dentro de su alcance."],
		["Armadura y paso libre", "Las bestias Terra pueden bloquear impactos. Prueba fuego concentrado y control. Aqua atraviesa los bloqueos, así que conserva árboles que puedan alcanzarla más adelante."],
	],
	[
		["Aviso de rayo", "Un recuadro amarillo muestra dónde caerá el rayo. En esta tormenta tienes 1.2 s para reaccionar. Puedes reservar esas casillas para árboles Electricitas, que resisten el impacto."],
		["Descargas y auras", "Electricitas encadena bestias cercanas y hace más daño en tormenta. Las bestias Electricitas dañan las ocho casillas que las rodean. Separa tus árboles del camino cuando puedas."],
	],
	LECCION_VOLCAN,
	[
		["Ventisca · cada 10 s", "El frío quita 25 HP y añade un nivel de congelación. Con tres niveles el árbol deja de disparar. Flamma y Glacies resisten la ventisca."],
		["Calor de Flamma", "Cada 20 s, Flamma reduce un nivel de congelación en sus ocho casillas vecinas y protege de nuevos niveles mientras siga allí. La ventisca aún quita vida. Contra el aura de una bestia Glacies, la protección de Flamma abarca su alcance de ataque."],
		["Qué probar", "Pon un Flamma junto a un atacante. Mantén a otros árboles a distancia del camino para evitar el aura tóxica de las bestias Venenum."],
	],
	[
		["Aviso de roca", "Cada 15 s cae una roca de arriba abajo. La franja naranja marca la columna 2.5 s antes. Sin Terra, la caída destruye las unidades de esa columna."],
		["Escudo de Terra", "Pon Terra en un puesto alto de la columna para proteger lo que quede debajo. Bloquea tres rocas y se rompe con la tercera. Si el aviso cae en una columna sin puesto, evita invertir allí hasta que pase."],
	],
	[
		["Radiación · cada 8 s en ronda", "Cada pulso quita 6 HP a los árboles. Aqua reduce el daño a 3 HP para sus vecinos de arriba, abajo, izquierda y derecha. Venenum es inmune."],
		["Dos atajos", "Las ramas naranja y amarilla corresponden a Flamma y Electricitas. Usa los puestos de Terra para ganar tiempo y el poder Aqua para confundir a las bestias antes de que entren al atajo."],
		["Qué probar", "Usa una poza para financiar el final. Cubre la entrada y las salidas de los atajos. Combina ataques de área con Glacies para grupos que esquivan Terra."],
	],
]

const BESTIAS := [
	["Camina por la ruta principal. Los Natura con rombo dorado dejan una copia del mismo tamaño al caer en combate.", "Concentra daño cerca de la meta. Reserva control para la copia si ves el rombo."],
	["Renace una vez y usa el atajo naranja donde existe. En lluvia o tormenta tiene la mitad de su vida base.", "Usa el poder Aqua o Glacies para infligir daño doble. Aqua también puede impedir que tome el atajo."],
	["Atraviesa barreras Terra y árboles Aqua. Es inmune al fuego de Flamma.", "Cubre la ruta con Natura, Electricitas o Glacies. El poder Glacies la congela y le inflige daño doble."],
	["Lenta y resistente. Tiene 10% de probabilidad de bloquear el daño de un impacto, aunque su efecto de control puede aplicarse.", "Deja espacio para varios disparos. El veneno periódico evita la tirada de bloqueo."],
	["Su aura quita 1 HP/s a los árboles en las ocho casillas vecinas. Resiste los rayos y puede usar el atajo eléctrico del nivel final.", "Aprovecha el alcance y separa los árboles del camino. Reserva control para su atajo."],
	["Su aura detiene los disparos de árboles vecinos, incluidas las diagonales. Glacies es inmune y Flamma protege a los árboles dentro de su alcance.", "Cubre a tus atacantes con Flamma. El poder Flamma inflige daño doble a esta bestia."],
	["Su aura reduce un 30% la cadencia de árboles vecinos y hace que fallen el 30% de sus intentos de disparo.", "Coloca atacantes de largo alcance fuera de las casillas adyacentes. El poder Natura y el poder Venenum no la afectan."],
]

const USOS_ARBOLES := [
	"Defensa barata de secano. Aprovecha parcelas que cubran dos tramos y mejora su alcance cuando se agote el espacio.",
	"Úsalo contra grupos y para proteger a los atacantes del aura de Glacies. Su fuego no daña a Aqua. Resiste géiseres y erupciones.",
	"Árbol de economía. Planta en casillas azules de lluvia, tormenta o radiación. Fuera del camino está a salvo del contacto. En radiación protege a los cuatro vecinos ortogonales.",
	"Úsalo para mantener bestias dentro del alcance de otros árboles. En derrumbe, protege su casilla y las de abajo en la misma columna. Aqua pasa de largo.",
	"Aprovecha los grupos compactos y las parcelas expuestas a rayos. La lluvia y la tormenta mejoran su daño.",
	"Colócalo al final de una recta para alcanzar a varias bestias en fila. Glacies resiste el frío y su proyectil puede detener grupos al congelarlos.",
	"Cubre varios tramos desde lejos. Su coste compensa cuando puede mantener el veneno sobre bestias resistentes. Resiste la radiación.",
]

const SIMBOLOS_ARBOLES := {
	"escudo": "Protección contra el aura de Glacies o nuevos niveles de ventisca.",
	"proteccion_aqua": "Un Aqua vecino reduce a la mitad el daño de radiación.",
	"rayo": "La bestia Electricitas causa daño continuo a sus vecinos.",
	"hielo": "El árbol acumula frío o tiene los disparos congelados.",
	"veneno": "La toxicidad reduce la cadencia y hace fallar disparos.",
	"geiser": "El pulso volcánico aumenta temporalmente la cadencia.",
}
const SIMBOLOS_BESTIAS := {
	"divisor": "Este Natura deja una copia al caer en combate.",
	"armadura": "Terra tiene un 10% de probabilidad de bloquear impactos.",
	"lento": "La bestia avanza más despacio.",
	"viento": "Ventus aumenta la velocidad de la bestia.",
	"renace": "Flamma se detiene brevemente después de recuperar su vida.",
}
const SIMBOLOS_PODERES := {
	"raiz": "La bestia está inmovilizada.",
	"confusion": "La bestia evita atajos mientras esté confundida.",
	"mareo": "La bestia se detiene a intervalos.",
	"retroceso": "La bestia retrocede por su ruta.",
	"fuego": "La quemadura inflige daño periódico.",
	"marca": "Los proyectiles de árbol infligen un punto de daño adicional.",
}

static func como_jugar() -> Array:
	return [
		{"titulo": "Primeros pasos", "secciones": [
			["1. Planta", "Selecciona una semilla y confirma en una parcela válida. El círculo muestra el alcance y se vuelve verde si puedes plantar allí. El Árbol Madre debe sobrevivir hasta que terminen todas las rondas."],
			["2. Defiende", "Lee la previsión y pulsa Iniciar ronda. Usa poderes contra grupos cuando pasen cerca. Recoge las gotas del pozo en el tablero para seguir plantando."],
			["3. Refuerza", "Lee el nivel y la barra de vida bajo cada árbol. Selecciónalo para ver su ficha. Pulsa Mejorar junto al árbol o usa la acción Mejorar Árbol. La pala libera la parcela sin devolver el agua."],
		]},
		{"titulo": "Terreno y agua", "secciones": [
			["Parcela seca", "El cuadrado marca una parcela para árboles de secano.", "parcela"],
			["Puesto de Terra", "Las barras marcan los bloqueos disponibles en el camino.", "puesto_terra"],
			["Poza de Aqua", "Planta Aqua en las casillas con la gota azul.", "gota"],
			["Pozo", "Guarda hasta cinco gotas durante la ronda. Confirma sobre la gota llena para recoger la reserva.", "gota", true],
			["Entrada", "La puerta marca el inicio. Las flechas siguen el sentido del camino.", "entrada"],
			["Árbol Madre", "Defiende el árbol al final de la ruta. Las bestias que llegan le quitan vida.", "meta"],
		]},
		{"titulo": "Combate y controles", "secciones": [
			["Teclado y mando", "Mueve el cursor del tablero con las acciones de dirección. Usa Confirmar para plantar, seleccionar un árbol o recoger el pozo. Usa Alternar Elemento o Planta y Cambiar Casilla para recorrer la barra. Puedes consultar o reasignar todas las teclas y botones en Ajustes."],
			["Poderes", "Selecciona un poder y confirma sobre el grupo objetivo. Cada uso gasta una carga aunque no alcance a nadie. Los efectos de daño y de movimiento pueden coexistir."],
			["Prioridad", "Selecciona un árbol ofensivo. Usa la mira junto a Mejorar o la acción Cambiar Prioridad para alternar entre Cerca de meta y Mayor vida.", "prioridad"],
		]},
		_leyenda("Símbolos de árboles", SIMBOLOS_ARBOLES),
		_leyenda("Símbolos de bestias", SIMBOLOS_BESTIAS),
		_leyenda("Símbolos de poderes", SIMBOLOS_PODERES),
	]

static func _leyenda(titulo: String, descripciones: Dictionary) -> Dictionary:
	var secciones := []
	for id in descripciones:
		secciones.append([ICONOS.ICONOS[id][1], descripciones[id], id])
	return {"titulo": titulo, "secciones": secciones}

static func bestias() -> Array:
	var fichas := []
	for i in ELEMENTOS.size():
		var tipo: String = ELEMENTOS[i]
		var datos: Dictionary = BESTIA.STATS[tipo]
		fichas.append({"titulo": tipo.capitalize(), "secciones": [
			["Qué hace", BESTIAS[i][0]],
			["Cómo responder", BESTIAS[i][1]],
			["Datos base · pequeño / mediano / grande", "%s HP · %s casillas/s\nDaño al Árbol Madre: %s\nDaño de contacto contra árboles: %d" % [
				_por_tamano(datos.vida), datos.vel, _por_tamano(datos.dano), BESTIA.DANO_CONTACTO[tipo]]],
		]})
	return fichas

static func arboles() -> Array:
	var fichas := []
	for i in HUD.SEMILLAS.size():
		var datos: Dictionary = HUD.SEMILLAS[i]
		fichas.append({"titulo": datos.nombre, "secciones": [
			["Qué hace", datos.rol],
			["Dónde y cuándo usarlo", USOS_ARBOLES[i]],
			["Coste en gotas", "Plantar %d · Mejora a nivel 2: %d · Mejora a nivel 3: %d" % datos.costos],
		]})
	return fichas

static func poderes() -> Array:
	var fichas := []
	for datos in HUD.ATAQUES:
		var recarga := str(datos.get("recarga", HUD.RECARGA_BASE)).trim_suffix(".0")
		fichas.append({"titulo": datos.nombre, "secciones": [
			["Efecto e inmunidades", datos.rol],
			["Datos base", "%d de daño directo · Radio de %s casillas\n%d cargas máximas · 1 carga cada %s s" % [
				datos.dano, datos.radio, datos.capacidad, recarga]],
		]})
	return fichas

static func _por_tamano(valores: Dictionary) -> String:
	var textos := PackedStringArray()
	for tamano in TAMANOS:
		textos.append(str(valores[tamano]))
	return " / ".join(textos)
