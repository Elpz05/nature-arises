# Nature Arises — Especificación de Mecánicas y Estadísticas

Documento de especificaciones técnicas y mecánicas de juego para el desarrollo en Godot.

## 1. Reglas Generales y Condición de Victoria/Derrota

* **Entidades Principales:**

  * **Árboles:** Unidades defensivas colocadas por el jugador.

  * **Bestias:** Unidades enemigas que avanzan por el mapa.

* **Flujo de Juego:**

  * Las bestias avanzan a lo largo de **caminos estériles** predefinidos con el objetivo de llegar al **Árbol Madre** y reducir su vida.

  * Los árboles atacan a la **bestia más cercana al Árbol Madre** dentro de su rango.

* **Condición de Derrota:** Si la salud del Árbol Madre llega a `0`, se pierde el nivel y debe reiniciarse.

* **Condición de Muerte de Unidades:**

  * Un árbol muere cuando su vida llega a `0`.

  * Una bestia muere cuando su vida llega a `0`.

## 2. Mecánicas de Construcción y Recursos

* **Recurso Principal (Agua):**

  * Generación pasiva base: `0.5` gotas de agua por segundo.

  * Las gotas acumulan un contador para comprar o mejorar árboles.

* **Plantado de Árboles:**

  * Los árboles **solo** se pueden plantar en casillas de pasto desocupadas (sin obstáculos), salvo excepciones por tipo de terreno especial.

  * **Límite:** Máximo `1` árbol por casilla.

  * **Desplantado:** Se puede retirar un árbol con la herramienta de pala; **no** se reembolsa el agua invertida.

* **Interactividad / Controles:**

  * **Arrastrar y Soltar (Drag & Drop):** Desde la barra de paquetes de semillas hasta la casilla vacía.

  * **Clic-Clic:** Clic en el paquete de semillas y posterior clic en la casilla objetivo.

  * **Ataques Elementales:** Mapeados en una barra independiente; se ejecutan arrastrando o haciendo clic en el objetivo dentro de un área circular predefinida.

## 3. Mecánicas del Entorno y Eventos Globales

* **Caminos Estériles:**

  * Las bestias **solo** pueden desplazarse por casillas de camino estéril.

  * Múltiples bestias pueden ocupación/transitar la misma casilla simultáneamente.

  * **Atajos Elementales:** Caminos secundarios específicos que solo permiten el paso de bestias de su mismo elemento para cortar distancia hacia el Árbol Madre.

* **Bendición de Ventus:**

  * Cada `20` segundos, una bestia elegida aleatoriamente recibe la bendición de Ventus.

  * **Efecto:** Incrementa su velocidad de movimiento en `+0.5` casillas por segundo.

## 4. Estadísticas y Comportamiento de los Árboles

### 4.1 Natura

* **Descripción:** Lanza semillas teledirigidas a un solo objetivo a la vez.

* **Costo de Agua:** Pequeño: `1` | Mediano: `2` | Grande: `3`

* **Vida:** Pequeño: `100` | Mediano: `200` | Grande: `300`

* **Radio de Ataque:** Pequeño: `2` casillas | Mediano: `2.5` casillas | Grande: `3` casillas

* **Velocidad de Ataque Base:** `2` balas por segundo.

* **Multiplicador por Tamaño:**

  * Pequeño: `x1.0` velocidad de ataque.

  * Mediano: `x1.2` velocidad de ataque.

  * Grande: `x1.5` velocidad de ataque.

* **Daño por Proyectil:** `20`

* **Especial:** Sin efectos adicionales.

### 4.2 Flamma

* **Descripción:** Lanza bolas de fuego infligiendo daño de área (AoE).

* **Costo de Agua:** Pequeño: `3` | Mediano: `4` | Grande: `5`

* **Vida:** Pequeño: `250` | Mediano: `500` | Grande: `800`

* **Radio de Ataque:** Pequeño: `2` casillas | Mediano: `3` casillas | Grande: `4` casillas

* **Área del Daño (AoE):** Pequeño: `1` casilla | Mediano: `1.5` casillas | Grande: `2` casillas

* **Velocidad de Ataque Base:** `1` bala por segundo.

* **Daño por Proyectil:** `40`

* **Interacciones Elementales Especiales:**

  * Vs **Bestia Flamma:** `-25%` de daño infligido.

  * Vs **Bestia Glacies:** `+25%` de daño infligido.

  * Vs **Bestia Aqua:** `-100%` de daño infligido (sin daño).

  * Vs **Bestia Natura:** `+5%` de daño infligido.

  * Remueve los efectos de congelación provocados por el Árbol Glacies en su zona de influencia.

### 4.3 Aqua

