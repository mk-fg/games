**Important: This mod should probably cause desyncs in multiplayer games**
Mod code uses things which are likely to desync mp games, and I only test singleplayer, so it's highly unlikely that it will "just work" in mp.

&nbsp;

--------------------

--------------------

## Description

Adds Moon Logic Combinator that runs Lua code that can read red/green wire signal inputs and set outputs.

Based on other LuaCombinator mods, but instead of adding more complexity and features, mostly removes them to keep it simple and clean.
I.e. no syntax highlighting, code formatting, binding to factorio events, etc.

General principle is that it's not a replacement for Vim/Emacs or some IDE, but just a window where you paste some Lua code/logic or type/edit a couple of lines.
And not a mod development framework either - only a combinator to convert circuit network inputs to outputs, nothing more.

Mostly created because I like using such Lua combinators myself, and all other mods for them seemed to be broken and abandoned atm.
Fixing/maintaining these is much easier without few thousand lines of extra complexity in there.

"Moon Logic" Combinator is because it's programmed in Lua - "moon" in portugese (as Lua itself originates in Brazil).

&nbsp;

--------------------

--------------------

## Mod Options

Startup Mod Settings:

- Red Wire Label - Lua environment name for in-game "red" circuit network values. Changes all labels in the GUIs as well.
- Green Wire Label - same as Red Wire Label, but for the other wire color.

These can be useful when playing with other mods that change colors, for labels to match those.
Note that red/green input tables are always available in the environment too, for better code/snippet compability.

- GUI Signals Update Interval

Interval in game ticks (60 ticks = 1 second at 1x game speed) between updating signal table in the UI.
Only relevant when main combinator UI window is actually open. Default is 1 - update signal side-window on every tick.
Note that with higher interval values, signals flapping on/off synced to it will be impossible to notice there.

- Enable Code Editing History

Toggles between smooth and pleasant editing or undo/redo buttons on top working for all non-saved code changes.
If you don't use these buttons to undo minor changes (they still keep history of saved changes), be sure to uncheck this.

UI hotkeys can also be customized in the Settings - Controls game menu.

There is an optional hotkey (Ctrl-E) for opening these combinators from anywhere on the map,
which kinda breaks basic game mechanics in a way similar to various "Long Reach" mods,
but can be useful if code breaks too often and is hard to reach for debugging all the time.

&nbsp;

--------------------

--------------------

## Lua Code

