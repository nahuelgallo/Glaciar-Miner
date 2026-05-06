# Glacial Miner — Documento de Diseño del Juego

## 1. Pitch

Glacial Miner es un roguelike que hibrida dungeon crawling basado en grilla con combate deck-building por turnos. Encarnás a un minero que se adentra en una civilización oculta enterrada bajo los glaciares de la Patagonia — los restos de una Argentina caída. Mineás los dungeons, armás un mazo de héroes y acciones políticas, y atravesás capa tras capa de ruina congelada.

El juego es una parodia del debate por la ley de glaciares de la Argentina del 2026, que legalizó la minería adyacente a glaciares y pone en riesgo una pérdida masiva de glaciares. Cada facción de cartas es un bloque político reconocible; el loop de minería *es* el chiste.

## 2. Objetivos y restricciones

### Objetivos de diseño
- Parodiar la votación de la ley de glaciares 2026
- Representar los bloques políticos y figuras clave del incidente
- Un loop deck-builder donde cada run se sienta diferente

### Restricciones de producción
- Construido en **1 semana** para una game jam
- **Engine:** Godot 4 con web export
- **Plataforma:** Web
- **Inputs (release de jam):** Mouse + Teclado + Touch (gamepad post-jam)
- **Referencias:** Slay the Spire (combate), Pokémon Mystery Dungeon (exploración), Rogue (runs procedurales), EarthBound (agrupamiento de encuentros)

## 3. Narrativa

### 3.1 Setting
Argentina post-apocalíptica, ocupada por una potencia extranjera. Los dungeons son los restos de una civilización perdida — una Argentina caída sepultada bajo los glaciares. El minero está cavando entre las ruinas de su propio país.

### 3.2 Tono
**Mayormente jugado en serio, con ocasional puntuación humorística.** La voz por default es seria — el minero se toma el trabajo en serio, los NPCs hablan con sinceridad, la civilización caída tiene peso real. La mayor parte de la comedia vive en el *contenido* (facciones políticas enterradas en el hielo, actores extranjeros como monstruos literales, el loop de minería como una parodia deadpan de la ley real), no en la *entrega*.

Dicho esto, el mundo es absurdo, y nunca dejar que eso se note sería su propia clase de auto-seriedad. Humor moderado — un nombre filoso de carta, una frase seca de un NPC, un sight gag en el arte — es bienvenido, *siempre que siga siendo la excepción, no la regla*.

Lineamientos de calibración:
- **Default a entrega deadpan.** La mayoría del texto de cartas se lee de manera funcional. *"Mineá toda roca del chunk actual instantáneamente. Destruí permanentemente una carta aleatoria de tu mazo."* La mecánica y el target de la carta *son* el chiste; envolverlo en wording chistoso lo ahoga.
- **Que el humor caiga porque es raro.** Reservá los chistes explícitos para momentos donde puntúan, no donde rellenan. Una sola frase memorable de un NPC le gana a cinco olvidables.
- **Usá referentes reales.** "La Jefa" / "FMI" / "Barrick Gold" le ganan a "Populista Genérica" / "Banco Extranjero" / "Minera Cía". Los nombres reconocibles hacen el trabajo de la sátira sin que la escritura tenga que esforzarse.
- **No rompas la cuarta pared.** Lampshading, referencias a memes, "los desarrolladores querían que sepas..." — todo eso colapsa el marco. El juego no reconoce que es una parodia.
- El marco serio es lo que le da fuerza a la parodia. Los chistes adentro son condimento.

## 4. Loop macro

```
RUN
  └─ CAPA (n total — TBD; el engine debe soportar n arbitrario)
      ├─ EXPLORACIÓN  (basada en grilla; los turnos avanzan al moverse el jugador)
      │   ├─ Mover / minar rocas / juntar cartas y minerales
      │   ├─ Chocar con un enemigo → COMBATE
      │   └─ Visitar SHRINE → gastar minerales en booster packs / curar / destruir cartas
      └─ BOSS ROOM
          ├─ Combate contra el boss → drop de un McGuffin
          └─ El McGuffin abre el HARD GATE de la capa → siguiente capa
FIN: el HP del jugador llega a 0 (game over) o se completa la última capa (victoria)
```