* **Descripción:** Unidad de soporte/recurso. Incrementa la producción de gotas de agua por segundo.

* **Costo de Agua:** Pequeño: `6` | Mediano: `8` | Grande: `10`

* **Vida:** Pequeño: `100` | Mediano: `100` | Grande: `100`

* **Estadísticas de Ataque:** N/A (no ataca).

* **Aumento de Producción:** Pequeño: `+0.1` gotas/s | Mediano: `+0.2` gotas/s | Grande: `+0.3` gotas/s

* **Interacciones y Reglas Especiales:**

  * Solo puede ser plantado en **caminos estériles inundados** (disponible únicamente en niveles con clima de Lluvia o Tormenta Eléctrica).

  * Si una **Bestia Aqua** pasa sobre él: la bestia lo ignora y pasa de largo.

  * Si una **Bestia Flamma** pasa sobre él: el árbol pierde `25` de vida y la Bestia Flamma pierde `100` de vida.

  * Cualquier **otra bestia** que pase sobre él lo destruye instantáneamente.

### 4.4 Terra

* **Descripción:** Unidad defensiva de bloqueo y control de masas.

* **Costo de Agua:** Pequeño: `3` | Mediano: `6` | Grande: `9`

* **Vida:** Pequeño: `1000` | Mediano: `2000` | Grande: `3000`

* **Estadísticas de Ataque:** N/A

* **Efecto de Empuje (Knockback):**

  * Pequeño: Empuja hacia atrás a las bestias `0.5` casillas.

  * Mediano: Empuja hacia atrás a las bestias `0.7` casillas.

  * Grande: Empuja hacia atrás a las bestias `1.0` casilla.

* **Especial:** Bloquea físicamente el avance enemigo.

### 4.5 Electricitas

* **Descripción:** Emite descargas eléctricas que rebotan encadenándose entre varias bestias.

* **Costo de Agua:** Pequeño: `2` | Mediano: `4` | Grande: `8`

* **Vida:** Pequeño: `200` | Mediano: `400` | Grande: `600`

* **Radio de Ataque:** Pequeño: `2.5` casillas | Mediano: `3` casillas | Grande: `3.5` casillas

* **Objetivos Máximos Encadenados:** Pequeño: `3` bestias | Mediano: `5` bestias | Grande: `7` bestias

* **Velocidad de Ataque Base:** `3` balas por segundo.

* **Daño por Proyectil:** `10`

* **Interacciones Elementales Especiales:**

  * Vs **Bestia Electricitas:** `-50%` de daño infligido.

  * Vs **Bestia Aqua:** `+10%` de daño infligido.

### 4.6 Glacies

* **Descripción:** Lanza carámbanos penetrantes que aplican ralentización y congelación.

* **Costo de Agua:** Pequeño: `3` | Mediano: `5` | Grande: `8`

* **Vida:** Pequeño: `150` | Mediano: `300` | Grande: `600`

* **Radio de Ataque:** Pequeño: `3` casillas | Mediano: `3.5` casillas | Grande: `4` casillas

* **Objetivos Afectados simultáneamente:** Pequeño: hasta `3` | Mediano: hasta `4` | Grande: hasta `5`

* **Velocidad de Ataque Base:** `1` bala por segundo.

* **Daño por Proyectil:** `2`

* **Interacciones Elementales Especiales:**

  * Aplica estado de congelación durante `2` segundos.

  * Vs **Bestia Glacies:** `-10%` de daño infligido.

  * Vs **Bestia Aqua:** `+10%` de daño infligido.

  * Vs **Bestia Flamma:** `+15%` de daño infligido.

### 4.7 Venenum

* **Descripción:** Unidad de largo alcance que lanza proyectiles radiactivos, aplicando veneno (DoT) y ralentización a un objetivo.

* **Costo de Agua:** Pequeño: `10` | Mediano: `12` | Grande: `14`

* **Vida:** Pequeño: `500` | Mediano: `800` | Grande: `1000`

* **Radio de Ataque:** Pequeño: `4` casillas | Mediano: `5` casillas | Grande: `6` casillas

* **Velocidad de Ataque Base:** `0.3` balas por segundo.

* **Daño por Impacto Directo:** `100`

* **Efectos de Estado por Tamaño:**

  * Pequeño: `-1` HP/segundo | `-25%` velocidad de movimiento.

  * Mediano: `-2` HP/segundo | `-27%` velocidad de movimiento.

  * Grande: `-3` HP/segundo | `-30%` velocidad de movimiento.

* **Interacciones Elementales Especiales:**

  * Vs **Bestia Venenum:** `-30%` de daño (la bestia es inmune al efecto de veneno DoT).

  * Vs **Bestia Natura:** `+10%` de daño infligido.

