# Sortie — Act I Story Specification

## 1. Act I Arc

The Gastronomic Brotherhood, an overzealous mercenary company led by General Malakor, has besieged Highspire to forcibly extract the King's state-secret recipe for Rosemary Mutton. Unable to breach the walls, they resort to culinary terrorism to starve out the royal palate. The escalation moves from spoiling the herb garden (M01), to intercepting the garrison's seasonal ale (M02), stealing the royal silverware (M03), constructing a blasphemous rival field-oven (M04), and finally launching a desperate, direct assault on Highspire's paprika reserves (M05). The act ends with Malakor personally defeated on the field, ensuring the King's monopoly on flavor remains unbroken.

- **M01_CABBAGE**: Repel the vegetable bombardment (Completed).
- **M02_ALE_RUN**: Secure the intercepted seasonal ale shipment to restore garrison morale.
- **M03_SILVER_SPOONS**: Recover the stolen royal dining forks from the Brotherhood's forward camp.
- **M04_FIELD_OVEN**: Dismantle the Brotherhood's illegal tactical bakery before it out-bakes the castle.
- **M05_SPICE_WARS**: Defeat General Malakor before he breaches the royal paprika cellar.

## 2. Character Bible

- **Vanguard**
  - Speaks in a pompous, chivalric register with frequent exclamation marks.
  - Treats extremely trivial culinary stakes as sacred, life-or-death duties.
  - Never acknowledges Pip's logical objections.
  - **Goal:** To uphold absolute knightly perfection in the face of mundane chores.
  - **Sample:** "Stand firm, Pip! They may take our lives, but they will never take our nutmeg!"
- **Scout** (Pip)
  - Deadpan pragmatist who actively questions the logic of the missions.
  - Whines about the danger but always does his job.
  - The only person who seems to realize they are fighting over groceries.
  - **Goal:** To understand why they are doing this and get back inside safely.
  - **Sample:** "Are we seriously fighting a pitched battle over soup spoons?"
- **Brute**
  - Enormous, soft-spoken, and infinitely polite.
  - Apologizes sincerely to every enemy before committing horrific violence.
  - Deeply concerned with safety protocols and collateral damage.
  - **Goal:** To ensure everyone is treated with courtesy, even while being crushed.
  - **Sample:** "I am so sorry about this, but I must respectfully cave in your breastplate now."
- **Raider**
  - Sharp mercenary instincts, scavenges everything.
  - Calls Vanguard "boss" and treats the war like an extended heist.
  - Constantly finding money in places that make no sense.
  - **Goal:** To extract maximum financial value from the enemy's culinary obsession.
  - **Sample:** "Boss, these forks are solid silver. I am taking a ten percent finder's fee."
- **Sir Roderick**
  - Grandiose and deeply loyal to the King's dining experience.
  - Addresses the squad as "Men" and directs most of his urgency at Pip.
  - Measures time and disaster entirely in agricultural or culinary metaphors.
  - **Goal:** To protect the King's garden, pantry, and dinner schedule at all costs.
  - **Sample:** "Hurry, Pip. A warm stout is a crime against the crown."
- **Barnaby** (Court Mage, Narrative NPC)
  - An overworked meteorological scholar obsessed with wind patterns.
  - Perpetually distracted and annoyed by the ongoing siege.
  - **Goal:** To predict the weather in peace without military interruption.
  - **Default dialogue (Sequential, single tree, no gating):**
    - Page 1: "The barometric pressure is plummeting, which is dreadful for my arthritis."
    - Page 2: "I am attempting to scry the kingdom's weather, if this infernal siege would just quiet down."
    - Page 3: "The eastern wind brings the scent of treason, and lightly toasted garlic."
- **General Malakor** (Enemy Leader)
  - Uses the `mage` sprite.
  - A grandiose culinary zealot who speaks of food like military doctrine.
  - **Goal:** To acquire the King's Rosemary Mutton recipe by any means necessary.
  - **Sample:** "Your pathetic palates cannot comprehend the tactical superiority of my marinades!"

## 3. Mission Sheets, M02 through M05

**Global Archetype Rules:**

- Player base stats mirror M01.
- **Skirmisher Archetype Baseline:** Evasion is set to 30. Other derived stats follow engine defaults.
- Certain `raider` and `mage` enemies are explicitly marked as **Range 2** below to override melee defaults. The engine will accept the melee swing animation for ranged `raider` attacks.

### M02_ALE_RUN

**Premise**: The Brotherhood has barricaded the southern dirt road and intercepted the seasonal stout shipment intended for the Highspire garrison. The squad must break the barricade and eliminate the interceptors before the ale gets warm.

**Briefing (Condition: `mission_m01_completed` is true, `mission_m02_completed` is false):**

