--------------------

## Description

Adds Power Meter Combinator which can be used to measure power production of electric grid connected to any closest pole (within 16-tile radius), transmitting that as signals for circuit network (red/green wires).

Signals are generated for each energy source item (e.g. Solar Panel, Steam Engine, Accumulator, etc), with values set to combined production of that building type in kW, rounded to nearest integer.

Special "W" signal is generated for total power production of energy grid (sum of all per-building-type values), which should match grid power usage.

Another special "O" signal is used for sum of production of all non-item power-generating entities added by mods, which can't be used as signals themselves.
(non-craftable/placeable invisible things that some mods use internally to represent power added to grid from somewhere, e.g. Personal Transformer mod sending excess power production from player's armor into the grid that way)

These are **current** power production values, as set by grid power demand and limited by available sources, not static maximum values of any kind.

Combinator finds closest electric pole within 16-tile radius and tracks values for its grid, finding new pole only if that one is no longer there (e.g. destroyed or deconstructed).

Signals are updated once per 1 in-game second (60 ticks at 1x speed) by default, which can be adjusted via Mod settings menu (Startup tab).
Measured values are capped at 2 TW (>10k vanilla nuclear reactors).
Large single-period spikes in measured values can happen when connecting two long-running electrical grids together.

Any additional signals can be set on the combinator as usual, ones generated from the grid will use empty slots, if available.

Can be built after unlocking Circuit Network technology, located next to Power Switch and Speaker items on the crafting grid.
It looks like blue-ish combinator with tiny yellow lighting bolt symbol painted on top (let me know if you know of a better sprites somewhere).


--------------------

## Usage

Common use-case can be generating alerts (e.g. via Programmable Speaker) when power capacity is close to the limit or to disable less efficient power sources depending on grid load (e.g. Steam Engines when Nuclear Power is sufficient, as latter consumes cells at a constant rate regardless).

Power production limit of the grid is not measured, and can depend on fuel availability, how stuff is connected, time of the day (for solar power), accumulator capacity, power switches and limited connections (e.g. through accumulators), etc.
Usually it's not hard to get a rough estimate for it though, by using Ctrl+C to count production facilities and multiplying their total number by max output of each.

Comparing such high-watermark value against measured output can be used to get grid utilization estimates.


--------------------

## Links

- [Power Combinator](https://mods.factorio.com/mod/power-combinator) - kinda similar, but checks pole(s) connected by circuit wire.

- [Power+: Power Meter](https://mods.factorio.com/mod/PowerPlusPowerMeter) - for power utilization percentage instead of raw production numbers.

- [Dragon Industries Factor-I/O](https://mods.factorio.com/mod/FactorIO) - includes power measuring combinators too.

- [Circuit Power Measurement Pole](https://mods.factorio.com/mod/Circuit_Power_Measurement_Pole) - earlier version of this mod.

- [This mod's github repository](https://github.com/mk-fg/games/tree/master/factorio/Circuit_Power_Measurement_Combinator)
