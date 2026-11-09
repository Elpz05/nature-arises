# Efectos, peligros y dificultad

## Proyectiles y partículas

1. Empieza con Flamma. Usa el punto de impacto de `bala.gd` para disparar una ráfaga de 12–20 brasas durante unos 0.35 s. Añade una estela corta al proyectil con partículas en coordenadas globales para que las brasas queden atrás mientras vuela. Conserva el radio de explosión y el daño donde se resuelven hoy.
2. En `carambano.gd`, añade una estela fría y una ráfaga pequeña por impacto confirmado. En `descarga.gd`, conserva la línea que muestra la cadena y añade chispas solo en sus extremos. Usa un efecto persistente discreto por objetivo envenenado en vez de emitir en cada tick de daño.
3. Pon los emisores de impacto bajo un nodo de efectos del nivel para que puedan terminar cuando se libera el proyectil. Empieza con escenas de una sola emisión y recicla por `finished` solo si el perfil de rendimiento lo justifica. Usa `restart()` al reutilizar. Mantén los efectos cosméticos fuera de las consultas de colisión, la simulación y el generador aleatorio de combate. Comprueba que el daño y los objetivos coincidan a 1× y 2×.

[Emisores 2D y ciclo de vida en Godot](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html)

## Terreno y peligros

Hoy `clima.gd` elige rayos con un muestreo uniforme del rectángulo jugable y consulta las unidades en la casilla al resolver el impacto. Conserva las coordenadas de casilla como identificadores y separa tres responsabilidades.

- **Terreno estático.** Construye un catálogo al inicializar el nivel a partir del suelo, el camino principal, los atajos y las marcas de nivel. Expón datos como terreno jugable, ruta, parcela, zona reservada y etiquetas de peligro. Usa datos personalizados de TileSet para propiedades que se repiten en todas las instancias de un tile, y una capa de marcadores para excepciones de una casilla concreta.
- **Ocupación dinámica.** Reutiliza el índice de torres por casilla. Da a los enemigos una consulta de ocupación al resolver el impacto, de forma que puedan salir de una casilla avisada o entrar en ella. Mantén las conversiones entre el mundo y la cuadrícula en el tablero para que la cámara y el HUD queden fuera de la simulación.
- **Planificación de peligros.** Da a cada peligro un filtro de candidatos, una ponderación y una política de aviso. Para rayos, empieza con exclusiones explícitas para la entrada, el pozo y la meta, y pondera terrenos expuestos. Congela el objetivo al emitir el aviso. Usa una semilla separada para repetir secuencias en pruebas. Define qué pasa con un aviso pendiente al cerrar una ronda.

Migra primero el muestreo de rayos y conserva sus intervalos y las inmunidades. Prueba exclusiones, atajos, cambios de ocupación entre aviso e impacto, pausa y reinicio. Extiende el mismo contrato a derrumbes, géiseres y radiación después.

[Capas de tile en Godot](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html) · [Datos de tile](https://docs.godotengine.org/en/stable/classes/class_tiledata.html)

## Pruebas de balance

- **Menos tiempo muerto.** Prueba intervalos de aparición un 10% más cortos en las dos últimas olas de los niveles 3–5. Conserva la primera ola para enseñar el nivel y mide si la presión sube antes de tocar la economía.
- **Composiciones que exijan cambiar de plan.** Pon un Terra delante de un grupo compacto y separa a los corredores Electricitas unos segundos después. En niveles con atajos, intercala Aqua para poner a prueba un bloqueo Terra y reserva un grupo pequeño para el final del aviso climático.
- **Desafíos que cambien decisiones.** Prueba una variante de tormenta con un aviso que obligue a invertir en Electricitas, o una ola con menos agua de recompensa a cambio de un objetivo opcional de supervivencia. Anuncia siempre la condición antes de empezar.
- **Una sola variable por prueba.** Registra vida de la Madre al terminar cada ola, gotas sobrantes, mejoras compradas, bajas por ruta y reintentos. Si los jugadores siguen llegando al final con mucha reserva, prueba bajar de 2 a 1 gota la recompensa de una ola tardía por nivel antes de subir la vida de todos los enemigos.