## 5. Exploración

Grilla cenital de tiles. El jugador se mueve ortogonalmente un tile por turno. **Los turnos solo avanzan cuando el jugador toma una acción** (moverse, minar, interactuar). Inmóvil = pausado.

### 5.1 Tipos de tile
- **Piso** — transitable
- **Pared dura** — bloquea el movimiento de forma permanente
- **Roca minable** — ver §5.2
- **Shrine** — ver §7.5
- **Hard gate** — ver §5.3

### 5.2 Rocas minables
- Bloquean el movimiento hasta ser destruidas
- Cada roca tiene un valor de **dureza**. La capa *n* contiene rocas de dureza ≤ *n*.
- Minar una roca desde un tile adyacente cuesta 1 turno por hit. Una roca de dureza *h* requiere *h* hits para romperse. (Escalado lineal — revisitar si el pacing se siente grindy.)
- Tablas de drop (propuesto; tunear en playtest):
  - Nada (lo más común)
  - Minerales (tipados por facción — ver §7.2)
  - Pickup de salud
  - Una carta (se agrega directamente al mazo — ver §7.6)

### 5.3 Hard gate
Una pared de dureza *n+1* entre capas. El McGuffin que dropea el boss de la capa funciona como **llave**: interactuar con el gate teniéndolo gasta 1 turno y lo abre. Sin el McGuffin el gate no se puede romper.

### 5.4 Enemigos (en la grilla)
- Se mueven 1 tile por turno
- Comportamiento por default: random walk cada *k* turnos (propuesto *k* = 2)
- Al ver al jugador (line-of-sight): cambian a chase
- Al colisionar con el jugador: **dispara combate**
- Un solo tile de enemigo puede representar un **grupo** en combate. Chocar contra un tile de slime puede iniciar una pelea contra 1–3 slimes, al estilo EarthBound. Cada tipo de enemigo define sus posibles composiciones de grupo en combate.

### 5.5 Generación procedural
- Los niveles están hechos de **chunks** conectados por **spaghetti caves** (corredores angostos y serpenteantes)
- Chunks: prefabs hechos a mano con spawn points marcados. Scope de jam: ~5–10 chunks por capa.
- Spaghetti caves: tallado estocástico de un tile de ancho entre chunks
- El engine debe soportar un número arbitrario de capas; la cantidad final es TBD hasta que el juego se sienta bien.

## 6. Combate

El combate es una **pantalla separada** (estilo Slay the Spire). Sin grilla, sin posicionamiento.

### 6.1 Layout

```
+---------------------------+
|   ENEMIGO1   ENEMIGO2     |
|   HP 14      HP 9         |
|   intención: pegar 6      |
|                           |
|   HÉROE_A   HÉROE_B       |
|   HP 12     HP 8          |
+---------------------------+
 [c] [c] [c] [c] [c]
 HP 30
```

### 6.2 Estructura de turnos
- Turno del jugador → todos los enemigos actúan → repetir
- **Inicio de combate (antes del turno 1):** el **signature hero** (ver §7.7) se invoca automáticamente al campo, gratis. El jugador roba *N* cartas en el turno 1 (propuesto *N* = 5).
- **Cada turno siguiente:** el jugador roba **1** carta. La mano persiste entre turnos; **nada se descarta al final del turno.**

> **Fallback (si la mano persistente prueba ser muy lenta o muy combo-degenerada en playtest):** cambiar al patrón Slay the Spire — robar 5 al inicio de cada turno, descartar toda la mano al final del turno, reshufflear el descarte al mazo cuando se vacía.

### 6.3 Lo que el jugador puede hacer por turno
- Jugar **a lo sumo 1 carta de héroe** (invoca un héroe al campo)
- Jugar **a lo sumo 1 carta de acción por héroe en el campo** (las cartas de acción se juegan *a través de* un héroe específico; los pasivos del héroe y el efecto de la acción pueden interactuar)
- Jugar **cualquier cantidad de cartas de efecto** (los efectos resuelven independientemente de cualquier héroe)
- Terminar turno

**No hay costo de energía/maná.** El pacing viene del tamaño de la mano, la tasa de robo, el cap de 1 héroe por turno, el cap de 1 acción por héroe, y el descarte (cada carta de efecto solo puede jugarse una vez por ciclo de robo).

