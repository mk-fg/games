Games
=====
-------------------------------------------------------
Misc game-related tweaks and tools that I tend to write
-------------------------------------------------------

Just a collection of accumulated stuff in no particular order, to be able to
link or remember stuff occasionally.


`Satellite Reign`_: sat-reign-pick-clone
-------------------------------------

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