## 5. Estadísticas y Comportamiento de las Bestias

### 5.1 Natura

* **Vida:** Pequeño: `200` | Mediano: `500` | Grande: `1000`

* **Velocidad de Movimiento:** `0.4` casillas/segundo.

* **Daño por Contacto:** `50`

* **Habilidad Especial:** Al morir, posee un `30%` de probabilidad de invocar una nueva Bestia Natura en el mismo punto con idénticas estadísticas.

### 5.2 Flamma

* **Vida:** Pequeño: `150` | Mediano: `450` | Grande: `800`

* **Velocidad de Movimiento:** `0.3` casillas/segundo.

* **Daño por Contacto:** `100`

* **Habilidad Especial:** Al morir, renace una sola vez en el mismo punto con sus estadísticas al máximo. Al renacer permanece inmóvil por `3` segundos antes de reanudar el avance.

### 5.3 Aqua

* **Vida:** Pequeño: `200` | Mediano: `500` | Grande: `1000`

* **Velocidad de Movimiento:** `0.5` casillas/segundo.

* **Daño por Contacto:** `0`

* **Habilidad Especial:** Ignora e inhabilita el ataque de contacto contra Árboles Aqua y Terra (pasa de largo).

### 5.4 Terra

* **Vida:** Pequeño: `500` | Mediano: `900` | Grande: `1500`

* **Velocidad de Movimiento:** `0.2` casillas/segundo.

* **Daño por Contacto:** `100`

* **Habilidad Especial:** Cada impacto recibido tiene un `10%` de probabilidad de anular completamente el daño (`0` de daño recibido).

### 5.5 Electricitas

* **Vida:** Pequeño: `300` | Mediano: `500` | Grande: `1000`

* **Velocidad de Movimiento:** `0.6` casillas/segundo.

* **Daño por Contacto:** `50`

* **Habilidad Especial (Aura Posesiva):** Los árboles situados en casillas adyacentes a esta bestia pierden `1` de vida cada segundo.

### 5.6 Glacies

* **Vida:** Pequeño: `350` | Mediano: `550` | Grande: `1050`

* **Velocidad de Movimiento:** `0.3` casillas/segundo.

* **Daño por Contacto:** `75`

* **Habilidad Especial (Aura Gélida):** Los árboles en casillas adyacentes sufren estado de congelación automáticamente, a menos que estén protegidos dentro del área de un Árbol Flamma. (El Árbol Glacies es inmune a esta aura).

### 5.7 Venenum

* **Vida:** Pequeño: `300` | Mediano: `600` | Grande: `900`

* **Velocidad de Movimiento:** `0.6` casillas/segundo.

* **Daño por Contacto:** `150`

* **Habilidad Especial (Aura Tóxica):** Los árboles en casillas adyacentes reducen su velocidad de ataque en un `30%` y cada proyectil que disparan tiene un `30%` de probabilidad de fallar (desviarse o desvanecerse).

## 6. Habilidades y Ataques Elementales del Jugador

Mapeados en la interfaz del jugador como hechizos/habilidades activas.

* **Regla General de Cancelación:** Aplicar un nuevo ataque elemental sobre una bestia bajo el efecto de otro anula el efecto anterior y aplica de inmediato el nuevo.

* **Tiempo de Recarga Base:** `3` segundos por habilidad.

| Elemento | Daño Base | Radio (Casillas) | Capacidad de Carga | Efecto Especial | Inmunidades / Modificadores | 
| ----- | ----- | ----- | ----- | ----- | ----- | 
| **Natura** | `10` | `2.5` | `2` | Inmoviliza a las bestias durante `0.5` s. | Inútil contra Bestias **Flamma** y **Venenum**. | 
| **Flamma** | `20` | `2.5` | `3` | Aplica quemadura por `3` s (`10` HP/s). | Inútil contra Bestias **Flamma** y **Aqua**. Daño x2 vs **Glacies**. | 
| **Aqua** | `30` | `3.0` | `2` | Las bestias se confunden e ignoran atajos. 50% chance de animación de natación (`0.5` s). | Inútil contra **Aqua**. Daño x2 vs **Flamma**. | 
| **Terra** | `50` | `2.0` | `2` | Mareo: interrumpe el movimiento `0.5` s cada segundo. | Inútil contra Bestia **Terra**. | 
| **Electricitas** | `40` | `2.5` | `2` | Invierte la dirección de marcha de las bestias por `0.5` s. | Inútil contra Bestia **Electricitas**. | 
| **Glacies** | `10` | `4.0` | `3` | Congela a las bestias durante `2` s. | Inútil contra **Glacies**. Daño x2 vs **Flamma** y **Aqua**. | 
| **Venenum** | `100` | `2.5` | `2.5` | Las bestias reciben `+1` de daño extra por proyectil recibido. Ralentiza 3 enemigos al azar en el área. | Inútil contra **Venenum**. Elimina instantáneamente Bestias Natura pequeñas. | 

