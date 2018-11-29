Companion mod for [url=steamcommunity.com/sharedfiles/filedetails/?id=1140543652]Glavius's Ultimate AI Megamod[/url] that adds two edicts - one for empire, one for planets - to toggle scripted building redevelopment in sectors of player empire.

Can be installed and removed at any time, though be sure to disable its edicts (if you've enabled them) before uninstalling/disabling the mod, as otherwise their effects will persist in a saved game (though it can be re-enabled again to disable them at any point).
Mod does not overwrite any of the main game or Glavius mod files, and only sets empire/planet flags based on these edicts for Glavius AI to check and use, so compatible with everything else.

[b]NOTE:[/b]
Glavius AI mod already includes similar [b]planetary[/b] edicts now
("DIsable GAI" / "Enable GAI" on planets), but not empire-wide ones,
so this mod can be used for latter, otherwise just use edicts from stock GAI.
Planetary edicts are kept here for compatibility too, but can be hidden via country-wide edict.


[b]Empire-wide edict: "GAI :: Scripted Sector Redev :: allowed/disabled"[/b]
Disable scripted redevelopment with important buildings (like clinic, nexus, mineral/slave processing, etc) in sectors using empire resources for all sectors and planets.

[b]Planetary edict: "GAI :: Redev :: allowed/disabled"[/b]
Disable all scripted redevelopment with important buildings (like clinic, nexus, mineral/slave processing, etc) using empire resources on this planet.
(empire-wide edict "GAI :: Planet Redev Edicts :: displayed/hidden" can be used to display/hide these, as they're now redundant with the ones in stock glavius mod, as mentioned above)


Both edicts can be toggled on and off at any time, with color (red / green) and name/description changing depending on current state.
(this can't be done with a checkbox like in stellaris pre-2.0, as edicts can't be disabled at will now)


Idea behind these edicts is to allow player to do two things, which they currently cannot with base Glavius AI mod:
[list]
[*]Disable sectors draining empire resources arbitrarily, for example when you're purposefully saving these for something expensive - e.g. a battleship, titan or a star fortress upgrade.
(reason behind sectors using empire stockpile is simply because there's no way to access sector stockpile from a mod)

[*]Prevent sector AI from doing redevelopment of fully-developed and/or specialized planets, where buildings which are generally important can be quite counter-productive.
Example can be a mineral-rich world, filled with mines and pops, where AI will try to build useless gene clinic and energy nexus, destroying fully-upgraded mines.
(and disregarding redevelopment option for sectors, as it can't be checked from a mod either)
[/list]