- **Sir Roderick**: "Splendid work out there! The royal herb garden is safe. The scout reports the remaining cabbage hurled over the ramparts was surprisingly edible in soup."
- **Sir Roderick**: "Catch your breath—word has it our ale shipment down south has run into trouble."
- **Sir Roderick**: "A kingdom cannot march on parched throats. The morale of the entire garrison is at stake!"
- **Sir Roderick**: "Sortie immediately and retrieve those barrels."
- **Choices**:
  - `[Sortie!]` -> Launches `M02_ALE_RUN`.
  - `[Prepare]` -> "Hurry, Pip. A warm stout is a crime against the crown."

**Map:** (Barricades on a dirt road)

```text
F.F....F.F
..##..##..
..........
..F....F..
..........
F.##..##.F
..........
..........
```

**Player Roster:**

| Class | Cell | HP | Atk | Def | Move | Range |
| --- | --- | --- | --- | --- | --- | --- |
| Vanguard | (4, 7) | 24 | 9 | 4 | 3 | 1 |
| Scout | (5, 7) | 14 | 6 | 0 | 5 | 1 |
| Brute | (3, 7) | 26 | 10 | 3 | 3 | 1 |
| Raider | (6, 7) | 18 | 8 | 1 | 4 | 1 |

**Enemy Roster:** (Roles are flavor only; AI remains standard expected-value)

| Name | Sprite | Cell | HP | Atk | Def | Move | Range | Role (Flavor) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Agile Thug | `skirmisher` | (3, 2) | 16 | 8 | 1 | 5 | 1 | High evasion blocker |
| Agile Rogue | `skirmisher` | (6, 2) | 16 | 8 | 1 | 5 | 1 | Flanker |
| Thirsty Bruiser | `brute` | (4, 0) | 26 | 9 | 2 | 3 | 1 | Heavy hitter |
| Keg Thief | `raider` | (5, 0) | 18 | 7 | 1 | 4 | 2 | Ranged annoyance |

**Turn 1 Banter:**

- **Scout**: "We are risking our necks for beer? Can't the guards just drink water for one night?"
- **Vanguard**: "Morale is the armor of the soul, Pip! We fight for the King's fermentation!"

**Area Trigger:** `Rect2i(Vector2i(4, 1), Vector2i(2, 1))` (The walkable gap between the northern barricades)

- **Brute**: "Pardon my intrusion, gentlemen. I am going to have to ask you to step away from the beverages."

**Victory Debrief:**

- **Raider**: "Kegs are secure, boss. And I found fourteen silver coins taped to the bottom of this barrel."
- **Raider**: "Consider it a liquid asset recovery fee."

**Defeat Debrief:**

- **Vanguard**: "A tactical withdrawal! We must regroup before the stout goes completely flat!"

**Flags:**

- Sets `mission_m02_completed` on victory.

### M03_SILVER_SPOONS

**Premise**: The Brotherhood has brazenly stolen the King's royal silverware to use in their own field camps. The squad must infiltrate a forward encampment in the woods and eliminate the thieves holding the velvet cutlery cases.

**Briefing (Condition: `mission_m02_completed` is true, `mission_m03_completed` is false):**

- **Sir Roderick**: "The ale flows, and morale is secure. However, a tragedy has struck the royal scullery!"
- **Sir Roderick**: "Men, the Gastronomic Brotherhood has crossed a line that cannot be uncrossed."
- **Sir Roderick**: "Their leader, General Malakor, personally ordered the theft of the royal dining forks."
- **Sir Roderick**: "How is the King expected to enjoy his evening roast? With his hands? Sortie and recover the silver!"
- **Choices**:
  - `[Sortie!]` -> Launches `M03_SILVER_SPOONS`.
  - `[Prepare]` -> "Hurry, Pip. Every second we tarry is another scratch on the royal silver."

**Map:** (A dense forest camp with central defensive barriers)

```text
.##....##.
.F......F.
..........
####..####
..........
..........
.F......F.
..........
```

**Player Roster:**

| Class | Cell | HP | Atk | Def | Move | Range |
| --- | --- | --- | --- | --- | --- | --- |
| Vanguard | (4, 7) | 24 | 9 | 4 | 3 | 1 |
| Scout | (5, 7) | 14 | 6 | 0 | 5 | 1 |
| Brute | (4, 6) | 26 | 10 | 3 | 3 | 1 |
| Raider | (5, 6) | 18 | 8 | 1 | 4 | 1 |

**Enemy Roster:**

