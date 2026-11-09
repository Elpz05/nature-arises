# Primer bloque de mecánicas

La fuente de diseño es `mecanicas_especificacion.md`. Este bloque sustituye los roles provisionales documentados anteriormente.

## Implementado

- El [pozo central](well_economy.md) acumula hasta cinco gotas durante las rondas. La recogida transfiere toda la reserva al jugador.
- Una planta por casilla; pala sin reembolso, incluyendo mejoras. Retirar o destruir Aqua conserva la reserva del camino.
- Natura conserva exactamente sus estadísticas por tamaño y sus semillas teledirigidas. Natura y Flamma priorizan la bestia con menor distancia restante en su ruta.
- Flamma: 250/500/800 HP, alcance 2/3/4, área 1/1.5/2 casillas, 40 de daño, un disparo/s en despejado. Modificadores contra Flamma (-25%), Glacies (+25%), Natura (+5%) y Aqua (inmunidad). Los modificadores de daño de clima y elemento se suman.
- Aqua tiene 100 HP y aporta +0.1/+0.2/+0.3 gotas/s al pozo. Crece en caminos inundados de lluvia y tormenta, o en pozas del campo radiactivo. En radiación reduce a la mitad el daño del pulso a sus vecinos ortogonales.
- Aqua ignora bestias Aqua; al pasar Flamma pierde 25 HP y la bestia pierde 100 HP. Otras bestias lo destruyen. Cada paso cuenta una vez, aunque la bestia permanezca varios fotogramas sobre la casilla.
- Ventus: cada 20 s de juego se elige una bestia viva de las rutas del nivel y obtiene +0.5 casillas/s, mostrado sobre su barra. No acumula bonos repetidos; al no haber bestias ese evento no concede nada. El documento no especifica duración/acumulación, por lo que se conserva hasta morir, sin apilar.
- Lluvia: 0.30 gotas/s, cadencia x0.75, Flamma -25% de daño, bestia Flamma con mitad de vida. Tormenta: 0.40 gotas/s, cadencia x0.5 y Flamma -50% de daño, bestia Flamma con mitad de vida. Renacer respeta esa vida máxima ajustada.
- HUD: producción y clima visibles, descripción de roles, vida de torres y aporte de Aqua en inspección.

## Probar

Abrir `res://demo/mecanicas_lluvia.tscn` y ejecutar con F6. Se habilitan los siete árboles (Natura, Flamma, Aqua, Terra, Electricitas, Glacies y Venenum) en este laboratorio. El camino tiene cinco casillas azules (x=6..10, y=4) aptas para Aqua; con 6 gotas se puede plantar uno. Terra cuesta 3 gotas y se puede probar desde el inicio en una casilla seca, por ejemplo (4, 4). La primera ronda incluye dos bestias Aqua para comprobar que atraviesan Terra. El laboratorio comienza con las 3 gotas habituales. Su victoria no guarda progreso de campaña. La campaña principal tiene ocho niveles con desbloqueos progresivos; se ejecuta con F5 desde el menú de partidas.

En el inspector de un nivel se configuran `clima` y `celdas_inundadas`; las entradas que no pertenecen a un camino no permiten Aqua. Es configuración de inicio del nivel, sin transiciones climáticas durante la partida.

Pruebas: `test_mechanics_foundation.gd` cubre producción fraccionaria y pausa, restricciones de terreno, mejoras, pala, contactos, Ventus, daño aditivo y renacimiento con clima. Se adaptaron también las pruebas de roles, economía, inspección, niveles compartidos y controles a las nuevas reglas.

Validación: las nueve suites informaron PASS con Godot 4.7.2. El entorno restringido emite `Failed to read the root certificate store` al iniciar Godot, que provoca código de salida 1 incluso cuando las aserciones pasan. Se aisló APPDATA/LOCALAPPDATA en `.godot/test_environment` para no usar partidas reales. También se renderizó y revisó el laboratorio a 1920×1080 con OpenGL Compatibility.

## Pendiente del documento

Quedan el balance humano de la campaña, el pulido visual y sonoro y la revisión del contacto general fuera de las interacciones de Terra/Aqua.

Se conserva el daño actual al Árbol Madre y sus 20 HP: el documento define daño de contacto, pero no un valor separado al llegar a la meta ni vida inicial del Árbol Madre. Falta decidir estos valores para balancear los niveles sin convertir cada llegada en derrota instantánea. La capacidad fraccionaria de Venenum ya se implementó con la interpretación documentada en ataques_elementales.md.

El árbol [Glacies](glacies.md) ya tiene sus tres tamaños, carámbanos penetrantes, congelación y modificadores elementales. [Terra](terra.md) cubre bloqueo y contacto.

[Electricitas](electricitas.md) ya tiene sus tres tamaños, descargas encadenadas 3/5/7, modificadores elementales y bonos de lluvia/tormenta.

[Venenum](venenum.md) completa los siete árboles: tres tamaños, proyectil de largo alcance, veneno y ralentización. El laboratorio habilita los siete; faltan el balance final y los sistemas avanzados enumerados arriba.

Las [siete bestias](bestias.md) ya tienen estadísticas por tamaño, rutas, contacto y habilidades base. Terra anula impactos y las auras de Electricitas, Glacies y Venenum actúan sobre los árboles. El laboratorio incluye los tipos nuevos en las rondas 1/3/5.

Los [siete ataques elementales](ataques_elementales.md) ya incluyen daño, inmunidades, cancelación, estados, confusión y rutas, vulnerabilidad y recarga por carga. El laboratorio habilita los siete hechizos sin modificar partidas.

Los [climas avanzados](climas.md) ya incluyen rayos, géiseres, erupciones, congelación y calor, rocas y radiación, con un selector de nueve variantes de laboratorio.

La [campaña de ocho niveles](campana.md) ya distribuye unidades, climas, rondas y desbloqueos. Incluye migración de partidas v1 y simulaciones de combate real de toda la campaña; ver [validación de jugabilidad](balance_campana.md). El balance humano sigue pendiente.