## 7. Mecánicas Climáticas y de Entorno (Modificadores Avanzados)

> **Cálculo de Modificadores:** Los bonos/penalizaciones de entorno se aplican sobre el cálculo final de daño.
> *Ejemplo:* Si Flamma inflige `-25%` a Bestia Flamma y el entorno le da `+20%`, el multiplicador resultante es `-5%`.

### 7.1 Lluvia

* **Torres:** Velocidad de ataque general `-25%`.

* **Recursos:** Generación de agua `+0.25` gotas/s.

* **Modificadores:**

  * Árbol Flamma: Daño `-25%`.

  * Árbol Electricitas: Daño `+25%`.

  * Bestia Flamma: Vida base `-50%`.

* **Terreno:** Se generan caminos de agua predefinidos. Permite la siembra del Árbol Aqua, inhabilita la del Árbol Terra en esas casillas.

### 7.2 Tormenta Eléctrica

* **Torres:** Velocidad de ataque general `-50%`.

* **Recursos:** Generación de agua `+0.5` gotas/s.

* **Modificadores:**

  * Árbol Flamma: Daño `-50%`.

  * Árbol Electricitas: Daño `+35%`.

  * Bestia Flamma: Vida base `-50%`.

* **Rayos Caóticos:**

  * *Tamaño Pequeño:* `10%` probabilidad de rayo cada `5` s.

  * *Tamaño Mediano:* `50%` probabilidad de rayo cada `3` s.

  * *Tamaño Grande:* `90%` probabilidad de rayo cada `1` s.

  * *Efecto:* Mata instantáneamente a cualquier árbol impactado (no reembolsa agua).

  * *Inmunidad:* Árbol y Bestia Electricitas son inmunes a los rayos.

### 7.3 Volcán

* **Modificadores:**

  * Árbol Flamma: Daño `+20%`.

  * Árbol Glacies: Daño `-20%`.

  * Demás Árboles: Velocidad de ataque `+10%`.

  * Bestia Glacies: Vida base `-50%`.

  * Recursos: Generación de agua reducida a `0.25` gotas/s.

* **Peligros Ambientales:**

  * **Géiser:** Cada `10` s otorga `+25%` velocidad de ataque a árboles adyacentes por `7` s, pero inflige `25` de daño a dichos árboles.

  * **Erupción:** Cada `25` s elimina un árbol aleatorio en el mapa.

  * *Inmunidad:* Árbol Flamma es completamente inmune a los efectos de géiser y erupción.

### 7.4 Ventisca

* **Modificadores:**

  * Árbol Glacies: Velocidad de ataque `+20%`.

  * Árbol Flamma: Daño `+10%`.

  * Bestia Glacies: Velocidad de movimiento `+20%`.

  * Bestia Flamma: Vida base `+20%`.

* **Mecánica de Congelación Climática:**

  * Cada `10` s, la ventisca barre el mapa aplicando `+1` nivel de congelación y `-25` HP a todos los árboles.

  * **Nivel 3 de Congelación:** El árbol queda totalmente inhabilitado (deja de atacar).

  * **Remoción/Inmunidad:** Árbol Flamma y Glacies son inmunes. Árbol Flamma emite un aura cálida en sus 8 casillas adyacentes cada `20` s, reduciendo en `1` el nivel de congelación y anulando congelaciones posteriores en su área.

### 7.5 Derrumbe

* **Mecánica:** Cada `15` s cae una roca a lo largo de una columna aleatoria del tablero, destruyendo a toda bestia y árbol en dicha columna.

* **Defensa:** El Árbol Terra puede aguantar y bloquear hasta `3` caídas de rocas independientemente de su HP (se destruye al 3.er impacto).

* **Diseño de Mapa:** Diseñado con caminos estériles de trazado vertical alargado.

### 7.6 Campo Radiactivo

* **Daño Ambiental:** Todos los árboles pierden `5` HP/segundo por radiación.

* **Modificadores:**

  * Todos los árboles obtienen `+5%` velocidad de ataque (excepto Árbol Venenum).

  * Bestia Venenum: Vida `+30%`.

* **Muerte por Intoxicación:**

  * *Árbol Pequeño:* `5%` prob/s de morir instantáneamente.

  * *Árbol Mediano:* `10%` prob/s de morir instantáneamente.

  * *Árbol Grande:* `15%` prob/s de morir instantáneamente.

* **Inmunidad:** Árbol Venenum es completamente inmune a la radiación e intoxicación.

```
