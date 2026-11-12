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

## Fase P3

Desde la tercera ronda del nivel 3 se ajustan la vida y la velocidad de las bestias. Los grupos de Terra/Aqua, Electricitas/Flamma y Venenum/Flamma se intercalan para que sus amenazas lleguen juntas. Las tres últimas rondas del nivel 6 tienen intervalos de aparición efectivos de 1.49, 1.45 y 1.40 s. El nivel 8 alterna amenazas del camino principal y de los atajos en las dos últimas rondas.

En los niveles 6–8, las rondas 3 y 4 pagan una gota normal. La preparación y el pago usan la misma función. El desafío sigue añadiendo tres gotas cuando se supera y la última ronda termina con la victoria.

Para repetir los controles con un perfil aislado:

```powershell
$env:APPDATA = Join-Path $PWD '.godot/p3/roaming'
$env:LOCALAPPDATA = Join-Path $PWD '.godot/p3/local'
$godot = 'C:\Users\Admin\Desktop\godot\Godot_v4.7.2_console.exe'
& $godot --headless --path . --script res://tests/simulate_campaign.gd -- --speed=8 --seed=20261108
& $godot --headless --path . --script res://tests/simulate_campaign.gd -- --speed=8 --seed=20261109
& $godot --headless --path . --script res://tests/simulate_campaign.gd -- --speed=8 --seed=20261108 --from=5 --winter-build=basin --finale-build=split
& $godot --headless --path . --script res://tests/simulate_campaign.gd -- --speed=8 --seed=20261108 --without-defense
```

El bosque helado admite un despliegue temprano junto a la primera columna y otro centrado en la cuenca y el tramo de salida. En el final, la variante dividida comienza con Aqua en la poza oriental y Terra en la ruta de salida. Compra los atacantes orientales antes de reforzar el centro y el oeste. Los informes distinguen las variantes con los sufijos `_basin` y `_split`.

Cada informe JSON contiene una entrada por nivel y otra por ronda completada o interrumpida por derrota. Incluye la vida inicial y final del Árbol Madre, impactos de bestias que llegan a la meta, gotas disponibles, reserva del pozo, bajas totales de árboles y bajas atribuidas a los avisos de clima. Cada combinación de nivel y semilla ejecuta un intento; se registra con cero reintentos. Los controles sin defensa deben perder y los controles mixtos deben ganar.

### Resultados de P3

Las dos semillas base, 20261108 y 20261109, ganaron los ocho niveles con 20/20 HP y cero fugas. El control sin defensa perdió los ocho, con 8–12 fugas por intento. Los informes detallados están en `.godot/campaign_combat_*.json`. Para el ajuste final de la quinta ronda del nivel 8 se hicieron ejecuciones específicas adicionales.

| Nivel | Gotas finales, dos semillas | Bajas de árboles, dos semillas |
| --- | --- | --- |
| 1 | 0 / 1 | 0 / 0 |
| 2 | 2 / 2 | 0 / 0 |
| 3 | 2 / 1 | 2 / 3 |
| 4 | 1 / 3 | 0 / 0 |
| 5 | 3 / 2 | 0 / 2 |
| 6 | 0 / 0 | 6 / 5 |
| 7 | 2 / 0 | 5 / 5 |
| 8 | 3 / 3 | 0 / 0 |

En el nivel 6, la ventisca causó dos bajas en una semilla y una en la otra. La variante de la cuenca ganó con 20 HP, una gota y dos bajas por ventisca en 700.6 s simulados. La formación de la primera columna completó el nivel en 388.0 s con la misma semilla. En el nivel 8, las dos configuraciones mixtas superaron la quinta ronda revisada. La variante dividida terminó con dos gotas. Solo torres también ganó con 20 HP, con compras y mejoras durante la partida. Los resultados no establecen que la adaptación activa sea indispensable en el final. El control sin defensa acumuló agua durante recorridos largos y terminó en derrota, por lo que sigue pendiente medir el acopio si un jugador demora una ronda deliberadamente.

Las pruebas de progresión de campaña, mapa de controles, escalas de interfaz de 100/125/150 %, tácticas de oleadas, economía del pozo y avisos de peligros pasaron. La batería amplia detectó pruebas que consultan miembros de interfaz ausentes, comprobaciones fallidas de las cargas de Venenum y los desbloqueos de Terra, y una ejecución de seguridad que se cerró con error después de imprimir PASS. Las partidas manuales con teclado y mando y la aprobación final de dificultad siguen pendientes.
