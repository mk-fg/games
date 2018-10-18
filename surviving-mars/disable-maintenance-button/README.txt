Adds button to toggle whether drones will patch building up when maintenance is required.
Unmaintained building will keep working until it finally breaks down.
Disabling/enabling maintenance mode should have immediate effect on drones,
stopping ones that are en-route if necessary.

Such functionality is useful in early stages of colony development,
when resources are scarce and letting stuff rust in disabled state is expensive,
so shutting it down only as it breaks is preferrable.

[[url=https://steamcommunity.com/sharedfiles/filedetails/?id=1541524054]Steam Workshop[/url]] [[url=https://www.nexusmods.com/survivingmars/mods/94]Nexus Mods[/url]] [[url=https://github.com/mk-fg/games/]Github[/url]]
(protip: if mod gets out of date, Nexus version does not have lua_revision compatbility check,
but Mod Editor won't upload to Steam without it)


[u][size=4]Installation[/size][/u]

Put unpacked "disable-maintenance-button" directory under:
%AppData%/Roaming/Surviving Mars/Mods/ (or something to that effect on Mac/Linux)
(Re-)start the game, and it should appear in "Mod Manager" menu.

Can be installed, enabled/disabled and removed at any time.
Should be compatible with any other mods, though might push
their buttons around (or vice-versa) if they add these to the same row.


[u][size=4]Similar mods[/size][/u]

- [url=https://steamcommunity.com/sharedfiles/filedetails/?id=1403028308]Work Till Maintenance[/url]

  Disables building immediately once maintenance threshold is reached.
  A bit outdated, has some code issues.

- [url=https://steamcommunity.com/sharedfiles/filedetails/?id=1411107464]ChoGGi's Disable Drone Maintenance[/url]

  Only different UI-wise (horizontal button, allows toggling for all buildings of specific type),
  and in that it requires an extra dependency library mod.
