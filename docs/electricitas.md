# Electricitas

Árbol disponible en el índice 4 de semillas, conectado en los dos niveles y habilitado en el laboratorio `res://demo/mecanicas_lluvia.tscn`. Ejecutar esa escena con F6 y seleccionar Electricitas con su botón o F5. El laboratorio habilita seis plantas sin escribir desbloqueos de campaña.

| Tamaño | Costo | Vida | Alcance | Total máximo encadenado |
| --- | --- | --- | --- | --- |
| Pequeño | 2 | 200 | 2.5 casillas | 3 bestias |
| Mediano | 4 | 400 | 3 casillas | 5 bestias |
| Grande | 8 | 600 | 3.5 casillas | 7 bestias |

Los costos superiores corresponden a las mejoras, igual que en el resto de árboles. Cadencia base: tres descargas por segundo. Cada víctima recibe 10 de daño, sin reducción por rebote. Solo se planta en pasto libre y la pala no reembolsa agua. Usa una silueta provisional amarilla en forma de rayo. La inspección muestra el máximo de objetivos y la distancia de salto.

## Cadena

El primer objetivo sigue la prioridad común: la bestia con menor distancia restante hasta el Árbol Madre dentro del Area2D de la torre. La descarga elige después la bestia más cercana a la víctima anterior, sin repetir víctimas. Los máximos 3/5/7 incluyen al primer objetivo.

**Decisión provisional:** el documento no define distancia entre rebotes. Se limita cada salto a dos casillas y se usa únicamente la lista de bestias detectadas por esta torre al disparar. La cadena termina al alcanzar su máximo o no encontrar otra víctima válida a esa distancia. Este valor queda en `radio_salto` del script de descarga para ajustarlo durante el pulido de gameplay.

El daño es instantáneo al resolver la descarga. Una línea quebrada de luz permanece 0.12 s para mostrar las conexiones. Los puntos se capturan antes de causar daño, por lo que la muerte de una víctima no impide el dibujo. Toda la cadena se decide antes de golpear: copias recién invocadas y renacimientos no añaden impactos a esa misma descarga. Se excluyen referencias liberadas, bestias muertas y cuerpos o seguidores pendientes de eliminación.

## Elementos y clima

- Contra Electricitas: -50% (5 de daño en despejado).
- Contra Aqua: +10% (11 de daño en despejado).
- Lluvia: daño +25%, cadencia x0.75 (2.25 descargas/s).
- Tormenta: daño +35%, cadencia x0.5 (1.5 descargas/s).

Los modificadores de elemento y entorno se suman. Por ejemplo, contra Aqua bajo tormenta causa 14.5 por impacto; contra Electricitas bajo lluvia, 7.5. Se mantiene el soporte de vida fraccionaria de Glacies. El ataque no añade congelación, aturdimiento ni otros estados.

La [bestia Electricitas](bestias.md) ya existe con su resistencia y aura. La inmunidad a rayos ya está integrada en [los climas](climas.md).

## Validación

`tests/test_electricitas.gd` cubre selección y desbloqueos, vista previa, plantado, costos, mejoras, vida, alcance y cadencia; disparo real por Area2D; prioridad inicial, límites 3/5/7, rebotes a los vecinos más cercanos, exclusión de objetivos fuera de la detección y cortes por distancia; referencias duplicadas o inválidas, daño único, renacimiento, duración de la línea, modificadores y pala.

Las doce suites informaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que causa salida 1 aun cuando pasan las aserciones. APPDATA y LOCALAPPDATA se aislaron en `.godot/test_environment`.
