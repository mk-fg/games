Games
=====
-------------------------------------------------------
Misc game-related tweaks and tools that I tend to write
-------------------------------------------------------

Just a collection of accumulated stuff in no particular order, to be able to
link or remember stuff occasionally.

Scripts here pretty much always have some -h/--help option/output, with
purpose/usage and all options documented there, as tend to write these down to
avoid forgetting them myself.

Likely to be out of date to a various degree for most games/mods that get updates.


.. contents::
  :backlinks: none


`Surviving Mars`_
-----------------

Great sci-fi city builder, like Outpost games of old, but with much lighter tone, and on Mars.

Minor quality-of-life lua tweaks for early versions:

- `cheaper-consumer-items <https://www.nexusmods.com/survivingmars/mods/4>`_

  70% cheaper Art and Electronics shop consumables for crowded domes, as they
  really slow production down needlessly otherwise.

- `no-border-scrolling <https://www.nexusmods.com/survivingmars/mods/5>`_

  For some reason it's extremely sensitive and annoying here, though maybe
  because I tend to move cursor from the window to tweak more lua too often.

- `university-entrance-exams <https://www.nexusmods.com/survivingmars/mods/6>`_

  Bars mentally challenged colonists from studying in Martian University,
  leaving them in service jobs forever, where they can do relatively little harm.

- polymers-production-buff

  Alternative to "cheaper-consumer-items" hack to just boost a-bit-too-slow
  resource production on that sanity-breaking outdoors factory instead.

- `console.lua <surviving-mars/console.lua>`_

  Adds in-game lua testing and introspection console.

  Has built-in docs, and created mostly to dump info on any selected /
  around-cursor objects (in json/text formats) or test arbitrary lua calls.

.. _Surviving Mars: https://www.survivingmars.com/


`Stellaris`_
------------

Sometimes needs a bunch of fixes and/or balancing tweaks for whatever weird and
unexpected game scenario you end up with, though extra content mods are nice too.

Mods for latest 2.0.x playthrough:

- `More Hyperlane Chokepoints
  <https://steamcommunity.com/sharedfiles/filedetails/?id=1310625695>`_

  Since game version 2.0 FTL went hyperlane-only (oh well), but options to tweak
  layout of these for galaxy generation are still kinda rudimentary, hence the
  mod to get it "just right".

- `Fast Cyborg Assimilation
  <https://steamcommunity.com/sharedfiles/filedetails/?id=1322434314>`_

  Cybernetic assimilation mechanics were clearly developed for either gestalt
  consciousness empires which have no politics, or egalitarian ones that have
  all species rights granted by default.

  Don't work well for authoritarian/xenophobe slavers, as this sets all
  assimilating pops "free" for a long time, and keep resetting rights for
  assimilated pops to "full citizenship" for no good reason.

  Simple workaround implemented in this mod is to make process fast enough to be
  less painful - more of a quick disruption than decades-long PITA.

.. _Stellaris: http://www.stellariswiki.com/


`Factorio`_
-----------

Great game, but found large-scale production required in late-game a bit too
slow or tedious to setup or debug without lots of boring unimaginative repetition.

Easy to fix with mods though, which are one of the best parts of the game.

- mod-list.yaml - list of mods from when I last played (should include base game
  version number) and backed it up.

- ReducedResearchX

  Local mod to reduce all research costs by somewhat complicated formula,
  designed to keep early-game tech costs pretty-much as-is, but have massive
  reductions for late-game techs.

  Formula (python3): ``cost = lambda v: (a + max(0,v-a)*b**(v/(v+c)))``

  a, b and c there are tweakable via config.lua, and can be tested like this::

    % python3
    cost = lambda v: (a + max(0,v-a)*b**(v/(v+c)))
    a,b,c=50,0.2,200
    list(map(int, [cost(100),cost(200),cost(300),cost(500),cost(1000),cost(2000),cost(5000)]))
    # output: [100=79, 200=117, 300=145, 500=192, 1000=298, 2000=501, 5000=1103]

  Shows how late-game techs that cost 1k/2k/5k research units get down to
  ~300/500/1k, while early-game ones get much smaller reductions.

  | Does not change research time by default, as it's not a bottleneck anyway.
  | Based on very simple "ReducedResearch" mod (~10 lines of lua), which was a
    bit too linear for me.

