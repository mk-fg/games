**Important: This mod should probably cause desyncs in multiplayer games**
Mod code uses things which are likely to desync mp games, and I only test singleplayer, so it's highly unlikely that it will "just work" in mp.


--------------------

## Description

Adds Moon Logic Combinator that runs Lua code that can read red/green wire signal inputs and set outputs.

Based on other LuaCombinator mods, but instead of adding more complexity and features, mostly removes them to keep it simple and clean.
I.e. no syntax highlighting, code formatting, binding to factorio events, blueprints, etc.

General principle is that it's not a replacement for Vim/Emacs or some IDE, but just a window where you paste some Lua code/logic or type/edit a couple of lines.
And not a mod development framework either - only a combinator to convert circuit network inputs to outputs, nothing more.

Mostly created because I like using those Lua combinators, and all mods for them seem to be broken and abandoned at the moment.
Fixing/maintaining these is much easier without few thousand lines of extra complexity in there.

"Moon Logic" Combinator is because it's programmed in Lua - "moon" in portugese (as Lua itself originates in Brazil).


--------------------

## Mod Options

Startup Mod Settings:

- Red Wire Label - Lua environment name for in-game "red" circuit network values. Changes all labels in the GUIs as well.
- Green Wire Label - same as Red Wire Label, but for the other wire color.

These can be useful when playing with other mods that change colors, for labels to match those.
Note that red/green input tables are always available in the environment too, for better code/snippet compability.

Some UI hotkeys can also be customized in the Settings - Controls game menu.


--------------------

## Lua Code

Lua is a very simple and easy-to-use programming language, which [fits entirely on a couple pages](http://lua-users.org/files/wiki_insecure/users/thomasl/luarefv51.pdf).
This mod allows using it to script factorio circuit network logic directly from within the game.

Example code:

- Set constant output signal value: `out.wood = 1`

- Simple arithmetic on an input: `out.wood = red.wood * 5`

- Ever-increasing counter: `out.wood = out.wood + 1`

- Don't update counter on every single [game tick](https://wiki.factorio.com/Time#Ticks): `out.wood = out.wood + 1; delay = 60`

- Control any number of things at once:

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
end

```

What is all this dark magic? See [Lua 5.2 Reference Manual](https://www.lua.org/manual/5.2/). I also like [quick pdf reference here](http://lua-users.org/files/wiki_insecure/users/thomasl/luarefv51single.pdf).

Runtime errors in the code will raise global alert on the map, set "mlc-error" output on the combinator (can catch these on Programmable Speakers), and highlight the line where it happened. Syntax errors are reported on save immediately. See in-game help window for some extra debugging options.

Regular combinators are best for simple things, as they work ridiculously fast on every tick. Fancy programmable ones are no replacement for them.


--------------------

## Known Issues and quirks

- Hotkeys for save/undo/redo/etc don't work when code textbox is focused, you need to press Esc or otherwise unfocus it first.
- Combinator code is not serialized to blueprints, need to restore that later.

Big thanks to [ixu](https://mods.factorio.com/user/ixu) for testing the mod extensively and reporting dozens of bugs here.


--------------------

## Links


- Nice and useful Circuit Network extensions:

    - [Switch Button](https://mods.factorio.com/mod/Switch_Button-1_0) - On/Off switch with configurable signal.

        Kinda like [Pushbutton](https://mods.factorio.com/mod/pushbutton), but signal is persistent, not just pulse, which is easiler to work with from any kind of delayed checks.
        Works from anywhere on the radar-covered map (flip with E key).
        Don't forget to bind a hotkey to change its signal, as [it defaults to none and won't enable without it](https://mods.factorio.com/mod/Switch_Button-1_0/discussion/5f53449361f20f06a85aac9f).

    - [Nixie Tubes](https://mods.factorio.com/mod/nixie-tubes) - a nice display for signal values.

        [Integrated Circuitry](https://mods.factorio.com/mod/integratedCircuitry) has even more display options and a neat wire support posts.

    - [Schall Virtual Signal](https://mods.factorio.com/mod/SchallVirtualSignal) - adds a bunch more extra signals to use on the net.

        They might not be very descriptive - mostly just more numbers - but there are a lot of them!

    - [Time Series Graphs](https://mods.factorio.com/mod/timeseries) - time-series monitoring/graphing system for your network.

    - [RadioNetwork](https://mods.factorio.com/mod/RadioNetwork) - to control everything from afar.


- This mod base/predecessors:

    - [Sandboxed LuaCombinator](https://mods.factorio.com/mod/SandboxedLuaCombinator) by [IWTDU](https://mods.factorio.com/user/IWTDU)

        Mod that this code was initially from. See changelog for an up-to-date list of differences. Seem to be abandoned atm (2020-08-31).

    - [LuaCombinator 2](https://mods.factorio.com/mod/LuaCombinator2) by [OwnlyMe](https://mods.factorio.com/user/OwnlyMe)

        Great mod on which Sandboxed LuaCombinator above was based itself. Long-deprecated by now.


- Other programmable logic combinator mods, in no particular order:

    - [LuaCombinator 3](https://mods.factorio.com/mod/LuaCombinator3) - successor to LuaCombinator 2.

        Unfortunately quite buggy, never worked right for me, and way-way overcomplicated, exposing pretty much whole factorio Lua modding API instead of simple inputs-and-outputs sandbox for in-game combinator logic. Seem to be abandoned at the moment (2020-08-31).

        There's also [LuaCombinator 3 Fixed](https://mods.factorio.com/mod/LuaCombinator3_fixed), which probably works better with current factorio and other mods.

    - [fCPU](https://mods.factorio.com/mod/fcpu) - simple cpu emulator, allowing to code logic in custom assembly language.

        Actually takes in-game ticks to run its assembly instructions for additional challenge.
        Stands somewhere in-between gate/cmos logic of vanilla factorio and high-level scripting like Lua here.
        Has great documentation, including in-game one.

    - [Improved Combinator](https://mods.factorio.com/mod/ImprovedCombinator) - factorio combinator combinator.

        Combines operations of any number of factorio combinators into one processing pipeline.
        Nice to save space and make vanilla simple combinator logic more tidy, without the confusing mess of wires.

    - [Advanced Combinator](https://mods.factorio.com/mod/advanced-combinator) - like Improved Combinator, but allows more advanced logic.

    - [MicroController](https://mods.factorio.com/mod/m-microcontroller) - similar to fCPU above, runs custom assembly instructions on factorio ticks.

    - [Programmable Controllers](https://mods.factorio.com/mod/programmable-controllers) - adds whole toolkit of components to build von Neumann architecture machine.

        Kinda like fCPU and MicroController as a starting point, but with extensible architecture, power management and peripherals.


- [Github repo link](https://github.com/mk-fg/games/tree/master/factorio/Moon_Logic)
