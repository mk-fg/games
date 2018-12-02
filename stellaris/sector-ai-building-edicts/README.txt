Adds toggleable empire/planetary edicts, controlling stuff sector AI is allowed to build.
For Stellaris 2.1. Not compatible with acheivements or mods that override first-tier buildings controlled by edicts in this mod. Can be added/removed at any time.


[h1]More Info[/h1]

Have you ever been annoyed that your empire has +200 food surplus before mid-game, no growing pops, and yet sector AI keeps building farms on all mineral/energy tiles?

This mod allows to prohibit that anywhere in the empire or on a specific planet by toggling an edict there, with similar edicts available for some other buildings.

Such edicts are only available to player empires and only affect sector AI decisions - prohibited buildings can still be placed manually.

Note that this is done to allow simplier micromanagement or min-maxing, i.e. to not bother demolishing or pre-filling all tiles on sector planets and leave that to sectors instead, but yet not go full hands-off "let them do whatever they want" either.


[h1]Policies / edicts currently added by this mod[/h1]

[b]SAI :: Empire/Planet Edicts :: displayed/hidden[/b] (empire)
Hides all empire/planet edicts added by this mod. State of edicts that are hidden will still apply.
Useful for cases when you don't need one or the other or just rarely change these.

[b]SAI :: Colony Shelter :: allowed/prohibited[/b] (empire/planet)
Allows/prohibits sector AI to rebuild colony shelter. Does not affect upgrades of colony admin building. Can be useful to prohibit because it's almost always useless until upgraded, yet AI always assigns a pop there, and rebuilding it is free.

[b]SAI :: New Farms :: allowed/prohibited[/b] (empire/planet)
Allows/prohibits sector AI to build new farms. Does not affect upgrades of existing farms.


[h1]Technical details[/h1]

All edicts are free to toggle between allow/prohibit states at any time, with color-coded (red/green) state displayed and explained in edict name and description.

Edicts work by setting empire/planet flags, which are then checked in the "ai_allow = ..." section of the overidden first-tier building definition (e.g. building_hydroponics_farm_1, ones that are built on empty tiles), so that when either empire or planet edict is set to "prohibit", building will not be available for AI to construct, and it will have to pick something else (next best thing).

Note that such logic makes "prohibit" decision on any level (empire or planet) override "allow", which is intentional, as everything is allowed by default, and idea of the mod is to veto AI decisions in specific places.

Other mods that override same exact buildings (only building_hydroponics_farm_1 so far) will either fail to do so (if this mod takes priority) or will remove ai_allow=... checks added by this mod (if they take priority over it).
This only applies to overriding edict-affected buildings, everything else is perfectly fine and totally compatible.

[url=https://steamcommunity.com/workshop/filedetails/?id=1140543652]Glavius's Compatible AI mod[/url] augments vanilla sector AI by adding "scripted planet development", where mod places "critical" buildings according to its own logic, using empire minerals/credits (not sector's) as if it was done manually by the player.
This mod will not affect these decisions, but you can disable them per-planet either by using "Disable GAI" planetary edicts from Glavius mod, or their empire-wide counterpart added by my [url=https://steamcommunity.com/sharedfiles/filedetails/?id=1380893289]Glavius AI Sector Development Edicts[/url] mod.
These are usually good decisions though (hence called "critical" in Glavius mod), and probably don't need to be disabled.

Stellaris 2.2 release will replace planet tile system, and this mod will either become obsolete or be updated to allow vetoing building choices there via planetary decisions or policies (as edicts will also be removed afaik).
