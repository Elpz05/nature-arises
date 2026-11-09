# Climas y peligros ambientales

El gestor compartido `scripts/nivel/clima.gd` aplica los eventos en tiempo de juego. La radiación solo avanza durante las rondas. Pausa, victoria y derrota detienen sus relojes. Los eventos que coinciden o se atraviesan en un fotograma largo se resuelven en orden temporal. El bono de géiser expira entre eventos.

Se configura al iniciar un nivel con `clima`, `intensidad_tormenta`, `celdas_inundadas` y `celdas_geiser`. No se cambian las estadísticas de una partida a mitad de nivel: el selector del laboratorio reinicia la prueba elegida. La [campaña](campana.md) ya distribuye los climas en ocho niveles con desbloqueos progresivos.

## Probar

Abrir `res://demo/mecanicas_lluvia.tscn` y ejecutar con F6. Las flechas **< / >** junto al botón de ronda reinician con el clima anterior o siguiente. Hay nueve variantes: despejado, lluvia, tres intensidades de tormenta, volcán, ventisca, derrumbe y radiación. Todas habilitan los siete árboles y hechizos. La victoria del laboratorio no guarda progreso de campaña.

También se pueden ejecutar directamente las escenas `mecanicas_volcan.tscn`, `mecanicas_ventisca.tscn`, `mecanicas_derrumbe.tscn`, `mecanicas_radiacion.tscn`, `mecanicas_tormenta.tscn`, `mecanicas_tormenta_pequena.tscn` y `mecanicas_tormenta_grande.tscn`.

El HUD mantiene visible clima y producción de agua, y el panel de combate muestra el último evento. La inspección de árboles incluye niveles de congelación/protección, tiempo restante del bono de géiser y rocas absorbidas por Terra. Se usan tintes y efectos de formas provisionales; las animaciones y el balance quedan para el pulido.

## Modificadores

| Clima | Árboles | Bestias | Agua base |
| --- | --- | --- | --- |
| Despejado | Sin cambios | Sin cambios | 0.20/s |
| Lluvia | Cadencia x0.75, Flamma daño -25%, Electricitas daño +25% | Flamma vida x0.5 | 0.30/s |
| Tormenta | Cadencia x0.5, Flamma daño -50%, Electricitas daño +35% | Flamma vida x0.5 | 0.40/s |
| Volcán | Flamma daño +20%, Glacies daño -20%; los demás elementos cadencia x1.1 | Glacies vida x0.5 | 0.15/s |
| Ventisca | Glacies cadencia x1.2, Flamma daño +10% | Glacies velocidad x1.2, Flamma vida x1.2 | 0.20/s |
| Radiación | Cadencia x1.05 excepto Venenum | Sin cambios | 0.20/s |
| Derrumbe | Sin modificadores base | Sin modificadores base | 0.20/s |

La producción de Aqua se suma al valor base cuando es plantable. Los modificadores de daño de elemento y entorno se suman: Flamma contra Flamma bajo volcán causa `40 × (1 - .25 + .20) = 38`. Cadencia, toxicidad y bonos temporales se multiplican. El renacimiento de Flamma usa su vida máxima ya ajustada al clima.

## Tormenta eléctrica

Los tamaños se interpretan como **intensidad de tormenta**, configurable en el inspector: pequeña = 10% cada 5 s; mediana = 50% cada 3 s; grande = 90% cada 1 s. En cada evento exitoso se elige una casilla uniforme del área jugable. Puede caer en una casilla vacía; no se garantiza que golpee una unidad.

El rayo destruye instantáneamente los árboles alcanzados, sin reembolso. Árboles y bestias Electricitas son inmunes. La especificación menciona inmunidad de bestias pero solo describe explícitamente el daño a árboles: se interpreta que las demás bestias de la casilla también son destruidas. Estas muertes ambientales evitan armadura, invocación de Natura y renacimiento de Flamma.

## Volcán

Los géiseres ocupan casillas de pasto predefinidas que se reservan para no plantar encima. Se validan contra límites, caminos, obstáculos, pozo y Árbol Madre. En el laboratorio están en (6,5) y (17,8).

Cada 10 s, cada géiser aplica 25 de daño y un bono de cadencia x1.25 durante 7 s a sus ocho casillas adyacentes. Flamma es inmune a ambos efectos, incluido el bono. Dos géiseres pueden sumar daño, pero el bono se renueva sin multiplicarse. Cada 25 s una erupción elige un árbol vivo uniforme; si el elegido es Flamma, resiste y no se vuelve a sortear. Una erupción sin árboles solo se anuncia.

## Ventisca

Cada 10 s, todos los árboles salvo Flamma y Glacies pierden 25 HP y ganan un nivel de congelación, hasta 3. Al nivel 3 se pausa su temporizador y no disparan. Mejorar no borra los niveles. La producción pasiva y el bloqueo físico de unidades sin proyectiles conservan el comportamiento de la congelación por aura.

Cada 20 s hay un pulso de calor de los Flamma vivos en sus ocho casillas adyacentes: reduce un nivel de congelación y activa protección contra niveles posteriores mientras permanezca un Flamma vivo adyacente. Desde el primer pulso se actualiza esa cobertura al plantar o quitar árboles. La protección no evita los 25 HP del barrido. Flamma y Glacies sí son inmunes tanto al daño como a la congelación.

Si calor y barrido coinciden, se resuelve primero el calor. La protección climática de ocho casillas es distinta de la protección contra el aura de bestias Glacies, que sigue usando el alcance de ataque de Flamma.

## Derrumbe

Cada 15 s se elige uniformemente una columna y la roca cae de arriba hacia abajo. Destruye árboles y bestias de esa columna hasta encontrar el primer Terra vivo. Terra absorbe la caída y protege su casilla y todo lo que hay debajo. Sobrevive a las dos primeras sin perder HP por roca; se destruye en la tercera, que también queda bloqueada. La siguiente caída ya puede continuar. Mejorar no reinicia el contador.

Las bestias destruidas por roca no usan armadura, copia ni renacimiento. El terreno no se convierte en un obstáculo permanente. El laboratorio de derrumbe usa un trazado vertical largo, con seis columnas de caminos y sin atajo Flamma.

## Campo radiactivo

Cada ocho segundos de ronda, un pulso inflige 6 HP de daño fijo. Un Aqua vivo reduce el daño a 3 HP en sus cuatro casillas vecinas ortogonales. Varias protecciones no se acumulan. Venenum conserva la inmunidad y las bestias Venenum tienen su vida normal. El reloj conserva el progreso parcial entre rondas y la preparación queda libre de pulsos.

## Alcance y validación

Los peligros afectan árboles defensivos plantados y, donde corresponde, bestias. El Árbol Madre y el pozo son entidades separadas y no participan en los sorteos ni en el daño de estos eventos. Las muertes de árboles usan la limpieza de casillas existente; quitar un bloqueador de un camino conserva la reserva de ese camino.

`tests/test_climas.gd` comprueba intensidades, intervalos, probabilidades, inmunidades, daño, pausa, resultados y el selector. `tests/test_sprint_finale.gd` comprueba el pulso del campo radiactivo y la protección de Aqua.

Las dieciséis suites reportaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que provoca salida 1 aunque pasen las aserciones. APPDATA y LOCALAPPDATA se aislaron en `.godot/test_environment` para no usar partidas reales.
