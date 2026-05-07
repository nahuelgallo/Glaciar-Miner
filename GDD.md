# Glacial Miner — Game Design Document

## 1. Pitch

Glacial Miner is a roguelike that hybridizes grid-based dungeon crawling with turn-based deck-building combat. You play a miner descending into a hidden civilization buried beneath the Patagonian glaciers — the ruins of a fallen Argentina. Mine the dungeons, build a deck of political heroes and actions, and break through layer after layer of frozen ruin.

The game is a parody of Argentina's 2026 glacier law debate, which legalized mining adjacent to glaciers and risks massive glacial loss. Each card faction is a recognizable political bloc; the mining loop is the joke.

## 2. Goals & Constraints

### Design goals
- Parody the 2026 glacier law vote
- Represent the key political blocs and figures involved
- A deck-builder loop where every run feels different

### Production constraints
- Built in **1 week** for a game jam
- **Engine:** Godot 4 with web export
- **Platform:** Web
- **Inputs (jam release):** Mouse + Keyboard + Touch (gamepad post-jam)
- **References:** Slay the Spire (combat), Pokémon Mystery Dungeon (exploration), Rogue (procedural runs), EarthBound (encounter groupings)

## 3. Narrative

### 3.1 Setting
Post-apocalyptic Argentina, occupied by a foreign power. The dungeons are the remains of a lost civilization — a fallen Argentina entombed beneath the glaciers. The miner is digging through the ruins of their own country.

### 3.2 Tone
**Mostly played straight, with occasional jokey punctuation.** The default voice is serious — the miner takes the job seriously, NPCs speak earnestly, the fallen civilization carries real weight. Most of the comedy lives in the *content* (political factions buried in ice, foreign actors as literal monsters, the mining loop as a deadpan parody of the real law), not the *delivery*.

That said, the world is absurd, and never letting that show would be its own kind of self-seriousness. Sparing humor — a sharp card name, a dry NPC one-liner, a sight gag in art — is welcome, *as long as it stays the exception, not the rule*.

Calibration guidelines:
- **Default to deadpan delivery.** Most card text reads functionally. *"Mine every rock in the current chunk instantly. Permanently destroy a random card from your deck."* The card's mechanic and target *are* the joke; jokey wording on top of that drowns it out.
- **Let humor land because it's rare.** Reserve overt jokes for moments where they punctuate, not pad. One memorable wisecrack from an NPC beats five forgettable ones.
- **Use real referents.** "La Jefa" / "FMI" / "Barrick Gold" beat "Generic Populist" / "Foreign Bank" / "Mining Co." Recognizable names do the satire's work without the writing having to lean in.
- **Don't break the fourth wall.** Lampshading, meme references, "the developers wanted you to know..." — these collapse the frame. The game does not acknowledge that it is a parody.
- The serious frame is what gives the parody its bite. The jokes inside it are seasoning.

## 4. Macro Loop

```
RUN
  └─ LAYER (n total — TBD; engine must support arbitrary n)
      ├─ EXPLORATION  (grid-based; turns advance on player movement)
      │   ├─ Move / mine rocks / pick up cards & minerals
      │   ├─ Bump enemy → COMBAT
      │   └─ Visit SHRINE → spend minerals on booster packs / heal / destroy cards
      └─ BOSS ROOM
          ├─ Combat against boss → drops a McGuffin
          └─ McGuffin opens the layer's HARD GATE → next layer
END: player HP reaches 0 (game over) or final layer cleared (victory)
```

## 5. Exploration

Top-down tile grid. The player moves orthogonally one tile per turn. **Turns only advance when the player takes an action** (move, mine, interact). Idle = paused.

### 5.1 Tile types
- **Floor** — passable
- **Hard wall** — permanently blocks movement
- **Mineable rock** — see §5.2
- **Shrine** — see §7.5
- **Hard gate** — see §5.3

### 5.2 Mineable rocks
- Block movement until destroyed
- Each rock has a **hardness** value. Layer *n* contains rocks of hardness ≤ *n*.
- Mining a rock from an adjacent tile costs 1 turn per hit. A rock of hardness *h* takes *h* hits to break. (Linear scaling — revisit if pacing feels grindy.)
- Drop tables (proposed; tune in playtest):
  - Nothing (most common)
  - Minerals (faction-typed — see §7.2)
  - Health pickup
  - A card (added directly to the deck — see §7.6)

