# Glaciar Miner — Contexto para Claude

Este archivo se mantiene actualizado para que una sesión nueva con Claude pueda
arrancar fría. Complementa los docs ya existentes:

- [`GDD.md`](GDD.md) / [`GDD.es.md`](GDD.es.md) — diseño completo
- [`ROADMAP.md`](ROADMAP.md) — milestones y orden propuesto
- [`ARQUITECTURA.md`](ARQUITECTURA.md) — refactor por partes
- [`DEVLOG.md`](DEVLOG.md) — bitácora histórica

---

## Estado al 2026-05-08

El loop completo de combate + exploración está cerrado (ver `ROADMAP.md`). La
sesión que acaba de terminar dejó dos frentes abiertos:

1. **Refactor pendiente:** Parte A de `ARQUITECTURA.md` (Cards as Resource).
   No arrancado todavía — sigue siendo el primer paso recomendado antes de
   crecer el roster de cartas en M4.
2. **Diseño de cartas pendiente:** la planilla `Referencia/Card Sheet - Glacial
   Miner.ods` tiene 42 líderes y 38 efectos con nombre + alineación + contexto
   histórico, pero **falta llenar las columnas mecánicas** (HP, Defensa, Effect).

---

## Lo que hay que decidir antes de seguir

### Decisión 1 — ¿Arrancar por Parte A (refactor) o por diseño de efectos?

Las dos cosas son trabajo del usuario + Claude. Trade-off:

- **Parte A primero:** te permite cargar cartas nuevas vía editor de Godot (con
  dropdowns y validación). Costo: ~1 hora juntos (Claude reescribe
  `card_data.gd`, script de migración JSON→`.tres`, `CardLoader` actualizado;
  el usuario verifica en el editor).
- **Diseño de efectos primero:** se llenan las celdas mecánicas de la planilla
  con efectos ya jugables. No bloquea nada porque los efectos se pueden
  expresar igual en JSON o en `.tres`.

**Recomendación de la sesión anterior:** arrancar por A — es el mejor uso del
tiempo antes de tener masa crítica de cartas.

### Decisión 2 — ¿Cómo manejar el campo `effect` en la nueva Resource?

Quedó sin resolver. Tres opciones (ver detalle en mensaje de la sesión
anterior, resumen acá):

1. **Dictionary plano** (`@export var effect: Dictionary`) — mínimo cambio,
   no rompe `EffectExecutor`, pero el editor sigue mostrando text/value sin
   tipos.
2. **CardEffect Resource único con enum Kind** — una clase nueva, dropdown del
   enum en el editor, `EffectExecutor` lee `card.effect.kind`.
3. **Una Resource por kind** — `DealDamageEffect`, `HealPlayerEffect`, etc. con
   polimorfismo. Más type-safe, más archivos.

### Decisión 3 — Falta facción `KIRCHNERIST` en el enum

El GDD §7.2.2 define 7 facciones; el código (`scripts/card/card_data.gd`)
tiene 6 (le falta KIRCHNERIST). La planilla del usuario sí incluye 7 líderes
kirchneristas (Capitanich, Soria, Wado, Tolosa Paz, Máximo, Di Tullio,
Alicia Kirchner), así que el enum hay que ampliarlo.

Nota: la sheet **no tiene cartas de Effect kirchneristas**. Es coherente
porque la mecánica K es deck-manipulation, y eso espera a que exista deck
formal (M2).

---

## Estado del diseño de cartas (de la planilla)

### Líderes (hoja "Líderes (Revision)") — 42 al MVP, R43+ descartables

Distribución por alineación, ordenados de la planilla:

| Facción | Líderes MVP | Ultra-raros / Líderes destacados |
|---|---|---|
| LLA | 12 | Bullrich (Ultra-raro, veleta), Milei (Ultra-raro), Menem (Raro) |
| Peronista | 8 | Jalil, Sáenz, Orrego (los tres como "Líder") |
| Kirchnerista | 7 | Capitanich (Raro), Wado (Raro) |
| Izquierda | 9 | Bregman (Ultra-raro), Maffei (Ultra-raro), del Caño (Raro) |
| PRO | 6 | Cornejo (Líder), Juez (veleta) |
| Neutral | 5 | (sin Ultra-raros) |
| Outsider | 6 | Barrick Gold (Ultra-raro), Peter Thiel (Ultra-raro) |

**Columna "Veleta?":** marca a quien cambió de bando. Propuesta de la sesión
anterior: implementar como tag `VELETA` que cuente como dos facciones para
synergy 1.5×.

### Efectos (hoja "Efectos") — 38 con nombre + contexto

Distribución: LLA 5, Peronista 6, Izquierda 5, PRO 3, Neutral 13, Outsider
5, Kirchnerista 0 (esperan deck formal).

---

## Qué efectos del GDD están implementables HOY vs. esperan features

| Mecánica del GDD | Estado código | Cuándo |
|---|---|---|
| `deal_damage`, `heal_player`, `heal_self`, `gain_minerals` | ✅ ya implementadas | hoy |
| Faction synergy 1.5× (★) | ✅ ya en `_deal_damage` | hoy |
| Sinergia LEADER tag | tag existe, sin reglas que lo lean | 1-2h código |
| Daño self / costo en HP del jugador | falta `RunState.damage_player` | 30 min |
| Skip enemy turn (debuff LLA) | sin state efímero de combate | M3 |
| Poison / DoT (LLA) | sin status effects | M3 |
| Sacrificio de héroe (Peronista) | sin UI de sacrificio | 1-2h |
| Deferred costs (PRO, Outsider) | sin end-of-combat trigger | M3 |
| FIT scaling (Izquierda) | sin contador "FIT en campo" | 1h post-M3 |
| Deck search / tutor (Kirchnerista) | sin deck formal | M2 |
| Draw N cards | sin deck/discard formal | M2 |

