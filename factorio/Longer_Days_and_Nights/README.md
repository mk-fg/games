## Description

Makes days and nights 4x longer (by default) and multiplies accumulator capacities by the same value.
Factor is adjustable via Mod Settings menu (Startup tab), changing accumulators can be disabled there too.
Only affects default surface, simply setting `nauvis.ticks_per_day` (earlier version/mods used to freeze/unfreeze clock).

Kinda like [Day Night Extender](https://mods.factorio.com/mod/DayNightExtender), but in 20 lines of lua instead of ~500, with proper Mod Settings affecting accumulator adjustments, and updated for 0.17.x.

Accumulator capacity adjustment is meant to have them last same time as before when using solar power (4x night length means they need to last longer), but note that it will apply to non-solar uses of them as well, hence the setting to disable this extension in the Mod Options (e.g. for those who never build solar panels).

## Trivia

Whole default day/night cycle is ~7 minutes at 1x game speed, see [Factorio wiki Time page](https://wiki.factorio.com/Time) for nice visualization and more details. Also check out [Time Tools mod](https://mods.factorio.com/mods/binbinhfr/TimeTools) for an in-game clock, easy game speed controls and circuit network elements to track time-of-day on a weird alien worlds.

4x adjustment will stretch full 7m cycle into 28m, prolonging all phases of it proportionally.
This mod does not have options to affect specific phases differently, but there are mods like [Clockwork](https://mods.factorio.com/mod/Clockwork) that allow that.

[[github link](https://github.com/mk-fg/games/tree/master/factorio/Longer_Days_and_Nights)]
