Covers mars terrain and atmosphere with greenish bioluminescent microbiotic life.
This is purely cosmetic (lightmodel) change, wait for at least 1 mars-hour to apply.
Can be enabled/disabled via Ctrl+Alt+Shift+K ("Green Mars Toggle" in Key Bindings).

Checked to be compatible with Gagarin / Space Race update 237,920, and probably later versions.

[[url=https://steamcommunity.com/sharedfiles/filedetails/?id=1543384888]Steam Workshop[/url]] [[url=https://www.nexusmods.com/survivingmars/mods/95]Nexus Mods[/url]] [[url=https://github.com/mk-fg/games/]Github[/url]]


[h1]Oh no! How could this happen!?[/h1]

Turns out some of the early martian probes weren't sterilized thoroughly enough back in 1960s.
Bio-contaminant got into liquid water on poles or underground, mutated rapidly due to lack of shielding magnetic field or atmosphere, got blown by dust storms all over the place and went exponential from there.
So now Mars is a slimeball, same as Earth was for 80% of its existance (~3.7/4.5 bil years).

Due to changes in martian atmospheric composition caused by this runaway disaster,
light passing through it now has a nice purplish hue.


[u][size=4]Installation[/size][/u]

Put unpacked "green-mars-terraforming-lightmodel" directory under:
%AppData%/Roaming/Surviving Mars/Mods/ (or something to that effect on Mac/Linux)
(Re-)start the game, and it should appear in "Mod Manager" menu.

Mod can be added and removed at any time, though green will stick around in saves.
To sterilize Mars back to its proper red-browns, you can edit green-mars-terraforming-lightmodel.lua file and uncomment "local lightmodel_list = 'TheMartian'" line there, load/save game and then disable/remove the mod.


[h1]Technical details[/h1]

Only changes normal ligthmodel, does not affect gameplay at all.
Disaster lightmodels stay the same, so green should probably still be covered in red dust during storms and freeze over to shiny crust during cold waves, but didn't test it myself yet.

Mod can be added and removed at any time, though green will stick around in saves,
so be sure to disable it via hotkey before removing the mod, if you must.

[url=https://steamcommunity.com/sharedfiles/filedetails/?id=1433249476]ChoGGi's Permanant Dreamers Lightmodel[/url] (typo not mine) does a similar thing but overrides all hours' and disaster lightmodels to a single stage of green one, while this mod only swaps normal lightmodel and uses full LightmodelList with a day/night cycle.

Lightmodel should be recognizable to those who played with Inner Light mystery.
