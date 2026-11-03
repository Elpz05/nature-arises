# Venenum

Completa el índice 6 de semillas. Ambos niveles tienen asignada su escena y el laboratorio `res://demo/mecanicas_lluvia.tscn` habilita las siete plantas sin escribir desbloqueos de campaña. Ejecutar con F6 y seleccionar Venenum mediante su botón o F7. Necesita pasto libre y 10 gotas iniciales; la pala no devuelve agua.

| Tamaño | Costo | Vida | Alcance | Veneno | Reducción de velocidad |
| --- | --- | --- | --- | --- | --- |
| Pequeño | 10 | 500 | 4 casillas | 1 HP/s | 25% |
| Mediano | 12 | 800 | 5 casillas | 2 HP/s | 27% |
| Grande | 14 | 1000 | 6 casillas | 3 HP/s | 30% |

Los costos superiores se cobran al mejorar. Cada proyectil teledirigido inflige 100 de daño directo a una sola bestia. La cadencia es 0.3 disparos/s antes de las penalizaciones de lluvia/tormenta. La torre conserva la prioridad común de menor distancia restante hasta el Árbol Madre. Se utiliza una silueta provisional violeta y la bala existente teñida de violeta. La inspección muestra vida, alcance, cadencia, veneno y ralentización.

## Duración y acumulación

**Decisión provisional:** la especificación no fija duración para el veneno ni su ralentización. Se usan 6 segundos para ambos efectos, definidos por `Arbol.DURACION_VENENO`. Un nuevo impacto de igual potencia renueva hasta 6 s sin sumar daño por segundo; uno más fuerte sustituye el efecto y uno más débil no lo reemplaza ni prolonga. El daño directo sí se aplica en cada proyectil.

La ralentización propia del veneno tiene un temporizador separado de otras ralentizaciones. Si coinciden, se utiliza la más fuerte, sin multiplicarlas. Expirar el veneno no elimina una ralentización independiente que siga activa. Glacies puede congelar simultáneamente a la víctima; el veneno sigue causando daño durante la congelación o la inmovilidad de renacimiento.

Daño y movimiento se integran con el tiempo transcurrido y las expiraciones intermedias. Un fotograma largo no extiende el daño más allá de los 6 s y permite recuperar la velocidad durante la fracción de tiempo ya libre de efectos. La pausa y los resultados detienen la actualización de veneno. Al morir, la bestia pierde ese efecto; si Flamma renace por daño de veneno, recupera su vida máxima, se limpia el veneno y conserva los 3 s completos de renacimiento. Una copia Natura también nace sin efectos heredados.

## Elementos

- Natura recibe +10% de daño directo: 110 por impacto. El veneno mantiene sus valores de 1/2/3 HP/s.
- Venenum recibe -30% de daño directo: 70 por impacto, y es inmune al daño periódico. La especificación no le da inmunidad a la ralentización, por lo que esa penalización sí se aplica.
- Otros elementos reciben 100 de daño directo y el efecto correspondiente al tamaño.

El estado sobre la bestia indica `Veneno N HP/s` y el porcentaje efectivo de lentitud. Se mantiene la vida fraccionaria para daños y movimiento independientes de la frecuencia de actualización.

La [bestia Venenum](bestias.md) ya existe con su resistencia, inmunidad al veneno y aura tóxica. El [hechizo completo](ataques_elementales.md) ya está implementado; el [campo radiactivo](climas.md) también está implementado, incluida la inmunidad ambiental del árbol.

## Validación

`tests/test_venenum.gd` verifica selección y desbloqueos, los siete árboles del laboratorio, costos, vida, tamaños, alcance, cadencia, inspección y terreno; proyectil real contra un único objetivo y daño único; DoT fraccionario, ralentización real, renovación y reemplazo, pausa, expiración exacta, lentitud independiente, congelación, modificadores, inmunidad solo al DoT, muerte y renacimiento, resultados y pala. Compara un paso largo con múltiples pasos cortos.

Las trece suites reportaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que causa salida 1 aunque pasen las aserciones. APPDATA y LOCALAPPDATA se aislaron en `.godot/test_environment`.
