Compatibility update and tweaks to [Will-o'-the-wisps mod by Betep3akata](https://mods.factorio.com/mod/Will-o-the-wisps).
[[Feedback forum thread link](https://forums.factorio.com/viewtopic.php?f=190&t=60876&p=366660)] - [[github link](https://github.com/mk-fg/games/tree/master/factorio/Will-o-the-Wisps_updated)]

**Important:** this mod is reported to cause desync issues in multiplayer games.
I try to fix known causes of this, and feel free to report any, but never play mp myself,
so don't test changes there or know much about how it works beyond other people's reports.


--------------------

## Description

Adds enigmatic Will-o'-the-Wisps to the game, which can be seen around forests at night.

One current goal of the mod is to add some visible consequences to destroying alien forests or
dumping pollution into them, but not necessarily damaging ones (see mod options).

Another one is making alien nature look more alive and mysterious, as nights in particular can look a bit dull there.
Third optional one is to add some light wisp-deterrent base-planning element, though still not sure how much.

New alien fauna:

- Yellow Will-o'-Wisp
    - They live in forests and aren't generally aggressive.
    - Destruction of trees at night time will draw them out in droves.
- Red Will-o'-Wisp
    - Rare wisps that live under rocks.
    - Physical damage will split them into multiple ones.
- Green Will-o'-the-Wisp
    - Smaller harmless will-o-wisps that are faster and more curious than others.
- Purple Will-o'-Wisp
    - Will-o'-the-Wisp spore.
    - Cause corrosion of structures and power production infrastructure in particular.

Technologies:

- UV Lamp (solar energy research) - only known way to reduce lifespan of purple Will-o'-Wisps when it's dark.
- Wisp Detector (alien biotech research) - outputs number of wisps around it to circuit network with a range input.
- Pet Will-o'-Wisp Lantern (combat robots) - lasting UV-resistant wisp drone to use as a personal lantern.


--------------------

## Hints

- Avoid burning forests at night.
- Trees destroyed or mined at night-time might spawn yellow wisps, rocks - red ones.
- Forests can be hard to find on a desert map, fix via moisture/trees bias in map generator.
- Purple wisps are only dangerous to specific building categories, like power production, refineries and defences.
- Wisps in the area attack when one of them is killed, but are not very fast or dangerous in low numbers.
- Disable turrets targeting wisps in Mod Options menu to avoid accidental aggression.
- UV will chase wisps away without any retaliation. Overlapping lamps will amplify effects.
- Circuit control wires can switch UV lamps on/off for power saving reasons - they eat quite a lot.
- Wisp detectors range can be set by R signal (on itself or via wires), see ingame description for more info.
- Lantern will-o-wisps last a long time, but can always be put down (C key) if they're a bother.
- Wisps appear in forests after dark (in a day or few), drawn out by nearby pollution and player activity.
- Mod only tracks surface darkness changes, not time, so mods that change day/night cycle should be compatible.
- There are mod options to control where, which and how many will-o'-the-wisps can be seen on the map.
- Set "Wisp aggression factor" in mod options to e.g. 0.5 or something higher for a more challenging game.
- Enabling wisps to fight biters while disabling immunity of their nests can speed up biter evolution factor.
- See [forum thread](https://forums.factorio.com/viewtopic.php?f=190&t=60876&p=366660#p366660) for more technical info and debug commands.
- [FAQ](https://mods.factorio.com/mod/Will-o-the-Wisps_updated/faq) and that forum thread also has info on [LuaRemote interfaces](https://lua-api.factorio.com/latest/LuaRemote.html) for other mods/devs.


--------------------

## Links


- Cosmetic Compatibility Mod(s)

    - [Inlaid UV-lamp](https://mods.factorio.com/mod/InlaidUVLamp) -  makes UV lamps look like ones in [Schall Lamp Contrast](https://mods.factorio.com/mod/SchallLampContrast) and [Inlaid Lamps Extended](https://mods.factorio.com/mod/InlaidLampsExtended) mods.


- Mod Suggestions

    - [Clockwork](https://mods.factorio.com/mod/Clockwork) - extends nights, and longer nights = more shinies!
    - [Time Tools](https://mods.factorio.com/mods/binbinhfr/TimeTools) - UI clock and speed settings plus time/darkness-tracking combinators.
    - [Wildfire](https://mods.factorio.com/mod/Wildfire) - can make things a lot more "interesting" at nights.
    - [Diplomacy](https://mods.factorio.com/mod/diplomacy) and [Rampant](https://mods.factorio.com/mod/Rampant) - for [emergent game faction dynamics and challenge](https://forums.factorio.com/viewtopic.php?p=377032#p377032).
    - [Catmod-Reborn](https://mods.factorio.com/mod/Catmod-Reborn) - have cats chase shiny orbs of tuna.


- Mod Alternatives / Forks

    Note that multiple versions of these should not be used at the same time.

    - [Will-o'-the-Wisps updated (2)](https://mods.factorio.com/mod/Will-o-the-Wisps_updated-2) - improved version between 0.17-1.0 factorio releases by Pi-C.

        All changes from there up to and including 0.18.6 are merged here as 0.2.x versions, see changelog for details.

    - [The Night Has A Thousand Eyes](https://mods.factorio.com/mod/The_Night_Has_A_Thousand_Eyes) - seem to be a local fork for a specific multiplayer server/game.

        Not recommended for general use by the author (as of 0.1.1 / 2020-08-21), except for reference and merging fixes/changes.
        Like the name a lot, way more imaginative than "wisps updated" here :)

    - Original [Will-o'-the-wisps](https://mods.factorio.com/mod/Will-o-the-wisps) mod and its [forum thread](https://forums.factorio.com/viewtopic.php?f=93&t=41514).

        Was only maintained up to 0.14.x-0.15.x factorio releases by Betep3akata.
