# Terra: bloqueo y contacto

Terra ocupa el índice 3, conserva el orden de plantas de los guardados y está conectado en ambos niveles. El laboratorio `res://demo/mecanicas_lluvia.tscn` lo habilita con F6 sin modificar los desbloqueos de campaña. F4 selecciona Terra con los controles predeterminados; también funciona clic-clic y arrastre.

| Tamaño | Costo | Vida | Empuje |
| --- | --- | --- | --- |
| Pequeño | 3 | 1000 | 0.5 casillas |
| Mediano | 6 | 2000 | 0.7 casillas |
| Grande | 9 | 3000 | 1 casilla |

Los costos mediano y grande se cobran al mejorar, con el mismo comportamiento de mejoras del resto de plantas. No dispara ni activa su temporizador de disparo. Tiene una silueta provisional marrón y una barra de vida; la inspección muestra vida y empuje.

## Terreno y colisión

En campaña, Terra puede plantarse en parcelas secas y en puestos de bloqueo marcados con barras sobre el camino o un atajo. En el laboratorio puede ocupar cualquier terreno seco libre. Solo bloquea las rutas que pasan por el centro de su casilla. Al morir o retirarlo, se libera el puesto para otro Terra. La pala no devuelve agua.

El avance se resuelve en la actualización física de cada bestia sobre su propia Path2D. Se comprueba el segmento completo desde su progreso actual hasta su siguiente posición y se elige el primer Terra atravesado. El borde de contacto está media casilla antes del centro. Esto evita atravesarlo en un fotograma largo y funciona en tramos horizontales, verticales, giros y atajos. Los enemigos que ya pasaron la casilla no son arrastrados hacia atrás. Plantar sobre un enemigo aún dentro de la casilla sí lo bloquea.

Al contactar, Natura causa 50 de daño y Flamma 100. El árbol empuja hacia atrás sobre la misma ruta; nunca reduce el progreso por debajo de cero. La bestia vuelve a acercarse y continúa golpeando mientras Terra sobreviva. Cada bestia conserva su propio enfriamiento; varias pueden atacar el mismo árbol. Aqua atraviesa Terra sin detenerse, golpearlo ni recibir empuje. El daño al llegar al Árbol Madre conserva sus valores anteriores y está separado del contacto.

**Decisión de balance:** el documento no especifica cuándo se activa el empuje ni la frecuencia del contacto. Por ahora el empuje acompaña cada golpe, con un máximo de un golpe por segundo por bestia. El tiempo necesario para volver a recorrer la distancia empujada puede espaciar más los golpes. No se aplican golpes acumulados durante un fotograma largo. Al morir Terra se libera su casilla inmediatamente; la bestia reanuda el avance en el siguiente paso de física. Pausa y resultados detienen tanto movimiento como contacto.

## Validación

`tests/test_terra.gd` verifica costos, tamaños, selección y desbloqueos, restricciones de terreno, ausencia de proyectiles, daño y enfriamiento, múltiples atacantes, paso de Aqua, empujes de los tres tamaños, fotogramas largos, muerte, pala, pausa, resultado y atajos. Incluye una comprobación con ticks físicos reales. Las diez suites de pruebas informaron PASS con Godot 4.7.2; persiste el error de certificados del entorno que causa salida 1 incluso con aserciones exitosas.