### 6.4 Héroes (en combate)
- Cada carta de héroe tiene **HP** y **Defensa**
- **La defensa es un umbral de daño por hit:** un hit ≤ Defensa es absorbido completamente por el héroe (resta del HP del héroe). Un hit > Defensa hace (hit − Defensa) de daño al héroe **y** el mismo overflow al HP del jugador.
- Los héroes **persisten entre combates** con su HP actual. Pueden curarse en shrines.
- Un héroe reducido a 0 HP es removido del campo. La carta **no se destruye** (el decay quedó cortado del scope de jam — ver §7.8). Pregunta abierta: ¿la carta vuelve al mazo reinvocable a HP completo, o requiere curación en shrine antes de reinvocarse? Elegir lo que produzca mejor pacing en el primer prototipo.
- Múltiples héroes pueden estar en el campo a la vez. No se propone cap duro; la composición del mazo limita esto naturalmente.

### 6.5 Enemigos (en combate)
- Una acción por enemigo por turno
- Los enemigos atacan **solo a héroes**
- Si no hay ningún héroe en el campo, los enemigos atacan al jugador directamente con **2× de daño**
- Las intenciones enemigas se telegrafían (estilo StS) para que el jugador pueda planear la defensa

### 6.6 HP del jugador
- Global a la run. HP inicial propuesto: **30**
- Se cura en shrines a cambio de minerales (costo TBD)

### 6.7 Fin de combate
- **Victoria:** todos los enemigos derrotados → recompensa = minerales (tipados por facción, tabla de drops por tipo de enemigo) + drops ocasionales de cartas
- **Derrota:** HP del jugador llega a 0 → game over, run termina

### 6.8 Combate de boss
Mismo sistema de combate. El boss tiene HP más alto (propuesto 2–3× un enemigo normal), un patrón de ataque único, y dropea un **McGuffin** además de minerales. La boss room no se puede skippear.

## 7. Cartas y mazos

### 7.1 Tipos de carta
1. **Héroe** — una unidad invocable con HP + Defensa + efecto(s) pasivo(s)
2. **Acción** — un efecto de combate jugado *a través de* un héroe en el campo; va al descarte después de jugarse
3. **Efecto** — un efecto de combate jugado independientemente de cualquier héroe; va al descarte después de jugarse

### 7.2 Facciones (tipos elementales)
Las cartas y minerales se reparten entre **4 facciones políticas** más **2 facciones neutrales-ish** (Apolíticos y Outsiders). La identidad mecánica de cada facción política es una parodia de cómo su contraparte real hace política — la fricción que el mazo crea *es* el chiste. Las dos facciones neutrales-ish existen fuera del griterío político pero juegan roles distintos en la run.

| Facción | Bloque real | Mineral | Arquetipo |
|---|---|---|---|
| Peronistas | Frente de Todos | **Peronite** | Sustain grupal, gateado por líder. La mayoría de héroes peronistas solo se activan mientras hay un héroe `[LEADER]` en el campo. |
| Libertarios | La Libertad Avanza | **Liberalite** | Burn y shutdown. Parálisis, veneno, cancelación de turno, debuffs. Muchas cartas le cuestan HP al jugador o destruyen las propias cartas del jugador para activarse. |
| Macristas | PRO | **Globite** | Ganancia de corto plazo, costo de largo plazo. Las cartas tienen efectos inmediatos potentes con downsides explícitos que se resuelven después en el mismo combate o al final del combate. |
| Izquierdistas | Frente de Izquierda y de los Trabajadores | **Zurdite** | Escalado lento. La mayoría de cartas tienen una condición de activación trivial (turno transcurrido, héroes invocados, cartas FIT en el campo) y escalan con la cantidad de cartas FIT en el campo. |
| **Apolíticos** | Figuras culturales / míticas / genéricas argentinas (no partidarias) | **Argentite** | Vanilla. Sin bono de sinergia, sin costos diferidos, efectos simples. El pool del mazo inicial / FTUE y el filler neutral. |
| **Outsiders** | Actores extranjeros con poder peligroso (FMI, mineras multinacionales, figuras tech-libertarias, gobiernos extranjeros) | **Xenite** | Cartas de alto poder con costos diferidos severos que pueden persistir *más allá* del combate o por el resto de la run. Sin sinergia de facción. Trampas tentadoras. |