| Name | Sprite | Cell | HP | Atk | Def | Move | Range | Role (Flavor) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cutlery Guard | `vanguard` | (4, 1) | 22 | 7 | 3 | 3 | 1 | Armored defender |
| Fork Pilferer | `skirmisher` | (3, 2) | 16 | 8 | 1 | 5 | 1 | High evasion attacker |
| Spoon Pilferer | `skirmisher` | (6, 2) | 16 | 8 | 1 | 5 | 1 | High evasion attacker |
| Camp Lookout | `scout` | (3, 0) | 14 | 6 | 0 | 5 | 1 | Fast mover |
| Silver Smuggler | `raider` | (6, 0) | 18 | 7 | 1 | 4 | 2 | Ranged attacker |

**Turn 1 Banter:**

- **Scout**: "Are we seriously fighting a pitched battle over soup spoons?"
- **Vanguard**: "They are salad forks, Pip! Show some respect for the implements of the realm!"

**Area Trigger:** `Rect2i(Vector2i(4, 3), Vector2i(2, 1))` (The gap between the center walls)

- **Brute**: "Excuse me! I will be gently retrieving those utensils now, please do not trip over the logs."

**Victory Debrief:**

- **Raider**: "Forks acquired, boss. I also found twenty silver coins in their velvet case."
- **Raider**: "I am keeping them as an anti-tarnish consultation fee."

**Defeat Debrief:**

- **Vanguard**: "Fall back! We are out-forked and out-maneuvered!"

**Flags:**

- Sets `mission_m03_completed` on victory.

### M04_FIELD_OVEN

**Premise**: Malakor has authorized the construction of a massive, heavily fortified brick oven on the western ridge to out-bake the royal kitchen. The squad must assault the ridge and destroy the bakers defending it.

**Briefing (Condition: `mission_m03_completed` is true, `mission_m04_completed` is false):**

- **Sir Roderick**: "The forks are polished and returned to their velvet case. But smell the air, Pip!"
- **Sir Roderick**: "The enemy has erected a tactical field oven just beyond the perimeter."
- **Sir Roderick**: "The sheer volume of their yeast production threatens to overshadow the King's pastry monopoly."
- **Sir Roderick**: "Sortie to the ridge and dismantle that blasphemous bakery!"
- **Choices**:
  - `[Sortie!]` -> Launches `M04_FIELD_OVEN`.
  - `[Prepare]` -> "Hurry, Pip. If their croissants finish baking, Highspire is doomed."

**Map:** (A large central brick structure representing the oven)

```text
...####...
..F####F..
...####...
..........
F........F
..........
.##....##.
..........
```

**Player Roster:**

| Class | Cell | HP | Atk | Def | Move | Range |
| --- | --- | --- | --- | --- | --- | --- |
| Vanguard | (3, 7) | 24 | 9 | 4 | 3 | 1 |
| Scout | (4, 7) | 14 | 6 | 0 | 5 | 1 |
| Brute | (5, 7) | 26 | 10 | 3 | 3 | 1 |
| Raider | (6, 7) | 18 | 8 | 1 | 4 | 1 |

**Enemy Roster:** (Enemies pulled north to form a defensive line in front of the oven structure)

| Name | Sprite | Cell | HP | Atk | Def | Move | Range | Role (Flavor) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Dough Sentinel | `vanguard` | (2, 1) | 24 | 8 | 3 | 3 | 1 | Heavy defender |
| Dough Sentinel | `vanguard` | (7, 1) | 24 | 8 | 3 | 3 | 1 | Heavy defender |
| Pastry Enforcer | `brute` | (4, 3) | 26 | 10 | 2 | 3 | 1 | High damage |
| Oven Stoker | `mage` | (5, 3) | 16 | 9 | 0 | 3 | 2 | Ranged magic |
| Flour Scout | `scout` | (3, 3) | 14 | 6 | 0 | 5 | 1 | Fast mover |

**Turn 1 Banter:**

- **Scout**: "Can we just let them bake? It smells amazing out here."
- **Vanguard**: "Treason always smells sweet, Pip! Cover your nose and charge!"

**Area Trigger:** `Rect2i(Vector2i(3, 3), Vector2i(4, 1))` (Just south of the oven structure)

- **Brute**: "I apologize for the mess, but I am legally obligated to smash your brickwork."

**Victory Debrief:**

- **Raider**: "Oven is cold, boss. I found thirty silver coins baked into a loaf of bread."
- **Raider**: "Do not ask questions. I am taking my carbohydrate processing fee."

**Defeat Debrief:**

- **Vanguard**: "The heat is too intense! A glorious retreat from the baked goods!"

**Flags:**

- Sets `mission_m04_completed` on victory.

### M05_SPICE_WARS

**Premise**: General Malakor leads a final, desperate charge to break into the royal cellar and steal the kingdom's paprika. The squad must hold the cellar entrance and defeat Malakor to break the siege.

