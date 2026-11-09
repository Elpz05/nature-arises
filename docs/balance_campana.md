# Validación de jugabilidad de la campaña

`tests/simulate_campaign.gd` ejecuta los niveles con las escenas, física, proyectiles, temporizadores, auras, recursos y peligros reales. Solo utiliza los árboles y ataques que corresponden a cada etapa. Compra desde la selección del HUD y paga tanto el plantado como las mejoras. Recoge el pozo y arranca la siguiente ronda sin esperar a acumular agua entre rondas. No cambia estadísticas, no elimina bestias artificialmente y no escribe partidas.

El controlador toma decisiones cada medio segundo de juego. Prioriza la bestia con menor distancia restante hasta la meta, descarta los ataques inmunes y deja terminar el efecto elemental anterior antes de sustituirlo. Esto evita obtener victorias a base de cancelar estados continuamente.

## Estrategias reproducibles

| Nivel | Defensa usada |
| --- | --- |
| 1 | Natura en seis parcelas cerca de varios tramos, con mejoras tras completar la formación. |
| 2 | Natura y Flamma en la entrada, con Aqua en la poza lateral (10,5). |
| 3 | Terra en el camino y Natura/Flamma junto a la primera columna vertical. |
| 4 | Electricitas y Natura alternados; reposición de bajas por rayos. |
| 5 | Flamma y Electricitas; reposición de bajas por erupción. |
| 6 | Terra, Natura, Flamma y Glacies en la primera sección vertical. |
| 7 | Terra en la cabecera de las columnas con atacantes detrás; reposición de barreras. |
| 8 | Aqua en una poza, Terra en los atajos, y los cinco árboles de ataque con alcance sobre los tramos de entrada y salida. |

Las estrategias están fijadas por nivel: no tienen acceso a eventos futuros, no teletransportan defensas ni conceden recursos. No intentan demostrar que todas las combinaciones sean viables.

## Resultados observados

Godot 4.7.2, parcelas marcadas y economía reducida. Las pruebas ganaron las ocho etapas con una formación legal. Las bases de semilla fueron `20261108` para los niveles 1–4 y `20261109` para los niveles 5–8.

| Nivel | Sitios | Tiempo simulado | HP del Árbol Madre |
| --- | ---: | ---: | ---: |
| 1 | 10 | 175.0 s | 20 |
| 2 | 12 | 181.6 s | 20 |
| 3 | 13 | 246.2 s | 15 |
| 4 | 15 | 165.2 s | 20 |
| 5 | 12 | 117.6 s | 20 |
| 6 | 13 | 119.4 s | 20 |
| 7 | 17 | 126.4 s | 20 |
| 8 | 16 | 223.7 s | 20 |

La simulación también permite un control negativo con `--without-defense` y exige una derrota real.

La prueba del final registra los árboles comprados y los proyectiles emitidos por elemento. Exige la compra de las siete variedades, disparos de los cinco tipos ofensivos y victoria. La protección de Aqua y el bloqueo Terra en la rama eléctrica se verifican por separado en `tests/test_sprint_finale.gd`.

## Comparación de recarga en el nivel final

Se usó la semilla de nivel `20261116` y la misma economía en todos los controles. La recarga ajustada es de 6 s para Glacies y 10 s para Venenum.

| Defensa | Recarga | Tiempo simulado | HP final | Glacies | Venenum | Lanzamientos totales |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Mixta | 3 s | 208.6 s | 20 | 5 | 26 | 65 |
| Mixta | Ajustada | 201.2 s | 20 | 3 | 20 | 70 |
| Solo torres | Ajustada | 297.7 s | 20 | 0 | 0 | 0 |
| Solo hechizos | 3 s | 659.3 s | 14 | 14 | 60 | 182 |
| Solo hechizos | Ajustada | 566.4 s | 14 | 7 | 38 | 185 |

Con la recarga ajustada, la defensa mixta ganó los ocho niveles. También ganó el desafío del último nivel en 227.5 s con 20 HP. Al alargar las recargas, el controlador lanzó menos Glacies y Venenum y recurrió más a Terra y Electricitas. Las torres por sí solas ganaron con el Árbol Madre intacto y el control de solo hechizos siguió siendo viable. Los conteos de lanzamiento y disparo no miden la proporción de daño por fuente.

## Ejecución

Ejemplo en PowerShell desde la raíz del proyecto, usando el Godot instalado en este equipo:

```powershell
$env:APPDATA = Join-Path $PWD '.godot\test_environment\roaming'
$env:LOCALAPPDATA = Join-Path $PWD '.godot\test_environment\local'
& 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe' --headless --path . --script res://tests/simulate_campaign.gd -- --seed=20261103
```

`--from=2 --to=7` limita la ejecución a los niveles 3–8 (índices desde cero). La semilla de cada nivel es la base más su índice. `--without-defense` omite árboles y ataques y exige una derrota real. `--towers-only` y `--spells-only` aíslan cada tipo de defensa. `--fast-recharge` usa la recarga anterior de 3 s solo para la simulación. Para reproducir la comparación, usa `--from=7 --to=7 --seed=20261109` junto a las opciones del control.

Se acelera el reloj x8 con 240 pasos físicos por segundo real, equivalente a un paso nominal de 1/30 s de juego. Las duraciones reportadas son tiempo simulado, no tiempo de ejecución. El resultado JSON queda en `.godot/campaign_combat_<semilla>.json`; el control sin defensa usa el sufijo `_without_defense`. Para resultados estables deben mantenerse versión del motor y configuración; las semillas no prometen determinismo entre plataformas.

## Alcance

Esta prueba detecta partidas atascadas, falta de recursos para una estrategia concreta, herramientas no disponibles y errores de integración. Una victoria con 20/20 HP solo demuestra que existe una estrategia que funciona con este controlador. No demuestra una dificultad apropiada para una persona, claridad visual ni variedad estratégica.

La siguiente prueba manual debe observar si el jugador entiende el peligro antes de perder una defensa, si puede reponerla con sus ingresos y si dispone de tiempo para reaccionar sin recoger el pozo ni lanzar ataques con precisión automática. Conviene registrar nivel/ronda, estrategia, vida restante y qué decisión causó la derrota antes de ajustar recetas o intervalos.

Se conservan las estadísticas de la especificación y la vida provisional de 20 HP del Árbol Madre. El entorno restringido sigue emitiendo el error conocido del almacén de certificados al iniciar Godot; el criterio de la prueba son los resultados por nivel y el mensaje final, revisando también cualquier error de script.