> **Disciplina de diseño:** estos arquetipos son intencionalmente implementables usando *solo* texto de carta y affordances existentes — subtipos de héroe, activación condicional, efectos diferidos, escalado según estado del campo. **Sin nuevos sistemas de juego de cartas** (sin tokens de deuda, contadores de asamblea, stacks de inflación, stats de carisma). Si una carta te tienta a agregar una nueva mecánica global para soportarla, rediseñá la carta.

#### 7.2.1 Peronistas — "El Movimiento"
- Un tag de subtipo `[LEADER]` se imprime en el tope de ciertas cartas de héroe peronistas. El tag es solamente metadata leída por las condiciones de otras cartas peronistas.
- Los héroes peronistas no-líderes típicamente leen como *"Mientras un `[LEADER]` esté en el campo, este héroe gana +X / hace Y"*. Sin un `[LEADER]` vivo, son unidades vainilla mediocres.
- La roster de `[LEADER]` está intencionalmente desbalanceada en poder. Los líderes fuertes hacen volar a todo el mazo. Los líderes débiles hacen colapsar al mazo estilo Alberto.
- La mayoría de los mazos peronistas anclan en un `[LEADER]` como su signature hero (ver §7.7) para que el resto del mazo se active desde el turno 1. Designar un peronista no-`[LEADER]` como signature está permitido pero deja al mazo inerte hasta que se robe y se invoque manualmente un `[LEADER]` — usualmente una mala decisión, ocasionalmente una build interesante.
- *Lectura en clave de parodia:* el movimiento no tiene identidad sin el referente, y el referente no siempre es bueno.

#### 7.2.2 Libertarios — "Motosierra"
- Dos pilares, ambos expresados enteramente en texto de carta:
  - **Shutdown:** parálisis, veneno, cancelación de turno, debuffs single-target (e.g. *"El enemigo objetivo skippea su próximo turno"*, *"El enemigo objetivo recibe 2 de daño por turno durante 3 turnos"*).
  - **Auto-burn:** las cartas LLA fuertes le cuestan explícitamente HP al jugador, destruyen una carta del mazo, o sacrifican un héroe aliado (e.g. *"Hacé 12 de daño. Perdé 3 HP."*, *"Destruí una carta de tu mazo. Hacé daño igual al recycle value de esa carta."*).
- Stat profile de héroes LLA: ataque alto, defensa muy baja — glass cannons.
- *Lectura en clave de parodia:* el mazo se sierra a sí mismo literalmente para conseguir poder.

#### 7.2.3 Macristas — "PRO"
- Toda carta poderosa Macrista tiene su downside *impreso en la carta misma* como efecto diferido. Sin tokens, sin contadores — solo texto de carta.
  - *"Robá 3 cartas. Al final del combate, recibí 6 de daño."*
  - *"Invocá un héroe gratis. Ese héroe no puede ser curado por el resto de la run."*
  - *"Todos los aliados +2 daño este turno. El próximo turno, todos los aliados −2 daño."*
- La diferida es lo que crea la parodia: la cuenta siempre llega, solo que más tarde.
- Tempo de mediano alcance: funciona increíble en combates cortos, se cae a pedazos en peleas largas donde los costos diferidos se acumulan.
- *Lectura en clave de parodia:* tomar prestado contra el futuro, pagar después. Prosperidad financiada en Globite que se hipoteca a sí misma.

#### 7.2.4 Izquierdistas — "Las Condiciones Objetivas"
- Dos patrones, ambos solo en texto de carta:
  - **Activación condicional:** las cartas son inertes hasta que se cumple una condición trivial sobre estado existente. (*"Se activa después del turno 2."*, *"Se activa mientras haya al menos 2 héroes FIT en el campo."*, *"Se activa después de que un héroe haya muerto este combate."*)
  - **Escalado por estado del campo:** los números de payoff escalan con la cantidad de cartas/héroes FIT ya en juego. (*"Hacé 1 de daño por carta FIT jugada este combate."*, *"Cada héroe FIT en el campo gana +1 ataque."*)
