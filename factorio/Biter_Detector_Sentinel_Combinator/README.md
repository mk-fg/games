--------------------

## Description

Adds Sentinel Alarm and Sentinel Combinator devices, which can be used to detect biters in a configurable radius (via R signal).

- Sentinel Alarm

    Constant combinator that enables when (any) hostile units are detected within specified circular range.
    Does not enable if no signals are set on it, so don't forget to set it up to actually send something.

    Test-run mode: T signal can be set (to non-0 value) on alarm combinator to have it activate on (any) player within range instead.
    Can be used to test distance and connected systems' reaction by player(s) pretending to be a biter, or maybe to prank them with a train.

- Sentinel Combinator

    Combinator that must be placed near a Radar to count and classify incoming biters.

    Connects to closest radar within short range (8 tiles) and monitors the area around the radar when it is powered.
    If radar is destroyed or scrapped, sentinel picks new radar within range, if any.
    When connected and working, it will always set at least "total" signal with 0 value on it, if nothing is within range.

    Only mobile units in "enemy" force are counted,
    which should be biters/spitters (including modded ones), but not nests/worms, players or non-biter entities on other forces.
    Each default biter/spitter types emit their own signal. Modded biters are counted into "Other Aliens" signal. "Total Alien Units" sums them all up.
    Any other signals can be set on the combinator freely as well, it shouldn't touch them.

    Uses biter icons from vanilla game for virtual signals, with two special ones for "other" and "total".

Difference between the two is that Alarm is a simplier on/off detector for when anything dangerous is in range,
while Combinator sends which types of biters are in range and their exact count.

Detection radius (in tiles, default=32) can be set by R signal right on these combinators, or sent from the circuit network (added to local one if both are present).
Negative value can be sent to disable scanning, or 0 to use default range.
Note that even with extremely high range set, detection should only work for map chunks that factorio simulates at the moment.

Both detectors can be built after unlocking Circuit Network technology, located next to Programmable Speaker on the crafting grid, have their own icons/sprites.

Mod settings allow to change update intervals and some workload parameters.


--------------------

## Usage

These combinators can be used to power defenses when biters are detected in the area, potentially in tiers, e.g. only enabling most expensive ones upon detecting high numbers or heavier critters.

When connected to a Programmable Speaker, can be used to broadcast an alert before buildings start getting wrecked, as biter hordes can be surprisingly sneaky.

With Speakers, it can also be useful to add interval between alarm pulses, so that they aren't too annoying due to repetition.
It's easy to do by adding arithmetic combinator with "memory" in-between alarm/speaker, like in [this attached image](https://mods-data.factorio.com/assets/cde0b568fcc6907bf7da9172bfea58b2258fe3ca.png).
(use any power-of-two-minus-one numbers for delays with bitwise AND operation there and/or larger signal increment values to get any kind of interval)

Having too many and/or too long-range detectors might impact performance on scans, but didn't test by how much. Alarms use simplier find_nearest_enemy() scans. If you are concerned about this when using many detectors, check "show-time-usage" in Shift-F4 debug menu and numbers under "Script Update" there.


--------------------

## Links


- Similar Mods

    - [Networked Radar](https://mods.factorio.com/mod/folk-radar) - very similar mod for factorio 0.14 - 0.16.
    - [Radar signals](https://mods.factorio.com/mod/radar-signals) - more up-to-date fork of Networked Radar, somehow missed it before.
    - [Dragon Industries Factor-I/O](https://mods.factorio.com/mod/FactorIO) - includes biter count sensor, among many others.


- Programmable Speakers

    - [Soundpack: Alerts and Sirens](https://mods.factorio.com/mod/Soundpack-alerts-and-sirens) - a lot of alert, siren and bell sounds for an easy speaker alarm variety.
    - [Speaker Signals 2](https://mods.factorio.com/mod/speaker-signals-2) - nice alert icons for speakers.
    - [Command & Conquer ☭ Red Alert Sounds](https://mods.factorio.com/mod/Command_and_Conquer_RedAlert_Sounds) - to have voiced "Enemy Approaching" or "Base Under Attack" alerts on speakers.
    - [Op2 announcer](https://mods.factorio.com/mod/Op2_announcer) - another great voice-alarm pack.


- Detectable fauna

    - [Armoured Biters](https://mods.factorio.com/mod/ArmouredBiters) - additional biter types for that "other aliens" category.
    - [Will-o'-the-Wisps updated](https://mods.factorio.com/mod/Will-o-the-Wisps_updated) - hostile ones trigger Alarm towers, but combinator doesn't count them.

- [Github repository for this mod](https://github.com/mk-fg/games/tree/master/factorio/Biter_Detector_Sentinel_Combinator)
