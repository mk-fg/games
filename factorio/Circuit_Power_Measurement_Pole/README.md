## Description

Adds Small "Smart Meter" Electric Pole which can be used to measure electric network power production for circuit network, transmitting signals to any nearby constant combinator, in addition to its usual function.

Multiple signals are transmitted for each energy source (e.g. Solar Panel, Steam Engine, Accumulator, etc), with values set to combined production of that building type in kW, rounded to nearest integer.

Special "W" signal is generated for total power production in the connected energy grid (sum of all per-building-type values), which should match grid usage.

Another special "O" signal is used for sum of production of all non-item power-generating entities added by mods, which can't be used as signals themselves.
(these are non-craftable/placeable invisible things that some mods use internally to represent power added to grid from somewhere, e.g. Personal Transformer mod sending excess power production from player's armor into the grid that way)

These are **current** power production values, as set by grid power demand and limited by available sources, not static maximum values of any kind.

Signals are set on the nearest Constant Combinator within Small Electric Pole range (2 tiles around pole), if any, as pole itself cannot interact with circuit network.

Updates signals once per 1 in-game second (60 ticks at 1x speed) by default, which can be adjusted via Mod settings menu (Startup tab).
Measured values are capped at 2 TW (>10k vanilla nuclear reactors).
Large single-period spikes in measured values can happen when connecting two long-running electrical grids together.

Available after unlocking Circuit Network technology, located next to Power Switch and Speaker items on the crafting grid.


## Usage

- Produce and place Smart Meter Electric Pole, connected to power grid which will be measured, same as any regular power pole.

- Place constant combinator within reach of this power pole (2 tiles).
  It should immediately start generating signals corresponding to power production on the grid.

- Connect constant combinator to a circuit network where these signals will be used.

Common use-case can be generating alerts (e.g. via Programmable Speaker) when power capacity is close to the limit or to disable less efficient power sources depending on grid load (e.g. Steam Engines when Nuclear Power is sufficient, as latter consumes cells at a constant rate regardless).

Power production limit of the grid is not measured, and can depend on fuel availability, how stuff is connected, time of the day (for solar power), accumulator capacity, power switches and limited connections (e.g. through accumulators), etc.
Usually it's not hard to get a rough estimate for it though, by using Ctrl+C to count production facilities and multiplying their total number by max output of each.

Comparing such high-watermark value against measured output can be used to get grid utilization estimates.

[[github link](https://github.com/mk-fg/games/tree/master/factorio/Circuit_Power_Measurement_Pole)]
