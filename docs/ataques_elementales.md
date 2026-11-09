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
| Venenum | 100 | 2.5 casillas | 2.5 | Vulnerabilidad +1 por proyectil; ralentiza 3 víctimas al azar |

## Inmunidades y cancelación

Natura es inútil contra Flamma y Venenum; Flamma contra Flamma y Aqua. Cada uno de los demás es inútil contra su propio elemento. Una inmunidad impide tanto el daño como el estado y no limpia efectos anteriores. Flamma duplica el daño directo contra Glacies, Aqua contra Flamma y Glacies contra Flamma/Aqua. El daño periódico de quemadura es siempre 10 HP/s, sin duplicarse.

Solo hay un paquete de **hechizo del jugador** activo por bestia. Un nuevo hechizo eficaz sustituye inmediatamente el anterior, incluyendo su control de movimiento, quemadura, confusión o vulnerabilidad. Repetirlo renueva su duración sin apilar efectos. No se revierten los puntos de vida ya perdidos ni una decisión de ruta ya realizada. La sustitución no elimina veneno, ralentización o congelación procedentes de árboles; esos efectos tienen sus propios temporizadores. Los proyectiles de Flamma descongelan también el estado Glacies del jugador, sin borrar otros hechizos ni la inmovilidad de renacimiento de la bestia Flamma.

El bloqueo de Terra se aplica al daño directo de un hechizo como a cualquier impacto; su inmunidad al hechizo Terra prevalece. La quemadura es daño periódico y no realiza una tirada de armadura por actualización. Los estados siguen la misma regla de los proyectiles: el bloqueo de daño no da inmunidad al estado.

## Confusión, movimiento y decisiones provisionales

La especificación no indica cuánto duran Aqua, el mareo de Terra o la vulnerabilidad/ralentización de Venenum. Se usan provisionalmente **6 s para Aqua, 3 s para Terra y 6 s para Venenum**. La ralentización de Venenum es del **25%**. Estos valores están centralizados en `efecto_elemental.gd` para el posterior balance.

Aqua devuelve a la ruta normal a una bestia que todavía está antes de la bifurcación. En un tramo exclusivo, puede salir por un enlace intermedio declarado si lo alcanza mientras siga confundida. Cada atajo se reincorpora al camino principal por su salida final. Al cambiar de ruta se conserva la distancia que faltaba por avanzar y se respetan las barreras Terra anteriores al enlace. La animación de natación es una oscilación breve del sprite que no interrumpe el avance ni el renacimiento.

Terra comienza cada ciclo con la mitad detenida y después permite movimiento durante la otra mitad. Electricitas invierte el avance sobre la misma ruta y limita el progreso inferior a cero. Cuando un fotograma abarca la expiración de un efecto, la parte restante transcurre con movimiento normal. La congelación de árboles y el renacimiento conservan sus bloqueos independientes; la marcha inversa no permite golpear una barrera mientras se retrocede.

## Venenum y selección de víctimas

Todas las víctimas no inmunes dentro del área reciben el daño directo y la marca de vulnerabilidad. Se seleccionan hasta tres víctimas distintas al azar para ralentizar, excluyendo Venenum y Natura pequeño, que se elimina instantáneamente. Un objetivo que muere por el daño directo no conserva efectos. La muerte de Natura mantiene su capacidad de invocar una copia; esa nueva copia no recibe otro golpe del mismo lanzamiento, porque las víctimas se capturan antes del daño.

La marca añade exactamente 1 al daño recibido por cada proyectil de árbol, incluyendo cada víctima alcanzada por una cadena o carámbano. No modifica hechizos ni daño periódico y no atraviesa la inmunidad de Aqua a proyectiles de Flamma. Otro hechizo eficaz o la expiración retiran el bono. La ralentización no se multiplica con otras: se utiliza la más fuerte que siga activa.

## Cargas y recarga

Cada lanzamiento consume una carga completa, aunque no haya víctimas en el área. Se recupera **una carga cada 3 s**, hasta el máximo, con un contador independiente por habilidad. Usar otra carga no reinicia el contador que ya está en marcha. Un fotograma largo puede recuperar varias cargas, sin superar el máximo. Se rechazan índices inválidos, habilidades bloqueadas y lanzamientos sin una carga completa. Pausa y resultados detienen la recarga y los efectos.

Se conserva literalmente la capacidad **2.5 de Venenum**. Empieza con 2.5, puede lanzar dos veces y quedan 0.5; no puede lanzar hasta recuperar una carga. La siguiente recarga deja 1.5 y la posterior 2.5. Esta interpretación de la media carga queda explícita para ajustar el diseño después, sin redondear silenciosamente el documento.

La barra muestra los valores fraccionarios y una línea de progreso cuando hay recarga pendiente. Los tooltips describen efecto, inmunidades, daño, radio y tiempo para la próxima carga. Al lanzar aparece un círculo breve del color del elemento; cada bestia muestra su estado y un contorno del mismo color mientras dure.

## Validación

`tests/test_ataques_elementales.gd` cubre todas las inmunidades y ventajas, daño directo/periódico, cancelación y efectos independientes de árboles; tiempos de inmovilización, mareo, marcha inversa y recuperación con fotogramas largos; natación determinista, cambios de ruta sin teletransporte y barreras anteriores a enlaces; área, selección de tres víctimas, vulnerabilidad, muerte de Natura pequeño, capacidad fraccionaria, rechazo de lanzamientos, recarga gradual, pausa y resultados.

Las quince suites reportaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que provoca salida 1 aunque pasen las aserciones. Se aislaron APPDATA y LOCALAPPDATA en `.godot/test_environment`.