- Los dos patrones combinan: setup por 2–3 turnos, después el mazo hace bola de nieve.
- *Lectura en clave de parodia:* la vanguardia espera las condiciones; teoría antes que acción; las masas llegan eventualmente.

#### 7.2.5 Apolíticos — "El Pueblo"
- Figuras culturales argentinas, figuras folclóricas/míticas, y arquetipos genéricos de fantasía minera — cualquiera ampliamente reconocido pero no alineado partidariamente. Evitar figuras con afinidad partidaria conocida (Maradona, Eva, Che, Menem, Bergoglio, etc. — esos van en cartas de facción).
- Los patrones de cartas son deliberadamente vainilla: stats claros, efectos simples, **sin bono de sinergia de facción**, **sin costos diferidos**.
- Roles en el loop:
  - Forman el **mazo inicial** para las primeras runs (FTUE) — ver §7.7
  - Aparecen en booster packs básicos / mixtos como filler
  - Proveen performance baseline confiable — nunca rotos, nunca peso muerto
- Pool de brainstorm (roster final TBD): El Minero, Messi, Mafalda, Gardel, Borges, Mercedes Sosa, Charly García, Favaloro, El Gaucho, La Pachamama, El Pombero, La Difunta Correa, El Linyera, San Martín, Belgrano.
- *Lectura en clave de parodia:* el sustrato cultural que existe debajo del griterío político — reconocible, querido, mayormente impotente.

#### 7.2.6 Outsiders — "Los de Afuera"
- Actores e instituciones extranjeros con poder predatorio: el **FMI**, mineras multinacionales (**Barrick Gold, Rio Tinto, Glencore**), figuras tech-libertarias (**Peter Thiel, Elon Musk**), gobiernos extranjeros, gestores de activos (**BlackRock, Vanguard**), etc.
- Cartas de alto poder con **costos diferidos severos que pueden persistir más allá del combate actual o por el resto de la run.** Esto es una extensión deliberada del patrón de costos diferidos macristas — los costos macristas resuelven dentro del combate; los costos Outsider pueden durar más.
- **Sin sinergia de facción.** Los Outsiders no se emparejan con `[LEADER]`, escalado FIT, auto-burn LLA, ni diferida PRO. Son spikes de poder aislados.
- Rareza: típicamente **Épica / Legendaria**. Se obtienen solo de booster packs de tier alto, pagados en **Xenite** (posiblemente mezclado con otros tipos de mineral — TBD).
- Patrones de carta de ejemplo (ilustrativos, no balanceados):
  - *FMI*: "Ganá 5 minerales inmediatamente. Al inicio de cada combate por el resto de la run, perdé 2 minerales."
  - *Peter Thiel*: "Revelá todas las intenciones enemigas por el resto del combate. Al final del combate, perdé 1 HP máximo permanentemente."
  - *Barrick Gold*: "Mineá toda roca del chunk actual instantáneamente. Destruí permanentemente una carta aleatoria de tu mazo."
  - *BlackRock*: "Ganá 1 de cada tipo de mineral. El próximo booster pack que compres cuesta el doble."
- *Lectura en clave de parodia:* los actores extranjeros que se benefician en serio de la ley de glaciares — los antagonistas literales de la sátira. Poder tentador, daño duradero. Cada carta Outsider es un pequeño pacto faústico.

### 7.3 Sinergia de facción
Las cartas de héroe y de acción tienen una facción. Las cartas de efecto son **neutras de facción** en el diseño propuesto (revisar si esto vuelve a las cartas de efecto demasiado one-size-fits-all).

Cuando una carta de acción se juega *a través de* un héroe de la **misma facción**, sus números potenciados se multiplican por **1.5×**. Los números elegibles para potenciación están marcados con una estrella (★) en el texto de la carta.

### 7.4 Rareza
Tiers propuestos (4): **Común / Rara / Épica / Legendaria**.
- Mayor rareza ⇒ números más fuertes, más hooks de sinergia, frecuentemente *requieren* sinergia para funcionar
- Mayor rareza ⇒ más valor en minerales al destruirse en un shrine
- Los booster packs de tier más alto (ver §7.5) tienen drop rates pesados hacia rarezas más altas
- *Solo scope futuro:* variantes EX / foil / UR de cartas existentes. Post-jam — demasiado trabajo de assets para 1 semana.

