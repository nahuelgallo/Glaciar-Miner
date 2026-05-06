# Glaciar Miner — Devlog

Bitácora de avance del proyecto. Las sesiones se apilan al final; el bloque
"Estado actual" arriba se mantiene actualizado para que una sesión nueva pueda
arrancar fría.

---

## Estado actual

**Proyecto:** roguelike híbrido dungeon-crawler + deckbuilder en **Godot 4.6**,
target **Web** (KB+M, touchscreen, mouse, gamepad). Concept doc original en
`Glaciar Jam.pdf`. Pensado para jam de 2 semanas.

**Etapa:** motor de cartas inicial. La lógica de combate, exploración por grilla
y minado todavía no se empezó — estamos puliendo la interacción de mano y
puede iterarse en aislamiento antes de meter sistemas más grandes.

**Lo que ya funciona:**
- Carga de cartas desde JSON (`data/cards/cards.json`)
- Mano con layout recto (estilo Balatro), animada con lerps frame-rate-independent
- Hover lift + scale, drag con tilt velocity-based
- Tooltip con detalle (nombre, tipo, facción, rareza, descripción, stats)
- Add/remove de cartas en runtime con relayout animado

**Cómo correr:** abrir el proyecto en Godot 4.6 y darle Play.
La escena `scenes/test/card_test.tscn` carga 5 cartas random; controles:
- `SPACE` — agrega una carta random
- `BACKSPACE` — saca la última carta
- `R` — reset (vacía y vuelve a poner 5 random)
- Hover sobre una carta — lift + tooltip
- Click + drag — arrastra con tilt según velocidad

---

## Arquitectura del card engine

