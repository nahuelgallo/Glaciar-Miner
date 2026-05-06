# Glaciar Miner — Plan de refactor arquitectónico

Este doc evalúa cómo está construido el proyecto hoy, en qué te limita, y
qué refactor conviene (y cuál no) antes de seguir agregando features.
Complementa [`ROADMAP.md`](ROADMAP.md).

---

## Diagnóstico honesto del estado actual

Las primeras tres jornadas optimicé velocidad de iteración a costa de
**editor-friendliness**. Casi todo lo visual se construye en código vía
`Node.new()` + `add_child` desde `_ready`, y se dibuja con `_draw()`
manualmente. Las escenas `.tscn` están casi vacías.

### Qué hay code-built (problema)

| Cosa | Dónde vive | Cómo modificarla hoy |
|---|---|---|
| Carta visual | `card_view.gd` con `_draw()` + Labels manuales | Editar GDScript |
| Tooltip | `card_tooltip.gd` con `_draw()` + Labels manuales | Editar GDScript |
| Discard pile | `discard_pile_view.gd` con `_draw()` | Editar GDScript |
| Enemy view | `enemy_view.gd` con `_draw()` | Editar GDScript |
| Hero field view | `hero_field_view.gd` con `_draw()` | Editar GDScript |
| Battlefield layout | `battlefield.gd` (positions hardcoded) | Editar GDScript |
| HUD del combate | construido en `main.gd._build_hud()` | Editar GDScript |
| HUD de exploración | construido en `exploration_main.gd._build_hud()` | Editar GDScript |
| Tiles de exploración | `_draw()` por tile en `exploration_main.gd` | Editar GDScript |

### Qué hay scene-built / data-driven (bien)

| Cosa | Cómo está | Valor |
|---|---|---|
| `card_test.tscn` | Mínima: Background + HandManager + Help label | OK pero podría tener todo |
| `exploration.tscn` | Solo el root | Casi vacía |
| Cartas (datos) | `cards.json` parseado a `CardData` | Bulk editing fácil |
| Lógica de combate | `CombatResolver`, `EffectExecutor`, `WorldState` | Código puro, está bien así |
| Estado de run | `RunState` autoload | Está bien así |

### Qué te impide eso

- No podés abrir una carta en el editor y ver cómo se va a renderizar
- No podés mover un slot del battlefield arrastrando en la vista 2D
- No podés pintar el mapa con pinceles ni swap tilesets por capa
- No podés cambiar fuentes/colores desde un Theme resource — son
  `add_theme_*_override` repartidos por todo el código
- Cuando entre el pipeline de arte (§8.1), todo `_draw()` con `draw_rect`
  hay que reemplazarlo por sprites — y eso es código en cada lugar
- No podés agregar variantes (cartas EX, foil §7.4) sin tocar lógica de render

---

## Cómo debería ser (Godot idiomático)

| Cosa | Patrón correcto | Por qué |
|---|---|---|
| Cartas | `card.tscn` con Sprite2D + Label + Panel + Area2D | Arte swappable, exports tunable en editor |
| Datos de carta | `Resource` (`.tres`) con `@export` por campo | Type-safe, editable visualmente. JSON queda como import opcional |
| Enemigos visuales | `enemy_view.tscn` con AnimatedSprite2D + Label | Animaciones idle/hit en editor |
| Tiles del dungeon | `TileMap` + `TileSet` resource | Pintás con pinceles, paletas por capa = swap del TileSet |
| HUD | Scenes con `MarginContainer` / `VBoxContainer` | Layout responsive sin matemática manual |
| Estilos | `Theme` resource (`theme.tres`) | Fonts/colors/font_sizes centralizados |
| Layouts del battlefield | `battlefield.tscn` con Marker2D nodes en posiciones | Mover slots arrastrando |
| Lógica del juego | GDScript (como ahora) | No tiene que ir a scene |

---

## Refactor por partes

Cada parte es testeable independientemente. Orden: alto impacto + bajo
riesgo primero. Tiempos estimados *en horas reales con vos manejando el
editor* (yo escribo el código, vos hacés clicks en Godot).

### Parte A — Cards como `Resource` 🔥

**Por qué primero:** M4 del ROADMAP va a crear decenas de cartas. Si las
hacés con el sistema actual (entries en JSON), después migrar es doloroso.
Migrando ahora ganás autocomplete, type checking y editor visual *antes*
de tener masa crítica de cartas.

- Reemplazar `card_data.gd` (que extiende `RefCounted`) por
  `extends Resource` con `@export var faction: Faction`, `@export var hp: int`, etc.
- Cada carta queda como `data/cards/<id>.tres`.
- `CardLoader` cambia: en vez de parsear JSON, hace
  `load("res://data/cards/<id>.tres")` para cada uno, o un `dir.list` masivo.
- Las cartas existentes se migran una vez (script o a mano).
- **Coexistencia con JSON:** opcional, podés mantener JSON como fuente
  para bulk imports y un script de "JSON → .tres" en el editor.

**Lo que ganás:** abrís una carta en Godot, ves los exports, cambiás
`amount` o `faction` con dropdown, guarda. Sin reabrir Godot. Sin tocar
código de carta.

