# Glacies

El árbol ocupa el índice 5, respetando los índices existentes de semillas y partidas. Está conectado en ambos niveles; el laboratorio `res://demo/mecanicas_lluvia.tscn` lo habilita con F6 sin guardar desbloqueos. F6 dentro del juego selecciona su semilla con los controles predeterminados; el botón Glacies permite seleccionarlo con ratón. Se planta en pasto libre, mediante clic-clic o arrastre.

| Tamaño | Costo | Vida | Alcance | Máximo de bestias por carámbano |
| --- | --- | --- | --- | --- |
| Pequeño | 3 | 150 | 3 casillas | 3 |
| Mediano | 5 | 300 | 3.5 casillas | 4 |
| Grande | 8 | 600 | 4 casillas | 5 |

La cadencia base es un disparo por segundo y cada impacto causa 2 de daño. Lluvia y tormenta conservan las reducciones generales de cadencia ya implementadas. Se utiliza una silueta de hielo provisional; los carámbanos tienen un dibujo propio y la inspección muestra alcance, cantidad de objetivos y duración de congelación.

## Proyectil penetrante

Se apunta a la bestia más cercana a la meta dentro del rango, igual que las otras torres ofensivas. El carámbano fija su dirección al comenzar a volar y sigue en línea recta hasta agotar el alcance de su tamaño o el máximo de víctimas. No se redirige tras cada impacto. Después de iniciar su vuelo puede continuar aunque desaparezca el objetivo inicial.

Para un fotograma largo se comprueba el segmento completo recorrido, ordenando los impactos por distancia a lo largo de la dirección de vuelo. Cada bestia solo recibe un impacto del mismo carámbano. No se afectan bestias fuera de la línea: se usa una tolerancia de 16 píxeles a cada lado del centro del proyectil como ancho provisional, pendiente de pulido de gameplay. Los enemigos nacidos como copias tras un impacto no forman parte de las víctimas capturadas de ese segmento.

## Congelación y elementos

Cada impacto congela 2 segundos. Repetir el efecto renueva la duración sin sumar segundos. La congelación detiene tanto el avance como el ataque de contacto contra Terra; al expirar se reanuda el movimiento. Si expira a mitad de un fotograma, se avanza solo durante la parte libre de congelación. Pausar conserva el tiempo restante. El estado se muestra como «Congelado» sobre la bestia.

El documento no define una ralentización adicional ni su porcentaje para Glacies; se aplica la congelación de 2 s especificada sin añadir una segunda penalización inventada. Su temporizador es independiente del renacimiento de Flamma y del aturdimiento de Natura.

Daño por impacto: 1.8 contra Glacies (-10%), 2.2 contra Aqua (+10%), 2.3 contra Flamma (+15%) y 2 para el resto. La vida de bestias admite fracciones para conservar estos modificadores en ataques de daño bajo. La [bestia Glacies](bestias.md) ya existe con su resistencia y aura de congelación de árboles.

Las explosiones de Flamma retiran la congelación en las víctimas de su área, incluso si Aqua es inmune al daño de fuego. Descongelar no cancela la inmovilidad de 3 s de renacimiento de una bestia Flamma. No se añadieron hechizos nuevos ni sistemas climáticos de congelación.

## Validación

`tests/test_glacies.gd` cubre costos y tamaños, vista previa e inspección, configuración real del disparo por Area2D, daño fraccionario, penetración 3/4/5 con fotogramas largos, orden de impactos, exclusión de objetivos fuera de la línea, impacto único, alcance máximo, congelación, pausa, renovación, recuperación del movimiento, deshielo de Flamma y pala sin reembolso.

Las once suites reportaron PASS con Godot 4.7.2. Persiste el error del almacén de certificados del entorno al iniciar Godot, que causa salida 1 aunque las aserciones pasen. APPDATA y LOCALAPPDATA se aíslan en `.godot/test_environment`.
