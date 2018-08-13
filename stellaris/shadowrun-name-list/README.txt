[h1]Cyberpunk / Shadowrun Name List[/h1]

Extensive Name List from The Sixth World of Shadowrun cyberpunk dystopia universe.
For any Stellaris verison, compatible with acheivements and all other mods.

Includes hundreds of names for every aspect of the game - designs, ships, fleets, planets, characters, royal dynasties - from pools of Sixth World character names for different origins/sovereignties, runner names, corporations, gangs, weapons, cities and shops of Shadowrun universe.

Lists were assembled by scripts, picking names from shadowrun.itemcards.com generator pool.


[h1]Links[/h1]

- [url=steamcommunity.com/sharedfiles/filedetails/?id=881118424]Animated Xirmian Portraits[/url] mod - cyberpunk Space Pixies or Shadowrun Elves, you decide.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=687822601]Human Revolution[/url] mod - adds heavily-augmented posthuman species.
- [url=store.steampowered.com/app/756010/Stellaris_Humanoids_Species_Pack/]Humanoids Species Pack[/url] DLC - official Space Dwarves, Space Orks, Space Trolls and other goblinized parts of metahumanity.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=843978491]Cyberpunk Cityscape[/url] mod - fitting cyberpunk cityscape.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=902204956]Diverse Rooms[/url] mod - includes many cyberpunk-themed backdrops for leaders.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=690303049]Tron Legacy Soundtrack[/url] mod - great addition to already-excellent Stellaris score, bridging the gap between it and synthwave dystopia.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=1385224677]Back to the 80's - Stellaris Synthwave Music[/url] mod - neon-age music and loading screens.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=682583213]Fandom Emblems 1.0[/url] mod - includes modern Salish-style S-serpent/dragon Shadowrun empire logo, if you can find it among all the others.
- [url=steamcommunity.com/sharedfiles/filedetails/?id=844023254]Cyberpunk Namelist[/url] mod - smaller cyberpunk name list, drawing from more broad/generic fiction.


[h1]Technical Info[/h1]

In-game mod name: Shadowrun Name List
Name List label: Shadowrun
Name List ID: SR01

Can be installed at any time, but only useful for new empires, as pre-existing empires/savegames will keep using whatever namelists they were created with.
To enable/disable it in existing savegames, if you really want it, unpack these (.sav are zip files) and change name_list= value in species={ ... } section (species using this name list will have name_list="SR01") in "gamestate" file, though it should only apply to new names (all existing ones are saved in same file) and dunno about any side-effects from that.

By default, can be used by randomized species (random AI or randomized player empire) in newly-generated galaxies.
This can be disabled by the "randomized = no" option in shadowrun_01.txt name list file, you'd have to unpack the mod for this though (easiest way - create new mod via Mod Tools in launcher with any name/dir, then unzip archive= from ugc_1363348791.mod ini next to that dir into it).

Planet names get assigned to every space rock in the home system, but all other systems will have generic names like "Tau Ceti VII" - afaik it's not a bug, your empire just doesn't get to pick names for stuff in any neutral systems.
Use "Randomize Name" button when establishing colonies to shuffle through and use empire-specific names for these.
Species names are pre-defined for their class (appearance), not picked-up from selected name lists.

See name list itself (shadowrun_01.txt) for exact commands and name pools used when generating lists for each name category.
Scripts to fetch pools of names (to pick from) and then arrange them into name lists can be found [url=github.com/mk-fg/games/tree/master/stellaris/shadowrun-name-list]here on github[/url].

For example, lists of character names are composed from specific distribution of generated names for different origins of Sixth World (us/uk english, arabic, chinese, french, german, japanese, russian, etc), as well as lists for different sovereignties (AGS, Aztlan, CAS, Hong Kong, UCAS, etc) and list of runner names, with specific counts/proportions between each - see comments / commands / ratios in shadowrun_01.txt (namelist file) for details.
