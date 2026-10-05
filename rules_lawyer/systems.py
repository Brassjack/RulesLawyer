"""The game systems /rules can answer for.

Adding a system is one entry here, plus optionally a reference file at
REFS_DIR/<id>.md. A system without a reference answers from Claude's memory.
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class System:
    name: str
    # Edition and terminology guidance, appended to the shared prompt.
    notes: str


SYSTEMS: dict[str, System] = {
    "dnd5e-2024": System(
        name="D&D 5e (2024)",
        notes="""\
- Answer from the D&D 5e 2024 rules (2024 Player's Handbook, Dungeon Master's Guide and Monster Manual). Many rules changed from 2014, such as spellcasting limits, conditions, weapon masteries, exhaustion and species. Check you're giving the 2024 version. If the 2014 rule differs in a way people commonly mix up, say so briefly.
- Known trap: 2024 replaced the 2014 bonus-action-spell restriction with "one spell slot per turn" (you can expend only one spell slot to cast spells on a turn). Don't give the 2014 version.
- The GM is called the DM.""",
    ),
    "mothership": System(
        name="Mothership 1e",
        notes="""\
- Answer from Mothership 1st edition (Player's Survival Guide v1.2). Don't use 0e/Alpha rules (Armor Save, Combat checks opposed by Armor, Resolve): 1e uses Armor Points, Wounds, and a d20 Panic Check against Stress.
- The GM is called the Warden. Rulings beyond the rules are the Warden's call; say so rather than inventing setting detail.
- Ships, space travel and Warden-side rules are in other books (Shipbreaker's Toolkit, Warden's Operations Manual), not the reference. If asked, answer from memory and say it isn't in the reference.""",
    ),
    "cyberpunk-red": System(
        name="Cyberpunk RED",
        notes="""\
- Answer from the Cyberpunk RED core rulebook. Don't use Cyberpunk 2020 rules (e.g. Body Type Modifier, Stun/Shock saves, 2020's wound levels): RED uses Hit Points, Wound States, DVs, Critical Injuries and Death Saves.
- The GM is called the GM. Setting, lore and NPCs aren't in the reference; if asked, answer from memory and say so.""",
    ),
}