- blueprints.yaml - misc blueprints I came up with, esp. for defence units or
  stuff like circuit logic parts.

Useful companion links for the game:

- https://doomeer.com/factorio/ - production chain calculator, simpliest.
- https://rubyruy.github.io/factorio-calc/ - same as above, but found it harder to use.

Best use for production chain calculators (that I've found) is to know in
advance how much basic resources (like copper and steel) to put into main belts
for some desired output level, and how many assemblers/throughput it'd require.

.. _Factorio: http://factorio.com/


`Darkest Dungeon`_: darkest-dungeon-save-manager.py
---------------------------------------------------

Cheat tool to backup DD save games, as it's too hardcore, random-bs and grindy
for my tastes.

So simple fix is just to allow some (minor) save-scumming, which is what this
tool does - allows to copy saved game state to multiple slots, like with any
less hardcore game.

Usage::

  % ./darkest-dungeon-sm save
  % ./darkest-dungeon-sm save some-slot-name

  % ./darkest-dungeon-sm list
  % ./darkest-dungeon-sm   # same thing

  % ./darkest-dungeon-sm restore   # latest slot
  % ./darkest-dungeon-sm restore some-slot-name
  % ./darkest-dungeon-sm restore any-name-part
  % ./darkest-dungeon-sm restore .5.

  % ./darkest-dungeon-sm remove -n10   # show 10 oldest slots to cleanup
  % ./darkest-dungeon-sm remove -n10 -x   # actually remove stuff

Remove some tension from the game for sure, if you know that the save is not
that far-off, but at least it's playable that way.

.. _Darkest Dungeon: http://www.darkestdungeon.com/


`Satellite Reign`_: sat-reign-pick-clone.py
-------------------------------------------

Simple script to find clone id in savegame xml by specified parameters.

Mostly cosmetic thing - allows to transplant some game-important parameters into
clone/agent with specific appearance, which was (maybe still is) cool because
there are all sorts of fancy cyberpunk character models in that game, but you
can't switch these for agents without sacrificing stats.

Usage:

- Pick whatever clone you want to use ingame, remember their stats.

- Run tool to find id of that clone in savegame by stats::

    ./sat-reign-pick-clone.py 'h: 5, s: 9, hr: 0.05, e: 0, er: 0' sr_save.xml

- Find that id in xml, paste stats from current (up-to-date) agent clone into
  weak clone with that id and appearance, so it'd be viable to use.

- Load game and swap agent into that clone.

.. _Satellite Reign: http://satellitereign.com/


`Anno 2070`_
------------

City layouts and production chains, as that's pretty much all there is in that
game, plus pretty graphics ofc.

- layout-\*.png

  | City layout templates, probably nicked from wikia.
  | For early techs this is kinda important, as costs are quite high there.
  | Usually use large corridor layout for sprawling non-tech cities.

- production-chains-best.{png,xcf}

  Production chain ratios, space requirements (production "field" count/size),
  and numbers for how much demand they satisfy, as getting them right through
  trial and error is very wasteful and hard to remember them all.

.. _Anno 2070: http://anno2070.wikia.com/


`Kerbal Space Program`_ (ksp)
-----------------------------

Bunch of delta-V and aerobraking maps, along with some outdated mod tweaks.

.. _Kerbal Space Program: https://kerbalspaceprogram.com/


`OpenXCOM XPirateZ mod`_: piratez-melee-calc.py
------------------------------------------------

Curses tool to examine/compare stats per TU and various buffs for hundreds of
weapons that are in that mod, which are not particulary well-documented.

Example run::

  % ./piratez-melee-calc.py -a -c ruleset_099F5.yaml.cache.json
    x:Ax 'Ball Bat' Saber Shiv Handle x:Dagger Rope x:Pipe Cutlass
    Fistycuffs Handy Shovel Machete Billhook Cattle 'Leather Whip'
    x:Spear 'Spiked Mace' Barbaric Barbed Rapier 'Fuso Sword'

Curses UI::

   strength: 33  melee: 70  throwing: 40  time: 65  bravery: 40   >>

  wght weapon         -- HM type dmg acc  dpu - costs     [specials]
  ---- ---------      -- --------------------------------------------------
  [12] Ax             -- 1M cut  80  60%  3.4 - 14 TU  8E [d2]
  [ 7] Ball Bat       -- 1M stn  35  71%  2.1 - 12 TU  4E [toH=0.75 d2]
  [20] Barbaric Sword -- 2M cut  85  63%  4.1 - 13 TU 13E [kArmor=1.25 d2]
  [ 4] Barbed Dagger  -- 1M cut  40  30%  1.5 -  8 TU  3E [kArmor=0.9 toM=10.0 d2]
  [ 8] Billhook       -- 1M cut  62  64%  2.6 - 15 TU  5E [toM=10.0 d2]
  [ 6] Cattle Prod    -- 2M las  70  94%  3.3 - 20 TU  4E [toH=0.0 toStn=1.0 +]
  [ 5] Cutlass        -- 1M cut  40  60%  3.0 -  8 TU  3E [kArmor=1.2 d2]
  [ 3] Dagger         -- 1M cut  27  32%  1.2 -  7 TU  2E [d2]
  [ 3] Fistycuffs     -- 1M stn  34  46%  1.9 -  8 TU  2E [toH=0.35 d1]
  [11] Fuso Sword     -- 2M cut  85  70%  5.0 - 12 TU  7E [kArmor=1.4 d2]
  [ 4] Handle         -- 1M stn  31  60%  2.0 -  9 TU  3E [toH=0.15 toM=-1.0 d2]
  [ 3] Leather Whip   -- 1S stn  17  69%  0.8 - 14 TU  4E [kArmor=1.25 toH=0.1 toM=15.0 toTU=3.0 d6 -dmg[4+]=999]
  [ 3] Machete        -- 1M cut  34  68%  3.8 -  6 TU  2E [kArmor=1.3 d2]
  [10] Mr. Handy      -- 2M stn  45  62%  2.0 - 14 TU  7E [res=con toH=1.0 d2]
  [ 5] Pipe           -- 1M con  33  62%  1.9 - 11 TU  3E [toStn=1.25]
  [ 6] Rapier         -- 1M cut  48  63%  3.4 -  9 TU  4E [d2]
  [ 4] Rope           -- 2M stn  23  84%  0.5 - 36%TU 16E [kArmor=0.0 res=chk toH=0.2 toE=2.0 d2]
  [ 7] Saber          -- 1M cut  62  70%  4.4 - 10 TU  5E [kArmor=1.2 d2]
  [ 2] Shiv           -- 1M cut  19  30%  1.1 -  5 TU  2E [d2]
  [ 8] Shovel         -- 2M cut  52  58%  2.0 - 15 TU  5E [kArmor=1.3 toStn=2.0 d2]
  [ 7] Spear          -- 2M prc  53  88%  2.9 - 16 TU  5E [kArmor=0.8 toTU=4.0 d2]
  [15] Spiked Mace    -- 1M con  53  60%  2.0 - 16 TU 10E [kArmor=0.75 toStn=1.0 toA-pre=0.1]

Main field is "dpu" - Damage per TU - which is calculated as "damage-per-hit *
accuracy / TU" for melee weapons, with no accuracy multiplier for ranged.

Also shows all special effects in addition to that, allowing to easily pick
something good for specific purpose, taking specifici soldier's attributes into
account (input on top).

piratez-extract-rulesets.sh is a helper script to run ``piratez-melee-calc.py
-c`` and cache all the stuff from multiple YAML sources so that these will be
parsed much faster from there, and there'll be no need to specify all of them on
each run (as cache-file contains all the info).

Fair Warning: art/text in that mod can get weird.

.. _OpenXCOM XPirateZ mod: https://www.ufopaedia.org/index.php/Piratez


Misc Scripts
------------

Helper scripts not related to specific games.

- gog-unpack.sh

  Script to unpack GoG (gog.com) linux archives without running makeself and
  mojosetup.

  They seem to have ``[ N lines of makeself script ] || mojosetup.tar.gz ||
  game.zip`` format, and script creates \*.mojosetup.tar.gz and \*.zip in the
  current directory from specified .sh pack, using only grep/head/tail coreutils.

  Usage: ``./gog-unpack.sh /path/to/gog-game.sh``

  Note that zip can have configuration and post-install instructions for
  mojosetup in it (under "scripts/"), plus misc assets like icons and such.
