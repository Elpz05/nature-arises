# Pozo y vista previa de plantado

El pozo central muestra su reserva de **0 a 5 gotas**. La generación arranca al pulsar «Iniciar ronda». Haz clic en el pozo o confirma sobre su casilla con el cursor de teclado o mando para recoger toda la reserva. El agua solo se puede gastar después de recogerla.

| Clima | Producción base del pozo |
| --- | ---: |
| Despejado, ventisca, derrumbe y radiación | 0.20 gotas/s |
| Lluvia | 0.30 gotas/s |
| Tormenta | 0.40 gotas/s |
| Volcán | 0.15 gotas/s |

Aqua aporta 0.10, 0.20 o 0.30 gotas/s según su tamaño. Una vez lleno, el pozo deja de acumular. Entre rondas conserva la reserva y la fracción de la siguiente gota. La reserva sigue disponible para recoger durante la preparación. La pausa congela la generación y bloquea la interacción. Recargar el nivel reinicia el tablero y el pozo.

En `scripts/nivel/nivel_base.gd`, `celda_pozo` usa (14,8) por defecto. Debe ser una casilla libre y seca. `Pozo.acumular()` recibe el tiempo de ronda y la tasa total. `agua_recogida` acredita la reserva al nivel y `reserva_cambiada` actualiza el HUD. Las acciones configuradas en InputMap se comprueban antes de plantar, mejorar o lanzar un ataque.

La vista previa se centra en la casilla seleccionada y toma el alcance y desplazamiento de la escena del árbol antes de añadirla al tablero. El color verde indica una colocación válida y asequible. El rojo indica una restricción de terreno, ocupación o coste. La vista previa se oculta sobre el HUD.

`tests/test_well_economy.gd` cubre inicio de ronda, producción fraccionaria, capacidad, recogida por clic y arrastre, prioridad frente al plantado y los ataques, pausa y resultado. `tests/test_input_map.gd` comprueba la recogida con controles reasignados y cursor de tablero.
