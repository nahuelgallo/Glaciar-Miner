# Glaciar Miner — Roadmap

Plan de trabajo del proyecto. Complementa:
- [`GDD.md`](GDD.md) / [`GDD.es.md`](GDD.es.md) — diseño completo
- [`DEVLOG.md`](DEVLOG.md) — bitácora de sesiones

Este doc se mantiene actualizado con cada cierre de hito. Si una sección queda
desfasada de la realidad, actualizar antes de seguir codeando.

---

## Estado actual (2026-05-06)

El **loop completo está cerrado de punta a punta**: exploración top-down →
bump enemigo → combate Slay-the-Spire-ish → victoria/derrota → vuelta a la
exploración con el state preservado. Tres días de código.

### Sistemas en pie

| Sistema | Cobertura | Notas |
|---|---|---|
| Card engine | ✅ funcional | Data en JSON, drag-to-target con global drop owner, discard pile visible |
| Schema GDD de cartas | ✅ migrado | `Faction` (6) + `Rarity` (4) + `tags` (LEADER) + `recycle_value` + `effect` (kind/params) |
| Vocabulario de efectos | ✅ mínimo | `deal_damage`, `heal_player`, `heal_self`, `gain_minerals`. `draw_cards` y `skip_turn` esperan al deck/turnos |
| Combate §6 | ✅ funcional | Turnos `T`, intent telegrafiada §6.5, defensa con overflow §6.4, mano persistente cap 7, draw 1 al inicio del turno |
| Exploración §5 | ✅ funcional | Grid 16×11, paredes, rocas con dureza §5.2 + drop table, shrines mínimo §7.5, random walk §5.4 |
| WorldState | ✅ persistente | Tiles, enemigos, rocas, shrines viven en `RunState.world` y sobreviven cambios de escena |
| Handoff exploración ⇄ combate | ✅ funcional | `pending_combat_enemy_ids` + `last_combat_outcome` (VICTORY/DEFEAT/ABORTED) |
| HUD | ✅ mínimo | HP, héroe, último ataque, minerales, turn counter en combate; HP + minerales + último evento en exploración |

### En el GDD pero todavía no implementado

| Sección GDD | Qué falta |
|---|---|
| §3.2 tono | Sin contenido de cartas serias todavía — depende de M4 |
| §4 macro loop | Sin boss, sin McGuffin, sin hard gate, sin transición de capa |
| §5.3 hard gate | Tile type no existe |
| §5.4 encounter groupings | Hoy 1 enemigo por bump, no 1-3 |
| §5.4 line-of-sight chase | Solo random walk |
| §5.5 procgen | Mapa hardcoded; sin chunks ni spaghetti caves |
| §6.4 hero HP carryover | Cada combate spawnea héroe fresh — no hay roster persistente |
| §6.4 múltiples héroes en el campo | Hoy un solo hero slot |
| §6.8 boss combat | No existe |
| §7.3 faction synergy 1.5× | Schema lo soporta (★) pero no está aplicado en `deal_damage` |
| §7.5 booster packs | Shrines solo curan, no venden cartas |
| §7.5 recycle cards | No implementado |
| §7.6 deck management real | Sin deck/discard piles formales — solo "mano que se rellena random" |
| §7.7 signature hero | El héroe activo es "el primero del pool" en lugar de uno designado |
| §8.1 art pipeline | Sin pipeline foto→ilustración; cartas son rectángulos coloreados |
| §8.3 layer feel | Sin paletas distintivas por capa |
| FTUE roster | Reservado por el usuario como tarea propia (memoria persistida) |

---

## Milestones

Orden propuesto. Cada milestone produce un build *probable* y *jugable*.

### M1 — Macro loop con meta (closes §4)

**Por qué primero:** hoy el jugador limpia los enemigos de la única sala y
no pasa nada. Sin meta visible, no hay tensión ni progresión. Es el paso que
más cambia la sensación de "esto es un juego" vs. "esto es una test scene".

- [ ] Boss room §6.8 — tile especial al fondo del mapa, encuentro con boss de stats elevados (2-3× HP de un slime, intent más alto) y una recompensa garantizada de minerales
- [ ] McGuffin §5.3 — flag en `RunState` (`has_mcguffin: bool`), drop garantizado al ganar boss
- [ ] Hard gate §5.3 — tile que solo se rompe con `has_mcguffin`. Visual: pared con icono de cerrojo
- [ ] Transición de capa — al cruzar el hard gate, regenerar el world con `_generate_layer(n+1)`. Stats de enemigos y rocas escalados
- [ ] Layer indicator — label en HUD "Capa 1 / 2 / 3"
- [ ] End condition — al limpiar la última capa (definir N en playtest), pantalla de "Victoria de la run" y reset

**Artefactos esperados:** `BossRoom` o flag en WorldState para boss tile, parámetros `current_layer: int` y `mcguffins: int` en `RunState`, función `WorldState.generate_for_layer(n)`.

### M2 — Deck que crece (closes §7.5 booster packs)

**Por qué:** el Argentite hoy solo cura; las otras facciones de mineral no
sirven para nada. Sin pulls de cartas, el deck es lo mismo toda la run y no
hay decisión de "¿qué carta tirás de este pack?".

