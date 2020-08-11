## Description

Adds Sentinel Combinator, which can be placed near a Radar to detect number (and types) of biters in configurable radius (via R signal), transmitting that as signals for circuit network (red/green wires).

Combinator connects to closest radar within short range (8 tiles) and monitors the surrounding area centered on that radar when it is powered.
If radar is destroyed or scrapped, it picks new radar within range, if any.
Connected and working detector will always set at least "total" signal with 0 value on it, even if nothing is within range.

Detection radius (in tiles, default=32) can be set by R signal right on the combinator, or sent from the circuit network (added to local one if both are present).
Negative value can be sent to disable scanning (same as shutting down combinator or connected radar), or 0 to use default range.
Note that even with extremely high range set, detection should only work for map chunks that factorio simulates at the moment.

All mobile units in "enemy" default force are detected, which should be biters/spitters, including modded biters, but not nests/worms, players or non-biter entities on other forces.
Each default biter/spitter type emit their own signal, while any other unit within range is counted into "Other Aliens" signal, and "Total Alien Units" counts them all.
Any other signals can be set on the combinator freely as well, it shouldn't touch them.

Mod settings allow to change update intervals and some workload parameters.
There is an option to disable radar building requirement, making detector more compact, free and more biter-friendly (radars annoy them).

Can be built after unlocking Circuit Network technology, located next to Programmable Speaker on the crafting grid.
Has its own unique sprites. Uses biter icons from vanilla game for signals, with two special ones for "other" and "total" signals.


## Usage

Can be used to power defenses when biters are detected in the area, potentially in tiers, e.g. only enabling most expensive ones upon detecting high numbers or heavier critters.

When connected to a Programmable Speaker, can be used to broadcast an alert before buildings start getting wrecked, as biter hordes can be surprisingly sneaky in vanilla factorio :)

Having too many and/or too long-range detectors might impact performance on scans, but didn't test by how much.
If you are concerned about this when using many of these detectors, check "show-time-usage" in Shift-F4 debug menu and numbers under "Script Update" there.


## Links

- [Networked Radar](https://mods.factorio.com/mod/folk-radar)

    Very similar mod for 0.14 - 0.16. Might also work with modern factorio after minor modification.

- [Command & Conquer ☭ Red Alert Sounds](https://mods.factorio.com/mod/Command_and_Conquer_RedAlert_Sounds)

    To have alerts on speakers be a bit more dramatic.


[[github link](https://github.com/mk-fg/games/tree/master/factorio/Biter_Detector_Sentinel_Combinator)]
