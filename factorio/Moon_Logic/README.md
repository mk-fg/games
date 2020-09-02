**Important:** this is an early release of this mod, so expect more than the usual amount bugs crawling in here!
(and please report any crashes with lua backtrace from factorio log or just a screenshot of it, thanks)

**This mod should probably cause desyncs in multiplayer games**
Mod code uses things which are likely to desync mp games, and I only test singleplayer, so it's highly unlikely that it will "just work" in mp.


--------------------

## Description

Adds Moon Logic Combinator that runs Lua code that can read red/green wire signal inputs and set outputs.

Based on other LuaCombinator mods, but instead of adding more complexity and features, removes them to keep it simple and clean.
I.e. no syntax highlighting, code formatting, binding to factorio events, blueprints, etc.

General principle is that it's not a replacement for Vim/Emacs or some IDE, but just a window where you paste some Lua code/logic or type/edit a couple of lines.
And not a mod development framework either - only a combinator to convert circuit network inputs to outputs, nothing more.

Mostly created because I like using those Lua combinators, and all mods for them seem to be broken and abandoned at the moment.
Fixing/maintaining these is much easier without few thousand lines of extra complexity in there.

"Moon Logic" Combinator is because it's programmed in Lua - "moon" in portugese (as Lua itself originates in Brazil).


--------------------

## Known Issues

- There really should be the usual Ok / Apply / Cancel button triplet in the UI there, not just Apply masquerading as Ok.
- Some editing hotkeys would be nice: ctrl+s (save), ctrl+z (undo), ctrl+y/ctrl+shift+z (redo), ctrl+enter (save/close).
- "Clear script" button would be useful.
- Needs some code examples and screenshots here.


--------------------

## Links


- This mod base/predecessors

    - [Sandboxed LuaCombinator](https://mods.factorio.com/mod/SandboxedLuaCombinator) by [IWTDU](https://mods.factorio.com/user/IWTDU)

        Mod that this code was initially from. See changelog for an up-to-date list of differences. Seem to be abandoned atm (2020-08-31).

    - [LuaCombinator 2](https://mods.factorio.com/mod/LuaCombinator2) by [OwnlyMe](https://mods.factorio.com/user/OwnlyMe)

        Base mod on which Sandboxed LuaCombinator above was based itself. Long-deprecated by now.


- Other programmable logic combinator mods, in no particular order

    - [LuaCombinator 3](https://mods.factorio.com/mod/LuaCombinator3) - successor to LuaCombinator 2, which this mod is based on.

        Unfortunately quite buggy, never worked right for me, and way-way overcomplicated, exposing pretty much whole factorio Lua modding API instead of simple inputs-and-outputs sandbox for in-game combinator logic. Seem to be abandoned at the moment (2020-08-31).

        There's also [LuaCombinator 3 Fixed](https://mods.factorio.com/mod/LuaCombinator3_fixed), which probably works better with current factorio and other mods.

    - [fCPU](https://mods.factorio.com/mod/fcpu) - simple cpu emulator, allowing to code logic in custom assembly language.

        Actually takes in-game ticks to run its assembly instructions for additional challenge.
        Stands somewhere in-between gate/cmos logic of vanilla factorio and high-level scripting like Lua here.
        Has great documentation, including in-game one.

    - [Improved Combinator](https://mods.factorio.com/mod/ImprovedCombinator) - factorio combinator combinator.

        Combines operations of any number factorio combinators into one processing pipeline.
        Nice to save space and make vanilla simple combinator logic more tidy, without the confusing mess of wires.

    - [Advanced Combinator](https://mods.factorio.com/mod/advanced-combinator) - like Improved Combinator, but allows more advanced logic.

    - [MicroController](https://mods.factorio.com/mod/m-microcontroller) - similar to fCPU above, runs custom assembly instructions on factorio ticks.

    - [Programmable Controllers](https://mods.factorio.com/mod/programmable-controllers) - adds whole toolkit of components to build von Neumann architecture machine.

        Kinda like fCPU and MicroController as a starting point, but with extensible architecture, power management and peripherals.


- [Github repo link](https://github.com/mk-fg/games/tree/master/factorio/Moon_Logic)