### 5.3 Hard gate
A wall of hardness *n+1* between layers. The McGuffin dropped by the layer's boss functions as a **key**: interacting with the gate while holding it spends 1 turn and opens it. Without the McGuffin the gate cannot be broken.

### 5.4 Enemies (on the grid)
- Move 1 tile per turn
- Default behavior: random walk every *k* turns (proposed *k* = 2)
- On line-of-sight to the player: switch to chase
- On collision with the player: **trigger combat**
- A single enemy tile can represent a **group** in combat. Bumping a hippie tile may start a fight against 1–3 hippies, EarthBound-style. Each enemy type defines its possible combat-group compositions.
- **Enemy types are political symbols, not generic monsters** (see §6.9). The grid sprite tells the player which symbol they are about to bump into so they can pre-plan based on that enemy's faction matchups before entering combat.

### 5.5 Procedural generation
- Levels are made of **chunks** connected by **spaghetti caves** (narrow winding corridors)
- Chunks: hand-authored prefabs with marked spawn points. Jam scope: ~5–10 chunks per layer.
- Spaghetti caves: stochastic single-tile-wide carving between chunks
- Engine must support an arbitrary number of layers; final layer count is TBD until the game feels right.

## 6. Combat

Combat is a **separate screen** (Slay the Spire-style). No grid, no positioning.

### 6.1 Layout

```
+---------------------------+
|   ENEMY1     ENEMY2       |
|   HP 14      HP 9         |
|   intent: hit 6           |
|                           |
|   HERO_A   HERO_B         |
|   HP 12    HP 8           |
+---------------------------+
 [c] [c] [c] [c] [c]
 HP 30
```

### 6.2 Turn structure
- Player turn → all enemies act → repeat
- **Combat start (before turn 1):** the **signature hero** (see §7.7) is auto-summoned to the field for free.
- **Each turn (including turn 1):** the player draws *N* cards (proposed *N* = 5) at the start of the turn. At the end of the turn, the entire hand is discarded. When the draw pile runs out, the discard pile is shuffled in to form a fresh draw pile.

> **Fallback (if draw-5-discard proves too churn-y or insufficiently rewarding for cross-turn planning in playtest):** switch to a persistent hand — draw *N* on turn 1, draw 1 at the start of each subsequent turn, hand persists across turns, nothing discards at end of turn.

### 6.3 What the player can do per turn
- Play **at most 1 hero card** (summons a hero to the field)
- Play **at most 1 action card per hero currently on the field** (action cards are played *through* a specific hero; the hero's passives and the action's effect can interact)
- Play **any number of effect cards** (effects resolve independently of any hero)
- End turn

There is **no energy/mana cost**. Pacing comes from hand size, draw rate, the 1-hero-per-turn cap, the 1-action-per-hero cap, and the discard pile (each effect card can only be played once per draw cycle).