### 7.5 Shrines
Los shrines son un tile de exploración. En un shrine el jugador puede:
- **Comprar un booster pack** con minerales. Los packs vienen en tiers; capas más avanzadas desbloquean mejores packs que contienen más cartas y tienen mejores drop rates de raras, pero cuestan más. (Definiciones de tier TBD.)
- **Curar** HP del jugador y HP de héroes a cambio de minerales (costo TBD)
- **Destruir cartas del mazo** a cambio de minerales (las raras rinden más)

> *Racional del modelo de pack:* alimenta la fantasía de "lotería minera", escala naturalmente con la progresión, y permite tunear drop rates por tier de pack en lugar de por shrine.

### 7.6 Manejo del mazo
- **No existe inventario de cartas fuera del mazo.** Las cartas levantadas entran al mazo inmediatamente.
- **Cap de tamaño del mazo:** propuesto **30** (TBD — el draft original era 60; probablemente muy grande para runs de jam, validar en playtest).
- Si un pickup excede el cap, el jugador se ve forzado a destruir cartas hasta quedar bajo el cap. La destrucción forzada **no rinde minerales** — solo la destrucción voluntaria en shrines.
- El mazo se puede abrir y ver en cualquier momento durante la exploración.

### 7.7 Signature hero

Cada mazo tiene un **signature hero** — una carta de héroe que el jugador designó como ancla del mazo.

- Durante la exploración, el jugador puede abrir la **vista de manejo del mazo** y **cambiar la designación de signature a cualquier carta de héroe en su mazo**. Es una acción gratuita y se puede hacer en cualquier momento fuera de combate.
- Al **inicio de cada combate**, el signature hero es **invocado automáticamente al campo gratis**, antes del primer turno del jugador. El signature *no* se roba a la mano y *no* cuenta para el cap de 1-héroe-por-turno — el jugador todavía puede invocar un héroe adicional en el turno 1 normalmente.
- La carta de signature se mantiene fuera del mazo de robo de combate mientras está en el campo.
- El HP del héroe persiste entre combates (§6.4). El signature se auto-invoca a su HP actual al inicio de cada combate. Si está a 0 HP, no se puede auto-invocar (ver abajo).
- **Si el signature hero muere durante un combate, el combate continúa sin él** (sin reemplazo a mitad de combate, sin interrupción de UI). **Después de que el combate termina, el jugador es forzado a designar un nuevo signature** entre sus héroes restantes antes de poder reanudar la exploración. El nuevo signature toma efecto al inicio del próximo combate a su HP actual.
- Si toda carta de héroe en el mazo está a 0 HP, el mazo no tiene signature usable. Los combates entonces empiezan sin héroe en el campo — los ataques enemigos pegan al jugador directamente con 2× de daño (§6.5). Esto es intencional: la cascada de daño acelera una run que se está cayendo, poniendo presión real al jugador para llegar a un shrine antes de que todo colapse.
- El signature es el **ancla mecánica** del mazo. La mayoría de los mazos construye sinergias nicho a su alrededor (mazos peronistas alrededor de un `[LEADER]`, mazos FIT alrededor de una unidad de alto escalado, mazos LLA alrededor de un glass cannon, etc.). La progresión deseada es *"cada vez más locked-in a medida que el mazo mejora"* — las sinergias se vuelven más poderosas y más nicho a medida que el jugador se compromete con una build.
- **Designar un signature no-sinérgico siempre está permitido.** Un jugador peronista puede elegir un peronista no-`[LEADER]`; un jugador FIT puede elegir un héroe de bajo escalado. Las sinergias del mazo simplemente no funcionarán como diseñadas desde el turno 1. Es una elección del jugador, no una restricción de regla.

### 7.8 Decay de cartas (cortado del scope de jam)
El GDD original proponía: héroes destruidos a 0 HP, cartas de acción/efecto con use-counts, los shrines restauran. **Cortado para la jam.** Todas las cartas son reusables.

Si una versión post-jam reintroduce el decay, reglas candidatas: (1) héroes destruidos a 0 HP solamente; (2) use-counts de acción/efecto como un tier separado de cartas "frágiles". Aparcar esto hasta que el loop base se sienta bien.

