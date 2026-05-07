# Glaciar Miner — Claude Code guide

Roguelike híbrido (dungeon crawler grid-based + deck-builder StS-style) en
Godot 4.6, target Web, hecho para un game jam.

## Documentos canónicos — leer antes de trabajar

| Doc | Qué contiene | Cuándo leerlo |
|---|---|---|
| [`GDD.md`](GDD.md) (EN) / [`GDD.es.md`](GDD.es.md) (ES) | Diseño completo del juego: pitch, factions, combate, exploración, cards, look & feel | **Cualquier cambio mecánico o de contenido.** Antes de crear/modificar cartas, enemigos, sistemas. |
| [Notion GDD](https://www.notion.so/GDD-3596a7adbf8c8054ae8ddf7fa95dfd48) | Misma fuente que el GDD local — mantenida en Notion. Accesible vía Notion MCP (`mcp__notion__notion-fetch`). | Para verificar que el GDD local esté al día con cambios recientes en Notion. |
| [`ROADMAP.md`](ROADMAP.md) | Estado actual + milestones (M1–M5) + parking lot post-jam | **Antes de empezar features.** Para entender qué está hecho, qué viene, y por qué. |
| [`ARQUITECTURA.md`](ARQUITECTURA.md) | Diagnóstico del estado del proyecto + plan de refactor (Cards as Resource, TileMap, etc.) | Cuando haya que decidir entre refactor o feature, o tocar render/scene structure. |
| [`DEVLOG.md`](DEVLOG.md) | Bitácora cronológica de sesiones + gotchas de Godot 4 ya cazados | Para no repetir bugs. **Leer la sección "Gotchas Godot 4"** antes de tocar input/Area2D/Controls. |
| `Glaciar Jam.pdf` | Concept doc original (pre-código) | Solo referencia histórica — el GDD lo supera. |

## Tech stack

- **Engine:** Godot 4.6, renderer GL Compatibility (para Web export)
- **Lenguaje:** GDScript con type hints estrictos
- **Target:** Web (KB+M, touch, mouse; gamepad post-jam)
- **Datos:** JSON por ahora (`data/cards/cards.json`); plan de migrar a `Resource .tres` (Parte A en `ARQUITECTURA.md`)
- **Entry point:** `scenes/exploration/exploration.tscn` (configurado en `project.godot`)
- **Autoload:** `RunState` (`scripts/run/run_state.gd`) — estado global de la run

## Estructura

```
scenes/
  exploration/exploration.tscn   ← entry point del juego
  test/card_test.tscn            ← scene de test del card engine
scripts/
  main.gd                         ← bootstrap del combat scene + HUD code-built
  card/                           ← card engine (data, view, tooltip, hand_manager, discard pile)
  combat/                         ← battlefield, combat_resolver, effect_executor, hero/enemy instances
  exploration/exploration_main.gd ← grid, tiles, rocks, shrines, enemy AI, HUD code-built
  run/                            ← run_state (autoload), world_state, mineral_bag
data/cards/cards.json             ← card schema (faction, rarity, recycle_value, tags, effect)
```

## Convenciones críticas

- **Idioma:** docs (DEVLOG, ROADMAP, ARQUITECTURA) y commits **en español**. Código y nombres de símbolos en inglés. Comentarios en español si aclaran *por qué*.
- **Arquitectura del card engine:** 3 capas separadas — `CardData` (datos puros) → `CardSlot` (anchor target) → `CardView` (visual que persigue al slot vía lerp). No mezclar.
- **UI code-built:** casi toda la UI hoy se construye en código (`Node.new()` + `add_child` + `_draw()`). Los `.tscn` están casi vacíos. Plan de refactor a scenes en `ARQUITECTURA.md` — **no migrar ad-hoc**, seguir el orden propuesto.
- **Effects son data, no clases.** Cada carta tiene `effect: { kind, params }`. Para sumar comportamiento nuevo, agregar un `kind` al vocabulario de `EffectExecutor`, no una clase nueva por carta.
- **Slay the Spire-ish, no StS exacto:** mano persistente, sin energy/mana, sin discard al fin de turno. Pacing por hand size + draw rate + caps por turno (ver §6 del GDD).
- **Tono del contenido:** parodia política argentina, **mostly played straight** — humor en el *contenido* (qué carta es), no en el *delivery* (cómo está escrita). Ver §3.2 del GDD antes de escribir card text.

## Gotchas Godot 4 ya cazados (no repetir — ver `DEVLOG.md` para detalle)

1. `Viewport.physics_object_picking` está en `false` por default — Area2D no recibe input sin esto.
2. `max`/`min`/`clamp`/`lerp` genéricos devuelven `Variant` y rompen `:=`. Usar `maxf`/`mini`/`clampf`/`lerpf` o métodos del tipo (`Vector2.lerp(...)`).
3. Controls con `mouse_filter = STOP` (default) **bloquean physics picking**. Cualquier ColorRect/Label decorativo necesita `mouse_filter = MOUSE_FILTER_IGNORE`.
4. Signal callbacks tienen que matchear la firma exacta — type-check estricto puede fallar silencioso.

## Cómo correr

Abrir el proyecto en Godot 4.6 y darle Play. Entry point `exploration.tscn`.
La scene `scenes/test/card_test.tscn` aísla el card engine para iterar sin
cargar combat/exploración (controles `SPACE`/`BACKSPACE`/`R`).

## Antes de cerrar una sesión

- Tildar `[x]` los items completados en `ROADMAP.md`
- Sumar entrada en `DEVLOG.md` con: hecho / bugs cazados / decisiones
- Actualizar el bloque "Estado actual" de `ROADMAP.md` si cambió la cobertura de algún sistema
