# Campaña de ocho niveles

La campaña principal ya integra los siete árboles, las siete bestias, los siete ataques y todos los climas. Se entra desde el menú de partidas habitual. Los niveles anteriores mantienen sus rutas y escenas; se añaden seis escenas nuevas y la victoria final solo aparece después del nivel 8.

## Progresión

| Nivel | Nombre | Clima | Agua inicial | Recompensa al completarlo |
| --- | --- | --- | --- | --- |
| 1 | Primeras raíces | Despejado | 3 | Árboles Flamma y Aqua; ataque Flamma |
| 2 | Agua y fuego | Lluvia | 3 | Árbol Terra; ataques Aqua y Terra |
| 3 | La muralla | Despejado | 8 | Árbol y ataque Electricitas |
| 4 | Cielo dividido | Tormenta mediana | 10 | Árbol y ataque Glacies |
| 5 | Corazón volcánico | Volcán | 12 | Árbol y ataque Venenum |
| 6 | El bosque helado | Ventisca | 14 | Acceso al desfiladero |
| 7 | El desfiladero | Derrumbe | 16 | Acceso al último nivel |
| 8 | El último brote | Radiación | 24 | Campaña completada |

Una partida nueva comienza con Natura y su ataque. Cada nivel tiene cinco rondas, con un total de 40 en la campaña. El HUD identifica el nivel y las victorias anuncian los desbloqueos de plantas y ataques.

## Guía de campo

La primera entrada a cada nivel de un archivo durante la sesión abre **Nivel actual** antes de la primera ronda. El informe explica las reglas del terreno y el clima, con una táctica para probar. Se puede volver a abrir con **Guía** en el HUD o **Guía de campo** en Pausa. Leerlo congela la partida. Al cerrar desde Pausa se vuelve a su menú.

La **Guía de campo** también está disponible en el menú principal. **Cómo jugar** explica la secuencia de plantado, combate y mejoras. **Bestias**, **Árboles** y **Poderes** tienen siete fichas cada uno, con habilidades, respuestas y cifras base. Las fichas toman estadísticas de las bestias y del HUD para mantener los valores actualizados.

El segundo nivel ofrece dos sitios para Aqua, uno sobre el camino en (7,4) y una poza lateral en (10,5). La muralla introduce bestias Terra, puestos de bloqueo y caminos verticales. La tormenta incorpora bestias Electricitas cuando el jugador ya dispone de su árbol. El volcán añade bestias Glacies y dos géiseres. Sus bordes naranjas marcan la zona del pulso y la cuenta muestra cuándo se activará. Ventisca introduce bestias Venenum con todos los árboles disponibles. El desfiladero emplea el mapa de seis columnas verticales para defenderse de rocas con Terra.

El último brote combina grupos numerosos, bestias blindadas, Aqua que atraviesan barreras y grandes de varios elementos. Natura ofrece cobertura barata al principio. Flamma daña grupos y protege a otros árboles del aura gélida. Aqua carga el pozo desde pozas fuera del camino y protege a sus vecinos de los pulsos. Terra bloquea los atajos de Flamma y Electricitas. Electricitas encadena a los grupos, Glacies frena a quienes atraviesan el bloqueo y Venenum cubre varios tramos con alcance e inmunidad. Los consejos del HUD cambian con la ronda.

La selección de mapas, recetas, economía, consejos y recompensas vive en `scripts/nivel/campana.gd`. `nivel_campana.gd` configura los seis niveles nuevos reutilizando las escenas y sistemas compartidos; no importa las escenas de laboratorio ni su selector. El laboratorio sigue habilitando todo y no guarda progreso.

## Preparación y formaciones

Antes de cada ronda, el HUD normal muestra la cantidad de bestias y hasta tres amenazas concretas. Los avisos incluyen atajos, auras, inmunidades y bestias grandes según la receta elegida.

Una receta de `ETAPAS.rondas` puede ser un diccionario de cantidades para una aparición mezclada o una lista de grupos para una aparición ordenada. Por ejemplo, `[{"terra:mediano": 2}, {"aqua:pequeno": 4}]` envía la vanguardia Terra antes del grupo Aqua. El volcán también envía Terra antes de Glacies y el final sigue una formación lenta con corredores Electricitas en su atajo.

La variante `natura:mediano:divisor` aparece por primera vez en la segunda ronda. El informe la anuncia y su rombo dorado indica que deja una copia al caer.

