## Description

Allows to adjust roboport construction/logistics bot ranges via Mod Settings menu.
Specifically - setting range multiplier value, specific static range values or copying one range to another.

Applies to all buildings of "roboport" type by default, so should also modify roboports added by mods, if any.
I don't play with any custom roboports though, so feel free to test and report if there are any issues.

Adds following Mod Settings (Startup tab):

- Roboport Range Multiplier (real/float number >0)

	Multiplies both construction/logistics default or previously-modded ranges by this factor.
	Use 1 for no changes, >1 to increase, or e.g. 0.5 to reduce it.
	Result will be rounded to nearest integer value. Applied before range values below.
	&nbsp;

- Roboport Logistics Range (integer)

	Logistics bot range of the roboport. Default/vanilla is 25.
	Special values: -1 - do not change it via this option, -2 - set to be equal to construction range.
	Applied after multiplier above and after static construction range value (if set).
	&nbsp;

- Roboport Construction Range (integer)

	Construction bot range of the roboport. Default/vanilla is 55.
	Special values: -1 - do not change it via this option, -2 - set to be equal to logistics range.
	Applied after multiplier above and after static logistics range value (if set).
	&nbsp;

- Robot Energy Multiplier (real/float number >0)

	Max energy value multiplier for construction and logistic robots.
	Values >1 will allow these bots to fly longer without running out of power.
	&nbsp;

- Affect Mod Roboports/Robots (yes/no boolean)

	If enabled (default), mod will affect all roboports/robots in their respective categories, including those added by mods, and only ones from base game otherwise.


## Cookbook

- Increase roboport and robot ranges 2x: set Roboport Range Multiplier and Robot Energy Multiplier to 2.

- Make roboport logistics bots range same as construction bots: set Logistics Range to -2.

- Set roboport construction bots range to be 90 tiles: set Construction Range to 90.

- Allow robots to stay in the air 5x longer: set Robot Energy Multiplier to 5.

- Don't affect already-buff roboports/robots from other mods: uncheck Affect Mod Roboports/Robots.


[[github link](https://github.com/mk-fg/games/tree/master/factorio/Configurable_Roboport_Range)]
