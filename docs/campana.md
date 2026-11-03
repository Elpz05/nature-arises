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
| 8 | El último brote | Radiación | 18 | Campaña completada |

Una partida nueva comienza con Natura y su ataque. Cada nivel tiene cinco rondas, con un total de 40 en la campaña. El HUD presenta el nombre, posición en la campaña y un consejo que explica el sistema principal del nivel. Las victorias anuncian los desbloqueos de plantas y ataques.

El segundo nivel tiene cinco casillas inundadas (6..10,4), de modo que el árbol Aqua ya es usable al desbloquearse. La muralla introduce bestias Terra y caminos verticales. La tormenta incorpora bestias Electricitas cuando el jugador ya dispone de su árbol. El volcán añade bestias Glacies y dos géiseres. Ventisca introduce bestias Venenum con todos los árboles disponibles. El desfiladero emplea el mapa de seis columnas verticales para defenderse de rocas con Terra. Radiación culmina con enemigos mixtos y grandes, y permite usar Venenum como defensa inmune al entorno.

La selección de mapas, recetas, economía, consejos y recompensas vive en `scripts/nivel/campana.gd`. `nivel_campana.gd` configura los seis niveles nuevos reutilizando las escenas y sistemas compartidos; no importa las escenas de laboratorio ni su selector. El laboratorio sigue habilitando todo y no guarda progreso.

## Primera pasada de balance

Se mantienen las estadísticas de la especificación para árboles, bestias y ataques. Se redujo la carga del tutorial Natura: sus rondas finales pasan de 4 medianos + 2 grandes y 6 grandes a 3 medianos + 1 grande y 2 medianos + 2 grandes. Los intervalos iniciales son más graduales y los niveles avanzados empiezan con más agua para permitir sus defensas específicas.

El nivel de lluvia mezcla Natura, Flamma y Aqua progresivamente. Las unidades grandes y las auras más peligrosas aparecen después de que sus herramientas de respuesta estén desbloqueadas. El daño al llegar al Árbol Madre y sus 20 HP conservan el balance provisional documentado en las mecánicas.

`tests/simulate_campaign_opening.gd` realiza una pasada de combate real de los dos primeros niveles con semilla fija: compra y mejora Natura con agua legítima, recoge el pozo y usa los ataques disponibles. No cambia estadísticas, no elimina enemigos artificialmente y no guarda partidas. Resultado observado: victorias con 20/20 HP en unos **96 y 103.5 segundos simulados**, respectivamente.

Esto confirma que la apertura es superable con una estrategia sencilla; **no equivale a balance humano de toda la campaña**. La [validación de jugabilidad](balance_campana.md) amplía ahora la simulación a los ocho niveles con estrategias adaptadas al clima, compras legítimas y ataques desbloqueados. Los niveles avanzados también se superan en combate real; todavía necesitan partidas humanas para ajustar densidad, economía, tiempos de peligros y variedad de estrategias.

## Partidas y migración

El formato de guardado pasa a versión 2. Los archivos de versión 1, o sin versión, solo podían representar dos niveles. Una partida antigua completada conserva esos dos niveles y se reanuda en el tercero: `nivel_actual = 2`, `niveles_completados = [0,1]`, `campana_completada = false`. No se marca como completado el nuevo contenido ni se reinicia el progreso existente.

La migración recupera las recompensas necesarias para el siguiente nivel, conserva desbloqueos ya poseídos y campos adicionales, y es idempotente. Una partida v2 completada sigue finalizada; volver a superar niveles previos no reduce el avance. Los desbloqueos se derivan de los niveles superados y el catálogo de recompensas, por lo que también se recuperan listas ausentes.

Leer una partida antigua solo normaliza en memoria. Al guardarla posteriormente se utiliza la protección existente: copia `.bak` del original si necesita reparación/migración y escritura temporal con sustitución segura. No se modificaron partidas reales durante las pruebas. El menú muestra el nuevo total de ocho niveles y las partidas antiguas finalizadas ofrecen continuar con el nivel 3/8.

Ejecutar un nivel directamente con F6 y sin slot seleccionado habilita las herramientas que corresponderían a su posición, sin escribir un guardado. Desde el menú, las herramientas dependen del progreso real de la partida.

## Validación

`tests/test_campaign_progression.gd` verifica la migración antigua/nueva, las ocho escenas, los perfiles de herramientas reales del HUD antes de cada nivel, los bloqueos, clima, agua inicial, objetivos, recetas, las 40 rondas y la victoria final. Comprueba los desbloqueos y guardados con un controlador en memoria. Las pruebas de seguridad conservan sus fixtures privados para archivos corruptos, respaldos, escrituras fallidas y tamaños máximos.

Las diecisiete suites reportaron PASS con Godot 4.7.2, además de la simulación de apertura. Persiste el error del almacén de certificados del entorno al iniciar Godot, que provoca salida 1 aunque pasen las aserciones. APPDATA y LOCALAPPDATA se aislaron en `.godot/test_environment`.