Cada nivel ofrece un **Desafío +3** antes de una de sus rondas intermedias. Se elige con el botón, **C** o el **gatillo izquierdo**, y la preparación indica los refuerzos exactos. La elección se fija al iniciar. Los refuerzos salen al final de la formación. Al superar la ronda se añaden tres gotas extra a las dos del premio normal. La elección vuelve a estar desactivada al pasar a la ronda siguiente.

Selecciona un árbol ofensivo y pulsa **Prioridad** junto a **Mejorar**. **R** y el **clic del stick derecho** también alternan entre **Cerca de meta** y **Mayor vida**. El primer modo compara la distancia restante en la ruta actual, incluido el atajo. El segundo compara la vida actual, con distancia restante como desempate. Cada árbol conserva su elección al mejorar.

## Primera pasada de balance

Se mantienen las estadísticas de la especificación para árboles, bestias y ataques. Se redujo la carga del tutorial Natura: sus rondas finales pasan de 4 medianos + 2 grandes y 6 grandes a 3 medianos + 1 grande y 2 medianos + 2 grandes. Los intervalos iniciales son más graduales y los niveles avanzados empiezan con más agua para permitir sus defensas específicas.

El nivel de lluvia mezcla Natura, Flamma y Aqua progresivamente. Las unidades grandes y las auras más peligrosas aparecen después de que sus herramientas de respuesta estén desbloqueadas. El daño al llegar al Árbol Madre y sus 20 HP conservan el balance provisional documentado en las mecánicas.

`tests/simulate_campaign_opening.gd` realiza una pasada de combate real de los dos primeros niveles con semilla fija. Compra y mejora Natura en seis parcelas, recoge el pozo y usa los ataques disponibles. Con los nuevos límites obtuvo victorias en **171.1 s con 17/20 HP** y **174.5 s con 20/20 HP**, respectivamente.

Esto confirma que la apertura es superable con una estrategia sencilla; **no equivale a balance humano de toda la campaña**. La [validación de jugabilidad](balance_campana.md) amplía ahora la simulación a los ocho niveles con estrategias adaptadas al clima, compras legítimas y ataques desbloqueados. Los niveles avanzados también se superan en combate real; todavía necesitan partidas humanas para ajustar densidad, economía, tiempos de peligros y variedad de estrategias.

## Partidas y migración

El formato de guardado pasa a versión 2. Los archivos de versión 1, o sin versión, solo podían representar dos niveles. Una partida antigua completada conserva esos dos niveles y se reanuda en el tercero: `nivel_actual = 2`, `niveles_completados = [0,1]`, `campana_completada = false`. No se marca como completado el nuevo contenido ni se reinicia el progreso existente.

La migración recupera las recompensas necesarias para el siguiente nivel, conserva desbloqueos ya poseídos y campos adicionales, y es idempotente. Una partida v2 completada sigue finalizada; volver a superar niveles previos no reduce el avance. Los desbloqueos se derivan de los niveles superados y el catálogo de recompensas, por lo que también se recuperan listas ausentes.

Leer una partida antigua solo normaliza en memoria. Al guardarla posteriormente se utiliza la protección existente: copia `.bak` del original si necesita reparación/migración y escritura temporal con sustitución segura. No se modificaron partidas reales durante las pruebas. El menú muestra el nuevo total de ocho niveles y las partidas antiguas finalizadas ofrecen continuar con el nivel 3/8.

Ejecutar un nivel directamente con F6 y sin slot seleccionado habilita las herramientas que corresponderían a su posición, sin escribir un guardado. Desde el menú, las herramientas dependen del progreso real de la partida.

## Validación

`tests/test_campaign_progression.gd` verifica la migración antigua/nueva, las ocho escenas, los perfiles de herramientas reales del HUD antes de cada nivel, los bloqueos, clima, agua inicial, objetivos, recetas, las 40 rondas y la victoria final. Comprueba los desbloqueos y guardados con un controlador en memoria. Las pruebas de seguridad conservan sus fixtures privados para archivos corruptos, respaldos, escrituras fallidas y tamaños máximos.

`tests/test_wave_tactics.gd` comprueba la preparación visible, el orden real de aparición, el cambio de prioridad mediante controles de ratón y mando y el pago único del desafío. Para probar un desafío con combate real se puede añadir `--challenge` a la simulación de campaña.