### 6.4 Heroes (in combat)
- Each hero card has **HP** and **Defense**
- **Defense is a damage threshold per hit:** a hit ≤ Defense is fully absorbed by the hero (deducts from the hero's HP). A hit > Defense deals (hit − Defense) damage to the hero **and** the same overflow to the player's HP.
- Heroes **persist between combats** at their current HP. They can be healed at shrines.
- A hero reduced to 0 HP is removed from the field. The card is **not destroyed** (decay is cut from jam scope — see §7.8). Open question: does the card return to the deck resummonable at full HP, or does it require shrine healing before resummon? Pick whichever produces better pacing in the first prototype.
- Multiple heroes can be on the field at once. No hard cap proposed; deck composition naturally limits this.

### 6.5 Enemies (in combat)
- One action per enemy per turn
- Enemies attack **heroes only**
- If no hero is on the field, enemies attack the player directly at **2× damage**
- Enemy intents are telegraphed (StS-style) so the player can plan defense
- Each enemy carries **faction matchup tags** (see §6.9). Hero damage taken and action-card damage dealt are multiplied by 2× / 1× / 0.5× depending on the matchup. The matchup icons appear in the intent display alongside the next-attack telegraph.

### 6.6 Player HP
- Global to the run. Proposed starting HP: **30**
- Healed at shrines for minerals (cost TBD)

### 6.7 Combat end
- **Victory:** all enemies defeated → reward = minerals (faction-typed, drop table per enemy type) + occasional card drops
- **Defeat:** player HP reaches 0 → game over, run ends

### 6.8 Boss combat
Same combat system. Boss has higher HP (proposed 2–3× a normal enemy), a unique attack pattern, and drops a **McGuffin** alongside minerals. Boss room cannot be skipped.

### 6.9 Enemy types & faction matchups

Enemies are not generic RPG monsters — each enemy type is a **political symbol** with defined matchups against the player's factions. The system creates rock-paper-scissors pressure: a monochrome deck repeatedly meets enemies that resist its faction and stalls. Hybridized decks always have something that hits.

#### 6.9.1 The matchup system

Each enemy type carries two faction lists:

- **Strong against** — heroes of these factions take **2× damage** from this enemy. Action cards of these factions deal **0.5× damage** to this enemy. The political symbol overpowers the faction.
- **Weak against** — heroes of these factions take **0.5× damage** from this enemy. Action cards of these factions deal **2× damage** to this enemy. The faction overpowers the symbol.

Factions not listed are **neutral** (1× both ways). A single faction appears in only one list per enemy.

Multipliers apply to base damage and resolve **before** §6.4 Defense. An enemy hitting a strong-against Peronist hero for raw 4 damage hits for 8; Defense subtracts; overflow hits player HP. An enemy with 10 HP hit by a weak-against-it Leftist action for raw 5 takes 10 — one-shot.

Matchup multipliers stack **multiplicatively** with §7.3 faction synergy (1.5× for an action played through a same-faction hero). All possible damage multipliers vs an enemy:

| Matchup | No synergy | + same-faction hero (1.5×) |
|---|---|---|
| Strong against (resists) | 0.5× | 0.75× |
| Neutral | 1× | 1.5× |
| Weak against (vulnerable) | 2× | 3× |

Synergy on its own does not save the player from a bad matchup — 0.75× is still less than baseline.

**Telegraphed in UI:** the enemy's strong/weak factions appear as small icons on the intent display, alongside the next-attack telegraph. Any enemy should read at a glance as "this thing chews up Peronists, but my LLA hero shreds it."

#### 6.9.2 Enemy roster (TBD — brainstorm)

Roster locked to recognizable Argentine political symbols. **No generic fantasy monsters.** Initial brainstorm (matchups illustrative, tune in playtest):

| Enemy | Symbolism | Strong against | Weak against |
|---|---|---|---|
| **La Pala** | Lawfare, Comodoro Py, "destapando la corrupción" | Peronists, Kirchnerists | LLA |
| **El Hippie** | Progressive activist, social-movement militant | Peronists, PRO, LLA, Apoliticals | Kirchnerists, Leftists |
| **La Feminista** | Feminist movement | LLA | Kirchnerists, Leftists |
| **El Camionero** | Union enforcer, Moyano-style | LLA, PRO | Peronists, Kirchnerists |
| **El Periodista de Clarín** | Corporate media establishment | Kirchnerists, Leftists | Peronists, PRO, LLA |
| **El Gendarme** | Repressive policing of street protests | Leftists, Kirchnerists | PRO, LLA |
| **El Tuitero LLA** | Online libertarian militant, "fenómeno Milei" | Leftists, Kirchnerists | (none — even LLA cards just trade evenly) |
| **El Cura Conservador** | Religious right, "valores tradicionales" | Leftists, Apoliticals | (none — universal repulsion) |
| **El Especulador** | Financial speculator, "corrida cambiaria" | Peronists, Kirchnerists | LLA, PRO |

Notes on the design:
- **Apoliticals are matchup-neutral by default.** They are rarely in any enemy's "strong against" list and never in any "weak against" list. Apolitical cards are the safe filler — they do reliable matchup-neutral damage when the player has no obvious tool for the encounter.
- A "monochrome punisher" enemy (multiple factions in Strong-against — La Pala, El Hippie, El Especulador) is a deliberate design lever. Use sparingly: too many and the player feels there is no winning strategy at all.
- Boss enemies (§6.8) typically have **wider Strong-against arrays**. The boss is the layer's hard test of deck breadth — a monochrome deck that scraped through normal enemies hits the boss and stalls.
- Outsider cards (§7.2.7) do not have an enemy-side counterpart in the matchup table — Outsiders are a *card pool*, not an enemy faction. The player using an Outsider action against a matchup-neutral enemy resolves at 1× (Outsiders never get synergy bonuses anyway, per §7.3).

#### 6.9.3 Why this exists

- **Punishes monochrome decks.** A mono-Peronist deck hits La Pala, El Hippie, El Especulador and stalls hard. The player must hybridize, grind shrines, or lose the run.
- **Rewards reading the encounter.** Skilled players check matchup icons before committing heroes; less-skilled players spam and bleed HP.
- **Self-reinforcing economy.** Diverse enemies → diverse mineral drops (§6.7) → diverse booster packs at shrines (§7.5) → naturally diverse decks. The economy compounds the hybridization pressure rather than fighting it.
- **Puts the satire on the board.** The shovel attacking a K hero literalizes lawfare. The hippie doing nothing to a FIT hero is the fragmented left coalition. Every fight is a small political vignette.
- **No new card-game systems.** Implemented by two arrays per enemy data and a damage multiplier in `EffectExecutor` and the enemy attack resolver. Card schema unchanged.

## 7. Cards & Decks

### 7.1 Card types
1. **Hero** — a summonable unit with HP + Defense + passive effect(s)
2. **Action** — a combat effect played *through* a hero on the field; goes to discard after play
3. **Effect** — a combat effect played independently of any hero; goes to discard after play

### 7.2 Factions (elemental types)
Cards and minerals are partitioned across **5 political factions** plus **2 neutral-ish factions** (Apoliticals and Outsiders). Each political faction's mechanical identity is a parody of how its real-world counterpart actually does politics — the friction the deck creates *is* the joke. The two neutral-ish factions exist outside the political shouting match but play different roles in the run.

| Faction | Real-world bloc | Mineral | Archetype |
|---|---|---|---|
| Peronists | PJ tradicional / gobernadores | **Peronite** | Clientelism. Powerful effects require a cost paid to your own side — sacrifice a hero, allied HP, destroy own cards, spend minerals. The machine runs on what you feed it. |
| Kirchnerists | Kirchnerismo / Unión por la Patria | **Kukite** | Narrative control through quantity and rule-breaking. Search the deck, force redraws, summon extra heroes, ignore per-turn caps. The rules bend around the signature. |
| Libertarians | La Libertad Avanza | **Liberalite** | Burn and shutdown. Paralysis, poison, turn-cancel, debuffs. Many cards cost the player HP or destroy the player's own cards to fire. |
| Macrists | PRO | **Globite** | Short-term gain, long-term cost. Cards have powerful immediate effects with explicit downsides resolved later in the same combat or at end of combat. |
| Leftists | Frente de Izquierda y de los Trabajadores | **Zurdite** | Slow scaling. Most cards have a trivial activation condition (turn elapsed, heroes summoned, FIT cards on field) and scale with the number of FIT cards on the field. |
| **Apoliticals** | Argentine cultural / mythic / generic figures (non-partisan) | **Argentite** | Vanilla. No synergy bonus, no deferred costs, simple effects. The FTUE / starting-deck pool and the neutral filler. |
| **Outsiders** | Foreign actors with dangerous power (IMF, multinational mining, tech-libertarian figures, foreign governments) | **Xenite** | High-power cards with severe deferred costs that can persist *beyond* combat or for the rest of the run. No faction synergy. Tempting traps. |

> **Design discipline:** these archetypes are intentionally implementable using *only* card text and existing affordances — hero subtypes, conditional activation, deferred effects, scaling on field state. **No new card-game systems** (no debt tokens, asamblea counters, inflation stacks, charisma stats). If a card design tempts you to add a new global mechanic to support it, redesign the card.

#### 7.2.1 Peronists — "El Aparato"
- Every powerful peronist card has a **cost paid to your own side**: sacrifice an allied hero, drain allied HP, destroy a card from your deck, spend accumulated minerals, skip a future draw. The card's effect is gated on the player surrendering something tangible. Without resources to pay, peronist cards are dead in hand.
- Costs deliberately exclude "discard your hand" — under the draw-5-discard turn structure (§6.2) the hand goes to discard at end of turn anyway, which would make discard-based costs nearly free if played late in the turn. Costs target persistent state (heroes, deck, mineral bag) instead.
- Example card patterns (illustrative, not balanced):
  - *"Sacrifice an allied hero. Deal damage equal to that hero's max HP."*
  - *"All allied heroes lose 2 HP. Deal damage equal to total HP lost."*
  - *"Spend 3 Peronite. Heal a hero to full HP and grant +2 max HP for the rest of the run."*
  - *"Destroy a card from your deck. Draw 3 cards next turn in addition to the normal draw."*
  - *"Your signature hero loses half its current HP. Summon two free common peronist heroes from your deck."*
- The deck snowballs late-run when the player has multiple heroes, a fat deck, and accumulated Peronite to feed the machine. Stalls hard in early-layer combats with one hero and an empty wallet.
- Signature heroes for peronist decks tend to be either **resource generators** (heroes whose passive provides extra cards / minerals / HP per turn) or **sacrifice fodder anchors** (heroes that produce additional value when consumed by the deck's own costs).
- *Parody read:* nothing is free, everything is transactional. Patronage politics, vote-for-favors, the apparatus that runs on what you put into it.

#### 7.2.2 Kirchnerists — "El Relato"
- Kirchnerist cards manipulate the deck, the hand, and the rules of the turn itself. The faction's identity is **narrative control through quantity and rule-breaking**: search the draw pile for what you want, discard your hand and redraw fresh, summon extra heroes outside the per-turn caps (§6.3), play multiple actions through the same hero, pull cards from the discard mid-combat.
- Most powerful kirchnerist effects are **explicit exceptions to the combat rules**. Where other factions express their identity within the existing rules, kirchnerist cards rewrite them locally for one turn — the card text says what it overrides.
- Effects skew toward **big numbers and big quantities** — full-deck searches, large multi-card draws, multiple simultaneous summons, mass reveals. The opposite of LLA's surgical shutdown.
- Example card patterns (illustrative, not balanced):
  - *Action*: "Search your draw pile for any card. Add it to your hand. Shuffle your draw pile."
  - *Effect*: "Discard your hand. Draw 7 cards."
  - *Hero passive*: "While this hero is on the field, you may summon one additional hero per turn."
  - *Effect*: "Summon up to two non-Outsider heroes from your draw pile. They enter at full HP."
  - *Action*: "This turn, you may play any number of action cards through any hero, ignoring the 1-action-per-hero cap (§6.3)."
  - *Effect*: "Reveal the top 7 cards of your draw pile. Add 3 of your choice to your hand. Discard the rest."
  - *Action*: "Return any Kirchnerist hero card from the discard to your hand."
- Signature heroes for kirchnerist decks tend to be **rule-breaker enablers** — heroes whose passive lifts a per-turn cap or guarantees a free search/draw every turn. The deck's whole engine is *"the rules don't apply to us as long as the signature is on the field."*
- Pairs interestingly with Peronist clientelism (§7.2.1): K tutors out the high-payoff peronist cost-cards on demand, and K's mass-draw effects refill the hand peronist cards burn through. The mixed coalition functions as *"find what we need, then pay for it."*
- *Parody read:* "el relato" — control what reaches the player by controlling what gets drawn, what gets seen, what counts as legal in this turn. Decree governance, court packing, narrative warfare via state media. *La realidad la decide quien la cuenta.*

#### 7.2.3 Libertarians — "Motosierra"
- Two pillars, both expressed entirely in card text:
  - **Shutdown:** paralysis, poison, turn-cancel, single-target debuffs (e.g. *"Target enemy skips next turn"*, *"Target enemy takes 2 damage per turn for 3 turns"*).
  - **Self-burn:** strong LLA cards explicitly cost the player HP, destroy a card from the player's deck, or sacrifice an allied hero (e.g. *"Deal 12 damage. Lose 3 HP."*, *"Destroy a card from your deck. Deal damage equal to that card's recycle value."*).
- LLA hero stat profile: high attack, very low defense — glass cannons.
- *Parody read:* the deck literally chainsaws itself for power.

#### 7.2.4 Macrists — "PRO"
- Every powerful Macrist card has its downside *printed on the card itself* as a deferred effect. No tokens, no counters — just card text.
  - *"Draw 3 cards. At the end of combat, take 6 damage."*
  - *"Summon a free hero. That hero cannot be healed for the rest of the run."*
  - *"All allies +2 damage this turn. Next turn, all allies −2 damage."*
- Deferral is what creates the parody: the bill always comes due, just later.
- Mid-range tempo: works great in short combats, falls apart in long fights where the deferred costs accumulate.
- *Parody read:* borrow against the future, pay later. Globite-funded prosperity that mortgages itself.

#### 7.2.5 Leftists — "Las Condiciones Objetivas"
- Two patterns, both in card text only:
  - **Conditional activation:** cards are inert until a trivial existing-state condition is met. (*"Activates after turn 2."*, *"Activates while at least 2 FIT heroes are on the field."*, *"Activates after a hero has died this combat."*)
  - **Field-state scaling:** payoff numbers scale with the count of FIT cards/heroes already in play. (*"Deal 1 damage per FIT card played this combat."*, *"Each FIT hero on the field gains +1 attack."*)
- The two patterns combine: setup for 2–3 turns, then the deck snowballs.
- *Parody read:* the vanguard waits for the conditions; theory before action; the masses arrive eventually.

#### 7.2.6 Apoliticals — "El Pueblo"
- Argentine cultural figures, folk/mythic figures, and generic mining-fantasy archetypes — anyone widely recognized but not factionally aligned. Avoid figures with known partisan allegiance (Maradona, Eva, Che, Menem, Bergoglio, etc. — those belong in faction cards).
- Card patterns are deliberately vanilla: clear stats, simple effects, **no faction synergy bonus**, **no deferred costs**.
- Roles in the loop:
  - Form the **starting deck** for first runs (FTUE) — see §7.7
  - Appear in basic / mixed booster packs as filler
  - Provide reliable baseline performance — never broken, never dead weight
- Brainstorm pool (final roster TBD): El Minero, Messi, Mafalda, Gardel, Borges, Mercedes Sosa, Charly García, Favaloro, El Gaucho, La Pachamama, El Pombero, La Difunta Correa, El Linyera, San Martín, Belgrano.
- *Parody read:* the cultural substrate that exists underneath the political shouting — recognizable, beloved, mostly powerless.

#### 7.2.7 Outsiders — "Los de Afuera"
- Foreign actors and institutions with predatory power: the **IMF (FMI)**, multinational mining (**Barrick Gold, Rio Tinto, Glencore**), tech-libertarian figures (**Peter Thiel, Elon Musk**), foreign governments, asset managers (**BlackRock, Vanguard**), etc.
- High-power cards with **severe deferred costs that can persist beyond the current combat or for the rest of the run.** This is a deliberate extension of the Macrist deferred-cost pattern — Macrist costs resolve in-combat; Outsider costs can outlast it.
- **No faction synergy.** Outsiders do not pair with peronist clientelism, kirchnerist rule-breaking, FIT scaling, LLA self-burn, or PRO deferral. They are isolated power spikes. Kirchnerist tutors and mass-summons explicitly **cannot target Outsider cards** — the foreign actors stay outside the relato.
- Rarity: typically **Epic / Legendary**. Obtained from high-tier booster packs only, paid in **Xenite** (possibly mixed with other mineral types — TBD).
- Example card patterns (illustrative, not balanced):
  - *FMI*: "Gain 5 minerals immediately. At the start of every combat for the rest of the run, lose 2 minerals."
  - *Peter Thiel*: "Reveal all enemy intents for the rest of combat. At end of combat, lose 1 max HP permanently."
  - *Barrick Gold*: "Mine every rock in the current chunk instantly. Permanently destroy a random card from your deck."
  - *BlackRock*: "Gain 1 of every mineral type. The next booster pack you buy costs double."
- *Parody read:* the foreign actors who actually benefit from the glacier law — the literal antagonists of the satire. Tempting power, lasting damage. Every Outsider card is a small Faustian bargain.

### 7.3 Faction synergy
Hero cards and action cards have a faction. Effect cards are **faction-neutral** in the proposed design (revisit if it makes effect cards too one-size-fits-all).

When an action card is played *through* a hero of the **same faction**, its potentiated numbers are multiplied by **1.5×**. Numbers eligible for potentiation are marked with a star (★) in card text.

The 1.5× synergy stacks **multiplicatively** with the §6.9 enemy faction matchups. Same-faction synergy on a weak-against-faction enemy resolves at 3× damage; same-faction synergy on a strong-against-faction enemy resolves at 0.75× damage — synergy alone does not save the player from a bad matchup. See §6.9.1 for the full multiplier table.

### 7.4 Rarity
Proposed tiers (4): **Common / Rare / Epic / Legendary**.
- Higher rarity ⇒ stronger numbers, more synergy hooks, often *requires* synergy to perform
- Higher rarity ⇒ higher mineral value when destroyed at a shrine
- Higher-tier booster packs (see §7.5) have drop rates weighted toward higher rarities
- *Future-scope only:* EX / foil / UR variants of existing cards. Post-jam — too much asset work for 1 week.

### 7.5 Shrines
Shrines are an exploration tile. At a shrine the player can:
- **Buy a booster pack** with minerals. Packs come in tiers; later layers unlock better packs that contain more cards and have better rare-drop rates, but cost more. (Tier definitions TBD.)
- **Heal** player HP and hero HP for minerals (cost TBD)
- **Destroy cards from the deck** in exchange for minerals (rarer cards yield more)

> *Pack model rationale:* feeds the "mining lottery" fantasy, scales naturally with progression, and lets us tune drop rates per pack tier rather than per shrine.

### 7.6 Deck management
- **No card inventory exists outside the deck.** Picked-up cards enter the deck immediately.
- **Deck size cap:** proposed **30** (TBD — original draft was 60; likely too big for jam-length runs, validate in playtest).
- If a pickup would exceed the cap, the player is forced to destroy cards until under the cap. Forced destruction yields **no minerals** — only voluntary destruction at shrines does.
- The deck can be opened and viewed at any time during exploration.

### 7.7 Signature hero

Every deck has one **signature hero** — a hero card the player has designated as the deck's anchor.

- During exploration, the player can open the **deck management view** and **change the signature designation to any hero card in their deck**. This is a free action and can be done any time outside of combat.
- At the **start of every combat**, the signature hero is **auto-summoned to the field for free**, before the player's first turn. The signature is *not* drawn into the hand and does *not* count toward the 1-hero-per-turn cap — the player may still summon one additional hero on turn 1 normally.
- The signature card stays out of the combat draw pile while it is on the field.
- Hero HP carries between combats (§6.4). The signature auto-summons at its current HP at the start of each combat. If at 0 HP, it cannot auto-summon (see below).
- **If the signature hero dies during a combat, the combat continues without it** (no mid-combat replacement, no UI interruption). **After the combat ends, the player is forced to designate a new signature** from their remaining heroes before they can resume exploration. The new signature takes effect at the start of the next combat at its current HP.
- If every hero card in the deck is at 0 HP, the deck has no usable signature. Combats then begin with no hero on the field — enemy attacks hit the player directly at 2× damage (§6.5). This is intentional: the cascading damage tax accelerates a failing run, putting real pressure on the player to reach a shrine before everything collapses.
- The signature is the deck's **mechanical anchor**. Most decks build niche synergies around it (peronist decks around a hero that fuels the cost machine, kirchnerist decks around a hero that lifts a per-turn cap or guarantees a search, FIT decks around a high-scaling unit, LLA decks around a glass cannon, etc.). The intended progression is *"increasingly locked-in as the deck gets better"* — synergies become more powerful and more niche as the player commits to a build.
- **Designating a non-synergistic signature is always allowed.** A peronist player may pick a hero whose passive doesn't fund the deck's costs; an FIT player may pick a low-scaling hero. The deck's synergies just won't function as designed from turn 1. This is a player choice, not a rule constraint.

### 7.8 Card decay (cut from jam scope)
The original GDD proposed: heroes destroyed at 0 HP, action/effect cards with use-counts, shrines restore. **Cut for the jam.** All cards are reusable.

If a post-jam version reintroduces decay, candidate rules: (1) heroes destroyed at 0 HP only; (2) action/effect use-counts as a separate "fragile" card tier. Park this until the base loop feels good.

## 8. Look & Feel

### 8.1 Art pipeline
- Card art must be generatable **fast** via a **photo → illustration** pipeline. Specific pipeline TBD (filter / AI model / template) — decide on day 1 so the artist isn't blocked.
- Card text must be readable at the smallest in-hand size — define a minimum font size early and enforce it.
- **Visual delivery follows the tone in §3.2: serious craft regardless of how absurd the subject is.** A Peter Thiel hero card should be illustrated with the same painterly weight as a San Martín card — the recognizable face on a heroic-frame portrait *is* the joke. Avoid jokey illustration styles (cartoon mascots, doodle effects, sight gags as default) — reserve those for the rare moments where humor punctuates.

### 8.2 Faction visual identity
Each faction gets a distinct primary color matching its real-world party branding:

- **Peronists:** light blue (celeste)
- **PRO (Macrists):** yellow
- **LLA (Libertarians):** purple
- **Leftists:** red
- **Apoliticals:** light metallic grey
- **Outsiders:** dark grey with a rocky / coal-ish texture

Iconography and silhouette language per faction is TBD; differentiate beyond color via shape and motif (e.g. PRO rounded/corporate, LLA sharp/aggressive, Peronists banner-and-mass imagery, Leftists worker-and-flag).

### 8.3 Layer feel
Each layer should have a distinct visual feel (palette, tile set, music). Number of layers TBD.

## 9. Tech notes for implementation

- **Cards are data, not classes.** Define a Godot resource (or JSON) schema early: `id`, `type`, `faction`, `rarity`, `recycle_value`, `effects[]`. Effects are a small composable vocabulary (deal X, heal Y, draw Z, summon, buff, etc.) — not bespoke code per card.
- **Separate scenes for exploration and combat.** Combat is a separate Godot scene loaded on encounter trigger; exploration state is preserved.
- **Multi-input on web:** mouse + KB for desktop; tap = click and drag for cards on touch. KB hotkeys for end-turn / open deck / movement. Gamepad post-jam.
- **Procedural generation:** chunk-based with prefab Godot scenes, connected by a stochastic single-tile carver. Don't over-engineer the connector — 5–10 chunks plus a dumb walker is indistinguishable from "real" procgen in a short jam run.
- **Vertical slice first.** Day 2–3 target: 1 layer, 1 enemy type, 1 hero, ~5 cards, full loop end-to-end including a shrine. Everything else builds on top of that.

## 10. Open questions / parking lot

Explicit unknowns that don't block starting the prototype. Resolve as the prototype reveals what feels right.

- Final layer count
- Final deck-cap value (start at 30, tune in playtest)
- Mining hardness scaling — is `hits = hardness` linear, or is later mining slowed by other costs?
- Healing cost formulae at shrines
- Boss attack pattern catalog
- Faction balance tuning after the first combat prototype (archetypes are locked, numbers are not)
- Enemy roster — final list of political-symbol enemies, their HP/attack baselines, and matchup tag arrays
- Matchup multipliers — are 2× / 0.5× the right magnitudes? 3× would punish mono decks more harshly; 1.5× / 0.75× would soften the system into a flavor layer
- Per-enemy strong-against count — too many resistances and decks have no answers; too few and the system has no teeth (rough target: 1–2 for normal enemies, 3–4 for bosses)
- Whether specific heroes should have **per-enemy counters** on top of faction-level matchups (e.g. *"Cristina is Strong-against La Pala"*) — likely post-jam if at all
- Peronist signature roster — which resource-generators and sacrifice-fodder anchors best fund the cost-paying loop
- Kirchnerist signature roster — which "anchor" heroes best lift per-turn caps or enable per-turn searches without becoming auto-include in every deck regardless of faction
- Peronist + Kirchnerist mixed-deck balance — K tutors out high-payoff peronist cost-cards on demand; does the search-and-pay coalition outscale single-faction decks?
- Apolitical roster — final shortlist for FTUE / filler pool
- Outsider roster + cost design — how harsh the run-persistent costs should be, and whether Xenite alone is enough to pull Outsiders or if a multi-mineral mix is required
- Whether effect cards stay faction-neutral or get factioned
- Whether the signature hero is a fixed run-starter or unlockable across runs
- Behavior of a hero whose card returns to the deck at 0 HP (resummonable at full HP, or must be healed first?)
