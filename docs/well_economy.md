# Pozo y vista previa de plantado

El pozo central muestra su reserva de **0 a 5 gotas**. La generación arranca al pulsar «Iniciar ronda». Haz clic en el pozo o confirma sobre su casilla con el cursor de teclado o mando para transferir la reserva al saldo.

| Clima | Producción base del pozo |
| --- | ---: |
| Despejado, ventisca, derrumbe y radiación | 0.085 gotas/s |
| Lluvia | 0.11 gotas/s |
| Tormenta | 0.14 gotas/s |
| Volcán | 0.07 gotas/s |

Completar una ronda intermedia entrega **2 gotas** directamente al saldo, más **3 extra** si se eligió su desafío. El pozo conserva su reserva para recogerla por separado. En un clima con tasa base de 0.085, el cambio traslada al premio el equivalente a 50 segundos de la reducción de producción.

Aqua aporta 0.06, 0.12 o 0.18 gotas/s según su tamaño. Una vez lleno, el pozo deja de acumular. Entre rondas conserva la reserva y la fracción de la siguiente gota. La reserva sigue disponible para recoger durante la preparación. La pausa congela la generación y bloquea la interacción. Recargar el nivel reinicia el tablero y el pozo.

Plantar Aqua cuesta 6 gotas. Las mejoras cuestan **4 y 6 gotas**, respectivamente. Cada mejora aporta 0.06 gotas/s más. Se amortizan en unos 67 y 100 segundos activos si se recoge el pozo antes de que se llene.

En `scripts/nivel/nivel_base.gd`, `celda_pozo` usa (14,8) por defecto. Debe ser una casilla libre y seca. `Pozo.acumular()` recibe el tiempo de ronda y la tasa total. `agua_recogida` acredita la reserva al nivel y `reserva_cambiada` actualiza el HUD. Las acciones configuradas en InputMap se comprueban antes de plantar, mejorar o lanzar un ataque.

En campaña, los cuadros de tierra seca admiten árboles terrestres, las barras marcan puestos de Terra sobre el camino y las casillas azules admiten Aqua. Los caminos ordinarios y el pasto sin marcar quedan fuera de las opciones de plantado. La vista previa usa la misma validación que la compra. El verde indica un lugar válido y asequible, y el rojo indica una restricción de terreno, ocupación o coste.

`tests/test_well_economy.gd` cubre inicio de ronda, producción fraccionaria, capacidad, recogida por clic y arrastre, prioridad frente al plantado y los ataques, pausa y resultado. `tests/test_input_map.gd` comprueba la recogida con controles reasignados y cursor de tablero.
