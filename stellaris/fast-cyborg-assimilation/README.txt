Changes pop assimilation steps (1-4 pops per planet being cyber-enhanced) to trigger monthly instead of yearly for empires on a synthetic ascension path (ones with "The Flesh is Weak" ascension perk).
For Stellaris 2.x (2.1 included), not acheivement-compatible.


[h1]More info[/h1]

This affects species that have "Assimilation" rights in the empire, increasing assimilation process rate by x13 factor and smoothing it out to get newly-assimilated pops monthly, but not for Gestalt Consciousness empires (Hive Minds and Driven Assimilators), mostly for balance reasons.

Intended to be a simple fix/workaround to make assimilation more viable and less painful in a synth-slaver empires, where it has "liberating" effect for years, resulting in various unintended and hard-to-manage effects, if used.

Does not need a new game, does not change savegames and can be added/removed at any time.
Should be compatible with any other mods (incl. ones changing ascension/assimilation effects).
(only adds new triggers for default assimilation event, without overwriting or changing existing stuff)


[h1]Technical details[/h1]

By default, assimilation works like this:

- on_yearly_pulse in 00_on_actions.txt runs action.64 event.
- action.64 event runs action.65 for every_owned_planet in every_playable_country.
- action.65 checks for pops on the planet that are subject to assimilation and replaces 1-4 of them with assimilated pops.

On top of that, when enabled, mod adds:

- on_monthly_pulse running fca.1 event.
- fca.1 event checks for every_playable_country with ap_the_flesh_is_weak perk, and runs default action.65 for every_owned_planet of these.

This will make pop assimilation event trigger 12 times via new on_monthly_pulse event in addition to default yearly trigger, effectively speeding-up the process by x13 factor.

There is a similar mod - [url=steamcommunity.com/sharedfiles/filedetails/?id=1164740948]Additional Monthly Assimilation[/url] - but it affects all empires, including gestalt conciousness ones, which might make some AIs quite OP as they can gain pops at a landslide rates that way.


[h1]Extended rationale[/h1]

Default assimilation does several strange things:

- Prevents all assimilating pops from working and being tile slaves (under caste system).
- Sets all assimilating pops free (to engage in politics, produce leaders, etc), even in authoritarian/xenophobic empires.
- Keeps setting just-assimilated pops to full citizen rights until assimilation finishes (bug?).
- Lasts a dozen years (1 pop with 50% chance, 2/30%, 4/20% - per planet per year).

Which is very problematic for slaver empires, where intent usually is to modify newly-acquired slave races, without freeing them, neither after nor during modification.

Effects of this are:

- Huge loss of productivity (starting from a total loss!) on whole planets.
- Factions with random ethos and disproportional influence (not slaves) popping-up from "free citizen" assimilating xenos.
- Unrest without the usual means to control it via slavery effects.
- Inability to effectively setup planets into some productive state and leave them for sector AI to upgrade, not until assimilation is done.

Which make locking pops into assimilation for years for a small +5% cyborg bonuses vs just leaving them to slave as-is pretty much never worth it.

IMO ideally assimilation would not affect neither slavery nor production, same as all other modifications (genetics, robomodding, "flesh is weak" research itself, etc), but as I don't know how to mod that in easily and reliably, next best thing is just to make the process much faster and hence less painful, which is what this mod aims to accomplish.

This only applies to regular ascending empires, as in Hive Minds and Machine Empires conquered pops cannot function (work) without ascension anyway, and would've been just food or bio-fuel otherwise, with stuff balanced to compensate for that already, which is why mod does not affect them.


[h1]Links[/h1]

- [url=steamcommunity.com/sharedfiles/filedetails/?id=1164740948]Additional Monthly Assimilation mod[/url] - works in the same way, but does not limit effect to ascendant empires only.