- [ ] Booster packs §7.5 en shrines — overlay UI con 3 botones: heal / pull pack / recycle
- [ ] Pack tiers (basic / advanced / outsider) con costos crecientes y mejores drop rates
- [ ] Pull lógica — abre N cartas random pesadas por rareza, jugador agrega al deck
- [ ] Recycle cards §7.5 — vista del deck, click carta = destruir por `recycle_value`
- [ ] Deck cap §7.6 — 30 cartas, descarte forzado al exceder

**Artefactos esperados:** `ShrinePanel` (Control overlay), `BoosterPack` resource, deck/discard piles reales en `RunState` (no solo `_pool` random).

### M3 — Factions con peso mecánico (closes §7.3, §7.7, §6.4)

**Por qué:** hoy las facciones son color. Sin sinergia 1.5×, sin signature
hero y sin HP carryover, el deck no tiene identidad mecánica y los héroes
son desechables. Estas tres mecánicas son lo que hace que las cartas
*importen* más allá del flavor.

- [ ] Faction synergy 1.5× §7.3 — en `EffectExecutor._deal_damage`, si la action es de la misma facción que el hero carrier, multiplicar amount × 1.5 (truncado a int)
- [ ] Marcador `★` en card text — parsing simple del símbolo en la descripción para potenciar visualmente
- [ ] Roster persistente §6.4 — `RunState.roster: Array[HeroInstance]` que sobrevive cambios de escena. Heroes mantienen HP entre combates
- [ ] Signature hero §7.7 — `RunState.signature_id`, vista de "deck management" en exploración para cambiar designación, auto-summon free al inicio del combate
- [ ] Encounter groupings §5.4 — bump enemigo spawnea 1-3 del mismo kind random

**Artefactos esperados:** UI de deck management (Control overlay), modificación de `_summon_first_hero_from_pool` → `_auto_summon_signature`, lógica multi-hero en `Battlefield`.

### M4 — Contenido (FTUE + cartas con sabor)

**Por qué:** con la mecánica cerrada, hace falta cartas. El brainstorm pool
del §7.2.5 está esperando, y las facciones políticas necesitan al menos 3-5
cartas cada una para que la sátira tenga peso.

- [ ] FTUE deck Apolítico (responsabilidad del usuario)
- [ ] Roster mínimo por facción — 3-5 cartas Peronistas con LEADER tag, 3-5 LLA con burn/shutdown, 3-5 PRO con costo diferido, 3-5 FIT con scaling
- [ ] Outsiders básicos — 2-3 cartas legendarias con costo run-persistente (FMI, Barrick Gold, etc.)
- [ ] Effect kinds extendidos — `draw_cards`, `skip_enemy_turn`, `apply_poison`, `damage_self_for_burn` para soportar el roster

**Artefactos esperados:** entradas masivas en `cards.json`, kinds nuevos en `EffectExecutor`.

### M5 — Polish jam

**Por qué:** una jam con loop cerrado y contenido pero sin feel pierde
votos. Es la última milla y la que define si la gente lo termina.

- [ ] Pipeline de arte de cartas §8.1 — decisión: filtro / template / IA. Aplicar al menos al starter deck
- [ ] Tipografía elegida y aplicada
- [ ] SFX mínimos: hit, drop card, mineral pickup, bump pared, shrine activate
- [ ] Música 1 track loop por capa
- [ ] Game over / victory screens con replay
- [ ] Tutorial mínimo — 2-3 cartelitos en la primera capa explicando bump roca / bump shrine / bump enemigo

**Artefactos esperados:** carpeta `assets/`, `AudioStreamPlayer` autoload o por escena, escenas `game_over.tscn` y `victory.tscn`.

### Post-jam (parking lot)

Lo que **no entra al jam** salvo que sobre tiempo:

- §5.4 line-of-sight chase de enemigos
- §5.5 procgen real con chunks + spaghetti caves
- §6.4 múltiples héroes en el campo simultáneo
- §7.4 EX / foil / UR variants
- §7.8 decay de cartas (re-introducción condicional)
- §10 todos los open questions de tuning fino
- Gamepad input
- Localización ES/EN

---

## Recomendación inmediata

**Atacar M1.** Sin macro loop el juego no tiene meta y todo lo que sumemos
después se siente flotante. Boss + McGuffin + hard gate + transición de capa
es chico-mediano (2-3 horas?) y desbloquea sentir la run como tal.

Después: M2 (booster packs) si querés que el jugador *use* los minerales que
está acumulando, o M3 (factions con peso) si te interesa más cerrar el
gameplay del combate antes de meter contenido.

M4 y M5 son tareas de contenido y polish — no las hagas hasta que M1-M3
estén firmes, porque cada cambio mecánico re-balancea las cartas.

---

## Cómo usar este doc

- Tildar `[x]` los items completados al cerrar una sesión
- Cuando un milestone completo se cierra, mover su sección a "Hecho" arriba
  con la fecha
- Si una decisión de scope cambia (ej. M5 audio se descarta), tachar y notar
  por qué — la justificación importa más que la lista
