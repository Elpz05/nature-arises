# Validación de jugabilidad de la campaña

`tests/simulate_campaign.gd` ejecuta los niveles con las escenas, física, proyectiles, temporizadores, auras, recursos y peligros reales. Solo utiliza los árboles y ataques que corresponden a cada etapa. Compra desde la selección del HUD y paga tanto el plantado como las mejoras. Recoge el pozo y arranca la siguiente ronda sin esperar a acumular agua entre rondas. No cambia estadísticas, no elimina bestias artificialmente y no escribe partidas.

El controlador toma decisiones cada medio segundo de juego. Prioriza la bestia con menor distancia restante hasta la meta, descarta los ataques inmunes y deja terminar el efecto elemental anterior antes de sustituirlo. Esto evita obtener victorias a base de cancelar estados continuamente.

## Estrategias reproducibles

| Nivel | Defensa usada |
| --- | --- |
| 1 | Natura cerca de varios tramos; compra antes de mejorar. |
| 2 | Aqua en la casilla inundada (7,4), seguido de Natura junto al camino. |
| 3 | Terra en el camino y Natura/Flamma junto a la primera columna vertical. |
| 4 | Electricitas y Natura alternados; reposición de bajas por rayos. |
| 5 | Flamma y Electricitas; reposición de bajas por erupción. |
| 6 | Terra, Natura, Flamma y Glacies en la primera sección vertical. |
| 7 | Terra en la cabecera de las columnas con atacantes detrás; reposición de barreras. |
| 8 | Venenum en dos filas con alcance sobre varios tramos, aprovechando su inmunidad a radiación. |

Las estrategias están fijadas por nivel: no tienen acceso a eventos futuros, no teletransportan defensas ni conceden recursos. No intentan demostrar que todas las combinaciones sean viables.

## Resultados observados

Godot 4.7.2, campaña completa con semilla base `20261103`: ocho victorias, todas con 20/20 HP. Una pasada adicional de los niveles 3–8 con base `20261102` también terminó con seis victorias y 20/20 HP.

| Nivel | Tiempo simulado, base 20261103 | Base 20261102 | Eventos en la pasada completa |
| --- | ---: | ---: | --- |
| 1 | 91.5 s | No ejecutado | Sin peligros periódicos |
| 2 | 101.7 s | No ejecutado | Lluvia pasiva |
| 3 | 90.5 s | 92.9 s | Sin peligros periódicos |
| 4 | 97.6 s | 105.2 s | 18 rayos |
| 5 | 82.8 s | 83.6 s | 16 emisiones de géiser y 3 erupciones |
| 6 | 132.0 s | 132.0 s | 13 ventiscas y 6 pulsos de calor |
| 7 | 112.1 s | 108.4 s | 7 derrumbes |
| 8 | 311.0 s | 304.9 s | 310 pulsos de radiación |

El control sin defensas del nivel 8, base `20261102`, perdió realmente en la segunda ronda: 0 HP a los 359.3 s, sin compras ni ataques. La simulación informó PASS porque esa derrota era su resultado esperado. No se alteraron recetas, estadísticas ni ingresos para conseguir los resultados.

La duración del nivel final destaca: aproximadamente cinco minutos frente a 83–132 s en los niveles anteriores. Es un candidato a revisar jugando, especialmente el precio y la cadencia de Venenum frente a enemigos de su propio elemento. No se reduce su dificultad basándose únicamente en un controlador automático.

## Ejecución

Ejemplo en PowerShell desde la raíz del proyecto, usando el Godot instalado en este equipo:

```powershell
$env:APPDATA = Join-Path $PWD '.godot\test_environment\roaming'
$env:LOCALAPPDATA = Join-Path $PWD '.godot\test_environment\local'
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/simulate_campaign.gd -- --seed=20261103
```

`--from=2 --to=7` limita la ejecución a los niveles 3–8 (índices desde cero). La semilla de cada nivel es la base más su índice. `--without-defense` omite árboles y ataques y exige una derrota real, no un tiempo agotado: sirve de control negativo.

Se acelera el reloj x8 con 240 pasos físicos por segundo real, equivalente a un paso nominal de 1/30 s de juego. Las duraciones reportadas son tiempo simulado, no tiempo de ejecución. El resultado JSON queda en `.godot/campaign_combat_<semilla>.json`; el control sin defensa usa el sufijo `_without_defense`. Para resultados estables deben mantenerse versión del motor y configuración; las semillas no prometen determinismo entre plataformas.

## Alcance

Esta prueba detecta partidas atascadas, falta de recursos para una estrategia concreta, herramientas no disponibles y errores de integración. Una victoria con 20/20 HP solo demuestra que existe una estrategia que funciona con este controlador. No demuestra una dificultad apropiada para una persona, claridad visual ni variedad estratégica.

La siguiente prueba manual debe observar si el jugador entiende el peligro antes de perder una defensa, si puede reponerla con sus ingresos y si dispone de tiempo para reaccionar sin recoger el pozo ni lanzar ataques con precisión automática. Conviene registrar nivel/ronda, estrategia, vida restante y qué decisión causó la derrota antes de ajustar recetas o intervalos.

Se conservan las estadísticas de la especificación y la vida provisional de 20 HP del Árbol Madre. El entorno restringido sigue emitiendo el error conocido del almacén de certificados al iniciar Godot; el criterio de la prueba son los resultados por nivel y el mensaje final, revisando también cualquier error de script.