Ver `EffectExecutor` (`scripts/combat/effect_executor.gd`) para el vocabulario
actual y `ROADMAP.md` para qué hito habilita cada feature.

---

## Recomendaciones de la sesión anterior — efectos por facción

Muestras representativas (no exhaustivo). Detalle completo en historial de
chat de la sesión.

**LLA — Burn / shutdown / self-burn:**
- *Rocas Congeladas Inútiles*: `deal_damage 5`, perdés 2 HP del jugador. ★
  +50% si carrier es LLA. Hoy (con `damage_player`).
- *No Más Prohibicionismo*: `deal_damage 8`, destruye 1 carta random de mano. Hoy.
- *Marx Tenía Razón*: enemigo skip próximo turno. M3.

**Peronista — Clientelismo / cost paid to own side:**
- *Judicialización Inmediata*: gastás 3 Peronite, curás un héroe a full. Hoy.
- *Peronismo Minero*: hero activo pierde mitad HP, ganás esa cantidad en
  Peronite. Hoy.
- *No Se Toca... Pero*: si controlás hero `VELETA`, ★ `deal_damage 5`. Hoy.

**Izquierda — Scaling lento / conditional:**
- *El agua vale más que el oro*: cura jugador 2 HP ★ por cada Izquierdista en
  campo. Espera M3 (counter).
- *"Glaciares No Se Toca"*: si pasaron ≥2 turnos en este combate,
  `deal_damage 6`. Espera M3 (turn counter).
- *Caos en Audiencias*: si hay ≥3 enemigos, `deal_damage 3` a todos. Espera
  encounter groupings (M3).

**PRO — Deferred costs:**
- *Previsibilidad de Inversiones*: ganás 5 Globite, fin de combate −3 HP del
  jugador. Espera M3.
- *Azul y Violeta*: `deal_damage 8`, próximo turno no podés invocar. Espera M3.
- *Equilibrio Realista*: `deal_damage 4`, `heal_player 4`. Hoy (kind compuesto).

**Apoliticales / Neutrales — Vainilla:**
- *17.000 Glaciares*: `gain_minerals APOLITICAL 4`. Hoy ✅
- *La Ciencia*: `heal_player 3`. Hoy ✅
- *Litio*: `gain_minerals random_faction 2`. Hoy (kind `gain_minerals_random`).
- *Perito Moreno*: `heal_self 6`. Hoy ✅

**Outsider — Power spike + costo run-persistente:**
- *Inversiones*: ganás 1 mineral de cada tipo. Próxima compra en shrine ×2
  caro. Espera M2.
- *Extractivismo*: destruye una roca del mapa al jugar; fin de combate
  destruye carta random de deck. Espera M3.
- *Tecnofeudalismo*: revela intents enemigos; costo: −1 max HP permanente.
  Espera M3.

**Líderes destacados (HP/Def/pasiva):**
- Milei (LLA) 4/1 — invocación: enemigos −2 HP, jugador −2 HP. Hoy con
  `summon_burn`.
- Bullrich (LLA, veleta) 5/3 — cuenta como Peronista para synergy. Hoy con
  tag VELETA.
- Bregman (Izquierda) 3/4 — ★ daño +1 por cada hero Izquierdista. M3.
- Maffei (Izquierda) 2/5 — invocación: +5 HP jugador; +5 más si ≥2
  Izquierdistas. Hoy con `summon_heal_player`.
- Barrick Gold (Outsider) 7/4 — invocación: +5 Xenite; fin de combate −1 max
  HP permanente. Espera M3.
- Peter Thiel (Outsider) 4/2 — revela intents resto del combate; fin de
  combate −2 max HP permanente. Espera M3.

---

## Cómo arrancar la próxima sesión

1. **Decidir las tres preguntas abiertas** (Decisión 1, 2 y 3 arriba).
2. Para retomar diseño de cartas, abrir las hojas `Líderes (Revision)` y
   `Efectos` de la planilla `.ods` y empezar a llenar columnas mecánicas
   facción por facción, priorizando efectos jugables hoy.
3. Para retomar refactor (Parte A), arrancar por reescribir
   `scripts/card/card_data.gd` extendiendo Resource y migrar las 8 cartas
   actuales de `data/cards/cards.json` a `data/cards/<id>.tres`.
4. **Reservado al usuario:** FTUE deck Apolítico (no implementarlo Claude).

---

## Convenciones del proyecto

- Engine: **Godot 4.6**, target Web (KB+M, touch, gamepad).
- Idioma de docs y comentarios: **español**.
- Datos de cartas hoy: JSON en `data/cards/cards.json` (post-Parte A: `.tres`
  por carta).
- Lógica de juego: GDScript con tipado estricto. Usar `maxf`/`mini`/`clampf`
  (no `max`/`min`/`clamp` genéricos — devuelven Variant y rompen inferencia).
- Cartas como Node2D + `_draw()` (no Control). Cualquier Control de
  decoración necesita `mouse_filter = MOUSE_FILTER_IGNORE` o bloquea el
  physics picking.
- Disciplina del GDD §7: no inventar mecánicas globales nuevas. Si una carta
  tienta a agregar un sistema (debt tokens, charisma stats, etc.), redesign
  the card.

---

## Comandos útiles

```powershell
# Abrir el proyecto en Godot
godot --path "F:\WORK STUFF\Proyectos de Juegos\Godot\2026\Glaciar Miner"

# Estado del repo
cd "F:\WORK STUFF\Proyectos de Juegos\Godot\2026\Glaciar Miner"
git status -sb

# Rama de trabajo actual: pulido-deck-game-screen
# Rama estable: main
```
