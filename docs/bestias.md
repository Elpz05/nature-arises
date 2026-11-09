# Bestias: siete elementos y tres tamaños

Las siete familias se asignan en ambos niveles en el orden `natura, flamma, aqua, terra, electricitas, glacies, venenum`, sin cambiar los índices anteriores. Los cuatro tipos nuevos tienen escenas heredadas, colores provisionales y nombres/habilidades visibles sobre la barra de vida. Sus tamaños usan la escala existente del cuerpo y su colisión.

| Bestia | Vida pequeño / mediano / grande | Velocidad (casillas/s) | Daño de contacto |
| --- | --- | --- | --- |
| Natura | 200 / 500 / 1000 | 0.4 | 50 |
| Flamma | 150 / 450 / 800 | 0.3 | 100 |
| Aqua | 200 / 500 / 1000 | 0.5 | 0 |
| Terra | 500 / 900 / 1500 | 0.2 | 100 |
| Electricitas | 300 / 500 / 1000 | 0.6 | 50 |
| Glacies | 350 / 550 / 1050 | 0.3 | 75 |
| Venenum | 300 / 600 / 900 | 0.6 | 150 |

Flamma usa su atajo cuando el mapa lo incluye. Electricitas también tiene una rama propia en el campo radiactivo. Ventus, vida fraccionaria, congelación, veneno, contacto con Aqua y bloqueo/empuje de Terra se aplican en todas las rutas. Se conservan la invocación al morir de Natura (30%), el único renacimiento de Flamma y el paso de Aqua a través de Terra y Aqua.

**Daño al Árbol Madre:** el contacto sigue separado de la llegada a meta. Para los cuatro tipos nuevos se usan provisionalmente 2/3/5 de daño al llegar, con el mismo patrón de Natura y los 20 HP actuales del Árbol Madre. No se modificaron los valores de llegada anteriores de Natura, Flamma o Aqua. El documento no fija vida inicial de la base ni daño separado de llegada; el balance permanece pendiente.

## Terra

Cada impacto positivo tiene una probabilidad del 10% de anular el daño por completo. Proyectiles y ataques elementales usan esa tirada; el daño periódico de veneno no es un impacto y no vuelve a tirar por cada actualización. El bloqueo anula daño, sin conceder inmunidad a los estados aplicados por el ataque. El resultado aleatorio puede sustituirse en pruebas mediante `_tirada_defensa()`.

## Auras

Se evalúan en la actualización física del nivel y solo afectan a los árboles plantados de ese tablero. «Adyacente» corresponde a las ocho casillas vecinas, incluyendo diagonales y excluyendo la casilla propia. Los efectos pasivos siguen activos mientras la bestia está viva, incluso si está congelada o detenida. Bestias muertas, liberadas o pendientes de eliminación no generan aura. Al salir o morir la fuente, el estado se retira en la siguiente actualización de física. Pausa y resultados detienen la actualización.

- **Electricitas:** cada fuente adyacente causa 1 HP/s. Varias fuentes suman daño. Se conservan fracciones de exposición por árbol y se descuentan HP enteros al completarse; ese residuo desaparece al morir o retirar el árbol. Salir del aura no causa daño adicional. Una muerte por aura libera su casilla mediante la señal existente.
- **Glacies:** congela inmediatamente los disparos del árbol y pausa su temporizador, conservando el tiempo restante. Glacies es inmune; cualquier árbol dentro del alcance circular actual de un Flamma vivo está protegido. Mejorar, plantar, retirar o destruir Flamma actualiza la cobertura. Flamma protege su propia casilla. La congelación de aura no altera la producción pasiva de Aqua ni el bloqueo físico/empuje de Terra, que no son ataques de proyectil. Las balas ya disparadas continúan.
- **Venenum:** reduce la cadencia de disparo un 30% y cada intento de disparo tiene un 30% de probabilidad de desvanecerse sin crear proyectil. Se decide al disparar, por lo que tampoco se crea una cadena eléctrica o un carámbano fallido. Varias auras no multiplican ni el porcentaje de fallo ni la penalización. La reducción de cadencia se combina multiplicativamente con la de clima. Al aplicar o retirar el aura se cambia el intervalo de los siguientes disparos y se conserva la cuenta regresiva actual. Los ataques ya en vuelo no cambian.

La inspección muestra congelación y toxicidad, y la cadencia presentada refleja ambos estados. El sprite se tiñe temporalmente de azul o verde, sin cambiar su silueta ni tamaño. Si coinciden ambos efectos, la congelación pausa los disparos y la toxicidad permanece lista para cuando se descongele.

## Laboratorio y campaña

Abrir `res://demo/mecanicas_lluvia.tscn` y ejecutar con F6. Siguen habilitados los siete árboles. Se añade una bestia pequeña de cada tipo nuevo en la ronda 1, una mediana en la ronda 3 y una grande en la ronda 5. Se conserva la pareja Aqua de la ronda 1. La vista de entrantes incluye las siete familias y la victoria del laboratorio no escribe progreso.

La [campaña de ocho niveles](campana.md) ya introduce los siete tipos de forma progresiva. Esta entrega completa las unidades y sus habilidades base; los hechizos completos se describen ahora en [ataques_elementales.md](ataques_elementales.md); los [eventos climáticos avanzados](climas.md) ya están implementados y el balance final sigue pendiente.

## Validación

`tests/test_bestias.gd` comprueba en ambos niveles vida, velocidad, contacto, escalas de tamaño y rutas; umbrales deterministas del bloqueo de Terra y fallo de disparo; daño eléctrico fraccionario, múltiples fuentes, salida de las auras, diagonales, inmunidad Glacies, protección y mejora de Flamma, recuperación de cadencia, muerte de fuentes y árboles, pausa y resultados. También comprueba daño y congelación por auras a través de ticks físicos reales.

Las catorce suites reportaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que provoca salida 1 aunque pasen las aserciones. APPDATA y LOCALAPPDATA se aislaron en `.godot/test_environment` para no usar partidas reales.