Lua is a very simple and easy-to-use programming language, which [fits entirely on a couple pages](http://lua-users.org/files/wiki_insecure/users/thomasl/luarefv51.pdf).
This mod allows using it to script factorio circuit network logic directly from within the game.
&nbsp;

----------

**-- Trivial one-liner examples:**

----------

- Set constant output signal value: `out.wood = 1`

- Simple arithmetic on an input: `out.wood = red.wood * 5`

- Ever-increasing output counter: `out.wood = out.wood + 1`

- Update counter once per second (see [game tick](https://wiki.factorio.com/Time#Ticks)): `delay, out.wood = 60, out.wood + 1`

- +1 counter every tick while signal-W input is non-zero: `delay, irq, out.wood = 2^30, 'signal-W', out.wood + 1`

- Different value on each output wire: `out['red/wood'], out['green/wood'] = -3, 10`

Click in-game "Quick Reference" button in combinator window for a full list of all special values and APIs there, default hotkeys and other general info.
&nbsp;

----------

**-- Control any number of things at once:**

----------
```
local our_train = 17 -- hover over train to find out its ID number
local train_loaded, train_unloaded -- locals get forgotten between runs

if red['signal-T'] == our_train then
  if not var.inbound_manifest_checked then
    -- Emit alarm signal for underloaded train arrival while it's on station
    -- Note how outputs persist until they are changed/reset
    out['signal-info'] = red['sulfur'] < 100 or red['solid-fuel'] < 200
    var.inbound_manifest_checked = true
  end

  out['signal-black'] = red.coal < 500 -- load coal
  out['signal-grey'] = red.barrel < 20 -- load barrels

  train_loaded =
    not (out['signal-black'] or out['signal-grey']) -- cargo limit
    or (var.coal == red.coal and var.barrels == red.barrel) -- no change since last check
  var.coal, var.barrels = red.coal, red.barrel -- remember for the next check

  local inbound_cargo = red['sulfur'] + red['solid-fuel']
  train_unloaded = inbound_cargo ~= var.inbound_cargo -- that's "not equals" in Lua
  var.inbound_cargo = inbound_cargo

  out['signal-check'] = train_loaded and train_unloaded -- HONK!
  if out['signal-check']
    then var.inbound_manifest_checked = false end -- reset for the next arrival

  delay = 2 * 60 -- check on cargo loading every other second
else
  out = {} -- keep inserters idle and environment clean
  delay = 20 * 60 -- check for next train every 20s
  irq = 'signal-T' -- any train on station will interrupt the delay
  irq_min_interval = delay -- to sleep when other train triggers that irq signal
end
```

As comments in the code might suggest already, it's a train station automation example.
&nbsp;

----------

**-- Toy example - 7-segment digit display for a ticking 0-9 counter:**

----------
```
local digit_segments = { -- segments to light up for 0, 1, 2, 3, ...
  'ABCDEF', 'BC', 'ABDEG', 'ABCDG', 'BCFG',
  'ACDFG', 'ACDEFG', 'ABC', 'ABCDEFG', 'ABCDFG' }
out, var.n = {}, (var.n or 0) % 10 + 1
for c in digit_segments[var.n]:gmatch('.') do out['signal-'..c] = 1 end
delay = 60
```

![Moon Logic ticker GIF](https://e.var.nz/factorio-moon-logic-ticker.cwc9p3ne69sn6.gif)

Blueprint for lamp segments used in the above example (A-F go clockwise from top, G is the middle one),
for "Import String" button in the shortcut bar at the bottom of the screen:

```
0eNrVmN1qrDAQx99lrm1x1MTVi8L57EOUZXF3056ARolx6bLk3WtW2u7JacCAHsiNMPmYxB8z/xm9wL4
eWCe5UFBegB9a0UP5dIGev4iqNmPq3DEogSvWQASiaozVN1Vd39VV04GOgIsje4US9TYCJhRXnE1ersZ
5J4Zmz+S44Kv9EXRtP25phTnNuMF7EsEZyoTck9H7eCcl23q3Z3+qE2+lWXbg8jBwtRvnjh97n7ns1e6
fm5+4VMM48nn4dcXdN5ic96oybx8bo+kqWSlzBjyAnuYFO5gTeuMSzUOy4+3b8dFKdPSXneqt1jdj7wS
SeQTi8AigRYA4CKTzCCThE8gdBLJZBIp3APmqAH4vCIBYADB2ECB+BGgwBGwZyBwA6LwkSP9PDHxfkEB
ux0DiQJB7IqDBIEgtBNRBYOOXBcWqAH4tKYSxHQSuclh4NgSbVRk8rsrAlQgYe/YE4UAoLAabmfKI6Ck
O6+bGjyXjwi4R6GoTMPHslMKJC2oxsOME0cUk9dLMNA5GM+3UQGduZH5ykeKqDH4umRt25UTXRwQSv8I
REoTMhuDqH5D6CURIEMhslfTsI1eWhEVLBX4dCdto+hlT3vy7ieDEZH+9c7LBLM+KnOYYU0K1fgMg+xdn
```

(adapted from [this post in the old LuaCombinator forum thread](https://forums.factorio.com/viewtopic.php?p=394048#p394048))
&nbsp;

----------

**-- What is all this dark magic?**

----------

See [Lua 5.2 Reference Manual](https://www.lua.org/manual/5.2/). I also like [quick pdf reference here](http://lua-users.org/files/wiki_insecure/users/thomasl/luarefv51single.pdf).

Runtime errors in the code will raise global alert on the map, set "mlc-error" output on the combinator (can catch these on Programmable Speakers), and highlight the line where it happened. Syntax errors are reported on save immediately. See in-game help window for some extra debugging options.

Regular combinators are best for simple things, as they work ridiculously fast on every tick. Fancy programmable ones are no replacement for them.

&nbsp;

--------------------

--------------------

## Known Issues and quirks

- There are some known limitations wrt storing/copying combinator code via blueprints:

    - Using blue "Select new contents" button in blueprint window will not store combinator code in that updated blueprint.

        At least as of Factorio 1.1.36, there's no good way to detect this happening to warn about it, so maybe avoid using that button.
        See bug report threads [#88100](https://forums.factorio.com/88100), [#99323](https://forums.factorio.com/99323) and ["text not copied when blueprinted" discussion thread here](https://mods.factorio.com/mod/Moon_Logic/discussion/5f51799b456fefcdcc7c7b76) for more details.

    - As of 2021-08-08, it was pointed out that current version 1.0.3 of [The Blueprint Designer Lab](https://mods.factorio.com/mod/BlueprintLab_design/) mod does not restore combinator code when placing blueprints in the lab there, due to how it's done in v1.0.3 of that mod.

        See this issue raised by ezonius in [a long "Text not copied when blueprinted" discussion thread](https://mods.factorio.com/mod/Moon_Logic/discussion/5f51799b456fefcdcc7c7b76) for details.

- Hotkeys for save/undo/redo/etc don't work when code textbox is focused, you need to press Esc or otherwise unfocus it first.
- Cursor position when clicking on the code box can be weird and unintiutive - just click again if you don't see it on the spot.

Huge thanks to [ixu](https://mods.factorio.com/user/ixu) and [completion](https://mods.factorio.com/user/completion) for testing the mod extensively and reporting dozens of bugs here.

&nbsp;

--------------------

--------------------

## Links


- [Frequently Asked Questions (FAQ) page](https://mods.factorio.com/mod/Moon_Logic/faq) has more info on this mod.
&nbsp;

- Nice and useful Circuit Network extensions:

    - [Switch Button](https://mods.factorio.com/mod/Switch_Button-1_0) - On/Off switch with configurable signal.

        Kinda like [Pushbutton](https://mods.factorio.com/mod/pushbutton), but signal is persistent, not just pulse, which is easier to work with from any kind of delayed checks.
        Works from anywhere on the (radar-covered) map by default, and can be flipped by simple left-click or E key.
        &nbsp;

    - [Nixie Tubes](https://mods.factorio.com/mod/nixie-tubes) - a nice display for signal values.

        [Integrated Circuitry](https://mods.factorio.com/mod/integratedCircuitry) has even more display options and a neat wire support posts.
        &nbsp;

    - [Time Series Graphs](https://mods.factorio.com/mod/timeseries) - time-series monitoring/graphing system for your network.

    - [Colored Signals](https://mods.factorio.com/mod/colored_signals), [Schall Virtual Signal](https://mods.factorio.com/mod/SchallVirtualSignal) - more signals to use on the network.

    - [RadioNetwork](https://mods.factorio.com/mod/RadioNetwork), [Factorio LAN](https://mods.factorio.com/mod/Factorio-LAN), etc - to link remote networks together and control things from afar.
    &nbsp;

- This mod base/predecessors:

    - [Sandboxed LuaCombinator](https://mods.factorio.com/mod/SandboxedLuaCombinator) by [IWTDU](https://mods.factorio.com/user/IWTDU)

        Mod that this code was initially from. See changelog for an up-to-date list of differences. Seem to be abandoned atm (2020-08-31).
        &nbsp;

    - [LuaCombinator 2](https://mods.factorio.com/mod/LuaCombinator2) by [OwnlyMe](https://mods.factorio.com/user/OwnlyMe)

        Great mod on which Sandboxed LuaCombinator above was based itself. Long-deprecated by now.
        I think this one is also based off [Patched LuaCombinator](https://mods.factorio.com/mod/LuaCombinator) and the original [LuaCombinator](https://forums.factorio.com/viewtopic.php?f=93&t=15352) mods, but not sure.
        &nbsp;

- Other programmable logic combinator mods, in no particular order:

    - [LuaCombinator 3](https://mods.factorio.com/mod/LuaCombinator3) - successor to LuaCombinator 2.

        Unfortunately quite buggy, never worked right for me, and way-way overcomplicated, exposing pretty much whole factorio Lua modding API instead of simple inputs-and-outputs sandbox for in-game combinator logic. Seem to be abandoned at the moment (2020-08-31).

        There's also [LuaCombinator 3 Fixed](https://mods.factorio.com/mod/LuaCombinator3_fixed), which probably works better with current factorio and other mods.
        &nbsp;

    - [fCPU](https://mods.factorio.com/mod/fcpu) - simple cpu emulator, allowing to code logic in custom assembly language.

        Actually takes in-game ticks to run its assembly instructions for additional challenge.
        Stands somewhere in-between gate/cmos logic of vanilla factorio and high-level scripting like Lua here.
        Has great documentation, including in-game one.
        &nbsp;

    - [Improved Combinator](https://mods.factorio.com/mod/ImprovedCombinator) - factorio combinator combinator.

        Combines operations of any number of factorio combinators into one processing pipeline.
        Nice to save space and make vanilla simple combinator logic more tidy, without the confusing mess of wires.
        &nbsp;

    - [Advanced Combinator](https://mods.factorio.com/mod/advanced-combinator) - like Improved Combinator, but allows more advanced logic.

    - [MicroController](https://mods.factorio.com/mod/m-microcontroller) - similar to fCPU above, runs custom assembly instructions on factorio ticks.

    - [Programmable Controllers](https://mods.factorio.com/mod/programmable-controllers) - adds whole toolkit of components to build von Neumann architecture machine.

        Kinda like fCPU and MicroController as a starting point, but with extensible architecture, power management and peripherals.
        &nbsp;

- [Github repo link](https://github.com/mk-fg/games/tree/master/factorio/Moon_Logic)

&nbsp;

--------------------

--------------------

If you like this mod and want to support it, buy yourself a coffee or something, idk.