Tres capas separadas que se comunican por interpolación. Inspirada en el
approach de Balatro ("just tweens and lerps. Separate the visuals and the
actual game objects").

```
CardData (RefCounted, parsed from JSON) ──▶ datos puros (sin nodos)
        │
        ▼
CardSlot (Node2D anchor, child de HandManager) ──▶ posición/rotación TARGET
        │
        ▼
CardView (Node2D + Area2D + Labels) ──▶ visual que persigue al slot vía lerp
```

**Por qué así:**
- Reordenar la mano = recalcular slots; los views animan gratis hacia su nuevo
  destino.
- La lógica de combate puede correrse sin instanciar un solo nodo visual
  (testing, simulación, headless).
- Drag/hover viven solo en CardView. La mano (qué cartas, en qué orden) vive
  solo en HandManager.

**Comunicación visual → manager** vía signals:
- `CardView.hover_started(view)` y `CardView.hover_ended(view)` →
  HandManager los conecta para mostrar/ocultar tooltip.

---

## Modelo de datos (`scripts/card/card_data.gd`)

Cartas parseadas desde JSON en runtime — `CardData.from_dict(d)`. Schema:

| Campo | Tipo | Notas |
|---|---|---|
| `id` | StringName | identificador único |
| `card_name` | String | nombre visible |
| `type` | enum `Type` | HERO / ACTION / EFFECT |
| `faction` | enum `Faction` | NONE / PERONIST / LIBERTARIAN / MACRIST / LEFTIST / APOLITICAL / OUTSIDER (GDD §7.2) |
| `rarity` | enum `Rarity` | COMMON / RARE / EPIC / LEGENDARY |
| `hp`, `defense` | int | solo para héroes |
| `recycle_value` | int | minerales que rinde al destruirse en shrine (GDD §7.5) |
| `tags` | Array[StringName] | metadata por carta. Convención: uppercase. Ej: `LEADER` (constante `CardData.TAG_LEADER`) |
| `description` | String | texto del tooltip |
| `art_path` | String | placeholder, todavía no se renderiza |

**Notas de diseño:**
- Las cartas Effect son neutrales (`faction = NONE`) por GDD §7.3.
- `recycle_value` reemplazó al sistema previo de `max_uses`. Si más adelante
  se reintroduce decay por usos, hay que volver a sumar campos.
- `tags` permite metadata sin agregar columnas — el uso actual es `LEADER`
  para cartas peronistas que habilitan condiciones tipo "mientras un LEADER
  esté en el campo, …". Es texto, no un sistema nuevo.

---

## Visualización (`scripts/card/card_view.gd`)

- **Fondo del cuerpo de la carta** = color de la facción (paleta GDD §8.2):
  - PERONIST → celeste
  - LIBERTARIAN → violeta
  - MACRIST → amarillo
  - LEFTIST → rojo
  - APOLITICAL → gris claro metálico
  - OUTSIDER → gris carbón
  - NONE / Effects neutrales → beige
- **Borde** = color por tipo (HERO=marrón / ACTION=dorado / EFFECT=verde menta).
  Permite distinguir tipo aun cuando dos cartas comparten facción.
- **Banda inferior** con stats (HP/DEF para héroes, "ACCIÓN"/"EFECTO" para los
  otros tipos).

Los visuales del cuerpo de carta se dibujan en `_draw()` directamente — no hay
sprite todavía. Cuando entren ilustraciones (`art_path`), se reemplaza el
`draw_rect` del fill por un `draw_texture_rect`.

---

## Tooltip (`scripts/card/card_tooltip.gd`)

Node2D con `_draw()` para el panel y Labels (con `mouse_filter = IGNORE`)
para el texto. Muestra:

```
NOMBRE
Tipo · Facción · Rareza
descripción del efecto

stats (HP/DEF para héroes, recycle_value para acciones/efectos)
```

Posicionado por HandManager `tooltip_offset` debajo del slot de la carta
hovered, centrado en x.

---

## Estructura de archivos

```
project.godot
icon.svg
Glaciar Jam.pdf                       ← concept doc original
DEVLOG.md                             ← este archivo
data/cards/cards.json                 ← schema actual (faction, rarity, recycle_value)
scenes/test/card_test.tscn            ← escena de test del card engine
scripts/main.gd                       ← bootstrap del test (input keys)
scripts/card/card_data.gd             ← modelo de datos + parser JSON
scripts/card/card_loader.gd           ← lee data/cards/cards.json
scripts/card/card_view.gd             ← visual Node2D + Area2D + signals hover
scripts/card/card_tooltip.gd          ← panel de detalle
scripts/card/hand_manager.gd          ← orquesta slots, views, tooltip y layout
```

---

## Variables tunables (sin tocar código)

**HandManager** (en el inspector del nodo en `card_test.tscn`):
- `hand_width` (720) — ancho máximo antes de comprimir cartas
- `card_spacing` (110) — separación ideal cuando entran cómodas
- `tooltip_offset` ((0, 100)) — desplazamiento del tooltip respecto al slot

**CardView** (defaults sensibles, se setean por instancia o vía script):
- `follow_speed` (18) — qué tan rápido la carta persigue al slot
- `hover_scale` (1.18) — cuánto crece al hacer hover
- `hover_lift` (-45) — cuánto se levanta al hover
- `drag_follow_speed` (26) — velocidad de seguimiento al mouse
- `tilt_strength` (0.0009) — rotación según velocidad de drag
- `max_drag_tilt` (0.55) — tope de rotación en drag (radianes)
- `tilt_smoothing` (22) — suavizado del tilt durante drag

---

## Gotchas Godot 4 que ya pateamos (no repitamos)

1. **`Viewport.physics_object_picking` es false por default.** Sin activarlo,
   los Area2D de las cartas no reciben mouse events. Activado en
   `scripts/main.gd:_ready()`.

2. **Funciones matemáticas genéricas devuelven Variant.** `max`, `min`,
   `clamp`, `lerp` rompen la inferencia con `:=`. Usar las tipadas:
   `maxf`/`maxi`, `minf`/`mini`, `clampf`/`clampi`, `lerpf`/`lerpi`. Para
   vectores usar el método (`Vector2.lerp(...)`).

3. **Controls con `mouse_filter = STOP` (default) bloquean el physics
   picking.** Los eventos GUI tienen prioridad: si un Control consume el
   evento, los Area2D nunca se enteran. Cualquier Control de decoración
   (ColorRect de fondo, Labels overlay) necesita
   `mouse_filter = MOUSE_FILTER_IGNORE` (valor 2 en .tscn). Especialmente
   peligroso con ColorRects fullscreen.

4. **Las firmas de signal callbacks deben matchear exacto.** `Area2D.input_event`
   envía `Node`, no `Viewport` — aunque `Viewport extends Node`, el type-check
   estricto puede fallar silenciosamente.

---

## Pendiente / abierto

**Card engine (corto plazo):**
- Animación de "carta jugada" (sale del slot hacia el play area)
- Animación de "carta destruida" (poof + queue_free después)
- Variantes EX/foil/UR (visual diferenciado, GDD)
- Multi-touch / gamepad para selección/drag (target plataforma Web requiere los 4 inputs)
- Decisión sobre re-introducción de decay por usos (queda anotado en GDD como "a definir")

**Sistemas grandes que todavía no existen:**
- Modelo de combate por turnos (héroes invocados, HP global del player, ataques enemigos)
- Estado de mazo / draw / discard piles
- Generación procedural de dungeons por chunks + spaghetti caves
- Movimiento por grilla en exploración (turnos avanzan al moverse)
- Shrines (pull cartas, recycle cartas)
- Boss rooms + hard gates entre layers
- Persistencia de run (HP del player carrea, héroes con HP entre combates)

**Look & feel sin definir:**
- Pipeline de generación de arte de cartas (foto → ilustración rápida)
- Tipografía
- VFX/SFX

---

## Sesiones

### 2026-05-04 — Setup + card engine v0

Primer día de código. Antes solo había `Glaciar Jam.pdf`.

**Hecho:**
- Project setup Godot 4.6 (renderer GL Compatibility para Web export, viewport
  1280×720, picking habilitado).
- `CardData` con parser desde JSON. **Expansión hecha durante la sesión:**
  schema crecido a `faction`/`rarity`/`recycle_value`/`tags` para alinear con
  GDD §7.x (las facciones políticas, sistema de reciclaje en shrines, tag
  LEADER para sinergias peronistas).
- `CardLoader` lee `data/cards/cards.json` y construye `Array[CardData]`.
- `CardView` (Node2D) con: `_draw()` de cuerpo + borde, Labels de nombre y
  stats, Area2D para input, signals `hover_started`/`hover_ended`. Color de
  fondo = facción (paleta GDD §8.2), color de borde = tipo de carta.
- `HandManager` con slots Node2D + views, layout recto (`_card_pose` versión
  Balatro: línea horizontal, span con clamp en `hand_width`, sin rotación
  ni arco — se probó arco antes pero se descartó a pedido).
- `CardTooltip` Node2D con panel custom + Labels (mouse_filter IGNORE).
  Muestra "Tipo · Facción · Rareza", descripción y stats / recycle_value.
- Lerps frame-rate-independent en CardView (`1 - exp(-speed * delta)`),
  hover lift + scale, drag con tilt velocity-based.

**Bugs cazados (en orden cronológico):**
1. Inferencia rota por `max()` y `clamp()` genéricos → cambio a
   `maxf`/`clampf` y tipado explícito.
2. Hover y click no funcionaban → `Viewport.physics_object_picking` estaba
   en false; activado en `main.gd`.
3. Hover seguía sin funcionar → el `Background` ColorRect fullscreen
   (mouse_filter STOP por default) absorbía todos los eventos antes del
   physics picking. Solucionado con `mouse_filter = IGNORE` en background,
   help label y los Labels internos de CardView/CardTooltip.

**Decisiones tomadas:**
- Datos en JSON (no Resource `.tres`) — pipeline de generación masiva más
  fácil. Trade-off: sin autocompletado en el editor de Godot.
- Cartas como Node2D (no Control) — libertad de transform, mejor para
  shaders eventuales. Trade-off: input por Area2D, no Theme automático.
- Arquitectura 3 capas (data / slot / view) con lerps — base para todo lo
  que venga.
- Layout descartado: arco / fan estilo Hearthstone. Decisión: recto estilo
  Balatro. La función `_card_pose` es trivial swap si se quiere volver.