**Costo:** migrar las 8 cartas actuales (~30 min). Reescribir CardLoader
(~15 min).

### Parte B — TileMap para exploración 🔥

**Por qué pronto:** §8.3 del GDD pide *layer feel* distinto por capa
(palette + tile set + música). Sin TileMap, hacer eso requiere reescribir
`_draw()` por capa. Con TileMap, swap de TileSet resource y listo.

- Crear `tilesets/dungeon_layer1.tres` con celdas para FLOOR / WALL /
  ROCK / SHRINE / HARD_GATE
- En `exploration.tscn` agregar un `TileMap` node
- `WorldState` queda igual a nivel de datos. El TileMap lee de
  `WorldState.tiles` para pintar (un loop al cargar la escena).
- Eliminar el `_draw()` de tiles en `exploration_main.gd`
- Las rocas y shrines siguen siendo dicts en `WorldState` (datos), pero
  se *pintan* via TileMap. Cuando la roca se rompe, se actualiza el cell
  del TileMap a FLOOR.

**Lo que ganás:** podés pintar mapas en el editor en vez de hardcodearlos
en `_generate_default()`. Para §5.5 procgen real esto es la base.

**Costo:** crear el TileSet con sprites placeholder (~1 hr — incluso
con cuadrados de colores como ahora, pero asignados a cells). Reescribir
el draw de tiles (~30 min).

### Parte C — Card scene `.tscn` 🟡

**Por qué intermedio:** el `_draw()` actual *funciona*. Migrar a scene
con sprites es mucho trabajo y solo paga cuando entre el pipeline de
arte (§8.1). Recomendación: posponer hasta tener arte real para meter.

- `card.tscn`: Panel root + Sprite2D para arte + RichTextLabel para
  texto + Area2D para input
- `card_view.gd` queda como script del scene root, mantiene drag/hover
- Cards existentes leen el sprite via `data.art_path`

**Lo que ganás:** posicionás los elementos de la carta arrastrando en
el editor. Cambiás la fuente vía Theme.

**Costo:** ~3-4 hrs de trabajo en el editor.

### Parte D — Theme global 🟡

**Por qué intermedio:** los colores/fuentes están repartidos en cada
`add_theme_*_override`. Centralizar es polish.

- Crear `theme.tres` con tipografía, colores principales, defaults para
  Label / Panel / Button
- Aplicarlo en root scenes
- Ir borrando los `add_theme_*_override` a medida que el Theme cubre
  el caso

**Lo que ganás:** cambiás la fuente del juego entero desde un solo lugar.

**Costo:** ~1-2 hrs.

### Parte E — Enemy / Hero scenes 🟢

**Por qué último:** lo mismo que con cartas, el `_draw()` funciona. Solo
es ganancia con arte real.

- Análogo a Parte C pero para `enemy_view` y `hero_field_view`

**Costo:** ~1-2 hrs cada uno.

---

## Qué refactor SÍ y qué refactor NO antes del jam

Tenés ~4 días. Brutal:

### SÍ hacer antes de M1
- **Parte A (Cards as Resource)** — paga inmediato, te ahorra retrabajo
  cuando agregues el roster de M4
- **Parte B (TileMap)** — paga al hacer M1 boss room / hard gate /
  layers, porque podés pintar variantes en el editor

### NO hacer durante el jam
- **Parte C (Card scene)** — esperá a tener arte. El rect actual sigue
  comunicando bien: facción por color, tipo por borde, LEADER tag visible.
- **Parte D (Theme)** — quick win pero no es bloqueante
- **Parte E (Enemy/Hero scenes)** — ídem C

Hacer C/D/E ahora consume 6-9 horas que mejor van a M1 (boss + layers) y
M4 (contenido). Post-jam, son refactors limpios.

---

## Plan revisado (combinado con ROADMAP)

Orden propuesto:

1. **Parte A: Cards as Resource** ⏱ ~1 hr (yo + vos)
2. **Parte B: TileMap para exploración** ⏱ ~1.5 hr (yo + vos)
3. **M1 del ROADMAP**: boss + McGuffin + hard gate + layer transition
4. **M2 del ROADMAP**: booster packs en shrines
5. **M3 del ROADMAP**: factions con peso (synergy + signature + HP carryover)
6. **M4 del ROADMAP**: contenido (vos + yo)
7. **M5 del ROADMAP**: polish + Parte D (theme) si hay tiempo
8. **Post-jam**: Partes C, E, F (procgen real, etc.)

---

## Recomendación inmediata

**Hacé Parte A primero.** Es la más urgente y la más barata. Te toma una
hora, te ahorra horas de migrar cartas en M4. La hacemos juntos:

1. Yo reescribo `card_data.gd` para extender Resource
2. Yo escribo un script de migración que convierte `cards.json` → `.tres`
3. Yo actualizo `CardLoader` para leer `.tres`
4. Vos verificás en el editor que las cartas existentes se ven bien

Una vez ahí, **Parte B** o **M1** según preferencia. M1 es más excitante
(cierra el macro loop), B es más estructural.

¿Arrancamos por A?
