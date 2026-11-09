# Ataques elementales del jugador

Los siete hechizos de la barra funcionan mediante clic-clic, arrastre o los controles configurados (1 a 7 por defecto). El laboratorio `res://demo/mecanicas_lluvia.tscn` los habilita junto con los siete árboles. La campaña conserva sus desbloqueos y partidas.

| Hechizo | Daño directo | Radio | Cargas máximas | Efecto |
| --- | --- | --- | --- | --- |
| Natura | 10 | 2.5 casillas | 2 | Inmoviliza 0.5 s |
| Flamma | 20 | 2.5 casillas | 3 | Quemadura de 10 HP/s durante 3 s |
| Aqua | 30 | 3 casillas | 2 | Confusión: ignora atajos, 50% de natación visual por 0.5 s |
| Terra | 50 | 2 casillas | 2 | Mareo: 0.5 s detenido, 0.5 s en movimiento por ciclo |
| Electricitas | 40 | 2.5 casillas | 2 | Marcha inversa durante 0.5 s |
| Glacies | 10 | 4 casillas | 3 | Congela 2 s |
| Venenum | 100 | 2.5 casillas | 2 | Vulnerabilidad +1 por proyectil; ralentiza 3 víctimas al azar |

## Inmunidades y coexistencia

Natura es inútil contra Flamma y Venenum; Flamma contra Flamma y Aqua. Cada uno de los demás es inútil contra su propio elemento. Una inmunidad impide tanto el daño como el estado y no limpia efectos anteriores. Flamma duplica el daño directo contra Glacies, Aqua contra Flamma y Glacies contra Flamma/Aqua. El daño periódico de quemadura es siempre 10 HP/s, sin duplicarse.

Cada bestia admite un efecto de **daño** (quemadura de Flamma o vulnerabilidad de Venenum) y uno de **movimiento** (Natura, Aqua, Terra, Electricitas o Glacies). Por ejemplo, Glacies congela a una bestia mientras Flamma sigue quemándola. Otro hechizo de la misma categoría sustituye ese efecto. Repetir el mismo hechizo renueva un solo temporizador. La ralentización de Venenum se mantiene con su vulnerabilidad y se combina usando la reducción más fuerte. Los estados procedentes de árboles tienen sus propios temporizadores. Un proyectil de Flamma descongela y conserva el efecto de daño que siga activo.

El bloqueo de Terra se aplica al daño directo de un hechizo como a cualquier impacto; su inmunidad al hechizo Terra prevalece. La quemadura es daño periódico y no realiza una tirada de armadura por actualización. Los estados siguen la misma regla de los proyectiles: el bloqueo de daño no da inmunidad al estado.

## Confusión, movimiento y decisiones provisionales

La especificación no indica cuánto duran Aqua, el mareo de Terra o la vulnerabilidad/ralentización de Venenum. Se usan provisionalmente **6 s para Aqua, 3 s para Terra y 6 s para Venenum**. La ralentización de Venenum es del **25%**. Estos valores están centralizados en `efecto_elemental.gd` para el posterior balance.

Aqua devuelve a la ruta normal a una bestia que todavía está antes de la bifurcación. En un tramo exclusivo, puede salir por un enlace intermedio declarado si lo alcanza mientras siga confundida. Cada atajo se reincorpora al camino principal por su salida final. Al cambiar de ruta se conserva la distancia que faltaba por avanzar y se respetan las barreras Terra anteriores al enlace. La animación de natación es una oscilación breve del sprite que no interrumpe el avance ni el renacimiento.

Terra comienza cada ciclo con la mitad detenida y después permite movimiento durante la otra mitad. Electricitas invierte el avance sobre la misma ruta y limita el progreso inferior a cero. Cuando un fotograma abarca la expiración de un efecto, la parte restante transcurre con movimiento normal. La congelación de árboles y el renacimiento conservan sus bloqueos independientes; la marcha inversa no permite golpear una barrera mientras se retrocede.

## Venenum y selección de víctimas

Todas las víctimas no inmunes dentro del área reciben el daño directo y la marca de vulnerabilidad. Se seleccionan hasta tres víctimas distintas al azar para ralentizar, excluyendo Venenum y Natura pequeño, que se elimina instantáneamente. Un Natura marcado como divisor genera una copia al caer. La copia queda fuera del mismo lanzamiento porque las víctimas se capturan antes del daño.

La marca añade exactamente 1 al daño recibido por cada proyectil de árbol, incluyendo cada víctima alcanzada por una cadena o carámbano. Se conserva al aplicar un hechizo de movimiento y se retira al expirar o al aplicar Flamma.

## Cargas y recarga

Cada lanzamiento consume una carga completa, aunque no haya víctimas en el área. Cada habilidad recupera una carga con su propio contador. **Glacies tarda 6 s**, **Venenum 10 s** y las demás **3 s**. Usar otra carga conserva la cuenta en marcha. Un fotograma largo puede recuperar varias cargas hasta el máximo. Pausa y resultados detienen la recarga y los efectos.

Venenum tiene **dos cargas enteras**. La barra muestra las cargas restantes y el progreso de la siguiente. Las bestias muestran ambos estados y sus colores cuando coinciden.

## Validación

`tests/test_ataques_elementales.gd` cubre inmunidades, coexistencia de daño y movimiento, renovación, deshielo, efectos de árboles, atajos, cargas enteras de Venenum y pausa.