## 8. Look & Feel

### 8.1 Pipeline de arte
- El arte de cartas debe ser generable **rápido** vía un pipeline **foto → ilustración**. Pipeline específico TBD (filtro / modelo de IA / template) — decidir el día 1 para que el artista no quede bloqueado.
- El texto de carta debe ser legible al tamaño más chico que tenga estando en mano — definir un tamaño mínimo de fuente temprano y aplicarlo.
- **La entrega visual sigue el tono de §3.2: artesanía seria sin importar lo absurdo del tema.** Una carta de héroe de Peter Thiel debería estar ilustrada con el mismo peso pictórico que una carta de San Martín — la cara reconocible en un retrato con frame heroico *es* el chiste. Evitar estilos de ilustración chistosos (mascotas cartoon, efectos doodle, sight gags como default) — reservar esos para los raros momentos donde el humor puntúa.

### 8.2 Identidad visual por facción
Cada facción recibe un color primario distintivo que matchea con el branding de su partido del mundo real:

- **Peronistas:** celeste
- **PRO (Macristas):** amarillo
- **LLA (Libertarios):** violeta
- **Izquierdistas:** rojo
- **Apolíticos:** gris claro metálico
- **Outsiders:** gris oscuro con textura rocosa / carbonosa

La iconografía y el lenguaje de silueta por facción son TBD; diferenciar más allá del color vía forma y motivo (e.g. PRO redondeado/corporativo, LLA filoso/agresivo, peronistas con imaginería de bandera-y-masa, Izquierda con obrero-y-bandera).

### 8.3 Feel por capa
Cada capa debería tener un feel visual distintivo (paleta, tile set, música). La cantidad de capas es TBD.

## 9. Notas técnicas para implementación

- **Las cartas son data, no clases.** Definir un schema de Resource de Godot (o JSON) temprano: `id`, `type`, `faction`, `rarity`, `recycle_value`, `effects[]`. Los efectos son un vocabulario pequeño y componible (hacer X de daño, curar Y, robar Z, invocar, buff, etc.) — no código a medida por carta.
- **Escenas separadas para exploración y combate.** El combate es una escena de Godot separada cargada al disparar el encuentro; el estado de la exploración se preserva.
- **Multi-input en web:** mouse + KB para desktop; tap = click y arrastre para cartas en touch. Hotkeys de teclado para terminar turno / abrir mazo / movimiento. Gamepad post-jam.
- **Generación procedural:** basada en chunks con escenas prefab de Godot, conectadas por un carver estocástico de un tile. No sobre-ingenierar el conector — 5–10 chunks más un walker tonto es indistinguible de procgen "real" en una run de jam corta.
- **Vertical slice primero.** Target del día 2–3: 1 capa, 1 tipo de enemigo, 1 héroe, ~5 cartas, loop completo de punta a punta incluyendo un shrine. Todo lo demás se construye sobre eso.

## 10. Preguntas abiertas / parking lot

Incógnitas explícitas que no bloquean empezar el prototipo. Resolver a medida que el prototipo revela qué se siente bien.

- Cantidad final de capas
- Valor final del cap del mazo (empezar en 30, tunear en playtest)
- Escalado de dureza de minería — ¿es `hits = dureza` lineal, o se ralentiza la minería tardía con otros costos?
- Fórmulas de costo de curación en shrines
- Catálogo de patrones de ataque de boss
- Tuning de balance de facciones después del primer prototipo de combate (los arquetipos están lockeados, los números no)
- Roster final de `[LEADER]` peronistas — lista, distribuciones de stats, sabor paródico por líder
- Roster final de Apolíticos — shortlist final para FTUE / pool de filler
- Roster de Outsiders + diseño de costos — qué tan duros deben ser los costos run-persistentes, y si Xenite solo alcanza para tirar Outsiders o si se requiere mix multi-mineral
- Si las cartas de efecto se quedan neutras de facción o se faccionan
- Si el signature hero es un fixed run-starter o desbloqueable entre runs
- Comportamiento de un héroe cuya carta vuelve al mazo a 0 HP (¿reinvocable a HP completo, o debe curarse primero?)
