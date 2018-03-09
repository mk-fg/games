Games
=====
-------------------------------------------------------
Misc game-related tweaks and tools that I tend to write
-------------------------------------------------------

Just a collection of accumulated stuff in no particular order, to be able to
link or remember stuff occasionally.

Pretty much always have some -h/--help output, with purpose and options
documented there, as I tend to write these to avoid forgetting them myself.

Likely to be out of date to a various degree for most games/mods that get updates.


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


`Satellite Reign`_: sat-reign-pick-clone
----------------------------------------

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

- production-chains-best.{png,xcf}

  Production chain ratios, space requirements (production "field" count/size),
  and numbers for how much demand they satisfy, as getting them right through
  trial and error is very wasteful and hard to remember them all.

.. _Anno 2070: http://anno2070.wikia.com/


`OpenXCOM: X-PirateZ mod`_: pirate-melee-calc.py
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

.. _OpenXCOM\: X-Piratez mod: https://www.ufopaedia.org/index.php/Piratez