**Briefing (Condition: `mission_m04_completed` is true, `mission_m05_completed` is false):**

- **Sir Roderick**: "The rogue oven is cold, and the King's pastry monopoly is safe."
- **Sir Roderick**: "But General Malakor himself is massing forces to breach the royal paprika reserves!"
- **Sir Roderick**: "If he breaches the doors and takes the paprika, the Rosemary Mutton recipe is compromised."
- **Sir Roderick**: "Sortie out there and end this culinary nightmare once and for all!"
- **Choices**:
  - `[Sortie!]` -> Launches `M05_SPICE_WARS`.
  - `[Prepare]` -> "Hurry, Pip. The fate of the kingdom's flavor rests on your shoulders."

**Map:** (The fortified cellar entrance)

```text
.########.
.F......F.
...####...
...####...
..........
F........F
..##..##..
..........
```

**Player Roster:**

| Class | Cell | HP | Atk | Def | Move | Range |
| --- | --- | --- | --- | --- | --- | --- |
| Vanguard | (4, 7) | 24 | 9 | 4 | 3 | 1 |
| Scout | (5, 7) | 14 | 6 | 0 | 5 | 1 |
| Brute | (3, 7) | 26 | 10 | 3 | 3 | 1 |
| Raider | (6, 7) | 18 | 8 | 1 | 4 | 1 |

**Enemy Roster:**

| Name | Sprite | Cell | HP | Atk | Def | Move | Range | Role (Flavor) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| General Malakor | `mage` | (4, 1) | 40 | 12 | 2 | 3 | 2 | The boss |
| Elite Guard | `vanguard` | (2, 2) | 25 | 8 | 4 | 3 | 1 | Heavy armor |
| Elite Guard | `vanguard` | (7, 2) | 25 | 8 | 4 | 3 | 1 | Heavy armor |
| Spice Runner | `skirmisher` | (2, 4) | 18 | 9 | 1 | 5 | 1 | High evasion |
| Spice Runner | `skirmisher` | (7, 4) | 18 | 9 | 1 | 5 | 1 | High evasion |
| Siege Breaker | `brute` | (5, 1) | 28 | 10 | 3 | 3 | 1 | Wall crusher |

**Turn 1 Banter:**

- **Scout**: "So this whole war was just about a mutton recipe?"
- **Vanguard**: "It is about honor, Pip! And perfectly balanced seasoning! To victory!"

**Area Trigger:** `Rect2i(Vector2i(3, 4), Vector2i(4, 1))` (Just south of the main chokepoint)

- **Brute**: "General, I am terribly sorry, but you are not on the guest list for dinner tonight."

**Victory Debrief:**

- **Raider**: "Malakor is down, boss. He had fifty silver coins in his spice pouch."
- **Raider**: "I am keeping them as an executive severance package."

**Defeat Debrief:**

- **Vanguard**: "The paprika is falling! Fall back and protect the salt!"

**Post-Victory Dialogue (Condition: `mission_m05_completed` is true):**

- **Sir Roderick**: "The paprika is safe, and Malakor has been routed! You have saved the realm's palate!"
- **Sir Roderick**: "Tonight, Highspire feasts in total victory. Dismissed, men!"

**Flags:**

- Sets `mission_m05_completed` on victory.

## 4. Running Gags and Callbacks

- **The Silver Coins**: In every Victory Debrief, the Raider announces finding an escalating amount of silver coins in completely nonsensical places (tool chests, velvet cases, baked bread). They always follow this by assigning a corporate-sounding "fee" to justify pocketing the money.
- **The Herb Garden / Culinary Metaphors**: Sir Roderick exclusively speaks of the kingdom's peril in terms of ruined vegetables, warm beer, scratched tableware, or stolen spices. He never once mentions actual casualties, borders, or territorial loss.
- **Pip's Questions vs. Vanguard's Zealotry**: On Turn 1 of every mission, Pip asks the single logical question about why they are fighting over something so trivial. The Vanguard ignores the logic entirely, reframing the grocery item as a sacred, chivalric artifact.
- **The Brute's Apologies**: The Brute's Area Trigger dialogue always features him politely apologizing to the enemy for the extreme violence he is about to inflict or the property he is about to destroy.

## 5. Requires New Engine Work

- **Skirmisher Archetype Implementation**: Needs an Evasion baseline stat added to the engine's archetype derived sheet (recommended `30`).

## 6. Open Questions

- **M05 Boss Balance**: General Malakor boasts 40 HP and 12 Atk at Range 2. Since the player squad cannot easily counter him at range, what is the target win-rate band for M05 in the auto-battle harness to ensure he is properly balanced before shipping?
